class_name EnemyFactory
extends RefCounted

const TYPES := {
	"melee_soldier": preload("res://scripts/enemies/MeleeEnemy.gd"),
	"ranged_soldier": preload("res://scripts/enemies/RangedEnemy.gd"),
	"elite_melee": preload("res://scripts/enemies/EliteEnemy.gd"),
	"boss": preload("res://scripts/enemies/BossEnemy.gd"),
	"healer": preload("res://scripts/enemies/HealerEnemy.gd"),
	"bomber": preload("res://scripts/enemies/BomberEnemy.gd"),
	"splitter": preload("res://scripts/enemies/SplitterEnemy.gd"),
	"mini_splitter": preload("res://scripts/enemies/SplitterEnemy.gd")
}

static func create_enemy(enemy_type: String) -> EnemyCharacter:
	if not TYPES.has(enemy_type):
		push_error("Unknown enemy type: %s" % enemy_type)
		return null
	var enemy: EnemyCharacter = TYPES[enemy_type].new()
	if enemy_type == "mini_splitter":
		enemy.is_mini_split = true
		enemy.apply_mini_split_stats()
	return enemy
