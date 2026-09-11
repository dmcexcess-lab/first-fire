extends SceneTree

const D = preload("res://scripts/FFData.gd")
const ExpeditionRules = preload("res://scripts/FFExpeditionRules.gd")
const TacticalScenarios = preload("res://scripts/FFTacticalScenarios.gd")
const TacticalEnvironments = preload("res://scripts/FFTacticalEnvironments.gd")
const TacticalLighting = preload("res://scripts/FFTacticalLighting.gd")
const TacticalTiles = preload("res://scripts/FFTacticalTiles.gd")
const TacticalSound = preload("res://scripts/FFTacticalSound.gd")
const TacticalBalance = preload("res://scripts/FFTacticalBalance.gd")
const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")
const SaveCodec = preload("res://scripts/FFSaveCodec.gd")
const CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")
const CampSocial = preload("res://scripts/FFCampSocial.gd")
const ThreeStatRules = preload("res://scripts/FFThreeStatRules.gd")
const GameThreeStat = preload("res://scripts/GameThreeStat.gd")
const CombatThreeStat = preload("res://scripts/FFCombatThreeStat.gd")
const MainThreeStat = preload("res://scripts/MainThreeStat.gd")
const InspectorThreeStat = preload("res://scripts/FFInspectorThreeStat.gd")

func _init() -> void:
    if not _check(ThreeStatRules.STAT_NAMES == ["Combat", "Agility", "Leadership"], "three-stat catalog"): return
    var normalized := ThreeStatRules.normalize_stats({"Combat": 4, "Agility": 3, "Leadership": 2, "Survival": 9})
    if not _check(normalized.size() == 3 and not normalized.has("Survival"), "removed legacy stats stay removed"): return
    if not _check(GameThreeStat.THREE_STAT_MODEL == "combat-agility-leadership-v1", "three-stat save reset marker"): return
    if not _check(str(ThreeStatRules.weapon_class("Kitchen Knife").get("label", "")) == "1H MELEE", "1H melee class"): return
    if not _check(str(ThreeStatRules.weapon_class("Baseball Bat").get("label", "")) == "2H MELEE", "2H melee class"): return
    if not _check(str(ThreeStatRules.weapon_class("Pistol").get("label", "")) == "1H GUN", "1H gun class"): return
    if not _check(str(ThreeStatRules.weapon_class("Shotgun").get("label", "")) == "2H GUN", "2H gun class"): return
    if not _check(ThreeStatRules.sprint_move_cost(6, 100) < ThreeStatRules.normal_move_cost(6, 100), "sprint is faster"): return
    if not _check(ThreeStatRules.stealth_noise(7) < ThreeStatRules.stealth_noise(1), "agility improves stealth"): return
    if not _check(ThreeStatRules.sprint_move_cost(7, 100) < ThreeStatRules.sprint_move_cost(1, 100), "agility improves sprint"): return
    var actor := {"skills": {"Combat": 3, "Agility": 4, "Leadership": 1}, "fatigue": 0.0, "guarding": false, "sprinting": false, "crouched": false}
    var guarded := actor.duplicate(true); guarded["guarding"] = true
    var sprinting := actor.duplicate(true); sprinting["sprinting"] = true
    if not _check(TacticalBalance.zombie_hit_chance(guarded) < TacticalBalance.zombie_hit_chance(actor), "guard reduces grab chance"): return
    if not _check(TacticalBalance.zombie_hit_chance(sprinting) < TacticalBalance.zombie_hit_chance(actor), "sprint evasion"): return
    if not _check(TacticalBalance.shove_chance(actor, "LIGHT", 1) > TacticalBalance.shove_chance(actor, "HEAVY", 1), "mass resists shove"): return
    if not _check(TacticalBalance.search_cost(actor) > 0 and TacticalBalance.search_noise(actor) > 0, "search remains bounded"): return
    var combat_source := FileAccess.get_file_as_string("res://scripts/FFCombatThreeStat.gd")
    if not _check(combat_source.contains("No armor layer") and combat_source.contains("target_actor.hp -= dmg"), "no armor damage mitigation"): return
    if not _check(combat_source.contains("super.shove()") and combat_source.contains("sacrifices the defensive state"), "shove drops guard"): return
    if not _check(combat_source.contains("func toggle_sprint()") and combat_source.contains("func stealth_attack"), "sprint and stealth actions"): return
    if not _check(ExpeditionRules.zone_cap("Camp Perimeter") == 3, "perimeter cap"): return
    if not _check(ExpeditionRules.should_force_tactical(2), "tactical drought protection"): return
    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Camp Perimeter"), "scenario catalog"): return
    if not _check(TacticalEnvironments.display_name("gas_station") == "Gas Station", "gas station environment"): return
    if not _check(TacticalScenarios.time_of_day_for_hour(6.0) == "dawn", "dawn phase"): return
    if not _check(TacticalScenarios.time_of_day_for_hour(12.0) == "day", "day phase"): return
    if not _check(TacticalScenarios.time_of_day_for_hour(18.5) == "dusk", "dusk phase"): return
    if not _check(TacticalScenarios.time_of_day_for_hour(2.0) == "night", "night phase"): return
    if not _check(TacticalLighting.ambient_level("alley", "dawn", false) > TacticalLighting.ambient_level("alley", "night", false), "dawn lighting"): return
    for environment_id in TacticalEnvironments.all_ids():
        for variant in range(TacticalEnvironments.variant_count(str(environment_id))):
            if not _check(TacticalEnvironments.validate_layout(TacticalEnvironments.build_layout(str(environment_id), variant)), "reachable exits: %s v%d" % [environment_id, variant]): return
    var base_needs := CampLifeRules.default_needs()
    if not _check(base_needs.has("hunger") and base_needs.has("safety") and base_needs.has("hygiene"), "camp needs"): return
    if not _check(CampSocial.candidate_standing({"id":1,"condition":"Healthy","skills":{"Leadership":5},"reputation":0,"relationships":{}}, []) == 30, "leadership drives politics"): return
    if not _check(D.BUILD_ORDER.size() == 15 and D.BUILDINGS.has("Dormitory") and D.BUILDINGS.has("Armory"), "final building tree"): return
    if not _check(str(D.GEAR["Flashlight"].get("slot", "")) == "Secondary", "flashlight secondary"): return
    if not _check(TacticalTiles.item_region("Headlamp") >= 0, "atlas secondary item"): return
    if not _check(str(TacticalVisuals.weapon_visual("Pistol").get("kind", "")) == "pistol", "weapon visual catalog"): return
    if not _check(TacticalSound.display_label("gunshot") != "", "sound catalog"): return
    var path := "user://ff_architecture_smoke.json"
    var payload := {"save_schema": 7, "stat_model": GameThreeStat.THREE_STAT_MODEL, "ok": true}
    if not _check(SaveCodec.write_json(path, payload), "save write"): return
    var loaded = SaveCodec.read_json(path)
    if not _check(loaded != null and str(loaded.get("stat_model", "")) == GameThreeStat.THREE_STAT_MODEL, "save read"): return
    SaveCodec.invalidate(path)
    print("FIRST_FIRE_ARCHITECTURE_SMOKE_OK")
    quit(0)

func _check(value: bool, label: String) -> bool:
    if value: return true
    push_error("FIRST_FIRE_ARCHITECTURE_SMOKE_FAIL: %s" % label)
    quit(1)
    return false
