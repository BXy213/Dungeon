extends "res://scripts/EnemyCharacter.gd"
class_name SplitterEnemy

# 🔀 分裂体 - 死亡时分裂成小型敌人（参考DOTA育母蜘蛛/LOL玛尔扎哈虫子）

## ========== 分裂体特有属性 ==========

# 分裂相关
@export var split_count: int = 3  # 分裂数量
@export var is_mini_split: bool = false  # 是否为分裂出来的小型体
var mini_split_multiplier: float = 0.5  # 小型体属性倍率

# AI相关
var current_target: Node = null
var detection_range: float = 400.0
var lose_target_distance: float = 600.0

## ========== 静态创建方法 ==========

static func create_splitter_enemy(enemy_room_id: Vector2i) -> SplitterEnemy:
	"""静态工厂方法：创建分裂体"""
	var splitter = SplitterEnemy.new()
	splitter.is_room_enemy = true
	splitter.room_id = enemy_room_id
	return splitter

static func create_mini_splitter_enemy(enemy_room_id: Vector2i) -> SplitterEnemy:
	"""静态工厂方法：创建小型分裂体"""
	var mini_splitter = SplitterEnemy.new()
	mini_splitter.is_mini_split = true
	mini_splitter.is_room_enemy = true
	mini_splitter.room_id = enemy_room_id
	mini_splitter.apply_mini_split_stats()
	return mini_splitter

## ========== 初始化方法 ==========

func _init():
	super._init()
	
	# 设置分裂体属性
	if is_mini_split:
		# 小型分裂体
		character_name = "小分裂体"
		max_health = 30
		base_speed = 100.0
		base_attack_damage = 8
		attack_range = 120.0
		attack_cooldown = 1.2
		experience_reward = 10
	else:
		# 普通分裂体
		character_name = "分裂体"
		max_health = 100
		base_speed = 50.0
		base_attack_damage = 18
		attack_range = 150.0
		attack_cooldown = 2.0
		experience_reward = 45
	
	# ✅ 修复：初始血量应等于最大血量（统一设置）
	health = max_health
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage

func apply_mini_split_stats() -> void:
	"""应用小型分裂体属性。is_mini_split 在 _init() 后设置时也可复用。"""
	character_name = "小分裂体"
	max_health = 30
	health = 30
	base_speed = 110.0
	base_attack_damage = 8
	attack_range = 120.0
	attack_cooldown = 1.2
	experience_reward = 10
	current_speed = base_speed
	current_attack_damage = base_attack_damage
	current_defense = 0

func _ready():
	super._ready()
	
	var type_name = "小分裂体" if is_mini_split else "分裂体"
	print("🔀 ", type_name, " _ready() 被调用")
	print("  - 位置: ", global_position)
	print("  - 生命值: ", health, "/", max_health)
	print("  - is_dead: ", is_dead)
	print("  - visible: ", visible)
	
	# 确保节点已创建
	var existing_sprite = get_node_or_null("Sprite2D")
	if existing_sprite == null:
		setup_enemy_nodes()
	else:
		print("  - Sprite2D已存在")
	
	# 定期查找目标
	var target_timer = Timer.new()
	target_timer.wait_time = 0.5
	target_timer.timeout.connect(_find_target)
	target_timer.autostart = true
	add_child(target_timer)
	
	print("🔀 ", type_name, " _ready() 完成")

func setup_enemy_nodes() -> void:
	"""创建分裂体节点"""
	print("🔨 分裂体正在创建节点...")
	
	# 创建Sprite2D节点
	var splitter_sprite = Sprite2D.new()
	splitter_sprite.name = "Sprite2D"
	splitter_sprite.texture = preload("res://art/icon.webp")
	
	if is_mini_split:
		splitter_sprite.modulate = Color(0.6, 0.3, 0.6)  # 浅紫色
		splitter_sprite.scale = Vector2(0.25, 0.25)  # 小型
	else:
		splitter_sprite.modulate = Color(0.8, 0.2, 0.8)  # 紫色
		splitter_sprite.scale = Vector2(0.4, 0.4)
	
	add_child(splitter_sprite)
	print("  ✓ Sprite2D已创建")
	
	# 创建CollisionShape2D节点
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	
	if is_mini_split:
		shape.size = Vector2(10, 10)
	else:
		shape.size = Vector2(16, 16)
	
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# 创建血条
	create_health_bar()
	print("  ✓ 血条已创建")
	
	print("🔀 分裂体节点创建完成")

func setup_visuals() -> void:
	"""设置分裂体视觉效果"""
	# ✅ 修复：确保贴图颜色正确设置（即使Sprite2D预先存在）
	var splitter_sprite = get_node_or_null("Sprite2D")
	if splitter_sprite:
		if is_mini_split:
			splitter_sprite.modulate = Color(0.6, 0.3, 0.6)  # 浅紫色
			print("  ✓ 小分裂体贴图颜色已设置为浅紫色, visible: ", splitter_sprite.visible, ", scale: ", splitter_sprite.scale)
		else:
			splitter_sprite.modulate = Color(0.8, 0.2, 0.8)  # 紫色
			print("  ✓ 分裂体贴图颜色已设置为紫色, visible: ", splitter_sprite.visible, ", scale: ", splitter_sprite.scale)
	else:
		var type_name = "小分裂体" if is_mini_split else "分裂体"
		print("  ⚠️ ", type_name, "setup_visuals()时Sprite2D不存在！")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if is_dead or not current_target:
		return
	
	var distance_to_target = get_distance_to(current_target)
	
	if distance_to_target <= attack_range:
		# 在攻击范围内
		execute_attack_behavior()
	else:
		# 追击
		execute_chase_behavior()

## ========== 分裂体AI行为 ==========

func _find_target():
	"""寻找玩家目标"""
	if is_dead:
		return
	
	var player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= detection_range:
			current_target = player
		elif distance > lose_target_distance:
			current_target = null

## ========== 分裂逻辑 ==========

func die() -> void:
	"""死亡时分裂（除非是小型体）"""
	if is_dead:
		return
	
	var type_name = "小分裂体" if is_mini_split else "分裂体"
	print("💀 ", type_name, " 开始死亡流程")
	
	# 只有普通分裂体会分裂，小型体不会
	if not is_mini_split:
		print("🔀 分裂体死亡，正在分裂成 ", split_count, " 个小型体!")
		# ✅ 标记为已死亡，防止重复执行
		is_dead = true
		# ✅ 启动分裂流程（小分裂体生成完成后才会调用父类die()）
		_spawn_mini_splits()
	else:
		print("🔀 小分裂体死亡，不会分裂")
		# ✅ 小分裂体直接调用父类die()
		super.die()
		print("  ✅ ", type_name, " 死亡流程完成")

func _spawn_mini_splits() -> void:
	"""生成小型分裂体"""
	# 获取当前房间
	var current_room = null
	if get_parent() and get_parent().get_parent():
		current_room = get_parent().get_parent()
	if not current_room:
		print("⚠️ 无法找到当前房间，分裂失败")
		return
	
	var death_position = global_position
	print("🔀 开始分裂成 ", split_count, " 个小型体，死亡位置(全局): ", death_position)
	
	# 获取敌人容器，计算相对位置
	var enemies_container = current_room.get_node_or_null(Constants.NODE_ENEMIES_CONTAINER)
	if not enemies_container:
		print("⚠️ 无法找到敌人容器，分裂失败")
		return
	
	# ⚠️ 使用 call_deferred 延迟生成，避免在物理查询刷新期间修改物理状态
	call_deferred("_deferred_spawn_mini_splits", current_room, enemies_container, death_position)

func _deferred_spawn_mini_splits(current_room: Node, enemies_container: Node, death_position: Vector2) -> void:
	"""延迟生成小型分裂体（在下一帧执行）"""
	# 在周围生成小型分裂体
	for i in range(split_count):
		var mini_split = _create_mini_split()
		if mini_split:
			# 计算生成位置（围绕死亡位置），并确保不与障碍物重叠
			var angle = (TAU / split_count) * i
			var base_offset = Vector2(cos(angle), sin(angle)) * 40.0
			
			# ✅ 查找有效的生成位置（避开障碍物）
			var spawn_global_pos = _find_valid_spawn_position(death_position, base_offset)
			
			mini_split.room_id = room_id
			
			print("  🔀 #", i+1, " 创建完成，准备添加到场景树")
			print("    - 名称: ", mini_split.character_name)
			print("    - 生命值: ", mini_split.health, "/", mini_split.max_health)
			print("    - 目标位置(全局): ", spawn_global_pos)
			print("    - is_dead: ", mini_split.is_dead)
			
			# 添加到房间的敌人容器
			enemies_container.add_child(mini_split)
			
			# ✅ 添加后再设置全局位置（此时mini_split已在场景树中）
			mini_split.global_position = spawn_global_pos
			
			print("  🔀 生成小型分裂体 #", i+1)
			print("    - 实际位置(全局): ", mini_split.global_position)
			print("    - 可见: ", mini_split.visible)
			print("    - z_index: ", mini_split.z_index)
			
			# ✅ 添加到房间的敌人列表
			if "enemies" in current_room:
				current_room.enemies.append(mini_split)
			
			# ✅ 连接死亡信号
			if not mini_split.character_died.is_connected(current_room._on_enemy_character_died):
				mini_split.character_died.connect(current_room._on_enemy_character_died)
			
			# 更新房间的敌人计数
			if current_room.has_signal("enemy_count_changed"):
				var old_count = current_room.alive_enemy_count
				current_room.alive_enemy_count += 1
				print("  📊 更新房间敌人计数: ", old_count, " → ", current_room.alive_enemy_count)
				current_room.enemy_count_changed.emit(current_room.room_id, current_room.alive_enemy_count)
			
			print("  ✅ 小型分裂体 #", i+1, " 完全初始化完成")
	
	# ✅ 所有小分裂体生成完成后，再处理父分裂体的死亡逻辑
	print("🔀 所有小型分裂体已生成，开始处理父分裂体的死亡逻辑")
	_finalize_parent_death()

func _create_mini_split() -> SplitterEnemy:
	"""创建小型分裂体实例"""
	var mini_split = create_mini_splitter_enemy(room_id)
	
	print("  🔀 创建小分裂体: health=", mini_split.health, "/", mini_split.max_health)
	
	return mini_split

## ========== 攻击和追击行为 ==========

func execute_attack_behavior() -> void:
	"""执行攻击行为"""
	if current_target and can_attack():
		perform_attack(current_target.global_position, current_target)

func execute_chase_behavior() -> void:
	"""执行追击行为"""
	if current_target:
		# 使用智能寻路
		navigate_to_target(current_target.global_position)
		move_and_slide()

func set_projectile_appearance(projectile: Node) -> void:
	"""
	设置分裂体弹道外观
	✅ 重写基类方法，自定义紫色弹道
	"""
	var sprite_node = projectile.get_node_or_null("Sprite2D")
	if sprite_node:
		# 根据是否为小型分裂体设置不同的颜色
		if is_mini_split:
			sprite_node.modulate = Color(0.6, 0.3, 0.6)  # 浅紫色弹道（小型分裂体）
			sprite_node.scale = Vector2(0.22, 0.22)  # 更小的弹道
			print("  🎨 小分裂体弹道外观: 浅紫色, 大小 0.22")
		else:
			sprite_node.modulate = Color(0.8, 0.2, 0.8)  # 紫色弹道（普通分裂体）
			sprite_node.scale = Vector2(0.32, 0.32)  # 中等大小
			print("  🎨 分裂体弹道外观: 紫色, 大小 0.32")
	
	# 设置弹道速度
	projectile.speed = 300

func _finalize_parent_death() -> void:
	"""
	完成父分裂体的死亡逻辑
	
	注意：is_dead 已经在 die() 中设置为 true
	这里手动执行父类死亡流程中的其他操作
	"""
	# 改变状态
	change_state(CharacterState.DEAD)
	
	# 清除所有Buff
	if buff_system:
		buff_system.clear_all_buffs()
	
	# 停止移动
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# 播放死亡效果
	play_death_effect()
	
	# 发出死亡信号
	character_died.emit(self)
	
	# 播放死亡动画（会在1秒后销毁）
	play_death_animation()
	
	# 掉落奖励
	drop_rewards()
	
	# 通知房间敌人死亡
	notify_room_enemy_death()
	
	# 发出敌人击败信号
	enemy_defeated.emit(self, experience_reward)
	
	print("  ✅ 父分裂体死亡流程完成，等待动画后销毁")

## ========== 辅助方法 ==========

func _find_valid_spawn_position(center: Vector2, preferred_offset: Vector2) -> Vector2:
	"""
	查找有效的生成位置（避开障碍物并确保在房间内）
	
	参数：
	- center: 中心位置（死亡位置）
	- preferred_offset: 首选偏移量
	
	返回：不与障碍物重叠且在房间内的有效位置
	"""
	# 获取当前房间边界
	var room_bounds = get_current_room_bounds()
	
	var preferred_pos = center + preferred_offset
	
	# 检查首选位置是否有效（无障碍物且在房间内）
	if _is_position_valid(preferred_pos) and room_bounds.has_point(preferred_pos):
		return preferred_pos
	
	# 如果首选位置无效，尝试在周围寻找有效位置
	var search_radius = 60.0  # 搜索半径
	var max_attempts = 12  # 增加最大尝试次数
	
	for attempt in range(max_attempts):
		var random_angle = randf() * TAU
		var random_distance = randf_range(30.0, search_radius)
		var test_offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
		var test_pos = center + test_offset
		
		if _is_position_valid(test_pos) and room_bounds.has_point(test_pos):
			print("    ✅ 找到有效位置（尝试 ", attempt + 1, " 次）: ", test_pos)
			return test_pos
	
	# 如果所有尝试都失败，将中心位置限制在房间边界内
	print("    ⚠️ 无法找到有效位置，使用限制后的中心位置")
	var clamped_center = Vector2(
		clamp(center.x, room_bounds.position.x, room_bounds.position.x + room_bounds.size.x),
		clamp(center.y, room_bounds.position.y, room_bounds.position.y + room_bounds.size.y)
	)
	return clamped_center

func _is_position_valid(check_position: Vector2) -> bool:
	"""
	检查位置是否有效（不与障碍物重叠）
	
	使用物理查询检测该位置是否有障碍物
	"""
	if not is_inside_tree():
		return true  # 如果不在场景树中，无法检测，默认有效
	
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return true
	
	# 创建一个小的矩形区域查询（小分裂体的大小）
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(12, 12)  # 稍大于小分裂体的碰撞体积（10x10）
	query.shape = shape
	query.transform = Transform2D(0, check_position)
	query.collision_mask = Constants.LAYER_WORLD
	
	# 执行查询
	var results = space_state.intersect_shape(query, 1)
	
	# 如果没有碰撞，位置有效
	return results.is_empty()

func get_ai_description() -> String:
	"""获取AI描述"""
	if is_mini_split:
		return "小分裂体AI - 快速追击"
	else:
		return "分裂体AI - 死亡时分裂成小型体"
