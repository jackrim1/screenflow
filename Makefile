.PHONY: build test run bundle install install-ctl clean open typecheck fix-clt

APP_NAME    = ScreenFlow
BUNDLE_DIR  = $(APP_NAME).app
INSTALL_DIR = $(HOME)/Applications
BUILD_DIR   = .build-direct
SDK         = $(shell xcrun --sdk macosx --show-sdk-path 2>/dev/null || \
                ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null | sort -V | tail -1)
TARGET      = arm64-apple-macos13.0

CORE_SRCS = \
  Sources/ScreenFlowCore/Screenshot.swift \
  Sources/ScreenFlowCore/ScreenshotStore.swift \
  Sources/ScreenFlowCore/ScreenshotWatcher.swift \
  Sources/ScreenFlowCore/ClipboardManager.swift

APP_SRCS = \
  Sources/ScreenFlowApp/ScreenFlowApp.swift \
  Sources/ScreenFlowApp/AppDelegate.swift \
  Sources/ScreenFlowApp/PopoverView.swift \
  Sources/ScreenFlowApp/GalleryWindowController.swift \
  Sources/ScreenFlowApp/GalleryView.swift \
  Sources/ScreenFlowApp/FloatingThumbnailPanel.swift

CTL_SRCS = Sources/screenflowctl/main.swift

SWIFTC_BASE = swiftc -sdk $(SDK) -target $(TARGET) -num-threads 1

# ── Build (no Xcode.app needed) ────────────────────────────────────────────────

build: $(BUILD_DIR)/ScreenFlow $(BUILD_DIR)/screenflowctl

$(BUILD_DIR)/libScreenFlowCore.a: $(CORE_SRCS)
	@mkdir -p $(BUILD_DIR)
	@echo "Compiling ScreenFlowCore…"
	$(SWIFTC_BASE) $(CORE_SRCS) \
	  -parse-as-library -module-name ScreenFlowCore \
	  -emit-module -emit-module-path $(BUILD_DIR)/ScreenFlowCore.swiftmodule \
	  -emit-library -static \
	  -o $(BUILD_DIR)/libScreenFlowCore.a
	@echo "✓ ScreenFlowCore"

$(BUILD_DIR)/ScreenFlow: $(BUILD_DIR)/libScreenFlowCore.a $(APP_SRCS)
	@echo "Compiling ScreenFlowApp…"
	$(SWIFTC_BASE) $(APP_SRCS) \
	  -I $(BUILD_DIR) -L $(BUILD_DIR) -lScreenFlowCore \
	  -parse-as-library -module-name ScreenFlowApp \
	  -o $(BUILD_DIR)/ScreenFlow
	@echo "✓ ScreenFlowApp"

$(BUILD_DIR)/screenflowctl: $(BUILD_DIR)/libScreenFlowCore.a $(CTL_SRCS)
	@echo "Compiling screenflowctl…"
	$(SWIFTC_BASE) $(CTL_SRCS) \
	  -I $(BUILD_DIR) -L $(BUILD_DIR) -lScreenFlowCore \
	  -module-name screenflowctl \
	  -o $(BUILD_DIR)/screenflowctl
	@echo "✓ screenflowctl"

# ── Test ───────────────────────────────────────────────────────────────────────
# Requires Xcode.app (XCTest is not shipped with Command Line Tools).
# To install: https://apps.apple.com/app/xcode/id497799835

test:
	swift test

test-verbose:
	swift test --verbose

# ── Typecheck (no Xcode needed) ────────────────────────────────────────────────

typecheck:
	@echo "Type-checking ScreenFlowCore…"
	@mkdir -p /tmp/sfcheck
	@swiftc -sdk $(SDK) -target $(TARGET) $(CORE_SRCS) \
	  -parse-as-library -module-name ScreenFlowCore \
	  -emit-module -emit-module-path /tmp/sfcheck/ScreenFlowCore.swiftmodule \
	  -emit-object -num-threads 1 -o /tmp/sfcheck/ScreenFlowCore.o
	@echo "✓ ScreenFlowCore"
	@swiftc -sdk $(SDK) -target $(TARGET) -I /tmp/sfcheck $(APP_SRCS) \
	  -parse-as-library -module-name ScreenFlowApp -typecheck
	@echo "✓ ScreenFlowApp"
	@swiftc -sdk $(SDK) -target $(TARGET) -I /tmp/sfcheck $(CTL_SRCS) \
	  -module-name screenflowctl -typecheck
	@echo "✓ screenflowctl"
	@rm -rf /tmp/sfcheck
	@echo "All files type-check cleanly."

# ── Bundle ─────────────────────────────────────────────────────────────────────

bundle: build
	@echo "Creating $(BUNDLE_DIR)…"
	@rm -rf $(BUNDLE_DIR)
	@mkdir -p $(BUNDLE_DIR)/Contents/MacOS
	@mkdir -p $(BUNDLE_DIR)/Contents/Resources
	@cp $(BUILD_DIR)/ScreenFlow $(BUNDLE_DIR)/Contents/MacOS/$(APP_NAME)
	@cp Sources/ScreenFlowApp/Resources/Info.plist $(BUNDLE_DIR)/Contents/Info.plist
	@echo "✓ $(BUNDLE_DIR) ready"

install: bundle
	@mkdir -p $(INSTALL_DIR)
	@rm -rf $(INSTALL_DIR)/$(BUNDLE_DIR)
	@cp -r $(BUNDLE_DIR) $(INSTALL_DIR)/
	@echo "✓ Installed to $(INSTALL_DIR)/$(BUNDLE_DIR)"

install-ctl: build
	sudo cp $(BUILD_DIR)/screenflowctl /usr/local/bin/screenflowctl
	@echo "✓ screenflowctl → /usr/local/bin/screenflowctl"

open: install
	open $(INSTALL_DIR)/$(BUNDLE_DIR)

run: build
	$(BUILD_DIR)/ScreenFlow

# ── One-time CLT fix (only needed for `make test` / `swift test`) ──────────────

fix-clt:
	@echo "Step 1/2: Creating missing Platforms directory…"
	sudo mkdir -p /Library/Developer/CommandLineTools/Platforms/MacOSX.platform/Developer/SDKs
	sudo ln -sf /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
	  /Library/Developer/CommandLineTools/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
	@echo "Step 2/2: Patching SDKSettings.plist files…"
	@for sdk in /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk; do \
	  plist="$$sdk/SDKSettings.plist"; \
	  if ! /usr/libexec/PlistBuddy -c "Print :PlatformPath" "$$plist" >/dev/null 2>&1; then \
	    sudo /usr/libexec/PlistBuddy -c \
	      "Add :PlatformPath string /Library/Developer/CommandLineTools/Platforms/MacOSX.platform" \
	      "$$plist" && echo "  patched $$plist"; \
	  else \
	    echo "  already patched: $$plist"; \
	  fi; \
	done
	@echo "✓ Done. 'make test' still needs Xcode.app for XCTest.framework."

# ── Clean ──────────────────────────────────────────────────────────────────────

clean:
	@rm -rf $(BUILD_DIR) $(BUNDLE_DIR)
	@echo "✓ Cleaned"
