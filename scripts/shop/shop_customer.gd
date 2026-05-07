extends Node
## 顾客购买模块
## 每日结束时触发顾客购买逻辑
## 每个顾客有独立名字，记录谁买了什么，返回每日销售统计

# ===== 材料类型映射表 =====
const SPECIES_TYPE_MAP := {
	"矿鼠": "兽皮",
	"猎手蜘蛛": "毒液",
	"穴居恐魔": "甲壳",
	"荧光蝠龙": "魔核",
	"荧光蜗牛": "腺体",
	"蝙蝠群": "爪牙",
	"史莱姆": "粘液",
	"石像鬼": "甲壳",
	"拟态宝箱": "魔核"
}
const FALLBACK_TYPES := ["骨材", "鳞片", "甲壳"]

# ===== 顾客名字池 =====
# 每位顾客都有一个身份，让销售记录更生动具体
const CUSTOMER_TITLES := ["冒险者", "旅人", "佣兵", "探索者", "拾荒者", "商人"]
const CUSTOMER_FIRST := ["铁锤", "黑袍", "独臂", "蒙面", "快刀", "银狐", "灰狼", "长弓", "铜牙", "石拳"]
const CUSTOMER_LAST := ["猎手", "游侠", "铁匠", "商人", "药师", "佣兵", "旅者", "骑士", "行者", "裁缝"]

## 生成随机顾客名字
## 格式如: "冒险者·铁锤猎手"
func _random_customer_name() -> String:
	var title = CUSTOMER_TITLES[randi() % CUSTOMER_TITLES.size()]
	var first = CUSTOMER_FIRST[randi() % CUSTOMER_FIRST.size()]
	var last = CUSTOMER_LAST[randi() % CUSTOMER_LAST.size()]
	return title + "·" + first + last

## 处理顾客购买流程
## 参数 shop: ShopManager 的引用
## 返回: 一个包含当日销售统计的字典
##   {sold_count: 成交件数, total_revenue: 总收入, total_profit: 总利润}
func process_customers(shop: Node) -> Dictionary:
	var lv_counter = shop.get_lv_counter()
	var reputation = shop.get_rep() if shop.has_method("get_rep") else 0.0

	# 计算当天顾客人数：基础1人 + 柜台等级影响 + 随机1~3人
	var customer_count = 1 + int(lv_counter * 0.5) + (randi() % 3)
	shop.add_log(str("👥 今日有 ", customer_count, " 位顾客光临..."))

	# ===== 销售统计 =====
	var stats := {
		"sold_count": 0,      # 成交件数
		"total_revenue": 0,   # 总收入
		"total_profit": 0,    # 总利润
		"items_sold": []      # 卖出的商品名列表
	}

	for i in range(customer_count):
		# 每位顾客生成一个名字
		var customer_name = _random_customer_name()

		var shelf = shop.get_shelf()
		if shelf.is_empty():
			shop.add_log(str("  [", customer_name, "] 货架上空空如也，顾客失望地离开了。"))
			break

		# 随机选择顾客偏好的材料类型
		var types = SPECIES_TYPE_MAP.values()
		var pref_type = types[randi() % types.size()]

		# 从货架筛选同类型商品
		var candidates = []
		for item in shelf:
			if item["type"] == pref_type:
				candidates.append(item)

		if candidates.is_empty():
			shop.add_log(str("  [", customer_name, "] 想买 ", pref_type, " 类商品，但缺货。"))
			continue

		# 从符合条件的商品中随机选一件
		var chosen = candidates[randi() % candidates.size()]
		var cost_val = chosen["value"]     # 收购成本价
		var price = chosen["price"]        # 上架售价
		var ratio = float(price) / float(cost_val)

		# 计算购买概率
		# 基础逻辑：售价越偏离成本，购买意愿越低
		var buy_chance = clamp(0.9 - (ratio - 1.0) * 0.5, 0.1, 1.0)
		# 受信誉和柜台等级影响
		buy_chance *= (0.8 + reputation * 0.004) + lv_counter * 0.02

		# 检查该材料类型是否在生态中稀缺
		var is_scarce = _get_type_ecosystem_scarcity(shop, pref_type)
		if is_scarce:
			buy_chance += 0.2              # 稀缺商品更受欢迎
			price = int(price * randf_range(1.1, 1.4))  # 价格自然上浮10~40%

		if randf() < buy_chance:
			# ---------- 成交！ ----------
			shop.add_gold(price)

			# 从货架移除商品
			var shelf_list = shop.get_shelf()
			var idx = shelf_list.find(chosen)
			if idx >= 0:
				shop.remove_from_shelf(idx)

			var profit = price - cost_val
			var msg = str("🛒 [", customer_name, "] 购买了 ", chosen["name"],
						" [", pref_type, "] 花费 ", price, " 金币 (利润 ", profit, ")")
			shop.add_log(msg)
			shop.add_sales_log(msg)

			# 顾客评分
			var rating = _calc_rating(ratio)
			if is_scarce:
				rating = min(5, rating + 1)  # 稀缺商品顾客更满意
			shop.add_reputation((rating - 3.0) * 2.0)

			# 顾客评价
			var rating_text = ""
			if rating >= 4.5:
				rating_text = "太棒了，物超所值！"
			elif rating >= 3.0:
				rating_text = "还算公道。"
			else:
				rating_text = "有点贵了..."
			shop.add_log(str("    ", customer_name, " 评价: ", "⭐".repeat(int(rating)), " \"", rating_text, "\""))

			# 更新统计
			stats.sold_count += 1
			stats.total_revenue += price
			stats.total_profit += profit
			stats.items_sold.append(chosen["name"])
		else:
			# 没成交
			shop.add_log(str("  [", customer_name, "] 嫌 ", chosen["name"], " 太贵，没买。"))

	return stats

## 检查某种材料类型在生态中是否稀缺（种群 < 容量的30%）
func _get_type_ecosystem_scarcity(shop: Node, type: String) -> bool:
	var sim = shop.get_sim()
	for domain_id in sim.domains:
		for sp_id in sim.domains[domain_id]["species"]:
			var sp = sim.domains[domain_id]["species"][sp_id]
			var sp_type = SPECIES_TYPE_MAP.get(sp["name"], "")
			if sp_type == "":
				sp_type = FALLBACK_TYPES[hash(sp["name"]) % FALLBACK_TYPES.size()]
			if sp_type == type and sp["population"] < sp["capacity"] * 0.3:
				return true
	return false

## 计算顾客评分（1.0~5.0星）
## ratio = 售价/成本，比值越高（越贵）评分越低
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
