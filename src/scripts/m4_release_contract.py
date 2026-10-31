import re
from pathlib import Path
main=Path('Sources/OpenstratorCoreSelfTest/main.swift').read_text()
exp=Path('Openstrator/Exporters.swift').read_text()
builder=Path('BUILD_OPENSTRATOR.command').read_text()
models=Path('Openstrator/Models.swift').read_text()
assert 'OpenstratorCoreSelfTest M4 final: PASS' in main
assert 'data-openstrator-appearance=' in exp
assert 'm4SVGElements' in exp
assert 'var appearanceStack: AppearanceStackV6?' in models
assert re.search(r'Openstrator V6 M(?:4|5|6|7|8|9|10)', builder), 'builder milestone regression'
assert '--product Openstrator' in builder
assert '"$SWIFT" test' not in builder
print('m4 release contract: PASS')
