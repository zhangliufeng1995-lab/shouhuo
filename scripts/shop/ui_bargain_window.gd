extends CanvasLayer
## 讨价还价弹窗控制器
## 管理弹窗的显示/隐藏，价格调整输入

@onready var _overlay: ColorRect = $Overlay
@onready var _popup_panel: Panel = $PopupPanel
@onready var _info_label: Label = $PopupPanel/VBox/InfoLabel
@onready var _price_input: LineEdit = $PopupPanel/VBox/PriceInput
@onready var _confirm_btn: Button = $PopupPanel/VBox/ButtonHB/ConfirmBtn
@onready var _cancel_btn: Button = $PopupPanel/VBox/ButtonHB/CancelBtn


func _ready() -> void:
	"""初始化：连接按钮信号，默认隐藏"""
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	hide()


## 显示讨价还价弹窗
## @param asking_price: 冒险者的要价
func show_popup(asking_price: int) -> void:
	"""显示讨价还价弹窗，设置要价信息"""
	_info_label.text = "冒险者要价：%d 金币" % asking_price
	_price_input.text = ""
	show()


## 隐藏弹窗
func hide_popup() -> void:
	"""隐藏讨价还价弹窗"""
	hide()


## 确认按钮点击
func _on_confirm_pressed() -> void:
	"""确认出价，预留业务逻辑接口"""
	# var offer = int(_price_input.text)
	# 后续业务逻辑：判断出价是否被接受
	hide_popup()


## 取消按钮点击
func _on_cancel_pressed() -> void:
	"""取消出价，关闭弹窗"""
	hide_popup()
