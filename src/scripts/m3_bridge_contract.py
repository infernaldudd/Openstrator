from pathlib import Path
models=Path('Openstrator/Models.swift').read_text()
store=Path('Openstrator/EditorStore.swift').read_text()
checks={
 'optional typography payload':'var typography: TextDataV6?',
 'resolved bridge':'var resolvedTypography: TextDataV6',
 'compatibility sync':'mutating func applyTypography',
 'character command':'func updateCharacterStyle',
 'paragraph command':'func updateParagraphStyle',
 'layout command':'func setTextLayout',
 'bullets':'func toggleBullets',
 'numbering':'func toggleNumbering',
 'threading':'func threadSelectedTextFrames',
 'unthreading':'func unthreadSelectedTextFrame',
 'warp':'func applyTextWarp',
 'glyph transform':'func setGlyphTransform',
}
for label,token in checks.items():
    hay=models if token in models else store
    assert token in hay, f'missing {label}: {token}'
print('M3 bridge contract: PASS')
