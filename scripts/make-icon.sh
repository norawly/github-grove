#!/bin/bash
set -euo pipefail
source_image="$1"
output="$2"
iconset="build/Grove.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" "$source_image" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    /usr/bin/sips -z "$retina" "$retina" "$source_image" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$iconset" -o "$output"
