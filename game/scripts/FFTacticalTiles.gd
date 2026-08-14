extends RefCounted
class_name FFTacticalTiles

const ATLAS_PATH := "res://assets/tactical_atlas.png"
const CELL := 32.0
static var _atlas: Texture2D = null

const GROUND := {
    "asphalt": 0,
    "road": 1,
    "sidewalk": 2,
    "concrete": 3,
    "tile": 4,
    "wood": 5,
    "carpet": 6,
    "linoleum": 7,
    "grass": 8,
    "dirt": 9,
    "wash_concrete": 10,
}

const WALL_BY_THEME := {
    "alley": 16,
    "gas": 17,
    "house": 18,
    "apartment": 19,
    "store": 20,
    "industrial": 21,
    "wash": 22,
}

const PROP := {
    "dumpster": 32,
    "trash": 33,
    "neon_sign": 34,
    "gas_pump": 35,
    "car": 36,
    "counter": 37,
    "store_shelf": 38,
    "gas_sign": 39,
    "ice_box": 40,
    "couch": 41,
    "table": 42,
    "bed": 43,
    "kitchen": 44,
    "fridge": 45,
    "washer": 46,
    "vending": 47,
    "crate": 48,
    "pallet": 49,
    "forklift": 50,
    "machine": 51,
    "scrub": 52,
    "shopping_cart": 53,
    "culvert_debris": 54,
    "apt_sign": 55,
    "shop_sign": 55,
    "warehouse_sign": 55,
    "wash_sign": 55,
}

const ITEM := {
    "Flashlight": 64,
    "Headlamp": 65,
    "Lantern": 66,
    "Glow Stick": 67,
    "Road Flare": 68,
    "Radio": 69,
    "Binoculars": 70,
    "Battery": 71,
}

static func _texture() -> Texture2D:
    if _atlas == null:
        _atlas = ResourceLoader.load(ATLAS_PATH) as Texture2D
    return _atlas

static func region(index: int) -> Rect2:
    return Rect2(float(posmod(index, 16)) * CELL, float(index / 16) * CELL, CELL, CELL)

static func draw_region(canvas: CanvasItem, index: int, rect: Rect2, modulate := Color.WHITE) -> void:
    var texture: Texture2D = _texture()
    if texture == null:
        return
    canvas.draw_texture_rect_region(texture, rect, region(index), modulate, false, true)

static func draw_ground(canvas: CanvasItem, rect: Rect2, kind: String) -> void:
    draw_region(canvas, int(GROUND.get(kind, 0)), rect)

static func draw_wall(canvas: CanvasItem, rect: Rect2, theme: String) -> void:
    draw_region(canvas, int(WALL_BY_THEME.get(theme, 16)), rect)

static func draw_door(canvas: CanvasItem, rect: Rect2, opened: bool) -> void:
    draw_region(canvas, 24 if opened else 23, rect)

static func draw_window(canvas: CanvasItem, rect: Rect2) -> void:
    draw_region(canvas, 25, rect)

static func draw_barrel(canvas: CanvasItem, rect: Rect2) -> void:
    draw_region(canvas, 26, rect)

static func draw_prop(canvas: CanvasItem, rect: Rect2, kind: String) -> void:
    draw_region(canvas, int(PROP.get(kind, 48)), rect)

static func item_region(item_name: String) -> int:
    return int(ITEM.get(item_name, -1))
