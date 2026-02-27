.PHONY: ffi header xcode build clean update-core

# Build Rust FFI static library
ffi:
	cd devcap-ffi && cargo build --release

# Generate C header (happens automatically during cargo build via build.rs)
header: ffi

# Generate Xcode project from project.yml
xcode: header
	xcodegen generate

# Build the macOS app via xcodebuild
build: xcode
	xcodebuild -project DevcapApp.xcodeproj -scheme DevcapApp -configuration Release build

# Update devcap-core to latest upstream version, rebuild FFI + header
update-core:
	cd devcap-ffi && cargo update -p devcap-core
	@echo "Updated devcap-core to:"
	@cd devcap-ffi && cargo tree -p devcap-core --depth 0
	$(MAKE) ffi

clean:
	cd devcap-ffi && cargo clean
	rm -rf DerivedData build
