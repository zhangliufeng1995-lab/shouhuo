extends CanvasLayer
## 怪物袭击弹窗控制器
## 管理怪物袭击事件的显示和应对选项

@onready var _overlay: ColorRect = $Overlay
@onready var _popup_panel: Panel = $PopupPanel
@onready var _info_label: Label = $PopupPanel/VBox/InfoLabel
@onready var _option_btn_1: Button = $PopupPanel/VBox/ButtonHB/OptionBtn1
@onready var _option_btn_2: Button = $PopupPanel/VBox/ButtonHB/OptionBtn2


func _ready() -> void:
	"""初始化：连接按钮信号，默认隐藏"""
	_option_btn_1.pressed.connect(_on_option_1_pressed)
	_option_btn_2.pressed.connect(_on_option_2_pressed)
	hide()


## 显示怪物袭击弹窗
## @param monster_name: 怪物名称
func show_popup(monster_name: String) -> void:
	"""显示怪物袭击弹窗"""
	_info_label.text = "⚠ 一只 [color=red]%s[/color] 正在袭击你的商店！" % monster_name
	_option_btn_1.text = "🛡 请守卫（消耗金币）"
	_option_btn_2.text = "⚔ 亲自应对"
	show()


## 隐藏弹窗
func hide_popup() -> void:
	"""隐藏怪物袭击弹窗"""
	hide()


## 选项1：请守卫
func _on_option_1_pressed() -> void:
	"""请守卫应对怪物，预留业务逻辑接口"""
	# TODO: 扣除金币，守卫成功/失败判定
	hide_popup()


## 选项2：亲自应对
func _on_option_2_pressed() -> void:
	"""亲自应对怪物，预留业务逻辑接口"""
	# TODO: 战斗成功率判定
	hide_popup()
