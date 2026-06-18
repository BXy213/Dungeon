# Project Context

This document is the human-maintained context handoff for Codex and future maintainers.
Keep it concise, durable, and focused on how the project works.

## What This Project Is

This is a Godot 4.6 dungeon-exploration / MOBA-like demo. The player starts from the main menu, enters a generated dungeon, clears rooms of enemies, collects keys and skill rewards, and ultimately reaches the boss / golden-key objective.

The project is currently GDScript-focused. There is a `.NET` assembly name in `project.godot`, but the active gameplay code lives under `scripts/` and scenes under `Scenes/`.

## Runtime Flow

- `project.godot` sets `res://Scenes/MainScene.tscn` as the main scene.
- `Scenes/MainScene.tscn` uses `scripts/MainMenu.gd`; Start loads the gameplay scene, Help loads `Scenes/HelpScene.tscn`, and Quit exits.
- `Scenes/GameScene.tscn` is the main gameplay composition. It instances the player, `DungeonGenerator`, `SkillIndicator`, `UI/UIManager`, and `GameManager`.
- `DungeonGenerator.gd` creates the dungeon grid, rooms, corridors, room transitions, collision gating, and camera limits.
- Each `Room.gd` instance generates its obstacles, enemies, chests, walls, saved state, and completion signals.
- `GameManager.gd` coordinates pause, death, restart, victory, boss defeat, and high-level game state panels.
- `UIManager.gd` builds and updates HUD, minimap, skill swapping, reward selection, silver-key display, and pause UI.

## Architecture

- Character model: `CharacterBase.gd` is the shared base for player and enemies. `PlayerCharacter.gd` handles input, movement, basic attacks, skills, experience, levels, silver keys, death, respawn, and camera limits. `EnemyCharacter.gd` extends the base with AI, rewards, loot, drops, health bars, damage feedback, and room death notifications.
- Enemy variants: `scripts/enemies/*.gd` implement melee, ranged, elite, boss, healer, bomber, splitter, and mini-splitter behavior. `EnemyFactory.gd` is the central creation and legacy type conversion point.
- Dungeon and rooms: `DungeonGenerator.gd` creates a connected grid using corridor data and room state. `Room.gd` owns per-room content generation and persistence. `EnemySpawnPlanner.gd` chooses enemy waves by room distance and boss-room position. `RoomSaveCodec.gd` serializes obstacles and enemies.
- Skills: `SkillBase.gd` defines common cooldown, mana, range, target, and effect helpers. `SkillRegistry.gd` maps skill IDs to scripts. `SkillManager.gd` owns active slots, library, swapping, cooldown queries, and casts. Concrete skills live in `scripts/skills/`.
- Effects and feedback: `SkillEffect.gd`, `SkillIndicator.gd`, `DamageNumber.gd`, and `FloatingLabel.gd` handle projectile / area effects, targeting visuals, and combat feedback.
- UI: Most gameplay UI is constructed or managed by `UIManager.gd`; `SkillButton.gd`, `HelpMenu.gd`, `MainMenu.gd`, and `UIStyleFactory.gd` support smaller UI surfaces.
- Shared constants: `scripts/core/GameConstants.gd` centralizes group names, node names, scene paths, and collision layer / mask constants.
- Debug logging: `scripts/core/DebugLog.gd` provides opt-in verbose gameplay logging with levels (`debug`, `info`, `warning`, `error`) and categories such as `game`, `ui`, `combat`, `skill`, `player`, `ai`, `dungeon`, `room`, `pickup`, `interaction`, and `buff`. It defaults to disabled and is configured by `GameManager.gd` via exported `enable_verbose_logs` and `verbose_log_level` fields. `SkillEffect.gd`, `GameManager.gd`, `UIManager.gd`, `EnemyCharacter.gd`, `PlayerCharacter.gd`, `SkillManager.gd`, `SkillBase.gd`, `PlayerStateManager.gd`, `SkillIndicator.gd`, `Chest.gd`, `SilverKey.gd`, and `GoldenKey.gd` route noisy or state-change logs through it.

## Key Directories And Files

- `project.godot`: Godot project config, main scene, input actions, renderer settings.
- `Scenes/MainScene.tscn`: main menu scene.
- `Scenes/GameScene.tscn`: gameplay root scene and primary node composition.
- `Scenes/Player.tscn`, `Scenes/Room.tscn`, `Scenes/*Skill*.tscn`, key/chest/obstacle scenes: reusable gameplay scene assets. The player `Sprite2D` uses `art/charwalk.png` as a 4x4 sheet, with columns for directions and rows for walk frames.
- `scripts/CharacterBase.gd`, `scripts/PlayerCharacter.gd`, `scripts/EnemyCharacter.gd`: combat-character core.
- `scripts/core/DebugLog.gd`: opt-in verbose gameplay logger with level and category filtering for noisy diagnostics.
- `scripts/DungeonGenerator.gd`, `scripts/Room.gd`: procedural dungeon and room lifecycle.
- `scripts/SkillBase.gd`, `scripts/SkillManager.gd`, `scripts/registries/SkillRegistry.gd`, `scripts/skills/`: skill system.
- `scripts/UIManager.gd`, `scripts/GameManager.gd`: gameplay UI and high-level flow.
- `scripts/factories/EnemyFactory.gd`, `scripts/rooms/EnemySpawnPlanner.gd`, `scripts/rooms/RoomSaveCodec.gd`: enemy creation, spawn planning, and room state serialization.
- `art/`: sprite and effect assets. `art/enemies/` contains generated transparent PNG enemy sprites; `art/environment/` contains generated dungeon floor, wall, and obstacle textures. Generated `.import` files are excluded from project snapshots.
- `docs/WORLD_MAP_MIGRATION_PLAN.md`: local planning document for the proposed open-world map and encounter-point migration.
- `docs/PROJECT_SNAPSHOT.md`: generated current structure summary.

## Common Commands

- Open in Godot Editor from the project root:

```bash
godot --editor --path .
```

- Run the project from the project root:

```bash
godot --path .
```

- Refresh the generated Codex project snapshot:

```bash
python "C:/Users/yangbo.ran/.codex/skills/project-context-maintainer/scripts/update_project_snapshot.py" --project .
```

No automated test command is currently documented in the repository.

## Data, APIs, And Resources

- Input actions are defined in `project.godot`: movement (`move_left`, `move_right`, `move_up`, `move_down`) and skill slots (`skill_1` through `skill_4`).
- `art/charwalk.png` is the player movement sprite sheet. `PlayerCharacter.gd` drives it by setting `Sprite2D.frame_coords`; columns are down, left, up, and right, while rows are walk frames.
- Enemy scripts under `scripts/enemies/` preload their type-specific sprites from `art/enemies/` instead of tinting the placeholder `icon.webp`.
- Room and corridor surfaces use tiled generated textures from `art/environment/`; `Room.gd` owns room floors and room wall visuals, `DungeonGenerator.gd` owns corridor floor and wall visuals, and `Obstacle.gd` scales the generated rubble sprite to its grid collision size.
- Skill IDs are canonicalized in `SkillRegistry.gd`; add new skills there and under `scripts/skills/`.
- Enemy type IDs are canonicalized in `EnemyFactory.gd`; room save/load uses both string IDs and legacy integer IDs.
- Room state and generated content live in `Room.gd` and `RoomSaveCodec.gd`. Be careful when changing enemy, obstacle, or room data shape because it may affect restoring room contents.
- Main gameplay node names are referenced by scripts via constants in `GameConstants.gd`; renaming scene nodes can break lookups unless constants and call sites are updated together.
- Collision layers and masks are encoded in `GameConstants.gd`. Coordinate changes with scene collision settings.
- Enemy subclasses own their AI movement and call `move_and_slide()` after setting velocity. `EnemyCharacter.gd` only gates dead / stunned AI processing so subclasses do not inherit `CharacterBase.gd`'s player-style movement pass.
- `UIManager.gd` refreshes skill and status UI on a short interval rather than every frame; force an immediate refresh after important state changes when adding new UI surfaces. `SkillIndicator.gd` disables processing while hidden and caches the player reference while active.
- To enable verbose logs, set `GameManager.enable_verbose_logs` to true in the scene inspector or in code, and choose a `verbose_log_level`. Use `DebugLog.debug/info/warning/error([...], DebugLog.CATEGORY_*)` for new diagnostics instead of raw `print()` when the message is not always user-relevant.

## Change Guidelines

- Update this file when project behavior, architecture, workflows, module responsibilities, or important constraints change.
- Regenerate `docs/PROJECT_SNAPSHOT.md` after source, config, scene, resource, build, or structure changes.
- Project maintenance is enabled by `.codex/project-maintenance.json`.
- Future Codex sessions should use `$project-context-maintainer` and automatically bootstrap by reading `AGENTS.md`, `.codex/project-maintenance.json`, `docs/PROJECT_CONTEXT.md`, and `docs/PROJECT_SNAPSHOT.md` before project-sensitive work.
- These maintenance files are intentionally local and ignored by Git in this repository: `.codex/`, `AGENTS.md`, `docs/PROJECT_CONTEXT.md`, and `docs/PROJECT_SNAPSHOT.md`.

## Known Sharp Edges

- Some Chinese user-facing strings and comments appear as mojibake when read from the command line. Verify encoding in the Godot editor before editing text fields or rewriting affected files.
- `UIManager.gd`, `DungeonGenerator.gd`, and `Room.gd` are large coordinator scripts with many direct node lookups and signal connections. Prefer small, local edits and verify affected scene node paths.
- Do not manually edit Godot `.uid` files or generated `.import` files.
- `docs/PROJECT_SNAPSHOT.md` is generated. Fix the generator or config rather than hand-editing snapshot contents.
