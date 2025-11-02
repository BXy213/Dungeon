class_name IceSpikeSkill
extends SkillBase

# ❄️ 冰锥术 - 投射物技能

# 可配置参数
@export var damage_multiplier: float = 1.2  # 伤害倍率（基于玩家攻击力）
@export var slow_strength: float = 0.7  # 减速强度（50%）
@export var slow_duration: float = 3.0  # 减速持续时间
@export var projectile_width: float = 0.0  # 弹道宽度（0表示使用默认圆形碰撞盒）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "ice_spike"
	skill_name = "冰锥术"
	cooldown = 3.0
	mana_cost = 15
	max_range = 0.0  # 无射程限制
	skill_color = Color.CYAN
	description = "发射冰锥，造成伤害并减速敌人3秒"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行冰锥术效果"""
	print("❄️ 释放冰锥术到: ", target_position)
	
	# 计算技能伤害（基于玩家攻击力）
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 创建冰锥投射物
	var ice_spike = create_skill_effect("projectile", player.global_position)
	ice_spike.direction = (target_position - player.global_position).normalized()
	ice_spike.speed = 500.0
	ice_spike.damage = skill_damage
	ice_spike.max_distance = 600.0
	ice_spike.skill_width = projectile_width  # 设置弹道宽度
	ice_spike.life_time = 3.0
	
	# 设置命中时的减速buff
	ice_spike.on_hit_buff_type = BuffSystem.BuffType.SLOW
	ice_spike.on_hit_buff_duration = slow_duration
	ice_spike.on_hit_buff_strength = slow_strength
	
	# ✅ 在设置完所有属性后初始化
	ice_spike.initialize()
	
	print("  ❄️ 冰锥伤害: ", player_attack, " × ", damage_multiplier, " = ", skill_damage)

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "projectile"
	return info
