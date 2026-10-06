# Keyboard Seller Simulator: roadmap

Status 2026-10-06. Detailed notes: `art_review.md` (graphics), `packaging.md` (packaging).

## Where we are
**Done and verified (the end-to-end flat test passes):**
- **Core loop:**
  - parts ordered in advance arrive as courier boxes at the door;
  - ASMR unboxing on the bench;
  - storage in the wardrobe;
  - building and repair;
  - manual packing into the brand box;
  - the courier picks it up.
- **KeyOS on the PC, the phone, the day/night clock, sleep.**
- **The flat:** rebuilt from the photos as one Blender scene (models, materials, wallpaper, ceiling, window with a view,
  doors / wardrobe / drawer animations, interior light in the wardrobe).
- **Light:**
  - window skylight, zone reflection probes, the view out of the window by day and by night;
  - lightmaps baked for day and night (used on Medium/Low).
- **Packaging:**
  - 10 Blender constructions;
  - brand templates GNK, Keychorn, Cherri, Gateran, Akco, boutique sticker, NovelKays, Ramma;
  - prints also on the unboxing packages.

**Open gaps:**
- **Progression has no places.** The data has garage → loft → studio → boutique → flagship, but buying a place no
  longer changes where you play: you always stay in the flat.
- **Packaging templates.** 10 are still missing, generated via GPT Image.
- **Plants:** Hybrid3D (generated foliage) is not done.
- **Performance:**
  - heavy cloth meshes;
  - up to ~3,000 objects in the bench shot — not confirmed which ones, most likely the keyboard on the bench.
- **The keyboard (the hero object)** is still code-built (`Keyboard3D`/`MeshGen`) and has not had a quality pass like
  the room.

## Tracks

### A. The flat: finish the look (1-2 sessions; needs the GPU)
1. **Remaining packaging templates.** Run them one at a time through the bridge (it loses focus otherwise).
2. **Plants and clothes via Hybrid3D.** Generated foliage seated in the exact procedural pot. Executor extension: a
   "pot + foliage" family, i.e. a solid blockout and a seat on the soil.
3. **Optimisation:**
   - cloth after simulation goes through decimate, plus LODs;
   - the books merged with shared materials;
   - check which objects make the ~3,000 count;
   - measured fps on Medium/High.
4. **Decals and wear:**
   - dust on top surfaces, scuffs near the bench, cables behind the PC;
   - a light tint on the ceiling around the chandelier.
5. **Daytime look:**
   - colour grading (AgX + a light LUT);
   - fixed exposure per time of day;
   - God rays from the window via volumetric fog.

### B. The keyboard and the ASMR (the TikTok moment) — highest player value
1. **Hero-quality keyboard parts in Blender.** Keycaps per profile (Cherry, SA, MT3, XDA, KAT) with real sculpt and
   legends, switch housings, stabilizers, plates with cut-outs, PCB with components, cases. Built as instances, so it
   stays cheap.
2. **Unboxing animations at the hands' level.** The knife on the tape, peeling the film, tearing the ESD bag, sliding
   the tray out. Sounds are already recorded.
3. **Close-up camera / "photo mode"** for building and packing (TikTok-ready shot).

### C. Progression: office and boutique (the original idea: flat → office → boutique)
1. **Each place is its own Blender scene** with the same kit and rules:
   - Office: an open-space corner with racks and a large workbench.
   - Boutique: a shop window, display cases, a counter, customers.
2. **The move:** buying a place in KeyOS → a "move" cut-scene → the new location. The flat stays as home (sleeping /
   evenings).
3. **Boutique gameplay:**
   - showcase layout (what is on display affects demand);
   - in-person customers;
   - checkout.

### D. Technical and release
- Commits after each completed block; clean up `art/` (now gdignored).
- Steam: icon (rcedit), achievements, build. Steam instructions already exist.
- Perf budget: 60 fps on a mid GPU (RTX 3060 / RX 6600) at Medium.

## Decisions (2026-10-06)
- No deadline, the goal is quality: go through the plan in order, without rushing toward a release.
- Next big block after the packaging and perf: **B1 — the keyboard at hero quality**.

## Proposed order
1. **A1 + A3** (finish the packaging, perf).
2. **B1** (keyboard at hero quality).
3. **C** (office → boutique).
4. **B2/B3, A2/A4/A5** in parallel as polish.
5. **D** before each public build.
