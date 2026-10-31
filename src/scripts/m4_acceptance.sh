#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo '[M4 1/9] Full OpenstratorCore XCTest suite'
swift test --filter OpenstratorCoreTests

echo '[M4 2/9] Framework-free M4 release self-test'
swift run -c release OpenstratorCoreSelfTest | tee /tmp/openstrator-m4-selftest.out
grep -q 'OpenstratorCoreSelfTest M4 final: PASS (61 checks)' /tmp/openstrator-m4-selftest.out

echo '[M4 3/9] Delete + appearance source contracts'
python3 scripts/m4_delete_regression.py
python3 scripts/m4_appearance_bridge_contract.py
python3 scripts/m4_renderer_contract.py
python3 scripts/m4_appearance_ui_contract.py
python3 scripts/m4_expand_app_contract.py
python3 scripts/m4_release_contract.py
python3 scripts/m3_macos_compile_regressions.py
python3 scripts/m4_1_mac_compiler_regression.py

echo '[M4 4/9] Terminal builder remains XCTest-independent'
bash scripts/test_builder_core_selftest.sh
if grep -q '"$SWIFT" test' BUILD_OPENSTRATOR.command; then
  echo 'FAIL: packaging builder invokes XCTest-backed swift test.' >&2
  exit 1
fi
grep -q -- '--product Openstrator' BUILD_OPENSTRATOR.command
grep -Eq 'Openstrator V6 M(4|5|6|7|8|9|10)' BUILD_OPENSTRATOR.command

echo '[M4 5/9] Swift parser checks'
for f in Openstrator/*.swift Sources/OpenstratorCore/*.swift Sources/OpenstratorCore/*/*.swift Sources/OpenstratorCoreSelfTest/*.swift; do
  swiftc -frontend -parse "$f"
done

echo '[M4 6/9] Icon transparency'
python3 scripts/verify_icon_alpha.py

echo '[M4 7/9] M4 persistence/export markers'
grep -q 'var appearanceStack: AppearanceStackV6?' Openstrator/Models.swift
grep -q 'AppearanceRenderer.draw' Openstrator/CanvasView.swift
grep -q 'data-openstrator-appearance=' Openstrator/Exporters.swift
grep -q 'AppearancePanel(object: object)' Openstrator/Panels.swift
grep -q 'Expand Appearance' Openstrator/OpenstratorApp.swift

echo '[M4 8/9] No stale index-bound effects UI'
if grep -q 'object.effects\[index\]' Openstrator/Panels.swift Openstrator/AppearancePanel.swift; then
  echo 'FAIL: stale index-based effect binding remains in active appearance UI.' >&2
  exit 1
fi

echo '[M4 9/9] Package manifest parses'
swift package dump-package >/tmp/openstrator-m4-package.json
python3 - <<'PY'
import json
with open('/tmp/openstrator-m4-package.json') as f:
    data=json.load(f)
assert data['name']=='Openstrator'
assert any(t['name']=='OpenstratorCoreSelfTest' for t in data['targets'])
print('Package.swift manifest: PASS')
PY

echo 'Openstrator V6 M4 acceptance: PASS'
