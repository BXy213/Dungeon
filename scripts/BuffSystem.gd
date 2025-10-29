class_name BuffSystem
extends Node

# 📋 Buff状态系统 - 管理角色的所有状态效果

## Buff类型枚举
enum BuffType {
	SLOW,           # 减速
	STUN,           # 眩晕
	POISON,         # 中毒
	SILENCE,        # 沉默
	STRENGTHEN,     # 强化攻击
	SHIELD,         # 护盾
	REGENERATION,   # 生命回复
	MANA_REGEN,     # 魔法回复
	SPEED_BOOST,    # 加速
	DAMAGE_BOOST    # 伤害增幅
}

## Buff效果分类
enum BuffCategory {
	DEBUFF,         # 负面效果
	BUFF,           # 正面效果
	NEUTRAL         # 中性效果
}

## 当前生效的Buff列表
var active_buffs: Dictionary = {}  # {buff_id: BuffInstance}
var buff_counter: int = 0

## 引用
var owner_character: Node = null

## 信号
signal buff_applied(buff_instance: BuffInstance)
signal buff_removed(buff_instance: BuffInstance)
signal buff_updated(buff_instance: BuffInstance)

func _init(character: Node = null):
	owner_character = character

func _ready():
	# 每0.5秒更新一次所有Buff
	var update_timer = Timer.new()
	update_timer.wait_time = 0.5
	update_timer.timeout.connect(_update_all_buffs)
	update_timer.autostart = true
	add_child(update_timer)

## ========== Buff管理方法 ==========

func apply_buff(buff_type: BuffType, duration: float, strength: float = 1.0, source: Node = null) -> String:
	"""应用Buff效果"""
	var buff_id = "buff_" + str(buff_counter)
	buff_counter += 1
	
	var buff_instance = BuffInstance.new()
	buff_instance.setup(buff_id, buff_type, duration, strength, source)
	
	# 检查是否与现有Buff冲突或叠加
	var existing_buff = find_existing_buff(buff_type)
	if existing_buff:
		handle_buff_stacking(existing_buff, buff_instance)
	else:
		# 新Buff
		active_buffs[buff_id] = buff_instance
		_apply_buff_effect(buff_instance)
		var character_name = "角色"
		if owner_character:
			character_name = owner_character.name
		print("🔮 ", character_name, " 获得Buff: ", BuffType.keys()[buff_type], " (", duration, "s)")
		buff_applied.emit(buff_instance)
		
		# 显示浮动buff标签
		if owner_character and owner_character.has_method("show_floating_buff"):
			var buff_display_name = _get_buff_display_name(buff_type)
			var is_debuff = (get_buff_category(buff_type) == BuffCategory.DEBUFF)
			owner_character.show_floating_buff(buff_display_name, is_debuff)
	
	return buff_id

func remove_buff(buff_id: String) -> void:
	"""移除指定Buff"""
	if buff_id in active_buffs:
		var buff_instance = active_buffs[buff_id]
		_remove_buff_effect(buff_instance)
		active_buffs.erase(buff_id)
		var character_name = "角色"
		if owner_character:
			character_name = owner_character.name
		print("🔮 ", character_name, " 失去Buff: ", BuffType.keys()[buff_instance.buff_type])
		buff_removed.emit(buff_instance)

func clear_all_buffs() -> void:
	"""清除所有Buff"""
	for buff_id in active_buffs.keys():
		remove_buff(buff_id)

func clear_buffs_by_type(buff_type: BuffType) -> void:
	"""清除指定类型的所有Buff"""
	var buffs_to_remove = []
	for buff_id in active_buffs:
		if active_buffs[buff_id].buff_type == buff_type:
			buffs_to_remove.append(buff_id)
	
	for buff_id in buffs_to_remove:
		remove_buff(buff_id)

func clear_buffs_by_category(category: BuffCategory) -> void:
	"""清除指定分类的所有Buff"""
	var buffs_to_remove = []
	for buff_id in active_buffs:
		var buff_category = get_buff_category(active_buffs[buff_id].buff_type)
		if buff_category == category:
			buffs_to_remove.append(buff_id)
	
	for buff_id in buffs_to_remove:
		remove_buff(buff_id)

## ========== 查询方法 ==========

func has_buff(buff_type: BuffType) -> bool:
	"""检查是否有指定类型的Buff"""
	var buff = find_existing_buff(buff_type)
	return buff != null

func get_buff_strength(buff_type: BuffType) -> float:
	"""获取指定Buff的强度"""
	var buff = find_existing_buff(buff_type)
	if buff:
		return buff.strength
	return 0.0

func get_all_buffs() -> Array[BuffInstance]:
	"""获取所有生效的Buff"""
	var buffs: Array[BuffInstance] = []
	for buff in active_buffs.values():
		buffs.append(buff)
	return buffs

func get_buffs_by_category(category: BuffCategory) -> Array[BuffInstance]:
	"""获取指定分类的所有Buff"""
	var buffs: Array[BuffInstance] = []
	for buff in active_buffs.values():
		if get_buff_category(buff.buff_type) == category:
			buffs.append(buff)
	return buffs

## ========== 内部方法 ==========

func find_existing_buff(buff_type: BuffType) -> BuffInstance:
	"""查找现有的同类型Buff"""
	for buff in active_buffs.values():
		if buff.buff_type == buff_type:
			return buff
	return null

func handle_buff_stacking(existing: BuffInstance, new_buff: BuffInstance) -> void:
	"""处理Buff叠加逻辑"""
	match new_buff.buff_type:
		BuffType.POISON, BuffType.REGENERATION, BuffType.MANA_REGEN:
			# 叠加强度和持续时间
			existing.strength += new_buff.strength
			existing.remaining_time = max(existing.remaining_time, new_buff.duration)
		
		BuffType.SLOW, BuffType.SPEED_BOOST, BuffType.DAMAGE_BOOST:
			# 取最大强度，重置持续时间
			if new_buff.strength > existing.strength:
				existing.strength = new_buff.strength
			existing.remaining_time = new_buff.duration
		
		BuffType.STUN, BuffType.SILENCE:
			# 延长持续时间
			existing.remaining_time += new_buff.duration
		
		_:
			# 默认：替换为新的Buff
			existing.strength = new_buff.strength
			existing.remaining_time = new_buff.duration
	
	print("🔄 Buff叠加: ", BuffType.keys()[new_buff.buff_type], " 强度:", existing.strength, " 时间:", existing.remaining_time)
	buff_updated.emit(existing)

func _update_all_buffs() -> void:
	"""更新所有Buff的持续时间和效果"""
	var expired_buffs = []
	
	for buff_id in active_buffs:
		var buff = active_buffs[buff_id]
		buff.remaining_time -= 0.5
		
		# 执行持续效果
		_apply_continuous_effect(buff)
		
		# 检查是否过期
		if buff.remaining_time <= 0:
			expired_buffs.append(buff_id)
	
	# 移除过期的Buff
	for buff_id in expired_buffs:
		remove_buff(buff_id)

func _apply_buff_effect(buff: BuffInstance) -> void:
	"""应用Buff效果"""
	if not owner_character:
		return
	
	match buff.buff_type:
		BuffType.SLOW:
			# 减速效果 - 降低移动速度
			if owner_character:
				var new_speed = owner_character.base_speed * (1.0 - buff.strength)
				owner_character.current_speed = new_speed
				print("  🐌 减速效果生效: ", owner_character.base_speed, " → ", new_speed, " (减速", int(buff.strength * 100), "%)")
		
		BuffType.STUN:
			# 眩晕效果
			if owner_character:
				owner_character.is_stunned = true
		
		BuffType.SILENCE:
			# 沉默效果
			if owner_character:
				owner_character.is_silenced = true
		
		BuffType.STRENGTHEN:
			# 攻击强化 - 直接修改攻击力
			if owner_character:
				owner_character.current_attack_damage = int(owner_character.base_attack_damage * (1.0 + buff.strength))
		
		BuffType.DAMAGE_BOOST:
			# 伤害增幅 - 提升攻击力（和STRENGTHEN相同）
			if owner_character:
				owner_character.current_attack_damage = int(owner_character.base_attack_damage * (1.0 + buff.strength))
		
		BuffType.SPEED_BOOST:
			# 加速效果 - 直接修改速度
			if owner_character:
				owner_character.current_speed = owner_character.base_speed * (1.0 + buff.strength)

func _remove_buff_effect(buff: BuffInstance) -> void:
	"""移除Buff效果"""
	if not owner_character:
		return
	
	match buff.buff_type:
		BuffType.SLOW:
			# 恢复速度
			if owner_character:
				owner_character.current_speed = owner_character.base_speed
				print("  🏃 减速效果移除，速度恢复: ", owner_character.current_speed)
		
		BuffType.STUN:
			# 取消眩晕
			if owner_character:
				owner_character.is_stunned = false
		
		BuffType.SILENCE:
			# 取消沉默
			if owner_character:
				owner_character.is_silenced = false
		
		BuffType.STRENGTHEN:
			# 恢复攻击力
			if owner_character:
				owner_character.current_attack_damage = owner_character.base_attack_damage
		
		BuffType.DAMAGE_BOOST:
			# 恢复攻击力
			if owner_character:
				owner_character.current_attack_damage = owner_character.base_attack_damage
		
		BuffType.SPEED_BOOST:
			# 恢复速度
			if owner_character:
				owner_character.current_speed = owner_character.base_speed

func _apply_continuous_effect(buff: BuffInstance) -> void:
	"""应用持续性效果（每0.5秒触发）"""
	if not owner_character:
		return
	
	match buff.buff_type:
		BuffType.POISON:
			# 中毒伤害
			if owner_character.has_method("take_damage"):
				var damage = int(buff.strength * 5)  # 每0.5秒造成强度*5的伤害
				owner_character.take_damage(damage)
				print("💚 中毒伤害: ", damage)
		
		BuffType.REGENERATION:
			# 生命回复
			if owner_character.has_method("heal"):
				var heal_amount = int(buff.strength * 10)  # 每0.5秒回复强度*10的生命
				owner_character.heal(heal_amount)
		
		BuffType.MANA_REGEN:
			# 魔法回复
			if owner_character.has_method("restore_mana"):
				var mana_amount = int(buff.strength * 8)  # 每0.5秒回复强度*8的魔法
				owner_character.restore_mana(mana_amount)

func get_buff_category(buff_type: BuffType) -> BuffCategory:
	"""获取Buff的分类"""
	match buff_type:
		BuffType.SLOW, BuffType.STUN, BuffType.POISON, BuffType.SILENCE:
			return BuffCategory.DEBUFF
		BuffType.STRENGTHEN, BuffType.SHIELD, BuffType.REGENERATION, BuffType.MANA_REGEN, BuffType.SPEED_BOOST, BuffType.DAMAGE_BOOST:
			return BuffCategory.BUFF
		_:
			return BuffCategory.NEUTRAL

func _get_buff_display_name(buff_type: BuffType) -> String:
	"""获取Buff的显示名称"""
	match buff_type:
		BuffType.SLOW:
			return "减速"
		BuffType.STUN:
			return "眩晕"
		BuffType.POISON:
			return "中毒"
		BuffType.SILENCE:
			return "沉默"
		BuffType.STRENGTHEN:
			return "强化"
		BuffType.SHIELD:
			return "护盾"
		BuffType.REGENERATION:
			return "生命回复"
		BuffType.MANA_REGEN:
			return "魔力回复"
		BuffType.SPEED_BOOST:
			return "加速"
		BuffType.DAMAGE_BOOST:
			return "增伤"
		_:
			return "未知"

## ========== BuffInstance 内部类 ==========

class BuffInstance:
	var buff_id: String
	var buff_type: BuffSystem.BuffType
	var duration: float
	var remaining_time: float
	var strength: float
	var source: Node = null
	var stack_count: int = 1
	
	func setup(id: String, type: BuffSystem.BuffType, dur: float, strength_value: float, src: Node = null):
		buff_id = id
		buff_type = type
		duration = dur
		remaining_time = dur
		strength = strength_value
		source = src
	
	func get_progress() -> float:
		"""获取Buff进度（0.0-1.0）"""
		return 1.0 - (remaining_time / duration) if duration > 0 else 0.0
	
	func get_display_name() -> String:
		"""获取显示名称"""
		return BuffSystem.BuffType.keys()[buff_type]
	
	func get_description() -> String:
		"""获取Buff描述"""
		match buff_type:
			BuffSystem.BuffType.SLOW:
				return "移动速度降低 " + str(int(strength * 100)) + "%"
			BuffSystem.BuffType.STUN:
				return "无法移动和攻击"
			BuffSystem.BuffType.POISON:
				return "每秒受到 " + str(int(strength * 10)) + " 点伤害"
			BuffSystem.BuffType.SILENCE:
				return "无法使用技能"
			BuffSystem.BuffType.STRENGTHEN:
				return "攻击力提升 " + str(int(strength * 100)) + "%"
			BuffSystem.BuffType.REGENERATION:
				return "每秒回复 " + str(int(strength * 20)) + " 点生命"
			BuffSystem.BuffType.SPEED_BOOST:
				return "移动速度提升 " + str(int(strength * 100)) + "%"
			_:
				return "未知效果"
