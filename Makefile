.PHONY: ffi header xcode build clean

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

clean:
	cd devcap-ffi && cargo clean
	rm -rf DerivedData build
