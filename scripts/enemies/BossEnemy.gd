extends "res://scripts/EnemyCharacter.gd"
class_name BossEnemy

# 👑 BOSS - 保持距离，召唤小兵，战术移动

## ========== BOSS特有属性 ==========

var preferred_distance: float = 150.0  # BOSS偏好的攻击距离
var min_distance: float = 120.0  # 最小保持距离
var max_distance: float = 200.0  # 最大攻击距离
var summon_cooldown: float = 15.0  # 召唤技能冷却时间（秒）
var last_summon_time: float = 0.0  # 使用引擎时间戳
var summon_range: float = 300.0  # 召唤范围

var move_timer: float = 0.0
var move_direction: Vector2 = Vector2.ZERO

# AI行为属性
var current_target: Node = null
var detection_range: float = 500.0
var lose_target_distance: float = 600.0

func _init():
	super._init()
	
	# 设置BOSS属性
	character_name = "BOSS"
	max_health = 400
	health = max_health  # ✅ 修复：初始血量应等于最大血量
	base_speed = 50.0  # 移动较慢
	base_attack_damage = 25
	attack_range = 500.0
	attack_cooldown = 2.5
	experience_reward = 200
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage
	
	# BOSS特有属性 - 使用更可靠的时间初始化
	last_summon_time = Time.get_unix_time_from_system() - summon_cooldown

func _ready():
	super._ready()
	
	# 确保节点已创建，如果没有则立即创建
	if get_node_or_null("Sprite2D") == null:
		setup_enemy_nodes()
	
	# 定期查找目标
	var target_timer = Timer.new()
	target_timer.wait_time = 1.0
	target_timer.timeout.connect(_find_target)
	target_timer.autostart = true
	add_child(target_timer)

func setup_enemy_nodes() -> void:
	"""创建敌人必要的子节点"""
	# 创建Sprite2D节点
	var boss_sprite = Sprite2D.new()
	boss_sprite.name = "Sprite2D"
	boss_sprite.texture = preload("res://art/icon.webp")
	boss_sprite.modulate = Color.PURPLE  # 紫色
	boss_sprite.scale = Vector2(0.72, 0.72)
	add_child(boss_sprite)
	
	# 创建CollisionShape2D节点
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28.8, 28.8)  # 0.72 * 40
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# 创建血条
	create_health_bar()
	
	print("👑 BOSS节点创建完成")

func setup_visuals() -> void:
	"""设置BOSS视觉效果"""
	# ✅ 修复：确保贴图颜色正确设置（即使Sprite2D预先存在）
	var boss_sprite = get_node_or_null("Sprite2D")
	if boss_sprite:
		boss_sprite.modulate = Color.PURPLE  # 紫色
		print("  ✓ BOSS贴图颜色已设置为紫色")

func setup_collision_size() -> void:
	"""设置碰撞盒大小"""
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return
	
	var base_size = Vector2(40, 40)
	var scale_factor = Vector2(0.72, 0.72)  # 最大
	
	if collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		circle_shape.radius = (base_size.x / 2.0) * scale_factor.x
	elif collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		rect_shape.size = base_size * scale_factor

## ========== BOSS AI行为 ==========


func _find_target():
	"""寻找玩家目标"""
	var player = get_tree().get_first_node_in_group("players")
	if player and not is_dead:
		var distance = global_position.distance_to(player.global_position)
		if distance <= detection_range:
			current_target = player
		elif distance > lose_target_distance:
			current_target = null

func _process(_delta: float) -> void:
	# 如果BOSS已死亡，停止所有行为（包括召唤）
	if is_dead:
		return
		
	# 检查召唤技能
	if current_target:
		if can_use_summon():
			perform_summon_ability()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_dead and current_target:
		var distance_to_target = get_distance_to(current_target)
		
		# 距离管理
		if distance_to_target <= max_distance and distance_to_target >= min_distance:
			# 在理想距离内 - 攻击并移动
			if can_attack():
				perform_attack(current_target.global_position, current_target)
				print("👑 BOSS发起攻击!")
			
			# 执行战术移动
			perform_tactical_movement()
		elif distance_to_target < min_distance:
			# 太近 - 后退
			retreat_from_target()
		elif distance_to_target > max_distance:
			# 太远 - 慢慢接近
			approach_target_slowly()

## ========== BOSS攻击和移动方法 ==========

func approach_target_slowly() -> void:
	"""BOSS慢慢接近目标"""
	if not current_target:
		return
	
	var direction = (current_target.global_position - global_position).normalized()
	var target_pos = current_target.global_position - direction * preferred_distance
	move_towards(target_pos, 0.5)  # 较慢的移动速度

func retreat_from_target() -> void:
	"""BOSS从目标后退"""
	if not current_target:
		return
	
	var direction = (global_position - current_target.global_position).normalized()
	var retreat_pos = global_position + direction * 60
	move_towards(retreat_pos, 0.7)

func perform_tactical_movement() -> void:
	"""执行战术移动"""
	move_timer -= get_physics_process_delta_time()
	
	if move_timer <= 0.0:
		# 选择新的移动方向
		update_movement_direction()
		move_timer = randf_range(2.0, 4.0)  # 2-4秒后改变方向
	
	# 执行移动
	if move_direction != Vector2.ZERO:
		var move_pos = global_position + move_direction * 50
		# 确保不会离目标太远
		if current_target:
			var distance_to_target_from_move = move_pos.distance_to(current_target.global_position)
			if distance_to_target_from_move < max_distance * 1.2:
				move_towards(move_pos, 0.4)  # 缓慢移动

func update_movement_direction() -> void:
	"""更新移动方向"""
	if not current_target:
		return
	
	# 随机选择移动方向，但倾向于保持与目标的距离
	var to_target = (current_target.global_position - global_position).normalized()
	var perpendicular = Vector2(-to_target.y, to_target.x)
	
	# 70%概率左右移动，30%概率前后移动
	if randf() < 0.7:
		move_direction = perpendicular if randf() < 0.5 else -perpendicular
	else:
		move_direction = to_target if randf() < 0.5 else -to_target

## ========== BOSS召唤系统 ==========

func can_use_summon() -> bool:
	"""检查是否可以使用召唤技能"""
	# 使用更可靠的时间获取方法
	var current_time = Time.get_unix_time_from_system()
	var time_since_last_summon = current_time - last_summon_time
	
	# 只在接近冷却完成时才打印log，避免刷屏
	if time_since_last_summon >= summon_cooldown - 1.0:
		print("👑 BOSS召唤检查: 距离上次", time_since_last_summon, "秒, 需要", summon_cooldown, "秒")
	
	# 冷却时间检查
	return time_since_last_summon >= summon_cooldown

func perform_summon_ability() -> void:
	"""执行召唤技能"""
	# 再次检查BOSS是否还活着，防止死亡后仍召唤
	if is_dead:
		print("👑 BOSS已死亡，取消召唤")
		return
		
	print("👑 BOSS使用召唤技能!")
	
	# 更新最后使用召唤的时间
	last_summon_time = Time.get_unix_time_from_system()
	
	# 创建召唤特效
	create_summon_effect()
	
	# 召唤小兵
	summon_minions()

func summon_minions() -> void:
	"""召唤小兵"""
	var dungeon_generator = get_tree().current_scene.get_node_or_null("DungeonGenerator")
	if not dungeon_generator:
		print("⚠️ 未找到DungeonGenerator")
		return
	
	var current_room = dungeon_generator.current_room
	if not current_room:
		print("⚠️ 未找到当前房间")
		return
	
	# spawn_area应该是相对于房间的本地坐标，不需要加上房间的全局位置
	# 因为小兵会被添加到 enemies_container，它已经是房间的子节点了
	var spawn_area = Rect2(
		Vector2(50, 50),
		current_room.room_size - Vector2(100, 100)
	)
	
	# 召唤小兵（通过Room的创建函数）
	print("👑 开始召唤小兵，当前房间: ", current_room.room_id)
	
	# 召唤近战小兵
	var melee_spawn_pos = current_room.get_valid_spawn_position(spawn_area)
	var melee_soldier = current_room.create_enemy_by_type("melee_soldier")
	print("    创建近战小兵: ", melee_soldier.character_name if melee_soldier else "null")
	
	if melee_soldier:
		melee_soldier.position = melee_spawn_pos
		print("    设置位置(本地): ", melee_spawn_pos)
		
		current_room.enemies_container.add_child(melee_soldier)
		
		# 等待节点准备好
		await get_tree().process_frame
		
		print("    近战小兵位置(本地): ", melee_soldier.position)
		print("    近战小兵位置(全局): ", melee_soldier.global_position)
		print("    近战小兵可见性: ", melee_soldier.visible)
		
		# 检查Sprite是否存在
		var melee_soldier_sprite = melee_soldier.get_node_or_null("Sprite2D")
		if melee_soldier_sprite:
			print("    Sprite2D: 存在, 可见:", melee_soldier_sprite.visible, ", modulate:", melee_soldier_sprite.modulate)
		else:
			print("    Sprite2D: 不存在")
		
		current_room.enemies.append(melee_soldier)
		melee_soldier.character_died.connect(current_room._on_enemy_character_died)
		current_room.alive_enemy_count += 1
		
		# 发出敌人计数变化信号
		current_room.enemy_count_changed.emit(current_room.room_id, current_room.alive_enemy_count)
		
		print("    ✅ 召唤近战小兵完成")
	
	# 召唤远程小兵
	var ranged_spawn_pos = current_room.get_valid_spawn_position(spawn_area)
	var ranged_soldier = current_room.create_enemy_by_type("ranged_soldier")
	print("    创建远程小兵: ", ranged_soldier.character_name if ranged_soldier else "null")
	
	if ranged_soldier:
		ranged_soldier.position = ranged_spawn_pos
		print("    设置位置(本地): ", ranged_spawn_pos)
		
		current_room.enemies_container.add_child(ranged_soldier)
		
		# 等待节点准备好
		await get_tree().process_frame
		
		print("    远程小兵位置(本地): ", ranged_soldier.position)
		print("    远程小兵位置(全局): ", ranged_soldier.global_position)
		print("    远程小兵可见性: ", ranged_soldier.visible)
		
		# 检查Sprite是否存在
		var ranged_soldier_sprite = ranged_soldier.get_node_or_null("Sprite2D")
		if ranged_soldier_sprite:
			print("    Sprite2D: 存在, 可见:", ranged_soldier_sprite.visible, ", modulate:", ranged_soldier_sprite.modulate)
		else:
			print("    Sprite2D: 不存在")
		
		current_room.enemies.append(ranged_soldier)
		ranged_soldier.character_died.connect(current_room._on_enemy_character_died)
		current_room.alive_enemy_count += 1
		
		# 发出敌人计数变化信号
		current_room.enemy_count_changed.emit(current_room.room_id, current_room.alive_enemy_count)
		
		print("    ✅ 召唤远程小兵完成")
	
	print("👑 召唤完成！当前房间敌人数: ", current_room.alive_enemy_count)
	
	# 敌人计数已在添加时自动更新，无需手动调用

func create_summon_effect() -> void:
	"""创建召唤视觉效果"""
	var summon_effect = preload("res://Scenes/SkillEffect.tscn").instantiate()
	summon_effect.global_position = global_position
	summon_effect.skill_type = "summon"
	summon_effect.life_time = 2.0
	
	# 设置召唤效果外观
	var effect_sprite = summon_effect.get_node_or_null("Sprite2D")
	if effect_sprite:
		effect_sprite.modulate = Color.MAGENTA
		effect_sprite.scale = Vector2(2.0, 2.0)
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null("SkillEffects")
	if skill_effects:
		skill_effects.add_child(summon_effect)
	else:
		get_tree().current_scene.add_child(summon_effect)
	
	# ✅ 初始化效果
	summon_effect.initialize()

## ========== BOSS特殊能力 ==========

func should_retreat() -> bool:
	"""BOSS从不撤退"""
	return false

func get_ai_description() -> String:
	"""获取AI描述"""
	return "BOSS AI - 战术移动，召唤小兵，不撤退"

## ========== 静态工厂方法 ==========

static func create_boss_enemy(enemy_room_id: Vector2i) -> BossEnemy:
	"""创建BOSS实例"""
	var boss_enemy = BossEnemy.new()
	boss_enemy.room_id = enemy_room_id
	return boss_enemy
