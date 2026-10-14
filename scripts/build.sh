#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Use the installed Command Line Tools if Xcode cannot currently run.
sdk_probe="$(/usr/bin/xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
if [[ ! -d "$sdk_probe" && -d /Library/Developer/CommandLineTools ]]; then
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
compiler="$(/usr/bin/xcrun --find swiftc)"
sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
app="dist/Grove.app"
mkdir -p build dist

for arch in arm64 x86_64; do
    directory="build/$arch"
    mkdir -p "$directory"
    "$compiler" -swift-version 5 -O -whole-module-optimization -sdk "$sdk" -target "$arch-apple-macos13.0" \
        -emit-library -static -emit-module -module-name GroveCore Sources/GroveCore/*.swift \
        -emit-module-path "$directory/GroveCore.swiftmodule" -o "$directory/libGroveCore.a"
    "$compiler" -swift-version 5 -O -whole-module-optimization -sdk "$sdk" -target "$arch-apple-macos13.0" \
        -module-name Grove -I "$directory" -L "$directory" -lGroveCore Sources/Grove/*.swift -o "$directory/Grove"
done

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/lipo -create build/arm64/Grove build/x86_64/Grove -output "$app/Contents/MacOS/Grove"
/usr/bin/strip -S "$app/Contents/MacOS/Grove"
cp Resources/Info.plist "$app/Contents/Info.plist"
bash scripts/make-icon.sh Resources/Grove.png "$app/Contents/Resources/Grove.icns"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app"
else
    /usr/bin/codesign --force --sign - "$app"
fi
/usr/bin/codesign --verify --strict "$app"
/usr/bin/lipo -archs "$app/Contents/MacOS/Grove"
printf 'Built %s (macOS 13+, Apple Silicon + Intel).\n' "$app"

if [[ "${1:-}" == "--package" ]]; then
    archive="dist/Grove-$version-universal.zip"
    COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --noextattr --keepParent "$app" "$archive"
    staging="build/dmg"
    mkdir -p "$staging"
    /usr/bin/ditto --norsrc --noextattr "$app" "$staging/Grove.app"
    ln -sfn /Applications "$staging/Applications"
    cp Resources/Install.txt "$staging/Start here.txt"
    /usr/bin/hdiutil create -volname Grove -srcfolder "$staging" -ov -format UDZO "dist/Grove-$version-universal.dmg"
    (cd dist && /usr/bin/shasum -a 256 "Grove-$version-universal.zip" "Grove-$version-universal.dmg" > SHA256SUMS.txt)
    printf 'Packaged Grove %s in dist/.\n' "$version"
fi
