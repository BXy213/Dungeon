class_name ManaRestoreSkill
extends SkillBase

# 🔮 魔法回复 - 自动释放技能，提供持续魔法回复

# 可配置的回复参数
@export var mana_duration: float = 3.0  # 回复持续时间
@export var mana_strength: float = 1.0  # 回复强度（每0.5秒回复 strength * 8 魔法值）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "mana_restore"
	skill_name = "魔法回复"
	cooldown = 15.0
	mana_cost = 0  # 不消耗魔法
	max_range = 0.0
	skill_color = Color.BLUE
	description = "持续回复魔法值3秒"
	cast_type = SkillCastType.AUTO_CAST

func on_skill_selected() -> void:
	"""魔法回复是自动释放技能，选中即释放"""
	super.on_skill_selected()
	
	# 自动释放技能
	cast_skill()

func execute_skill_effect(_target_position: Vector2, _target_node: Node) -> void:
	"""执行魔法回复效果"""
	print("🔮 使用魔法回复!")
	
	# 为玩家施加魔法回复buff
	if player and player.has_node("BuffSystem"):
		var buff_system = player.get_node("BuffSystem")
		buff_system.apply_buff(BuffSystem.BuffType.MANA_REGEN, mana_duration, mana_strength, player)
		
		# 创建回复效果
		var restore_effect = create_skill_effect("heal", player.global_position)
		restore_effect.modulate = skill_color
		restore_effect.life_time = 1.5
		restore_effect.initialize()  # ✅ 初始化
		
		var total_mana = int(mana_strength * 8 * (mana_duration / 0.5))  # 预估总回复量
		print("🔮 魔法回复释放! 获得魔法回复buff，持续 ", mana_duration, " 秒 (预计回复约 ", total_mana, " 点魔法)")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "auto"
	return info
