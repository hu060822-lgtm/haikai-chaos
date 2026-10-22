#!/bin/bash
# HAIKAI: CHAOS relay: puts the relay server on Cloudflare (free plan). Needs Node.js.
cd "$(dirname "$0")"
npm install --no-audit --no-fund && npx wrangler login && npx wrangler deploy
