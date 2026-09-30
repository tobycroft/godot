extends Node3D
## 卡通小人：Q 版大头造型，程序化拼装（球体/胶囊/盒子，面朝 -Z）。
## 待机微动画：呼吸起伏 + 双臂摆动 + 轻微歪头。

var _torso: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head: Node3D
var _t := randf() * TAU

const SKIN := Color(1.0, 0.85, 0.70)
const SHIRT := Color(0.88, 0.33, 0.29)
const CAP := Color(0.85, 0.27, 0.24)
const PANTS := Color(0.22, 0.28, 0.38)
const HAIR := Color(0.29, 0.20, 0.13)
const SHOE := Color(0.95, 0.95, 0.96)


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta
	var sway := sin(_t * 2.0)
	_arm_l.rotation.x = sway * 0.12
	_arm_r.rotation.x = -sway * 0.12
	_head.rotation.z = sin(_t * 0.7) * 0.045
	_torso.position.y = 0.38 + absf(sway) * 0.02


func _build() -> void:
	var mats := {}
	for c: Color in [SKIN, SHIRT, CAP, PANTS, HAIR, SHOE, Color.WHITE, Color(0.10, 0.10, 0.12), Color(0.95, 0.64, 0.63), Color(0.48, 0.26, 0.20)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		mats[c] = m

	# 腿脚（不参与动画）
	for sx: float in [-1.0, 1.0]:
		_box(self, Vector3(0.26, 0.12, 0.42), Vector3(0.15 * sx, 0.06, -0.04), mats[SHOE])
		_capsule(self, 0.09, 0.35, Vector3(0.15 * sx, 0.32, 0), mats[PANTS])

	# 躯干容器（呼吸起伏作用于此）
	_torso = Node3D.new()
	_torso.position.y = 0.38
	add_child(_torso)
	_capsule(_torso, 0.23, 0.42, Vector3(0, 0.48, 0), mats[SHIRT])
	_box(_torso, Vector3(0.40, 0.09, 0.32), Vector3(0, 0.24, 0), mats[PANTS]) # 裤腰

	# 双臂：肩部容器（摆臂动画旋转容器）
	for sx: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.27 * sx, 1.00, 0)
		shoulder.rotation.z = -0.18 * sx
		add_child(shoulder)
		if sx < 0:
			_arm_l = shoulder
		else:
			_arm_r = shoulder
		_capsule(shoulder, 0.07, 0.30, Vector3(0, -0.20, 0), mats[SHIRT]) # 袖子
		_capsule(shoulder, 0.065, 0.14, Vector3(0, -0.40, 0), mats[SKIN]) # 手臂
		_sphere(shoulder, 0.08, Vector3(0, -0.50, 0), mats[SKIN]) # 手

	# 头部容器（歪头动画作用于此）
	_head = Node3D.new()
	_head.position.y = 1.22
	add_child(_head)
	_capsule(_head, 0.07, 0.08, Vector3(0, -0.01, 0), mats[SKIN]) # 脖子
	_sphere(_head, 0.34, Vector3(0, 0.32, 0), mats[SKIN]) # 脑袋
	_sphere(_head, 0.345, Vector3(0, 0.37, 0.06), mats[HAIR], Vector3(1, 0.8, 1)) # 头发
	_sphere(_head, 0.35, Vector3(0, 0.46, 0.02), mats[CAP], Vector3(1, 0.58, 1)) # 帽顶
	_box(_head, Vector3(0.36, 0.045, 0.22), Vector3(0, 0.43, -0.30), mats[CAP]) # 帽檐
	# 五官
	for sx: float in [-1.0, 1.0]:
		_sphere(_head, 0.08, Vector3(0.13 * sx, 0.32, -0.27), mats[Color.WHITE])
		_sphere(_head, 0.038, Vector3(0.13 * sx, 0.32, -0.335), mats[Color(0.10, 0.10, 0.12)])
		_sphere(_head, 0.05, Vector3(0.22 * sx, 0.22, -0.22), mats[Color(0.95, 0.64, 0.63)]) # 腮红
	_box(_head, Vector3(0.13, 0.035, 0.02), Vector3(0, 0.16, -0.318), mats[Color(0.48, 0.26, 0.20)]) # 嘴


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


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


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
