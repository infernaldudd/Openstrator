from pathlib import Path
panels=Path('Openstrator/Panels.swift').read_text()
app=Path('Openstrator/OpenstratorApp.swift').read_text()
store=Path('Openstrator/EditorStore.swift').read_text()
for token in ['Font Family','Font Face','Leading','Tracking','Kerning','Baseline','Horizontal Scale','Vertical Scale','Underline','Strikethrough','Paragraph','First Line','Bullets','Numbering','Variable Font','Warp','Create Outlines','Check Spelling']:
    assert token in panels, f'missing inspector control: {token}'
for token in ['CommandMenu("Type")','Menu("Font")','Menu("Recent Fonts")','Menu("Size")','Menu("Leading")','Menu("Tracking")','Menu("Kerning")','Button("Create Outlines")','Menu("Spelling")','Menu("Bullets & Numbering")','Menu("Text Orientation")','Menu("Text Alignment")','Menu("Warp Text")','Button("Fill with Placeholder Text")']:
    assert token in app, f'missing Type menu item: {token}'
for token in ['func setFontFamily','func setFontFace','func fillPlaceholderText','func checkSpelling','func insertSpecialCharacter','func convertPointAreaText','func setTextOrientation']:
    assert token in store, f'missing Type command: {token}'
print('M3 Type UI contract: PASS')
assert 'bend: 0.35' in app, 'Warp Text menu must use normalized 35% bend, not clamp to 100%'
