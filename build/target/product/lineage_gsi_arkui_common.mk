# Copyright (C) 2026 The ArkUI Project
# SPDX-License-Identifier: Apache-2.0

# A system-only GSI has no device OTA payload for the Lineage updater.
TARGET_DISABLE_LINEAGE_UPDATER := true
GSI_FILE_SYSTEM_TYPE := ext4

# Product names retain lineage_gsi_ and _arm64 for upstream GSI rules.
$(call inherit-product, vendor/lineage/build/target/product/lineage_gsi_arm64.mk)

PRODUCT_BRAND := ArkUI
PRODUCT_MANUFACTURER := ArkUI
PRODUCT_PRODUCT_PROPERTIES += ro.arkui.gsi=true
