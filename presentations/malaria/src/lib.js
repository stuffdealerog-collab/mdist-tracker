// Asset helpers for the deck: display-type PNGs (Archivo Expanded via Chromium),
// overlays, the red-blood-cell disc, duotone portraits and icons.
const fs = require("fs");
const path = require("path");
const sharp = require("sharp");
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");

const ROOT = path.resolve(__dirname, "..");
const BUILD = path.join(ROOT, "build");
fs.mkdirSync(BUILD, { recursive: true });

const FONT_B64 = fs.readFileSync(path.join(ROOT, "assets/fonts/Archivo-latin.woff2")).toString("base64");
const SCALE = 3; // device pixels per CSS px; CSS px are 1/96 in

const PAGE_CSS = `
@font-face { font-family: 'ArchivoX'; src: url(data:font/woff2;base64,${FONT_B64}) format('woff2');
  font-weight: 100 900; font-stretch: 62% 125%; }
html, body { margin: 0; background: transparent; }
#t { display: inline-block; white-space: pre-line; font-family: 'ArchivoX'; font-stretch: 125%;
  text-transform: uppercase; line-height: 0.98; padding: 0.06em 0.04em; }
.grad { background: linear-gradient(180deg, #FFFFFF 0%, #F5E4E0 55%, #D7AEA8 100%);
  -webkit-background-clip: text; background-clip: text; color: transparent !important; }
`;

// Render every display spec to a transparent PNG. Returns id -> {file, w, h} in inches.
async function renderDisplay(specs) {
  const { chromium } = require("playwright");
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: SCALE, viewport: { width: 1600, height: 900 } });
  const out = {};
  for (const [id, s] of Object.entries(specs)) {
    const style = [
      `font-size:${s.size}pt`,
      `font-weight:${s.weight || 600}`,
      `color:${s.color || "#F4ECE8"}`,
      `letter-spacing:${s.track ?? -0.005}em`,
      `line-height:${s.lh || 0.98}`,
      `text-align:${s.align || "left"}`,
      s.maxW ? `max-width:${s.maxW * 96}px` : "",
      s.stretch ? `font-stretch:${s.stretch}%` : "",
      s.case === "none" ? "text-transform:none" : "",
    ].join(";");
    const cls = s.grad ? "grad" : "";
    const html = `<html><head><style>${PAGE_CSS}</style></head><body><span id="t" class="${cls}" style="${style}">${s.text
      .replace(/&/g, "&amp;").replace(/</g, "&lt;")}</span></body></html>`;
    await page.setContent(html);
    await page.evaluate(() => document.fonts.ready);
    const el = await page.$("#t");
    const box = await el.boundingBox();
    const file = path.join(BUILD, `t_${id}.png`);
    await el.screenshot({ path: file, omitBackground: true });
    out[id] = { file, w: box.width / 96, h: box.height / 96 };
  }
  await browser.close();
  return out;
}

async function svgToPng(svg, file, width) {
  await sharp(Buffer.from(svg)).resize(width ? { width } : undefined).png().toFile(file);
  return file;
}

// Dark gradient that keeps text readable over a photo. side: 'L' | 'R' | 'B' | 'full'
async function shade(name, side, strength = 1) {
  const a = (v) => Math.min(1, v * strength).toFixed(3);
  const stopsH = side === "R"
    ? [[0, 0.05], [0.4, 0.35], [0.62, 0.86], [1, 0.97]]
    : [[0, 0.97], [0.38, 0.88], [0.62, 0.38], [1, 0.08]];
  const h = stopsH.map(([o, v]) => `<stop offset="${o}" stop-color="#080304" stop-opacity="${a(v)}"/>`).join("");
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080">
    <defs>
      <linearGradient id="h" x1="0" x2="1" y1="0" y2="0">${h}</linearGradient>
      <linearGradient id="v" x1="0" x2="0" y1="0" y2="1">
        <stop offset="0" stop-color="#080304" stop-opacity="${a(0.55)}"/>
        <stop offset="0.22" stop-color="#080304" stop-opacity="0"/>
        <stop offset="0.78" stop-color="#080304" stop-opacity="0"/>
        <stop offset="1" stop-color="#080304" stop-opacity="${a(0.75)}"/>
      </linearGradient>
      <radialGradient id="c" cx="0.5" cy="0.5" r="0.75">
        <stop offset="0.55" stop-color="#080304" stop-opacity="0"/>
        <stop offset="1" stop-color="#080304" stop-opacity="${a(0.8)}"/>
      </radialGradient>
    </defs>
    ${side === "full" ? `<rect width="1920" height="1080" fill="#080304" fill-opacity="${a(0.62)}"/><rect width="1920" height="1080" fill="url(#c)"/>` : `<rect width="1920" height="1080" fill="url(#h)"/>`}
    <rect width="1920" height="1080" fill="url(#v)"/>
  </svg>`;
  return svgToPng(svg, path.join(BUILD, `shade_${name}.png`));
}

// The motif: a glowing red blood cell (pale biconcave centre) inside microscope reticle brackets.
async function disc() {
  const br = (x, y, dx, dy) => `<path d="M${x} ${y + dy * 70} L${x} ${y} L${x + dx * 70} ${y}" fill="none" stroke="#E7626B" stroke-opacity="0.75" stroke-width="3"/>`;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1000">
    <defs>
      <radialGradient id="g" cx="0.5" cy="0.47" r="0.5">
        <stop offset="0" stop-color="#7E0E1B"/>
        <stop offset="0.32" stop-color="#9E1424"/>
        <stop offset="0.66" stop-color="#D2283A"/>
        <stop offset="0.86" stop-color="#B21B2B"/>
        <stop offset="1" stop-color="#5C0710"/>
      </radialGradient>
      <radialGradient id="hl" cx="0.38" cy="0.3" r="0.5">
        <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.22"/>
        <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
      </radialGradient>
      <filter id="b" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="34"/></filter>
    </defs>
    <circle cx="500" cy="500" r="370" fill="#D4202F" fill-opacity="0.55" filter="url(#b)"/>
    <circle cx="500" cy="500" r="360" fill="url(#g)"/>
    <circle cx="500" cy="500" r="360" fill="url(#hl)"/>
    <circle cx="500" cy="500" r="360" fill="none" stroke="#FF9AA0" stroke-opacity="0.35" stroke-width="3"/>
    <circle cx="500" cy="500" r="410" fill="none" stroke="#E7626B" stroke-opacity="0.35" stroke-width="2" stroke-dasharray="2 14"/>
    ${br(40, 40, 1, 1)}${br(960, 40, -1, 1)}${br(40, 960, 1, -1)}${br(960, 960, -1, -1)}
    <path d="M500 22 V62 M500 938 V978 M22 500 H62 M938 500 H978" stroke="#E7626B" stroke-opacity="0.6" stroke-width="3"/>
  </svg>`;
  return svgToPng(svg, path.join(BUILD, "disc.png"));
}

// Background photo cropped to 16:9.
async function background(src, name, opts = {}) {
  const file = path.join(BUILD, `bg_${name}.jpg`);
  let img = sharp(src).resize(1920, 1080, { fit: "cover", position: opts.position || "centre" });
  if (opts.blur) img = img.blur(opts.blur);
  if (opts.darken) img = img.modulate({ brightness: opts.darken });
  await img.jpeg({ quality: 84, mozjpeg: true }).toFile(file);
  return file;
}

// Duotone (black -> crimson -> cream) circular portrait.
async function portrait(src, name) {
  const size = 600;
  const { data, info } = await sharp(src).resize(size, size, { fit: "cover", position: "north" })
    .grayscale().normalise().raw().toBuffer({ resolveWithObject: true });
  const dark = [14, 4, 6], mid = [150, 22, 36], light = [250, 228, 222];
  const rgb = Buffer.alloc(info.width * info.height * 3);
  for (let i = 0; i < info.width * info.height; i++) {
    const t = data[i * info.channels] / 255;
    const [a, b, u] = t < 0.5 ? [dark, mid, t / 0.5] : [mid, light, (t - 0.5) / 0.5];
    for (let c = 0; c < 3; c++) rgb[i * 3 + c] = Math.round(a[c] + (b[c] - a[c]) * u);
  }
  const mask = Buffer.from(`<svg width="${size}" height="${size}"><circle cx="${size / 2}" cy="${size / 2}" r="${size / 2}" fill="#fff"/></svg>`);
  const file = path.join(BUILD, `portrait_${name}.png`);
  await sharp(rgb, { raw: { width: info.width, height: info.height, channels: 3 } })
    .ensureAlpha().composite([{ input: mask, blend: "dest-in" }]).png().toFile(file);
  return file;
}

async function icon(Comp, name, color = "#FFE9E6") {
  const svg = renderToStaticMarkup(React.createElement(Comp, { size: 256, color, strokeWidth: 1.6 }));
  return svgToPng(svg, path.join(BUILD, `icon_${name}.png`), 256);
}

async function logo() {
  const src = fs.readFileSync(path.join(ROOT, "assets/logo/mdis_tashkent_logo.svg"));
  const full = path.join(BUILD, "logo_full.png");
  await sharp(src, { density: 600 }).png().toFile(full);
  const meta = await sharp(full).metadata();
  // the crest occupies roughly the first 12% of the horizontal lockup
  const crest = path.join(BUILD, "logo_crest.png");
  await sharp(full).extract({ left: 0, top: 0, width: Math.round(meta.width * 0.122), height: meta.height }).trim().png().toFile(crest);
  const cm = await sharp(crest).metadata();
  return { full, fullRatio: meta.width / meta.height, crest, crestRatio: cm.width / cm.height };
}

module.exports = { ROOT, BUILD, renderDisplay, shade, disc, background, portrait, icon, logo };
