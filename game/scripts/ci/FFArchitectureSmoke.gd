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
const THREE_STAT_MODEL := "combat-agility-leadership-v1"

func _init() -> void:
    if not _check(ThreeStatRules.STAT_NAMES == ["Combat", "Agility", "Leadership"], "three-stat catalog"): return
    var normalized := ThreeStatRules.normalize_stats({"Combat": 4, "Agility": 3, "Leadership": 2, "Survival": 9})
    if not _check(normalized.size() == 3 and not normalized.has("Survival"), "removed legacy stats stay removed"): return
    if not _check(str(ThreeStatRules.weapon_class("Kitchen Knife").get("label", "")) == "1H MELEE", "1H melee class"): return
    if not _check(str(ThreeStatRules.weapon_class("Baseball Bat").get("label", "")) == "2H MELEE", "2H melee class"): return
    if not _check(str(ThreeStatRules.weapon_class("Pistol").get("label", "")) == "1H GUN", "1H gun class"): return
    if not _check(str(ThreeStatRules.weapon_class("Shotgun").get("label", "")) == "2H GUN", "2H gun class"): return
    if not _check(ThreeStatRules.sprint_move_cost(6, 100) < ThreeStatRules.normal_move_cost(6, 100), "sprint is faster"): return
    if not _check(ThreeStatRules.stealth_noise(7) < ThreeStatRules.stealth_noise(1), "agility improves stealth"): return
    if not _check(ThreeStatRules.sprint_move_cost(7, 100) < ThreeStatRules.sprint_move_cost(1, 100), "agility improves sprint"): return

    var actor := {"skills": {"Combat": 3, "Agility": 4, "Leadership": 1}, "fatigue": 0.0, "sprinting": false, "crouched": false}
    var sprinting := actor.duplicate(true); sprinting["sprinting"] = true
    if not _check(TacticalBalance.zombie_hit_chance(sprinting) < TacticalBalance.zombie_hit_chance(actor), "sprint evasion"): return
    if not _check(TacticalBalance.shove_chance(actor, "LIGHT", 1) > TacticalBalance.shove_chance(actor, "HEAVY", 1), "mass resists shove"): return
    if not _check(TacticalBalance.search_cost(actor) > 0 and TacticalBalance.search_noise(actor) > 0, "search remains bounded"): return
    if not _check(TacticalBalance.zombie_count("Camp Perimeter", "rescue") < TacticalBalance.zombie_count("Camp Perimeter", "ambush"), "objective zombie balance"): return
    if not _check(TacticalBalance.zombie_hp_range("HEAVY").x > TacticalBalance.zombie_hp_range("LIGHT").x, "mass-aware infected HP"): return

    # UI/autoload scripts intentionally refer to the global Game singleton, which
    # does not exist when this file is run directly with --script. Import/startup
    # CI compiles them in their real project context; smoke verifies their contracts
    # as source so this pure rules test stays independent of autoload boot order.
    var game_source := FileAccess.get_file_as_string("res://scripts/GameThreeStat.gd")
    var combat_source := FileAccess.get_file_as_string("res://scripts/FFCombatThreeStat.gd")
    var main_source := FileAccess.get_file_as_string("res://scripts/MainThreeStat.gd")
    var inspector_source := FileAccess.get_file_as_string("res://scripts/FFInspectorThreeStat.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")
    var scene_source := FileAccess.get_file_as_string("res://main.tscn")
    if not _check(game_source.contains("const THREE_STAT_MODEL := \"%s\"" % THREE_STAT_MODEL), "three-stat save reset marker"): return
    if not _check(game_source.contains("skills.size() != 3") and game_source.contains("SaveCodecThree.invalidate"), "legacy skill saves reset"): return
    if not _check(project_source.contains("Game=\"*res://scripts/GameThreeStat.gd\""), "three-stat game autoload active"): return
    if not _check(scene_source.contains("res://scripts/MainThreeStat.gd"), "three-stat main active"): return
    if not _check(main_source.contains("FFCombatThreeStat.gd") and main_source.contains("FFInspectorThreeStat.gd"), "three-stat UI routing"): return
    if not _check(inspector_source.contains("ThreeStatRules.STAT_NAMES") and not inspector_source.contains("Scavenging\", \"Survival"), "inspector exposes three stats"): return
    if not _check(combat_source.contains("No armor layer") and combat_source.contains("target_actor.hp -= dmg"), "no armor damage mitigation"): return
    if not _check(not combat_source.contains("func guard():") and not combat_source.contains("KEY_G: guard()"), "guard removed from active combat"): return
    if not _check(combat_source.contains("btn_forward_primary") and combat_source.contains("draw_button(btn_forward_primary,\"FORWARD\""), "forward occupies former guard slot"): return
    if not _check(combat_source.contains("func shove()") and combat_source.contains("super.shove()"), "shove remains active"): return
    if not _check(combat_source.contains("func toggle_sprint()") and combat_source.contains("func stealth_attack"), "sprint and stealth actions"): return
    if not _check(combat_source.contains("vision_range_for_light") and combat_source.contains("vision_cone_min_dot"), "active sight uses light-sensitive cone geometry"): return
    var base_combat_source := FileAccess.get_file_as_string("res://scripts/FFCombat.gd")
    if not _check(base_combat_source.contains("rescue_contacted and not rescuee.is_empty()") and base_combat_source.contains("func search_loot_container"), "protected rescue opening and physical container search"): return
    if not _check(combat_source.contains("nearest_exit_distance") and combat_source.contains("LOOT %d/%d"), "route-oriented tactical HUD"): return

    if not _check(ExpeditionRules.zone_cap("Camp Perimeter") == 3, "perimeter cap"): return
    if not _check(ExpeditionRules.should_force_tactical(2), "tactical drought protection"): return
    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Camp Perimeter"), "scenario catalog"): return
    if not _check(TacticalEnvironments.display_name("gas_station") == "Gas Station", "gas station environment"): return
    if not _check(TacticalScenarios.time_of_day_for_hour(6.0) == "dawn", "dawn phase"): return
    if not _check(TacticalScenarios.time_of_day_for_hour(12.0) == "day", "day phase"): return
    if not _check(TacticalScenarios.time_of_day_for_hour(18.5) == "dusk", "dusk phase"): return
    if not _check(TacticalScenarios.time_of_day_for_hour(2.0) == "night", "night phase"): return
    if not _check(TacticalLighting.ambient_level("alley", "dawn", false) > TacticalLighting.ambient_level("alley", "night", false), "dawn lighting"): return
    if not _check(TacticalLighting.vision_range_for_light(0.85, 7) > TacticalLighting.vision_range_for_light(0.08, 7), "bright light extends vision cone"): return
    if not _check(TacticalLighting.vision_cone_min_dot(0.85) < TacticalLighting.vision_cone_min_dot(0.08), "bright light widens vision cone"): return
    for environment_id in TacticalEnvironments.all_ids():
        for variant in range(TacticalEnvironments.variant_count(str(environment_id))):
            var layout: Dictionary = TacticalEnvironments.build_layout(str(environment_id), variant)
            if not _check(TacticalEnvironments.validate_layout(layout), "reachable exits: %s v%d" % [environment_id, variant]): return
            if not _check(TacticalEnvironments.minimum_exit_distance(layout) >= 8, "planned extraction distance: %s v%d" % [environment_id, variant]): return
            if not _check(layout.get("loot_containers", []).size() >= 3, "physical loot containers: %s v%d" % [environment_id, variant]): return

    var base_needs := CampLifeRules.default_needs()
    if not _check(base_needs.has("hunger") and base_needs.has("safety") and base_needs.has("hygiene"), "camp needs"): return
    if not _check(CampSocial.candidate_standing({"id":1,"condition":"Healthy","skills":{"Leadership":5},"reputation":0,"relationships":{}}, []) == 30, "leadership drives politics"): return
    if not _check(D.BUILD_ORDER.size() == 15 and D.BUILDINGS.has("Dormitory") and D.BUILDINGS.has("Armory"), "final building tree"): return
    if not _check(str(D.GEAR["Flashlight"].get("slot", "")) == "Secondary", "flashlight secondary"): return
    if not _check(TacticalTiles.item_region("Headlamp") >= 0, "atlas secondary item"): return
    if not _check(str(TacticalVisuals.weapon_visual("Pistol").get("kind", "")) == "pistol", "weapon visual catalog"): return
    if not _check(TacticalSound.display_label("gunshot") != "", "sound catalog"): return

    var path := "user://ff_architecture_smoke.json"
    var payload := {"save_schema": 7, "stat_model": THREE_STAT_MODEL, "ok": true}
    if not _check(SaveCodec.write_json(path, payload), "save write"): return
    var loaded = SaveCodec.read_json(path)
    if not _check(loaded != null and str(loaded.get("stat_model", "")) == THREE_STAT_MODEL, "save read"): return
    SaveCodec.invalidate(path)

    print("FIRST_FIRE_ARCHITECTURE_SMOKE_OK")
    quit(0)

func _check(value: bool, label: String) -> bool:
    if value: return true
    push_error("FIRST_FIRE_ARCHITECTURE_SMOKE_FAIL: %s" % label)
    quit(1)
    return false
