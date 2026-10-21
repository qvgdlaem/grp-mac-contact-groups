#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh --universal
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
ARCHIVE="GRP-$VERSION-universal.zip"
ditto -c -k --sequesterRsrc --keepParent dist/GRP.app "dist/$ARCHIVE"
unzip -tq "dist/$ARCHIVE"
(cd dist && shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt)
printf 'Packaged dist/%s and dist/SHA256SUMS.txt\n' "$ARCHIVE"
