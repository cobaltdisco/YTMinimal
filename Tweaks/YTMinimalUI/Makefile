ARCHS = arm64
TARGET = iphone:clang:16.5:13.0
INSTALL_TARGET_PROCESSES = YouTube

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTMinimalUI

# Tweak.xm wires up the feature groups; every feature lives in its own
# Features/<Name>.xm and is picked up automatically.
$(TWEAK_NAME)_FILES = Tweak.xm $(wildcard Features/*.xm)
$(TWEAK_NAME)_CFLAGS = -fobjc-arc \
	-DTWEAK_VERSION='"$(shell sed -n "s/^Version: //p" ../../control)"'

include $(THEOS_MAKE_PATH)/tweak.mk
