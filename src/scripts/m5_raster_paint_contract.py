from pathlib import Path
root = Path(__file__).resolve().parents[1]
store = (root/'Openstrator/EditorStore.swift').read_text()
canvas = (root/'Openstrator/CanvasView.swift').read_text()
runtime = (root/'Openstrator/RasterImageRuntime.swift').read_text()
for needle in ['var canRasterEditSelection: Bool', 'func paintSelectedRaster(along points: [CGPoint], eraser: Bool)', 'RasterBrushV6.erase', 'RasterBrushV6.paint', 'maxEditablePixels: Int = 40_000_000', 'RasterImageCache.shared.removeAll()']:
    assert needle in store or needle in runtime, needle
assert 'if store.canRasterEditSelection { store.paintSelectedRaster' in canvas
assert 'store.activeTool == .eraser && store.canRasterEditSelection' in canvas
assert 'static func pngData(from store: RasterTileStoreV6)' in runtime
print('M5 raster paint/erase contract: PASS')
