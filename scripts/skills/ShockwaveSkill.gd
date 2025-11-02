class_name ShockwaveSkill
extends SkillBase

# ⚡ 震荡波 - 直线AOE伤害（参考DOTA巫妖）

# 可配置参数
@export var damage_multiplier: float = 2.0  # 伤害倍率（基于玩家攻击力）
@export var wave_speed: float = 400.0  # 波动速度
@export var wave_distance: float = 800.0  # 波动距离
@export var wave_width: float = 40.0  # 波动宽度

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "shockwave"
	skill_name = "震荡波"
	cooldown = 8.0
	mana_cost = 40
	max_range = 0.0  # 无射程限制
	skill_color = Color(0.3, 0.9, 0.9)  # 青色
	description = "发射直线震荡波，对路径上所有敌人造成伤害"
	cast_type = SkillCastType.TARGET_GROUND

func create_skill_effect(effect_type: String, position: Vector2) -> Node:
	"""重写父类方法，使用自定义的ShockwaveSkill场景"""
	var effect = preload("res://Scenes/ShockwaveSkill.tscn").instantiate()
	effect.global_position = position
	effect.modulate = Color(1.0, 1.0, 1.0, 1.0)
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
	"""执行震荡波效果"""
	print("⚡ 释放震荡波到: ", target_position)
	
	if not player:
		return
	
	# 计算技能伤害
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 创建震荡波
	var shockwave = create_skill_effect("sonic_wave", player.global_position)
	shockwave.direction = (target_position - player.global_position).normalized()
	shockwave.speed = wave_speed
	shockwave.damage = skill_damage
	shockwave.max_distance = wave_distance
	shockwave.skill_width = wave_width
	shockwave.life_time = 3.0
	
	# 穿透所有敌人，每个敌人只命中一次
	shockwave.set_meta("hit_once", true)
	
	shockwave.initialize()
	
	print("  ⚡ 震荡波伤害: ", player_attack, " × ", damage_multiplier, " = ", skill_damage, ", 宽度: ", wave_width, " 像素")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "projectile"
	return info

