from pathlib import Path
rt=Path('Openstrator/RasterFilterRuntime.swift')
store=Path('Openstrator/EditorStore.swift').read_text()
app=Path('Openstrator/OpenstratorApp.swift').read_text()
models=Path('Sources/OpenstratorCore/Raster/RasterModels.swift').read_text()
panels=Path('Openstrator/Panels.swift').read_text()
s=rt.read_text() if rt.exists() else ''
checks={
 'runtime exists':rt.exists(),
 'CIContext reused':'static let context = CIContext' in s,
 'preview 2048':'2048' in s and 'preview' in s,
 'final quality':'case final' in s,
 'gaussian':'CIGaussianBlur' in s,
 'motion':'CIMotionBlur' in s,
 'exposure':'CIExposureAdjust' in s,
 'color controls':'CIColorControls' in s,
 'sepia':'CISepiaTone' in s,
 'sharpen':'CISharpenLuminance' in s,
 'pixelate':'CIPixellate' in s,
 'crystallize':'CICrystallize' in s,
 'normalize':'func normalize()' in models,
 'store add':'func addRasterFilter(' in store,
 'raster menu':'CommandMenu("Raster")' in app,
 'raster inspector':'RasterFilterPanel(object: object)' in panels,
 'preview controls':'Button("Reset")' in panels and 'Button("Apply")' in panels and 'beginRasterFilterPreview' in store,
 'stable filter row identity':'ForEach(filters, id: \\.uuid)' in panels,
}
failed=[k for k,v in checks.items() if not v]
if failed:
 print('M5 filter runtime contract FAIL:', ', '.join(failed)); raise SystemExit(1)
print('M5 filter runtime contract PASS')
