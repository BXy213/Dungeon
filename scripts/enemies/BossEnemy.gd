extends "res://scripts/EnemyCharacter.gd"
class_name BossEnemy

const EnemyTypes = preload("res://scripts/factories/EnemyFactory.gd")
# 👑 BOSS - 保持距离，召唤小兵，战术移动

## ========== BOSS特有属性 ==========

# 距离管理属性
var preferred_distance: float = 150.0  # BOSS偏好的攻击距离
var min_distance: float = 120.0  # 最小保持距离
var max_distance: float = 200.0  # 最大攻击距离

# 召唤技能属性
var summon_cooldown: float = 15.0  # 召唤技能冷却时间（秒）
var last_summon_time: float = 0.0  # 使用引擎时间戳
var summon_range: float = 300.0  # 召唤范围

# 战术移动属性
var move_timer: float = 0.0
var move_direction: Vector2 = Vector2.ZERO

# AI行为属性
var current_target: Node = null
var detection_range: float = 500.0
var lose_target_distance: float = 600.0

## ========== 初始化方法 ==========

func _init():
	super._init()
	
	# 设置BOSS属性
	character_name = "BOSS"
	max_health = 500
	health = max_health
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
	
	print("👑 BOSS _ready() 被调用，位置: ", global_position)
	
	# 确保节点已创建
	if get_node_or_null("Sprite2D") == null:
		setup_enemy_nodes()
	
	# 定期查找目标
	var target_timer = Timer.new()
	target_timer.wait_time = 1.0
	target_timer.timeout.connect(_find_target)
	target_timer.autostart = true
	add_child(target_timer)
	
	print("👑 BOSS _ready() 完成")

## ========== 节点设置方法 ==========

func setup_enemy_nodes() -> void:
	"""创建敌人必要的子节点"""
	print("🔨 BOSS正在创建节点...")
	
	# 创建Sprite2D节点
	var boss_sprite = Sprite2D.new()
	boss_sprite.name = "Sprite2D"
	boss_sprite.texture = preload("res://art/icon.webp")
	boss_sprite.modulate = Color.PURPLE  # 紫色
	boss_sprite.scale = Vector2(0.72, 0.72)
	add_child(boss_sprite)
	print("  ✓ Sprite2D已创建")
	
	# 创建CollisionShape2D节点
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28.8, 28.8)  # 0.72 * 40
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# 创建血条
	create_health_bar()
	print("  ✓ 血条已创建")
	
	print("👑 BOSS节点创建完成")

func setup_visuals() -> void:
	"""设置BOSS视觉效果"""
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
	var scale_factor = Vector2(0.72, 0.72)
	
	if collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		circle_shape.radius = (base_size.x / 2.0) * scale_factor.x
	elif collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		rect_shape.size = base_size * scale_factor

## ========== AI行为方法 ==========

func _find_target():
	"""寻找玩家目标"""
	var player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
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
		
		# 应用移动
		move_and_slide()

## ========== 移动方法 ==========

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

## ========== 攻击方法 ==========

func set_projectile_appearance(projectile: Node) -> void:
	"""设置BOSS弹道外观"""
	var sprite_node = projectile.get_node_or_null("Sprite2D")
	if sprite_node:
		sprite_node.modulate = Color.PURPLE  # 紫色弹道
		sprite_node.scale = Vector2(0.45, 0.45)  # 更大的弹道
		print("  🎨 BOSS弹道外观: 紫色, 大小 0.45")
	
	# 设置弹道速度
	projectile.speed = 400  # 更快的速度

## ========== 特殊能力方法 ==========

func can_use_summon() -> bool:
	"""检查是否可以使用召唤技能"""
	var current_time = Time.get_unix_time_from_system()
	var time_since_last_summon = current_time - last_summon_time
	
	# 只在接近冷却完成时才打印log，避免刷屏
	if time_since_last_summon >= summon_cooldown - 1.0:
		print("👑 BOSS召唤检查: 距离上次", time_since_last_summon, "秒, 需要", summon_cooldown, "秒")
	
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
	var dungeon_generator = get_tree().current_scene.get_node_or_null(Constants.NODE_DUNGEON_GENERATOR)
	if not dungeon_generator:
		print("⚠️ 未找到DungeonGenerator")
		return
	
	var current_room = dungeon_generator.current_room
	if not current_room:
		print("⚠️ 未找到当前房间")
		return
	
	# spawn_area应该是相对于房间的本地坐标
	var spawn_area = Rect2(
		Vector2(50, 50),
		current_room.room_size - Vector2(100, 100)
	)
	
	print("👑 开始召唤小兵，当前房间: ", current_room.room_id)
	
	# 召唤1个精英战士
	var elite_spawn_pos = current_room.get_valid_spawn_position(spawn_area)
	var elite_soldier = current_room.create_enemy_by_type(EnemyTypes.ENEMY_ELITE_MELEE)
	
	if elite_soldier:
		elite_soldier.position = elite_spawn_pos
		current_room.enemies_container.add_child(elite_soldier)
		await get_tree().process_frame
		
		current_room.enemies.append(elite_soldier)
		elite_soldier.character_died.connect(current_room._on_enemy_character_died)
		current_room.alive_enemy_count += 1
		current_room.enemy_count_changed.emit(current_room.room_id, current_room.alive_enemy_count)
		
		print("    ✅ 召唤精英战士完成")
	
	# 召唤2个远程小兵
	for i in range(2):
		var ranged_spawn_pos = current_room.get_valid_spawn_position(spawn_area)
		var ranged_soldier = current_room.create_enemy_by_type(EnemyTypes.ENEMY_RANGED_SOLDIER)
		
		if ranged_soldier:
			ranged_soldier.position = ranged_spawn_pos
			current_room.enemies_container.add_child(ranged_soldier)
			await get_tree().process_frame
			
			current_room.enemies.append(ranged_soldier)
			ranged_soldier.character_died.connect(current_room._on_enemy_character_died)
			current_room.alive_enemy_count += 1
			current_room.enemy_count_changed.emit(current_room.room_id, current_room.alive_enemy_count)
			
			print("    ✅ 召唤远程小兵 #", i + 1, " 完成")
	
	# 召唤1个分裂者
	var splitter_spawn_pos = current_room.get_valid_spawn_position(spawn_area)
	var splitter = current_room.create_enemy_by_type(EnemyTypes.ENEMY_SPLITTER)
	
	if splitter:
		splitter.position = splitter_spawn_pos
		current_room.enemies_container.add_child(splitter)
		await get_tree().process_frame
		
		current_room.enemies.append(splitter)
		splitter.character_died.connect(current_room._on_enemy_character_died)
		current_room.alive_enemy_count += 1
		current_room.enemy_count_changed.emit(current_room.room_id, current_room.alive_enemy_count)
		
		print("    ✅ 召唤分裂者完成")
	
	print("👑 召唤完成！当前房间敌人数: ", current_room.alive_enemy_count)

func create_summon_effect() -> void:
	"""创建召唤视觉效果"""
	var effect_scene = load(Constants.SCENE_SKILL_EFFECT) as PackedScene
	if not effect_scene:
		return
	
	var summon_effect = effect_scene.instantiate()
	summon_effect.global_position = global_position
	summon_effect.skill_type = "summon"
	summon_effect.life_time = 2.0
	
	# 设置召唤效果外观
	var effect_sprite = summon_effect.get_node_or_null("Sprite2D")
	if effect_sprite:
		effect_sprite.modulate = Color.MAGENTA
		effect_sprite.scale = Vector2(2.0, 2.0)
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null(Constants.NODE_SKILL_EFFECTS)
	if skill_effects:
		skill_effects.add_child(summon_effect)
	else:
		get_tree().current_scene.add_child(summon_effect)
	
	# 初始化效果
	summon_effect.initialize()

## ========== 辅助方法 ==========

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
