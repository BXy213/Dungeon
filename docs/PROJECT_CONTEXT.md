# Project Context

Human-maintained handoff for this repository. Read alongside the generated `PROJECT_SNAPSHOT.md`.

## Project And Current Status

Godot 4.7.1, GDScript, 2D open-map combat prototype. The former generated room dungeon has been replaced on branch `codex/world-map-encounters`. The .NET assembly setting exists but gameplay is GDScript.

The initial map is designed and implemented by Codex: 3840x3072 world units, nine resident 1280x1024 chunks, six authored encounter points, safe southwest spawn, southern/eastern route, central route and western reward detour. Existing environment PNG textures are reused. There are no room transitions or combat-locked corridors.

The first version supports fighting, retreating, returning home, configurable rosters and reset policies, keys/chests/skill rewards, and a final encounter with a golden-key victory. This is a playable prototype, not a finished open-world content system. Difficulty and route pressure still need human playtesting.

## Entrypoints And Runtime Flow

- `project.godot` starts `Scenes/MainScene.tscn`; Start loads `Scenes/GameScene.tscn`.
- `Scenes/WorldTestScene.tscn` inherits GameScene for direct F6 testing. F5 follows the menu.
- GameScene composes Player, WorldManager/WorldMap, SkillEffects, SkillIndicator, UI/UIManager and GameManager.
- WorldMap builds authored terrain in the editor and at runtime. WorldManager builds AStarGrid2D navigation, registers placed encounters, assigns the safe spawn and whole-map camera bounds.
- WorldManager ticks encounter activation/discovery at 10 Hz. Enemy movement is still physics-driven.
- GameManager owns pause, death/continue, restart and victory. Continue respawns the player at the safe spawn and retains the run; restart reloads all state.
- The final encounter must clear its roster and all summons/splits before spawning the golden key. Pickup triggers the existing victory panel.

## World Responsibilities

- `scripts/world/WorldLayout.gd`: fixed dimensions, spawn, rock-shelf obstacle rectangles and three authored roads. Terrain and navigation derive from the same layout.
- `WorldMap.gd`: nine terrain chunks, textured roads, StaticBody2D world obstacles and editor preview. Not procedural level generation.
- `WorldManager.gd`: world orchestration, 64-unit AStarGrid2D with obstacle clearance, reachable spawn positions, safe blink landing positions, camera bounds, clear rewards and UI queries.
- `EncounterConfig.gd`: reusable Resource for name, threat, roster, activation/leash/reset radii, reset policy and rewards.
- `EncounterSpawnGroup.gd`: typed Resource for group ID, factory type or custom PackedScene, count, offsets, spread, health/damage multipliers and key holder.
- `EncounterPoint.gd`: unique placed identity and DORMANT/ACTIVE/LEASHING/RESETTING/CLEARED state machine; owns enemy membership and pending summons.
- `WorldState.gd`: in-memory per-run discovery, dead member IDs, clear/reward flags and member reward ledger. No disk save or streaming restore API.
- `WorldHUD.gd`: world-coordinate minimap, discovered chunks, encounter threat/state, final objective and player position.

Configuration lives in `resources/encounters/*.tres`; point placement lives in `Scenes/world/WorldMap.tscn`. Copying a template should not require controller edits. `encounter_id` is unique per placed point, separate from its reusable config. Member IDs are `group_id/index`; summons/splits have deterministic child IDs.

## Combat And Reused Systems

- `CharacterBase.gd`: common character stats, combat and BuffSystem integration.
- `PlayerCharacter.gd`: input, movement/basic attacks, skills, XP, levels, keys, death/respawn and walk-sheet animation.
- `EnemyCharacter.gd`: encounter ownership, home/return behavior, collision-aware navigation, rewards/loot and feedback. Subclasses call the base physics method then gate their own AI with `can_process_enemy_ai()`; timers must honor the same gate.
- `scripts/enemies/`: melee, ranged, elite, boss, healer, bomber and splitter variants. Boss/splitter request reinforcements through their encounter. Healers do not heal neighboring encounters or returning enemies.
- `scripts/factories/EnemyFactory.gd`: factory for eight canonical string IDs. Legacy room IDs, integer mappings and room-specific static constructors were removed.
- `SkillBase.gd`, `SkillManager.gd`, `registries/SkillRegistry.gd`, `scripts/skills/`: existing skill system. New skills register with SkillRegistry. Blink delegates landing validation to WorldManager.
- `SkillEffect.gd`: shared effects/projectiles. World blocking is determined by StaticBody2D world collision layer, not legacy RoomWall names. Existing intentional piercing skills retain their behavior.
- `UIManager.gd`: skill/status UI, swapping, chest rewards and pause UI; delegates map display to WorldHUD.
- `Chest.gd`, `SilverKey.gd`, `GoldenKey.gd`: shared interaction/pickup objects. Encounter completion now owns chest/final-key generation, not individual Boss death.

## State And Gameplay Contracts

- Radii must satisfy `0 < activation < leash < reset`; measured from the point, not from chunk edges.
- PARTIAL_PERSIST retains dead members and heals surviving returned members; FULL_RESET rebuilds the roster after return/reset; NO_RESET retains survivors' health.
- Return clears buffs and suppresses damage/AI until enemies are home. Reset requires all surviving members home and the player outside reset_radius for reset_delay.
- Cleared encounters never respawn within the run. FULL_RESET preserves the per-member reward ledger, preventing repeated XP/key farming.
- Dynamic summons/splits count toward encounter completion but grant no XP or keys. Pending member reservations prevent a parent death from prematurely clearing the camp.
- Threat level is UI metadata. Actual difficulty comes from roster, health/damage multipliers and terrain, not automatic threat scaling.
- Keys/chests remain in the resident world when the player leaves. No room-transition projectile clearing occurs; existing effects expire normally.
- WorldMap/WorldManager currently assume world origin zero and unscaled placement. Encounter points support translation only.
- All nine chunks remain resident; distant unvisited encounters have no enemy instances, returned encounters sleep. Profile before adding streaming.

## Commands And Verification

Use Godot 4.7.1. Installed Windows executable:

`D:/Program Files/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`

Commands below use `godot` as an alias for that executable:

```powershell
godot --editor --path .
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/world_integration.gd
godot --path . --script tests/world_visual.gd --rendering-method gl_compatibility --resolution 1280x720
godot --path . --script tests/world_visual.gd --rendering-method gl_compatibility --resolution 1024x576
python "C:/Users/yangbo.ran/.codex/skills/project-context-maintainer/scripts/update_project_snapshot.py" --project .
```

Integration tests currently cover 117 assertions: six configurations, connected roads/camps, activation idempotence, cross-chunk projectile/movement, obstacle blocking, retreat/navigation, all reset policies, XP/key deduplication, real chest reward selection, custom enemy PackedScene, Boss summons/splits/final reward, blink limits and death/restart.

Visual checks write screenshots under ignored `.godot/world-qa/` and sample canvas colors. The screenshots were visually inspected at 1280x720 and 1024x576. Gameplay balance and long-duration performance are not proven by these tests.

The current host blocks some native executables in the default sandbox; Godot, Git and Python commands may need tool approval. Do not interpret that as a project parse error.

## Documentation And Change Guidelines

- `docs/WORLD_MAP_MIGRATION_PLAN.md`: architecture decisions, implemented scope, future phases and final legacy cleanup.
- `docs/WORLD_MAP_TODO.md`: persistent checklist, validation results and remaining work.
- `docs/ENCOUNTER_AUTHORING.md`: Inspector authoring workflow, exact fields, resource sharing and custom enemy contracts.
- `docs/PROJECT_SNAPSHOT.md`: generated inventory, never edit by hand.
- AGENTS.md opts this repository into project-context-maintainer. Read AGENTS, maintenance config, this file and the snapshot before architecture-sensitive work.
- Update this context and regenerate the snapshot after structural/behavioral changes.
- Preserve existing unrelated edits. No automatic commit/push.
- Actual Git rules track PROJECT_CONTEXT.md and PROJECT_SNAPSHOT.md, while ignoring other docs/*.md and .codex/. The plan, TODO and authoring guide are local files and will not accompany commits unless the user changes that policy. AGENTS' older local-only wording does not fully match these current rules; this task did not alter tracking rules.
- Do not manually edit Godot-generated .uid/.import files. Several existing files contain Unicode comments or BOMs; preserve encoding.

## Known Limitations

- No full cross-launch save, streaming, patrol/ambush event system, reward-pool tiers, automatic threat scaling or procedural world generation.
- Initial health, XP, skills and rewards reuse the prior demo; difficulty labels and route balance need playtesting.
- Custom static monsters use enemy_scene; new dynamic reinforcement types still need a factory registration/API extension.
- The existing skill metadata/reward UI creates cooldown Timer objects before attaching them to the scene. Reward-flow tests can report orphan Timer instances on exit; this pre-existing skill lifecycle issue is separate from world state and remains a follow-up.
- Removed runtime modules: DungeonGenerator, Room, Room.tscn, EnemySpawnPlanner, RoomSaveCodec, room minimap/corridor display, room enemy ownership and obsolete Boss-key emission. Recover historical behavior through Git, not a parallel legacy runtime.
