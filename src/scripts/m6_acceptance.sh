#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo '[M6 1/10] Historical M1→M5 acceptance gates'
if [[ "${M6_SKIP_HISTORICAL:-0}" == "1" ]]; then
  echo 'Historical gates already verified in this release run; skipping duplicate execution.'
else
  bash scripts/m5_acceptance.sh
fi

echo '[M6 2/10] Full OpenstratorCore XCTest suite'
swift test --filter OpenstratorCoreTests

echo '[M6 3/10] Framework-free M6 release self-test'
swift run -c release OpenstratorCoreSelfTest | tee /tmp/openstrator-m6-selftest.out
grep -q 'OpenstratorCoreSelfTest M6 final: PASS (87 checks)' /tmp/openstrator-m6-selftest.out

echo '[M6 4/10] M6 workflow contracts'
python3 scripts/m6_model_compat_contract.py
python3 scripts/m6_layer_ui_contract.py
python3 scripts/m6_mask_clip_contract.py
python3 scripts/m6_embedded_object_contract.py
python3 scripts/m6_linked_asset_contract.py
python3 scripts/m6_symbol_contract.py
python3 scripts/m6_resources_thumbnail_contract.py
python3 scripts/m6_mac_compiler_regression.py
python3 scripts/m6_release_contract.py

echo '[M6 5/10] Historical delete/native compiler regressions remain green'
python3 scripts/m4_delete_regression.py
python3 scripts/m3_macos_compile_regressions.py
python3 scripts/m4_1_mac_compiler_regression.py
python3 scripts/m5_macos_compile_regressions.py
python3 scripts/m5_1_mac_compiler_regression.py

echo '[M6 6/10] Terminal builder remains XCTest-independent'
bash scripts/test_builder_core_selftest.sh
if grep -q '"$SWIFT" test' BUILD_OPENSTRATOR.command; then
  echo 'FAIL: packaging builder invokes XCTest-backed swift test.' >&2
  exit 1
fi
grep -q -- '--product Openstrator' BUILD_OPENSTRATOR.command
grep -q 'Openstrator V6 M6' BUILD_OPENSTRATOR.command

echo '[M6 7/10] Swift parser checks'
for f in Openstrator/*.swift Sources/OpenstratorCore/*.swift Sources/OpenstratorCore/*/*.swift Sources/OpenstratorCoreSelfTest/*.swift; do
  swiftc -frontend -parse "$f"
done

echo '[M6 8/10] Icon transparency + Package manifest'
python3 scripts/verify_icon_alpha.py
swift package dump-package >/tmp/openstrator-m6-package.json
python3 - <<'PY'
import json
with open('/tmp/openstrator-m6-package.json') as f: data=json.load(f)
assert data['name']=='Openstrator'
assert any(t['name']=='OpenstratorCoreSelfTest' for t in data['targets'])
print('Package.swift manifest: PASS')
PY

echo '[M6 9/10] M6 file/resource inventory'
for f in LayerWorkflow.swift MaskClippingWorkflow.swift EmbeddedObjectWorkflow.swift LinkedAssetWorkflow.swift SymbolWorkflow.swift ResourceLibraryWorkflow.swift LayerThumbnails.swift; do
  test -f "Openstrator/$f"
done
test -f Sources/OpenstratorCore/Workflow/LayerObjectModels.swift

echo '[M6 10/10] M6 documentation markers'
grep -q 'Milestone 6' README.md
grep -q 'M6' FEATURES.md
grep -q 'M6' BUILD_FIX_NOTES.md

echo 'Openstrator V6 M6 acceptance: PASS'
