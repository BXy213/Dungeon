extends "res://scripts/EnemyCharacter.gd"
class_name MeleeEnemy

# 🗡️ 近战小兵 - 冲锋射击

## ========== 近战小兵特有属性 ==========

# AI行为属性
var current_target: Node = null
var detection_range: float = 400.0
var lose_target_distance: float = 400.0

## ========== 初始化方法 ==========

func _init():
	super._init()
	
	# 设置近战小兵属性
	character_name = "近战小兵"
	max_health = 100
	health = max_health
	base_speed = 55.0
	base_attack_damage = 12
	attack_range = 150.0
	attack_cooldown = 1.8
	experience_reward = 30
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage

func _ready():
	super._ready()
	
	print("🗡️ 近战小兵 _ready() 被调用，位置: ", global_position)
	
	# 确保节点已创建，如果没有则立即创建
	var existing_sprite = get_node_or_null("Sprite2D")
	if existing_sprite == null:
		setup_enemy_nodes()
	
	# 定期查找目标
	var target_timer = Timer.new()
	target_timer.wait_time = 0.5
	target_timer.timeout.connect(_find_target)
	target_timer.autostart = true
	add_child(target_timer)
	
	print("🗡️ 近战小兵 _ready() 完成")

## ========== 节点设置方法 ==========

func setup_enemy_nodes() -> void:
	"""创建敌人必要的子节点"""
	print("🔨 近战小兵正在创建节点...")
	
	# 创建Sprite2D节点
	var melee_sprite = Sprite2D.new()
	melee_sprite.name = "Sprite2D"
	melee_sprite.texture = preload("res://art/icon.webp")
	melee_sprite.modulate = Color.RED  # 红色
	melee_sprite.scale = Vector2(0.4, 0.4)
	add_child(melee_sprite)
	print("  ✓ Sprite2D已创建")
	
	# 创建CollisionShape2D节点
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 16)  # 0.4 * 40
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# 创建血条
	create_health_bar()
	print("  ✓ 血条已创建")
	
	print("🗡️ 近战小兵节点创建完成")

func setup_visuals() -> void:
	"""设置近战小兵视觉效果"""
	var melee_sprite = get_node_or_null("Sprite2D")
	if melee_sprite:
		melee_sprite.modulate = Color.RED  # 红色
		print("  ✓ 近战小兵贴图颜色已设置为红色")

func setup_collision_size() -> void:
	"""设置碰撞盒大小"""
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return
	
	var base_size = Vector2(40, 40)
	var scale_factor = Vector2(0.4, 0.4)
	
	if collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		circle_shape.radius = (base_size.x / 2.0) * scale_factor.x
	elif collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		rect_shape.size = base_size * scale_factor

## ========== AI行为方法 ==========

func _find_target():
	"""寻找玩家目标"""
	var player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if player and not is_dead:
		var distance = global_position.distance_to(player.global_position)
		if distance <= detection_range:
			current_target = player
		elif distance > lose_target_distance:
			current_target = null

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_dead and current_target:
		var distance_to_target = get_distance_to(current_target)
		
		if distance_to_target <= attack_range:
			# 在攻击范围内 - 攻击
			if can_attack():
				perform_attack(current_target.global_position, current_target)
				print("🗡️ 近战小兵发起攻击!")
				
				# 攻击后稍微后退
				var retreat_direction = (global_position - current_target.global_position).normalized()
				move_towards(global_position + retreat_direction * 20, 0.5)
				move_and_slide()
		else:
			# 不在攻击范围内 - 使用智能寻路追击
			navigate_to_target(current_target.global_position)
			move_and_slide()

## ========== 攻击方法 ==========

func set_projectile_appearance(projectile: Node) -> void:
	"""设置近战小兵弹道外观"""
	var sprite_node = projectile.get_node_or_null("Sprite2D")
	if sprite_node:
		sprite_node.modulate = Color.RED  # 红色弹道（与近战小兵颜色一致）
		sprite_node.scale = Vector2(0.3, 0.3)  # 中等大小
		print("  🎨 近战小兵弹道外观: 红色, 大小 0.3")
	
	# 设置弹道速度
	projectile.speed = 330

## ========== 辅助方法 ==========

func should_retreat() -> bool:
	"""近战小兵在低血量时撤退"""
	var health_ratio = get_health_percentage()
	return health_ratio < 0.2  # 20%血量以下撤退

func get_ai_description() -> String:
	"""获取AI描述"""
	return "近战小兵AI - 冲锋射击，低血量时撤退"

## ========== 静态工厂方法 ==========

static func create_melee_enemy(enemy_room_id: Vector2i) -> MeleeEnemy:
	"""创建近战小兵实例"""
	var melee_enemy = MeleeEnemy.new()
	melee_enemy.room_id = enemy_room_id
	return melee_enemy
