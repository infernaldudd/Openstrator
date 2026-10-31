from pathlib import Path
main=Path('Sources/OpenstratorCoreSelfTest/main.swift').read_text()
models=Path('Openstrator/Models.swift').read_text()
store=Path('Openstrator/EditorStore.swift').read_text()
app=Path('Openstrator/OpenstratorApp.swift').read_text()
builder=Path('BUILD_OPENSTRATOR.command').read_text()
assert 'OpenstratorCoreSelfTest M5 final: PASS' in main
assert 'var rasterAssets: [RasterAssetRecord]? = nil' in models
assert 'var rasterAssetID: UUID? = nil' in models
assert 'func placeImages()' in store and 'func placeImages(at urls: [URL]' in store
assert 'func setArtboardOrientation(_ orientation: ArtboardOrientationV6)' in store
assert 'CommandMenu("Raster")' in app
assert 'CommandMenu("Artboard")' in app
assert 'Openstrator V6 M5' in builder or 'Openstrator V6 M6' in builder
assert '--product Openstrator' in builder
assert '"$SWIFT" test' not in builder
print('m5 release contract: PASS')
