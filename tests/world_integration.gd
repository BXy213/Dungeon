extends SceneTree

var failures := 0
var checks := 0
var world: Node
var player: Node2D

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func frames(count: int = 4) -> void:
	for index in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	var scene: Node = load("res://Scenes/WorldTestScene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(8)
	world = scene.get_node("WorldManager")
	player = scene.get_node("Player")
	world.set_physics_process(false)
	player.set_physics_process(false)
	player.input_enabled = false
	player.max_health = 100000
	player.health = 100000
	check(world.initialized, "world initializes")
	check(world.encounters.size() == 6, "six authored encounters")
	check(scene.get_node("WorldManager/WorldMap/Terrain").get_child_count() >= 9, "nine terrain chunks")
	check(player.global_position == WorldLayout.SPAWN, "safe spawn")
	for point in world.encounters:
		check(not world.find_navigation_path(WorldLayout.SPAWN, point.global_position).is_empty(), "reachable: " + str(point.encounter_id))
		check(point.config.validate().is_empty(), "valid config: " + str(point.encounter_id))
	for road in WorldLayout.roads():
		for position in road:
			check(world.is_walkable(position), "road waypoint is walkable: " + str(position))
		var clear_road := true
		for index in range(road.size() - 1):
			for sample in range(41):
				var position: Vector2 = road[index].lerp(road[index + 1], sample / 40.0)
				for obstacle in WorldLayout.obstacles():
					if obstacle.grow(32).has_point(position):
						clear_road = false
		check(clear_road, "entire road centerline is unobstructed")
	var camp: EncounterPoint = world.encounters[0]
	camp.update_encounter(player, 0.1)
	check(camp.enemies.is_empty(), "distant camp remains dormant")
	player.global_position = camp.global_position + Vector2(400, 0)
	camp.update_encounter(player, 0.1)
	await frames()
	check(camp.enemies.size() == 3, "activation creates configured members")
	camp.update_encounter(player, 0.1)
	check(camp.enemies.size() == 3, "activation is idempotent")
	await _test_cross_chunk_combat(camp)
	var victim: EnemyCharacter = camp.enemies.values()[0]
	victim.take_damage(100000, player)
	await frames()
	check(camp.enemies.size() == 2 and camp.record.dead_members.size() == 1, "death tracked by stable member ID")
	var survivor: EnemyCharacter = camp.enemies.values()[0]
	survivor.take_damage(20, player)
	await frames(10)
	survivor.global_position += Vector2(80, 0)
	var before := survivor.global_position
	player.global_position = WorldLayout.SPAWN
	camp.update_encounter(player, 0.1)
	check(camp.state == EncounterPoint.State.LEASHING, "retreat starts return")
	var health_before := survivor.health
	survivor.take_damage(20, player)
	check(survivor.health == health_before, "returning members cannot be farmed at leash edge")
	await frames(100)
	check(survivor.global_position.distance_to(survivor.home_position) < before.distance_to(survivor.home_position), "return movement heads home")
	for enemy in camp.enemies.values():
		enemy.global_position = enemy.home_position
	camp.update_encounter(player, 3)
	check(camp.state == EncounterPoint.State.DORMANT, "returned camp sleeps after reset delay")
	check(survivor.health == survivor.max_health, "partial reset heals survivors")
	player.global_position = camp.global_position + Vector2(400, 0)
	camp.update_encounter(player, 0.1)
	check(camp.enemies.size() == 2, "partial reset keeps dead members dead")
	for enemy in camp.enemies.values().duplicate():
		enemy.take_damage(100000, player)
	await frames()
	check(camp.state == EncounterPoint.State.CLEARED, "camp clears after all deaths")
	check(camp.record.reward_spawned and is_instance_valid(camp.reward_node), "clear creates reward chest")
	var reward := camp.reward_node
	camp.activate()
	world._on_completed(camp)
	check(camp.reward_node == reward and camp.enemies.is_empty(), "clear cannot duplicate reward or enemies")
	await _test_chest_reward(reward)
	check(camp.record.reward_claimed, "chest claim tracked")
	await _test_custom_point()
	await _test_navigation_and_blink()
	await _test_full_reset_rewards()
	await _test_boss()
	await _test_splitter()
	await _test_all_configs()
	await _test_death_and_restart(scene)
	print("WORLD_TEST_RESULT checks=%d failures=%d" % [checks, failures])
	current_scene.queue_free()
	await frames(3)
	quit(1 if failures else 0)

func _test_cross_chunk_combat(point: EncounterPoint) -> void:
	var target: EnemyCharacter = point.enemies.values()[1]
	target.set_physics_process(false)
	player.global_position = Vector2(1270, target.global_position.y)
	var health_before := target.health
	player.create_basic_attack_projectile(target.global_position)
	await frames(65)
	check(target.health < health_before, "projectile crosses chunk boundary and damages enemy")
	target.set_physics_process(true)
	player.global_position = Vector2(1250, 2700)
	for i in range(30):
		await physics_frame
		player.velocity = Vector2(200, 0)
		player.move_and_slide()
	check(player.global_position.x > 1280, "physical player movement crosses chunk boundary")
	player.global_position = point.global_position + Vector2(400, 0)

func _test_chest_reward(chest: Node2D) -> void:
	var keys_before: int = player.silver_key_count
	for key in get_nodes_in_group("pickups"):
		if not key.is_picked_up:
			player.global_position = key.global_position
			await frames()
	check(player.silver_key_count > keys_before, "dropped silver key is picked up by proximity")
	player.global_position = chest.global_position
	chest.attempt_interaction()
	await frames()
	var ui: Node = current_scene.get_node("UI/UIManager")
	check(paused and ui.is_skill_reward_open, "chest opens skill reward UI and pauses world")
	if ui.reward_skill_buttons.is_empty():
		check(false, "reward choices are available")
		ui.hide_skill_reward_panel()
		return
	var skill_id: String = ui.reward_skill_buttons[0].get_meta("skill_id")
	ui.reward_skill_buttons[0].pressed.emit()
	ui.reward_confirm_button.pressed.emit()
	check(not paused and not ui.is_skill_reward_open, "confirming reward resumes gameplay")
	check(skill_id not in player.get_node("SkillManager").get_unowned_skills(), "selected skill enters player library")
	var keys_after: int = player.silver_key_count
	chest.attempt_interaction()
	check(player.silver_key_count == keys_after and not paused, "claimed chest cannot consume another key")

func _test_navigation_and_blink() -> void:
	var point := EncounterPoint.new()
	point.encounter_id = &"navigation_test"
	point.config = EncounterConfig.new()
	var group := EncounterSpawnGroup.new()
	group.count = 1
	group.spawn_radius = 0
	point.config.spawn_groups.append(group)
	world.get_node("WorldMap/Encounters").add_child(point)
	point.global_position = Vector2(1000, 2450)
	point.setup(world, world.world_state.encounter(point.encounter_id))
	point.activate()
	var enemy: EnemyCharacter = point.enemies.values()[0]
	enemy.global_position = Vector2(1120, 2080)
	check(not world.is_walkable(enemy.global_position), "wall-adjacent fixture lies in inflated navigation cell")
	check(not world.find_navigation_path(enemy.global_position, enemy.home_position).is_empty(), "wall-adjacent start resolves to reachable navigation cell")
	point.begin_return()
	enemy.buff_system.apply_buff(BuffSystem.BuffType.STUN, 8, 1, player)
	enemy.current_speed = 500
	player.global_position = WorldLayout.SPAWN
	await frames(160)
	check(enemy.global_position.distance_to(enemy.home_position) < 16, "enemy returns around rock shelf with physical collisions")
	check(not enemy.is_stunned, "returning enemy clears newly applied crowd control")
	enemy.set_physics_process(false)
	enemy.encounter_returning = false
	enemy.global_position = Vector2(1120, 2080)
	player.global_position = Vector2(1120, 2380)
	var health_before := enemy.health
	player.create_basic_attack_projectile(enemy.global_position)
	await frames(50)
	check(enemy.health == health_before, "world rock shelf blocks projectile damage")
	point.queue_free()
	await frames()
	var blink := BlinkSkill.new(player, player.get_node("SkillManager"))
	player.global_position = Vector2(150, 2600)
	blink.execute_skill_effect(Vector2(-100, 2600), null)
	check(player.global_position.x >= 125, "blink cannot leave world boundary")
	player.global_position = Vector2(1000, 2400)
	blink.execute_skill_effect(Vector2(1000, 2200), null)
	check(player.global_position.y >= 2333, "blink trims destination before solid terrain")
	player.global_position = Vector2(1200, 2600)
	blink.execute_skill_effect(Vector2(1400, 2600), null)
	check(player.global_position == Vector2(1400, 2600), "blink crosses chunk boundary on clear ground")
	blink.cooldown_timer.free()
	player.global_position = WorldLayout.SPAWN

func _test_full_reset_rewards() -> void:
	var point: EncounterPoint = world.encounters[4]
	player.global_position = point.global_position + Vector2(400, 0)
	point.activate()
	await frames()
	point.enemies["elite/0"].take_damage(100000, player)
	await frames()
	check(point.record.rewarded_members.has("elite/0"), "real elite death enters reward ledger")
	player.global_position = WorldLayout.SPAWN
	point.begin_return()
	for member in point.enemies.values():
		member.global_position = member.home_position
	point.update_encounter(player, 3)
	await frames()
	point.activate()
	await frames()
	check(point.enemies.has("elite/0"), "full reset revives previously killed member")
	var xp_before: int = player.experience
	var keys_before := get_nodes_in_group("pickups").size()
	point.enemies["elite/0"].take_damage(100000, player)
	await frames()
	check(player.experience == xp_before, "revived member cannot grant XP twice")
	check(get_nodes_in_group("pickups").size() == keys_before, "revived key holder cannot drop another key")

func _test_all_configs() -> void:
	for point in world.encounters:
		if point.state == EncounterPoint.State.CLEARED:
			continue
		player.global_position = point.global_position + Vector2(400, 0)
		point.update_encounter(player, 0.1)
		await frames()
		check(not point.enemies.is_empty() and not point.spawn_failed, "all configured members spawn: " + str(point.encounter_id))
		for enemy in point.enemies.values():
			check(world.is_walkable(enemy.home_position), "enemy home on navigable ground")
		player.global_position = WorldLayout.SPAWN
		point.begin_return()
		for enemy in point.enemies.values():
			enemy.global_position = enemy.home_position
		point.update_encounter(player, 3)

func _test_custom_point() -> void:
	var point := load("res://Scenes/world/EncounterPoint.tscn").instantiate() as EncounterPoint
	point.encounter_id = &"config_only_extension"
	point.config = EncounterConfig.new()
	point.config.reward_chest = false
	point.config.reset_policy = EncounterConfig.ResetPolicy.NO_RESET
	var group := EncounterSpawnGroup.new()
	group.group_id = &"test_archers"
	group.enemy_type = "ranged_soldier"
	group.count = 2
	var custom_scene := PackedScene.new()
	var custom_enemy := MeleeEnemy.new()
	check(custom_scene.pack(custom_enemy) == OK, "custom EnemyCharacter scene can be packed")
	custom_enemy.free()
	group.enemy_scene = custom_scene
	point.config.spawn_groups.append(group)
	world.get_node("WorldMap/Encounters").add_child(point)
	point.global_position = Vector2(2800, 2670)
	check(point.setup(world, world.world_state.encounter(point.encounter_id)), "new resource-only encounter accepted")
	player.global_position = point.global_position + Vector2(400, 0)
	point.update_encounter(player, 0.1)
	await frames()
	check(point.enemies.size() == 2, "new config creates requested type and count")
	check(point.enemies.values()[0] is MeleeEnemy, "custom enemy_scene overrides factory enemy type")
	var enemy: EnemyCharacter = point.enemies.values()[0]
	enemy.take_damage(17, player)
	var health := enemy.health
	player.global_position = WorldLayout.SPAWN
	point.begin_return()
	for member in point.enemies.values():
		member.global_position = member.home_position
	point.update_encounter(player, 3)
	check(enemy.health == health, "no_reset preserves surviving health")
	var bad := EncounterConfig.new()
	check(not bad.validate().is_empty(), "empty config rejected")
	bad.spawn_groups = [group, group]
	check(not bad.validate().is_empty(), "duplicate group IDs rejected")
	point.queue_free()
	await frames()

func _test_boss() -> void:
	var point: EncounterPoint = world.encounters[5]
	player.global_position = point.global_position + Vector2(-400, 0)
	point.update_encounter(player, 0.1)
	await frames()
	var boss: EnemyCharacter = point.enemies.get("boss/0")
	check(boss != null, "boss spawned outside room system")
	if boss == null:
		return
	boss.set_process(false)
	boss.summon_minions()
	await frames()
	check(point.enemies.size() >= 5, "boss summons belong to same encounter")
	check(point.claim_member_reward("boss/0"), "first member reward can be claimed")
	player.global_position = WorldLayout.SPAWN
	point.begin_return()
	for member in point.enemies.values():
		member.global_position = member.home_position
	point.update_encounter(player, 3)
	await frames()
	check(point.enemies.is_empty() and not point.initialized, "full reset removes live members and summons")
	check(not point.claim_member_reward("boss/0"), "full reset preserves reward ledger")
	player.global_position = point.global_position + Vector2(-400, 0)
	point.update_encounter(player, 0.1)
	await frames()
	check(point.enemies.has("boss/0"), "full reset can rebuild roster")
	point.enemies["boss/0"].set_process(false)
	for pass_index in range(5):
		for enemy in point.enemies.values().duplicate():
			enemy.take_damage(100000, player)
		await frames()
	check(point.state == EncounterPoint.State.CLEARED, "boss encounter waits for summons and splits")
	check(is_instance_valid(point.reward_node) and point.reward_node.is_in_group("golden_keys"), "final encounter creates golden key")
	if is_instance_valid(point.reward_node):
		point.reward_node.pickup_by_player(player)
		await create_timer(1.2).timeout
		check(paused and current_scene.get_node("GameManager").boss_defeated, "golden key triggers victory")
		current_scene.get_node("GameManager").hide_victory_panel()
		current_scene.get_node("GameManager").resume_game()

func _test_splitter() -> void:
	var point: EncounterPoint = world.encounters[2]
	player.global_position = point.global_position + Vector2(400, 0)
	point.update_encounter(player, 0.1)
	await frames()
	var before: int = point.enemies.size()
	var splitter: EnemyCharacter = point.enemies.get("splitters/0")
	check(splitter != null, "splitter config loads")
	if splitter == null:
		return
	splitter.take_damage(100000, player)
	check(point.pending_spawns > 0, "split reserves members before parent death")
	await frames()
	check(point.enemies.size() == before + 2, "three child splits replace parent")
	check(point.state != EncounterPoint.State.CLEARED, "pending splits prevent premature clear")
	check(point.enemies.has("splitters/0/split/0"), "split child has stable ID")

func _test_death_and_restart(scene: Node) -> void:
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.die()
	check(paused and scene.get_node("UI/DeathPanel").visible, "death pauses and opens panel")
	scene.get_node("GameManager").continue_game()
	check(not paused and not player.is_dead and player.global_position == WorldLayout.SPAWN, "continue respawns at safe camp")
	scene.get_node("GameManager").restart_game()
	await frames(8)
	var fresh := current_scene.get_node("WorldManager")
	check(fresh.encounters[0].record.dead_members.is_empty(), "restart creates fresh run state")
