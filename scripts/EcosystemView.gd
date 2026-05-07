extends Node2D

var sim: Node
var title_label: Label
var species_labels: Array[Label] = []
var event_label: Label
var ui_container: Control  # 用一个容器来装物种标签，避免干扰背景

func _ready():
	sim = load("res://scripts/EcosystemSim.gd").new()
	sim.name = "EcosystemSimulator"
	add_child(sim)
	sim.migration_happened.connect(_on_migration)
	sim.mutation_occurred.connect(_on_mutation)

	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.04, 0.04, 1)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(800, 600)
	add_child(bg)

	# 标题
	title_label = Label.new()
	title_label.position = Vector2(160, 80)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.add_theme_font_size_override("font_size", 26)
	add_child(title_label)

	# 事件提示
	event_label = Label.new()
	event_label.position = Vector2(160, 500)
	event_label.add_theme_color_override("font_color", Color.ORANGE)
	event_label.add_theme_font_size_override("font_size", 18)
	add_child(event_label)

	# 模拟按钮
	var btn = Button.new()
	btn.text = "模拟一天"
	btn.position = Vector2(160, 540)
	btn.size = Vector2(160, 50)
	btn.pressed.connect(_on_btn)
	add_child(btn)

	# 第一次更新UI
	update_ui()

func _on_btn():
	sim.simulate_day()
	update_ui()

func _on_migration(sp_name, from_domain, to_domain, count):
	event_label.text = "⚠️ 迁徙！%s → %s (%d只)" % [from_domain, to_domain, count]

func _on_mutation(sp_name, mut_name, domain_name):
	event_label.text = "🧬 异化！%s 的变体 %s 在 %s 出现" % [sp_name, mut_name, domain_name]

func update_ui():
	title_label.text = "🌍 地下城生态 · 第%d天 (%s)" % [sim.day, ["春","夏","秋","冬"][sim.season]]

	# 获取当前荧光苔原域的所有物种
	var tundra = sim.domains["glowing_tundra"]
	var species_ids = tundra["species"].keys()
	var needed_labels = species_ids.size()

	# 补齐标签
	while species_labels.size() < needed_labels:
		var lbl = Label.new()
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 18)
		add_child(lbl)
		species_labels.append(lbl)

	# 移除多余的标签
	while species_labels.size() > needed_labels:
		var extra = species_labels.pop_back()
		extra.queue_free()

	# 刷新所有标签的位置和文本
	var y = 160
	for i in range(needed_labels):
		var sp_id = species_ids[i]
		var sp = tundra["species"][sp_id]
		species_labels[i].position = Vector2(160, y)
		species_labels[i].text = "%s：%d / %d" % [sp["name"], sp["population"], sp["capacity"]]
		y += 40
