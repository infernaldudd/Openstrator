from pathlib import Path
rt=Path('Openstrator/RasterImageRuntime.swift').read_text()
store=Path('Openstrator/EditorStore.swift').read_text()
canvas=Path('Openstrator/CanvasView.swift').read_text()
checks={
 'decode tile store':'func tileStore(assetID: UUID, document: OpenDocument' in rt,
 'encode png':'func pngData(from store: RasterTileStoreV6)' in rt,
 'editable guard':'maxEditablePixels' in rt,
 'can edit':'var canRasterEditSelection: Bool' in store,
 'paint method':'func paintSelectedRaster(along points: [CGPoint], eraser: Bool)' in store,
 'brush core':'RasterBrushV6.paint' in store and 'RasterBrushV6.erase' in store,
 'persist bytes':'embeddedData = png' in store,
 'cache clear':'RasterImageCache.shared.removeAll()' in store,
 'canvas paint branch':'canRasterEditSelection' in canvas and 'paintSelectedRaster' in canvas,
}
failed=[k for k,v in checks.items() if not v]
if failed:
 print('M5 raster edit contract FAIL:', ', '.join(failed)); raise SystemExit(1)
print('M5 raster edit contract PASS')
