@echo off
rem HAIKAI: CHAOS relay: puts the relay server on Cloudflare (free plan).
rem Needs Node.js (https://nodejs.org). The first time, a browser opens to sign in to Cloudflare.
cd /d "%~dp0"
call npm install --no-audit --no-fund
call npx wrangler login
call npx wrangler deploy
echo.
echo Copy the https://haikai-relay....workers.dev address above and send it back.
pause
