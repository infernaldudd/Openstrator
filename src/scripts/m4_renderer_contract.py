from pathlib import Path
canvas=Path('Openstrator/CanvasView.swift').read_text()
renderer=Path('Openstrator/AppearanceRenderer.swift').read_text() if Path('Openstrator/AppearanceRenderer.swift').exists() else ''
assert 'AppearanceRenderer.draw' in canvas, 'Canvas must route M4 stacks through AppearanceRenderer'
assert 'object.appearanceStack != nil' in canvas, 'M4 route must preserve legacy renderer for legacy objects'
assert 'for entry in stack.entries' in renderer, 'Renderer must consume ordered appearance entries'
assert 'include: { $0.liveEffectV6 == nil }' in renderer, 'legacy effects outside M4 typed subset must keep rendering after stack activation'
assert 'case .fill' in renderer and 'case .stroke' in renderer and 'case .effect' in renderer
assert 'map(CGFloat.init)' not in renderer, 'SwiftUI StrokeStyle dash conversion must use explicit CGFloat closure for Swift 6 compatibility'
print('m4 renderer contract: PASS')
