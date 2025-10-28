extends "res://scripts/AI/AIBase.gd"

# 🏹 普通远程小兵AI - 保持距离并游走，快速弹道攻击

var ranged_preferred_distance: float = 120.0  # 偏好的攻击距离
var min_distance: float = 80.0  # 最小保持距离
var max_distance: float = 180.0  # 最大攻击距离
var strafe_timer: float = 0.0
var strafe_direction: Vector2 = Vector2.ZERO

func _init(character: Node = null):
	super._init(character)
	ai_type = AIType.AGGRESSIVE
	ai_name = "远程小兵AI"
	
	# 远程小兵AI配置
	aggression_level = 0.8
	detection_range = 250.0
	attack_range = 150.0  # 较长的攻击距离
	reaction_time = 0.4
	decision_interval = 0.8
	movement_style = "tactical"

func setup_ai() -> void:
	"""设置远程小兵AI特性"""
	super.setup_ai()
	
	if decision_timer:
		decision_timer.wait_time = decision_interval

## ========== 重写行为方法 ==========

func execute_idle_behavior() -> void:
	"""远程小兵空闲行为"""
	super.execute_idle_behavior()
	
	# 远程小兵更喜欢巡逻
	if not has_valid_target() and randf() < 0.5:
		change_state(AIState.PATROL)

func execute_chase_behavior() -> void:
	"""远程小兵追击行为 - 保持距离"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 进入攻击范围
	if distance_to_target <= attack_range and distance_to_target >= min_distance:
		change_state(AIState.ATTACK)
		return
	
	# 距离太远，靠近一些
	if distance_to_target > max_distance:
		if distance_to_target > lose_target_distance:
			lose_target()
			return
		else:
			approach_target()
	# 距离太近，后退
	elif distance_to_target < min_distance:
		retreat_from_target()

func execute_attack_behavior() -> void:
	"""远程小兵攻击行为"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 距离不合适，调整位置
	if distance_to_target > max_distance or distance_to_target < min_distance:
		change_state(AIState.CHASE)
		return
	
	# 执行远程攻击和游走
	perform_ranged_attack_and_strafe()

## ========== 特殊行为实现 ==========

func approach_target() -> void:
	"""接近目标到合适距离"""
	if not current_target:
		return
	
	var direction = (current_target.global_position - owner_character.global_position).normalized()
	var target_pos = current_target.global_position - direction * ranged_preferred_distance
	owner_character.move_towards(target_pos, 0.8)

func retreat_from_target() -> void:
	"""从目标后退到安全距离"""
	if not current_target:
		return
	
	var direction = (owner_character.global_position - current_target.global_position).normalized()
	var retreat_pos = owner_character.global_position + direction * 50
	owner_character.move_towards(retreat_pos, 1.2)

func perform_ranged_attack_and_strafe() -> void:
	"""远程攻击并左右游走"""
	if not owner_character or not current_target:
		return
	
	# 执行攻击
	if owner_character.can_attack():
		# 创建更快的弹道
		owner_character.perform_attack(current_target.global_position, current_target)
		
		# 攻击后改变游走方向
		update_strafe_direction()
	
	# 执行游走移动
	perform_strafe_movement()

func update_strafe_direction() -> void:
	"""更新游走方向"""
	strafe_timer -= get_physics_process_delta_time()
	
	if strafe_timer <= 0.0:
		# 随机选择左右方向
		var target_direction = (current_target.global_position - owner_character.global_position).normalized()
		var perpendicular = Vector2(-target_direction.y, target_direction.x)
		
		# 随机选择左或右
		if randf() < 0.5:
			perpendicular = -perpendicular
		
		strafe_direction = perpendicular
		strafe_timer = randf_range(1.0, 2.5)  # 1-2.5秒后改变方向

func perform_strafe_movement() -> void:
	"""执行游走移动"""
	if strafe_direction == Vector2.ZERO:
		update_strafe_direction()
		return
	
	# 计算游走目标位置
	var strafe_distance = 60.0
	var strafe_pos = owner_character.global_position + strafe_direction * strafe_distance
	
	# 确保不会离目标太远或太近
	var distance_to_target_from_strafe = strafe_pos.distance_to(current_target.global_position)
	if distance_to_target_from_strafe > min_distance and distance_to_target_from_strafe < max_distance:
		owner_character.move_towards(strafe_pos, 0.6)

## ========== 重写攻击属性 ==========

func get_projectile_speed_multiplier() -> float:
	"""远程小兵的弹道速度更快"""
	return 1.5

func get_projectile_scale() -> float:
	"""远程小兵的子弹更小"""
	return 0.7

## ========== 条件检查重写 ==========

func should_retreat() -> bool:
	"""远程小兵在较高血量时就会撤退"""
	if not owner_character:
		return false
	
	var health_ratio = owner_character.get_health_percentage()
	return health_ratio < 0.4  # 40%血量时撤退

func should_start_patrol() -> bool:
	"""远程小兵经常巡逻"""
	return randf() < 0.6  # 60%概率开始巡逻
