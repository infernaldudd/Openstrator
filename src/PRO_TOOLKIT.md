# Openstrator 0.5 Pro Toolkit inventory

**89 tools · 124 effects/effect equivalents**

## Tools

### Selection
Selection, Direct Selection, Group Selection, Magic Wand, Lasso

### Drawing
Pen, Add Anchor Point, Delete Anchor Point, Anchor Point, Curvature, Pencil, Paintbrush, Blob Brush, Smooth, Path Eraser, Scissors, Knife, Join, Shaper, Eraser

### Shapes
Rectangle, Rounded Rectangle, Ellipse, Polygon, Star, Line Segment, Arc, Spiral, Rectangular Grid, Polar Grid, Flare

### Type
Type, Area Type, Type on Path, Vertical Type, Vertical Area Type, Vertical Type on Path, Touch Type

### Transform
Rotate, Reflect, Scale, Shear, Width, Free Transform, Reshape, Warp, Twirl, Pucker, Bloat, Scallop, Crystallize, Wrinkle, Puppet Warp

### Color & Appearance
Gradient, Gradient Mesh, Eyedropper, Measure

### Construction
Blend, Shape Builder, Live Paint Bucket, Live Paint Selection, Symbol Sprayer, Symbol Shifter, Symbol Scruncher, Symbol Sizer, Symbol Spinner, Symbol Stainer, Symbol Screener, Symbol Styler, Column Graph, Stacked Column Graph, Bar Graph, Stacked Bar Graph, Line Graph, Area Graph, Scatter Graph, Pie Graph, Radar Graph, Perspective Grid, Perspective Selection, Artboard, Slice, Slice Selection, Dimension, Objects on Path

### Navigation
Hand, Print Tiling, Rotate View, Zoom

## Effects

### Convert to Shape
Rectangle, Rounded Rectangle, Ellipse

### Stylize
Drop Shadow, Outer Glow, Inner Shadow, Inner Glow, Feather, Round Corners, Scribble, Glowing Edges, Neon Edge

### Blur
Blur, Gaussian Blur, Radial Blur, Zoom Blur, Smart Blur, Motion Blur

### Color
Brightness, Contrast, Saturation, Hue Rotation, Grayscale, Sepia, Invert, Exposure, Vibrance, Temperature, Posterize, Threshold, Color Boost, Fade

### Distort & Transform
Offset, Transform Scale, Transform Rotate, Free Distort, Pucker & Bloat, Roughen, Tweak, Twist, Zig Zag

### Warp
Arc, Arch, Bulge, Flag, Fish, Inflate, Rise, Shell Lower, Shell Upper, Squeeze, Wave

### Path
Offset Path, Outline Object, Outline Stroke

### Pathfinder
Add / Unite, Intersect, Exclude, Subtract / Minus Front, Minus Back, Divide, Trim, Merge, Crop, Outline

### 3D & Materials
Plane, Extrude & Bevel, Revolve, Inflate

### Artistic
Colored Pencil, Cutout, Dry Brush, Film Grain, Fresco, Neon Glow, Paint Daubs, Palette Knife, Plastic Wrap, Poster Edges, Rough Pastels, Smudge Stick, Sponge, Underpainting, Watercolor

### Brush Strokes
Accented Edges, Angled Strokes, Crosshatch, Dark Strokes, Ink Outlines, Spatter, Sprayed Strokes, Sumi-e

### Distort (Raster)
Diffuse Glow, Glass, Ocean Ripple

### Pixelate
Color Halftone, Crystallize, Mezzotint, Mosaic, Pointillize

### Sketch
Bas Relief, Chalk & Charcoal, Charcoal, Chrome, Conté Crayon, Graphic Pen, Halftone Pattern, Note Paper, Photocopy, Plaster, Reticulation, Stamp, Torn Edges, Water Paper

### Texture
Craquelure, Grain, Mosaic Tiles, Patchwork, Stained Glass, Texturizer

### Video
De-Interlace, NTSC Colors

### Rasterize & SVG
Rasterize, SVG Filter

## Implementation note

Openstrator uses original native SwiftUI/Core Graphics implementations. Many complex Illustrator-class effects are represented by lightweight, editable Openstrator equivalents rather than Adobe’s proprietary algorithms. Pathfinder effects operate on the current selection; Convert-to-Shape effects override rendered geometry non-destructively; raster-style effects use native filter/transform approximations.


## V6 M4 Appearance engine

Openstrator M4 introduces an ordered appearance graph with multiple fills, multiple strokes, stable entry IDs, root/entry opacity and blend modes, typed live-effect parameter schemas, visual-bounds evaluation, live Preview/Reset/Cancel/Apply editing, and vector-safe Expand Appearance. The Appearance panel also retains the complete legacy effect inventory under **All Effects** while effect families are progressively moved to typed engines. Raster-dependent expansion is intentionally deferred to the M5 raster engine.
