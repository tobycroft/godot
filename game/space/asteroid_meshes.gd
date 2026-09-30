class_name AsteroidMeshes
extends RefCounted
## 小行星外形库。
## 首次调用时程序化生成若干种岩石网格，并缓存成 .res 资源放在
## res://game/space/meshes/ 下（rock_00.res ...），之后直接 load 复用；
## 想换外形时删掉该目录里的文件、或把美术做好的网格按同名放进去即可。

const DIR := "res://game/space/meshes/"
const VARIANTS := 8
const RINGS := 30
const RADIAL := 48

const FILE_PATTERN := "rock_%02d.res"


static func get_all() -> Array[Mesh]:
	var out: Array[Mesh] = []
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
	for i in VARIANTS:
		var path := DIR + (FILE_PATTERN % i)
		var m: Mesh = null
		if ResourceLoader.exists(path):
			m = load(path) as Mesh
		if m == null:
			m = _build(1000 + i * 137)
			if ResourceSaver.save(m, path) != OK:
				push_warning("小行星网格未能缓存到磁盘（不影响运行）: %s" % path)
		out.append(m)
	return out


## 生成岩石：球面基底 + 多层噪声起伏 + 陨石坑（凹陷 + 坑缘），顶点色做斑驳。
static func _build(vseed: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = vseed
	noise.frequency = 0.6
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.45
	noise.fractal_lacunarity = 2.1

	var rng := RandomNumberGenerator.new()
	rng.seed = vseed

	var crater_dirs: Array[Vector3] = []
	var crater_ang: Array[float] = []
	var crater_depth: Array[float] = []
	for k in rng.randi_range(5, 9):
		crater_dirs.append(_rand_unit(rng))
		crater_ang.append(rng.randf_range(0.18, 0.55))
		crater_depth.append(rng.randf_range(0.08, 0.22))

	var s := MeshSurf.new()
	var rows: Array = []
	for r in RINGS + 1:
		var phi := float(r) / float(RINGS) * PI
		var row := PackedInt32Array()
		row.resize(RADIAL)
		for j in RADIAL:
			var theta := float(j) / float(RADIAL) * TAU
			var n := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var d := 1.0
			d += 0.26 * noise.get_noise_3dv(n * 1.9)
			d += 0.11 * noise.get_noise_3dv(n * 4.7)
			d += 0.045 * noise.get_noise_3dv(n * 11.0)
			for c in crater_dirs.size():
				var a := n.angle_to(crater_dirs[c])
				var ra := crater_ang[c]
				if a < ra:
					var t := a / ra
					d -= crater_depth[c] * pow(cos(t * PI * 0.5), 1.5)
				elif a < ra * 1.5:
					d += crater_depth[c] * 0.3 * (1.0 - (a - ra) / (ra * 0.5))
			var shade := 0.6 + 0.4 * clampf(
				0.5 + 0.6 * noise.get_noise_3dv(n * 3.1 + Vector3(19.0, 7.0, 3.0)), 0.0, 1.0)
			row[j] = s.v(n * d, Color(shade, shade * 0.97, shade * 0.9))
		rows.append(row)
	for r in RINGS:
		var r0 := rows[r] as PackedInt32Array
		var r1 := rows[r + 1] as PackedInt32Array
		for j in RADIAL:
			var j2 := (j + 1) % RADIAL # 首尾相接，避免接缝处法线断裂
			s.quad(r0[j], r0[j2], r1[j2], r1[j])
	return s.commit()


static func _rand_unit(rng: RandomNumberGenerator) -> Vector3:
	var p := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
	if p.length_squared() < 0.001:
		p = Vector3.UP
	return p.normalized()
