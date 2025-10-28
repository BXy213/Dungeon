extends "res://scripts/AI/AIBase.gd"

# 👑 精英近战士兵AI - 拉近距离普攻，近距离时有概率释放毒攻击

var poison_attack_range: float = 40.0  # 毒攻击范围
var poison_attack_chance: float = 0.3  # 毒攻击概率
var poison_cooldown: float = 5.0  # 毒攻击冷却时间
var last_poison_time: float = 0.0

func _init(character: Node = null):
	super._init(character)
	ai_type = AIType.AGGRESSIVE
	ai_name = "精英近战士兵AI"
	
	# 精英近战士兵AI配置
	aggression_level = 1.3
	detection_range = 220.0
	attack_range = 70.0  # 比普通近战稍长
	reaction_time = 0.3
	decision_interval = 0.9
	movement_style = "aggressive"

func setup_ai() -> void:
	"""设置精英近战士兵AI特性"""
	super.setup_ai()
	
	if decision_timer:
		decision_timer.wait_time = decision_interval

## ========== 重写行为方法 ==========

func execute_idle_behavior() -> void:
	"""精英近战士兵空闲行为"""
	super.execute_idle_behavior()
	
	# 精英更主动寻找目标
	if not has_valid_target() and randf() < 0.7:
		change_state(AIState.PATROL)

func execute_chase_behavior() -> void:
	"""精英近战士兵追击行为 - 积极追击"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 进入攻击范围
	if distance_to_target <= attack_range:
		change_state(AIState.ATTACK)
		return
	
	# 精英追击距离更远
	if distance_to_target > lose_target_distance * 1.3:
		lose_target()
		return
	
	# 更快的追击
	perform_elite_chase()

func execute_attack_behavior() -> void:
	"""精英近战士兵攻击行为"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 目标太远，切换到追击
	if distance_to_target > attack_range * 1.3:
		change_state(AIState.CHASE)
		return
	
	# 检查是否可以使用毒攻击
	if can_use_poison_attack() and distance_to_target <= poison_attack_range:
		perform_poison_attack()
	else:
		perform_elite_melee_attack()

## ========== 特殊行为实现 ==========

func perform_elite_chase() -> void:
	"""精英追击移动 - 带预测"""
	if not current_target:
		return
	
	# 预测目标位置
	var target_velocity = Vector2.ZERO
	if current_target.has_method("get_velocity"):
		target_velocity = current_target.velocity
	
	# 预测目标0.3秒后的位置
	var predicted_position = current_target.global_position + target_velocity * 0.3
	
	# 以更快的速度冲向预测位置
	owner_character.move_towards(predicted_position, 1.1)

func perform_elite_melee_attack() -> void:
	"""精英近战攻击"""
	if not owner_character or not current_target:
		return
	
	if owner_character.can_attack():
		# 精英的普攻伤害更高
		owner_character.perform_attack(current_target.global_position, current_target)
		
		# 攻击后短暂前冲，更加aggressive
		var charge_direction = (current_target.global_position - owner_character.global_position).normalized()
		owner_character.move_towards(owner_character.global_position + charge_direction * 15, 0.8)

func can_use_poison_attack() -> bool:
	"""检查是否可以使用毒攻击"""
	var current_time = Time.get_time_dict_from_system()
	var time_since_last_poison = current_time.get("second", 0) - last_poison_time
	
	# 冷却时间检查 + 概率检查
	return time_since_last_poison >= poison_cooldown and randf() < poison_attack_chance

func perform_poison_attack() -> void:
	"""执行毒攻击"""
	if not owner_character or not current_target:
		return
	
	print("💚 精英近战士兵释放毒攻击!")
	
	# 更新最后使用毒攻击的时间
	last_poison_time = Time.get_time_dict_from_system().get("second", 0)
	
	# 创建毒攻击效果
	create_poison_attack_effect()
	
	# 对目标造成毒伤害并应用毒buff
	if current_target.has_method("take_damage"):
		var poison_damage = owner_character.current_attack_damage * 0.8  # 毒攻击伤害稍低
		current_target.take_damage(poison_damage)
		
		# 应用毒buff
		if current_target.has_method("apply_buff"):
			# BuffType.POISON = 2 (根据BuffSystem.gd)
			current_target.apply_buff(2, 3.0, 0.3)  # 毒害3秒，每秒0.3倍伤害
			print("🐍 对 ", current_target.character_name, " 施加毒害效果")

func create_poison_attack_effect() -> void:
	"""创建毒攻击视觉效果"""
	var poison_effect = preload("res://Scenes/SkillEffect.tscn").instantiate()
	poison_effect.position = owner_character.global_position
	poison_effect.skill_type = "poison_burst"
	poison_effect.life_time = 1.0
	poison_effect.damage = 0  # 伤害已经单独处理
	
	# 设置毒攻击的视觉效果
	var effect_sprite = poison_effect.get_node_or_null("Sprite2D")
	if effect_sprite:
		effect_sprite.modulate = Color.GREEN
		effect_sprite.scale = Vector2(1.5, 1.5)
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null("SkillEffects")
	if skill_effects:
		skill_effects.add_child(poison_effect)
	else:
		get_tree().current_scene.add_child(poison_effect)

## ========== 条件检查重写 ==========

func should_retreat() -> bool:
	"""精英近战士兵很少撤退"""
	if not owner_character:
		return false
	
	var health_ratio = owner_character.get_health_percentage()
	# 只在极低血量时撤退
	return health_ratio < 0.15

func should_start_patrol() -> bool:
	"""精英近战士兵经常巡逻寻找目标"""
	return randf() < 0.8  # 80%概率开始巡逻

func find_new_target() -> void:
	"""精英寻找目标 - 优先攻击距离近的敌人"""
	super.find_new_target()
	
	# 如果有多个目标，选择距离最近的
	if nearby_players.size() > 1:
		var closest_target = null
		var shortest_distance = 999999.0
		
		for player in nearby_players:
			var distance = owner_character.get_distance_to(player)
			if distance < shortest_distance:
				shortest_distance = distance
				closest_target = player
		
		if closest_target:
			acquire_target(closest_target)
