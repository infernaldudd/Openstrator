#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE="$ROOT/Package.swift"
BUILDER="$ROOT/BUILD_OPENSTRATOR.command"

grep -q 'name: "OpenstratorCoreSelfTest"' "$PACKAGE" || {
  echo 'FAIL: Package.swift does not define OpenstratorCoreSelfTest.' >&2
  exit 1
}
grep -q 'OpenstratorCoreSelfTest' "$BUILDER" || {
  echo 'FAIL: builder does not run OpenstratorCoreSelfTest.' >&2
  exit 1
}
if grep -q '"\$SWIFT" test' "$BUILDER"; then
  echo 'FAIL: builder still makes XCTest-backed swift test mandatory.' >&2
  exit 1
fi
printf 'PASS: builder uses framework-free core self-test instead of mandatory XCTest.\n'
