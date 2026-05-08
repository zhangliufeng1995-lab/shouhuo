extends Node
## 生态面板模块
## 使用 CanvasLayer 覆盖层显示所有生态域的物种数据
## 修复：将 Window.new() 改为 CanvasLayer 覆盖层（和BargainWindow一样的模式），
##       避免独立OS窗口被主窗口遮挡、点不开的问题
##
## 关键结构：
##   CanvasLayer (Node，非Control)
##   └── Screen (Control，全屏铺满，作为尺寸锚点容器)
##       ├── Overlay (ColorRect，半透明遮罩，全屏)
##       ├── Panel (生态面板主体，固定位置)
##       └── Scroll → VBox (生态数据列表)

var _panel_canvas: CanvasLayer = null
var _panel_container: VBoxContainer = null

## 打开生态面板
## shop: ShopManager 引用
func open_panel(shop: Node) -> void:
	# 如果窗口不存在或已被销毁，重新创建
	if _panel_canvas == null or not is_instance_valid(_panel_canvas):
		_create_panel(shop)
	_refresh_panel(shop)
	_panel_canvas.show()

## 刷新面板内容
func refresh_panel(shop: Node) -> void:
	if _panel_canvas == null or not is_instance_valid(_panel_canvas):
		return
	_refresh_panel(shop)

## 判断窗口是否可见
func is_window_visible() -> bool:
	return _panel_canvas != null and is_instance_valid(_panel_canvas) and _panel_canvas.visible

## 关闭面板
func close_panel() -> void:
	if _panel_canvas and is_instance_valid(_panel_canvas):
		_panel_canvas.hide()

## 创建生态面板覆盖层（CanvasLayer）
func _create_panel(shop: Node) -> void:
	# 1. CanvasLayer（覆盖层，显示在所有UI之上）
	_panel_canvas = CanvasLayer.new()
	_panel_canvas.name = "EcologyPanelCanvas"
	_panel_canvas.layer = 128  # 高层级，确保在最前面
	_panel_canvas.hide()        # 初始隐藏
	shop.add_child(_panel_canvas)
	
	# 2. 中间层：全屏 Control（必须！CanvasLayer继承自Node不是Control，
	#    子节点的 set_anchors_preset 需要Control父节点才能生效）
	var screen = Control.new()
	screen.name = "EcologyScreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)  # 铺满整个窗口
	screen.mouse_filter = Control.MOUSE_FILTER_STOP       # 阻止点击穿透
	_panel_canvas.add_child(screen)
	
	# 3. 半透明遮罩（用锚点铺满全屏）
	var overlay = ColorRect.new()
	overlay.name = "EcologyOverlay"
	overlay.color = Color(0, 0, 0, 0.6)  # 半透明黑色
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)  # 铺满父Control
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP       # 阻止点击穿透
	screen.add_child(overlay)
	# 点击遮罩也可以关闭（方便用户）
	overlay.gui_input.connect(_on_overlay_clicked)
	
	# 4. 生态面板主窗口（Panel），左上角定位
	var panel = Panel.new()
	panel.name = "EcologyPanel"
	panel.visible = true
	panel.size = Vector2(600, 700)     # 面板尺寸
	panel.position = Vector2(80, 50)   # 面板位置
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # 阻止点击穿透到遮罩
	screen.add_child(panel)
	
	# 面板标题
	var title_label = Label.new()
	title_label.name = "EcologyTitle"
	title_label.text = "🌍 生态面板"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	title_label.position = Vector2(20, 15)
	title_label.size = Vector2(450, 35)
	panel.add_child(title_label)
	
	# 关闭按钮
	var close_btn = Button.new()
	close_btn.name = "EcologyCloseBtn"
	close_btn.text = "✖ 关闭"
	close_btn.position = Vector2(470, 12)
	close_btn.size = Vector2(110, 40)
	close_btn.pressed.connect(_on_close_btn_pressed)
	panel.add_child(close_btn)
	
	# 5. 滚动区域（放生态数据列表）- 添加到 panel 下，而不是 screen
	var scroll = ScrollContainer.new()
	scroll.name = "EcologyScroll"
	scroll.position = Vector2(15, 60)
	scroll.size = Vector2(570, 620)
	panel.add_child(scroll)  # ← 修复BUG-01：之前错误地加到 screen 下，导致滚动区域显示在屏幕左上角
	
	# 6. 容器VBox

	_panel_container = VBoxContainer.new()
	_panel_container.name = "EcologyContent"
	_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_panel_container)
	
	print("✅ 生态面板创建完成（CanvasLayer+Control模式）")

## 点击关闭按钮
func _on_close_btn_pressed() -> void:
	if _panel_canvas and is_instance_valid(_panel_canvas):
		_panel_canvas.hide()

## 点击遮罩关闭
func _on_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _panel_canvas and is_instance_valid(_panel_canvas):
			_panel_canvas.hide()

## 刷新生态面板内容
func _refresh_panel(shop: Node) -> void:
	if _panel_container == null or not is_instance_valid(_panel_container):
		return
	
	# 清空旧内容（保留VBox本身）
	for child in _panel_container.get_children():
		child.queue_free()
	
	var sim = shop.get_sim()
	if sim == null:
		return
	
	# ===== 标题：天数和季节 =====
	var header = Label.new()
	header.text = str("📅 第 ", sim.day, " 天  -  ", sim.SEASONS[sim.season], "季")
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color.GOLD)
	_panel_container.add_child(header)
	
	# 分隔线
	_panel_container.add_child(_make_separator(560))
	
	# ===== 遍历所有生态域 =====
	for domain_id in sim.domains:
		var domain = sim.domains[domain_id]
		
		# 域标题
		var domain_label = Label.new()
		domain_label.text = str("【", domain["name"], "】")
		domain_label.add_theme_font_size_override("font_size", 18)
		domain_label.add_theme_color_override("font_color", Color.CYAN)
		_panel_container.add_child(domain_label)
		
		# 遍历该域的所有物种
		for sp_id in domain["species"]:
			var sp = domain["species"][sp_id]
			var pop = sp["population"]
			var cap = sp["capacity"]
			var ratio = float(pop) / float(cap) * 100.0
			
			var sp_label = Label.new()
			sp_label.text = str("  ", sp["name"], ": ", pop, " / ", cap, " (", "%.0f" % ratio, "%)")
			
			# 根据种群密度着色：
			# 红色（<30%）→ 濒危
			# 绿色（30%~100%）→ 健康
			# 黄色（>100%）→ 泛滥
			if ratio < 30:
				sp_label.add_theme_color_override("font_color", Color.RED)
			elif ratio > 100:
				sp_label.add_theme_color_override("font_color", Color.YELLOW)
			else:
				sp_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
			
			sp_label.add_theme_font_size_override("font_size", 16)
			
			_panel_container.add_child(sp_label)
		
		# 域之间的间隔
		_panel_container.add_child(_make_separator(560))
	
	# 底部说明
	var note = Label.new()
	note.text = "🔴 濒危  🟢 健康  🟡 泛滥"
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	_panel_container.add_child(note)

## 创建分隔线
func _make_separator(width: int = 560) -> ColorRect:
	var sep = ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.3, 1)
	sep.size = Vector2i(width, 2)
	return sep
