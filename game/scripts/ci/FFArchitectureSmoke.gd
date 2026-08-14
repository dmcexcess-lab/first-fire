extends SceneTree

const ExpeditionRules = preload("res://scripts/FFExpeditionRules.gd")
const TacticalScenarios = preload("res://scripts/FFTacticalScenarios.gd")
const LegacyFieldEvents = preload("res://scripts/FFFieldEventsLegacy.gd")
const SaveCodec = preload("res://scripts/FFSaveCodec.gd")
const CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")
const CampSocial = preload("res://scripts/FFCampSocial.gd")
const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")

func _init() -> void:
    if not _check(ExpeditionRules.zone_cap("Camp Perimeter") == 3, "perimeter cap"): return
    if not _check(ExpeditionRules.zone_cap("Industrial Edge") == 7, "industrial cap"): return
    if not _check(abs(ExpeditionRules.travel_duration(20.0, 0.0) - 20.0) < 0.001, "base travel"): return
    if not _check(ExpeditionRules.should_force_recruit(1, 1, 5, true), "solo recruit protection"): return
    if not _check(not ExpeditionRules.should_force_recruit(1, 1, 4, true), "solo recruit threshold"): return
    if not _check(abs(ExpeditionRules.tactical_event_chance("Nearby Streets") - 0.55) < 0.001, "nearby tactical pop rate"): return
    if not _check(abs(ExpeditionRules.tactical_event_chance("Industrial Edge") - 0.85) < 0.001, "industrial tactical pop rate"): return
    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Residential Blocks"), "scenario catalog"): return
    if not _check(LegacyFieldEvents.all_keys().has("injured_stranger"), "legacy field catalog"): return
    var rates := CampLifeRules.idle_recovery_rates(true, false)
    if not _check(rates.x > 0.0 and rates.y > 0.0, "camp recovery rules"): return
    if not _check(abs(CampLifeRules.fatigue_gain(5.0) - 10.0) < 0.001, "fatigue gain multiplier"): return
    if not _check(CampSocial.relationship_label(70) == "Close", "social relationship bands"): return
    var visual_rng := RandomNumberGenerator.new()
    visual_rng.seed = 12345
    var survivor_look: Dictionary = TacticalVisuals.survivor_appearance(visual_rng)
    if not _check(survivor_look.has("skin") and survivor_look.has("top") and survivor_look.has("body"), "survivor visual identity"): return
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
