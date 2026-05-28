class_name DebugLog
extends RefCounted

enum Level {
	DEBUG,
	INFO,
	WARNING,
	ERROR
}

const CATEGORY_GENERAL := "general"
const CATEGORY_GAME := "game"
const CATEGORY_UI := "ui"
const CATEGORY_DUNGEON := "dungeon"
const CATEGORY_ROOM := "room"
const CATEGORY_COMBAT := "combat"
const CATEGORY_SKILL := "skill"
const CATEGORY_AI := "ai"
const CATEGORY_PLAYER := "player"

static var gameplay_enabled: bool = false
static var minimum_level: int = Level.DEBUG
static var enabled_categories: Dictionary = {}
static var disabled_categories: Dictionary = {}
static var category_minimum_levels: Dictionary = {}

static func configure(
	enabled: bool,
	min_level: int = Level.DEBUG,
	categories: Array = []
) -> void:
	gameplay_enabled = enabled
	minimum_level = min_level
	enabled_categories.clear()
	disabled_categories.clear()
	for category in categories:
		enabled_categories[category] = true

static func set_enabled(enabled: bool) -> void:
	gameplay_enabled = enabled

static func set_minimum_level(level: int) -> void:
	minimum_level = level

static func enable_category(category: String) -> void:
	disabled_categories.erase(category)
	enabled_categories[category] = true

static func disable_category(category: String) -> void:
	enabled_categories.erase(category)
	disabled_categories[category] = true

static func clear_category_filters() -> void:
	enabled_categories.clear()
	disabled_categories.clear()

static func set_category_minimum_level(category: String, level: int) -> void:
	category_minimum_levels[category] = level

static func clear_category_minimum_level(category: String) -> void:
	category_minimum_levels.erase(category)

static func level_from_name(level_name: String) -> int:
	match level_name.to_lower():
		"debug":
			return Level.DEBUG
		"info":
			return Level.INFO
		"warning", "warn":
			return Level.WARNING
		"error":
			return Level.ERROR
		_:
			return Level.DEBUG

static func debug(parts: Array, category: String = CATEGORY_GENERAL) -> void:
	write(Level.DEBUG, parts, category)

static func info(parts: Array, category: String = CATEGORY_GENERAL) -> void:
	write(Level.INFO, parts, category)

static func warning(parts: Array, category: String = CATEGORY_GENERAL) -> void:
	write(Level.WARNING, parts, category)

static func error(parts: Array, category: String = CATEGORY_GENERAL) -> void:
	write(Level.ERROR, parts, category)

static func write(level: int, parts: Array, category: String = CATEGORY_GENERAL) -> void:
	if not _should_log(level, category):
		return
	var message := _format_message(level, category, parts)
	match level:
		Level.WARNING:
			push_warning(message)
		Level.ERROR:
			push_error(message)
		_:
			print(message)

static func _should_log(level: int, category: String) -> bool:
	if not gameplay_enabled:
		return false
	if category in disabled_categories:
		return false
	if enabled_categories.size() > 0 and not enabled_categories.has(category):
		return false
	var category_level = int(category_minimum_levels.get(category, minimum_level))
	return level >= category_level

static func _format_message(level: int, category: String, parts: Array) -> String:
	return "[%s][%s] %s" % [_level_name(level), category, _join_parts(parts)]

static func _level_name(level: int) -> String:
	match level:
		Level.DEBUG:
			return "debug"
		Level.INFO:
			return "info"
		Level.WARNING:
			return "warning"
		Level.ERROR:
			return "error"
		_:
			return "log"

static func _join_parts(parts: Array) -> String:
	var message := ""
	for part in parts:
		message += str(part)
	return message
