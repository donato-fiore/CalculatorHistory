ARCHS = arm64
ifeq ($(SIM),1)
	TARGET = simulator:clang:17.2:14.0
	ARCHS += x86_64
	THEOS_PACKAGE_SCHEME =
	THEOS_PACKAGE_INSTALL_PREFIX = /opt/simject
else
	TARGET = iphone:clang:16.5:14.0
	ARCHS += arm64e
	THEOS_PACKAGE_SCHEME = rootless
endif

INSTALL_TARGET_PROCESSES = Calculator

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CalculatorHistory

CalculatorHistory_FILES = Tweak.x $(shell find . \( -path "*/.theos/*" -prune \) -o \( -name "*.m" -o -name "*.mm" -o -name "*.swift" \) -print)
CalculatorHistory_CFLAGS = -fobjc-arc
CalculatorHistory_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

deploy:: package
ifeq ($(SIM),1)
	@echo "Deploying to simulator..."
	sudo cp $(THEOS_STAGING_DIR)/$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/MobileSubstrate/DynamicLibraries/$(TWEAK_NAME).dylib /opt/simject/Library/MobileSubstrate/DynamicLibraries/$(TWEAK_NAME).dylib
	sudo cp $(THEOS_STAGING_DIR)/$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/MobileSubstrate/DynamicLibraries/$(TWEAK_NAME).plist /opt/simject/Library/MobileSubstrate/DynamicLibraries/$(TWEAK_NAME).plist

	sudo mkdir -p /opt/simject/Library/Tweak\ Support/$(TWEAK_NAME).bundle
	sudo cp -r $(THEOS_STAGING_DIR)/$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/Tweak\ Support/$(TWEAK_NAME).bundle/* /opt/simject/Library/Tweak\ Support/$(TWEAK_NAME).bundle/

	@echo "Restarting SpringBoard..."
	resim
else
	@echo "Deploying to physical device..."
	@$(MAKE) install
endif