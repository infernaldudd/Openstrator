from pathlib import Path
s=Path('Openstrator/Models.swift').read_text()
assert 'var appearanceStack: AppearanceStackV6? = nil' in s
assert 'var resolvedAppearanceStack: AppearanceStackV6' in s
assert 'mutating func applyAppearanceStack(_ stack: AppearanceStackV6)' in s
assert 'effects = normalized.entries.compactMap' in s
assert 'legacyUnmapped' in s, 'legacy effects outside the M4 typed subset must survive appearance edits'
print('m4 appearance bridge contract: PASS')
