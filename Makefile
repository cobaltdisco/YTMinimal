export TARGET = iphone:clang:16.5:13.0
export SDK_PATH = $(THEOS)/sdks/iPhoneOS16.5.sdk/
export SYSROOT = $(SDK_PATH)
export ARCHS = arm64

export libcolorpicker_ARCHS = arm64
export Alderis_XCODEOPTS = LD_DYLIB_INSTALL_NAME=@rpath/Alderis.framework/Alderis
export Alderis_XCODEFLAGS = DYLIB_INSTALL_NAME_BASE=/Library/Frameworks BUILD_LIBRARY_FOR_DISTRIBUTION=YES ARCHS="$(ARCHS)"
export libcolorpicker_LDFLAGS = -F$(TARGET_PRIVATE_FRAMEWORK_PATH) -install_name @rpath/libcolorpicker.dylib
export ADDITIONAL_CFLAGS = -I$(THEOS_PROJECT_DIR)/Headers

# The iSponsorBlock subproject (Tweaks/iSponsorBlock) uses Alderis's color picker.
# Override its EMBED_FRAMEWORKS from here so the Alderis.framework built by our
# Alderis subproject gets bundled into the staged deb.
export iSponsorBlock_EMBED_FRAMEWORKS = $(_THEOS_LOCAL_DATA_DIR)/$(THEOS_OBJ_DIR_NAME)/install_Alderis.xcarchive/Products/var/jb/Library/Frameworks/Alderis.framework

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
