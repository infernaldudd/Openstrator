from pathlib import Path
w=Path('Openstrator/EmbeddedObjectWorkflow.swift').read_text()
c=Path('Openstrator/CanvasView.swift').read_text()
a=Path('Openstrator/OpenstratorApp.swift').read_text()
for token in [
    'struct EmbeddedObjectPayloadV6: Codable, Equatable',
    'static let recursionLimit = 8',
    'func convertSelectionToEmbeddedObject()',
    'func expandSelectedEmbeddedObjects()',
    'func replaceEmbeddedContentsFromSelection()',
    'func openSelectedEmbeddedObject()',
    'EmbeddedObjectWindowManager.shared.open',
    'RootEditorView().environmentObject(store)',
    'Apply to Parent',
]: assert token in w, token
assert 'object.embeddedObjectID' in c and 'embeddedDepth: Int = 0' in c
assert 'Menu("Embedded Object")' in a
print('M6 embedded object contract: PASS')
