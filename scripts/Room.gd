extends Node2D
class_name Room

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
	enemies_container.name = "Enemies"
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
	# 生成障碍物
	var obstacle_scene = preload("res://Scenes/Obstacle.tscn")
	
	var safe_margin = 200
	var spawn_area = Rect2(
		Vector2(safe_margin, safe_margin),
		room_size - Vector2(safe_margin * 2, safe_margin * 2)
	)
	
	for i in range(obstacle_count):
		var obstacle = obstacle_scene.instantiate()
		
		var random_pos = Vector2(
			randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x),
			randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
		)
		
		var random_type = ["wall", "rock", "tree"][randi() % 3]
		
		# 使用新的初始化方法
		obstacle.initialize(random_type, random_pos)
		obstacles_container.add_child(obstacle)
		obstacles.append(obstacle)

func generate_enemies() -> void:
	# 如果是起始房间(0,0)，不生成敌人
	if room_id == Vector2i(0, 0):
		print("起始房间 (0,0) 不生成敌人")
		alive_enemy_count = 0
		# 确保起始房间状态正确
		if room_state != RoomState.EXPLORED:
			room_state = RoomState.EXPLORED
			is_room_completed = true
		return
	
	# 获取地牢信息来确定敌人类型
	var dungeon_generator = get_tree().current_scene.get_node_or_null("DungeonGenerator")
	var dungeon_width = 5
	var dungeon_height = 5
	if dungeon_generator:
		dungeon_width = dungeon_generator.dungeon_width
		dungeon_height = dungeon_generator.dungeon_height
	
	# 根据新的刷怪逻辑确定敌人类型和数量
	var enemies_to_spawn = determine_enemy_types(dungeon_width, dungeon_height)
	
	if enemies_to_spawn.is_empty():
		print("房间 ", room_id, " 不生成敌人")
		alive_enemy_count = 0
		room_state = RoomState.EXPLORED
		is_room_completed = true
		return
	
	var safe_margin = 150
	var spawn_area = Rect2(
		Vector2(safe_margin, safe_margin),
		room_size - Vector2(safe_margin * 2, safe_margin * 2)
	)
	
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
			print("🏠 生成 ", enemy.character_name, " 在房间 ", room_id)
			
			enemies_container.add_child(enemy)
			enemies.append(enemy)
			
			# 连接敌人死亡信号
			enemy.character_died.connect(_on_enemy_character_died)
	
	alive_enemy_count = enemies.size()
	print("房间 ", room_id, " 生成了 ", enemies.size(), " 个敌人")
	
	# 发出敌人计数变化信号
	if alive_enemy_count > 0:
		enemy_count_changed.emit(room_id, alive_enemy_count)

func determine_enemy_types(dungeon_width: int, dungeon_height: int) -> Array[String]:
	"""根据房间位置确定敌人类型"""
	var enemies_to_spawn: Array[String] = []
	
	# 最右下角的房间 - 只刷新一个BOSS
	if room_id == Vector2i(dungeon_width - 1, dungeon_height - 1):
		enemies_to_spawn.append("boss")
		print("🏆 BOSS房间: ", room_id)
		return enemies_to_spawn
	
	# 前三个房间的判断（通过探索顺序或距离判断）
	var distance_from_start = abs(room_id.x) + abs(room_id.y)  # 曼哈顿距离
	var is_early_room = distance_from_start <= 2  # 距离起始房间较近的前几个房间
	
	if is_early_room:
		# 前三个房间：只刷新普通近战和远程小兵
		var soldier_count = randi() % 3 + 2  # 2-4个普通士兵
		for i in range(soldier_count):
			if randf() < 0.6:  # 60%概率近战
				enemies_to_spawn.append("melee_soldier")
			else:  # 40%概率远程
				enemies_to_spawn.append("ranged_soldier")
		print("🥉 早期房间: ", room_id, " 距离起始点: ", distance_from_start)
	else:
		# 其他房间：可能刷新精英近战士兵 + 普通士兵
		var soldier_count = randi() % 3 + 1  # 1-3个普通士兵
		for i in range(soldier_count):
			if randf() < 0.5:  # 50%概率近战
				enemies_to_spawn.append("melee_soldier")
			else:  # 50%概率远程
				enemies_to_spawn.append("ranged_soldier")
		
		# 至多一个精英近战士兵
		if randf() < 0.7:  # 70%概率生成精英
			enemies_to_spawn.append("elite_melee")
		print("⭐ 后期房间: ", room_id, " 距离起始点: ", distance_from_start)
	
	return enemies_to_spawn

# 预加载敌人子类（使用不同的名称避免与全局类名冲突）
const MeleeEnemyScript = preload("res://scripts/enemies/MeleeEnemy.gd")
const RangedEnemyScript = preload("res://scripts/enemies/RangedEnemy.gd")
const EliteEnemyScript = preload("res://scripts/enemies/EliteEnemy.gd")
const BossEnemyScript = preload("res://scripts/enemies/BossEnemy.gd")

func create_enemy_by_type(enemy_type: String) -> Node:
	"""根据类型创建敌人（使用新的敌人子类）"""
	var enemy: Node
	
	# 根据类型创建对应的敌人子类
	match enemy_type:
		"melee_soldier":
			enemy = MeleeEnemyScript.create_melee_enemy(room_id)
		"ranged_soldier":
			enemy = RangedEnemyScript.create_ranged_enemy(room_id)
		"elite_melee":
			enemy = EliteEnemyScript.create_elite_enemy(room_id)
		"boss":
			enemy = BossEnemyScript.create_boss_enemy(room_id)
		_:
			print("⚠️ 未知敌人类型: ", enemy_type, "，默认创建近战小兵")
			enemy = MeleeEnemyScript.create_melee_enemy(room_id)
	
	return enemy

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
			var obstacle_data = {
				"type": obstacle.get_obstacle_type(),
				"position": obstacle.position
			}
			saved_obstacle_data.append(obstacle_data)
	
	# 保存敌人数据
	saved_enemy_data.clear()
	for enemy in enemies:
		if is_instance_valid(enemy):
			var enemy_data = {
				"position": enemy.position,
				"health": enemy.health,
				"max_health": enemy.max_health,
				"is_dead": enemy.is_dead,
				"enemy_type": get_enemy_type_as_int(enemy)
			}
			saved_enemy_data.append(enemy_data)
	
	has_saved_data = true
	print("已保存房间数据: ", room_id, " 障碍物:", saved_obstacle_data.size(), " 敌人:", saved_enemy_data.size())

func get_enemy_type_as_int(enemy: Node) -> int:
	"""获取敌人类型的整数表示（兼容性方法）"""
	var enemy_name = enemy.character_name
	if "近战" in enemy_name:
		return 0  # MELEE_SOLDIER
	elif "远程" in enemy_name:
		return 1  # RANGED_SOLDIER
	elif "精英" in enemy_name:
		return 2  # ELITE_MELEE
	elif "BOSS" in enemy_name:
		return 3  # BOSS
	else:
		return 0  # 默认近战

func load_room_data() -> void:
	# 清理现有数据
	clear_room_content()
	
	# 加载障碍物
	var obstacle_scene = preload("res://Scenes/Obstacle.tscn")
	for obstacle_data in saved_obstacle_data:
		var obstacle = obstacle_scene.instantiate()
		obstacle.initialize(obstacle_data.type, obstacle_data.position)
		obstacles_container.add_child(obstacle)
		obstacles.append(obstacle)
	
	# 加载敌人（只加载存活的敌人）
	for enemy_data in saved_enemy_data:
		if not enemy_data.is_dead:  # 只加载存活的敌人
			var enemy = create_enemy_by_type_from_data(enemy_data)
			if enemy:
				enemy.position = enemy_data.position
				enemy.room_id = room_id
				
				enemies_container.add_child(enemy)
				
				# 延迟设置属性，确保CharacterBase已初始化
				await get_tree().process_frame
				
				# 直接设置属性，新架构保证这些属性存在
				enemy.health = enemy_data.health
				enemy.max_health = enemy_data.max_health
				
				enemies.append(enemy)
				
				# 连接敌人死亡信号
				enemy.character_died.connect(_on_enemy_character_died)
	
	print("已加载房间数据: ", room_id, " 障碍物:", obstacles.size(), " 敌人:", enemies.size())

func create_enemy_by_type_from_data(enemy_data: Dictionary) -> Node:
	"""从保存的数据创建敌人（使用新的敌人子类）"""
	var enemy: Node
	var enemy_type_string = ""
	
	# 确定敌人类型
	if "enemy_type" in enemy_data:
		# 新版本有enemy_type字段
		match enemy_data.enemy_type:
			0: # MELEE_SOLDIER
				enemy_type_string = "melee_soldier"
			1: # RANGED_SOLDIER
				enemy_type_string = "ranged_soldier"
			2: # ELITE_MELEE
				enemy_type_string = "elite_melee"
			3: # BOSS
				enemy_type_string = "boss"
			_:
				enemy_type_string = "melee_soldier"
	else:
		# 旧版本没有enemy_type，根据名称推断
		var enemy_name = enemy_data.get("character_name", "")
		if "近战" in enemy_name:
			enemy_type_string = "melee_soldier"
		elif "远程" in enemy_name:
			enemy_type_string = "ranged_soldier"
		elif "精英" in enemy_name:
			enemy_type_string = "elite_melee"
		elif "BOSS" in enemy_name or "Boss" in enemy_name:
			enemy_type_string = "boss"
		else:
			enemy_type_string = "melee_soldier"
	
	# 使用统一的创建方法
	enemy = create_enemy_by_type(enemy_type_string)
	
	return enemy

func _on_enemy_character_died(enemy: CharacterBase) -> void:
	"""敌人死亡处理"""
	print("👹 敌人死亡: ", enemy.character_name)
	
	# 从敌人列表中移除死亡的敌人
	if enemy in enemies:
		enemies.erase(enemy)
	
	# 更新存活敌人计数
	alive_enemy_count = max(0, alive_enemy_count - 1)
	
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
	var dungeon_generator = get_tree().current_scene.get_node_or_null("DungeonGenerator")
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
