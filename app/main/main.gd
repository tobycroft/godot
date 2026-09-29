extends Control
## 主菜单脚本：2D 入口暂留，Running Man 入口进入三维跑酷场景。

@onready var btn_2d: Button = $Start2DButton
@onready var btn_running_man: Button = $StartRunningManButton
@onready var btn_space: Button = $StartSpaceButton
@onready var btn_quit: Button = $QuitButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	btn_running_man.pressed.connect(_on_running_man_pressed)
	btn_space.pressed.connect(_on_space_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	# 2D 入口先留着，后续接入 2D 场景
	btn_2d.pressed.connect(_on_2d_pressed)


func _on_2d_pressed() -> void:
	# TODO: 接入 2D 场景
	pass


func _on_running_man_pressed() -> void:
	get_tree().change_scene_to_file("res://game/running_man/runner/runner.tscn")


func _on_space_pressed() -> void:
	get_tree().change_scene_to_file("res://game/space/space.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
