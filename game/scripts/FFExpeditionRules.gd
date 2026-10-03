extends RefCounted
class_name FFExpeditionRules

const MAX_PARTY_SIZE := 2
const VEHICLE_UNLOCK_FLAG := "expedition_vehicle_unlocked"
const STARTING_ROUTES := ["Camp Perimeter", "Nearby Streets", "Residential Blocks", "Commercial Fringe"]
const ROUTE_HOURS := {
    "Camp Perimeter": 3.0,
    "Nearby Streets": 5.0,
    "Residential Blocks": 8.0,
    "Commercial Fringe": 12.0,
    "Industrial Edge": 18.0,
}
const ROUTE_BANDS := {
    "Camp Perimeter": "VERY SHORT",
    "Nearby Streets": "SHORT",
    "Residential Blocks": "MEDIUM",
    "Commercial Fringe": "FAR",
    "Industrial Edge": "VERY FAR",
}
const ROUTE_COST_PER_SURVIVOR := {
    "Camp Perimeter": {"Cooked Food":0, "Clean Water":0},
    "Nearby Streets": {"Cooked Food":0, "Clean Water":0},
    "Residential Blocks": {"Cooked Food":1, "Clean Water":1},
    "Commercial Fringe": {"Cooked Food":2, "Clean Water":2},
    "Industrial Edge": {"Cooked Food":3, "Clean Water":3},
}
const ZONE_CAPS := {
    "Camp Perimeter": 3,
    "Nearby Streets": 4,
    "Residential Blocks": 5,
    "Commercial Fringe": 6,
    "Industrial Edge": 7,
}

static func starting_routes() -> Array:
    return STARTING_ROUTES.duplicate()

static func route_band(zone: String) -> String:
    return str(ROUTE_BANDS.get(zone, "UNKNOWN"))

static func route_hours(zone: String) -> float:
    return float(ROUTE_HOURS.get(zone, 0.0))

static func route_duration_seconds(zone: String, day_seconds: float = 300.0) -> float:
    return route_hours(zone) * maxf(1.0, day_seconds) / 24.0

static func route_fatigue_hit(zone: String) -> float:
    # Expedition fatigue is intentionally a large return consequence and scales
    # directly from the authored 3/5/8/12/18-hour distance bands.
    var hours := route_hours(zone)
    if hours <= 0.0:
        return 0.0
    return minf(85.0, 10.0 + hours * 4.0)

static func vehicle_unlocked(flags: Dictionary) -> bool:
    return bool(flags.get(VEHICLE_UNLOCK_FLAG, false))

static func route_is_unlocked(zone: String, flags: Dictionary) -> bool:
    if zone == "Industrial Edge":
        return vehicle_unlocked(flags)
    return STARTING_ROUTES.has(zone)

static func route_lock_text(zone: String) -> String:
    return "Requires Expedition Vehicle" if zone == "Industrial Edge" else ""

static func route_supply_cost(zone: String, party_size: int) -> Dictionary:
    var size := clampi(party_size, 1, MAX_PARTY_SIZE)
    var per_survivor: Dictionary = ROUTE_COST_PER_SURVIVOR.get(zone, {})
    return {
        "Cooked Food": maxi(0, int(per_survivor.get("Cooked Food", 0))) * size,
        "Clean Water": maxi(0, int(per_survivor.get("Clean Water", 0))) * size,
    }

static func route_is_free(zone: String) -> bool:
    var cost := route_supply_cost(zone, 1)
    return int(cost.get("Cooked Food", 0)) == 0 and int(cost.get("Clean Water", 0)) == 0

static func route_cost_text(zone: String, party_size: int) -> String:
    var cost := route_supply_cost(zone, party_size)
    var food := int(cost.get("Cooked Food", 0))
    var water := int(cost.get("Clean Water", 0))
    if food <= 0 and water <= 0:
        return "FREE"
    return "%d Food + %d Water" % [food, water]

static func travel_duration(base_duration: float, unused_agility: float = 0.0) -> float:
    # Compatibility helper for remaining special callers. Standard expedition
    # routes use fixed authored hours and are never shortened by stats.
    return base_duration

static func should_force_recruit(population: int, shelter_capacity: int, max_population: int, eligible_count: int, recruit_eligible: bool) -> bool:
    return false

static func tactical_event_chance(zone: String) -> float:
    return 1.0

static func should_trigger_tactical_event(zone: String, rng: RandomNumberGenerator) -> bool:
    return true

static func should_force_tactical(drought_count: int) -> bool:
    return true

static func zone_cap(zone: String) -> int:
    return int(ZONE_CAPS.get(zone, 3))

static func loot_item_target(zone: String, rng: RandomNumberGenerator) -> int:
    var r: float = rng.randf()
    if zone == "Camp Perimeter":
        if r < 0.25: return 0
        if r < 0.70: return 1
        if r < 0.95: return 2
        return 3
    if zone == "Nearby Streets":
        if r < 0.15: return 0
        if r < 0.45: return 1
        if r < 0.80: return 2
        if r < 0.95: return 3
        return 4
    if zone == "Residential Blocks":
        if r < 0.08: return 0
        if r < 0.30: return 1
        if r < 0.60: return 2
        if r < 0.85: return 3
        if r < 0.97: return 4
        return 5
    if zone == "Commercial Fringe":
        if r < 0.04: return 0
        if r < 0.20: return 1
        if r < 0.45: return 2
        if r < 0.70: return 3
        if r < 0.88: return 4
        if r < 0.97: return 5
        return 6
    if r < 0.02: return 0
    if r < 0.12: return 1
    if r < 0.32: return 2
    if r < 0.57: return 3
    if r < 0.77: return 4
    if r < 0.89: return 5
    if r < 0.97: return 6
    return 7
