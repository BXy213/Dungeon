class_name EnemySpawnPlanner
extends RefCounted

const EnemyTypes = preload("res://scripts/factories/EnemyFactory.gd")

static func determine_enemy_types(room_id: Vector2i, dungeon_width: int, dungeon_height: int) -> Array[String]:
	"""根据房间位置确定敌人类型"""
	var enemies_to_spawn: Array[String] = []
	
	# 最右下角的房间 - 只刷新一个BOSS
	if room_id == Vector2i(dungeon_width - 1, dungeon_height - 1):
		enemies_to_spawn.append(EnemyTypes.ENEMY_BOSS)
		print("🏆 BOSS房间: ", room_id)
		return enemies_to_spawn
	
	var distance_from_start = abs(room_id.x) + abs(room_id.y)
	
	if distance_from_start <= 1:
		_add_basic_enemy_wave(enemies_to_spawn, randi() % 3 + 3)
		print("🥉 早期房间: ", room_id, " 距离起始点: ", distance_from_start, " 敌人数: ", enemies_to_spawn.size())
	elif distance_from_start <= 3:
		_add_basic_enemy_wave(enemies_to_spawn, randi() % 3 + 6)
		print("🥉 早期房间: ", room_id, " 距离起始点: ", distance_from_start, " 敌人数: ", enemies_to_spawn.size())
	else:
		_add_mixed_enemy_wave(enemies_to_spawn, randi() % 3 + 8)
		print("⭐ 后期房间: ", room_id, " 距离起始点: ", distance_from_start, " 敌人数: ", enemies_to_spawn.size())
	
	return enemies_to_spawn

static func _add_basic_enemy_wave(enemies_to_spawn: Array[String], enemy_count: int) -> void:
	for i in range(enemy_count):
		var rand = randf()
		if rand < 0.5:
			enemies_to_spawn.append(EnemyTypes.ENEMY_MELEE_SOLDIER)
		elif rand < 0.85:
			enemies_to_spawn.append(EnemyTypes.ENEMY_RANGED_SOLDIER)
		else:
			enemies_to_spawn.append(EnemyTypes.ENEMY_BOMBER)

static func _add_mixed_enemy_wave(enemies_to_spawn: Array[String], enemy_count: int) -> void:
	var has_elite = false
	var has_healer = false
	
	for i in range(enemy_count):
		if i == 0 and randf() < 0.8:
			enemies_to_spawn.append(EnemyTypes.ENEMY_ELITE_MELEE)
			has_elite = true
			continue
		
		if i == 1 and randf() < 0.6:
			enemies_to_spawn.append(EnemyTypes.ENEMY_HEALER)
			has_healer = true
			continue
		
		var rand = randf()
		if rand < 0.3:
			enemies_to_spawn.append(EnemyTypes.ENEMY_MELEE_SOLDIER)
		elif rand < 0.5:
			enemies_to_spawn.append(EnemyTypes.ENEMY_RANGED_SOLDIER)
		elif rand < 0.65:
			enemies_to_spawn.append(EnemyTypes.ENEMY_BOMBER)
		elif rand < 0.8:
			enemies_to_spawn.append(EnemyTypes.ENEMY_SPLITTER)
		elif not has_elite and rand < 0.9:
			enemies_to_spawn.append(EnemyTypes.ENEMY_ELITE_MELEE)
			has_elite = true
		elif not has_healer:
			enemies_to_spawn.append(EnemyTypes.ENEMY_HEALER)
			has_healer = true
		else:
			enemies_to_spawn.append(EnemyTypes.ENEMY_MELEE_SOLDIER)
