#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo '[M5 1/11] Historical M1→M4 acceptance gates'
if [[ "${M5_SKIP_HISTORICAL:-0}" == "1" ]]; then
  echo 'Historical gates already verified in this release run; skipping duplicate execution.'
else
  bash scripts/m1_acceptance.sh
  bash scripts/m2_acceptance.sh
  bash scripts/m3_acceptance.sh
  bash scripts/m4_acceptance.sh
fi

echo '[M5 2/11] Full OpenstratorCore XCTest suite'
swift test --filter OpenstratorCoreTests

echo '[M5 3/11] Framework-free M5 release self-test'
swift run -c release OpenstratorCoreSelfTest | tee /tmp/openstrator-m5-selftest.out
grep -q 'OpenstratorCoreSelfTest M5 final: PASS (75 checks)' /tmp/openstrator-m5-selftest.out

echo '[M5 4/11] M5 artboard/model/image/raster/filter contracts'
python3 scripts/m5_artboard_orientation_contract.py
python3 scripts/m5_raster_model_contract.py
python3 scripts/m5_image_place_contract.py
python3 scripts/m5_raster_render_contract.py
python3 scripts/m5_raster_paint_contract.py
python3 scripts/m5_raster_edit_contract.py
python3 scripts/m5_filter_runtime_contract.py
python3 scripts/m5_vector_kind_contract.py
python3 scripts/m5_macos_compile_regressions.py
python3 scripts/m5_1_mac_compiler_regression.py
python3 scripts/m5_release_contract.py

echo '[M5 5/11] Delete + native compiler regressions remain green'
python3 scripts/m4_delete_regression.py
python3 scripts/m3_macos_compile_regressions.py
python3 scripts/m4_1_mac_compiler_regression.py

echo '[M5 6/11] Terminal builder remains XCTest-independent'
bash scripts/test_builder_core_selftest.sh
if grep -q '"$SWIFT" test' BUILD_OPENSTRATOR.command; then
  echo 'FAIL: packaging builder invokes XCTest-backed swift test.' >&2
  exit 1
fi
grep -q -- '--product Openstrator' BUILD_OPENSTRATOR.command
grep -Eq 'Openstrator V6 M(5|6)' BUILD_OPENSTRATOR.command

echo '[M5 7/11] Swift parser checks'
for f in Openstrator/*.swift Sources/OpenstratorCore/*.swift Sources/OpenstratorCore/*/*.swift Sources/OpenstratorCoreSelfTest/*.swift; do
  swiftc -frontend -parse "$f"
done

echo '[M5 8/11] Icon transparency'
python3 scripts/verify_icon_alpha.py

echo '[M5 9/11] Persistence/UI markers'
grep -q 'var rasterAssets: \[RasterAssetRecord\]?' Openstrator/Models.swift
grep -q 'Place Images' Openstrator/OpenstratorApp.swift
grep -q 'Portrait' Openstrator/Panels.swift
grep -q 'CommandMenu("Raster")' Openstrator/OpenstratorApp.swift

echo '[M5 10/11] Package manifest parses'
swift package dump-package >/tmp/openstrator-m5-package.json
python3 - <<'PY'
import json
with open('/tmp/openstrator-m5-package.json') as f: data=json.load(f)
assert data['name']=='Openstrator'
assert any(t['name']=='OpenstratorCoreSelfTest' for t in data['targets'])
print('Package.swift manifest: PASS')
PY

echo '[M5 11/11] Raster core file inventory'
for f in RasterModels.swift RasterBuffer.swift RasterOperations.swift RasterSelection.swift RasterBrush.swift; do
  test -f "Sources/OpenstratorCore/Raster/$f"
done

echo 'Openstrator V6 M5 acceptance: PASS'
