extends "res://scripts/CharacterBase.gd"

# 🎮 玩家角色类 - 基于新架构的玩家实现

## ========== 玩家特有属性 ==========

@export var experience: int = 0
@export var level: int = 1

# 输入相关
var input_enabled: bool = true

# 技能系统
var state_manager: PlayerStateManager  # 状态管理器
var skill_indicator: Node2D  # 技能指示器

# 相机系统
@onready var camera = $Camera2D

## ========== 信号 ==========

signal player_leveled_up(new_level: int)
signal experience_gained(amount: int)
signal player_died

## ========== 初始化 ==========

func _init():
	# 设置玩家角色基础属性
	character_type = CharacterType.PLAYER
	character_name = "玩家"
	is_controllable = true
	
	# 玩家属性
	max_health = 300
	health = 300
	max_mana = 200
	mana = 200
	base_speed = 200.0
	base_attack_damage = 25
	attack_range = 400.0
	attack_cooldown = 0.8
	mana_regen_rate = 5.0

func post_ready_setup() -> void:
	"""玩家特有的初始化"""
	super.post_ready_setup()
	
	# 设置技能管理器
	skill_manager = get_node_or_null("SkillManager")
	
	# 初始化状态管理器
	setup_state_manager()
	
	# 获取技能指示器引用
	skill_indicator = get_tree().current_scene.get_node_or_null("SkillIndicator")
	
	# 将玩家加入角色组
	add_to_group("characters")
	add_to_group("players")
	
	print("🎮 玩家角色初始化完成")

func setup_state_manager() -> void:
	"""设置玩家状态管理器"""
	# 直接使用preload，在编译时检查，导出后也能正常工作
	state_manager = PlayerStateManager.new(self)
	add_child(state_manager)
	print("✅ PlayerStateManager初始化完成")

## ========== 输入处理 ==========

func _input(event: InputEvent) -> void:
	# 调试：打印所有按键事件
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		print("🔍 按键事件: keycode=", event.keycode, " physical_keycode=", event.physical_keycode)
		print("  skill_1=", event.is_action("skill_1"), " pressed=", event.is_action_pressed("skill_1"))
		print("  input_enabled=", input_enabled, " is_dead=", is_dead, " is_stunned=", is_stunned)
	
	if not input_enabled or is_dead or is_stunned:
		return
	
	# 技能按键（使用输入映射，确保导出后正常工作）
	if event.is_action_pressed("skill_1"):
		print("✅ 技能1触发")
		state_manager.handle_skill_key_input(0)
	elif event.is_action_pressed("skill_2"):
		print("✅ 技能2触发")
		state_manager.handle_skill_key_input(1)
	elif event.is_action_pressed("skill_3"):
		print("✅ 技能3触发")
		state_manager.handle_skill_key_input(2)
	elif event.is_action_pressed("skill_4"):
		print("✅ 技能4触发")
		state_manager.handle_skill_key_input(3)
	
	# ESC键
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		state_manager.handle_escape_key()
	
	# 鼠标输入
	if event is InputEventMouseButton and event.pressed:
		handle_mouse_input(event)

func handle_mouse_input(event: InputEventMouseButton) -> void:
	"""处理鼠标输入"""
	var mouse_position = get_global_mouse_position()
	
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if not state_manager.handle_left_click(mouse_position):
				# 状态管理器没有处理，可以添加其他逻辑
				pass
		
		MOUSE_BUTTON_RIGHT:
			if not state_manager.handle_right_click(mouse_position):
				# 执行普攻
				perform_attack(mouse_position)

## ========== 移动系统重写 ==========

func handle_movement(_delta: float) -> void:
	"""处理玩家移动"""
	if not input_enabled:
		return
	
	# 获取输入
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	# 标准化输入
	input_vector = input_vector.normalized()
	
	# 应用移动
	velocity = input_vector * current_speed
	
	# 更新状态
	if velocity.length() > 0:
		change_state(CharacterState.MOVING)
	else:
		change_state(CharacterState.IDLE)

## ========== 攻击系统重写 ==========

func execute_attack(target_position: Vector2, _target: Node = null) -> void:
	"""执行玩家普攻"""
	print("⚔️ 玩家执行普攻到: ", target_position)
	
	# 创建普攻弹道
	create_basic_attack_projectile(target_position)
	
	# 改变状态
	change_state(CharacterState.ATTACKING)
	
	# 短暂攻击状态后返回空闲
	await get_tree().create_timer(0.3).timeout
	change_state(CharacterState.IDLE)

func create_basic_attack_projectile(target_pos: Vector2) -> void:
	"""创建普攻弹道"""
	var projectile = preload("res://Scenes/SkillEffect.tscn").instantiate()
	
	# 设置弹道属性
	projectile.position = position
	projectile.skill_type = "projectile"
	projectile.damage = current_attack_damage
	projectile.speed = 500
	projectile.max_distance = attack_range
	projectile.life_time = 3.0
	projectile.collision_layer = 8  # 玩家弹道层
	projectile.collision_mask = 5   # 检测敌人层(4) + 障碍物层(1) = 5
	projectile.source = self  # 设置伤害来源为玩家
	
	# 计算方向
	var direction = (target_pos - position).normalized()
	projectile.direction = direction
	
	# 添加到场景
	var skill_effects = get_tree().current_scene.get_node_or_null("SkillEffects")
	if skill_effects:
		skill_effects.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)
	
	# ✅ 在设置完所有属性并添加到场景后初始化
	projectile.initialize()
	call_deferred("set_projectile_color", projectile)

func set_projectile_color(projectile: Node) -> void:
	"""设置弹道颜色"""
	var projectile_sprite = projectile.get_node_or_null("Sprite2D")
	if projectile_sprite:
		projectile_sprite.modulate = Color.WHITE

## ========== 技能系统集成 ==========

func execute_skill_cast(skill_id: String, target_position: Vector2, _target: Node) -> bool:
	"""执行技能释放"""
	if not skill_manager:
		return false
	
	# 通过技能管理器释放技能
	# 这里需要根据实际的技能管理器接口调整
	print("🔮 玩家释放技能: ", skill_id, " 到: ", target_position)
	return true

## ========== 经验和等级系统 ==========

func gain_experience(amount: int) -> void:
	"""获得经验值"""
	experience += amount
	experience_gained.emit(amount)
	
	print("✨ 获得 ", amount, " 点经验值，当前经验: ", experience)
	
	# 检查升级
	check_level_up()

func check_level_up() -> void:
	"""检查升级"""
	var required_exp = get_required_experience_for_level(level + 1)
	
	if experience >= required_exp:
		level_up()

func level_up() -> void:
	"""升级"""
	level += 1
	
	# 升级奖励
	var health_bonus = 20
	var mana_bonus = 15
	
	max_health += health_bonus
	max_mana += mana_bonus
	health = max_health  # 升级时满血满蓝
	mana = max_mana
	
	print("🎉 玩家升级到 ", level, " 级! 生命值+", health_bonus, " 魔法值+", mana_bonus)
	player_leveled_up.emit(level)
	
	# 升级特效
	show_level_up_effect()

func get_required_experience_for_level(target_level: int) -> int:
	"""获取升级所需经验值"""
	return target_level * target_level * 100  # 简单的经验公式

func show_level_up_effect() -> void:
	"""显示升级特效"""
	var level_up_tween = create_tween()
	level_up_tween.parallel().tween_property(self, "modulate", Color.GOLD, 0.3)
	level_up_tween.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), 0.3)
	level_up_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	level_up_tween.tween_property(self, "scale", Vector2.ONE, 0.3)

## ========== 状态管理重写 ==========

func die() -> void:
	"""玩家死亡"""
	super.die()
	
	# 禁用输入
	input_enabled = false
	
	# 发出玩家死亡信号
	player_died.emit()

func respawn() -> void:
	"""玩家重生"""
	super.respawn()
	
	# 重新启用输入
	input_enabled = true
	
	# 移动到起始房间
	move_to_start_room()
	
	print("🎮 玩家重生完成")

func move_to_start_room() -> void:
	"""移动到起始房间"""
	var dungeon_generator = get_tree().current_scene.get_node_or_null("DungeonGenerator")
	if dungeon_generator:
		var start_room = dungeon_generator.rooms.get(Vector2i(0, 0))
		if start_room:
			# 将玩家移动到起始房间中心
			position = start_room.position + start_room.room_size / 2
			print("🏠 玩家重生到起始房间: ", start_room.room_id, " 位置: ", position)
			
			# 如果当前房间不是起始房间，切换到起始房间
			if dungeon_generator.current_room != start_room:
				dungeon_generator.change_to_new_room(start_room)
			else:
				# 如果已经在起始房间，确保房间状态正确
				dungeon_generator.current_room = start_room
				print("🔄 玩家已在起始房间，重置房间状态")

## ========== 相机管理 ==========

func set_camera_limits(room_position: Vector2, room_size: Vector2) -> void:
	"""设置相机限制（兼容性保留，实际由DungeonGenerator的全局限制管理）"""
	if camera:
		# 这个函数现在主要用于兼容性，实际的相机限制由DungeonGenerator统一设置
		print("📷 相机限制设置请求 - 房间位置: ", room_position, " 尺寸: ", room_size)
		print("📷 实际相机限制由DungeonGenerator的全局设置管理")

## ========== Buff系统集成 ==========

func apply_player_buff(buff_type: int, duration: float, strength: float = 1.0) -> void:
	"""为玩家应用Buff"""
	if buff_system:
		buff_system.apply_buff(buff_type, duration, strength)


func show_damage_number(amount: int, is_critical: bool = false) -> void:
	"""显示伤害数字"""
	var damage_label = Label.new()
	damage_label.script = preload("res://scripts/DamageNumber.gd")
	
	var ui_layer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(damage_label)
		
		var screen_pos = global_position
		if get_viewport().get_camera_2d():
			screen_pos = global_position
		
		damage_label.setup(amount, screen_pos + Vector2(0, -30), is_critical)

## ========== 调试方法 ==========

func get_debug_info() -> Dictionary:
	"""获取调试信息"""
	return {
		"health": str(health) + "/" + str(max_health),
		"mana": str(mana) + "/" + str(max_mana),
		"level": level,
		"experience": experience,
		"state": CharacterState.keys()[current_state],
		"buffs_count": buff_system.active_buffs.size() if buff_system else 0,
		"position": global_position,
		"velocity": velocity
	}
