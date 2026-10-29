.PHONY: project check lint verify icons release

ARCH := $(shell uname -m)
SDK := $(shell xcrun --show-sdk-path)
BIN := $(shell cd Packages/DevSessionsCore && swift build --show-bin-path)

project:
	xcodegen generate

check:
	cd Packages/DevSessionsCore && swift run DevSessionsCoreChecks

lint:
	plutil -lint Config/*.plist Config/*.entitlements

verify: check lint
	xcrun swiftc -typecheck -swift-version 5 -target $(ARCH)-apple-macos14.0 -sdk "$(SDK)" -I "$(BIN)" -parse-as-library DevSessions/*.swift
	xcrun swiftc -typecheck -swift-version 5 -target $(ARCH)-apple-macos14.0 -sdk "$(SDK)" -I "$(BIN)" -parse-as-library -application-extension DevSessionsWidget/*.swift
	@echo "Core checks, plist lint, and Swift type checks passed."
	@echo "Use Xcode or xcodebuild for the signed app/widget build."

icons:
	swift scripts/generate_app_icon.swift

release: project
	./scripts/package_release.sh
