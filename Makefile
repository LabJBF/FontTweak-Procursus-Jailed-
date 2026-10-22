ifeq ($(THEOS)/makefiles/common.mk,$(wildcard $(THEOS)/makefiles/common.mk))
endif

TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += Sources/FontTweak Sources/FontTweakPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "sbreload"
