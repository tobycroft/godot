class_name AsteroidField
extends Node3D
## 小行星场：只负责"批量生成 + 循环补充 + 查询 / 结算"，
## 单颗小行星的一切行为都封装在 Asteroid 类里，新增小行星直接 new Asteroid 即可。

const COUNT := 46
const RANGE := 220.0
const RECYCLE_BEHIND := 12.0
const SPAWN_CLEAR := 14.0
const MAX_GLOW_LIGHTS := 5

var _asteroids: Array[Asteroid] = []
var _center := Vector3.ZERO
var _fwd := Vector3(0.0, 0.0, -1.0)


func _ready() -> void:
	Asteroid.shapes() # 提前触发外形生成 / 读缓存
	for i in COUNT:
		var a := Asteroid.new()
		a.scatter(_center, _fwd, true, RANGE, SPAWN_CLEAR + 4.0)
		add_child(a)
		a.set_glow_light(a.wants_glow and _glow_count() < MAX_GLOW_LIGHTS)
		_asteroids.append(a)


## 每帧根据飞船位姿循环小行星（落在后方的补充到前方），并自转。
func update(ship_t: Transform3D, delta: float) -> void:
	_center = ship_t.origin
	_fwd = -ship_t.basis.z
	for a in _asteroids:
		var rel := a.position - _center
		if rel.dot(_fwd) < -RECYCLE_BEHIND or rel.length() > RANGE * 1.6:
			_recycle(a)
		else:
			a.rotation += a.spin * delta


func asteroids() -> Array[Asteroid]:
	return _asteroids


## 飞船（center）是否撞上小行星；返回被撞的那颗（没撞到返回 null）。
func hit_test(center: Vector3, ship_radius: float) -> Asteroid:
	for a in _asteroids:
		if a.position.distance_to(center) < ship_radius + a.radius:
			return a
	return null


## 某个点是否落在小行星体内（静态判定）。
func hit_at(pos: Vector3, radius: float) -> Asteroid:
	for a in _asteroids:
		if a.position.distance_to(pos) < radius + a.radius:
			return a
	return null


## 线段判定：高速子弹一帧能走好几米，用"上一帧位置 -> 当前位置"这条线段来测，避免穿透。
func hit_segment(from: Vector3, to: Vector3, radius: float) -> Asteroid:
	var seg := to - from
	var len2 := seg.length_squared()
	for a in _asteroids:
		var rel := a.position - from
		var k := 0.0
		if len2 > 0.0001:
			k = clampf(rel.dot(seg) / len2, 0.0, 1.0)
		if (from + seg * k).distance_to(a.position) <= radius + a.radius:
			return a
	return null


## 结算伤害：命中溅火花，打爆则回收并炸开。
func damage(a: Asteroid, amount: float) -> void:
	if a.take_damage(amount):
		destroy(a, 0.5 + a.scale.x * 0.3)
	else:
		Explosion.spawn(get_parent() as Node3D, a.position, 0.16)


## 被打爆：重新投放并触发爆炸。
func destroy(a: Asteroid, power: float) -> void:
	var at: Vector3 = a.position
	_recycle(a)
	Explosion.spawn(get_parent() as Node3D, at, power)


## 飞船撞击后把这颗挪走（不扣小行星血量，撞机是飞船吃亏）。
func recycle(a: Asteroid) -> void:
	_recycle(a)


func _recycle(a: Asteroid) -> void:
	a.scatter(_center, _fwd, false, RANGE, SPAWN_CLEAR + 4.0)
	a.set_glow_light(a.wants_glow and _glow_count() < MAX_GLOW_LIGHTS)


func _glow_count() -> int:
	var n := 0
	for a in _asteroids:
		if a.has_node("Glow"):
			n += 1
	return n
