extends Node
## 鼠标坐标调试工具
## 运行后点击画面任意位置，会在控制台输出点击坐标
## 用于帮助校准透明按钮位置与背景图UI的对齐

func _ready() -> void:
	# 在 UILayer 上添加一个全屏透明区域来捕捉点击
	var overlay = ColorRect.new()
	overlay.color = Color(1, 1, 1, 0)  # 完全透明
	overlay.mouse_filter = 0  # 接收点击
	overlay.size = Vector2(1292, 1217)
	
	# 添加到场景
	var ui_layer = get_node("../UILayer")
	if ui_layer:
		ui_layer.add_child(overlay)
		overlay.gui_input.connect(_on_overlay_input)
		print("===== 鼠标坐标调试模式已启动 =====")
		print("请点击背景图上的UI按钮位置，记录坐标")
		print("点击后按 F11 查看控制台输出的坐标")


func _on_overlay_input(event: InputEvent) -> void:
	"""捕捉鼠标点击并输出坐标"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("点击位置: x=" + str(event.position.x) + ", y=" + str(event.position.y))
