// HAIKAI: CHAOS relay: rooms on a public server, so players on different networks can
// play with no port forwarding. The host and every client keep one WebSocket to the
// relay; the relay forwards game packets between a room's host and its clients.
//
// Shared by the Node server (node_server.js) and the Cloudflare Worker (worker.js).
//
// Control messages are JSON text frames:
//   -> {op:"host", game, proto, name, info}   <- {op:"hosted", code, id:1}
//   -> {op:"join", game, proto, code, name}   <- {op:"joined", code, id}   (host gets {op:"peer_joined", id, name})
//   -> {op:"info", info}                      (host: what the room list shows)
//   -> {op:"list", game, proto}               <- {op:"rooms", rooms:[{code, name, players, max, map, in_match}]}
//   -> {op:"kick", id}                        (host)
//   -> {op:"ping", t}                         <- {op:"pong", t}
//   <- {op:"error", message}                  (then the socket closes)
//   <- {op:"peer_left", id}                   (host)
//   <- {op:"host_left"}                       (clients; then the socket closes)
// Game packets are binary frames: a little-endian int32 then the payload.
//   client -> relay: the int32 is ignored (everything goes to the host)
//   host -> relay:   the target: 0 every client, n > 0 that client, n < 0 everyone but -n
//   relay -> anyone: the int32 is the sender's id

const CODE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const CODE_LENGTH = 5;
const MAX_ROOMS = 500;
const MAX_PEERS = 16;
const MAX_PACKET = 1 << 20;

export class Relay {
  constructor(random = Math.random) {
    this.random = random;
    this.rooms = new Map(); // code -> {code, game, proto, host, peers: Map(id -> conn), nextId, info}
  }

  // A new socket. `conn` is {send(data), close(code, reason)}; the relay adds its fields.
  open(conn) {
    conn.room = null;
    conn.id = 0;
  }

  message(conn, data) {
    if (typeof data === "string") {
      let msg;
      try {
        msg = JSON.parse(data);
      } catch {
        return this.fail(conn, "bad message");
      }
      return this.control(conn, msg || {});
    }
    const bytes = data instanceof Uint8Array ? data : new Uint8Array(data);
    if (!conn.room || bytes.length < 4 || bytes.length > MAX_PACKET) return;
    const room = conn.room;
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const target = view.getInt32(0, true);
    // Rewrite the header to the sender's id, then deliver.
    const out = new Uint8Array(bytes);
    new DataView(out.buffer).setInt32(0, conn.id, true);
    if (conn.id !== 1) {
      safeSend(room.host, out);
      return;
    }
    if (target > 0) {
      const to = room.peers.get(target);
      if (to) safeSend(to, out);
      return;
    }
    for (const [id, to] of room.peers) {
      if (target < 0 && id === -target) continue;
      safeSend(to, out);
    }
  }

  control(conn, msg) {
    switch (msg.op) {
      case "host": {
        if (conn.room) return this.fail(conn, "already in a room");
        if (this.rooms.size >= MAX_ROOMS) return this.fail(conn, "relay full");
        const code = this.newCode();
        const room = {
          code, game: String(msg.game || ""), proto: msg.proto | 0, host: conn, peers: new Map(), nextId: 2,
          info: cleanInfo(msg.info, msg.name),
        };
        this.rooms.set(code, room);
        conn.room = room;
        conn.id = 1;
        return safeSend(conn, JSON.stringify({ op: "hosted", code, id: 1 }));
      }
      case "join": {
        if (conn.room) return this.fail(conn, "already in a room");
        const room = this.rooms.get(String(msg.code || "").toUpperCase());
        if (!room) return this.fail(conn, "no such room");
        if (room.game !== String(msg.game || "") || room.proto !== (msg.proto | 0)) return this.fail(conn, "different game version");
        if (room.peers.size + 1 >= MAX_PEERS) return this.fail(conn, "room full");
        const id = room.nextId++;
        room.peers.set(id, conn);
        conn.room = room;
        conn.id = id;
        safeSend(conn, JSON.stringify({ op: "joined", code: room.code, id }));
        return safeSend(room.host, JSON.stringify({ op: "peer_joined", id, name: String(msg.name || "").slice(0, 32) }));
      }
      case "info":
        if (conn.room && conn.id === 1) conn.room.info = cleanInfo(msg.info, conn.room.info.name);
        return;
      case "list": {
        const rooms = [];
        for (const room of this.rooms.values()) {
          if (room.game !== String(msg.game || "") || room.proto !== (msg.proto | 0)) continue;
          rooms.push({ code: room.code, players: room.peers.size + 1, ...room.info });
          if (rooms.length >= 50) break;
        }
        return safeSend(conn, JSON.stringify({ op: "rooms", rooms }));
      }
      case "kick": {
        if (!conn.room || conn.id !== 1) return;
        const to = conn.room.peers.get(msg.id | 0);
        if (to) {
          safeSend(to, JSON.stringify({ op: "error", message: "kicked" }));
          safeClose(to);
          this.close(to);
        }
        return;
      }
      case "ping":
        return safeSend(conn, JSON.stringify({ op: "pong", t: msg.t }));
      default:
        return this.fail(conn, "unknown op");
    }
  }

  // The socket closed (or errored).
  close(conn) {
    const room = conn.room;
    if (!room) return;
    conn.room = null;
    if (conn.id === 1) {
      this.rooms.delete(room.code);
      for (const peer of room.peers.values()) {
        peer.room = null;
        safeSend(peer, JSON.stringify({ op: "host_left" }));
        safeClose(peer);
      }
      room.peers.clear();
      return;
    }
    if (room.peers.get(conn.id) === conn) {
      room.peers.delete(conn.id);
      safeSend(room.host, JSON.stringify({ op: "peer_left", id: conn.id }));
    }
  }

  fail(conn, message) {
    safeSend(conn, JSON.stringify({ op: "error", message }));
    safeClose(conn);
    this.close(conn);
  }

  newCode() {
    for (;;) {
      let code = "";
      for (let i = 0; i < CODE_LENGTH; i++) code += CODE_ALPHABET[Math.floor(this.random() * CODE_ALPHABET.length)];
      if (!this.rooms.has(code)) return code;
    }
  }
}

function cleanInfo(info, name) {
  info = info && typeof info === "object" ? info : {};
  return {
    name: String(info.name || name || "?").slice(0, 32),
    max: Math.max(2, Math.min(MAX_PEERS, info.max | 0 || 10)),
    map: String(info.map || "").slice(0, 16),
    in_match: !!info.in_match,
  };
}

function safeSend(conn, data) {
  try {
    conn.send(data);
  } catch {
    // The socket is going away; its close handler cleans up.
  }
}

function safeClose(conn) {
  try {
    conn.close(1000, "bye");
  } catch {
    // Already closed.
  }
}
