from pathlib import Path
store=Path('Openstrator/EditorStore.swift').read_text()
panels=Path('Openstrator/Panels.swift').read_text()
ui=Path('Openstrator/AppearancePanel.swift').read_text() if Path('Openstrator/AppearancePanel.swift').exists() else ''
for marker in ['func beginAppearancePreview(objectID: UUID)','func updateAppearancePreview(objectID: UUID','func commitAppearancePreview(objectID: UUID)','func cancelAppearancePreview(objectID: UUID)','func addAppearanceFill(objectID: UUID)','func addAppearanceStroke(objectID: UUID)','func addLiveEffect(_ effectID: String, objectID: UUID)']:
    assert marker in store, marker
assert 'AppearancePanel(object: object)' in panels
assert 'ForEach(stack.entries' in ui
assert 'object.effects[index]' not in ui
assert 'entryID:' in ui
assert 'EffectCategory.allCases' in ui and 'store.addEffect(kind)' in ui, 'M4 Appearance panel must preserve access to the full legacy effect inventory'
assert '.onDisappear { store.cancelAppearancePreview(objectID: objectID) }' in ui, 'dismissed effect sheets must cancel uncommitted preview'
assert 'gradient!' not in panels, 'Inspector must not retain stale force-unwrapped gradient bindings after M4 replaces the old appearance section'
print('m4 appearance UI contract: PASS')
