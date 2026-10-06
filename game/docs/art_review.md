# Keyboard Seller Simulator: art review and the plan for the room, models and graphics

Written 2026-10-05. Scope: models, look and rendering only (no game rules).

## 1. What is wrong now

### Pipeline (the root cause of most visual problems)
1. **The room exists twice.** `scripts/world/home.gd` (~900 lines, ~150 `_box/_cyl/_soft` calls) builds the room in code,
   and Blender files are laid on top with the code copies "muted". Coordinates are duplicated in GDScript and Python
   (`g(x, y, z)` in `room_build.py`). Any change has to be made in two places, and hidden duplicates stay in the scene.
2. **Furniture is box assemblies.** `furniture.py` builds 11 objects in 285 lines. The silhouettes are right, but there is
   no secondary detail (panel grooves, edge banding, hinges, screws, shadow gaps) and no tertiary detail (wear, dust,
   wood grain direction per part).
3. **The AI models are scans.** The TRELLIS chair and valet stand are dense (over 40k triangles), with UVs shredded
   into thousands of islands and a bumpy surface. They also cannot be lightmapped.
4. **Packaging and parcels are code.** `ItemBox` draws a rounded box, a colour stripe and a `Label3D`. There is no
   artwork, no box construction (lid, sleeve, window, insert), and no brand identity.
5. **The art folder is inside the Godot project.** `game/art/` has hundreds of reference images, each with an
   `.import` file. This slows every import and they would leak into exports.

### Materials
6. **Procedural textures from 4D noise.** They have no real micro-detail, roughness is almost flat, and albedo is
   uncalibrated (whites near 0.95, which a real surface never reaches).
7. **The wallpaper is wrong.** In the photos it is blue-grey with a large damask pattern. In the game it is beige, and
   its 3×3 tiling reads as squares.
8. **Inconsistent texel density.** Big surfaces are blurry next to sharp small props. There are no detail maps and
   no decals (scuffs, dust, cables, skirting dirt).

### Lighting and post
9. **Washed-out image.**
   - Auto exposure plus a strong flat ambient term flattens everything.
   - The window does not read as the key light.
   - The chandelier is a single point light.
10. **Weak GI and reflections.** The lightmap bakes only bounce light, and a single `UPDATE_ONCE` reflection probe
    covers the whole room. Glossy furniture reflects the wrong things.

### Proportions compared with the photos
11. **Room shell.**
    - The ceiling is 3.0 m in the game; the real one is about 3.2–3.3 m.
    - The tray ceiling has three moulding tiers in reality and one in the game.
    - The window is taller and narrower, with a deep reveal.
12. **Wall details.**
    - The door pediment is carved.
    - The wardrobe has three equal doors with long vertical handles.
    - The bed has a curved headboard and footboard with turned posts.
13. **Small objects.**
    - The rug is larger and paler.
    - The curtains run from the ceiling to the floor.

### Interaction visuals
14. **Static wardrobe.** It opens only together with a modal, the interior is plain, and items are flat boxes. You
    cannot see "how the components lie".
15. **Doors and drawers.** Only the room door and the wardrobe swing. The chest drawers do not open.

## 2. How large studios do it (what applies to us)
- **Layout in the DCC or level editor, behaviour in code.**
  - The level is assembled in one place.
  - Code attaches behaviour through named sockets, pivots and collision proxies.
  - Code never builds geometry.
- **Kit plus hero props plus surface materials.** Typical split: roughly 60–70% modular pieces, 20–25% hero assets,
  10–15% tiling surfaces. Mouldings, skirting and door casings come from a **trim sheet**: one texture shared by many
  meshes, so there are few materials and few draw calls.
- **Texel density as a rule, not a guess.** Around 512 px/m is the AAA baseline for walls and floors; close-up
  first-person props get more.
- **Detail stages.**
  - Blockout, then primary/secondary/tertiary forms.
  - Every hard edge is bevelled, so it catches light; razor edges look like CG.
  - Weighted normals throughout.
- **PBR from real scans.**
  - Albedo is calibrated: no pure black or white.
  - Roughness variation carries realism more than colour does.
  - Decals and dirt break up repetition.
- **Interior lighting in Godot.** LightmapGI for indirect light plus reflection probes for every enclosed area, a
  fixed exposure, and a filmic tonemap.
- **Lightmap UV2 is authored in the DCC**, not auto-unwrapped at runtime.

Sources:
- [Level Design Book: environment art](https://book.leveldesignbook.com/process/env-art)
- [80.lv: modular environment with trim sheets](https://80.lv/articles/making-of-a-modular-gothic-environment-with-procedural-systems-trim-sheets-custom-shaders)
- [3D Texel: trim sheets and atlases](https://3dtexel.com/trim-sheets-texture-atlases-the-game-environment-workflow/)
- [Nasty Rodent: environment pipeline and texel density](https://nastyrodent.com/3d-environment-design/)
- [Godot docs: LightmapGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html)
- [Godot docs: reflection probes](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/reflection_probes.html)
- [Godot forum: realistic lighting](https://forum.godotengine.org/t/tutorial-realistic-lighting-in-godot-4/87219)

## 3. Decision: what gives the best result here

| area | decision | why |
|---|---|---|
| room layout | **One Blender scene is the source of truth** (`tools/blender/room/`). It exports `assets/room/room.glb` with a hierarchy: static architecture, furniture, moving parts with pivots at hinges and rails, `-colonly` collision proxies, and `IA_*` interaction volumes. `home.gd` only loads it and binds behaviour by node names. | One place to edit; no hidden duplicates; Blender's lightmap UV2 is used as is. |
| hard-surface props (furniture, doors, PC, printer, bench, boxes) | **Hand-authored Blender Python at hero quality.** Real sizes from the photos; bevels and weighted normals; secondary details as real geometry; materials from the scanned library. | Exact, editable, clean shading; the "iPhone scan" look disappears. |
| organics (plants, clothes, cushions, curtains, bedding) | **Hybrid3D:** a procedural base plus a generated part (TRELLIS.2), checked with an edit contract and in Godot. Cloth (curtains, blanket, clothes on the stand) is simulated with Blender cloth. | AI where shape is free-form; physics where cloth must hang right; never AI for boxes. |
| surface materials | **CC0 photo-scanned PBR** (Poly Haven / ambientCG): wood, laminate, fabric, plaster, metal, plastic. **Custom textures** (wallpaper, rug, curtain, bedding, packaging art) made with GPT Image from photo crops, then made seamless. A trim sheet for mouldings. | Real micro-detail and roughness; looks like the real room. |
| packaging | Box **constructions** in Blender (tuck box, lid-and-base, sleeve, switch tube or tray, ESD bag, zip bag, jar). Front and side **art made with GPT Image** in the style of the real brand each parody stands for. | The unboxing is the TikTok moment; it has to read as real retail packaging. |
| lighting | Window sun plus sky as the key light; the chandelier as several emitting bars; fixed exposure per time of day with no auto-adaptation; AgX tonemap; a reflection probe per zone (bench, PC, bed, wardrobe, door); lightmap rebaked on the new geometry. | Contrast and depth instead of a flat grey haze. |
| budgets | Room total under 1.2M tris visible; hero props 5–30k tris with LOD; textures 2K per prop family; texel density 512 px/m on architecture and 1024 px/m on bench/packaging. | Studio practice; keeps 60+ fps on mid GPUs. |

## 4. Phases
1. **Foundation.**
   - Material library (scanned CC0 plus custom wallpaper and rug).
   - Blender room-scene framework: export, sockets and collisions, and a Godot loader.
   - `.gdignore` for `art/`.
2. **Architecture.**
   - Shell to the photo proportions: 3-tier tray ceiling, crown mouldings on a trim sheet, skirting, window reveal with
     radiator and sill.
   - Ornate door with pediment and casing, animated.
3. **Hero furniture.**
   - Wardrobe: real interior with shelves, a rail and sockets for items; doors animated, interior lit on opening.
   - Bookshelf with real books, chest with opening drawers, bed with cloth bedding, L-desk and bench.
   - PC, printer, ring light, speaker, AC, projector screen, chair.
4. **Packaging and parcels.**
   - A market style guide per category.
   - GPT Image art, Blender box constructions, wiring by catalog id.
5. **Organics via Hybrid3D:** plants in pots, clothes on the valet stand, curtains.
6. **Lighting and post.**
   - Exposure, tonemap, probes, rebaked lightmap.
   - Decals: dust, scuffs, cables.
7. **Verification:** the same camera set before and after, performance numbers, and the end-to-end test.
