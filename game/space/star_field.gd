extends Node3D
## 星空：用 MultiMesh 在体积内散布大量发光星点，向 +Z 流动并循环，
## 配合飞船前进产生穿越星空的高速飞行感。

const COUNT := 1400
const HALF_X := 130.0
const HALF_Y := 90.0
const FAR_Z := 22.0
const RANGE_Z := 540.0

var _mm: MultiMeshInstance3D


func _ready() -> void:
	_mm = MultiMeshInstance3D.new()
	add_child(_mm)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = COUNT
	_mm.multimesh = mm

	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.5, 0.5, 0.5)

	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color(0, 0, 0)
	star_mat.emission_enabled = true
	star_mat.emission = Color(1, 1, 1)
	star_mat.emission_energy_multiplier = 2.0
	_mm.material_override = star_mat

	for i in COUNT:
		var s := randf_range(0.25, 1.1)
		var t := Transform3D(Basis(), Vector3(
			randf_range(-HALF_X, HALF_X),
			randf_range(-HALF_Y, HALF_Y),
			randf_range(FAR_Z - RANGE_Z, FAR_Z)
		))
		t = t.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, t)


func scroll(dz: float) -> void:
	var mm := _mm.multimesh
	for i in mm.instance_count:
		var t := mm.get_instance_transform(i)
		t.origin.z += dz
		if t.origin.z > FAR_Z:
			t.origin.z -= RANGE_Z
			t.origin.x = randf_range(-HALF_X, HALF_X)
			t.origin.y = randf_range(-HALF_Y, HALF_Y)
		mm.set_instance_transform(i, t)
