class_name TornadoSkill
extends SkillBase

# 🌪️ 强袭飓风 - 眩晕龙卷风

# 可配置参数
@export var damage_multiplier: float = 0.8  # 伤害倍率（基于玩家攻击力）
@export var stun_duration: float = 3.0  # 眩晕持续时间
@export var tornado_speed: float = 300.0  # 龙卷风速度
@export var tornado_distance: float = 600.0  # 龙卷风飞行距离
@export var tornado_width: float = 150.0  # 龙卷风宽度（垂直于发射方向）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "tornado"
	skill_name = "强袭飓风"
	cooldown = 12.0
	mana_cost = 50
	max_range = 0.0  # 无射程限制
	skill_color = Color(0.7, 0.9, 1.0, 0.6)  # 淡蓝色半透明
	description = "发射龙卷风，眩晕第一个敌人3秒"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行强袭飓风效果"""
	print("🌪️ 释放强袭飓风到: ", target_position)
	
	# 计算技能伤害（基于玩家攻击力）
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 创建龙卷风特效
	var tornado = create_skill_effect("tornado", player.global_position)
	tornado.direction = (target_position - player.global_position).normalized()
	tornado.speed = tornado_speed
	tornado.damage = skill_damage
	tornado.max_distance = tornado_distance
	tornado.skill_width = tornado_width  # 设置技能宽度
	tornado.life_time = 5.0
	tornado.modulate = skill_color
	
	# 设置命中时的眩晕buff
	tornado.on_hit_buff_type = BuffSystem.BuffType.STUN
	tornado.on_hit_buff_duration = stun_duration
	tornado.on_hit_buff_strength = 1.0
	
	# 特殊标记：穿透但每个敌人只命中一次
	tornado.set_meta("hit_once", true)
	
	# ✅ 在设置完所有属性后初始化
	tornado.initialize()
	
	print("  🌪️ 强袭飓风伤害: ", player_attack, " × ", damage_multiplier, " = ", skill_damage, ", 眩晕: ", stun_duration, " 秒")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "projectile"
	return info

