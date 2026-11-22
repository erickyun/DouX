TARGET := iphone:clang:latest:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES = TikTok

# A standalone UI-only tweak: no DouX source, networking hooks, Safari hooks,
# authentication handling, diagnostics or other TikTok modifications.
LOGOS_DEFAULT_GENERATOR = internal
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CleanIdentity
CleanIdentity_FILES = clean_identity/identity.x clean_identity/CleanIdentityPrefs.m
CleanIdentity_CFLAGS = -fobjc-arc -Wno-unused-function -Wno-deprecated-declarations -Wno-nullability-completeness
CleanIdentity_FRAMEWORKS = Foundation UIKit QuartzCore CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
