extends Area2D

@export var speed: float = 400.0
@export var life_time: float = 2.0
@export var max_distance: float = 600.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 0
var skill_type: String = "projectile"
var traveled_distance: float = 0.0
var skill_radius: float = 0.0  # 技能作用范围半径（通用）
var skill_width: float = 0.0  # 技能宽度（用于定向技能如龙卷风、声波）
var skill_length: float = 0.0  # 技能长度（用于定向技能，0表示使用默认值）
var source: Node = null  # 技能来源（玩家或敌人）

# Buff相关属性（命中时对目标施加buff）
var on_hit_buff_type: int = -1  # BuffSystem.BuffType，-1表示无buff
var on_hit_buff_duration: float = 0.0
var on_hit_buff_strength: float = 0.0

# 已命中的目标列表（用于"穿透但每个敌人只命中一次"的技能）
var hit_targets: Array = []

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

# 标记是否已初始化（避免重复初始化）
var _is_initialized: bool = false

func _ready() -> void:
	# 不在这里初始化，等待调用者设置完属性后调用initialize()
	pass

func initialize() -> void:
	"""在设置完所有属性后调用此函数进行初始化"""
	if _is_initialized:
		return
	_is_initialized = true
	
	# 如果有技能宽度，设置碰撞盒为矩形
	if skill_width > 0:
		setup_directional_collision()
	
	# 所有弹道类技能（projectile, tornado, sonic_wave, enemy_projectile）都需要旋转
	if is_projectile_type():
		update_rotation()
	
	# 根据技能类型设置不同行为
	match skill_type:
		"projectile", "tornado", "sonic_wave":
			setup_projectile_skill()
		"enemy_projectile":
			setup_enemy_projectile()
		"instant":
			setup_instant()  
		"heal":
			setup_heal()
		"aoe":
			setup_aoe()
		"targeted":
			setup_targeted()
	
	# 自动销毁
	get_tree().create_timer(life_time).timeout.connect(queue_free)

func is_projectile_type() -> bool:
	"""检查是否为弹道类技能"""
	return skill_type in ["projectile", "tornado", "sonic_wave", "enemy_projectile"]

func setup_projectile_skill() -> void:
	"""设置弹道技能（包括普通弹道、龙卷风、声波等）"""
	# 如果有技能宽度或长度，调整贴图缩放
	if sprite and (skill_width > 0 or skill_length > 0):
		# 假设原始贴图大小是32x32像素
		var original_size = 32.0
		var scale_x = sprite.scale.x  # 默认保持X轴的原始缩放
		var scale_y = sprite.scale.y  # 默认保持Y轴的原始缩放
		
		# 如果设置了skill_length，调整X轴缩放
		if skill_length > 0:
			scale_x = skill_length / original_size
		
		# 如果设置了skill_width，调整Y轴缩放
		if skill_width > 0:
			scale_y = skill_width / original_size
		
		sprite.scale = Vector2(scale_x, scale_y)
		
		print("  🎨 调整弹道贴图缩放: scale=", sprite.scale, " (长度: ", skill_length if skill_length > 0 else "默认", ", 宽度: ", skill_width if skill_width > 0 else "默认", ")")

func setup_directional_collision() -> void:
	"""设置定向碰撞盒（矩形，朝向发射方向）"""
	if not collision_shape:
		return
	
	# 创建矩形碰撞盒
	var rect_shape = RectangleShape2D.new()
	# 如果设置了skill_length则使用，否则使用默认值30像素
	var collision_length = skill_length if skill_length > 0 else 30.0
	rect_shape.size = Vector2(collision_length, skill_width)
	collision_shape.shape = rect_shape
	
	print("  📐 设置定向碰撞盒: 长度=", collision_length, " 宽度=", skill_width)

func update_rotation() -> void:
	"""更新旋转角度和贴图朝向（在direction设置后调用）"""
	if direction != Vector2.ZERO:
		rotation = direction.angle()
		print("  🔄 更新旋转朝向: ", rad_to_deg(rotation), "° 方向: ", direction)

func setup_enemy_projectile() -> void:
	"""初始化敌人弹道（不设置外观，由敌人类自己控制）"""
	# ✅ 移除了强制的外观设置，外观应该在create_attack_projectile()中通过set_projectile_appearance()设置
	
	# 添加旋转效果（可选，子类可以在set_projectile_appearance中禁用）
	if get_meta("disable_rotation", false):
		return
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "rotation", rotation + TAU, 0.5)

func setup_instant() -> void:
	# 瞬间技能 - 不移动，播放闪电动画，禁用碰撞检测
	set_deferred("monitoring", false)  # 延迟禁用碰撞检测
	set_deferred("monitorable", false) # 延迟禁用被检测
	
	if sprite:
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.1)

func setup_heal() -> void:
	# 治疗技能 - 上升动画
	if sprite:
		var tween = create_tween()
		tween.parallel().tween_property(self, "position", position + Vector2(0, -50), life_time)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, life_time)

func setup_aoe() -> void:
	# AOE技能 - 爆炸效果
	if sprite:
		# 先快速放大，然后慢慢消失
		sprite.scale = Vector2.ZERO
		var tween = create_tween()
		tween.parallel().tween_property(sprite, "scale", Vector2(skill_radius / 50.0, skill_radius / 50.0), 0.3)
		tween.parallel().tween_property(sprite, "modulate:a", 0.5, 0.3)
		tween.tween_property(sprite, "modulate:a", 0.0, life_time - 0.3)

func setup_targeted() -> void:
	# 精准射击技能 - 闪烁效果
	if sprite:
		var tween = create_tween()
		tween.set_loops(4)
		tween.tween_property(sprite, "modulate:a", 0.2, 0.1)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.1)

func _physics_process(delta: float) -> void:
	# 投射物和敌人弹道都需要移动
	if skill_type in ["projectile", "enemy_projectile", "tornado", "sonic_wave"]:
		var movement = direction.normalized() * speed * delta
		position += movement
		traveled_distance += movement.length()
		
		# 检查是否超过最大距离
		if traveled_distance >= max_distance:
			queue_free()

func _on_area_entered(area: Area2D) -> void:
	"""处理Area2D碰撞（弹道之间不应相互碰撞）"""
	# 检查是否为弹道碰撞（通过检查是否有skill_type属性）
	if "skill_type" in area:
		var other_skill_type = area.skill_type
		if other_skill_type in ["projectile", "enemy_projectile"]:
			print("🔄 弹道相遇，互相穿过: ", skill_type, " vs ", other_skill_type)
			return  # 弹道之间不碰撞，互相穿过
	
	# 其他Area2D碰撞处理（如果需要的话）
	# 目前所有实际碰撞都通过body_entered处理
	# 这里可以用于处理特殊的Area碰撞逻辑

func _on_body_entered(body: Node2D) -> void:
	# instant 类型的技能不应该进行碰撞检测（它们是静态特效）
	if skill_type == "instant":
		return
	
	print("📍 弹道检测到碰撞: ", body.name, " 类型: ", body.get_class(), " 弹道类型: ", skill_type)
	
	# 首先检查是否为阻挡物（障碍物或墙壁）碰撞
	if is_obstacle_collision(body):
		handle_obstacle_collision(body)
		return
	
	# 根据技能类型处理其他碰撞
	match skill_type:
		"projectile", "tornado", "sonic_wave":
			# 这三种都使用玩家弹道碰撞逻辑
			handle_player_projectile_collision(body)
		"enemy_projectile":
			handle_enemy_projectile_collision(body)
		"heal":
			handle_heal_collision(body)

func handle_player_projectile_collision(body: Node2D) -> void:
	# 玩家弹道：检查是否为敌人（不攻击玩家自己）
	if body != get_tree().get_first_node_in_group("players") and body.has_method("take_damage"):
		# 检查是否是"穿透但每个敌人只命中一次"的技能（如龙卷风、声波）
		if has_meta("hit_once") and get_meta("hit_once") == true:
			# 检查这个敌人是否已经被命中过
			if body in hit_targets:
				print("  ⏭️ 敌人 ", body.name, " 已被命中过，跳过")
				return  # 这个敌人已经被命中过，跳过
			else:
				# 记录这个敌人
				hit_targets.append(body)
				print("  🎯 首次命中敌人: ", body.name, " (已命中数: ", hit_targets.size(), ")")
		
		# 传递伤害来源（玩家）
		body.take_damage(damage, source if source else get_tree().get_first_node_in_group("players"))
		print("玩家技能命中 ", body.name, "! 造成 ", damage, " 点伤害")
		
		# 如果有buff信息，对目标施加buff
		if on_hit_buff_type >= 0:
			print("  🔍 检查buff应用: buff_type=", on_hit_buff_type, " 目标=", body.name)
			print("    目标有BuffSystem子节点? ", body.has_node("BuffSystem"))
			
			if body.has_node("BuffSystem"):
				var buff_system = body.get_node("BuffSystem")
				print("    BuffSystem节点类型: ", buff_system.get_class())
				if buff_system.has_method("apply_buff"):
					buff_system.apply_buff(on_hit_buff_type, on_hit_buff_duration, on_hit_buff_strength, source)
					print("  ✨ 成功对 ", body.name, " 施加Buff: ", on_hit_buff_type)
				else:
					print("  ⚠️ BuffSystem没有apply_buff方法")
			else:
				print("  ⚠️ 目标没有BuffSystem节点，目标子节点: ", body.get_children())
		
		# 处理击退效果
		if has_meta("knockback") and get_meta("knockback") == true:
			apply_knockback(body)
		
		# 如果不是"穿透"类型的技能，命中后销毁
		if not (has_meta("hit_once") and get_meta("hit_once") == true):
			# 延迟禁用碰撞检测，避免物理引擎冲突
			set_deferred("monitoring", false)
			set_deferred("monitorable", false)
			
			# 延迟创建撞击特效，避免物理引擎冲突
			call_deferred("create_impact_effect", Color.WHITE)
			queue_free()
		else:
			# 穿透技能，命中后继续飞行并可以命中其他目标
			print("  ✈️ 技能继续飞行，可以命中其他未命中的目标")

func handle_enemy_projectile_collision(body: Node2D) -> void:
	# 敌人弹道：检查是否为玩家
	print("🎯 敌人弹道碰撞检测: 命中节点 ", body.name, " (", body.get_class(), ")")
	
	var is_player = (body.name == "Player" or body.is_in_group("players")) and body.has_method("take_damage")
	print("    最终判定是否为玩家: ", is_player)
	
	if is_player:
		# 造成伤害（✅ 传递source用于寒冰护甲反击等）
		body.take_damage(damage, source)
		print("敌人弹道命中玩家，造成 ", damage, " 点伤害")
		
		# 显示伤害数字
		if body.has_method("show_damage_number"):
			body.show_damage_number(damage)
		
		# 延迟禁用碰撞检测，避免物理引擎冲突
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		# 延迟创建撞击特效，避免物理引擎冲突
		call_deferred("create_impact_effect", Color.ORANGE_RED)
		
		# 销毁弹道
		queue_free()

func handle_heal_collision(body: Node2D) -> void:
	# 治疗技能
	if body.has_method("heal"):
		body.heal(damage)  # 对于治疗技能，使用damage作为治疗量
		print("治疗技能命中 ", body.name, "! 恢复 ", damage, " 点生命值")
		queue_free()

func create_impact_effect(color: Color = Color.WHITE) -> void:
	"""创建撞击特效（延迟调用以避免物理引擎冲突）"""
	# 确保节点仍然有效
	if not is_inside_tree():
		return
	
	var impact_scene = load("res://Scenes/SkillEffect.tscn") as PackedScene
	if not impact_scene:
		return
	
	var impact = impact_scene.instantiate()
	impact.global_position = global_position
	impact.skill_type = "instant"
	impact.life_time = 0.3
	
	# 设置颜色
	var impact_sprite = impact.get_node_or_null("Sprite2D")
	if impact_sprite:
		impact_sprite.modulate = color
		impact_sprite.scale = Vector2(0.8, 0.8)
	
	# 获取技能效果容器
	var skill_effects = get_tree().current_scene.get_node_or_null("SkillEffects")
	if skill_effects:
		skill_effects.add_child(impact)
	else:
		get_tree().current_scene.add_child(impact)
	
	# ✅ 初始化撞击特效
	impact.initialize()

## ========== 阻挡物碰撞处理（障碍物 + 墙壁） ==========

func is_obstacle_collision(body: Node2D) -> bool:
	"""检查是否为障碍物或墙壁碰撞"""
	if not body is StaticBody2D:
		return false
	
	# 检查是否为障碍物（有obstacle_type方法）
	var is_obstacle = body.has_method("get_obstacle_type")
	
	# 检查是否为房间墙壁（名称包含"RoomWall"）
	var is_wall = body.name.begins_with("RoomWall")
	
	var is_blocking = is_obstacle or is_wall
	
	if is_blocking:
		if is_wall:
			print("✅ 确认为房间墙壁: ", body.name)
		else:
			print("✅ 确认为障碍物: ", body.name)
	else:
		print("❌ 不是障碍物或墙壁: ", body.name, " 类型: ", body.get_class())
	
	return is_blocking

func handle_obstacle_collision(body: Node2D) -> void:
	"""处理障碍物或墙壁碰撞"""
	var collision_type = "unknown"
	
	# 判断是墙壁还是障碍物
	if body.name.begins_with("RoomWall"):
		collision_type = "wall"
	elif body.has_method("get_obstacle_type"):
		collision_type = body.get_obstacle_type()
	
	print("🧱 弹道碰撞到阻挡物: ", body.name, " 类型: ", collision_type, " 弹道类型: ", skill_type)
	
	# 🌪️ 特殊技能（龙卷风、声波）穿透障碍物和墙壁，继续飞行
	if skill_type in ["tornado", "sonic_wave"]:
		print("  ✈️ ", skill_type, " 穿透阻挡物，继续飞行")
		return  # 不销毁，继续飞行
	
	# 其他技能：销毁弹道
	print("  💥 弹道被阻挡，销毁")
	
	# 延迟禁用碰撞检测，避免物理引擎冲突
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# 创建撞击特效
	call_deferred("create_impact_effect", Color.GRAY)
	
	# 销毁弹道
	queue_free()

func apply_knockback(target: Node2D) -> void:
	"""对目标应用击退效果"""
	if not target.has_method("move_and_collide"):
		print("  ⚠️ 目标无法被击退: ", target.name)
		return
	
	if not has_meta("knockback_distance") or not has_meta("knockback_direction"):
		print("  ⚠️ 缺少击退参数")
		return
	
	var kb_distance = get_meta("knockback_distance")
	var kb_direction = get_meta("knockback_direction")
	
	print("  💥 击退 ", target.name, " 方向: ", kb_direction, " 距离: ", kb_distance)
	
	# 使用Tween实现平滑击退
	var tween = create_tween()
	var start_pos = target.global_position
	var end_pos = start_pos + kb_direction * kb_distance
	tween.tween_property(target, "global_position", end_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
