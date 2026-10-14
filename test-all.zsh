#!/bin/zsh
set -eu
root="${0:A:h}"
work=$(mktemp -d "${TMPDIR:-/tmp}/panda-companion-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT
zsh "$root/test.zsh"
xcrun swiftc -Onone "$root/Configuration.swift" "$root/AssistantState.swift" "$root/ConfigTests.swift" -module-cache-path "$work/cache" -o "$work/config-tests"
"$work/config-tests"
xcrun swiftc -Onone "$root/Configuration.swift" "$root/PandaCompatibility.swift" "$root/CompatibilityTests.swift" -module-cache-path "$work/cache" -o "$work/compatibility-tests"
"$work/compatibility-tests"
