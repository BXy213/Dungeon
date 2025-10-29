class_name HealSkill
extends SkillBase

# 💚 治疗术 - 自动释放技能，提供持续生命回复

# 可配置的回复参数
@export var heal_duration: float = 3.0  # 回复持续时间
@export var heal_strength: float = 1.0  # 回复强度（每0.5秒回复 strength * 10 生命值）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "heal"
	skill_name = "治疗术"
	cooldown = 10.0
	mana_cost = 30
	max_range = 0.0  # 自动释放，无需选择目标
	skill_color = Color.GREEN
	description = "持续回复生命值3秒"
	cast_type = SkillCastType.AUTO_CAST

func on_skill_selected() -> void:
	"""治疗术是自动释放技能，选中即释放"""
	super.on_skill_selected()
	
	# 自动释放技能
	cast_skill()

func execute_skill_effect(_target_position: Vector2, _target_node: Node) -> void:
	"""执行治疗术效果"""
	print("💚 使用治疗术!")
	
	# 为玩家施加生命回复buff
	if player and player.has_node("BuffSystem"):
		var buff_system = player.get_node("BuffSystem")
		buff_system.apply_buff(BuffSystem.BuffType.REGENERATION, heal_duration, heal_strength, player)
		
		# 创建治疗视觉效果
		var heal_effect = create_skill_effect("heal", player.global_position)
		heal_effect.modulate = skill_color
		heal_effect.life_time = 1.5
		
		var total_heal = int(heal_strength * 10 * (heal_duration / 0.5))  # 预估总回复量
		print("💚 治疗术释放! 获得生命回复buff，持续 ", heal_duration, " 秒 (预计回复约 ", total_heal, " 点生命)")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "auto"
	return info
