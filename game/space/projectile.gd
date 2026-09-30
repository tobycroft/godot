class_name Projectile
extends Node3D
## 弹药：子弹（直线、高射速、低伤害）与导弹（加速 + 有限速率追踪、低射速、高伤害）。
## 由 Weapons 统一创建并每帧调用 step()（返回 false 表示寿命结束），命中判定在 Weapons 里做。

const KIND_BULLET := 0
const KIND_MISSILE := 1

var kind := KIND_BULLET
var velocity := Vector3.ZERO
var damage := 10.0
var life := 2.0
var radius := 0.35
var turn_rate := 0.0  # 0 = 不追踪
var accel := 0.0
var max_speed := 0.0
var target: Asteroid = null
var prev_position := Vector3.ZERO # 上一帧位置：高速子弹用线段判定，避免穿透

var _age := 0.0


func launch(k: int, at: Vector3, vel: Vector3, dmg: float, lf: float, r: float) -> void:
	kind = k
	position = at
	prev_position = at
	velocity = vel
	damage = dmg
	life = lf
	radius = r
	_build()
	_orient()


func step(delta: float) -> bool:
	_age += delta
	if _age >= life:
		return false
	if is_instance_valid(target) and turn_rate > 0.0:
		_home(delta)
	if accel > 0.0:
		var sp := velocity.length()
		velocity = velocity.normalized() * minf(sp + accel * delta, max_speed)
	prev_position = position
	position += velocity * delta
	_orient()
	return true


func _home(delta: float) -> void:
	var desired := (target.position - position).normalized()
	var cur := velocity.normalized()
	var ang := cur.angle_to(desired)
	if ang < 0.001:
		return
	var axis := cur.cross(desired)
	if axis.length_squared() < 1e-6:
		return
	velocity = cur.rotated(axis.normalized(), minf(ang, turn_rate * delta)) * velocity.length()


func _orient() -> void:
	look_at(position + velocity, Vector3.UP)


func _build() -> void:
	if kind == KIND_MISSILE:
		_build_missile()
	else:
		_build_bullet()


func _build_bullet() -> void:
	var mat := _glow_mat(Color(0.45, 0.92, 1.0), 3.0)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.045
	cm.height = 0.95
	cm.radial_segments = 6
	mi.mesh = cm
	mi.rotation.x = PI * 0.5 # 轴转到 Z
	mi.material_override = mat
	add_child(mi)


func _build_missile() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.74, 0.76, 0.8)
	body_mat.metallic = 0.8
	body_mat.roughness = 0.35

	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.10
	cm.bottom_radius = 0.10
	cm.height = 0.72
	cm.radial_segments = 10
	body.mesh = cm
	body.rotation.x = PI * 0.5
	body.material_override = body_mat
	add_child(body)

	var nose := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.015
	nm.bottom_radius = 0.10
	nm.height = 0.26
	nm.radial_segments = 10
	nose.mesh = nm
	nose.rotation.x = -PI * 0.5 # 锥尖朝前(-Z)
	nose.position = Vector3(0.0, 0.0, -0.49)
	nose.material_override = body_mat
	add_child(nose)

	var flame := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.02
	fm.bottom_radius = 0.085
	fm.height = 0.45
	fm.radial_segments = 8
	flame.mesh = fm
	flame.rotation.x = PI * 0.5 # 锥尖朝后(+Z)
	flame.position = Vector3(0.0, 0.0, 0.58)
	flame.material_override = _glow_mat(Color(1.0, 0.68, 0.28), 3.4)
	add_child(flame)


func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m
