extends Node3D
## 星空：MultiMesh 在飞船周围的体积内散布大量发光星点，
## 随飞船朝任意方向飞行而循环补充到前方，营造星空流动感。

const COUNT := 2200
const RANGE := 400.0
const RECYCLE_BEHIND := 15.0

var _mm: MultiMeshInstance3D


func _ready() -> void:
	_mm = MultiMeshInstance3D.new()
	add_child(_mm)

	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.5, 0.5, 0.5)

	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color(0, 0, 0)
	star_mat.emission_enabled = true
	star_mat.emission = Color(1, 1, 1)
	star_mat.emission_energy_multiplier = 2.0

	var mm := MultiMesh.new()
	mm.mesh = star_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = COUNT
	_mm.multimesh = mm
	_mm.material_override = star_mat

	for i in COUNT:
		var s := randf_range(0.25, 1.1)
		var p := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
		if p.length() < 0.001:
			p = Vector3(1, 0, 0)
		p = p.normalized() * randf_range(0.0, RANGE)
		var t := Transform3D(Basis(), p).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, t)


## 每帧根据飞船位姿循环星点：落在飞船后方的星点补充到前方半球。
func update(ship_t: Transform3D, _delta: float) -> void:
	var center := ship_t.origin
	var fwd := -ship_t.basis.z
	var mm := _mm.multimesh
	for i in mm.instance_count:
		var t := mm.get_instance_transform(i)
		if t.origin.distance_to(center) > RANGE or t.origin.dot(fwd) < -RECYCLE_BEHIND:
			var dir := (fwd + _lateral_unit(fwd) * randf_range(0.2, 0.9)).normalized()
			t.origin = center + dir * RANGE
		mm.set_instance_transform(i, t)


func _lateral_unit(fwd: Vector3) -> Vector3:
	var up := Vector3.UP
	if absf(fwd.dot(up)) > 0.98:
		up = Vector3.RIGHT
	var right := fwd.cross(up).normalized()
	var real_up := right.cross(fwd).normalized()
	var ang := randf_range(0.0, TAU)
	return (right * cos(ang) + real_up * sin(ang)).normalized()
