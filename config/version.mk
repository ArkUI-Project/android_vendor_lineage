PRODUCT_VERSION_MAJOR = 23
PRODUCT_VERSION_MINOR = 2
# Allow the build launcher to select the ArkUI version for this invocation.
ARKUI_VERSION ?= 1.0

# Kati removes BUILD_NUMBER from its environment; the launcher supplies this
# copy. Native builds use the same files as ro.build.version.incremental.
ARKUI_SOURCE_BUILD_NUMBER := $(shell cat $(SOONG_OUT_DIR)/build_number.txt 2>/dev/null)
ARKUI_BUILD_NUMBER ?= $(if $(filter eng.%,$(ARKUI_SOURCE_BUILD_NUMBER)),$(shell cat $(BUILD_DATETIME_FILE) 2>/dev/null),$(ARKUI_SOURCE_BUILD_NUMBER))

# This source tree is maintained by the ArkUI Project. Explicit release types still apply.
ifeq ($(strip $(LINEAGE_BUILDTYPE)),)
    LINEAGE_BUILDTYPE := OFFICIAL
endif

# Build provenance and official update channels are separate properties.
ifneq ($(words $(LINEAGE_BUILDTYPE)),1)
    $(error ArkUI release type must contain exactly one value)
endif
ifeq ($(filter OFFICIAL UNOFFICIAL,$(LINEAGE_BUILDTYPE)),)
    $(error Unsupported ArkUI release type: $(LINEAGE_BUILDTYPE). Use OFFICIAL or UNOFFICIAL)
endif

ifeq ($(LINEAGE_BUILDTYPE),OFFICIAL)
    ARKUI_CHANNEL ?= stable
    ifneq ($(words $(ARKUI_CHANNEL)),1)
        $(error Official ArkUI channel must contain exactly one value)
    endif
    ifeq ($(filter stable beta alpha,$(ARKUI_CHANNEL)),)
        $(error Unsupported official ArkUI channel: $(ARKUI_CHANNEL). Use stable, beta or alpha)
    endif
    PRODUCT_PRODUCT_PROPERTIES += org.arkui.channel=$(ARKUI_CHANNEL)
    ifeq ($(ARKUI_CHANNEL),stable)
        ifneq ($(strip $(ARKUI_CHANNEL_NUMBER)),)
            $(error Stable must not set ARKUI_CHANNEL_NUMBER)
        endif
        ARKUI_CHANNEL_LABEL := Stable
    else
        ARKUI_CHANNEL_NUMBER ?= 1
        ARKUI_NUMBER_REMAINDER := $(ARKUI_CHANNEL_NUMBER)
        $(foreach digit,0 1 2 3 4 5 6 7 8 9,$(eval ARKUI_NUMBER_REMAINDER := $(subst $(digit),,$(ARKUI_NUMBER_REMAINDER))))
        ifneq ($(strip $(ARKUI_NUMBER_REMAINDER)),)
            $(error ARKUI_CHANNEL_NUMBER must be a positive integer)
        endif
        ifeq ($(strip $(ARKUI_CHANNEL_NUMBER)),)
            $(error ARKUI_CHANNEL_NUMBER must not be empty)
        endif
        ifneq ($(filter 0%,$(ARKUI_CHANNEL_NUMBER)),)
            $(error ARKUI_CHANNEL_NUMBER must not start with zero)
        endif
        ifneq ($(shell test $(ARKUI_CHANNEL_NUMBER) -le 2147483647 && echo valid),valid)
            $(error ARKUI_CHANNEL_NUMBER exceeds 2147483647)
        endif
        PRODUCT_PRODUCT_PROPERTIES += org.arkui.channel.number=$(ARKUI_CHANNEL_NUMBER)
        ARKUI_CHANNEL_LABEL := $(if $(filter beta,$(ARKUI_CHANNEL)),Beta,Alpha)$(ARKUI_CHANNEL_NUMBER)
    endif
else
    ifneq ($(strip $(ARKUI_CHANNEL)),)
        $(error UNOFFICIAL builds must not set ARKUI_CHANNEL)
    endif
    ifneq ($(strip $(ARKUI_CHANNEL_NUMBER)),)
        $(error UNOFFICIAL builds must not set ARKUI_CHANNEL_NUMBER)
    endif
    ARKUI_CHANNEL_LABEL := None
endif

# Internal version
LINEAGE_VERSION := ArkUI-$(ARKUI_VERSION)-$(LINEAGE_BUILDTYPE)-$(ARKUI_CHANNEL_LABEL)-$(ARKUI_BUILD_NUMBER)

# Display version
LINEAGE_DISPLAY_VERSION := $(LINEAGE_VERSION)

# LineageOS version properties
PRODUCT_PRODUCT_PROPERTIES += \
    ro.arkui.version=$(ARKUI_VERSION) \
    ro.lineage.version=$(LINEAGE_VERSION) \
    ro.lineage.display.version=$(LINEAGE_DISPLAY_VERSION) \
    org.arkui.build.version=$(ARKUI_VERSION) \
    org.arkui.releasetype=$(LINEAGE_BUILDTYPE)
