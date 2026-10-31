from pathlib import Path
p=Path('Openstrator/TypographyRuntime.swift')
assert p.exists(), 'TypographyRuntime.swift missing'
s=p.read_text()
need=[
 'NSFontManager.shared.availableFontFamilies',
 'availableMembers(ofFontFamily:',
 'CTFontCopyVariationAxes',
 'NSFontDescriptor.AttributeName.variation',
 'style.variableAxes',
 'kCTFontVariationAxisIdentifierKey',
 'NSSpellChecker.shared',
 'struct FontFamilyRecord',
 'struct FontFaceRecord',
 'struct VariableFontAxisRecord',
 'func resolveFont',
 'func misspellings',
]
for token in need:
    assert token in s, f'missing runtime contract: {token}'
print('M3 typography runtime contract: PASS')
