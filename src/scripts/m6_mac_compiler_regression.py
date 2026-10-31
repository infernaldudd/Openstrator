from pathlib import Path

layer = Path('Openstrator/LayerWorkflow.swift').read_text()
thumb = Path('Openstrator/LayerThumbnails.swift').read_text()
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
print('M6 macOS compiler-risk regression: PASS')
