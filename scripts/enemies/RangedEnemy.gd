extends "res://scripts/EnemyCharacter.gd"
class_name RangedEnemy

# 🏹 远程小兵 - 保持距离射击并游走

## ========== 远程小兵特有属性 ==========

var preferred_distance: float = 120.0  # 偏好的攻击距离
var min_distance: float = 80.0  # 最小保持距离
var max_distance: float = 180.0  # 最大攻击距离
var strafe_timer: float = 0.0
var strafe_direction: Vector2 = Vector2.ZERO

# AI行为属性
var current_target: Node = null
var detection_range: float = 300.0
var lose_target_distance: float = 400.0

func _init():
	super._init()
	
	# 设置远程小兵属性
	character_name = "远程小兵"
	max_health = 60
	health = 60
	base_speed = 70.0
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
	
	# 确保节点已创建，如果没有则立即创建
	var existing_sprite = get_node_or_null("Sprite2D")
	print("  检查Sprite2D: ", "已存在" if existing_sprite else "不存在，需要创建")
	
	if existing_sprite == null:
		setup_enemy_nodes()
	
	# 定期查找目标
	var target_timer = Timer.new()
	target_timer.wait_time = 0.5
	target_timer.timeout.connect(_find_target)
	target_timer.autostart = true
	add_child(target_timer)
	
	strafe_timer = randf_range(1.0, 3.0)
	strafe_direction = Vector2.from_angle(randf() * TAU).normalized()
	
	print("🏹 远程小兵 _ready() 完成")

func setup_enemy_nodes() -> void:
	"""创建敌人必要的子节点"""
	print("🔨 远程小兵正在创建节点...")
	
	# 创建Sprite2D节点
	var ranged_sprite = Sprite2D.new()
	ranged_sprite.name = "Sprite2D"
	ranged_sprite.texture = preload("res://art/icon.webp")
	ranged_sprite.modulate = Color.BLUE  # 蓝色
	ranged_sprite.scale = Vector2(0.36, 0.36)
	add_child(ranged_sprite)
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
	# 节点在setup_enemy_nodes中创建，这里可以进行额外的视觉调整
	pass

func setup_collision_size() -> void:
	"""设置碰撞盒大小"""
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return
	
	var base_size = Vector2(40, 40)
	var scale_factor = Vector2(0.36, 0.36)  # 稍小
	
	if collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		circle_shape.radius = (base_size.x / 2.0) * scale_factor.x
	elif collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		rect_shape.size = base_size * scale_factor

## ========== 远程小兵AI行为 ==========

func _find_target():
	"""寻找玩家目标"""
	var player = get_tree().get_first_node_in_group("players")
	if player and not is_dead:
		var distance = global_position.distance_to(player.global_position)
		if distance <= detection_range:
			current_target = player
		elif distance > lose_target_distance:
			current_target = null

func _process(delta: float) -> void:
	# 更新游走计时器
	strafe_timer -= delta
	if strafe_timer <= 0:
		strafe_timer = randf_range(1.0, 3.0)
		strafe_direction = Vector2.from_angle(randf() * TAU).normalized()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_dead and current_target:
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

## ========== 远程小兵移动行为 ==========

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

## ========== 远程小兵特殊能力 ==========

func should_retreat() -> bool:
	"""远程小兵在被近身时撤退"""
	if not current_target:
		return false
	
	var distance_to_target = get_distance_to(current_target)
	return distance_to_target < min_distance * 0.8

func get_ai_description() -> String:
	"""获取AI描述"""
	return "远程小兵AI - 保持距离射击，侧移游走"

func set_projectile_appearance(projectile: Node) -> void:
	"""设置远程小兵弹道外观"""
	var sprite_node = projectile.get_node_or_null("Sprite2D")
	if sprite_node:
		sprite_node.modulate = Color.CYAN  # 青色弹道
		sprite_node.scale = Vector2(0.25, 0.25)  # 更小的弹道
	
	# 设置更快的弹道速度
	if projectile.has_method("set"):
		projectile.speed = 450  # 比普通弹道更快

## ========== 静态工厂方法 ==========

static func create_ranged_enemy(enemy_room_id: Vector2i) -> RangedEnemy:
	"""创建远程小兵实例"""
	var ranged_enemy = RangedEnemy.new()
	ranged_enemy.room_id = enemy_room_id
	return ranged_enemy