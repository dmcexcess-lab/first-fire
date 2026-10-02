extends RefCounted
class_name FFExpeditionRules

const STARTING_ROUTES := ["Camp Perimeter", "Nearby Streets"]
const ROUTE_HOURS := {
    "Camp Perimeter": 3.0,
    "Nearby Streets": 5.0,
    "Residential Blocks": 8.0,
    "Commercial Fringe": 12.0,
    "Industrial Edge": 18.0,
}
const ROUTE_UNLOCK_KEYS := {
    "Residential Blocks": "long_range_residential",
    "Commercial Fringe": "long_range_commercial",
    "Industrial Edge": "long_range_industrial",
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

static func route_hours(zone: String) -> float:
    return float(ROUTE_HOURS.get(zone, 0.0))

static func route_duration_seconds(zone: String, day_seconds: float = 120.0) -> float:
    return route_hours(zone) * maxf(1.0, day_seconds) / 24.0

static func route_unlock_key(zone: String) -> String:
    return str(ROUTE_UNLOCK_KEYS.get(zone, ""))

static func route_is_unlocked(zone: String, unlocks: Dictionary) -> bool:
    if STARTING_ROUTES.has(zone):
        return true
    var key := route_unlock_key(zone)
    return key != "" and bool(unlocks.get(key, false))

static func route_lock_text(zone: String) -> String:
    return "" if STARTING_ROUTES.has(zone) else "Requires long-range travel"

static func travel_duration(base_duration: float, unused_agility: float = 0.0) -> float:
    # Compatibility helper for special-site callers. Normal Send Out routes use
    # fixed authored route hours and are not shortened by survivor stats.
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
