extends Node3D
## Q 版卡通小人：完整关节链（肩-肘 / 髋-膝），程序化拼装，面朝 -Z。
## 根据父节点 CharacterBody3D 的速度自动播放跑步循环（摆臂/迈腿/屈膝/起伏/前倾），
## 静止时待机呼吸，离地时收腿摆臂跳跃；身体平滑转向移动方向。

# ---- 材质色 ----
const SKIN := Color(1.0, 0.85, 0.70)
const SHIRT := Color(0.88, 0.30, 0.26)
const CAP := Color(0.86, 0.24, 0.22)
const PANTS := Color(0.20, 0.27, 0.38)
const HAIR := Color(0.28, 0.19, 0.12)
const SHOE := Color(0.96, 0.96, 0.97)
const SOLE := Color(0.14, 0.14, 0.16)
const IRIS := Color(0.20, 0.42, 0.62)
const BLACK := Color(0.08, 0.08, 0.10)
const MOUTH := Color(0.62, 0.30, 0.26)
const BLUSH := Color(0.96, 0.62, 0.60)
const PACK := Color(0.95, 0.78, 0.25)
const PACK_DARK := Color(0.80, 0.60, 0.14)

const HIP_H := 0.82 # 髋关节高度
const STRIDE := 0.55 # 步频系数

var _torso: Node3D
var _head: Node3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D

var _t := 0.0
var _phase := 0.0
var _run_blend := 0.0
var _air_blend := 0.0
var _mats := {}


func _ready() -> void:
	for c: Color in [SKIN, SHIRT, CAP, PANTS, HAIR, SHOE, SOLE, IRIS, BLACK, MOUTH, BLUSH, PACK, PACK_DARK, Color.WHITE]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.75
		_mats[c] = m
	_build()


func _physics_process(delta: float) -> void:
	_t += delta
	var parent_body := get_parent() as CharacterBody3D
	var speed := Vector2(parent_body.velocity.x, parent_body.velocity.z).length()
	var grounded: bool = parent_body.is_on_floor()

	_run_blend = lerpf(_run_blend, clampf(speed / 2.5, 0.0, 1.0), 1.0 - exp(-12.0 * delta))
	_air_blend = lerpf(_air_blend, 0.0 if grounded else 1.0, 1.0 - exp(-10.0 * delta))
	if grounded and _run_blend > 0.05:
		_phase += delta * speed * STRIDE

	_face_movement(parent_body, delta, speed)
	_pose(delta)


# ---- 动画姿态 ----

func _pose(delta: float) -> void:
	var b := _run_blend
	var s := sin(_phase)
	var c := cos(_phase)

	# 跑步目标姿态
	var hip_l_x := s * 0.85 * b
	var hip_r_x := -s * 0.85 * b
	var knee_l_x := -(0.08 + maxf(0.0, c) * 1.05 * b)
	var knee_r_x := -(0.08 + maxf(0.0, -c) * 1.05 * b)
	var sho_l_x := -s * 0.75 * b
	var sho_r_x := s * 0.75 * b
	var elb_l_x := 0.35 + (0.35 + maxf(0.0, s) * 0.45) * b
	var elb_r_x := 0.35 + (0.35 + maxf(0.0, -s) * 0.45) * b

	# 离地姿态：屈膝收腿、双臂上摆
	if _air_blend > 0.001:
		var k := _air_blend
		hip_l_x = lerpf(hip_l_x, 0.55, k)
		hip_r_x = lerpf(hip_r_x, -0.25, k)
		knee_l_x = lerpf(knee_l_x, -1.25, k)
		knee_r_x = lerpf(knee_r_x, -0.70, k)
		sho_l_x = lerpf(sho_l_x, -1.10, k)
		sho_r_x = lerpf(sho_r_x, -1.10, k)
		elb_l_x = lerpf(elb_l_x, 0.30, k)
		elb_r_x = lerpf(elb_r_x, 0.30, k)

	var ik := 1.0 - exp(-18.0 * delta)
	_hip_l.rotation.x = lerpf(_hip_l.rotation.x, hip_l_x, ik)
	_hip_r.rotation.x = lerpf(_hip_r.rotation.x, hip_r_x, ik)
	_knee_l.rotation.x = lerpf(_knee_l.rotation.x, knee_l_x, ik)
	_knee_r.rotation.x = lerpf(_knee_r.rotation.x, knee_r_x, ik)
	_shoulder_l.rotation.x = lerpf(_shoulder_l.rotation.x, sho_l_x, ik)
	_shoulder_r.rotation.x = lerpf(_shoulder_r.rotation.x, sho_r_x, ik)
	_elbow_l.rotation.x = lerpf(_elbow_l.rotation.x, elb_l_x, ik)
	_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, elb_r_x, ik)

	# 躯干：跑步起伏 + 前倾，待机呼吸
	var bob := absf(c) * 0.07 * b
	var breath := sin(_t * 2.2) * 0.012
	_torso.position.y = HIP_H + bob + breath
	var lean := -0.04 - 0.16 * b
	_torso.rotation.x = lerpf(_torso.rotation.x, lean, ik)
	_torso.rotation.z = lerpf(_torso.rotation.z, s * 0.05 * b, ik)

	# 头部：跑步轻微随动，待机歪头，始终回正不随躯干前倾过度
	_head.rotation.x = lerpf(_head.rotation.x, -lean * 0.4, ik)
	_head.rotation.z = lerpf(_head.rotation.z, sin(_t * 0.8) * 0.05 * (1.0 - b) - s * 0.03 * b, ik)


func _face_movement(body: CharacterBody3D, delta: float, speed: float) -> void:
	if speed > 1.0:
		var yaw := atan2(body.velocity.x, body.velocity.z) + PI
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-10.0 * delta))


# ---- 建模 ----

func _build() -> void:
	# 腿（髋/膝关节直接挂在角色根节点，脚底在 y=0）
	for sx: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.13 * sx, HIP_H, 0)
		add_child(hip)
		_capsule(hip, 0.10, 0.40, Vector3(0, -0.20, 0), _mats[PANTS])
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.40, 0)
		hip.add_child(knee)
		_capsule(knee, 0.09, 0.38, Vector3(0, -0.19, 0), _mats[SKIN])
		_box(knee, Vector3(0.19, 0.06, 0.30), Vector3(0, -0.40, -0.03), _mats[SOLE])
		_box(knee, Vector3(0.18, 0.10, 0.28), Vector3(0, -0.36, -0.05), _mats[SHOE])
		if sx < 0.0:
			_hip_l = hip
			_knee_l = knee
		else:
			_hip_r = hip
			_knee_r = knee

	# 躯干（起伏/前倾作用于此容器）
	_torso = Node3D.new()
	_torso.position.y = HIP_H
	add_child(_torso)
	_capsule(_torso, 0.23, 0.60, Vector3(0, 0.36, 0), _mats[SHIRT])
	_box(_torso, Vector3(0.40, 0.12, 0.32), Vector3(0, 0.10, 0), _mats[PANTS]) # 裤腰
	# 后背小书包
	_box(_torso, Vector3(0.30, 0.34, 0.13), Vector3(0, 0.42, 0.23), _mats[PACK])
	_box(_torso, Vector3(0.22, 0.10, 0.04), Vector3(0, 0.50, 0.30), _mats[PACK_DARK])

	# 双臂（肩-肘铰链）
	for sx: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.26 * sx, 0.62, 0)
		shoulder.rotation.z = -0.16 * sx
		_torso.add_child(shoulder)
		_sphere(shoulder, 0.085, Vector3.ZERO, _mats[SHIRT]) # 圆肩
		_capsule(shoulder, 0.065, 0.32, Vector3(0, -0.18, 0), _mats[SHIRT])
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.34, 0)
		shoulder.add_child(elbow)
		_capsule(elbow, 0.058, 0.28, Vector3(0, -0.14, 0), _mats[SKIN])
		_sphere(elbow, 0.075, Vector3(0, -0.30, 0), _mats[SKIN])
		if sx < 0.0:
			_shoulder_l = shoulder
			_elbow_l = elbow
		else:
			_shoulder_r = shoulder
			_elbow_r = elbow

	# 头部
	_head = Node3D.new()
	_head.position = Vector3(0, 0.70, 0)
	_torso.add_child(_head)
	_capsule(_head, 0.07, 0.10, Vector3(0, 0.02, 0), _mats[SKIN]) # 脖子
	_sphere(_head, 0.36, Vector3(0, 0.34, 0), _mats[SKIN], Vector3(1.0, 0.96, 0.98)) # 脸
	_sphere(_head, 0.20, Vector3(0, 0.30, 0.20), _mats[HAIR], Vector3(1.1, 1.0, 0.8)) # 后脑勺头发
	# 耳朵
	for sx: float in [-1.0, 1.0]:
		_sphere(_head, 0.07, Vector3(0.34 * sx, 0.34, 0.0), _mats[SKIN], Vector3(0.55, 1.0, 0.8))
	# 五官（正面 -Z）
	for sx: float in [-1.0, 1.0]:
		_sphere(_head, 0.095, Vector3(0.13 * sx, 0.38, -0.285), _mats[Color.WHITE], Vector3(1.0, 1.15, 0.45))
		_sphere(_head, 0.052, Vector3(0.13 * sx, 0.37, -0.34), _mats[IRIS], Vector3(1.0, 1.0, 0.5))
		_sphere(_head, 0.028, Vector3(0.13 * sx, 0.37, -0.375), _mats[BLACK])
		_sphere(_head, 0.014, Vector3(0.112 * sx, 0.395, -0.392), _mats[Color.WHITE]) # 高光
		_box(_head, Vector3(0.12, 0.028, 0.02), Vector3(0.13 * sx, 0.50, -0.315), _mats[HAIR], 0.12 * sx) # 眉毛
		_sphere(_head, 0.055, Vector3(0.235 * sx, 0.27, -0.235), _mats[BLUSH], Vector3(1.0, 0.7, 0.4)) # 腮红
	_sphere(_head, 0.035, Vector3(0, 0.29, -0.35), _mats[SKIN], Vector3(0.8, 0.8, 1.2)) # 鼻子
	_box(_head, Vector3(0.11, 0.028, 0.02), Vector3(0, 0.16, -0.33), _mats[MOUTH]) # 嘴
	# 棒球帽
	_sphere(_head, 0.38, Vector3(0, 0.50, 0.02), _mats[CAP], Vector3(1.0, 0.55, 1.0))
	_box(_head, Vector3(0.34, 0.04, 0.26), Vector3(0, 0.46, -0.38), _mats[CAP])
	_sphere(_head, 0.045, Vector3(0, 0.71, 0.02), _mats[CAP])


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, scale := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)


func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_z := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.z = rot_z
	parent.add_child(mi)
