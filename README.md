# HAIKAI: CHAOS

HAIKAI 的衍伸作：回合制競技 PvP 射擊（瓦羅蘭 / CS:GO 的骨架），核心是自由、不講道理的改槍和高上限身法。
美術風格：**FAULTPRINT 斷層印刷體**。引擎：Godot 4.3（GL Compatibility）。

目前是 **C0 原型**：單機、一張灰盒地圖 FOLDED WORKS、三個陪練機器人、靶場、改槍工作台、擊殺列表、死亡畫面。還沒有連線（C2 才做）。

## 怎麼玩

1. 下載 [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/)（標準版）。
2. 打開 Godot → 匯入 → 選這個資料夾的 `project.godot` → 執行（F5）。

| 按鍵 | 動作 |
|---|---|
| WASD / Shift / Space | 移動 / 衝刺跑 / 跳 |
| Ctrl 或 C | 蹲；快跑中按下 = 滑鏟（下坡更快，滑鏟中跳 = 滑鏟跳） |
| 空中靠近有橘色線的牆 + 按住 W | 牆跑；牆跑中 Space = 蹬牆跳 |
| 空中貼任何牆按 Space | 踢牆（每次離地可踢幾次，看左下角菱形） |
| 面對牆按住 Space | 攀牆；手碰到邊緣會自動翻越 |
| Q | 衝刺閃避（有冷卻） |
| 空中高處按蹲 | 重踩：砸向地面，震傷附近的人 |
| 左鍵 / 右鍵 / R / B | 開火 / 瞄準 / 換彈 / 射擊模式 |
| Tab | 改槍工作台 |
| F1 / F2 / F3 | 操作說明 / 敵我顏色（色盲模式）/ 機器人開火開關 |

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
| `scripts/player/player.gd` | 玩家：動量移動與所有身法、開槍、受傷 |
| `scripts/player/view_model.gd` | 第一人稱槍（手套、晃動、後座、換彈、瞄準對準準心） |
| `scripts/actors/` | 陪練機器人、角色模型、靶 |
| `scripts/maps/geo.gd`, `folded_works.gd` | 關卡積木（可牆跑的牆、楔形、坡道、樓梯）與測試地圖 |
| `scripts/ui/` | HUD、擊殺列表、死亡畫面、改槍工作台、UI 套件、槍縮圖 |
| `scripts/fx/print_fx.gd` | 印刷風格的戰鬥特效（槍口星形、彈道、撞擊、落地圈） |
| `scripts/sfx.gd` | 暫時用的合成音效 |

## 測試與截圖

```
godot --headless --path . --script res://tests/movement_test.gd      # 身法、開槍、TTK 自動測試
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/game_shots.gd -- <資料夾>
xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/map_shots.gd -- <資料夾>
```
