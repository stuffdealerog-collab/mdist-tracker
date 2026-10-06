# The keyboard at hero quality: spec and plan (track B1 of roadmap.md)

The keyboard is the hero object: it is built, pressed, filmed for TikTok. Today it is code-built
(`scripts/keyboard3d.gd`, `scripts/meshgen.gd`): a fair approximation of keycap sculpts, but no cap interior, generic
switch boxes, a plate drawn by a texture, and ~7 nodes per key (≈480 for a 65%, ≈3000 objects with shadow passes).

## Goal
Every part modelled in Blender to real dimensions (same kit as the room: bevels, weighted normals, named material
slots), exported in **key units** (1 u = 19.05 mm, Y up, Z towards the typist — the frame Keyboard3D already uses) so
the game swaps meshes without touching the assembly logic (`asm.gd`, press/insert animations).

## Real dimensions used (mm; ÷19.05 for key units)
| item | value | source |
|---|---|---|
| key pitch | 19.05 | standard |
| keycap bottom 1u | 18.1 × 18.1 (skirt), wall ~1.3-1.5 | common spec |
| stem socket | cross 4.1 × 1.3 slot, post Ø 5.5 | MX standard |
| plate | 1.5 thick, switch cut-out 14.0 × 14.0, corner r ≤ 0.3 | Cherry datasheet |
| plate top → PCB top | 5.0 | Cherry datasheet |
| PCB | 1.6 thick | standard |
| MX top housing | 15.6 × 15.6 at the base, ~6.3 high above the plate | MX drawings |
| stem top at rest | ~11.6 above the plate; travel 4.0 (pre-travel 2.0, Blue 2.2) | Cherry |
| stabilizer spacing | 2u/2.25u/2.75u: 23.8 (11.9 each side); 6.25u: 100 (50 each side); 7u: 114.3 | standard |
| 6.25u spacebar | 119.06 wide | standard |

Row heights at the keycap's tallest point (sculpt R1 → R4):
| profile | R1 | R2 | R3 (home) | R4 | top / dish |
|---|---|---|---|---|---|
| Cherry | 9.4 | 7.9 | 6.6 | 6.3 | cylindrical dish, small top, sharp-ish skirt |
| OEM | 11.9 | 10.6 | 9.5 | 9.3 | cylindrical dish |
| SA | 16.5 | 14.9 | 13.5 | 13.5 | spherical dish, rounded "bowl" top |
| MT3 | 14.6 | 13.6 | 13.0 | 13.6 | deep spherical dish, tall rounded top |
| KAT | 13.5 | 12.0 | 11.0 | 11.6 | spherical, between SA and Cherry |
| XDA | 9.1 uniform | | | | spherical, large flat-ish top |
(Cherry/OEM/SA/XDA: [keycapcompare.com chart](https://keycapcompare.com/posts/keycap-profile-height-chart/),
[keebdepot](https://keebdepot.com/guides/keycap-profiles-compared); MT3/KAT home/tallest rows from the same sources,
intermediate rows interpolated.)

## Asset matrix (what Blender exports)
| part | variants | file |
|---|---|---|
| keycaps | 6 profiles × sculpt rows (4; XDA 1) × widths {1, 1.25, 1.5, 1.75, 2, 2.25, 2.75, 6.25} — surfaces: 0 = sides + interior (stem post), 1 = top with UV 0..1 for the legend atlas | `assets/kb/caps_<profile>.glb`, nodes `cap_r<row>_<w>` |
| switch | MX: bottom housing (pins, clips), top housing (LED window, logo boss), stem (cross, rails), spring (visible through clear tops); box-stem variant | `assets/kb/switch_mx.glb` |
| stabilizers | plate-mount and screw-in housings, stems, wires for 2u spacing and 6.25u | `assets/kb/stabs.glb` |
| plate | per layout (60/65/75/TKL/full): real cut-outs (switch + stab), screw holes, gasket tabs | `assets/kb/plate_<layout>.glb` |
| PCB | per layout: hot-swap sockets or solder pads, diodes, SMD RGB LEDs, MCU, USB-C, silkscreen | `assets/kb/pcb_<layout>.glb` |
| cases | 8 shapes (c_abs … c_ti, their bezel / radius / chamfer / angle / two-tone / knob / acrylic layers) × 5 layouts | `assets/kb/case_<id>_<layout>.glb` |

Budgets: 1u cap ≤ 1.2k tris (LOD 300), switch ≤ 2k (LOD 400), 65% board total ≤ 250k tris at LOD0.

## Game side (Keyboard3D)
1. A `KbParts` loader returns meshes by key (`cap|sa|2|1.25`, `switch_mx`, `plate|l65` …), with MeshGen as the fallback
   while assets are missing.
2. Fewer nodes per key: housing = 1 MeshInstance (2 surfaces), stem = 1 (it animates), cap = 1. That is 7 → 3 nodes
   per key.
3. The cap shader stays (instance parameters: colour, legend index, roughness).
4. Plate and PCB become real meshes (no holes texture); the PCB keeps hot-swap sockets visible during assembly.

## Order
1. `tools/blender/kit/kbd_spec.py`: all numbers above as data (done with this document).
2. Keycaps (6 profiles): generator written (`tools/blender/kit/kbd_caps.py`), not run yet (GPU busy) → review renders against reference photos → Godot swap.
3. Switch + stabs → swap; node count measured before/after.
4. Plate + PCB per layout → swap.
5. Cases → swap; close-up shots for the TikTok photo mode.
