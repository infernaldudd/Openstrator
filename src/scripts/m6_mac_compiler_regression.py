from pathlib import Path

layer = Path('Openstrator/LayerWorkflow.swift').read_text()
thumb = Path('Openstrator/LayerThumbnails.swift').read_text()
canvas = Path('Openstrator/CanvasView.swift').read_text()
mask = Path('Openstrator/MaskClippingWorkflow.swift').read_text()
resources = Path('Openstrator/ResourceLibraryWorkflow.swift').read_text()
embedded = Path('Openstrator/EmbeddedObjectWorkflow.swift').read_text()
linked = Path('Openstrator/LinkedAssetWorkflow.swift').read_text()
symbols = Path('Openstrator/SymbolWorkflow.swift').read_text()
models = Path('Sources/OpenstratorCore/Workflow/LayerObjectModels.swift').read_text()

for name, text in {
    'LayerWorkflow': layer,
    'LayerThumbnails': thumb,
    'ResourceLibraryWorkflow': resources,
    'EmbeddedObjectWorkflow': embedded,
    'LinkedAssetWorkflow': linked,
    'SymbolWorkflow': symbols,
}.items():
    assert 'import OpenstratorCore' in text, f'{name} must explicitly import OpenstratorCore'

assert 'import AppKit' in layer, 'LayerWorkflow uses NSEvent and must explicitly import AppKit'
assert 'private struct LayerTreeRowView' not in layer, 'LayerTreeRowView is referenced cross-file and cannot be private'
assert '@MainActor\nstruct LayerTreeRowView: View' in layer
assert '@MainActor\nfinal class LayerThumbnailCache' in thumb
assert '@MainActor\nstruct LayerThumbnailView: View' in thumb
assert '@MainActor\nstruct ResourceLibraryPanel: View' in resources
assert 'Color(nsColor: .secondaryLabelColor)' in resources, 'avoid ambiguous conditional ShapeStyle inference'
assert 'CGFloat(object.fill.r)' in thumb and 'CGFloat(cos(a))' in thumb, 'AppKit/CoreGraphics numeric bridges must be explicit'
assert 'public enum LayerNodeKindV6' in models and 'Equatable' in models and 'Hashable' in models
assert 'cos(CGFloat(angle))' in canvas and 'sin(CGFloat(angle))' in canvas, 'polygon trig must use CGFloat overloads'
assert 'let radians = CGFloat(proxy.rotation * .pi / 180)' in embedded, 'embedded rotation must remain CGFloat-safe'
assert '?? CGFloat(proxy.x)' in embedded and '?? CGFloat(proxy.y)' in embedded, 'embedded bounds fallback must use CGFloat'
assert 'object.x = Double(minX)' in embedded and 'object.width = max(1, Double(maxX - minX))' in embedded, 'embedded geometry must convert CGFloat to Double'
assert 'guard let clippingGroupID' in mask and 'groupIDs.contains(clippingGroupID)' in mask, 'release must unwrap UUID'
assert 'func toggleLayerVisibility(_ id: UUID) {\n        guard var tree = document.layerTree, let node =' in layer, 'layer visibility guard must be immutable'
print('M6.1 macOS compiler-risk regression: PASS')
