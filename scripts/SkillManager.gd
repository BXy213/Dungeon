extends Node

# 🎯 重构后的技能管理器 - 基于技能类的新架构

# 技能库 - 存储所有可用技能类路径
var all_skill_classes = {
	"fireball": "res://scripts/skills/FireballSkill.gd",
	"ice_spike": "res://scripts/skills/IceSpikeSkill.gd",
	"lightning": "res://scripts/skills/LightningSkill.gd",
	"heal": "res://scripts/skills/HealSkill.gd",
	"meteor": "res://scripts/skills/MeteorSkill.gd",
	"snipe": "res://scripts/skills/SnipeSkill.gd",
	"mana_restore": "res://scripts/skills/ManaRestoreSkill.gd",
	# 🌟 新增技能 - 参考DOTA2祈求者
	"poison_shot": "res://scripts/skills/PoisonShotSkill.gd",
	"swift_strike": "res://scripts/skills/SwiftStrikeSkill.gd",
	"tornado": "res://scripts/skills/TornadoSkill.gd",
	"sonic_wave": "res://scripts/skills/SonicWaveSkill.gd"
}

# 🎮 玩家激活的技能实例（最多4个，可以为null）
var active_skills = [null, null, null, null]

# 🎁 玩家拥有的技能库（包括激活和未激活的）
var owned_skills: Array[String] = []

# 引用
var player: Node = null

# 🎮 初始技能配置 - 可以根据需要修改
@export var initial_skills: Array[String] = []  # 空数组表示无初始技能，可填入技能ID如["fireball", "heal"]

func _ready() -> void:
	# 获取玩家引用
	player = get_parent()
	
	# 设置初始技能（如果配置了的话）
	if initial_skills.size() > 0:
		set_initial_skills(initial_skills)
		print("🎮 玩家初始技能: ", initial_skills)
	else:
		print("🎮 玩家开始时没有任何技能，需要通过房间奖励获得")

# 🔧 简化初始技能设置函数
func set_initial_skills(skill_ids: Array[String]) -> void:
	"""设置玩家的初始技能。参数是技能ID数组，最多4个。"""
	# 先将技能添加到拥有的技能库
	for skill_id in skill_ids:
		if skill_id in all_skill_classes:
			add_skill_to_library(skill_id)
	
	# 然后激活技能到槽位
	for i in range(min(skill_ids.size(), 4)):
		if skill_ids[i] in all_skill_classes:
			var skill_script_path = all_skill_classes[skill_ids[i]]
			var skill_script = load(skill_script_path)
			active_skills[i] = skill_script.new(player, self)
			print("设置初始技能槽 ", i, ": ", active_skills[i].skill_name)

# 🔄 技能切换函数
func swap_skill(slot_index: int, new_skill_id: String) -> bool:
	"""将技能槽中的技能替换为新技能。返回是否成功。"""
	if slot_index < 0 or slot_index >= 4:
		return false
	
	if new_skill_id in all_skill_classes:
		var old_skill = active_skills[slot_index]
		var skill_script_path = all_skill_classes[new_skill_id]
		var skill_script = load(skill_script_path)
		active_skills[slot_index] = skill_script.new(player, self)
		print("技能槽 ", slot_index, " 从 ", (old_skill.skill_name if old_skill else "空"), " 切换到 ", active_skills[slot_index].skill_name)
		return true
	elif new_skill_id == "":
		# 移除技能
		var old_skill = active_skills[slot_index]
		active_skills[slot_index] = null
		print("移除技能槽 ", slot_index, " 的技能: ", (old_skill.skill_name if old_skill else "空"))
		return true
	
	return false

# 🎯 获取技能信息（支持激活技能）
func get_active_skill_info(slot_index: int) -> Dictionary:
	"""获取激活技能槽中的技能信息"""
	if slot_index < 0 or slot_index >= 4:
		return {}
	
	var skill = active_skills[slot_index]
	if skill:
		return {
			"name": skill.skill_name,
			"cooldown": skill.cooldown,
			"mana_cost": skill.mana_cost,
			"color": skill.skill_color,
			"type": skill.get_cast_type_string(),
			"range": skill.max_range,
			"description": skill.description
		}
	return {}

func get_skill_info_by_id(skill_id: String) -> Dictionary:
	"""通过技能ID获取技能信息"""
	if skill_id in all_skill_classes:
		var skill_script_path = all_skill_classes[skill_id]
		var skill_script = load(skill_script_path)
		var temp_skill = skill_script.new(player, self)
		return {
			"name": temp_skill.skill_name,
			"cooldown": temp_skill.cooldown,
			"mana_cost": temp_skill.mana_cost,
			"color": temp_skill.skill_color,
			"type": temp_skill.get_cast_type_string(),
			"range": temp_skill.max_range,
			"description": temp_skill.description
		}
	return {}

func get_skill_instance(slot_index: int):
	"""获取技能实例"""
	if slot_index >= 0 and slot_index < 4:
		return active_skills[slot_index]
	return null

func can_cast_skill(slot_index: int) -> bool:
	var skill = get_skill_instance(slot_index)
	if not skill:
		return false
	return skill.can_cast()

func cast_skill(slot_index: int, target_position: Vector2 = Vector2.ZERO, target_node: Node = null) -> bool:
	var skill = get_skill_instance(slot_index)
	if not skill:
		print("技能槽为空!")
		return false
	
	return skill.cast_skill(target_position, target_node)

# 🔄 适配现有接口
func get_skill_info(slot_index: int) -> Dictionary:
	"""获取技能信息"""
	return get_active_skill_info(slot_index)

func get_cooldown_remaining(slot_index: int) -> float:
	var skill = get_skill_instance(slot_index)
	if skill:
		return skill.get_cooldown_remaining()
	return 0.0

func get_skill_cooldown(slot_index: int) -> float:
	var skill = get_skill_instance(slot_index)
	if skill:
		return skill.cooldown
	return 0.0

# 🔍 获取技能库信息
func get_all_available_skills() -> Dictionary:
	"""获取所有可用技能（只包括拥有的技能，用于技能切换界面）"""
	var skills = {}
	for skill_id in owned_skills:
		var skill_info = get_skill_info_by_id(skill_id)
		skills[skill_id] = skill_info
	return skills

func get_unowned_skills() -> Array[String]:
	"""获取玩家未拥有的技能ID列表"""
	var unowned: Array[String] = []
	for skill_id in all_skill_classes.keys():
		if skill_id not in owned_skills:
			unowned.append(skill_id)
	return unowned

func add_skill_to_library(skill_id: String) -> bool:
	"""将技能添加到玩家的技能库"""
	if skill_id in all_skill_classes and skill_id not in owned_skills:
		owned_skills.append(skill_id)
		print("🎁 获得新技能: ", skill_id)
		return true
	return false

func auto_activate_skill(skill_id: String) -> int:
	"""自动激活技能到空闲槽位，返回激活的槽位索引，-1表示没有空闲槽位"""
	for i in range(4):
		if active_skills[i] == null:
			if swap_skill(i, skill_id):
				print("🔥 技能 ", skill_id, " 自动激活到槽位 ", i + 1)
				return i
			break
	return -1

func get_active_skill_count() -> int:
	"""获取当前激活的技能数量"""
	var count = 0
	for skill in active_skills:
		if skill != null:
			count += 1
	return count

func get_inactive_skills() -> Array:
	"""获取未激活的技能ID列表（从拥有的技能中）"""
	var inactive = []
	var active_skill_ids = get_active_skill_ids()
	
	for skill_id in owned_skills:
		if not skill_id in active_skill_ids:
			inactive.append(skill_id)
	return inactive

func get_active_skill_ids() -> Array:
	"""获取当前激活的技能ID列表"""
	var skill_ids = []
	for skill in active_skills:
		if skill:
			skill_ids.append(skill.skill_id)
	return skill_ids
