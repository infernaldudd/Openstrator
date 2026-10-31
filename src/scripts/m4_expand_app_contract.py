from pathlib import Path
store=Path('Openstrator/EditorStore.swift').read_text()
app=Path('Openstrator/OpenstratorApp.swift').read_text()
assert 'func expandAppearance()' in store
assert 'ExpandAppearanceV6.expand' in store
assert 'requiresRasterExpansion' in store
assert 'Button("Expand Appearance") { store.expandAppearance() }' in app
print('m4 expand app contract: PASS')
