extends Node2D
## 商店主脚本：核心数据、UI 创建、主循环
## 游戏循环协调者，将具体功能委托给子模块
## 2D视觉版：搭建奥利凡德风格商店环境 + 冒险者动画行走

# ========== 信号 ==========
signal day_ended(day: int)
signal gold_changed(new_gold: int)
signal reputation_changed(new_rep: float)

# ========== 常量 ==========
const MAX_INVENTORY := 20
const MAX_SALES_LOG := 10
const SCREEN_W := 1280
const SCREEN_H := 720

# 材料类型映射表
const SPECIES_TYPE_MAP := {
	"矿鼠": "兽皮", "猎手蜘蛛": "毒液", "穴居恐魔": "甲壳",
	"荧光蝠龙": "魔核", "荧光蜗牛": "腺体", "蝙蝠群": "爪牙",
	"史莱姆": "粘液", "石像鬼": "甲壳", "拟态宝箱": "魔核"
}
const FALLBACK_TYPES := ["骨材", "鳞片", "甲壳"]

# ========== 导出变量 ==========
@export var initial_gold: int = 50000
@export var initial_reputation: float = 50.0

# ========== 公共变量 ==========
var gold: int
var reputation: float
var day: int = 0
var season: String = "春"

# ========== 私有变量 ==========
var _inventory: Array[Dictionary] = []
var _shelf: Array[Dictionary] = []
var _current_adv: Dictionary = {}
var _sales_log: Array[String] = []

# 防抖标志，防止按钮快速连点
var _is_processing_action := false

var _lv_decor: int = 1
var _lv_counter: int = 1
var _lv_vault: int = 1

# ========== 生态模拟器引用 ==========
var _sim: Node

# ========== 子模块引用 ==========
var _adventurer_module
var _bargain_module
var _monster_module
var _upgrade_module
var _ecosystem_panel_module
var _customer_module
var _visual_module     # 视觉环境模块
var _character_module  # 角色动画模块

# ========== @onready UI节点 ==========
@onready var _gold_label: Label = $UILayer/GoldLabel
@onready var _rep_label: Label = $UILayer/RepLabel
@onready var _day_label: Label = $UILayer/DayLabel
@onready var _adv_info_label: Label = $UILayer/AdvInfoPanel/AdvInfoLabel
@onready var _goods_label: Label = $UILayer/AdvInfoPanel/GoodsLabel
@onready var _story_label: Label = $UILayer/AdvInfoPanel/StoryLabel
@onready var _buy_btn: Button = $UILayer/AdvInfoPanel/BuyBtn
@onready var _bargain_btn: Button = $UILayer/AdvInfoPanel/BargainBtn
@onready var _reject_btn: Button = $UILayer/AdvInfoPanel/RejectBtn

@onready var _log_scroll: ScrollContainer = $UILayer/BottomPanel/LogScroll
@onready var _log_rich: RichTextLabel = $UILayer/BottomPanel/LogScroll/RichTextLabel
@onready var _sales_log_list: VBoxContainer = $UILayer/BottomPanel/SalesLogList

@onready var _inv_list: VBoxContainer = $UILayer/InventoryPanel/InvScroll/InvList
@onready var _inv_count: Label = $UILayer/InventoryPanel/InvCount
@onready var _price_input: LineEdit = $UILayer/InventoryPanel/PriceInput
@onready var _shelf_btn: Button = $UILayer/InventoryPanel/ShelfBtn

@onready var _ecosystem_btn: Button = $UILayer/BottomPanel/EcosystemBtn
@onready var _end_day_btn: Button = $UILayer/BottomPanel/EndDayBtn

@onready var _upg_decor_btn: Button = $UILayer/UpgradeDecor
@onready var _upg_counter_btn: Button = $UILayer/UpgradeCounter
@onready var _upg_vault_btn: Button = $UILayer/UpgradeVault

# 弹窗
@onready var _bargain_window: Window = $BargainWindow
@onready var _bargain_label: Label = $BargainWindow/BargainVBox/BargainLabel
@onready var _bargain_input: LineEdit = $BargainWindow/BargainVBox/BargainInput
@onready var _bargain_submit: Button = $BargainWindow/BargainVBox/BargainHB/BargainSubmit
@onready var _bargain_cancel: Button = $BargainWindow/BargainVBox/BargainHB/BargainCancel

@onready var _monster_window: Window = $MonsterWindow
@onready var _monster_label: Label = $MonsterWindow/MonsterVBox/MonsterLabel
@onready var _monster_log: RichTextLabel = $MonsterWindow/MonsterVBox/MonsterLog
@onready var _monster_guard_btn: Button = $MonsterWindow/MonsterVBox/MonsterHB/MonsterGuardBtn
@onready var _monster_fight_btn: Button = $MonsterWindow/MonsterVBox/MonsterHB/MonsterFightBtn

# ========== 内置回调 ==========

func _ready() -> void:
	# 设置窗口大小
	get_window().size = Vector2i(SCREEN_W, SCREEN_H)
	
	# 1. 加载生态模拟器
	_sim = preload("res://scripts/EcosystemSim.gd").new()
	_sim.name = "EcosystemSimulator"
	add_child(_sim)
	_sim.initialize("res://ecosystem_data.json")
	
	# 2. 初始化子模块
	_initialize_modules()
	
	# 3. 搭建视觉环境
	_build_visual_shop()
	
	# 4. 初始化UI
	_initialize_ui()
	_update_resource_display()
	_update_upgrade_buttons()
	
	# 5. 连接UI按钮信号
	_buy_btn.pressed.connect(_on_buy_pressed)
	_bargain_btn.pressed.connect(_on_bargain_pressed)
	_reject_btn.pressed.connect(_on_reject_pressed)
	_shelf_btn.pressed.connect(_on_shelf_pressed)
	_end_day_btn.pressed.connect(_on_end_day_pressed)
	_ecosystem_btn.pressed.connect(_on_ecosystem_panel_pressed)
	_upg_decor_btn.pressed.connect(_on_upgrade_decor_pressed)
	_upg_counter_btn.pressed.connect(_on_upgrade_counter_pressed)
	_upg_vault_btn.pressed.connect(_on_upgrade_vault_pressed)
	
	# 6. 连接弹窗信号
	$BargainWindow/BargainVBox/BargainHB/BargainSubmit.pressed.connect(_on_bargain_submit)
	$BargainWindow/BargainVBox/BargainHB/BargainCancel.pressed.connect(_on_bargain_cancel)
	
	_bargain_window.hide()
	_bargain_window.close_requested.connect(_bargain_window.hide)
	_monster_window.hide()
	_monster_window.close_requested.connect(_monster_window.hide)
	
	# 7. 生成第一位冒险者（带延迟，等场景完全加载）
	await get_tree().create_timer(0.5).timeout
	_generate_adventurer()

## 初始化子模块
func _initialize_modules() -> void:
	var module_paths := {
		"adventurer": "res://scripts/shop/shop_adventurer.gd",
		"bargain": "res://scripts/shop/shop_bargain.gd",
		"monster": "res://scripts/shop/shop_monster.gd",
		"upgrade": "res://scripts/shop/shop_upgrade.gd",
		"ecosystem_panel": "res://scripts/shop/shop_ecosystem_panel.gd",
		"customer": "res://scripts/shop/shop_customer.gd",
		"visual": "res://scripts/shop/shop_visual.gd",
		"character": "res://scripts/shop/shop_character.gd",
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
	_visual_module = loader.call(module_paths["visual"])
	_character_module = loader.call(module_paths["character"])

## 搭建视觉商店环境
func _build_visual_shop() -> void:
	# 【重要！】角色模块必须添加到场景树，否则 Tween 不会工作
	if _character_module:
		_character_module.name = "CharacterModule"
		add_child(_character_module)  # 添加到场景树以支持 Tween 动画
	
	# 视觉环境（不需要在场景树中也能创建UI节点）
	if _visual_module and _visual_module.has_method("build_shop"):
		var _visual_nodes = _visual_module.build_shop(self)
		# 存储货架物品槽位引用
		set_meta("visual_nodes", _visual_nodes)
	
	# 角色控制器（先添加再build，确保节点树正确）
	if _character_module and _character_module.has_method("build_character"):
		_character_module.build_character(self)
		# 连接角色到达柜台的信号
		_character_module.arrived_at_counter.connect(_on_character_arrived)
		# 连接角色离开的信号
		_character_module.left_shop.connect(_on_character_left)

func _initialize_ui() -> void:
	gold = initial_gold
	reputation = initial_reputation

# ========== 公开方法（供子模块调用） ==========

## 向库存中添加物品
func add_to_inventory(item: Dictionary) -> void:
	if _inventory.size() >= _lv_vault * 10:
		_add_log("库存已满!", "red")
		return
	_inventory.append(item)
	_refresh_inventory_display()

## 将库存首位的物品上架到货架（或指定索引，如果需要）
func shelf_item(price: int) -> void:
	if _inventory.is_empty():
		return
	var item = _inventory.pop_front()
	item["price"] = price
	_shelf.append(item)
	_refresh_inventory_display()
	_refresh_shelf_display()

## 从货架移除指定索引的物品
func remove_from_shelf(index: int) -> void:
	if index >= 0 and index < _shelf.size():
		_shelf.remove_at(index)
		_refresh_shelf_display()

## 增加金币
func add_gold(amount: int) -> void:
	gold += amount
	_update_resource_display()
	gold_changed.emit(gold)

## 增加/减少信誉值
func add_reputation(amount: float) -> void:
	reputation = clamp(reputation + amount, 0.0, 100.0)
	_update_resource_display()
	reputation_changed.emit(reputation)

## 添加销售记录
func add_sales_log(entry: String) -> void:
	_sales_log.push_front(entry)
	if _sales_log.size() > MAX_SALES_LOG:
		_sales_log.pop_back()
	_refresh_sales_log_display()

# ========== UI刷新 ==========

func _update_resource_display() -> void:
	if _gold_label:
		_gold_label.text = "🪙 %d" % gold
	if _rep_label:
		_rep_label.text = "⭐ %.0f" % reputation
	if _day_label:
		_day_label.text = "📅 %s季 第%d天" % [season, day]
	_update_inventory_count()

func _update_inventory_count() -> void:
	var max_inv = _lv_vault * 10
	if _inv_count:
		_inv_count.text = "库存: %d/%d" % [_inventory.size(), max_inv]

func _refresh_inventory_display() -> void:
	for child in _inv_list.get_children():
		child.queue_free()
	for item in _inventory:
		var label = Label.new()
		label.text = "%s [%s] %d金" % [item.get("name", "?"), item.get("type", "?"), item.get("value", 0)]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1, 1, 0.8))
		_inv_list.add_child(label)
	_update_inventory_count()

## 刷新货架视觉显示
func _refresh_shelf_display() -> void:
	# 更新货架上的物品视觉展示
	if _visual_module and _visual_module.has_method("refresh_shelf_items"):
		var meta = get_meta("visual_nodes") if has_meta("visual_nodes") else null
		if meta:
			var item_container = meta.get("item_slots")
			var slot_positions = meta.get("slot_positions", [])
			_visual_module.refresh_shelf_items(item_container, _shelf, slot_positions)

func _refresh_sales_log_display() -> void:
	for child in _sales_log_list.get_children():
		child.queue_free()
	for entry in _sales_log:
		var label = Label.new()
		label.text = entry
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_sales_log_list.add_child(label)

func _update_upgrade_buttons() -> void:
	if _upg_decor_btn:
		_upg_decor_btn.text = "🎨装饰 Lv%d" % _lv_decor
		_upg_decor_btn.tooltip_text = "升级费用: %d金" % (300 * _lv_decor)
	if _upg_counter_btn:
		_upg_counter_btn.text = "🛒柜台 Lv%d" % _lv_counter
		_upg_counter_btn.tooltip_text = "升级费用: %d金" % (400 * _lv_counter)
	if _upg_vault_btn:
		_upg_vault_btn.text = "🔒保险箱 Lv%d" % _lv_vault
		_upg_vault_btn.tooltip_text = "升级费用: %d金" % (500 * _lv_vault)

# ========== 按钮回调 ==========

func _on_buy_pressed() -> void:
	if _is_processing_action:
		return
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
		_add_log("金币不足!", "red")
		_is_processing_action = false
		return
	
	# 成交后先禁用按钮，等角色离开再生成新冒险者
	gold -= cost
	add_to_inventory(goods.duplicate())
	_add_log(str("收购了 ", goods.get("name", "?"), "，花费 ", cost, " 金"))
	_reduce_ecosystem(goods.get("name", ""))
	
	# 角色离开
	_trigger_character_leave()
	_is_processing_action = false

func _on_bargain_pressed() -> void:
	if _is_processing_action:
		return
	if _current_adv.is_empty():
		return
	if _bargain_module and _bargain_module.has_method("start_bargain"):
		_bargain_module.start_bargain(self, _current_adv)

func _on_reject_pressed() -> void:
	if _is_processing_action:
		return
	_is_processing_action = true
	
	if _current_adv.is_empty():
		_is_processing_action = false
		return
	_add_log(str("拒绝了 ", _current_adv.get("goods", {}).get("name", ""), " 的货物"))
	
	# 角色离开
	_trigger_character_leave()
	_is_processing_action = false

func _on_shelf_pressed() -> void:
	var price_text = _price_input.text.strip_edges()
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
	shelf_item(price)
	_price_input.text = ""
	_add_log("已上架，售价 %d 金" % price)

func _on_end_day_pressed() -> void:
	_add_log(str("—— 第 ", day + 1, " 天结算开始 ——"))
	
	# 1. 顾客购买
	if _customer_module and _customer_module.has_method("process_customers"):
		_customer_module.process_customers(self)
	else:
		_process_customers_builtin()
	
	# 2. 怪物袭击
	if _monster_module and _monster_module.has_method("check_monster_attack"):
		_monster_module.check_monster_attack(self)
	else:
		_trigger_monster_attack_builtin()
	
	# 3. 生态模拟
	_sim.simulate_day()
	season = _sim.SEASONS[_sim.season]
	day = _sim.day
	
	day_ended.emit(day)
	_add_log(str("—— 第 ", day, " 天结束 ——"))
	
	# 4. 刷新UI
	_update_resource_display()
	_refresh_inventory_display()
	_refresh_shelf_display()
	
	# 5. 生态面板同步
	if _ecosystem_panel_module and _ecosystem_panel_module.has_method("is_window_visible"):
		if _ecosystem_panel_module.is_window_visible():
			_ecosystem_panel_module.refresh_panel(self)
	
	# 6. 生成明天的冒险者
	_generate_adventurer()

func _on_ecosystem_panel_pressed() -> void:
	if _ecosystem_panel_module and _ecosystem_panel_module.has_method("open_panel"):
		_ecosystem_panel_module.open_panel(self)

# ========== 冒险者生成系统 ==========

## 生成冒险者：让角色从门口走进来
func _generate_adventurer() -> void:
	if _adventurer_module and _adventurer_module.has_method("generate_adventurer"):
		_current_adv = _adventurer_module.generate_adventurer(self)
	else:
		_current_adv = _builtin_generate_adventurer()
	
	if _current_adv.is_empty():
		_update_adv_ui()
		return
	
	# 先更新信息UI（角色到达后才显示）
	_update_adv_ui()
	
	# 让角色根据性格换衣服
	var pers = _current_adv.get("personality", "普通")
	if _character_module and _character_module.has_method("set_color_by_personality"):
		_character_module.set_color_by_personality(pers)
	
	# 让角色从门口走进来
	if _character_module and _character_module.has_method("walk_to_counter"):
		# 先隐藏操作按钮，等待角色到达
		_set_buttons_enabled(false)
		_character_module.walk_to_counter()

## 角色到达柜台后的回调
func _on_character_arrived() -> void:
	_add_log(str(_current_adv.get("name", "?"), " 推门走了进来。"))
	_set_buttons_enabled(true)

## 角色离开商店后的回调
func _on_character_left() -> void:
	_add_log("冒险者离开了商店。")
	# 生成下一位冒险者
	_generate_adventurer()

## 触发角色离开商店
func _trigger_character_leave() -> void:
	_set_buttons_enabled(false)
	if _character_module and _character_module.has_method("walk_to_door"):
		_character_module.walk_to_door()
	else:
		# 没有角色模块，直接生成下一个
		_generate_adventurer()

## 启用/禁用操作按钮
func _set_buttons_enabled(enabled: bool) -> void:
	if _buy_btn:
		_buy_btn.disabled = not enabled
	if _bargain_btn:
		_bargain_btn.disabled = not enabled
	if _reject_btn:
		_reject_btn.disabled = not enabled

## 刷新冒险者信息UI
func _update_adv_ui() -> void:
	if _current_adv.is_empty():
		if _adv_info_label:
			_adv_info_label.text = "店内暂无客人..."
		if _goods_label:
			_goods_label.text = ""
		if _story_label:
			_story_label.text = ""
		_set_buttons_enabled(false)
		return
	
	if _adv_info_label:
		_adv_info_label.text = str(_current_adv.get("name", "?"), "（", _current_adv.get("personality", "普通"), "）")
	var goods = _current_adv.get("goods", {})
	if goods and _goods_label:
		_goods_label.text = str("带来：", goods.get("name", "?"), " [", goods.get("type", "?"), "]  价值 ", goods.get("value", 0), "金")
	if _story_label:
		_story_label.text = str("\"", _current_adv.get("story", ""), "\"")

# ========== 内建降级实现 ==========

func _builtin_generate_adventurer() -> Dictionary:
	var adv := {}
	adv["name"] = _random_name()
	adv["personality"] = _random_personality()
	
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

func _reduce_ecosystem(item_name: String) -> void:
	var tundra = _sim.domains["glowing_tundra"]
	for sp_id in tundra["species"]:
		if tundra["species"][sp_id]["name"] == item_name:
			tundra["species"][sp_id]["population"] = max(1, tundra["species"][sp_id]["population"] - 1)
			break

func _on_bargain_submit() -> void:
	if _bargain_module and _bargain_module.has_method("handle_submit"):
		_bargain_module.handle_submit(self, _current_adv)

func _on_bargain_cancel() -> void:
	if _bargain_module and _bargain_module.has_method("is_bargaining"):
		if _bargain_module.is_bargaining():
			_add_log("你放弃了议价，冒险者失望地离开了。")
			# 注意：cancel_bargain(shop, true) 内部会调用 _generate_adventurer()
			# 所以不需要再调用 _trigger_character_leave（避免重复生成）
			_bargain_module.cancel_bargain(self, true)
	else:
		_bargain_window.hide()

func _trigger_monster_attack_builtin() -> void:
	pass

func _process_customers_builtin() -> void:
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
			var msg = str("卖出 ", chosen["name"], " [", pref_type, "] 售价 ", price, " 金币 (利润 ", profit, ")")
			_add_log(msg)
			add_sales_log(msg)
			var rating = _calc_rating(ratio)
			reputation = clamp(reputation + (rating - 3.0) * 2.0, 0.0, 100.0)

func _calc_rating(ratio: float) -> float:
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

func _on_upgrade_decor_pressed() -> void:
	if _upgrade_module and _upgrade_module.has_method("upgrade_decor"):
		_upgrade_module.upgrade_decor(self)
	else:
		_execute_upgrade("decor")

func _on_upgrade_counter_pressed() -> void:
	if _upgrade_module and _upgrade_module.has_method("upgrade_counter"):
		_upgrade_module.upgrade_counter(self)
	else:
		_execute_upgrade("counter")

func _on_upgrade_vault_pressed() -> void:
	if _upgrade_module and _upgrade_module.has_method("upgrade_vault"):
		_upgrade_module.upgrade_vault(self)
	else:
		_execute_upgrade("vault")

func _execute_upgrade(type: String) -> void:
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
	_add_log("升级成功!")
	_update_upgrade_buttons()
	_update_resource_display()
	if type == "vault":
		_add_log(str("库存上限提升至 ", _lv_vault * 10))

# ========== 工具 ==========

func _random_name() -> String:
	var first = ["锈剑","影步","火拳","独眼","快手","银发"]
	var last = ["杰克","莉娜","巴特尔","艾希","莫娜"]
	return first[randi() % first.size()] + "·" + last[randi() % last.size()]

func _random_personality() -> String:
	return ["急躁","普通","耐心","狡猾","豪爽"][randi() % 5]

func _add_log(text: String, color := "white") -> void:
	_log_rich.append_text("[color=%s]%s[/color]\n" % [color, text])

# ========== 模块访问器 ==========

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
	_update_upgrade_buttons()

func set_lv_counter(val: int) -> void:
	_lv_counter = val
	_update_upgrade_buttons()

func set_lv_vault(val: int) -> void:
	_lv_vault = val
	_update_upgrade_buttons()

func add_log(text: String, color := "white") -> void:
	_add_log(text, color)
