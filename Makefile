export TARGET = iphone:clang:16.5:13.0
export SDK_PATH = $(THEOS)/sdks/iPhoneOS16.5.sdk/
export SYSROOT = $(SDK_PATH)
export ARCHS = arm64

export libcolorpicker_ARCHS = arm64
# Tweaks/Alderis/Makefile assigns its own Alderis_XCODEFLAGS (and lcpshim its own
# libcolorpicker_LDFLAGS), which win over anything exported from here, so Alderis
# settings ride on Alderis_XCODEOPTS, which it leaves alone. Its project targets
# iOS 12.0, below Xcode 27's floor of 15.0; this drops Alderis, and with it
# iSponsorBlock, on iOS 13-14 — only reachable with a years-old YouTube IPA.
export Alderis_XCODEOPTS = LD_DYLIB_INSTALL_NAME=@rpath/Alderis.framework/Alderis IPHONEOS_DEPLOYMENT_TARGET=15.0
export ADDITIONAL_CFLAGS = -I$(THEOS_PROJECT_DIR)/Headers

ifeq ($(ROOTLESS),1)
THEOS_PACKAGE_SCHEME=rootless
endif

INSTALL_TARGET_PROCESSES = YouTube

include $(THEOS)/makefiles/common.mk

# Optional tweaks (enabled by default, disable with ENABLE_<NAME>=0)
ENABLE_ISPONSORBLOCK ?= 1
ENABLE_DONTEATMYCONTENT ?= 1
ENABLE_YOUCHOOSEQUALITY ?= 1
ENABLE_NATIVESHARE ?= 1
ENABLE_YTMINIMALUI ?= 1

ifeq ($(ENABLE_ISPONSORBLOCK),1)
SUBPROJECTS += Tweaks/Alderis Tweaks/iSponsorBlock
endif

ifeq ($(ENABLE_DONTEATMYCONTENT),1)
SUBPROJECTS += Tweaks/DontEatMyContent
endif

ifeq ($(ENABLE_YOUCHOOSEQUALITY),1)
SUBPROJECTS += Tweaks/YouChooseQuality
endif

ifeq ($(ENABLE_NATIVESHARE),1)
SUBPROJECTS += Tweaks/youtube-native-share
endif

# Interface tweaks written for this fork (see Tweaks/YTMinimalUI/README.md).
# Must come last: it folds the settings of the tweaks above into one section,
# and relies on their hooks already being installed.
ifeq ($(ENABLE_YTMINIMALUI),1)
SUBPROJECTS += Tweaks/YTMinimalUI
endif

include $(THEOS_MAKE_PATH)/aggregate.mk

TWEAK_NAME = YTMinimal

YTMinimal_FILES = SideloadFixes.xm Tweaks/IAmYouTube/Tweak.x
YTMinimal_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
