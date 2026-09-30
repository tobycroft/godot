class_name EnginePlume
extends Node3D
## 单台发动机的尾焰（挂在喷口位置，本地 +Z 为喷流方向）。
## · 白热核心 + 外焰锥：长度 / 粗细 / 亮度随油门变化
## · 燃气粒子流：MultiMesh 持续喷出的火花团，速度与寿命随油门增长
## · 马赫环（激波钻石）：油门进入加力段后沿轴线依次亮起，环距随推力拉长

const PARTICLES := 120
const RING_COUNT := 5
const MACH_START := 0.72 # 超过这个油门开始出现马赫环
const FLAME_MIN := 0.4
const FLAME_MAX := 2.7

var _flame: MeshInstance3D
var _core: MeshInstance3D
var _rings: Array[MeshInstance3D] = []
var _ring_mats: Array[StandardMaterial3D] = []
var _mm: MultiMeshInstance3D
var _p_pos := PackedVector3Array()
var _p_vel := PackedVector3Array()
var _p_life := PackedFloat32Array()
var _p_life0 := PackedFloat32Array()
var _p_size := PackedFloat32Array()
var _thrust := 0.45
var _t := 0.0


func _ready() -> void:
	_build()
	set_thrust(_thrust)


func _build() -> void:
	# 外焰锥（宽端在喷口，锥尖向后）
	_flame = MeshInstance3D.new()
	_flame.mesh = _cone(0.19, 0.025)
	_flame.material_override = _fire_mat(Color(0.30, 0.75, 1.0), 2.0, 0.5)
	_flame.rotation.x = PI * 0.5
	add_child(_flame)

	# 白热核心
	_core = MeshInstance3D.new()
	_core.mesh = _cone(0.10, 0.02)
	_core.material_override = _fire_mat(Color(0.85, 0.95, 1.0), 3.2, 0.85)
	_core.rotation.x = PI * 0.5
	add_child(_core)

	# 燃气粒子
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.use_colors = true
	pm.mesh = SphereMesh.new()
	(pm.mesh as SphereMesh).radius = 0.5
	(pm.mesh as SphereMesh).height = 1.0
	(pm.mesh as SphereMesh).radial_segments = 6
	(pm.mesh as SphereMesh).rings = 4
	pm.instance_count = PARTICLES
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = pm
	_mm.material_override = _fire_mat(Color(1.0, 1.0, 1.0), 2.6, 0.9)
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.extra_cull_margin = 20.0
	add_child(_mm)
	_p_pos.resize(PARTICLES)
	_p_vel.resize(PARTICLES)
	_p_life.resize(PARTICLES)
	_p_life0.resize(PARTICLES)
	_p_size.resize(PARTICLES)
	for i in PARTICLES:
		var hot := randf()
		pm.set_instance_color(i, Color(1.0, 0.72 + 0.28 * hot, 0.35 * hot + 0.25))
		_spawn(i, 9.0 + _thrust * 48.0)

	# 马赫环
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.085
	ring_mesh.outer_radius = 0.125
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 26
	for i in RING_COUNT:
		var r := MeshInstance3D.new()
		r.mesh = ring_mesh
		var mat := _fire_mat(Color(0.75, 0.92, 1.0), 3.6, 0.9)
		r.material_override = mat
		r.rotation.x = PI * 0.5 # 环面法线转到喷流轴
		r.visible = false
		add_child(r)
		_rings.append(r)
		_ring_mats.append(mat)


func _process(delta: float) -> void:
	_t += delta
	var speed := 9.0 + _thrust * 48.0
	var m := _mm.multimesh
	for i in PARTICLES:
		_p_life[i] -= delta
		if _p_life[i] <= 0.0:
			_spawn(i, speed)
		else:
			_p_pos[i] += _p_vel[i] * delta
			_p_vel[i] *= maxf(1.0 - 2.4 * delta, 0.0)
		var r := clampf(_p_life[i] / _p_life0[i], 0.0, 1.0)
		var s := _p_size[i] * (0.35 + 0.65 * r)
		m.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(s, s, s)), _p_pos[i]))
	_flicker()


func set_thrust(v: float) -> void:
	_thrust = clampf(v, 0.0, 1.0)
	var t := _thrust

	# 焰锥：长度与粗细随油门
	var len := lerpf(FLAME_MIN, FLAME_MAX, t)
	var w := 0.65 + t * 0.5
	_flame.scale = Vector3(w, len, w)
	_flame.position.z = 0.5 * len
	(_flame.material_override as StandardMaterial3D).emission_energy_multiplier = 1.4 + t * 2.6
	var clen := len * 0.45
	var cw := 0.5 + t * 0.35
	_core.scale = Vector3(cw, clen, cw)
	_core.position.z = 0.5 * clen

	# 马赫环：加力段依次亮起，环距随推力拉长
	var mach := clampf((t - MACH_START) / (1.0 - MACH_START), 0.0, 1.0)
	var spacing := 0.26 + 0.42 * t
	for i in RING_COUNT:
		var appear := clampf(mach * RING_COUNT - float(i), 0.0, 1.0)
		var r := _rings[i]
		r.visible = appear > 0.02
		if not r.visible:
			continue
		var f := float(i) / float(RING_COUNT)
		var s := (0.85 - f * 0.45) * (0.6 + 0.75 * t)
		r.scale = Vector3(s, 0.55 + 0.9 * t, s) # 局部 y = 喷流轴向厚度
		r.position.z = 0.18 + float(i) * spacing
		var mat := _ring_mats[i]
		mat.albedo_color.a = appear * (1.0 - f * 0.5) * 0.9
		mat.emission_energy_multiplier = 2.4 + t * 2.4


func _flicker() -> void:
	# 轻微抖动，避免尾焰看起来是死的
	var k := 1.0 + sin(_t * 42.0) * 0.05 + randf_range(-0.04, 0.04)
	_flame.scale.x = (0.65 + _thrust * 0.5) * k
	_flame.scale.z = _flame.scale.x


func _spawn(i: int, speed: float) -> void:
	_p_pos[i] = Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(0.0, 0.1))
	var swirl := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0).normalized() * randf_range(0.4, 2.0)
	_p_vel[i] = swirl * (0.35 + _thrust) + Vector3(0.0, 0.0, 1.0) * speed * randf_range(0.65, 1.15)
	_p_life0[i] = randf_range(0.10, 0.30) * (0.55 + _thrust * 0.9)
	_p_life[i] = _p_life0[i]
	_p_size[i] = randf_range(0.05, 0.14) * (0.7 + _thrust * 0.6)


func _cone(r_bottom: float, r_top: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = 1.0
	cm.radial_segments = 18
	return cm


func _fire_mat(col: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m
