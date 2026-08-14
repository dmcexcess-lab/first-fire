extends SceneTree

const D = preload("res://scripts/FFData.gd")
const ExpeditionRules = preload("res://scripts/FFExpeditionRules.gd")
const TacticalScenarios = preload("res://scripts/FFTacticalScenarios.gd")
const TacticalEnvironments = preload("res://scripts/FFTacticalEnvironments.gd")
const TacticalLighting = preload("res://scripts/FFTacticalLighting.gd")
const TacticalTiles = preload("res://scripts/FFTacticalTiles.gd")
const TacticalTime = preload("res://scripts/FFTacticalTime.gd")
const TacticalSound = preload("res://scripts/FFTacticalSound.gd")
const LegacyFieldEvents = preload("res://scripts/FFFieldEventsLegacy.gd")
const SaveCodec = preload("res://scripts/FFSaveCodec.gd")
const CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")
const CampSocial = preload("res://scripts/FFCampSocial.gd")
const CampView = preload("res://scripts/FFCampView.gd")
const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")

func _init() -> void:
    var visual_rng := RandomNumberGenerator.new()
    visual_rng.seed = 12345

    if not _check(ExpeditionRules.zone_cap("Camp Perimeter") == 3, "perimeter cap"): return
    if not _check(ExpeditionRules.zone_cap("Industrial Edge") == 7, "industrial cap"): return
    if not _check(abs(ExpeditionRules.travel_duration(20.0, 0.0) - 20.0) < 0.001, "base travel"): return
    if not _check(ExpeditionRules.should_force_recruit(1, 1, 5, true), "solo recruit protection"): return
    if not _check(ExpeditionRules.tactical_event_chance("Camp Perimeter") > 0.0, "starting zone tactical chance"): return
    if not _check(ExpeditionRules.should_force_tactical(2), "tactical drought protection"): return
    if not _check(not ExpeditionRules.should_force_recruit(1, 1, 4, true), "solo recruit threshold"): return
    if not _check(abs(ExpeditionRules.tactical_event_chance("Nearby Streets") - 0.70) < 0.001, "nearby tactical pop rate"): return
    if not _check(abs(ExpeditionRules.tactical_event_chance("Industrial Edge") - 0.90) < 0.001, "industrial tactical pop rate"): return
    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Residential Blocks"), "scenario catalog"): return
    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Camp Perimeter"), "starting zone scenario catalog"): return
    if not _check(TacticalEnvironments.display_name("gas_station") == "Gas Station", "gas station environment"): return
    if not _check(TacticalEnvironments.exit_count("house", 0) == 1, "single-exit house variant"): return
    if not _check(TacticalEnvironments.exit_count("gas_station", 1) >= 3, "multi-exit gas station variant"): return
    if not _check(str(D.GEAR["Flashlight"].get("slot", "")) == "Secondary", "flashlight secondary slot"): return
    if not _check(TacticalLighting.secondary_item_from_equipment({"Secondary": "Flashlight", "Tool": ""}) == "Flashlight", "secondary light lookup"): return
    if not _check(TacticalLighting.item_contribution(Vector2i(5, 5), Vector2i(1, 0), Vector2i(10, 5), "Flashlight") > 0.0, "flashlight forward cone"): return
    if not _check(TacticalLighting.item_contribution(Vector2i(5, 5), Vector2i(1, 0), Vector2i(2, 5), "Flashlight") == 0.0, "flashlight rear cutoff"): return
    if not _check(TacticalEnvironments.build_layout("gas_station", 0).get("lights", []).size() >= 3, "gas station authored lights"): return
    var scene_state: Dictionary = TacticalScenarios.pick_scene_state("gas_station", visual_rng)
    if not _check(scene_state.has("time_of_day") and scene_state.has("power_on"), "scene day night state"): return
    if not _check(TacticalTiles.item_region("Headlamp") >= 0, "atlas secondary item"): return
    if not _check(CampView.station_cell("Workbench") == Vector2i(10, 2), "camp workbench visual station"): return
    if not _check(CampView.building_cell("Cabin") == Vector2i(12, 5), "camp cabin visual anchor"): return

    var light_actor: Dictionary = {"equipment": {"Weapon": "Utility Knife", "Secondary": "", "Tool": "", "Clothing": "", "Pack": ""}, "fatigue": 0.0, "condition": "Healthy", "skills": {"Survival": 3, "Combat": 2}, "crouched": false}
    var heavy_actor: Dictionary = light_actor.duplicate(true)
    heavy_actor["equipment"] = {"Weapon": "Shotgun", "Secondary": "Lantern", "Tool": "Toolbox", "Clothing": "Leather Jacket", "Pack": "Hiking Pack"}
    if not _check(TacticalTime.movement_cost(heavy_actor, false) > TacticalTime.movement_cost(light_actor, false), "encumbrance changes timeline"): return

    var sound_rng := RandomNumberGenerator.new()
    sound_rng.seed = 7
    var estimate: Vector2i = TacticalSound.estimate_location(Vector2i(10,10), Vector2i(2,2), 2, sound_rng, 20, 18)
    if not _check(absi(estimate.x-10)+absi(estimate.y-10) <= 2, "sound stays in source vicinity"): return

    for environment_id in TacticalEnvironments.all_ids():
        for variant in range(TacticalEnvironments.variant_count(str(environment_id))):
            if not _check(TacticalEnvironments.validate_layout(TacticalEnvironments.build_layout(str(environment_id), variant)), "reachable exits: %s v%d" % [environment_id, variant]): return
    if not _check(LegacyFieldEvents.all_keys().has("injured_stranger"), "legacy field catalog"): return
    var rates := CampLifeRules.idle_recovery_rates(true, false)
    if not _check(rates.x > 0.0 and rates.y > 0.0, "camp recovery rules"): return
    if not _check(abs(CampLifeRules.fatigue_gain(5.0) - 10.0) < 0.001, "fatigue gain multiplier"): return
    if not _check(CampSocial.relationship_label(70) == "Close", "social relationship bands"): return

    var survivor_look: Dictionary = TacticalVisuals.survivor_appearance(visual_rng)
    if not _check(survivor_look.has("sprite") and survivor_look.has("accent"), "survivor sprite identity"): return
    var zombie_look: Dictionary = TacticalVisuals.zombie_appearance(visual_rng, "Industrial Edge")
    if not _check(str(zombie_look.get("family", "")) != "", "zombie visual family"): return
    if not _check(str(TacticalVisuals.weapon_visual("Pistol").get("kind", "")) == "pistol", "weapon visual catalog"): return

    var path := "user://ff_architecture_smoke.json"
    var payload := {"save_schema": 99, "ok": true}
    if not _check(SaveCodec.write_json(path, payload), "save write"): return
    var loaded = SaveCodec.read_json(path)
    if not _check(SaveCodec.is_compatible(loaded, 99), "save compatibility"): return
    SaveCodec.invalidate(path)
    if not _check(not SaveCodec.exists(path), "save invalidation"): return
    print("FIRST_FIRE_ARCHITECTURE_SMOKE_OK")
    quit(0)

func _check(value: bool, label: String) -> bool:
    if value:
        return true
    push_error("FIRST_FIRE_ARCHITECTURE_SMOKE_FAILED: %s" % label)
    quit(1)
    return false
