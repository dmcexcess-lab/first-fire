extends RefCounted
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
