extends RefCounted
class_name FFFieldEventsLegacy

# LEGACY ALPHA 0.2 PATH.
# Text-based outside-world events are intentionally isolated here so Alpha 0.3
# can remove this module after each event has a tactical/physical equivalent.
const EVENTS_BY_ZONE := {
    "Camp Perimeter": ["backpack"],
    "Nearby Streets": ["backpack", "injured_stranger", "dog"],
    "Residential Blocks": ["someone_inside", "injured_stranger", "dog", "locked_garage", "gunshot"],
    "Commercial Fringe": ["injured_stranger", "gunshot", "discover_market", "discover_clinic", "hardware_cage", "patrol_car", "barricade"],
    "Industrial Edge": ["gunshot", "barricade", "construction_trailer", "locked_office"],
}

static func select(zone: String, rng: RandomNumberGenerator) -> String:
    var pool: Array = EVENTS_BY_ZONE.get(zone, [])
    if pool.is_empty():
        return ""
    return str(pool[rng.randi_range(0, pool.size() - 1)])

static func all_keys() -> Array:
    var result: Array = []
    for pool in EVENTS_BY_ZONE.values():
        for key in pool:
            if not result.has(key):
                result.append(key)
    return result
