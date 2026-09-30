extends Node3D
## 跑酷游戏：100 秒倒计时，收集黄球积分，躲避红色障碍。
## 黄球被收集或物件滚出屏幕后都会在远处重生为新的随机物件，黄球持续出现；
## 结束后以收集到的黄球数量作为积分展示。

const GAME_TIME := 100.0
const START_SPEED := 20.0
const SPEED_GROWTH := 0.2
const SPAWN_FAR := -130.0
const SPAWN_SPREAD := 40.0
const RECYCLE_Z := 7.0
const ITEM_COUNT := 16
const HIT_Z := 1.0
const LANE_X: Array[float] = [-2.2, 0.0, 2.2]

@onready var player: RunnerPlayer = $Player
@onready var track: Node3D = $Track
@onready var score_label: Label = $UI/ScoreLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_label: Label = $UI/GameOverPanel/VBox/FinalLabel

var _speed := START_SPEED
var _time_left := GAME_TIME
var _coins := 0
var _running := false
var _items: Array[Dictionary] = []
var _coin_mesh: SphereMesh
var _coin_mat: StandardMaterial3D
var _obstacle_mesh: BoxMesh
var _obstacle_mat: StandardMaterial3D


func _ready() -> void:
	randomize()
	_make_res()
	for i in ITEM_COUNT:
		_spawn_item(SPAWN_FAR + i * 8.0)
	player.start_run()
	_running = true
	game_over_panel.visible = false
	_connect_ui()
	_update_hud()


func _connect_ui() -> void:
	$UI/GameOverPanel/VBox/RetryButton.pressed.connect(_on_retry_pressed)
	$UI/GameOverPanel/VBox/MenuButton.pressed.connect(_on_menu_pressed)


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_speed = _speed + SPEED_GROWTH * delta
	player.set_run_pace(_speed)

	# 倒计时，归零即结束
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_update_hud()
		game_over(true)
		return

	var moved := _speed * delta
	for it in _items:
		var n := it.node as Node3D
		n.position.z += moved
		if n.position.z > RECYCLE_Z:
			_respawn(it, SPAWN_FAR - randf() * SPAWN_SPREAD)

	_check_interactions(moved)
	_update_hud()


func _check_interactions(moved: float) -> void:
	for it in _items:
		var n := it.node as Node3D
		# 扫掠判定：物件本帧从 z-moved 移动到 z，与玩家窗口 [-1,1] 相交即判定
		if n.position.z < -HIT_Z or n.position.z - moved > HIT_Z:
			continue
		if absf(n.position.x - player.position.x) > 0.9:
			continue
		if it.type == "coin":
			_coins += 1
			_respawn(it, SPAWN_FAR - randf() * SPAWN_SPREAD) # 立刻重生，黄球不断
		else:  # 障碍：未跳起则撞上
			if player.position.y < 0.7:
				game_over(false)
				return


func _make_res() -> void:
	_coin_mesh = SphereMesh.new()
	_coin_mesh.radius = 0.35
	_coin_mesh.height = 0.7
	_coin_mat = StandardMaterial3D.new()
	_coin_mat.albedo_color = Color(1.0, 0.85, 0.2, 1.0)
	_coin_mat.emission = Color(0.4, 0.3, 0.0, 1.0)
	_coin_mat.emission_energy_multiplier = 1.2
	_obstacle_mesh = BoxMesh.new()
	_obstacle_mesh.size = Vector3(1.2, 0.7, 1.2)
	_obstacle_mat = StandardMaterial3D.new()
	_obstacle_mat.albedo_color = Color(0.85, 0.3, 0.2, 1.0)


func _spawn_item(z: float) -> void:
	var n := MeshInstance3D.new()
	track.add_child(n)
	var it := {node = n, type = ""}
	_items.append(it)
	_respawn(it, z)


## 在远处重生为随机物件（黄球或障碍），保持场上物件总数不变
func _respawn(it: Dictionary, z: float) -> void:
	var n: MeshInstance3D = it.node
	if randf() < 0.4:
		it.type = "obstacle"
		n.mesh = _obstacle_mesh
		n.material_override = _obstacle_mat
		n.position = Vector3(LANE_X[randi_range(0, 2)], 0.35, z)
	else:
		it.type = "coin"
		n.mesh = _coin_mesh
		n.material_override = _coin_mat
		n.position = Vector3(LANE_X[randi_range(0, 2)], 0.8, z)


func _update_hud() -> void:
	score_label.text = "黄球: %d   时间: %d s" % [_coins, ceili(_time_left)]


func game_over(time_up: bool) -> void:
	_running = false
	player.stop_run()
	final_label.text = ("时间到！" if time_up else "撞到障碍！") + "收集黄球: %d" % _coins
	game_over_panel.visible = true


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://app/main.tscn")
