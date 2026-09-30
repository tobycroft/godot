class_name RunnerPlayer
extends Node3D
## 跑酷玩家：程序化关节小人（躯干/头/双臂/双腿，肘膝铰链）。
## 按奔跑相位驱动四肢摆动、屈膝、身体起伏前倾，速度越快步频越快；
## 腾空时收腿摆臂成跳跃姿态。左右切道、跳跃逻辑不变。

const LANE_X: Array[float] = [-2.2, 0.0, 2.2]
const LANE_SWITCH_SPEED := 12.0
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const HIP_HEIGHT := 0.9 # 髋关节高度（大腿0.45+小腿0.40+脚踝0.05）
const STRIDE_RATE := 0.62 # 步频系数：相位速率 = 跑速 * STRIDE_RATE

var _lane := 1
var _velocity_y := 0.0
var _running := false
var _pace := 20.0
var _phase := 0.0

# 关节节点
var _body: Node3D
var _head: Node3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D


func _ready() -> void:
	_build_model()


func start_run() -> void:
	_running = true
	_phase = 0.0


func stop_run() -> void:
	_running = false
	_reset_pose()


func set_run_pace(speed: float) -> void:
	_pace = speed


func is_on_ground() -> bool:
	return position.y <= 0.001


func _physics_process(delta: float) -> void:
	position.x = move_toward(position.x, LANE_X[_lane], LANE_SWITCH_SPEED * delta)

	if not is_on_ground() or _velocity_y > 0.0:
		_velocity_y -= GRAVITY * delta
		position.y += _velocity_y * delta
		if position.y <= 0.0:
			position.y = 0.0
			_velocity_y = 0.0

	if not _running:
		return
	if is_on_ground():
		_phase += delta * _pace * STRIDE_RATE
		_animate_run()
	else:
		_animate_air(delta)


# ---- 程序化建模（角色面朝 -Z 前进方向）----

func _build_model() -> void:
	var shirt := _mat(Color(0.16, 0.46, 0.78))
	var skin := _mat(Color(0.93, 0.76, 0.62))
	var hair := _mat(Color(0.16, 0.13, 0.11))
	var pants := _mat(Color(0.22, 0.24, 0.30))
	var shoe := _mat(Color(0.92, 0.92, 0.95))

	# 上身：起伏/前倾/侧倾都作用在 Body 上
	_body = Node3D.new()
	_body.name = "Body"
	_body.position.y = HIP_HEIGHT
	add_child(_body)
	_box(_body, Vector3(0.52, 0.62, 0.30), Vector3(0, 0.31, 0), shirt) # 躯干

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.62, 0)
	_body.add_child(_head)
	_box(_head, Vector3(0.30, 0.32, 0.28), Vector3(0, 0.17, 0), skin)
	_box(_head, Vector3(0.32, 0.10, 0.30), Vector3(0, 0.30, -0.01), hair)

	# 左臂：肩→肘 两级铰链
	_shoulder_l = _limb(_body, Vector3(-0.33, 0.58, 0))
	_box(_shoulder_l, Vector3(0.14, 0.50, 0.16), Vector3(0, -0.25, 0), shirt)
	_elbow_l = _limb(_shoulder_l, Vector3(0, -0.50, 0))
	_box(_elbow_l, Vector3(0.12, 0.40, 0.13), Vector3(0, -0.20, 0), skin)

	# 右臂
	_shoulder_r = _limb(_body, Vector3(0.33, 0.58, 0))
	_box(_shoulder_r, Vector3(0.14, 0.50, 0.16), Vector3(0, -0.25, 0), shirt)
	_elbow_r = _limb(_shoulder_r, Vector3(0, -0.50, 0))
	_box(_elbow_r, Vector3(0.12, 0.40, 0.13), Vector3(0, -0.20, 0), skin)

	# 左腿：髋→膝 两级铰链，脚底落在 y=0
	_hip_l = _limb(self, Vector3(-0.15, HIP_HEIGHT, 0))
	_box(_hip_l, Vector3(0.17, 0.45, 0.19), Vector3(0, -0.225, 0), pants)
	_knee_l = _limb(_hip_l, Vector3(0, -0.45, 0))
	_box(_knee_l, Vector3(0.15, 0.40, 0.16), Vector3(0, -0.20, 0), pants)
	_box(_knee_l, Vector3(0.16, 0.09, 0.30), Vector3(0, -0.40, -0.04), shoe)

	# 右腿
	_hip_r = _limb(self, Vector3(0.15, HIP_HEIGHT, 0))
	_box(_hip_r, Vector3(0.17, 0.45, 0.19), Vector3(0, -0.225, 0), pants)
	_knee_r = _limb(_hip_r, Vector3(0, -0.45, 0))
	_box(_knee_r, Vector3(0.15, 0.40, 0.16), Vector3(0, -0.20, 0), pants)
	_box(_knee_r, Vector3(0.16, 0.09, 0.30), Vector3(0, -0.40, -0.04), shoe)


func _limb(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


# ---- 奔跑动画 ----

func _animate_run() -> void:
	var swing := sin(_phase)
	var bob := absf(cos(_phase)) # 每步一次上下起伏

	# 双腿相位相反；膝盖在迈腿摆动段屈曲最大
	_hip_l.rotation.x = swing * 0.85
	_hip_r.rotation.x = -swing * 0.85
	_knee_l.rotation.x = -maxf(0.0, cos(_phase)) * 1.15 - 0.08
	_knee_r.rotation.x = -maxf(0.0, -cos(_phase)) * 1.15 - 0.08

	# 双臂与同侧腿相反摆动，肘部保持弯曲随摆动加深
	_shoulder_l.rotation.x = -swing * 0.75
	_shoulder_r.rotation.x = swing * 0.75
	_elbow_l.rotation.x = 0.65 + maxf(0.0, swing) * 0.55
	_elbow_r.rotation.x = 0.65 + maxf(0.0, -swing) * 0.55

	# 身体：上下起伏 + 前倾 + 轻微侧倾/扭转；头部反向补偿保持稳定
	_body.position.y = HIP_HEIGHT + bob * 0.07
	_body.rotation.x = -0.16 - 0.02 * sin(_phase * 2.0)
	_body.rotation.z = swing * 0.05
	_body.rotation.y = swing * 0.08
	_head.rotation.x = 0.10
	_head.rotation.y = -swing * 0.06


func _animate_air(delta: float) -> void:
	# 跳跃姿态：收腿屈膝、双臂后摆，平滑过渡
	var k := minf(1.0, delta * 12.0)
	_lerp_joint(_hip_l, 0.55, k)
	_lerp_joint(_hip_r, -0.20, k)
	_lerp_joint(_knee_l, -1.30, k)
	_lerp_joint(_knee_r, -0.55, k)
	_lerp_joint(_shoulder_l, -1.00, k)
	_lerp_joint(_shoulder_r, -1.00, k)
	_lerp_joint(_elbow_l, 0.40, k)
	_lerp_joint(_elbow_r, 0.40, k)
	_body.position.y = HIP_HEIGHT
	_body.rotation.x = lerpf(_body.rotation.x, -0.05, k)
	_body.rotation.y = lerpf(_body.rotation.y, 0.0, k)
	_body.rotation.z = lerpf(_body.rotation.z, 0.0, k)
	_head.rotation.x = lerpf(_head.rotation.x, 0.0, k)
	_head.rotation.y = 0.0


func _lerp_joint(j: Node3D, target_x: float, k: float) -> void:
	j.rotation.x = lerpf(j.rotation.x, target_x, k)


func _reset_pose() -> void:
	for j: Node3D in [_body, _head, _shoulder_l, _shoulder_r, _elbow_l, _elbow_r, _hip_l, _hip_r, _knee_l, _knee_r]:
		j.rotation = Vector3.ZERO
	_body.position.y = HIP_HEIGHT


# ---- 操作输入 ----

func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event.is_action_pressed("move_left") and event.pressed and not event.echo:
		_lane = maxi(_lane - 1, 0)
	elif event.is_action_pressed("move_right") and event.pressed and not event.echo:
		_lane = mini(_lane + 1, LANE_X.size() - 1)
	elif event.is_action_pressed("jump") and event.pressed and not event.echo and is_on_ground():
		_velocity_y = JUMP_VELOCITY
