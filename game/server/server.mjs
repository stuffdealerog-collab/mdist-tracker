// Keyboard Seller Simulator — online server (boxes, player trading, leaderboards).
// Zero dependencies: Node.js 22+ (node:sqlite, node:http).
//   node server.mjs            (PORT=8787 DB=./kss.db by default)
import http from "node:http";
import { DatabaseSync } from "node:sqlite";
import { randomBytes, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const DIR = path.dirname(fileURLToPath(import.meta.url));
const PORT = +(process.env.PORT || 8787);
const DB_PATH = process.env.DB || path.join(DIR, "kss.db");
const POOLS = JSON.parse(readFileSync(path.join(DIR, "pools.json"), "utf8"));
const RAR = ["common", "rare", "epic", "legendary"];
const OFFER_TTL = 7 * 24 * 3600 * 1000;

// ------------------------------------------------------------------ database
const db = new DatabaseSync(DB_PATH);
db.exec(`
PRAGMA journal_mode = WAL;
CREATE TABLE IF NOT EXISTS players (pid TEXT PRIMARY KEY, device TEXT UNIQUE, token TEXT, name TEXT, created INTEGER, opens_day TEXT, opens INTEGER DEFAULT 0, last_open INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS items (uid TEXT PRIMARY KEY, owner TEXT, kind TEXT, id TEXT, n INTEGER, rarity TEXT, name TEXT, state TEXT, created INTEGER);
CREATE TABLE IF NOT EXISTS offers (id TEXT PRIMARY KEY, seller TEXT, give_uid TEXT, want_kind TEXT, want_rarity TEXT, created INTEGER, state TEXT);
CREATE TABLE IF NOT EXISTS inbox (id INTEGER PRIMARY KEY AUTOINCREMENT, pid TEXT, uid TEXT, via TEXT, created INTEGER, delivered INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS scores (pid TEXT PRIMARY KEY, name TEXT, earned REAL, level INTEGER, built INTEGER, city TEXT, updated INTEGER);
CREATE TABLE IF NOT EXISTS contest (week INTEGER, pid TEXT, name TEXT, score REAL, PRIMARY KEY (week, pid));
CREATE INDEX IF NOT EXISTS items_owner ON items(owner, state);
CREATE INDEX IF NOT EXISTS offers_state ON offers(state, created);
CREATE INDEX IF NOT EXISTS inbox_pid ON inbox(pid, delivered);
`);
const q = (sql) => db.prepare(sql);
const tx = (fn) => { db.exec("BEGIN"); try { const r = fn(); db.exec("COMMIT"); return r; } catch (e) { db.exec("ROLLBACK"); throw e; } };

// ------------------------------------------------------------------ helpers
const now = () => Date.now();
const clean = (s, n = 32) => String(s ?? "").replace(/[\u0000-\u001f<>]/g, "").trim().slice(0, n);
const err = (code, msg) => Object.assign(new Error(msg), { code });
const itemOut = (r) => r && ({ uid: r.uid, kind: r.kind, id: r.id, n: r.n, rarity: r.rarity, name: r.name });
const pick = (a) => a[Math.floor(Math.random() * a.length)];
const today = () => new Date().toISOString().slice(0, 10);

function rollRarity(table, luck) {
  luck = Math.max(0, Math.min(0.5, +luck || 0));
  const w = { common: table.common, rare: table.rare * (1 + luck), epic: table.epic * (1 + luck), legendary: table.legendary * (1 + luck) };
  const tot = RAR.reduce((a, k) => a + w[k], 0);
  let r = Math.random() * tot;
  for (const k of RAR) { r -= w[k]; if (r <= 0) return k; }
  return "common";
}
// mirrors Game.box_entry()
function boxEntry(pool, rar) {
  if (pool === "art") {
    const a = pick(POOLS.artisans.filter((x) => x.r === rar));
    return { kind: "art", id: a.id, n: 1, rarity: rar, name: a.name };
  }
  if (pool === "sw") {
    const S = POOLS.switches;
    const cand = rar === "common" ? S.filter((s) => !s.gb && !s.box && s.price < 60)
      : rar === "rare" ? S.filter((s) => (!s.box && s.price >= 60) || s.box === "rare")
      : rar === "epic" ? S.filter((s) => s.gb || s.box === "epic")
      : S.filter((s) => s.box === "legendary");
    const s = pick(cand); const n = rar !== "common" ? POOLS.tkl : POOLS.l65;
    return { kind: "sw", id: s.id, n, rarity: rar, name: `${n} × ${s.name}` };
  }
  const K = POOLS.keycaps;
  const cand = rar === "common" ? K.filter((k) => !k.gb && !k.box && k.price < 9000)
    : rar === "rare" ? K.filter((k) => (!k.gb && !k.box && k.price >= 9000) || k.box === "rare")
    : rar === "epic" ? K.filter((k) => k.gb || k.box === "epic")
    : K.filter((k) => k.box === "legendary");
  const k = pick(cand);
  return { kind: "kc", id: k.id, n: 1, rarity: rar, name: `кейкапы «${k.name}»` };
}
function mint(owner, e) {
  const uid = randomUUID().replace(/-/g, "");
  q("INSERT INTO items VALUES (?,?,?,?,?,?,?,?,?)").run(uid, owner, e.kind, e.id, e.n, e.rarity, e.name, "owned", now());
  return { ...e, uid };
}
function expireOffers() {
  const old = q("SELECT * FROM offers WHERE state='open' AND created < ?").all(now() - OFFER_TTL);
  for (const o of old) tx(() => {
    q("UPDATE offers SET state='expired' WHERE id=?").run(o.id);
    q("UPDATE items SET state='owned' WHERE uid=?").run(o.give_uid);
    q("INSERT INTO inbox (pid, uid, via, created) VALUES (?,?,?,?)").run(o.seller, o.give_uid, "expired", now());
  });
}
function offerOut(o) {
  const it = q("SELECT * FROM items WHERE uid=?").get(o.give_uid);
  const seller = q("SELECT name FROM players WHERE pid=?").get(o.seller);
  return { id: o.id, seller: seller ? seller.name : "Мастер", give: itemOut(it), want: { kind: o.want_kind, rarity: o.want_rarity }, created: o.created };
}

// ------------------------------------------------------------------ rate limit
const buckets = new Map();
function allow(key, rate = 20, burst = 40) {
  const t = now(); let b = buckets.get(key);
  if (!b) { b = { tokens: burst, t }; buckets.set(key, b); }
  b.tokens = Math.min(burst, b.tokens + ((t - b.t) / 1000) * rate); b.t = t;
  if (b.tokens < 1) return false;
  b.tokens -= 1; return true;
}
setInterval(() => { const t = now(); for (const [k, b] of buckets) if (t - b.t > 600000) buckets.delete(k); }, 300000).unref();

// ------------------------------------------------------------------ routes
const routes = [];
const route = (method, pattern, auth, fn) => routes.push({ method, re: new RegExp("^" + pattern.replace(/:(\w+)/g, "(?<$1>[^/]+)") + "$"), auth, fn });

route("GET", "/health", false, () => ({ ok: true, players: q("SELECT COUNT(*) c FROM players").get().c, offers: q("SELECT COUNT(*) c FROM offers WHERE state='open'").get().c }));

route("POST", "/auth", false, ({ body }) => {
  const device = clean(body.device, 128), name = clean(body.name) || "Мастерская";
  if (!device) throw err(400, "device required");
  let p = body.token ? q("SELECT * FROM players WHERE token=?").get(String(body.token)) : null;
  if (!p) p = q("SELECT * FROM players WHERE device=?").get(device);
  if (!p) {
    p = { pid: randomUUID().slice(0, 12), token: randomBytes(24).toString("hex") };
    q("INSERT INTO players (pid, device, token, name, created) VALUES (?,?,?,?,?)").run(p.pid, device, p.token, name, now());
  } else q("UPDATE players SET name=? WHERE pid=?").run(name, p.pid);
  return { pid: p.pid, token: p.token };
});

route("POST", "/boxes/open", true, ({ me, body }) => {
  const box = POOLS.boxes.find((b) => b.id === body.box);
  if (!box) throw err(400, "unknown box");
  const t = now(), day = today();
  const opens = me.opens_day === day ? me.opens : 0;
  if (opens >= 300) throw err(429, "Лимит открытий на сегодня");
  if (t - (me.last_open || 0) < 1500) throw err(429, "Слишком часто");
  q("UPDATE players SET opens_day=?, opens=?, last_open=? WHERE pid=?").run(day, opens + 1, t, me.pid);
  const rar = rollRarity(box.id === "box_pro" ? POOLS.odds_pro : POOLS.odds, body.luck);
  const pool = box.pool === "mix" ? pick(["sw", "kc", "art", "art"]) : box.pool;
  return { item: mint(me.pid, boxEntry(pool, rar)) };
});

route("GET", "/market", true, ({ me }) => {
  expireOffers();
  const open = q("SELECT * FROM offers WHERE state='open' ORDER BY created DESC LIMIT 200").all();
  return { offers: open.filter((o) => o.seller !== me.pid).map(offerOut), mine: open.filter((o) => o.seller === me.pid).map(offerOut) };
});

route("POST", "/market", true, ({ me, body }) => {
  const want = body.want || {};
  if (!["art", "sw", "kc"].includes(want.kind) || !RAR.includes(want.rarity)) throw err(400, "Неверное желание");
  if (q("SELECT COUNT(*) c FROM offers WHERE seller=? AND state='open'").get(me.pid).c >= 10) throw err(400, "Не больше 10 предложений одновременно");
  return tx(() => {
    const it = q("SELECT * FROM items WHERE uid=? AND owner=? AND state='owned'").get(String(body.give_uid), me.pid);
    if (!it) throw err(400, "Предмет не найден или уже выставлен");
    q("UPDATE items SET state='listed' WHERE uid=?").run(it.uid);
    const id = randomUUID().slice(0, 10);
    q("INSERT INTO offers VALUES (?,?,?,?,?,?,?)").run(id, me.pid, it.uid, want.kind, want.rarity, now(), "open");
    return { id };
  });
});

route("POST", "/market/:id/accept", true, ({ me, body, params }) => tx(() => {
  const o = q("SELECT * FROM offers WHERE id=? AND state='open'").get(params.id);
  if (!o) throw err(404, "Предложение уже закрыто");
  if (o.seller === me.pid) throw err(400, "Это ваше предложение");
  const mine = q("SELECT * FROM items WHERE uid=? AND owner=? AND state='owned'").get(String(body.give_uid), me.pid);
  if (!mine) throw err(400, "Ваш предмет не найден");
  if (mine.kind !== o.want_kind || RAR.indexOf(mine.rarity) < RAR.indexOf(o.want_rarity)) throw err(400, "Продавец хочет другое");
  q("UPDATE offers SET state='done' WHERE id=?").run(o.id);
  q("UPDATE items SET owner=?, state='owned' WHERE uid=?").run(me.pid, o.give_uid);
  q("UPDATE items SET owner=?, state='owned' WHERE uid=?").run(o.seller, mine.uid);
  q("INSERT INTO inbox (pid, uid, via, created) VALUES (?,?,?,?)").run(o.seller, mine.uid, "trade", now());
  return { item: itemOut(q("SELECT * FROM items WHERE uid=?").get(o.give_uid)) };
}));

route("DELETE", "/market/:id", true, ({ me, params }) => tx(() => {
  const o = q("SELECT * FROM offers WHERE id=? AND seller=? AND state='open'").get(params.id, me.pid);
  if (!o) throw err(404, "Нет такого предложения");
  q("UPDATE offers SET state='cancelled' WHERE id=?").run(o.id);
  q("UPDATE items SET state='owned' WHERE uid=?").run(o.give_uid);
  q("INSERT INTO inbox (pid, uid, via, created) VALUES (?,?,?,?)").run(me.pid, o.give_uid, "cancel", now());
  return { ok: true };
}));

route("GET", "/inbox", true, ({ me }) => tx(() => {
  const rows = q("SELECT inbox.id iid, inbox.via, items.* FROM inbox JOIN items ON items.uid = inbox.uid WHERE inbox.pid=? AND inbox.delivered=0").all(me.pid);
  for (const r of rows) q("UPDATE inbox SET delivered=1 WHERE id=?").run(r.iid);
  return { items: rows.filter((r) => r.owner === me.pid).map((r) => ({ ...itemOut(r), via: r.via })) };
}));

route("POST", "/items/:uid/consume", true, ({ me, params }) => {
  const r = q("UPDATE items SET state='consumed' WHERE uid=? AND owner=? AND state='owned'").run(params.uid, me.pid);
  return { ok: r.changes > 0 };
});

route("POST", "/score", true, ({ me, body }) => {
  const earned = Math.max(0, Math.min(1e12, +body.earned || 0)), level = Math.max(1, Math.min(999, body.level | 0)), built = Math.max(0, Math.min(1e7, body.built | 0));
  q(`INSERT INTO scores VALUES (?,?,?,?,?,?,?) ON CONFLICT(pid) DO UPDATE SET name=excluded.name, earned=excluded.earned, level=excluded.level, built=excluded.built, city=excluded.city, updated=excluded.updated`)
    .run(me.pid, clean(body.name) || me.name, earned, level, built, clean(body.city, 24), now());
  return { ok: true };
});

route("POST", "/contest", true, ({ me, body }) => {
  const week = body.week | 0, score = Math.max(0, Math.min(200, +body.score || 0));
  q(`INSERT INTO contest VALUES (?,?,?,?) ON CONFLICT(week, pid) DO UPDATE SET score=max(score, excluded.score), name=excluded.name`).run(week, me.pid, clean(body.name) || me.name, score);
  return { ok: true };
});

route("GET", "/leaderboard", false, ({ url }) => {
  const week = +(url.searchParams.get("week") || 0);
  return {
    top: q("SELECT pid, name, earned, level, built, city FROM scores ORDER BY earned DESC LIMIT 50").all(),
    contest: week ? q("SELECT pid, name, score FROM contest WHERE week=? ORDER BY score DESC LIMIT 20").all(week) : [],
  };
});

// ------------------------------------------------------------------ http
const server = http.createServer(async (req, res) => {
  const send = (code, obj) => {
    res.writeHead(code, { "Content-Type": "application/json; charset=utf-8", "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "Content-Type, Authorization", "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS" });
    res.end(JSON.stringify(obj));
  };
  if (req.method === "OPTIONS") return send(204, {});
  const ip = req.headers["x-forwarded-for"]?.split(",")[0].trim() || req.socket.remoteAddress;
  if (!allow("ip:" + ip)) return send(429, { error: "Слишком много запросов" });
  const url = new URL(req.url, "http://x");
  const r = routes.find((x) => x.method === req.method && x.re.test(url.pathname));
  if (!r) return send(404, { error: "not found" });
  let raw = "";
  for await (const chunk of req) { raw += chunk; if (raw.length > 16384) return send(413, { error: "too large" }); }
  let body = {};
  try { body = raw ? JSON.parse(raw) : {}; } catch { return send(400, { error: "bad json" }); }
  try {
    let me = null;
    if (r.auth) {
      const tok = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
      me = tok && q("SELECT * FROM players WHERE token=?").get(tok);
      if (!me) return send(401, { error: "unauthorized" });
    }
    send(200, await r.fn({ me, body, params: url.pathname.match(r.re).groups || {}, url }));
  } catch (e) {
    if (!e.code) console.error(e);
    send(e.code || 500, { error: e.code ? e.message : "server error" });
  }
});
server.listen(PORT, () => console.log(`KSS server on :${PORT}, db ${DB_PATH}`));
export { server, db };
