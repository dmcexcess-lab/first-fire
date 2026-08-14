extends RefCounted
class_name FFTacticalEnvironments

# Authored tactical places. The encounter objective is deliberately separate:
# a rescue, search, or ambush can happen in the same physical place.
const BOARD_W := 20
const BOARD_H := 18

const CATALOG := {
    "back_alley": {
        "name": "Back Alley",
        "theme": "alley",
        "zones": ["Camp Perimeter", "Nearby Streets", "Commercial Fringe", "Industrial Edge"],
        "kinds": ["ambush", "explore", "rescue"],
        "variants": 2,
    },
    "gas_station": {
        "name": "Gas Station",
        "theme": "gas",
        "zones": ["Camp Perimeter", "Nearby Streets", "Commercial Fringe"],
        "kinds": ["ambush", "explore", "rescue"],
        "variants": 2,
    },
    "house": {
        "name": "Residential House",
        "theme": "house",
        "zones": ["Nearby Streets", "Residential Blocks"],
        "kinds": ["ambush", "explore", "rescue"],
        "variants": 2,
    },
    "apartment": {
        "name": "Apartment",
        "theme": "apartment",
        "zones": ["Nearby Streets", "Residential Blocks", "Commercial Fringe"],
        "kinds": ["ambush", "explore", "rescue"],
        "variants": 2,
    },
    "corner_store": {
        "name": "Corner Store",
        "theme": "store",
        "zones": ["Nearby Streets", "Residential Blocks", "Commercial Fringe"],
        "kinds": ["ambush", "explore", "rescue"],
        "variants": 2,
    },
    "warehouse_yard": {
        "name": "Warehouse Yard",
        "theme": "industrial",
        "zones": ["Commercial Fringe", "Industrial Edge"],
        "kinds": ["ambush", "explore", "rescue"],
        "variants": 2,
    },
    "drainage_wash": {
        "name": "Drainage Wash",
        "theme": "wash",
        "zones": ["Camp Perimeter", "Nearby Streets"],
        "kinds": ["ambush", "explore"],
        "variants": 2,
    },
}

const ZONE_POOLS := {
    "Camp Perimeter": ["drainage_wash", "back_alley", "gas_station"],
    "Nearby Streets": ["back_alley", "gas_station", "house", "apartment", "corner_store", "drainage_wash"],
    "Residential Blocks": ["house", "house", "apartment", "corner_store", "back_alley"],
    "Commercial Fringe": ["gas_station", "corner_store", "back_alley", "apartment", "warehouse_yard"],
    "Industrial Edge": ["warehouse_yard", "warehouse_yard", "back_alley"],
}

static func all_ids() -> Array:
    return CATALOG.keys()

static func display_name(environment_id: String) -> String:
    var data: Dictionary = CATALOG.get(environment_id, CATALOG["back_alley"])
    return str(data.get("name", "Field Encounter"))

static func theme_name(environment_id: String) -> String:
    var data: Dictionary = CATALOG.get(environment_id, CATALOG["back_alley"])
    return str(data.get("theme", "alley"))

static func variant_count(environment_id: String) -> int:
    var data: Dictionary = CATALOG.get(environment_id, CATALOG["back_alley"])
    return maxi(1, int(data.get("variants", 1)))

static func pick(zone: String, kind: String, rng: RandomNumberGenerator) -> String:
    var source: Array = ZONE_POOLS.get(zone, ["back_alley"])
    var pool: Array = []
    for raw_id in source:
        var environment_id := str(raw_id)
        var data: Dictionary = CATALOG.get(environment_id, {})
        if data.is_empty():
            continue
        var kinds: Array = data.get("kinds", [])
        if kinds.has(kind):
            pool.append(environment_id)
    if pool.is_empty():
        pool = ["back_alley"]
    return str(pool[rng.randi_range(0, pool.size() - 1)])

static func pick_variant(environment_id: String, rng: RandomNumberGenerator) -> int:
    return rng.randi_range(0, variant_count(environment_id) - 1)

static func legacy_environment(layout: int, zone: String) -> String:
    # Keeps an already-open schema-4 tactical save playable after 0.3B.
    if zone == "Residential Blocks" and posmod(layout, 3) == 1:
        return "house"
    match posmod(layout, 3):
        0: return "corner_store"
        1: return "house"
        _: return "back_alley"

static func default_ground(environment_id: String) -> String:
    match theme_name(environment_id):
        "house": return "grass"
        "apartment", "store": return "sidewalk"
        "industrial": return "concrete"
        "wash": return "dirt"
        _: return "asphalt"

static func ground_color(kind: String) -> Color:
    match kind:
        "road": return Color("26292b")
        "asphalt": return Color("303436")
        "sidewalk": return Color("686866")
        "concrete": return Color("555754")
        "tile": return Color("7b7d78")
        "wood": return Color("755d43")
        "carpet": return Color("514b4f")
        "linoleum": return Color("6f756d")
        "grass": return Color("3f5138")
        "dirt": return Color("69563d")
        "wash_concrete": return Color("77716a")
        _: return Color("303436")

static func wall_color(environment_id: String) -> Color:
    match theme_name(environment_id):
        "alley": return Color("51423f")
        "gas": return Color("d5d0bf")
        "house": return Color("a38a6a")
        "apartment": return Color("76716b")
        "store": return Color("8c8172")
        "industrial": return Color("59605f")
        "wash": return Color("82786b")
        _: return Color("62625e")

static func grid_color(environment_id: String) -> Color:
    match theme_name(environment_id):
        "gas": return Color(0.82, 0.82, 0.76, 0.16)
        "house": return Color(0.90, 0.80, 0.65, 0.14)
        "wash": return Color(0.90, 0.78, 0.55, 0.12)
        _: return Color(0.78, 0.82, 0.80, 0.12)

static func accent_color(environment_id: String) -> Color:
    match theme_name(environment_id):
        "alley": return Color("b04d78")
        "gas": return Color("e6c84f")
        "house": return Color("d8b47c")
        "apartment": return Color("8fa8bb")
        "store": return Color("70b0aa")
        "industrial": return Color("d08139")
        "wash": return Color("c5a36c")
        _: return Color("d0b15a")

static func build_layout(environment_id: String, raw_variant: int) -> Dictionary:
    var variant := posmod(raw_variant, variant_count(environment_id))
    match environment_id:
        "gas_station": return _gas_station(variant)
        "house": return _house(variant)
        "apartment": return _apartment(variant)
        "corner_store": return _corner_store(variant)
        "warehouse_yard": return _warehouse_yard(variant)
        "drainage_wash": return _drainage_wash(variant)
        _: return _back_alley(variant)

static func exit_count(environment_id: String, variant: int) -> int:
    return int(build_layout(environment_id, variant).get("exit_cells", []).size())

static func validate_layout(spec: Dictionary) -> bool:
    var spawn: Vector2i = spec.get("player_spawn", Vector2i(-1, -1))
    var exits: Array = spec.get("exit_cells", [])
    if exits.is_empty() or not _inside(spawn):
        return false
    var blocked := {}
    for p in spec.get("walls", []):
        blocked[p] = true
    for p in spec.get("obstacles", []):
        blocked[p] = true
    if blocked.has(spawn):
        return false
    var seen := {spawn: true}
    var queue: Array = [spawn]
    while not queue.is_empty():
        var p: Vector2i = queue.pop_front()
        for d in [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]:
            var n := p + d
            if not _inside(n) or blocked.has(n) or seen.has(n):
                continue
            seen[n] = true
            queue.append(n)
    for exit_cell in exits:
        if not seen.has(exit_cell):
            return false
    return true

static func _inside(p: Vector2i) -> bool:
    return p.x >= 1 and p.y >= 1 and p.x < BOARD_W - 1 and p.y < BOARD_H - 1

static func _spec(default_ground_kind: String, player_spawn: Vector2i, ally_spawn: Vector2i, exits: Array) -> Dictionary:
    return {
        "default_ground": default_ground_kind,
        "ground_rects": [],
        "walls": [],
        "obstacles": [],
        "glass": [],
        "doors": [],
        "barrels": [],
        "props": [],
        "player_spawn": player_spawn,
        "ally_spawn": ally_spawn,
        "exit_cells": exits,
    }

static func _ground(spec: Dictionary, x: int, y: int, w: int, h: int, kind: String) -> void:
    spec["ground_rects"].append([x, y, w, h, kind])

static func _wall_x(spec: Dictionary, y: int, x0: int, x1: int) -> void:
    for x in range(x0, x1 + 1):
        spec["walls"].append(Vector2i(x, y))

static func _wall_y(spec: Dictionary, x: int, y0: int, y1: int) -> void:
    for y in range(y0, y1 + 1):
        spec["walls"].append(Vector2i(x, y))

static func _cut_wall(spec: Dictionary, p: Vector2i) -> void:
    while spec["walls"].has(p):
        spec["walls"].erase(p)

static func _door(spec: Dictionary, p: Vector2i, opened := false) -> void:
    _cut_wall(spec, p)
    spec["doors"].append([p, opened])

static func _window(spec: Dictionary, p: Vector2i) -> void:
    _cut_wall(spec, p)
    spec["glass"].append(p)

static func _obstacle(spec: Dictionary, p: Vector2i, prop_kind := "crate") -> void:
    spec["obstacles"].append(p)
    if prop_kind != "":
        spec["props"].append([p, prop_kind])

static func _prop(spec: Dictionary, p: Vector2i, prop_kind: String) -> void:
    spec["props"].append([p, prop_kind])

static func _back_alley(variant: int) -> Dictionary:
    var exits: Array = [Vector2i(9, 16)]
    if variant == 1:
        exits.append(Vector2i(10, 1))
    var spec := _spec("asphalt", Vector2i(9, 14), Vector2i(8, 14), exits)
    _ground(spec, 5, 1, 10, 16, "asphalt")
    _ground(spec, 5, 1, 1, 16, "sidewalk")
    _ground(spec, 14, 1, 1, 16, "sidewalk")
    _wall_y(spec, 4, 1, 16)
    _wall_y(spec, 15, 1, 16)
    _wall_x(spec, 8, 5, 14)
    _door(spec, Vector2i(9, 8), false)
    _obstacle(spec, Vector2i(5, 5), "dumpster")
    _obstacle(spec, Vector2i(6, 5), "dumpster")
    _obstacle(spec, Vector2i(13, 11), "dumpster")
    _obstacle(spec, Vector2i(14, 11), "dumpster")
    _obstacle(spec, Vector2i(12, 4), "trash")
    _prop(spec, Vector2i(14, 3), "neon_sign")
    spec["barrels"].append(Vector2i(6, 12))
    return spec

static func _gas_station(variant: int) -> Dictionary:
    var exits: Array = [Vector2i(2, 16), Vector2i(17, 16)]
    if variant == 1:
        exits.append(Vector2i(1, 11))
    var spec := _spec("asphalt", Vector2i(4, 14), Vector2i(5, 14), exits)
    _ground(spec, 1, 12, 18, 5, "road")
    _ground(spec, 11, 2, 8, 9, "tile")
    _wall_x(spec, 2, 11, 18)
    _wall_x(spec, 10, 11, 18)
    _wall_y(spec, 11, 2, 10)
    _wall_y(spec, 18, 2, 10)
    _door(spec, Vector2i(11, 7), false)
    _window(spec, Vector2i(11, 5))
    _window(spec, Vector2i(11, 6))
    _window(spec, Vector2i(14, 10))
    _window(spec, Vector2i(15, 10))
    for p in [Vector2i(6, 5), Vector2i(9, 5), Vector2i(6, 8), Vector2i(9, 8)]:
        _obstacle(spec, p, "gas_pump")
    _obstacle(spec, Vector2i(3, 9), "car")
    _obstacle(spec, Vector2i(4, 9), "car")
    _obstacle(spec, Vector2i(13, 4), "counter")
    _obstacle(spec, Vector2i(14, 4), "counter")
    _obstacle(spec, Vector2i(16, 4), "store_shelf")
    _obstacle(spec, Vector2i(16, 7), "store_shelf")
    _obstacle(spec, Vector2i(3, 3), "gas_sign")
    _obstacle(spec, Vector2i(10, 10), "ice_box")
    spec["barrels"].append(Vector2i(17, 8))
    return spec

static func _house(variant: int) -> Dictionary:
    var exits: Array = [Vector2i(10, 15)]
    if variant == 1:
        exits.append(Vector2i(15, 1))
    var spec := _spec("grass", Vector2i(10, 12), Vector2i(11, 12), exits)
    _ground(spec, 5, 2, 13, 13, "wood")
    _ground(spec, 6, 3, 6, 5, "carpet")
    _ground(spec, 13, 3, 4, 5, "linoleum")
    _wall_x(spec, 2, 5, 17)
    _wall_x(spec, 14, 5, 17)
    _wall_y(spec, 5, 2, 14)
    _wall_y(spec, 17, 2, 14)
    _door(spec, Vector2i(10, 14), false)
    if variant == 1:
        _door(spec, Vector2i(15, 2), false)
    _wall_x(spec, 8, 6, 16)
    _door(spec, Vector2i(9, 8), false)
    _door(spec, Vector2i(14, 8), false)
    _wall_y(spec, 12, 3, 7)
    _door(spec, Vector2i(12, 5), false)
    _window(spec, Vector2i(6, 14))
    _window(spec, Vector2i(16, 14))
    _window(spec, Vector2i(5, 5))
    _obstacle(spec, Vector2i(7, 11), "couch")
    _obstacle(spec, Vector2i(8, 11), "couch")
    _obstacle(spec, Vector2i(14, 11), "table")
    _obstacle(spec, Vector2i(7, 4), "bed")
    _obstacle(spec, Vector2i(8, 4), "bed")
    _obstacle(spec, Vector2i(14, 4), "kitchen")
    _obstacle(spec, Vector2i(15, 4), "kitchen")
    _obstacle(spec, Vector2i(16, 6), "fridge")
    return spec

static func _apartment(variant: int) -> Dictionary:
    var exits: Array = [Vector2i(9, 15)]
    if variant == 1:
        exits.append(Vector2i(17, 8))
    var spec := _spec("sidewalk", Vector2i(9, 13), Vector2i(10, 13), exits)
    _ground(spec, 3, 2, 15, 13, "carpet")
    _ground(spec, 8, 2, 3, 13, "concrete")
    _wall_x(spec, 2, 3, 17)
    _wall_x(spec, 14, 3, 17)
    _wall_y(spec, 3, 2, 14)
    _wall_y(spec, 17, 2, 14)
    _door(spec, Vector2i(9, 14), false)
    if variant == 1:
        _door(spec, Vector2i(17, 8), false)
    _wall_y(spec, 7, 3, 13)
    _wall_y(spec, 11, 3, 13)
    for y in [5, 9, 12]:
        _door(spec, Vector2i(7, y), false)
        _door(spec, Vector2i(11, y), false)
    _wall_x(spec, 7, 4, 6)
    _wall_x(spec, 10, 4, 6)
    _wall_x(spec, 7, 12, 16)
    _wall_x(spec, 10, 12, 16)
    _obstacle(spec, Vector2i(5, 4), "bed")
    _obstacle(spec, Vector2i(5, 12), "couch")
    _obstacle(spec, Vector2i(14, 4), "table")
    _obstacle(spec, Vector2i(14, 12), "bed")
    _obstacle(spec, Vector2i(16, 6), "washer")
    _prop(spec, Vector2i(9, 3), "apt_sign")
    return spec

static func _corner_store(variant: int) -> Dictionary:
    var exits: Array = [Vector2i(10, 15)]
    if variant == 1:
        exits.append(Vector2i(18, 7))
    var spec := _spec("sidewalk", Vector2i(10, 12), Vector2i(9, 12), exits)
    _ground(spec, 4, 3, 15, 11, "tile")
    _wall_x(spec, 3, 4, 18)
    _wall_x(spec, 13, 4, 18)
    _wall_y(spec, 4, 3, 13)
    _wall_y(spec, 18, 3, 13)
    _door(spec, Vector2i(10, 13), false)
    if variant == 1:
        _door(spec, Vector2i(18, 7), false)
    for x in [6, 7, 13, 14, 15]:
        _window(spec, Vector2i(x, 13))
    for y in range(5, 11):
        if y not in [7, 9]:
            _obstacle(spec, Vector2i(8, y), "store_shelf")
            _obstacle(spec, Vector2i(12, y), "store_shelf")
            _obstacle(spec, Vector2i(16, y), "store_shelf")
    _obstacle(spec, Vector2i(6, 5), "counter")
    _obstacle(spec, Vector2i(6, 6), "counter")
    _obstacle(spec, Vector2i(17, 11), "vending")
    _prop(spec, Vector2i(10, 4), "shop_sign")
    spec["barrels"].append(Vector2i(17, 4))
    return spec

static func _warehouse_yard(variant: int) -> Dictionary:
    var exits: Array = [Vector2i(2, 16), Vector2i(17, 16)]
    if variant == 1:
        exits.append(Vector2i(1, 8))
    var spec := _spec("concrete", Vector2i(4, 14), Vector2i(5, 14), exits)
    _ground(spec, 10, 2, 9, 9, "concrete")
    _ground(spec, 1, 11, 18, 6, "asphalt")
    _wall_x(spec, 2, 10, 18)
    _wall_x(spec, 10, 10, 18)
    _wall_y(spec, 10, 2, 10)
    _wall_y(spec, 18, 2, 10)
    _door(spec, Vector2i(10, 7), true)
    _door(spec, Vector2i(10, 8), true)
    for p in [Vector2i(5,5), Vector2i(6,5), Vector2i(5,6), Vector2i(13,5), Vector2i(14,5), Vector2i(15,5), Vector2i(7,10), Vector2i(8,10), Vector2i(14,12), Vector2i(15,12)]:
        _obstacle(spec, p, "crate" if p.x >= 10 else "pallet")
    _obstacle(spec, Vector2i(3, 10), "forklift")
    _obstacle(spec, Vector2i(4, 10), "forklift")
    _obstacle(spec, Vector2i(16, 8), "machine")
    _obstacle(spec, Vector2i(16, 9), "machine")
    spec["barrels"].append(Vector2i(12, 8))
    spec["barrels"].append(Vector2i(17, 13))
    _prop(spec, Vector2i(12, 3), "warehouse_sign")
    return spec

static func _drainage_wash(variant: int) -> Dictionary:
    var exits: Array = [Vector2i(9, 16)]
    if variant == 1:
        exits.append(Vector2i(10, 1))
    var spec := _spec("dirt", Vector2i(9, 14), Vector2i(10, 14), exits)
    _ground(spec, 5, 1, 10, 16, "wash_concrete")
    _ground(spec, 7, 1, 6, 16, "dirt")
    _wall_y(spec, 4, 1, 16)
    _wall_y(spec, 15, 1, 16)
    for p in [Vector2i(6,4), Vector2i(13,5), Vector2i(6,10), Vector2i(13,12)]:
        _obstacle(spec, p, "scrub")
    _obstacle(spec, Vector2i(8, 8), "shopping_cart")
    _obstacle(spec, Vector2i(11, 6), "culvert_debris")
    _prop(spec, Vector2i(10, 3), "wash_sign")
    return spec
