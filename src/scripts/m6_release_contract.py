from pathlib import Path

main = Path('Sources/OpenstratorCoreSelfTest/main.swift').read_text()
models = Path('Openstrator/Models.swift').read_text()
layer = Path('Openstrator/LayerWorkflow.swift').read_text()
mask = Path('Openstrator/MaskClippingWorkflow.swift').read_text()
embedded = Path('Openstrator/EmbeddedObjectWorkflow.swift').read_text()
links = Path('Openstrator/LinkedAssetWorkflow.swift').read_text()
symbols = Path('Openstrator/SymbolWorkflow.swift').read_text()
resources = Path('Openstrator/ResourceLibraryWorkflow.swift').read_text()
thumbs = Path('Openstrator/LayerThumbnails.swift').read_text()
builder = Path('BUILD_OPENSTRATOR.command').read_text()

assert 'OpenstratorCoreSelfTest M6 final: PASS' in main
assert 'var layerTree: LayerTreeV6?' in models and 'var resourceLibrary: ResourceLibraryV6?' in models
assert 'groupSelectionM6' in layer and 'dropLayerNodeStrings' in layer
assert 'makeClippingGroup' in mask and 'makeOpacityMask' in mask
assert 'convertSelectionToEmbeddedObject' in embedded and 'EmbeddedObjectWindowManager' in embedded
assert 'placeLinkedImages' in links and 'embedLinkedAsset' in links
assert 'createSymbolFromSelection' in symbols and 'detachSelectedSymbolInstances' in symbols
assert 'saveGraphicStyleFromSelection' in resources and 'exportResourceLibrary' in resources
assert 'NSCache<NSString, NSImage>' in thumbs and 'Task.yield()' in thumbs
assert 'Openstrator V6 M6' in builder
assert '--product Openstrator' in builder
assert '"$SWIFT" test' not in builder
print('M6 release contract: PASS')
