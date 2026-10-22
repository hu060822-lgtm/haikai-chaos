// The relay on Cloudflare Workers (free plan): one Durable Object holds every room, so a
// host and its clients always meet in the same place. Deploy: npx wrangler deploy
import { Relay } from "./core.js";

export default {
  async fetch(request, env) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("HAIKAI: CHAOS relay\n", { headers: { "content-type": "text/plain" } });
    }
    const stub = env.RELAY.get(env.RELAY.idFromName("global"));
    return stub.fetch(request);
  },
};

export class RelayRoom {
  constructor(state, env) {
    this.relay = new Relay();
  }

  async fetch(request) {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    const conn = { send: (d) => server.send(d), close: (c, r) => server.close(c, r) };
    this.relay.open(conn);
    server.addEventListener("message", (event) => {
      const d = event.data;
      this.relay.message(conn, typeof d === "string" ? d : new Uint8Array(d));
    });
    server.addEventListener("close", () => this.relay.close(conn));
    server.addEventListener("error", () => this.relay.close(conn));
    return new Response(null, { status: 101, webSocket: client });
  }
}
