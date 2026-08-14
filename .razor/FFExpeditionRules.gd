extends RefCounted
class_name FFExpeditionRules

# Pure expedition rules live here so travel/logistics changes (especially vehicles)
# do not spread back through Game.gd.
const TACTICAL_EVENT_SHARE := 0.55
const ZONE_CAPS := {
    "Camp Perimeter": 3,
    "Nearby Streets": 4,
    "Residential Blocks": 5,
    "Commercial Fringe": 6,
    "Industrial Edge": 7,
}

static func travel_duration(base_duration: float, average_survival: float, vehicle_speed_multiplier: float = 1.0) -> float:
    var reduction: float = minf(0.20, average_survival * 0.025)
    var speed: float = maxf(0.05, vehicle_speed_multiplier)
    return (base_duration * (1.0 - reduction)) / speed

static func should_force_recruit(population: int, shelter_capacity: int, eligible_count: int, recruit_eligible: bool) -> bool:
    if not recruit_eligible or population >= shelter_capacity + 1:
        return false
    if population == 1:
        return eligible_count >= 5
    if population >= 2 and population < 5:
        return eligible_count >= 7
    return false

static func should_use_tactical_event(zone: String, rng: RandomNumberGenerator) -> bool:
    return zone != "Camp Perimeter" and rng.randf() < TACTICAL_EVENT_SHARE

static func zone_cap(zone: String) -> int:
    return int(ZONE_CAPS.get(zone, 3))

static func loot_item_target(zone: String, rng: RandomNumberGenerator) -> int:
    var r: float = rng.randf()
    # Total routine items. Empty runs fall with distance while maximum haul rises.
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
