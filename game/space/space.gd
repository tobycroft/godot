extends Node3D
## 空间飞行 Demo 主场景。
## 飞船沿机头方向实际飞行；Shift 加速 / Ctrl 减速；撞上小行星按体积扣血，
## 护甲先承伤，血量归零则飞船爆炸。左下角 HUD 显示血条与护甲。
## Esc 由 Pause 自动加载接管（弹出暂停菜单，可返回主菜单 / 退出）。

const SHIP_RADIUS := 1.6 # 与放大后的机体（含机翼）尺寸匹配
const MAX_HP := 100.0
const INVULN_TIME := 0.9 # 受击后的短暂无敌，避免一次撞击连续扣血
const HP_BAR_W := 300.0
const ARMOR_BAR_W := 240.0

@onready var ship: Ship = $Ship
@onready var star_field: StarField = $StarField
@onready var asteroid_field: AsteroidField = $AsteroidField
@onready var weapons: Weapons = $Weapons
@onready var speed_label: Label = $UI/SpeedLabel
@onready var game_over: Control = $UI/GameOver
@onready var hp_fill: ColorRect = $UI/HUD/HPFill
@onready var armor_fill: ColorRect = $UI/HUD/ArmorFill
@onready var hp_text: Label = $UI/HUD/HPText
@onready var armor_text: Label = $UI/HUD/ArmorText
@onready var hit_flash: ColorRect = $UI/HitFlash

var hp := MAX_HP
var armor := 0.0 # 默认无护甲；护甲先于血量承伤

var _dead := false
var _invuln := 0.0


func _ready() -> void:
	game_over.visible = false
	game_over.get_node("VBox/RetryButton").pressed.connect(_on_retry_pressed)
	game_over.get_node("VBox/MenuButton").pressed.connect(_on_menu_pressed)
	_update_speed_label()
	_update_hud()


func _process(delta: float) -> void:
	if _dead:
		return

	# 飞船自身负责带惯性的推进与转向，这里只跟随其位姿刷新环境
	var t := ship.global_transform

	# 让星空 / 小行星围绕飞船流动
	star_field.update(t, delta)
	asteroid_field.update(t, delta)

	# 碰撞检测：命中则扣血（护甲先承伤）
	_invuln = maxf(_invuln - delta, 0.0)
	var hit := asteroid_field.hit_test(t.origin, SHIP_RADIUS)
	if hit != null and _invuln <= 0.0:
		_take_damage(hit, t)
		if _dead:
			return

	_update_speed_label()


func _update_speed_label() -> void:
	speed_label.text = "速度: %d" % ship.get_speed()


## 受击：小行星越大伤害越高，护甲先扛，护甲耗尽后扣血。
func _take_damage(hit: Asteroid, t: Transform3D) -> void:
	var dmg := clampf(roundf(hit.scale.x * 10.0), 15.0, 45.0)
	_invuln = INVULN_TIME

	var absorbed := minf(armor, dmg)
	armor -= absorbed
	dmg -= absorbed
	hp = maxf(hp - dmg, 0.0)

	var at: Vector3 = hit.position
	asteroid_field.recycle(hit)
	Explosion.spawn(self, at, 0.5)
	_flash_hit()
	_update_hud()

	if hp <= 0.0:
		_explode()


func _flash_hit() -> void:
	hit_flash.color.a = 0.32
	var tw := create_tween()
	tw.tween_property(hit_flash, "color:a", 0.0, 0.45)


func _update_hud() -> void:
	var ratio := clampf(hp / MAX_HP, 0.0, 1.0)
	hp_fill.size.x = maxf(HP_BAR_W * ratio, 0.0)
	hp_fill.color = Color(1.0 - ratio * 0.55, 0.24 + ratio * 0.62, 0.22, 1.0)
	hp_text.text = "血量  %d / %d" % [roundi(hp), roundi(MAX_HP)]
	armor_fill.size.x = maxf(ARMOR_BAR_W * clampf(armor / MAX_HP, 0.0, 1.0), 0.0)
	armor_text.text = "护甲  %d" % roundi(armor)


func _explode() -> void:
	_dead = true
	ship.die()
	weapons.set_disabled(true) # 撞毁后停火（已在飞的弹药让它飞完）
	Explosion.spawn(self, ship.global_transform.origin, 1.8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_game_over()


## 撞毁后弹出的结算面板：暗化 + 由小到大弹入，而不是瞬间出现。
func _show_game_over() -> void:
	game_over.visible = true
	var dim := game_over.get_node("Dim") as CanvasItem
	var vbox := game_over.get_node("VBox") as Control
	dim.modulate = Color(1, 1, 1, 0)
	vbox.pivot_offset = vbox.size * 0.5
	vbox.scale = Vector2(0.85, 0.85)
	vbox.modulate = Color(1, 1, 1, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "modulate", Color(1, 1, 1, 1), 0.4)
	tw.tween_property(vbox, "modulate", Color(1, 1, 1, 1), 0.45).set_delay(0.05)
	tw.tween_property(vbox, "scale", Vector2(1.0, 1.0), 0.5).set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://app/main.tscn")
