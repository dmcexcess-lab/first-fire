extends RefCounted
class_name FFTacticalScenarios

const Environments = preload("res://scripts/FFTacticalEnvironments.gd")

const KIND_WEIGHTS := {
    "Camp Perimeter": [["rescue", 0.20], ["explore", 0.65], ["ambush", 1.00]],
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

static func time_of_day_for_hour(hour: float) -> String:
    var normalized_hour := fposmod(hour, 24.0)
    return "night" if normalized_hour >= 18.0 or normalized_hour < 7.0 else "day"

static func current_encounter_hour() -> float:
    # Tactical time is a snapshot of the authoritative settlement clock at the
    # instant the encounter opens. Tactical play then pauses settlement time.
    var day_seconds := maxf(1.0, float(Game.DAY_SECONDS))
    var fraction := clampf(float(Game.day_elapsed) / day_seconds, 0.0, 1.0)
    return fposmod(8.0 + fraction * 24.0, 24.0)

static func pick_scene_state(environment_id: String, rng: RandomNumberGenerator) -> Dictionary:
    var time_of_day := time_of_day_for_hour(current_encounter_hour())
    var power_on := rng.randf() < Environments.power_chance(environment_id)
    return {"time_of_day": time_of_day, "power_on": power_on}
