extends Node2D
## 冒险者角色控制器
## 第三人称身后视角，冒险者从店铺深处（画面上方/门）走向柜台（画面下方）
## 纵向移动 + 近大远小缩放：门口时0.7倍 → 柜台前时1.0倍

signal arrived_at_counter()  # 到达柜台后的信号
signal left_shop()           # 离开商店的信号

# 颜色
const SKIN_COLOR := Color(0.95, 0.8, 0.6)
const SHIRT_COLOR := Color(0.4, 0.25, 0.1)
const PANTS_COLOR := Color(0.25, 0.15, 0.05)
const BOOTS_COLOR := Color(0.2, 0.1, 0.05)
const HAIR_COLOR := Color(0.3, 0.2, 0.1)
const CAPE_COLOR := Color(0.5, 0.15, 0.1)

# 位置（纵深布局：门在画面上方/深处，柜台在画面下方/近端）
var _door_y := 155.0       # 门口Y坐标（纵深最远处，门下方）
var _counter_y := 520.0    # 柜台前Y坐标（近端，冒险者走到这里停下）
var _center_x := 400.0     # 角色在过道中间行走的X坐标

# 近大远小缩放范围
const SCALE_FAR := 0.7     # 门口时（最远处）的缩放
const SCALE_NEAR := 1.0    # 柜台前（最近处）的缩放

var _character_body: Node2D
var _tween: Tween
var _is_moving := false

## 创建角色
func build_character(parent: Node) -> void:
	_character_body = Node2D.new()
	_character_body.name = "AdventurerCharacter"
	# 初始位置在门口，缩放为远处尺寸
	_character_body.position = Vector2(_center_x, _door_y)
	_character_body.scale = Vector2(SCALE_FAR, SCALE_FAR)
	parent.add_child(_character_body)
	
	# ===== 用ColorRect拼出角色（基础尺寸，通过scale控制大小） =====
	
	# 披风（背后）
	_make_part(_character_body, CAPE_COLOR, -15, -60, 30, 55)
	
	# 身体（躯干）
	_make_part(_character_body, SHIRT_COLOR, -12, -40, 24, 30)
	
	# 头
	_make_part(_character_body, SKIN_COLOR, -10, -60, 20, 20)
	
	# 头发
	_make_part(_character_body, HAIR_COLOR, -12, -65, 24, 8)
	
	# 眼睛（两个小白点）
	_make_part(_character_body, Color(1, 1, 1), -6, -55, 5, 4)
	_make_part(_character_body, Color(1, 1, 1), 1, -55, 5, 4)
	# 瞳孔
	_make_part(_character_body, Color(0, 0, 0), -4, -54, 3, 3)
	_make_part(_character_body, Color(0, 0, 0), 3, -54, 3, 3)
	
	# 腿
	_make_part(_character_body, PANTS_COLOR, -10, -10, 8, 10)
	_make_part(_character_body, PANTS_COLOR, 2, -10, 8, 10)
	
	# 靴子
	_make_part(_character_body, BOOTS_COLOR, -11, 0, 10, 5)
	_make_part(_character_body, BOOTS_COLOR, 1, 0, 10, 5)
	
	# 左臂
	var arm = _make_part(_character_body, SHIRT_COLOR, -20, -35, 8, 20, false)
	arm.rotation_degrees = -15
	
	# 右臂
	arm = _make_part(_character_body, SHIRT_COLOR, 12, -35, 8, 20, false)
	arm.rotation_degrees = 15
	
	# 初始隐藏（等到触发时才显示）
	_character_body.visible = false

## 让角色从门口（深处/画面上方）走到柜台（画面下方）
## 纵向移动 + 同步缩放：从0.7倍逐渐变为1.0倍
## speed: 移动速度（像素/秒），默认120
func walk_to_counter(speed: float = 120.0) -> void:
	if _is_moving or _character_body == null:
		return
	
	_is_moving = true
	_character_body.visible = true
	# 重置位置和缩放
	_character_body.position = Vector2(_center_x, _door_y)
	_character_body.scale = Vector2(SCALE_FAR, SCALE_FAR)
	
	# 创建Tween并行执行移动和缩放
	_tween = create_tween().set_parallel(true)
	var distance = abs(_counter_y - _door_y)
	var duration = distance / speed
	
	# ① Y轴纵向移动：从门口走到柜台
	_tween.tween_property(_character_body, "position:y", _counter_y, duration).set_ease(Tween.EASE_IN_OUT)
	
	# ② 同步缩放：从0.7倍渐变为1.0倍（近大远小）
	_tween.tween_property(_character_body, "scale", Vector2(SCALE_NEAR, SCALE_NEAR), duration).set_ease(Tween.EASE_IN_OUT)
	
	await _tween.finished
	
	_is_moving = false
	arrived_at_counter.emit()

## 让角色转身离开，走回门口（深处）
## 纵向移动 + 同步缩放：从1.0倍逐渐变为0.7倍
func walk_to_door(speed: float = 150.0) -> void:
	if _is_moving or _character_body == null:
		return
	
	_is_moving = true
	
	# 创建Tween并行执行移动和缩放
	_tween = create_tween().set_parallel(true)
	var distance = abs(_counter_y - _door_y)
	var duration = distance / speed
	
	# ① Y轴纵向移动：从柜台走回门口
	_tween.tween_property(_character_body, "position:y", _door_y, duration).set_ease(Tween.EASE_IN_OUT)
	
	# ② 同步缩放：从1.0倍渐变为0.7倍
	_tween.tween_property(_character_body, "scale", Vector2(SCALE_FAR, SCALE_FAR), duration).set_ease(Tween.EASE_IN_OUT)
	
	await _tween.finished
	
	_character_body.visible = false
	_is_moving = false
	left_shop.emit()

## 设置角色的衣服颜色（根据冒险者性格）
func set_color_by_personality(pers: String) -> void:
	var shirt_color := SHIRT_COLOR
	match pers:
		"急躁": shirt_color = Color(0.8, 0.2, 0.1)   # 红色
		"普通": shirt_color = Color(0.4, 0.25, 0.1)    # 棕色
		"耐心": shirt_color = Color(0.2, 0.4, 0.6)     # 蓝色
		"狡猾": shirt_color = Color(0.2, 0.6, 0.2)     # 绿色
		"豪爽": shirt_color = Color(0.7, 0.5, 0.1)     # 金色
	
	# 找到身体部分重新着色（高度在25~35之间的ColorRect是身体）
	for child in _character_body.get_children():
		if child is ColorRect and child.size.y > 25 and child.size.y < 35:
			child.color = shirt_color
			break

## 辅助：创建角色部件
func _make_part(parent: Node, color: Color, x: float, y: float, w: float, h: float, center: bool = true) -> ColorRect:
	var rect = ColorRect.new()
	rect.color = color
	rect.position = Vector2(x, y)
	rect.size = Vector2i(int(w), int(h))
	parent.add_child(rect)
	return rect
