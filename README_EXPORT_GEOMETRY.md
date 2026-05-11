# Export Geometry To GLB

This tool exports clean visual geometry from the generated Godot scenes to glTF 2.0 `.glb` files and ASCII `.stl` files.

It does not export gameplay scripts, cameras, lights, particles, or collision-only nodes.

## Export From Godot

Option A, editor menu:

1. Open the project in Godot.
2. Go to `Project > Project Settings > Plugins`.
3. Enable `Geometry Exporter`.
4. Use `Project > Tools > Export geometry to GLB`.

Option B, script command:

1. Open `res://scripts/editor/ExportGeometryToGLB.gd`.
2. In the script editor, choose `File > Run`.

## Output

Files are written to:

`res://exports_geometry/`

Generated files:

- `court.glb`
- `court.stl`
- `gymnase.glb`
- `gymnase.stl`
- `filet.glb`
- `filet.stl`
- `props.glb`
- `props.stl`

The `.glb` files keep more scene information and materials. The `.stl` files are raw geometry only, without colors or materials.

## Import In Blender

1. Open Blender.
2. Use `File > Import > glTF 2.0` for `.glb`, or `File > Import > STL` for `.stl`.
3. Select one of the exported files from `exports_geometry`.
4. Clean, remodel, merge, or replace geometry as needed.

## Re-export From Blender

1. Select the cleaned object or collection.
2. Use `File > Export > glTF 2.0`.
3. Choose `.glb`.
4. Keep transforms applied if you changed scale or rotation.
5. Export back into the Godot project, preferably under `res://assets/imported/` or a new scene-specific folder.

## Reimport In Godot

1. Copy the new `.glb` into the Godot project.
2. Let Godot import it.
3. Create a new scene from the imported file or instance it in a visual-only scene.
4. Keep gameplay scenes and hitboxes separate.

The exported files are meant as a modeling base, not as final optimized assets.
