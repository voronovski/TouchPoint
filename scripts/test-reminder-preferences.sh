#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /private/tmp/touchpoint-reminders.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
{
    echo 'import SwiftUI'
    sed -n '/^enum TouchPointColor {/,/^}/p' TouchPoint/DesignSystem/TouchPointDesign.swift
} > "$test_dir/Palette.swift"
xcrun swiftc -module-cache-path "$test_dir/cache" \
    TouchPoint/Models/AppModels.swift \
    TouchPoint/Preferences/AppPreferences.swift \
    "$test_dir/Palette.swift" Tests/ReminderPreferencesRegression.swift \
    -o "$test_dir/tests"
"$test_dir/tests"
