class_name WorldLayout
extends RefCounted

const CHUNK_SIZE := Vector2(1280, 1024)
const MAP_SIZE := CHUNK_SIZE * 3
const SPAWN := Vector2(430, 2650)
const CELL_SIZE := 64

## Authored rock shelves; gaps form the south road, central pass and west detour.
static func obstacles() -> Array[Rect2]:
	return [
		Rect2(0, 0, 3840, 96), Rect2(0, 2976, 3840, 96),
		Rect2(0, 0, 96, 3072), Rect2(3744, 0, 96, 3072),
		Rect2(900, 2112, 480, 192), Rect2(2150, 2080, 400, 224),
		Rect2(1088, 960, 224, 850), Rect2(2464, 960, 256, 1088),
		Rect2(320, 640, 560, 192), Rect2(1408, 832, 640, 160),
		Rect2(2304, 640, 480, 192), Rect2(3100, 2200, 350, 200),
		Rect2(192, 1728, 448, 192), Rect2(3040, 1024, 384, 160)
	]

static func roads() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([SPAWN, Vector2(1700, 2600), Vector2(2890, 2560), Vector2(3220, 1700), Vector2(3560, 1380), Vector2(3540, 820), Vector2(3260, 440)]),
		PackedVector2Array([Vector2(1700, 2600), Vector2(1790, 1560), Vector2(2220, 1220), Vector2(2200, 470), Vector2(3260, 440)]),
		PackedVector2Array([SPAWN, Vector2(800, 2400), Vector2(810, 1520), Vector2(550, 1270), Vector2(970, 1150), Vector2(970, 440), Vector2(1900, 430)])
	]
