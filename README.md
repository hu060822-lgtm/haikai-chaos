# HAIKAI: CHAOS

HAIKAI 的衍伸作：回合制競技 PvP 射擊（瓦羅蘭 / CS:GO 的骨架），核心是自由、不講道理的改槍和高上限身法。
美術風格：**FAULTPRINT 斷層印刷體**。引擎：Godot 4.3（GL Compatibility）。

目前是 **C1.1 原型（移動手感第二輪）**：單機、兩張地圖（灰盒對戰圖 FOLDED WORKS、移動測試場 MOVEMENT LAB）、三個陪練機器人、靶場、改槍工作台、擊殺列表、死亡畫面、移動除錯面板。還沒有連線（C2 才做）。

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
| Q | 衝刺閃避（有冷卻）；衝刺中按跳 = 衝刺跳，保留衝刺速度 |
| 空中低頭看地面按蹲 | 重踩：砸向地面，震傷附近的人；落地瞬間按跳 = 重踩彈跳，摔多高彈多高（平視時按蹲只是準備落地滑鏟） |
| 左鍵 / 右鍵 / R / B | 開火 / 瞄準 / 換彈 / 射擊模式 |
| Tab | 改槍工作台 |
| F1 / F2 / F3 | 操作說明 / 敵我顏色（色盲模式）/ 機器人開火開關 |
| F4 / F5 / F7 | 移動除錯面板 / 鏡頭效果（完整、減少、關閉）/ 物理頻率 60·120·240 Hz |
| T | 移動測試場：回到目前路線起點 |
| Esc | 設定：滑鼠靈敏度、FOV、V-Sync、FPS 顯示、畫面風格（原版／柔和／暗色印刷，預設暗色）、描邊、像素化（2×–4×）、鏡頭效果、**所有按鍵都能改** |

## 移動測試場

標題畫面選「移動測試場」。三條計時路線從南邊的起點區往北跑，穿過藍綠色起點門開始計時、黃色終點門停止，會記錄最佳時間、平均與最低速度、動量中斷次數：

- **A 滑鏟循環**：衝刺 → 下坡滑鏟 → 滑鏟跳過欄 → 落地接滑鏟 → 再跳
- **B 牆跑連段**：跳上左牆 → 蹬牆跳（W+D）→ 右牆 → 蹬牆跳（W+A）→ 四面牆
- **C 高速綜合**：長坡滑鏟 → 滑鏟跳過溝並在空中射擊標靶 → 踢右牆上平台 → 高速落地

東邊是自由練習區：五種高度的障礙、長牆、短牆、相鄰雙牆、轉角、踢牆井、窄平台、12 m 落地塔、落點修正區。

## 移動系統

所有參數都在 `scripts/player/move_tuning.gd`，附單位和說明。原則：速度向量是唯一的真相，任何狀態都不會直接把速度設成固定值，只會加速、摩擦、阻力。每個狀態有自己的上限：地面超速時線性衰減、快速落地後 0.3 秒不減速、滑鏟下坡加速、空中轉向速率隨速度降低、牆跑趨近 12 m/s。

C1.1 調整（參考泰坦殞落 2 和 ULTRAKILL）：跑速 7.4、衝刺 10.2、牆跑 12 m/s；蹬牆跳和踢牆完全保留速度，方向跟方向鍵；牆跑前段幾乎不掉、最後三分之一才慢慢下沉（最快 2 m/s）；衝刺跳、重踩彈跳；速度越快 FOV 越寬（最多 +12°）、畫面邊緣出現速度線、風聲變大。延遲：鏡頭每個畫面都插值（不再跟 120 Hz 物理一格一格跳）、預設關 V-Sync、不限 FPS、輸入事件即時處理。

**槍越重，身法越鈍。** 右下角的「機動性」就是槍的重量換算出來的：輕手槍跑得快、踢牆次數多；12 kg 的機槍幾乎只能在地上走。

## 程式結構

| 路徑 | 內容 |
|---|---|
| `scripts/style/faultprint.gd` | 美術風格的唯一入口：色盤、材質、描邊、環境光。換風格只動這裡和 `shaders/` |
| `shaders/faultprint.gdshader` | 三階色塊光影 + 半色調網點（隨距離換層級）+ 套色偏移的第二版 + 墨色缺損 |
| `shaders/fp_misreg.gdshader` | 物件輪廓外的套色偏移（只用在場景，不用在角色） |
| `scripts/weapons/arsenal.gd` | 從 HAIKAI 搬來的改槍系統（28 種槍身、156 個零件，器官已移除） |
| `scripts/weapons/gun_models.gd` | 從 HAIKAI 搬來的槍模型組裝，改用 FAULTPRINT 材質 |
| `scripts/weapons/weapon.gd` | 一把槍的使用狀態與射擊判定（玩家、機器人共用）；PvP 傷害表 `STK` |
| `scripts/weapons/gun_names.gd` | 自動槍名、隨機組槍 |
| `scripts/weapons/blueprints.gd` | 藍圖存檔（`user://blueprints.json`） |
| `scripts/player/player.gd` | 玩家：動量移動與所有身法、輸入緩衝、狀態轉換紀錄、開槍、受傷 |
| `scripts/player/move_tuning.gd` | 所有移動參數（單位、說明） |
| `scripts/player/camera_fx.gd` | 鏡頭效果：每種效果獨立的彈簧或平滑，強度可調 |
| `scripts/settings.gd`, `scripts/input_setup.gd`, `scripts/ui/settings_menu.gd` | 設定（`user://settings.cfg`）、按鍵註冊與自訂、Esc 設定選單 |
| `scripts/ui/speed_lines.gd` | 高速時的速度線 |
| `scripts/ui/move_debug.gd` | F4 移動除錯面板與場景內的射線、速度向量、碰撞體 |
| `scripts/maps/movement_lab.gd` | 移動測試場、計時路線 |
| `scripts/player/view_model.gd` | 第一人稱槍（手套、晃動、後座、換彈、瞄準對準準心） |
| `scripts/actors/` | 陪練機器人、角色模型、靶 |
| `scripts/maps/geo.gd`, `folded_works.gd` | 關卡積木（可牆跑的牆、楔形、坡道、樓梯）與測試地圖 |
| `scripts/ui/` | HUD、擊殺列表、死亡畫面、改槍工作台、UI 套件、槍縮圖 |
| `scripts/fx/print_fx.gd` | 印刷風格的戰鬥特效（槍口星形、彈道、撞擊、落地圈） |
| `scripts/sfx.gd` | 暫時用的合成音效 |

## 測試與截圖

```
tools/run_tests.sh <godot 路徑>    # 全部測試：舊的身法/開槍/TTK、手感 20 項、三條路線，各在 60/120/240 Hz
godot --headless --path . --script res://tests/movement_test.gd      # 身法、開槍、TTK 自動測試
godot --headless --fixed-fps 120 --path . --script res://tests/movement_feel_test.gd -- 120
godot --headless --fixed-fps 120 --path . --script res://tests/route_test.gd -- 120
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/lab_shots.gd -- <資料夾>
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c11_shots.gd -- <資料夾>
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/look_shots.gd -- <資料夾>   # 三種畫面風格對照
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/game_shots.gd -- <資料夾>
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/map_shots.gd -- <資料夾>
```
