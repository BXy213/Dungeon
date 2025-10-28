extends Button

var player = null
var skill_manager = null
var skill_index: int = 0

func _ready() -> void:
	# 延迟初始化，确保场景树完全准备好
	call_deferred("initialize_references")

func initialize_references() -> void:
	player = get_tree().get_first_node_in_group("players")
	if player:
		skill_manager = player.get_node_or_null("SkillManager")

func _pressed() -> void:
	if player and skill_manager:
		# 通过玩家的状态管理器处理技能选择
		if player.state_manager:
			player.state_manager.handle_skill_key_input(skill_index)
