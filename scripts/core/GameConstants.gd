class_name GameConstants
extends RefCounted

const GROUP_CHARACTERS := "characters"
const GROUP_PLAYERS := "players"
const GROUP_ENEMIES := "enemies"
const GROUP_CHESTS := "chests"
const GROUP_PICKUPS := "pickups"
const GROUP_GOLDEN_KEYS := "golden_keys"

const NODE_SKILL_MANAGER := "SkillManager"
const NODE_STATE_MANAGER := "StateManager"
const NODE_DUNGEON_GENERATOR := "DungeonGenerator"
const NODE_GAME_MANAGER := "GameManager"
const NODE_ENEMIES_CONTAINER := "Enemies"
const NODE_SKILL_EFFECTS := "SkillEffects"
const NODE_SKILL_INDICATOR := "SkillIndicator"
const NODE_UI_MANAGER := "UI/UIManager"
const NODE_DEATH_PANEL := "UI/DeathPanel"

const SCENE_SKILL_EFFECT := "res://Scenes/SkillEffect.tscn"

const LAYER_NONE := 0
const LAYER_DEFAULT := 1
const LAYER_WORLD := LAYER_DEFAULT
const LAYER_PLAYER_BODY := LAYER_DEFAULT
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_PLAYER_PROJECTILE := 8
const LAYER_INTERACTABLE := 16

const MASK_WORLD_AND_PLAYERS := LAYER_WORLD | LAYER_PLAYER
const MASK_WORLD_AND_ENEMIES := LAYER_WORLD | LAYER_ENEMY
