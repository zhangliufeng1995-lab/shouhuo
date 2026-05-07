extends Node2D
## 商店主控脚本
## 负责：UI按钮信号连接、业务逻辑调度、子模块调用
## 集成 shop_main.gd 的全部业务逻辑，适配当前场景节点结构
##
## 节点树参考：
##   ShopRoot (Node2D) ← 挂载此脚本
##   ├─ ShopBackground (TextureRect)
##   ├─ UILayer (Control)
##   │   ├─ TopBar (Control) → 3个Status_* → Label + 3个升级按钮
##   │   ├─ Panel_Adventurer (NinePatchRect)
##   │   │   ├─ Label_Name / Label_Class / Label_Level / Label_Rep / Label_Relation
##   │   │   ├─ ItemIcon (TextureRect)
##   │   │   ├─ Label_ItemName / Label_ItemDesc / Label_Price
##   │   │   ├─ Btn_Acquire / Btn_Bargain / Btn_Refuse
##   │   ├─ Panel_Inventory (NinePatchRect)
##   │   │   ├─ Input_SellPrice (LineEdit)
##   │   │   ├─ Btn_PutOnSale
##   │   │   ├─ Scroll_Inventory → InventoryList (VBoxContainer)
##   │   ├─ Btn_BusinessLog / Btn_SalesRecord / Btn_EcologyPanel / Btn_EndDay
##   ├─ BargainWindow (CanvasLayer) [instanced]
##   │   └─ PopupPanel/VBox → InfoLabel, PriceInput, ButtonHB→ConfirmBtn, CancelBtn
##   └─ MonsterAttackWindow (CanvasLayer) [instanced]
##       └─ PopupPanel/VBox → InfoLabel, ButtonHB→OptionBtn1, OptionBtn2

# ========== 信号 ==========
signal day_ended(day: int)
signal gold_changed(new_gold: int)
signal reputation_changed(new_rep: float)

# ========== 常量 ==========
const MAX_INVENTORY := 20                     # 最大库存（基础值）
const MAX_SALES_LOG := 10                     # 销售记录最大数量
const SPECIES_TYPE_MAP := {                    # 物种→材料类型映射
	"矿鼠": "兽皮", "猎手蜘蛛": "毒液", "穴居恐魔": "甲壳",
	"荧光蝠龙": "魔核", "荧光蜗牛": "腺体", "蝙蝠群": "爪牙",
	"史莱姆": "粘液", "石像鬼": "甲壳", "拟态宝箱": "魔核"
}
const FALLBACK_TYPES := ["骨材", "鳞片", "甲壳"]

# ========== 导出变量（可在编辑器中调整） ==========
@export var initial_gold: int = 50000
@export var initial_reputation: float = 50.0

# ========== 公共变量 ==========
var gold: int                                  # 当前金币
var reputation: float                          # 当前信誉
var day: int = 0                               # 当前天数
var season: String = "春"                      # 当前季节

# ========== 私有变量 ==========
var _inventory: Array[Dictionary] = []         # 未上架库存
var _shelf: Array[Dictionary] = []             # 已上架货架
var _current_adv: Dictionary = {}              # 当前冒险者
var _sales_log: Array[String] = []             # 销售记录列表
var _log_history: Array[String] = []           # 经营日志历史列表（内存中保存全部日志，打开经营面板时从此恢复）
var _monster_attack_logs: Array[Dictionary] = []  # 怪物袭击记录列表（每次袭击存储详细信息）
var _is_processing_action := false             # 防抖标志
var _is_modal_open := false                    # 弹窗锁定标志（弹窗打开时阻止主按钮操作）
var _lv_decor: int = 1                         # 装饰等级
var _lv_counter: int = 1                       # 柜台等级
var _lv_vault: int = 1                         # 保险箱等级

# ========== 子模块引用 ==========
var _sim: Node                                 # 生态模拟器
var _adventurer_module                        # 冒险者生成模块
var _bargain_module                           # 讨价还价模块
var _monster_module                           # 怪物袭击模块
var _upgrade_module                           # 升级模块
var _ecosystem_panel_module                   # 生态面板模块
var _customer_module                          # 顾客购买模块

# ========== 弹窗节点引用（供子模块通过 shop.xxx 访问） ==========
var _bargain_window: CanvasLayer               # 讨价还价窗口（CanvasLayer）
var _bargain_label: Label                      # 讨价窗口 - 信息标签
var _bargain_input: LineEdit                   # 讨价窗口 - 价格输入框
var _bargain_submit: Button                    # 讨价窗口 - 确认按钮

var _monster_window: CanvasLayer               # 怪物袭击窗口（CanvasLayer）
var _monster_label: RichTextLabel              # 怪物窗口 - 怪物名标签
var _monster_log: RichTextLabel                # 怪物窗口 - 日志标签
var _monster_guard_btn: Button                 # 怪物窗口 - 守卫按钮
var _monster_fight_btn: Button                 # 怪物窗口 - 战斗按钮

# ========== 上架管理弹窗引用 ==========
var _shelf_manager: Node                       # ShelfManagerWindow 弹窗

# ========== 日志引用 ==========
var _log_content: RichTextLabel                # 经营日志显示控件

# ========== 内置回调 ==========

func _ready() -> void:
	"""场景就绪初始化"""
	# 1. 自动连接所有按钮信号（使用 find_child 模糊匹配）
	_auto_connect_buttons()
	
	# 2. 加载生态模拟器
	_sim = preload("res://scripts/EcosystemSim.gd").new()
	_sim.name = "EcosystemSimulator"
	add_child(_sim)
	_sim.initialize("res://ecosystem_data.json")
	
	# 3. 初始化子模块
	_initialize_modules()
	
	# 4. 初始化变量
	gold = initial_gold
	reputation = initial_reputation
	
	# 5. 更新UI显示
	_update_all_status()
	
	# 6. 初始化弹窗节点引用（供子模块 shop_bargain / shop_monster 访问）
	_init_window_refs()
	
	# 7. 绑定弹窗按钮信号
	_bind_popup_signals()
	
	# 8. 初始化上架管理弹窗
	_shelf_manager = _find("ShelfManagerWindow")
	if _shelf_manager:
		_shelf_manager.hide()
		_add_log("📦 上架管理弹窗已就绪")
	else:
		push_warning("⚠️ 未找到 ShelfManagerWindow 弹窗节点")
	
	# 8.5 在功能栏创建"袭击记录"按钮（动态添加，场景中不存在）
	_setup_monster_log_button()
	
	# 9. 初始化经营日志引用

	# 注意：LogContent 是动态创建的（_ensure_log_overlay），启动时不存在
	# 所以 _add_log 需要在 if 外面调用，确保日志保存到 _log_history
	_log_content = _find("LogContent") as RichTextLabel
	if not _log_content:
		print("ℹ️ LogContent 将在经营日志面板打开时动态创建，目前为 null（正常）")
	
	# ★ 无论 _log_content 是否存在，欢迎消息都保存到 _log_history
	_add_log("🏪 欢迎来到地下城收货商店！")
	_add_log(str("💰 初始资金: ", _format_number(initial_gold), " 金"))
	
	# 如果 _log_content 已存在，设置颜色（实际上启动时不存在，保留为空判断）
	if _log_content:
		_log_content.add_theme_color_override("default_color", Color(0.9, 0.9, 0.85))
	
	# 10. 为所有图片按钮设置 tooltip 提示文字（按钮是 flat=true + 图片模式，没有文字）
	_setup_button_tooltips()
	
	# 11. 为所有空白按钮设置文字（BUG-04修复）
	_setup_button_texts()
	
	# 12. 生成第一位冒险者（延迟等待场景完全加载）

	await get_tree().create_timer(0.5).timeout
	_generate_adventurer()
	
	print("✅ ShopManager 初始化完成")

func _init_window_refs() -> void:
	"""初始化弹窗子节点引用"""
	# --- 讨价还价窗口 ---
	_bargain_window = _find("BargainWindow") as CanvasLayer
	if _bargain_window:
		_bargain_window.hide()
		# 在 BargainWindow 内查找子节点
		var bargain_panel = _bargain_window.find_child("PopupPanel", true, false)
		if bargain_panel:
			var vbox = bargain_panel.find_child("VBox", true, false)
			if vbox:
				_bargain_label = vbox.find_child("InfoLabel", true, false) as Label
				_bargain_input = vbox.find_child("PriceInput", true, false) as LineEdit
				var hb = vbox.find_child("ButtonHB", true, false)
				if hb:
					_bargain_submit = hb.find_child("ConfirmBtn", true, false) as Button
		else:
			# 降级：在整个场景中查找
			_bargain_label = _find("InfoLabel") as Label
			_bargain_input = _find("PriceInput") as LineEdit
			_bargain_submit = _find("ConfirmBtn") as Button
	else:
		push_error("未找到 BargainWindow 弹窗节点！")

	# --- 怪物袭击窗口 ---
	_monster_window = _find("MonsterAttackWindow") as CanvasLayer
	if _monster_window:
		_monster_window.hide()
		# 在 MonsterAttackWindow 内查找子节点
		var monster_panel = _monster_window.find_child("PopupPanel", true, false)
		if monster_panel:
			var vbox = monster_panel.find_child("VBox", true, false)
			if vbox:
				_monster_label = vbox.find_child("InfoLabel", true, false) as RichTextLabel
				var hb = vbox.find_child("ButtonHB", true, false)
				if hb:
					_monster_guard_btn = hb.find_child("OptionBtn1", true, false) as Button
					_monster_fight_btn = hb.find_child("OptionBtn2", true, false) as Button
		# 注：_monster_log 暂未使用，设置为 _monster_label 的别名
		_monster_log = _monster_label
	else:
		push_error("未找到 MonsterAttackWindow 弹窗节点！")

# ========== 经营日志弹窗（动态创建） ==========
var _log_overlay: CanvasLayer = null               # 经营日志弹窗层

func _ensure_log_overlay() -> void:
	"""确保经营日志弹窗已创建（懒加载）
	每次打开时重新构建UI，并从 _log_history 恢复全部历史日志"""
	# 如果已存在有效的弹窗，复用
	if _log_overlay != null and is_instance_valid(_log_overlay):
		return
	
	_log_overlay = CanvasLayer.new()
	_log_overlay.name = "LogOverlay"
	_log_overlay.layer = 128  # 与生态面板同一层级
	add_child(_log_overlay)
	
	# 1. 半透明遮罩
	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.size = get_viewport_rect().size
	_log_overlay.add_child(overlay)
	
	# 2. 日志面板背景
	var panel = Panel.new()
	panel.name = "LogPanel"
	panel.size = Vector2(1050, 860)
	panel.position = Vector2(20, 100)
	panel.add_theme_stylebox_override("panel", _make_log_stylebox())
	_log_overlay.add_child(panel)
	
	# 3. 标题
	var title = Label.new()
	title.name = "LogTitle"
	title.text = "📋 经营日志"
	title.position = Vector2(30, 16)
	title.size = Vector2(300, 40)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0))
	panel.add_child(title)
	
	# 4. 关闭按钮
	var close_btn = Button.new()
	close_btn.name = "CloseLogBtn"
	close_btn.text = "✕"
	close_btn.position = Vector2(960, 10)
	close_btn.size = Vector2(70, 50)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(_hide_log_overlay)
	panel.add_child(close_btn)
	
	# 5. 日志内容 RichTextLabel（不使用 ScrollContainer）
	# ★ Godot 4 中 RichTextLabel 自带了滚动功能（scroll_active = true 默认开启），
	#   当内容超出固定大小时会自动显示滚动条。比 ScrollContainer 更可靠。
	var content = RichTextLabel.new()
	content.name = "LogContent"
	content.position = Vector2(20, 70)
	content.size = Vector2(1010 - 20, 770 - 10)  # 固定宽980 x 高760
	content.custom_minimum_size = Vector2(980, 760)
	content.bbcode_enabled = true
	content.scroll_following = true
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_font_size_override("normal_font_size", 16)
	content.add_theme_color_override("default_color", Color(0.9, 0.9, 0.85))
	panel.add_child(content)
	
	# 更新 _log_content 引用
	_log_content = content
	
	# ★ 从 _log_history 恢复所有历史日志
	_log_content.append_text("[color=#888888]— 📋 经营日志（完整历史） —[/color]\n")
	for entry in _log_history:
		_log_content.append_text(entry)
	
	# 默认隐藏
	_log_overlay.hide()

func _make_log_stylebox() -> StyleBoxFlat:
	"""创建日志面板的样式盒（深色半透明背景+金色边框）"""
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.07, 0.04, 0.97)       # 深褐色背景
	sb.border_color = Color(0.78, 0.58, 0.29)          # 金色边框
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(8)
	return sb

func _hide_log_overlay() -> void:
	"""隐藏经营日志弹窗"""
	if _log_overlay and is_instance_valid(_log_overlay):
		_log_overlay.hide()

func _toggle_log_overlay() -> void:
	"""切换经营日志弹窗的显示/隐藏"""
	_ensure_log_overlay()
	if _log_overlay.visible:
		_log_overlay.hide()
	else:
		# 打开时刷新内容
		_add_log("📋 === 经营摘要 ===")
		_add_log(str("  金币: ", _format_number(gold)))
		_add_log(str("  信誉: %.0f" % reputation))
		_add_log(str("  库存: ", _inventory.size(), " 件"))
		_add_log(str("  货架: ", _shelf.size(), " 件"))
		_add_log(str("  装饰 Lv", _lv_decor, " | 柜台 Lv", _lv_counter, " | 保险箱 Lv", _lv_vault))
		_log_overlay.show()

# ========== 袭击记录按钮与弹窗 ==========

## 在功能栏动态创建"袭击记录"按钮（场景中不存在此按钮，需要代码创建）
var _monster_log_btn: Button = null               # 袭击记录按钮
var _monster_log_overlay: CanvasLayer = null       # 袭击记录弹窗层

func _setup_monster_log_button() -> void:
	"""在功能栏中创建"袭击记录"按钮"""
	# 找到功能栏面板
	var function_bar = _find("Panel_BusinessFunctionBar")
	if not function_bar:
		push_warning("⚠️ 未找到 Panel_BusinessFunctionBar，无法创建袭击记录按钮")
		return
	
	# 创建按钮
	var btn = Button.new()
	btn.name = "Btn_MonsterLog"
	btn.text = "⚔️ 袭击记录"
	btn.position = Vector2(270, 100)  # 放在功能栏第二行，生态面板按钮下方
	btn.size = Vector2(125, 55)
	btn.add_theme_font_size_override("font_size", 14)
	btn.tooltip_text = "查看所有怪物袭击的详细记录"
	btn.pressed.connect(_on_btn_monster_log)
	
	function_bar.add_child(btn)
	_monster_log_btn = btn
	print("✅ 创建袭击记录按钮")

func _on_btn_monster_log() -> void:
	"""袭击记录按钮：显示/隐藏袭击记录专用弹窗"""
	_ensure_monster_log_overlay()
	if _monster_log_overlay and is_instance_valid(_monster_log_overlay):
		if _monster_log_overlay.visible:
			_monster_log_overlay.hide()
		else:
			# 打开时刷新内容
			_refresh_monster_log_content()
			_monster_log_overlay.show()

func _ensure_monster_log_overlay() -> void:
	"""确保袭击记录弹窗已创建（懒加载）"""
	if _monster_log_overlay != null and is_instance_valid(_monster_log_overlay):
		return
	
	_monster_log_overlay = CanvasLayer.new()
	_monster_log_overlay.name = "MonsterLogOverlay"
	_monster_log_overlay.layer = 128  # 与经营日志同一层级
	add_child(_monster_log_overlay)
	
	# 1. 半透明遮罩（点击可关闭）
	var overlay = ColorRect.new()
	overlay.name = "MonsterLogOverlayBg"
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.size = get_viewport_rect().size
	overlay.gui_input.connect(_on_monster_log_overlay_click)
	_monster_log_overlay.add_child(overlay)
	
	# 2. 面板背景
	var panel = Panel.new()
	panel.name = "MonsterLogPanel"
	panel.size = Vector2(750, 600)
	panel.position = Vector2(100, 200)
	panel.add_theme_stylebox_override("panel", _make_log_stylebox())
	_monster_log_overlay.add_child(panel)
	
	# 3. 标题
	var title = Label.new()
	title.name = "MonsterLogTitle"
	title.text = "⚔️ 怪物袭击记录"
	title.position = Vector2(30, 16)
	title.size = Vector2(400, 40)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.3))  # 红色标题
	panel.add_child(title)
	
	# 4. 统计摘要标签（显示总袭击次数/成功率）
	var stats_label = Label.new()
	stats_label.name = "MonsterStatsLabel"
	stats_label.position = Vector2(30, 56)
	stats_label.size = Vector2(600, 24)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	panel.add_child(stats_label)
	
	# 5. 关闭按钮
	var close_btn = Button.new()
	close_btn.name = "CloseMonsterLogBtn"
	close_btn.text = "✕"
	close_btn.position = Vector2(670, 10)
	close_btn.size = Vector2(60, 50)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(_hide_monster_log_overlay)
	panel.add_child(close_btn)
	
	# 6. 记录列表 RichTextLabel
	var content = RichTextLabel.new()
	content.name = "MonsterLogContent"
	content.position = Vector2(20, 90)
	content.size = Vector2(710, 490)
	content.custom_minimum_size = Vector2(710, 490)
	content.bbcode_enabled = true
	content.scroll_following = true
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_font_size_override("normal_font_size", 15)
	content.add_theme_color_override("default_color", Color(0.9, 0.9, 0.85))
	panel.add_child(content)
	
	# 默认隐藏
	_monster_log_overlay.hide()

func _refresh_monster_log_content() -> void:
	"""刷新袭击记录弹窗的内容"""
	if not _monster_log_overlay or not is_instance_valid(_monster_log_overlay):
		return
	
	var panel = _monster_log_overlay.find_child("MonsterLogPanel", true, false)
	if not panel:
		return
	
	var content = panel.find_child("MonsterLogContent", true, false) as RichTextLabel
	var stats_label = panel.find_child("MonsterStatsLabel", true, false) as Label
	if not content:
		return
	
	# 清空内容
	content.clear()
	
	if _monster_attack_logs.is_empty():
		content.append_text("[color=#888888]暂无袭击记录，店铺一直平安无事。[/color]\n")
		if stats_label:
			stats_label.text = "📊 总计: 0 次袭击"
		return
	
	# 计算统计数据
	var total_attacks = _monster_attack_logs.size()
	var successful = 0
	var guarded = 0
	var lost_items = 0
	for entry in _monster_attack_logs:
		if entry.get("success", false):
			successful += 1
		if entry.get("had_guard", false):
			guarded += 1
		if entry.get("lost_item") != null:
			lost_items += 1
	
	var win_rate = float(successful) / float(total_attacks) * 100.0
	
	# 更新统计摘要
	if stats_label:
		stats_label.text = str(
			"📊 总计: ", total_attacks, " 次袭击 | ",
			"✅ 胜利: ", successful, " 次 (", int(win_rate), "%) | ",
			"🛡 守卫: ", guarded, " 次 | ",
			"💔 丢失: ", lost_items, " 件"
		)
	
	# 逐条显示袭击记录（从最新到最旧）
	content.append_text("[color=#ff8844]═══════ 袭击记录（最新在前） ═══════[/color]\n\n")
	
	# 倒序遍历（最新的在前）
	for i in range(_monster_attack_logs.size() - 1, -1, -1):
		var log = _monster_attack_logs[i]
		
		var log_day = log.get("day", 0)
		var monster_name = log.get("monster_name", "未知怪物")
		var is_elite = log.get("is_elite", false)
		var had_guard = log.get("had_guard", false)
		var success = log.get("success", false)
		var success_chance = log.get("success_chance", 0.0)
		var guard_cost = log.get("guard_cost", 0)
		var loot_item = log.get("loot_item", null)
		var lost_item = log.get("lost_item", null)
		
		# 天数标题
		var day_color = "#ffaa44"
		content.append_text(str("[color=", day_color, "]━━━ 第 ", log_day, " 天 ━━━[/color]\n"))
		
		# 怪物信息
		var elite_tag = "精英 " if is_elite else ""
		content.append_text(str("[color=#ff6666]🐾 怪物: ", elite_tag, monster_name, "[/color]\n"))
		
		# 应对方式
		if had_guard:
			content.append_text(str("[color=#66aaff]🛡 应对: 雇佣守卫 (花费 ", guard_cost, " 金)[/color]\n"))
		else:
			content.append_text("[color=#ffcc66]⚔ 应对: 亲自迎战[/color]\n")
		
		# 成功率
		content.append_text(str("[color=#888888]  成功率: ", int(success_chance * 100), "%[/color]\n"))
		
		# 结果
		if success:
			content.append_text("[color=#66ff66]✅ 结果: 胜利！[/color]\n")
		else:
			content.append_text("[color=#ff3333]❌ 结果: 失败...[/color]\n")
		
		# 收益/损失
		if loot_item:
			var loot_name = loot_item.get("name", "未知")
			var loot_val = loot_item.get("value", 0)
			content.append_text(str("[color=#66ff66]  🎁 掉落: ", loot_name, " (价值 ", loot_val, " 金)[/color]\n"))
		
		if lost_item:
			var lost_name = lost_item.get("name", "未知")
			content.append_text(str("[color=#ff3333]  💔 损失: 丢失了货物「", lost_name, "」[/color]\n"))
		
		content.append_text("\n")

func _hide_monster_log_overlay() -> void:
	"""隐藏袭击记录弹窗"""
	if _monster_log_overlay and is_instance_valid(_monster_log_overlay):
		_monster_log_overlay.hide()

func _on_monster_log_overlay_click(event: InputEvent) -> void:
	"""点击遮罩关闭袭击记录弹窗"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_monster_log_overlay()

# ========== 按钮自动连接 ==========


func _auto_connect_buttons() -> void:
	"""用 find_child 模糊匹配所有按钮并连接信号"""
	var connected := 0
	
	# [通配符名称, 回调函数名]
	var buttons := [
		["*Btn_Acquire*", "_on_btn_acquire"],           # 收购
		["*Btn_Bargain*", "_on_btn_bargain"],            # 讨价
		["*Btn_Refuse*", "_on_btn_refuse"],              # 拒绝
		["*Btn_PutOnSale*", "_on_btn_put_on_sale"],      # 上架
		["*Btn_ShelfManager*", "_on_btn_shelf_manager"], # 货架管理
		["*Btn_BusinessLog*", "_on_btn_business_log"],   # 经营日志
		["*Btn_SalesRecord*", "_on_btn_sales_record"],   # 销售记录
		["*Btn_EcologyPanel*", "_on_btn_ecology_panel"], # 生态面板
		["*Btn_EndDay*", "_on_btn_end_day"],              # 结束一天
		["*Btn_UpgradeDecor*", "_on_upgrade_decor"],     # 升级装饰
		["*Btn_UpgradeCounter*", "_on_upgrade_counter"], # 升级柜台
		["*Btn_UpgradeVault*", "_on_upgrade_vault"],     # 升级保险箱
	]
	
	for b in buttons:
		var btn = _find(b[0]) as Button
		if btn:
			btn.pressed.connect(Callable(self, b[1]))
			connected += 1
		else:
			push_warning("⚠️ 未找到按钮: ", b[0])
	
	print("✅ 按钮信号连接: ", connected, "/", buttons.size())

func _bind_popup_signals() -> void:
	"""绑定弹窗内的按钮信号"""
	# 讨价还价窗口 - ConfirmBtn / CancelBtn
	var confirm_btn = _find("ConfirmBtn") as Button
	var cancel_btn = _find("CancelBtn") as Button
	if confirm_btn:
		confirm_btn.pressed.connect(_on_bargain_confirm)
	if cancel_btn:
		cancel_btn.pressed.connect(_on_bargain_cancel)
	
	# 怪物袭击窗口 - OptionBtn1（请守卫）/ OptionBtn2（亲自应对）
	# 静态连接后，shop_monster.gd 的 check_monster_attack() 不再需要管理信号，
	# 消除了每次袭击都重复 connect 导致信号累积的问题
	if _monster_guard_btn:
		_monster_guard_btn.pressed.connect(_on_monster_guard)
	if _monster_fight_btn:
		_monster_fight_btn.pressed.connect(_on_monster_fight)

func _setup_button_tooltips() -> void:
	"""为所有图片按钮（flat=true + icon模式）设置 tooltip 提示文字
	这些按钮在场景中使用图片作为图标，没有文字，所以需要 tooltip 让玩家知道功能"""
	
	# 冒险者操作按钮
	var btn_acquire = _find("Btn_Acquire") as Button
	if btn_acquire:
		btn_acquire.tooltip_text = "以冒险者要价直接收购货物"
	
	var btn_bargain = _find("Btn_Bargain") as Button
	if btn_bargain:
		btn_bargain.tooltip_text = "与冒险者讨价还价，争取更低价格"
	
	var btn_refuse = _find("Btn_Refuse") as Button
	if btn_refuse:
		btn_refuse.tooltip_text = "拒绝购买，将冒险者打发走"
	
	# 库存操作按钮
	var btn_put_on_sale = _find("Btn_PutOnSale") as Button
	if btn_put_on_sale:
		btn_put_on_sale.tooltip_text = "将选中的库存物品上架到货架出售"
	
	# 底部功能栏按钮
	var btn_sales_record = _find("Btn_SalesRecord") as Button
	if btn_sales_record:
		btn_sales_record.tooltip_text = "查看最近10条销售记录"
	
	var btn_ecology_panel = _find("Btn_EcologyPanel") as Button
	if btn_ecology_panel:
		btn_ecology_panel.tooltip_text = "打开生态面板，查看各生态域物种状况"
	
	var btn_end_day = _find("Btn_EndDay") as Button
	if btn_end_day:
		btn_end_day.tooltip_text = "结束当前天，触发顾客购买、怪物袭击、生态模拟"

func _setup_button_texts() -> void:
	"""为所有空白按钮设置文字（BUG-04修复）
	让玩家能清楚看到每个按钮的功能，而不是空白一块"""
	
	# 冒险者操作按钮
	var btn_acquire = _find("Btn_Acquire") as Button
	if btn_acquire:
		btn_acquire.text = "💰 收购"
	
	var btn_bargain = _find("Btn_Bargain") as Button
	if btn_bargain:
		btn_bargain.text = "💬 讨价"
	
	var btn_refuse = _find("Btn_Refuse") as Button
	if btn_refuse:
		btn_refuse.text = "❌ 拒绝"
	
	# 库存操作按钮 - 上架
	var btn_put_on_sale = _find("Btn_PutOnSale") as Button
	if btn_put_on_sale:
		btn_put_on_sale.text = "📤 上架"
	
	# 底部功能栏按钮
	var btn_log = _find("Btn_BusinessLog") as Button
	if btn_log:
		btn_log.text = "📋 经营日志"
	
	var btn_sales = _find("Btn_SalesRecord") as Button
	if btn_sales:
		btn_sales.text = "📊 销售记录"
	
	var btn_eco = _find("Btn_EcologyPanel") as Button
	if btn_eco:
		btn_eco.text = "🌿 生态面板"
	
	var btn_end = _find("Btn_EndDay") as Button
	if btn_end:
		btn_end.text = "⏭ 结束一天"

# ========== 子模块初始化 ==========


func _initialize_modules() -> void:
	"""加载所有子模块脚本"""
	var module_paths := {
		"adventurer": "res://scripts/shop/shop_adventurer.gd",
		"bargain": "res://scripts/shop/shop_bargain.gd",
		"monster": "res://scripts/shop/shop_monster.gd",
		"upgrade": "res://scripts/shop/shop_upgrade.gd",
		"ecosystem_panel": "res://scripts/shop/shop_ecosystem_panel.gd",
		"customer": "res://scripts/shop/shop_customer.gd",
	}
	
	var loader = func(path: String):
		if ResourceLoader.exists(path):
			return load(path).new()
		else:
			push_error("子模块脚本缺失: %s" % path)
			return null
	
	_adventurer_module = loader.call(module_paths["adventurer"])
	_bargain_module = loader.call(module_paths["bargain"])
	_monster_module = loader.call(module_paths["monster"])
	_upgrade_module = loader.call(module_paths["upgrade"])
	_ecosystem_panel_module = loader.call(module_paths["ecosystem_panel"])
	_customer_module = loader.call(module_paths["customer"])

# ========== 公共业务方法（供子模块调用） ==========

## 向库存中添加物品
func add_to_inventory(item: Dictionary) -> void:
	if _inventory.size() >= _lv_vault * 10:
		_add_log("库存已满!", "red")
		return
	_inventory.append(item)
	_refresh_inventory_display()

## 将库存首位的物品上架到货架
func shelf_item(price: int) -> void:
	if _inventory.is_empty():
		return
	var item = _inventory.pop_front()
	item["price"] = price
	_shelf.append(item)
	_refresh_inventory_display()

## 从货架移除指定索引的物品
func remove_from_shelf(index: int) -> void:
	if index >= 0 and index < _shelf.size():
		_shelf.remove_at(index)

## 增加金币
func add_gold(amount: int) -> void:
	gold += amount
	_update_all_status()
	gold_changed.emit(gold)

## 增加/减少信誉值
func add_reputation(amount: float) -> void:
	reputation = clamp(reputation + amount, 0.0, 100.0)
	_update_all_status()
	reputation_changed.emit(reputation)

## 添加销售记录
func add_sales_log(entry: String) -> void:
	_sales_log.push_front(entry)
	if _sales_log.size() > MAX_SALES_LOG:
		_sales_log.pop_back()
	_refresh_sales_log_display()

## 添加经营日志
func add_log(text: String, color := "white") -> void:
	_add_log(text, color)

## 添加怪物袭击记录（供 shop_monster.gd 调用）
## log_data 包含：day, monster_name, is_elite, had_guard, success, 
##                guard_cost, loot_item, lost_item, text_summary
func add_monster_attack_log(log_data: Dictionary) -> void:
	"""添加一条怪物袭击详细记录，同时写入经营日志"""
	_monster_attack_logs.append(log_data)
	
	# 确保记录数组不会无限增长（保留最近50条）
	if _monster_attack_logs.size() > 50:
		_monster_attack_logs.pop_front()

## 获取怪物袭击记录列表
func get_monster_attack_logs() -> Array[Dictionary]:
	return _monster_attack_logs

## 设置/清除弹窗锁定状态
## 弹窗打开时 = true → 阻止所有主按钮操作；关闭后 = false → 恢复
func set_modal_open(val: bool) -> void:
	_is_modal_open = val

# ========== UI状态刷新 ==========

func _update_all_status() -> void:
	"""更新所有顶部状态栏、升级标签和升级按钮显示"""
	_set_status_text("Status_Gold", "🪙 " + _format_number(gold))
	_set_status_text("Status_Reputation", "⭐ %.0f" % reputation)
	_set_status_text("Status_Days", "📅 %s季 第%d天" % [season, day])
	
	# 更新升级等级标签（显示在升级按钮上方，不重叠）
	var label_decor = _find("Label_Decor") as Label
	var label_counter = _find("Label_Counter") as Label
	var label_safe = _find("Label_Safe") as Label
	if label_decor:
		label_decor.text = "🎨装饰 Lv.%d" % _lv_decor
	if label_counter:
		label_counter.text = "🛒柜台 Lv.%d" % _lv_counter
	if label_safe:
		label_safe.text = "🔒保险箱 Lv.%d" % _lv_vault
	
	# 更新升级按钮的文字
	_update_upgrade_btn_text()

func _set_status_text(control_name: String, text: String) -> void:
	"""设置状态栏下 Label 的文字"""
	var control = _find(control_name)
	if control and control.get_child_count() > 0:
		var label = control.get_child(0) as Label
		if label:
			label.text = text

func _refresh_inventory_display() -> void:
	"""刷新库存列表显示"""
	var list_container = _find("InventoryList") as VBoxContainer
	if not list_container:
		return
	
	# 清空现有列表
	for child in list_container.get_children():
		child.queue_free()
	
	# 填充物品行
	for item in _inventory:
		var row = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = str(item.get("name", "?"), " [", item.get("type", "?"), "]")
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var value_label = Label.new()
		value_label.text = str(item.get("value", 0), "金")
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.15))
		value_label.custom_minimum_size = Vector2(100, 0)
		
		row.add_child(name_label)
		row.add_child(value_label)
		list_container.add_child(row)

# _refresh_shelf_display() 和 _on_remove_from_shelf()
# 已迁移到 ShelfManagerWindow（shelf_manager.gd）
# 下架操作通过弹窗中的按钮触发

func _refresh_sales_log_display() -> void:
	"""刷新销售记录显示 - 只添加最新的一条到日志（避免重复）"""
	if _sales_log.size() > 0:
		# 只添加最新的第一条
		_add_log(_sales_log[0])

func _update_adv_info() -> void:
	"""更新冒险者面板信息"""
	if _current_adv.is_empty():
		_set_adv_field("Label_Name", "暂无客人...")
		_set_adv_field("Label_ItemName", "")
		_set_adv_field("Label_ItemDesc", "")
		_set_adv_field("Label_Price", "")
		_set_adv_field("Label_Class", "")
		_set_adv_field("Label_Level", "")
		_set_adv_field("Label_Rep", "")
		_set_adv_field("Label_Relation", "")
		_set_buttons_enabled(false)
		return
	
	# 冒险者基本信息
	_set_adv_field("Label_Name", str("🧑 ", _current_adv.get("name", "?")))
	_set_adv_field("Label_Class", str("🎭 性格: ", _current_adv.get("personality", "普通")))
	_set_adv_field("Label_Level", str("🏠 来自: ", _current_adv.get("goods", {}).get("domain_name", "地下城")))
	_set_adv_field("Label_Rep", str("⭐ 信誉评分: ", _current_adv.get("trust", 50)))
	_set_adv_field("Label_Relation", str("🤝 友善度: 普通"))
	
	# 货物信息
	var goods = _current_adv.get("goods", {})
	if not goods.is_empty():
		_set_adv_field("Label_ItemName", str("📦 ", goods.get("name", "?"), " [", goods.get("type", "?"), "]"))
		_set_adv_field("Label_ItemDesc", str("📝 价值: ", goods.get("value", 0), "金"))
		_set_adv_field("Label_Price", str("💰 建议采购价: ", goods.get("value", 0), "金"))
	else:
		_set_adv_field("Label_ItemName", "")
		_set_adv_field("Label_ItemDesc", "冒险者身上没有携带货物。")
		_set_adv_field("Label_Price", "")

func _set_adv_field(field_name: String, text: String) -> void:
	"""设置冒险者面板某个字段的文字"""
	var label = _find(field_name) as Label
	if label:
		label.text = text

func _set_buttons_enabled(enabled: bool) -> void:
	"""启用/禁用冒险者操作按钮"""
	var acquire = _find("Btn_Acquire") as Button
	var bargain = _find("Btn_Bargain") as Button
	var refuse = _find("Btn_Refuse") as Button
	if acquire:
		acquire.disabled = not enabled
	if bargain:
		bargain.disabled = not enabled
	if refuse:
		refuse.disabled = not enabled

# ========== 冒险者生成 ==========

func _generate_adventurer() -> void:
	"""生成新的冒险者"""
	if _adventurer_module and _adventurer_module.has_method("generate_adventurer"):
		_current_adv = _adventurer_module.generate_adventurer(self)
	else:
		_current_adv = _builtin_generate_adventurer()
	
	_update_adv_info()
	
	if not _current_adv.is_empty():
		_add_log(str("🧑 ", _current_adv.get("name", "?"), " 推门走了进来。"))
		var story = _current_adv.get("story", "")
		if story:
			_add_log(str("\"", story, "\""))
		_set_buttons_enabled(true)

# ========== 按钮回调 ==========

func _close_bargain_window() -> void:
	"""关闭讨价还价窗口（如果开着的话），不生成新冒险者"""
	if _bargain_module and _bargain_module.has_method("is_bargaining"):
		if _bargain_module.is_bargaining():
			# 调用模块内部方法：仅关闭窗口，不生成新冒险者
			_bargain_module.cancel_bargain(self, false)
		elif is_instance_valid(_bargain_window):
			_bargain_window.hide()

func _on_btn_acquire() -> void:
	"""收购按钮：以冒险者要价收购货物"""
	if _is_processing_action or _is_modal_open:
		return
	# 关闭可能开着的议价窗口
	_close_bargain_window()
	_is_processing_action = true
	
	if _current_adv.is_empty():
		_is_processing_action = false
		return
	
	var goods = _current_adv.get("goods", {})
	if goods.is_empty():
		_is_processing_action = false
		return
	
	var cost = goods.get("value", 0)
	if gold < cost:
		_add_log("金币不足，无法收购!", "red")
		_is_processing_action = false
		return
	
	# ★ 收购前检查库存容量，满则阻止（避免扣了钱但物品没加进去）
	var max_inv = _lv_vault * 10
	if _inventory.size() >= max_inv:
		_add_log(str("⚠️ 库存已满 (", _inventory.size(), "/", max_inv, ")，无法继续收购！"), "red")
		_add_log("💡 提示：可以先上架部分物品到货架，或升级保险箱扩大库存上限。")
		_is_processing_action = false
		return
	
	# 成交
	gold -= cost
	add_to_inventory(goods.duplicate())
	_add_log(str("✅ 收购了 ", goods.get("name", "?"), "，花费 ", cost, " 金"))
	_update_all_status()
	
	# 从生态中减少对应的物种 - 使用货物来源域（修复BUG-03：之前硬编码荧光苔原域）
	var domain_source = goods.get("domain", "glowing_tundra")
	_reduce_ecosystem(domain_source, goods.get("name", ""))

	
	# 生成下一位冒险者
	_current_adv = {}
	_update_adv_info()
	_generate_adventurer()
	
	_is_processing_action = false

func _on_btn_bargain() -> void:
	"""讨价还价按钮：弹出讨价窗口"""
	if _is_processing_action or _is_modal_open:
		return
	if _current_adv.is_empty():
		return
	if _bargain_module and _bargain_module.has_method("start_bargain"):
		_bargain_module.start_bargain(self, _current_adv)

func _on_btn_refuse() -> void:
	"""拒绝按钮：拒绝当前冒险者，生成下一位"""
	if _is_processing_action or _is_modal_open:
		return
	# 关闭可能开着的议价窗口
	_close_bargain_window()
	_is_processing_action = true
	
	if _current_adv.is_empty():
		_is_processing_action = false
		return
	
	_add_log(str("❌ 拒绝了 ", _current_adv.get("goods", {}).get("name", "?"), " 的货物"))
	
	# 生成下一位
	_current_adv = {}
	_update_adv_info()
	_generate_adventurer()
	
	_is_processing_action = false

func _on_btn_put_on_sale() -> void:
	"""上架按钮：从库存取物品，输入价格后上架到货架"""
	if _is_modal_open:
		return
	var price_input = _find("Input_SellPrice") as LineEdit
	if not price_input:
		return
	
	var price_text = price_input.text.strip_edges()
	if not price_text.is_valid_int():
		_add_log("请输入有效的整数价格!", "red")
		return
	
	var price = int(price_text)
	if price <= 0:
		_add_log("价格必须大于0!", "red")
		return
	
	if _inventory.is_empty():
		_add_log("库存中没有可上架的物品!", "red")
		return
	
	# 上架
	var item = _inventory.pop_front()
	item["price"] = price
	_shelf.append(item)
	_add_log(str("📤 已上架 ", item.get("name", "?"), "，售价 ", price, " 金"))
	
	# 刷新库存显示
	_refresh_inventory_display()
	
	# 通知上架管理弹窗刷新（如果已打开）
	if _shelf_manager and _shelf_manager.has_method("refresh"):
		_shelf_manager.refresh()
	
	# ★ 保留售价输入框中的值，方便连续上架同类货物（不再清空）
	price_input.select_all()
	price_input.grab_focus()

func _on_btn_shelf_manager() -> void:
	"""货架管理按钮：打开已上架物品管理弹窗"""
	if _shelf_manager:
		if _shelf_manager.visible:
			# 如果已打开则关闭
			_shelf_manager.hide()
		else:
			# 打开弹窗并刷新数据
			_shelf_manager.open(self)
			_add_log("📋 打开货架管理面板")
	else:
		_add_log("⚠️ 货架管理弹窗未就绪", "red")

func _on_btn_business_log() -> void:
	"""经营日志按钮：切换动态创建的日志弹窗"""
	_toggle_log_overlay()

func _on_btn_close_log() -> void:
	"""关闭经营日志按钮：隐藏经营日志弹窗"""
	_hide_log_overlay()

func _on_btn_sales_record() -> void:
	"""销售记录按钮：显示最近的销售记录"""
	_add_log("📊 === 销售记录 ===")
	if _sales_log.is_empty():
		_add_log("  暂无销售记录")
	else:
		for entry in _sales_log:
			_add_log("  " + entry)

func _on_btn_ecology_panel() -> void:
	"""生态面板按钮：打开生态面板窗口"""
	if _ecosystem_panel_module and _ecosystem_panel_module.has_method("open_panel"):
		_ecosystem_panel_module.open_panel(self)

func _on_btn_end_day() -> void:
	"""结束一天按钮：触发每日结算"""
	if _is_modal_open:
		return
	_add_log(str("—— 第 ", day + 1, " 天结算开始 ——"))
	
	# 1. 顾客购买（process_customers 现在返回销售统计字典）
	var day_stats := {}
	if _customer_module and _customer_module.has_method("process_customers"):
		day_stats = _customer_module.process_customers(self)
	else:
		_process_customers_builtin()
	
	# 2. 显示每日销售总结
	_add_log("")
	_add_log("📊 === 今日销售总结 ===")
	if day_stats.get("sold_count", 0) > 0:
		_add_log(str("  ✅ 成交: ", day_stats.sold_count, " 件"))
		_add_log(str("  💰 收入: ", _format_number(day_stats.total_revenue), " 金"))
		_add_log(str("  📈 利润: ", _format_number(day_stats.total_profit), " 金"))
		var items_str = ", ".join(day_stats.get("items_sold", []))
		_add_log(str("  📦 售出: ", items_str))
	else:
		_add_log("  😔 今日无成交，货架可能空了或定价过高。")
	_add_log("")
	
	# 3. 怪物袭击
	if _monster_module and _monster_module.has_method("check_monster_attack"):
		_monster_module.check_monster_attack(self)
	else:
		_trigger_monster_attack_builtin()
	
	# 4. 生态模拟
	_sim.simulate_day()
	season = _sim.SEASONS[_sim.season]
	day = _sim.day
	
	day_ended.emit(day)
	_add_log(str("—— 第 ", day, " 天结束 ——"))
	
	# 5. 刷新UI
	_update_all_status()
	_refresh_inventory_display()
	
	# 通知上架管理弹窗刷新（如果已打开）
	if _shelf_manager and _shelf_manager.has_method("refresh"):
		_shelf_manager.refresh()
	
	# 5. 更新生态面板（如果已打开）
	if _ecosystem_panel_module and _ecosystem_panel_module.has_method("is_window_visible"):
		if _ecosystem_panel_module.is_window_visible():
			_ecosystem_panel_module.refresh_panel(self)
	
	# 6. 生成明天的冒险者
	_generate_adventurer()

# ========== 讨价还价弹窗信号 ==========

func _on_bargain_confirm() -> void:
	"""讨价还价 - 确认出价按钮"""
	if _bargain_module and _bargain_module.has_method("handle_submit"):
		_bargain_module.handle_submit(self, _current_adv)

func _on_bargain_cancel() -> void:
	"""讨价还价 - 取消按钮"""
	if _bargain_module and _bargain_module.has_method("is_bargaining"):
		if _bargain_module.is_bargaining():
			_add_log("❌ 你放弃了议价，冒险者失望地离开了。")
			_bargain_module.cancel_bargain(self, true)
	else:
		var bw = _find("BargainWindow")
		if bw:
			bw.hide()

# ========== 怪物袭击弹窗信号 ==========

func _on_monster_guard() -> void:
	"""怪物袭击 - 请守卫"""
	if _monster_module and _monster_module.has_method("_on_guard_clicked"):
		_monster_module._on_guard_clicked(self)

func _on_monster_fight() -> void:
	"""怪物袭击 - 亲自应对"""
	if _monster_module and _monster_module.has_method("_on_fight_clicked"):
		_monster_module._on_fight_clicked(self)

# ========== 内建降级实现 ==========

func _builtin_generate_adventurer() -> Dictionary:
	"""内建冒险者生成（当子模块不可用时的降级方案）"""
	var adv := {}
	adv["name"] = _random_name()
	adv["personality"] = _random_personality()
	adv["trust"] = randi() % 40 + 30
	
	var tundra = _sim.domains["glowing_tundra"]
	if tundra["species"].is_empty():
		return {}
	
	var chosen = _get_ecosystem_weighted_species()
	if chosen.is_empty():
		return {}
	var chosen_sp = chosen["data"]
	var capacity = chosen_sp["capacity"]
	var population = chosen_sp["population"]
	
	var base_value := int(float(capacity) * 0.7 * 10.0)
	
	var price_multiplier = 1.0
	var story_tag = "normal"
	if population < capacity * 0.3:
		price_multiplier = randf_range(1.5, 2.5)
		story_tag = "scarce"
	elif population > capacity * 1.5:
		price_multiplier = randf_range(0.5, 0.7)
		story_tag = "abundant"
	else:
		price_multiplier = randf_range(0.8, 1.2)
	
	var value: int = max(5, int(base_value * price_multiplier))
	
	var item_type = SPECIES_TYPE_MAP.get(chosen_sp["name"], "")
	if item_type == "":
		item_type = FALLBACK_TYPES[hash(chosen_sp["name"]) % FALLBACK_TYPES.size()]
	
	adv["goods"] = {
		"name": chosen_sp["name"],
		"type": item_type,
		"domain": "glowing_tundra",
		"domain_name": "荧光苔原域",
		"value": value,
		"population": population,
		"id": chosen["id"]
	}
	
	if story_tag == "scarce":
		adv["story"] = "为了这只" + chosen_sp["name"] + "，我追踪了整整三天。"
	elif story_tag == "abundant":
		adv["story"] = "随手就能逮到" + chosen_sp["name"] + "，现在到处都是。"
	else:
		if population < 20:
			adv["story"] = "这" + chosen_sp["name"] + "还算常见，不过这只个头特别大。"
		else:
			adv["story"] = "今天运气不错，抓到一只" + chosen_sp["name"] + "。"
	
	return adv

func _get_ecosystem_weighted_species() -> Dictionary:
	"""按种群权重从荧光苔原域选取物种"""
	var tundra = _sim.domains["glowing_tundra"]
	var species_ids = tundra["species"].keys()
	if species_ids.is_empty():
		return {}
	
	var total_weight := 0
	var weights = {}
	for sp_id in species_ids:
		var sp = tundra["species"][sp_id]
		weights[sp_id] = max(1, sp["population"])
		total_weight += weights[sp_id]
	
	if total_weight == 0:
		return {}
	
	var roll = randi() % total_weight
	var cumulative = 0
	for sp_id in weights:
		cumulative += weights[sp_id]
		if roll < cumulative:
			return {"id": sp_id, "data": tundra["species"][sp_id]}
	
	var first_id = species_ids[0]
	return {"id": first_id, "data": tundra["species"][first_id]}

func _reduce_ecosystem(domain_id: String, item_name: String) -> void:
	"""从指定生态域中减少一个对应物种（修复BUG-03：之前硬编码荧光苔原域）"""
	if not _sim.domains.has(domain_id):
		return
	var domain = _sim.domains[domain_id]
	for sp_id in domain["species"]:
		if domain["species"][sp_id]["name"] == item_name:
			domain["species"][sp_id]["population"] = max(1, domain["species"][sp_id]["population"] - 1)
			break


func _trigger_monster_attack_builtin() -> void:
	"""内建怪物袭击（降级方案 - 仅打印）"""
	_add_log("🐾 今晚平安无事...")

func _process_customers_builtin() -> void:
	"""内建顾客购买（降级方案）"""
	var customer_count = randi() % 3 + 1 + int(_lv_counter * 0.5)
	for i in range(customer_count):
		if _shelf.is_empty():
			break
		
		var types = SPECIES_TYPE_MAP.values()
		var pref_type = types[randi() % types.size()]
		var candidates = []
		for item in _shelf:
			if item["type"] == pref_type:
				candidates.append(item)
		
		if candidates.is_empty():
			_add_log(str("一位顾客想买", pref_type, "类商品，但缺货。"))
			continue
		
		var chosen = candidates[randi() % candidates.size()]
		var cost_val = chosen["value"]
		var price = chosen["price"]
		var ratio = float(price) / float(cost_val)
		var buy_chance = clamp(0.9 - (ratio - 1.0) * 0.5, 0.1, 1.0)
		buy_chance *= (0.8 + reputation * 0.004) + _lv_counter * 0.02
		
		if randf() < buy_chance:
			gold += price
			_shelf.erase(chosen)
			var profit = price - cost_val
			var msg = str("🛒 卖出 ", chosen["name"], " [", pref_type, "] 售价 ", price, " 金币 (利润 ", profit, ")")
			_add_log(msg)
			add_sales_log(msg)
			var rating = _calc_rating(ratio)
			reputation = clamp(reputation + (rating - 3.0) * 2.0, 0.0, 100.0)

func _calc_rating(ratio: float) -> float:
	"""计算顾客评分（1.0~5.0星）"""
	if ratio <= 1.0:
		return 5.0
	elif ratio <= 1.3:
		return 4.0
	elif ratio <= 1.6:
		return 3.0
	elif ratio <= 2.0:
		return 2.0
	else:
		return 1.0

# ========== 升级 ==========

func _update_upgrade_btn_text() -> void:
	"""更新三个升级按钮的文字，显示当前等级和升级费用"""
	var decor_btn = _find("Btn_UpgradeDecor") as Button
	var counter_btn = _find("Btn_UpgradeCounter") as Button
	var vault_btn = _find("Btn_UpgradeVault") as Button
	
	if decor_btn:
		decor_btn.text = str("🎨装饰 Lv", _lv_decor, " (升级", 300 * _lv_decor, "金)")
	if counter_btn:
		counter_btn.text = str("🛒柜台 Lv", _lv_counter, " (升级", 400 * _lv_counter, "金)")
	if vault_btn:
		vault_btn.text = str("🔒保险箱 Lv", _lv_vault, " (升级", 500 * _lv_vault, "金)")

func _on_upgrade_decor() -> void:
	"""升级装饰"""
	if _is_modal_open:
		return
	if _upgrade_module and _upgrade_module.has_method("upgrade_decor"):
		_upgrade_module.upgrade_decor(self)
	else:
		_execute_upgrade("decor")

func _on_upgrade_counter() -> void:
	"""升级柜台"""
	if _is_modal_open:
		return
	if _upgrade_module and _upgrade_module.has_method("upgrade_counter"):
		_upgrade_module.upgrade_counter(self)
	else:
		_execute_upgrade("counter")

func _on_upgrade_vault() -> void:
	"""升级保险箱"""
	if _is_modal_open:
		return
	if _upgrade_module and _upgrade_module.has_method("upgrade_vault"):
		_upgrade_module.upgrade_vault(self)
	else:
		_execute_upgrade("vault")

func _execute_upgrade(type: String) -> void:
	"""执行升级（降级方案）"""
	var cost := 0
	match type:
		"decor":   cost = 300 * _lv_decor
		"counter": cost = 400 * _lv_counter
		"vault":   cost = 500 * _lv_vault
	
	if gold < cost:
		_add_log("金币不足，无法升级!", "red")
		return
	
	gold -= cost
	match type:
		"decor":   _lv_decor += 1
		"counter": _lv_counter += 1
		"vault":   _lv_vault += 1
	
	_add_log("✅ 升级成功!")
	_update_all_status()
	
	if type == "vault":
		_add_log(str("📦 库存上限提升至 ", _lv_vault * 10))

# ========== 工具 ==========

func _random_name() -> String:
	"""生成随机冒险者名字"""
	var first = ["锈剑", "影步", "火拳", "独眼", "快手", "银发", "铁盾", "灰烬"]
	var last = ["杰克", "莉娜", "巴特尔", "艾希", "莫娜", "格罗"]
	return first[randi() % first.size()] + "·" + last[randi() % last.size()]

func _random_personality() -> String:
	"""生成随机性格"""
	return ["急躁", "普通", "耐心", "狡猾", "豪爽"][randi() % 5]

func _add_log(text: String, color := "white") -> void:
	"""向经营日志添加一条记录，同时输出到控制台和UI面板"""
	# 控制台输出
	print(text)
	
	# 根据color参数选择颜色
	var bbcode := ""
	match color:
		"red":
			bbcode = "[color=#ff6666]"
		"green":
			bbcode = "[color=#66ff66]"
		"yellow":
			bbcode = "[color=#ffff66]"
		"cyan":
			bbcode = "[color=#66ffff]"
		_:
			bbcode = "[color=#e6e6d6]"
	
	# 构建带时间戳的BBCODE文本（用于 _log_history 存储和RichTextLabel显示）
	var time = Time.get_time_string_from_system()
	var bb_entry: String = str("[color=#888888]", time, "[/color] ", bbcode, text, "[/color]\n")
	
	# ★ 保存到内存日志历史，打开经营面板时可以完整恢复
	_log_history.append(bb_entry)
	
	# 显示到UI经营日志面板（如果有）
	if _log_content and is_instance_valid(_log_content):
		_log_content.append_text(bb_entry)
		# 自动滚动到底部
		_log_content.scroll_to_line(_log_content.get_line_count() - 1)

func _format_number(value: int) -> String:
	"""格式化数字为千分位，如 12450 → "12,450" """
	var s := str(value)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

func _find(pattern: String) -> Node:
	"""快捷查找节点（find_child 包装）"""
	return find_child(pattern, true, false)

# ========== 模块访问器（供子模块调用） ==========

func get_inventory() -> Array[Dictionary]:
	return _inventory

func get_shelf() -> Array[Dictionary]:
	return _shelf

func get_current_adv() -> Dictionary:
	return _current_adv

func get_sim():
	return _sim

func get_day() -> int:
	return day

func get_lv_decor() -> int:
	return _lv_decor

func get_lv_counter() -> int:
	return _lv_counter

func get_lv_vault() -> int:
	return _lv_vault

func get_rep() -> float:
	return reputation

func set_lv_decor(val: int) -> void:
	_lv_decor = val
	_update_all_status()

func set_lv_counter(val: int) -> void:
	_lv_counter = val
	_update_all_status()

func set_lv_vault(val: int) -> void:
	_lv_vault = val
	_update_all_status()
