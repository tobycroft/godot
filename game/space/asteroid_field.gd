extends Node3D
## 小行星场：在飞船周围的体积内维护一组小行星，随飞船飞行循环补充到前方，
## 随机的位置 / 大小 / 自转让飞行有穿梭移动感；并提供碰撞检测。

const COUNT := 46
const RANGE := 220.0
const RECYCLE_BEHIND := 12.0
const MIN_SCALE := 1.2
const MAX_SCALE := 4.5
const SPAWN_CLEAR := 14.0

var _asteroids: Array[MeshInstance3D] = []
var _spin: Array[Vector3] = []


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.52, 0.5)
	mat.roughness = 0.95
	mat.metallic = 0.0

	for i in COUNT:
		var m := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 10
		sphere.rings = 6
		m.mesh = sphere
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
