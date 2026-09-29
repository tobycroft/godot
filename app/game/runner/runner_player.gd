class_name RunnerPlayer
extends Node3D
## 跑酷玩家：左右切换跑道、跳跃，并由 AnimationPlayer 播放程序化跑步动画。

const LANE_X: Array[float] = [-2.2, 0.0, 2.2]
const LANE_SWITCH_SPEED := 12.0
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
## 跑步动画单步周期（秒），循环播放
const RUN_STEP_TIME := 0.28

@onready var model: Node3D = $Model
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _lane := 1
var _velocity_y := 0.0
var _running := false

func _ready() -> void:
	model.rotation.y = PI  # 朝向前进方向（-Z）；若角色背向前进，改回 0.0
	anim_player.root_node = NodePath("..")  # 以 Player 为根，动画轨道路径 "Model:..." 才能命中
	_build_run_animation()

func start_run() -> void:
	_running = true
	anim_player.play("run")

func stop_run() -> void:
	_running = false
	anim_player.stop()
	model.position = Vector3.ZERO
	model.rotation = Vector3(-0.16, PI, 0.0)

func set_run_pace(speed: float) -> void:
	## 游戏速度越快，跑步动画播放越快，动作更带感
	if anim_player.is_playing():
		anim_player.speed_scale = clampf(speed / 20.0, 0.6, 6.0)

func _build_run_animation() -> void:
	## 模型为单一网格、无骨骼，用整体弹跳 + 前倾 + 左右摆动模拟跑步循环
	if anim_player.has_animation("run"):
		return
	var anim := Animation.new()
	anim.resource_name = "run"
	anim.length = RUN_STEP_TIME
	anim.loop_mode = Animation.LOOP_MODE_LINEAR

	var pos_idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos_idx, "Model:position")
	anim.track_set_interpolation_type(pos_idx, Animation.INTERPOLATION_LINEAR)
	anim.track_insert_key(pos_idx, 0.0, Vector3(0.0, 0.0, 0.0))
	anim.track_insert_key(pos_idx, RUN_STEP_TIME * 0.25, Vector3(0.0, 0.14, 0.0))
	anim.track_insert_key(pos_idx, RUN_STEP_TIME * 0.5, Vector3(0.0, 0.0, 0.0))
	anim.track_insert_key(pos_idx, RUN_STEP_TIME * 0.75, Vector3(0.0, 0.14, 0.0))
	anim.track_insert_key(pos_idx, RUN_STEP_TIME, Vector3(0.0, 0.0, 0.0))

	var rot_idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot_idx, "Model:rotation")
	anim.track_set_interpolation_type(rot_idx, Animation.INTERPOLATION_LINEAR)
	anim.track_insert_key(rot_idx, 0.0, Vector3(-0.16, PI, 0.0))
	anim.track_insert_key(rot_idx, RUN_STEP_TIME * 0.25, Vector3(-0.16, PI, 0.07))
	anim.track_insert_key(rot_idx, RUN_STEP_TIME * 0.5, Vector3(-0.13, PI, 0.0))
	anim.track_insert_key(rot_idx, RUN_STEP_TIME * 0.75, Vector3(-0.16, PI, -0.07))
	anim.track_insert_key(rot_idx, RUN_STEP_TIME, Vector3(-0.16, PI, 0.0))

	anim_player.add_animation("run", anim)

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

	# 跑步动作（弹跳/前倾/摆动）由 AnimationPlayer 播放 "run" 动画驱动
