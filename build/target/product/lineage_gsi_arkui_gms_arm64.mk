# Copyright (C) 2026 The ArkUI Project
# SPDX-License-Identifier: Apache-2.0

# MindTheGapps is a separate repo project at vendor/gapps.
ifeq ($(wildcard vendor/gapps/arm64/arm64-vendor.mk),)
$(error ArkUI GMS requires vendor/gapps; run arkui-builder with --prepare-dependencies)
endif

# Use the explicit MindTheGapps integration below rather than partner_gms.
WITH_GMS := false
$(call inherit-product, vendor/lineage/build/target/product/lineage_gsi_arkui_common.mk)
$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)

PRODUCT_NAME := lineage_gsi_arkui_gms_arm64
PRODUCT_MODEL := ArkUI GSI ARM64 GMS
PRODUCT_PRODUCT_PROPERTIES += ro.arkui.gsi.variant=gms
