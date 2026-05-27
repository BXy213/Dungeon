class_name EnemyFactory
extends RefCounted

const ENEMY_MELEE_SOLDIER := "melee_soldier"
const ENEMY_RANGED_SOLDIER := "ranged_soldier"
const ENEMY_ELITE_MELEE := "elite_melee"
const ENEMY_BOSS := "boss"
const ENEMY_HEALER := "healer"
const ENEMY_BOMBER := "bomber"
const ENEMY_SPLITTER := "splitter"
const ENEMY_MINI_SPLITTER := "mini_splitter"

const LEGACY_TYPE_MELEE_SOLDIER := 0
const LEGACY_TYPE_RANGED_SOLDIER := 1
const LEGACY_TYPE_ELITE_MELEE := 2
const LEGACY_TYPE_BOSS := 3
const LEGACY_TYPE_HEALER := 4
const LEGACY_TYPE_BOMBER := 5
const LEGACY_TYPE_SPLITTER := 6
const LEGACY_TYPE_MINI_SPLITTER := 7

const _MeleeEnemyScript = preload("res://scripts/enemies/MeleeEnemy.gd")
const _RangedEnemyScript = preload("res://scripts/enemies/RangedEnemy.gd")
const _EliteEnemyScript = preload("res://scripts/enemies/EliteEnemy.gd")
const _BossEnemyScript = preload("res://scripts/enemies/BossEnemy.gd")
const _HealerEnemyScript = preload("res://scripts/enemies/HealerEnemy.gd")
const _BomberEnemyScript = preload("res://scripts/enemies/BomberEnemy.gd")
const _SplitterEnemyScript = preload("res://scripts/enemies/SplitterEnemy.gd")

static func create_enemy(enemy_type: String, room_id: Vector2i) -> Node:
	var normalized_type = normalize_enemy_type(enemy_type)
	match normalized_type:
		ENEMY_MELEE_SOLDIER:
			return _MeleeEnemyScript.create_melee_enemy(room_id)
		ENEMY_RANGED_SOLDIER:
			return _RangedEnemyScript.create_ranged_enemy(room_id)
		ENEMY_ELITE_MELEE:
			return _EliteEnemyScript.create_elite_enemy(room_id)
		ENEMY_BOSS:
			return _BossEnemyScript.create_boss_enemy(room_id)
		ENEMY_HEALER:
			return _HealerEnemyScript.create_healer_enemy(room_id)
		ENEMY_BOMBER:
			return _BomberEnemyScript.create_bomber_enemy(room_id)
		ENEMY_SPLITTER:
			return _SplitterEnemyScript.create_splitter_enemy(room_id)
		ENEMY_MINI_SPLITTER:
			return _SplitterEnemyScript.create_mini_splitter_enemy(room_id)
		_:
			push_warning("未知敌人类型: %s，默认创建近战小兵" % enemy_type)
			return _MeleeEnemyScript.create_melee_enemy(room_id)

static func normalize_enemy_type(enemy_type: String) -> String:
	match enemy_type:
		"elite_soldier":
			return ENEMY_ELITE_MELEE
		_:
			return enemy_type

static func from_legacy_type_id(enemy_type_id: int) -> String:
	match enemy_type_id:
		LEGACY_TYPE_MELEE_SOLDIER:
			return ENEMY_MELEE_SOLDIER
		LEGACY_TYPE_RANGED_SOLDIER:
			return ENEMY_RANGED_SOLDIER
		LEGACY_TYPE_ELITE_MELEE:
			return ENEMY_ELITE_MELEE
		LEGACY_TYPE_BOSS:
			return ENEMY_BOSS
		LEGACY_TYPE_HEALER:
			return ENEMY_HEALER
		LEGACY_TYPE_BOMBER:
			return ENEMY_BOMBER
		LEGACY_TYPE_SPLITTER:
			return ENEMY_SPLITTER
		LEGACY_TYPE_MINI_SPLITTER:
			return ENEMY_MINI_SPLITTER
		_:
			return ENEMY_MELEE_SOLDIER

static func to_legacy_type_id(enemy_type: String) -> int:
	match normalize_enemy_type(enemy_type):
		ENEMY_MELEE_SOLDIER:
			return LEGACY_TYPE_MELEE_SOLDIER
		ENEMY_RANGED_SOLDIER:
			return LEGACY_TYPE_RANGED_SOLDIER
		ENEMY_ELITE_MELEE:
			return LEGACY_TYPE_ELITE_MELEE
		ENEMY_BOSS:
			return LEGACY_TYPE_BOSS
		ENEMY_HEALER:
			return LEGACY_TYPE_HEALER
		ENEMY_BOMBER:
			return LEGACY_TYPE_BOMBER
		ENEMY_SPLITTER:
			return LEGACY_TYPE_SPLITTER
		ENEMY_MINI_SPLITTER:
			return LEGACY_TYPE_MINI_SPLITTER
		_:
			return LEGACY_TYPE_MELEE_SOLDIER

static func from_character_name(character_name: String) -> String:
	if "近战" in character_name:
		return ENEMY_MELEE_SOLDIER
	if "远程" in character_name:
		return ENEMY_RANGED_SOLDIER
	if "精英" in character_name:
		return ENEMY_ELITE_MELEE
	if "BOSS" in character_name or "Boss" in character_name:
		return ENEMY_BOSS
	if "治疗" in character_name:
		return ENEMY_HEALER
	if "自爆" in character_name:
		return ENEMY_BOMBER
	if "小分裂" in character_name:
		return ENEMY_MINI_SPLITTER
	if "分裂" in character_name:
		return ENEMY_SPLITTER
	return ENEMY_MELEE_SOLDIER
