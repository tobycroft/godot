extends Node3D
## 空间飞行 Demo 主场景。
## 飞船沿机头方向实际飞行；Shift 加速 / Ctrl 减速；撞上小行星则飞船爆炸。
## Esc 由 Pause 自动加载接管（弹出暂停菜单，可返回主菜单 / 退出）。

const SHIP_RADIUS := 1.4

@onready var ship: Node3D = $Ship
@onready var star_field: Node3D = $StarField
@onready var asteroid_field: Node3D = $AsteroidField
@onready var speed_label: Label = $UI/SpeedLabel
@onready var game_over: Control = $UI/GameOver

var _dead := false


func _ready() -> void:
	game_over.visible = false
	game_over.get_node("VBox/RetryButton").pressed.connect(_on_retry_pressed)
	game_over.get_node("VBox/MenuButton").pressed.connect(_on_menu_pressed)
	_update_speed_label()


func _process(delta: float) -> void:
	if _dead:
		return

	# 飞船自身负责带惯性的推进与转向，这里只跟随其位姿刷新环境
	var t := ship.global_transform

	# 让星空 / 小行星围绕飞船流动
	star_field.update(t, delta)
	asteroid_field.update(t, delta)

	# 碰撞检测
	if asteroid_field.collides(t.origin, SHIP_RADIUS):
		_explode()
		return

	_update_speed_label()


func _update_speed_label() -> void:
	speed_label.text = "速度: %d" % ship.get_speed()


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
