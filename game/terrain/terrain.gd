extends Node3D
## Terrain3D 拟真地形场景：代码生成 1km² 地图（平原、山地、湖泊、土路）。
## 草地/岩石使用 demo 真实照片纹理，路面/沙地程序化生成；树木岩石程序化散布。
## 玩家复用 demo Player：WASD 移动 / 鼠标视角 / V 第一人称 / Esc 暂停（全局 Pause 接管）。

const WATER_LEVEL := 2.0
const MAP_SIZE := 1024.0 # 单区域 1024m，世界范围 [0,1024)²（region 边界必须对齐）
const LAKE_CENTER := Vector2(215.0, 800.0) # 世界坐标 x,z
const LAKE_OUTER := 150.0
const LAKE_INNER := 70.0
const LAKE_DEPTH := -7.0
const PINE_COUNT := 260
const LEAF_COUNT := 150
const ROCK_COUNT := 30
const ROCK_SCENES: Array[PackedScene] = [
	preload("res://demo/assets/models/RockA.tscn"),
	preload("res://demo/assets/models/RockB.tscn"),
	preload("res://demo/assets/models/RockC.tscn"),
]

@onready var player: CharacterBody3D = $Player
@onready var loading_label: Label = $UI/Loading

var _terrain: Terrain3D
var _plain_noise := FastNoiseLite.new()
var _mountain_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _cluster_noise := FastNoiseLite.new()


func _ready() -> void:
	($Sun as DirectionalLight3D).rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	_init_noise()
	await get_tree().process_frame # 让加载提示先渲染出来
	await _build_terrain()
	_place_player()
	_spawn_trees()
	_spawn_rocks()
	loading_label.visible = false


func _init_noise() -> void:
	_plain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_plain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_plain_noise.fractal_octaves = 4
	_plain_noise.frequency = 0.004
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mountain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_mountain_noise.fractal_octaves = 3
	_mountain_noise.frequency = 0.0011
	_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge_noise.fractal_octaves = 4
	_ridge_noise.frequency = 0.006
	_cluster_noise.frequency = 0.015


# ---- 地形形状 ----

func _road_x(wz: float) -> float:
	return 512.0 + 90.0 * sin(wz * 0.008) + 50.0 * sin(wz * 0.019 + 2.0)


func _plain_height(wx: float, wz: float) -> float:
	return 8.0 + 6.0 * _plain_noise.get_noise_2d(wx, wz)


func _height_at(wx: float, wz: float) -> float:
	var h := _plain_height(wx, wz)
	# 山地：远离道路走廊的区域隆起
	var corridor := smoothstep(70.0, 220.0, absf(wx - _road_x(wz)))
	var m := smoothstep(0.4, 0.75, 0.5 + 0.5 * _mountain_noise.get_noise_2d(wx, wz)) * corridor
	if m > 0.001:
		var r := 0.5 + 0.5 * _ridge_noise.get_noise_2d(wx, wz)
		h += m * pow(r, 1.4) * 88.0
	# 湖盆
	var d := Vector2(wx - LAKE_CENTER.x, wz - LAKE_CENTER.y).length()
	var t := 1.0 - smoothstep(LAKE_INNER, LAKE_OUTER, d)
	if t > 0.0:
		h = lerpf(h, LAKE_DEPTH, t)
	return h


# ---- Terrain3D 构建 ----

func _build_terrain() -> void:
	_terrain = Terrain3D.new()
	_terrain.name = "Terrain3D"
	add_child(_terrain)
	_terrain.region_size = 1024

	# 纹理资产：0 草地 / 1 土路 / 2 沙地 / 3 岩石（最后一个供 auto_shader 陡坡混合）
	_terrain.assets = Terrain3DAssets.new()
	_terrain.assets.set_texture(0, _real_texture("Grass", "ground037", 0.35))
	_terrain.assets.set_texture(1, await _noise_texture("Road",
			Color.from_hsv(28.0 / 360.0, 0.38, 0.30), Color.from_hsv(33.0 / 360.0, 0.35, 0.42), 0.4))
	_terrain.assets.set_texture(2, await _noise_texture("Sand",
			Color.from_hsv(43.0 / 360.0, 0.28, 0.60), Color.from_hsv(48.0 / 360.0, 0.24, 0.72), 0.35))
	_terrain.assets.set_texture(3, _real_texture("Rock", "rock023", 0.3))

	# 材质：按坡度自动把陡坡混到岩石纹理
	_terrain.material.world_background = Terrain3DMaterial.WorldBackground.NONE
	_terrain.material.auto_shader = true
	_terrain.material.set_shader_param("auto_slope", 30.0)
	_terrain.material.set_shader_param("blend_sharpness", 0.97)

	var maps := _generate_maps()
	_terrain.data.import_images([maps[0], null, maps[1]], Vector3(0.0, 0.0, 0.0), 0.0, 1.0)

	# 运行时动态碰撞（跟随相机生成碰撞体）
	_terrain.collision_mode = Terrain3DCollision.CollisionMode.DYNAMIC_GAME


func _real_texture(asset_name: String, base: String, uv: float) -> Terrain3DTextureAsset:
	var ta := Terrain3DTextureAsset.new()
	ta.name = asset_name
	ta.albedo_texture = _uncompressed(load("res://demo/assets/textures/%s_alb_ht.png" % base))
	ta.normal_texture = _uncompressed(load("res://demo/assets/textures/%s_nrm_rgh.png" % base))
	ta.uv_scale = uv
	return ta


# Terrain3D 要求所有资产纹理尺寸/格式一致：统一解压成未压缩格式
func _uncompressed(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# 程序化纹理资产：噪声渐变 albedo（含高度通道）+ 噪声法线（含粗糙度通道）
# 尺寸/格式自动对齐 grass 纹理（Terrain3D 要求所有资产纹理一致）
func _noise_texture(asset_name: String, c0: Color, c1: Color, uv: float) -> Terrain3DTextureAsset:
	var ref_img: Image = _uncompressed(load("res://demo/assets/textures/ground037_alb_ht.png")).get_image()
	var tex_size := ref_img.get_width()
	var tex_fmt := ref_img.get_format()

	var grad := Gradient.new()
	grad.set_color(0, c0)
	grad.set_color(1, c1)
	var fnl := FastNoiseLite.new()
	fnl.frequency = 0.004

	var alb_tex := NoiseTexture2D.new()
	alb_tex.width = tex_size
	alb_tex.height = tex_size
	alb_tex.seamless = true
	alb_tex.noise = fnl
	alb_tex.color_ramp = grad
	await alb_tex.changed
	var alb_img := alb_tex.get_image()
	for y in alb_img.get_height():
		for x in alb_img.get_width():
			var clr := alb_img.get_pixel(x, y)
			clr.a = clr.v # 噪声作为高度通道
			alb_img.set_pixel(x, y, clr)
	alb_img.convert(tex_fmt)
	alb_img.generate_mipmaps()
	var albedo := ImageTexture.create_from_image(alb_img)

	var nrm_tex := NoiseTexture2D.new()
	nrm_tex.width = tex_size
	nrm_tex.height = tex_size
	nrm_tex.seamless = true
	nrm_tex.as_normal_map = true
	nrm_tex.noise = fnl
	await nrm_tex.changed
	var nrm_img := nrm_tex.get_image()
	for y in nrm_img.get_height():
		for x in nrm_img.get_width():
			var px := nrm_img.get_pixel(x, y)
			px.a = 0.8 # 粗糙度
			nrm_img.set_pixel(x, y, px)
	nrm_img.convert(tex_fmt)
	nrm_img.generate_mipmaps()
	var normal := ImageTexture.create_from_image(nrm_img)

	var ta := Terrain3DTextureAsset.new()
	ta.name = asset_name
	ta.albedo_texture = albedo
	ta.normal_texture = normal
	ta.uv_scale = uv
	return ta


# 高度图（米）+ 控制图（纹理 id），一次导入
func _generate_maps() -> Array:
	var size := int(MAP_SIZE)
	var h_img := Image.create_empty(size, size, false, Image.FORMAT_RF)
	var c_img := Image.create_empty(size, size, false, Image.FORMAT_RG8)
	for iz in size:
		var wz := float(iz)
		var road_px := _road_x(wz)
		var road_h := maxf(_plain_height(_road_x(wz), wz), WATER_LEVEL + 1.5) # 路面不低于水面
		for ix in size:
			var wx := float(ix)
			var h := _height_at(wx, wz)
			var d := absf(float(ix) - road_px)
			h = lerpf(road_h, h, smoothstep(4.0, 11.0, d)) # 路基压平
			h_img.set_pixel(ix, iz, Color(h, 0.0, 0.0, 1.0))
			var id := 0
			if d < 4.5 or (d < 7.5 and randf() < (7.5 - d) / 3.0):
				id = 1 # 土路（边缘抖动过渡）
			elif h < WATER_LEVEL + 1.8:
				id = 2 # 水边沙地
			elif h > 55.0 and randf() < clampf((h - 55.0) / 18.0, 0.0, 1.0):
				id = 3 # 高山裸岩（抖动）
			c_img.set_pixel(ix, iz, Color(id / 255.0, 0.0, 0.0, 1.0))
	return [h_img, c_img]


# ---- 玩家与植被 ----

func _place_player() -> void:
	var wz := 960.0
	var x := _road_x(wz)
	player.position = Vector3(x, _terrain.data.get_height(Vector3(x, 0.0, wz)) + 1.0, wz)


func _spawn_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260930

	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.30, 0.21, 0.13)
	bark.roughness = 1.0
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 2.4
	trunk_mesh.radial_segments = 7
	trunk_mesh.material = bark

	var pine := StandardMaterial3D.new()
	pine.albedo_color = Color(0.10, 0.26, 0.10)
	pine.roughness = 0.95
	var pine_mesh := CylinderMesh.new()
	pine_mesh.top_radius = 0.05
	pine_mesh.bottom_radius = 1.35
	pine_mesh.height = 5.2
	pine_mesh.radial_segments = 9
	pine_mesh.material = pine

	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.18, 0.36, 0.12)
	leaf.roughness = 0.9
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 1.7
	leaf_mesh.height = 3.4
	leaf_mesh.radial_segments = 12
	leaf_mesh.rings = 8
	leaf_mesh.material = leaf

	var trunk_xf: Array[Transform3D] = []
	var pine_xf: Array[Transform3D] = []
	var leaf_xf: Array[Transform3D] = []
	var tries := 0
	while (pine_xf.size() < PINE_COUNT or leaf_xf.size() < LEAF_COUNT) and tries < 12000:
		tries += 1
		var x := rng.randf_range(15.0, MAP_SIZE - 15.0)
		var z := rng.randf_range(15.0, MAP_SIZE - 15.0)
		if absf(x - _road_x(z)) < 9.0: # 避开道路
			continue
		if _cluster_noise.get_noise_2d(x, z) < -0.05: # 成片分布
			continue
		var h := _terrain.data.get_height(Vector3(x, 0.0, z))
		if h < WATER_LEVEL + 1.2 or h > 48.0: # 避开水面与高山
			continue
		var s := rng.randf_range(0.7, 1.5)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
				Vector3(s, s * rng.randf_range(0.9, 1.2), s))
		trunk_xf.append(Transform3D(basis, Vector3(x, h + 1.2 * s, z)))
		if pine_xf.size() < PINE_COUNT and (leaf_xf.size() >= LEAF_COUNT or rng.randf() < 0.62):
			pine_xf.append(Transform3D(basis, Vector3(x, h + 3.6 * s, z)))
		else:
			leaf_xf.append(Transform3D(basis, Vector3(x, h + 2.7 * s, z)))
	_add_multimesh(trunk_mesh, trunk_xf)
	_add_multimesh(pine_mesh, pine_xf)
	_add_multimesh(leaf_mesh, leaf_xf)


func _add_multimesh(mesh: Mesh, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _spawn_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var placed := 0
	var tries := 0
	while placed < ROCK_COUNT and tries < 3000:
		tries += 1
		var x := rng.randf_range(20.0, MAP_SIZE - 20.0)
		var z := rng.randf_range(20.0, MAP_SIZE - 20.0)
		if absf(x - _road_x(z)) < 7.0:
			continue
		var h := _terrain.data.get_height(Vector3(x, 0.0, z))
		if h < WATER_LEVEL + 0.6 or h > 95.0:
			continue
		var rock: Node3D = ROCK_SCENES[rng.randi_range(0, ROCK_SCENES.size() - 1)].instantiate()
		var s := rng.randf_range(0.5, 2.4)
		rock.scale = Vector3(s, s * rng.randf_range(0.8, 1.2), s)
		rock.rotation = Vector3(0.0, rng.randf_range(0.0, TAU), rng.randf_range(-0.08, 0.08))
		rock.position = Vector3(x, h + 0.15 * s, z)
		add_child(rock)
		placed += 1
