extends "res://scripts/AI/AIBase.gd"

# 👑 BOSS AI - 保持距离游走普攻，移动慢血厚，可召唤小兵

var boss_preferred_distance: float = 150.0  # BOSS偏好的攻击距离
var min_distance: float = 120.0  # 最小保持距离
var max_distance: float = 200.0  # 最大攻击距离
var summon_cooldown: float = 15.0  # 召唤技能冷却时间
var last_summon_time: float = 0.0
var summon_range: float = 300.0  # 召唤范围

var move_timer: float = 0.0
var move_direction: Vector2 = Vector2.ZERO

func _init(character: Node = null):
	super._init(character)
	ai_type = AIType.AGGRESSIVE
	ai_name = "BOSS AI"
	
	# BOSS AI配置
	aggression_level = 1.2
	detection_range = 400.0
	attack_range = 180.0  # 较长的攻击距离
	reaction_time = 0.2  # 反应很快
	decision_interval = 0.6  # 决策频繁
	movement_style = "tactical"

func setup_ai() -> void:
	"""设置BOSS AI特性"""
	super.setup_ai()
	
	if decision_timer:
		decision_timer.wait_time = decision_interval

## ========== 重写行为方法 ==========

func execute_idle_behavior() -> void:
	"""BOSS空闲行为"""
	super.execute_idle_behavior()
	
	# BOSS总是在巡逻寻找目标
	if not has_valid_target():
		change_state(AIState.PATROL)

func execute_chase_behavior() -> void:
	"""BOSS追击行为 - 保持距离并准备攻击"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 进入攻击范围
	if distance_to_target <= attack_range and distance_to_target >= min_distance:
		change_state(AIState.ATTACK)
		return
	
	# 距离太远，慢慢靠近
	if distance_to_target > max_distance:
		if distance_to_target > lose_target_distance:
			lose_target()
			return
		else:
			approach_target_slowly()
	# 距离太近，后退
	elif distance_to_target < min_distance:
		retreat_from_target()

func execute_attack_behavior() -> void:
	"""BOSS攻击行为"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 距离不合适，调整位置
	if distance_to_target > max_distance or distance_to_target < min_distance:
		change_state(AIState.CHASE)
		return
	
	# 检查是否可以召唤小兵
	if can_use_summon():
		perform_summon_ability()
	else:
		# 执行普通攻击和游走
		perform_boss_attack_and_move()

## ========== 特殊行为实现 ==========

func approach_target_slowly() -> void:
	"""BOSS慢慢接近目标"""
	if not current_target:
		return
	
	var direction = (current_target.global_position - owner_character.global_position).normalized()
	var target_pos = current_target.global_position - direction * boss_preferred_distance
	owner_character.move_towards(target_pos, 0.5)  # 较慢的移动速度

func retreat_from_target() -> void:
	"""BOSS从目标后退"""
	if not current_target:
		return
	
	var direction = (owner_character.global_position - current_target.global_position).normalized()
	var retreat_pos = owner_character.global_position + direction * 60
	owner_character.move_towards(retreat_pos, 0.7)

func perform_boss_attack_and_move() -> void:
	"""BOSS攻击并移动"""
	if not owner_character or not current_target:
		return
	
	# 执行攻击
	if owner_character.can_attack():
		owner_character.perform_attack(current_target.global_position, current_target)
		print("👑 BOSS发起攻击!")
	
	# 执行战术移动
	perform_tactical_movement()

func perform_tactical_movement() -> void:
	"""执行战术移动"""
	move_timer -= get_physics_process_delta_time()
	
	if move_timer <= 0.0:
		# 选择新的移动方向
		update_movement_direction()
		move_timer = randf_range(2.0, 4.0)  # 2-4秒后改变方向
	
	# 执行移动
	if move_direction != Vector2.ZERO:
		var move_pos = owner_character.global_position + move_direction * 50
		# 确保不会离目标太远
		var distance_to_target_from_move = move_pos.distance_to(current_target.global_position)
		if distance_to_target_from_move < max_distance * 1.2:
			owner_character.move_towards(move_pos, 0.4)  # 缓慢移动

func update_movement_direction() -> void:
	"""更新移动方向"""
	if not current_target:
		return
	
	# 随机选择移动方向，但倾向于保持与目标的距离
	var to_target = (current_target.global_position - owner_character.global_position).normalized()
	var perpendicular = Vector2(-to_target.y, to_target.x)
	
	# 70%概率左右移动，30%概率前后移动
	if randf() < 0.7:
		move_direction = perpendicular if randf() < 0.5 else -perpendicular
	else:
		move_direction = to_target if randf() < 0.5 else -to_target

func can_use_summon() -> bool:
	"""检查是否可以使用召唤技能"""
	var current_time = Time.get_time_dict_from_system()
	var time_since_last_summon = current_time.get("second", 0) - last_summon_time
	
	# 冷却时间检查
	return time_since_last_summon >= summon_cooldown

func perform_summon_ability() -> void:
	"""执行召唤技能"""
	if not owner_character:
		return
	
	print("👑 BOSS使用召唤技能!")
	
	# 更新最后使用召唤的时间
	last_summon_time = Time.get_time_dict_from_system().get("second", 0)
	
	# 创建召唤特效
	create_summon_effect()
	
	# 召唤一个近战小兵和一个远程小兵
	summon_minion("melee")
	await get_tree().create_timer(0.5).timeout  # 稍微延迟第二个召唤
	summon_minion("ranged")

func summon_minion(minion_type: String) -> void:
	"""召唤小兵"""
	var room = get_current_room()
	if not room:
		print("❌ BOSS无法找到当前房间，召唤失败")
		return
	
	# 在房间内随机位置召唤
	var spawn_pos = get_random_spawn_position_in_room(room)
	if spawn_pos == Vector2.ZERO:
		print("❌ BOSS无法找到合适的召唤位置")
		return
	
	# 创建敌人
	var enemy_scene = preload("res://Scenes/Enemy.tscn")
	var summoned_enemy = enemy_scene.instantiate()
	
	# 设置敌人类型
	if minion_type == "melee":
		summoned_enemy.setup_enemy_type("melee_soldier")
	else:
		summoned_enemy.setup_enemy_type("ranged_soldier")
	
	summoned_enemy.position = spawn_pos
	summoned_enemy.room_id = owner_character.room_id
	
	# 添加到房间
	var enemies_container = room.get_node_or_null("Enemies")
	if enemies_container:
		enemies_container.add_child(summoned_enemy)
		room.enemies.append(summoned_enemy)
		
		# 连接信号
		summoned_enemy.character_died.connect(room._on_enemy_character_died)
		
		print("👑 BOSS召唤了一个", minion_type, "小兵在位置:", spawn_pos)
	else:
		summoned_enemy.queue_free()
		print("❌ 无法找到敌人容器")

func get_current_room():
	"""获取当前房间"""
	var dungeon_generator = get_tree().current_scene.get_node_or_null("DungeonGenerator")
	if dungeon_generator:
		return dungeon_generator.current_room
	return null

func get_random_spawn_position_in_room(room) -> Vector2:
	"""在房间内获取随机召唤位置"""
	if not room:
		return Vector2.ZERO
	
	var room_size = room.room_size
	var margin = 100  # 离边界的距离
	
	# 尝试10次找到合适的位置
	for i in range(10):
		var spawn_pos = Vector2(
			randf_range(margin, room_size.x - margin),
			randf_range(margin, room_size.y - margin)
		)
		
		# 转换为全局坐标
		spawn_pos += room.position
		
		# 简单检查：不要离BOSS太近
		if spawn_pos.distance_to(owner_character.global_position) > 80:
			return spawn_pos
	
	# 如果找不到合适位置，返回房间中心
	return room.position + room_size / 2

func create_summon_effect() -> void:
	"""创建召唤视觉效果"""
	var summon_effect = preload("res://Scenes/SkillEffect.tscn").instantiate()
	summon_effect.position = owner_character.global_position
	summon_effect.skill_type = "boss_summon"
	summon_effect.life_time = 1.5
	summon_effect.damage = 0
	
	# 设置召唤效果的视觉
	var effect_sprite = summon_effect.get_node_or_null("Sprite2D")
	if effect_sprite:
		effect_sprite.modulate = Color.PURPLE
		effect_sprite.scale = Vector2(2.0, 2.0)
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null("SkillEffects")
	if skill_effects:
		skill_effects.add_child(summon_effect)
	else:
		get_tree().current_scene.add_child(summon_effect)

## ========== 条件检查重写 ==========

func should_retreat() -> bool:
	"""BOSS从不撤退"""
	return false

func should_start_patrol() -> bool:
	"""BOSS总是巡逻"""
	return true

func find_new_target() -> void:
	"""BOSS寻找目标 - 总是选择玩家"""
	super.find_new_target()
	
	# BOSS优先攻击玩家
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		acquire_target(players[0])
