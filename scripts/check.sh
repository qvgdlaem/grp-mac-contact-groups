#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
CACHE="${TMPDIR:-/tmp}/grp-clang-cache"
swiftc -module-cache-path "$CACHE" Sources/GRP/DeleteGuard.swift \
    Tests/GRPTests/DeleteGuardTests.swift -o .build/DeleteGuardChecks
.build/DeleteGuardChecks
SOURCES=(
    Sources/GRP/DeleteGuard.swift
    Sources/GRP/ContactData.swift
    Sources/GRP/ContactsAutomation.swift
    Sources/GRP/ContactService.swift
    Sources/GRP/Model.swift
    Sources/GRP/MembershipUpdate.swift
    Sources/GRP/ContactSorting.swift
    Sources/GRP/GroupColorLibrary.swift
    Sources/GRP/GroupFilter.swift
    Sources/GRP/BulkGroups.swift
)
for CHECK in FeatureChecks ConnectionChecks MembershipChecks SortingPaletteChecks GroupFilterChecks BulkGroupsChecks; do
    swiftc -module-cache-path "$CACHE" "${SOURCES[@]}" "Tests/GRPTests/$CHECK.swift" -o ".build/$CHECK"
    ".build/$CHECK"
done
