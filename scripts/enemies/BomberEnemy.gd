extends "res://scripts/EnemyCharacter.gd"
class_name BomberEnemy

# 💣 自爆兵 - 死亡时爆炸（参考DOTA特克斯/LOL炼金男爵虫子）

## ========== 自爆兵特有属性 ==========

# 爆炸相关
var explosion_radius: float = 100.0  # 爆炸范围
var explosion_damage_multiplier: float = 2.0  # 爆炸伤害倍率（基于攻击力）
var chase_speed_boost: float = 1.3  # 追击时速度提升

# AI相关
var current_target: Node = null
var detection_range: float = 400.0
var detonate_range: float = 80.0  # 引爆距离

## ========== 静态创建方法 ==========

static func create_bomber_enemy(enemy_room_id: Vector2i) -> BomberEnemy:
	"""静态工厂方法：创建自爆兵"""
	var bomber = BomberEnemy.new()
	bomber.is_room_enemy = true
	bomber.room_id = enemy_room_id
	return bomber

## ========== 初始化方法 ==========

func _init():
	super._init()
	
	# 设置自爆兵属性
	character_name = "自爆兵"
	max_health = 60  # 血量较低
	health = max_health  # ✅ 修复：初始血量应等于最大血量
	base_speed = 55.0
	base_attack_damage = 15  # 爆炸伤害会更高
	attack_range = 80.0  # 近身引爆
	attack_cooldown = 999.0  # 不使用普通攻击
	experience_reward = 40
	
	# 更新当前属性
	current_speed = base_speed
	current_attack_damage = base_attack_damage

func _ready():
	super._ready()
	
	print("💣 自爆兵 _ready() 被调用，位置: ", global_position)
	
	# 确保节点已创建
	var existing_sprite = get_node_or_null("Sprite2D")
	if existing_sprite == null:
		setup_enemy_nodes()
	
	# 定期查找目标
	var target_timer = Timer.new()
	target_timer.wait_time = 0.3
	target_timer.timeout.connect(_find_target)
	target_timer.autostart = true
	add_child(target_timer)
	
	print("💣 自爆兵 _ready() 完成")

func setup_enemy_nodes() -> void:
	"""创建自爆兵节点"""
	print("🔨 自爆兵正在创建节点...")
	
	# 创建Sprite2D节点（发光效果）
	var bomber_sprite = Sprite2D.new()
	bomber_sprite.name = "Sprite2D"
	bomber_sprite.texture = preload("res://art/icon.webp")
	bomber_sprite.modulate = Color(1.0, 0.5, 0.0)  # 橙色，像炸弹
	bomber_sprite.scale = Vector2(0.35, 0.35)
	add_child(bomber_sprite)
	print("  ✓ Sprite2D已创建")
	
	# 添加脉冲动画（像定时炸弹）
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(bomber_sprite, "modulate:a", 0.5, 0.5)
	tween.tween_property(bomber_sprite, "modulate:a", 1.0, 0.5)
	
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
	
	print("💣 自爆兵节点创建完成")

func setup_visuals() -> void:
	"""设置自爆兵视觉效果"""
	# ✅ 修复：确保贴图颜色正确设置（即使Sprite2D预先存在）
	var bomber_sprite = get_node_or_null("Sprite2D")
	if bomber_sprite:
		bomber_sprite.modulate = Color(1.0, 0.5, 0.0)  # 橙色
		print("  ✓ 自爆兵贴图颜色已设置为橙色, visible: ", bomber_sprite.visible, ", scale: ", bomber_sprite.scale)
		
		# 重新创建脉冲动画
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(bomber_sprite, "modulate:a", 0.5, 0.5)
		tween.tween_property(bomber_sprite, "modulate:a", 1.0, 0.5)
	else:
		print("  ⚠️ 自爆兵setup_visuals()时Sprite2D不存在！")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if is_dead or not current_target:
		return
	
	var distance_to_target = get_distance_to(current_target)
	
	# 检查是否在引爆范围内
	if distance_to_target <= detonate_range:
		_detonate()
	else:
		# 快速冲向目标
		execute_chase_behavior()

## ========== 自爆兵AI行为 ==========

func _find_target():
	"""寻找玩家目标"""
	if is_dead:
		return
	
	var player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= detection_range:
			current_target = player
			
			# 如果非常接近，立即引爆
			if distance <= detonate_range:
				_detonate()

## ========== 自爆逻辑 ==========

func _detonate() -> void:
	"""引爆自己"""
	if is_dead:
		return
	
	print("💣 自爆兵引爆! 位置: ", global_position)
	
	# 标记为已死亡，防止二次引爆
	is_dead = true
	
	# ⚠️ 使用 call_deferred 延迟创建爆炸效果
	var explosion_position = global_position
	var damage_to_deal = int(current_attack_damage * explosion_damage_multiplier)
	call_deferred("_deferred_create_explosion_effect", explosion_position, damage_to_deal)
	
	# 对范围内所有目标造成伤害
	var targets_in_range = _find_targets_in_explosion()
	var explosion_damage = int(current_attack_damage * explosion_damage_multiplier)
	
	for target in targets_in_range:
		if target.has_method("take_damage"):
			target.take_damage(explosion_damage, self)
			print("  💥 爆炸伤害: ", target.name, " 受到 ", explosion_damage, " 点伤害")
	
	# ✅ 调用父类die()来正确处理死亡逻辑（发出信号、掉落经验等）
	# 但跳过动画，直接销毁
	character_died.emit(self)
	
	# 掉落经验和物品
	drop_rewards()
	
	# 通知房间敌人死亡
	notify_room_enemy_death()
	
	# 发出敌人击败信号
	enemy_defeated.emit(self, experience_reward)
	
	# 立即销毁（不播放死亡动画）
	queue_free()

func _find_targets_in_explosion() -> Array:
	"""查找爆炸范围内的目标"""
	var targets = []
	
	# 检查玩家
	var player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if player and not player.is_dead:
		var distance = global_position.distance_to(player.global_position)
		if distance <= explosion_radius:
			targets.append(player)
	
	# 可以选择是否伤害其他敌人（目前不伤害队友）
	# var enemies = get_tree().get_nodes_in_group(Constants.GROUP_ENEMIES)
	# for enemy in enemies:
	#     if enemy != self and not enemy.is_dead:
	#         var distance = global_position.distance_to(enemy.global_position)
	#         if distance <= explosion_radius:
	#             targets.append(enemy)
	
	return targets

func _deferred_create_explosion_effect(explosion_position: Vector2, damage_to_deal: int) -> void:
	"""延迟创建爆炸效果（在下一帧执行）"""
	var SkillEffectScene = load(Constants.SCENE_SKILL_EFFECT) as PackedScene
	if not SkillEffectScene:
		return
	
	var explosion = SkillEffectScene.instantiate()
	explosion.global_position = explosion_position
	explosion.skill_type = "aoe"
	explosion.skill_radius = explosion_radius
	explosion.damage = damage_to_deal
	explosion.life_time = 1.0
	explosion.modulate = Color(1.0, 0.3, 0.0, 0.8)
	get_tree().current_scene.add_child(explosion)
	explosion.initialize()

func die() -> void:
	"""死亡时引爆"""
	if is_dead:
		return
	
	print("💣 自爆兵被击杀，触发爆炸!")
	_detonate()
	# ✅ _detonate()已经处理了所有死亡逻辑（包括信号发送、掉落等）

## ========== 攻击和追击行为 ==========

func execute_attack_behavior() -> void:
	"""自爆兵不使用普通攻击"""
	pass

func execute_chase_behavior() -> void:
	"""快速冲向目标"""
	if current_target:
		# 使用智能寻路（带速度加成）
		navigate_to_target(current_target.global_position)
		velocity = velocity * chase_speed_boost  # 应用追击速度加成
		move_and_slide()

## ========== 辅助方法 ==========

func get_ai_description() -> String:
	"""获取AI描述"""
	return "自爆兵AI - 冲向玩家并引爆"
