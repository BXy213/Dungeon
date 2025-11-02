class_name EnemyCharacter
extends CharacterBase

# 🦹 敌人角色基类 - 继承自CharacterBase，提供敌人通用功能

## ========== 敌人通用属性 ==========

@export var room_id: Vector2i = Vector2i.ZERO
@export var is_room_enemy: bool = true
@export var experience_reward: int = 10
@export var loot_chance: float = 0.1
@export var has_silverkey: bool = false  # 是否携带银钥匙

# AI逻辑已直接集成到敌人子类中

# 敌人血条UI组件（通过代码创建，不使用@onready）
var health_bar: Control = null
var health_fill: ColorRect = null

# 智能寻路配置
var use_smart_pathfinding: bool = true  # 是否使用射线检测避障
var avoidance_direction: Vector2 = Vector2.ZERO  # 当前避障方向
var avoidance_timer: float = 0.0  # 避障方向保持时间
var last_direction: Vector2 = Vector2.ZERO  # 上一帧的移动方向

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

## ========== 智能寻路系统（射线检测避障） ==========

func navigate_to_target(target_pos: Vector2) -> void:
	"""智能移动到目标位置（使用射线检测避障，带平滑移动）"""
	# 计算到目标的方向
	var to_target = target_pos - global_position
	var distance_to_target = to_target.length()
	var direction = to_target.normalized()
	
	# 减少避障计时器
	if avoidance_timer > 0:
		avoidance_timer -= get_physics_process_delta_time()
	
	# 只在需要时重新计算避障方向（避免频繁切换）
	if avoidance_timer <= 0:
		# 使用射线检测检查是否有障碍物（提前检测，距离更远）
		var detection_distance = min(distance_to_target, 150.0)  # 最多检测150像素
		var detection_target = global_position + direction * detection_distance
		
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, detection_target)
		query.collision_mask = 1  # 只检测障碍物层
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		
		if result:
			# 检测到障碍物，计算新的避障方向
			var obstacle_pos = result.position
			var to_obstacle = obstacle_pos - global_position
			
			# 只有在障碍物比较近时才避障（距离小于80像素）
			if to_obstacle.length() < 80.0:
				# 计算绕路方向（左右两侧）
				var perpendicular_left = Vector2(-direction.y, direction.x)
				var perpendicular_right = Vector2(direction.y, -direction.x)
				
				# 检测左右两侧哪边更通畅
				var left_ray = PhysicsRayQueryParameters2D.create(
					global_position, 
					global_position + perpendicular_left * 80
				)
				left_ray.collision_mask = 1
				left_ray.exclude = [self]
				
				var right_ray = PhysicsRayQueryParameters2D.create(
					global_position, 
					global_position + perpendicular_right * 80
				)
				right_ray.collision_mask = 1
				right_ray.exclude = [self]
				
				var left_result = space_state.intersect_ray(left_ray)
				var right_result = space_state.intersect_ray(right_ray)
				
				# 选择更通畅的一侧
				if not left_result and not right_result:
					# 两侧都通畅，选择更靠近目标的一侧
					var left_to_target = (target_pos - (global_position + perpendicular_left * 40)).length()
					var right_to_target = (target_pos - (global_position + perpendicular_right * 40)).length()
					avoidance_direction = perpendicular_left if left_to_target < right_to_target else perpendicular_right
				elif not left_result:
					avoidance_direction = perpendicular_left
				elif not right_result:
					avoidance_direction = perpendicular_right
				else:
					# 两侧都有障碍，向远离障碍的方向移动
					avoidance_direction = (global_position - obstacle_pos).normalized()
				
				# 设置避障计时器，在一段时间内保持这个方向（减少抖动）
				avoidance_timer = 0.3  # 保持0.3秒
			else:
				# 障碍物还比较远，不需要避障
				avoidance_direction = Vector2.ZERO
				avoidance_timer = 0.1
		else:
			# 没有障碍物，重置避障方向
			avoidance_direction = Vector2.ZERO
			avoidance_timer = 0.1
	
	# 计算最终方向
	var final_direction = direction
	if avoidance_direction != Vector2.ZERO:
		# 混合避障方向和目标方向
		final_direction = (avoidance_direction * 0.6 + direction * 0.4).normalized()
	
	# 与上一帧方向插值，使移动更平滑
	if last_direction != Vector2.ZERO:
		final_direction = last_direction.lerp(final_direction, 0.3)  # 30%的插值，使转向更平滑
	
	# 记录当前方向
	last_direction = final_direction.normalized()
	
	# 设置速度
	velocity = final_direction * current_speed

## ========== 敌人通用移动系统 ==========

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
	print("🚀 ", character_name, " 发射弹道 → 目标: ", target_pos, " 伤害: ", current_attack_damage)
	
	# 房间ID验证 - 只在当前房间创建弹道
	var dungeon_generator = get_tree().current_scene.get_node_or_null("DungeonGenerator")
	if dungeon_generator:
		var current_room_id = dungeon_generator.get_current_room_coord()
		if room_id != current_room_id:
			print("    ❌ 敌人不在当前房间，跳过攻击")
			return
	
	# 创建攻击弹道
	create_attack_projectile(target_pos)
	print("  ✅ 弹道已添加到场景")

func create_attack_projectile(target_pos: Vector2) -> void:
	"""
	创建敌人攻击弹道的内部实现
	
	⚠️ 子类不应该重写此方法！
	要自定义弹道外观，请重写 set_projectile_appearance()
	"""
	var projectile = preload("res://Scenes/SkillEffect.tscn").instantiate()
	
	# 设置弹道基础属性
	projectile.position = global_position
	projectile.skill_type = "enemy_projectile"  # 标记为敌人弹道
	projectile.damage = current_attack_damage
	projectile.speed = 300  # 默认速度，子类可在set_projectile_appearance中修改
	projectile.max_distance = attack_range * 2  # 给足够的飞行距离
	projectile.life_time = 3.0
	projectile.collision_layer = 4  # 敌人弹道层
	projectile.collision_mask = 3   # 检测玩家层(2) + 障碍物层(1) = 3
	projectile.source = self  # 弹道来源（用于寒冰护甲反击等）
	
	# 计算方向
	var direction = (target_pos - global_position).normalized()
	projectile.direction = direction
	
	# ✅ 关键：在initialize()之前设置外观
	# 由于SkillEffect.setup_enemy_projectile()不再强制设置外观，
	# 这里的设置会被保留
	set_projectile_appearance(projectile)
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null("SkillEffects")
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
	# 记录玩家造成的伤害
	if source:
		if source.is_in_group("players"):
			var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
			if game_manager and game_manager.has_method("record_damage"):
				game_manager.record_damage(amount)
			else:
				print("⚠️ 未找到GameManager或record_damage方法")
		else:
			var source_name: String = "null"
			if source:
				source_name = source.name
			print("⚠️ 伤害来源不是玩家: ", source_name)
	
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
	# 检查是否是BOSS（在调用super.die()之前处理金钥匙掉落）
	if character_name == "BOSS":
		print("🎉 检测到BOSS死亡！将掉落金钥匙...")
		drop_golden_key()
	
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
	
	# 掉落银钥匙
	if has_silverkey:
		drop_silver_key()
	
	# 随机掉落物品
	if randf() < loot_chance:
		drop_loot()

func drop_loot() -> void:
	"""掉落物品（待实现）"""
	print("💎 ", character_name, " 掉落了物品!")
	# TODO: 实现物品掉落系统

func drop_silver_key() -> void:
	"""掉落银钥匙"""
	print("🔑 ", character_name, " 掉落银钥匙！位置: ", global_position)
	
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
		print("  ✓ 银钥匙已添加到场景")
	else:
		print("  ⚠️ 无法找到游戏场景，银钥匙添加失败")

func drop_golden_key() -> void:
	"""掉落金钥匙（BOSS专属）"""
	print("🏆 ", character_name, " 掉落金钥匙！位置: ", global_position)
	
	# ⚠️ 使用 call_deferred 延迟添加，避免在物理查询期间修改物理状态
	var drop_position = global_position
	call_deferred("_deferred_drop_golden_key", drop_position)

func _deferred_drop_golden_key(drop_position: Vector2) -> void:
	"""延迟掉落金钥匙（在下一帧执行）"""
	# 加载金钥匙场景
	var GoldenKeyScene = preload("res://Scenes/GoldenKey.tscn")
	var golden_key = GoldenKeyScene.instantiate()
	
	# 设置金钥匙位置
	golden_key.global_position = drop_position
	
	# 将金钥匙添加到场景树
	var game_scene = get_tree().current_scene
	if game_scene:
		game_scene.add_child(golden_key)
		print("  ✓ 金钥匙已添加到场景")
	else:
		print("  ⚠️ 无法找到游戏场景，金钥匙添加失败")

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

func get_current_room_bounds() -> Rect2:
	"""
	获取当前房间的全局边界区域
	
	返回：Rect2 表示房间的全局坐标区域（包含position和size）
	如果找不到房间，返回一个默认的大区域
	"""
	# 尝试获取当前房间（敌人在Enemies容器中，父节点是房间）
	var current_room = get_parent().get_parent() if get_parent() and get_parent().get_parent() else null
	
	if not current_room:
		print("⚠️ 无法找到当前房间，使用默认边界")
		return Rect2(0, 0, 1152, 648)  # 默认房间大小
	
	# 获取房间的全局位置和大小
	var room_global_pos = current_room.global_position if current_room.has_method("get_global_position") else Vector2.ZERO
	var room_size = current_room.room_size if "room_size" in current_room else Vector2(1152, 648)
	
	# 添加边界留白，避免生成在墙壁上
	var margin = 80.0
	
	return Rect2(
		room_global_pos.x + margin,
		room_global_pos.y + margin,
		room_size.x - margin * 2,
		room_size.y - margin * 2
	)
