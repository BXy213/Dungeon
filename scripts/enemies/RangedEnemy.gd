extends "res://scripts/EnemyCharacter.gd"
class_name RangedEnemy

const RANGED_TEXTURE = preload("res://art/enemies/enemy_ranged.png")

# 🏹 远程小兵 - 保持距离射击并游走

## ========== 远程小兵特有属性 ==========

# 距离管理属性
var preferred_distance: float = 250.0  # 偏好的攻击距离
var min_distance: float =100.0  # 最小保持距离
var max_distance: float = 350.0  # 最大攻击距离

# 游走移动属性
var strafe_timer: float = 0.0
var strafe_direction: Vector2 = Vector2.ZERO

# AI行为属性
var current_target: Node = null
var detection_range: float = 500.0
var lose_target_distance: float = 600.0

## ========== 初始化方法 ==========

func _init():
	super._init()
	
	# 设置远程小兵属性
	character_name = "远程小兵"
	max_health = 80
	health = max_health
	base_speed = 30.0
	base_attack_damage = 10
	attack_range = 500.0
	attack_cooldown = 1.5
	experience_reward = 35
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage

func _ready():
	super._ready()
	
	print("🏹 远程小兵 _ready() 被调用，位置: ", global_position)
	
	# 确保节点已创建
	var existing_sprite = get_node_or_null("Sprite2D")
	if existing_sprite == null:
		setup_enemy_nodes()
	
	# 定期查找目标
	var target_timer = Timer.new()
	target_timer.wait_time = 0.5
	target_timer.timeout.connect(_find_target)
	target_timer.autostart = true
	add_child(target_timer)
	
	# 初始化游走方向
	strafe_timer = randf_range(1.0, 3.0)
	strafe_direction = Vector2.from_angle(randf() * TAU).normalized()
	
	print("🏹 远程小兵 _ready() 完成")

## ========== 节点设置方法 ==========

func setup_enemy_nodes() -> void:
	"""创建敌人必要的子节点"""
	print("🔨 远程小兵正在创建节点...")
	
	# 创建Sprite2D节点
	var ranged_sprite = Sprite2D.new()
	ranged_sprite.name = "Sprite2D"
	ranged_sprite.texture = RANGED_TEXTURE
	ranged_sprite.modulate = Color.WHITE
	ranged_sprite.scale = Vector2.ONE
	add_child(ranged_sprite)
	sprite = ranged_sprite
	print("  ✓ Sprite2D已创建")
	
	# 创建CollisionShape2D节点
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(14.4, 14.4)  # 0.36 * 40
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# 创建血条
	create_health_bar()
	print("  ✓ 血条已创建")
	
	print("🏹 远程小兵节点创建完成")

func setup_visuals() -> void:
	"""设置远程小兵视觉效果"""
	var ranged_sprite = get_node_or_null("Sprite2D")
	if ranged_sprite:
		ranged_sprite.texture = RANGED_TEXTURE
		ranged_sprite.modulate = Color.WHITE
		ranged_sprite.scale = Vector2.ONE
		sprite = ranged_sprite
		print("  ✓ 远程小兵贴图已设置")

func setup_collision_size() -> void:
	"""设置碰撞盒大小"""
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return
	
	var base_size = Vector2(40, 40)
	var scale_factor = Vector2(0.36, 0.36)
	
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

func _process(delta: float) -> void:
	if not can_process_enemy_ai():
		return

	# 更新游走计时器
	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_timer = randf_range(1.0, 3.0)
		strafe_direction = Vector2.from_angle(randf() * TAU).normalized()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not can_process_enemy_ai() or not current_target:
		velocity = Vector2.ZERO
		return

	velocity = Vector2.ZERO
	var distance_to_target = get_distance_to(current_target)

	# 距离管理和攻击逻辑
	if distance_to_target <= max_distance and distance_to_target >= min_distance:
		# 在理想距离内 - 攻击并游走
		if can_attack():
			perform_attack(current_target.global_position, current_target)
			print("🏹 远程小兵发起攻击!")
		perform_strafe_movement()
	elif distance_to_target < min_distance:
		# 太近 - 后退
		perform_retreat_movement()
	elif distance_to_target > max_distance:
		# 太远 - 接近
		perform_approach_movement()

	# 应用移动
	move_and_slide()

## ========== 移动方法 ==========

func perform_approach_movement() -> void:
	"""接近目标到合适距离"""
	if not current_target:
		return
	
	var direction = (current_target.global_position - global_position).normalized()
	var target_pos = current_target.global_position - direction * preferred_distance
	move_towards(target_pos, 0.8)

func perform_retreat_movement() -> void:
	"""从目标后退到安全距离"""
	if not current_target:
		return
	
	var direction = (global_position - current_target.global_position).normalized()
	move_towards(global_position + direction * 50, 1.0)

func perform_strafe_movement() -> void:
	"""侧移游走"""
	if not current_target:
		return
	
	var target_direction = (current_target.global_position - global_position).normalized()
	var perpendicular_direction = Vector2(-target_direction.y, target_direction.x)
	
	var movement_vector = perpendicular_direction * strafe_direction.x + target_direction * strafe_direction.y
	move_towards(global_position + movement_vector * 50, 0.7)

## ========== 攻击方法 ==========

func set_projectile_appearance(projectile: Node) -> void:
	"""设置远程小兵弹道外观"""
	var sprite_node = projectile.get_node_or_null("Sprite2D")
	if sprite_node:
		sprite_node.modulate = Color.RED  # 红色弹道
		sprite_node.scale = Vector2(0.25, 0.25)  # 更小的弹道
		print("  🎨 远程小兵弹道外观: 红色, 大小 0.25")
	
	# 设置更快的弹道速度
	projectile.speed = 350

## ========== 辅助方法 ==========

func should_retreat() -> bool:
	"""远程小兵在被近身时撤退"""
	if not current_target:
		return false
	
	var distance_to_target = get_distance_to(current_target)
	return distance_to_target < min_distance * 0.8

func get_ai_description() -> String:
	"""获取AI描述"""
	return "远程小兵AI - 保持距离射击，侧移游走"

## ========== 静态工厂方法 ==========

static func create_ranged_enemy(enemy_room_id: Vector2i) -> RangedEnemy:
	"""创建远程小兵实例"""
	var ranged_enemy = RangedEnemy.new()
	ranged_enemy.room_id = enemy_room_id
	return ranged_enemy
