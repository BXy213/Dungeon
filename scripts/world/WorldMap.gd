@tool
extends Node2D

const Layout = preload("res://scripts/world/WorldLayout.gd")
const FLOOR = preload("res://art/environment/dungeon_floor_stone.png")
const WALL = preload("res://art/environment/dungeon_wall_stone.png")
const ROCK = preload("res://art/environment/dungeon_obstacle_rubble.png")

func _ready() -> void:
	build_map()

func build_map() -> void:
	if has_node("Terrain"):
		return
	var terrain := Node2D.new()
	terrain.name = "Terrain"
	add_child(terrain)
	var colors := [Color("879782"), Color("a6ad9c"), Color("9a9292"), Color("7c9483"), Color("8b9f9a"), Color("a0a6a3"), Color("819f87"), Color("a1ad94"), Color("8da6a2")]
	for y in range(3):
		for x in range(3):
			var chunk := Node2D.new()
			chunk.name = "Chunk_%d_%d" % [x, y]
			chunk.position = Vector2(x, y) * Layout.CHUNK_SIZE
			terrain.add_child(chunk)
			_surface(chunk, Rect2(Vector2.ZERO, Layout.CHUNK_SIZE), FLOOR, colors[y * 3 + x], -20)
	for points in Layout.roads():
		var edge := Line2D.new()
		edge.points = points
		edge.width = 160
		edge.default_color = Color("626e68")
		edge.joint_mode = Line2D.LINE_JOINT_ROUND
		edge.z_index = -18
		terrain.add_child(edge)
		var road := Line2D.new()
		road.points = points
		road.width = 130
		road.default_color = Color("b7bfb3")
		road.texture = FLOOR
		road.texture_mode = Line2D.LINE_TEXTURE_TILE
		road.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		road.joint_mode = Line2D.LINE_JOINT_ROUND
		road.z_index = -17
		terrain.add_child(road)
	for rect in Layout.obstacles():
		var body := StaticBody2D.new()
		body.position = rect.position
		body.collision_layer = 1
		body.collision_mask = 0
		terrain.add_child(body)
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.size * 0.5
		body.add_child(shape)
		_surface(body, Rect2(Vector2.ZERO, rect.size), WALL, Color("71807c"), -8)
		for x in range(48, int(rect.size.x), 120):
			var rubble := Sprite2D.new()
			rubble.texture = ROCK
			rubble.position = Vector2(x, rect.size.y * 0.5)
			rubble.modulate = Color("b3bdac")
			rubble.z_index = -7
			body.add_child(rubble)

func _surface(parent: Node, rect: Rect2, texture: Texture2D, color: Color, depth: int) -> void:
	var surface := TextureRect.new()
	surface.texture = texture
	surface.position = rect.position
	surface.size = rect.size
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode = TextureRect.STRETCH_TILE
	surface.modulate = color
	surface.z_index = depth
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(surface)
