# Copyright (C) 2026 The ArkUI Project
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

# A system-only GSI has no device OTA payload for the Lineage updater.
TARGET_DISABLE_LINEAGE_UPDATER := true

# The official GSI profile is vanilla, including when WITH_GMS was exported.
WITH_GMS := false
GSI_FILE_SYSTEM_TYPE := ext4

# Keep the lineage_gsi_ prefix and _arm64 suffix: upstream GSI rules use them.
$(call inherit-product, vendor/lineage/build/target/product/lineage_gsi_arm64.mk)

PRODUCT_NAME := lineage_gsi_arkui_arm64
PRODUCT_BRAND := ArkUI
PRODUCT_MANUFACTURER := ArkUI
PRODUCT_MODEL := ArkUI GSI ARM64

PRODUCT_PRODUCT_PROPERTIES += \
    ro.arkui.gsi=true \
    ro.arkui.gsi.variant=vanilla
