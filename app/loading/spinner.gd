extends Control
## 旋转圆弧加载指示器：纯代码绘制，无需任何贴图资源。

const ARC_COUNT := 12
const SPEED := TAU * 0.9        # 每秒旋转弧度
const ARC_SWEEP := 0.5          # 单段圆弧长度（弧度）
const LINE_WIDTH := 5.0

var _angle := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(72, 72)


func _process(delta: float) -> void:
	_angle = fmod(_angle + delta * SPEED, TAU)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var center := size * 0.5
	var radius: float = min(size.x, size.y) * 0.5 - LINE_WIDTH
	for i in ARC_COUNT:
		var a := _angle + float(i) / ARC_COUNT * TAU
		var alpha := 1.0 - float(i) / ARC_COUNT
		draw_arc(center, radius, a, a + ARC_SWEEP, 20, Color(1, 1, 1, alpha), LINE_WIDTH, true)
