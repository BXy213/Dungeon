extends Node2D
class_name Room

const EnemyTypes = preload("res://scripts/factories/EnemyFactory.gd")
const Constants = preload("res://scripts/core/GameConstants.gd")
const SpawnPlanner = preload("res://scripts/rooms/EnemySpawnPlanner.gd")
const SaveCodec = preload("res://scripts/rooms/RoomSaveCodec.gd")

const START_ROOM_ID := Vector2i(0, 0)
const DEFAULT_DUNGEON_SIZE := Vector2i(5, 5)
const SAFE_SPAWN_MARGIN := 150.0

# 房间脚本 - 管理房间内容和状态

enum RoomState {
	UNEXPLORED,  # 未探索
	EXPLORING,   # 探索中
	EXPLORED     # 已探索
}

var room_id: Vector2i = Vector2i.ZERO
var room_size: Vector2 = Vector2(1152, 648)
var obstacle_count: int = 10
var has_saved_data: bool = false

# 房间状态
var room_state: RoomState = RoomState.UNEXPLORED
var is_room_completed: bool = false
var alive_enemy_count: int = 0

# 房间内容容器
var obstacles_container: Node2D
var enemies_container: Node2D

# 房间内容列表
var obstacles: Array = []
var enemies: Array = []

# 保存的数据
var saved_obstacle_data: Array = []
var saved_enemy_data: Array = []

# 连接关系
var connections: Array[Vector2i] = []

signal room_completed(room_id: Vector2i)
signal enemy_died_in_room(room_id: Vector2i, remaining_enemies: int)
signal enemy_count_changed(room_id: Vector2i, enemy_count: int)

func _ready() -> void:
	# 创建房间背景
	create_room_background()
	
	# 创建容器
	obstacles_container = Node2D.new()
	obstacles_container.name = "Obstacles"
	add_child(obstacles_container)
	
	enemies_container = Node2D.new()
	enemies_container.name = Constants.NODE_ENEMIES_CONTAINER
	add_child(enemies_container)
	
	print("房间 ", room_id, " 创建完成")

func setup_room_content() -> void:
	"""设置房间内容"""
	# 如果有保存的数据，使用保存的数据；否则生成新的
	if has_saved_data:
		load_room_data()
	else:
		generate_obstacles()
		generate_enemies()
		generate_chest()  # 生成宝箱
		save_room_data()
	
	# 设置房间状态
	if enemies.size() > 0:
		room_state = RoomState.EXPLORING
		alive_enemy_count = enemies.size()
		print("房间 ", room_id, " 开始探索，敌人数: ", alive_enemy_count)
	else:
		room_state = RoomState.EXPLORED
		is_room_completed = true
		alive_enemy_count = 0
		print("房间 ", room_id, " 无敌人，直接设为已探索")
	
	# 为所有敌人连接死亡信号
	connect_enemy_signals()
	
	print("房间 ", room_id, " 内容设置完成，状态: ", RoomState.keys()[room_state])

func generate_obstacles() -> void:
	"""生成障碍物（网格化布局，避免形成封闭环）"""
	# 初始房间不生成障碍物，避免卡死玩家
	if is_start_room():
		print("🏠 初始房间 (0,0) 不生成障碍物")
		return
	
	print("🧱 开始生成网格化障碍物，房间: ", room_id)
	
	var obstacle_scene = preload("res://Scenes/Obstacle.tscn")
	var grid_size = 64  # 网格大小（与障碍物大小一致）
	
	# 计算网格数量（留出边缘空间）
	var margin = 150  # 边缘留白
	var grid_area_width = room_size.x - margin * 2
	var grid_area_height = room_size.y - margin * 2
	var grid_cols = int(grid_area_width / grid_size)
	var grid_rows = int(grid_area_height / grid_size)
	
	print("  📐 网格尺寸: ", grid_cols, "x", grid_rows, " (", grid_cols * grid_rows, " 格子)")
	
	# 创建网格地图（0=空，1=障碍）
	var grid_map = []
	for y in range(grid_rows):
		var row = []
		for x in range(grid_cols):
			row.append(0)
		grid_map.append(row)
	
	# 随机放置障碍物（约15-25%的格子）
	var obstacle_density = randf_range(0.15, 0.25)
	var target_obstacle_count = int(grid_cols * grid_rows * obstacle_density)
	print("  🎯 目标障碍物数量: ", target_obstacle_count, " (密度: ", int(obstacle_density * 100), "%)")
	
	var placed_obstacles = []
	var attempts = 0
	var max_attempts = target_obstacle_count * 3
	
	while placed_obstacles.size() < target_obstacle_count and attempts < max_attempts:
		attempts += 1
		
		# 随机选择一个格子
		var grid_x = randi() % grid_cols
		var grid_y = randi() % grid_rows
		
		# 跳过已有障碍物的格子
		if grid_map[grid_y][grid_x] == 1:
			continue
		
		# 临时放置障碍物
		grid_map[grid_y][grid_x] = 1
		
		# 检查连通性（确保不会形成封闭环）
		if is_grid_connected(grid_map, grid_cols, grid_rows):
			# 连通性良好，保留这个障碍物
			placed_obstacles.append(Vector2i(grid_x, grid_y))
		else:
			# 连通性被破坏，移除这个障碍物
			grid_map[grid_y][grid_x] = 0
	
	print("  ✅ 成功放置 ", placed_obstacles.size(), " 个障碍物")
	
	# 在场景中实例化障碍物
	for grid_pos in placed_obstacles:
		var obstacle = obstacle_scene.instantiate()
		
		# 计算障碍物的世界坐标（格子中心）
		var world_pos = Vector2(
			margin + grid_pos.x * grid_size + grid_size / 2.0,
			margin + grid_pos.y * grid_size + grid_size / 2.0
		)
		
		# 目前统一生成rock类型（保留类型系统以便将来扩展）
		obstacle.initialize("rock", world_pos)
		obstacles_container.add_child(obstacle)
		obstacles.append(obstacle)
	
	print("  🎉 障碍物生成完成")

func is_grid_connected(grid_map: Array, cols: int, rows: int) -> bool:
	"""使用洪水填充算法检查网格连通性"""
	# 找到第一个空格子作为起点
	var start_pos = Vector2i(-1, -1)
	for y in range(rows):
		for x in range(cols):
			if grid_map[y][x] == 0:
				start_pos = Vector2i(x, y)
				break
		if start_pos.x != -1:
			break
	
	# 如果没有空格子，认为连通（虽然这种情况不应该发生）
	if start_pos.x == -1:
		return true
	
	# 洪水填充，统计可达的空格子数量
	var visited = {}
	var queue = [start_pos]
	visited[start_pos] = true
	var reachable_count = 0
	
	while queue.size() > 0:
		var current = queue.pop_front()
		reachable_count += 1
		
		# 检查四个方向的邻居
		var directions = [
			Vector2i(0, -1),  # 上
			Vector2i(0, 1),   # 下
			Vector2i(-1, 0),  # 左
			Vector2i(1, 0)    # 右
		]
		
		for dir in directions:
			var next_pos = current + dir
			
			# 检查边界
			if next_pos.x < 0 or next_pos.x >= cols or next_pos.y < 0 or next_pos.y >= rows:
				continue
			
			# 检查是否已访问或是障碍物
			if next_pos in visited or grid_map[next_pos.y][next_pos.x] == 1:
				continue
			
			visited[next_pos] = true
			queue.append(next_pos)
	
	# 统计总的空格子数量
	var total_empty_count = 0
	for y in range(rows):
		for x in range(cols):
			if grid_map[y][x] == 0:
				total_empty_count += 1
	
	# 如果所有空格子都可达，则连通
	return reachable_count == total_empty_count

func generate_enemies() -> void:
	# 如果是起始房间(0,0)，不生成敌人
	if is_start_room():
		print("起始房间 (0,0) 不生成敌人")
		alive_enemy_count = 0
		# 确保起始房间状态正确
		if room_state != RoomState.EXPLORED:
			room_state = RoomState.EXPLORED
			is_room_completed = true
		return
	
	var dungeon_size = get_dungeon_size()
	
	# 根据新的刷怪逻辑确定敌人类型和数量
	var enemies_to_spawn = determine_enemy_types(dungeon_size.x, dungeon_size.y)
	
	if enemies_to_spawn.is_empty():
		print("房间 ", room_id, " 不生成敌人")
		alive_enemy_count = 0
		room_state = RoomState.EXPLORED
		is_room_completed = true
		return
	
	var spawn_area = get_safe_spawn_area()
	
	print("正在生成房间内容: ", room_id)
	
	# 创建指定类型的敌人
	for enemy_type in enemies_to_spawn:
		var enemy = create_enemy_by_type(enemy_type)
		if enemy:
			# 随机位置，避免与障碍物重叠
			var enemy_pos = get_valid_spawn_position(spawn_area)
			enemy.position = enemy_pos
			
			# 设置敌人的房间ID
			enemy.room_id = room_id
			print("🏠 生成 ", enemy.character_name, " (", enemy_type, ") 在位置: ", enemy_pos, " 房间: ", room_id)
			
			enemies_container.add_child(enemy)
			enemies.append(enemy)
			
			print("  ✅ ", enemy.character_name, " 已添加到场景树，可见性: ", enemy.visible, ", z_index: ", enemy.z_index)
			
			# 连接敌人死亡信号
			enemy.character_died.connect(_on_enemy_character_died)
	
	alive_enemy_count = enemies.size()
	print("房间 ", room_id, " 生成了 ", enemies.size(), " 个敌人")
	
	# 随机指定一个敌人携带银钥匙（BOSS房间除外）
	if enemies.size() > 0 and not is_boss_room(dungeon_size):
		var key_holder_index = randi() % enemies.size()
		var key_holder = enemies[key_holder_index]
		key_holder.has_silverkey = true
		print("🔑 ", key_holder.character_name, " (#", key_holder_index, ") 携带银钥匙")
	elif is_boss_room(dungeon_size):
		print("🏆 BOSS房间不分配银钥匙")
	
	# 发出敌人计数变化信号
	if alive_enemy_count > 0:
		enemy_count_changed.emit(room_id, alive_enemy_count)

func generate_chest() -> void:
	"""生成宝箱"""
	# 起始房间不生成宝箱
	if is_start_room():
		print("📦 起始房间 (0,0) 不生成宝箱")
		return
	
	# BOSS房间不生成宝箱
	if is_boss_room(get_dungeon_size()):
		print("📦 BOSS房间不生成宝箱")
		return
	
	print("📦 开始生成宝箱，房间: ", room_id)
	
	# 加载宝箱场景
	var ChestScene = preload("res://Scenes/Chest.tscn")
	var chest = ChestScene.instantiate()
	
	# 找到合适的生成位置（避开障碍物和敌人）
	var chest_pos = get_valid_chest_position(get_safe_spawn_area())
	chest.position = chest_pos
	
	# 设置z_index确保宝箱可见
	chest.z_index = 1
	
	# 添加到房间
	add_child(chest)
	
	print("  ✓ 宝箱已添加到房间")
	print("    - 位置: ", chest_pos)
	print("    - 全局位置: ", chest.global_position)
	print("    - 可见性: ", chest.visible)
	print("    - z_index: ", chest.z_index)

func get_valid_chest_position(spawn_area: Rect2) -> Vector2:
	"""获取有效的宝箱生成位置（避开障碍物和敌人）"""
	var max_attempts = 50
	var min_distance_to_obstacle = 100.0
	var min_distance_to_enemy = 100.0
	
	for attempt in range(max_attempts):
		var pos = Vector2(
			randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x),
			randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
		)
		
		# 检查与障碍物的距离
		var too_close_to_obstacle = false
		for obstacle in obstacles:
			if is_instance_valid(obstacle):
				var distance = pos.distance_to(obstacle.position)
				if distance < min_distance_to_obstacle:
					too_close_to_obstacle = true
					break
		
		if too_close_to_obstacle:
			continue
		
		# 检查与敌人的距离
		var too_close_to_enemy = false
		for enemy in enemies:
			if is_instance_valid(enemy):
				var distance = pos.distance_to(enemy.position)
				if distance < min_distance_to_enemy:
					too_close_to_enemy = true
					break
		
		if too_close_to_enemy:
			continue
		
		# 找到了合适的位置
		return pos
	
	# 如果找不到合适位置，返回房间中心
	print("  ⚠️ 未找到理想的宝箱位置，使用房间中心")
	return room_size / 2

func determine_enemy_types(dungeon_width: int, dungeon_height: int) -> Array[String]:
	return SpawnPlanner.determine_enemy_types(room_id, dungeon_width, dungeon_height)

func is_start_room() -> bool:
	return room_id == START_ROOM_ID

func get_dungeon_size() -> Vector2i:
	var dungeon_generator = get_tree().current_scene.get_node_or_null(Constants.NODE_DUNGEON_GENERATOR)
	if dungeon_generator:
		return Vector2i(dungeon_generator.dungeon_width, dungeon_generator.dungeon_height)
	return DEFAULT_DUNGEON_SIZE

func is_boss_room(dungeon_size: Vector2i) -> bool:
	return room_id == Vector2i(dungeon_size.x - 1, dungeon_size.y - 1)

func get_safe_spawn_area() -> Rect2:
	return Rect2(
		Vector2(SAFE_SPAWN_MARGIN, SAFE_SPAWN_MARGIN),
		room_size - Vector2(SAFE_SPAWN_MARGIN * 2, SAFE_SPAWN_MARGIN * 2)
	)

func create_enemy_by_type(enemy_type: String) -> Node:
	"""根据类型创建敌人（使用新的敌人子类）"""
	return EnemyTypes.create_enemy(enemy_type, room_id)

func get_valid_spawn_position(spawn_area: Rect2) -> Vector2:
	"""获取有效的生成位置，避免与障碍物重叠"""
	var max_attempts = 50
	var attempt = 0
	
	while attempt < max_attempts:
		var pos = Vector2(
			randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x),
			randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
		)
		
		# 检查是否与现有障碍物重叠
		var is_valid = true
		for obstacle in obstacles:
			if pos.distance_to(obstacle.position) < 100:  # 最小距离100像素
				is_valid = false
				break
		
		if is_valid:
			return pos
		
		attempt += 1
	
	# 如果找不到合适位置，返回中心点
	return spawn_area.get_center()

func create_room_background() -> void:
	# 创建房间背景
	var room_background = ColorRect.new()
	room_background.size = room_size
	room_background.color = Color(0.2, 0.3, 0.25, 1.0)  # 深绿色背景
	room_background.z_index = -10  # 确保在最底层
	add_child(room_background)
	move_child(room_background, 0)  # 移到最前面（最底层）

func save_room_data() -> void:
	# 保存障碍物数据
	saved_obstacle_data.clear()
	for obstacle in obstacles:
		if is_instance_valid(obstacle):
			saved_obstacle_data.append(SaveCodec.create_obstacle_data(obstacle))
	
	# 保存敌人数据
	saved_enemy_data.clear()
	for enemy in enemies:
		if is_instance_valid(enemy):
			saved_enemy_data.append(SaveCodec.create_enemy_data(enemy))
	
	has_saved_data = true
	print("已保存房间数据: ", room_id, " 障碍物:", saved_obstacle_data.size(), " 敌人:", saved_enemy_data.size())

func get_enemy_type_as_int(enemy: Node) -> int:
	"""获取敌人类型的整数表示（兼容性方法）"""
	return EnemyTypes.to_legacy_type_id(get_enemy_type_id(enemy))

func get_enemy_type_id(enemy: Node) -> String:
	"""获取敌人类型ID，用于保存和恢复房间状态"""
	return EnemyTypes.from_character_name(enemy.character_name)

func load_room_data() -> void:
	# 清理现有数据
	clear_room_content()
	
	# 加载障碍物
	var obstacle_scene = preload("res://Scenes/Obstacle.tscn")
	for obstacle_data in saved_obstacle_data:
		var obstacle = obstacle_scene.instantiate()
		# 恢复障碍物的类型和位置
		obstacle.initialize(obstacle_data.type, obstacle_data.position)
		obstacles_container.add_child(obstacle)
		obstacles.append(obstacle)
	
	# 加载敌人（只加载存活的敌人）
	for enemy_data in saved_enemy_data:
		if SaveCodec.is_saved_enemy_alive(enemy_data):
			var enemy = create_enemy_by_type_from_data(enemy_data)
			if enemy:
				enemy.position = enemy_data.get("position", Vector2.ZERO)
				enemy.room_id = room_id
				
				enemies_container.add_child(enemy)
				
				# 延迟设置属性，确保CharacterBase已初始化
				await get_tree().process_frame
				
				# 直接设置属性，新架构保证这些属性存在
				enemy.max_health = int(enemy_data.get("max_health", enemy.max_health))
				enemy.health = int(enemy_data.get("health", enemy.health))
				if "has_silverkey" in enemy:
					enemy.has_silverkey = bool(enemy_data.get("has_silverkey", false))
				
				enemies.append(enemy)
				
				# 连接敌人死亡信号
				enemy.character_died.connect(_on_enemy_character_died)
	
	print("已加载房间数据: ", room_id, " 障碍物:", obstacles.size(), " 敌人:", enemies.size())

func create_enemy_by_type_from_data(enemy_data: Dictionary) -> Node:
	"""从保存的数据创建敌人（使用新的敌人子类）"""
	return create_enemy_by_type(SaveCodec.get_enemy_type_id(enemy_data))

func _on_enemy_character_died(enemy: CharacterBase) -> void:
	"""敌人死亡处理"""
	print("👹 房间 ", room_id, " - 敌人死亡: ", enemy.character_name)
	print("  当前计数: ", alive_enemy_count, " → ", alive_enemy_count - 1)
	
	# 从敌人列表中移除死亡的敌人
	if enemy in enemies:
		enemies.erase(enemy)
		print("  ✅ 已从enemies列表中移除")
	else:
		print("  ⚠️ 该敌人不在enemies列表中！")
	
	# 更新存活敌人计数
	alive_enemy_count = max(0, alive_enemy_count - 1)
	print("  剩余敌人数: ", alive_enemy_count, " (列表中实际: ", enemies.size(), ")")
	
	# 发出信号
	enemy_died_in_room.emit(room_id, alive_enemy_count)
	enemy_count_changed.emit(room_id, alive_enemy_count)
	
	# 检查房间是否完成
	if alive_enemy_count == 0 and not is_room_completed:
		var old_state = room_state
		room_state = RoomState.EXPLORED
		is_room_completed = true
		room_completed.emit(room_id)
		print("房间 ", room_id, " 探索完成! 所有敌人已被消灭")
		
		# 更新连接的通道状态
		if old_state != room_state:
			update_connected_corridors()

func clear_room_content() -> void:
	"""清理房间内容"""
	# 清理障碍物
	for obstacle in obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacles.clear()
	
	# 清理敌人
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

func connect_enemy_signals() -> void:
	"""连接所有敌人的死亡信号"""
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.character_died.is_connected(_on_enemy_character_died):
			enemy.character_died.connect(_on_enemy_character_died)

func get_room_state() -> RoomState:
	"""获取房间状态"""
	return room_state

func set_room_state(new_state: RoomState) -> void:
	"""设置房间状态"""
	var old_state = room_state
	room_state = new_state
	
	if old_state != new_state:
		update_connected_corridors()
		print("房间 ", room_id, " 状态变化: ", RoomState.keys()[old_state], " → ", RoomState.keys()[new_state])

func is_room_exploration_completed() -> bool:
	"""检查房间是否探索完成"""
	return is_room_completed or room_state == RoomState.EXPLORED

func update_connected_corridors() -> void:
	"""更新连接的通道状态"""
	var dungeon_generator = get_tree().current_scene.get_node_or_null(Constants.NODE_DUNGEON_GENERATOR)
	if dungeon_generator and dungeon_generator.has_method("update_corridors_for_room"):
		dungeon_generator.update_corridors_for_room(room_id, room_state)

# 连接关系管理
func add_connection(direction: Vector2i) -> void:
	"""添加连接方向"""
	if direction not in connections:
		connections.append(direction)

func has_connection(direction: Vector2i) -> bool:
	"""检查是否有指定方向的连接"""
	return direction in connections

func get_connections() -> Array[Vector2i]:
	"""获取所有连接方向"""
	return connections.duplicate()

func create_room_walls_based_on_connections() -> void:
	"""基于连接关系创建房间墙体"""
	create_room_border()
	create_room_walls()
	print("房间 ", room_id, " 墙体创建完成，连接数: ", connections.size())

func create_room_border() -> void:
	"""创建房间边界线（视觉效果）"""
	var border_color = Color(0.4, 0.4, 0.5, 0.8)
	var border_width = 4
	
	# 顶边
	var top_border = ColorRect.new()
	top_border.name = "TopBorder"
	top_border.color = border_color
	top_border.size = Vector2(room_size.x, border_width)
	top_border.position = Vector2(0, 0)
	top_border.z_index = -7
	add_child(top_border)
	
	# 底边
	var bottom_border = ColorRect.new()
	bottom_border.name = "BottomBorder"
	bottom_border.color = border_color
	bottom_border.size = Vector2(room_size.x, border_width)
	bottom_border.position = Vector2(0, room_size.y - border_width)
	bottom_border.z_index = -7
	add_child(bottom_border)
	
	# 左边
	var left_border = ColorRect.new()
	left_border.name = "LeftBorder"
	left_border.color = border_color
	left_border.size = Vector2(border_width, room_size.y)
	left_border.position = Vector2(0, 0)
	left_border.z_index = -7
	add_child(left_border)
	
	# 右边
	var right_border = ColorRect.new()
	right_border.name = "RightBorder"
	right_border.color = border_color
	right_border.size = Vector2(border_width, room_size.y)
	right_border.position = Vector2(room_size.x - border_width, 0)
	right_border.z_index = -7
	add_child(right_border)

func create_room_walls() -> void:
	"""创建房间四周的碰撞墙体"""
	var wall_thickness = 20
	var door_width = 120  # 门口宽度
	
	# 为每个方向创建墙体
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for direction in directions:
		if not has_connection(direction):
			# 无连接方向：创建完整墙体
			create_full_wall(direction, wall_thickness)
			print("房间 ", room_id, " 创建完整墙体: ", direction)
		else:
			# 有连接方向：创建门口两侧的墙体（为通道留出空间）
			create_wall_with_passage(direction, wall_thickness, door_width)
			print("房间 ", room_id, " 创建带通道口的墙体: ", direction)

func create_full_wall(direction: Vector2i, wall_thickness: int = 20) -> void:
	"""创建完整的墙体"""
	match direction:
		Vector2i.UP:
			create_wall_segment(Vector2(0, -wall_thickness), Vector2(room_size.x, wall_thickness))
		Vector2i.DOWN:
			create_wall_segment(Vector2(0, room_size.y), Vector2(room_size.x, wall_thickness))
		Vector2i.LEFT:
			create_wall_segment(Vector2(-wall_thickness, 0), Vector2(wall_thickness, room_size.y))
		Vector2i.RIGHT:
			create_wall_segment(Vector2(room_size.x, 0), Vector2(wall_thickness, room_size.y))

func create_wall_with_passage(direction: Vector2i, wall_thickness: int, door_width: int) -> void:
	"""创建带门口的墙体"""
	match direction:
		Vector2i.UP:
			# 上方墙体，中间留门口
			var side_wall_width = (room_size.x - door_width) / 2
			create_wall_segment(Vector2(0, -wall_thickness), Vector2(side_wall_width, wall_thickness))
			create_wall_segment(Vector2(room_size.x - side_wall_width, -wall_thickness), Vector2(side_wall_width, wall_thickness))
		Vector2i.DOWN:
			# 下方墙体，中间留门口
			var side_wall_width = (room_size.x - door_width) / 2
			create_wall_segment(Vector2(0, room_size.y), Vector2(side_wall_width, wall_thickness))
			create_wall_segment(Vector2(room_size.x - side_wall_width, room_size.y), Vector2(side_wall_width, wall_thickness))
		Vector2i.LEFT:
			# 左方墙体，中间留门口
			var side_wall_height = (room_size.y - door_width) / 2
			create_wall_segment(Vector2(-wall_thickness, 0), Vector2(wall_thickness, side_wall_height))
			create_wall_segment(Vector2(-wall_thickness, room_size.y - side_wall_height), Vector2(wall_thickness, side_wall_height))
		Vector2i.RIGHT:
			# 右方墙体，中间留门口
			var side_wall_height = (room_size.y - door_width) / 2
			create_wall_segment(Vector2(room_size.x, 0), Vector2(wall_thickness, side_wall_height))
			create_wall_segment(Vector2(room_size.x, room_size.y - side_wall_height), Vector2(wall_thickness, side_wall_height))

func create_wall_segment(wall_pos: Vector2, wall_size: Vector2) -> void:
	"""创建墙体段"""
	# 创建碰撞墙体
	var wall = StaticBody2D.new()
	wall.name = "RoomWall_" + str(wall_pos.x) + "_" + str(wall_pos.y)
	wall.position = wall_pos
	
	# 设置碰撞层级
	wall.set_collision_layer_value(1, true)  # 墙体层
	wall.set_collision_mask_value(2, true)   # 可以与玩家碰撞
	
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
	wall_visual.color = Color(0.3, 0.3, 0.35, 1.0)  # 深灰色墙体
	wall_visual.z_index = -6
	wall.add_child(wall_visual)
	
	add_child(wall)
	print("创建房间墙体段: 位置", wall_pos, " 大小", wall_size)
