#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift test
python3 scripts/verify_icon_alpha.py
swiftc -frontend -parse Openstrator/*.swift Sources/OpenstratorCore/*.swift Sources/OpenstratorCore/*/*.swift
