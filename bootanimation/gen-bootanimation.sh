#!/bin/bash -e
#
# Copyright (C) 2016 The CyanogenMod Project
#               2017-2024 The LineageOS Project
#               2026 The ArkUI Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -u -o pipefail

PARAM_GENDIR=$1
PARAM_LOGO=$2
PARAM_RENDERER=$3
PARAM_DESC_TXT=$4
PARAM_MOGRIFY=$5
PARAM_SOONG_ZIP=$6
PARAM_TARGET_SCREEN_HEIGHT=$7
PARAM_TARGET_SCREEN_WIDTH=$8
PARAM_TARGET_BOOTANIMATION_HALF_RES=$9

if ! [[ "$PARAM_TARGET_SCREEN_HEIGHT" =~ ^[0-9]+$ &&
        "$PARAM_TARGET_SCREEN_WIDTH" =~ ^[0-9]+$ ]] ||
        (( PARAM_TARGET_SCREEN_HEIGHT < 6 || PARAM_TARGET_SCREEN_WIDTH < 6 )); then
    echo "Boot animation requires positive screen dimensions of at least 6 pixels" >&2
    exit 1
fi

IMAGESCALEWIDTH=$PARAM_TARGET_SCREEN_WIDTH
if (( PARAM_TARGET_SCREEN_HEIGHT < IMAGESCALEWIDTH )); then
    IMAGESCALEWIDTH=$PARAM_TARGET_SCREEN_HEIGHT
fi
IMAGESCALEHEIGHT=$((IMAGESCALEWIDTH / 3))
IMAGEWIDTH=$IMAGESCALEWIDTH
if [[ "$PARAM_TARGET_BOOTANIMATION_HALF_RES" == "true" ]]; then
    IMAGEWIDTH=$((IMAGEWIDTH / 2))
fi
IMAGEHEIGHT=$((IMAGEWIDTH / 3))

# Keep the frame and letterbox backgrounds pure black for every boot theme.
INTERMEDIATES="$PARAM_GENDIR/intermediates/black"
mkdir -p "$INTERMEDIATES/part0" "$INTERMEDIATES/part1"
rm -f "$INTERMEDIATES"/part*/*.mvg "$INTERMEDIATES"/part*/*.png
awk -v destination="$INTERMEDIATES" \
    -v frame_width="$IMAGEWIDTH" -v frame_height="$IMAGEHEIGHT" \
    -f "$PARAM_RENDERER" "$PARAM_LOGO"

FRAMES=("$INTERMEDIATES"/part*/*.mvg)
MAGICK_THREAD_LIMIT=1 "$PARAM_MOGRIFY" -size "${IMAGEWIDTH}x${IMAGEHEIGHT}" \
    -format png -depth 8 -strip -define png:color-type=2 "${FRAMES[@]/#/MVG:}"
rm "${FRAMES[@]}"

echo "$IMAGESCALEWIDTH $IMAGESCALEHEIGHT 30" > "$INTERMEDIATES/desc.txt"
cat "$PARAM_DESC_TXT" >> "$INTERMEDIATES/desc.txt"

# BootAnimation maps uncompressed ZIP entries directly into memory.
"$PARAM_SOONG_ZIP" -L 0 -o "$PARAM_GENDIR/bootanimation.zip" \
    -C "$INTERMEDIATES" -D "$INTERMEDIATES"
