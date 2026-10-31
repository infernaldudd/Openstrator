from pathlib import Path

image_runtime = Path("Openstrator/RasterImageRuntime.swift").read_text()
filter_runtime = Path("Openstrator/RasterFilterRuntime.swift").read_text()
store = Path("Openstrator/EditorStore.swift").read_text()
app = Path("Openstrator/OpenstratorApp.swift").read_text()

assert "import OpenstratorCore" in image_runtime, "RasterImageRuntime must see RasterTileStoreV6/RasterAssetMetadataV6"
assert "import OpenstratorCore" in filter_runtime, "RasterFilterRuntime must see RasterFilterRecordV6"
assert "horizontalPixelScale" in store and "verticalPixelScale" in store, "split raster pixelScale expression for Swift 6 type checking"
assert "Double(buffer.width) / max(1.0, Double(rect.width))" not in store
assert "@MainActor\nprivate struct OpenstratorM5Commands: Commands" in app
assert "OpenstratorM5Commands(store: store)" in app
print("M5.1 macOS compiler regression: PASS")
