class_name ManaRestoreSkill
extends SkillBase

# 🔮 魔法回复 - 自动释放技能

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "mana_restore"
	skill_name = "魔法回复"
	cooldown = 8.0
	mana_cost = 0  # 不消耗魔法
	max_range = 0.0
	skill_color = Color.BLUE
	description = "立即恢复魔法值"
	cast_type = SkillCastType.AUTO_CAST

func on_skill_selected() -> void:
	"""魔法回复是自动释放技能，选中即释放"""
	super.on_skill_selected()
	
	# 自动释放技能
	cast_skill()

func execute_skill_effect(_target_position: Vector2, _target_node: Node) -> void:
	"""执行魔法回复效果"""
	print("🔮 使用魔法回复!")
	
	# 恢复魔法值
	if player and player.has_method("restore_mana"):
		var restore_amount = 50
		player.restore_mana(restore_amount)
		
		# 创建回复效果
		var restore_effect = create_skill_effect("heal", player.global_position)
		restore_effect.modulate = skill_color
		restore_effect.life_time = 1.5
		
		print("🔮 魔法回复! 恢复 ", restore_amount, " 点魔法值")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "auto"
	return info
