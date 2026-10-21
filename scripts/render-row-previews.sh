#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
SOURCES=()
for SOURCE in Sources/GRP/*.swift; do
    if [[ "$SOURCE" != "Sources/GRP/App.swift" ]]; then SOURCES+=("$SOURCE"); fi
done
swiftc -module-cache-path "${TMPDIR:-/tmp}/grp-clang-cache" \
    "${SOURCES[@]}" scripts/render-row-previews.swift -o .build/RowPreviews
.build/RowPreviews "${1:-dist/previews}" "${2:-}"
