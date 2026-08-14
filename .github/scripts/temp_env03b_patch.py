from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


def replace_between(text: str, start: str, end: str, replacement: str, label: str) -> str:
    a = text.find(start)
    if a < 0:
        raise SystemExit(f"{label}: start marker missing")
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f"{label}: end marker missing")
    return text[:a] + replacement + text[b:]


# ---------------------------------------------------------------------------
# New durable tactical environment owner.
# ---------------------------------------------------------------------------
env = r'''extends RefCounted
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
'''
Path("game/scripts/FFTacticalEnvironments.gd").write_text(env)


# ---------------------------------------------------------------------------
# Scenario catalog: objective selection stays here; physical place selection
# delegates to the environment owner.
# ---------------------------------------------------------------------------
scenarios = r'''extends RefCounted
class_name FFTacticalScenarios

const Environments = preload("res://scripts/FFTacticalEnvironments.gd")

# Objective mix is independent from physical place. The same gas station or
# apartment can host an ambush, a search, or a rescue when compatible.
const KIND_WEIGHTS := {
    "Camp Perimeter": [["explore", 0.65], ["ambush", 1.00]],
    "Nearby Streets": [["rescue", 0.35], ["explore", 0.70], ["ambush", 1.00]],
    "Residential Blocks": [["rescue", 0.30], ["explore", 0.75], ["ambush", 1.00]],
    "Commercial Fringe": [["rescue", 0.20], ["explore", 0.70], ["ambush", 1.00]],
    "Industrial Edge": [["rescue", 0.15], ["explore", 0.50], ["ambush", 1.00]],
}

static func pick_kind(zone: String, rng: RandomNumberGenerator) -> String:
    var roll := rng.randf()
    var weights: Array = KIND_WEIGHTS.get(zone, KIND_WEIGHTS["Industrial Edge"])
    for entry in weights:
        if roll < float(entry[1]):
            return str(entry[0])
    return "ambush"

static func pick_environment(zone: String, kind: String, rng: RandomNumberGenerator) -> String:
    return Environments.pick(zone, kind, rng)

static func environment_name(environment_id: String) -> String:
    return Environments.display_name(environment_id)

static func environment_variant(environment_id: String, rng: RandomNumberGenerator) -> int:
    return Environments.pick_variant(environment_id, rng)
'''
Path("game/scripts/FFTacticalScenarios.gd").write_text(scenarios)


# ---------------------------------------------------------------------------
# Game orchestration: choose objective, then choose place independently.
# Retreating before the optional objective is a valid escape, just without its
# tactical objective reward/recruit result.
# ---------------------------------------------------------------------------
p = Path("game/scripts/Game.gd")
t = p.read_text()
t = replace_once(
    t,
    '''func _combat_location_name(zone, kind):
    return TacticalScenarios.location_name(str(zone), str(kind), rng)

''',
    '',
    'obsolete tactical location helper',
)
t = replace_once(
    t,
    '''    current_combat = {
        "uid": "%d-%d-%d" % [day, int(exp["id"]), rng.randi_range(1000, 999999)],
        "expedition_id": int(exp["id"]),
        "survivor_ids": ids.duplicate(true),
        "zone": str(exp["zone"]),
        "kind": str(exp.get("combat_kind", "ambush")),
        "location_name": _combat_location_name(str(exp["zone"]), str(exp.get("combat_kind", "ambush"))),
        "layout": TacticalScenarios.layout_index(rng),
        "seed": rng.randi_range(1, 2147483000),
''',
    '''    var combat_kind := str(exp.get("combat_kind", "ambush"))
    var environment_id := TacticalScenarios.pick_environment(str(exp["zone"]), combat_kind, rng)
    var environment_variant := TacticalScenarios.environment_variant(environment_id, rng)
    current_combat = {
        "uid": "%d-%d-%d" % [day, int(exp["id"]), rng.randi_range(1000, 999999)],
        "expedition_id": int(exp["id"]),
        "survivor_ids": ids.duplicate(true),
        "zone": str(exp["zone"]),
        "kind": combat_kind,
        "environment_id": environment_id,
        "environment_variant": environment_variant,
        "location_name": TacticalScenarios.environment_name(environment_id),
        "seed": rng.randi_range(1, 2147483000),
''',
    'combat environment context',
)
t = replace_once(
    t,
    '''    if kind == "rescue" and bool(result.get("rescued", false)):
        _queue_recruit_offer(event, "A Survivor Makes It Out", "You get the stranger out of %s alive. Away from the infected and with a little room to breathe, they finally decide whether they trust First Fire enough to come back with you." % place, "tactical_rescue")
    elif kind == "explore" and bool(result.get("objective_done", false)):
        var reward = _grant_tactical_explore_reward(exp, lead)
        _queue_field_result(event, "%s Searched" % place, "You searched the place under real pressure and got back out. Extra find: %s." % reward, "The party searched %s tactically and escaped." % place)
    else:
        _queue_field_result(event, "Broke Contact", "The ambush never became a stand-up fight. You made space, found the exit, and got away from %s." % place, "The party escaped a tactical ambush at %s." % place)
''',
    '''    if kind == "rescue" and bool(result.get("rescued", false)):
        _queue_recruit_offer(event, "A Survivor Makes It Out", "You get the stranger out of %s alive. Away from the infected and with a little room to breathe, they finally decide whether they trust First Fire enough to come back with you." % place, "tactical_rescue")
    elif kind == "explore" and bool(result.get("objective_done", false)):
        var reward = _grant_tactical_explore_reward(exp, lead)
        _queue_field_result(event, "%s Searched" % place, "You searched the place under real pressure and got back out. Extra find: %s." % reward, "The party searched %s tactically and escaped." % place)
    elif kind in ["rescue", "explore"] and not bool(result.get("objective_done", false)):
        _queue_field_result(event, "Withdrew from %s" % place, "You found a way out and chose survival over the objective. The expedition can continue, but the opportunity here is gone.", "The party withdrew from %s before completing the tactical objective." % place)
    else:
        _queue_field_result(event, "Broke Contact", "The ambush never became a stand-up fight. You made space, found an exit, and got away from %s." % place, "The party escaped a tactical ambush at %s." % place)
''',
    'retreat result handling',
)
p.write_text(t)


# ---------------------------------------------------------------------------
# Tactical runtime: consume authored environment spec, draw place-specific props,
# and make every marked exit immediately valid even before the optional objective.
# ---------------------------------------------------------------------------
p = Path("game/scripts/FFCombat.gd")
t = p.read_text()
t = replace_once(
    t,
    'const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\n',
    'const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\nconst TacticalEnvironments = preload("res://scripts/FFTacticalEnvironments.gd")\n',
    'environment preload',
)
t = replace_once(t, 'const W := 20\nconst H := 18\n', 'const W := TacticalEnvironments.BOARD_W\nconst H := TacticalEnvironments.BOARD_H\n', 'board dimensions')
t = replace_once(
    t,
    '''var barrels := {}
var base_glass := {}
var base_barrels := {}
''',
    '''var barrels := {}
var props := {}
var ground := {}
var base_glass := {}
var base_barrels := {}
''',
    'environment render state',
)
t = replace_once(
    t,
    'var exit_cell := Vector2i(1, H - 2)\nvar objective_cell := Vector2i(W - 3, 3)\n',
    'var exit_cells: Array = []\nvar player_spawn := Vector2i(2, H - 2)\nvar ally_spawn := Vector2i(2, H - 3)\nvar environment_id := "back_alley"\nvar objective_cell := Vector2i(W - 3, 3)\n',
    'multi-exit state',
)
t = replace_once(
    t,
    '''    tick = int(runtime.get("tick", 0))
    location_name = str(context.get("location_name", "Field Encounter"))
    build_map(int(context.get("layout", 0)))
''',
    '''    tick = int(runtime.get("tick", 0))
    var legacy_layout := int(context.get("layout", 0))
    environment_id = str(context.get("environment_id", TacticalEnvironments.legacy_environment(legacy_layout, str(context.get("zone", "Nearby Streets")))))
    var environment_variant := int(context.get("environment_variant", legacy_layout))
    location_name = str(context.get("location_name", TacticalEnvironments.display_name(environment_id)))
    build_map(environment_id, environment_variant)
''',
    'encounter environment startup',
)
t = replace_once(
    t,
    '''    player = make_actor(lead, Vector2i(2, H - 2), true)
    ally = {}
    if ids.size() > 1:
        var companion = Game.get_survivor(ids[1])
        if companion != null and companion.get("condition", "Dead") != "Dead":
            ally = make_actor(companion, Vector2i(2, H - 3), false)
''',
    '''    player = make_actor(lead, player_spawn, true)
    ally = {}
    if ids.size() > 1:
        var companion = Game.get_survivor(ids[1])
        if companion != null and companion.get("condition", "Dead") != "Dead":
            ally = make_actor(companion, ally_spawn, false)
''',
    'party authored spawns',
)

new_build_map = r'''func build_map(new_environment_id: String, variant: int):
    environment_id = new_environment_id
    walls.clear(); obstacles.clear(); glass.clear(); doors.clear(); barrels.clear(); props.clear(); ground.clear(); exit_cells.clear()
    for x in range(W):
        walls[Vector2i(x, 0)] = true
        walls[Vector2i(x, H - 1)] = true
    for y in range(H):
        walls[Vector2i(0, y)] = true
        walls[Vector2i(W - 1, y)] = true

    var spec: Dictionary = TacticalEnvironments.build_layout(environment_id, variant)
    player_spawn = spec.get("player_spawn", Vector2i(2, H - 2))
    ally_spawn = spec.get("ally_spawn", Vector2i(2, H - 3))
    exit_cells = spec.get("exit_cells", [Vector2i(1, H - 2)]).duplicate()
    var default_ground := str(spec.get("default_ground", TacticalEnvironments.default_ground(environment_id)))
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            ground[Vector2i(x, y)] = default_ground
    for entry in spec.get("ground_rects", []):
        var gx := int(entry[0]); var gy := int(entry[1]); var gw := int(entry[2]); var gh := int(entry[3]); var ground_kind := str(entry[4])
        for y in range(gy, gy + gh):
            for x in range(gx, gx + gw):
                var gp := Vector2i(x, y)
                if inside(gp): ground[gp] = ground_kind
    for p in spec.get("walls", []): walls[p] = true
    for p in spec.get("obstacles", []): obstacles[p] = true
    for p in spec.get("glass", []): glass[p] = true
    for entry in spec.get("doors", []): doors[entry[0]] = bool(entry[1])
    for p in spec.get("barrels", []): barrels[p] = true
    for entry in spec.get("props", []): props[entry[0]] = str(entry[1])

    base_glass = glass.duplicate(true)
    base_barrels = barrels.duplicate(true)
    objective_cell = choose_far_open_cell()
    rescue_cell = objective_cell

func choose_far_open_cell() -> Vector2i:
    # Objectives are selected only from cells physically reachable from the
    # authored party spawn. Closed doors/glass count as traversable because the
    # tactical rules let the player open/break them.
    var distances := {player_spawn: 0}
    var queue: Array = [player_spawn]
    while not queue.is_empty():
        var p: Vector2i = queue.pop_front()
        var base_distance := int(distances[p])
        for d in DIRS:
            var n := p + d
            if not inside(n) or walls.has(n) or obstacles.has(n) or distances.has(n):
                continue
            distances[n] = base_distance + 1
            queue.append(n)
    var farthest := 0
    for p in distances.keys():
        if not exit_cells.has(p):
            farthest = maxi(farthest, int(distances[p]))
    var candidates: Array = []
    var threshold := maxi(6, farthest - 3)
    for p in distances.keys():
        if not exit_cells.has(p) and int(distances[p]) >= threshold:
            candidates.append(p)
    if candidates.is_empty():
        return player_spawn
    return candidates[rng.randi_range(0, candidates.size() - 1)]

'''
t = replace_between(t, 'func build_map(layout: int):\n', 'func spawn_zombies():\n', new_build_map, 'environment map builder')

t = t.replace('p == player.get("pos", Vector2i(2, H - 2))', 'p == player.get("pos", player_spawn)')
t = t.replace('var d = manhattan(Vector2i(2, H - 2), p)', 'var d = manhattan(player_spawn, p)')
t = t.replace('"target": Vector2i(2, H - 2) if state == "INVESTIGATE" else Vector2i(-1,-1),', '"target": player_spawn if state == "INVESTIGATE" else Vector2i(-1,-1),')
t = t.replace('"heard": Vector2i(2, H - 2) if state == "INVESTIGATE" else Vector2i(-1,-1),', '"heard": player_spawn if state == "INVESTIGATE" else Vector2i(-1,-1),')

new_check = r'''func check_objective_and_exit():
    var kind := str(context.get("kind", "ambush"))
    if not objective_done and (kind == "explore" or kind == "rescue"):
        var target = rescue_cell if kind == "rescue" else objective_cell
        if player.pos == target or (not ally.is_empty() and not ally.dead and ally.pos == target):
            objective_done = true
            if kind == "rescue":
                msg = "Survivor found. Reach any exit."
                emit_noise(target, 9, "struggle", true)
            else:
                msg = "Search complete. Reach any exit."
                emit_noise(target, 10, "rummaging", true)
    if exit_cells.has(player.pos):
        if objective_done:
            msg = "You made it out."
        elif kind == "ambush":
            msg = "You broke contact and escaped."
        else:
            msg = "You abandon the objective and get out alive."
        finish_encounter("escaped")

'''
t = replace_between(t, 'func check_objective_and_exit():\n', 'func interact():\n', new_check, 'universal escape rule')

# Draw escape markers after fog so every known route remains readable on phone.
t = replace_once(
    t,
    '''    draw_map()
    draw_units()
    draw_fog()
    draw_sounds()
''',
    '''    draw_map()
    draw_units()
    draw_fog()
    draw_escape_markers()
    draw_sounds()
''',
    'escape draw layer',
)

new_draw_map = r'''func draw_map():
    var wall_color := TacticalEnvironments.wall_color(environment_id)
    var grid_color := TacticalEnvironments.grid_color(environment_id)
    for y in range(H):
        for x in range(W):
            var p := Vector2i(x,y)
            var r := Rect2(x*TILE,y*TILE,TILE,TILE)
            var ground_kind := str(ground.get(p, TacticalEnvironments.default_ground(environment_id)))
            draw_rect(r, TacticalEnvironments.ground_color(ground_kind))
            draw_rect(r, grid_color, false, 1)
            if walls.has(p):
                draw_rect(r, wall_color)
                draw_rect(r.grow(-3), wall_color.lightened(0.08), false, 1)
            elif doors.has(p):
                draw_rect(r.grow(-4), Color(.34,.24,.14) if not doors[p] else Color(.18,.15,.11), false, 3)
            elif glass.has(p):
                draw_line(r.position+Vector2(3,TILE-4), r.position+Vector2(TILE-3,4), Color(.55,.75,.82), 2)
                draw_line(r.position+Vector2(3,4), r.position+Vector2(TILE-3,TILE-4), Color(.40,.62,.70,.65), 1)
            elif barrels.has(p):
                draw_circle(cell_center(p), 8, Color(.55,.25,.10))
                draw_circle(cell_center(p), 8, Color(.85,.48,.16), false, 2)
            elif props.has(p):
                draw_environment_prop(p, str(props[p]))
            elif obstacles.has(p):
                draw_rect(r.grow(-3), Color(.30,.25,.18))
    var kind := str(context.get("kind","ambush"))
    if kind == "explore" and not objective_done:
        draw_rect(Rect2(objective_cell.x*TILE+5,objective_cell.y*TILE+5,TILE-10,TILE-10), Color(.95,.75,.20), false, 3)
    elif kind == "rescue" and not objective_done:
        draw_circle(cell_center(rescue_cell), 8, Color(.95,.75,.20), false, 3)
        draw_string(font, cell_center(rescue_cell)+Vector2(-9,-12), "SOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.95,.8,.35))

func draw_escape_markers():
    for p in exit_cells:
        var c := cell_center(p)
        var known := visible_cells.has(p) or memory.has(p)
        var alpha := 1.0 if known else 0.72
        var color := Color(0.18, 0.82, 0.38, alpha)
        draw_rect(Rect2(p.x*TILE+3,p.y*TILE+3,TILE-6,TILE-6), color, false, 3)
        draw_line(c + Vector2(-6, 0), c + Vector2(5, 0), color, 2)
        draw_line(c + Vector2(1, -4), c + Vector2(6, 0), color, 2)
        draw_line(c + Vector2(1, 4), c + Vector2(6, 0), color, 2)
        draw_string(font, c + Vector2(-12,-10), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 24, 7, color)

func draw_environment_prop(p: Vector2i, kind: String):
    var r := Rect2(p.x*TILE,p.y*TILE,TILE,TILE)
    var c := cell_center(p)
    match kind:
        "dumpster":
            draw_rect(r.grow(-3), Color("304b3d"))
            draw_line(r.position+Vector2(4,7), r.position+Vector2(TILE-4,7), Color("6d806f"), 2)
        "trash":
            draw_circle(c, 7, Color("4c4941")); draw_line(c-Vector2(5,3), c+Vector2(5,3), Color("827966"), 1)
        "neon_sign":
            draw_rect(r.grow(-5), Color("5a243f")); draw_rect(r.grow(-7), TacticalEnvironments.accent_color(environment_id), false, 2)
            draw_string(font, c+Vector2(-9,3), "OPEN", HORIZONTAL_ALIGNMENT_CENTER, 18, 6, Color("f3a8cd"))
        "gas_pump":
            draw_rect(r.grow(-5), Color("d9d6c8")); draw_rect(Rect2(r.position+Vector2(7,5),Vector2(12,7)),Color("30383b"))
            draw_circle(c+Vector2(7,4),2,Color("d9b14b"))
        "car":
            draw_rect(r.grow(-2), Color("4a5961")); draw_rect(r.grow(-6), Color("9bb1b8")); draw_circle(c+Vector2(-7,8),2,Color("141718")); draw_circle(c+Vector2(7,8),2,Color("141718"))
        "counter":
            draw_rect(r.grow(-3), Color("735a3f")); draw_line(r.position+Vector2(3,7),r.position+Vector2(TILE-3,7),Color("b09a76"),2)
        "store_shelf":
            draw_rect(r.grow(-4), Color("595b58")); draw_line(r.position+Vector2(4,9),r.position+Vector2(TILE-4,9),Color("b0a77d"),2); draw_line(r.position+Vector2(4,16),r.position+Vector2(TILE-4,16),Color("8e9b7d"),2)
        "gas_sign":
            draw_rect(r.grow(-4), Color("383b3b")); draw_string(font,c+Vector2(-9,4),"GAS",HORIZONTAL_ALIGNMENT_CENTER,18,8,Color("ead25d"))
        "ice_box":
            draw_rect(r.grow(-3), Color("d9e4e4")); draw_string(font,c+Vector2(-8,4),"ICE",HORIZONTAL_ALIGNMENT_CENTER,16,7,Color("507b9b"))
        "couch":
            draw_rect(r.grow(-3), Color("765344")); draw_rect(r.grow(-7), Color("9a705c"), false, 2)
        "table":
            draw_circle(c,8,Color("765b3e")); draw_circle(c,8,Color("b08b62"),false,2)
        "bed":
            draw_rect(r.grow(-3), Color("738291")); draw_rect(Rect2(r.position+Vector2(4,4),Vector2(TILE-8,6)),Color("d6d4c6"))
        "kitchen":
            draw_rect(r.grow(-3), Color("8b8b83")); draw_circle(c,4,Color("272b2c"),false,2)
        "fridge":
            draw_rect(r.grow(-3), Color("c6c9c5")); draw_line(c+Vector2(0,-8),c+Vector2(0,8),Color("7c807d"),1)
        "washer":
            draw_rect(r.grow(-3), Color("b9bbb6")); draw_circle(c,6,Color("4e6268"),false,2)
        "apt_sign":
            draw_rect(r.grow(-5), Color("4e5660")); draw_string(font,c+Vector2(-8,4),"APT",HORIZONTAL_ALIGNMENT_CENTER,16,7,Color("c5d0db"))
        "vending":
            draw_rect(r.grow(-3), Color("87443d")); draw_rect(r.grow(-7),Color("e6c770"),false,2)
        "shop_sign":
            draw_rect(r.grow(-5), Color("315d59")); draw_string(font,c+Vector2(-10,4),"SHOP",HORIZONTAL_ALIGNMENT_CENTER,20,7,Color("9fe0d8"))
        "crate":
            draw_rect(r.grow(-3), Color("7a5d3a")); draw_line(r.position+Vector2(4,4),r.end-Vector2(4,4),Color("b18a58"),1); draw_line(Vector2(r.end.x-4,r.position.y+4),Vector2(r.position.x+4,r.end.y-4),Color("b18a58"),1)
        "pallet":
            draw_rect(r.grow(-4), Color("765c3d"), false, 3); draw_line(r.position+Vector2(6,4),r.position+Vector2(6,TILE-4),Color("a88658"),2); draw_line(r.position+Vector2(13,4),r.position+Vector2(13,TILE-4),Color("a88658"),2)
        "forklift":
            draw_rect(r.grow(-3), Color("c98d2d")); draw_line(c+Vector2(8,-8),c+Vector2(8,8),Color("2b2c2b"),2)
        "machine":
            draw_rect(r.grow(-3), Color("4e5b58")); draw_circle(c,5,Color("202626")); draw_rect(Rect2(r.position+Vector2(5,4),Vector2(5,3)),Color("d58d36"))
        "warehouse_sign":
            draw_rect(r.grow(-5), Color("51595a")); draw_string(font,c+Vector2(-9,4),"BAY",HORIZONTAL_ALIGNMENT_CENTER,18,7,Color("e2a04f"))
        "scrub":
            draw_circle(c+Vector2(-4,2),6,Color("667047")); draw_circle(c+Vector2(4,-2),6,Color("55623d"))
        "shopping_cart":
            draw_rect(r.grow(-5), Color("8d9390"), false, 2); draw_circle(c+Vector2(-6,8),2,Color("242727")); draw_circle(c+Vector2(6,8),2,Color("242727"))
        "culvert_debris":
            draw_circle(c,9,Color("5a5148")); draw_line(c-Vector2(8,5),c+Vector2(8,5),Color("8b7355"),2)
        "wash_sign":
            draw_rect(r.grow(-6), Color("867253")); draw_string(font,c+Vector2(-8,4),"WASH",HORIZONTAL_ALIGNMENT_CENTER,16,6,Color("e2c695"))
        _:
            draw_rect(r.grow(-3), Color(.30,.25,.18))

'''
t = replace_between(t, 'func draw_map():\n', 'func draw_units():\n', new_draw_map, 'environment drawing')

# HUD makes the number of escape routes explicit.
t = replace_once(
    t,
    '    draw_string(font,Vector2(10,112),"Objective: %s"%objective_text,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color(.96,.80,.34))\n',
    '    objective_text += "  |  Exits %d" % exit_cells.size()\n    draw_string(font,Vector2(10,112),"Objective: %s"%objective_text,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color(.96,.80,.34))\n',
    'exit count HUD',
)

if 'exit_cell' in t:
    raise SystemExit('single exit_cell remnant remains in FFCombat')
p.write_text(t)


# ---------------------------------------------------------------------------
# Regression checks for environment ownership and escape geometry.
# ---------------------------------------------------------------------------
p = Path("game/scripts/ci/FFArchitectureSmoke.gd")
t = p.read_text()
t = replace_once(
    t,
    'const TacticalScenarios = preload("res://scripts/FFTacticalScenarios.gd")\n',
    'const TacticalScenarios = preload("res://scripts/FFTacticalScenarios.gd")\nconst TacticalEnvironments = preload("res://scripts/FFTacticalEnvironments.gd")\n',
    'environment smoke preload',
)
marker = '    if not _check(TacticalScenarios.LOCATIONS_BY_ZONE.has("Camp Perimeter"), "starting zone tactical locations"): return\n'
if marker in t:
    t = t.replace(marker, '', 1)
insert_after = '    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Camp Perimeter"), "starting zone scenario catalog"): return\n'
checks = '''    if not _check(TacticalEnvironments.display_name("gas_station") == "Gas Station", "gas station environment"): return
    if not _check(TacticalEnvironments.exit_count("house", 0) == 1, "single-exit house variant"): return
    if not _check(TacticalEnvironments.exit_count("gas_station", 1) >= 3, "multi-exit gas station variant"): return
    for environment_id in TacticalEnvironments.all_ids():
        for variant in range(TacticalEnvironments.variant_count(str(environment_id))):
            if not _check(TacticalEnvironments.validate_layout(TacticalEnvironments.build_layout(str(environment_id), variant)), "reachable exits: %s v%d" % [environment_id, variant]): return
'''
t = replace_once(t, insert_after, insert_after + checks, 'environment regression checks')
p.write_text(t)


# ---------------------------------------------------------------------------
# Durable docs.
# ---------------------------------------------------------------------------
p = Path("ARCHITECTURE.md")
t = p.read_text()
needle = '''### `FFTacticalScenarios.gd`
Tactical scenario/catalog ownership: encounter-kind weights, location catalogs, and layout selection. Alpha 0.3/0.4 should grow this toward data-driven physical versions of all outside-world events, authored chunks, objective combinations, hazards, human/survivor situations, and optional objectives.

'''
replacement = '''### `FFTacticalScenarios.gd`
Tactical objective/catalog ownership: encounter-kind weights and combination of an objective with a compatible physical environment. Objective and place are intentionally separate so the same location can host rescue, search, or ambush situations.

### `FFTacticalEnvironments.gd`
Authored tactical place ownership: recognizable 20×18 environment templates, zone compatibility, ground/theme metadata, props, party entry positions, and one-or-multiple escape routes. Current families include back alley, gas station, residential house, apartment, corner store, warehouse yard, and drainage wash. Geometry must keep every declared exit reachable from the authored party spawn.

'''
t = replace_once(t, needle, replacement, 'architecture environment ownership')
p.write_text(t)

p = Path("README_CONTEXT.md")
t = p.read_text()
t = replace_once(t, 'Current milestone: **Alpha 0.3A — Tactical Character Graphics**.', 'Current milestone: **Alpha 0.3B — Tactical Environments & Escape Routes**.', 'context milestone')
needle = '''`FFCombat.gd` owns tactical runtime mechanics. `FFTacticalScenarios.gd` owns what kind of physical situation/location/layout is created and is the intended Alpha 0.3/0.4 expansion seam. `FFTacticalVisuals.gd` owns persistent survivor appearance generation, zombie visual families, weapon silhouettes, and character rendering; tactical mechanics remain in `FFCombat.gd`.

Survivors now keep persistent modular tactical appearances. Zombies use varied civilian/worker/service/medical/decayed/heavy visual families, while those families remain cosmetic until a future gameplay change explicitly says otherwise. Equipped weapons are drawn as separate readable silhouettes beside survivors.
'''
replacement = '''`FFCombat.gd` owns tactical runtime mechanics. `FFTacticalScenarios.gd` owns encounter objectives and combines them with a compatible place. `FFTacticalEnvironments.gd` owns recognizable authored tactical places, environment geometry, props, party entry points, and escape-route definitions. `FFTacticalVisuals.gd` owns persistent survivor appearance generation, zombie visual families, weapon silhouettes, and character rendering.

Objective and place are now separate: rescue/search/ambush situations can occur across compatible back alleys, gas stations, residential houses, apartments, corner stores, warehouse yards, and drainage washes. Every tactical map declares at least one reachable exit; some have one route and some have multiple. Reaching any exit is always a valid retreat even when the optional rescue/search objective was not completed.

Survivors keep persistent modular tactical appearances. Zombies use varied civilian/worker/service/medical/decayed/heavy visual families, while those families remain cosmetic until a future gameplay change explicitly says otherwise. Equipped weapons are drawn as separate readable silhouettes beside survivors.
'''
t = replace_once(t, needle, replacement, 'context tactical environment section')
p.write_text(t)

p = Path("CHANGELOG.md")
t = p.read_text()
header = '# First Fire — Changelog\n\nThis file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n'
entry = '''## Alpha 0.3B — Tactical Environments & Escape Routes — 2026-08-13

### Recognizable Tactical Places
- Replaced the three generic board shapes with authored environment families that read as actual places: **Back Alley, Gas Station, Residential House, Apartment, Corner Store, Warehouse Yard, and Drainage Wash**.
- Environments now carry distinct ground treatments, walls, room shapes, recognizable props, entry positions, and zone-appropriate selection pools.
- Gas pumps/storefront, house rooms/furniture, apartment corridor/units, shop aisles, dumpsters/neon, warehouse pallets/machinery, and wash debris now visually identify the location before reading the HUD.
- Tactical **objective and location are separate systems**: rescue, search, and ambush objectives are combined with compatible physical places instead of selecting a generic layout from the objective.

### Universal Escape
- Every tactical environment now declares at least one reachable escape point.
- Some layouts have a single escape route; others have two or three exits.
- Reaching **any EXIT** immediately allows the party to leave, even if a rescue/search objective is unfinished. Survival is always a legitimate choice.
- Leaving before an optional objective completes forfeits that tactical opportunity/reward but does not count as a tactical disaster.
- Exit markers remain readable through fog and the tactical HUD shows the number of available routes.
- Added deterministic CI checks that every authored environment variant has reachable exits from its party spawn.

### Saves
- Save schema remains **4**. New tactical contexts store environment ID/variant, while already-open older schema-4 tactical encounters fall back to equivalent environment families.

'''
t = replace_once(t, header, header + entry, 'changelog 0.3B entry')
p.write_text(t)

print('FIRST_FIRE_ENV03B_PATCH_OK')
