# Packaging of keyboard components: market study and our parody brands

Every catalog brand is a slightly altered real brand (Keychorn ← Keychron, Gateran ← Gateron, GNK ← GMK …). The packaging
copies the *language* of the prototype — material, colour, layout, what is printed where — so a player who knows the
hobby recognises it at a glance, without using real logos or names. Data: `data/packaging.json`; constructions:
`tools/blender/kit/packaging.py` → `assets/models/pack/`; artwork (GPT Image) → `assets/tex/pack/<art>.jpg`.

## How the real market packs things
| category | what real products ship in | typical print | ASMR moment |
|---|---|---|---|
| premium cases (Keychron Q, Mode, Rama) | rigid two-piece box (lid over base), foam insert, case in a dust/poly bag | black or off-white board, line drawing or huge model number, tiny logo | lid sliding off with air resistance, foam out |
| budget / kit cases (KBDfans Tofu, KBD67) | brown corrugated mailer, foam | black stamped logo + a sticker label with model/colour | tape cut, flaps, foam |
| enthusiast PC cases (NovelKeys NK65) | white printed box | big bold model name, playful colour shapes | lid off, bag slide |
| keycap sets (GMK, ePBT, SP, KAT/MT3) | long rigid box, 1-2 vacuum-formed trays | white box with wordmark + set label/render strip (GMK), colour stripes (ePBT), red oval (SP), black with illustrated band (KAT/MT3) | lid off, tray lift, caps rattling in the tray |
| mass switches (Cherry, Gateron, Akko) | small printed carton of 35/45/70, plastic tube or tray | Cherry: white + black wordmark + colour band; Gateron: yellow/black, switch window; Akko: pastel illustration | carton tuck flap, tube slide |
| boutique switches (Holy Panda, Alpaca, Boba, Tangerine…) | zip-lock bag with a round colourful sticker | indie illustrated sticker, name, spring weight | zip opening, shaking the switches |
| stabilizers (Durock, TX, Cherry) | clamshell or zip bag with a card insert | black card with wordmark + line drawing | clamshell click |
| PCBs | silver ESD shielding bag inside a thin white box | ESD warning sticker, board name | bag tear strip, PCB slide |
| plates | thin white box / bubble sleeve | sticker: material, layout | protective film peel |
| lube (Krytox 205g0) | small white jar | white label, red band, "205g0" | lid twist |
| films, foam, tape | clear bag with a header card | header card print | bag rustle |

## Our brands → template
| our brand (catalog) | prototype | construction | template |
|---|---|---|---|
| Keychorn Q1 | Keychron Q1 | case_box | `keychorn` (black, line drawing) |
| KDBfans Tofo, KDB67 Lite | KBDfans Tofu65, KBD67 Lite | kraft_box | `kdbfans` (kraft + label) |
| NovelKays NK65 Ice | NovelKeys NK65 | case_box | `novelkays` |
| Mod Sonet | Mode Sonnet | case_box | `modsonet` (charcoal + gold) |
| Ramma M65-T | Rama M65 | case_box | `ramma` (off-white minimal) |
| Kelovna Walnut | Glorious/Kelowna wood | kraft_box | `kelovna` |
| clear acrylic case | generic acrylic | case_box | `acrylic` |
| GNK * | GMK | keycap_box | `gnk` |
| ePTB * | ePBT | keycap_box | `eptb` |
| SP * | Signature Plastics | keycap_box | `sp` |
| KAT / MT3 / XDA * | Keyreative KAT, Drop MT3 | keycap_box | `kat` |
| Cherri MX * | Cherry MX | switch_box | `cherri` (band recoloured to the stem colour) |
| Gateran * | Gateron | switch_box | `gateran` |
| Akco Lavender | Akko | switch_box | `akco` |
| Holy Pando, Alpacca, Gazew Boba, Tangerin, Zealent, NovelKays Cream, Durok Polaris, Wootin Lekkr … | boutique | switch_bag | `boutique` sticker |
| Cherri / Durok V2 / TK stabs | Cherry, Durock, TX | stab_pack | `stab` |
| DZ6O / GN60 / Keychorn PCB | DZ60 / GH60 | esd_pcb | `pcb_label` |
| plates (FR4, aluminium, …) | generic | plate_sleeve | `plate_label` |
| lube 205g0 | Krytox 205g0 | jar | `kritoks` |
| films, foam, tape | generic | poly_bag | `boutique` header |
