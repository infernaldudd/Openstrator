from pathlib import Path

root = Path(__file__).resolve().parents[1]
core = (root / 'Sources/OpenstratorCore/Document/ArtboardOperations.swift').read_text()
store = (root / 'Openstrator/EditorStore.swift').read_text()
app = (root / 'Openstrator/OpenstratorApp.swift').read_text()
panels = (root / 'Openstrator/Panels.swift').read_text()

required_core = [
    'public enum ArtboardOrientationV6',
    'mutating func setArtboardOrientation(_ orientation: ArtboardOrientationV6, id: NodeID)',
    'let center = CGPoint(x: rect.midX, y: rect.midY)',
]
for needle in required_core:
    assert needle in core, needle

fn_start = store.index('func setArtboardOrientation(_ orientation: ArtboardOrientationV6)')
fn_body = store[fn_start:fn_start + 850]
assert 'guard !alreadyMatches else { return }' in fn_body
assert fn_body.index('snapshot()') < fn_body.index('document.artboardWidth = height')
assert 'document.artboardHeight = width' in fn_body
assert 'CommandMenu("Artboard")' in app
assert 'store.setArtboardOrientation(.portrait)' in app
assert 'store.setArtboardOrientation(.landscape)' in app
assert 'actionChip("Portrait"' in panels
assert 'actionChip("Landscape"' in panels
print('M5 artboard orientation contract: PASS')
