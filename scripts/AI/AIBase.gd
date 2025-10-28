class_name AIBase
extends Node

# 🤖 AI基类 - 敌人行为的基础框架

## AI状态枚举
enum AIState {
	IDLE,           # 空闲状态
	PATROL,         # 巡逻状态
	CHASE,          # 追击玩家
	ATTACK,         # 攻击状态
	RETREAT,        # 撤退状态
	SEARCH,         # 搜索玩家
	STUNNED,        # 被眩晕
	DEAD            # 死亡
}

## AI类型枚举
enum AIType {
	PASSIVE,        # 被动型（不主动攻击）
	AGGRESSIVE,     # 攻击型（主动攻击）
	DEFENSIVE,      # 防御型（保持距离攻击）
	BERSERKER,      # 狂暴型（血量低时更猛）
	SUPPORT         # 支援型（治疗/Buff队友）
}

## ========== AI配置 ==========

@export var ai_type: AIType = AIType.AGGRESSIVE
@export var ai_name: String = "基础AI"

# 感知配置
@export var detection_range: float = 300.0      # 检测范围
@export var attack_range: float = 100.0         # 攻击范围  
@export var lose_target_distance: float = 500.0 # 失去目标距离
@export var patrol_radius: float = 150.0        # 巡逻半径

# 行为配置
@export var aggression_level: float = 1.0       # 攻击性 (0.0-2.0)
@export var intelligence_level: float = 1.0     # 智能程度 (0.0-2.0)
@export var reaction_time: float = 0.5          # 反应时间
@export var decision_interval: float = 1.0      # 决策间隔

# 移动配置
@export var movement_style: String = "direct"   # "direct", "zigzag", "circle"
@export var preferred_distance: float = 80.0    # 偏好距离

## ========== 状态管理 ==========

var current_state: AIState = AIState.IDLE
var previous_state: AIState = AIState.IDLE
var state_time: float = 0.0

## ========== 目标管理 ==========

var current_target: Node2D = null
var last_known_target_position: Vector2 = Vector2.ZERO
var target_lost_time: float = 0.0

## ========== 环境感知 ==========

var nearby_enemies: Array[Node] = []
var nearby_players: Array[Node] = []
var obstacles_in_path: Array[Node] = []

## ========== 引用 ==========

var owner_character: Node = null  # CharacterBase type will be available at runtime
var decision_timer: Timer
var perception_timer: Timer

## ========== 信号 ==========

signal ai_state_changed(old_state: AIState, new_state: AIState)
signal target_acquired(target: Node2D)
signal target_lost(target: Node2D)

## ========== 初始化 ==========

func _init(character: Node = null):
	owner_character = character

func _ready() -> void:
	setup_timers()
	setup_ai()

func setup_timers() -> void:
	"""设置AI计时器"""
	# 决策计时器
	decision_timer = Timer.new()
	decision_timer.wait_time = decision_interval
	decision_timer.timeout.connect(_on_decision_tick)
	decision_timer.autostart = true
	add_child(decision_timer)
	
	# 感知计时器（更频繁）
	perception_timer = Timer.new()
	perception_timer.wait_time = 0.2  # 每0.2秒感知一次
	perception_timer.timeout.connect(_on_perception_tick)
	perception_timer.autostart = true
	add_child(perception_timer)

func setup_ai() -> void:
	"""设置AI初始状态"""
	if not owner_character:
		return
	
	# 根据AI类型调整参数
	adjust_ai_parameters()
	
	# 连接角色信号
	owner_character.character_died.connect(_on_character_died)
	owner_character.damage_taken.connect(_on_damage_taken)

func adjust_ai_parameters() -> void:
	"""根据AI类型调整参数"""
	match ai_type:
		AIType.PASSIVE:
			aggression_level = 0.2
			detection_range *= 0.5
			
		AIType.AGGRESSIVE:
			aggression_level = 1.5
			attack_range *= 1.2
			
		AIType.DEFENSIVE:
			preferred_distance = attack_range * 0.8
			movement_style = "circle"
			
		AIType.BERSERKER:
			aggression_level = 2.0
			reaction_time *= 0.5
			
		AIType.SUPPORT:
			detection_range *= 1.5
			preferred_distance = detection_range * 0.6

## ========== 主要AI循环 ==========

func _on_decision_tick() -> void:
	"""AI决策循环"""
	if not owner_character or owner_character.is_dead:
		return
	
	# 更新状态时间
	state_time += decision_interval
	
	# 执行当前状态逻辑
	execute_current_state()
	
	# 检查状态转换
	check_state_transitions()

func execute_current_state() -> void:
	"""执行当前状态的行为"""
	match current_state:
		AIState.IDLE:
			execute_idle_behavior()
		AIState.PATROL:
			execute_patrol_behavior()
		AIState.CHASE:
			execute_chase_behavior()
		AIState.ATTACK:
			execute_attack_behavior()
		AIState.RETREAT:
			execute_retreat_behavior()
		AIState.SEARCH:
			execute_search_behavior()
		AIState.STUNNED:
			execute_stunned_behavior()

## ========== 状态行为实现 ==========

func execute_idle_behavior() -> void:
	"""空闲行为"""
	# 停止移动
	if owner_character:
		owner_character.stop_movement()
	
	# 寻找目标
	if should_start_patrol():
		change_state(AIState.PATROL)
	elif has_valid_target():
		change_state(AIState.CHASE)

func execute_patrol_behavior() -> void:
	"""巡逻行为"""
	# 简单的巡逻逻辑：在初始位置周围移动
	if not owner_character:
		return
	
	# 如果发现目标，开始追击
	if has_valid_target():
		change_state(AIState.CHASE)
		return
	
	# 巡逻移动逻辑（子类可重写）
	perform_patrol_movement()

func execute_chase_behavior() -> void:
	"""追击行为"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 如果在攻击范围内，开始攻击
	if distance_to_target <= attack_range:
		change_state(AIState.ATTACK)
		return
	
	# 如果目标太远，失去目标
	if distance_to_target > lose_target_distance:
		lose_target()
		return
	
	# 追击移动
	perform_chase_movement()

func execute_attack_behavior() -> void:
	"""攻击行为"""
	if not has_valid_target():
		change_state(AIState.SEARCH)
		return
	
	var distance_to_target = owner_character.get_distance_to(current_target)
	
	# 如果目标离开攻击范围，继续追击
	if distance_to_target > attack_range:
		change_state(AIState.CHASE)
		return
	
	# 执行攻击
	perform_attack()

func execute_retreat_behavior() -> void:
	"""撤退行为"""
	# 远离目标
	if has_valid_target():
		var direction = owner_character.get_direction_to(current_target) * -1
		var retreat_pos = owner_character.global_position + direction * 100
		owner_character.move_towards(retreat_pos)
	
	# 检查是否可以停止撤退
	if should_stop_retreating():
		change_state(AIState.IDLE)

func execute_search_behavior() -> void:
	"""搜索行为"""
	# 在最后已知位置附近搜索
	if last_known_target_position != Vector2.ZERO:
		perform_search_movement()
	
	# 搜索超时，返回空闲
	if state_time > 5.0:  # 搜索5秒后放弃
		change_state(AIState.IDLE)

func execute_stunned_behavior() -> void:
	"""眩晕行为"""
	# 停止所有行动
	if owner_character:
		owner_character.stop_movement()
	
	# 检查眩晕是否结束
	if not owner_character.is_stunned:
		change_state(previous_state)

## ========== 移动行为 ==========

func perform_patrol_movement() -> void:
	"""执行巡逻移动（子类可重写）"""
	# 基础巡逻：随机选择方向移动
	if randf() < 0.1:  # 10%概率改变方向
		var random_angle = randf_range(0, TAU)
		var patrol_target = owner_character.global_position + Vector2.from_angle(random_angle) * 50
		owner_character.move_towards(patrol_target, 0.5)

func perform_chase_movement() -> void:
	"""执行追击移动"""
	if not current_target:
		return
	
	match movement_style:
		"direct":
			# 直接追击
			owner_character.move_towards(current_target.global_position)
		
		"zigzag":
			# 之字形追击
			var _base_direction = owner_character.get_direction_to(current_target)
			var zigzag_offset = Vector2(sin(state_time * 3) * 50, 0)
			var target_pos = current_target.global_position + zigzag_offset
			owner_character.move_towards(target_pos)
		
		"circle":
			# 环绕移动
			perform_circle_movement()

func perform_circle_movement() -> void:
	"""执行环绕移动"""
	if not current_target:
		return
	
	var distance = owner_character.get_distance_to(current_target)
	var desired_distance = preferred_distance
	
	if distance > desired_distance + 20:
		# 太远，靠近
		owner_character.move_towards(current_target.global_position)
	elif distance < desired_distance - 20:
		# 太近，远离
		var direction = owner_character.get_direction_to(current_target) * -1
		var retreat_pos = owner_character.global_position + direction * 50
		owner_character.move_towards(retreat_pos)
	else:
		# 距离合适，环绕移动
		var angle = state_time * 2  # 环绕速度
		var offset = Vector2(cos(angle), sin(angle)) * desired_distance
		var circle_pos = current_target.global_position + offset
		owner_character.move_towards(circle_pos)

func perform_search_movement() -> void:
	"""执行搜索移动"""
	# 在最后已知位置周围搜索
	var search_angle = state_time * 1.5
	var search_radius = 80.0
	var search_offset = Vector2(cos(search_angle), sin(search_angle)) * search_radius
	var search_pos = last_known_target_position + search_offset
	owner_character.move_towards(search_pos, 0.7)

## ========== 攻击行为 ==========

func perform_attack() -> void:
	"""执行攻击"""
	if not owner_character or not current_target:
		return
	
	# 调用角色的攻击方法
	if owner_character.can_attack():
		owner_character.perform_attack(current_target.global_position, current_target)

## ========== 状态转换检查 ==========

func check_state_transitions() -> void:
	"""检查状态转换条件"""
	# 检查眩晕状态
	if owner_character.is_stunned and current_state != AIState.STUNNED:
		change_state(AIState.STUNNED)
		return
	
	# 检查生命值低是否需要撤退
	if should_retreat():
		change_state(AIState.RETREAT)
		return
	
	# 根据当前状态检查特定转换
	match current_state:
		AIState.IDLE:
			if has_valid_target():
				change_state(AIState.CHASE)
			elif should_start_patrol():
				change_state(AIState.PATROL)
		
		AIState.PATROL:
			if has_valid_target():
				change_state(AIState.CHASE)
		
		AIState.CHASE:
			if not has_valid_target():
				change_state(AIState.SEARCH)
			elif owner_character.get_distance_to(current_target) <= attack_range:
				change_state(AIState.ATTACK)
		
		AIState.ATTACK:
			if not has_valid_target():
				change_state(AIState.SEARCH)
			elif owner_character.get_distance_to(current_target) > attack_range:
				change_state(AIState.CHASE)

## ========== 条件检查方法 ==========

func should_start_patrol() -> bool:
	"""是否应该开始巡逻"""
	return ai_type != AIType.PASSIVE and randf() < 0.3

func should_retreat() -> bool:
	"""是否应该撤退"""
	if not owner_character:
		return false
	
	var health_ratio = owner_character.get_health_percentage()
	
	match ai_type:
		AIType.BERSERKER:
			return false  # 狂暴型永不撤退
		AIType.DEFENSIVE:
			return health_ratio < 0.4
		_:
			return health_ratio < 0.2

func should_stop_retreating() -> bool:
	"""是否应该停止撤退"""
	if not owner_character:
		return true
	
	var health_ratio = owner_character.get_health_percentage()
	return health_ratio > 0.5 or not has_valid_target()

func has_valid_target() -> bool:
	"""是否有有效目标"""
	return current_target != null and is_instance_valid(current_target) and not current_target.is_dead

## ========== 感知系统 ==========

func _on_perception_tick() -> void:
	"""感知更新"""
	update_perception()
	update_target()

func update_perception() -> void:
	"""更新环境感知"""
	if not owner_character:
		return
	
	# 清空感知数据
	nearby_players.clear()
	nearby_enemies.clear()
	
	# 检测范围内的角色
	var all_characters = get_tree().get_nodes_in_group("characters")
	for character in all_characters:
		if character == owner_character:
			continue
		
		var distance = owner_character.get_distance_to(character)
		if distance <= detection_range:
			if character.has_method("get") and character.character_type == 0:  # PLAYER type
				nearby_players.append(character)
			elif character.has_method("get") and character.character_type == 1:  # ENEMY type
				nearby_enemies.append(character)

func update_target() -> void:
	"""更新目标"""
	# 如果当前目标无效，寻找新目标
	if not has_valid_target():
		find_new_target()
	else:
		# 更新最后已知位置
		last_known_target_position = current_target.global_position

func find_new_target() -> void:
	"""寻找新目标"""
	if ai_type == AIType.PASSIVE:
		return
	
	# 优先攻击玩家
	if nearby_players.size() > 0:
		# 选择最近的玩家
		var closest_player = null
		var closest_distance = INF
		
		for player in nearby_players:
			var distance = owner_character.get_distance_to(player)
			if distance < closest_distance:
				closest_distance = distance
				closest_player = player
		
		if closest_player:
			acquire_target(closest_player)

func acquire_target(target: Node2D) -> void:
	"""获取目标"""
	current_target = target
	last_known_target_position = target.global_position
	target_lost_time = 0.0
	target_acquired.emit(target)
	print("🎯 ", owner_character.character_name, " 锁定目标: ", target.name)

func lose_target() -> void:
	"""失去目标"""
	if current_target:
		var lost_target = current_target
		current_target = null
		target_lost_time = 0.0
		target_lost.emit(lost_target)
		print("❌ ", owner_character.character_name, " 失去目标: ", lost_target.name)

## ========== 状态管理 ==========

func change_state(new_state: AIState) -> void:
	"""改变AI状态"""
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	state_time = 0.0
	
	print("🤖 ", owner_character.character_name if owner_character else "AI", " 状态: ", AIState.keys()[previous_state], " → ", AIState.keys()[new_state])
	ai_state_changed.emit(previous_state, new_state)

## ========== 事件回调 ==========

func _on_character_died(character: Node) -> void:
	"""角色死亡回调"""
	if character == owner_character:
		change_state(AIState.DEAD)

func _on_damage_taken(_amount: int, source: Node) -> void:
	"""受伤回调"""
	if source and source != current_target:
		# 如果被其他角色攻击，可能转换目标
		if randf() < (aggression_level * 0.5):
			var distance = owner_character.get_distance_to(source)
			if distance <= detection_range:
				acquire_target(source)

## ========== 工具方法 ==========

func get_state_name() -> String:
	"""获取当前状态名称"""
	return AIState.keys()[current_state]

func get_ai_type_name() -> String:
	"""获取AI类型名称"""
	return AIType.keys()[ai_type]

func is_state(state: AIState) -> bool:
	"""检查是否为指定状态"""
	return current_state == state

func get_target_distance() -> float:
	"""获取到目标的距离"""
	if has_valid_target():
		return owner_character.get_distance_to(current_target)
	return INF
