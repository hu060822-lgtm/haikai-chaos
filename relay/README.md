# HAIKAI: CHAOS 中繼伺服器（relay）

讓不同網路的玩家不用設定路由器就能連線：房主和每個玩家都只連到中繼伺服器，伺服器在同一間房裡轉送封包。房間碼是 5 個字（例如 `7AN68`）。

## 放上網路（Cloudflare，免費）

1. 裝 [Node.js](https://nodejs.org)（LTS 版）。
2. 申請免費的 [Cloudflare](https://dash.cloudflare.com/sign-up) 帳號。
3. Windows：雙擊 `relay/deploy.bat`；Mac / Linux：執行 `relay/deploy.sh`。第一次會開瀏覽器登入 Cloudflare。
4. 最後會印出一個網址，例如 `https://haikai-relay.xxxx.workers.dev`。遊戲裡用的是 `wss://haikai-relay.xxxx.workers.dev`：
   - 寫進 `scripts/net/matchmaker.gd` 的 `DEFAULT_RELAY`，所有人的遊戲就會內建；或
   - 在遊戲的設定（Esc）→「中繼伺服器」貼上。

免費方案每天 10 萬次請求；WebSocket 訊息以 20 則算 1 次，十個人打一場 8 分鐘大約用 5,000 次。

## 自己架（任何有 Node.js 的電腦或主機）

```
cd relay
npm install
node node_server.js 24700        # ws://這台電腦的 IP:24700
```

## 測試

```
node test.js                     # 協定測試
tools/net_test.sh <godot> 24692 relay   # 兩個遊戲程序透過中繼打一場
```

## 協定

見 `core.js` 開頭的說明：控制訊息是 JSON 文字，遊戲封包是二進位（前 4 位元組是目標或來源的 id）。
