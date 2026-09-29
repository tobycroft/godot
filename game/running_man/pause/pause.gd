extends Node
## Esc 暂停管理器（自动加载）。
## 在任意界面按 Esc 弹出/关闭暂停菜单（模糊 + 20% 变暗 + 返回主菜单/退出游戏）。

const PAUSE_SCENE := preload("res://game/running_man/pause/pause_menu.tscn")

var overlay: CanvasLayer = null
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		toggle()


func toggle() -> void:
	if overlay == null:
		open()
	else:
		close()


func open() -> void:
	if overlay != null:
		return
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay = PAUSE_SCENE.instantiate()
	get_tree().root.add_child(overlay)
	get_tree().paused = true


func close() -> void:
	if overlay == null:
		return
	var o: CanvasLayer = overlay
	overlay = null
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse_mode
	o.queue_free()
