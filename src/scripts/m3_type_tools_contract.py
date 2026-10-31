from pathlib import Path
canvas=Path('Openstrator/CanvasView.swift').read_text()
store=Path('Openstrator/EditorStore.swift').read_text()
required_store=[
 'func addVerticalText',
 'func addAreaText',
 'func addTypeOnSelectedPath',
 'func touchType',
 'data.layoutMode = .point',
 'data.layoutMode = .verticalPoint',
 'data.layoutMode = vertical ? .verticalArea : .area',
 'data.layoutMode = vertical ? .verticalPath : .path',
]
for t in required_store: assert t in store, f'missing store type behavior: {t}'
for case in ['case .text:', 'case .areaText:', 'case .typeOnPath:', 'case .verticalText:', 'case .verticalAreaText:', 'case .verticalTypeOnPath:', 'case .touchType:']:
    assert case in canvas, f'missing canvas tool branch: {case}'
print('M3 type tools contract: PASS')
