extends Node
## 商店视觉环境生成器
## 第三人称身后视角 - 镜头位于店主身后，看向店内深处
## 纯2D分层布景：近端大货架→中端货架→远端小货架→玻璃门
##
## 屏幕布局：
## ┌─────────────────────────────────────┐
## │  💰12450  🤝信誉68  📅第23天  升级按钮  │ y=0~50   顶部状态栏（UI层）
## ├─────────────────────────────────────┤
## │     🚪 玻璃店门（远景，门外雨景）     │ y=51~150  门区
## │   📚远端货架 │ 地毯 │ 📚远端货架      │ y=100~220
## │   📚中远端   │ 走道  │ 📚中远端        │ y=170~320
## │   📚中近端   │ 通道  │ 📚中近端        │ y=260~420
## │   📚近端货架 │ ｀｀  │ 📚近端货架      │ y=360~500
## │  ┌────────── 柜台 ──────────┐        │ y=490~650
## │  │🧑店主背影 台灯 账本 小黑板│        │
## └─────────────────────────────────────┘
##   x=0                              x=800

const SCREEN_W := 1280
const SCREEN_H := 720

# ---- 颜色常量 ----
const WALL_COLOR := Color(0.15, 0.08, 0.04)        # 深色墙壁
const FLOOR_COLOR := Color(0.22, 0.14, 0.08)        # 地板色
const WOOD_DARK := Color(0.25, 0.12, 0.05)          # 深木色
const WOOD_MEDIUM := Color(0.35, 0.18, 0.08)        # 中木色
const WOOD_LIGHT := Color(0.45, 0.25, 0.12)         # 浅木色
const SHELF_COLOR := Color(0.30, 0.16, 0.07)        # 货架木色
const ITEM_BG := Color(0.15, 0.12, 0.08)            # 物品背景
const GOLD_ACCENT := Color(0.85, 0.65, 0.15)        # 金色装饰
const WARM_GLOW := Color(1.0, 0.7, 0.2, 0.10)      # 暖色光晕

# ---- 物品视觉映射 ----
const ITEM_VISUALS := {
	"兽皮": { "color": Color(0.6, 0.35, 0.2), "icon": "🦴" },
	"毒液": { "color": Color(0.2, 0.7, 0.3), "icon": "🧪" },
	"甲壳": { "color": Color(0.5, 0.3, 0.15), "icon": "🛡️" },
	"魔核": { "color": Color(0.7, 0.2, 0.7), "icon": "💎" },
	"腺体": { "color": Color(0.8, 0.4, 0.6), "icon": "🧬" },
	"爪牙": { "color": Color(0.9, 0.9, 0.5), "icon": "🗡️" },
	"粘液": { "color": Color(0.3, 0.8, 0.6), "icon": "💧" },
	"骨材": { "color": Color(0.9, 0.85, 0.7), "icon": "💀" },
	"鳞片": { "color": Color(0.4, 0.7, 0.6), "icon": "🐉" },
}

## 构建整个商店视觉环境
func build_shop(parent: Node) -> Dictionary:
	var nodes = {}
	
	# === 底层 ===
	# 全屏深色底
	_make_rect(parent, Color(0.08, 0.04, 0.02), 0, 0, 800, SCREEN_H)
	
	# 1. 远景墙壁（门两侧和上方的墙面）
	_build_far_wall(parent)
	
	# 2. 玻璃店门（远景中央，门外带雨景）
	nodes["door"] = _build_glass_door(parent)
	
	# 3. 地板系统（纵向木板+横向接缝）
	_build_floor(parent)
	
	# 4. 天花板+横梁
	_build_ceiling(parent)
	
	# 5. 左侧4层货架（近→远）
	nodes["left_shelves"] = _build_left_shelves(parent)
	
	# 6. 右侧4层货架（近→远）
	nodes["right_shelves"] = _build_right_shelves(parent)
	
	# 7. 过道地毯
	_build_carpet(parent)
	
	# 8. 中央吊灯
	nodes["chandelier"] = _build_chandelier(parent)
	
	# 9. 店门两侧壁灯
	_build_wall_sconces(parent)
	
	# 10. 柜台（带小黑板+台灯+账本+羽毛笔）
	nodes["counter"] = _build_counter(parent)
	
	# 11. 店主背影（固定在柜台后）
	nodes["shopkeeper"] = _build_shopkeeper(parent)
	
	# 12. 灯光氛围（暖色全店光晕+深处暗色渐变）
	nodes["lighting"] = _build_atmosphere(parent)
	
	# 13. 货架物品槽位
	var item_container = Node2D.new()
	item_container.name = "ShelfItemSlots"
	parent.add_child(item_container)
	nodes["item_slots"] = item_container
	
	# 14. 物品槽位位置（左侧近端2层货架）
	nodes["slot_positions"] = [
		Vector2(75, 390),   # 近端上层
		Vector2(75, 460),  # 近端下层
		Vector2(160, 390), # 中近端上层
		Vector2(160, 460), # 中近端下层
	]
	
	return nodes

# ========== ① 远景墙壁 ==========

func _build_far_wall(parent: Node) -> void:
	# 门上方墙面
	_make_rect(parent, Color(0.12, 0.06, 0.03), 220, 50, 360, 100)
	# 门两侧墙面
	_make_rect(parent, Color(0.12, 0.06, 0.03), 220, 150, 100, 120)   # 门左
	_make_rect(parent, Color(0.12, 0.06, 0.03), 480, 150, 100, 120)   # 门右

# ========== ② 玻璃店门 + 雨景 ==========

func _build_glass_door(parent: Node) -> Node2D:
	var door = Node2D.new()
	door.name = "GlassDoor"
	parent.add_child(door)
	
	# 门外雨景背景（透过玻璃看到）
	var rain_bg = _make_rect(door, Color(0.08, 0.1, 0.15, 0.8), 320, 80, 160, 170)
	
	# 雨滴效果（白色细线）
	for i in range(15):
		var rx = 320 + (randf() * 160)
		var ry = 80 + (randf() * 170)
		var rain_len = 8 + (randf() * 12)
		_make_rect(door, Color(0.6, 0.7, 0.9, 0.3 + randf() * 0.3), rx, ry, 1, rain_len)
	
	# 门框（深木色）
	_make_rect(door, WOOD_DARK, 318, 78, 164, 10)   # 上门框
	_make_rect(door, WOOD_DARK, 318, 248, 164, 8)    # 下门槛
	_make_rect(door, WOOD_DARK, 318, 88, 8, 160)      # 左门框
	_make_rect(door, WOOD_DARK, 474, 88, 8, 160)      # 右门框
	
	# 门板（半透明玻璃效果）
	_make_rect(door, Color(0.2, 0.25, 0.35, 0.25), 326, 88, 148, 160)
	
	# 门中间横框（分割上下玻璃）
	_make_rect(door, WOOD_DARK, 326, 168, 148, 6)
	
	# 门上方的拱形装饰
	_make_rect(door, WOOD_MEDIUM, 315, 68, 170, 12)
	_make_rect(door, WOOD_DARK, 312, 62, 176, 8)
	
	# 门把手
	_make_rect(door, GOLD_ACCENT, 460, 150, 7, 14)
	
	# 门牌"营业中"
	_make_rect(door, Color(0.5, 0.35, 0.15), 385, 75, 30, 10)
	var sign_text = Label.new()
	sign_text.text = "营业中"
	sign_text.add_theme_font_size_override("font_size", 7)
	sign_text.add_theme_color_override("font_color", Color(1, 1, 0.8))
	sign_text.position = Vector2(386, 73)
	sign_text.size = Vector2(28, 12)
	door.add_child(sign_text)
	
	# 门外雨景装饰（大门两侧可以看到的雨丝）
	for i in range(8):
		var rx = 300 + (randf() * 200)
		var ry = 70 + (randf() * 180)
		_make_rect(door, Color(0.6, 0.7, 0.9, 0.15), rx, ry, 1, 6 + randf() * 8)
	
	return door

# ========== ③ 地板 ==========

func _build_floor(parent: Node) -> void:
	# 地板底色
	_make_rect(parent, Color(0.18, 0.10, 0.05), 0, 180, 800, 540)
	
	# 纵向木板条纹（从近到远疏密变化）
	var planks := [35, 90, 145, 200, 255, 310, 365, 420, 475, 530, 585, 640, 695, 750]
	for x in planks:
		_make_rect(parent, Color(0.2, 0.12, 0.06, 0.4), x, 185, 2, 530)
	
	# 横向接缝（增强纵深感）
	var seam_ys = [220, 290, 370, 460, 560]
	for y in seam_ys:
		_make_rect(parent, Color(0.1, 0.05, 0.02, 0.25), 40, y, 720, 2)

# ========== ④ 天花板横梁 ==========

func _build_ceiling(parent: Node) -> void:
	# 天花板底色
	_make_rect(parent, Color(0.08, 0.04, 0.02), 0, 0, 800, 55)
	
	# 横梁（从近到远：近粗→远细）
	var beams = [
		{ "x": 20, "w": 760, "h": 14, "y": 5 },    # 近（最粗）
		{ "x": 80, "w": 640, "h": 10, "y": 28 },    # 中近
		{ "x": 150, "w": 500, "h": 8, "y": 44 },    # 中远
		{ "x": 240, "w": 320, "h": 6, "y": 55 },    # 远（最细）
	]
	for beam in beams:
		_make_rect(parent, WOOD_DARK, beam["x"], beam["y"], beam["w"], beam["h"])
		_make_rect(parent, WOOD_LIGHT, beam["x"], beam["y"], beam["w"], 2)

# ========== ⑤ 左侧4层货架 ==========

func _build_left_shelves(parent: Node) -> Node2D:
	var wall = Node2D.new()
	wall.name = "LeftShelves"
	parent.add_child(wall)
	
	# 左墙壁分段（从近到远，宽度递减模拟透视）
	var wall_segs = [
		{ "x": 0, "y": 55, "w": 70, "h": 430 },    # ① 近端（最大）
		{ "x": 65, "y": 55, "w": 55, "h": 400 },    # ② 中近端
		{ "x": 115, "y": 55, "w": 42, "h": 360 },   # ③ 中远端
		{ "x": 150, "y": 55, "w": 32, "h": 310 },   # ④ 远端（最小）
	]
	for seg in wall_segs:
		_make_rect(wall, WALL_COLOR, seg["x"], seg["y"], seg["w"], seg["h"])
	
	# 装饰柱
	_make_rect(wall, WOOD_DARK, 0, 55, 8, 430)
	_make_rect(wall, WOOD_DARK, 65, 55, 6, 400)
	_make_rect(wall, WOOD_DARK, 115, 55, 5, 360)
	_make_rect(wall, WOOD_DARK, 150, 55, 4, 310)
	
	# 货架层板（每层4段，纵深递减）
	var shelf_layers = [
		{ "y": 130, "h": 8 },   # 上层
		{ "y": 250, "h": 8 },   # 中层
		{ "y": 370, "h": 8 },   # 下层
	]
	
	for lay in shelf_layers:
		# 近端（最大）
		_make_rect(wall, SHELF_COLOR, 10, lay["y"], 52, lay["h"])
		_make_rect(wall, WOOD_LIGHT, 10, lay["y"], 52, 2)
		# 中近端
		_make_rect(wall, SHELF_COLOR, 70, lay["y"] + 12, 44, lay["h"] - 3)
		_make_rect(wall, WOOD_LIGHT, 70, lay["y"] + 12, 44, 2)
		# 中远端
		_make_rect(wall, SHELF_COLOR, 120, lay["y"] + 25, 35, lay["h"] - 5)
		_make_rect(wall, WOOD_LIGHT, 120, lay["y"] + 25, 35, 2)
		# 远端（最小）
		_make_rect(wall, SHELF_COLOR, 154, lay["y"] + 38, 26, lay["h"] - 7)
		_make_rect(wall, WOOD_LIGHT, 154, lay["y"] + 38, 26, 2)
	
	# 装饰物品（瓶子罐子）
	var deco = [
		# 近端大件
		{ "x": 14, "y": 170, "w": 16, "h": 26, "c": Color(0.2, 0.6, 0.2, 0.7) },
		{ "x": 38, "y": 175, "w": 12, "h": 20, "c": Color(0.6, 0.2, 0.5, 0.6) },
		{ "x": 12, "y": 290, "w": 18, "h": 28, "c": Color(0.7, 0.5, 0.2, 0.7) },
		{ "x": 40, "y": 295, "w": 10, "h": 16, "c": Color(0.3, 0.3, 0.7, 0.5) },
		# 中近端
		{ "x": 74, "y": 240, "w": 12, "h": 18, "c": Color(0.7, 0.3, 0.2, 0.5) },
		{ "x": 98, "y": 355, "w": 14, "h": 20, "c": Color(0.2, 0.4, 0.5, 0.5) },
		# 中远端
		{ "x": 124, "y": 190, "w": 10, "h": 14, "c": Color(0.5, 0.5, 0.2, 0.4) },
		{ "x": 142, "y": 310, "w": 8, "h": 12, "c": Color(0.5, 0.2, 0.3, 0.4) },
	]
	for d in deco:
		_make_rect(wall, d["c"], d["x"], d["y"], d["w"], d["h"])
	
	return wall

# ========== ⑥ 右侧4层货架 ==========

func _build_right_shelves(parent: Node) -> Node2D:
	var wall = Node2D.new()
	wall.name = "RightShelves"
	parent.add_child(wall)
	
	var wall_segs = [
		{ "x": 730, "y": 55, "w": 70, "h": 430 },
		{ "x": 680, "y": 55, "w": 55, "h": 400 },
		{ "x": 642, "y": 55, "w": 42, "h": 360 },
		{ "x": 618, "y": 55, "w": 32, "h": 310 },
	]
	for seg in wall_segs:
		_make_rect(wall, WALL_COLOR, seg["x"], seg["y"], seg["w"], seg["h"])
	
	_make_rect(wall, WOOD_DARK, 792, 55, 8, 430)
	_make_rect(wall, WOOD_DARK, 729, 55, 6, 400)
	_make_rect(wall, WOOD_DARK, 680, 55, 5, 360)
	_make_rect(wall, WOOD_DARK, 645, 55, 4, 310)
	
	var shelf_layers = [
		{ "y": 130, "h": 8 },
		{ "y": 250, "h": 8 },
		{ "y": 370, "h": 8 },
	]
	
	for lay in shelf_layers:
		_make_rect(wall, SHELF_COLOR, 738, lay["y"], 52, lay["h"])
		_make_rect(wall, WOOD_LIGHT, 738, lay["y"], 52, 2)
		_make_rect(wall, SHELF_COLOR, 686, lay["y"] + 12, 44, lay["h"] - 3)
		_make_rect(wall, WOOD_LIGHT, 686, lay["y"] + 12, 44, 2)
		_make_rect(wall, SHELF_COLOR, 645, lay["y"] + 25, 35, lay["h"] - 5)
		_make_rect(wall, WOOD_LIGHT, 645, lay["y"] + 25, 35, 2)
		_make_rect(wall, SHELF_COLOR, 620, lay["y"] + 38, 26, lay["h"] - 7)
		_make_rect(wall, WOOD_LIGHT, 620, lay["y"] + 38, 26, 2)
	
	var deco = [
		{ "x": 738, "y": 170, "w": 16, "h": 24, "c": Color(0.4, 0.2, 0.6, 0.6) },
		{ "x": 758, "y": 290, "w": 18, "h": 22, "c": Color(0.3, 0.5, 0.5, 0.6) },
		{ "x": 740, "y": 405, "w": 14, "h": 18, "c": Color(0.6, 0.4, 0.2, 0.5) },
		{ "x": 690, "y": 350, "w": 12, "h": 16, "c": Color(0.5, 0.2, 0.3, 0.4) },
	]
	for d in deco:
		_make_rect(wall, d["c"], d["x"], d["y"], d["w"], d["h"])
	
	return wall

# ========== ⑦ 过道地毯 ==========

func _build_carpet(parent: Node) -> void:
	# 深色长条地毯从门口延伸到柜台
	_make_rect(parent, Color(0.10, 0.05, 0.03, 0.5), 230, 160, 340, 460)
	
	# 地毯花纹
	for i in range(6):
		var x = 250 + i * 55
		_make_rect(parent, Color(0.15, 0.08, 0.04, 0.3), x, 165, 2, 450)

# ========== ⑧ 中央吊灯 ==========

func _build_chandelier(parent: Node) -> Node2D:
	var light = Node2D.new()
	light.name = "Chandelier"
	parent.add_child(light)
	
	# 链条
	_make_rect(light, Color(0.3, 0.3, 0.3), 398, 5, 4, 28)
	
	# 灯架
	_make_rect(light, GOLD_ACCENT, 360, 30, 80, 6)
	_make_rect(light, Color(0.8, 0.6, 0.15), 365, 35, 70, 10)
	_make_rect(light, Color(0.7, 0.5, 0.1), 372, 45, 56, 8)
	
	# 蜡烛（3个）
	var flame_colors = [Color(1, 0.6, 0.1), Color(1, 0.7, 0.2), Color(0.9, 0.5, 0.1)]
	for i in range(3):
		var fx = 378 + i * 22
		var flame = _make_rect(light, flame_colors[i], fx, 53, 8, 14)
		flame.modulate.a = 0.8
	
	return light

# ========== ⑨ 壁灯 ==========

func _build_wall_sconces(parent: Node) -> void:
	# 门左侧壁灯
	_make_rect(parent, GOLD_ACCENT, 235, 140, 6, 14)
	_make_rect(parent, Color(1, 0.6, 0.1, 0.5), 232, 128, 12, 12)
	
	# 门右侧壁灯
	_make_rect(parent, GOLD_ACCENT, 559, 140, 6, 14)
	_make_rect(parent, Color(1, 0.6, 0.1, 0.5), 556, 128, 12, 12)

# ========== ⑩ 柜台（中景，带全部细节） ==========

func _build_counter(parent: Node) -> Node2D:
	var counter = Node2D.new()
	counter.name = "Counter"
	parent.add_child(counter)
	
	# 柜台主体（宽木桌，从y=490延伸至画面底，中景显眼）
	_make_rect(counter, WOOD_MEDIUM, 100, 490, 600, 230)
	# 台面（亮色木，宽大厚实）
	_make_rect(counter, WOOD_LIGHT, 100, 490, 600, 12)
	# 正面板（深色）
	_make_rect(counter, WOOD_DARK, 100, 502, 600, 218)
	
	# 金色包边（上下两条）
	_make_rect(counter, GOLD_ACCENT, 100, 485, 600, 6)
	_make_rect(counter, GOLD_ACCENT, 100, 718, 600, 5)
	
	# 柜台侧柱
	_make_rect(counter, Color(0.4, 0.2, 0.08), 95, 490, 10, 230)
	_make_rect(counter, Color(0.4, 0.2, 0.08), 695, 490, 10, 230)
	
	# 台面木纹（横向条纹）
	for i in range(6):
		var y = 510 + i * 28
		_make_rect(counter, Color(0.28, 0.15, 0.06), 110, y, 580, 1)
	
	# ---- 柜台细节（全部放在台面 y=490 之上） ----
	
	# ① 黄铜台灯（柜台左侧偏中，灯座紧贴台面 y=490）
	_make_rect(counter, GOLD_ACCENT, 520, 492, 18, 24)     # 灯座（y=492，略高于台面，放在台面上）
	_make_rect(counter, Color(0.9, 0.7, 0.2, 0.75), 502, 468, 54, 24)  # 灯罩（在灯座上方）
	# 台灯暖光范围
	var lamp_glow = ColorRect.new()
	lamp_glow.color = Color(1.0, 0.8, 0.3, 0.06)
	lamp_glow.position = Vector2(460, 440)
	lamp_glow.size = Vector2i(140, 100)
	counter.add_child(lamp_glow)
	
	# ② 账本（柜台右侧，放在台面上 y=498）
	_make_rect(counter, Color(0.85, 0.8, 0.6), 160, 498, 70, 42)
	_make_rect(counter, Color(0.7, 0.65, 0.5), 165, 500, 60, 38)
	# 账本上的文字行（细线）
	for i in range(6):
		_make_rect(counter, Color(0.3, 0.2, 0.1, 0.4), 170, 504 + i * 6, 50, 1)
	
	# ③ 羽毛笔（账本旁）
	_make_rect(counter, Color(0.9, 0.8, 0.7), 245, 502, 32, 4)    # 笔杆（水平搁在账本上）
	_make_rect(counter, Color(0.8, 0.6, 0.4), 274, 499, 3, 16)     # 羽毛（斜插）
	_make_rect(counter, Color(0.5, 0.3, 0.1), 243, 502, 3, 5)      # 笔尖
	
	# ④ 小黑板（柜台左侧，立在台面上，底部紧贴台面 y=490）
	_make_rect(counter, Color(0.15, 0.15, 0.15), 120, 495, 85, 48)  # 板面（从y=495起，底部在y=543）
	_make_rect(counter, WOOD_DARK, 118, 493, 89, 52)                 # 板框（底部在y=545）
	
	# 黑板文字：今日金价
	var board_text1 = Label.new()
	board_text1.text = "今日金价"
	board_text1.add_theme_font_size_override("font_size", 8)
	board_text1.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	board_text1.position = Vector2(124, 500)
	board_text1.size = Vector2(75, 12)
	counter.add_child(board_text1)
	
	# 收售箭头
	var board_text2 = Label.new()
	board_text2.text = "收↑ 售↓"
	board_text2.add_theme_font_size_override("font_size", 7)
	board_text2.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	board_text2.position = Vector2(124, 515)
	board_text2.size = Vector2(75, 12)
	counter.add_child(board_text2)
	
	# 急收提示
	var board_text3 = Label.new()
	board_text3.text = "急收:兽皮"
	board_text3.add_theme_font_size_override("font_size", 7)
	board_text3.add_theme_color_override("font_color", Color(1, 0.5, 0.3))
	board_text3.position = Vector2(124, 530)
	board_text3.size = Vector2(75, 12)
	counter.add_child(board_text3)
	
	return counter

# ========== ⑪ 店主背影 ==========

func _build_shopkeeper(parent: Node) -> Node2D:
	var keeper = Node2D.new()
	keeper.name = "Shopkeeper"
	parent.add_child(keeper)
	
	# 店主位置：柜台后方中间偏左 x=320, y=700
	# 柜台 y=490~720，店主在柜台最底部，背影越过柜台台面可见
	# 第三人称视角：店主在后景（低处），冒险者在柜台前（深处）
	keeper.position = Vector2(320, 700)
	
	# 身体（深色上衣）
	_make_rect(keeper, Color(0.15, 0.10, 0.05), -14, -30, 28, 38)
	
	# 头（背影只看到后脑勺）
	_make_rect(keeper, Color(0.25, 0.15, 0.08), -11, -52, 22, 24)
	
	# 头发（后脑）
	_make_rect(keeper, Color(0.2, 0.12, 0.05), -13, -58, 26, 9)
	
	# 肩膀（披风/外套）
	_make_rect(keeper, Color(0.18, 0.12, 0.06), -20, -28, 40, 10)
	
	# 双臂（自然下垂，背影可见肘部以上）
	_make_rect(keeper, Color(0.15, 0.10, 0.05), -26, -20, 10, 28)
	_make_rect(keeper, Color(0.15, 0.10, 0.05), 16, -20, 10, 28)
	
	# 围裙（柜台店主标志性装备）
	_make_rect(keeper, Color(0.35, 0.25, 0.15), -10, -18, 20, 5)
	_make_rect(keeper, Color(0.35, 0.25, 0.15), -8, -13, 16, 18)
	
	return keeper

# ========== ⑫ 灯光氛围 ==========

func _build_atmosphere(parent: Node) -> Node2D:
	var atmos = Node2D.new()
	atmos.name = "Atmosphere"
	parent.add_child(atmos)
	
	# 全店暖色光晕（覆盖整个画面）
	var full_glow = ColorRect.new()
	full_glow.color = Color(1.0, 0.7, 0.2, 0.025)
	full_glow.position = Vector2(0, 0)
	full_glow.size = Vector2i(800, 600)
	atmos.add_child(full_glow)
	
	# 深处暗色渐变（y越大越亮，y越小越暗 -> 深处暗）
	var dark_far = ColorRect.new()
	dark_far.color = Color(0.0, 0.0, 0.0, 0.18)
	dark_far.position = Vector2(200, 55)
	dark_far.size = Vector2i(400, 250)
	atmos.add_child(dark_far)
	
	# 近端柜台区域稍微亮一点
	var counter_glow = ColorRect.new()
	counter_glow.color = Color(1.0, 0.7, 0.2, 0.03)
	counter_glow.position = Vector2(50, 450)
	counter_glow.size = Vector2i(700, 200)
	atmos.add_child(counter_glow)
	
	return atmos

# ========== 货架物品刷新 ==========

## 刷新货架上的商品显示
func refresh_shelf_items(item_container: Node, shelf_data: Array, slot_positions: Array) -> void:
	for child in item_container.get_children():
		child.queue_free()
	var count = min(shelf_data.size(), slot_positions.size())
	for i in range(count):
		var item = shelf_data[i]
		var pos = slot_positions[i]
		_create_item_display(item_container, item, pos)

## 创建一个物品的视觉展示
func _create_item_display(parent: Node, item: Dictionary, pos: Vector2) -> void:
	var item_node = Node2D.new()
	item_node.name = "ShelfItem_" + str(pos.x)
	parent.add_child(item_node)
	
	# 物品背景卡片
	_make_rect(item_node, ITEM_BG, pos.x - 32, pos.y - 22, 64, 44)
	
	# 类型颜色标识
	var type_name = item.get("type", "杂物")
	var vis_data = ITEM_VISUALS.get(type_name, { "color": Color(0.5, 0.5, 0.5), "icon": "📦" })
	_make_rect(item_node, vis_data["color"], pos.x - 30, pos.y - 20, 60, 4)
	
	# 物品名
	var name_lbl = Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	name_lbl.position = Vector2(pos.x - 28, pos.y - 14)
	name_lbl.size = Vector2(55, 12)
	item_node.add_child(name_lbl)
	
	# 价格
	var price_lbl = Label.new()
	price_lbl.text = str(item.get("price", 0), "金")
	price_lbl.add_theme_font_size_override("font_size", 9)
	price_lbl.add_theme_color_override("font_color", GOLD_ACCENT)
	price_lbl.position = Vector2(pos.x - 28, pos.y + 10)
	price_lbl.size = Vector2(55, 12)
	item_node.add_child(price_lbl)
	
	# 类型图标
	var type_lbl = Label.new()
	type_lbl.text = vis_data.get("icon", "📦")
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.position = Vector2(pos.x + 12, pos.y - 16)
	type_lbl.size = Vector2(18, 18)
	item_node.add_child(type_lbl)

## 辅助：创建矩形
func _make_rect(parent: Node, color: Color, x: float, y: float, w: float, h: float) -> ColorRect:
	var rect = ColorRect.new()
	rect.color = color
	rect.position = Vector2(x, y)
	rect.size = Vector2i(int(w), int(h))
	parent.add_child(rect)
	return rect
