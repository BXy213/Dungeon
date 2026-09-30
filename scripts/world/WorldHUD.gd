extends Control

const Layout = preload("res://scripts/world/WorldLayout.gd")
var world: Node
var title: Label
var status: Label
var elapsed := 0.0
const MAP_RECT := Rect2(20, 46, 210, 168)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world = get_tree().current_scene.get_node("WorldManager")
	var map_title := Label.new()
	map_title.position = Vector2(20, 20)
	map_title.text = "边境遗迹"
	map_title.add_theme_font_size_override("font_size", 16)
	add_child(map_title)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	title.position = Vector2(size.x - 365, 80)
	title.size = Vector2(340, 28)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.position = Vector2(size.x - 365, 110)
	status.size = Vector2(340, 28)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.1 or not is_instance_valid(world) or not world.initialized:
		return
	elapsed = 0
	var point: EncounterPoint = world.nearest_encounter()
	if point:
		title.text = "%s  /  威胁 %d" % [point.config.display_name, point.config.threat_level]
		title.modulate = threat_color(point.config.threat_level)
		match point.state:
			EncounterPoint.State.CLEARED: status.text = "已清除"
			EncounterPoint.State.LEASHING: status.text = "敌人正在撤回营地"
			EncounterPoint.State.ACTIVE: status.text = "剩余敌人 %d" % (point.enemies.size() + point.pending_spawns)
			_: status.text = "尚未清除"
	else:
		title.text = "边境遗迹"
		title.modulate = Color.WHITE
		status.text = "安全营地" if world.player.global_position.distance_to(Layout.SPAWN) < 500 else "荒野"
	queue_redraw()

func map_position(value: Vector2) -> Vector2:
	return MAP_RECT.position + value / Layout.MAP_SIZE * MAP_RECT.size

func threat_color(level: int) -> Color:
	if level >= 5:
		return Color("ec7777")
	return Color("edc16c") if level >= 3 else Color("8ccea1")

func _draw() -> void:
	draw_rect(MAP_RECT.grow(5), Color(0.08, 0.11, 0.1, 0.92))
	if not is_instance_valid(world) or not world.initialized:
		return
	for coord in world.world_state.discovered_chunks:
		draw_rect(Rect2(map_position(Vector2(coord) * Layout.CHUNK_SIZE), MAP_RECT.size / 3), Color("384940"))
	for road in Layout.roads():
		for i in range(road.size() - 1):
			draw_line(map_position(road[i]), map_position(road[i + 1]), Color("8b9d8e"), 2)
	for point in world.encounters:
		if not point.record.discovered and not point.config.is_final_objective:
			continue
		var color := Color("71847c") if point.record.cleared else threat_color(point.config.threat_level)
		var p := map_position(point.global_position)
		draw_circle(p, 5 if point.config.is_final_objective else 3.5, color)
		if point.config.is_final_objective:
			draw_arc(p, 8, 0, TAU, 16, color, 1)
	draw_circle(map_position(Layout.SPAWN), 3, Color("77bed4"))
	draw_circle(map_position(world.player.global_position), 4, Color.WHITE)
