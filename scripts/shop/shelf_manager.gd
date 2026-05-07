extends CanvasLayer
## 已上架物品管理弹窗（场景UI + 脚本控制版）
## UI节点在 ShelfManagerWindow.tscn 中定义，脚本通过 @onready 引用
## 调用方式：
##   open(shop_ref) - 打开弹窗并加载数据
##   close()        - 关闭弹窗
##   refresh()      - 刷新数据与UI

# ========== 信号 ==========
signal price_changed(index: int, new_price: int)  # 调整价格后发出
signal item_off_shelved(index: int)               # 下架后发出
signal batch_off_shelved(indices: Array)           # 批量下架后发出

# ========== 纹理资源（供动态物品行使用） ==========
const TEX_BTN_ADJUST := preload("res://scripts/shop/ui/Btn_Shelf_AdjustPrice.png")
const TEX_BTN_OFFSHELF := preload("res://scripts/shop/ui/Btn_Shelf_OffShelf.png")
const TEX_SLIDER_TRACK := preload("res://scripts/shop/ui/Slider_ItemPrice_Track.png")
const TEX_SLIDER_THUMB := preload("res://scripts/shop/ui/Slider_ItemPrice_Thumb.png")

# 场景中 TextureButton 的纹理资源（9个按钮）
const TEX_BTN_PAGE_FIRST := preload("res://scripts/shop/ui/Btn_Shelf_PageFirst.png")
const TEX_BTN_PAGE_PREV := preload("res://scripts/shop/ui/Btn_Shelf_PagePrev.png")
const TEX_BTN_PAGE_NEXT := preload("res://scripts/shop/ui/Btn_Shelf_PageNext.png")
const TEX_BTN_PAGE_LAST := preload("res://scripts/shop/ui/Btn_Shelf_PageLast.png")
const TEX_BTN_PRICE_MINUS := preload("res://scripts/shop/ui/Btn_PriceAdjust_Minus.png")
const TEX_BTN_PRICE_PLUS := preload("res://scripts/shop/ui/Btn_PriceAdjust_Plus.png")
const TEX_BTN_SAVE_PRICE := preload("res://scripts/shop/ui/Btn_ItemPrice_Save.png")
const TEX_BTN_BATCH_OFF := preload("res://scripts/shop/ui/Btn_Shelf_BatchOffShelf_.png")
const TEX_BTN_CLOSE := preload("res://scripts/shop/ui/Btn_ShelfWindow_Close.png")

# ========== 文字颜色 ==========
const COLOR_GOLD := Color(0.95, 0.75, 0.20)       # 暖金色文字
const COLOR_GOLD_DIM := Color(0.75, 0.55, 0.15)    # 暗金色
const COLOR_TEXT := Color(1.0, 1.0, 1.0)           # 白色主文字
const COLOR_TEXT_DIM := Color(0.85, 0.82, 0.75)    # 浅米色辅助文字
const COLOR_WARN_RED := Color(1.0, 0.30, 0.20)     # 红色警示

# ========== 常量 ==========
const ITEMS_PER_PAGE := 8  # 每页显示物品数

# ========== @onready 节点引用（对接场景中的UI节点） ==========
@onready var _overlay: ColorRect = $Overlay

# --- 左侧：货架列表 ---
@onready var _label_title: Label = $Panel_Root/Left_ShelfList/TitleBar/Label_Title
@onready var _vbox_shelf_items: VBoxContainer = $Panel_Root/Left_ShelfList/Scroll_ShelfList/ShelfItems
@onready var _label_page_info: Label = $Panel_Root/Left_ShelfList/Pagination/Label_PageInfo
@onready var _btn_page_first: TextureButton = $Panel_Root/Left_ShelfList/Pagination/Btn_PageFirst
@onready var _btn_page_prev: TextureButton = $Panel_Root/Left_ShelfList/Pagination/Btn_PagePrev
@onready var _btn_page_next: TextureButton = $Panel_Root/Left_ShelfList/Pagination/Btn_PageNext
@onready var _btn_page_last: TextureButton = $Panel_Root/Left_ShelfList/Pagination/Btn_PageLast

# --- 右侧：物品详情 ---
@onready var _label_item_name: Label = $Panel_Root/Right_ItemDetail/Label_ItemName
@onready var _label_rarity: Label = $Panel_Root/Right_ItemDetail/Label_Rarity
@onready var _label_quantity: Label = $Panel_Root/Right_ItemDetail/Label_Quantity
@onready var _label_desc: Label = $Panel_Root/Right_ItemDetail/Label_Desc
@onready var _label_shelf_qty: Label = $Panel_Root/Right_ItemDetail/Label_ShelfQty
@onready var _label_unit_price: Label = $Panel_Root/Right_ItemDetail/Label_UnitPrice
@onready var _label_total_price: Label = $Panel_Root/Right_ItemDetail/Label_TotalPrice
@onready var _label_shelf_time: Label = $Panel_Root/Right_ItemDetail/Label_ShelfTime
@onready var _label_recommend_price: Label = $Panel_Root/Right_ItemDetail/Label_RecommendPrice
@onready var _label_tip_text: Label = $Panel_Root/Right_ItemDetail/Label_TipText
@onready var _input_adjust_price: LineEdit = $Panel_Root/Right_ItemDetail/Input_AdjustPrice
@onready var _slider_price: HSlider = $Panel_Root/Right_ItemDetail/Slider_Price
@onready var _icon_item_sprite: TextureRect = $Panel_Root/Right_ItemDetail/Icon_ItemSprite
@onready var _btn_price_minus: TextureButton = $Panel_Root/Right_ItemDetail/Btn_PriceMinus
@onready var _btn_price_plus: TextureButton = $Panel_Root/Right_ItemDetail/Btn_PricePlus
@onready var _btn_save_price: TextureButton = $Panel_Root/Right_ItemDetail/Btn_SavePrice

# --- 底部栏 ---
@onready var _btn_batch_off: TextureButton = $Panel_Root/Bottom_Bar/Btn_BatchOffShelf
@onready var _btn_close: TextureButton = $Panel_Root/Btn_Close

# ========== 私有变量 ==========
var _shop_ref: Node                       # 关联的 ShopManager 引用
var _shelf_data: Array[Dictionary] = []   # 当前货架数据快照
var _current_page: int = 0                # 当前页码（0起始）
var _total_pages: int = 1                 # 总页数
var _selected_item_index: int = -1        # 当前选中的物品索引
var _shelf_start_time: Array[int] = []    # 每个物品的上架时间戳

# ========== 内置回调 ==========

func _ready() -> void:
	"""初始化：加载按钮纹理→设置滑块样式→连接信号→默认隐藏"""
	_load_button_textures()
	_setup_slider_style()
	_connect_signals()
	hide()

# ========== 按钮纹理加载（场景中的 TextureButton） ==========

func _load_button_textures() -> void:
	"""为场景中所有 TextureButton 节点设置 texture_normal 纹理

	注意：.tscn 文件中的 TextureButton 如果用 modify_node_property 设置 texture_normal
	可能不会持久化保存到磁盘（Godot 编辑器内部优化），所以改用代码加载最可靠。
	"""
	_btn_page_first.texture_normal = TEX_BTN_PAGE_FIRST
	_btn_page_prev.texture_normal = TEX_BTN_PAGE_PREV
	_btn_page_next.texture_normal = TEX_BTN_PAGE_NEXT
	_btn_page_last.texture_normal = TEX_BTN_PAGE_LAST
	_btn_price_minus.texture_normal = TEX_BTN_PRICE_MINUS
	_btn_price_plus.texture_normal = TEX_BTN_PRICE_PLUS
	_btn_save_price.texture_normal = TEX_BTN_SAVE_PRICE
	_btn_batch_off.texture_normal = TEX_BTN_BATCH_OFF
	_btn_close.texture_normal = TEX_BTN_CLOSE

# ========== 滑块样式 ==========

func _setup_slider_style() -> void:
	"""给 HSlider 设置轨道和把手的纹理样式"""
	# 滑块轨道纹理
	var track_style := StyleBoxTexture.new()
	track_style.texture = TEX_SLIDER_TRACK
	_slider_price.add_theme_stylebox_override(&"slider", track_style)
	_slider_price.add_theme_stylebox_override(&"grabber_area", StyleBoxEmpty.new())
	_slider_price.add_theme_stylebox_override(&"grabber_area_highlight", StyleBoxEmpty.new())

	# 滑块把手纹理
	var thumb_style := StyleBoxTexture.new()
	thumb_style.texture = TEX_SLIDER_THUMB
	_slider_price.add_theme_stylebox_override(&"grabber", thumb_style)
	_slider_price.add_theme_stylebox_override(&"grabber_highlight", thumb_style)

# ========== 信号连接 ==========

func _connect_signals() -> void:
	"""连接所有按钮和控件的信号"""
	# 左侧 - 分页按钮
	_btn_page_first.pressed.connect(_on_first_page)
	_btn_page_prev.pressed.connect(_on_prev_page)
	_btn_page_next.pressed.connect(_on_next_page)
	_btn_page_last.pressed.connect(_on_last_page)

	# 右侧 - 价格调整
	_btn_price_minus.pressed.connect(_on_price_minus)
	_btn_price_plus.pressed.connect(_on_price_plus)
	_btn_save_price.pressed.connect(_on_save_price)

	# 底部栏
	_btn_batch_off.pressed.connect(_on_batch_off_shelf)
	_btn_close.pressed.connect(_on_close)

	# 输入框文本改变 + 滑块值改变
	_input_adjust_price.text_changed.connect(_on_price_text_changed)
	_slider_price.value_changed.connect(_on_slider_changed)

	# 点击遮罩关闭弹窗
	_overlay.gui_input.connect(_on_overlay_clicked)

# ========== 公开接口 ==========

func open(shop_ref: Node) -> void:
	"""打开货架管理弹窗并加载数据"""
	_shop_ref = shop_ref
	_refresh_data()
	show()
	_refresh_ui()

func close() -> void:
	"""关闭货架管理弹窗"""
	hide()

func refresh() -> void:
	"""刷新货架数据和UI显示（供外部调用）"""
	_refresh_data()
	_refresh_ui()

func set_window_visible(visible_state: bool) -> void:
	"""设置弹窗的可见状态（兼容旧版调用方式）"""
	visible = visible_state

# ========== 工具函数：创建纹理按钮（用于动态物品行） ==========

func _make_tex_btn(tex: Texture2D, pos: Vector2) -> Button:
	"""创建一个使用图片纹理的扁平 Button（用于物品行动态生成）

	参数:
		tex: 纹理资源
		pos: 位置坐标

	返回:
		配置好的 扁平 Button 实例
	"""
	var btn := Button.new()
	btn.flat = true
	btn.position = pos
	btn.size = tex.get_size()

	# 四个状态都用同一张纹理
	var style := StyleBoxTexture.new()
	style.texture = tex
	btn.add_theme_stylebox_override(&"normal", style)
	btn.add_theme_stylebox_override(&"hover", style)
	btn.add_theme_stylebox_override(&"pressed", style)
	btn.add_theme_stylebox_override(&"disabled", style)
	btn.text = ""
	return btn

# ========== 数据刷新 ==========

func _refresh_data() -> void:
	"""从 ShopManager 读取最新的货架数据"""
	if not _shop_ref:
		return
	_shelf_data = _shop_ref.get_shelf().duplicate()

	# 为新物品创建上架时间戳
	while _shelf_start_time.size() < _shelf_data.size():
		_shelf_start_time.append(Time.get_unix_time_from_system())

	# 计算分页
	_total_pages = max(1, ceil(_shelf_data.size() / float(ITEMS_PER_PAGE)))
	if _current_page >= _total_pages:
		_current_page = max(0, _total_pages - 1)

	# 如果选中的物品已被删除，取消选中
	if _selected_item_index >= _shelf_data.size():
		_selected_item_index = -1

func _refresh_ui() -> void:
	"""刷新所有UI元素的显示"""
	# 更新标题：显示当前上架数量/总容量
	var max_cap = _shop_ref.get_lv_vault() * 10 if _shop_ref else 40
	_label_title.text = "在上架的物品 (%d/%d)" % [_shelf_data.size(), max_cap]

	# 刷新物品列表和页码
	_refresh_item_list()
	_label_page_info.text = "%d/%d" % [max(1, _current_page + 1), _total_pages]

	# 更新或清空右侧详情
	if _selected_item_index >= 0 and _selected_item_index < _shelf_data.size():
		_update_item_detail(_selected_item_index)
	else:
		_clear_item_detail()

func _refresh_item_list() -> void:
	"""清空物品列表容器，重新构建当前页的所有物品行"""
	# 先删除所有旧的物品行
	for child in _vbox_shelf_items.get_children():
		child.queue_free()

	var start_idx = _current_page * ITEMS_PER_PAGE
	var end_idx = min(start_idx + ITEMS_PER_PAGE, _shelf_data.size())

	# 如果货架为空，显示"暂无上架物品"
	if _shelf_data.is_empty() or start_idx >= _shelf_data.size():
		var empty_lbl := Label.new()
		empty_lbl.text = "    暂无上架物品"
		empty_lbl.add_theme_font_size_override("font_size", 15)
		empty_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		empty_lbl.custom_minimum_size = Vector2(0, 60)
		_vbox_shelf_items.add_child(empty_lbl)
		return

	# 遍历当前页的物品，为每个物品创建一行
	for i in range(start_idx, end_idx):
		_vbox_shelf_items.add_child(_build_item_row(_shelf_data[i], i))

# ========== 物品行构建（动态） ==========

func _build_item_row(item: Dictionary, index: int) -> Control:
	"""为单个物品创建一行显示：名称+数量+单价+时间+操作按钮

	参数:
		item: 物品数据字典
		index: 在货架数组中的索引

	返回:
		包含所有子控件的 Control 行节点
	"""
	var row := Control.new()
	row.name = "Row_Item_%d" % index
	row.custom_minimum_size = Vector2(540, 50)

	# 选中高亮条（如果是当前选中行）
	if _selected_item_index == index:
		var bg := ColorRect.new()
		bg.name = "BG_Row"
		bg.color = Color(0.35, 0.25, 0.12, 0.4)
		bg.anchors_preset = Control.PRESET_FULL_RECT
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bg)

	# 物品名称（列宽0~190）
	var nl := Label.new()
	nl.name = "Name_%d" % index
	nl.text = item.get("name", "?")
	nl.add_theme_font_size_override("font_size", 13)
	nl.add_theme_color_override("font_color", COLOR_TEXT)
	nl.position = Vector2(8, 14)
	nl.size = Vector2(180, 24)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nl)

	# 数量（列宽190~240）
	var ql := Label.new()
	ql.name = "Qty_%d" % index
	ql.text = "1"
	ql.add_theme_font_size_override("font_size", 13)
	ql.add_theme_color_override("font_color", COLOR_TEXT)
	ql.position = Vector2(195, 14)
	ql.size = Vector2(45, 24)
	ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ql)

	# 单价（列宽240~336）
	var pl := Label.new()
	pl.name = "Price_%d" % index
	pl.text = _fmt(item.get("price", 0))
	pl.add_theme_font_size_override("font_size", 13)
	pl.add_theme_color_override("font_color", COLOR_GOLD_DIM)
	pl.position = Vector2(245, 14)
	pl.size = Vector2(85, 24)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pl)

	# 上架时间（列宽336~411）
	var tl := Label.new()
	tl.name = "Time_%d" % index
	tl.text = _elapsed(index)
	tl.add_theme_font_size_override("font_size", 11)
	tl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	tl.position = Vector2(340, 14)
	tl.size = Vector2(65, 24)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tl)

	# 「调整价格」按钮（列宽411~470）
	var b_adj := _make_tex_btn(TEX_BTN_ADJUST, Vector2(415, 6))
	b_adj.name = "Btn_Adj_%d" % index
	b_adj.pressed.connect(_on_adjust_price.bind(index))
	row.add_child(b_adj)

	# 「下架」按钮（列宽470~537）
	var b_off := _make_tex_btn(TEX_BTN_OFFSHELF, Vector2(480, 6))
	b_off.name = "Btn_Off_%d" % index
	b_off.pressed.connect(_on_off_shelf.bind(index))
	row.add_child(b_off)

	# 整行的点击选中区域（透明覆盖层）
	var click_area := ColorRect.new()
	click_area.name = "Click_%d" % index
	click_area.color = Color(0.0, 0.0, 0.0, 0.0)
	click_area.anchors_preset = Control.PRESET_FULL_RECT
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.gui_input.connect(_on_row_click.bind(index))
	row.add_child(click_area)

	return row

# ========== 物品详情更新 ==========

func _update_item_detail(index: int) -> void:
	"""更新右侧面板显示选中物品的详细信息"""
	if index < 0 or index >= _shelf_data.size():
		_clear_item_detail()
		return

	var item = _shelf_data[index]
	var price = item.get("price", 0)
	var cost = item.get("value", 0)

	# 基础信息
	_label_item_name.text = item.get("name", "?")
	_label_rarity.text = "普通材料"
	_label_quantity.text = "持有: 1"
	_label_desc.text = "来自%s的%s" % [
		item.get("domain_name", "地下城"),
		item.get("name", "?")
	]

	# 上架信息
	_label_shelf_qty.text = "上架数量: 1"
	_label_unit_price.text = "单价: %s 🪙" % _fmt(price)
	_label_total_price.text = "总价: %s 🪙" % _fmt(price)
	_label_shelf_time.text = "上架: %s" % _elapsed(index)

	# 推荐价格范围（成本的50%~150%）
	var rmin = max(1, int(cost * 0.5))
	var rmax = max(rmin + 50, int(cost * 1.5))
	_label_recommend_price.text = "推荐: %s-%s 🪙" % [_fmt(rmin), _fmt(rmax)]

	# 价格输入框和滑块同步
	_input_adjust_price.text = str(price)
	_slider_price.min_value = max(1, rmin)
	_slider_price.max_value = max(100, rmax)
	_slider_price.value = clamp(price, _slider_price.min_value, _slider_price.max_value)

	# 小贴士
	if price > cost * 1.5:
		_label_tip_text.text = "定价偏高，调低价格可加快出售"
	elif price < cost * 0.5:
		_label_tip_text.text = "定价偏低，可适当提价增加利润"
	else:
		_label_tip_text.text = "定价合理，利润与销量兼顾"

	_icon_item_sprite.modulate = Color(0.8, 0.7, 0.5)

func _clear_item_detail() -> void:
	"""清空右侧详情面板为默认状态"""
	_label_item_name.text = "请选择"
	_label_rarity.text = ""
	_label_quantity.text = ""
	_label_desc.text = ""
	_label_shelf_qty.text = "上架数量: -"
	_label_unit_price.text = "单价: -"
	_label_total_price.text = "总价: -"
	_label_shelf_time.text = "上架: -"
	_label_recommend_price.text = "推荐: -"
	_input_adjust_price.text = ""
	_icon_item_sprite.modulate = Color(0.6, 0.6, 0.6)

# ========== 按钮回调 ==========

func _on_row_click(event: InputEvent, index: int) -> void:
	"""点击物品行 → 选中该物品"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_item_index = index
		_refresh_ui()

func _on_adjust_price(index: int) -> void:
	"""点击行中的「调整价格」按钮 → 选中并显示详情"""
	_selected_item_index = index
	_refresh_ui()

func _on_off_shelf(index: int) -> void:
	"""点击行中的「下架」按钮 → 放回库存并从货架移除"""
	if not _shop_ref or index < 0 or index >= _shelf_data.size():
		return
	var item = _shelf_data[index]
	_shop_ref.add_to_inventory(item.duplicate())
	_shop_ref.remove_from_shelf(index)
	_shop_ref.add_log("📥 已将 %s 下架放回库存" % item.get("name", "?"))
	item_off_shelved.emit(index)
	refresh()

func _on_first_page() -> void:
	"""翻到第一页"""
	_current_page = 0
	_refresh_ui()

func _on_prev_page() -> void:
	"""翻到上一页"""
	if _current_page > 0:
		_current_page -= 1
		_refresh_ui()

func _on_next_page() -> void:
	"""翻到下一页"""
	if _current_page < _total_pages - 1:
		_current_page += 1
		_refresh_ui()

func _on_last_page() -> void:
	"""翻到最后一页"""
	_current_page = max(0, _total_pages - 1)
	_refresh_ui()

func _on_price_text_changed(new_text: String) -> void:
	"""输入框文本变化 → 同步滑块位置"""
	var val = int(new_text)
	if val > 0 and val <= 100000:
		_slider_price.set_block_signals(true)
		_slider_price.value = clamp(val, _slider_price.min_value, _slider_price.max_value)
		_slider_price.set_block_signals(false)

func _on_slider_changed(value: float) -> void:
	"""滑块值变化 → 同步输入框文本"""
	_input_adjust_price.set_block_signals(true)
	_input_adjust_price.text = str(int(value))
	_input_adjust_price.set_block_signals(false)

func _on_price_minus() -> void:
	"""减价按钮 → 输入框数值减1"""
	var val = int(_input_adjust_price.text) if _input_adjust_price.text.is_valid_int() else 0
	if val > 1:
		_input_adjust_price.text = str(val - 1)

func _on_price_plus() -> void:
	"""加价按钮 → 输入框数值加1"""
	var val = int(_input_adjust_price.text) if _input_adjust_price.text.is_valid_int() else 0
	if val < 100000:
		_input_adjust_price.text = str(val + 1)

func _on_save_price() -> void:
	"""保存价格按钮 → 将输入的价格写入货架数据"""
	if not _shop_ref or _selected_item_index < 0 or _selected_item_index >= _shelf_data.size():
		return
	var text = _input_adjust_price.text.strip_edges()
	if not text.is_valid_int() or int(text) <= 0:
		return
	var new_price = int(text)
	var shelf = _shop_ref.get_shelf()
	if _selected_item_index < shelf.size():
		shelf[_selected_item_index]["price"] = new_price
		_shop_ref.add_log("💰 已将 %s 的价格调整为 %d 金" % [
			_shelf_data[_selected_item_index].get("name", "?"), new_price
		])
		price_changed.emit(_selected_item_index, new_price)
		refresh()

func _on_batch_off_shelf() -> void:
	"""批量下架按钮（功能待完善，目前仅记录日志）"""
	if not _shop_ref or _shelf_data.is_empty():
		return
	_shop_ref.add_log("📋 批量下架已触发（待实现选择功能）")
	batch_off_shelved.emit([])

func _on_close() -> void:
	"""关闭按钮 → 隐藏弹窗"""
	hide()

func _on_overlay_clicked(event: InputEvent) -> void:
	"""点击遮罩层 → 关闭弹窗"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide()

# ========== 工具函数 ==========

func _elapsed(index: int) -> String:
	"""获取物品从上次刷新到现在的上架时间文本"""
	if index < 0 or index >= _shelf_start_time.size():
		return "刚刚"
	var e = Time.get_unix_time_from_system() - _shelf_start_time[index]
	if e < 60:
		return "刚刚"
	elif e < 3600:
		return "%d分钟前" % (e / 60)
	elif e < 86400:
		return "%d时%d分" % [e / 3600, (e % 3600) / 60]
	else:
		return "%d天前" % (e / 86400)

func _fmt(v: int) -> String:
	"""千分位格式化数字，例如 12345 → "12,345" """
	if v == 0:
		return "0"
	var s := str(v)
	var r := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		if c > 0 and c % 3 == 0:
			r = "," + r
		r = s[i] + r
		c += 1
	return r
