class_name FrostArmorSkill
extends SkillBase

# ❄️ 寒冰护甲 - 自我buff，受击时减速攻击者（参考魔兽争霸/DOTA寒冰护甲）

# 可配置参数
@export var armor_duration: float = 10.0  # 护甲持续时间
@export var damage_reduction: float = 0.5  # 伤害减免（50%）
@export var slow_duration: float = 2.0  # 攻击者减速持续时间
@export var slow_strength: float = 0.4  # 攻击者减速强度（40%）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "frost_armor"
	skill_name = "寒冰护甲"
	cooldown = 15.0
	mana_cost = 40
	max_range = 0.0  # 自我施放
	skill_color = Color(0.5, 0.8, 1.0)  # 冰蓝色
	description = "获得护甲，减少50%伤害，攻击你的敌人会被减速"
	cast_type = SkillCastType.AUTO_CAST

func execute_skill_effect(_target_position: Vector2, _target_node: Node) -> void:
	"""执行寒冰护甲效果"""
	print("❄️ 释放寒冰护甲")
	
	if not player:
		return
	
	# 创建护甲视觉效果（短暂的释放特效，不是持续的光环）
	var armor_effect = create_skill_effect("instant", player.global_position)
	armor_effect.life_time = 0.5  # ✅ 修复：只显示0.5秒的释放特效
	armor_effect.modulate = Color(0.5, 0.8, 1.0, 0.8)
	armor_effect.initialize()
	
	# 施加寒冰护甲buff（提供伤害减免+反击减速）
	if player.has_node("BuffSystem"):
		var buff_system = player.get_node("BuffSystem")
		# ✅ 施加FROST_ARMOR buff，strength 存储减伤值
		buff_system.apply_buff(BuffSystem.BuffType.FROST_ARMOR, armor_duration, damage_reduction, player)
		print("  ❄️ 寒冰护甲激活! 持续 ", armor_duration, " 秒")
		print("  ❄️ 伤害减免: ", int(damage_reduction * 100), "%")
		print("  ❄️ 反击减速: ", int(slow_strength * 100), "% 持续 ", slow_duration, " 秒")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "auto"
	return info

