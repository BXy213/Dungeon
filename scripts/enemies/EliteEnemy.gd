extends "res://scripts/EnemyCharacter.gd"
class_name EliteEnemy

# 🛡️ 精英战士 - 预测性攻击，毒技能

## ========== 精英战士特有属性 ==========

# 毒攻击属性
var poison_attack_chance: float = 0.3  # 毒攻击概率
var poison_attack_range: float = 40.0  # 毒攻击触发距离
var poison_cooldown: float = 8.0  # 毒攻击冷却时间
var last_poison_time: float = 0.0  # 上次毒攻击时间

# AI行为属性
var current_target: Node = null
var detection_range: float = 500.0
var lose_target_distance: float = 500.0

## ========== 初始化方法 ==========

func _init():
	super._init()
	
	# 设置精英战士属性
	character_name = "精英战士"
	max_health = 200
	health = max_health
	base_speed = 85.0
	base_attack_damage = 20
	attack_range = 150.0
	attack_cooldown = 2.0
	experience_reward = 80
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage
	
	# 初始化毒攻击时间
	last_poison_time = get_time_seconds() - poison_cooldown

func _ready():
	super._ready()
	
	print("🛡️ 精英战士 _ready() 被调用，位置: ", global_position)
	
	# 确保节点已创建
	if get_node_or_null("Sprite2D") == null:
		setup_enemy_nodes()
	
	# 定期查找目标
	var target_timer = Timer.new()
	target_timer.wait_time = 0.5
	target_timer.timeout.connect(_find_target)
	target_timer.autostart = true
	add_child(target_timer)
	
	print("🛡️ 精英战士 _ready() 完成")

## ========== 节点设置方法 ==========

func setup_enemy_nodes() -> void:
	"""创建敌人必要的子节点"""
	print("🔨 精英战士正在创建节点...")
	
	# 创建Sprite2D节点
	var elite_sprite = Sprite2D.new()
	elite_sprite.name = "Sprite2D"
	elite_sprite.texture = preload("res://art/icon.webp")
	elite_sprite.modulate = Color.ORANGE  # 橙色
	elite_sprite.scale = Vector2(0.52, 0.52)
	add_child(elite_sprite)
	print("  ✓ Sprite2D已创建")
	
	# 创建CollisionShape2D节点
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20.8, 20.8)  # 0.52 * 40
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# 创建血条
	create_health_bar()
	print("  ✓ 血条已创建")
	
	print("🛡️ 精英战士节点创建完成")

func setup_visuals() -> void:
	"""设置精英战士视觉效果"""
	var elite_sprite = get_node_or_null("Sprite2D")
	if elite_sprite:
		elite_sprite.modulate = Color.ORANGE  # 橙色
		print("  ✓ 精英战士贴图颜色已设置为橙色")

func setup_collision_size() -> void:
	"""设置碰撞盒大小"""
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return
	
	var base_size = Vector2(40, 40)
	var scale_factor = Vector2(0.52, 0.52)
	
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
		
		if distance_to_target <= attack_range * 1.3:
			# 在攻击范围内 - 攻击
			if can_attack():
				perform_elite_attack()
			
			# 检查毒攻击
			if can_use_poison_attack() and distance_to_target <= poison_attack_range:
				perform_poison_attack()
		else:
			# 不在攻击范围内 - 预测性追击
			perform_predictive_chase()

## ========== 移动方法 ==========

func perform_predictive_chase() -> void:
	"""预测目标位置进行追击"""
	if not current_target:
		return
	
	# 预测目标位置
	var target_velocity = Vector2.ZERO
	if current_target.has_method("get_velocity"):
		target_velocity = current_target.velocity
	
	# 预测目标0.3秒后的位置
	var predicted_position = current_target.global_position + target_velocity * 0.3
	
	# 使用智能寻路追击预测位置（带速度加成）
	navigate_to_target(predicted_position)
	velocity = velocity * 1.1  # 应用速度加成
	move_and_slide()

## ========== 攻击方法 ==========

func perform_elite_attack() -> void:
	"""精英战士普通攻击"""
	if not current_target:
		return
	
	perform_attack(current_target.global_position, current_target)
	print("🛡️ 精英战士发起攻击!")
	
	# 攻击后短暂前冲，更加aggressive
	var charge_direction = (current_target.global_position - global_position).normalized()
	move_towards(global_position + charge_direction * 15, 0.8)

func set_projectile_appearance(projectile: Node) -> void:
	"""设置精英战士弹道外观"""
	var sprite_node = projectile.get_node_or_null("Sprite2D")
	if sprite_node:
		sprite_node.modulate = Color.ORANGE  # 橙色弹道
		sprite_node.scale = Vector2(0.35, 0.35)
		print("  🎨 精英战士弹道外观: 橙色, 大小 0.35")
	
	# 设置弹道速度
	projectile.speed = 320

## ========== 特殊能力方法 ==========

func can_use_poison_attack() -> bool:
	"""检查是否可以使用毒攻击"""
	var current_time = get_time_seconds()
	var time_since_last_poison = current_time - last_poison_time
	
	# 冷却时间检查 + 概率检查
	return time_since_last_poison >= poison_cooldown and randf() < poison_attack_chance

func get_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func perform_poison_attack() -> void:
	"""执行毒攻击"""
	if not current_target:
		return
	
	print("💚 精英战士释放毒攻击!")
	
	# 更新最后使用毒攻击的时间
	last_poison_time = get_time_seconds()
	
	# 创建毒攻击效果
	create_poison_attack_effect()
	
	# 对目标造成毒伤害并应用毒buff
	if current_target.has_method("take_damage"):
		var poison_damage = int(current_attack_damage * 0.8)
		current_target.take_damage(poison_damage)
		
		# 应用毒buff
		if "buff_system" in current_target and current_target.buff_system:
			current_target.buff_system.apply_buff(BuffSystem.BuffType.POISON, 2.0, 8.0, self)

func create_poison_attack_effect() -> void:
	"""创建毒攻击视觉效果"""
	var effect_scene = load(Constants.SCENE_SKILL_EFFECT) as PackedScene
	if not effect_scene:
		return
	
	var poison_effect = effect_scene.instantiate()
	poison_effect.global_position = global_position
	poison_effect.skill_type = "poison"
	poison_effect.life_time = 1.0
	
	# 设置毒效果外观
	var effect_sprite = poison_effect.get_node_or_null("Sprite2D")
	if effect_sprite:
		effect_sprite.modulate = Color.GREEN
		effect_sprite.scale = Vector2(1.5, 1.5)
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null(Constants.NODE_SKILL_EFFECTS)
	if skill_effects:
		skill_effects.add_child(poison_effect)
	else:
		get_tree().current_scene.add_child(poison_effect)
	
	# 初始化效果
	poison_effect.initialize()

## ========== 辅助方法 ==========

func should_retreat() -> bool:
	"""精英战士很少撤退"""
	return false

func get_ai_description() -> String:
	"""获取AI描述"""
	return "精英战士AI - 预测性追击，毒攻击技能，不撤退"

## ========== 静态工厂方法 ==========

static func create_elite_enemy(enemy_room_id: Vector2i) -> EliteEnemy:
	"""创建精英战士实例"""
	var elite_enemy = EliteEnemy.new()
	elite_enemy.room_id = enemy_room_id
	return elite_enemy
