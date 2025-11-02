class_name SwiftStrikeSkill
extends SkillBase

# ⚡ 灵动迅捷 - 自身增益技能

# 可配置参数
@export var buff_duration: float = 5.0  # buff持续时间
@export var speed_boost_strength: float = 0.5  # 加速强度（50%移动速度提升）
@export var damage_boost_strength: float = 0.3  # 攻击强化（30%攻击力提升）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "swift_strike"
	skill_name = "灵动迅捷"
	cooldown = 10.0
	mana_cost = 35
	max_range = 0.0  # 自动释放
	skill_color = Color(1.0, 0.8, 0.2)  # 金黄色
	description = "获得5秒加速和攻击强化"
	cast_type = SkillCastType.AUTO_CAST

func on_skill_selected() -> void:
	"""灵动迅捷是自动释放技能，选中即释放"""
	super.on_skill_selected()
	
	# 自动释放技能
	cast_skill()

func execute_skill_effect(_target_position: Vector2, _target_node: Node) -> void:
	"""执行灵动迅捷效果"""
	print("⚡ 使用灵动迅捷!")
	
	# 为玩家施加加速buff
	if player and player.has_node("BuffSystem"):
		var buff_system = player.get_node("BuffSystem")
		
		# 施加加速
		buff_system.apply_buff(BuffSystem.BuffType.SPEED_BOOST, buff_duration, speed_boost_strength, player)
		
		# 施加攻击强化
		buff_system.apply_buff(BuffSystem.BuffType.STRENGTHEN, buff_duration, damage_boost_strength, player)
		
		# 创建视觉效果
		var effect = create_skill_effect("instant", player.global_position)
		effect.modulate = skill_color
		effect.life_time = 0.8
		effect.initialize()  # ✅ 初始化
		
		# 添加光环效果
		var aura = create_skill_effect("heal", player.global_position)
		aura.modulate = skill_color
		aura.life_time = 1.5
		aura.initialize()  # ✅ 初始化
		
		print("⚡ 灵动迅捷释放! 移动速度+", int(speed_boost_strength * 100), "%, 攻击力+", int(damage_boost_strength * 100), "%, 持续 ", buff_duration, " 秒")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "auto"
	return info

