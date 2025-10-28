extends Area2D

@export var speed: float = 400.0
@export var life_time: float = 2.0
@export var max_distance: float = 600.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 0
var skill_type: String = "projectile"
var traveled_distance: float = 0.0
var skill_radius: float = 0.0  # 技能作用范围半径（通用）

@onready var sprite = $Sprite2D

func _ready() -> void:
	# 根据技能类型设置不同行为
	match skill_type:
		"projectile":
			setup_projectile()
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
	await get_tree().create_timer(life_time).timeout
	queue_free()

func setup_projectile() -> void:
	# 投射物技能 - 需要移动
	pass

func setup_enemy_projectile() -> void:
	# 敌人弹道 - 类似投射物但有不同外观
	if sprite:
		sprite.modulate = Color.ORANGE_RED
		sprite.scale = Vector2(0.3, 0.3)
	
	# 添加旋转效果
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
	if skill_type == "projectile" or skill_type == "enemy_projectile":
		var movement = direction.normalized() * speed * delta
		position += movement
		traveled_distance += movement.length()
		
		# 检查是否超过最大距离
		if traveled_distance >= max_distance:
			queue_free()

func _on_area_entered(_area: Area2D) -> void:
	# 碰撞检测 - 可以在这里处理伤害
	if skill_type == "projectile":
		print("技能命中目标! 造成 ", damage, " 点伤害")
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# instant 类型的技能不应该进行碰撞检测（它们是静态特效）
	if skill_type == "instant":
		return
	
	print("📍 弹道检测到碰撞: ", body.name, " 类型: ", body.get_class(), " 弹道类型: ", skill_type)
	
	# 首先检查是否为障碍物碰撞
	if is_obstacle_collision(body):
		handle_obstacle_collision(body)
		return
	
	# 根据技能类型处理其他碰撞
	match skill_type:
		"projectile":
			handle_player_projectile_collision(body)
		"enemy_projectile":
			handle_enemy_projectile_collision(body)
		"heal":
			handle_heal_collision(body)

func handle_player_projectile_collision(body: Node2D) -> void:
	# 玩家弹道：检查是否为敌人（不攻击玩家自己）
	if body != get_tree().get_first_node_in_group("players") and body.has_method("take_damage"):
		body.take_damage(damage)
		print("玩家技能命中 ", body.name, "! 造成 ", damage, " 点伤害")
		
		# 延迟禁用碰撞检测，避免物理引擎冲突
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		# 延迟创建撞击特效，避免物理引擎冲突
		call_deferred("create_impact_effect", Color.WHITE)
		queue_free()

func handle_enemy_projectile_collision(body: Node2D) -> void:
	# 敌人弹道：检查是否为玩家
	print("🎯 敌人弹道碰撞检测: 命中节点 ", body.name, " (", body.get_class(), ")")
	
	var is_player = (body.name == "Player" or body.is_in_group("players")) and body.has_method("take_damage")
	print("    最终判定是否为玩家: ", is_player)
	
	if is_player:
		# 造成伤害
		body.take_damage(damage)
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
	
	var impact = preload("res://Scenes/SkillEffect.tscn").instantiate()
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

## ========== 障碍物碰撞处理 ==========

func is_obstacle_collision(body: Node2D) -> bool:
	"""检查是否为障碍物碰撞"""
	# 检查是否为障碍物（StaticBody2D类型且有obstacle_type属性）
	var is_obstacle = body is StaticBody2D and body.has_method("get_obstacle_type")
	if is_obstacle:
		print("✅ 确认为障碍物: ", body.name)
	else:
		print("❌ 不是障碍物: ", body.name, " 类型: ", body.get_class())
	return is_obstacle

func handle_obstacle_collision(body: Node2D) -> void:
	"""处理障碍物碰撞"""
	var obstacle_type = "unknown"
	if body.has_method("get_obstacle_type"):
		obstacle_type = body.get_obstacle_type()
	
	print("🧱 弹道碰撞到障碍物: ", body.name, " 类型: ", obstacle_type, " 弹道类型: ", skill_type)
	
	# 延迟禁用碰撞检测，避免物理引擎冲突
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# 创建撞击特效
	call_deferred("create_impact_effect", Color.GRAY)
	
	# 销毁弹道
	queue_free()
