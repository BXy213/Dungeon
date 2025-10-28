extends "res://scripts/AI/AIBase.gd"

# ⚔️ 普通近战小兵AI - 拉近距离进行普攻

func _init(character: Node = null):
	super._init(character)
	ai_type = AIType.AGGRESSIVE
	ai_name = "近战小兵AI"
	
	# 近战小兵AI配置
	aggression_level = 1.0
	detection_range = 200.0
	attack_range = 60.0  # 较短的攻击距离
	reaction_time = 0.5
	decision_interval = 1.0
	movement_style = "direct"

func setup_ai() -> void:
	"""设置近战小兵AI特性"""
	super.setup_ai()
	
	if decision_timer:
		decision_timer.wait_time = decision_interval

## ========== 重写行为方法 ==========

func execute_idle_behavior() -> void:
	"""近战小兵空闲行为"""
	super.execute_idle_behavior()
	
	# 相对不太主动的巡逻
	if not has_valid_target() and randf() < 0.3:
		change_state(AIState.PATROL)

func execute_chase_behavior() -> void:
	"""近战小兵追击行为 - 直线冲向目标"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 进入攻击范围
	if distance_to_target <= attack_range:
		change_state(AIState.ATTACK)
		return
	
	# 距离太远放弃追击
	if distance_to_target > lose_target_distance:
		lose_target()
		return
	
	# 直接冲向目标
	perform_direct_chase()

func execute_attack_behavior() -> void:
	"""近战小兵攻击行为"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 目标太远，切换到追击
	if distance_to_target > attack_range * 1.2:
		change_state(AIState.CHASE)
		return
	
	# 执行近战攻击
	perform_melee_attack()

## ========== 特殊行为实现 ==========

func perform_direct_chase() -> void:
	"""直接追击移动"""
	if not current_target:
		return
	
	# 直接移动到目标位置
	owner_character.move_towards(current_target.global_position, 1.0)

func perform_melee_attack() -> void:
	"""近战攻击"""
	if not owner_character or not current_target:
		return
	
	if owner_character.can_attack():
		owner_character.perform_attack(current_target.global_position, current_target)
		
		# 攻击后稍微后退一点点
		var retreat_direction = (owner_character.global_position - current_target.global_position).normalized()
		owner_character.move_towards(owner_character.global_position + retreat_direction * 20, 0.5)

## ========== 条件检查重写 ==========

func should_retreat() -> bool:
	"""近战小兵在低血量时会短暂撤退"""
	if not owner_character:
		return false
	
	var health_ratio = owner_character.get_health_percentage()
	return health_ratio < 0.25  # 25%血量时撤退

func should_start_patrol() -> bool:
	"""近战小兵偶尔巡逻"""
	return randf() < 0.4  # 40%概率开始巡逻
