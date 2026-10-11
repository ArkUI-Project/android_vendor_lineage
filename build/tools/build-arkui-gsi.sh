#!/usr/bin/env bash
# Copyright (C) 2026 The ArkUI Project
# SPDX-License-Identifier: Apache-2.0

# Android's environment scripts are not nounset-safe.
set -eo pipefail

usage() {
    cat <<'EOF'
Usage: bash vendor/lineage/build/tools/build-arkui-gsi.sh \
    --artifacts-dir /absolute/path/outside/source [--jobs N] [--official]

Build the ArkUI ARM64 vanilla GSI and package its system image.
Default: userdebug, EXPERIMENTAL, 4 jobs, isolated out/arkui-gsi directory.
--official requires a clean source tree; it does not sign or publish a release.
No source sync, emulator operation, flashing, or upload is performed.
EOF
}

fail() { echo "Error: $*" >&2; exit 1; }

artifacts_dir=
jobs=4
release_type=EXPERIMENTAL
while (($#)); do
    case "$1" in
        --artifacts-dir)
            (($# >= 2)) || fail '--artifacts-dir needs a value'
            artifacts_dir=$2; shift 2 ;;
        --jobs)
            (($# >= 2)) || fail '--jobs needs a value'
            jobs=$2; shift 2 ;;
        --official) release_type=OFFICIAL; shift ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done
[[ $jobs =~ ^[1-9][0-9]*$ ]] || fail '--jobs must be a positive integer'
[[ $artifacts_dir == /* ]] || fail '--artifacts-dir must be an absolute path'

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
cd "$source_dir"
[[ -d .repo && -f build/envsetup.sh ]] || fail 'A complete repo source tree is required'
for tool in xz sha256sum flock realpath cmp; do
    command -v "$tool" >/dev/null || fail "Missing tool: $tool"
done
repo_tool=$(command -v repo || true)
[[ -n $repo_tool ]] || repo_tool="$source_dir/.repo/repo/repo"
[[ -x $repo_tool ]] || fail 'repo is not available'

artifacts_dir=$(realpath -m -- "$artifacts_dir")
case "$artifacts_dir/" in
    "$source_dir/"*) fail 'Keep exported artifacts outside the Android source tree' ;;
esac

# Never reuse the emulator output, or inherit its product/release selection.
# Soong's test_package rules expect host output paths to start with "out".
# The script has already changed to the source root, so keep OUT_DIR relative.
export OUT_DIR=out/arkui-gsi
unset OUT_DIR_COMMON_BASE OUT_DIR_SUFFIX DIST_DIR
unset TARGET_PRODUCT TARGET_RELEASE TARGET_BUILD_VARIANT TARGET_BUILD_APPS
unset LINEAGE_EXTRAVERSION TARGET_UNOFFICIAL_BUILD_ID RELEASE_TYPE
unset WITH_ADB_INSECURE
export LINEAGE_BUILDTYPE=$release_type
export WITH_GMS=false
mkdir -p "$OUT_DIR" "$artifacts_dir"
exec 9>"$OUT_DIR/.arkui-gsi.lock"
flock -n 9 || fail 'Another ArkUI GSI build is running'

stage=$(mktemp -d "$artifacts_dir/.arkui-gsi-partial-XXXXXXXX")
trap 'result=$?; if ((result != 0)); then echo "Build or packaging failed. Incomplete output retained at: $stage" >&2; fi' EXIT
exec > >(tee "$stage/build.log") 2>&1

snapshot() {
    local destination=$1
    mkdir -p "$destination"
    "$repo_tool" manifest -r -o "$destination/source-lock.xml"
    "$repo_tool" forall -e -c '
        state=$(git status --porcelain=v1 --untracked-files=all) || exit
        if [ -n "$state" ]; then
            printf "project %s\n%s\n" "$REPO_PATH" "$state"
        fi
    ' > "$destination/source-status.txt"
    "$repo_tool" forall -e -c '
        if ! git diff --quiet HEAD --; then
            printf "project %s\n" "$REPO_PATH"
            git diff --binary HEAD -- || exit
        fi
    ' > "$destination/source-changes.patch"
    "$repo_tool" forall -e -c '
        printf "project %s\n" "$REPO_PATH"
        git ls-files --others --exclude-standard -z | xargs -0 -r sha256sum --
    ' > "$destination/untracked-sha256.txt"
}

snapshot "$stage/source-before"
if [[ $release_type == OFFICIAL && -s $stage/source-before/source-status.txt ]]; then
    fail "Official builds require clean repositories; see $stage/source-before/source-status.txt"
fi

source build/envsetup.sh
breakfast gsi_arkui_arm64 userdebug
[[ $TARGET_PRODUCT == lineage_gsi_arkui_arm64 ]] || fail 'Unexpected product selected'
product_out=$(get_abs_build_var PRODUCT_OUT)
product_files=$(get_abs_build_var TARGET_OUT_PRODUCT)
system_ext_files=$(get_abs_build_var TARGET_OUT_SYSTEM_EXT)
[[ $(get_build_var TARGET_ARCH) == arm64 ]] || fail 'Expected ARM64'
[[ $(get_build_var BUILDING_GSI) == true ]] || fail 'GSI configuration is not active'
[[ $(get_build_var TARGET_COPY_OUT_PRODUCT) == system/product ]] || fail 'Product must be inside system'
[[ $(get_build_var TARGET_COPY_OUT_SYSTEM_EXT) == system/system_ext ]] || fail 'System_ext must be inside system'
filesystem=$(get_build_var BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE)
[[ $filesystem == ext4 ]] || fail 'Expected an ext4 system image'
device=$(get_build_var TARGET_DEVICE)
default_certificate=$(get_build_var PRODUCT_DEFAULT_DEV_CERTIFICATE)

m -j"$jobs" systemimage
[[ -s $product_out/system.img ]] || fail 'systemimage returned without system.img'
snapshot "$stage/source-after"
for record in source-lock.xml source-status.txt source-changes.patch untracked-sha256.txt; do
    cmp -s "$stage/source-before/$record" "$stage/source-after/$record" ||
        fail "Source changed during the build: $record; rebuild without concurrent edits or sync"
done

mkdir "$stage/properties"
cp "$product_out/system/build.prop" "$stage/properties/system.build.prop"
cp "$product_files/etc/build.prop" "$stage/properties/product.build.prop"
cp "$system_ext_files/etc/build.prop" "$stage/properties/system_ext.build.prop"
grep -Fqx 'ro.arkui.gsi=true' "$stage/properties/product.build.prop" || fail 'Image is not an ArkUI GSI'
grep -Fqx 'ro.arkui.gsi.variant=vanilla' "$stage/properties/product.build.prop" || fail 'Unexpected GSI variant'
grep -Fqx "ro.lineage.releasetype=$release_type" "$stage/properties/product.build.prop" || fail 'Release type mismatch'

version=$(awk -F= '$1 == "ro.lineage.version" { print $2; exit }' "$stage/properties/product.build.prop")
[[ $version =~ ^[A-Za-z0-9._-]+$ ]] || fail 'Missing or unsafe ROM version'
build_id="ArkUI-GSI-arm64-vanilla-$version-$(date -u +%Y%m%dT%H%M%SZ)"
image_name="$build_id.img"
raw_hash=$(sha256sum "$product_out/system.img")
raw_hash=${raw_hash%% *}
printf '%s  %s\n' "$raw_hash" "$image_name" > "$stage/IMAGE.sha256"
xz -T1 -6 --check=crc64 -c "$product_out/system.img" > "$stage/$image_name.xz"
packed_hash=$(xz -dc "$stage/$image_name.xz" | sha256sum)
[[ ${packed_hash%% *} == "$raw_hash" ]] || fail 'Compressed image does not match the original image hash'

source_state=clean
[[ ! -s $stage/source-before/source-status.txt ]] || source_state=dirty
cat > "$stage/build-info.txt" <<EOF
format_version=1
product=$TARGET_PRODUCT
device=$device
target_release=$TARGET_RELEASE
build_variant=$TARGET_BUILD_VARIANT
release_type=$release_type
rom_version=$version
architecture=arm64
flavor=vanilla
filesystem=$filesystem
system_image_bytes=$(stat -c %s "$product_out/system.img")
system_image_sha256=$raw_hash
source_state=$source_state
default_app_certificate=$default_certificate
build_success=true
boot_verified=false
hardware_validation=not_performed
EOF
cp "$source_dir/vendor/lineage/LICENSE" "$stage/LICENSE.vendor-lineage"
(
    cd "$stage"
    sha256sum "$image_name.xz" IMAGE.sha256 build-info.txt LICENSE.vendor-lineage \
        properties/*.prop source-before/* source-after/* > SHA256SUMS
)
[[ ! -e $artifacts_dir/$build_id ]] || fail 'Artifact destination already exists'
mv -T -- "$stage" "$artifacts_dir/$build_id"
trap - EXIT
echo "GSI build and packaging complete: $artifacts_dir/$build_id"
echo 'Boot and device compatibility remain unverified. No release was published.'
