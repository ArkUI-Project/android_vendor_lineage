# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-FileCopyrightText: 2026 The ArkUI Project
# SPDX-License-Identifier: Apache-2.0

ifneq ($(LINEAGE_BUILD),)
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += vendor/lineage/sepolicy/private
endif

# Recovery
BOARD_USES_FULL_RECOVERY_IMAGE ?= true

include vendor/lineage/config/BoardConfigKernel.mk

ifeq ($(BOARD_USES_QCOM_HARDWARE),true)
    include hardware/qcom-caf/common/BoardConfigQcom.mk
endif

include vendor/lineage/config/BoardConfigSoong.mk
