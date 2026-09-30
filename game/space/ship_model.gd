@tool
extends Node3D
class_name ShipModel
## 飞船机体模型：全部由代码程序化生成（不再用方块 / 圆柱硬拼）。
## · 机身：超椭圆截面沿 Z 轴旋转成型（压扁 + 圆角方截面），首尾自动封口
## · 主翼 / 平尾 / 垂尾 / 腹鳍 / 边条：NACA 对称翼型沿展向放样，带后掠、锥度与上反
## · 细节：座舱盖（半透明 + 内舱）、背脊、机身分段环、翼刀、翼尖吊舱、
##   双发喷口与光核、尾焰（随油门伸缩）、航行灯
## 每个零件单独生成并单独校正绕序（闭合曲面 ∮(x-c)·n dA = 3V > 0），
## 因此镜像件（左机翼）与倾斜件（垂尾）的法线同样朝外，最后再按材质合并。

const SEG := 32          # 旋转体周向分段
const AIRFOIL_HALF := 12 # 翼型单面点数
const PLUME_BASE_Z := 2.28

var _mat_hull: StandardMaterial3D
var _mat_dark: StandardMaterial3D
var _mat_trim: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_core: StandardMaterial3D
var _mat_red: StandardMaterial3D
var _mat_green: StandardMaterial3D
var _mat_white: StandardMaterial3D
var _mat_plume: StandardMaterial3D
var _plumes: Array[MeshInstance3D] = []
var _plume_x: Array[float] = []


## 网格累加器（含 Godot 绕序校正），见 mesh_surf.gd


func _ready() -> void:
	_make_materials()
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.free()
	_plumes.clear()
	_plume_x.clear()
	_build()


# ---------------------------------------------------------------- 材质

func _std(col: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = roughness
	return m


func _emissive(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 1)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _make_materials() -> void:
	_mat_hull = _std(Color(0.235, 0.285, 0.365), 0.9, 0.30)
	_mat_dark = _std(Color(0.095, 0.115, 0.155), 0.75, 0.48)
	_mat_trim = _std(Color(0.60, 0.66, 0.77), 1.0, 0.18)
	_mat_core = _emissive(Color(0.35, 0.88, 1.0), 3.2)
	_mat_red = _emissive(Color(1.0, 0.16, 0.12), 3.0)
	_mat_green = _emissive(Color(0.18, 1.0, 0.42), 3.0)
	_mat_white = _emissive(Color(1.0, 1.0, 1.0), 2.4)

	_mat_glass = StandardMaterial3D.new()
	_mat_glass.albedo_color = Color(0.32, 0.60, 0.90, 0.34)
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_glass.metallic = 0.15
	_mat_glass.roughness = 0.06
	_mat_glass.emission_enabled = true
	_mat_glass.emission = Color(0.10, 0.30, 0.55)
	_mat_glass.emission_energy_multiplier = 0.35

	_mat_plume = StandardMaterial3D.new()
	_mat_plume.albedo_color = Color(0.40, 0.85, 1.0, 0.5)
	_mat_plume.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_plume.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_plume.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_plume.emission_enabled = true
	_mat_plume.emission = Color(0.35, 0.85, 1.0)
	_mat_plume.emission_energy_multiplier = 2.0


# ---------------------------------------------------------------- 组装

func _build() -> void:
	var hull := MeshSurf.new()
	var dark := MeshSurf.new()
	var trim := MeshSurf.new()
	var glass := MeshSurf.new()

	hull.merge(_fuselage())
	dark.merge(_spine())
	glass.merge(_canopy())
	for side in [-1.0, 1.0]:
		hull.merge(_lerx(side))
		hull.merge(_wing(side))
		hull.merge(_stabilator(side))
		hull.merge(_fin(side))
		dark.merge(_pod(side))
		dark.merge(_ventral(side))
		dark.merge(_nozzle(side))
	trim.merge(_canopy_frame())
	trim.merge(_probe())
	trim.merge(_bands())

	_add(hull, _mat_hull)
	_add(dark, _mat_dark)
	_add(trim, _mat_trim)
	_add(glass, _mat_glass)

	_cockpit()
	_fences()
	_belly_panels()
	_engine_glows()
	_nav_lights()
	_make_plumes()


func _add(s: MeshSurf, mat: Material) -> void:
	if s.idx.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = s.commit()
	mi.material_override = mat
	add_child(mi)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)


func _ball(r: float, pos: Vector3, mat: Material, scale := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.position = pos
	mi.scale = scale
	mi.material_override = mat
	add_child(mi)


# ---------------------------------------------------------------- 零件

func _fuselage() -> MeshSurf:
	# (半径, z)：机头收尖 -> 机身最粗 -> 尾部收拢
	return _lathe([
		Vector2(0.02, -2.34), Vector2(0.07, -2.20), Vector2(0.14, -1.98),
		Vector2(0.22, -1.72), Vector2(0.29, -1.44), Vector2(0.35, -1.14),
		Vector2(0.39, -0.80), Vector2(0.415, -0.44), Vector2(0.425, -0.06),
		Vector2(0.42, 0.32), Vector2(0.40, 0.68), Vector2(0.37, 1.02),
		Vector2(0.34, 1.34), Vector2(0.315, 1.64), Vector2(0.30, 1.88),
		Vector2(0.295, 2.06),
	], SEG, 1.16, 0.86, 2.6, Vector3.ZERO)


func _probe() -> MeshSurf:
	return _lathe([Vector2(0.035, -2.30), Vector2(0.022, -2.54), Vector2(0.0, -2.74)],
		12, 1.0, 1.0, 2.0, Vector3.ZERO)


func _spine() -> MeshSurf:
	return _lathe([
		Vector2(0.03, -0.12), Vector2(0.105, 0.06), Vector2(0.13, 0.34),
		Vector2(0.135, 0.82), Vector2(0.12, 1.28), Vector2(0.10, 1.68),
		Vector2(0.06, 1.98), Vector2(0.02, 2.08),
	], 18, 1.9, 0.82, 2.2, Vector3(0.0, 0.30, 0.0))


func _canopy() -> MeshSurf:
	return _lathe([
		Vector2(0.02, -1.42), Vector2(0.15, -1.26), Vector2(0.26, -1.06),
		Vector2(0.34, -0.80), Vector2(0.385, -0.50), Vector2(0.40, -0.18),
		Vector2(0.375, 0.06), Vector2(0.30, 0.26), Vector2(0.16, 0.40),
		Vector2(0.03, 0.46),
	], SEG, 0.82, 0.72, 2.2, Vector3(0.0, 0.20, 0.0))


func _canopy_frame() -> MeshSurf:
	# 沿座舱外表面的一圈骨架
	return _ring(Vector3(0.0, 0.20, -0.62), 0.375, 0.016, 0.84, 0.74, 26, 6)


func _cockpit() -> void:
	_ball(0.30, Vector3(0.0, 0.16, -0.52), _mat_dark, Vector3(0.66, 0.46, 1.05))


func _bands() -> MeshSurf:
	var s := MeshSurf.new()
	# [z, 该处机身半径]
	var spec := [[-1.18, 0.345], [-0.06, 0.422], [0.66, 0.40], [1.32, 0.34], [1.82, 0.305]]
	for b in spec:
		s.merge(_ring(Vector3(0.0, 0.0, float(b[0])), float(b[1]), 0.015, 1.16, 0.86, SEG, 6))
	return s


func _lerx(side: float) -> MeshSurf:
	return _loft(
		Vector3(0.30 * side, 0.02, -1.34), Vector3(0.0, 0.0, 0.95), 0.11,
		Vector3(1.05 * side, 0.10, -0.52), Vector3(0.0, 0.0, 0.30), 0.05,
		Vector3.UP, 6)


func _wing(side: float) -> MeshSurf:
	return _loft(
		Vector3(0.28 * side, 0.04, -0.62), Vector3(0.0, 0.0, 2.05), 0.23,
		Vector3(2.30 * side, 0.26, 0.58), Vector3(0.0, 0.0, 0.62), 0.08,
		Vector3.UP, 10)


func _stabilator(side: float) -> MeshSurf:
	return _loft(
		Vector3(0.30 * side, 0.14, 1.22), Vector3(0.0, 0.0, 1.10), 0.15,
		Vector3(1.28 * side, 0.20, 1.62), Vector3(0.0, 0.0, 0.52), 0.06,
		Vector3.UP, 6)


func _fin(side: float) -> MeshSurf:
	var cant := deg_to_rad(26.0)
	var span := Vector3(sin(cant) * side, cos(cant), 0.0)
	var axis := span.cross(Vector3(0.0, 0.0, 1.0)).normalized()
	var root_o := Vector3(0.28 * side, 0.30, 0.66)
	return _loft(
		root_o, Vector3(0.0, 0.0, 1.38), 0.16,
		root_o + span * 0.95 + Vector3(0.0, 0.0, 0.42), Vector3(0.0, 0.0, 0.60), 0.07,
		axis, 6)


func _ventral(side: float) -> MeshSurf:
	return _loft(
		Vector3(0.22 * side, -0.14, 1.42), Vector3(0.0, 0.0, 0.60), 0.09,
		Vector3(0.44 * side, -0.52, 1.70), Vector3(0.0, 0.0, 0.34), 0.05,
		Vector3.RIGHT, 4)


func _pod(side: float) -> MeshSurf:
	return _lathe([
		Vector2(0.02, 0.42), Vector2(0.085, 0.52), Vector2(0.095, 0.76),
		Vector2(0.09, 1.06), Vector2(0.06, 1.22), Vector2(0.02, 1.30),
	], 16, 1.0, 1.0, 2.0, Vector3(2.30 * side, 0.26, 0.0))


func _nozzle(side: float) -> MeshSurf:
	return _lathe([
		Vector2(0.195, 1.90), Vector2(0.19, 2.02), Vector2(0.182, 2.14),
		Vector2(0.192, 2.24), Vector2(0.212, 2.32),
	], 20, 1.0, 1.0, 2.0, Vector3(0.245 * side, 0.0, 0.0))


func _fences() -> void:
	for side in [-1.0, 1.0]:
		for x in [1.15, 1.78]:
			var t: float = (float(x) - 0.28) / (2.30 - 0.28)
			var y := lerpf(0.04, 0.26, t)
			var z_le := lerpf(-0.62, 0.58, t)
			_box(Vector3(0.035, 0.15, 0.44), Vector3(float(x) * side, y + 0.09, z_le + 0.28), _mat_dark)


func _belly_panels() -> void:
	for side in [-1.0, 1.0]:
		_box(Vector3(0.16, 0.05, 0.95), Vector3(0.27 * side, -0.30, 0.25), _mat_dark)


func _engine_glows() -> void:
	for side in [-1.0, 1.0]:
		_ball(0.155, Vector3(0.245 * side, 0.0, 2.18), _mat_core, Vector3(1.0, 1.0, 0.5))
		var light := OmniLight3D.new()
		light.position = Vector3(0.245 * side, 0.0, 2.40)
		light.light_color = Color(0.35, 0.88, 1.0)
		light.light_energy = 1.1
		light.omni_range = 5.0
		add_child(light)


func _nav_lights() -> void:
	_ball(0.06, Vector3(-2.30, 0.26, 0.60), _mat_red)
	_ball(0.06, Vector3(2.30, 0.26, 0.60), _mat_green)
	_ball(0.05, Vector3(0.0, 0.36, 1.98), _mat_white)


func _make_plumes() -> void:
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.16
		cm.height = 1.0
		cm.radial_segments = 16
		mi.mesh = cm
		mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		mi.material_override = _mat_plume
		add_child(mi)
		_plumes.append(mi)
		_plume_x.append(0.245 * side)
	set_thrust(0.45)


## 由 ship.gd 每帧调用：油门越大尾焰越长越亮。
func set_thrust(v: float) -> void:
	if _mat_plume == null:
		return
	_mat_plume.emission_energy_multiplier = 1.2 + v * 3.0
	for i in _plumes.size():
		var p := _plumes[i]
		var len_scale := 0.35 + v * 2.1
		p.scale.z = len_scale
		p.position.z = PLUME_BASE_Z + 0.5 * len_scale
		var w := 0.7 + v * 0.45
		p.scale.x = w
		p.scale.y = w
		p.position.x = _plume_x[i]


# ---------------------------------------------------------------- 几何工具

## 旋转体：profile 为 [(半径, z)]，截面为超椭圆（en>2 时趋于圆角矩形）。
func _lathe(profile: Array, seg: int, sx: float, sy: float, en: float, pos: Vector3) -> MeshSurf:
	var s := MeshSurf.new()
	var head := profile[0] as Vector2
	var tail := profile[-1] as Vector2
	var cap_a := s.v(Vector3(0.0, 0.0, head.y) + pos) if head.x > 0.001 else -1
	var cap_b := s.v(Vector3(0.0, 0.0, tail.y) + pos) if tail.x > 0.001 else -1
	var rings: Array = []
	var e := 2.0 / en
	for i in profile.size():
		var p := profile[i] as Vector2
		var ring := PackedInt32Array()
		ring.resize(seg)
		for j in seg:
			var th := float(j) / float(seg) * TAU
			var c := cos(th)
			var sn := sin(th)
			var px := signf(c) * pow(absf(c), e) * sx
			var py := signf(sn) * pow(absf(sn), e) * sy
			ring[j] = s.v(Vector3(px * p.x, py * p.x, p.y) + pos)
		rings.append(ring)
	for i in profile.size() - 1:
		var r0 := rings[i] as PackedInt32Array
		var r1 := rings[i + 1] as PackedInt32Array
		for j in seg:
			var j2 := (j + 1) % seg
			s.quad(r0[j], r0[j2], r1[j2], r1[j])
	if cap_a >= 0:
		var ra := rings[0] as PackedInt32Array
		for j in seg:
			s.tri(cap_a, ra[(j + 1) % seg], ra[j])
	if cap_b >= 0:
		var rb := rings[-1] as PackedInt32Array
		for j in seg:
			s.tri(cap_b, rb[j], rb[(j + 1) % seg])
	return s


## 圆环（管截面绕 Z 轴一圈），用于机身分段环与座舱骨架。
func _ring(center: Vector3, r: float, tube: float, sx: float, sy: float, seg: int, mseg: int) -> MeshSurf:
	var s := MeshSurf.new()
	var rings: Array = []
	for i in mseg:
		var phi := float(i) / float(mseg) * TAU
		var ring := PackedInt32Array()
		ring.resize(seg)
		for j in seg:
			var th := float(j) / float(seg) * TAU
			var rr := r + tube * cos(phi)
			ring[j] = s.v(center + Vector3(cos(th) * rr * sx, sin(th) * rr * sy, tube * sin(phi)))
		rings.append(ring)
	for i in mseg:
		var r0 := rings[i] as PackedInt32Array
		var r1 := rings[(i + 1) % mseg] as PackedInt32Array
		for j in seg:
			var j2 := (j + 1) % seg
			s.quad(r0[j], r0[j2], r1[j2], r1[j])
	return s


## 翼面：翼型沿翼根 -> 翼尖线性放样，两端自动封口。
func _loft(root_o: Vector3, root_c: Vector3, root_t: float,
		tip_o: Vector3, tip_c: Vector3, tip_t: float,
		axis: Vector3, stations: int) -> MeshSurf:
	var s := MeshSurf.new()
	var foil := _foil()
	var rings: Array = []
	for i in stations + 1:
		var t := float(i) / float(stations)
		var o := root_o.lerp(tip_o, t)
		var cv := root_c.lerp(tip_c, t)
		var th := lerpf(root_t, tip_t, t)
		var ring := PackedInt32Array()
		ring.resize(foil.size())
		for k in foil.size():
			var f := foil[k]
			ring[k] = s.v(o + cv * f.x + axis * (f.y * th))
		rings.append(ring)
	for i in stations:
		var r0 := rings[i] as PackedInt32Array
		var r1 := rings[i + 1] as PackedInt32Array
		for k in foil.size():
			var k2 := (k + 1) % foil.size()
			s.quad(r0[k], r0[k2], r1[k2], r1[k])
	_cap(s, rings[0] as PackedInt32Array)
	_cap(s, rings[-1] as PackedInt32Array)
	return s


func _cap(s: MeshSurf, ring: PackedInt32Array) -> void:
	var c := Vector3.ZERO
	for i in ring:
		c += s.verts[i]
	c /= float(ring.size())
	var ci := s.v(c)
	for k in ring.size():
		s.tri(ci, ring[k], ring[(k + 1) % ring.size()])


## NACA 对称翼型：y 归一化到 ±0.5 左右（乘厚度即得实际半厚度）。
func _foil() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var h := AIRFOIL_HALF
	for i in h:
		var b := float(i) / float(h - 1) * PI
		var xc := 0.5 * (1.0 - cos(b))
		pts.append(Vector2(xc, _shape(xc)))
	for i in range(1, h - 1):
		var b := (1.0 - float(i) / float(h - 1)) * PI
		var xc := 0.5 * (1.0 - cos(b))
		pts.append(Vector2(xc, -_shape(xc)))
	return pts


func _shape(x: float) -> float:
	return 5.0 * (0.2969 * sqrt(x) - 0.1260 * x - 0.3516 * x * x
		+ 0.2843 * x * x * x - 0.1036 * x * x * x * x)
