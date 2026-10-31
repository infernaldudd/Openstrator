from pathlib import Path
canvas=Path('Openstrator/CanvasView.swift').read_text()
panels=Path('Openstrator/Panels.swift').read_text()
exporters=Path('Openstrator/Exporters.swift').read_text()
appearance=Path('Openstrator/AppearanceRenderer.swift').read_text()
assert 'case .image:' in canvas
assert 'case .image: return "photo"' in panels
assert exporters.count('case .image:') >= 2
assert 'case .text, .image:' in appearance or 'case .image:' in appearance
print('m5 VectorKind image coverage: PASS')
