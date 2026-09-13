#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /private/tmp/touchpoint-person-contact.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
{
    echo 'import SwiftUI'
    sed -n '/^enum TouchPointColor {/,/^}/p' TouchPoint/DesignSystem/TouchPointDesign.swift
} > "$test_dir/Palette.swift"
xcrun swiftc -module-cache-path "$test_dir/cache" \
    TouchPoint/Models/AppModels.swift \
    TouchPoint/Preferences/AppPreferences.swift \
    TouchPoint/Data/AppStore.swift \
    "$test_dir/Palette.swift" Tests/PersonContactRegression.swift \
    -o "$test_dir/tests"
"$test_dir/tests"
