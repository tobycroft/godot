extends Control
## 主菜单脚本：2D 入口暂留，Running Man 入口进入三维跑酷场景。
## 元素不再瞬切显示，而是在 _ready 里先藏好、再播放入场动画。

const INTRO_STAGGER := 0.09  # 按钮逐个入场的时间间隔
const SLIDE := 26.0          # 按钮入场时从下方滑入的距离

const LOADING_SCENE := preload("res://app/loading/loading.tscn")

@onready var btn_2d: Button = $Start2DButton
@onready var btn_running_man: Button = $StartRunningManButton
@onready var btn_space: Button = $StartSpaceButton
@onready var btn_terrain: Button = $StartTerrainButton
@onready var btn_settings: Button = $SettingsButton
@onready var btn_quit: Button = $QuitButton
@onready var background: Control = $Background
@onready var title: Control = $Title


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	btn_running_man.pressed.connect(_on_running_man_pressed)
	btn_space.pressed.connect(_on_space_pressed)
	btn_terrain.pressed.connect(_on_terrain_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	# 2D 入口先留着，后续接入 2D 场景
	btn_2d.pressed.connect(_on_2d_pressed)

	# 先把元素藏起来并稍微下移，避免首帧闪现，再播放入场动画
	background.modulate = Color(1, 1, 1, 0)
	title.modulate = Color(1, 1, 1, 0)
	title.offset_top += 18.0
	title.offset_bottom += 18.0
	var items := _menu_items()
	for it in items:
		it.modulate = Color(1, 1, 1, 0)
		it.offset_top += SLIDE
		it.offset_bottom += SLIDE

	await get_tree().process_frame
	_play_intro()


## 主菜单上的全部可点击 / 可入场元素，按入场顺序列出。
func _menu_items() -> Array[Control]:
	return [btn_2d, btn_running_man, btn_space, btn_terrain, btn_settings, btn_quit]


func _play_intro() -> void:
	background.pivot_offset = background.size * 0.5

	var tw := create_tween().set_parallel(true)
	# 背景渐显
	tw.tween_property(background, "modulate", Color(1, 1, 1, 1), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 标题先轻轻落位
	tw.tween_property(title, "modulate", Color(1, 1, 1, 1), 0.5).set_delay(0.15)
	tw.tween_property(title, "offset_top", title.offset_top - 18.0, 0.55).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "offset_bottom", title.offset_bottom - 18.0, 0.55).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 按钮依次从下方弹入
	var items := _menu_items()
	for i in items.size():
		var it := items[i] as Control
		var delay := 0.32 + i * INTRO_STAGGER
		tw.tween_property(it, "modulate", Color(1, 1, 1, 1), 0.4).set_delay(delay)
		tw.tween_property(it, "offset_top", it.offset_top - SLIDE, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(it, "offset_bottom", it.offset_bottom - SLIDE, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 背景缓慢推拉（ken-burns 式），让画面更有"活着"的感觉
	var drift := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(background, "scale", Vector2(1.04, 1.04), 16.0)
	drift.tween_property(background, "scale", Vector2(1.0, 1.0), 16.0)


func _on_2d_pressed() -> void:
	# TODO: 接入 2D 场景
	pass


func _on_running_man_pressed() -> void:
	_goto_level("res://game/running_man/runner/runner.tscn")


func _on_space_pressed() -> void:
	_goto_level("res://game/space/space.tscn")


func _on_terrain_pressed() -> void:
	_goto_level("res://game/terrain/terrain.tscn")


## 先叠一层加载界面（后台线程加载关卡场景），加载完成后再切换过去。
## 关卡（地图）资源较重，直接 change_scene_to_file 会卡住主线程，
## 用 loading 过渡既避免卡顿也避免白屏。
func _goto_level(path: String) -> void:
	var loading := LOADING_SCENE.instantiate() as Control
	loading.target_path = path
	add_child(loading)


func _on_settings_pressed() -> void:
	# TODO: 接入设置面板
	pass


func _on_quit_pressed() -> void:
	get_tree().quit()
