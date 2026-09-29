class_name Ship
extends Node3D
## 宇宙飞船控制器（含模型）。
## 鼠标拖拽 / 方向键控制俯仰(pitch)与偏航(yaw)，转向时机身轻微滚转(bank)增强飞行感。
## 飞船本体保持在原点附近，真正的环境流动由 Space 场景负责，从而营造 3D 空间飞行错觉。

const YAW_SPEED := 1.8
const PITCH_SPEED := 1.3
const ROLL_SPEED := 2.5
const MOUSE_SENS := 0.0025

@onready var visual: Node3D = $Visual


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_object_local(Vector3.UP, -event.relative.x * MOUSE_SENS)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * MOUSE_SENS)


func _process(delta: float) -> void:
	var yaw := 0.0
	var pitch := 0.0
	if Input.is_action_pressed("move_left"):
		yaw += 1.0
	if Input.is_action_pressed("move_right"):
		yaw -= 1.0
	if Input.is_action_pressed("move_forward"):
		pitch -= 1.0
	if Input.is_action_pressed("move_back"):
		pitch += 1.0

	rotate_object_local(Vector3.UP, yaw * YAW_SPEED * delta)
	rotate_object_local(Vector3.RIGHT, pitch * PITCH_SPEED * delta)

	# 转向时机身自然倾斜（bank）
	var target_roll := -yaw * 0.45
	visual.rotation.z = lerp_angle(visual.rotation.z, target_roll, ROLL_SPEED * delta)
