extends Node3D
## 空间飞行 Demo 主场景。
## 飞船沿机头方向实际飞行；Shift 加速 / Ctrl 减速；撞上小行星则飞船爆炸。
## Esc 由 Pause 自动加载接管（弹出暂停菜单，可返回主菜单 / 退出）。

const MIN_SPEED := 8.0
const MAX_SPEED := 90.0
const BASE_SPEED := 28.0
const ACCEL := 26.0
const SHIP_RADIUS := 1.4

@onready var ship: Node3D = $Ship
@onready var star_field: Node3D = $StarField
@onready var asteroid_field: Node3D = $AsteroidField
@onready var speed_label: Label = $UI/SpeedLabel
@onready var game_over: Control = $UI/GameOver

var _speed := BASE_SPEED
var _dead := false


func _ready() -> void:
	game_over.visible = false
	game_over.get_node("VBox/RetryButton").pressed.connect(_on_retry_pressed)
	game_over.get_node("VBox/MenuButton").pressed.connect(_on_menu_pressed)
	_update_speed_label()


func _process(delta: float) -> void:
	if _dead:
		return

	# 加速 / 减速
	if Input.is_key_pressed(KEY_SHIFT):
		_speed = min(_speed + ACCEL * delta, MAX_SPEED)
	if Input.is_key_pressed(KEY_CTRL):
		_speed = max(_speed - ACCEL * delta, MIN_SPEED)

	# 沿机头方向实际移动飞船
	var fwd := -ship.global_transform.basis.z
	ship.global_transform.origin += fwd * _speed * delta

	# 让星空 / 小行星围绕飞船流动
	star_field.update(ship.global_transform, delta)
	asteroid_field.update(ship.global_transform, delta)

	# 碰撞检测
	if asteroid_field.collides(ship.global_transform.origin, SHIP_RADIUS):
		_explode()
		return

	_update_speed_label()


func _update_speed_label() -> void:
	speed_label.text = "速度: %d" % _speed


func _explode() -> void:
	_dead = true
	ship.die()
	_spawn_explosion(ship.global_transform.origin)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_over.visible = true


func _spawn_explosion(at: Vector3) -> void:
	var flash := MeshInstance3D.new()
	flash.mesh = SphereMesh.new()
	flash.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 4.0
	flash.material_override = mat
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector3(7, 7, 7), 0.6)
	tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.6)
	tw.tween_callback(flash.queue_free)

	for i in 14:
		var d := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 0.4, 0.4)
		d.mesh = bm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0, 0, 0)
		dm.emission_enabled = true
		dm.emission = Color(1.0, 0.5, 0.1)
		dm.emission_energy_multiplier = 3.0
		d.material_override = dm
		d.position = at
		add_child(d)
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var spd := randf_range(6.0, 16.0)
		var tw2 := create_tween()
		tw2.tween_property(d, "position", at + dir * spd, randf_range(0.8, 1.3))
		tw2.parallel().tween_property(dm, "emission_energy_multiplier", 0.0, 1.0)
		tw2.tween_callback(d.queue_free)


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://app/main.tscn")
