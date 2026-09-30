class_name Ship
extends Node3D
## 宇宙飞船控制器（含模型）——战斗机式操控。
## · A / D：沿机身纵轴滚转（按住就一直滚，松手保持当前坡度，不会改变航向）
## · W / S：俯仰（S 拉杆抬头、W 推杆低头），绕机体横轴，所以滚转后拉杆就是转弯
## · Q / E 与鼠标左右：偏航（方向舵 / 视线平移），绕机体竖轴
## · 鼠标上下：俯仰
## 因此"左转"= 先按 A 压左坡度，再按 S 拉杆，像真机一样把升力矢量压向左侧。
## 相机挂在机体下、没有自身旋转，滚转时是整幅画面随机体一起转，机翼始终平行画面水平线。
## Shift 加大油门 / Ctrl 减小油门；撞毁时由 die() 停摆并隐藏机体。

const MAX_THRUST := 90.0
const DRAG := 1.6
const LATERAL_DRAG := 1.3
const MIN_THROTTLE := 0.15
const MAX_THROTTLE := 1.0
const THROTTLE_RATE := 0.6
const MAX_SPEED := 60.0

const ROLL_RATE := 2.6      # rad/s，按住 A / D 的滚转角速度（约 150°/s）
const ROLL_ACCEL := 9.0     # 滚转的加减速，比俯仰 / 偏航更利落
const PITCH_RATE := 1.2     # W / S 俯仰角速度
const YAW_RATE := 1.0       # Q / E 方向舵角速度
const MOUSE_YAW_RATE := 1.6 # 鼠标左右 -> 偏航
const MOUSE_PITCH_RATE := 1.2
const ANG_ACCEL := 3.0      # 俯仰 / 偏航的加减速（有惯性，不是瞬间到位）
const MOUSE_GAIN := 0.006
const MOUSE_DECAY := 2.5

const CAM_BASE_Z := 7.6
const CAM_MAX_Z := 9.8
const FOV_BASE := 70.0
const FOV_MAX := 84.0

@onready var visual: ShipModel = $Visual
@onready var camera: Camera3D = $Camera3D

var _velocity := Vector3.ZERO
var _throttle := 0.45
var _roll_rate := 0.0
var _pitch_rate := 0.0
var _yaw_rate := 0.0
var _mouse_yaw := 0.0
var _mouse_pitch := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_velocity = -global_transform.basis.z * 24.0


func get_speed() -> float:
	return _velocity.length()


## 弹药初速要叠加飞船速度，所以对外暴露当前速度矢量。
func get_velocity() -> Vector3:
	return _velocity


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_yaw = clampf(_mouse_yaw - event.relative.x * MOUSE_GAIN, -1.0, 1.0)
		_mouse_pitch = clampf(_mouse_pitch - event.relative.y * MOUSE_GAIN, -1.0, 1.0)


func _process(delta: float) -> void:
	# 鼠标杆量自然回中
	_mouse_yaw = move_toward(_mouse_yaw, 0.0, MOUSE_DECAY * delta)
	_mouse_pitch = move_toward(_mouse_pitch, 0.0, MOUSE_DECAY * delta)

	# 油门：Shift 加速 / Ctrl 减速
	if Input.is_key_pressed(KEY_SHIFT):
		_throttle = min(_throttle + THROTTLE_RATE * delta, MAX_THROTTLE)
	if Input.is_key_pressed(KEY_CTRL):
		_throttle = max(_throttle - THROTTLE_RATE * delta, MIN_THROTTLE)

	# 操纵面：A/D 滚转、W/S 俯仰、Q/E 方向舵、鼠标偏航 + 俯仰
	var stick_roll := 0.0
	var stick_pitch := 0.0
	var stick_yaw := 0.0
	if Input.is_action_pressed("roll_left"):
		stick_roll += 1.0
	if Input.is_action_pressed("roll_right"):
		stick_roll -= 1.0
	if Input.is_action_pressed("pitch_up"):
		stick_pitch += 1.0
	if Input.is_action_pressed("pitch_down"):
		stick_pitch -= 1.0
	if Input.is_action_pressed("yaw_left"):
		stick_yaw += 1.0
	if Input.is_action_pressed("yaw_right"):
		stick_yaw -= 1.0

	var want_roll := clampf(stick_roll, -1.0, 1.0) * ROLL_RATE
	var want_pitch := clampf(stick_pitch, -1.0, 1.0) * PITCH_RATE \
		+ clampf(_mouse_pitch, -1.0, 1.0) * MOUSE_PITCH_RATE
	var want_yaw := clampf(stick_yaw, -1.0, 1.0) * YAW_RATE \
		+ clampf(_mouse_yaw, -1.0, 1.0) * MOUSE_YAW_RATE
	_roll_rate = move_toward(_roll_rate, want_roll, ROLL_ACCEL * delta)
	_pitch_rate = move_toward(_pitch_rate, want_pitch, ANG_ACCEL * delta)
	_yaw_rate = move_toward(_yaw_rate, want_yaw, ANG_ACCEL * delta)

	# 全部绕机体自身三轴：先滚转、再拉杆，就能像真机一样把机头拉向坡度内侧
	rotate_object_local(Vector3.BACK, _roll_rate * delta)   # 滚转 A / D
	rotate_object_local(Vector3.RIGHT, _pitch_rate * delta) # 俯仰 W / S
	rotate_object_local(Vector3.UP, _yaw_rate * delta)      # 偏航 Q / E、鼠标

	visual.set_thrust(_throttle)

	# 推进与阻力：转弯时保留侧向惯性，产生漂移感
	var fwd := -global_transform.basis.z
	_velocity += fwd * (_throttle * MAX_THRUST) * delta
	_velocity -= _velocity * DRAG * delta
	var along := fwd * _velocity.dot(fwd)
	var lateral := _velocity - along
	_velocity = along + lateral * max(1.0 - LATERAL_DRAG * delta, 0.0)
	if _velocity.length() > MAX_SPEED:
		_velocity = _velocity.normalized() * MAX_SPEED
	global_transform.origin += _velocity * delta

	_update_camera(delta)


## 相机只做跟拍机位微调（远近 / FOV），朝向完全由机体决定。
func _update_camera(delta: float) -> void:
	var ratio := clampf((get_speed() - 8.0) / (MAX_SPEED - 8.0), 0.0, 1.0)
	camera.fov = lerpf(FOV_BASE, FOV_MAX, ratio)
	var target_z := lerpf(CAM_BASE_Z, CAM_MAX_Z, ratio)
	camera.position.z = lerpf(camera.position.z, target_z, 3.0 * delta)


## 被小行星撞毁：停摆输入与旋转，并隐藏机体模型。
func die() -> void:
	set_process(false)
	set_process_input(false)
	if has_node("Visual"):
		$Visual.visible = false
