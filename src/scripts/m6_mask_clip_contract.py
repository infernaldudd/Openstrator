from pathlib import Path
workflow=Path('Openstrator/MaskClippingWorkflow.swift').read_text()
canvas=Path('Openstrator/CanvasView.swift').read_text()
app=Path('Openstrator/OpenstratorApp.swift').read_text()
for token in [
    'func makeClippingGroup()', 'func releaseClippingGroup()',
    'func makeOpacityMask()', 'func releaseOpacityMask()', 'func toggleOpacityMaskInversion()',
    'layer.clip(to: clipPath)', '.destinationIn', '.destinationOut',
]:
    assert token in workflow, token
assert 'CompositedDocumentRenderer.draw' in canvas
assert 'static func clippingPath(for object: VectorObject)' in canvas
assert 'Make Clipping Group' in app and 'Make Opacity Mask' in app
print('M6 clipping/mask contract: PASS')
