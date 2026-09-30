class_name EnemyCharacter
extends CharacterBase

const Constants = preload("res://scripts/core/GameConstants.gd")

# 🦹 敌人角色基类 - 继承自CharacterBase，提供敌人通用功能

## ========== 敌人通用属性 ==========

@export var experience_reward: int = 10
@export var loot_chance: float = 0.1
@export var has_silverkey: bool = false  # 是否携带银钥匙

var encounter_owner: Node
var encounter_member_id: String = ""
var home_position: Vector2
var encounter_returning := false
var world_path := PackedVector2Array()
var path_refresh := 0.0
var rewards_emitted := false

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
	add_to_group(Constants.GROUP_ENEMIES)
	
	# AI逻辑已直接集成到子类中，无需单独的AI控制器
	
	# 设置视觉效果（由子类实现）
	setup_visuals()
	
	# 更新血条（延迟执行，确保节点已创建）
	call_deferred("update_health_bar")
	
	DebugLog.debug(["👹 敌人基类初始化完成: ", character_name], DebugLog.CATEGORY_AI)

## ========== 抽象方法（子类必须实现） ==========

func setup_ai_controller() -> void:
	"""AI控制器已废弃，逻辑直接集成到敌人子类中"""
	pass

func setup_visuals() -> void:
	"""设置敌人视觉效果（子类实现）"""
	DebugLog.warning(["setup_visuals() 应该由子类实现"], DebugLog.CATEGORY_AI)

func _physics_process(_delta: float) -> void:
	# Enemy subclasses own AI movement and call move_and_slide() after setting velocity.
	if encounter_returning and buff_system and not buff_system.active_buffs.is_empty():
		buff_system.clear_all_buffs()
	if is_dead or is_stunned:
		velocity = Vector2.ZERO
		return
	path_refresh -= _delta
	if is_instance_valid(encounter_owner):
		if not encounter_returning and global_position.distance_to(encounter_owner.global_position) > encounter_owner.config.leash_radius:
			begin_encounter_return()
		if encounter_returning:
			if global_position.distance_to(home_position) > 12:
				navigate_to_target(home_position)
				move_and_slide()
			else:
				velocity = Vector2.ZERO
				if encounter_owner.state == encounter_owner.State.ACTIVE:
					encounter_returning = false
					modulate = Color.WHITE

func can_process_enemy_ai() -> bool:
	return not is_dead and not is_stunned and not encounter_returning and process_mode != Node.PROCESS_MODE_DISABLED

func begin_encounter_return() -> void:
	encounter_returning = true
	set("current_target", null)
	world_path.clear()
	path_refresh = 0
	if buff_system:
		buff_system.clear_all_buffs()
	modulate = Color(0.65, 0.8, 0.8, 0.8)

func move_towards(target_position: Vector2, speed_multiplier: float = 1.0) -> void:
	if is_instance_valid(encounter_owner):
		navigate_to_target(target_position)
		velocity *= speed_multiplier
	else:
		super.move_towards(target_position, speed_multiplier)

func execute_attack_behavior() -> void:
	"""执行攻击行为（子类实现）"""
	DebugLog.warning(["execute_attack_behavior() 应该由子类实现"], DebugLog.CATEGORY_AI)

func execute_chase_behavior() -> void:
	"""执行追击行为（子类实现）"""
	DebugLog.warning(["execute_chase_behavior() 应该由子类实现"], DebugLog.CATEGORY_AI)

## ========== 智能寻路系统（射线检测避障） ==========

func navigate_to_target(target_pos: Vector2) -> void:
	if not is_instance_valid(encounter_owner):
		velocity = global_position.direction_to(target_pos) * current_speed
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = $CollisionShape2D.global_transform
	query.motion = target_pos - global_position
	query.collision_mask = Constants.LAYER_WORLD
	if get_world_2d().direct_space_state.cast_motion(query)[0] >= 1.0:
		velocity = global_position.direction_to(target_pos) * current_speed
		return
	if path_refresh <= 0:
		world_path = encounter_owner.world.find_navigation_path(global_position, target_pos)
		path_refresh = 0.35
		if world_path.size() > 1 and encounter_owner.world.is_walkable(global_position):
			world_path.remove_at(0)
	while not world_path.is_empty() and global_position.distance_to(world_path[0]) < 12:
		world_path.remove_at(0)
	velocity = Vector2.ZERO if world_path.is_empty() else global_position.direction_to(world_path[0]) * current_speed

func handle_movement(_delta: float) -> void:
	"""敌人移动由AI控制，这里不需要实现"""
	pass

## ========== 攻击系统（子类可重写） ==========

func execute_attack(target_position: Vector2, target: Node = null) -> void:
	"""
	执行攻击效果（基础实现：发射弹道）
	
	⚠️ 注意：此方法由基类的 perform_attack() 调用，基类已处理：
	- 攻击冷却检查
	- 攻击距离检查
	- 状态切换
	
	子类可以重写此方法来实现自定义攻击方式：
	- 近战敌人：直接造成伤害（不使用弹道）
	- 远程敌人：发射弹道（使用默认实现）
	- 特殊敌人：自定义攻击效果（如范围攻击、多重攻击等）
	"""
	# 默认实现：发射弹道
	launch_projectile(target_position, target)
	
	# 播放攻击动画
	play_attack_animation()

func launch_projectile(target_pos: Vector2, _target: Node = null) -> void:
	"""
	发射攻击弹道（用于远程敌人）
	
	子类通常不需要重写此方法，而是重写：
	- execute_attack(): 改变攻击方式（如近战直接伤害）
	- set_projectile_appearance(): 改变弹道外观
	"""
	DebugLog.debug(["🚀 ", character_name, " 发射弹道 → 目标: ", target_pos, " 伤害: ", current_attack_damage], DebugLog.CATEGORY_COMBAT)
	
	# 创建攻击弹道
	create_attack_projectile(target_pos)
	DebugLog.debug(["弹道已添加到场景"], DebugLog.CATEGORY_COMBAT)

func create_attack_projectile(target_pos: Vector2) -> void:
	"""
	创建敌人攻击弹道的内部实现
	
	⚠️ 子类不应该重写此方法！
	要自定义弹道外观，请重写 set_projectile_appearance()
	"""
	var projectile_scene = load(Constants.SCENE_SKILL_EFFECT) as PackedScene
	var projectile = projectile_scene.instantiate()
	
	# 设置弹道基础属性
	projectile.position = global_position
	projectile.skill_type = "enemy_projectile"  # 标记为敌人弹道
	projectile.damage = current_attack_damage
	projectile.speed = 300  # 默认速度，子类可在set_projectile_appearance中修改
	projectile.max_distance = attack_range * 2  # 给足够的飞行距离
	projectile.life_time = 3.0
	projectile.collision_layer = Constants.LAYER_ENEMY
	projectile.collision_mask = Constants.MASK_WORLD_AND_PLAYERS
	projectile.source = self  # 弹道来源（用于寒冰护甲反击等）
	
	# 计算方向
	var direction = (target_pos - global_position).normalized()
	projectile.direction = direction
	
	# ✅ 关键：在initialize()之前设置外观
	# 由于SkillEffect.setup_enemy_projectile()不再强制设置外观，
	# 这里的设置会被保留
	set_projectile_appearance(projectile)
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null(Constants.NODE_SKILL_EFFECTS)
	if skill_effects:
		skill_effects.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)
	
	# 初始化弹道效果
	projectile.initialize()

func set_projectile_appearance(projectile: Node) -> void:
	"""
	设置弹道外观（子类应该重写此方法）
	
	可设置的属性：
	- sprite.modulate: 弹道颜色
	- sprite.scale: 弹道大小
	- projectile.speed: 弹道速度
	- projectile.set_meta("disable_rotation", true): 禁用旋转动画
	
	示例：
	func set_projectile_appearance(projectile: Node) -> void:
	    var sprite = projectile.get_node_or_null("Sprite2D")
	    if sprite:
	        sprite.modulate = Color.CYAN  # 青色弹道
	        sprite.scale = Vector2(0.25, 0.25)  # 更小的弹道
	    projectile.speed = 400  # 更快的速度
	"""
	var sprite_node = projectile.get_node_or_null("Sprite2D")
	if sprite_node:
		# 默认外观：橙红色，中等大小
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
	if encounter_returning:
		return
	# 记录玩家造成的伤害
	if source:
		if source.is_in_group(Constants.GROUP_PLAYERS):
			var game_manager = get_tree().current_scene.get_node_or_null(Constants.NODE_GAME_MANAGER)
			if game_manager and game_manager.has_method("record_damage"):
				game_manager.record_damage(amount)
			else:
				DebugLog.warning(["未找到GameManager或record_damage方法"], DebugLog.CATEGORY_COMBAT)
		else:
			var source_name: String = "null"
			if source:
				source_name = source.name
			DebugLog.debug(["伤害来源不是玩家: ", source_name], DebugLog.CATEGORY_COMBAT)
	
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
	
	# 显示浮动伤害数字（通用效果）
	show_floating_damage(actual_damage)
	
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
	if is_dead:
		return
	super.die()
	
	# 播放死亡动画
	play_death_animation()
	
	# 掉落经验和物品
	drop_rewards()
	
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
	if rewards_emitted:
		return
	rewards_emitted = true
	if is_instance_valid(encounter_owner) and not encounter_owner.claim_member_reward(encounter_member_id):
		return
	# 给玩家经验值
	var player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if player:
		player.gain_experience(experience_reward)
	
	# 掉落银钥匙
	if has_silverkey:
		drop_silver_key()
	
	# 随机掉落物品
	if randf() < loot_chance:
		drop_loot()

func drop_loot() -> void:
	"""掉落物品（待实现）"""
	DebugLog.info(["💎 ", character_name, " 掉落了物品!"], DebugLog.CATEGORY_COMBAT)
	# TODO: 实现物品掉落系统

func drop_silver_key() -> void:
	"""掉落银钥匙"""
	DebugLog.info(["🔑 ", character_name, " 掉落银钥匙！位置: ", global_position], DebugLog.CATEGORY_COMBAT)
	
	# ⚠️ 使用 call_deferred 延迟添加，避免在物理查询期间修改物理状态
	var drop_position = global_position
	call_deferred("_deferred_drop_silver_key", drop_position)

func _deferred_drop_silver_key(drop_position: Vector2) -> void:
	"""延迟掉落银钥匙（在下一帧执行）"""
	# 加载银钥匙场景
	var SilverKeyScene = preload("res://Scenes/SilverKey.tscn")
	var silver_key = SilverKeyScene.instantiate()
	
	# 设置银钥匙位置
	silver_key.global_position = drop_position
	
	# 将银钥匙添加到场景树
	var game_scene = get_tree().current_scene
	if game_scene:
		game_scene.add_child(silver_key)
		DebugLog.debug(["银钥匙已添加到场景"], DebugLog.CATEGORY_COMBAT)
	else:
		DebugLog.warning(["无法找到游戏场景，银钥匙添加失败"], DebugLog.CATEGORY_COMBAT)


func cast_enemy_skill(skill_name: String, _target: Node = null) -> void:
	"""敌人释放技能（基础实现，子类可重写）"""
	match skill_name:
		"heal_self":
			cast_heal_skill()
		_:
			DebugLog.warning(["基类不支持技能: ", skill_name, "，应由子类实现"], DebugLog.CATEGORY_AI)

func cast_heal_skill() -> void:
	"""释放自我治疗技能"""
	heal(30)
	DebugLog.info(["🩹 ", character_name, " 释放自我治疗!"], DebugLog.CATEGORY_COMBAT)

## ========== 敌人通用AI接口方法 ==========

func get_ai_state() -> String:
	"""获取AI状态（基础实现）"""
	return "INTEGRATED"  # AI已集成到子类

func get_debug_info() -> Dictionary:
	"""获取敌人调试信息"""
	var debug_info = super.get_debug_info()
	debug_info.merge({
		"encounter_id": str(encounter_owner.encounter_id) if is_instance_valid(encounter_owner) else "",
		"experience_reward": experience_reward,
		"ai_state": get_ai_state(),
		"ai_description": str(get_ai_description()) if has_method("get_ai_description") else "无描述",
		"health": str(health) + "/" + str(max_health),
	})
	return debug_info

func get_ai_description() -> String:
	"""获取AI描述（子类可重写）"""
	return "基础敌人AI"
