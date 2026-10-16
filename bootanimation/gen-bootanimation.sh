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

# Keep full-screen logical coordinates so the relay stays near the screen bottom.
IMAGEWIDTH=$PARAM_TARGET_SCREEN_WIDTH
IMAGEHEIGHT=$PARAM_TARGET_SCREEN_HEIGHT
if [[ "$PARAM_TARGET_BOOTANIMATION_HALF_RES" == "true" ]]; then
    IMAGEWIDTH=$((IMAGEWIDTH / 2))
    IMAGEHEIGHT=$((IMAGEHEIGHT / 2))
fi

# Only these private intermediates are regenerated. Trimmed textures avoid storing
# the full-screen black margins in every frame; both boot themes remain black.
WORKDIR="$PARAM_GENDIR/intermediates"
INTERMEDIATES="$PARAM_GENDIR/intermediates/black"
LAYERS="$WORKDIR/layers"
mkdir -p "$INTERMEDIATES/part0" "$INTERMEDIATES/part1" "$LAYERS"
rm -f "$INTERMEDIATES"/part{0,1}/*.mvg "$INTERMEDIATES"/part{0,1}/*.png \
    "$INTERMEDIATES"/part{0,1}/trim.txt "$LAYERS"/*.mvg "$LAYERS"/*.png
: > "$WORKDIR/geometry.tsv"
: > "$WORKDIR/layers.tsv"
awk -v destination="$INTERMEDIATES" \
    -v layer_destination="$LAYERS" -v plan_directory="$WORKDIR" \
    -v frame_width="$IMAGEWIDTH" -v frame_height="$IMAGEHEIGHT" \
    -v logical_width="$PARAM_TARGET_SCREEN_WIDTH" \
    -v logical_height="$PARAM_TARGET_SCREEN_HEIGHT" \
    -f "$PARAM_RENDERER" "$PARAM_LOGO"

# Gaussian blur is applied to transparent glyph layers before compositing, keeping
# the background and bottom relay crisp. No new host renderer is required.
while IFS=$'\t' read -r LAYER LAYERWIDTH LAYERHEIGHT SIGMA; do
    MAGICK_THREAD_LIMIT=1 "$PARAM_MOGRIFY" -background none \
        -size "${LAYERWIDTH}x${LAYERHEIGHT}" -format png -depth 8 \
        -channel RGBA -blur "0,${SIGMA}" +channel -strip \
        -define png:color-type=6 "MVG:$LAYER"
done < "$WORKDIR/layers.tsv"

while IFS=$'\t' read -r PART PARTWIDTH PARTHEIGHT; do
    FRAMES=("$INTERMEDIATES/$PART/"*.mvg)
    MAGICK_THREAD_LIMIT=1 "$PARAM_MOGRIFY" -size "${PARTWIDTH}x${PARTHEIGHT}" \
        -format png -depth 8 -strip -define png:color-type=2 "${FRAMES[@]/#/MVG:}"
    rm "${FRAMES[@]}"
done < "$WORKDIR/geometry.tsv"
rm -f "$LAYERS"/*.mvg "$LAYERS"/*.png

echo "$PARAM_TARGET_SCREEN_WIDTH $PARAM_TARGET_SCREEN_HEIGHT 50" > "$INTERMEDIATES/desc.txt"
cat "$PARAM_DESC_TXT" >> "$INTERMEDIATES/desc.txt"

# BootAnimation maps uncompressed ZIP entries directly into memory.
"$PARAM_SOONG_ZIP" -L 0 -o "$PARAM_GENDIR/bootanimation.zip" \
    -C "$INTERMEDIATES" -D "$INTERMEDIATES"
