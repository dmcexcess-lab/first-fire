extends RefCounted
class_name FFTacticalScenarios

# Scenario selection/catalog is deliberately separate from FFCombat.gd. FFCombat
# owns tactical runtime; this file owns what kind of physical situation is created.
const KIND_WEIGHTS := {
    "Camp Perimeter": [["explore", 0.65], ["ambush", 1.00]],
    "Nearby Streets": [["rescue", 0.35], ["explore", 0.70], ["ambush", 1.00]],
    "Residential Blocks": [["rescue", 0.30], ["explore", 0.75], ["ambush", 1.00]],
    "Commercial Fringe": [["rescue", 0.20], ["explore", 0.70], ["ambush", 1.00]],
    "Industrial Edge": [["rescue", 0.15], ["explore", 0.50], ["ambush", 1.00]],
}

const AMBUSH_LOCATIONS := ["Narrow Street", "Parking Cut", "Service Alley", "Blocked Intersection"]
const LOCATIONS_BY_ZONE := {
    "Camp Perimeter": ["Vacant Lot", "Drainage Wash", "Abandoned Shed", "Edge Street"],
    "Nearby Streets": ["Corner Store", "Abandoned Duplex", "Bus Stop Shops", "Detached Garage"],
    "Residential Blocks": ["Ransacked House", "Backyard Workshop", "Vacant Townhouse", "Neighborhood Market"],
    "Commercial Fringe": ["Pharmacy Annex", "Strip-Mall Office", "Loading Dock Store", "Closed Restaurant"],
    "Industrial Edge": ["Machine Shop", "Warehouse Office", "Loading Yard", "Maintenance Building"],
}

static func pick_kind(zone: String, rng: RandomNumberGenerator) -> String:
    var roll := rng.randf()
    var weights: Array = KIND_WEIGHTS.get(zone, KIND_WEIGHTS["Industrial Edge"])
    for entry in weights:
        if roll < float(entry[1]):
            return str(entry[0])
    return "ambush"

static func location_name(zone: String, kind: String, rng: RandomNumberGenerator) -> String:
    var pool: Array = AMBUSH_LOCATIONS if kind == "ambush" else LOCATIONS_BY_ZONE.get(zone, LOCATIONS_BY_ZONE["Industrial Edge"])
    return str(pool[rng.randi_range(0, pool.size() - 1)])

static func layout_index(rng: RandomNumberGenerator) -> int:
    # Current combat supports three layouts. Keeping this ownership here lets
    # Alpha 0.3/0.4 expand scenario/layout catalogs without touching Game.gd.
    return rng.randi_range(0, 2)
