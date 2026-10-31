from pathlib import Path
store=Path('Openstrator/LayerWorkflow.swift').read_text()
editor=Path('Openstrator/EditorStore.swift').read_text()
required=[
    'var layerRows: [LayerRowEntry]',
    'func ensureM6LayerTree()',
    'func reconcileM6LayerTree()',
    'func selectLayerNode(',
    'func toggleLayerExpansion(',
    'func toggleLayerVisibility(',
    'func toggleLayerLock(',
    'func renameLayerNode(',
    'func cycleLayerAccent(',
    'func dropLayerNodeStrings(',
    'func syncDocumentObjectOrderFromLayerTree()',
]
missing=[x for x in required if x not in store]
assert not missing, missing
assert 'groupSelectionM6()' in editor and 'ungroupSelectionM6()' in editor
assert 'reconcileM6LayerTree()' in editor
print('M6 layer UI bridge contract: PASS')
