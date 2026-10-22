// The relay as a plain Node server (self-hosting, and the tests): node node_server.js [port]
import { WebSocketServer } from "ws";
import { Relay } from "./core.js";

const port = Number(process.argv[2] || process.env.PORT || 24700);
const relay = new Relay();
const wss = new WebSocketServer({ port, maxPayload: 1 << 20 });

wss.on("connection", (ws) => {
  const conn = { send: (d) => ws.send(d), close: (c, r) => ws.close(c, r) };
  relay.open(conn);
  ws.on("message", (data, isBinary) => relay.message(conn, isBinary ? new Uint8Array(data) : data.toString()));
  ws.on("close", () => relay.close(conn));
  ws.on("error", () => relay.close(conn));
});

console.log(`HAIKAI relay on ws://0.0.0.0:${port}`);
