import json, subprocess, os, re, sys
from fs_search import search
WANT = {
 # long typing recordings to segment into keystrokes
 "kb_mxbrown_majod":400167, "kb_mxbrown_nick":432432, "kb_mxblack_leopold":628325, "kb_mxblue_simeon":638035,
 "kb_mxblue_james":400699, "kb_topre_hhkb":546165, "kb_whitefox":546167, "kb_omnikey":685984,
 "kb_humi_2":412924, "kb_humi_4":412926, "kb_single_5ro4":609534, "kb_treble":450282, "kb_mxbrown_seth":618064,
 # spacebars / big keys (stabilizer sound, rattle)
 "sp_bt_cabled":494398, "sp_tap_green":350935, "sp_zavadil":796112, "sp_uber":421582, "sp_keychron":789630,
 "sp_lego":389512, "sp_moody":741585, "sp_mash":724419, "en_cabled":493676, "en_alpine":627647,
 # springs / hollow / rattle
 "spr_batt2":472477, "spr_batt1":472478, "spr_flick":323372, "spr_bounce":434335, "ping_tiny":266947,
 "hol_bucket_a":825102, "hol_bucket_b":825107, "hol_bucket_c":825110, "hol_bucket_d":825112,
 "rat_plastic":441349, "rat_beskhu":273900,
 # foley
 "fx_clipin":151778, "fx_psnap":686167, "fx_zip":767049, "fx_click1":63531, "fx_click2":63532, "fx_pmouse":734219,
 "fx_btnplastic":545527, "fx_scr_pick":637812, "fx_scr_seq":579554, "fx_scr_taps":435814,
 "fx_sizzle_s":478800, "fx_sizzle":569609, "fx_brush":650357, "fx_brush1":487810,
 "fx_coins2":223342, "fx_coin010":847340, "fx_coinhand":847350, "fx_coins05":336571,
 "fx_register":209578, "fx_drawer_receipt":202531, "fx_box_open":561012, "fx_box_tape":708197, "fx_box_rustle":334216,
 "fx_tape":466211, "fx_drawer":245782, "fx_whoosh_little":423799, "fx_whoosh_mid":449996, "fx_whoosh":459941,
 "fx_lamp":395125, "fx_flash_btn":557509, "fx_bell":452379, "fx_mouse":534104,
}
os.makedirs("raw", exist_ok=True)
# resolve preview urls via sound pages
ok=0
for name, sid in WANT.items():
    out = "raw/%s.mp3" % name
    if os.path.exists(out) and os.path.getsize(out) > 1000: ok+=1; continue
    h = subprocess.run(["curl","-sSL","-m","25","https://freesound.org/s/%d/" % sid],capture_output=True,text=True).stdout
    m = re.search(r'https://cdn\.freesound\.org/previews/[0-9]+/%d_[0-9]+-hq\.mp3' % sid, h) or re.search(r'https://cdn\.freesound\.org/previews/[0-9]+/%d_[0-9]+-lq\.mp3' % sid, h)
    lic = "Creative Commons 0" in h or "creativecommons.org/publicdomain/zero" in h
    if not m: print("NO URL", name, sid); continue
    url = m.group(0).replace("-lq.mp3","-hq.mp3")
    subprocess.run(["curl","-sSL","-m","60","-o",out,url])
    t = re.search(r'<title>([^<]+)</title>', h)
    print("%-20s %7d cc0=%s %6dB  %s" % (name, sid, lic, os.path.getsize(out) if os.path.exists(out) else 0, (t.group(1) if t else "")[:60]))
    ok+=1
print("ok", ok, "/", len(WANT))
