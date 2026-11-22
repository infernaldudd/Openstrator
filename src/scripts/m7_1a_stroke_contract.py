"""Portable source contracts for M7.1a native vector width-profile integration.

Linux can parse but cannot type-check AppKit or SwiftUI. The final native gate
is still BUILD_OPENSTRATOR.command on macOS.
"""
from pathlib import Path
root=Path('.')
core=(root/'Sources/OpenstratorCore/Vector/StrokeWidthProfile.swift').read_text()
models=(root/'Openstrator/Models.swift').read_text()
outline=(root/'Openstrator/StrokeProfileRenderer.swift').read_text()
classic=(root/'Openstrator/CanvasView.swift').read_text()
appearance=(root/'Openstrator/AppearanceRenderer.swift').read_text()
inspector=(root/'Openstrator/AppearancePanel.swift').read_text()
store=(root/'Openstrator/EditorStore.swift').read_text()
svg=(root/'Openstrator/Exporters.swift').read_text()
tests=(root/'Tests/OpenstratorCoreTests/StrokeWidthProfileTests.swift').read_text()
assert 'public enum StrokeWidthProfileV6' in core
for preset in ('uniform','taperBoth','taperStart','taperEnd','middleHeavy'):
    assert f'case {preset}' in core or f', {preset}' in core
assert 'return left + right.reversed()' in core
assert 'var strokeProfile: StrokeWidthProfileV6? = nil' in models, 'old document compatibility'
assert 'StrokeOutlineV6.make(path:' in outline
assert 'StrokeProfileRenderer.outlinePath(for: object' in classic
assert 'StrokeProfileRenderer.outlinePath(for: object' in appearance
assert 'context.fill(outline, with:' in appearance, 'real geometry rendering for appearance stack'
assert 'Picker("Width Profile"' in inspector
assert 'store.setStrokeWidthProfile' in inspector
assert 'func setStrokeWidthProfile(' in store and 'snapshot()' in store, 'history/UI integration'
assert 'variableStrokeSVGElement(for: object' in svg, 'SVG must preserve variable-width geometry'
assert 'func testBezierOutlineFollowsCurveAndRespectsProfile' in tests
assert 'func testDuplicatePointsInvalidWidthsAndHugeNumbersAreSafe' in tests
print('M7.1a stroke model/UI/render/export native source contract: PASS')
