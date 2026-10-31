from pathlib import Path
root = Path(__file__).resolve().parents[1]
models = (root / 'Openstrator/Models.swift').read_text()
core = (root / 'Sources/OpenstratorCore/Raster/RasterModels.swift').read_text()
doc = (root / 'Sources/OpenstratorCore/Document/DocumentV6.swift').read_text()
for needle in [
    'var rasterAssetID: UUID? = nil',
    'var rasterFilters: [RasterFilterRecordV6]? = nil',
    'var rasterMask: RasterMaskV6? = nil',
    'var rasterAssets: [RasterAssetRecord]? = nil',
]:
    assert needle in models, needle
assert 'image(RasterImageDataV6)' in doc
assert 'public struct RasterImageDataV6' in core
assert 'public struct RasterMaskV6' in core
print('M5 raster model compatibility contract: PASS')
