class_name RunnerPlayer
extends Node3D
## 跑酷玩家：左右切换跑道、跳跃、跑步晃动。

const LANE_X: Array[float] = [-2.2, 0.0, 2.2]
const LANE_SWITCH_SPEED := 12.0
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0

@onready var model: Node3D = $Model

var _lane := 1
var _velocity_y := 0.0
var _running := false
var _bob_t := 0.0

func _ready() -> void:
	model.rotation.y = PI  # 朝向前进方向（-Z）；若角色背向前进，改回 0.0

func start_run() -> void:
	_running = true

func stop_run() -> void:
	_running = false

func is_on_ground() -> bool:
	return position.y <= 0.001

func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event.is_action_pressed("move_left") and event.pressed and not event.echo:
		_lane = maxi(_lane - 1, 0)
	elif event.is_action_pressed("move_right") and event.pressed and not event.echo:
		_lane = mini(_lane + 1, LANE_X.size() - 1)
	elif event.is_action_pressed("jump") and event.pressed and not event.echo and is_on_ground():
		_velocity_y = JUMP_VELOCITY

func _physics_process(delta: float) -> void:
	position.x = move_toward(position.x, LANE_X[_lane], LANE_SWITCH_SPEED * delta)

	if not is_on_ground() or _velocity_y > 0.0:
		_velocity_y -= GRAVITY * delta
		position.y += _velocity_y * delta
		if position.y <= 0.0:
			position.y = 0.0
			_velocity_y = 0.0

	if _running:
		_bob_t += delta * 12.0
		model.position.y = absf(sin(_bob_t)) * 0.08
		model.rotation.x = -0.12  # 前倾，跑步姿态
