// Builds output/Malaria_Prep_Sheet.pdf (A4) from content.json + prep_data.json
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const ROOT = path.resolve(__dirname, "..");
const content = require("./content.json");
const P = require("./prep_data.json");
const SP = content.speakers;
const ORDER = ["J", "M", "R", "A"];
const WPM = 125, CLICK = 2; // calm live pace, pause on each click
const FONT = fs.readFileSync(path.join(ROOT, "assets/fonts/Archivo-latin.woff2")).toString("base64");
const LOGO = fs.readFileSync(path.join(ROOT, "assets/logo/mdis_tashkent_logo.svg"), "utf8").replace(/<\?xml[^>]*>/, "");

const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const words = (t) => (t.match(/[A-Za-z0-9'’,.-]+/g) || []).length;
const mmss = (s) => `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, "0")}`;
const col = (k) => P.colors[k];

// ---- timing ----
const runOfShow = [];
let t = 0;
for (const s of content.slides) {
  s.notes.forEach((b, i) => {
    if (b.silent) return;
    const len = (words(b.text) / WPM) * 60 + (i === 0 ? CLICK : 0.5);
    runOfShow.push({ start: t, n: s.n, title: s.title, who: b.who, len });
    t += len;
  });
}
const totalTalk = t;
const perSpeaker = Object.fromEntries(ORDER.map((k) => [k, runOfShow.filter((r) => r.who === k).reduce((a, r) => a + r.len, 0)]));
const slidesOf = (k) => [...new Set(runOfShow.filter((r) => r.who === k).map((r) => r.n))];

// ---- script highlighting: numbers bold, handover lines marked ----
const NUM = "(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|billion|percent|point)";
const NUM_RE = new RegExp(`\\b(?:${NUM}(?:[\\s-]+(?:and[\\s-]+)?${NUM})*|\\d[\\d,.]*(?:s|\\s?BC)?)\\b`, "gi");
const SOLO_OK = /^(?:\d|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)/i;
function markNumbers(s) {
  return s.replace(NUM_RE, (m) => (/\s|-/.test(m.trim()) || SOLO_OK.test(m) ? `<b class="num">${m}</b>` : m));
}
function scriptHtml(text) {
  const paras = text.split("\n");
  return paras.map((para, pi) => {
    const sentences = para.match(/[^.!?]+[.!?]+["”]?\s*/g) || [para];
    return "<p>" + sentences.map((sn, si) => {
      const h = esc(sn);
      const first = pi === 0 && si === 0 && /^Thank you, \w+\./.test(sn.trim());
      const last = pi === paras.length - 1 && si === sentences.length - 1 && /\bwill (tell|show|explain|sum)\b/.test(sn);
      return first || last ? `<mark>${markNumbers(h.trim())}</mark> ` : markNumbers(h);
    }).join("") + "</p>";
  }).join("");
}

// ---- page helpers ----
const head = (left, right) => `<div class="runhead"><span>${left}</span><span>${right}</span></div>`;
const title = (a, b) => `<h1>${a} <em>${b}</em></h1>`;

function cover() {
  const cards = ORDER.map((k) => `
    <div class="sp" style="--c:${col(k)}">
      <div class="role">${esc(SP[k].role)}</div>
      <div class="nm">${esc(SP[k].short)}</div>
      <div class="meta">${SP[k].id} · slides ${slidesOf(k).map((n) => String(n).padStart(2, "0")).join(", ")}</div>
      <div class="meta">target ≈ ${mmss(perSpeaker[k])}</div>
    </div>`).join("");
  const map = [
    ["Title + names + IDs", "01", "Javohir (+ everyone introduces himself)"],
    ["Outline", "02", "Javohir"],
    ["Definition · viral or bacterial? · fatality rate", "03 – 04", "Javohir"],
    ["First records from history", "05 – 06", "Muhammadrizo"],
    ["Major outbreaks around the world", "07", "Muhammadrizo"],
    ["Statistics on damage / fatality so far", "08 – 10", "Ramazan"],
    ["Invention of the vaccine", "11", "Akmalbek"],
    ["Prevention measures", "12", "Akmalbek"],
    ["Treatment", "13", "Akmalbek"],
    ["Conclusion · Thank you", "14 – 15", "Javohir"],
    ["References (Harvard)", `16 (${content.references.length} sources)`, "on screen during questions"],
  ].map((r) => `<tr><td>${r[0]}</td><td>${r[1]}</td><td>${r[2]}</td></tr>`).join("");
  return `<section class="page">
    <div class="cover">
      <div class="logo">${LOGO}</div>
      <div class="ctitle">Malaria</div>
      <div class="csub">Prep pack · ${esc(content.subtitle)}</div>
      <div class="sps">${cards}</div>
    </div>
    <h2>The exam in one look</h2>
    <div class="grid2">
      <div class="fact"><div class="k">Speaking time</div><div class="v">3:00 – 3:30 each · 12 – 15 min total</div><div class="s">Our script is timed at a calm ${WPM} words per minute: ≈ ${mmss(totalTalk)} in total. Less than 3 or more than 3.5 minutes loses marks.</div></div>
      <div class="fact"><div class="k">Slides</div><div class="v">16 slides, rule is 15 – 20</div><div class="s">Includes Title, Outline, References and Thank you, as the task requires. One click = next slide, animations start by themselves.</div></div>
    </div>
    <div class="redline"><b>The red line.</b> Know every number on your slides and where it comes from (see "Every number and its source"). Never read from the slides: they are a guide, not your notes.</div>
    <h2>The task → our slides</h2>
    <table class="tbl"><tr><th>Required by the task</th><th>Our slides</th><th>Speaker</th></tr>${map}</table>
  </section>`;
}

function storyPage() {
  const tiles = content.slides.map((s) => `
    <div class="tile" style="--c:${col(s.owner)}">
      <div class="tn">${String(s.n).padStart(2, "0")}</div>
      <div class="tt">${esc(s.title)}</div>
      <div class="tk">${esc(P.keywords[s.n])}</div>
      <div class="tw">${SP[s.owner].first}${s.n === 1 ? " + all" : ""}</div>
    </div>`).join("");
  const tech = P.techniques.map(([h, d], i) => `<div class="tech"><span>${i + 1}</span><div><b>${h}.</b> ${esc(d)}</div></div>`).join("");
  return `<section class="page">${head("Prep pack · Malaria", "The whole talk")}
    ${title("The whole talk", "as one story")}
    <div class="story">${esc(P.story)}</div>
    <div class="tiles">${tiles}</div>
    <h2>How to make it stick</h2>
    <div class="techs">${tech}</div>
  </section>`;
}

function runPage() {
  const rows = runOfShow.map((r) => `<tr><td>${mmss(r.start)}</td><td><b>${String(r.n).padStart(2, "0")}</b> ${esc(r.title)}</td><td><i class="dot" style="background:${col(r.who)}"></i>${esc(SP[r.who].short)}</td><td>${mmss(r.len)}</td></tr>`).join("");
  const hand = [];
  const notes = content.slides.flatMap((s) => s.notes.filter((b) => !b.silent).map((b) => ({ ...b, n: s.n })));
  for (let i = 1; i < notes.length; i++) {
    const a = notes[i - 1], b = notes[i];
    if (a.who === b.who || a.n === 1) continue;
    const last = (a.text.match(/[^.!?]+[.!?]+\s*$/) || [a.text])[0].trim();
    const first = (b.text.match(/^[^.!?]+[.!?]+/) || [b.text])[0].trim();
    hand.push(`<tr><td>${SP[a.who].first} → ${SP[b.who].first}</td><td>“…${esc(last)}” → <mark>“${esc(first)}”</mark></td></tr>`);
  }
  const intro = ORDER.map((k) => `<tr><td>${esc(SP[k].short)}</td><td>${esc(SP[k].full)} · <b>${SP[k].id}</b> <span class="muted">(read: ${esc(SP[k].idSpoken)})</span></td></tr>`).join("");
  return `<section class="page">${head("Prep pack · Malaria", "Run of show")}
    ${title("Run of", "show")}
    <p class="muted">At a calm ${WPM} words per minute plus a pause on each click. The audio is a little faster (≈ 140 wpm), so live you will be ≈ 10 – 20 s longer than your audio.</p>
    <table class="tbl small"><tr><th>Start</th><th>Slide</th><th>Speaker</th><th>Length</th></tr>${rows}
      <tr><td><b>${mmss(totalTalk)}</b></td><td colspan="3"><b>End of talk</b> → slide 16 (References) stays on screen during questions</td></tr></table>
    <h2>Handovers: the relay baton</h2>
    <p class="muted">The next speaker always starts with “Thank you, [name]. As [name] said…”. Rehearse these exact lines together.</p>
    <table class="tbl small">${hand.join("")}</table>
    <h2>Self-introductions on slide 01</h2>
    <p class="muted">Javohir starts, then each person says only: <b>“Good afternoon. My name is [full name], and my ID number is [ID].”</b> Say your name exactly as on your ID card.</p>
    <table class="tbl small">${intro}</table>
  </section>`;
}

function speakerPages(k) {
  const c = col(k);
  const blocks = content.slides.flatMap((s) => s.notes.filter((b) => b.who === k && !b.silent).map((b) => ({ s, b })));
  const timeOf = (n) => runOfShow.find((r) => r.n === n && r.who === k);
  const script = blocks.map(({ s, b }) => {
    const r = timeOf(s.n);
    return `<div class="blk"><div class="bh"><span><b>${String(s.n).padStart(2, "0")}</b> ${esc(s.title)}</span><span>${mmss(r.start)} – ${mmss(r.start + r.len)} · ${s.n === 1 && k !== "J" ? "right after the person before you" : "click → slide " + s.n}</span></div>${scriptHtml(b.text)}</div>`;
  }).join("");
  const ladder = blocks.map(({ s }) => `<tr><td><b>${String(s.n).padStart(2, "0")}</b></td><td>${esc(s.title)}</td><td>${esc(P.keywords[s.n])}</td></tr>`).join("");
  const hooks = P.hooks[k].map(([h, d]) => `<div class="hook"><b>${esc(h)}</b><span>${esc(d)}</span></div>`).join("");
  const say = P.say[k].map(([w, p]) => `<tr><td>${esc(w)}</td><td class="muted">${esc(p)}</td></tr>`).join("");
  const cue = blocks.map(({ s }) => `<tr><td><b>${String(s.n).padStart(2, "0")}</b></td><td>${esc(s.cue[k])}</td></tr>`).join("");
  const test = P.selftest[k].map(([q, a]) => `<tr><td>${esc(q)}</td><td class="ans">${esc(a)}</td></tr>`).join("");
  const sp = SP[k];
  return `<section class="page" style="--c:${c}">${head(`Prep pack · ${esc(sp.role)}`, `${esc(sp.short)} · ${sp.id}`)}
      <h1 class="spk">${esc(sp.first)} <em>${esc(sp.short.split(" ")[1])}</em></h1>
      <p class="muted">${esc(sp.part)} · your slides ${slidesOf(k).map((n) => String(n).padStart(2, "0")).join(", ")} · target ≈ ${mmss(perSpeaker[k])} (must stay between 3:00 and 3:30) · <mark>highlighted</mark> = handover lines · <b class="num">bold</b> = numbers to own</p>
      ${script}
    </section>
    <section class="page" style="--c:${c}">${head("Prep pack · memory page", esc(sp.short))}
      ${title("Your", "memory page")}
      <div class="grid2 top">
        <div><h3>3 words per slide</h3><table class="tbl small">${ladder}</table>
          <h3>Say it right</h3><table class="tbl small">${say}</table>
          <p class="muted tiny">Capital letters = stressed syllable.</p></div>
        <div><h3>Memory hooks</h3>${hooks}</div>
      </div>
      <div class="grid2">
        <div class="cuecard"><div class="scissors">✂ cut out · the only notes you take on stage</div><table class="tbl small">${cue}</table></div>
        <div><h3>Self-test <span class="muted tiny">· cover the right column, answer aloud</span></h3><table class="tbl small test">${test}</table></div>
      </div>
    </section>`;
}

function planPage() {
  const days = [
    ["Day 1 · Understand", "Listen to <b>00_Full_run-through</b> once to hear the whole story and the handovers. Then play <b>your “my part”</b> 3 times while reading your script page. Mark where you breathe."],
    ["Day 2 · Shadow", "Play <b>your shadowing track</b> twice: repeat each phrase aloud in the pause. Then say your part from the <b>3 words per slide</b> list only."],
    ["Day 3 · Own it", "Speak from the cue card with a timer and record yourself on the phone. Do the <b>self-test</b> on your memory page. Fix every number you missed using the hooks."],
    ["Day 4 · Together", "Two full group run-throughs with the slides and a clicker, standing. Practise the four handovers until they are smooth. Total time 12 – 15 minutes."],
    ["Exam morning", "One listen to your “my part” with headphones (3 minutes). One run-through of the handovers only. Breathe."],
  ].map(([h, d]) => `<tr><td><b>${h}</b></td><td>${d}</td></tr>`).join("");
  return `<section class="page">${head("Prep pack · Malaria", "Plan and exam day")}
    ${title("Four days", "to learn it")}
    <p class="muted">Short sessions on different days beat one long night: each day you recall the talk again, and every recall makes it stronger. 20 – 30 minutes a day is enough.</p>
    <table class="tbl">${days}</table>
    <h2>Your audio files (output/audio)</h2>
    <table class="tbl small"><tr><th>File</th><th>What it is · how to use it</th></tr>
      <tr><td>00_Full_run-through_all_speakers.mp3</td><td>The whole talk in four voices, a soft click = next slide. Listen once on Day 1 and once on Day 4.</td></tr>
      <tr><td>0N_Name_1_my_part.mp3</td><td>Only your part (≈ 3 min). Before each entry you hear the previous speaker's last line: that is your cue to start.</td></tr>
      <tr><td>0N_Name_2_shadowing.mp3</td><td>Your part phrase by phrase. After each phrase there is a pause of the same length: repeat it aloud.</td></tr>
    </table>
    <h2>Memory palace (5 minutes, works very well)</h2>
    <p>Walk through your home in your mind and put one slide in each place: door, corridor, kitchen, window, sofa. Picture the image of the slide there (a mosquito on the door, an hourglass in the kitchen…). On stage, “walk” to the next room and the next slide comes back.</p>
    <div class="grid2">
      <div><h2>On stage</h2><ul>
        <li>Look at the teacher <b>and</b> the audience; move your eyes every sentence or two.</li>
        <li>Stand still, open hands, no hands in pockets.</li>
        <li>Pause after every number: let it land.</li>
        <li>One click = next slide. Wait one second for the animation, then speak.</li>
        <li>When others speak, look at them or at the screen, not at your notes.</li></ul></div>
      <div><h2>Do not</h2><ul>
        <li>Read from the slides or from a sheet.</li>
        <li>Use fillers: “eee”, “um”, “like”, “actually”.</li>
        <li>Hold your phone or chew gum.</li>
        <li>Apologise or say “I forgot”.</li></ul>
        <h2>Bring</h2><ul><li>ID card, formal clothes, one small cue card.</li><li>The .pptx on a USB stick and in Telegram.</li></ul></div>
    </div>
    <div class="redline"><b>If you forget a line:</b> look at the slide title, say its 3 keywords in one simple sentence and continue with the next point. The audience does not know your script.</div>
  </section>`;
}

function questionsPage() {
  const q = P.questions.map(([k, qq, a]) => `<div class="qa"><div class="qo" style="color:${col(k)}">${esc(SP[k].short)}</div><div class="qq">${esc(qq)}</div><div>${esc(a)}</div></div>`).join("");
  return `<section class="page">${head("Prep pack · Malaria", "Questions")}
    ${title("Possible", "questions")}
    <p class="muted">The owner answers first; the others may add one sentence. Keep answers to two or three sentences. If you do not know: “That is a good question. From our sources we know…, but we did not study this part in detail.”</p>
    ${q}
  </section>`;
}

function sourcesPage() {
  const rows = P.numbers.map(([n, m, s, w]) => `<tr><td><b>${esc(n)}</b></td><td>${esc(m)}</td><td>${esc(s)}</td><td>${esc(w.split(", ").map((x) => SP[x].first).join(", "))}</td></tr>`).join("");
  const refs = content.references.map((r) => `<li>${esc(r)}</li>`).join("");
  return `<section class="page">${head("Prep pack · Malaria", "Sources")}
    ${title("Every number", "and its source")}
    <table class="tbl small"><tr><th>Figure</th><th>Meaning</th><th>Source</th><th>Who says it</th></tr>${rows}</table>
  </section>
  <section class="page">${head("Prep pack · Malaria", "References")}
    ${title("Reference", "list")}
    <p class="muted">Harvard style, the same list as slide 16. The figures in this pack come only from these sources; “our calculation” means simple arithmetic on WHO numbers.</p>
    <ul class="refs">${refs}</ul>
  </section>`;
}

const CSS = `
@font-face { font-family: 'ArchivoX'; src: url(data:font/woff2;base64,${FONT}) format('woff2'); font-weight: 100 900; font-stretch: 62% 125%; }
@page { size: A4; margin: 0; }
* { box-sizing: border-box; }
body { margin: 0; font-family: 'Inter', Arial, sans-serif; color: #1d1416; font-size: 10.2pt; line-height: 1.45; }
.page { width: 210mm; height: 297mm; padding: 13mm 15mm 12mm; page-break-after: always; overflow: hidden; position: relative; --c: #C8202F; }
.runhead { display: flex; justify-content: space-between; font-size: 8pt; color: #8a7a7c; border-bottom: 1px solid #eadfe0; padding-bottom: 2.2mm; margin-bottom: 5mm; }
h1 { font-family: 'ArchivoX'; font-stretch: 125%; font-weight: 600; text-transform: uppercase; font-size: 23pt; line-height: 1; margin: 0 0 3.5mm; letter-spacing: -0.01em; }
h1 em { font-style: normal; color: var(--c); }
h1.spk { font-size: 25pt; }
h2 { font-size: 11.5pt; margin: 5mm 0 2mm; }
h3 { font-size: 10.5pt; margin: 0 0 1.6mm; }
p { margin: 0 0 2mm; }
.muted { color: #7d6d6f; } .tiny { font-size: 8pt; }
mark { background: #fbe1e3; padding: 0 1px; border-radius: 2px; }
b.num { color: var(--c); }
.tbl { width: 100%; border-collapse: collapse; margin-bottom: 2mm; }
.tbl th { text-align: left; font-weight: 600; color: #8a7a7c; font-size: 8.5pt; border-bottom: 1px solid #d9cdce; padding: 1.4mm 2mm 1.4mm 0; }
.tbl td { border-bottom: 1px solid #eee4e5; padding: 1.5mm 2mm 1.5mm 0; vertical-align: top; }
.tbl.small td, .tbl.small th { font-size: 8.6pt; padding-top: .75mm; padding-bottom: .75mm; line-height: 1.35; }
.dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%; margin-right: 5px; vertical-align: 1px; }
.cover { background: radial-gradient(120% 140% at 85% 30%, #6a0d17 0%, #2a0609 45%, #0b0405 100%); color: #f4ece8; margin: -13mm -15mm 0; padding: 11mm 15mm 8mm; }
.cover .logo svg { height: 9mm; width: auto; }
.ctitle { font-family: 'ArchivoX'; font-stretch: 125%; font-weight: 600; font-size: 54pt; text-transform: uppercase; line-height: 1; margin-top: 9mm;
  background: linear-gradient(180deg, #fff, #d7aea8); -webkit-background-clip: text; color: transparent; }
.csub { font-size: 11pt; color: #e9c9c5; margin: 2mm 0 8mm; }
.sps { display: grid; grid-template-columns: repeat(4, 1fr); gap: 3mm; }
.sp { border: 1px solid rgba(255,255,255,.18); border-radius: 3mm; padding: 3mm; background: rgba(255,255,255,.04); border-top: 0; box-shadow: inset 0 3px 0 var(--c); }
.sp .role { font-size: 7.5pt; color: #d9b3ae; text-transform: uppercase; letter-spacing: .06em; }
.sp .nm { font-weight: 700; font-size: 10.5pt; margin: 1mm 0; }
.sp .meta { font-size: 8pt; color: #cfb5b1; }
.grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 6mm; }
.grid2.top { margin-bottom: 4mm; }
.fact { border-top: 1px solid #e3d6d7; padding-top: 2mm; }
.fact .k { font-size: 8pt; color: #8a7a7c; } .fact .v { font-weight: 700; font-size: 11pt; margin: .5mm 0 1mm; } .fact .s { font-size: 8.5pt; color: #7d6d6f; }
.redline { background: #1d0a0d; color: #f4ece8; padding: 3.5mm 4.5mm; border-radius: 2.5mm; margin: 5mm 0 1mm; font-size: 9.5pt; }
.story { font-size: 11pt; line-height: 1.55; background: #fbf3f3; border-radius: 3mm; padding: 4mm 5mm; margin-bottom: 4mm; }
.tiles { display: grid; grid-template-columns: repeat(4, 1fr); gap: 2.4mm; }
.tile { border: 1px solid #eadfe0; border-radius: 2.5mm; padding: 2.4mm 2.8mm; min-height: 25mm; position: relative; box-shadow: inset 3px 0 0 var(--c); }
.tn { font-family: 'ArchivoX'; font-stretch: 125%; font-weight: 600; font-size: 13pt; color: var(--c); }
.tt { font-weight: 700; font-size: 9pt; margin: .6mm 0 .8mm; }
.tk { font-size: 8.2pt; color: #4a3b3d; line-height: 1.35; }
.tw { position: absolute; right: 2.6mm; top: 2.6mm; font-size: 7.3pt; color: #8a7a7c; }
.techs { display: grid; grid-template-columns: 1fr 1fr; gap: 2mm 6mm; }
.tech { display: flex; gap: 2.5mm; font-size: 9pt; }
.tech span { flex: none; width: 5.5mm; height: 5.5mm; border-radius: 50%; background: #C8202F; color: #fff; font-size: 8pt; display: flex; align-items: center; justify-content: center; font-weight: 700; }
.blk { border-top: 1.2px solid #1d1416; padding-top: 1.6mm; margin-top: 2.6mm; }
.bh { display: flex; justify-content: space-between; font-size: 8.6pt; color: #6d5d5f; margin-bottom: 1.2mm; }
.bh b { color: var(--c); }
.blk p { font-size: 10.1pt; margin-bottom: 1.4mm; }
.hook { border-left: 2.5px solid var(--c); padding: .3mm 0 .3mm 3mm; margin-bottom: 1.9mm; line-height: 1.35; }
.hook b { display: block; font-size: 9.2pt; } .hook span { font-size: 8.5pt; color: #4a3b3d; }
.cuecard { border: 1.5px dashed #b9a9ab; border-radius: 3mm; padding: 3mm 3.5mm; }
.scissors { font-size: 8pt; color: #8a7a7c; margin-bottom: 1.5mm; }
.test .ans { color: var(--c); font-weight: 600; }
.aud { margin: 0; padding-left: 4mm; font-size: 8.4pt; }
.qa { border-top: 1px solid #eadfe0; padding: 1.1mm 0 1.2mm; font-size: 8.7pt; line-height: 1.36; }
.qo { font-size: 8pt; font-weight: 600; } .qq { font-weight: 700; margin: .4mm 0 .6mm; }
ul { margin: 0 0 2mm; padding-left: 5mm; } li { margin-bottom: 1mm; }
.refs li { font-size: 9.2pt; margin-bottom: 2.4mm; }
`;

(async () => {
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>${CSS}</style></head><body>
    ${cover()}${storyPage()}${runPage()}${ORDER.map(speakerPages).join("")}${planPage()}${questionsPage()}${sourcesPage()}
  </body></html>`;
  fs.writeFileSync(path.join(ROOT, "build/prep.html"), html);
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.setContent(html, { waitUntil: "load" });
  await page.evaluate(() => document.fonts.ready);
  const overflow = await page.$$eval(".page", (ps) => ps.map((p, i) => [i + 1, p.scrollHeight - p.clientHeight]).filter(([, d]) => d > 2));
  if (overflow.length) console.warn("Pages overflowing (page, px):", JSON.stringify(overflow));
  const out = path.join(ROOT, "output/Malaria_Prep_Sheet.pdf");
  await page.pdf({ path: out, format: "A4", printBackground: true, preferCSSPageSize: true });
  await browser.close();
  console.log("Wrote", out, "· talk ≈", mmss(totalTalk), Object.entries(perSpeaker).map(([k, v]) => `${k} ${mmss(v)}`).join(" "));
})();
