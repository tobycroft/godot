class_name Ship
extends Node3D
## 宇宙飞船控制器（含模型）。
## 带惯性的飞行手感：角速度有加速与回中过程（不是瞬间转向），
## 速度由推力与阻力决定，转弯时保留侧向惯性（漂移感）。
## 镜头逻辑：相机挂在 Body 下，与机体共用同一滚转角 —— 转弯时是"整个画面"
## 跟着飞船一起倾转，机翼始终与画面水平线平行，而不是飞船在画面里独自翻滚。
## Shift 加大油门 / Ctrl 减小油门；撞毁时由 die() 停摆并隐藏机体。

const MAX_THRUST := 90.0
const DRAG := 1.6
const LATERAL_DRAG := 1.3
const MIN_THROTTLE := 0.15
const MAX_THROTTLE := 1.0
const THROTTLE_RATE := 0.6
const MAX_SPEED := 60.0

const TURN_RATE := 1.6
const PITCH_TURN_RATE := 1.2
const ANG_ACCEL := 3.0
const MOUSE_GAIN := 0.006
const MOUSE_DECAY := 2.5

# 滚转：协调转弯（左转压左翼、右转压右翼），上限约 49°
const BANK_FACTOR := 0.55
const MAX_BANK := 0.85
const BANK_SMOOTH := 3.4

const CAM_BASE_Z := 7.6
const CAM_MAX_Z := 9.8
const FOV_BASE := 70.0
const FOV_MAX := 84.0

@onready var body: Node3D = $Body
@onready var visual: ShipModel = $Body/Visual
@onready var camera: Camera3D = $Body/Camera3D

var _velocity := Vector3.ZERO
var _throttle := 0.45
var _yaw_rate := 0.0
var _pitch_rate := 0.0
var _mouse_yaw := 0.0
var _mouse_pitch := 0.0
var _bank := 0.0


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

	# 目标角速度（键盘 + 鼠标），带惯性加速与回中
	var target_yaw := 0.0
	var target_pitch := 0.0
	if Input.is_action_pressed("move_left"):
		target_yaw += 1.0
	if Input.is_action_pressed("move_right"):
		target_yaw -= 1.0
	if Input.is_action_pressed("move_forward"):
		target_pitch -= 1.0
	if Input.is_action_pressed("move_back"):
		target_pitch += 1.0
	target_yaw = clampf(target_yaw + _mouse_yaw, -1.0, 1.0)
	target_pitch = clampf(target_pitch + _mouse_pitch, -1.0, 1.0)
	_yaw_rate = move_toward(_yaw_rate, target_yaw * TURN_RATE, ANG_ACCEL * delta)
	_pitch_rate = move_toward(_pitch_rate, target_pitch * PITCH_TURN_RATE, ANG_ACCEL * delta)

	rotate_object_local(Vector3.UP, _yaw_rate * delta)
	rotate_object_local(Vector3.RIGHT, _pitch_rate * delta)

	# 机体（连同相机）一起滚转：整个画面随飞船倾转
	_bank = lerpf(_bank, clampf(_yaw_rate * BANK_FACTOR, -MAX_BANK, MAX_BANK), BANK_SMOOTH * delta)
	body.rotation.z = _bank
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


## 相机：只做"跟拍机位"的微调（远近 / 侧向偏移 / FOV），
## 朝向完全由 Body 决定，所以转弯时画面与机翼始终同一水平基准。
func _update_camera(delta: float) -> void:
	var ratio := clampf((get_speed() - 8.0) / (MAX_SPEED - 8.0), 0.0, 1.0)
	camera.fov = lerpf(FOV_BASE, FOV_MAX, ratio)
	var target_z := lerpf(CAM_BASE_Z, CAM_MAX_Z, ratio)
	var target_x := clampf(_yaw_rate * 0.55, -1.2, 1.2)
	camera.position.z = lerpf(camera.position.z, target_z, 3.0 * delta)
	camera.position.x = lerpf(camera.position.x, target_x, 3.0 * delta)


## 被小行星撞毁：停摆输入与旋转，并隐藏机体模型。
func die() -> void:
	set_process(false)
	set_process_input(false)
	if has_node("Body/Visual"):
		$"Body/Visual".visible = false
