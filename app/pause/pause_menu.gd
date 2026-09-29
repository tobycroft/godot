extends CanvasLayer
## 暂停菜单界面：模糊底层画面并叠加按钮。

@onready var home_button: Button = $CenterContainer/VBox/HomeButton
@onready var quit_button: Button = $CenterContainer/VBox/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	home_button.pressed.connect(_on_home_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_home_pressed() -> void:
	Pause.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://app/main/main.tscn")


func _on_quit_pressed() -> void:
	Pause.close()
	get_tree().quit()
