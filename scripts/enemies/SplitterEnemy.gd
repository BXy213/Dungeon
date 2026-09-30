extends "res://scripts/EnemyCharacter.gd"
class_name SplitterEnemy

const SPLITTER_TEXTURE = preload("res://art/enemies/enemy_splitter.png")
const MINI_SPLITTER_TEXTURE = preload("res://art/enemies/enemy_mini_splitter.png")

# 🔀 分裂体 - 死亡时分裂成小型敌人（参考DOTA育母蜘蛛/LOL玛尔扎哈虫子）

## ========== 分裂体特有属性 ==========

# 分裂相关
@export var split_count: int = 3  # 分裂数量
@export var is_mini_split: bool = false  # 是否为分裂出来的小型体
var mini_split_multiplier: float = 0.5  # 小型体属性倍率

# AI相关
var current_target: Node = null
var detection_range: float = 400.0
var lose_target_distance: float = 600.0

## ========== 静态创建方法 ==========

func _init():
	super._init()
	
	# 设置分裂体属性
	if is_mini_split:
		# 小型分裂体
		character_name = "小分裂体"
		max_health = 30
		base_speed = 100.0
		base_attack_damage = 8
		attack_range = 120.0
		attack_cooldown = 1.2
		experience_reward = 10
	else:
		# 普通分裂体
		character_name = "分裂体"
		max_health = 100
		base_speed = 50.0
		base_attack_damage = 18
		attack_range = 150.0
		attack_cooldown = 2.0
		experience_reward = 45
	
	# ✅ 修复：初始血量应等于最大血量（统一设置）
	health = max_health
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage

func apply_mini_split_stats() -> void:
	"""应用小型分裂体属性。is_mini_split 在 _init() 后设置时也可复用。"""
	character_name = "小分裂体"
	max_health = 30
	health = 30
	base_speed = 110.0
	base_attack_damage = 8
	attack_range = 120.0
	attack_cooldown = 1.2
	experience_reward = 10
	current_speed = base_speed
	current_attack_damage = base_attack_damage
	current_defense = 0

func _ready():
	super._ready()
	
	var type_name = "小分裂体" if is_mini_split else "分裂体"
	print("🔀 ", type_name, " _ready() 被调用")
	print("  - 位置: ", global_position)
	print("  - 生命值: ", health, "/", max_health)
	print("  - is_dead: ", is_dead)
	print("  - visible: ", visible)
	
	# 确保节点已创建
	var existing_sprite = get_node_or_null("Sprite2D")
	if existing_sprite == null:
		setup_enemy_nodes()
	else:
		print("  - Sprite2D已存在")
	
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
	
	if is_mini_split:
		splitter_sprite.texture = MINI_SPLITTER_TEXTURE
	else:
		splitter_sprite.texture = SPLITTER_TEXTURE
	splitter_sprite.modulate = Color.WHITE
	splitter_sprite.scale = Vector2.ONE
	
	add_child(splitter_sprite)
	sprite = splitter_sprite
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
			splitter_sprite.texture = MINI_SPLITTER_TEXTURE
			print("  ✓ 小分裂体贴图已设置, visible: ", splitter_sprite.visible, ", scale: ", splitter_sprite.scale)
		else:
			splitter_sprite.texture = SPLITTER_TEXTURE
			print("  ✓ 分裂体贴图已设置, visible: ", splitter_sprite.visible, ", scale: ", splitter_sprite.scale)
		splitter_sprite.modulate = Color.WHITE
		splitter_sprite.scale = Vector2.ONE
		sprite = splitter_sprite
	else:
		var type_name = "小分裂体" if is_mini_split else "分裂体"
		print("  ⚠️ ", type_name, "setup_visuals()时Sprite2D不存在！")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if not can_process_enemy_ai() or not current_target:
		velocity = Vector2.ZERO
		return
	
	velocity = Vector2.ZERO
	var distance_to_target = get_distance_to(current_target)
	
	if distance_to_target <= attack_range:
		# 在攻击范围内
		execute_attack_behavior()
	else:
		# 追击
		execute_chase_behavior()

## ========== 分裂体AI行为 ==========

func _find_target():
	if not can_process_enemy_ai():
		current_target = null
		return
	"""寻找玩家目标"""
	if is_dead:
		return
	
	var player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= detection_range:
			current_target = player
		elif distance > lose_target_distance:
			current_target = null

## ========== 分裂逻辑 ==========

func die() -> void:
	"""死亡时分裂（除非是小型体）"""
	if is_dead:
		return
	
	var type_name = "小分裂体" if is_mini_split else "分裂体"
	print("💀 ", type_name, " 开始死亡流程")
	
	# 只有普通分裂体会分裂，小型体不会
	if not is_mini_split:
		print("🔀 分裂体死亡，正在分裂成 ", split_count, " 个小型体!")
		# ✅ 标记为已死亡，防止重复执行
		is_dead = true
		# ✅ 启动分裂流程（小分裂体生成完成后才会调用父类die()）
		_spawn_mini_splits()
	else:
		print("🔀 小分裂体死亡，不会分裂")
		# ✅ 小分裂体直接调用父类die()
		super.die()
		print("  ✅ ", type_name, " 死亡流程完成")

func _spawn_mini_splits() -> void:
	if is_instance_valid(encounter_owner):
		var types: Array[String] = []
		for index in range(split_count):
			types.append("mini_splitter")
		encounter_owner.request_reinforcements(self, types, "split")
	_finalize_parent_death()

func execute_attack_behavior() -> void:
	"""执行攻击行为"""
	if current_target and can_attack():
		perform_attack(current_target.global_position, current_target)

func execute_chase_behavior() -> void:
	"""执行追击行为"""
	if current_target:
		# 使用智能寻路
		navigate_to_target(current_target.global_position)
		move_and_slide()

func set_projectile_appearance(projectile: Node) -> void:
	"""
	设置分裂体弹道外观
	✅ 重写基类方法，自定义紫色弹道
	"""
	var sprite_node = projectile.get_node_or_null("Sprite2D")
	if sprite_node:
		# 根据是否为小型分裂体设置不同的颜色
		if is_mini_split:
			sprite_node.modulate = Color(0.6, 0.3, 0.6)  # 浅紫色弹道（小型分裂体）
			sprite_node.scale = Vector2(0.22, 0.22)  # 更小的弹道
			print("  🎨 小分裂体弹道外观: 浅紫色, 大小 0.22")
		else:
			sprite_node.modulate = Color(0.8, 0.2, 0.8)  # 紫色弹道（普通分裂体）
			sprite_node.scale = Vector2(0.32, 0.32)  # 中等大小
			print("  🎨 分裂体弹道外观: 紫色, 大小 0.32")
	
	# 设置弹道速度
	projectile.speed = 300

func _finalize_parent_death() -> void:
	"""
	完成父分裂体的死亡逻辑
	
	注意：is_dead 已经在 die() 中设置为 true
	这里手动执行父类死亡流程中的其他操作
	"""
	# 改变状态
	change_state(CharacterState.DEAD)
	
	# 清除所有Buff
	if buff_system:
		buff_system.clear_all_buffs()
	
	# 停止移动
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# 播放死亡效果
	play_death_effect()
	
	# 发出死亡信号
	character_died.emit(self)
	
	# 播放死亡动画（会在1秒后销毁）
	play_death_animation()
	
	# 掉落奖励
	drop_rewards()
	
	# 发出敌人击败信号
	enemy_defeated.emit(self, experience_reward)
	
	print("  ✅ 父分裂体死亡流程完成，等待动画后销毁")

## ========== 辅助方法 ==========

func get_ai_description() -> String:
	"""获取AI描述"""
	if is_mini_split:
		return "小分裂体AI - 快速追击"
	else:
		return "分裂体AI - 死亡时分裂成小型体"
