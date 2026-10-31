from pathlib import Path

panels = Path('Openstrator/Panels.swift').read_text()
store = Path('Openstrator/EditorStore.swift').read_text()

assert 'first(where: { $0.id == id })!' not in panels, 'unsafe objectBinding force unwrap remains'
assert 'objectBinding<Value>(_ object: VectorObject' in panels, 'objectBinding must retain a fallback snapshot'
start = store.index('func deleteSelection()')
end = store.index('\n    func duplicateSelection()', start)
delete_body = store[start:end]
assert 'let doomed = selection' in delete_body, 'delete must capture doomed IDs'
assert 'selection.removeAll()' in delete_body, 'delete must clear selection'
assert delete_body.index('selection.removeAll()') < delete_body.index('document.objects.removeAll'), 'selection must clear before object removal'
assert 'directComponentSelection = nil' in delete_body, 'direct selection must clear before deletion'
assert 'repairReferencesAfterDeletion(doomed)' in delete_body, 'references must be repaired after deletion'
print('m4 delete regression: PASS')
