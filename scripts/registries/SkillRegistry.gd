class_name SkillRegistry
extends RefCounted

const SKILL_FIREBALL := "fireball"
const SKILL_ICE_SPIKE := "ice_spike"
const SKILL_HEAL := "heal"
const SKILL_METEOR := "meteor"
const SKILL_SNIPE := "snipe"
const SKILL_MANA_RESTORE := "mana_restore"
const SKILL_POISON_SHOT := "poison_shot"
const SKILL_SWIFT_STRIKE := "swift_strike"
const SKILL_TORNADO := "tornado"
const SKILL_SONIC_WAVE := "sonic_wave"
const SKILL_BLINK := "blink"
const SKILL_DRAIN_LIFE := "drain_life"
const SKILL_CHAIN_LIGHTNING := "chain_lightning"
const SKILL_FLAME_STORM := "flame_storm"
const SKILL_FROST_ARMOR := "frost_armor"
const SKILL_SPLIT_SHOT := "split_shot"
const SKILL_SHOCKWAVE := "shockwave"
const SKILL_VOID_PRISON := "void_prison"

const SKILL_CLASSES := {
	SKILL_FIREBALL: "res://scripts/skills/FireballSkill.gd",
	SKILL_ICE_SPIKE: "res://scripts/skills/IceSpikeSkill.gd",
	SKILL_HEAL: "res://scripts/skills/HealSkill.gd",
	SKILL_METEOR: "res://scripts/skills/MeteorSkill.gd",
	SKILL_SNIPE: "res://scripts/skills/SnipeSkill.gd",
	SKILL_MANA_RESTORE: "res://scripts/skills/ManaRestoreSkill.gd",
	SKILL_POISON_SHOT: "res://scripts/skills/PoisonShotSkill.gd",
	SKILL_SWIFT_STRIKE: "res://scripts/skills/SwiftStrikeSkill.gd",
	SKILL_TORNADO: "res://scripts/skills/TornadoSkill.gd",
	SKILL_SONIC_WAVE: "res://scripts/skills/SonicWaveSkill.gd",
	SKILL_BLINK: "res://scripts/skills/BlinkSkill.gd",
	SKILL_DRAIN_LIFE: "res://scripts/skills/DrainLifeSkill.gd",
	SKILL_CHAIN_LIGHTNING: "res://scripts/skills/ChainLightningSkill.gd",
	SKILL_FLAME_STORM: "res://scripts/skills/FlameStormSkill.gd",
	SKILL_FROST_ARMOR: "res://scripts/skills/FrostArmorSkill.gd",
	SKILL_SPLIT_SHOT: "res://scripts/skills/SplitShotSkill.gd",
	SKILL_SHOCKWAVE: "res://scripts/skills/ShockwaveSkill.gd",
	SKILL_VOID_PRISON: "res://scripts/skills/VoidPrisonSkill.gd"
}

static func has_skill(skill_id: String) -> bool:
	return skill_id in SKILL_CLASSES

static func create_skill(skill_id: String, player: Node, skill_manager: Node):
	if not has_skill(skill_id):
		return null
	
	var skill_script = load(SKILL_CLASSES[skill_id])
	if not skill_script:
		return null
	
	return skill_script.new(player, skill_manager)

static func get_skill_ids() -> Array[String]:
	var skill_ids: Array[String] = []
	for skill_id in SKILL_CLASSES.keys():
		skill_ids.append(skill_id)
	return skill_ids
