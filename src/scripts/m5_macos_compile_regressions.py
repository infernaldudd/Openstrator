from pathlib import Path

canvas = Path("Openstrator/CanvasView.swift").read_text()
assert ".dropDestination(for: URL.self)" in canvas, "use typed location-aware dropDestination for URL drops"
assert ".onDrop(of: [UTType.fileURL.identifier]" not in canvas, "invalid location-aware onDrop overload must not return"

image_runtime = Path("Openstrator/RasterImageRuntime.swift").read_text()
filter_runtime = Path("Openstrator/RasterFilterRuntime.swift").read_text()
for name, source in [("RasterImageRuntime.swift", image_runtime), ("RasterFilterRuntime.swift", filter_runtime)]:
    assert "import OpenstratorCore" in source, f"{name} must import OpenstratorCore for Raster*V6 types"
assert "CGImageDestinationCreateWithData" in image_runtime
assert "maxEditablePixels" in image_runtime

store = Path("Openstrator/EditorStore.swift").read_text()
assert "horizontalPixelScale" in store and "verticalPixelScale" in store, "keep raster pixel-scale math split into compiler-friendly subexpressions"
assert "Double(buffer.width) / max(1.0, Double(rect.width))" not in store, "do not restore the Swift 6 type-check-heavy pixelScale expression"

app = Path("Openstrator/OpenstratorApp.swift").read_text()
assert "private struct OpenstratorM5Commands: Commands" in app, "M5 menus must be grouped to avoid CommandsBuilder arity failure"
assert "OpenstratorM5Commands(store: store)" in app
assert 'CommandMenu("Artboard")' in app and 'CommandMenu("Raster")' in app and 'CommandMenu("View")' in app
print("m5 macOS compile regressions: PASS")
