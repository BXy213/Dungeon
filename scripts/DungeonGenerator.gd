extends Node2D
class_name DungeonGenerator

const Constants = preload("res://scripts/core/GameConstants.gd")

# 房间状态常量
const ROOM_UNEXPLORED = 0
const ROOM_EXPLORING = 1
const ROOM_EXPLORED = 2

# 并查集类，用于最小生成树算法
class UnionFind:
	var parent: Dictionary = {}
	var rank: Dictionary = {}
	
	func make_set(x):
		parent[x] = x
		rank[x] = 0
	
	func find(x):
		if parent[x] != x:
			parent[x] = find(parent[x])  # 路径压缩
		return parent[x]
	
	func union(x, y):
		var root_x = find(x)
		var root_y = find(y)
		
		if root_x != root_y:
			# 按秩合并
			if rank[root_x] < rank[root_y]:
				parent[root_x] = root_y
			elif rank[root_x] > rank[root_y]:
				parent[root_y] = root_x
			else:
				parent[root_y] = root_x
				rank[root_x] += 1
	
	func connected(x, y) -> bool:
		return find(x) == find(y)

@export var dungeon_width: int = 3
@export var dungeon_height: int = 3
var room_scene: PackedScene

var rooms: Dictionary = {}  # {Vector2i(x, y): Room}
var current_room  # Room类型
var player: CharacterBody2D

# 房间和通道大小
var room_size: Vector2 = Vector2(1152, 648)
var corridor_width: int = 200  # 通道长度
var corridor_thickness: int = 120  # 通道厚度

# 通道系统
var corridors: Dictionary = {}  # {corridor_id: Corridor_data}
var current_area_type: String = "room"  # "room" 或 "corridor"
var current_corridor_id: String = ""

# 房间状态管理
var room_states: Dictionary = {}  # {Vector2i: int} Room.RoomState enum values
var start_room_coord: Vector2i = Vector2i(0, 0)

signal room_changed(new_room, old_room)
signal room_exploration_completed(room_id: Vector2i)

func _ready() -> void:
	room_scene = preload("res://Scenes/Room.tscn")
	generate_dungeon()
	setup_player_reference()

func setup_player_reference() -> void:
	# 等待一帧确保场景树准备好
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if player:
		# 将玩家移动到起始房间中心
		var start_room = rooms.get(start_room_coord)
		if start_room:
			current_room = start_room
			player.position = start_room.position + start_room.room_size / 2.0
			# 设置全局相机限制，覆盖整个地牢
			setup_global_camera_limits()
			
			# 设置起始房间为已探索状态（无敌人生成，可自由进出）
			start_room.set_room_state(ROOM_EXPLORED)
			room_states[start_room_coord] = ROOM_EXPLORED
			
			# 为起始房间生成内容（只有障碍物，无敌人）
			start_room.setup_room_content()
			
			# 启动玩家位置检测
			start_position_detection()
			
			print("起始房间已设置完成，状态: EXPLORED")

func start_position_detection() -> void:
	# 每帧检测玩家位置，确定当前所在房间
	var timer = Timer.new()
	timer.wait_time = 0.1  # 每0.1秒检测一次
	timer.timeout.connect(_check_player_position)
	timer.autostart = true
	add_child(timer)
	print("开始玩家位置检测")

func generate_dungeon() -> void:
	print("开始生成地牢: ", dungeon_width, "x", dungeon_height)
	
	# 生成所有房间
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			var room_coord = Vector2i(x, y)
			var room = create_room(room_coord)
			rooms[room_coord] = room
	
	# 连接相邻房间
	connect_rooms()
	
	# 生成房间间的通道
	create_corridors()
	
	# 显示所有房间背景（不再隐藏房间）
	show_all_room_backgrounds()
	
	print("地牢生成完成，包含房间和通道")

func create_room(coord: Vector2i):
	var room = room_scene.instantiate()
	room.room_id = coord
	# 新的房间位置计算，考虑通道空间
	room.position = calculate_room_position(coord)
	room.room_size = room_size
	room.name = "Room_" + str(coord.x) + "_" + str(coord.y)
	
	# 设置房间的障碍物数量（边缘房间少一些）
	var is_edge = coord.x == 0 or coord.x == dungeon_width - 1 or coord.y == 0 or coord.y == dungeon_height - 1
	room.obstacle_count = 10 if is_edge else 15
	
	# 初始化房间状态（起始房间除外）
	if coord != start_room_coord:
		room_states[coord] = ROOM_UNEXPLORED
		# 起始房间不生成敌人，其他房间正常生成
	else:
		room_states[coord] = ROOM_EXPLORED
	
	# 连接房间完成信号
	room.room_completed.connect(_on_room_completed)
	room.enemy_died_in_room.connect(_on_enemy_died_in_room)
	
	add_child(room)
	# 不再隐藏房间，所有背景同时显示
	
	return room

func connect_rooms() -> void:
	# 暂时不建立任何房间连接，等通道生成完成后再建立实际连接
	print("房间连接将在通道生成完成后建立")

func create_corridors() -> void:
	print("开始生成优化的通道系统")
	
	# 使用最小生成树算法生成通道，确保连通性并最小化通道数
	var edges = generate_all_possible_edges()
	var selected_edges = generate_minimum_spanning_tree(edges)
	
	# 创建选中的通道并建立房间连接
	for edge in selected_edges:
		create_corridor_between_rooms(edge.room1, edge.room2, edge.direction)
		# 建立实际的房间连接关系
		establish_room_connection(edge.room1, edge.room2)
	
	# 为所有房间创建墙体（基于实际连接）
	create_room_walls_for_all_rooms()
	
	print("优化通道生成完成，总数: ", corridors.size(), " (最大允许: ", calculate_max_corridors(), ")")

func generate_all_possible_edges() -> Array:
	var edges = []
	
	for coord in rooms.keys():
		# 只检查向右和向下的连接，避免重复
		var directions_to_check = [Vector2i.RIGHT, Vector2i.DOWN]
		
		for direction in directions_to_check:
			var neighbor_coord = coord + direction
			if neighbor_coord in rooms:
				var edge = {
					"room1": coord,
					"room2": neighbor_coord,
					"direction": direction,
					"weight": randf()  # 随机权重用于随机化最小生成树
				}
				edges.append(edge)
	
	# 按权重排序（实现随机化的Kruskal算法）
	edges.sort_custom(func(a, b): return a.weight < b.weight)
	
	print("生成了 ", edges.size(), " 条可能的边")
	return edges

func generate_minimum_spanning_tree(edges: Array) -> Array:
	var selected_edges = []
	var union_find = UnionFind.new()
	
	# 初始化并查集，每个房间作为一个独立的集合
	for coord in rooms.keys():
		union_find.make_set(coord)
	
	var max_corridors = calculate_max_corridors()
	var remaining_edges = []  # 保存未使用的边，用于后续补充
	
	# 第一阶段：Kruskal算法生成最小生成树，确保连通性
	print("第一阶段：生成最小生成树确保连通性")
	for edge in edges:
		# 如果两个房间不在同一个连通组件中，添加这条边
		if not union_find.connected(edge.room1, edge.room2):
			union_find.union(edge.room1, edge.room2)
			selected_edges.append(edge)
		else:
			# 保存未使用的边用于后续补充
			remaining_edges.append(edge)
	
	# 验证所有房间是否连通
	var root = union_find.find(start_room_coord)
	var all_connected = true
	for coord in rooms.keys():
		if union_find.find(coord) != root:
			all_connected = false
			break
	
	if not all_connected:
		print("警告：无法确保所有房间连通！")
		return selected_edges
	
	print("基础连通性已建立，使用 ", selected_edges.size(), " 条通道")
	
	# 第二阶段：补充通道直到达到最大允许数量
	if selected_edges.size() < max_corridors:
		print("第二阶段：补充通道至最大数量 ", max_corridors)
		var additional_needed = max_corridors - selected_edges.size()
		var additional_count = 0
		
		# 从剩余边中继续添加通道
		for edge in remaining_edges:
			if additional_count >= additional_needed:
				break
			
			selected_edges.append(edge)
			additional_count += 1
			print("添加补充通道: ", get_normalized_corridor_id(edge.room1, edge.room2))
		
		print("补充完成，总通道数: ", selected_edges.size(), " (目标: ", max_corridors, ")")
	else:
		print("已达到最大通道数限制: ", selected_edges.size())
	
	return selected_edges

func calculate_max_corridors() -> int:
	# 计算最大通道数
	var min_for_connectivity = dungeon_width * dungeon_height - 1  # 连通性最小需求
	var max_possible_corridors = get_max_possible_corridors()  # 理论最大通道数
	var user_limit = max(1, (dungeon_width) * (dungeon_height) + max(dungeon_width, dungeon_height))  # 用户期望
	
	# 确保不超过理论最大值
	user_limit = min(user_limit, max_possible_corridors)
	
	# 如果用户限制太小无法保证连通性，使用最小连通数
	if user_limit < min_for_connectivity:
		print("用户限制 ", user_limit, " 小于连通性需要的最小值 ", min_for_connectivity, "，使用最小值")
		return min_for_connectivity
	
	print("通道数量配置 - 最小连通:", min_for_connectivity, " 用户期望:", user_limit, " 理论最大:", max_possible_corridors)
	return user_limit

func get_max_possible_corridors() -> int:
	# 计算理论上最大可能的通道数量（所有相邻房间都连通）
	var horizontal_corridors = dungeon_width * (dungeon_height - 1)  # 垂直相邻
	var vertical_corridors = (dungeon_width - 1) * dungeon_height    # 水平相邻
	return horizontal_corridors + vertical_corridors

func get_normalized_corridor_id(coord1: Vector2i, coord2: Vector2i) -> String:
	# 确保通道ID的唯一性：总是将较小的坐标放在前面
	var smaller_coord: Vector2i
	var larger_coord: Vector2i
	
	if coord1.x < coord2.x or (coord1.x == coord2.x and coord1.y < coord2.y):
		smaller_coord = coord1
		larger_coord = coord2
	else:
		smaller_coord = coord2
		larger_coord = coord1
	
	return str(smaller_coord) + "_to_" + str(larger_coord)

func get_actual_direction(coord1: Vector2i, coord2: Vector2i) -> Vector2i:
	# 计算从coord1到coord2的方向向量
	var diff = coord2 - coord1
	
	if diff.x > 0:
		return Vector2i.RIGHT
	elif diff.x < 0:
		return Vector2i.LEFT
	elif diff.y > 0:
		return Vector2i.DOWN
	elif diff.y < 0:
		return Vector2i.UP
	else:
		return Vector2i.ZERO  # 不应该发生

func create_corridor_between_rooms(room1_coord: Vector2i, room2_coord: Vector2i, direction: Vector2i) -> void:
	# 创建标准化的通道ID（较小坐标在前，确保唯一性）
	var corridor_id = get_normalized_corridor_id(room1_coord, room2_coord)
	
	# 检查是否已存在该通道，避免重复创建
	if corridor_id in corridors:
		print("通道 ", corridor_id, " 已存在，跳过创建")
		return
	
	var corridor_data = {}
	corridor_data.id = corridor_id
	corridor_data.room1_coord = room1_coord
	corridor_data.room2_coord = room2_coord
	corridor_data.direction = direction
	
	# 计算实际方向（基于房间坐标差）
	var actual_direction = get_actual_direction(room1_coord, room2_coord)
	corridor_data.direction = actual_direction  # 更新为实际方向
	
	# 根据实际方向计算通道位置和大小
	var room1_obj = rooms[room1_coord]
	var room2_obj = rooms[room2_coord]
	
	if actual_direction == Vector2i.RIGHT:
		# 水平向右的通道
		corridor_data.size = Vector2(corridor_width, corridor_thickness)
		corridor_data.position = Vector2(
			room1_obj.position.x + room_size.x,
			room1_obj.position.y + (room_size.y - corridor_thickness) / 2.0
		)
	elif actual_direction == Vector2i.LEFT:
		# 水平向左的通道
		corridor_data.size = Vector2(corridor_width, corridor_thickness)
		corridor_data.position = Vector2(
			room2_obj.position.x + room_size.x,
			room2_obj.position.y + (room_size.y - corridor_thickness) / 2.0
		)
	elif actual_direction == Vector2i.DOWN:
		# 垂直向下的通道
		corridor_data.size = Vector2(corridor_thickness, corridor_width)
		corridor_data.position = Vector2(
			room1_obj.position.x + (room_size.x - corridor_thickness) / 2.0,
			room1_obj.position.y + room_size.y
		)
	elif actual_direction == Vector2i.UP:
		# 垂直向上的通道
		corridor_data.size = Vector2(corridor_thickness, corridor_width)
		corridor_data.position = Vector2(
			room2_obj.position.x + (room_size.x - corridor_thickness) / 2.0,
			room2_obj.position.y + room_size.y
		)
	
	# 创建通道的视觉背景
	create_corridor_visual(corridor_data)
	
	corridors[corridor_id] = corridor_data
	print("创建通道: ", corridor_id, " 位置: ", corridor_data.position, " 大小: ", corridor_data.size)

func create_corridor_visual(corridor_data: Dictionary) -> void:
	# 创建通道的视觉效果和碰撞体
	var corridor_bg = ColorRect.new()
	corridor_bg.name = "CorridorBG_" + corridor_data.id
	corridor_bg.size = corridor_data.size
	corridor_bg.position = corridor_data.position
	corridor_bg.color = Color(0.4, 0.4, 0.6, 0.9)  # 蓝灰色，比房间浅
	corridor_bg.z_index = -9  # 在房间背景之上，但在内容之下
	add_child(corridor_bg)
	
	# 创建通道的碰撞体（默认禁用，由房间状态控制）
	var corridor_collision = StaticBody2D.new()
	corridor_collision.name = "CorridorCollision_" + corridor_data.id
	corridor_collision.position = corridor_data.position
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"  # 明确设置名称便于查找
	var shape = RectangleShape2D.new()
	shape.size = corridor_data.size
	collision_shape.shape = shape
	collision_shape.position = corridor_data.size / 2.0
	collision_shape.disabled = true  # 默认禁用碰撞
	
	corridor_collision.add_child(collision_shape)
	print("  ✅ 创建通道碰撞形状: ", corridor_data.size, " 位置: ", collision_shape.position)
	add_child(corridor_collision)
	
	# 保存通道组件的引用
	corridor_data.background = corridor_bg
	corridor_data.collision = corridor_collision
	
	# 创建通道的物理墙体
	create_corridor_walls(corridor_data)
	
	print("创建通道视觉效果和碰撞体: ", corridor_data.position, " 大小: ", corridor_data.size)

func create_corridor_walls(corridor_data: Dictionary) -> void:
	var pos = corridor_data.position
	var size = corridor_data.size
	var wall_thickness = 20
	
	# 检查通道方向来确定哪些边需要封闭
	var room1_coord = corridor_data.room1_coord
	var room2_coord = corridor_data.room2_coord
	var actual_direction = get_actual_direction(room1_coord, room2_coord)
	
	if actual_direction == Vector2i.RIGHT or actual_direction == Vector2i.LEFT:
		# 水平通道：封闭上下两边，左右连接房间
		create_corridor_wall(Vector2(pos.x, pos.y - wall_thickness), Vector2(size.x, wall_thickness), "top")
		create_corridor_wall(Vector2(pos.x, pos.y + size.y), Vector2(size.x, wall_thickness), "bottom")
	elif actual_direction == Vector2i.DOWN or actual_direction == Vector2i.UP:
		# 垂直通道：封闭左右两边，上下连接房间
		create_corridor_wall(Vector2(pos.x - wall_thickness, pos.y), Vector2(wall_thickness, size.y), "left")
		create_corridor_wall(Vector2(pos.x + size.x, pos.y), Vector2(wall_thickness, size.y), "right")

func create_corridor_wall(wall_pos: Vector2, wall_size: Vector2, wall_name: String) -> void:
	# 创建碰撞墙体
	var wall = StaticBody2D.new()
	wall.name = "CorridorWall_" + wall_name
	wall.position = wall_pos
	
	# 设置碰撞层级
	wall.set_collision_layer_value(1, true)
	wall.set_collision_mask_value(1, true)
	
	# 创建碰撞形状
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = wall_size
	collision.shape = shape
	collision.position = wall_size / 2.0
	
	wall.add_child(collision)
	
	# 创建视觉效果
	var wall_visual = ColorRect.new()
	wall_visual.size = wall_size
	wall_visual.color = Color(0.4, 0.4, 0.5, 1.0)  # 灰色墙体
	wall_visual.z_index = -5
	wall.add_child(wall_visual)
	
	add_child(wall)
	print("创建通道墙体: ", wall_name, " 位置: ", wall_pos, " 大小: ", wall_size)

func _check_player_position() -> void:
	if not player:
		return
	
	# 根据玩家位置确定当前所在区域（房间或通道）
	var player_pos = player.position
	var area_info = get_area_at_position(player_pos)
	
	if area_info.type == "room":
		var new_room = area_info.object
		if new_room and new_room != current_room:
			# 玩家进入了新房间
			change_to_new_room(new_room)
			current_area_type = "room"
			# 通知UI更新房间状态
			var ui_manager = get_tree().current_scene.get_node_or_null(Constants.NODE_UI_MANAGER)
			if ui_manager and ui_manager.has_method("_on_area_changed"):
				ui_manager._on_area_changed("room", str(new_room.room_id))
		elif new_room == current_room and current_area_type != "room":
			# 玩家从通道回到当前房间
			current_area_type = "room"
			print("玩家回到房间: ", current_room.room_id)
			var ui_manager = get_tree().current_scene.get_node_or_null(Constants.NODE_UI_MANAGER)
			if ui_manager and ui_manager.has_method("_on_area_changed"):
				ui_manager._on_area_changed("room", str(current_room.room_id))
	elif area_info.type == "corridor":
		# 玩家在通道中
		if current_area_type != "corridor" or current_corridor_id != area_info.id:
			current_area_type = "corridor"
			current_corridor_id = area_info.id
			print("玩家进入通道: ", area_info.id)
			# 通知UI更新
			var ui_manager = get_tree().current_scene.get_node_or_null(Constants.NODE_UI_MANAGER)
			if ui_manager and ui_manager.has_method("_on_area_changed"):
				ui_manager._on_area_changed("corridor", area_info.id)

func calculate_room_position(coord: Vector2i) -> Vector2:
	# 计算包含通道空间的房间位置
	var x_pos = coord.x * (room_size.x + corridor_width)
	var y_pos = coord.y * (room_size.y + corridor_width)
	return Vector2(x_pos, y_pos)

func establish_room_connection(room1_coord: Vector2i, room2_coord: Vector2i) -> void:
	# 建立两个房间之间的双向连接
	var room1 = rooms[room1_coord]
	var room2 = rooms[room2_coord]
	var direction = get_actual_direction(room1_coord, room2_coord)
	var opposite_direction = get_opposite_direction(direction)
	
	# 建立双向连接
	room1.add_connection(direction)
	room2.add_connection(opposite_direction)
	
	print("建立房间连接: ", room1_coord, " ↔ ", room2_coord, " (方向: ", direction, ")")

func get_opposite_direction(direction: Vector2i) -> Vector2i:
	match direction:
		Vector2i.UP:
			return Vector2i.DOWN
		Vector2i.DOWN:
			return Vector2i.UP
		Vector2i.LEFT:
			return Vector2i.RIGHT
		Vector2i.RIGHT:
			return Vector2i.LEFT
		_:
			return Vector2i.ZERO

func create_room_walls_for_all_rooms() -> void:
	# 为所有房间创建墙体，基于实际的连接关系
	for coord in rooms.keys():
		var room = rooms[coord]
		room.create_room_walls_based_on_connections()
		print("为房间 ", coord, " 创建墙体，连接数: ", room.connections.size())

func get_area_at_position(pos: Vector2) -> Dictionary:
	# 返回位置信息：{type: "room"/"corridor", id: room_coord/corridor_id, object: room/corridor}
	
	# 检查是否在房间内
	for coord in rooms:
		var room = rooms[coord]
		var room_rect = Rect2(room.position, room_size)
		if room_rect.has_point(pos):
			return {"type": "room", "id": coord, "object": room}
	
	# 检查是否在通道内
	for corridor_id in corridors:
		var corridor = corridors[corridor_id]
		var corridor_rect = Rect2(corridor.position, corridor.size)
		if corridor_rect.has_point(pos):
			return {"type": "corridor", "id": corridor_id, "object": corridor}
	
	# 不在任何区域内
	return {"type": "none", "id": "", "object": null}

func get_room_at_position(pos: Vector2):
	var area_info = get_area_at_position(pos)
	if area_info.type == "room":
		return area_info.object
	return null

func change_to_new_room(new_room) -> void:
	if not new_room:
		return
	
	var old_room = current_room
	var old_room_text = str(old_room.room_id) if old_room else "无"
	print("玩家从房间 ", old_room_text, " 移动到房间 ", new_room.room_id)
	
	# 探索限制现在由通道门的物理碰撞来处理，不再需要推回玩家
	# 通道门在探索中房间会自动启用碰撞，物理阻止玩家进入通道
	
	# 清理所有弹道和技能效果
	clear_all_projectiles()
	
	# 禁用旧房间碰撞
	if old_room:
		disable_room_collisions(old_room)
	
	# 如果目标房间是第一次进入，生成房间内容
	if new_room.get_room_state() == ROOM_UNEXPLORED:
		print("首次进入房间 ", new_room.room_id, "，生成房间内容")
		new_room.setup_room_content()
	
	# 启用新房间碰撞
	current_room = new_room
	enable_room_collisions(current_room)
	
	# 发出房间改变信号
	room_changed.emit(new_room, old_room)
	
	print("成功切换到房间: ", new_room.room_id)

# 移除了推回玩家的逻辑，现在使用物理碰撞门来限制移动

func show_all_room_backgrounds() -> void:
	# 显示所有房间背景，但只启用当前房间的碰撞
	for room_coord in rooms:
		var room = rooms[room_coord]
		room.visible = true  # 所有房间背景都显示
		if room_coord == start_room_coord:
			# 只有起始房间启用碰撞和内容
			enable_room_collisions(room)
			current_room = room
		else:
			# 其他房间禁用碰撞
			disable_room_collisions(room)

func setup_global_camera_limits() -> void:
	"""设置全局相机限制，覆盖整个地牢并添加宽松边距"""
	if not player:
		return
	
	# 获取玩家的相机
	var camera = player.get("camera")
	if not camera:
		print("⚠️ 玩家没有相机组件")
		return
	
	# 计算整个地牢的边界
	var dungeon_total_width = dungeon_width * (room_size.x + corridor_width) - corridor_width
	var dungeon_total_height = dungeon_height * (room_size.y + corridor_width) - corridor_width
	
	# 添加宽松的边距，特别是为边缘房间
	var margin = 300  # 增加到300像素的宽松边距
	
	# 设置全局相机限制
	camera.limit_left = -margin
	camera.limit_top = -margin
	camera.limit_right = int(dungeon_total_width + margin)
	camera.limit_bottom = int(dungeon_total_height + margin)
	
	print("📷 设置全局相机限制 - 地牢尺寸: ", dungeon_total_width, "x", dungeon_total_height)
	print("📷 相机边界: (", camera.limit_left, ",", camera.limit_top, ") 到 (", 
		  camera.limit_right, ",", camera.limit_bottom, ") - 边距:", margin)

func get_current_room_coord() -> Vector2i:
	return current_room.room_id if current_room else Vector2i.ZERO

func get_total_rooms() -> int:
	return dungeon_width * dungeon_height

func clear_all_projectiles() -> void:
	# 清理所有活跃的弹道和技能效果，防止虚空攻击
	var skill_effects = get_tree().current_scene.get_node_or_null(Constants.NODE_SKILL_EFFECTS)
	if skill_effects:
		for child in skill_effects.get_children():
			if is_instance_valid(child):
				child.queue_free()
		print("已清理所有弹道和技能效果")

func disable_room_collisions(room) -> void:
	# 禁用房间内所有障碍物和墙体的碰撞体（但保持通道门状态不变）
	if not room:
		return
		
	# 禁用障碍物碰撞
	var obstacles_container = room.get_node_or_null("Obstacles")
	if obstacles_container:
		for obstacle in obstacles_container.get_children():
			obstacle.set_collision_layer_value(1, false)
			obstacle.set_collision_mask_value(1, false)
	
	# 只禁用墙体碰撞，不影响通道门
	for child in room.get_children():
		if child is StaticBody2D and child.name.begins_with("Wall_"):
			child.set_collision_layer_value(1, false)
			child.set_collision_mask_value(1, false)
			print("禁用房间 ", room.room_id, " 的墙体: ", child.name)
	
	# 通道门状态保持不变，由房间状态控制

func enable_room_collisions(room) -> void:
	# 启用房间内所有障碍物、墙体的碰撞体，并确保通道门状态正确
	if not room:
		return
		
	# 启用障碍物碰撞
	var obstacles_container = room.get_node_or_null("Obstacles")
	if obstacles_container:
		for obstacle in obstacles_container.get_children():
			obstacle.set_collision_layer_value(1, true)
			obstacle.set_collision_mask_value(1, true)
	
	# 启用墙体碰撞
	for child in room.get_children():
		if child is StaticBody2D and child.name.begins_with("Wall_"):
			child.set_collision_layer_value(1, true)
			child.set_collision_mask_value(1, true)
			print("启用房间 ", room.room_id, " 的墙体: ", child.name)
	
	# 确保连接的通道状态根据房间状态正确设置
	update_corridors_for_room(room.room_id, room.get_room_state())
	print("房间 ", room.room_id, " 碰撞启用完成，连接的通道状态已更新")

# 房间状态管理函数
func can_leave_current_room() -> bool:
	if not current_room:
		return true
	
	# 如果房间已探索完成，可以自由进出
	var can_leave = current_room.is_room_exploration_completed()
	print("检查是否可以离开房间 ", current_room.room_id, ", 状态: ", current_room.get_room_state(), ", 可离开: ", can_leave)
	return can_leave

func get_room_state(room_coord: Vector2i) -> int:
	return room_states.get(room_coord, ROOM_UNEXPLORED)

func update_corridors_for_room(room_id: Vector2i, room_state: int) -> void:
	# 更新连接指定房间的所有通道的状态
	var state_names = ["UNEXPLORED", "EXPLORING", "EXPLORED"]
	print("🔄 更新房间 ", room_id, " 连接的通道，房间状态: ", state_names[room_state])
	
	for corridor_id in corridors.keys():
		var corridor = corridors[corridor_id]
		
		# 检查通道是否连接此房间
		if corridor_connects_room(corridor_id, room_id):
			# 获取通道连接的两个房间
			var rooms_connected = get_corridor_connected_rooms(corridor_id)
			var should_block = false
			
			# 如果任一连接的房间处于探索中状态，封锁通道
			for connected_room_id in rooms_connected:
				var connected_room = rooms.get(connected_room_id)
				if connected_room and connected_room.get_room_state() == ROOM_EXPLORING:
					should_block = true
					break
			
			# 更新通道状态
			update_corridor_state(corridor, should_block)
			
			print("  通道 ", corridor_id, " 连接房间 ", room_id, " - ", "封锁" if should_block else "开放")

func corridor_connects_room(corridor_id: String, room_id: Vector2i) -> bool:
	# 检查通道是否连接指定房间
	var parts = corridor_id.split("_to_")
	if parts.size() != 2:
		return false
	
	var coord1_str = parts[0].replace("(", "").replace(")", "").strip_edges()
	var coord2_str = parts[1].replace("(", "").replace(")", "").strip_edges()
	
	var coord1_parts = coord1_str.split(",")
	var coord2_parts = coord2_str.split(",")
	
	if coord1_parts.size() != 2 or coord2_parts.size() != 2:
		return false
	
	var coord1 = Vector2i(int(coord1_parts[0].strip_edges()), int(coord1_parts[1].strip_edges()))
	var coord2 = Vector2i(int(coord2_parts[0].strip_edges()), int(coord2_parts[1].strip_edges()))
	
	return coord1 == room_id or coord2 == room_id

func get_corridor_connected_rooms(corridor_id: String) -> Array[Vector2i]:
	# 获取通道连接的两个房间坐标
	var result: Array[Vector2i] = []
	var parts = corridor_id.split("_to_")
	if parts.size() != 2:
		return result
	
	var coord1_str = parts[0].replace("(", "").replace(")", "").strip_edges()
	var coord2_str = parts[1].replace("(", "").replace(")", "").strip_edges()
	
	var coord1_parts = coord1_str.split(",")
	var coord2_parts = coord2_str.split(",")
	
	if coord1_parts.size() == 2 and coord2_parts.size() == 2:
		var coord1 = Vector2i(int(coord1_parts[0].strip_edges()), int(coord1_parts[1].strip_edges()))
		var coord2 = Vector2i(int(coord2_parts[0].strip_edges()), int(coord2_parts[1].strip_edges()))
		result.append(coord1)
		result.append(coord2)
	
	return result

func update_corridor_state(corridor_data: Dictionary, should_block: bool) -> void:
	# 更新通道的碰撞和视觉状态
	var background = corridor_data.get("background")
	var collision = corridor_data.get("collision")
	
	print("  🔧 更新通道碰撞状态 - ID: ", corridor_data.get("id"), " 封锁: ", should_block)
	
	if background:
		if should_block:
			# 封锁状态：通道变暗
			background.color = Color(0.2, 0.2, 0.3, 0.9)  # 深色
			background.modulate = Color(0.6, 0.6, 0.6, 1.0)  # 暗化
			print("    🎨 通道视觉已变暗")
		else:
			# 开放状态：通道正常颜色
			background.color = Color(0.4, 0.4, 0.6, 0.9)  # 正常蓝灰色
			background.modulate = Color.WHITE  # 正常亮度
			print("    🎨 通道视觉已恢复正常")
	
	if collision:
		# 调试：显示碰撞体的所有子节点
		print("    🔍 通道碰撞体子节点: ", collision.get_children().size())
		for child in collision.get_children():
			print("      - ", child.name, " (", child.get_class(), ")")
		
		var collision_shape = collision.get_node_or_null("CollisionShape2D")
		if collision_shape:
			# 使用set_deferred避免在物理查询期间修改碰撞状态
			collision_shape.set_deferred("disabled", not should_block)  # 封锁时启用碰撞
			print("    🚧 碰撞形状禁用状态将设置为: ", not should_block, " (", "启用" if should_block else "禁用", ")")
			
			# 验证形状
			if collision_shape.shape:
				print("    📏 碰撞形状大小: ", collision_shape.shape.size)
			else:
				print("    ⚠️ 警告：碰撞形状为空")
		else:
			print("    ⚠️ 错误：找不到CollisionShape2D，尝试直接查找...")
			# 尝试直接通过索引查找
			if collision.get_child_count() > 0:
				var first_child = collision.get_child(0)
				if first_child is CollisionShape2D:
					collision_shape = first_child
					# 使用set_deferred避免在物理查询期间修改碰撞状态
					collision_shape.set_deferred("disabled", not should_block)
					print("    ✅ 通过索引找到碰撞形状，将", "启用" if should_block else "禁用")
				else:
					print("    ❌ 第一个子节点不是CollisionShape2D: ", first_child.get_class())
			
		if should_block:
			collision.set_collision_layer_value(1, true)
			collision.set_collision_mask_value(1, false)
			print("    📍 通道碰撞层级已设置: layer=1, mask=0")
		else:
			collision.set_collision_layer_value(1, false)
			collision.set_collision_mask_value(1, false)
			print("    📍 通道碰撞层级已清除: layer=0, mask=0")
		
		# 验证碰撞体位置和大小
		var collision_size_text = str(collision_shape.shape.size) if collision_shape and collision_shape.shape else "N/A"
		print("    📐 通道碰撞体位置: ", collision.position, " 大小: ", collision_size_text)
	else:
		print("    ⚠️ 警告：找不到通道碰撞体")
	
	var state_text = "封锁" if should_block else "开放"
	print("  🚧 通道状态更新完成: ", state_text)

func _on_room_completed(room_id: Vector2i) -> void:
	room_states[room_id] = ROOM_EXPLORED
	room_exploration_completed.emit(room_id)
	print("地牢生成器: 房间 ", room_id, " 探索完成!")
	
	# 更新连接此房间的通道状态
	update_corridors_for_room(room_id, ROOM_EXPLORED)

func _on_enemy_died_in_room(room_id: Vector2i, remaining_count: int) -> void:
	print("房间 ", room_id, " 还剩 ", remaining_count, " 个敌人")
	
	# 如果是当前房间且敌人全部死亡，更新UI或其他状态
	if current_room and current_room.room_id == room_id and remaining_count == 0:
		print("当前房间所有敌人已消灭，可以离开了!")

func force_room_completion(room_coord: Vector2i) -> void:
	# 强制完成房间（调试用）
	if room_coord in rooms:
		var room = rooms[room_coord]
		room.set_room_state(ROOM_EXPLORED)
		room_states[room_coord] = ROOM_EXPLORED
