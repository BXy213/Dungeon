extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://Scenes/WorldTestScene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(12):
		await process_frame
	var player: Node2D = scene.get_node("Player")
	var world: Node = scene.get_node("WorldManager")
	var camera: Camera2D = player.get_node("Camera2D")
	player.set_physics_process(false)
	world.set_physics_process(false)
	await _capture("spawn")
	player.global_position = Vector2(1510, 2600)
	world.encounters[0].update_encounter(player, 0.1)
	camera.reset_smoothing()
	await create_timer(0.7).timeout
	await _capture("encounter")
	player.global_position = WorldLayout.MAP_SIZE * 0.5
	camera.limit_left = -10000
	camera.limit_top = -10000
	camera.limit_right = 10000
	camera.limit_bottom = 10000
	camera.zoom = Vector2.ONE * 0.21
	camera.reset_smoothing()
	await _capture("overview")
	current_scene.queue_free()
	await process_frame
	quit()

func _capture(label: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var folder := "res://.godot/world-qa"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := "%s/%s-%dx%d.png" % [folder, label, image.get_width(), image.get_height()]
	image.save_png(path)
	var distinct: Dictionary = {}
	for y in range(0, image.get_height(), 16):
		for x in range(0, image.get_width(), 16):
			distinct[image.get_pixel(x, y).to_html()] = true
	print("VISUAL_CAPTURE %s sampled_colors=%d" % [path, distinct.size()])
	if distinct.size() < 30:
		push_error("Blank or incomplete world render.")
