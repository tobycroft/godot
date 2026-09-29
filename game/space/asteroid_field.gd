extends Node3D
## 小行星场：程序化生成不规则岩石外观的小行星，围绕飞船循环补充；
## 部分小行星带辐射微光（自发光 + 点光源）。并提供碰撞检测。

const COUNT := 46
const RANGE := 220.0
const RECYCLE_BEHIND := 12.0
const MIN_SCALE := 1.2
const MAX_SCALE := 4.5
const SPAWN_CLEAR := 14.0
const GLOW_CHANCE := 0.3
const MAX_GLOW_LIGHTS := 5

const GLOW_COLORS := [
	Color(0.35, 1.0, 0.85),
	Color(0.45, 0.8, 1.0),
	Color(0.75, 0.5, 1.0),
	Color(1.0, 0.75, 0.35),
]

var _asteroids: Array[MeshInstance3D] = []
var _spin: Array[Vector3] = []
var _glow_lights := 0


func _ready() -> void:
	for i in COUNT:
		var m := MeshInstance3D.new()
		m.mesh = _create_rock_mesh(6, 9, 0.38)

		var mat := StandardMaterial3D.new()
		mat.roughness = randf_range(0.85, 1.0)
		mat.metallic = 0.05
		if randf() < GLOW_CHANCE:
			var c: Color = GLOW_COLORS[randi() % GLOW_COLORS.size()]
			mat.albedo_color = Color(0.22, 0.26, 0.3)
			mat.emission_enabled = true
			mat.emission = c
			mat.emission_energy_multiplier = randf_range(1.5, 3.0)
			if _glow_lights < MAX_GLOW_LIGHTS:
				_glow_lights += 1
				var light := OmniLight3D.new()
				light.light_color = c
				light.light_energy = 1.6
				light.omni_range = 34.0
				m.add_child(light)
		else:
			var g := randf_range(0.35, 0.6)
			mat.albedo_color = Color(g * 1.05, g, g * randf_range(0.85, 1.0))
		m.material_override = mat

		_respawn(m, Vector3.ZERO, Vector3(0, 0, -1), true)
		add_child(m)
		_asteroids.append(m)
		_spin.append(Vector3(
			randf_range(-0.6, 0.6),
			randf_range(-0.6, 0.6),
			randf_range(-0.6, 0.6)
		))


## 每帧根据飞船位姿循环小行星（落在后方的补充到前方），并自转。
func update(ship_t: Transform3D, delta: float) -> void:
	var center := ship_t.origin
	var fwd := -ship_t.basis.z
	for i in _asteroids.size():
		var m := _asteroids[i]
		var rel := m.position - center
		if rel.dot(fwd) < -RECYCLE_BEHIND or rel.length() > RANGE * 1.6:
			_respawn(m, center, fwd, false)
		else:
			m.rotation += _spin[i] * delta


## 飞船（center）是否撞上任一小行星；半径随小行星体积增大。
func collides(center: Vector3, ship_radius: float) -> bool:
	for m in _asteroids:
		if m.position.distance_to(center) < ship_radius + m.scale.x * 0.9:
			return true
	return false


## 生成不规则岩石网格：在球面上叠加正弦起伏与随机扰动，形成凹凸岩块。
func _create_rock_mesh(rings: int, radial: int, amp: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings + 1):
		var phi := float(r) / rings * PI
		for s in range(radial + 1):
			var theta := float(s) / radial * TAU
			var n := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var d := 1.0 + amp * (
				sin(theta * 3.0 + phi * 2.0) * 0.35
				+ sin(phi * 5.0 - theta) * 0.25
				+ randf_range(-0.35, 0.35)
			)
			st.add_vertex(n * d)
	for r in range(rings):
		for s in range(radial):
			var i0 := r * (radial + 1) + s
			var i1 := i0 + 1
			var i2 := i0 + (radial + 1)
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i3)
	st.generate_normals()
	return st.commit()


func _respawn(m: MeshInstance3D, center: Vector3, fwd: Vector3, initial: bool) -> void:
	var s := randf_range(MIN_SCALE, MAX_SCALE)
	m.scale = Vector3(s, s, s)
	var dir := (fwd + _lateral_unit(fwd) * randf_range(0.2, 0.9)).normalized()
	var dist := RANGE
	if initial:
		dist = randf_range(SPAWN_CLEAR + 4.0, RANGE)
	m.position = center + dir * dist
	m.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))


func _lateral_unit(fwd: Vector3) -> Vector3:
	var up := Vector3.UP
	if absf(fwd.dot(up)) > 0.98:
		up = Vector3.RIGHT
	var right := fwd.cross(up).normalized()
	var real_up := right.cross(fwd).normalized()
	var ang := randf_range(0.0, TAU)
	return (right * cos(ang) + real_up * sin(ang)).normalized()
