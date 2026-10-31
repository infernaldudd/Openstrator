from pathlib import Path
w=Path('Openstrator/SymbolWorkflow.swift').read_text()
c=Path('Openstrator/CanvasView.swift').read_text()
e=Path('Openstrator/EditorStore.swift').read_text()
a=Path('Openstrator/OpenstratorApp.swift').read_text()
for token in [
    'func createSymbolFromSelection()', 'func placeSymbol(', 'func replaceSymbolDefinitionFromSelection()',
    'func detachSelectedSymbolInstances()', 'func spraySymbolDefinition(', 'symbolDefinitionID',
]: assert token in w, token
assert 'SymbolRuntime.draw' in c
assert 'symbolDefinitionForSprayer()' in e
assert 'Create Symbol from Selection' in a
print('M6 symbol contract: PASS')
