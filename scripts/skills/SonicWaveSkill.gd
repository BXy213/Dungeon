class_name SonicWaveSkill
extends SkillBase

# 📢 超震声波 - 伤害+减速+击退

# 可配置参数
@export var damage_multiplier: float = 1.8  # 伤害倍率（基于玩家攻击力）
@export var slow_duration: float = 2.0  # 减速持续时间
@export var slow_strength: float = 0.6  # 减速强度（60%减速）
@export var knockback_distance: float = 50.0  # 击退距离
@export var wave_speed: float = 300.0  # 声波速度
@export var wave_distance: float = 200.0  # 声波飞行距离
@export var wave_width: float = 80.0  # 声波宽度（垂直于发射方向）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "sonic_wave"
	skill_name = "超震声波"
	cooldown = 10.0
	mana_cost = 45
	max_range = 0.0  # 无射程限制
	skill_color = Color(1.0, 0.5, 0.0, 0.7)  # 橙色半透明
	description = "冲击波，伤害+减速+击退第一个敌人"
	cast_type = SkillCastType.TARGET_GROUND

func create_skill_effect(effect_type: String, position: Vector2) -> Node:
	"""重写父类方法，使用自定义的SonicWaveSkill场景"""
	var effect = preload("res://Scenes/SonicWaveSkill.tscn").instantiate()
	effect.global_position = position
	effect.modulate = skill_color
	effect.skill_type = effect_type
	effect.source = player  # 设置技能来源为玩家
	
	# 添加到场景但延迟初始化
	var skill_effects = player.get_tree().current_scene.get_node_or_null("SkillEffects")
	if skill_effects:
		skill_effects.add_child(effect)
	else:
		player.get_tree().current_scene.add_child(effect)
	
	return effect

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行超震声波效果"""
	print("📢 释放超震声波到: ", target_position)
	
	# 计算技能伤害（基于玩家攻击力）
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 创建声波特效
	var sonic_wave = create_skill_effect("sonic_wave", player.global_position)
	sonic_wave.direction = (target_position - player.global_position).normalized()
	sonic_wave.speed = wave_speed
	sonic_wave.damage = skill_damage
	sonic_wave.max_distance = wave_distance
	sonic_wave.skill_width = wave_width  # 设置技能宽度
	sonic_wave.life_time = 4.0
	sonic_wave.modulate = skill_color
	
	# 设置命中时的减速buff
	sonic_wave.on_hit_buff_type = BuffSystem.BuffType.SLOW
	sonic_wave.on_hit_buff_duration = slow_duration
	sonic_wave.on_hit_buff_strength = slow_strength
	
	# 特殊标记：穿透但每个敌人只命中一次，并且需要击退
	sonic_wave.set_meta("hit_once", true)
	sonic_wave.set_meta("knockback", true)
	sonic_wave.set_meta("knockback_distance", knockback_distance)
	sonic_wave.set_meta("knockback_direction", sonic_wave.direction)
	
	# ✅ 在设置完所有属性后初始化
	sonic_wave.initialize()
	
	print("  📢 超震声波伤害: ", player_attack, " × ", damage_multiplier, " = ", skill_damage, ", 减速: ", int(slow_strength * 100), "%, 击退: ", knockback_distance, " 像素")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "projectile"
	return info

