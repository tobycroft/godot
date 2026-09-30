extends CharacterBody3D
## 地形漫游玩家：基于 demo Player 修改。
## Q/E 已让给铲子/堆土功能；空格触发喷气背包持续上升（重力始终生效，松开下落），其余不变。

@export var MOVE_SPEED: float = 14.0
@export var JET_THRUST: float = 60.0 # 喷气背包推力（上升加速度）
@export var JET_MAX_UP: float = 9.0 # 喷气上升速度上限

@export var first_person: bool = false :
	set(p_value):
		first_person = p_value
		if first_person:
			var tween: Tween = create_tween()
			tween.tween_property($CameraManager/Arm, "spring_length", 0.0, .33)
			tween.tween_callback($Body.set_visible.bind(false))
		else:
			$Body.visible = true
			create_tween().tween_property($CameraManager/Arm, "spring_length", 6.0, .33)

@export var gravity_enabled: bool = true :
	set(p_value):
		gravity_enabled = p_value
		if not gravity_enabled:
			velocity.y = 0

@export var collision_enabled: bool = true :
	set(p_value):
		collision_enabled = p_value
		$CollisionShapeBody.disabled = ! collision_enabled
		$CollisionShapeRay.disabled = ! collision_enabled


func _physics_process(p_delta) -> void:
	var direction: Vector3 = get_camera_relative_input()
	var h_veloc: Vector2 = Vector2(direction.x, direction.z).normalized() * MOVE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		h_veloc *= 2
	velocity.x = h_veloc.x
	velocity.z = h_veloc.y
	if gravity_enabled:
		velocity.y -= 40 * p_delta
	if Input.is_key_pressed(KEY_SPACE):
		velocity.y = minf(velocity.y + JET_THRUST * p_delta, JET_MAX_UP)
	move_and_slide()


# 返回相对相机的输入方向
func get_camera_relative_input() -> Vector3:
	var input_dir: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_A):
		input_dir -= %Camera3D.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += %Camera3D.global_transform.basis.x
	if Input.is_key_pressed(KEY_W):
		input_dir -= %Camera3D.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += %Camera3D.global_transform.basis.z
	if Input.is_key_pressed(KEY_KP_ADD) or Input.is_key_pressed(KEY_EQUAL):
		MOVE_SPEED = clamp(MOVE_SPEED + .5, 5, 9999)
	if Input.is_key_pressed(KEY_KP_SUBTRACT) or Input.is_key_pressed(KEY_MINUS):
		MOVE_SPEED = clamp(MOVE_SPEED - .5, 5, 9999)
	return input_dir


func _input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseButton and p_event.pressed:
		if p_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			MOVE_SPEED = clamp(MOVE_SPEED + 5, 5, 9999)
		elif p_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			MOVE_SPEED = clamp(MOVE_SPEED - 5, 5, 9999)

	elif p_event is InputEventKey:
		if p_event.pressed:
			if p_event.keycode == KEY_V:
				first_person = ! first_person
			elif p_event.keycode == KEY_G:
				gravity_enabled = ! gravity_enabled
			elif p_event.keycode == KEY_C:
				collision_enabled = ! collision_enabled

		elif p_event.keycode == KEY_SPACE:
			velocity.y = 0
