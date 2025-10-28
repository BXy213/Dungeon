class_name CharacterBase
extends CharacterBody2D

# 🎭 角色基类 - 玩家和敌人的共同基础

## 角色类型枚举
enum CharacterType {
	PLAYER,         # 玩家角色
	ENEMY,          # 敌人角色
	NPC             # NPC角色
}

## 角色状态枚举
enum CharacterState {
	IDLE,           # 空闲
	MOVING,         # 移动中
	ATTACKING,      # 攻击中
	CASTING_SKILL,  # 释放技能中
	STUNNED,        # 被眩晕
	DEAD            # 死亡
}

## ========== 基础属性 ==========

@export var character_type: CharacterType = CharacterType.PLAYER
@export var character_name: String = "角色"

# 生命值系统
@export var max_health: int = 100
@export var health: int = 100
@export var health_regen_rate: float = 0.0  # 每秒生命回复

# 魔法值系统
@export var max_mana: int = 100
@export var mana: int = 100
@export var mana_regen_rate: float = 5.0  # 每秒魔法回复

# 移动系统
@export var base_speed: float = 200.0
@export var current_speed: float = 200.0

# 攻击系统
@export var base_attack_damage: int = 25
@export var current_attack_damage: int = 25
@export var attack_range: float = 400.0
@export var attack_cooldown: float = 1.0

# 防御系统
@export var base_defense: int = 0
@export var current_defense: int = 0

## ========== 状态管理 ==========

var current_state: CharacterState = CharacterState.IDLE
var is_controllable: bool = true  # 是否可控制（玩家专用）
var is_stunned: bool = false
var is_silenced: bool = false
var is_dead: bool = false

## ========== 系统组件 ==========

var buff_system: Node  # BuffSystem type will be available at runtime
var skill_manager: Node = null

# UI组件 - 假设存在，如果没有会在运行时安全检查
@onready var sprite: Node = get_node_or_null("Sprite2D")

## ========== 计时器和冷却 ==========

var attack_ready: bool = true
var regen_timer: Timer

## ========== 信号 ==========

signal health_changed(old_value: int, new_value: int)
signal mana_changed(old_value: int, new_value: int)
signal character_died(character: CharacterBase)
signal character_respawned(character: CharacterBase)
signal state_changed(old_state: CharacterState, new_state: CharacterState)
signal damage_taken(amount: int, source: Node)

## ========== 初始化 ==========

func _ready() -> void:
	setup_character()
	setup_timers()
	setup_buff_system()
	call_deferred("post_ready_setup")

func setup_character() -> void:
	"""设置角色基础属性"""
	current_speed = base_speed
	current_attack_damage = base_attack_damage
	current_defense = base_defense

func setup_timers() -> void:
	"""设置计时器"""
	# 生命和魔法回复计时器
	regen_timer = Timer.new()
	regen_timer.wait_time = 1.0
	regen_timer.timeout.connect(_on_regen_tick)
	regen_timer.autostart = true
	add_child(regen_timer)

func setup_buff_system() -> void:
	"""设置Buff系统"""
	var BuffSystemClass = preload("res://scripts/BuffSystem.gd")
	buff_system = BuffSystemClass.new(self)
	add_child(buff_system)
	
	# 连接Buff信号
	buff_system.buff_applied.connect(_on_buff_applied)
	buff_system.buff_removed.connect(_on_buff_removed)

func post_ready_setup() -> void:
	"""延迟初始化（子类可重写）"""
	pass

## ========== 移动系统 ==========

func _physics_process(delta: float) -> void:
	if is_dead or is_stunned:
		velocity = Vector2.ZERO
	else:
		handle_movement(delta)
	
	move_and_slide()

func handle_movement(_delta: float) -> void:
	"""处理移动逻辑（子类重写）"""
	pass

func move_towards(target_position: Vector2, speed_multiplier: float = 1.0) -> void:
	"""向目标位置移动"""
	if is_stunned or is_dead:
		return
	
	var direction = (target_position - global_position).normalized()
	velocity = direction * current_speed * speed_multiplier

func stop_movement() -> void:
	"""停止移动"""
	velocity = Vector2.ZERO

## ========== 生命值系统 ==========

func take_damage(amount: int, source: Node = null) -> void:
	"""受到伤害"""
	if is_dead:
		return
	
	# 计算实际伤害（考虑防御）
	var actual_damage = max(1, amount - current_defense)
	var old_health = health
	
	health -= actual_damage
	health = max(0, health)
	
	print("💔 ", character_name, " 受到 ", actual_damage, " 点伤害，剩余血量: ", health)
	
	# 发出信号
	health_changed.emit(old_health, health)
	damage_taken.emit(actual_damage, source)
	
	# 视觉反馈
	show_damage_effect(actual_damage)
	
	# 检查死亡
	if health <= 0:
		die()

func heal(amount: int) -> void:
	"""治疗"""
	if is_dead:
		return
	
	var old_health = health
	health += amount
	health = min(health, max_health)
	
	var actual_heal = health - old_health
	if actual_heal > 0:
		print("💚 ", character_name, " 恢复 ", actual_heal, " 点生命值，当前血量: ", health)
		health_changed.emit(old_health, health)
		show_heal_effect(actual_heal)

func set_max_health(new_max: int) -> void:
	"""设置最大生命值"""
	var health_ratio = float(health) / float(max_health) if max_health > 0 else 1.0
	max_health = new_max
	health = int(max_health * health_ratio)
	health_changed.emit(health, health)

## ========== 魔法值系统 ==========

func use_mana(amount: int) -> bool:
	"""消耗魔法值"""
	if mana < amount:
		print("🔵 ", character_name, " 魔法值不足")
		return false
	
	var old_mana = mana
	mana -= amount
	mana_changed.emit(old_mana, mana)
	return true

func restore_mana(amount: int) -> void:
	"""恢复魔法值"""
	var old_mana = mana
	mana += amount
	mana = min(mana, max_mana)
	
	var actual_restore = mana - old_mana
	if actual_restore > 0:
		mana_changed.emit(old_mana, mana)

## ========== 攻击系统 ==========

func can_attack() -> bool:
	"""检查是否可以攻击"""
	return attack_ready and not is_stunned and not is_dead

func perform_attack(target_position: Vector2, target: Node = null) -> bool:
	"""执行攻击（子类重写具体实现）"""
	if not can_attack():
		return false
	
	# 检查攻击距离
	var distance = global_position.distance_to(target_position)
	if distance > attack_range:
		print("⚔️ ", character_name, " 攻击距离过远")
		return false
	
	# 开始攻击冷却
	start_attack_cooldown()
	
	# 改变状态
	change_state(CharacterState.ATTACKING)
	
	# 子类实现具体攻击逻辑
	execute_attack(target_position, target)
	
	return true

func execute_attack(_target_position: Vector2, _target: Node = null) -> void:
	"""执行攻击效果（子类重写）"""
	print("⚔️ ", character_name, " 执行基础攻击")

func start_attack_cooldown() -> void:
	"""开始攻击冷却"""
	attack_ready = false
	var cooldown_timer = Timer.new()
	cooldown_timer.wait_time = attack_cooldown
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(func():
		attack_ready = true
		cooldown_timer.queue_free()
	)
	add_child(cooldown_timer)
	cooldown_timer.start()

## ========== 技能系统 ==========

func can_cast_skill() -> bool:
	"""检查是否可以释放技能"""
	return not is_silenced and not is_stunned and not is_dead

func cast_skill(skill_id: String, target_position: Vector2 = Vector2.ZERO, target: Node = null) -> bool:
	"""释放技能（需要skill_manager支持）"""
	if not can_cast_skill():
		print("🚫 ", character_name, " 无法释放技能")
		return false
	
	if not skill_manager:
		print("❌ ", character_name, " 没有技能管理器")
		return false
	
	# 子类实现具体技能释放逻辑
	return execute_skill_cast(skill_id, target_position, target)

func execute_skill_cast(_skill_id: String, _target_position: Vector2, _target: Node) -> bool:
	"""执行技能释放（子类重写）"""
	return false

## ========== 状态管理 ==========

func change_state(new_state: CharacterState) -> void:
	"""改变角色状态"""
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)

func set_stunned(stunned: bool) -> void:
	"""设置眩晕状态"""
	is_stunned = stunned
	if stunned:
		change_state(CharacterState.STUNNED)
		velocity = Vector2.ZERO
	else:
		change_state(CharacterState.IDLE)

func set_silenced(silenced: bool) -> void:
	"""设置沉默状态"""
	is_silenced = silenced

## ========== 属性修改系统（Buff支持） ==========

func modify_speed(multiplier: float) -> void:
	"""修改移动速度"""
	current_speed = base_speed * multiplier

func modify_damage(multiplier: float) -> void:
	"""修改攻击伤害"""
	current_attack_damage = int(base_attack_damage * multiplier)

func modify_defense(amount: int) -> void:
	"""修改防御力"""
	current_defense = base_defense + amount

func reset_speed() -> void:
	"""重置移动速度"""
	current_speed = base_speed

func reset_damage() -> void:
	"""重置攻击伤害"""
	current_attack_damage = base_attack_damage

func reset_defense() -> void:
	"""重置防御力"""
	current_defense = base_defense

## ========== 死亡和重生系统 ==========

func die() -> void:
	"""死亡"""
	if is_dead:
		return
	
	is_dead = true
	change_state(CharacterState.DEAD)
	
	print("💀 ", character_name, " 死亡!")
	
	# 检查是否是BOSS
	if character_name == "BOSS":
		print("🎉 检测到BOSS死亡！")
		var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
		if game_manager and game_manager.has_method("_on_boss_defeated"):
			game_manager._on_boss_defeated()
	
	# 清除所有Buff
	if buff_system:
		buff_system.clear_all_buffs()
	
	# 停止移动
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# 播放死亡效果
	play_death_effect()
	
	# 发出死亡信号
	character_died.emit(self)

func respawn() -> void:
	"""重生"""
	if not is_dead:
		return
	
	# 重置状态
	is_dead = false
	health = max_health
	mana = max_mana
	attack_ready = true
	
	# 重设外观
	modulate = Color.WHITE
	scale = Vector2.ONE
	
	# 重新启用物理处理
	set_physics_process(true)
	
	# 改变状态
	change_state(CharacterState.IDLE)
	
	print("✨ ", character_name, " 重生!")
	character_respawned.emit(self)

## ========== 视觉效果系统 ==========

func show_damage_effect(_amount: int) -> void:
	"""显示受伤效果（默认实现，子类可重写）"""
	# 基础闪烁效果 - 使用更温和的效果
	var damage_tween = create_tween()
	damage_tween.tween_property(self, "modulate", Color(1.0, 0.8, 0.8, 1.0), 0.08)
	damage_tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	
	# 震动效果
	create_shake_effect()

func show_heal_effect(_amount: int) -> void:
	"""显示治疗效果"""
	var heal_tween = create_tween()
	heal_tween.tween_property(self, "modulate", Color.GREEN, 0.2)
	heal_tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func create_shake_effect() -> void:
	"""创建震动效果"""
	var original_pos = position
	var shake_tween = create_tween()
	for i in range(3):
		var offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		shake_tween.tween_property(self, "position", original_pos + offset, 0.05)
	shake_tween.tween_property(self, "position", original_pos, 0.05)

func play_death_effect() -> void:
	"""播放死亡效果"""
	var death_tween = create_tween()
	death_tween.parallel().tween_property(self, "modulate:a", 0.3, 0.5)
	death_tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.5)

## ========== 回调方法 ==========

func _on_regen_tick() -> void:
	"""生命和魔法回复计时器回调"""
	if is_dead:
		return
	
	# 生命回复
	if health_regen_rate > 0 and health < max_health:
		heal(int(health_regen_rate))
	
	# 魔法回复
	if mana_regen_rate > 0 and mana < max_mana:
		restore_mana(int(mana_regen_rate))

func _on_buff_applied(buff_instance) -> void:
	"""Buff应用回调"""
	print("🔮 ", character_name, " 获得Buff: ", buff_instance.get_display_name())

func _on_buff_removed(buff_instance) -> void:
	"""Buff移除回调"""
	print("🔮 ", character_name, " 失去Buff: ", buff_instance.get_display_name())

## ========== 工具方法 ==========

func get_distance_to(target: Node2D) -> float:
	"""获取到目标的距离"""
	return global_position.distance_to(target.global_position)

func is_in_range_of(target: Node2D, check_range: float) -> bool:
	"""检查是否在目标范围内"""
	return get_distance_to(target) <= check_range

func get_direction_to(target: Node2D) -> Vector2:
	"""获取到目标的方向"""
	return (target.global_position - global_position).normalized()

func get_health_percentage() -> float:
	"""获取生命值百分比"""
	return float(health) / float(max_health)

func get_debug_info() -> Dictionary:
	"""获取调试信息（基础实现）"""
	return {
		"character_name": character_name,
		"character_type": str(character_type),
		"health": str(health) + "/" + str(max_health),
		"mana": str(mana) + "/" + str(max_mana),
		"position": str(global_position),
		"state": str(current_state),
		"is_dead": is_dead,
		"is_stunned": is_stunned,
	}

func get_mana_percentage() -> float:
	"""获取魔法值百分比"""
	return float(mana) / float(max_mana) if max_mana > 0 else 0.0
