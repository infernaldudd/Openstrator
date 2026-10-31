#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p releases
cat releases/parts/intel-*.part > releases/Openstrator-Intel-V6-M6-Terminal.zip
cat releases/parts/apple-*.part > releases/Openstrator-AppleSilicon-V6-M6-Terminal.zip
printf '%s  %s\n' \
'd58b986df137be6e6f614cbeecc2284d42dfc5c86074743261bc06a67c95993a' 'releases/Openstrator-Intel-V6-M6-Terminal.zip' \
'776ca970c5763eae0f129625a74bc162d15c5510e6cb225dcabb8d8f165606c4' 'releases/Openstrator-AppleSilicon-V6-M6-Terminal.zip' | shasum -a 256 -c -
unzip -tq releases/Openstrator-Intel-V6-M6-Terminal.zip >/dev/null
unzip -tq releases/Openstrator-AppleSilicon-V6-M6-Terminal.zip >/dev/null
echo 'Both original V6 M6 archives reconstructed and verified.'
