# HAIKAI: CHAOS

HAIKAI 的衍伸作：回合制競技 PvP 射擊（瓦羅蘭 / CS:GO 的骨架），核心是自由、不講道理的改槍和高上限身法。
美術風格：**Counterform Industrial**（正式風格，規範見 [`docs/COUNTERFORM.md`](docs/COUNTERFORM.md)）；舊的 FAULTPRINT 印刷風保留為設定裡的選項。引擎：Godot 4.3（GL Compatibility）。

目前是 **C4 原型**：兩種連線模式（改版死鬥、回合制「預算戰」）、**中繼伺服器**（五碼房間碼，不同網路直接連）、主機判定＋延遲補償、擊殺回放、重做的第一人稱手臂。三張地圖（灰盒對戰圖 FOLDED WORKS、夢核地圖「夢核之家」、移動測試場 MOVEMENT LAB）、完整的前端（主畫面、快速配對、自訂房間、房間大廳、計分板、結算畫面）、原創配樂（大廳、對戰、結算）、單機練習（陪練機器人、靶場）、**連線團隊模式「改版死鬥 PATCH WAR」**（最多 10 人，空位補機器人）、改槍工作台（223 個零件）、換彈手部動作、擊殺列表、死亡畫面、移動除錯面板。

## C4 新東西

- **中繼伺服器**（`relay/`）：房主和玩家都只連到中繼伺服器，它在同一間房裡轉送封包，所以不同網路的人用 **5 個字的房間碼**（例如 `7AN68`）就能連，不用開埠、不用 Radmin。遊戲內建 `wss://haikai-relay.hu060822.workers.dev`（Cloudflare Workers 免費方案，部署方式見 [`relay/README.md`](relay/README.md)）；設定（Esc）→「中繼伺服器」可以換成別台。自訂房間預設開在中繼伺服器上（另有「只在區網開房」），快速配對也會找中繼伺服器上的房間。舊的 10 字區網房間碼照樣能用。
- **預算戰 BUDGET WAR**（回合制，房間大廳選模式）：每回合一條命，先贏 N 回合（2–9，預設 5）。開頭 15 秒備戰，被關在重生圈裡，**工作台就是商店**：槍身和零件都有價錢，加上去付全價、拆下來退一半。活下來的人槍留著，陣亡就沒了，下回合從左輪重來。起始 $800；贏 $1500、輸 $1000（連輸每次多 $400，最多 +$800）；擊殺 +$100 再加對方槍價的 25%（拆件，上限 $1000）；助攻 +$50。回合結束條件：一隊全滅、時間到（剩下的總血量多的贏）、或最後 40 秒中央「超頻區」打開，只有一隊站在裡面 6 秒。機器人也會在預算內買槍。金錢和槍由主機記帳，客戶端花錢主機會再核一次。
- **主機判定與延遲補償**：客戶端照樣自己找命中（看到打到就是打到），但每一發都送到主機，主機用過去 1.2 秒的位置紀錄倒帶到射手看到的時間，檢查：射手是誰、受害者當時在不在那裡、子彈是不是從射手的位置射出、直線射擊中間有沒有牆（穿牆子彈除外）、傷害有沒有超過那把槍的上限、命中次數有沒有超過射速。通過才轉給受害者那台電腦。主機每秒 ping 每個人，計分板的延遲在中繼連線下也看得到。
- **擊殺回放**：一直在錄所有人的位置和彈道（最後 6 秒）。陣亡時死亡畫面先播最後 4 秒，鏡頭在殺手的肩膀後面看著你，最後 0.7 秒放慢；播完換成殺手的槍，R 鍵切換。
- **第一人稱手臂**：有關節的手指、指節護板、綁帶護手、有皺褶的袖子、手腕上的終端機，和槍的精細度一致。
- **夢核之家**：改成傍晚的光（暗很多），加了可牆跑的壁紙板（泳池上方）、浮空玩具方塊、南側橫梁、兩條溜滑梯。

## 配對與房間（C3）

- **開始配對**：自動在區網找開著的房間（UDP 24681 廣播），找到就加入人最少的；找不到就直接幫你開一間，之後按「開始配對」的人會自動進來。
- **自訂房間**：開房會得到一組**房間碼**（例如 `8G2KA-04R3R`，是 IP 和埠編碼成的 10 個字），複製給朋友貼上就能加入；也可以直接輸入 IP。下方列出區網裡所有開著的房間，點一下就加入。
- **開放網路連線**：房間大廳裡的按鈕會用 UPnP 在路由器上開埠，成功後給你一組外網房間碼；路由器不支援時改用 Radmin / ZeroTier 這類虛擬區網。
- 房間大廳：兩隊名單、準備狀態、換隊、地圖（折疊工廠／夢核之家／隨機）、房主設定每隊人數（1–5）、目標分數、時間上限、空位補機器人。
- 對戰中按住 Tab 看計分板（分數、擊殺、助攻、陣亡、延遲），輕按 Tab 開工作台。結算畫面有勝負、比分、MVP 和完整計分板。

## 改版死鬥 PATCH WAR（C2）

一人開房（UDP 埠 24680），其他人用房間碼、IP 或區網列表加入。規則全部繞著「改槍」這個核心：

- **版本新鮮度**：每一種確切的改裝組合都是一個「版本」。同一個版本你的前兩殺各 3 分、接著兩殺各 2 分、之後每殺 1 分（版本疲乏）。換任何一個零件、調任何一格微調，就是新版本，重新值 3 分。改槍是得分手段，不只是準備。
- **身法加分**：帶身法標籤的擊殺（牆跑、滑鏟、空中、重踩…）+1。
- **版本答案**：某個版本在整場累積 4 殺，就被公告為「版本答案」。拿著它的人全場透視可見（黃色菱形），擊殺他 +3。強勢配裝會被全場追殺，逼你換版本。
- **重生區＝改槍區**：每隊重生點有安全圈，圈內不能傷人也不會被傷；敵人踏進來每秒 25 傷害。圈內隨時能開工作台。
- **脫離戰鬥才能改槍**：圈外要 4 秒沒有受傷或造成傷害（開槍後 1.5 秒）才能開工作台；在外面改槍時被打中，工作台立刻關上（已改好的部分會裝上）。
- 死亡 4 秒後可重生，9 秒自動重生；死亡畫面可以抄下殺你的槍。
- **助攻**：同一條命裡對敵人造成 25 以上傷害、但不是最後一擊的人算助攻，個人分數 +1。
- 主機端只接受「擁有這個射手的電腦」送來的命中，隊友傷害和超過任何槍上限的傷害一律丟掉。

## 怎麼玩

1. 下載 [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/)（標準版）。
2. 打開 Godot → 匯入 → 選這個資料夾的 `project.godot` → 執行（F5）。

| 按鍵 | 動作 |
|---|---|
| WASD / Shift / Space | 移動 / 衝刺跑 / 跳 |
| Ctrl 或 C | 蹲；跑動中按下 = 滑鏟（下坡越滑越快，滑鏟中跳 = 滑鏟跳，空中按住蹲落地 = 接滑鏟） |
| 空中靠近有橘色線的牆 + 方向鍵沿著牆 | 牆跑；牆跑中 Space = 蹬牆跳，**往方向鍵指的方向跳**（不看鏡頭），離牆後一瞬間內按也算 |
| 空中貼任何牆按 Space | 踢牆（每次離地可踢幾次，看左下角菱形） |
| 面對牆按住 Space | 攀牆；手碰到邊緣會自動翻越 |
| Q | 衝刺閃避（兩格，各自充能）；衝刺中按跳 = 衝刺跳，保留衝刺速度 |
| 空中低頭看地面按蹲 | 重踩：砸向地面，震傷附近的人；落地瞬間按跳 = 重踩彈跳，摔多高彈多高（平視時按蹲只是準備落地滑鏟） |
| 左鍵 / 右鍵 / R / B | 開火 / 瞄準 / 換彈 / 射擊模式 |
| Tab | 改槍工作台（對戰中：輕按 = 工作台，按住 = 計分板） |
| F1 / F2 / F3 | 操作說明 / 敵我顏色（色盲模式）/ 機器人開火開關（只在練習） |
| F4 / F5 / F7 | 移動除錯面板 / 鏡頭效果（完整、減少、關閉）/ 物理頻率 60·120·240 Hz |
| T | 移動測試場：回到目前路線起點 |
| Esc | 設定：滑鼠靈敏度、FOV、V-Sync、FPS 顯示、畫面風格（原版／柔和／暗色印刷，預設暗色）、描邊、像素化（2×–4×）、鏡頭效果、**所有按鍵都能改** |

## 夢核之家（C3 新地圖）

粉彩色調、過亮的室內，像小時候記憶裡變形的家。南邊是藍隊的**嬰兒房**，北邊是紅隊的**客廳**（電視只有雜訊）。中央是**沒有水的磁磚泳池**（深 1.6 m，坡道和階梯進出，池底有一隻大鴨子），西邊是**無盡走廊**（中間的牆可以牆跑，上面有天花板走道），東邊是**巨人餐廳**（桌面高 2.2 m，可以跳上去打，旁邊有夾層和書櫃）。北邊 5 m 高的橫梁連接兩側，天上飄著雲、門和通往天空的樓梯。

## 移動測試場

主畫面選「練習場」→「移動測試場」。三條計時路線從南邊的起點區往北跑，穿過藍綠色起點門開始計時、黃色終點門停止，會記錄最佳時間、平均與最低速度、動量中斷次數：

- **A 滑鏟循環**：衝刺 → 下坡滑鏟 → 滑鏟跳過欄 → 落地接滑鏟 → 再跳
- **B 牆跑連段**：跳上左牆 → 蹬牆跳（W+D）→ 右牆 → 蹬牆跳（W+A）→ 四面牆
- **C 高速綜合**：長坡滑鏟 → 滑鏟跳過溝並在空中射擊標靶 → 踢右牆上平台 → 高速落地

東邊是自由練習區：五種高度的障礙、長牆、短牆、相鄰雙牆、轉角、踢牆井、窄平台、12 m 落地塔、落點修正區。

## 移動系統

所有參數都在 `scripts/player/move_tuning.gd`，附單位和說明。原則：速度向量是唯一的真相，任何狀態都不會直接把速度設成固定值，只會加速、摩擦、阻力。每個狀態有自己的上限：地面超速時線性衰減、快速落地後 0.4 秒不減速、滑鏟下坡加速、空中轉向速率隨速度降低、牆跑趨近 12 m/s。

C1.1 調整（參考泰坦殞落 2 和 ULTRAKILL）：跑速 7.4、衝刺 10.2、牆跑 12 m/s；蹬牆跳和踢牆完全保留速度，方向跟方向鍵；牆跑前段幾乎不掉、最後三分之一才慢慢下沉（最快 2 m/s）；衝刺跳、重踩彈跳；速度越快 FOV 越寬（最多 +12°）、畫面邊緣出現速度線、風聲變大。延遲：鏡頭每個畫面都插值（不再跟 120 Hz 物理一格一格跳）、預設關 V-Sync、不限 FPS、輸入事件即時處理。

C3 調整（參考 ULTRAKILL 和 Apex）：跑速 7.9、衝刺跑 11.0、地面加速更快；**衝刺兩格**，可以連續閃兩次；空中扭轉加速（兔子跳）提高到 3 m/s²、上限 17 m/s；滑鏟加速 4.2 m/s、冷卻 0.9 秒；快速落地後 0.4 秒不減速，連跳更好接。三條路線的時間都變快（A 5.90→5.50 秒、C 6.52→6.13 秒）。擊殺時鏡頭會往前一推，練習模式還有 0.06 秒的頓格。

**槍越重，身法越鈍。** 右下角的「機動性」就是槍的重量換算出來的：輕手槍跑得快、踢牆次數多；12 kg 的機槍幾乎只能在地上走。

## 程式結構

| 路徑 | 內容 |
|---|---|
| `scripts/style/counterform.gd` | Counterform Industrial：色票、材質類別（混凝土、塗裝金屬、氧化、裸金屬、聚合物、橡膠、玻璃）、程序貼圖、光照與霧、超現實遠景 |
| `scripts/style/faultprint.gd` | 美術風格的唯一入口：色盤、材質、描邊、環境光。換風格只動這裡和 `shaders/` |
| `shaders/faultprint.gdshader` | 三階色塊光影 + 半色調網點（隨距離換層級）+ 套色偏移的第二版 + 墨色缺損 |
| `shaders/fp_misreg.gdshader` | 物件輪廓外的套色偏移（只用在場景，不用在角色） |
| `scripts/weapons/arsenal.gd` | 改槍系統（38 種槍身、223 個零件），CHAOS 新增的槍與零件在檔案後段 |
| `scripts/weapons/gun_kit.gd` | 精密槍件的兩種基本形：側面輪廓擠出（`slab`）與車床件（`turned`） |
| `scripts/weapons/gun_frames.gd` | 每種槍身的機匣外型與零件安裝點 |
| `scripts/weapons/gun_models.gd` | 依改裝組出整把槍：槍管、槍口、瞄具、握把、扳機、槍機、彈匣、槍托、吊飾 |
| `scripts/weapons/weapon.gd` | 一把槍的使用狀態與射擊判定（玩家、機器人共用）；PvP 傷害表 `STK`；特殊效果（後座推人、飛鉤、跳彈、吸血、賭命、獵頭、空戰、疾風…）說明在檔案開頭 |
| `scripts/weapons/gun_names.gd` | 自動槍名、隨機組槍 |
| `scripts/weapons/blueprints.gd` | 藍圖存檔（`user://blueprints.json`） |
| `scripts/player/player.gd` | 玩家：動量移動與所有身法、輸入緩衝、狀態轉換紀錄、開槍、受傷 |
| `scripts/player/move_tuning.gd` | 所有移動參數（單位、說明） |
| `scripts/player/camera_fx.gd` | 鏡頭效果：每種效果獨立的彈簧或平滑，強度可調 |
| `scripts/settings.gd`, `scripts/input_setup.gd`, `scripts/ui/settings_menu.gd` | 設定（`user://settings.cfg`）、按鍵註冊與自訂、Esc 設定選單 |
| `scripts/ui/speed_lines.gd` | 高速時的速度線 |
| `scripts/ui/move_debug.gd` | F4 移動除錯面板與場景內的射線、速度向量、碰撞體 |
| `scripts/maps/movement_lab.gd` | 移動測試場、計時路線 |
| `scripts/net/net_session.gd` | 連線：開房／加入（ENet）、大廳名單與隊伍、房間設定、開始與回大廳 |
| `scripts/net/avatar.gd` | 別台電腦上的玩家（或房主的機器人）：狀態插值、判定框、命中轉給擁有者 |
| `scripts/match/team_match.gd` | 改版死鬥：重生、狀態同步、命中與死亡、版本新鮮度計分、版本答案 |
| `scripts/match/safe_zone.gd` | 重生安全圈與「脫離戰鬥」規則 |
| `scripts/match/round_rules.gd` | 預算戰：回合、商店價格、金錢、超頻區 |
| `scripts/match/hit_judge.gd` | 主機的命中判定（倒帶驗證、射速桶） |
| `scripts/fx/kill_cam.gd` | 擊殺回放（錄影、鬼影、肩後鏡頭） |
| `scripts/net/relay_peer.gd`, `relay/` | 中繼連線（MultiplayerPeer）與中繼伺服器（Node／Cloudflare Worker） |
| `scripts/ui/lobby.gd` | 房間大廳（房間碼、隊伍、準備、地圖、規則） |
| `scripts/ui/front_end.gd` | 主畫面、練習場、自訂房間、快速配對頁 |
| `scripts/ui/scoreboard.gd` | 計分板（按住 Tab、結算畫面） |
| `scripts/net/matchmaker.gd` | 房間碼、區網廣播與搜尋、UPnP |
| `scripts/maps/dream_home.gd` | 夢核之家：自製材質（壁紙、地毯、磁磚、雲、雜訊）和整張地圖 |
| `scripts/music.gd`, `tools/music/compose.py` | 音樂播放（交叉淡入、音量匯流排）；配樂是用 Python 合成器寫出來的（`python3 tools/music/compose.py audio/music`） |
| `fonts/` | Chakra Petch、Barlow Condensed、Noto Sans TC（SIL OFL，授權檔在同一個資料夾） |
| `scripts/player/view_model.gd` | 第一人稱槍（手套、晃動、後座、換彈、瞄準對準準心） |
| `scripts/actors/` | 陪練機器人、角色模型、靶 |
| `scripts/maps/geo.gd`, `folded_works.gd` | 關卡積木（可牆跑的牆、楔形、坡道、樓梯）與測試地圖 |
| `scripts/ui/` | HUD、擊殺列表、死亡畫面、改槍工作台、UI 套件、槍縮圖 |
| `scripts/fx/print_fx.gd` | 印刷風格的戰鬥特效（槍口星形、彈道、撞擊、落地圈） |
| `scripts/sfx.gd` | 暫時用的合成音效 |

## 測試與截圖

```
tools/run_tests.sh <godot 路徑>    # 全部測試：舊的身法/開槍/TTK、槍與零件、C2 零件與計分、手感 20 項、三條路線（60/120/240 Hz）、連線
tools/net_test.sh <godot 路徑>     # 連線測試：同一台電腦開房主＋用戶端兩個程序，各自檢查自己那邊（第三個參數 relay＝透過本機中繼伺服器）
godot --headless --path . --script res://tests/rounds_test.gd   # 預算戰
godot --headless --path . --script res://tests/judge_test.gd    # 主機命中判定
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/rounds_shots.gd -- <資料夾>   # 預算戰（大廳、備戰、商店、超頻區）
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/killcam_shots.gd -- <資料夾>  # 擊殺回放
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/arms_shots.gd -- <資料夾>     # 第一人稱手臂
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c3_shots.gd -- <資料夾>      # C3 截圖（主畫面、配對、大廳、夢核之家、HUD、計分板、結算）
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/dream_shots.gd -- <資料夾>   # 夢核之家各區域
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c2_shots.gd -- <資料夾>      # C2 截圖（大廳、對戰、結算）
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/reload_shots.gd -- <資料夾>  # 換彈動作分格、死亡畫面三種解析度
godot --headless --path . --script res://tests/movement_test.gd      # 身法、開槍、TTK 自動測試
godot --headless --fixed-fps 120 --path . --script res://tests/movement_feel_test.gd -- 120
godot --headless --fixed-fps 120 --path . --script res://tests/route_test.gd -- 120
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/lab_shots.gd -- <資料夾>
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c11_shots.gd -- <資料夾>
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/cf_shots.gd -- <資料夾>      # Counterform 截圖（MAP=folded 換對戰圖）
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/gun_gallery.gd -- <資料夾>   # 槍械型錄（FRAMES=、MODS=1、PARTS=、CLOSE=）
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/character_shots.gd -- <資料夾>
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/look_shots.gd -- <資料夾>   # 三種畫面風格對照
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/game_shots.gd -- <資料夾>
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/map_shots.gd -- <資料夾>
```
