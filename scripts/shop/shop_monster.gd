extends Node
## 怪物袭击模块
## 每日结束时判断是否触发袭击、处理守卫/硬扛选择、掉落/损失逻辑

var _monster_names := ["暗影潜伏者", "石像鬼", "穴居恐魔", "骸骨骑士", "巨型蜘蛛", "熔岩蠕虫"]

# 存储本次袭击的参数（避免信号bind连接/断开的问题）
var _current_guard_cost := 0
var _current_is_elite := false
var _current_monster_name := ""

## 检查并触发怪物袭击
## shop: shop_main 引用
func check_monster_attack(shop: Node) -> void:
	var day = shop.get_day()
	
	# 触发概率 = 基础15% + 每天增加0.1%（随时间略微增加难度）
	var base_chance = 0.15 + day * 0.001
	if randf() > base_chance:
		return
	
	# 判定是否为精英怪物（更强，但掉落更好）
	var is_elite = randf() < (0.2 + day * 0.002)
	_current_is_elite = is_elite
	var monster = (("精英 " if is_elite else "") + _monster_names[randi() % _monster_names.size()])
	_current_monster_name = monster
	_current_guard_cost = 30 + day * 2  # 守卫费用随天数增加
	
	# 更新怪物窗口UI
	shop._monster_label.text = "怪物 " + monster + " 冲进了店铺!"
	shop._monster_log.text = "怪物冲了进来，开始破坏货架...\n请选择应对方式："
	shop._monster_guard_btn.text = "💰 请守卫 (" + str(_current_guard_cost) + "金)"
	
	# 按钮信号已由 ShopManager.gd 的 _bind_popup_signals() 静态连接
	# shop_monster.gd 不再需要管理信号连接/断开，消除了信号累积bug
	shop._monster_window.show()
	
	# 锁定主界面操作（弹窗期间不可点按钮）
	shop.set_modal_open(true)

## 点击"请守卫"按钮
func _on_guard_clicked(shop: Node) -> void:
	# 检查窗口是否还可见，防止重复点击
	if shop._monster_window and is_instance_valid(shop._monster_window):
		shop._monster_window.hide()
	
	var guard_cost = _current_guard_cost
	if shop.gold < guard_cost:
		shop.add_log("金币不足，无法雇佣守卫，只能硬扛!", "red")
		_execute_fight_result(shop, false, _current_is_elite, _current_monster_name)
	else:
		shop.gold -= guard_cost
		shop.add_log(str("花费了 ", guard_cost, " 金币雇佣守卫。"))
		_execute_fight_result(shop, true, _current_is_elite, _current_monster_name)
	
	shop._update_all_status()

## 点击"硬扛"按钮
func _on_fight_clicked(shop: Node) -> void:
	# 检查窗口是否还可见，防止重复点击
	if shop._monster_window and is_instance_valid(shop._monster_window):
		shop._monster_window.hide()
	
	shop.add_log(str("亲自迎战 ", _current_monster_name, "!"))
	_execute_fight_result(shop, false, _current_is_elite, _current_monster_name)

## 执行战斗结果
func _execute_fight_result(shop: Node, had_guard: bool, is_elite: bool, monster: String) -> void:
	var day = shop.get_day()
	
	# 收集本次袭击的详细数据（用于记录到 _monster_attack_logs）
	var log_data: Dictionary = {
		"day": day + 1,                          # 袭击发生天数（+1因为 day 从0开始）
		"monster_name": monster,                 # 怪物名
		"is_elite": is_elite,                    # 是否精英
		"had_guard": had_guard,                  # 是否请守卫
		"success": false,                        # 是否成功（稍后设置）
		"guard_cost": _current_guard_cost,       # 守卫费用
		"loot_item": null,                       # 掉落物（如果有）
		"lost_item": null,                       # 丢失物（如果有）
		"success_chance": 0.0,                   # 成功率
	}
	
	# 成功概率计算：
	# 有守卫 → 70%基础成功率
	# 硬扛 → 70% - 每天下降1%，最低30%
	var success_chance: float = 0.7 if had_guard else max(0.3, 0.7 - day * 0.01)
	log_data.success_chance = success_chance
	
	# 弹窗战斗信息增强：更新怪物窗口显示更详细的信息
	if had_guard:
		shop._monster_label.text = str("🛡 花费 ", _current_guard_cost, " 金币雇佣了守卫对抗 ", monster, "！\n\n守卫成功率：", int(success_chance * 100), "%")
	else:
		shop._monster_label.text = str("⚔ 你亲自迎战 ", monster, "！\n\n硬扛成功率：", int(success_chance * 100), "%")
	
	if randf() < success_chance:
		# 胜利！
		log_data.success = true
		shop.add_log(str("✅ 成功击退了 ", monster, "!"))
		
		# 掉落判定：精英怪60%，普通怪30%
		var drop_chance = 0.6 if is_elite else 0.3
		if randf() < drop_chance:
			var sim = shop.get_sim()
			var tundra = sim.domains["glowing_tundra"]
			var species_ids = tundra["species"].keys()
			if not species_ids.is_empty():
				var chosen_id = species_ids[randi() % species_ids.size()]
				var chosen_sp = tundra["species"][chosen_id]
				var loot_value = randi() % 50 + 10 + (30 if is_elite else 0)
				var loot_item = {
					"name": chosen_sp["name"] + "残骸",
					"type": "杂物",
					"value": loot_value
				}
				shop.add_to_inventory(loot_item)
				log_data.loot_item = loot_item.duplicate()
				shop.add_log(str("🎁 怪物掉落了 ", loot_item["name"], " [杂物] 价值 ", loot_item["value"], " 金"))
	else:
		# 失败！
		log_data.success = false
		shop.add_log(str("❌ 被 ", monster, " 击败了!"))
		var shelf = shop.get_shelf()
		if shelf.is_empty():
			shop.add_log("幸好货架空无一物，没有损失。")
		else:
			# 随机丢失一件货架商品
			var lost_item = shelf[randi() % shelf.size()]
			log_data.lost_item = lost_item.duplicate()
			shop.add_log(str("💔 丢失了货物: ", lost_item["name"]))
			var idx = shelf.find(lost_item)
			if idx >= 0:
				shop.remove_from_shelf(idx)
	
	# 将本次袭击详细记录保存到主控（可在袭击记录面板查看）
	shop.add_monster_attack_log(log_data)
	
	shop._refresh_inventory_display()
	
	# 解除弹窗锁定（怪物袭击处理完毕）
	shop.set_modal_open(false)
