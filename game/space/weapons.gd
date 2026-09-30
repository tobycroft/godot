class_name Weapons
extends Node3D
## 武器系统：C 键机炮（子弹），空格键导弹（自动锁定前方最近的小行星）。
## 弹药初速叠加飞船速度，命中后由 AsteroidField 结算伤害（爆炸/回收都走 Asteroid 类）。

const BULLET_SPEED := 150.0
const BULLET_DAMAGE := 10.0
const BULLET_COOLDOWN := 0.1
const BULLET_LIFE := 2.0
const BULLET_RADIUS := 0.35
const BULLET_SPREAD := 0.012
const BULLET_CONVERGE := 70.0 # 两翼机炮的交汇距离：不交汇的话打准星中心会偏

const MISSILE_SPEED := 55.0
const MISSILE_MAX_SPEED := 135.0
const MISSILE_ACCEL := 75.0
const MISSILE_DAMAGE := 55.0
const MISSILE_COOLDOWN := 0.8
const MISSILE_LIFE := 5.0
const MISSILE_RADIUS := 0.5
const MISSILE_TURN := 2.2

const LOCK_RANGE := 300.0
const LOCK_CONE := 0.8 # 锁定锥：dot(机头方向, 目标方向) 下限，约 ±37°

@onready var ship: Ship = $"../Ship"
@onready var field: AsteroidField = $"../AsteroidField"

var _live: Array[Projectile] = []
var _bullet_cd := 0.0
var _missile_cd := 0.0
var _side := 1.0
var disabled := false # 撞毁后停火，但已在飞的弹药继续飞完


func _process(delta: float) -> void:
	if not disabled:
		_bullet_cd = maxf(_bullet_cd - delta, 0.0)
		_missile_cd = maxf(_missile_cd - delta, 0.0)
		if Input.is_key_pressed(KEY_C) and _bullet_cd <= 0.0:
			_fire_bullet()
		if Input.is_key_pressed(KEY_SPACE) and _missile_cd <= 0.0:
			_fire_missile()
	_update(delta)


func set_disabled(v: bool) -> void:
	disabled = v


## 供外部（脚本 / UI / 手柄映射）直接调用的发射接口，自带射速限制。
func fire_bullet() -> void:
	if _bullet_cd > 0.0:
		return
	_fire_bullet()


func fire_missile() -> void:
	if _missile_cd > 0.0:
		return
	_fire_missile()


func _fire_bullet() -> void:
	_bullet_cd = BULLET_COOLDOWN
	_side *= -1.0
	var t := ship.global_transform
	var origin: Vector3 = t * Vector3(1.85 * _side, 0.10, -0.35)
	var vel := ship.get_velocity() + _aim_dir(t, origin) * BULLET_SPEED
	_spawn(Projectile.KIND_BULLET, origin, vel, BULLET_DAMAGE, BULLET_LIFE, BULLET_RADIUS)


func _fire_missile() -> void:
	_missile_cd = MISSILE_COOLDOWN
	_side *= -1.0
	var t := ship.global_transform
	var origin: Vector3 = t * Vector3(1.15 * _side, -0.14, 0.15)
	var vel := ship.get_velocity() + (-t.basis.z) * MISSILE_SPEED
	var p := _spawn(Projectile.KIND_MISSILE, origin, vel, MISSILE_DAMAGE, MISSILE_LIFE, MISSILE_RADIUS)
	p.accel = MISSILE_ACCEL
	p.max_speed = MISSILE_MAX_SPEED + ship.get_velocity().length()
	p.turn_rate = MISSILE_TURN
	p.target = _lock(t)


func _spawn(kind: int, at: Vector3, vel: Vector3, dmg: float, life: float, r: float) -> Projectile:
	var p := Projectile.new()
	add_child(p)
	p.launch(kind, at, vel, dmg, life, r)
	_live.append(p)
	return p


func _update(delta: float) -> void:
	for i in range(_live.size() - 1, -1, -1):
		var p := _live[i]
		if not is_instance_valid(p) or not p.step(delta):
			if is_instance_valid(p):
				p.queue_free()
			_live.remove_at(i)
			continue
		var hit := field.hit_segment(p.prev_position, p.position, p.radius)
		if hit != null:
			field.damage(hit, p.damage)
			p.queue_free()
			_live.remove_at(i)


## 机炮射线：从炮口指向机头前方 CONVERGE 米处的交汇点，再加一点散布
func _aim_dir(t: Transform3D, origin: Vector3) -> Vector3:
	var aim := t.origin + (-t.basis.z) * BULLET_CONVERGE
	var dir := (aim - origin).normalized()
	dir = dir.rotated(t.basis.x, randf_range(-BULLET_SPREAD, BULLET_SPREAD))
	dir = dir.rotated(t.basis.y, randf_range(-BULLET_SPREAD, BULLET_SPREAD))
	return dir.normalized()


## 锁定：正前方锥内、越近越优先
func _lock(t: Transform3D) -> Asteroid:
	var best: Asteroid = null
	var best_score := -2.0
	var fwd := -t.basis.z
	for a in field.asteroids():
		var rel := a.position - t.origin
		var d := rel.length()
		if d < 1.0 or d > LOCK_RANGE:
			continue
		var dot := rel.dot(fwd) / d
		if dot < LOCK_CONE:
			continue
		var score := dot * 2.0 - d / LOCK_RANGE
		if score > best_score:
			best_score = score
			best = a
	return best
