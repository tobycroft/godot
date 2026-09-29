extends Node3D
## 空间飞行 Demo 主场景。
## 飞船在原点附近受控转向，星空与小行星持续向相机方向流动，形成 3D 空间飞行感。
## Esc 由 Pause 自动加载接管（弹出暂停菜单，可返回主菜单 / 退出）。

const BASE_SPEED := 32.0

@onready var star_field: Node3D = $StarField
@onready var asteroid_field: Node3D = $AsteroidField
@onready var speed_label: Label = $UI/SpeedLabel

var _speed := BASE_SPEED


func _ready() -> void:
	speed_label.text = "速度: %d" % _speed


func _process(delta: float) -> void:
	var dz := _speed * delta
	star_field.scroll(dz)
	asteroid_field.scroll(dz, delta)
	speed_label.text = "速度: %d" % _speed
