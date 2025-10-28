extends "res://scripts/AI/AIBase.gd"

# 🗡️ 攻击型AI - 主动攻击，直接冲向目标

func _init(character: Node = null):
	super._init(character)
	ai_type = AIType.AGGRESSIVE
	ai_name = "攻击型AI"
	
	# 攻击型AI配置
	aggression_level = 1.5
	detection_range = 350.0
	attack_range = 120.0
	reaction_time = 0.3
	decision_interval = 0.8
	movement_style = "direct"

func setup_ai() -> void:
	"""设置攻击型AI特性"""
	super.setup_ai()
	
	# 攻击型AI更快的反应和决策
	if decision_timer:
		decision_timer.wait_time = decision_interval

## ========== 重写行为方法 ==========

func execute_idle_behavior() -> void:
	"""攻击型空闲行为 - 更主动寻找目标"""
	super.execute_idle_behavior()
	
	# 如果没有目标，主动巡逻寻找
	if not has_valid_target() and randf() < 0.6:
		change_state(AIState.PATROL)

func execute_chase_behavior() -> void:
	"""攻击型追击行为 - 更积极追击"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 攻击型AI更远的攻击范围判定
	if distance_to_target <= attack_range * 1.2:
		change_state(AIState.ATTACK)
		return
	
	# 攻击型AI追击距离更远
	if distance_to_target > lose_target_distance * 1.5:
		lose_target()
		return
	
	# 更快速的追击
	perform_aggressive_chase()

func execute_attack_behavior() -> void:
	"""攻击型攻击行为 - 连续攻击"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 攻击型AI即使目标稍远也继续攻击
	if distance_to_target > attack_range * 1.3:
		change_state(AIState.CHASE)
		return
	
	# 连续攻击
	perform_continuous_attack()

## ========== 特殊行为实现 ==========

func perform_aggressive_chase() -> void:
	"""攻击型追击移动"""
	if not current_target:
		return
	
	# 预测目标位置
	var target_velocity = Vector2.ZERO
	if current_target.has_method("get_velocity"):
		target_velocity = current_target.velocity
	
	# 预测目标0.5秒后的位置
	var predicted_position = current_target.global_position + target_velocity * 0.5
	
	# 直接冲向预测位置
	owner_character.move_towards(predicted_position, 1.2)  # 120%速度

func perform_continuous_attack() -> void:
	"""连续攻击"""
	if not owner_character or not current_target:
		return
	
	# 攻击型AI攻击间隔更短
	if owner_character.can_attack():
		owner_character.perform_attack(current_target.global_position, current_target)
		
		# 攻击后短暂停顿，然后继续
		await get_tree().create_timer(0.2).timeout
		
		# 如果目标仍在范围内，继续攻击
		if has_valid_target() and owner_character.get_distance_to(current_target) <= attack_range:
			perform_attack()

## ========== 条件检查重写 ==========

func should_retreat() -> bool:
	"""攻击型AI很少撤退"""
	if not owner_character:
		return false
	
	var health_ratio = owner_character.get_health_percentage()
	# 只在极低血量时撤退
	return health_ratio < 0.1

func should_start_patrol() -> bool:
	"""攻击型AI更频繁巡逻"""
	return randf() < 0.7  # 70%概率开始巡逻

func find_new_target() -> void:
	"""攻击型AI寻找目标 - 优先攻击血量低的敌人"""
	super.find_new_target()
	
	# 如果有多个目标，选择血量最低的
	if nearby_players.size() > 1:
		var weakest_target = null
		var lowest_health_ratio = 1.0
		
		for player in nearby_players:
			if player.has_method("get_health_percentage"):
				var health_ratio = player.get_health_percentage()
				if health_ratio < lowest_health_ratio:
					lowest_health_ratio = health_ratio
					weakest_target = player
		
		if weakest_target:
			acquire_target(weakest_target)
