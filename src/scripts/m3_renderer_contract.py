from pathlib import Path
r=Path('Openstrator/TypographyRenderer.swift')
o=Path('Openstrator/TextOutliner.swift')
c=Path('Openstrator/CanvasView.swift').read_text()
s=Path('Openstrator/EditorStore.swift').read_text()
assert r.exists(), 'TypographyRenderer.swift missing'
assert o.exists(), 'TextOutliner.swift missing'
rs=r.read_text(); os=o.read_text()
for token in ['enum TypographyRenderer','TextPathLayout.placements','glyphTransforms','TextWarpEngine.offset','.verticalArea','.verticalPath','MacFontCatalog.shared.resolveFont']:
    assert token in rs, f'missing renderer contract: {token}'
for token in ['CTLineCreateWithAttributedString','CTFontCreatePathForGlyph','CGPath','BezierPathV6']:
    assert token in os, f'missing outliner contract: {token}'
assert 'TypographyRenderer.draw' in c, 'Canvas renderer does not delegate rich text'
assert 'func createOutlines()' in s, 'Create Outlines command missing'
print('M3 renderer/outliner contract: PASS')
