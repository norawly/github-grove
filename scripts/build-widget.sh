#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sdk_probe="$(/usr/bin/xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
if [[ ! -d "$sdk_probe" && -d /Library/Developer/CommandLineTools ]]; then export DEVELOPER_DIR=/Library/Developer/CommandLineTools; fi
compiler="$(/usr/bin/xcrun --find swiftc)"
sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
app="${1:-dist/Grove.app}"
extension="$app/Contents/PlugIns/GroveWidget.appex"
for arch in arm64 x86_64; do
    mkdir -p "build/widget-$arch"
    "$compiler" -swift-version 5 -O -whole-module-optimization -sdk "$sdk" -target "$arch-apple-macos14.0" \
        -emit-library -static -emit-module -module-name GroveCore Sources/GroveCore/*.swift \
        -emit-module-path "build/widget-$arch/GroveCore.swiftmodule" -o "build/widget-$arch/libGroveCore.a"
    "$compiler" -swift-version 5 -O -parse-as-library -application-extension -sdk "$sdk" -target "$arch-apple-macos14.0" \
        -module-name GroveWidget -I "build/widget-$arch" -L "build/widget-$arch" -lGroveCore \
        Sources/GroveWidget/*.swift -framework WidgetKit -framework SwiftUI -framework Foundation \
        -Xlinker -e -Xlinker _NSExtensionMain -o "build/widget-$arch/GroveWidget"
done
mkdir -p "$extension/Contents/MacOS"
/usr/bin/lipo -create build/widget-arm64/GroveWidget build/widget-x86_64/GroveWidget -output "$extension/Contents/MacOS/GroveWidget"
cp Resources/Widget-Info.plist "$extension/Contents/Info.plist"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    /usr/bin/codesign --force --timestamp --options runtime --entitlements Resources/Widget.entitlements --sign "$SIGNING_IDENTITY" "$extension"
    /usr/bin/codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$app"
else
    /usr/bin/codesign --force --entitlements Resources/Widget.entitlements --sign - "$extension"
    /usr/bin/codesign --force --sign - "$app"
    printf 'Widget compiled with an ad-hoc signature. Native gallery eligibility is NOT confirmed.\n'
fi
/usr/bin/codesign --verify --strict --deep "$app"
