extends Node
## 冒险者生成模块
## 从荧光苔原域按种群权重选择物种（70%），或30%概率从其他域跨域取货
## 计算价格，生成冒险者信息和狩猎故事

# 材料类型映射表（与 shop_main 保持一致）
const SPECIES_TYPE_MAP := {
	"矿鼠": "兽皮",
	"猎手蜘蛛": "毒液",
	"穴居恐魔": "甲壳",
	"荧光蝠龙": "魔核",
	"荧光蜗牛": "腺体",
	"蝙蝠群": "爪牙",
	"史莱姆": "粘液",
	"石像鬼": "甲壳",
	"拟态宝箱": "魔核",
	"熔岩甲虫": "甲壳",
	"硫磺猎犬": "兽皮",
	"炎魔": "魔核",
	"骸骨骑士": "骨材",
	"食腐鸟": "爪牙",
	"寄生蠕虫": "腺体",
	"石甲蜥蜴": "鳞片"
}
const FALLBACK_TYPES := ["骨材", "鳞片", "甲壳"]
const BASE_PRICE_FACTOR := 0.7
const CROSS_DOMAIN_CHANCE := 0.3  # 30% 跨域概率

## 跨域商人的名字池（外地来的冒险者用）
const CROSS_DOMAIN_NAMES := [
	"远行者·萨拉丁", "流浪商·卡珊", "异乡人·格里姆",
	"旅人·艾薇", "行商·铁砧"
]

## 所有冒险者名字池
const ADV_FIRST_NAMES := ["锈剑","影步","火拳","独眼","快手","银发","铁盾","灰烬","断刃","回声"]
const ADV_LAST_NAMES := ["杰克","莉娜","巴特尔","艾希","莫娜","格罗","塞拉","沃夫","伊登","索恩"]

## 生成一位冒险者，返回冒险者字典
## 参数 shop: shop_main 的引用，用于读取生态数据和状态
func generate_adventurer(shop: Node) -> Dictionary:
	var adv := {}
	adv["name"] = _random_name()
	adv["personality"] = _random_personality()
	
	var sim = shop.get_sim()
	
	# ===== 跨域商人判定 =====
	# 30% 概率从其他域选取，如果其他域无物种则回退到荧光苔原域
	var use_cross_domain := randf() < CROSS_DOMAIN_CHANCE
	var target_domain_id := "glowing_tundra"
	var domain_name := "荧光苔原域"
	
	if use_cross_domain:
		var other_domains := []
		for did in sim.domains:
			if did != "glowing_tundra":
				other_domains.append(did)
		
		if not other_domains.is_empty():
			# 随机选一个其他域
			other_domains.shuffle()
			for did in other_domains:
				var d = sim.domains[did]
				if not d["species"].is_empty():
					target_domain_id = did
					domain_name = d["name"]
					# 跨域商人用特殊名字
					adv["name"] = CROSS_DOMAIN_NAMES[randi() % CROSS_DOMAIN_NAMES.size()]
					break
	
	# ===== 从目标域加权选取物种 =====
	var chosen = _get_weighted_species(sim, target_domain_id)
	if chosen.is_empty():
		# 如果目标域无物种，回退到荧光苔原域
		if target_domain_id != "glowing_tundra":
			chosen = _get_weighted_species(sim, "glowing_tundra")
			if chosen.is_empty():
				return {}
			domain_name = "荧光苔原域"
		else:
			return {}
	
	var chosen_sp = chosen["data"]
	var capacity = chosen_sp["capacity"]
	var population = chosen_sp["population"]
	
	# 数学推导：货物价值计算
	# 基础价值 = 容量 × 0.7 × 10
	# 最终价值 = 基础价值 × 生态稀缺倍率 × 跨域溢价
	var base_value := int(float(capacity) * BASE_PRICE_FACTOR * 10.0)
	
	# 跨域商品稀有度加成（外地货更贵）
	var cross_domain_premium := 1.0
	if target_domain_id != "glowing_tundra":
		cross_domain_premium = randf_range(1.2, 1.8)
	
	# 根据生态状态调整价格
	var price_multiplier = 1.0
	var story_tag = "normal"
	if population < capacity * 0.3:
		# 稀缺：价格飙升1.5~2.5倍
		price_multiplier = randf_range(1.5, 2.5)
		story_tag = "scarce"
	elif population > capacity * 1.5:
		# 泛滥：价格打折0.5~0.7倍
		price_multiplier = randf_range(0.5, 0.7)
		story_tag = "abundant"
	else:
		# 正常：价格小幅波动0.8~1.2倍
		price_multiplier = randf_range(0.8, 1.2)
	
	var final_multiplier: float = price_multiplier * cross_domain_premium
	var value: int = max(5, int(base_value * final_multiplier))
	
	# 确定材料类型
	var item_type = SPECIES_TYPE_MAP.get(chosen_sp["name"], "")
	if item_type == "":
		item_type = FALLBACK_TYPES[hash(chosen_sp["name"]) % FALLBACK_TYPES.size()]
	
	adv["goods"] = {
		"name": chosen_sp["name"],
		"type": item_type,
		"domain": target_domain_id,
		"domain_name": domain_name,
		"value": value,
		"population": population,
		"id": chosen["id"]
	}
	
	# 根据场景生成不同风格的狩猎故事
	if target_domain_id != "glowing_tundra":
		adv["story"] = "我从远方%s带来了一只%s，这可是稀罕货！" % [domain_name, chosen_sp["name"]]
	elif story_tag == "scarce":
		adv["story"] = "为了这只%s，我追踪了整整三天，差点交代在洞里。" % chosen_sp["name"]
	elif story_tag == "abundant":
		adv["story"] = "随手就能逮到%s，现在到处都是，不值钱了。" % chosen_sp["name"]
	else:
		if population < 20:
			adv["story"] = "这%s还算常见，不过这只个头特别大，应该能卖个好价钱。" % chosen_sp["name"]
		else:
			adv["story"] = "今天运气不错，抓到一只%s。" % chosen_sp["name"]
	
	return adv

## 从一个指定的生态域加权选择物种
## sim: 生态模拟器, domain_id: 域ID
func _get_weighted_species(sim: Node, domain_id: String) -> Dictionary:
	var domain = sim.domains[domain_id]
	var species_ids = domain["species"].keys()
	if species_ids.is_empty():
		return {}
	
	# 使用种群数量作为权重，种群越大越容易遇到
	var total_weight := 0
	var weights = {}
	for sp_id in species_ids:
		var sp = domain["species"][sp_id]
		var weight = max(1, sp["population"])
		weights[sp_id] = weight
		total_weight += weight
	
	if total_weight == 0:
		return {}
	
	var roll = randi() % total_weight
	var cumulative = 0
	for sp_id in weights:
		cumulative += weights[sp_id]
		if roll < cumulative:
			return {"id": sp_id, "data": domain["species"][sp_id]}
	
	var first_id = species_ids[0]
	return {"id": first_id, "data": domain["species"][first_id]}

## 生成随机冒险者名字
func _random_name() -> String:
	var first = ADV_FIRST_NAMES[randi() % ADV_FIRST_NAMES.size()]
	var last = ADV_LAST_NAMES[randi() % ADV_LAST_NAMES.size()]
	return first + "·" + last

## 生成随机性格
func _random_personality() -> String:
	return ["急躁", "普通", "耐心", "狡猾", "豪爽"][randi() % 5]
