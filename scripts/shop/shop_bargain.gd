extends Node
## 讨价还价模块
## 管理讨价还价窗口的逻辑，包括轮数、概率计算、成交处理

var _is_bargaining := false
var _bargain_round := 0
var _max_rounds := 4
var _last_offer := 0
var _current_adv_name := ""

## 开始讨价还价
## shop: shop_main 引用, adv: 当前冒险者字典
func start_bargain(shop: Node, adv: Dictionary) -> void:
	# 防抖：如果已经在讨价中，忽略重复调用
	if _is_bargaining:
		return
	
	_is_bargaining = true
	_bargain_round = 0
	_current_adv_name = adv.get("name", "冒险者")
	
	# 根据性格确定最大轮数
	var pers = adv.get("personality", "普通")
	_max_rounds = {"急躁": 2, "普通": 4, "耐心": 6, "狡猾": 3, "豪爽": 3}.get(pers, 4)
	
	# 初始要价 = 货物价值 × 1.0~1.3（冒险者会加点价）
	var goods = adv.get("goods", {})
	var base_value = goods.get("value", 0)
	_last_offer = int(base_value * randf_range(1.0, 1.3))
	
	var bargain_window = shop._bargain_window
	var bargain_label = shop._bargain_label
	var bargain_input = shop._bargain_input
	var bargain_submit = shop._bargain_submit
	
	bargain_label.text = "%s 要价：%d 金币\n（%s性格，最多 %d 轮）" % [_current_adv_name, _last_offer, pers, _max_rounds]
	bargain_input.text = str(_last_offer)
	bargain_window.show()
	bargain_input.grab_focus()
	
	# 锁定主界面操作
	shop.set_modal_open(true)
	
	# 防连点：按钮0.3秒内不可用
	bargain_submit.disabled = true
	await shop.get_tree().create_timer(0.3).timeout
	if is_instance_valid(bargain_submit):
		bargain_submit.disabled = false

## 处理出价（由 shop_main 的按钮回调调用）
func handle_submit(shop: Node, adv: Dictionary) -> void:
	if not _is_bargaining:
		return
	
	var input_text = shop._bargain_input.text.strip_edges()
	if not input_text.is_valid_int():
		shop.add_log("请输入有效的整数价格!", "red")
		return
	var input_price = int(input_text)
	if input_price <= 0:
		shop.add_log("价格必须大于0!", "red")
		return
	
	_bargain_round += 1
	var pers = adv.get("personality", "普通")
	var item_value = adv.get("goods", {}).get("value", 0)
	
	# ===== 出价判定逻辑 =====
	# 情况1：出价 >= 对方要价 → 直接成交
	if input_price >= _last_offer:
		shop.add_log("%s：这价格我接受!" % _current_adv_name)
		_finalize(shop, adv, input_price)
		return
	
	# 情况2：出价太低（低于物品价值的30%）→ 愤怒离开
	if input_price < item_value * 0.3:
		shop.add_log("%s：你在耍我吗？%s 大怒离去。" % [_current_adv_name, _current_adv_name])
		cancel_bargain(shop, true)
		return
	
	# 情况3：急躁性格 + 出价低于要价70% → 直接走
	if pers == "急躁" and input_price < _last_offer * 0.7:
		shop.add_log("%s 性子急，不愿多谈，走了。" % _current_adv_name)
		cancel_bargain(shop, true)
		return
	
	# ===== 概率计算 =====
	# 基础接受概率 = 15% + 每轮+12%
	var prob = 0.15 + _bargain_round * 0.12
	
	# 性格修正
	match pers:
		"耐心":
			prob += 0.2  # 耐心的人更容易接受
		"狡猾":
			prob -= 0.1  # 狡猾的人更难搞定
		"豪爽":
			prob += 0.15  # 豪爽的人好说话
	
	# 出价合理性修正：出价 >= 物品价值80% → +40%概率
	if input_price >= item_value * 0.8:
		prob += 0.4
	
	prob = clamp(prob, 0.0, 0.95)
	
	# ===== 判定结果 =====
	if randf() < prob:
		shop.add_log("%s 同意以 %d 金币成交。" % [_current_adv_name, input_price])
		_finalize(shop, adv, input_price)
	else:
		if _bargain_round >= _max_rounds:
			shop.add_log("%s 不耐烦了，谈判破裂。" % _current_adv_name)
			cancel_bargain(shop, true)
			return
		
		# 对方降价：降幅为差价的40%
		_last_offer = int(_last_offer - (_last_offer - input_price) * 0.4)
		shop.add_log("%s：至少 %d 金币。" % [_current_adv_name, _last_offer])
		
		# 更新窗口显示
		if is_instance_valid(shop._bargain_label):
			shop._bargain_label.text = "%s 要价：%d 金币\n（%s性格，最多 %d 轮）" % [_current_adv_name, _last_offer, pers, _max_rounds]
		if is_instance_valid(shop._bargain_input):
			shop._bargain_input.text = str(_last_offer)

## 成交：扣金币、加库存、减少生态、刷新UI
func _finalize(shop: Node, adv: Dictionary, price: int) -> void:
	if shop.gold < price:
		shop.add_log("金币不足!", "red")
		cancel_bargain(shop)
		return
	
	# ★ 扣钱前先检查库存容量，满则阻止（避免扣了钱但物品没加进去）
	var max_inv = shop.get_lv_vault() * 10
	if shop.get_inventory().size() >= max_inv:
		shop.add_log(str("⚠️ 库存已满 (", shop.get_inventory().size(), "/", max_inv, ")，讨价还价无法继续！"), "red")
		shop.add_log("💡 提示：可以先上架部分物品到货架，或升级保险箱扩大库存上限。")
		cancel_bargain(shop)
		return
	
	shop.gold -= price
	var goods = adv.get("goods", {}).duplicate()
	shop.add_to_inventory(goods)
	shop.add_log(str("讨价成功，以 ", price, " 金币收购 ", goods.get("name", "")))
	
	# 从生态中减少一个对应的物种
	var item_name = goods.get("name", "")
	var sim = shop.get_sim()
	# 从冒险者货物来源域中减少
	var domain_id = adv.get("goods", {}).get("domain", "glowing_tundra")
	if sim.domains.has(domain_id):
		var domain = sim.domains[domain_id]
		for sp_id in domain["species"]:
			if domain["species"][sp_id]["name"] == item_name:
				domain["species"][sp_id]["population"] = max(1, domain["species"][sp_id]["population"] - 1)
				break
	
	shop._update_all_status()
	cancel_bargain(shop)

## 取消/结束讨价还价
## reason_leave: 是否因为谈判破裂而离开（true=生成下一位冒险者）
func cancel_bargain(shop: Node, reason_leave := false) -> void:
	_is_bargaining = false
	if is_instance_valid(shop._bargain_window):
		shop._bargain_window.hide()
	# 解锁主界面操作
	shop.set_modal_open(false)
	if reason_leave:
		shop._generate_adventurer()

## 检查是否正在讨价还价
func is_bargaining() -> bool:
	return _is_bargaining
