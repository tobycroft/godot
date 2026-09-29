extends Control
## 主菜单脚本：2D 入口暂留，3D 入口进入三维世界场景。

@onready var btn_2d: Button = $Start2DButton
@onready var btn_3d: Button = $Start3DButton
@onready var btn_quit: Button = $QuitButton


func _ready() -> void:
	btn_3d.pressed.connect(_on_3d_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	# 2D 入口先留着，后续接入 2D 场景
	btn_2d.pressed.connect(_on_2d_pressed)


func _on_2d_pressed() -> void:
	# TODO: 接入 2D 场景
	pass


func _on_3d_pressed() -> void:
	get_tree().change_scene_to_file("res://game/3d/runner/runner.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
