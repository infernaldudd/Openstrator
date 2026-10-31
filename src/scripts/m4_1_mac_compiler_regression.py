from pathlib import Path
import re, sys
root = Path(__file__).resolve().parents[1]
appearance = (root/'Openstrator'/'AppearancePanel.swift').read_text()
models = (root/'Openstrator'/'Models.swift').read_text()
editor = (root/'Openstrator'/'EditorStore.swift').read_text()
fail=[]
# macOS SwiftUI has no frame(width:minHeight:) overload.
if re.search(r'\.frame\(\s*width\s*:\s*[^,\n]+,\s*minHeight\s*:', appearance):
    fail.append('AppearancePanel still uses invalid frame(width:minHeight:) overload')
# M4 keeps legacy effect call sites; a concrete compatibility initializer must exist.
if not re.search(r'init\s*\(\s*(?:id\s*:\s*UUID\s*=\s*UUID\(\)\s*,\s*)?kind\s*:\s*EffectKind\s*,\s*amount\s*:\s*Double', models):
    fail.append('VectorEffect lacks init(kind:amount:) compatibility initializer')
# Verify old call sites actually exist so the initializer test is meaningful.
legacy_calls = len(re.findall(r'VectorEffect\s*\(\s*kind\s*:', editor))
if legacy_calls < 5:
    fail.append(f'Expected >=5 legacy VectorEffect(kind:) call sites, found {legacy_calls}')
# Remove the specific warning reported by the Mac compiler.
if 'case .color(let color):' in appearance:
    fail.append('AppearancePanel still binds unused color in .color switch case')
if fail:
    print('M4.1 compiler regression: FAIL')
    for item in fail: print(' -', item)
    sys.exit(1)
print(f'M4.1 compiler regression: PASS ({legacy_calls} legacy VectorEffect call sites covered)')
