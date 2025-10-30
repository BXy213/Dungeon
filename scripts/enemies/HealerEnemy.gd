extends "res://scripts/EnemyCharacter.gd"
class_name HealerEnemy

# 💚 治疗者 - 给其他敌人治疗（参考LOL索拉卡/DOTA巫医）

## ========== 治疗者特有属性 ==========

var heal_range: float = 300.0  # 治疗范围
var heal_amount: int = 30  # 治疗量
var heal_cooldown: float = 5.0  # 治疗冷却
var heal_timer: Timer = null
var can_heal: bool = true

func _init():
	super._init()
	
	# 设置治疗者属性
	character_name = "治疗者"
	max_health = 80  # 血量较低
	health = max_health  # ✅ 修复：初始血量应等于最大血量
	base_speed = 70.0  # 移速较慢
	base_attack_damage = 5  # 攻击力很低
	attack_range = 350.0
	attack_cooldown = 3.0
	experience_reward = 50  # 击杀奖励高
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage

func _ready():
	super._ready()
	
	print("💚 治疗者 _ready() 被调用，位置: ", global_position)
	
	# 确保节点已创建
	var existing_sprite = get_node_or_null("Sprite2D")
	if existing_sprite == null:
		setup_enemy_nodes()
	
	# 设置治疗计时器
	heal_timer = Timer.new()
	heal_timer.wait_time = heal_cooldown
	heal_timer.one_shot = true
	heal_timer.timeout.connect(_on_heal_cooldown_finished)
	add_child(heal_timer)
	
	# 定期查找目标和治疗对象
	var ai_timer = Timer.new()
	ai_timer.wait_time = 0.5
	ai_timer.timeout.connect(_ai_update)
	ai_timer.autostart = true
	add_child(ai_timer)
	
	print("💚 治疗者 _ready() 完成")

func setup_enemy_nodes() -> void:
	"""创建治疗者节点"""
	print("🔨 治疗者正在创建节点...")
	
	# 创建Sprite2D节点
	var healer_sprite = Sprite2D.new()
	healer_sprite.name = "Sprite2D"
	healer_sprite.texture = preload("res://art/icon.webp")
	healer_sprite.modulate = Color(0.0, 1.0, 0.5)  # 青绿色
	healer_sprite.scale = Vector2(0.35, 0.35)  # 稍小
	add_child(healer_sprite)
	print("  ✓ Sprite2D已创建")
	
	# 创建CollisionShape2D节点
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# 创建血条
	create_health_bar()
	print("  ✓ 血条已创建")
	
	print("💚 治疗者节点创建完成")

func setup_visuals() -> void:
	"""设置治疗者视觉效果"""
	# ✅ 修复：确保贴图颜色正确设置（即使Sprite2D预先存在）
	var healer_sprite = get_node_or_null("Sprite2D")
	if healer_sprite:
		healer_sprite.modulate = Color(0.0, 1.0, 0.5)  # 青绿色
		print("  ✓ 治疗者贴图颜色已设置为青绿色")

## ========== 治疗者AI行为 ==========

var current_target: Node = null  # 追击目标（玩家）
var detection_range: float = 350.0
var flee_range: float = 200.0  # 逃跑距离

func _ai_update():
	"""AI更新逻辑"""
	if is_dead:
		return
	
	var player = get_tree().get_first_node_in_group("players")
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# 检查是否需要治疗队友
	if can_heal:
		_try_heal_allies()
	
	# 如果玩家太近，向后逃跑
	if distance_to_player < flee_range:
		_flee_from_player(player)
	# 如果在检测范围内但不太近，保持距离
	elif distance_to_player < detection_range:
		current_target = player
		_maintain_distance(player)
	else:
		current_target = null

func _try_heal_allies() -> void:
	"""尝试治疗队友"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var injured_allies = []
	
	# 查找受伤的队友
	for enemy in enemies:
		if enemy == self or enemy.is_dead:
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= heal_range and enemy.health < enemy.max_health:
			injured_allies.append(enemy)
	
	# 治疗血量最低的队友
	if not injured_allies.is_empty():
		injured_allies.sort_custom(func(a, b): return a.health < b.health)
		var target = injured_allies[0]
		_heal_ally(target)

func _heal_ally(ally: Node) -> void:
	"""治疗队友"""
	if not can_heal:
		return
	
	if ally.has_method("heal"):
		ally.heal(heal_amount)
		print("💚 治疗者治疗了 ", ally.name, ", 恢复 ", heal_amount, " 点生命值")
		
		# 创建治疗特效
		_create_heal_effect(ally.global_position)
		
		# 开始冷却
		can_heal = false
		heal_timer.start()

func _create_heal_effect(target_pos: Vector2) -> void:
	"""创建治疗特效"""
	var SkillEffectScene = preload("res://Scenes/SkillEffect.tscn")
	var heal_effect = SkillEffectScene.instantiate()
	heal_effect.global_position = target_pos
	heal_effect.skill_type = "heal"
	heal_effect.life_time = 1.0
	heal_effect.modulate = Color(0.0, 1.0, 0.5, 0.8)
	get_tree().current_scene.add_child(heal_effect)
	heal_effect.initialize()

func _on_heal_cooldown_finished() -> void:
	"""治疗冷却完成"""
	can_heal = true

func _flee_from_player(player: Node) -> void:
	"""从玩家处逃跑"""
	var flee_direction = (global_position - player.global_position).normalized()
	velocity = flee_direction * current_speed
	move_and_slide()

func _maintain_distance(player: Node) -> void:
	"""保持与玩家的距离"""
	var distance = global_position.distance_to(player.global_position)
	var desired_distance = (flee_range + detection_range) / 2.0
	
	if distance < desired_distance:
		# 太近，后退
		var flee_direction = (global_position - player.global_position).normalized()
		velocity = flee_direction * current_speed * 0.5
		move_and_slide()
	elif distance > desired_distance + 50:
		# 太远，靠近
		var chase_direction = (player.global_position - global_position).normalized()
		velocity = chase_direction * current_speed * 0.5
		move_and_slide()
	else:
		# 距离合适，停止
		velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# AI逻辑在_ai_update中处理

## ========== 攻击行为 ==========

func execute_attack_behavior() -> void:
	"""执行攻击行为（治疗者攻击力很低）"""
	if current_target and can_attack():
		perform_attack(current_target.global_position, current_target)

func execute_chase_behavior() -> void:
	"""执行追击行为（由_ai_update处理）"""
	pass

