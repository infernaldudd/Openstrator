from pathlib import Path
r=Path('Openstrator/ResourceLibraryWorkflow.swift').read_text()
t=Path('Openstrator/LayerThumbnails.swift').read_text()
p=Path('Openstrator/Panels.swift').read_text()
l=Path('Openstrator/LayerWorkflow.swift').read_text()
e=Path('Openstrator/EditorStore.swift').read_text()
for token in ['func saveGraphicStyleFromSelection()', 'func applyGraphicStyle(', 'func importResourceLibrary()', 'func exportResourceLibrary()', 'struct ResourceLibraryPanel: View']:
    assert token in r, token
for token in ['final class LayerThumbnailCache: ObservableObject', 'cache.countLimit = 96', 'cache.totalCostLimit = 24 * 1024 * 1024', 'await Task.yield()', 'struct LayerThumbnailView: View']:
    assert token in t, token
assert 'ResourceLibraryPanel()' in p
assert 'LayerThumbnailView(node: node)' in l
assert 'LayerThumbnailCache.shared.removeAll()' in e
print('M6 resources/thumbnail contract: PASS')
