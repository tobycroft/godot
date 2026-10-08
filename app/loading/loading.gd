extends Control
## 关卡加载过渡层。
## 以子节点方式叠在当前场景（主菜单）之上，用后台线程（WorkerThreadPool）加载目标关卡，
## 加载期间主线程仍可播放转圈动画与进度条，加载完成后再切换到目标场景。
## 这样关卡（地图）加载不会再卡住主线程，玩家能看到 loading 而不是白屏卡死。

@onready var bar: ProgressBar = $Center/VBox/ProgressBar

## 要加载的目标关卡场景路径，由调用方在 add_child 之前赋值。
var target_path: String = ""

var _done := false
var _packed: PackedScene
var _task_id := -1


func _ready() -> void:
	if target_path == "":
		push_error("Loading: 未设置 target_path，无法加载关卡")
		_fallback()
		return
	_task_id = WorkerThreadPool.add_task(_load_task.bind(target_path), false, "LoadLevel")


## 在后台线程同步加载关卡场景，避免阻塞主线程造成卡顿。
func _load_task(path: String) -> void:
	_packed = ResourceLoader.load(path) as PackedScene


func _process(delta: float) -> void:
	if _done:
		return
	# 加载期间让进度条缓慢推进到 90%，加载完成时再走满，呈现“正在加载”的观感
	if bar != null:
		bar.value = min(bar.value + delta * 45.0, 90.0)
	if _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		_task_id = -1
		if _packed == null:
			push_error("Loading: 关卡加载失败: %s" % target_path)
			_fallback()
			return
		_switch()


## 真正切换到目标关卡。
func _switch() -> void:
	if _done:
		return
	_done = true
	if bar != null:
		bar.value = 100.0
	get_tree().change_scene_to_packed(_packed)


## 加载异常时退回主菜单，避免永久卡在加载界面。
func _fallback() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file("res://app/main.tscn")
