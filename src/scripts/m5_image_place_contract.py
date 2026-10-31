from pathlib import Path
root = Path(__file__).resolve().parents[1]
store = (root / 'Openstrator/EditorStore.swift').read_text()
app = (root / 'Openstrator/OpenstratorApp.swift').read_text()
canvas = (root / 'Openstrator/CanvasView.swift').read_text()
runtime_path = root / 'Openstrator/RasterImageRuntime.swift'
assert runtime_path.exists(), 'RasterImageRuntime.swift missing'
runtime = runtime_path.read_text()
for needle in [
    'func placeImages()',
    'allowsMultipleSelection = true',
    'allowedContentTypes = [UTType.image]',
    'func placeImages(at urls: [URL], dropPoint: CGPoint? = nil)',
    'RasterImageRuntime.metadataAndEmbeddedAsset(from: url)',
    'snapshot()',
    'artW * 0.60',
    'artH * 0.60',
    'CGFloat(index) * 24',
    'VectorObject.image(',
    'assetID: asset.id',
]:
    assert needle in store, needle
assert 'metadataAndEmbeddedAsset(from url: URL)' in runtime
assert 'embeddedData = try Data(contentsOf: url)' in runtime
assert 'id: UUID()' in runtime
assert 'Button("Place Images…")' in app
assert 'Button("Images…")' in app
assert '.dropDestination(for: URL.self)' in canvas
assert 'store.placeImages(at: urls, dropPoint:' in canvas
print('M5 image placement contract: PASS')
