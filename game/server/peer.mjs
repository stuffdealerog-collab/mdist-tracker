// Player B for the client integration test: waits for the client's offer and accepts it.
import { existsSync, writeFileSync } from "node:fs";
const B = "http://127.0.0.1:8899";
const call = async (m, p, tok, body) => (await fetch(B + p, { method: m, headers: { "Content-Type": "application/json", ...(tok ? { Authorization: "Bearer " + tok } : {}) }, body: body ? JSON.stringify(body) : undefined })).json();
const me = await call("POST", "/auth", null, { device: "peer", name: "Пир" });
const it = (await call("POST", "/boxes/open", me.token, { box: "box_art" })).item;
for (let i = 0; i < 60 && !existsSync("/tmp/kss_client_ready"); i++) await new Promise((r) => setTimeout(r, 500));
const m = await call("GET", "/market", me.token);
const o = m.offers[0];
const r = await call("POST", `/market/${o.id}/accept`, me.token, { give_uid: it.uid });
console.log("PEER accepted, got", r.item && r.item.name);
writeFileSync("/tmp/kss_peer_done", "1");
