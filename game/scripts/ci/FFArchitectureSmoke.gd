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
const VirusRules = preload("res://scripts/FFVirusRules.gd")
const THREE_STAT_MODEL := "combat-agility-leadership-v1"

func _init() -> void:
    if not _check(ThreeStatRules.STAT_NAMES == ["Combat", "Agility", "Leadership"], "three-stat catalog"): return
    var normalized := ThreeStatRules.normalize_stats({"Combat": 4, "Agility": 3, "Leadership": 2, "Survival": 9})
    if not _check(normalized.size() == 3 and not normalized.has("Survival"), "removed legacy stats stay removed"): return
    if not _check(str(ThreeStatRules.weapon_class("Kitchen Knife").get("label", "")) == "1H MELEE", "1H melee class"): return
    if not _check(str(ThreeStatRules.weapon_class("Baseball Bat").get("label", "")) == "2H MELEE", "2H melee class"): return
    if not _check(str(ThreeStatRules.weapon_class("Pistol").get("label", "")) == "1H GUN", "1H gun class"): return
    if not _check(str(ThreeStatRules.weapon_class("Shotgun").get("label", "")) == "2H GUN", "2H gun class"): return
    for agility in [0, 5, 10]:
        var walk_cost:=ThreeStatRules.normal_move_cost(agility,100)
        var sprint_cost:=ThreeStatRules.sprint_move_cost(agility,100)
        var crouch_cost:=ThreeStatRules.stealth_move_cost(agility,100)
        if not _check(sprint_cost<=int(floor(float(walk_cost)*0.72)), "sprint materially faster at agility %d" % agility): return
        if not _check(crouch_cost>=int(ceil(float(walk_cost)*1.25)), "crouch materially slower at agility %d" % agility): return
    if not _check(ThreeStatRules.stealth_noise(7) < ThreeStatRules.stealth_noise(1), "agility improves stealth"): return
    if not _check(ThreeStatRules.sprint_move_cost(7, 100) < ThreeStatRules.sprint_move_cost(1, 100), "agility improves sprint"): return

    var actor := {"skills": {"Combat": 3, "Agility": 4, "Leadership": 1}, "fatigue": 0.0, "sprinting": false, "crouched": false}
    var sprinting := actor.duplicate(true); sprinting["sprinting"] = true
    var baseline_actor := {"skills": {"Agility": 0}, "fatigue": 0.0, "sprinting": false}
    if not _check(TacticalBalance.zombie_hit_chance(sprinting) < TacticalBalance.zombie_hit_chance(actor), "sprint evasion"): return
    if not _check(TacticalBalance.zombie_hit_chance(baseline_actor) >= 0.70 and TacticalBalance.zombie_damage_range("HEAVY").y >= 7, "infected pressure tuning"): return
    if not _check(TacticalBalance.shove_chance(actor, "LIGHT", 1) > TacticalBalance.shove_chance(actor, "HEAVY", 1), "mass resists shove"): return
    if not _check(TacticalBalance.search_cost(actor) > 0 and TacticalBalance.search_noise(actor) > 0, "search remains bounded"): return
    if not _check(TacticalBalance.zombie_count("Camp Perimeter", "rescue") < TacticalBalance.zombie_count("Camp Perimeter", "ambush"), "objective zombie balance"): return
    if not _check(TacticalBalance.zombie_hp_range("HEAVY").x > TacticalBalance.zombie_hp_range("LIGHT").x, "mass-aware infected HP"): return

    # UI/autoload scripts intentionally refer to the global Game singleton, which
    # does not exist when this file is run directly with --script. Import/startup
    # CI compiles them in their real project context; smoke verifies their contracts
    # as source so this pure rules test stays independent of autoload boot order.
    var game_source := FileAccess.get_file_as_string("res://scripts/GameThreeStat.gd")
    var active_game_source := FileAccess.get_file_as_string("res://scripts/GameSleepVirus.gd")
    var base_game_source := FileAccess.get_file_as_string("res://scripts/Game.gd")
    var combat_source := FileAccess.get_file_as_string("res://scripts/FFCombatThreeStat.gd")
    var active_combat_source := FileAccess.get_file_as_string("res://scripts/FFCombatVirus.gd")
    var main_source := FileAccess.get_file_as_string("res://scripts/MainThreeStat.gd")
    var active_main_source := FileAccess.get_file_as_string("res://scripts/MainSleepVirus.gd")
    var inspector_source := FileAccess.get_file_as_string("res://scripts/FFInspectorThreeStat.gd")
    var active_inspector_source := FileAccess.get_file_as_string("res://scripts/FFInspectorVirus.gd")
    var active_camp_source := FileAccess.get_file_as_string("res://scripts/FFCampViewSleepVirus.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")
    var scene_source := FileAccess.get_file_as_string("res://main.tscn")
    if not _check(game_source.contains("const THREE_STAT_MODEL := \"%s\"" % THREE_STAT_MODEL), "three-stat save reset marker"): return
    if not _check(game_source.contains("skills.size() != 3") and game_source.contains("SaveCodecThree.invalidate"), "legacy skill saves reset"): return
    if not _check(project_source.contains("Game=\"*res://scripts/GameSleepVirus.gd\""), "sleep-virus game autoload active"): return
    if not _check(scene_source.contains("res://scripts/MainSleepVirus.gd"), "sleep-virus main active"): return
    if not _check(main_source.contains("FFCombatThreeStat.gd") and main_source.contains("FFInspectorThreeStat.gd"), "three-stat UI base routing"): return
    if not _check(active_main_source.contains("FFCombatVirus.gd") and active_main_source.contains("FFInspectorVirus.gd") and active_main_source.contains("FFCampViewSleepVirus.gd"), "sleep-virus UI routing"): return
    if not _check(inspector_source.contains("ThreeStatRules.STAT_NAMES") and not inspector_source.contains("Scavenging\", \"Survival"), "inspector exposes three stats"): return
    if not _check(active_inspector_source.contains("ZOMBIE VIRUS") and active_inspector_source.contains("QUARANTINE") and active_inspector_source.contains("start_virus_treatment"), "virus choices exposed in inspector"): return
    if not _check(combat_source.contains("No armor layer") and combat_source.contains("target_actor.hp -= dmg"), "no armor damage mitigation"): return
    if not _check(not combat_source.contains("func guard():") and not combat_source.contains("KEY_G: guard()"), "guard removed from active combat"): return
    if not _check(combat_source.contains("btn_forward_primary") and combat_source.contains("draw_button(btn_forward_primary,\"FORWARD\""), "forward occupies former guard slot"): return
    if not _check(combat_source.contains("func shove()") and combat_source.contains("super.shove()"), "shove remains active"): return
    if not _check(combat_source.contains("func toggle_sprint()") and combat_source.contains("func stealth_attack"), "sprint and stealth actions"): return
    if not _check(combat_source.contains("vision_range_for_light") and combat_source.contains("vision_cone_min_dot"), "active sight uses light-sensitive cone geometry"): return
    if not _check(active_combat_source.contains("infected_hits") and active_combat_source.contains("super.zombie_attack"), "direct infected contact tracked"): return
    var base_combat_source := FileAccess.get_file_as_string("res://scripts/FFCombat.gd")
    if not _check(base_combat_source.contains("rescue_contacted and not rescuee.is_empty()") and base_combat_source.contains("func search_loot_container"), "protected rescue opening and physical container search"): return
    if not _check(combat_source.contains("nearest_exit_distance") and combat_source.contains("LOOT %d/%d"), "route-oriented tactical HUD"): return
    if not _check(active_game_source.contains("const SIM_TIME_SCALE := 0.5") and active_game_source.contains("\"status\"] = \"Sleeping\"") and active_game_source.contains("func survivor_can_assign") and active_game_source.contains("func start_virus_treatment") and active_game_source.contains("func quarantine_survivor"), "authoritative sleep virus and half-speed orchestration"): return
    if not _check(active_camp_source.contains("status == \"Sleeping\"") and active_camp_source.contains("_sleep_cell_for_survivor") and active_camp_source.contains("QUARANTINE"), "camp reflects sleep and isolation"): return
    if not _check(active_game_source.contains("func camp_chore_needed") and active_main_source.contains("LEAVE CAMP") and active_main_source.contains("Nothing urgent right now") and active_camp_source.contains("MENU_VISIBLE_GRID_WIDTH := 8.5") and active_camp_source.contains("_continue_pan_drag"), "camp focus routing and problem-driven work"): return

    if not _check(VirusRules.exposure_chance(1) > 0.0 and VirusRules.exposure_chance(4) > VirusRules.exposure_chance(1), "virus exposure scales with infected contact"): return
    var early_plan: Dictionary = VirusRules.treatment_plan(VirusRules.STAGE_EXPOSED, false)
    var infected_plan: Dictionary = VirusRules.treatment_plan(VirusRules.STAGE_INFECTED, false)
    var fever_no_infirmary: Dictionary = VirusRules.treatment_plan(VirusRules.STAGE_FEVERISH, false)
    var fever_infirmary: Dictionary = VirusRules.treatment_plan(VirusRules.STAGE_FEVERISH, true)
    if not _check(int(early_plan.get("resources", {}).get("Clean Water", 0)) == 1 and int(early_plan.get("components", {}).get("Sterile Dressing", 0)) == 1, "early virus decontamination costs real supplies"): return
    if not _check(int(infected_plan.get("resources", {}).get("Medicine", 0)) == 1, "established virus uses medicine"): return
    if not _check(not bool(fever_no_infirmary.get("available", true)) and bool(fever_infirmary.get("available", false)) and int(fever_infirmary.get("resources", {}).get("Medicine", 0)) == 2, "feverish virus requires infirmary emergency care"): return

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

    if not _check(int(D.STARTING_RESOURCES.get("Cooked Food", 0)) >= 3 and int(D.STARTING_RESOURCES.get("Clean Water", 0)) >= 3, "new game basic supply runway"): return
    var base_needs := CampLifeRules.default_needs()
    if not _check(base_needs.has("hunger") and base_needs.has("safety") and base_needs.has("hygiene"), "camp needs"): return
    var pet_rng:=RandomNumberGenerator.new(); pet_rng.seed=7
    var pet_find:=CampLifeRules.pet_forage_resource("Dog",pet_rng)
    if not _check(CampLifeRules.default_pet_needs().size()==1 and CampLifeRules.default_pet_needs().has("affection"), "affection-only pet needs"): return
    if not _check(CampLifeRules.pet_should_leave({"affection":10}) and not CampLifeRules.pet_should_leave({"affection":60}), "neglected pets leave"): return
    if not _check(pet_find in ["Wood","Scrap Metal","Hardware","Cloth","Plastic","Raw Food"], "daily pet material reward"): return
    if not _check(str(CampLifeRules.choose_available_activity({"sleep":20,"fun":90},0.0,5,1,false,false,RandomNumberGenerator.new()).get("kind","")) == "rest", "low sleep selects real sleep"): return
    if not _check(str(CampLifeRules.choose_available_activity({"sleep":90,"fun":90},0.0,5,1,false,false,RandomNumberGenerator.new()).get("kind","")) != "maintain_fire", "productive chores are not autonomous"): return
    if not _check(base_game_source.contains("var pets := []") and base_game_source.contains("func start_camp_chore") and base_game_source.contains("func perform_camp_task_tap") and base_game_source.contains("rescue_is_pet"), "active camp work and pet rescue state"): return
    if not _check(CampSocial.candidate_standing({"id":1,"condition":"Healthy","skills":{"Leadership":5},"reputation":0,"relationships":{}}, []) == 30, "leadership drives politics"): return
    if not _check(D.BUILD_ORDER.size() == 15 and D.BUILDINGS.has("Dormitory") and D.BUILDINGS.has("Armory"), "final building tree"): return
    if not _check(str(D.GEAR["Flashlight"].get("slot", "")) == "Secondary", "flashlight secondary"): return
    if not _check(TacticalTiles.item_region("Headlamp") >= 0, "atlas secondary item"): return
    if not _check(str(TacticalVisuals.weapon_visual("Pistol").get("kind", "")) == "pistol", "weapon visual catalog"): return
    if not _check(TacticalSound.display_label("gunshot") != "", "sound catalog"): return

    var path := "user://ff_architecture_smoke.json"
    var payload := {"save_schema": 7, "stat_model": THREE_STAT_MODEL, "virus_model": "zombie-virus-v1", "ok": true}
    if not _check(SaveCodec.write_json(path, payload), "save write"): return
    var loaded = SaveCodec.read_json(path)
    if not _check(loaded != null and str(loaded.get("stat_model", "")) == THREE_STAT_MODEL and str(loaded.get("virus_model", "")) == "zombie-virus-v1", "save read"): return
    SaveCodec.invalidate(path)

    print("FIRST_FIRE_ARCHITECTURE_SMOKE_OK")
    quit(0)

func _check(value: bool, label: String) -> bool:
    if value: return true
    push_error("FIRST_FIRE_ARCHITECTURE_SMOKE_FAIL: %s" % label)
    quit(1)
    return false