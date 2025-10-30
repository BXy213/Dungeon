extends "res://scripts/EnemyCharacter.gd"
class_name SplitterEnemy

# 🔀 分裂体 - 死亡时分裂成小型敌人（参考DOTA育母蜘蛛/LOL玛尔扎哈虫子）

## ========== 分裂体特有属性 ==========

@export var split_count: int = 3  # 分裂数量
@export var is_mini_split: bool = false  # 是否为分裂出来的小型体
var mini_split_multiplier: float = 0.5  # 小型体属性倍率

func _init():
	super._init()
	
	# 设置分裂体属性
	if is_mini_split:
		# 小型分裂体
		character_name = "小分裂体"
		max_health = 30
		base_speed = 110.0
		base_attack_damage = 8
		attack_range = 120.0
		attack_cooldown = 1.2
		experience_reward = 10
	else:
		# 普通分裂体
		character_name = "分裂体"
		max_health = 100
		base_speed = 85.0
		base_attack_damage = 18
		attack_range = 150.0
		attack_cooldown = 2.0
		experience_reward = 45
	
	# ✅ 修复：初始血量应等于最大血量（统一设置）
	health = max_health
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage

func _ready():
	super._ready()
	
	var type_name = "小分裂体" if is_mini_split else "分裂体"
	print("🔀 ", type_name, " _ready() 被调用，位置: ", global_position)
	
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
	
	print("🔀 ", type_name, " _ready() 完成")

func setup_enemy_nodes() -> void:
	"""创建分裂体节点"""
	print("🔨 分裂体正在创建节点...")
	
	# 创建Sprite2D节点
	var splitter_sprite = Sprite2D.new()
	splitter_sprite.name = "Sprite2D"
	splitter_sprite.texture = preload("res://art/icon.webp")
	
	if is_mini_split:
		splitter_sprite.modulate = Color(0.6, 0.3, 0.6)  # 浅紫色
		splitter_sprite.scale = Vector2(0.25, 0.25)  # 小型
	else:
		splitter_sprite.modulate = Color(0.8, 0.2, 0.8)  # 紫色
		splitter_sprite.scale = Vector2(0.4, 0.4)
	
	add_child(splitter_sprite)
	print("  ✓ Sprite2D已创建")
	
	# 创建CollisionShape2D节点
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	
	if is_mini_split:
		shape.size = Vector2(10, 10)
	else:
		shape.size = Vector2(16, 16)
	
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# 创建血条
	create_health_bar()
	print("  ✓ 血条已创建")
	
	print("🔀 分裂体节点创建完成")

func setup_visuals() -> void:
	"""设置分裂体视觉效果"""
	# ✅ 修复：确保贴图颜色正确设置（即使Sprite2D预先存在）
	var splitter_sprite = get_node_or_null("Sprite2D")
	if splitter_sprite:
		if is_mini_split:
			splitter_sprite.modulate = Color(0.6, 0.3, 0.6)  # 浅紫色
			print("  ✓ 小分裂体贴图颜色已设置为浅紫色")
		else:
			splitter_sprite.modulate = Color(0.8, 0.2, 0.8)  # 紫色
			print("  ✓ 分裂体贴图颜色已设置为紫色")

## ========== 分裂体AI行为 ==========

var current_target: Node = null
var detection_range: float = 400.0
var lose_target_distance: float = 600.0

func _find_target():
	"""寻找玩家目标"""
	if is_dead:
		return
	
	var player = get_tree().get_first_node_in_group("players")
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= detection_range:
			current_target = player
		elif distance > lose_target_distance:
			current_target = null

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if is_dead or not current_target:
		return
	
	var distance_to_target = get_distance_to(current_target)
	
	if distance_to_target <= attack_range:
		# 在攻击范围内
		execute_attack_behavior()
	else:
		# 追击
		execute_chase_behavior()

## ========== 分裂逻辑 ==========

func die() -> void:
	"""死亡时分裂（除非是小型体）"""
	if is_dead:
		return
	
	is_dead = true
	
	# 只有普通分裂体会分裂，小型体不会
	if not is_mini_split:
		print("🔀 分裂体死亡，正在分裂成 ", split_count, " 个小型体!")
		_spawn_mini_splits()
	
	# 调用父类die()处理其他逻辑（经验、信号等）
	super.die()

func _spawn_mini_splits() -> void:
	"""生成小型分裂体"""
	# 获取当前房间
	var current_room = get_parent().get_parent() if get_parent() and get_parent().get_parent() else null
	if not current_room:
		print("⚠️ 无法找到当前房间，分裂失败")
		return
	
	# 在周围生成小型分裂体
	for i in range(split_count):
		var mini_split = _create_mini_split()
		if mini_split:
			# 计算生成位置（围绕死亡位置）
			var angle = (TAU / split_count) * i
			var offset = Vector2(cos(angle), sin(angle)) * 40.0
			mini_split.global_position = global_position + offset
			mini_split.room_id = room_id
			
			# 添加到房间的敌人容器
			var enemies_container = current_room.get_node_or_null("Enemies")
			if enemies_container:
				enemies_container.add_child(mini_split)
				print("  🔀 生成小型分裂体 #", i+1, " 位置: ", mini_split.global_position)
				
				# 更新房间的敌人计数
				if current_room.has_signal("enemy_count_changed"):
					current_room.alive_enemy_count += 1
					current_room.enemy_count_changed.emit(current_room.room_id, current_room.alive_enemy_count)
			else:
				print("⚠️ 无法找到敌人容器")
				mini_split.queue_free()

func _create_mini_split() -> SplitterEnemy:
	"""创建小型分裂体实例"""
	var mini = SplitterEnemy.new()
	mini.is_mini_split = true
	mini.is_room_enemy = true
	return mini

## ========== 攻击和追击行为 ==========

func execute_attack_behavior() -> void:
	"""执行攻击行为"""
	if current_target and can_attack():
		perform_attack(current_target.global_position, current_target)

func execute_chase_behavior() -> void:
	"""执行追击行为"""
	if current_target:
		var direction = (current_target.global_position - global_position).normalized()
		velocity = direction * current_speed
		move_and_slide()

