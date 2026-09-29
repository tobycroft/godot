extends Node3D
## 跑酷游戏：沿马路自动前进，收集金币、躲避障碍，计分。

const COIN_VALUE := 10
const START_SPEED := 8.0
const MAX_SPEED := 20.0
const SPEED_GROWTH := 0.2
const SPAWN_FAR := -130.0
const RECYCLE_Z := 7.0
const LANE_X: Array[float] = [-2.2, 0.0, 2.2]

@onready var player: RunnerPlayer = $Player
@onready var track: Node3D = $Track
@onready var score_label: Label = $UI/ScoreLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_label: Label = $UI/GameOverPanel/VBox/FinalLabel

var _speed := START_SPEED
var _distance := 0.0
var _coins := 0
var _score := 0
var _running := false
var _items := []

func _ready() -> void:
	randomize()
	for i in range(16):
		spawn_item(SPAWN_FAR + i * 8.0)
	player.start_run()
	_running = true
	score_label.text = "分数: 0"
	game_over_panel.visible = false
	_connect_ui()

func _connect_ui() -> void:
	$UI/GameOverPanel/VBox/RetryButton.pressed.connect(_on_retry_pressed)
	$UI/GameOverPanel/VBox/MenuButton.pressed.connect(_on_menu_pressed)

func _physics_process(delta: float) -> void:
	if not _running:
		return
	_speed = minf(_speed + SPEED_GROWTH * delta, MAX_SPEED)
	_distance += _speed * delta

	for it in _items:
		var n := it.node as Node3D
		n.position.z += _speed * delta
		if n.position.z > RECYCLE_Z:
			recycle(it)

	_check_interactions()
	_score = int(_distance) + _coins * COIN_VALUE
	score_label.text = "分数: %d   速度: %.0f" % [_score, _speed]

func _check_interactions() -> void:
	for it in _items.duplicate():
		var n := it.node as Node3D
		if n.position.z < -1.0 or n.position.z > 1.0:
			continue
		if absf(n.position.x - player.position.x) > 0.9:
			continue
		if it.type == "coin":
			if not it.collected:
				it.collected = true
				_coins += 1
				n.queue_free()
				_items.erase(it)
		else:  # 障碍：未跳起则撞上
			if player.position.y < 0.7:
				game_over()
				return

func spawn_item(z: float) -> void:
	var is_obstacle := randf() < 0.4
	var lane := randi_range(0, 2)
	var x := LANE_X[lane]
	var n := MeshInstance3D.new()
	if is_obstacle:
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 0.7, 1.2)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.3, 0.2, 1.0)
		n.mesh = box
		n.material_override = mat
		n.position = Vector3(x, 0.35, z)
		track.add_child(n)
		_items.append({type = "obstacle", node = n, collected = false})
	else:
		var sph := SphereMesh.new()
		sph.radius = 0.35
		sph.height = 0.7
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.2, 1.0)
		mat.emission = Color(0.4, 0.3, 0.0, 1.0)
		n.mesh = sph
		n.material_override = mat
		n.position = Vector3(x, 0.8, z)
		track.add_child(n)
		_items.append({type = "coin", node = n, collected = false})

func recycle(it: Dictionary) -> void:
	var lane := randi_range(0, 2)
	it.node.position = Vector3(LANE_X[lane], it.node.position.y, SPAWN_FAR)

func game_over() -> void:
	_running = false
	player.stop_run()
	final_label.text = "本局分数: %d" % _score
	game_over_panel.visible = true

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://app/main/main.tscn")
