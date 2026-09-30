@tool
class_name EncounterPoint
extends Node2D

enum State { DORMANT, ACTIVE, LEASHING, RESETTING, CLEARED }
const Factory = preload("res://scripts/factories/EnemyFactory.gd")

## Unique per placed point, separate from the reusable configuration resource.
@export var encounter_id: StringName = &"camp_01"
@export var config: EncounterConfig
@export var preview_radius: bool = false:
	set(value):
		preview_radius = value
		queue_redraw()

signal changed(point: EncounterPoint)
signal enemy_killed(point: EncounterPoint)
signal completed(point: EncounterPoint)

var state: State = State.DORMANT
var world: Node
var record: Dictionary = {}
var enemies: Dictionary = {}
var initialized := false
var enabled := false
var pending_spawns := 0
var spawn_failed := false
var outside_time := 0.0
var reward_node: Node2D

func _get_configuration_warnings() -> PackedStringArray:
	var errors := PackedStringArray()
	if encounter_id.is_empty():
		errors.append("Set a unique encounter_id for this placed point.")
	if config == null:
		errors.append("Assign an EncounterConfig resource.")
	else:
		errors.append_array(config.validate())
	return errors

func _ready() -> void:
	queue_redraw()

func setup(manager: Node, data: Dictionary) -> bool:
	world = manager
	record = data
	var errors := _get_configuration_warnings()
	if not errors.is_empty():
		push_error("Encounter %s: %s" % [encounter_id, "; ".join(errors)])
		return false
	enabled = true
	if record.cleared:
		state = State.CLEARED
	queue_redraw()
	return true

func update_encounter(player: Node2D, delta: float) -> void:
	if not enabled or not is_instance_valid(player) or player.is_dead:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance < config.activation_radius + 200 and not record.discovered:
		record.discovered = true
		changed.emit(self)
	if state == State.CLEARED:
		return
	match state:
		State.DORMANT:
			if distance <= config.activation_radius:
				activate()
		State.ACTIVE:
			if distance > config.leash_radius:
				begin_return()
		State.LEASHING:
			if distance > config.reset_radius:
				outside_time += delta
			else:
				outside_time = 0.0
			if all_at_home():
				if distance <= config.activation_radius:
					activate()
				elif outside_time >= config.reset_delay:
					reset_encounter()

func activate() -> void:
	if not enabled or state == State.CLEARED:
		return
	_set_state(State.ACTIVE)
	if not initialized:
		initialized = true
		for group in config.spawn_groups:
			for index in range(group.count):
				var id := "%s/%d" % [group.group_id, index]
				if record.dead_members.has(id):
					continue
				var angle := TAU * float(index) / float(group.count)
				var offset := group.spawn_offset + Vector2.from_angle(angle) * group.spawn_radius
				_spawn_member(group.enemy_type, id, global_position + offset, group)
	for enemy in enemies.values():
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
			enemy.encounter_returning = false
			enemy.modulate = Color.WHITE
	outside_time = 0
	changed.emit(self)

func _spawn_member(type_id: String, member_id: String, desired: Vector2, group: EncounterSpawnGroup = null) -> void:
	var candidate: Node = group.enemy_scene.instantiate() if group != null and group.enemy_scene != null else Factory.create_enemy(type_id)
	if not candidate is EnemyCharacter:
		if is_instance_valid(candidate):
			candidate.free()
		spawn_failed = true
		push_error("Encounter %s requires EnemyCharacter scenes." % encounter_id)
		return
	var enemy := candidate as EnemyCharacter
	var spot: Vector2 = world.find_spawn_position(desired, global_position)
	if not spot.is_finite():
		enemy.free()
		spawn_failed = true
		push_error("Encounter %s has no reachable spawn position." % encounter_id)
		return
	if group != null:
		enemy.max_health = maxi(1, roundi(enemy.max_health * group.health_multiplier))
		enemy.health = enemy.max_health
		enemy.base_attack_damage = maxi(1, roundi(enemy.base_attack_damage * group.damage_multiplier))
		enemy.has_silverkey = group.silver_key_holder and member_id.ends_with("/0")
	else:
		# Summons contribute to the encounter, but are not an infinite XP source.
		enemy.experience_reward = 0
		enemy.loot_chance = 0
	enemy.encounter_owner = self
	enemy.encounter_member_id = member_id
	enemy.collision_layer = 4
	enemy.collision_mask = 3
	enemy.position = to_local(spot)
	enemy.home_position = spot
	enemy.character_died.connect(_on_member_died)
	enemies[member_id] = enemy
	add_child(enemy)
	enemy.encounter_returning = state == State.LEASHING
	changed.emit(self)

func _on_member_died(enemy: CharacterBase) -> void:
	var id: String = enemy.encounter_member_id
	if not enemies.has(id):
		return
	enemies.erase(id)
	record.dead_members[id] = true
	enemy_killed.emit(self)
	changed.emit(self)
	call_deferred("_check_completion")

func request_reinforcements(source: EnemyCharacter, types: Array[String], tag: String) -> void:
	if not enabled or state == State.CLEARED or state == State.RESETTING:
		return
	if enemies.size() + pending_spawns + types.size() > 80:
		return
	# Reserve before the parent's death signal; deferred children must count toward completion.
	pending_spawns += types.size()
	_spawn_reinforcements.call_deferred(source.encounter_member_id, source.global_position, types, tag)

func _spawn_reinforcements(parent_id: String, origin: Vector2, types: Array[String], tag: String) -> void:
	for index in range(types.size()):
		var id := "%s/%s/%d" % [parent_id, tag, index]
		if enemies.has(id) or record.dead_members.has(id):
			continue
		var offset := Vector2.from_angle(TAU * float(index) / float(types.size())) * 90
		_spawn_member(types[index], id, origin + offset)
	pending_spawns -= types.size()
	_check_completion()

func _check_completion() -> void:
	if not initialized or spawn_failed or not enemies.is_empty() or pending_spawns > 0 or state == State.CLEARED:
		return
	record.cleared = true
	_set_state(State.CLEARED)
	completed.emit(self)

func begin_return() -> void:
	_set_state(State.LEASHING)
	outside_time = 0
	for enemy in enemies.values():
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.begin_encounter_return()

func all_at_home() -> bool:
	if pending_spawns > 0:
		return false
	for enemy in enemies.values():
		if is_instance_valid(enemy) and enemy.global_position.distance_to(enemy.home_position) > 16:
			return false
	return true

func reset_encounter() -> void:
	if pending_spawns > 0:
		return
	_set_state(State.RESETTING)
	if config.reset_policy == EncounterConfig.ResetPolicy.FULL_RESET:
		for enemy in enemies.values():
			enemy.queue_free()
		enemies.clear()
		record.dead_members.clear()
		initialized = false
	else:
		for enemy in enemies.values():
			if not is_instance_valid(enemy):
				continue
			if config.reset_policy == EncounterConfig.ResetPolicy.PARTIAL_PERSIST:
				enemy.heal(enemy.max_health)
			enemy.velocity = Vector2.ZERO
			enemy.encounter_returning = false
			enemy.modulate = Color.WHITE
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	outside_time = 0
	_set_state(State.DORMANT)

func claim_member_reward(member_id: String) -> bool:
	return world.world_state.claim_member_reward(encounter_id, member_id)

func _set_state(value: State) -> void:
	state = value
	queue_redraw()
	changed.emit(self)

func _draw() -> void:
	var color := Color("e5ae57")
	if config != null and config.threat_level >= 4:
		color = Color("dc7474")
	if state == State.CLEARED:
		color = Color("7ac19a")
	draw_arc(Vector2.ZERO, 56, 0, TAU, 32, color, 3, true)
	draw_circle(Vector2.ZERO, 7, color)
	if Engine.is_editor_hint() and preview_radius and config != null:
		draw_arc(Vector2.ZERO, config.activation_radius, 0, TAU, 64, Color(0.3, 0.9, 0.6, 0.5), 2)
		draw_arc(Vector2.ZERO, config.leash_radius, 0, TAU, 64, Color(1, 0.6, 0.3, 0.5), 2)
