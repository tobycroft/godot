extends SceneTree

func _initialize() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	var inst := packed.instantiate()
	root.add_child(inst)
	# 等几帧让渲染完成
	for i in 30:
		await create_timer(0.05).timeout
	var vp := root.get_viewport()
	var tex := vp.get_texture()
	var img := tex.get_image()
	if img == null:
		push_error("viewport image is null")
		quit(1)
		return
	img.save_png("/tmp/main_shot.png")
	print("OK screenshot saved size=", img.get_size())
	quit(0)
