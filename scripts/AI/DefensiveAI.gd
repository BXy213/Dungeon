extends "res://scripts/AI/AIBase.gd"

# 🛡️ 防御型AI - 保持距离攻击，血量低时撤退

var retreat_position: Vector2 = Vector2.ZERO
var kiting_angle: float = 0.0

func _init(character: Node = null):
	super._init(character)
	ai_type = AIType.DEFENSIVE
	ai_name = "防御型AI"
	
	# 防御型AI配置
	aggression_level = 0.8
	detection_range = 400.0
	attack_range = 200.0  # 更远的攻击距离
	preferred_distance = 150.0  # 保持距离
	reaction_time = 0.4
	decision_interval = 1.0
	movement_style = "circle"

## ========== 重写行为方法 ==========

func execute_chase_behavior() -> void:
	"""防御型追击 - 保持距离"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 如果在攻击范围内，开始风筝战术
	if distance_to_target <= attack_range:
		change_state(AIState.ATTACK)
		return
	
	# 如果太近，先拉开距离
	if distance_to_target < preferred_distance:
		perform_retreat_movement()
	else:
		# 否则接近到合适距离
		perform_approach_movement()

func execute_attack_behavior() -> void:
	"""防御型攻击 - 边打边退"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 如果目标太近，撤退
	if distance_to_target < preferred_distance * 0.8:
		perform_retreat_movement()
	# 如果目标太远，接近
	elif distance_to_target > attack_range:
		change_state(AIState.CHASE)
		return
	else:
		# 在合适距离，进行风筝攻击
		perform_kiting_attack()

func execute_retreat_behavior() -> void:
	"""防御型撤退"""
	# 寻找安全位置
	if retreat_position == Vector2.ZERO:
		find_retreat_position()
	
	# 向安全位置移动
	owner_character.move_towards(retreat_position, 1.3)  # 快速撤退
	
	# 如果到达安全位置或血量恢复，停止撤退
	var distance_to_retreat = owner_character.global_position.distance_to(retreat_position)
	if distance_to_retreat < 50 or should_stop_retreating():
		retreat_position = Vector2.ZERO
		change_state(AIState.IDLE)

## ========== 特殊移动行为 ==========

func perform_retreat_movement() -> void:
	"""撤退移动 - 远离目标"""
	if not current_target:
		return
	
	var direction_away = owner_character.get_direction_to(current_target) * -1
	var retreat_pos = owner_character.global_position + direction_away * 80
	owner_character.move_towards(retreat_pos, 1.1)

func perform_approach_movement() -> void:
	"""接近移动 - 谨慎接近"""
	if not current_target:
		return
	
	# 不直接冲向目标，而是斜着接近
	var base_direction = owner_character.get_direction_to(current_target)
	var angle_offset = sin(state_time * 2) * 0.5  # 左右摆动
	var approach_direction = base_direction.rotated(angle_offset)
	var approach_pos = owner_character.global_position + approach_direction * 60
	
	owner_character.move_towards(approach_pos, 0.8)

func perform_kiting_attack() -> void:
	"""风筝攻击 - 边打边移动"""
	if not owner_character or not current_target:
		return
	
	# 攻击
	if owner_character.can_attack():
		owner_character.perform_attack(current_target.global_position, current_target)
	
	# 攻击后立即侧移
	kiting_angle += 90  # 每次攻击后改变90度
	var side_direction = Vector2(cos(kiting_angle * PI / 180), sin(kiting_angle * PI / 180))
	var kiting_pos = owner_character.global_position + side_direction * 40
	
	owner_character.move_towards(kiting_pos, 0.9)

func find_retreat_position() -> void:
	"""寻找撤退位置"""
	if not current_target:
		retreat_position = owner_character.global_position + Vector2(200, 0)
		return
	
	# 寻找远离目标的安全位置
	var direction_away = owner_character.get_direction_to(current_target) * -1
	retreat_position = owner_character.global_position + direction_away * 250
	
	# 尝试避开障碍物（简单实现）
	var space_state = owner_character.get_world_2d().direct_space_state
	if space_state:
		var query = PhysicsRayQueryParameters2D.create(
			owner_character.global_position, 
			retreat_position
		)
		var result = space_state.intersect_ray(query)
		if result:
			# 如果有障碍物，调整撤退位置
			retreat_position = owner_character.global_position + direction_away.rotated(PI/4) * 200

## ========== 条件检查重写 ==========

func should_retreat() -> bool:
	"""防御型AI更容易撤退"""
	if not owner_character:
		return false
	
	var health_ratio = owner_character.get_health_percentage()
	return health_ratio < 0.6  # 血量低于60%就撤退

func should_stop_retreating() -> bool:
	"""防御型AI撤退条件"""
	if not owner_character:
		return true
	
	var health_ratio = owner_character.get_health_percentage()
	var target_distance = INF
	
	if has_valid_target():
		target_distance = owner_character.get_distance_to(current_target)
	
	# 血量恢复到80%以上，或者目标足够远时停止撤退
	return health_ratio > 0.8 or target_distance > detection_range * 1.2

func perform_circle_movement() -> void:
	"""防御型环绕移动 - 保持安全距离"""
	if not current_target:
		return
	
	var distance = owner_character.get_distance_to(current_target)
	var desired_distance = preferred_distance
	
	if distance > desired_distance + 30:
		# 距离太远，谨慎接近
		perform_approach_movement()
	elif distance < desired_distance - 30:
		# 距离太近，快速撤退
		perform_retreat_movement()
	else:
		# 距离合适，环绕移动
		var angle = state_time * 1.5  # 环绕速度
		var offset = Vector2(cos(angle), sin(angle)) * desired_distance
		var circle_pos = current_target.global_position + offset
		owner_character.move_towards(circle_pos, 0.9)
