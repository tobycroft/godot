class_name Player
extends CharacterBody3D
## 第三人称玩家控制器。
## WASD / 方向键移动，Space 跳跃，鼠标控制视角环绕。Esc 由 Pause 自动加载接管（弹出暂停菜单）。

const SPEED := 5.0
const ACCELERATION := 10.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.0025
const MODEL_TURN_SPEED := 12.0
## 模型朝向修正角（弧度）：若角色背对移动方向，改为 PI 即可
const MODEL_FACING_OFFSET := 0.0

@onready var model: Node3D = $Model
@onready var camera_pivot: Node3D = $CameraPivot


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY,
			deg_to_rad(-75.0), deg_to_rad(35.0)
		)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCELERATION * SPEED * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCELERATION * SPEED * delta)
		# 模型转向移动方向
		var target_yaw := atan2(direction.x, direction.z) + MODEL_FACING_OFFSET
		model.global_rotation.y = lerp_angle(model.global_rotation.y, target_yaw, MODEL_TURN_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ACCELERATION * SPEED * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCELERATION * SPEED * delta)

	move_and_slide()
