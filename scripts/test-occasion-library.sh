#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /private/tmp/touchpoint-occasion-library.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
# Compile the real data layer on macOS, using only the shared palette from the iOS UI file.
{
    echo 'import SwiftUI'
    sed -n '/^enum TouchPointColor {/,/^}/p' TouchPoint/DesignSystem/TouchPointDesign.swift
} > "$test_dir/Palette.swift"
xcrun swiftc -module-cache-path "$test_dir/cache" \
    TouchPoint/Models/AppModels.swift \
    TouchPoint/Preferences/AppPreferences.swift \
    TouchPoint/Data/AppStore.swift \
    "$test_dir/Palette.swift" Tests/OccasionLibraryRegression.swift \
    -o "$test_dir/tests"
"$test_dir/tests"
