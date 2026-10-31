from pathlib import Path

artboard = Path('Sources/OpenstratorCore/Document/ArtboardOperations.swift').read_text()
canvas = Path('Openstrator/CanvasView.swift').read_text()
outliner = Path('Openstrator/TextOutliner.swift').read_text()
renderer = Path('Openstrator/TypographyRenderer.swift').read_text()

assert 'import CoreGraphics' in artboard, 'ArtboardOperations must explicitly import CoreGraphics for CGSize default arguments under Swift 6'
assert 'MainActor.assumeIsolated' in canvas and 'TypographyRenderer.draw' in canvas, 'Canvas text rendering must bridge explicitly into the main actor'
assert 'as? CTFont' not in outliner, 'Swift 6 rejects conditional casts to CoreFoundation CTFont'
assert 'private static func makeGlyphs' in renderer, 'makeGlyphs must not expose the private RenderGlyphV6 type'
assert 'var text = Text(' not in renderer, 'renderer should not keep an unmutated Text as var'
print('M3 macOS compile regressions: PASS')
