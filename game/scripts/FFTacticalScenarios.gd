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
    return "%s • %s" % [Environments.display_name(environment_id), formatted_hour(current_encounter_hour())]

static func environment_variant(environment_id: String, rng: RandomNumberGenerator) -> int:
    return Environments.pick_variant(environment_id, rng)

static func time_of_day_for_hour(hour: float) -> String:
    var normalized_hour := fposmod(hour, 24.0)
    if normalized_hour >= 5.5 and normalized_hour < 7.0:
        return "dawn"
    if normalized_hour >= 18.0 and normalized_hour < 19.5:
        return "dusk"
    return "night" if normalized_hour >= 19.5 or normalized_hour < 5.5 else "day"

static func formatted_hour(hour: float) -> String:
    var total_minutes := int(round(fposmod(hour, 24.0) * 60.0)) % 1440
    var hour24 := int(total_minutes / 60)
    var minute := total_minutes % 60
    var suffix := "PM" if hour24 >= 12 else "AM"
    var display_hour := hour24 % 12
    if display_hour == 0:
        display_hour = 12
    return "%d:%02d %s" % [display_hour, minute, suffix]

static func current_encounter_hour() -> float:
    # Read the authoritative settlement clock only at encounter creation. Use a
    # dynamic root lookup so this pure scenario module does not create an
    # autoload/preload cycle with Game during headless smoke execution.
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        return 12.0
    var game := tree.root.get_node_or_null("Game")
    if game == null:
        return 12.0
    var day_seconds := maxf(1.0, float(game.get("DAY_SECONDS")))
    var elapsed := float(game.get("day_elapsed"))
    var fraction := clampf(elapsed / day_seconds, 0.0, 1.0)
    return fposmod(8.0 + fraction * 24.0, 24.0)

static func pick_scene_state(environment_id: String, rng: RandomNumberGenerator) -> Dictionary:
    var encounter_hour := current_encounter_hour()
    var time_of_day := time_of_day_for_hour(encounter_hour)
    var power_on := rng.randf() < Environments.power_chance(environment_id)
    return {
        "time_of_day": time_of_day,
        "encounter_hour": encounter_hour,
        "encounter_time": formatted_hour(encounter_hour),
        "power_on": power_on,
    }
