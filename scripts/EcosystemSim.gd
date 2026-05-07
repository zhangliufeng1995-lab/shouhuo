extends Node

var domains: Dictionary
var migration_rules: Array

var day := 0
var season := 0
const SEASONS := ["春", "夏", "秋", "冬"]

signal migration_happened(sp_name: String, from_domain: String, to_domain: String, count: int)
signal mutation_occurred(sp_name: String, mut_name: String, domain_name: String)

func _ready():
	# 不再自动加载，由外部调用 initialize()
	pass

## 初始化生态模拟器，可在游戏进行中多次调用以重置
func initialize(path: String) -> void:
	day = 0
	season = 0
	domains.clear()
	migration_rules.clear()
	_load_data(path)

func _load_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			var data = json.get_data()
			domains = data["domains"]
			migration_rules = data["migration_rules"]
			print("生态数据加载成功: ", path)
		else:
			print("JSON 解析错误: ", error)
	else:
		print("无法打开 ", path)

func simulate_day():
	day += 1
	if day % 90 == 0:
		season = (season + 1) % 4

	var season_factor = get_season_factor()

	# 第一遍：记录当前所有物种数量（作为捕食基数）
	var current_pops = {}
	for domain_id in domains:
		current_pops[domain_id] = {}
		for sp_id in domains[domain_id]["species"]:
			current_pops[domain_id][sp_id] = domains[domain_id]["species"][sp_id]["population"]

	# 第二遍：生长与捕食
	for domain_id in domains:
		var domain = domains[domain_id]
		for sp_id in domain["species"]:
			var sp = domain["species"][sp_id]
			var cap = sp["capacity"]

			# ----- 计算食物充足度 (food_ratio) -----
			var total_prey = 0
			for prey_id in sp.get("prey", []):
				if current_pops[domain_id].has(prey_id):
					total_prey += current_pops[domain_id][prey_id]

			var needed_food = sp["population"] * 2
			var food_ratio = 1.0
			if total_prey > 0 and needed_food > 0:
				food_ratio = min(2.0, float(total_prey) / float(needed_food))

			# ----- 动态最大容量（受食物影响） -----
			var effective_capacity = cap
			if not sp["prey"].is_empty():
				effective_capacity = int(cap * clamp(food_ratio, 0.3, 2.0))

			var pop = sp["population"]

			# ----- 拥挤惩罚 -----
			var crowding_penalty = 1.0
			if pop > cap * 1.3:
				crowding_penalty = max(0.1, 1.0 - (float(pop - cap * 1.3) / float(cap)))

			# ----- 计算增长率 -----
			var base_growth_rate = 0.08
			var rate: float

			if sp["prey"].is_empty():
				rate = base_growth_rate * crowding_penalty + randf_range(-0.02, 0.02)
			else:
				rate = (base_growth_rate * food_ratio) + randf_range(-0.03, 0.03)
				rate = clamp(rate, -0.05, 0.20)

			# 应用增长率
			var change = int(pop * rate)
			pop = max(1, pop + change)

			# ----- 容量限制 -----
			pop = min(pop, effective_capacity * 2)

			# ----- 捕食消耗 -----
			for prey_id in sp.get("prey", []):
				if domain["species"].has(prey_id):
					var prey = domain["species"][prey_id]
					var eat_rate = 0.06 + randf_range(-0.02, 0.02)
					var eaten = int(sp["population"] * eat_rate)
					eaten = min(eaten, prey["population"])
					prey["population"] = max(0, prey["population"] - eaten)

			sp["population"] = pop

			# ----- 异化检查 -----
			if sp.get("mutation_chance", 0) > 0 and randf() < sp["mutation_chance"]:
				for mut_id in sp["mutations"]:
					var mut = sp["mutations"][mut_id]
					if randf() < mut["chance"]:
						emit_signal("mutation_occurred", sp["name"], mut["name"], domain["name"])
						break

	# ----- 种群恢复机制 -----
	for domain_id in domains:
		var domain = domains[domain_id]
		for sp_id in domain["species"]:
			var sp = domain["species"][sp_id]
			if sp["population"] <= 1:
				var restore_rate = 0.15 if sp["prey"].is_empty() else 0.05
				var restore_amount = max(2, int(sp["capacity"] * restore_rate))
				sp["population"] = restore_amount
				print("种群恢复：", sp["name"], "恢复至", restore_amount)

	# ----- 迁徙 -----
	for rule in migration_rules:
		var from_domain = domains[rule["from"]]
		var to_domain = domains[rule["to"]]
		var sp_data = from_domain["species"].get(rule["species"])
		if not sp_data or sp_data["population"] == 0:
			continue

		var ratio = float(sp_data["population"]) / float(sp_data["capacity"])
		if ratio >= rule["threshold"]:
			var base_rate = (ratio - rule["threshold"]) / rule["threshold"] * rule["rate"]
			base_rate = clamp(base_rate, 0.05, 0.60)
			var actual_rate = base_rate * (1.0 + season_factor * 0.3)
			actual_rate = clamp(actual_rate, 0.0, 1.0)

			var migrants = int(sp_data["population"] * actual_rate)
			if migrants > 0:
				sp_data["population"] -= migrants
				if not to_domain["species"].has(rule["species"]):
					to_domain["species"][rule["species"]] = {
						"name": sp_data["name"],
						"population": 0,
						"capacity": sp_data["capacity"],
						"prey": sp_data.get("prey", []),
						"mutation_chance": sp_data.get("mutation_chance", 0),
						"mutations": sp_data.get("mutations", {})
					}
				to_domain["species"][rule["species"]]["population"] += migrants
				emit_signal("migration_happened", sp_data["name"], from_domain["name"], to_domain["name"], migrants)

func get_season_factor() -> float:
	match SEASONS[season]:
		"春": return 1.0
		"夏": return 0.0
		"秋": return 0.5
		"冬": return -0.5
	return 0.0

## 减少指定域中的物种数量（供商店调用）
func reduce_species(domain_id: String, species_id: String, amount: int) -> void:
	if domains.has(domain_id) and domains[domain_id]["species"].has(species_id):
		var sp = domains[domain_id]["species"][species_id]
		sp["population"] = max(1, sp["population"] - amount)
