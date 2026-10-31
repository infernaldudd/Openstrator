# Openstrator V6 Milestone 6 — Layer/Object Workflows Implementation Plan

**Goal:** Add professional layer/object workflows on top of the M5.1 raster-capable shell without regressing vector, typography, appearance, raster, delete safety, or old-document compatibility.

**Architecture:** Keep the existing M5.1 `OpenDocument.objects` rendering facade for compatibility, but add a backward-compatible hierarchical `LayerTreeV6` plus a typed `ResourceLibraryV6`. Object records receive optional M6 relationship IDs. The layer tree becomes the source of hierarchy/order/visibility/lock semantics while the flat object array remains a rendering/storage bridge until the later full V6 ownership migration.

## Global constraints
- M5.1 and older `.openstrator` documents must decode with no M6 keys.
- Layer move/reparent must reject cycles and dangling parents.
- Delete/duplicate/copy/paste must repair hierarchy and resource references.
- Clipping/masks must affect rendering, not be decorative metadata.
- Embedded Objects and Symbols preserve source content in document-owned encoded payloads.
- Linked assets retain an embedded fallback so missing external files do not break the document.
- Resource definitions are shared; instances/references do not duplicate payload bytes.
- Layer thumbnails are cacheable and generated asynchronously.
- Intel and Apple Silicon package source remains identical except architecture metadata.

## Task 1 — Hierarchical Layer Tree Core
- Create `Sources/OpenstratorCore/Workflow/LayerObjectModels.swift`.
- Add `LayerNodeKindV6`, `LayerNodeV6`, `LayerTreeV6`, cycle-safe insert/move/reparent/remove and validation.
- Add tests for nested hierarchy, reordering, reparenting, cycle rejection, subtree delete and round-trip.
- Add optional `OpenDocument.layerTree` and `VectorObject.layerNodeID` compatibility fields.

## Task 2 — Layer Panel / Group Workflow Bridge
- Bootstrap a tree for legacy flat documents and reconcile it after edits.
- Upgrade Group/Ungroup to real nested group nodes while keeping legacy `groupID` behavior compatible.
- Add expand/collapse, rename, recursive visibility/lock, selection targeting, locate selected object, layer accent and drag reorder/reparent.
- Keep z-order synchronized with layer order.

## Task 3 — Clipping Groups + Opacity Masks
- Add optional clipping/mask relationship fields.
- Commands: Make/Release Clipping Group, Make/Release Opacity Mask, invert mask.
- Renderer isolates group contents; clipping path clips content and opacity mask composites with destination-in semantics.
- Delete/reference repair prevents dangling relationships.

## Task 4 — Embedded Objects
- Add typed `EmbeddedObjectResourceV6` resources and app payload encoding including raster/resource dependencies.
- Convert selection to Embedded Object proxy, preserve internal content/bounds, transform non-destructively, expand contents explicitly, replace contents, and support nested resources with a recursion guard.
- Render proxies from their preserved internal content.

## Task 5 — Links / Assets
- Add `LinkedAssetResourceV6` with original URL, filename, fallback raster asset and fingerprint/date metadata.
- Place linked images, refresh, relink and embed linked assets.
- Renderer prefers live external data when available and falls back to document-owned embedded bytes.
- Links panel reports linked/missing/modified state.

## Task 6 — Symbols
- Add `SymbolDefinitionV6` and symbol-instance object metadata.
- Create symbol definition from selection, place instances without duplicating definition payload, replace definition from selection, detach instance.
- Symbol Sprayer uses a selected/available symbol definition when possible.

## Task 7 — Graphic Styles + Resource Library + Thumbnails
- Add `GraphicStyleV6` and `ResourceLibraryV6` persistence.
- Save/apply/remove graphic styles.
- Resource panel sections for Embedded Objects, Links, Symbols and Graphic Styles.
- Add bounded asynchronous `LayerThumbnailCache` and real thumbnail rows.

## Task 8 — M6 Release Gate / Packages
- Expand framework-free self-test with layer tree/resource checks.
- Add M6 source/runtime contracts for layer UI, clipping/masks, embedded objects, links, symbols/styles and thumbnail cache.
- Run full core suite, M1–M6 regressions, parser/package/icon checks and M5.1 native compiler regression.
- Produce clean Intel and Apple Silicon packages from identical implementation source and record ZIP CRC, executable builder mode, parity and SHA-256.
