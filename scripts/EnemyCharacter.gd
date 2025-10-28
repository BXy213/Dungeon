class_name EnemyCharacter
extends CharacterBase

# 🦹 敌人角色基类 - 继承自CharacterBase，提供敌人通用功能

## ========== 敌人通用属性 ==========

@export var room_id: Vector2i = Vector2i.ZERO
@export var is_room_enemy: bool = true
@export var experience_reward: int = 10
@export var loot_chance: float = 0.1

# AI逻辑已直接集成到敌人子类中

# 敌人血条UI组件（通过代码创建，不使用@onready）
var health_bar: Control = null
var health_fill: ColorRect = null

## ========== 敌人信号 ==========

signal enemy_defeated(enemy: EnemyCharacter, exp_reward: int)

## ========== 敌人基类初始化 ==========

func _init():
	pass
	
	# 设置敌人基础属性（子类可重写）
	character_type = CharacterType.ENEMY
	character_name = "敌人"
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
	"""敌人通用初始化（子类可重写）"""
	super.post_ready_setup()
	
	# 设置敌人组
	add_to_group("enemies")
	
	# AI逻辑已直接集成到子类中，无需单独的AI控制器
	
	# 设置视觉效果（由子类实现）
	setup_visuals()
	
	# 更新血条（延迟执行，确保节点已创建）
	call_deferred("update_health_bar")
	
	print("👹 敌人基类初始化完成: ", character_name)

## ========== 抽象方法（子类必须实现） ==========

func setup_ai_controller() -> void:
	"""AI控制器已废弃，逻辑直接集成到敌人子类中"""
	pass

func setup_visuals() -> void:
	"""设置敌人视觉效果（子类实现）"""
	print("⚠️ setup_visuals() 应该由子类实现")

func execute_attack_behavior() -> void:
	"""执行攻击行为（子类实现）"""
	print("⚠️ execute_attack_behavior() 应该由子类实现")

func execute_chase_behavior() -> void:
	"""执行追击行为（子类实现）"""
	print("⚠️ execute_chase_behavior() 应该由子类实现")

## ========== 敌人通用移动系统 ==========

func handle_movement(_delta: float) -> void:
	"""敌人移动由AI控制，这里不需要实现"""
	pass

## ========== 敌人通用攻击系统 ==========

func execute_attack(target_position: Vector2, target: Node = null) -> void:
	"""执行攻击效果 - 发射弹道"""
	# 创建攻击弹道
	launch_projectile(target_position, target)
	
	# 播放攻击动画
	play_attack_animation()

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
	
	# 创建攻击弹道
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
	
	# 设置弹道外观（由子类重写）
	set_projectile_appearance(projectile)
	
	# 计算方向
	var direction = (target_pos - global_position).normalized()
	projectile.direction = direction
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null("SkillEffects")
	if skill_effects:
		skill_effects.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)

func set_projectile_appearance(projectile: Node) -> void:
	"""设置弹道外观（子类可重写）"""
	var sprite_node = projectile.get_node_or_null("Sprite2D")
	if sprite_node:
		sprite_node.modulate = Color.ORANGE_RED
		sprite_node.scale = Vector2(0.3, 0.3)

func play_attack_animation() -> void:
	"""播放攻击动画（基础实现，子类可重写）"""
	if not sprite:
		return
	
	# 获取当前颜色和大小
	var current_color = sprite.modulate
	var current_scale = sprite.scale
	
	# 攻击动画：轻微放大然后恢复
	var attack_tween = create_tween()
	attack_tween.parallel().tween_property(sprite, "scale", current_scale * 1.1, 0.1)
	attack_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)
	attack_tween.tween_property(sprite, "scale", current_scale, 0.2)
	attack_tween.tween_property(sprite, "modulate", current_color, 0.1)

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

## ========== 敌人生命值系统 ==========

func take_damage(amount: int, source: Node = null) -> void:
	"""敌人受伤"""
	# 记录玩家造成的伤害
	if source:
		if source.is_in_group("players"):
			var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
			if game_manager and game_manager.has_method("record_damage"):
				game_manager.record_damage(amount)
			else:
				print("⚠️ 未找到GameManager或record_damage方法")
		else:
			print("⚠️ 伤害来源不是玩家: ", source.name if source else "null")
	
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
	
	# 更新血条（延迟执行，确保节点已创建）
	call_deferred("update_health_bar")
	
	# 检查是否为持续伤害（如中毒等buff伤害）
	var is_continuous_damage = false
	if source and source.get_script():
		var script_path = source.get_script().resource_path
		# 如果伤害来源是BuffSystem，认为是持续伤害
		is_continuous_damage = "BuffSystem" in script_path
	
	# 专门的敌人受伤视觉效果
	show_enemy_damage_effect(actual_damage, is_continuous_damage)
	
	# AI逻辑已集成到子类中，无需单独通知
	
	# 检查死亡
	if health <= 0:
		die()

func show_enemy_damage_effect(_amount: int, is_continuous: bool = false) -> void:
	"""显示敌人受伤效果（基础实现，子类可重写）"""
	if not sprite:
		return
	
	# 获取当前颜色和大小
	var current_color = sprite.modulate
	var current_scale = sprite.scale
	
	# 根据伤害类型选择不同的视觉效果
	var damage_tween = create_tween()
	
	if is_continuous:
		# 持续伤害（如中毒）：更轻微的效果，避免频繁闪烁
		damage_tween.tween_property(sprite, "modulate", Color(1.0, 0.8, 0.8, 1.0), 0.1)
		damage_tween.tween_property(sprite, "modulate", current_color, 0.2)
		# 不执行震动效果，避免过于频繁
	else:
		# 普通伤害：完整的闪烁效果
		damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
		damage_tween.tween_property(sprite, "modulate", current_color, 0.05)
		damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
		damage_tween.tween_property(sprite, "modulate", current_color, 0.05)
		
		# 只有普通伤害才触发震动
		create_enemy_shake_effect()
	
	# 确保恢复原始大小
	sprite.scale = current_scale

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
	
	# 更新血条（延迟执行，确保节点已创建）
	call_deferred("update_health_bar")

func create_health_bar() -> void:
	"""创建血条UI"""
	health_bar = Control.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(-32, -45)
	health_bar.size = Vector2(64, 10)
	add_child(health_bar)
	
	# 血条背景
	var health_bg = ColorRect.new()
	health_bg.name = "HealthBG"
	health_bg.size = Vector2(64, 10)
	health_bg.color = Color(0.2, 0.2, 0.2, 1.0)
	health_bar.add_child(health_bg)
	
	# 血条前景
	health_fill = ColorRect.new()
	health_fill.name = "HealthFill"
	health_fill.size = Vector2(64, 10)
	health_fill.color = Color.GREEN
	health_bar.add_child(health_fill)

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

## ========== 敌人死亡系统 ==========

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

## ========== 敌人通用技能系统 ==========

func cast_enemy_skill(skill_name: String, _target: Node = null) -> void:
	"""敌人释放技能（基础实现，子类可重写）"""
	match skill_name:
		"heal_self":
			cast_heal_skill()
		_:
			print("⚠️ 基类不支持技能: ", skill_name, "，应由子类实现")

func cast_heal_skill() -> void:
	"""释放自我治疗技能"""
	heal(30)
	print("🩹 ", character_name, " 释放自我治疗!")

## ========== 敌人通用AI接口方法 ==========

func get_ai_state() -> String:
	"""获取AI状态（基础实现）"""
	return "INTEGRATED"  # AI已集成到子类

func set_room_id(new_room_id: Vector2i) -> void:
	"""设置所属房间ID"""
	room_id = new_room_id

## ========== 敌人通用调试信息 ==========

func get_debug_info() -> Dictionary:
	"""获取敌人调试信息"""
	var debug_info = super.get_debug_info()
	debug_info.merge({
		"room_id": str(room_id),
		"experience_reward": experience_reward,
		"ai_state": get_ai_state(),
		"ai_description": get_ai_description() if has_method("get_ai_description") else "无描述",
		"health": str(health) + "/" + str(max_health),
	})
	return debug_info

func get_ai_description() -> String:
	"""获取AI描述（子类可重写）"""
	return "基础敌人AI"