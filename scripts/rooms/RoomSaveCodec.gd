class_name RoomSaveCodec
extends RefCounted

const EnemyTypes = preload("res://scripts/factories/EnemyFactory.gd")

static func create_obstacle_data(obstacle: Node) -> Dictionary:
	return {
		"type": obstacle.get_obstacle_type(),
		"position": obstacle.position
	}

static func create_enemy_data(enemy: Node) -> Dictionary:
	var enemy_type_id = EnemyTypes.from_character_name(enemy.character_name)
	return {
		"character_name": enemy.character_name,
		"position": enemy.position,
		"health": enemy.health,
		"max_health": enemy.max_health,
		"is_dead": enemy.is_dead,
		"has_silverkey": bool(enemy.has_silverkey) if "has_silverkey" in enemy else false,
		"is_mini_split": _is_mini_split_enemy(enemy),
		"enemy_type_id": enemy_type_id,
		"enemy_type": EnemyTypes.to_legacy_type_id(enemy_type_id)
	}

static func is_saved_enemy_alive(enemy_data: Dictionary) -> bool:
	return not bool(enemy_data.get("is_dead", false))

static func get_enemy_type_id(enemy_data: Dictionary) -> String:
	if _is_mini_split_data(enemy_data):
		return EnemyTypes.ENEMY_MINI_SPLITTER
	
	if enemy_data.has("enemy_type_id"):
		return EnemyTypes.normalize_enemy_type(str(enemy_data["enemy_type_id"]))
	
	if enemy_data.has("enemy_type"):
		return EnemyTypes.from_legacy_type_id(int(enemy_data["enemy_type"]))
	
	return EnemyTypes.from_character_name(str(enemy_data.get("character_name", "")))

static func _is_mini_split_enemy(enemy: Node) -> bool:
	return "is_mini_split" in enemy and enemy.is_mini_split

static func _is_mini_split_data(enemy_data: Dictionary) -> bool:
	if bool(enemy_data.get("is_mini_split", false)):
		return true
	
	var character_name = str(enemy_data.get("character_name", ""))
	if "小分裂" in character_name:
		return true
	
	var type_id = str(enemy_data.get("enemy_type_id", ""))
	var max_health = int(enemy_data.get("max_health", 0))
	return type_id == EnemyTypes.ENEMY_SPLITTER and max_health > 0 and max_health <= 30
