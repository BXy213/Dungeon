@tool
class_name EncounterConfig
extends Resource

enum ResetPolicy { PARTIAL_PERSIST, FULL_RESET, NO_RESET }

@export var display_name: String = "Camp"
@export_range(1, 10, 1) var threat_level: int = 1
@export var spawn_groups: Array[EncounterSpawnGroup] = []
## Measured from the EncounterPoint origin, independently of chunk boundaries.
@export_range(100, 2000, 10) var activation_radius: float = 650.0
@export_range(100, 2500, 10) var leash_radius: float = 850.0
@export_range(100, 3000, 10) var reset_radius: float = 1000.0
@export_range(0, 10, 0.5) var reset_delay: float = 2.0
@export var reset_policy: ResetPolicy = ResetPolicy.PARTIAL_PERSIST
@export var reward_chest: bool = true
@export_range(0, 1000, 10) var clear_experience: int = 40
@export var is_final_objective: bool = false

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if spawn_groups.is_empty():
		errors.append("At least one spawn group is required.")
	if activation_radius <= 0 or activation_radius >= leash_radius or leash_radius >= reset_radius:
		errors.append("Radii must satisfy 0 < activation < leash < reset.")
	var ids: Dictionary = {}
	for group in spawn_groups:
		if group == null:
			errors.append("Spawn group must not be null.")
			continue
		if group.group_id.is_empty() or ids.has(group.group_id):
			errors.append("Spawn group IDs must be nonempty and unique.")
		ids[group.group_id] = true
		if group.count < 1 or group.spawn_radius < 0 or group.health_multiplier <= 0 or group.damage_multiplier <= 0:
			errors.append("Invalid count, radius, or stat multiplier.")
		if group.enemy_scene == null and group.enemy_type not in ["melee_soldier", "ranged_soldier", "elite_melee", "boss", "healer", "bomber", "splitter", "mini_splitter"]:
			errors.append("Unknown enemy_type: %s" % group.enemy_type)
		if group.spawn_offset.length() + group.spawn_radius + 48 >= activation_radius:
			errors.append("Spawn positions must fit inside the activation radius.")
	return errors
