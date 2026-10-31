import re
from pathlib import Path
exporter = Path('Openstrator/Exporters.swift').read_text()
selftest = Path('Sources/OpenstratorCoreSelfTest/main.swift').read_text()
builder = Path('BUILD_OPENSTRATOR.command').read_text()
required_export = [
    'font-family=', 'font-size=', 'letter-spacing=', 'data-openstrator-layout=',
    '<textPath href=\\"#path-', 'writing-mode:vertical-rl', 'data-openstrator-warp=',
    'id=\\"path-'
]
for token in required_export:
    assert token in exporter, f'missing M3 SVG export token: {token}'
assert 'OpenstratorCoreSelfTest M3 final: PASS (' in selftest, 'missing M3 self-test final marker'
assert re.search(r'Openstrator V6 M(?:3|4|5|6|7|8|9|10)', builder), 'builder is not branded as M3'
assert '--product Openstrator' in builder, 'builder must explicitly build app product'
assert '"$SWIFT" test' not in builder, 'Terminal packaging must not depend on XCTest'
print('M3 release contract: PASS')
