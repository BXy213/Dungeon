@tool
class_name EncounterSpawnGroup
extends Resource

## Stable within an encounter. Changing this ID creates new member identities.
@export var group_id: StringName = &"frontline"
@export_enum("melee_soldier", "ranged_soldier", "elite_melee", "boss", "healer", "bomber", "splitter", "mini_splitter") var enemy_type: String = "melee_soldier"
## Optional scene for a new EnemyCharacter subtype, without editing the controller.
@export var enemy_scene: PackedScene
@export_range(1, 30, 1) var count: int = 3
@export var spawn_offset: Vector2 = Vector2.ZERO
@export_range(0, 400, 10) var spawn_radius: float = 120.0
@export_range(0.1, 10.0, 0.1) var health_multiplier: float = 1.0
@export_range(0.1, 10.0, 0.1) var damage_multiplier: float = 1.0
## Only the first member carries a key, even when count is greater than one.
@export var silver_key_holder: bool = false
