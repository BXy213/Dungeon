extends Node2D

const Layout = preload("res://scripts/world/WorldLayout.gd")
const StateData = preload("res://scripts/world/WorldState.gd")
const Constants = preload("res://scripts/core/GameConstants.gd")

signal encounter_changed(point: EncounterPoint)
signal enemy_killed(point: EncounterPoint)

var world_state := StateData.new()
var encounters: Array[EncounterPoint] = []
var navigation := AStarGrid2D.new()
var player: Node2D
var initialized := false
var update_elapsed := 0.0

func _ready() -> void:
	build_navigation()
	var ids: Dictionary = {}
	for node in $WorldMap/Encounters.get_children():
		if not node is EncounterPoint:
			continue
		if ids.has(node.encounter_id):
			push_error("Duplicate encounter ID: %s. Give the copy its own ID." % node.encounter_id)
			continue
		ids[node.encounter_id] = true
		if not node.setup(self, world_state.encounter(node.encounter_id)):
			continue
		encounters.append(node)
		node.changed.connect(func(point): encounter_changed.emit(point))
		node.enemy_killed.connect(func(point): enemy_killed.emit(point))
		node.completed.connect(_on_completed)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if player:
		respawn_player()
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			camera.limit_left = 0
			camera.limit_top = 0
			camera.limit_right = int(Layout.MAP_SIZE.x)
			camera.limit_bottom = int(Layout.MAP_SIZE.y)
			camera.reset_smoothing()
	initialized = true

func _physics_process(delta: float) -> void:
	if not initialized or not is_instance_valid(player):
		return
	update_elapsed += delta
	if update_elapsed < 0.1:
		return
	var elapsed := update_elapsed
	update_elapsed = 0
	world_state.discovered_chunks[Vector2i(player.global_position / Layout.CHUNK_SIZE)] = true
	for point in encounters:
		point.update_encounter(player, elapsed)

func respawn_player() -> void:
	if is_instance_valid(player):
		player.global_position = Layout.SPAWN

func build_navigation() -> void:
	navigation.region = Rect2i(0, 0, int(Layout.MAP_SIZE.x) / Layout.CELL_SIZE, int(Layout.MAP_SIZE.y) / Layout.CELL_SIZE)
	navigation.cell_size = Vector2.ONE * Layout.CELL_SIZE
	navigation.offset = navigation.cell_size * 0.5
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in range(navigation.region.size.y):
		for x in range(navigation.region.size.x):
			var id := Vector2i(x, y)
			var center := navigation.get_point_position(id)
			for obstacle in Layout.obstacles():
				if obstacle.grow(32).has_point(center):
					navigation.set_point_solid(id)
					break

func cell_at(position: Vector2) -> Vector2i:
	return Vector2i((position / Layout.CELL_SIZE).floor())

func is_walkable(position: Vector2) -> bool:
	var cell := cell_at(position)
	return navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell)

func find_navigation_path(start: Vector2, target: Vector2) -> PackedVector2Array:
	var from_cell := _nearest_navigation_cell(start)
	var to_cell := _nearest_navigation_cell(target)
	if from_cell.x < 0 or to_cell.x < 0:
		return PackedVector2Array()
	return navigation.get_point_path(from_cell, to_cell)

func _nearest_navigation_cell(position: Vector2) -> Vector2i:
	var center := cell_at(position)
	if not navigation.is_in_boundsv(center):
		return Vector2i(-1, -1)
	if is_walkable(position):
		return center
	# A body's actual position can be clear while its inflated navigation cell is solid.
	var result := Vector2i(-1, -1)
	var nearest := INF
	for y in range(-2, 3):
		for x in range(-2, 3):
			var cell := center + Vector2i(x, y)
			if not navigation.is_in_boundsv(cell) or navigation.is_point_solid(cell):
				continue
			var candidate := navigation.get_point_position(cell)
			var distance := position.distance_squared_to(candidate)
			if distance >= nearest:
				continue
			var query := PhysicsRayQueryParameters2D.create(position, candidate, Constants.LAYER_WORLD)
			query.hit_from_inside = true
			if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
				result = cell
				nearest = distance
	return result

func find_blink_position(start: Vector2, desired: Vector2) -> Vector2:
	var shape := CircleShape2D.new()
	shape.radius = 29
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = Constants.LAYER_WORLD | Constants.LAYER_ENEMY
	var steps := maxi(1, ceili(start.distance_to(desired) / 8.0))
	for index in range(steps, -1, -1):
		var candidate := start.lerp(desired, float(index) / steps)
		if not Rect2(Vector2.ZERO, Layout.MAP_SIZE).has_point(candidate):
			continue
		query.transform = Transform2D(0, candidate)
		if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return start

func find_spawn_position(desired: Vector2, origin: Vector2) -> Vector2:
	for radius in range(0, 6):
		for step in range(12):
			var candidate := desired + Vector2.from_angle(TAU * float(step) / 12.0) * radius * 40
			if not is_walkable(candidate) or find_navigation_path(origin, candidate).is_empty():
				continue
			var query := PhysicsShapeQueryParameters2D.new()
			var shape := CircleShape2D.new()
			shape.radius = 28
			query.shape = shape
			query.transform = Transform2D(0, candidate)
			query.collision_mask = Constants.LAYER_WORLD | Constants.LAYER_ENEMY | Constants.LAYER_PLAYER
			if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				return candidate
	return Vector2.INF

func nearest_encounter() -> EncounterPoint:
	var result: EncounterPoint
	var nearest := INF
	if not is_instance_valid(player):
		return null
	for point in encounters:
		var distance := point.global_position.distance_to(player.global_position)
		if point.record.discovered and distance < nearest and distance < point.config.reset_radius:
			nearest = distance
			result = point
	return result

func _on_completed(point: EncounterPoint) -> void:
	if point.record.reward_spawned:
		return
	point.record.reward_spawned = true
	if is_instance_valid(player):
		player.gain_experience(point.config.clear_experience)
	var scene_path := "res://Scenes/GoldenKey.tscn" if point.config.is_final_objective else "res://Scenes/Chest.tscn"
	if not point.config.is_final_objective and not point.config.reward_chest:
		point.record.reward_claimed = true
		return
	var reward := (load(scene_path) as PackedScene).instantiate() as Node2D
	reward.position = point.position + Vector2(0, 85)
	point.get_parent().add_child(reward)
	point.reward_node = reward
	var picked_signal := "golden_key_picked_up" if point.config.is_final_objective else "chest_opened"
	reward.connect(picked_signal, func(_actor): point.record.reward_claimed = true)
