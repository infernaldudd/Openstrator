from pathlib import Path
w=Path('Openstrator/LinkedAssetWorkflow.swift').read_text()
r=Path('Openstrator/CanvasView.swift').read_text()
a=Path('Openstrator/OpenstratorApp.swift').read_text()
for token in [
    'func placeLinkedImages()', 'func refreshLinkedAsset(', 'func relinkLinkedAsset(', 'func embedLinkedAsset(',
    'fallbackRasterAssetID', 'contentFingerprint', 'modificationDate',
    'RasterImageCache.shared.removeAll()',
]: assert token in w, token
assert 'LinkedAssetRuntime.image' in r
assert 'Place Linked Images…' in a and 'Linked Images…' in a
print('M6 linked asset contract: PASS')
