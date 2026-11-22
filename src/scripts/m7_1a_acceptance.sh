#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo '[M7.1a 1/7] Run M6 historical contracts (set M7_SKIP_HISTORICAL=1 if already verified)'
if [[ "${M7_SKIP_HISTORICAL:-0}" != "1" ]]; then
  M6_SKIP_HISTORICAL=1 bash scripts/m6_acceptance.sh
fi

echo '[M7.1a 2/7] Full portable core tests'
swift test --filter OpenstratorCoreTests

echo '[M7.1a 3/7] Framework-free release self-test'
swift run -c release OpenstratorCoreSelfTest | tee /tmp/openstrator-m7-selftest.out
grep -q 'OpenstratorCoreSelfTest M7.1: PASS (91 total checks)' /tmp/openstrator-m7-selftest.out

echo '[M7.1a 4/7] New feature contract and past native fixes'
python3 scripts/m7_1a_stroke_contract.py
python3 scripts/m6_mac_compiler_regression.py
python3 scripts/m5_1_mac_compiler_regression.py
python3 scripts/m4_delete_regression.py

echo '[M7.1a 5/7] Parse all Swift sources (syntax only on Linux)'
for source in Openstrator/*.swift Sources/OpenstratorCore/*.swift Sources/OpenstratorCore/*/*.swift Sources/OpenstratorCoreSelfTest/*.swift; do
  swiftc -frontend -parse "$source"
done

echo '[M7.1a 6/7] Icon and manifest'
python3 scripts/verify_icon_alpha.py
swift package dump-package >/tmp/openstrator-m7-package.json

echo '[M7.1a 7/7] Builder and packaging preflight'
bash scripts/test_builder_core_selftest.sh
grep -q 'Openstrator V6 M7.1a' BUILD_OPENSTRATOR.command
if grep -q '"$SWIFT" test' BUILD_OPENSTRATOR.command; then exit 1; fi

echo 'Openstrator V6 M7.1a acceptance: PASS'
