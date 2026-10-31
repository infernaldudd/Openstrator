from pathlib import Path
s=Path('Openstrator/Models.swift').read_text()
required=[
    'var layerNodeID: UUID? = nil',
    'var clippingGroupID: UUID? = nil',
    'var clippingRole: ClippingRoleV6? = nil',
    'var opacityMaskObjectID: UUID? = nil',
    'var embeddedObjectID: UUID? = nil',
    'var symbolDefinitionID: UUID? = nil',
    'var graphicStyleID: UUID? = nil',
    'var linkedAssetID: UUID? = nil',
    'var layerTree: LayerTreeV6? = nil',
    'var resourceLibrary: ResourceLibraryV6? = nil',
]
missing=[x for x in required if x not in s]
assert not missing, missing
print('M6 model compatibility contract: PASS')
