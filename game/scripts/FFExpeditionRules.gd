extends RefCounted
class_name FFExpeditionRules

const TACTICAL_EVENT_CHANCE := {
    "Camp Perimeter": 0.65,
    "Nearby Streets": 0.70,
    "Residential Blocks": 0.75,
    "Commercial Fringe": 0.82,
    "Industrial Edge": 0.90,
}
const TACTICAL_DROUGHT_LIMIT := 2
const ZONE_CAPS := {
    "Camp Perimeter": 3,
    "Nearby Streets": 4,
    "Residential Blocks": 5,
    "Commercial Fringe": 6,
    "Industrial Edge": 7,
}

static func travel_duration(base_duration: float, survival_skill: float) -> float:
    var reduction: float = minf(0.20, survival_skill * 0.025)
    return base_duration * (1.0 - reduction)

static func should_force_recruit(population: int, shelter_capacity: int, max_population: int, eligible_count: int, recruit_eligible: bool) -> bool:
    if not recruit_eligible or population >= mini(shelter_capacity, max_population):
        return false
    if population <= 1:
        return eligible_count >= 4
    if population < 5:
        return eligible_count >= 6
    if population < 10:
        return eligible_count >= 8
    if population < 15:
        return eligible_count >= 10
    return eligible_count >= 12

static func tactical_event_chance(zone: String) -> float:
    return float(TACTICAL_EVENT_CHANCE.get(zone, 0.0))

static func should_trigger_tactical_event(zone: String, rng: RandomNumberGenerator) -> bool:
    return rng.randf() < tactical_event_chance(zone)

static func should_force_tactical(drought_count: int) -> bool:
    return drought_count >= TACTICAL_DROUGHT_LIMIT

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
