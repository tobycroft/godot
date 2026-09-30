class_name Explosion
extends Node3D
## 爆炸特效：火花 / 碎块 / 烟尘三层 MultiMesh 粒子（千级数量）+ 闪光 + 冲击波 + 点光源。
## 用法：Explosion.spawn(父节点, 世界坐标, 强度)；强度 1.0 约 700 个粒子，
## 撞毁用 1.6 左右，小行星被撞碎用 0.4 左右。

const SPARKS := 460
const DEBRIS := 180
const SMOKE := 90
const MAX_LIFE := 3.0

var _swarms: Array[Swarm] = []
var _age := 0.0


## 一层粒子群：位置 / 速度 / 自转 / 寿命，每帧写回 MultiMesh。
class Swarm:
	const MODE_SHRINK := 0 # 随寿命收缩（火星）
	const MODE_HOLD := 1   # 保持大小，末期收缩（碎块）
	const MODE_GROW := 2   # 边扩散边膨胀（烟尘）

	var mm: MultiMeshInstance3D
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var eul := PackedVector3Array()
	var spin := PackedVector3Array()
	var life := PackedFloat32Array()
	var life0 := PackedFloat32Array()
	var size0 := PackedFloat32Array()
	var drag := 1.0
	var grow := 2.0
	var mode := MODE_SHRINK
	var count := 0

	func setup(n: int, mesh: Mesh, mat: Material, drag_v: float) -> void:
		count = n
		drag = drag_v
		pos.resize(n)
		vel.resize(n)
		eul.resize(n)
		spin.resize(n)
		life.resize(n)
		life0.resize(n)
		size0.resize(n)
		mm = MultiMeshInstance3D.new()
		var m := MultiMesh.new()
		m.transform_format = MultiMesh.TRANSFORM_3D
		m.use_colors = true
		m.mesh = mesh
		m.instance_count = n
		mm.multimesh = m
		mm.material_override = mat
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mm.extra_cull_margin = 60.0

	func emit(i: int, p: Vector3, v: Vector3, size: float, lf: float, sp: Vector3, col: Color) -> void:
		pos[i] = p
		vel[i] = v
		size0[i] = size
		life[i] = lf
		life0[i] = lf
		spin[i] = sp
		eul[i] = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		mm.multimesh.set_instance_color(i, col)
		var s := size
		mm.multimesh.set_instance_transform(i, Transform3D(
			Basis.from_euler(eul[i]).scaled(Vector3(s, s, s)), p))

	func update(delta: float) -> bool:
		var m := mm.multimesh
		var k: float = maxf(1.0 - drag * delta, 0.0)
		var any := false
		for i in count:
			if life[i] <= 0.0:
				continue
			any = true
			life[i] -= delta
			if life[i] <= 0.0:
				_hide(m, i)
				continue
			pos[i] += vel[i] * delta
			vel[i] *= k
			eul[i] += spin[i] * delta
			var r := clampf(life[i] / life0[i], 0.0, 1.0)
			var s := size0[i]
			if mode == MODE_SHRINK:
				s *= r
			elif mode == MODE_HOLD:
				s *= clampf(r / 0.3, 0.0, 1.0)
			else:
				s *= 1.0 + grow * (1.0 - r)
			var b := Basis.from_euler(eul[i]).scaled(Vector3(s, s, s))
			m.set_instance_transform(i, Transform3D(b, pos[i]))
		return any

	func _hide(m: MultiMesh, i: int) -> void:
		var b := Basis().scaled(Vector3(0.0001, 0.0001, 0.0001))
		m.set_instance_transform(i, Transform3D(b, pos[i]))


static func spawn(parent: Node3D, at: Vector3, power := 1.0) -> Explosion:
	var e := Explosion.new()
	e.position = at
	parent.add_child(e)
	e._start(power)
	return e


func _start(power: float) -> void:
	var p := maxf(power, 0.1)

	# --- 火花：数量最多、速度最快、加色混合
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.09, 0.09, 0.20)
	var sparks := Swarm.new()
	sparks.setup(int(SPARKS * p), spark_mesh, _unlit(Color(1.0, 1.0, 1.0), true,
		BaseMaterial3D.BLEND_MODE_ADD), 1.7)
	sparks.mode = Swarm.MODE_SHRINK
	for i in sparks.count:
		var dir := _rand_dir()
		var spd := randf_range(7.0, 36.0) * (0.55 + 0.6 * p)
		var hot := randf()
		var col := Color(1.0, 0.55 + 0.45 * hot, 0.12 + 0.4 * hot * hot)
		sparks.emit(i, dir * randf_range(0.1, 1.0) * p, dir * spd,
			randf_range(0.5, 1.7), randf_range(0.35, 1.5), _rand_spin(16.0), col)
	_add(sparks)

	# --- 碎块：慢一些、翻滚、末期收缩，从炽热冷却到暗
	var deb_mesh := SphereMesh.new()
	deb_mesh.radius = 0.5
	deb_mesh.height = 1.0
	deb_mesh.radial_segments = 6
	deb_mesh.rings = 4
	var deb_mat := StandardMaterial3D.new()
	deb_mat.albedo_color = Color(0.17, 0.15, 0.14)
	deb_mat.roughness = 0.85
	deb_mat.metallic = 0.2
	deb_mat.emission_enabled = true
	deb_mat.emission = Color(1.0, 0.42, 0.12)
	deb_mat.emission_energy_multiplier = 2.2
	deb_mat.vertex_color_use_as_albedo = true # 逐块明暗差异
	var tw0 := create_tween()
	tw0.tween_property(deb_mat, "emission_energy_multiplier", 0.0, 1.5)
	var debris := Swarm.new()
	debris.setup(int(DEBRIS * p), deb_mesh, deb_mat, 0.5)
	debris.mode = Swarm.MODE_HOLD
	for i in debris.count:
		var dir := _rand_dir()
		var spd := randf_range(3.0, 15.0) * (0.6 + 0.5 * p)
		var g := randf_range(0.75, 1.15)
		debris.emit(i, dir * randf_range(0.2, 1.1) * p, dir * spd,
			randf_range(0.12, 0.42) * p, randf_range(1.1, 2.2), _rand_spin(6.0),
			Color(g, g * 0.92, g * 0.85))
	_add(debris)

	# --- 烟尘：膨胀扩散，整体淡出
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.6
	smoke_mesh.height = 1.2
	smoke_mesh.radial_segments = 8
	smoke_mesh.rings = 6
	var smoke_mat := _unlit(Color(0.30, 0.26, 0.24), true, BaseMaterial3D.BLEND_MODE_MIX)
	smoke_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tw1 := create_tween()
	tw1.tween_property(smoke_mat, "albedo_color:a", 0.0, 1.9)
	var smoke := Swarm.new()
	smoke.setup(int(SMOKE * p), smoke_mesh, smoke_mat, 1.1)
	smoke.mode = Swarm.MODE_GROW
	smoke.grow = 2.6
	for i in smoke.count:
		var dir := _rand_dir()
		var spd := randf_range(1.5, 8.0) * (0.6 + 0.5 * p)
		var g := randf_range(0.55, 0.95)
		smoke.emit(i, dir * randf_range(0.2, 1.4) * p, dir * spd,
			randf_range(0.4, 1.0) * p, randf_range(1.2, 2.1), _rand_spin(1.5),
			Color(g, g * 0.95, g * 0.9))
	_add(smoke)

	_flash(p)
	_shockwave(p)
	_lights(p)


func _add(s: Swarm) -> void:
	add_child(s.mm)
	_swarms.append(s)


func _flash(p: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 20
	sm.rings = 10
	mi.mesh = sm
	var mat := _unlit(Color(1.0, 0.88, 0.62), true, BaseMaterial3D.BLEND_MODE_ADD)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.scale = Vector3.ONE * (0.6 * p)
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * (7.0 * p), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)


func _shockwave(p: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 28
	sm.rings = 14
	mi.mesh = sm
	var mat := _unlit(Color(0.75, 0.88, 1.0), true, BaseMaterial3D.BLEND_MODE_ADD)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.scale = Vector3.ONE * 0.4
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * (22.0 * p), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(mi.queue_free)


func _lights(p: float) -> void:
	for i in 2:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.26)
		l.light_energy = 14.0 * p
		l.omni_range = 40.0
		l.position = _rand_dir() * 1.5
		add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "light_energy", 0.0, 0.8)
		tw.tween_callback(l.queue_free)


func _unlit(col: Color, fade: bool, blend: BaseMaterial3D.BlendMode) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.blend_mode = blend
	m.albedo_color = col
	if fade:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _rand_dir() -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()


func _rand_spin(mag: float) -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * mag


func _process(delta: float) -> void:
	_age += delta
	var any := false
	for s in _swarms:
		if s.update(delta):
			any = true
	if (not any and _age > 0.5) or _age > MAX_LIFE:
		set_process(false)
		queue_free()
