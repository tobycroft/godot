class_name Asteroid
extends MeshInstance3D
## 单颗小行星（可复用的类）。
## 外界只需要：var a := Asteroid.new(); add_child(a); a.scatter(中心, 朝向)
## 体型 / 血量 / 外观 / 自转全部在类内部随机，血量按体积分配（越大越硬）。
## 命中用 take_damage()，返回 true 表示被打爆。

const MIN_SCALE := 1.2
const MAX_SCALE := 4.5
const GLOW_CHANCE := 0.3
const HP_BASE := 18.0
const HP_PER_SCALE := 20.0 # 血量 = HP_BASE + 缩放 * HP_PER_SCALE（1.2 号约 42，4.5 号约 108）

const GLOW_COLORS := [
	Color(0.35, 1.0, 0.85),
	Color(0.45, 0.8, 1.0),
	Color(0.75, 0.5, 1.0),
	Color(1.0, 0.75, 0.35),
]

var max_hp := 1.0
var hp := 1.0
var radius := 1.0     # 碰撞半径（已含缩放）
var spin := Vector3.ZERO
var wants_glow := false

var _mat: StandardMaterial3D
var _base_emission := Color(0.0, 0.0, 0.0)
var _base_energy := 0.0

static var _shapes: Array[Mesh] = []


func _ready() -> void:
	_ensure_material()


## 全部外形（首次调用时生成 / 读取磁盘缓存）。
static func shapes() -> Array[Mesh]:
	if _shapes.is_empty():
		_shapes = AsteroidMeshes.get_all()
	return _shapes


## 随机体型、血量、外观，并投放到 center 周围（initial=true 时铺满整个场）。
## far/near 由 AsteroidField 传入，保证与场地的循环范围一致。
func scatter(center: Vector3, fwd: Vector3, initial: bool = false,
		far := 220.0, near := 18.0) -> void:
	_ensure_material()

	var s := randf_range(MIN_SCALE, MAX_SCALE)
	scale = Vector3(s, s, s)
	radius = s * 0.9
	max_hp = roundf(HP_BASE + s * HP_PER_SCALE)
	hp = max_hp
	spin = Vector3(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))

	var pool := shapes()
	mesh = pool[randi() % pool.size()]
	wants_glow = randf() < GLOW_CHANCE
	_apply_look()

	var dir := (fwd + _lateral_unit(fwd) * randf_range(0.2, 0.9)).normalized()
	position = center + dir * (randf_range(near, far) if initial else far)
	rotation = Vector3(randf_range(0.0, TAU), randf_range(0.0, TAU), randf_range(0.0, TAU))


## 扣血；返回 true 表示这一击把它打爆了。
func take_damage(amount: float) -> bool:
	hp = maxf(hp - amount, 0.0)
	_flash()
	return hp <= 0.0


func health_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


## 是否带辐射点光源（由 AsteroidField 控制总数）。
func set_glow_light(on: bool) -> void:
	if on:
		if not has_node("Glow"):
			var l := OmniLight3D.new()
			l.name = "Glow"
			l.light_color = _base_emission
			l.light_energy = 1.6
			l.omni_range = 34.0
			add_child(l)
	elif has_node("Glow"):
		get_node("Glow").queue_free()


func _ensure_material() -> void:
	if _mat != null:
		return
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	material_override = _mat


func _apply_look() -> void:
	_mat.roughness = randf_range(0.85, 1.0)
	_mat.metallic = 0.05
	if wants_glow:
		var c: Color = GLOW_COLORS[randi() % GLOW_COLORS.size()]
		_mat.albedo_color = Color(0.32, 0.34, 0.38)
		_mat.emission_enabled = true
		_mat.emission = c
		_mat.emission_energy_multiplier = randf_range(1.5, 3.0)
	else:
		var g := randf_range(0.5, 0.78)
		_mat.albedo_color = Color(g * 1.04, g, g * randf_range(0.86, 1.0))
		_mat.emission_enabled = false
		_mat.emission = Color(0.0, 0.0, 0.0)
		_mat.emission_energy_multiplier = 1.0
	_base_emission = _mat.emission
	_base_energy = _mat.emission_energy_multiplier if wants_glow else 0.0


## 被命中时白热一下再恢复本色。
func _flash() -> void:
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.78, 0.5)
	_mat.emission_energy_multiplier = 2.6
	var tw := create_tween()
	tw.tween_property(_mat, "emission_energy_multiplier", _base_energy, 0.25)
	tw.tween_callback(_restore_emission)


func _restore_emission() -> void:
	_mat.emission = _base_emission
	_mat.emission_enabled = wants_glow


func _lateral_unit(fwd: Vector3) -> Vector3:
	var up := Vector3.UP
	if absf(fwd.dot(up)) > 0.98:
		up = Vector3.RIGHT
	var right := fwd.cross(up).normalized()
	var real_up := right.cross(fwd).normalized()
	var ang := randf_range(0.0, TAU)
	return (right * cos(ang) + real_up * sin(ang)).normalized()
