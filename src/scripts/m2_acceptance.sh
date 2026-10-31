#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo '[M2 1/6] Full OpenstratorCore XCTest suite'
swift test --filter OpenstratorCoreTests

echo '[M2 2/6] Framework-free release self-test'
swift run -c release OpenstratorCoreSelfTest | tee /tmp/openstrator-m2-selftest.out
grep -q 'OpenstratorCoreSelfTest M2 final: PASS (37 checks)' /tmp/openstrator-m2-selftest.out

echo '[M2 3/6] Terminal builder must not require XCTest'
bash scripts/test_builder_core_selftest.sh
if grep -q '"$SWIFT" test' BUILD_OPENSTRATOR.command; then
  echo 'FAIL: packaging builder invokes XCTest-backed swift test.' >&2
  exit 1
fi
grep -q -- '--product Openstrator' BUILD_OPENSTRATOR.command || {
  echo 'FAIL: packaging builder must explicitly build the Openstrator product.' >&2
  exit 1
}

echo '[M2 4/6] Swift parser checks'
for f in Openstrator/*.swift Sources/OpenstratorCore/*.swift Sources/OpenstratorCore/*/*.swift Sources/OpenstratorCoreSelfTest/*.swift; do
  swiftc -frontend -parse "$f"
done

echo '[M2 5/6] Icon transparency'
python3 scripts/verify_icon_alpha.py

echo '[M2 6/6] M2 source contract checks'
grep -q 'var bezierAnchors: \[PathAnchorV6\]?' Openstrator/Models.swift
grep -q 'func penAddAnchor' Openstrator/EditorStore.swift
grep -q 'func curvatureAddAnchor' Openstrator/EditorStore.swift
grep -q 'DirectPathOverlay' Openstrator/CanvasView.swift
grep -q 'path.addCurve' Openstrator/CanvasView.swift
grep -q 'commands.append("C ' Openstrator/Exporters.swift

echo 'Openstrator V6 M2 acceptance: PASS'
