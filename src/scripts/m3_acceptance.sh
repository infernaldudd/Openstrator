#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo '[M3 1/8] Full OpenstratorCore XCTest suite'
swift test --filter OpenstratorCoreTests

echo '[M3 2/8] Framework-free M3 release self-test'
swift run -c release OpenstratorCoreSelfTest | tee /tmp/openstrator-m3-selftest.out
grep -q 'OpenstratorCoreSelfTest M3 final: PASS (49 checks)' /tmp/openstrator-m3-selftest.out

echo '[M3 3/8] Typography source contracts'
python3 scripts/m3_typography_runtime_contract.py
python3 scripts/m3_bridge_contract.py
python3 scripts/m3_type_tools_contract.py
python3 scripts/m3_renderer_contract.py
python3 scripts/m3_type_ui_contract.py
python3 scripts/m3_release_contract.py
python3 scripts/m3_macos_compile_regressions.py

echo '[M3 4/8] Terminal builder must remain XCTest-independent'
bash scripts/test_builder_core_selftest.sh
if grep -q '"$SWIFT" test' BUILD_OPENSTRATOR.command; then
  echo 'FAIL: packaging builder invokes XCTest-backed swift test.' >&2
  exit 1
fi
grep -q -- '--product Openstrator' BUILD_OPENSTRATOR.command || {
  echo 'FAIL: packaging builder must explicitly build the Openstrator product.' >&2
  exit 1
}
grep -Eq 'Openstrator V6 M(3|4|5|6|7|8|9|10)' BUILD_OPENSTRATOR.command || {
  echo 'FAIL: builder must identify M3 or a later V6 release.' >&2
  exit 1
}

echo '[M3 5/8] Swift parser checks'
for f in Openstrator/*.swift Sources/OpenstratorCore/*.swift Sources/OpenstratorCore/*/*.swift Sources/OpenstratorCoreSelfTest/*.swift; do
  swiftc -frontend -parse "$f"
done

echo '[M3 6/8] Icon transparency'
python3 scripts/verify_icon_alpha.py

echo '[M3 7/8] M3 persistence/export markers'
grep -q 'var typography: TextDataV6?' Openstrator/Models.swift
grep -q 'var resolvedTypography: TextDataV6' Openstrator/Models.swift
grep -q 'TypographyRenderer.draw' Openstrator/CanvasView.swift
grep -q 'CommandMenu("Type")' Openstrator/OpenstratorApp.swift
grep -q 'font-family=' Openstrator/Exporters.swift
grep -q '<textPath href=' Openstrator/Exporters.swift
grep -q 'writing-mode:vertical-rl' Openstrator/Exporters.swift

echo '[M3 8/8] Package manifest parses'
swift package dump-package >/tmp/openstrator-m3-package.json
python3 - <<'PY'
import json
with open('/tmp/openstrator-m3-package.json') as f:
    data=json.load(f)
assert data['name']=='Openstrator'
assert any(t['name']=='OpenstratorCoreSelfTest' for t in data['targets'])
print('Package.swift manifest: PASS')
PY

echo 'Openstrator V6 M3 acceptance: PASS'
