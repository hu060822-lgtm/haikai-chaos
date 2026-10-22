// Relay protocol test: node test.js (starts its own server on a free port).
import { spawn } from "node:child_process";
import WebSocket from "ws";

const port = 24790 + Math.floor(Math.random() * 100);
const server = spawn(process.execPath, ["node_server.js", String(port)], { stdio: "ignore" });
let failed = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"} ${what}`);
  if (!ok) failed++;
};

function client() {
  const ws = new WebSocket(`ws://127.0.0.1:${port}`);
  const inbox = [];
  const waiters = [];
  ws.on("message", (data, isBinary) => {
    const m = isBinary ? { bin: new Uint8Array(data) } : JSON.parse(data.toString());
    const w = waiters.findIndex((x) => x.pred(m));
    if (w >= 0) waiters.splice(w, 1)[0].resolve(m);
    else inbox.push(m);
  });
  const next = (pred = () => true, ms = 2000) => {
    const i = inbox.findIndex(pred);
    if (i >= 0) return Promise.resolve(inbox.splice(i, 1)[0]);
    return new Promise((resolve) => {
      const w = { pred, resolve };
      waiters.push(w);
      setTimeout(() => {
        const k = waiters.indexOf(w);
        if (k >= 0) waiters.splice(k, 1), resolve(null);
      }, ms);
    });
  };
  const ready = new Promise((r, j) => (ws.on("open", r), ws.on("error", j)));
  const sendJ = (o) => ws.send(JSON.stringify(o));
  const sendB = (target, bytes) => {
    const b = new Uint8Array(4 + bytes.length);
    new DataView(b.buffer).setInt32(0, target, true);
    b.set(bytes, 4);
    ws.send(b);
  };
  return { ws, next, ready, sendJ, sendB };
}
const from = (m) => new DataView(m.bin.buffer, m.bin.byteOffset).getInt32(0, true);

async function main() {
  await new Promise((r) => setTimeout(r, 400));
  const game = { game: "HAIKAI_CHAOS", proto: 3 };
  const host = client(), a = client(), b = client(), c = client();
  await Promise.all([host.ready, a.ready, b.ready, c.ready]);
  host.sendJ({ op: "host", ...game, name: "luz", info: { max: 10, map: "dream" } });
  const hosted = await host.next();
  check(hosted?.op === "hosted" && /^[0-9A-Z]{5}$/.test(hosted.code), `host gets a 5-character code (${hosted?.code})`);
  c.sendJ({ op: "list", ...game });
  const list = await c.next((m) => m.op === "rooms");
  check(list?.rooms.length === 1 && list.rooms[0].name === "luz" && list.rooms[0].map === "dream", "the room list shows it");
  a.sendJ({ op: "join", ...game, code: hosted.code.toLowerCase(), name: "A" });
  b.sendJ({ op: "join", ...game, code: hosted.code, name: "B" });
  const ja = await a.next(), jb = await b.next();
  check(ja?.op === "joined" && jb?.op === "joined" && ja.id !== jb.id && ja.id > 1, `clients get their own ids (${ja?.id}, ${jb?.id})`);
  const p1 = await host.next((m) => m.op === "peer_joined"), p2 = await host.next((m) => m.op === "peer_joined");
  check(p1 && p2, "the host hears both join");
  a.sendB(99, new Uint8Array([7, 8, 9]));
  const got = await host.next((m) => m.bin);
  check(got && from(got) === ja.id && got.bin[4] === 7 && got.bin.length === 7, "a client's packet reaches the host, tagged with the client's id");
  host.sendB(0, new Uint8Array([1]));
  const ga = await a.next((m) => m.bin), gb = await b.next((m) => m.bin);
  check(ga && gb && from(ga) === 1, "host broadcast reaches every client");
  host.sendB(-ja.id, new Uint8Array([2]));
  const gb2 = await b.next((m) => m.bin), ga2 = await a.next((m) => m.bin, 300);
  check(gb2?.bin[4] === 2 && ga2 === null, "broadcast-except skips that client");
  host.sendB(jb.id, new Uint8Array([3]));
  const gb3 = await b.next((m) => m.bin), ga3 = await a.next((m) => m.bin, 300);
  check(gb3?.bin[4] === 3 && ga3 === null, "a targeted packet reaches only its target");
  c.sendJ({ op: "join", game: "HAIKAI_CHAOS", proto: 2, code: hosted.code });
  const bad = await c.next();
  check(bad?.op === "error", "an old game version can't join (" + bad?.message + ")");
  a.ws.close();
  const left = await host.next((m) => m.op === "peer_left");
  check(left?.id === ja.id, "the host hears a client leave");
  host.ws.close();
  const gone = await b.next((m) => m.op === "host_left");
  check(!!gone, "clients hear the host leave");
  const d = client();
  await d.ready;
  d.sendJ({ op: "list", ...game });
  const empty = await d.next((m) => m.op === "rooms");
  check(empty?.rooms.length === 0, "the room is gone from the list");
  d.ws.close();
  console.log(`RELAY TESTS: ${failed ? failed + " FAILED" : "PASS"}`);
  server.kill();
  process.exit(failed ? 1 : 0);
}
main().catch((e) => {
  console.error(e);
  server.kill();
  process.exit(1);
});
