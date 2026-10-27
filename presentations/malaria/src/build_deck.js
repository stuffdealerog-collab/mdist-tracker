// Builds output/Malaria_Group_Presentation.pptx
//   node src/build_deck.js            needs every photo in assets/images (see gen_images.py)
//   node src/build_deck.js --draft    layout check only: missing photos become dark placeholders
const fs = require("fs");
const path = require("path");
const sharp = require("sharp");
const JSZip = require("jszip");
const pptxgen = require("pptxgenjs");
const Lu = require("react-icons/lu");
const L = require("./lib");
const content = require("./content.json");

const DRAFT = process.argv.includes("--draft");
const OUT = path.join(L.ROOT, "output", DRAFT ? "DRAFT_layout_check.pptx" : "Malaria_Group_Presentation.pptx");
const W = 13.333, H = 7.5, M = 0.6, TOTAL = content.slides.length;
const C = { ink: "F4ECE8", muted: "C9B2AE", dim: "9C8380", red: "E5333D", crimson: "B01C2C", card: "1C080B", line: "7A3038", bg: "0A0405" };
const SP = content.speakers;
const FONT = "Arial";

// ---------- display type (rendered to PNG in Archivo Expanded) ----------
const D_SPECS = {
  title_main: { text: "Malaria", size: 104, grad: true },
  title_sub: { text: "An ancient parasite,\na modern fight", size: 21, lh: 1.15, color: "#F4ECE8" },
  thanks: { text: "Thank you", size: 88, grad: true },
  thanks_sub: { text: "for your attention", size: 22, color: "#F4ECE8" },
};
const TITLES = { 2: "Outline", 3: "What is malaria?", 4: "How deadly is it?", 5: "First records", 6: "The great discoveries", 7: "Major outbreaks", 8: "Malaria today", 9: "The numbers are rising", 10: "Malaria can be defeated", 11: "The vaccine", 12: "Prevention", 13: "Treatment", 14: "Conclusion", 16: "References" };
for (const [n, t] of Object.entries(TITLES)) D_SPECS[`t${n}`] = { text: t, size: 38, grad: true };
const num = (id, text, size = 34, color = "#E5333D", extra = {}) => (D_SPECS[id] = { text, size, color, ...extra });
["01", "02", "03", "04", "05"].forEach((t, i) => num(`o${i}`, t, 34));
num("disc3", "Not a virus.\nNot a bacterium.\nA parasite.", 21, "#FFFFFF", { align: "center", lh: 1.12 });
num("disc4", "Time\nsaves\nlives", 19, "#FFFFFF", { align: "center", lh: 1.05 });
num("disc10", "Malaria-\nfree since\n2018", 17, "#FFFFFF", { align: "center", lh: 1.08 });
num("d4a", "10–15", 38); num("d4b", "24", 38); num("d4c", "≈100%", 38);
["China", "Egypt", "Greece", "Italy"].forEach((t, i) => num(`r${i}`, t, 24, "#F4ECE8"));
num("y1880", "1880", 38); num("y1897", "1897", 38); num("y1898", "1898", 38);
num("ob0", "80,000", 32); num("ob1", "150,000", 32); num("ob2", "×4", 32); num("ob3", "+5 M", 32);
num("big282", "282 million", 54, "#F4ECE8", { grad: true });
num("s610", "610,000", 27); num("s9495", "94% · 95%", 27); num("s34", "3 of 4", 27);
num("deaths9", "578,000 → 610,000", 22, "#F4ECE8");
num("p42", "42%", 26, "#F4ECE8");
num("g23", "2.3 bn", 30); num("g14", "14 M", 30); num("g47", "47 + 1", 30);
["1961", "2005", "2010", "2018"].forEach((t) => num(`u${t}`, t, 19, "#F4ECE8"));
num("vRTSS", "RTS,S", 30, "#F4ECE8"); num("vR21", "R21", 30, "#F4ECE8");
num("v13", "−13%", 30); num("v24", "24", 30);
["1600s", "1820", "1970s", "Today"].forEach((t) => num(`tr${t}`, t === "Today" ? "TODAY" : t, 18, "#F4ECE8", { case: "none" }));
["01", "02", "03", "04"].forEach((t, i) => num(`c${i}`, t, 30));
num("motto", "Block the bite · Test early · Treat fast", 24, "#F4ECE8", { grad: true });

let D, ASSET;

// ---------- small helpers ----------
let seq = 0;
const fx = (effect, label, step = 1) => { seq += step; return `fx:${seq}:${effect}:${label}`; };
const same = (effect, label) => `fx:${seq}:${effect}:${label}`; // animate together with the previous element

function txt(s, text, o) {
  s.addText(text, {
    fontFace: FONT, fontSize: 14, color: C.ink, margin: 0, valign: "top", isTextBox: true, fit: "none",
    ...o,
  });
}
function card(s, x, y, w, h, o = {}) {
  s.addShape("roundRect", {
    x, y, w, h, rectRadius: 0.09,
    fill: { color: o.fill || C.card, transparency: o.transparency ?? 22 },
    line: { color: o.lineColor || C.line, width: o.lineWidth || 0.75 },
    objectName: o.name,
  });
}
function pill(s, text, x, y, o = {}) {
  const w = o.w || 0.5 + text.length * 0.104;
  s.addShape("roundRect", { x, y, w, h: 0.3, rectRadius: 0.15, fill: { color: o.fill || C.bg, transparency: o.fill ? 0 : 35 }, line: { color: o.lineColor || C.line, width: 0.75 }, objectName: o.name });
  txt(s, text, { x, y, w, h: 0.3, fontSize: 10, bold: true, charSpacing: 1.5, color: o.color || C.muted, align: "center", valign: "middle", objectName: o.textName });
  return w;
}
function disp(s, id, x, y, o = {}) {
  const d = D[id];
  const scale = o.scale || 1;
  const w = d.w * scale, h = d.h * scale;
  const px = o.align === "center" ? x - w / 2 : o.align === "right" ? x - w : x;
  const py = o.valign === "middle" ? y - h / 2 : y;
  s.addImage({ path: d.file, x: px, y: py, w, h, altText: D_SPECS[id].text.replace(/\n/g, " "), objectName: o.name });
  return { x: px, y: py, w, h };
}
function diamonds(s, x, y, o = {}) {
  txt(s, "◆  ◆  ◆", { x, y, w: 1.2, h: 0.2, fontSize: 7, color: o.color || C.red, align: o.align || "left", objectName: o.name });
}
function bg(s, key, o = {}) {
  s.background = { color: C.bg };
  const box = o.box || { x: 0, y: 0, w: W, h: H };
  s.addImage({ path: ASSET.bg[key], ...box, altText: o.alt || key, objectName: "!!bg" });
  s.addImage({ path: ASSET.shade[o.shade || "L"], x: 0, y: 0, w: W, h: H, altText: "", objectName: "!!shade" });
}
function iconCircle(s, key, x, y, d, name) {
  s.addShape("ellipse", { x, y, w: d, h: d, fill: { color: C.crimson }, line: { color: "E7626B", width: 0.75 }, objectName: name });
  const i = d * 0.56;
  s.addImage({ path: ASSET.icon[key], x: x + (d - i) / 2, y: y + (d - i) / 2, w: i, h: i, altText: key, objectName: name && name.replace(":icon", ":iconimg") });
}
function discAt(s, x, y, d, textId) {
  s.addImage({ path: ASSET.disc, x, y, w: d, h: d, altText: "Red blood cell", objectName: "!!disc" });
  if (textId) disp(s, textId, x + d / 2, y + d / 2, { align: "center", valign: "middle", name: fx("zoom", "disctext") });
}
// Shared frame for content slides: section pill, title, crest, footer with source and speaker.
function frame(s, n, section, who, source) {
  pill(s, section, M, 0.45, { name: "!!pill", textName: "!!pilltext" });
  disp(s, `t${n}`, M - 0.03, 0.9, { name: "!!title" });
  s.addImage({ path: ASSET.logo.crest, x: W - M - 0.42 * ASSET.logo.crestRatio, y: 0.42, w: 0.42 * ASSET.logo.crestRatio, h: 0.42, altText: "MDIS Tashkent crest", objectName: "!!crest" });
  if (source) txt(s, `Source: ${source}`, { x: M, y: 6.98, w: 8.6, h: 0.28, fontSize: 10, color: C.dim, valign: "middle" });
  const label = who ? `${SP[who].short.toUpperCase()}   ·   ${String(n).padStart(2, "0")} / ${TOTAL}` : `${String(n).padStart(2, "0")} / ${TOTAL}`;
  txt(s, label, { x: W - M - 4.2, y: 6.98, w: 4.2, h: 0.28, fontSize: 10, color: C.muted, bold: true, charSpacing: 1, align: "right", valign: "middle" });
}
function notes(s, sl) {
  s.addNotes(sl.notes.map((b) => (b.silent ? b.text : `[${SP[b.who].short}]\n${b.text}`)).join("\n\n"));
}

// ---------- assets ----------
const IMAGES = ["hero_mosquito", "blood_cells", "night_mosquito", "hourglass", "ancient_scroll", "microscope", "world_map", "africa_dusk", "smoke", "samarkand", "vaccine", "bed_net", "artemisia", "dawn"];

async function placeholder(key) {
  const file = path.join(L.BUILD, `placeholder_${key}.png`);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080"><defs><radialGradient id="g" cx="0.72" cy="0.5" r="0.6"><stop offset="0" stop-color="#5a1018"/><stop offset="1" stop-color="#0a0405"/></radialGradient></defs><rect width="1920" height="1080" fill="url(#g)"/><text x="1400" y="560" fill="#ffffff" fill-opacity="0.25" font-size="44" font-family="Arial" text-anchor="middle">PLACEHOLDER: ${key}</text></svg>`;
  await sharp(Buffer.from(svg)).png().toFile(file);
  return file;
}

async function prepareAssets() {
  const bgs = {};
  for (const k of IMAGES) {
    let src = path.join(L.ROOT, "assets/images", `${k}.png`);
    if (!fs.existsSync(src)) {
      if (!DRAFT) throw new Error(`Missing assets/images/${k}.png — run: python3 src/gen_images.py`);
      src = await placeholder(k);
    }
    bgs[k] = await L.background(src, k, k === "smoke" ? { darken: 0.7 } : {});
  }
  const shade = { L: await L.shade("L", "L"), Lsoft: await L.shade("Lsoft", "L", 0.85), full: await L.shade("full", "full") };
  const icon = {
    net: await L.icon(Lu.LuBed, "net"), spray: await L.icon(Lu.LuSprayCan, "spray"), pill: await L.icon(Lu.LuPill, "pill"),
    shield: await L.icon(Lu.LuShieldCheck, "shield"), test: await L.icon(Lu.LuTestTube, "test"), alert: await L.icon(Lu.LuTriangleAlert, "alert"),
  };
  const portraits = {};
  for (const p of ["laveran", "ross", "grassi"]) portraits[p] = await L.portrait(path.join(L.ROOT, "assets/portraits", `${p}.jpg`), p);
  return { bg: bgs, shade, icon, portraits, disc: await L.disc(), logo: await L.logo() };
}

// ---------- slides ----------
function slideTitle(s, sl) {
  bg(s, "hero_mosquito", { alt: "Macro photo of a female Anopheles mosquito against a red moon" });
  const lw = 0.5 * ASSET.logo.fullRatio;
  s.addImage({ path: ASSET.logo.full, x: M, y: 0.55, w: lw, h: 0.5, altText: "MDIS Tashkent logo", objectName: "!!logo" });
  pill(s, content.course.toUpperCase(), M, 1.42, { name: fx("fade", "pill"), textName: same("fade", "pilltext") });
  disp(s, "title_main", M - 0.08, 1.85, { name: "!!title" });
  disp(s, "title_sub", M, 3.55, { name: fx("up", "sub") });
  diamonds(s, M, 4.42, { name: same("up", "dia") });
  const keys = ["J", "M", "R", "A"], cw = 2.85, gap = 0.2;
  keys.forEach((k, i) => {
    const x = M + i * (cw + gap), y = 5.3, sp = SP[k];
    const parts = sp.full.split(" ");
    card(s, x, y, cw, 1.32, { name: fx("up", `card${k}`) });
    txt(s, parts.slice(0, 2).join(" ").toUpperCase(), { x: x + 0.2, y: y + 0.18, w: cw - 0.4, h: 0.5, fontSize: 12, bold: true, charSpacing: 0.5, objectName: same("up", `n${k}`) });
    txt(s, parts.slice(2).join(" "), { x: x + 0.2, y: y + 0.62, w: cw - 0.4, h: 0.26, fontSize: 11, color: C.muted, objectName: same("up", `p${k}`) });
    txt(s, sp.id, { x: x + 0.2, y: y + 0.92, w: cw - 0.4, h: 0.26, fontSize: 11, bold: true, color: C.red, charSpacing: 1, objectName: same("up", `i${k}`) });
  });
}

function slideOutline(s, sl) {
  bg(s, "blood_cells", { alt: "Red blood cells under a microscope" });
  frame(s, 2, "PLAN OF THE TALK", "J");
  const items = [
    ["What is malaria", "Definition, cause and fatality rate", "J"],
    ["History", "First records, discoveries, major outbreaks", "M"],
    ["Malaria today", "Statistics on cases, deaths and damage", "R"],
    ["Fighting back", "Vaccine, prevention and treatment", "A"],
    ["Conclusion", "Key takeaways", "J"],
  ];
  const cw = 2.28, gap = 0.175, y = 2.05, h = 4.45;
  items.forEach(([t, d, k], i) => {
    const x = M + i * (cw + gap);
    card(s, x, y, cw, h, { name: fx("up", `card${i}`), transparency: 30 });
    disp(s, `o${i}`, x + 0.22, y + 0.3, { name: same("up", `num${i}`) });
    txt(s, t.toUpperCase(), { x: x + 0.22, y: y + 1.2, w: cw - 0.44, h: 0.8, fontSize: 15, bold: true, charSpacing: 0.5, objectName: same("up", `t${i}`) });
    txt(s, d, { x: x + 0.22, y: y + 2.0, w: cw - 0.44, h: 1.1, fontSize: 13, color: C.muted, objectName: same("up", `d${i}`) });
    diamonds(s, x + 0.22, y + 3.3, { name: same("up", `dia${i}`) });
    txt(s, SP[k].short.replace(" ", "\n"), { x: x + 0.22, y: y + 3.58, w: cw - 0.44, h: 0.62, fontSize: 12, bold: true, color: C.ink, objectName: same("up", `s${i}`) });
  });
}

function slideWhat(s, sl) {
  bg(s, "night_mosquito", { alt: "Anopheles mosquito silhouetted against a red lamp at night" });
  frame(s, 3, "01 · WHAT IS MALARIA", "J", "World Health Organization (2025a)");
  card(s, M, 1.95, 6.75, 1.32, { name: fx("up", "quote") });
  txt(s, "“A life-threatening disease spread to humans by some types of mosquitoes. The infection is caused by a parasite and does not spread from person to person.”",
    { x: M + 0.25, y: 2.07, w: 6.3, h: 0.85, fontSize: 14, italic: true, color: C.ink, objectName: same("up", "quotetext") });
  txt(s, "WORLD HEALTH ORGANIZATION", { x: M + 0.25, y: 2.93, w: 6.3, h: 0.22, fontSize: 10, bold: true, charSpacing: 2, color: C.red, objectName: same("up", "quotesrc") });
  const cards = [
    ["CAUSE", "A parasite", "Plasmodium, a single-celled organism. Not a virus, not a bacterium."],
    ["CARRIER", "Female Anopheles", "The mosquito bites mostly at night. Parasites go to the liver, then to red blood cells."],
    ["SPECIES", "5 infect humans", "P. falciparum is the deadliest. P. vivax is the most common outside Africa."],
  ];
  const cw = 2.12, gap = 0.19, y = 3.5;
  cards.forEach(([l, hd, b], i) => {
    const x = M + i * (cw + gap);
    card(s, x, y, cw, 2.72, { name: fx("up", `c${i}`) });
    txt(s, l, { x: x + 0.2, y: y + 0.22, w: cw - 0.4, h: 0.24, fontSize: 10, bold: true, charSpacing: 2, color: C.red, objectName: same("up", `l${i}`) });
    txt(s, hd, { x: x + 0.2, y: y + 0.5, w: cw - 0.4, h: 0.7, fontSize: 18, bold: true, objectName: same("up", `h${i}`) });
    txt(s, b, { x: x + 0.2, y: y + 1.25, w: cw - 0.4, h: 1.35, fontSize: 12, color: C.muted, objectName: same("up", `b${i}`) });
  });
  discAt(s, 8.75, 1.75, 3.85, "disc3");
}

function slideDeadly(s, sl) {
  bg(s, "hourglass", { alt: "Hourglass with red sand next to blood sample tubes" });
  frame(s, 4, "01 · WHAT IS MALARIA", "J", "World Health Organization (2025a); World Health Organization (2015)");
  const rows = [
    ["d4a", "DAYS", "until the first symptoms: fever, chills and headache. It looks like the flu."],
    ["d4b", "HOURS", "Left untreated, P. falciparum malaria can progress to severe illness and death."],
    ["d4c", "UNTREATED", "Severe malaria without treatment: deaths approach 100%. With treatment: 10–20%."],
  ];
  rows.forEach(([id, unit, t], i) => {
    const y = 1.95 + i * 1.38;
    card(s, M, y, 6.75, 1.22, { name: fx("up", `r${i}`) });
    disp(s, id, M + 0.25, y + 0.14, { name: same("zoom", `n${i}`) });
    txt(s, unit, { x: M + 0.27, y: y + 0.85, w: 2.2, h: 0.24, fontSize: 10, bold: true, charSpacing: 2, color: C.muted, objectName: same("up", `u${i}`) });
    txt(s, t, { x: M + 2.75, y: y + 0.2, w: 3.8, h: 0.85, fontSize: 13, color: C.ink, valign: "middle", objectName: same("up", `t${i}`) });
  });
  txt(s, [{ text: "The key word is ", options: { color: C.muted } }, { text: "TIME", options: { bold: true, color: C.red } }, { text: ": fast diagnosis saves lives.", options: { color: C.muted } }],
    { x: M, y: 6.18, w: 6.75, h: 0.34, fontSize: 15, italic: true, objectName: fx("fade", "key") });
  discAt(s, 10.0, 4.2, 2.45, "disc4");
}

function slideRecords(s, sl) {
  bg(s, "ancient_scroll", { alt: "Ancient Chinese scroll and Egyptian papyrus lit by an oil lamp" });
  frame(s, 5, "02 · HISTORY", "M", "Cox (2010); Hawass et al. (2010)");
  s.addShape("line", { x: M, y: 3.08, w: W - 2 * M, h: 0, line: { color: C.line, width: 1 }, objectName: fx("wipe", "line") });
  const items = [
    ["c. 2700 BC", "Fevers that keep coming back", "A Chinese medical text describes repeating fevers and an enlarged spleen."],
    ["1570 BC", "Papyri and a pharaoh", "Egyptian papyri describe fevers. In 2010, parasite DNA was found in Tutankhamun’s mummy."],
    ["c. 400 BC", "Hippocrates and the marshes", "He links the fevers to life near marshes and stagnant water."],
    ["THE NAME", "Mal aria = “bad air”", "People blamed the air of the swamps, and the disease got its name."],
  ];
  const cw = 2.9, gap = 0.143;
  items.forEach(([date, hd, b], i) => {
    const x = M + i * (cw + gap);
    disp(s, `r${i}`, x, 2.28, { name: fx("up", `place${i}`) });
    s.addShape("diamond", { x: x + 0.02, y: 3.0, w: 0.16, h: 0.16, fill: { color: C.red }, line: { color: C.red, width: 0 }, objectName: same("zoom", `node${i}`) });
    card(s, x, 3.38, cw, 2.95, { name: same("up", `card${i}`) });
    txt(s, date, { x: x + 0.22, y: 3.6, w: cw - 0.44, h: 0.24, fontSize: 10, bold: true, charSpacing: 2, color: C.red, objectName: same("up", `date${i}`) });
    txt(s, hd, { x: x + 0.22, y: 3.9, w: cw - 0.44, h: 0.72, fontSize: 16, bold: true, objectName: same("up", `hd${i}`) });
    txt(s, b, { x: x + 0.22, y: 4.68, w: cw - 0.44, h: 1.5, fontSize: 12, color: C.muted, objectName: same("up", `b${i}`) });
  });
}

function slideDiscovery(s, sl) {
  bg(s, "microscope", { alt: "19th-century brass microscope with blood slides" });
  frame(s, 6, "02 · HISTORY", "M", "Cox (2010); Nobel Prize Outreach (2026). Portraits: Wellcome Collection, public domain");
  const items = [
    ["laveran", "y1880", "Alphonse Laveran", "A French army doctor in Algeria sees the parasite in the blood of a sick soldier.", "NOBEL PRIZE 1907"],
    ["ross", "y1897", "Ronald Ross", "In India, he finds the parasite inside a mosquito: 20 August, “Mosquito Day”.", "NOBEL PRIZE 1902"],
    ["grassi", "y1898", "Giovanni Battista Grassi", "His Italian team proves that Anopheles mosquitoes carry human malaria.", "ITALY · 1898"],
  ];
  const cw = 3.83, gap = 0.32;
  items.forEach(([p, yid, name, b, tag], i) => {
    const x = M + i * (cw + gap), y = 1.95;
    card(s, x, y, cw, 4.55, { name: fx("up", `card${i}`), transparency: 18 });
    s.addImage({ path: ASSET.portraits[p], x: x + 0.28, y: y + 0.3, w: 1.3, h: 1.3, altText: `Portrait of ${name}`, objectName: same("zoom", `por${i}`) });
    disp(s, yid, x + 1.82, y + 0.55, { name: same("up", `yr${i}`) });
    txt(s, name.toUpperCase(), { x: x + 0.28, y: y + 1.85, w: cw - 0.56, h: 0.5, fontSize: 14, bold: true, charSpacing: 0.5, objectName: same("up", `nm${i}`) });
    txt(s, b, { x: x + 0.28, y: y + 2.4, w: cw - 0.56, h: 1.2, fontSize: 13, color: C.muted, objectName: same("up", `b${i}`) });
    pill(s, tag, x + 0.28, y + 3.88, { name: same("up", `tag${i}`), textName: same("up", `tagt${i}`), color: i < 2 ? C.ink : C.muted, lineColor: i < 2 ? C.red : C.line });
  });
}

function slideOutbreaks(s, sl) {
  bg(s, "world_map", { alt: "Antique globe with red hotspots over Africa and South Asia" });
  frame(s, 7, "02 · HISTORY", "M", "Gill (1935); Fontaine, Najjar and Prince (1961); World Health Organization (2023a; 2025b)");
  const items = [
    ["ob0", "DEATHS", "Ceylon (Sri Lanka) · 1934–35", "After a drought, about 1.5 million people fell ill."],
    ["ob1", "DEATHS", "Ethiopia · 1958", "About 3 million cases in one epidemic."],
    ["ob2", "CASES", "Pakistan · 2022", "After the floods: 400,000 cases (2021) → 1.6 million+ (2022)."],
    ["ob3", "NEW CASES", "3 countries · 2024", "Ethiopia, Madagascar and Yemen added them in one year."],
  ];
  const cw = 3.25, ch = 2.15;
  items.forEach(([id, unit, place, b], i) => {
    const x = M + (i % 2) * (cw + 0.2), y = 1.95 + Math.floor(i / 2) * (ch + 0.2);
    card(s, x, y, cw, ch, { name: fx("up", `card${i}`) });
    disp(s, id, x + 0.22, y + 0.2, { name: same("zoom", `n${i}`) });
    txt(s, unit, { x: x + 0.22, y: y + 0.78, w: 1.6, h: 0.22, fontSize: 10, bold: true, charSpacing: 2, color: C.red, objectName: same("up", `u${i}`) });
    txt(s, place.toUpperCase(), { x: x + 0.22, y: y + 1.07, w: cw - 0.44, h: 0.26, fontSize: 11, bold: true, charSpacing: 1, color: C.ink, objectName: same("up", `p${i}`) });
    txt(s, b, { x: x + 0.22, y: y + 1.38, w: cw - 0.44, h: 0.68, fontSize: 12, color: C.muted, objectName: same("up", `b${i}`) });
  });
}

function slideToday(s, sl) {
  bg(s, "africa_dusk", { alt: "Mother carrying a child through an African village at sunset" });
  frame(s, 8, "03 · MALARIA TODAY", "R", "World Health Organization (2025b), World malaria report 2025");
  disp(s, "big282", M - 0.03, 1.9, { name: fx("zoom", "big") });
  txt(s, "malaria cases in 2024, in 80 countries", { x: M, y: 2.82, w: 6.5, h: 0.36, fontSize: 16, color: C.muted, objectName: same("up", "biglabel") });
  const items = [
    ["s610", "DEATHS IN 2024", "almost 1,700 people every day"],
    ["s9495", "AFRICA", "of all cases · of all deaths"],
    ["s34", "CHILDREN UNDER 5", "of all malaria deaths in Africa"],
  ];
  const widths = [2.25, 2.75, 2.25], gap = 0.18, y = 3.55;
  items.forEach(([id, l, b], i) => {
    const cw = widths[i], x = M + widths.slice(0, i).reduce((t, v) => t + v + gap, 0);
    card(s, x, y, cw, 2.15, { name: fx("up", `c${i}`) });
    disp(s, id, x + 0.2, y + 0.25, { name: same("zoom", `n${i}`) });
    txt(s, l, { x: x + 0.2, y: y + 0.95, w: cw - 0.4, h: 0.24, fontSize: 10, bold: true, charSpacing: 2, color: C.red, objectName: same("up", `l${i}`) });
    txt(s, b, { x: x + 0.2, y: y + 1.25, w: cw - 0.4, h: 0.7, fontSize: 13, color: C.ink, objectName: same("up", `b${i}`) });
  });
  txt(s, [{ text: "5 countries have more than half of all cases: ", options: { color: C.muted } }, { text: "Nigeria · DR Congo · Uganda · Ethiopia · Mozambique", options: { color: C.ink, bold: true } }],
    { x: M, y: 5.95, w: 7.4, h: 0.6, fontSize: 13, objectName: fx("fade", "five") });
}

function slideTrend(s, sl, pres) {
  bg(s, "smoke", { shade: "full", alt: "Dark red smoke texture" });
  frame(s, 9, "03 · MALARIA TODAY", "R", "World Health Organization (2025b)");
  card(s, M, 1.95, 6.85, 4.6, { name: "chartcard", transparency: 30 });
  s.addChart(pres.charts.BAR, [{ name: "Malaria cases, millions", labels: ["2015", "2023", "2024"], values: [230, 273, 282] }], {
    x: M + 0.2, y: 2.05, w: 6.45, h: 4.4, barDir: "col", barGapWidthPct: 55,
    chartColors: ["C8202F"], showLegend: false,
    showTitle: true, title: "Malaria cases worldwide, millions", titleColor: C.ink, titleFontSize: 14, titleFontFace: FONT,
    showValue: true, dataLabelPosition: "outEnd", dataLabelColor: C.ink, dataLabelFontSize: 16, dataLabelFontBold: true, dataLabelFontFace: FONT,
    catAxisLabelColor: C.muted, catAxisLabelFontSize: 14, catAxisLabelFontFace: FONT, catAxisLineShow: false,
    valAxisHidden: true, valAxisMinVal: 0, valAxisMaxVal: 320, valGridLine: { style: "none" }, catGridLine: { style: "none" },
  });
  const x = 7.75, w = W - M - x;
  card(s, x, 1.95, w, 1.95, { name: fx("up", "deaths") });
  txt(s, "DEATHS · 2015 → 2024", { x: x + 0.25, y: 2.15, w: w - 0.5, h: 0.24, fontSize: 10, bold: true, charSpacing: 2, color: C.red, objectName: same("up", "dl") });
  disp(s, "deaths9", x + 0.25, 2.48, { name: same("up", "dn") });
  txt(s, "The death rate per person fell, but the population keeps growing.", { x: x + 0.25, y: 3.08, w: w - 0.5, h: 0.65, fontSize: 12, color: C.muted, objectName: same("up", "db") });
  card(s, x, 4.1, w, 2.45, { name: fx("up", "fund") });
  txt(s, "FUNDING IN 2024", { x: x + 0.25, y: 4.3, w: w - 0.5, h: 0.24, fontSize: 10, bold: true, charSpacing: 2, color: C.red, objectName: same("up", "fl") });
  s.addChart(pres.charts.DOUGHNUT, [{ name: "Funding", labels: ["Invested", "Gap"], values: [3.9, 5.4] }], {
    x: x + 0.1, y: 4.55, w: 1.9, h: 1.9, holeSize: 70, chartColors: ["E5333D", "3A1418"], showLegend: false, showValue: false, showPercent: false, showLabel: false, showTitle: false,
    dataBorder: { pt: 0.5, color: "1C080B" },
  });
  disp(s, "p42", x + 1.05, 5.5, { align: "center", valign: "middle", name: same("zoom", "p42") });
  txt(s, [{ text: "US$ 3.9 bn", options: { bold: true, color: C.ink, breakLine: true } }, { text: "invested", options: { color: C.muted, breakLine: true } }, { text: "US$ 9.3 bn", options: { bold: true, color: C.ink, breakLine: true } }, { text: "needed every year", options: { color: C.muted } }],
    { x: x + 2.15, y: 4.72, w: w - 2.35, h: 1.6, fontSize: 13, valign: "middle", objectName: same("up", "ft") });
}

function slideProgress(s, sl) {
  bg(s, "samarkand", { alt: "Registan square in Samarkand at twilight under a red sky" });
  frame(s, 10, "03 · MALARIA TODAY", "R", "World Health Organization (2018); World Health Organization (2025b)");
  const items = [["g23", "CASES PREVENTED", "since 2000"], ["g14", "DEATHS PREVENTED", "since 2000"], ["g47", "MALARIA-FREE", "countries + territory, WHO-certified"]];
  const cw = 2.28, gap = 0.18;
  items.forEach(([id, l, b], i) => {
    const x = M + i * (cw + gap), y = 1.95;
    card(s, x, y, cw, 1.6, { name: fx("up", `c${i}`) });
    disp(s, id, x + 0.2, y + 0.2, { name: same("zoom", `n${i}`) });
    txt(s, l, { x: x + 0.2, y: y + 0.85, w: cw - 0.4, h: 0.22, fontSize: 10, bold: true, charSpacing: 1.5, color: C.red, objectName: same("up", `l${i}`) });
    txt(s, b, { x: x + 0.2, y: y + 1.1, w: cw - 0.4, h: 0.42, fontSize: 11, color: C.muted, objectName: same("up", `b${i}`) });
  });
  const x0 = M, y0 = 3.75, w0 = 7.2;
  card(s, x0, y0, w0, 2.8, { name: fx("up", "uz") });
  txt(s, "UZBEKISTAN: OUR OWN SUCCESS STORY", { x: x0 + 0.3, y: y0 + 0.22, w: w0 - 0.6, h: 0.26, fontSize: 11, bold: true, charSpacing: 2, color: C.red, objectName: same("up", "uzt") });
  s.addShape("line", { x: x0 + 0.95, y: y0 + 1.25, w: w0 - 1.9, h: 0, line: { color: C.line, width: 1 }, objectName: fx("wipe", "uzline") });
  const steps = [["1961", "First elimination"], ["2005", "Tashkent Declaration"], ["2010", "Last local cases"], ["2018", "WHO certificate, 7 Dec"]];
  const sw = (w0 - 1.9) / 3;
  steps.forEach(([yr, t], i) => {
    const cx = x0 + 0.95 + i * sw;
    s.addShape("ellipse", { x: cx - 0.08, y: y0 + 1.17, w: 0.16, h: 0.16, fill: { color: i === 3 ? C.red : C.ink }, line: { color: C.red, width: 0.75 }, objectName: fx("zoom", `dot${i}`, 0.5) });
    disp(s, `u${yr}`, cx, y0 + 0.62, { align: "center", name: same("up", `yr${i}`) });
    txt(s, t, { x: cx - 0.85, y: y0 + 1.45, w: 1.7, h: 0.5, fontSize: 11, color: C.ink, align: "center", objectName: same("up", `st${i}`) });
  });
  txt(s, [{ text: "Surkhandarya, the most affected province: ", options: { color: C.muted } }, { text: "81 cases in 2007 → 0", options: { bold: true, color: C.ink } }],
    { x: x0 + 0.3, y: y0 + 2.2, w: w0 - 0.6, h: 0.32, fontSize: 12, objectName: fx("fade", "surx") });
  discAt(s, 9.85, 1.25, 2.75, "disc10");
}

function slideVaccine(s, sl) {
  bg(s, "vaccine", { alt: "Vaccine vial and syringe in red light" });
  frame(s, 11, "04 · FIGHTING BACK", "A", "World Health Organization (2021; 2023b; 2025b); University of Oxford (2023)");
  const items = [
    ["vRTSS", "FIRST · WHO 2021", "AS01 · GSK", "30 years of research. Recommended for children in October 2021: “a historic moment”."],
    ["vR21", "SECOND · WHO 2023", "Matrix-M · Oxford", "−75% cases where malaria is seasonal. Cost-effective at US$ 2–4 per dose."],
  ];
  const cw = 3.45, gap = 0.25;
  items.forEach(([id, tag, sub, b], i) => {
    const x = M + i * (cw + gap), y = 1.95;
    card(s, x, y, cw, 3.15, { name: fx("up", `c${i}`) });
    pill(s, tag, x + 0.25, y + 0.25, { name: same("up", `tag${i}`), textName: same("up", `tagt${i}`), color: C.ink, lineColor: C.red });
    disp(s, id, x + 0.22, y + 0.75, { name: same("up", `n${i}`) });
    txt(s, sub.toUpperCase(), { x: x + 0.25, y: y + 1.38, w: cw - 0.5, h: 0.24, fontSize: 10, bold: true, charSpacing: 1.5, color: C.red, objectName: same("up", `s${i}`) });
    txt(s, b, { x: x + 0.25, y: y + 1.72, w: cw - 0.5, h: 1.3, fontSize: 13, color: C.ink, objectName: same("up", `b${i}`) });
  });
  const stats = [["v13", "child deaths from all causes in the pilot: Ghana, Kenya, Malawi"], ["v24", "countries using malaria vaccines by October 2025"]];
  stats.forEach(([id, b], i) => {
    const x = M + i * (cw + gap), y = 5.3;
    card(s, x, y, cw, 1.25, { name: fx("up", `st${i}`) });
    const n = disp(s, id, x + 0.22, y + 0.28, { name: same("zoom", `sn${i}`) });
    txt(s, b, { x: n.x + n.w + 0.2, y: y + 0.18, w: cw - (n.w + 0.64), h: 0.9, fontSize: 12, color: C.muted, valign: "middle", objectName: same("up", `sb${i}`) });
  });
}

function slidePrevention(s, sl) {
  bg(s, "bed_net", { alt: "Child sleeping under a mosquito bed net" });
  frame(s, 12, "04 · FIGHTING BACK", "A", "Bhatt et al. (2015); World Health Organization (2025a; 2025b)");
  const rows = [
    ["net", "Insecticide-treated bed nets", "68% of all cases prevented in Africa, 2000–2015. Sleep under it every night."],
    ["spray", "Indoor spraying", "Insecticide on the inside walls, where mosquitoes rest after they bite."],
    ["pill", "Seasonal medicines for children", "About 54 million African children in each round, 2024."],
    ["shield", "Personal protection", "Repellent, long sleeves, no standing water. Preventive tablets for travellers."],
  ];
  rows.forEach(([ic, hd, b], i) => {
    const y = 1.95 + i * 1.16;
    card(s, M, y, 6.95, 1.02, { name: fx("up", `r${i}`) });
    iconCircle(s, ic, M + 0.22, y + 0.2, 0.62, same("zoom", `r${i}:icon`));
    txt(s, `${i + 1} · ${hd}`.toUpperCase(), { x: M + 1.1, y: y + 0.14, w: 5.65, h: 0.3, fontSize: 13, bold: true, charSpacing: 0.5, objectName: same("up", `h${i}`) });
    txt(s, b, { x: M + 1.1, y: y + 0.46, w: 5.65, h: 0.48, fontSize: 12, color: C.muted, objectName: same("up", `b${i}`) });
  });
}

function slideTreatment(s, sl) {
  bg(s, "artemisia", { alt: "Sweet wormwood, cinchona bark and tablets" });
  frame(s, 13, "04 · FIGHTING BACK", "A", "Achan et al. (2011); World Health Organization (2015; 2025b); Nobel Prize Outreach (2026)");
  card(s, M, 1.95, 6.75, 0.7, { name: fx("up", "test"), lineColor: C.red });
  iconCircle(s, "test", M + 0.16, 2.03, 0.54, same("zoom", "test:icon"));
  txt(s, [{ text: "STEP 1 · TEST FIRST   ", options: { bold: true, color: C.ink, charSpacing: 1 } }, { text: "microscope or rapid diagnostic test", options: { color: C.muted } }],
    { x: M + 0.9, y: 2.07, w: 5.7, h: 0.46, fontSize: 13, valign: "middle", objectName: same("up", "testt") });
  s.addShape("line", { x: M + 0.35, y: 3.05, w: 0, h: 3.25, line: { color: C.line, width: 1 }, objectName: fx("wipe", "vline") });
  const steps = [
    ["1600s", "Cinchona bark from South America is used against fever."],
    ["1820", "Scientists extract quinine from the bark."],
    ["1970s", "Tu Youyou finds artemisinin in sweet wormwood. Nobel Prize 2015."],
    ["Today", "ACT: artemisinin-based combination therapy. Severe malaria: artesunate injection."],
  ];
  steps.forEach(([yr, t], i) => {
    const y = 2.95 + i * 0.86;
    s.addShape("ellipse", { x: M + 0.27, y: y + 0.13, w: 0.16, h: 0.16, fill: { color: i === 3 ? C.red : C.ink }, line: { color: C.red, width: 0.75 }, objectName: fx("zoom", `dot${i}`) });
    disp(s, `tr${yr}`, M + 0.65, y + 0.05, { name: same("up", `yr${i}`) });
    txt(s, t, { x: M + 2.2, y: y, w: 4.55, h: 0.75, fontSize: 13, color: i === 3 ? C.ink : C.muted, objectName: same("up", `t${i}`) });
  });
  const x = 7.95, w = W - M - x, y = 5.05;
  card(s, x, y, w, 1.5, { name: fx("up", "warn"), lineColor: C.red, lineWidth: 1.25, transparency: 10 });
  iconCircle(s, "alert", x + 0.22, y + 0.24, 0.54, same("zoom", "warn:icon"));
  txt(s, "NEW THREAT: DRUG RESISTANCE", { x: x + 0.95, y: y + 0.22, w: w - 1.15, h: 0.26, fontSize: 11, bold: true, charSpacing: 1.5, color: C.red, objectName: same("up", "wt") });
  txt(s, "Partial resistance to artemisinin is confirmed in Eritrea, Rwanda, Uganda and Tanzania.", { x: x + 0.95, y: y + 0.52, w: w - 1.15, h: 0.85, fontSize: 12, color: C.ink, objectName: same("up", "wb") });
}

function slideConclusion(s, sl) {
  bg(s, "dawn", { alt: "African savanna at dawn" });
  frame(s, 14, "05 · CONCLUSION", "J");
  const items = [
    ["A parasite,", " not a virus or a bacterium. Without treatment it can kill within 24 hours."],
    ["Almost 5,000 years", " with humanity, from ancient China to Tutankhamun."],
    ["282 million cases,", " 610,000 deaths in 2024, mostly young children in Africa."],
    ["We know how to win:", " vaccines, bed nets and fast treatment. Uzbekistan is the proof."],
  ];
  const cw = 2.88, gap = 0.17;
  items.forEach(([b, t], i) => {
    const x = M + i * (cw + gap), y = 1.95;
    card(s, x, y, cw, 3.0, { name: fx("up", `c${i}`) });
    disp(s, `c${i}`, x + 0.22, y + 0.25, { name: same("up", `n${i}`) });
    txt(s, [{ text: b, options: { bold: true, color: C.ink } }, { text: t, options: { color: C.muted } }], { x: x + 0.22, y: y + 1.0, w: cw - 0.44, h: 1.85, fontSize: 14, objectName: same("up", `t${i}`) });
  });
  disp(s, "motto", W / 2, 5.4, { align: "center", name: fx("zoom", "motto", 1.5) });
  diamonds(s, W / 2 - 0.6, 5.12, { align: "center", name: same("zoom", "dia") });
  txt(s, "Malaria is preventable and curable.", { x: M, y: 6.1, w: W - 2 * M, h: 0.34, fontSize: 15, italic: true, color: C.muted, align: "center", objectName: fx("fade", "sub") });
}

function slideThanks(s, sl) {
  bg(s, "hero_mosquito", { box: { x: -1.6, y: -0.9, w: 16.5, h: 9.28 }, alt: "Macro photo of a female Anopheles mosquito" });
  const lw = 0.5 * ASSET.logo.fullRatio;
  s.addImage({ path: ASSET.logo.full, x: M, y: 0.55, w: lw, h: 0.5, altText: "MDIS Tashkent logo", objectName: "!!logo" });
  disp(s, "thanks", M - 0.07, 2.0, { name: "!!title" });
  disp(s, "thanks_sub", M, 3.45, { name: fx("up", "sub") });
  diamonds(s, M, 4.15, { name: same("up", "dia") });
  pill(s, "QUESTIONS ARE WELCOME", M, 4.5, { name: same("up", "q"), textName: same("up", "qt"), color: C.ink, lineColor: C.red });
  txt(s, ["J", "M", "R", "A"].map((k) => SP[k].short).join("   ·   "), { x: M, y: 6.55, w: 9.5, h: 0.3, fontSize: 12, color: C.muted, objectName: fx("fade", "names") });
}

function slideReferences(s, sl) {
  bg(s, "smoke", { shade: "full", alt: "Dark red smoke texture" });
  frame(s, 16, "SOURCES · HARVARD STYLE", null);
  const refs = content.references;
  const half = Math.ceil(refs.length / 2);
  [refs.slice(0, half), refs.slice(half)].forEach((col, i) => {
    txt(s, col.map((r, j) => ({ text: r, options: { breakLine: j < col.length - 1, paraSpaceAfter: 6 } })), {
      x: M + i * 6.18, y: 1.85, w: 5.95, h: 5.0, fontSize: 10, color: C.muted, lineSpacingMultiple: 1.0,
    });
  });
}

const BUILDERS = { title: slideTitle, outline: slideOutline, what: slideWhat, deadly: slideDeadly, records: slideRecords, discovery: slideDiscovery, outbreaks: slideOutbreaks, today: slideToday, trend: slideTrend, progress: slideProgress, vaccine: slideVaccine, prevention: slidePrevention, treatment: slideTreatment, conclusion: slideConclusion, thanks: slideThanks, references: slideReferences };
const SECTIONS = { 1: "Javohir · Introduction", 5: "Muhammadrizo · History", 8: "Ramazan · Malaria today", 11: "Akmalbek · Fighting back", 14: "Javohir · Conclusion" };

// ---------- OOXML post-processing: Morph transitions + automatic entrance animations ----------
const NS_P14 = "http://schemas.microsoft.com/office/powerpoint/2010/main";
function transitionXml(n) {
  const dur = n === 1 ? 1600 : 1400;
  return `<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:Choice xmlns:p159="http://schemas.microsoft.com/office/powerpoint/2015/09/main" Requires="p159"><p:transition spd="slow" p14:dur="${dur}"><p159:morph option="byObject"/></p:transition></mc:Choice><mc:Fallback><p:transition spd="slow"><p:fade/></p:transition></mc:Fallback></mc:AlternateContent>`;
}

function effectXml(e, nextId) {
  const id = nextId, t = e.spid, D = e.dur;
  const set = `<p:set><p:cBhvr><p:cTn id="${id()}" dur="1" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst></p:cTn><p:tgtEl><p:spTgt spid="${t}"/></p:tgtEl><p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr><p:to><p:strVal val="visible"/></p:to></p:set>`;
  const fade = `<p:animEffect transition="in" filter="fade"><p:cBhvr><p:cTn id="${id()}" dur="${D}"/><p:tgtEl><p:spTgt spid="${t}"/></p:tgtEl></p:cBhvr></p:animEffect>`;
  const anim = (attr, from, to) => `<p:anim calcmode="lin" valueType="num"><p:cBhvr><p:cTn id="${id()}" dur="${D}" decel="100000" fill="hold"/><p:tgtEl><p:spTgt spid="${t}"/></p:tgtEl><p:attrNameLst><p:attrName>${attr}</p:attrName></p:attrNameLst></p:cBhvr><p:tavLst><p:tav tm="0"><p:val><p:strVal val="${from}"/></p:val></p:tav><p:tav tm="100000"><p:val><p:strVal val="${to}"/></p:val></p:tav></p:tavLst></p:anim>`;
  const kinds = {
    fade: [10, 0, () => set + fade],
    up: [42, 0, () => set + fade + anim("ppt_x", "#ppt_x", "#ppt_x") + anim("ppt_y", "#ppt_y+0.04", "#ppt_y")],
    zoom: [53, 16, () => set + anim("ppt_w", "#ppt_w*0.7", "#ppt_w") + anim("ppt_h", "#ppt_h*0.7", "#ppt_h") + fade],
    wipe: [22, 8, () => set + `<p:animEffect transition="in" filter="wipe(left)"><p:cBhvr><p:cTn id="${id()}" dur="${D}"/><p:tgtEl><p:spTgt spid="${t}"/></p:tgtEl></p:cBhvr></p:animEffect>`],
  };
  const [preset, sub, body] = kinds[e.effect];
  const outer = id();
  return `<p:par><p:cTn id="${outer}" presetID="${preset}" presetClass="entr" presetSubtype="${sub}" fill="hold" grpId="0" nodeType="${e.first ? "afterEffect" : "withEffect"}"><p:stCondLst><p:cond delay="${e.delay}"/></p:stCondLst><p:childTnLst>${body()}</p:childTnLst></p:cTn></p:par>`;
}

function timingXml(items) {
  let n = 4;
  const nextId = () => ++n;
  const effects = items.map((e, i) => effectXml({ ...e, first: i === 0 }, nextId)).join("");
  const bld = items.filter((e) => e.isSp).map((e) => `<p:bldP spid="${e.spid}" grpId="0" animBg="1"/>`).join("");
  return `<p:timing><p:tnLst><p:par><p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot"><p:childTnLst><p:seq concurrent="1" nextAc="seek"><p:cTn id="2" dur="indefinite" nodeType="mainSeq"><p:childTnLst><p:par><p:cTn id="3" fill="hold"><p:stCondLst><p:cond delay="indefinite"/><p:cond evt="onBegin" delay="0"><p:tn val="2"/></p:cond></p:stCondLst><p:childTnLst><p:par><p:cTn id="4" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst>${effects}</p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn><p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst><p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst></p:seq></p:childTnLst></p:cTn></p:par></p:tnLst>${bld ? `<p:bldLst>${bld}</p:bldLst>` : ""}</p:timing>`;
}

async function postProcess(file) {
  const zip = await JSZip.loadAsync(fs.readFileSync(file));
  const slides = Object.keys(zip.files).filter((f) => /^ppt\/slides\/slide\d+\.xml$/.test(f));
  for (const f of slides) {
    const n = Number(f.match(/slide(\d+)\.xml/)[1]);
    let xml = await zip.file(f).async("string");
    const items = [];
    // <p:sp>/<p:pic> ... <p:cNvPr id=".." name="fx:seq:effect:label">
    const re = /<p:(sp|pic)>\s*<p:nv(?:Sp|Pic)Pr>\s*<p:cNvPr id="(\d+)" name="fx:([\d.]+):(\w+):([^"]*)"/g;
    let m;
    while ((m = re.exec(xml))) items.push({ isSp: m[1] === "sp", spid: m[2], seq: Number(m[3]), effect: m[4] });
    items.sort((a, b) => a.seq - b.seq);
    const seqs = [...new Set(items.map((i) => i.seq))];
    items.forEach((it) => {
      const rank = seqs.indexOf(it.seq);
      it.delay = 150 + rank * 130;
      it.dur = it.effect === "wipe" ? 900 : it.effect === "zoom" ? 600 : 550;
    });
    xml = xml.replace(/<p:sld /, `<p:sld xmlns:p14="${NS_P14}" `);
    const tail = transitionXml(n) + (items.length ? timingXml(items) : "");
    if (/<p:transition|<p:timing/.test(xml)) throw new Error(`${f} already has transition/timing`);
    xml = xml.replace("</p:clrMapOvr>", `</p:clrMapOvr>${tail}`);
    zip.file(f, xml);
  }
  fs.writeFileSync(file, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
}

// ---------- main ----------
(async () => {
  ASSET = await prepareAssets();
  D = await L.renderDisplay(D_SPECS);
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE";
  pres.title = "Malaria: an ancient parasite, a modern fight";
  pres.author = Object.values(SP).map((s) => s.short).join(", ");
  pres.company = "MDIS Tashkent";
  pres.theme = { headFontFace: FONT, bodyFontFace: FONT };
  for (const sl of content.slides) {
    if (SECTIONS[sl.n]) pres.addSection({ title: SECTIONS[sl.n] });
    const sectionTitle = Object.entries(SECTIONS).filter(([k]) => Number(k) <= sl.n).pop()[1];
    const s = pres.addSlide({ sectionTitle });
    seq = 0;
    BUILDERS[sl.key](s, sl, pres);
    notes(s, sl);
  }
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  await pres.writeFile({ fileName: OUT });
  await postProcess(OUT);
  console.log("Wrote", OUT);
})().catch((e) => { console.error(e); process.exit(1); });
