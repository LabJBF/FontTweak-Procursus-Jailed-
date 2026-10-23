include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FontTweakPrefs

FontTweakPrefs_FILES = FontTweakListController.m
FontTweakPrefs_INSTALL_PATH = /Library/PreferenceBundles
FontTweakPrefs_FRAMEWORKS = UIKit Foundation
FontTweakPrefs_CFLAGS = -fobjc-arc
FontTweakPrefs_LDFLAGS += -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
