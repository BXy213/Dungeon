extends "res://scripts/CharacterBase.gd"

# 👹 敌人角色类 - 基于新架构的敌人实现

## ========== 敌人类型枚举 ==========

enum EnemyType {
	MELEE_SOLDIER,    # 普通近战小兵
	RANGED_SOLDIER,   # 普通远程小兵  
	ELITE_MELEE,      # 精英近战士兵
	BOSS             # BOSS
}

## ========== 敌人特有属性 ==========

@export var enemy_type: EnemyType = EnemyType.MELEE_SOLDIER
@export var ai_type: int = 1  # AIBase.AIType.AGGRESSIVE
@export var experience_reward: int = 50
@export var loot_chance: float = 0.3

# AI系统
var ai_controller: Node  # AIBase type will be available at runtime

# 视觉组件
@onready var health_bar = $HealthBar
@onready var health_fill = $HealthBar/HealthFill
@onready var sprite = $Sprite2D

# 敌人特有状态
var room_id: Vector2i = Vector2i.ZERO  # 所属房间
var is_room_enemy: bool = true  # 是否为房间敌人

## ========== 信号 ==========

signal enemy_defeated(enemy: Node, exp_reward: int)

## ========== 初始化 ==========

func _init():
	# 设置敌人角色基础属性
	character_type = CharacterType.ENEMY
	character_name = "敌人"
	is_controllable = false
	
	# 敌人属性
	max_health = 100
	health = 100
	max_mana = 50
	mana = 50
	base_speed = 80.0
	base_attack_damage = 15
	attack_range = 100.0
	attack_cooldown = 2.0
	health_regen_rate = 0.0  # 禁用敌人自然回血

func post_ready_setup() -> void:
	"""敌人特有的初始化"""
	super.post_ready_setup()
	
	# 根据类型设置敌人属性
	setup_enemy_type_attributes()
	
	# 设置AI控制器
	setup_ai_controller()
	
	# 设置视觉效果
	setup_visuals()
	
	# 更新血条
	update_health_bar()
	
	# 将敌人加入相关组
	add_to_group("characters")
	add_to_group("enemies")
	
	print("👹 敌人角色初始化完成: ", character_name)

func setup_enemy_type_attributes() -> void:
	"""根据敌人类型设置属性"""
	match enemy_type:
		EnemyType.MELEE_SOLDIER:
			# 普通近战小兵
			character_name = "近战小兵"
			max_health = 80
			health = 80
			base_speed = 90.0
			base_attack_damage = 12
			attack_range = 60.0
			attack_cooldown = 1.8
			experience_reward = 30
			
		EnemyType.RANGED_SOLDIER:
			# 普通远程小兵
			character_name = "远程小兵"
			max_health = 60
			health = 60
			base_speed = 70.0
			base_attack_damage = 10
			attack_range = 150.0
			attack_cooldown = 1.5
			experience_reward = 35
			
		EnemyType.ELITE_MELEE:
			# 精英近战士兵
			character_name = "精英战士"
			max_health = 150
			health = 150
			base_speed = 85.0
			base_attack_damage = 20
			attack_range = 70.0
			attack_cooldown = 2.0
			experience_reward = 80
			
		EnemyType.BOSS:
			# BOSS
			character_name = "BOSS"
			max_health = 400
			health = 400
			base_speed = 50.0  # 移动较慢
			base_attack_damage = 25
			attack_range = 180.0
			attack_cooldown = 2.5
			experience_reward = 200
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage

func setup_ai_controller() -> void:
	"""设置AI控制器"""
	# 根据敌人类型创建对应的AI控制器
	match enemy_type:
		EnemyType.MELEE_SOLDIER:
			var MeleeAIClass = preload("res://scripts/AI/MeleeAI.gd")
			ai_controller = MeleeAIClass.new(self)
		EnemyType.RANGED_SOLDIER:
			var RangedAIClass = preload("res://scripts/AI/RangedAI.gd")
			ai_controller = RangedAIClass.new(self)
		EnemyType.ELITE_MELEE:
			var EliteMeleeAIClass = preload("res://scripts/AI/EliteMeleeAI.gd")
			ai_controller = EliteMeleeAIClass.new(self)
		EnemyType.BOSS:
			var BossAIClass = preload("res://scripts/AI/BossAI.gd")
			ai_controller = BossAIClass.new(self)
		_:
			print("⚠️ 未知的敌人类型: ", enemy_type)
			var MeleeAIClass = preload("res://scripts/AI/MeleeAI.gd")
			ai_controller = MeleeAIClass.new(self)
	
	# 添加AI控制器到场景
	add_child(ai_controller)
	print("🤖 敌人AI控制器设置完成: ", ai_controller.ai_name)

func setup_visuals() -> void:
	"""设置敌人视觉效果"""
	if sprite:
		# 根据敌人类型设置不同的颜色和大小
		var target_color = get_enemy_original_color()
		var target_scale = get_enemy_original_scale()
		
		sprite.modulate = target_color
		sprite.scale = target_scale
		
		# 设置敌人贴图（如果有）
		# sprite.texture = preload("res://art/enemy_texture.png")
		
		print("👹 设置 ", character_name, " sprite - 颜色:", target_color, " 大小:", target_scale)
	
	# 设置碰撞盒大小以匹配sprite（延迟执行确保sprite已设置）
	call_deferred("setup_collision_size")
	
	print("👹 敌人视觉效果设置完成: ", character_name)

func setup_collision_size() -> void:
	"""设置碰撞盒大小以匹配sprite"""
	# 获取碰撞形状
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		print("⚠️ 敌人碰撞形状未找到: ", character_name)
		return
	
	# 根据玩家的设置：玩家碰撞盒是40x40，sprite scale是0.4
	# 所以敌人的基础碰撞盒也应该是40x40，然后根据敌人类型缩放
	var base_size = Vector2(40, 40)  # 与玩家一致的基础碰撞盒大小
	var scale_factor = get_enemy_original_scale()
	
	if collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		# 圆形碰撞盒：半径 = 基础大小的一半 * 缩放因子
		circle_shape.radius = (base_size.x / 2.0) * scale_factor.x
		print("🎯 设置 ", character_name, " 圆形碰撞盒半径: ", circle_shape.radius)
	elif collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		# 矩形碰撞盒：直接按比例缩放
		rect_shape.size = base_size * scale_factor
		print("🎯 设置 ", character_name, " 矩形碰撞盒大小: ", rect_shape.size)
	
	print("🎯 ", character_name, " 碰撞盒设置完成，sprite缩放: ", scale_factor)

## ========== 移动系统重写 ==========

func handle_movement(_delta: float) -> void:
	"""敌人移动由AI控制，这里不需要实现"""
	# AI系统会通过调用move_towards等方法来控制移动
	pass

## ========== 攻击系统重写 ==========

func execute_attack(target_position: Vector2, target: Node = null) -> void:
	"""执行敌人攻击"""
	print("⚔️ ", character_name, " 攻击到: ", target_position)
	
	# 创建攻击弹道
	launch_projectile(target_position, target)
	
	# 播放攻击动画
	play_attack_animation()
	
	# 改变状态
	change_state(CharacterState.ATTACKING)
	
	# 攻击完成后返回空闲
	await get_tree().create_timer(0.3).timeout
	change_state(CharacterState.IDLE)

func launch_projectile(target_pos: Vector2, _target: Node = null) -> void:
	"""发射攻击弹道"""
	print("🚀 敌人 ", character_name, " 发射弹道到: ", target_pos, " 伤害: ", current_attack_damage)
	
	# 房间ID验证 - 只在当前房间创建弹道
	var dungeon_generator = get_tree().current_scene.get_node_or_null("DungeonGenerator")
	if dungeon_generator:
		var current_room_id = dungeon_generator.get_current_room_coord()
		if room_id != current_room_id:
			print("    ❌ 敌人不在当前房间，跳过攻击")
			return
	
	# 创建攻击弹道（使用SkillEffect，就像玩家一样）
	create_attack_projectile(target_pos)
	print("✅ 弹道已添加到场景，从 ", global_position, " 到 ", target_pos)

func create_attack_projectile(target_pos: Vector2) -> void:
	"""创建敌人攻击弹道"""
	var projectile = preload("res://Scenes/SkillEffect.tscn").instantiate()
	
	# 设置弹道属性
	projectile.position = global_position
	projectile.skill_type = "enemy_projectile"  # 标记为敌人弹道
	projectile.damage = current_attack_damage
	projectile.speed = 300
	projectile.max_distance = attack_range * 2  # 给足够的飞行距离
	projectile.life_time = 3.0
	projectile.collision_layer = 4  # 敌人弹道层
	projectile.collision_mask = 3   # 检测玩家层(2) + 障碍物层(1) = 3
	
	# 计算方向
	var direction = (target_pos - global_position).normalized()
	projectile.direction = direction
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null("SkillEffects")
	if skill_effects:
		skill_effects.add_child(projectile)
		call_deferred("set_enemy_projectile_appearance", projectile)
	else:
		get_tree().current_scene.add_child(projectile)
		call_deferred("set_enemy_projectile_appearance", projectile)

func set_enemy_projectile_appearance(projectile: Node) -> void:
	"""设置敌人弹道外观"""
	var projectile_sprite = projectile.get_node_or_null("Sprite2D")
	if projectile_sprite:
		# 根据敌人类型设置不同的弹道外观
		match enemy_type:
			EnemyType.MELEE_SOLDIER:
				projectile_sprite.modulate = Color.ORANGE_RED
				projectile_sprite.scale = Vector2(0.4, 0.4)
				projectile.speed = 250  # 普通速度
			EnemyType.RANGED_SOLDIER:
				projectile_sprite.modulate = Color.CYAN
				projectile_sprite.scale = Vector2(0.25, 0.25)  # 更小的子弹
				projectile.speed = 400  # 更快的弹道
			EnemyType.ELITE_MELEE:
				projectile_sprite.modulate = Color.ORANGE
				projectile_sprite.scale = Vector2(0.5, 0.5)
				projectile.speed = 280
			EnemyType.BOSS:
				projectile_sprite.modulate = Color.PURPLE
				projectile_sprite.scale = Vector2(0.6, 0.6)  # 更大的弹道
				projectile.speed = 320

func play_attack_animation() -> void:
	"""播放攻击动画"""
	if sprite:
		# 保存原始大小和颜色
		var original_scale = get_enemy_original_scale()
		var original_color = get_enemy_original_color()
		
		var attack_tween = create_tween()
		# 攻击动画：稍微放大然后恢复
		attack_tween.parallel().tween_property(sprite, "scale", original_scale * 1.1, 0.1)
		attack_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)
		attack_tween.tween_property(sprite, "scale", original_scale, 0.2)
		attack_tween.tween_property(sprite, "modulate", original_color, 0.1)

func get_enemy_original_scale() -> Vector2:
	"""获取敌人原始大小（相对于玩家的0.4缩放）"""
	# 玩家sprite scale是0.4，近战小兵1.0x应该与玩家大小一致
	# 所以近战小兵的实际scale应该是0.4
	match enemy_type:
		EnemyType.MELEE_SOLDIER:
			return Vector2(0.4, 0.4)  # 与玩家一致
		EnemyType.RANGED_SOLDIER:
			return Vector2(0.36, 0.36)  # 0.4 * 0.9
		EnemyType.ELITE_MELEE:
			return Vector2(0.52, 0.52)  # 0.4 * 1.3
		EnemyType.BOSS:
			return Vector2(0.72, 0.72)  # 0.4 * 1.8
		_:
			return Vector2(0.4, 0.4)

func get_enemy_original_color() -> Color:
	"""获取敌人原始颜色"""
	match enemy_type:
		EnemyType.MELEE_SOLDIER:
			return Color.RED
		EnemyType.RANGED_SOLDIER:
			return Color.BLUE
		EnemyType.ELITE_MELEE:
			return Color.ORANGE
		EnemyType.BOSS:
			return Color.PURPLE
		_:
			return Color.RED

func show_attack_warning() -> void:
	"""显示攻击预警"""
	create_warning_indicator()

func create_warning_indicator() -> void:
	"""创建警告指示器"""
	var warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.modulate = Color.RED
	warning_label.position = Vector2(-10, -60)
	add_child(warning_label)
	
	# 警告指示器动画
	var indicator_tween = create_tween()
	indicator_tween.tween_property(warning_label, "position", Vector2(-10, -80), 0.3)
	indicator_tween.parallel().tween_property(warning_label, "modulate:a", 0.0, 0.5)
	
	# 动画结束后删除
	await indicator_tween.finished
	warning_label.queue_free()

## ========== 生命值系统重写 ==========

func take_damage(amount: int, source: Node = null) -> void:
	"""敌人受伤"""
	if is_dead:
		return
	
	# 计算实际伤害（考虑防御）
	var actual_damage = max(1, amount - current_defense)
	var old_health = health
	
	health -= actual_damage
	health = max(0, health)
	
	# 发出信号
	health_changed.emit(old_health, health)
	damage_taken.emit(actual_damage, source)
	
	# 更新血条
	update_health_bar()
	
	# 检查是否为持续伤害（如中毒等buff伤害）
	var is_continuous_damage = false
	if source and source.get_script():
		var script_path = source.get_script().resource_path
		# 如果伤害来源是BuffSystem，认为是持续伤害
		is_continuous_damage = "BuffSystem" in script_path
	
	# 专门的敌人受伤视觉效果
	show_enemy_damage_effect(actual_damage, is_continuous_damage)
	
	# 通知AI受到攻击
	if ai_controller and ai_controller.has_method("_on_damage_taken"):
		ai_controller._on_damage_taken(actual_damage, source)
	
	# 检查死亡
	if health <= 0:
		die()

func show_enemy_damage_effect(amount: int, is_continuous: bool = false) -> void:
	"""显示敌人受伤效果（不影响基础颜色）"""
	if not sprite:
		return
	
	# 获取原始颜色和大小
	var original_color = get_enemy_original_color()
	var original_scale = get_enemy_original_scale()
	
	# 根据伤害类型选择不同的视觉效果
	var damage_tween = create_tween()
	
	if is_continuous:
		# 持续伤害（如中毒）：更轻微的效果，避免频繁闪烁
		damage_tween.tween_property(sprite, "modulate", Color(1.0, 0.8, 0.8, 1.0), 0.1)
		damage_tween.tween_property(sprite, "modulate", original_color, 0.2)
		# 不执行震动效果，避免过于频繁
	else:
		# 普通伤害：完整的闪烁效果
		damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
		damage_tween.tween_property(sprite, "modulate", original_color, 0.05)
		damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
		damage_tween.tween_property(sprite, "modulate", original_color, 0.05)
		
		# 只有普通伤害才触发震动
		create_enemy_shake_effect()
	
	# 确保恢复原始大小
	sprite.scale = original_scale

func create_enemy_shake_effect() -> void:
	"""创建敌人震动效果"""
	var original_pos = position
	var shake_tween = create_tween()
	for i in range(2):  # 减少震动次数
		var offset = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		shake_tween.tween_property(self, "position", original_pos + offset, 0.03)
	shake_tween.tween_property(self, "position", original_pos, 0.03)

func heal(amount: int) -> void:
	"""敌人治疗"""
	super.heal(amount)
	
	# 更新血条
	update_health_bar()

func update_health_bar() -> void:
	"""更新血条显示"""
	if health_fill:
		var health_percent = get_health_percentage()
		health_fill.scale.x = health_percent
		
		# 血条颜色变化
		if health_percent > 0.6:
			health_fill.color = Color.GREEN
		elif health_percent > 0.3:
			health_fill.color = Color.YELLOW
		else:
			health_fill.color = Color.RED

## ========== 状态管理重写 ==========

func die() -> void:
	"""敌人死亡"""
	super.die()
	
	# 播放死亡动画
	play_death_animation()
	
	# 掉落经验和物品
	drop_rewards()
	
	# 通知房间敌人死亡
	notify_room_enemy_death()
	
	# 发出敌人击败信号
	enemy_defeated.emit(self, experience_reward)

func play_death_animation() -> void:
	"""播放死亡动画"""
	super.play_death_effect()
	
	# 等待动画完成后销毁
	await get_tree().create_timer(1.0).timeout
	queue_free()

func drop_rewards() -> void:
	"""掉落奖励"""
	# 给玩家经验值
	var player = get_tree().get_first_node_in_group("players")
	if player:
		player.gain_experience(experience_reward)
	
	# 随机掉落物品
	if randf() < loot_chance:
		drop_loot()

func drop_loot() -> void:
	"""掉落物品（待实现）"""
	print("💎 ", character_name, " 掉落了物品!")
	# TODO: 实现物品掉落系统

func notify_room_enemy_death() -> void:
	"""通知房间敌人死亡"""
	if is_room_enemy:
		# 新系统使用character_died信号自动处理，无需手动通知
		print("🏠 敌人 ", character_name, " 在房间 ", room_id, " 中死亡，通过信号系统处理")

## ========== AI接口方法 ==========

func set_ai_type(new_ai_type: int) -> void:
	"""设置AI类型"""
	ai_type = new_ai_type
	
	# 重新创建AI控制器
	if ai_controller:
		ai_controller.queue_free()
	
	setup_ai_controller()

func get_ai_state() -> String:
	"""获取AI状态"""
	if ai_controller:
		return ai_controller.get_state_name()
	return "NONE"

func set_room_id(new_room_id: Vector2i) -> void:
	"""设置所属房间ID"""
	room_id = new_room_id

## ========== Buff系统集成 ==========

func apply_enemy_buff(buff_type: int, duration: float, strength: float = 1.0, source: Node = null) -> void:
	"""为敌人应用Buff"""
	if buff_system:
		buff_system.apply_buff(buff_type, duration, strength, source)

## ========== 特殊能力系统 ==========

func cast_enemy_skill(skill_name: String, target: Node = null) -> void:
	"""释放敌人技能（子类可重写）"""
	match skill_name:
		"heal_self":
			cast_heal_skill()
		"poison_attack":
			cast_poison_attack(target)
		"speed_boost":
			cast_speed_boost()
		_:
			print("⚡ ", character_name, " 释放了未知技能: ", skill_name)

func cast_heal_skill() -> void:
	"""治疗技能"""
	heal(30)
	print("💚 ", character_name, " 使用治疗术！")

func cast_poison_attack(target: Node = null) -> void:
	"""毒攻击"""
	if target and target.has_method("apply_player_buff"):
		target.apply_player_buff(2, 5.0, 2.0)  # POISON
		print("☠️ ", character_name, " 对 ", target.name, " 使用毒攻击！")

func cast_speed_boost() -> void:
	"""加速技能"""
	apply_enemy_buff(8, 8.0, 1.5)  # SPEED_BOOST
	print("💨 ", character_name, " 使用加速术！")

## ========== 工厂方法 ==========

static func create_enemy(enemy_room_id: Vector2i, type: EnemyType = EnemyType.MELEE_SOLDIER) -> Node:
	"""创建敌人的工厂方法"""
	var enemy_scene = preload("res://Scenes/Enemy.tscn")
	var enemy = enemy_scene.instantiate()
	
	# 设置敌人类型和房间ID
	enemy.enemy_type = type
	enemy.room_id = enemy_room_id
	
	return enemy

func setup_enemy_type(type_name: String) -> void:
	"""通过字符串设置敌人类型（用于动态创建）"""
	match type_name:
		"melee_soldier":
			enemy_type = EnemyType.MELEE_SOLDIER
		"ranged_soldier":
			enemy_type = EnemyType.RANGED_SOLDIER
		"elite_melee":
			enemy_type = EnemyType.ELITE_MELEE
		"boss":
			enemy_type = EnemyType.BOSS
		_:
			print("⚠️ 未知的敌人类型字符串: ", type_name)
			enemy_type = EnemyType.MELEE_SOLDIER
	
	# 重新设置属性
	setup_enemy_type_attributes()
	
	# 如果AI已经创建，需要重新创建
	if ai_controller:
		ai_controller.queue_free()
		setup_ai_controller()
	
	# 重新设置视觉
	setup_visuals()

## ========== 调试方法 ==========

func get_debug_info() -> Dictionary:
	"""获取调试信息"""
	return {
		"name": character_name,
		"health": str(health) + "/" + str(max_health),
		"state": CharacterState.keys()[current_state],
		"ai_state": get_ai_state(),
		"ai_type": "AGGRESSIVE",  # get_ai_type_name() would need to be implemented
		"room_id": room_id,
		"buffs_count": buff_system.active_buffs.size() if buff_system else 0,
		"position": global_position,
		"velocity": velocity
	}

