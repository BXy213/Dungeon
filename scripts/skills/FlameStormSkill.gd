class_name FlameStormSkill
extends SkillBase

# 🔥 烈焰风暴 - 持续AOE伤害（参考LOL安妮大招/DOTA火女）

# 可配置参数
@export var damage_multiplier_per_tick: float = 0.4  # 每次伤害倍率
@export var storm_duration: float = 4.0  # 风暴持续时间
@export var tick_interval: float = 0.5  # 伤害间隔
@export var storm_radius: float = 180.0  # 风暴范围

var storm_timer: Timer = null
var storm_position: Vector2 = Vector2.ZERO
var storm_effect: Node = null

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "flame_storm"
	skill_name = "烈焰风暴"
	cooldown = 15.0
	mana_cost = 70
	max_range = 600.0
	skill_radius = storm_radius
	skill_color = Color(1.0, 0.3, 0.0)  # 橙红色
	description = "召唤持续4秒的烈焰风暴，持续伤害范围内敌人"
	cast_type = SkillCastType.TARGET_AREA

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行烈焰风暴效果"""
	print("🔥 释放烈焰风暴到: ", target_position)
	
	if not is_position_in_range(target_position):
		print("🔥 目标超出射程!")
		return
	
	storm_position = target_position
	
	# 创建视觉特效
	storm_effect = create_skill_effect("aoe", storm_position)
	storm_effect.skill_radius = storm_radius
	storm_effect.life_time = storm_duration
	storm_effect.modulate = Color(1.0, 0.3, 0.0, 0.6)
	storm_effect.initialize()
	
	# 创建持续伤害计时器
	storm_timer = Timer.new()
	storm_timer.wait_time = tick_interval
	storm_timer.timeout.connect(_on_storm_tick)
	player.add_child(storm_timer)
	storm_timer.start()
	
	# 设置持续时间后自动停止
	await player.get_tree().create_timer(storm_duration).timeout
	_cleanup_storm()
	
	print("  🔥 烈焰风暴结束")

func _on_storm_tick() -> void:
	"""每次伤害Tick"""
	if not player or player.is_dead:
		_cleanup_storm()
		return
	
	# 查找范围内的敌人
	var enemies = find_enemies_in_area(storm_position, storm_radius)
	var hit_count = 0
	
	# 计算每次伤害
	var tick_damage = int(player.current_attack_damage * damage_multiplier_per_tick)
	
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(tick_damage, player)
			hit_count += 1
	
	if hit_count > 0:
		print("  🔥 烈焰风暴伤害Tick: ", tick_damage, " × ", hit_count, " 个敌人")

func _cleanup_storm() -> void:
	"""清理风暴计时器"""
	if storm_timer:
		storm_timer.stop()
		storm_timer.queue_free()
		storm_timer = null

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "aoe"
	return info

