from pathlib import Path
root = Path(__file__).resolve().parents[1]
runtime = (root / 'Openstrator/RasterImageRuntime.swift').read_text()
canvas = (root / 'Openstrator/CanvasView.swift').read_text()
store = (root / 'Openstrator/EditorStore.swift').read_text()
models = (root / 'Openstrator/Models.swift').read_text()
for needle in [
    'final class RasterImageCache',
    'cache.countLimit = 64',
    'cache.totalCostLimit = 256 * 1024 * 1024',
    'static func image(assetID: UUID, document: OpenDocument, maxPixelDimension: Int) -> NSImage?',
    'CGImageSourceCreateThumbnailAtIndex',
]: assert needle in runtime, needle
for needle in [
    'case .image:',
    'RasterImageRuntime.image(assetID: assetID, document: document, maxPixelDimension: 2048)',
    'missingImagePlaceholder',
    'layer.draw(Image(nsImage: nsImage), in: rect)',
]: assert needle in canvas, needle
for needle in [
    'private var internalClipboardRasterAssets: [UUID: RasterAssetRecord] = [:]',
    'referencedAssetIDs',
    'missingClipboardAssets',
    'document.rasterAssets = assets',
]: assert needle in store, needle
assert 'var rasterAssets: [RasterAssetRecord]? = nil' in models
print('M5 raster rendering/persistence/cache contract: PASS')
