TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OCBoost
OCBoost_FILES = Tweak.m
OCBoost_CFLAGS = -fobjc-arc -Wall -Wextra
OCBoost_FRAMEWORKS = Foundation UIKit

BUNDLE_NAME = OCBoostPrefs
OCBoostPrefs_FILES = Preferences/OCBoostRootListController.m
OCBoostPrefs_FRAMEWORKS = Foundation UIKit QuartzCore
OCBoostPrefs_PRIVATE_FRAMEWORKS = Preferences
OCBoostPrefs_RESOURCE_FILES = Preferences/Root.plist
OCBoostPrefs_INSTALL_PATH = /Library/PreferenceBundles
OCBoostPrefs_CFLAGS = -fobjc-arc -Wall -Wextra

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
