extends Node3D
## 小行星场：在飞船前方体积内维护一组小行星，向 +Z 流动并循环，
## 随机的位置 / 大小 / 自转让飞行过程更有穿梭与移动感。

const COUNT := 36
const HALF_X := 70.0
const HALF_Y := 45.0
const FAR_Z := 30.0
const RANGE_Z := 360.0
const MIN_SCALE := 1.2
const MAX_SCALE := 4.5

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
		_spawn(m, randf_range(FAR_Z - RANGE_Z, FAR_Z))
		add_child(m)
		_asteroids.append(m)
		_spin.append(Vector3(
			randf_range(-0.6, 0.6),
			randf_range(-0.6, 0.6),
			randf_range(-0.6, 0.6)
		))


func _spawn(m: MeshInstance3D, z: float) -> void:
	var s := randf_range(MIN_SCALE, MAX_SCALE)
	m.scale = Vector3(s, s, s)
	m.position = Vector3(
		randf_range(-HALF_X, HALF_X),
		randf_range(-HALF_Y, HALF_Y),
		z
	)
	m.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))


func scroll(dz: float, delta: float) -> void:
	for i in _asteroids.size():
		var m := _asteroids[i]
		m.position.z += dz
		m.rotation += _spin[i] * delta
		if m.position.z > FAR_Z:
			_spawn(m, m.position.z - RANGE_Z)
