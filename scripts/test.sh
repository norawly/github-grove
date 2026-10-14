#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sdk_probe="$(/usr/bin/xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
if [[ ! -d "$sdk_probe" && -d /Library/Developer/CommandLineTools ]]; then
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
compiler="$(/usr/bin/xcrun --find swiftc)"
sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
mkdir -p build/checks
"$compiler" -swift-version 5 -sdk "$sdk" -emit-library -static -emit-module -module-name GroveCore Sources/GroveCore/*.swift \
    -emit-module-path build/checks/GroveCore.swiftmodule -o build/checks/libGroveCore.a
"$compiler" -swift-version 5 -sdk "$sdk" -I build/checks -L build/checks -lGroveCore Tests/GroveCoreTests/*.swift -o build/checks/GroveChecks
build/checks/GroveChecks
