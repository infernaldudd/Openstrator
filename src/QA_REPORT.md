# Openstrator V6 M7.1a — QA and Mac handoff

**Date:** 2026-11-22 · **Baseline:** V6 M6.1, known to launch on Apple Silicon from screenshots.

## Shipped this release

- A new framework-free `StrokeWidthProfileV6` model with five profiles and a real filled vector outline generator for **open** lines and Bézier paths.
- `VectorObject.strokeProfile` is optional, preserving old `.openstrator` Codable documents.
- Stroke Profile picker in Appearance Inspector. Each change snapshots history; copying, saving and reopening preserve the profile.
- Matching classic-canvas and M4 Appearance stack rendering. SVG export expands profiles to vector polygon paths rather than silently dropping width variation.
- App bundle version updated to 0.7.1 (build 71).

## Verification (this Linux execution environment)

- OpenstratorCore XCTest: **130/130 passed** (126 baseline + 4 new tests).
- Framework-free Terminal release self-test: **91/91 passed** (87 baseline + 4 new checks).
- M5 acceptance: passed, M6 acceptance: passed.
- M7.1a contracts: passed; all Swift source syntax parses; icon alpha, `Package.swift`, historical native compiler and delete lifecycle regressions pass.
- Intel and Apple Silicon sources: verified identical under implementation, test and script trees in final packaging; architecture/build metadata differ intentionally.
- ZIP: CRC checked; `BUILD_OPENSTRATOR.command` executable.

## Native Mac build still required

The current environment **cannot type-check/link/launch** SwiftUI, AppKit or Core Image. The user should unzip the appropriate Terminal archive into a fresh folder, run `BUILD_OPENSTRATOR.command`, and send `OPENSTRATOR_BUILD_LOG.txt` if native compilation fails. A native `.app` is **not included** in the ZIP and has **not** been built in this environment.

## Native smoke tests

1. Select an open Pen/Pencil path and choose Taper Both Ends, then Taper Start/End and Undo/Redo.
2. Save as `.openstrator`, close and reopen; confirm profile persists.
3. Export SVG and inspect the filled outline in a browser/editor. Compare against the canvas.
4. Confirm uniform strokes, closed path strokes, text, raster images, masks, nested layers, and symbols still render.
5. Check the previously observed typography transforms and off-artboard artwork from the user's M6.1 screenshots (reproduction needed to classify a defect).

## Deliberate limits

M7.1a delivers variable-width profile presets for **open paths only**. Closed-path seam interpolation, per-node Width-tool dragging, dash-compatible variable-width strokes, full Illustrator-class brushes/meshes/perspective/3D, and all remaining Adobe-class features are **not** implemented. The existing M7 feature tracker remains the umbrella scope.
