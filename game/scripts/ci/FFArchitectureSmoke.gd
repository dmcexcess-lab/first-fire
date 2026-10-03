extends SceneTree

const D = preload("res://scripts/FFData.gd")
const ExpeditionRules = preload("res://scripts/FFExpeditionRules.gd")
const TacticalScenarios = preload("res://scripts/FFTacticalScenarios.gd")
const TacticalEnvironments = preload("res://scripts/FFTacticalEnvironments.gd")
const TacticalLighting = preload("res://scripts/FFTacticalLighting.gd")
const TacticalTiles = preload("res://scripts/FFTacticalTiles.gd")
const TacticalSound = preload("res://scripts/FFTacticalSound.gd")
const TacticalBalance = preload("res://scripts/FFTacticalBalance.gd")
const TacticalTime = preload("res://scripts/FFTacticalTime.gd")
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
    if not _check(str(ThreeStatRules.weapon_class("Crossbow").get("label", "")) == "CROSSBOW" and str(ThreeStatRules.weapon_class("Rifle").get("label", "")) == "2H GUN", "crossbow and rifle classes"): return
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
    if not _check(TacticalBalance.zombie_attack_hit_chance(sprinting, "scratch") < TacticalBalance.zombie_attack_hit_chance(actor, "scratch"), "sprint evasion"): return
    if not _check(is_equal_approx(TacticalBalance.BITE_ATTEMPT_CHANCE, 0.20) and TacticalBalance.zombie_attack_hit_chance(baseline_actor, "scratch") > TacticalBalance.zombie_attack_hit_chance(baseline_actor, "bite"), "scratch is common/high-hit while bite is rare/low-hit"): return
    if not _check(TacticalBalance.zombie_attack_damage_range("MED", "scratch").y < TacticalBalance.zombie_attack_damage_range("MED", "bite").x, "scratch is low damage while bite is high damage"): return
    if not _check(TacticalBalance.zombie_attack_hit_chance(baseline_actor, "scratch", 4) > TacticalBalance.zombie_attack_hit_chance(baseline_actor, "scratch", 1) and TacticalBalance.mob_damage_bonus(4) > 0 and TacticalBalance.mob_attack_cost_multiplier(4) < 1.0 and TacticalBalance.mob_alert_radius(4) > TacticalBalance.mob_alert_radius(1), "mob pressure boosts infected without inflating lone stats"): return
    var all_hp_min := TacticalBalance.zombie_hp_range("LIGHT").x
    var all_hp_max := maxi(TacticalBalance.zombie_hp_range("LIGHT").y, maxi(TacticalBalance.zombie_hp_range("MED").y, TacticalBalance.zombie_hp_range("HEAVY").y))
    var fists := ThreeStatRules.weapon_profile("")
    var starter_knife := ThreeStatRules.weapon_profile("Utility Knife")
    var one_hand := ThreeStatRules.weapon_profile("Kitchen Knife")
    var two_hand := ThreeStatRules.weapon_profile("Baseball Bat")
    var sledge := ThreeStatRules.weapon_profile("Sledgehammer")
    var hatchet := ThreeStatRules.weapon_profile("Hatchet")
    var crossbow := ThreeStatRules.weapon_profile("Crossbow")
    var revolver := ThreeStatRules.weapon_profile("6-Shot Revolver")
    var auto_pistol := ThreeStatRules.weapon_profile("12-Shot Automatic")
    var double_barrel := ThreeStatRules.weapon_profile("Double-Barrel Shotgun")
    var pump_shotgun := ThreeStatRules.weapon_profile("Pump Shotgun")
    var medium_rifle := ThreeStatRules.weapon_profile("Medium Rifle")
    var long_rifle := ThreeStatRules.weapon_profile("Long Rifle")
    if not _check(int(ceil(float(all_hp_min) / float(fists["dmax"]))) == 3 and int(ceil(float(all_hp_max) / float(fists["dmin"]))) == 5, "fists kill infected in three to five hits"): return
    if not _check(int(ceil(float(all_hp_min) / float(starter_knife["dmax"]))) == 2 and int(ceil(float(all_hp_max) / float(starter_knife["dmin"]))) == 3, "utility knife kills infected in two to three hits"): return
    if not _check(int(ceil(float(all_hp_min) / float(one_hand["dmax"]))) == 2 and int(ceil(float(all_hp_max) / float(one_hand["dmin"]))) == 2, "standard one hand melee kills in two hits"): return
    if not _check(int(ceil(float(all_hp_min) / float(two_hand["dmax"]))) == 1 and int(ceil(float(all_hp_max) / float(two_hand["dmin"]))) == 2, "standard two hand melee kills in one to two hits"): return
    if not _check(int(sledge["dmin"]) >= all_hp_max and int(hatchet["dmin"]) >= all_hp_max, "top two hand and rare one hand melee kill in one hit"): return
    if not _check(int(ceil(float(all_hp_min) / float(crossbow["gmax"]))) == 2 and int(ceil(float(all_hp_max) / float(crossbow["gmin"]))) == 3 and ThreeStatRules.weapon_mag_capacity(crossbow) == 1 and ThreeStatRules.weapon_projectile_range(crossbow) == 7, "crossbow is one shot before reload and two to three hit medium range"): return
    if not _check(ThreeStatRules.weapon_mag_capacity(revolver) == 6 and ThreeStatRules.weapon_mag_capacity(auto_pistol) == 12 and ThreeStatRules.weapon_optimal_range(revolver) == 4 and ThreeStatRules.weapon_optimal_range(auto_pistol) == 4, "two short-range pistol magazines"): return
    if not _check(ThreeStatRules.weapon_projectile_range(revolver) == 0 and ThreeStatRules.weapon_projectile_range(auto_pistol) == 0 and ThreeStatRules.ranged_falloff_penalty(revolver, 8) > ThreeStatRules.ranged_falloff_penalty(revolver, 4), "pistols can fire to visible targets with distance hit falloff"): return
    if not _check(ThreeStatRules.weapon_mag_capacity(double_barrel) == 2 and int(double_barrel.get("hands", 2)) == 1 and int(ThreeStatRules.weapon_class("Double-Barrel Shotgun").get("hands", 2)) == 1 and ThreeStatRules.weapon_projectiles(double_barrel) == 3 and ThreeStatRules.weapon_projectile_range(double_barrel) == 5, "double barrel is one handed with two shells and three tight physical-range projectiles"): return
    if not _check(ThreeStatRules.weapon_mag_capacity(pump_shotgun) == 6 and ThreeStatRules.weapon_projectiles(pump_shotgun) == 5 and ThreeStatRules.weapon_requires_pump(pump_shotgun) and ThreeStatRules.weapon_projectile_range(pump_shotgun) == 4 and ThreeStatRules.weapon_spread_scale(pump_shotgun) > ThreeStatRules.weapon_spread_scale(double_barrel), "pump shotgun has six shells pump action and wider five-projectile spread"): return
    if not _check(ThreeStatRules.weapon_mag_capacity(medium_rifle) == 20 and ThreeStatRules.weapon_optimal_range(medium_rifle) == 7 and ThreeStatRules.weapon_projectile_range(medium_rifle) == 0, "medium rifle has twenty-round magazine and hit falloff instead of hard range"): return
    if not _check(ThreeStatRules.weapon_mag_capacity(long_rifle) == 5 and ThreeStatRules.weapon_optimal_range(long_rifle) == 10 and ThreeStatRules.weapon_projectile_range(long_rifle) == 0, "long rifle has five-round magazine and long accuracy band"): return
    if not _check(int(revolver["gmin"]) >= all_hp_max and int(auto_pistol["gmin"]) >= all_hp_max and int(double_barrel["gmin"]) >= all_hp_max and int(pump_shotgun["gmin"]) >= all_hp_max and int(medium_rifle["gmin"]) >= all_hp_max and int(long_rifle["gmin"]) >= all_hp_max, "all firearms retain one-projectile one-hit infected lethality"): return
    var recipe_ids: Array = []
    var bandage_recipe: Dictionary = {}
    var tavern_recipe: Dictionary = {}
    var tavern_kitchen_recipe: Dictionary = {}
    var beer_recipe: Dictionary = {}
    var hatchet_recipe: Dictionary = {}
    var crossbow_recipe: Dictionary = {}
    var lock_pick_recipe: Dictionary = {}
    var cure_recipe: Dictionary = {}
    for recipe_value in D.RECIPES.get("Fire Pit", []):
        var fire_recipe: Dictionary = recipe_value
        if str(fire_recipe.get("id", "")) == "Bandage":
            bandage_recipe = fire_recipe
        if str(fire_recipe.get("id", "")) == "Community Stew":
            tavern_recipe = fire_recipe
        if str(fire_recipe.get("id", "")) == "Kitchen Supper":
            tavern_kitchen_recipe = fire_recipe
        if str(fire_recipe.get("id", "")) == "Brew Beer":
            beer_recipe = fire_recipe
    for recipe_value in D.RECIPES.get("Workbench", []):
        var recipe: Dictionary = recipe_value
        recipe_ids.append(str(recipe.get("id", "")))
        if str(recipe.get("id", "")) == "Hatchet": hatchet_recipe = recipe
        if str(recipe.get("id", "")) == "Crossbow": crossbow_recipe = recipe
        if str(recipe.get("id", "")) == "Lock Pick": lock_pick_recipe = recipe
    for recipe_value in D.RECIPES.get("Sewing Table", []):
        var recipe: Dictionary = recipe_value
        recipe_ids.append(str(recipe.get("id", "")))
    for recipe_value in D.RECIPES.get("Infirmary", []):
        var infirmary_recipe: Dictionary = recipe_value
        if str(infirmary_recipe.get("id", "")) == "Zombie Cure":
            cure_recipe = infirmary_recipe
    var found_only_guns := ["6-Shot Revolver", "12-Shot Automatic", "Double-Barrel Shotgun", "Pump Shotgun", "Medium Rifle", "Long Rifle"]
    var found_only_offhand := ["Flashlight", "Firecracker"]
    for gear_name in found_only_guns + found_only_offhand:
        if not _check(not recipe_ids.has(gear_name), "%s is found-only" % gear_name): return
    if not _check(not bandage_recipe.is_empty() and int(bandage_recipe.get("cost", {}).get("Cloth", 0)) == 1 and int(bandage_recipe.get("cost", {}).get("Clean Water", 0)) == 1 and int(bandage_recipe.get("gives_component", {}).get("Bandage", 0)) == 1, "bandage is craftable at the First Fire"): return
    if not _check(not tavern_recipe.is_empty() and Array(tavern_recipe.get("requires", [])).has("Tavern") and int(tavern_recipe.get("gives_resource", {}).get("Cooked Food", 0)) == 5, "tavern stage one upgrades the fire with efficient community cooking"): return
    if not _check(not tavern_kitchen_recipe.is_empty() and Array(tavern_kitchen_recipe.get("requires", [])).has("Tavern Kitchen") and int(tavern_kitchen_recipe.get("cost", {}).get("Raw Food", 0)) == 3 and int(tavern_kitchen_recipe.get("gives_resource", {}).get("Cooked Food", 0)) == 8, "tavern kitchen improves raw-to-cooked conversion"): return
    if not _check(not beer_recipe.is_empty() and Array(beer_recipe.get("requires", [])).has("Tavern Brewery") and int(beer_recipe.get("gives_resource", {}).get("Beer", 0)) == 4 and D.RESOURCE_ORDER.has("Beer"), "tavern brewery unlocks beer as a real camp resource"): return
    if not _check(not cure_recipe.is_empty() and int(cure_recipe.get("cost", {}).get("Zombie Corpse", 0)) == 2 and int(cure_recipe.get("gives_component", {}).get("Zombie Cure", 0)) == 1 and D.RESOURCE_ORDER.has("Zombie Corpse"), "zombie cure is craftable at the infirmary from two recovered corpses"): return
    if not _check(not recipe_ids.has("First Aid Kit") and not D.GEAR.has("First Aid Kit"), "first aid kit is found-only consumable rather than craftable gear"): return
    var nearby_medical: Dictionary = D.ZONES["Nearby Streets"]["loot"]
    var residential_medical: Dictionary = D.ZONES["Residential Blocks"]["loot"]
    if not _check(int(nearby_medical.get("First Aid Kit", 0)) > 0 and int(nearby_medical.get("Zombie Cure", 0)) == 0 and int(residential_medical.get("First Aid Kit", 0)) > int(residential_medical.get("Zombie Cure", 0)) and int(residential_medical.get("Zombie Cure", 0)) > 0, "first aid is rare and zombie cure is the rarer later medical find"): return
    if not _check(recipe_ids.has("Crossbow") and Array(crossbow_recipe.get("requires", [])).has("Armory") and Array(hatchet_recipe.get("requires", [])).has("Armory"), "advanced workbench weapons require the Armory"): return
    if not _check(not lock_pick_recipe.is_empty() and not Array(lock_pick_recipe.get("requires", [])).has("Armory") and int(D.GEAR["Lock Pick"].get("uses_min", 0)) == 1 and int(D.GEAR["Lock Pick"].get("uses_max", 0)) == 3, "lock pick stays basic workbench crafting and lasts one to three unlocks"): return
    var pack_names := ["Worn Backpack", "School Backpack", "Improvised Pack", "Hiking Pack", "Reinforced Pack"]
    for pack_name in pack_names:
        if not _check(not recipe_ids.has(pack_name), "%s is found-only" % pack_name): return
    if not _check(int(D.GEAR["Worn Backpack"]["capacity"]) == 6 and int(D.GEAR["School Backpack"]["capacity"]) == 6 and int(D.GEAR["Improvised Pack"]["capacity"]) == 6 and int(D.GEAR["Hiking Pack"]["capacity"]) == 8 and int(D.GEAR["Reinforced Pack"]["capacity"]) == 8, "backpacks are six or eight carry found-only tiers"): return
    for gear_value in D.GEAR.values():
        var gear_data: Dictionary = gear_value
        if not _check(not gear_data.has("weight") and not gear_data.has("size"), "gear carry uses item slots rather than weight or size metadata"): return
    var timing_bare := {"skills":{"Combat":3}, "fatigue":35.0, "condition":"Healthy", "crouched":false, "equipment":{}}
    var timing_loaded := timing_bare.duplicate(true)
    timing_loaded["equipment"] = {"Weapon":"Sledgehammer","Secondary":"Flashlight","Tool":"Toolbox","Clothing":"Heavy Boots","Pack":"Reinforced Pack"}
    if not _check(TacticalTime.movement_cost(timing_bare, false) == TacticalTime.movement_cost(timing_loaded, false) and TacticalTime.attack_cost(timing_bare, 100) == TacticalTime.attack_cost(timing_loaded, 100), "equipment weight no longer affects tactical timing"): return
    if not _check(int(hatchet_recipe.get("cost", {}).get("Scrap Metal", 0)) >= 5 and int(hatchet_recipe.get("cost", {}).get("Hardware", 0)) >= 4 and not Array(D.TACTICAL_GEAR_UNLOCKS_BY_ZONE["Residential Blocks"]).has("Hatchet") and Array(D.TACTICAL_GEAR_UNLOCKS_BY_ZONE["Commercial Fringe"]).has("Hatchet"), "one hit one hand hatchet is expensive and late field loot"): return
    if not _check(not D.RESOURCE_ORDER.has("Ammo") and not D.STARTING_RESOURCES.has("Ammo"), "camp ammo resource is retired in favor of tactical reloads"): return
    if not _check(Array(D.TACTICAL_GEAR_UNLOCKS_BY_ZONE["Camp Perimeter"]).has("Flashlight") and Array(D.TACTICAL_GEAR_UNLOCKS_BY_ZONE["Nearby Streets"]).has("Lock Pick") and Array(D.TACTICAL_GEAR_UNLOCKS_BY_ZONE["Camp Perimeter"]).has("Firecracker"), "all three active off-hand items can be field finds"): return
    if not _check(TacticalBalance.shove_chance(actor, "LIGHT", 1) > TacticalBalance.shove_chance(actor, "HEAVY", 1), "mass resists shove"): return
    if not _check(TacticalBalance.search_cost(actor) > 0 and TacticalBalance.search_noise(actor) > 0, "search remains bounded"): return
    if not _check(TacticalBalance.zombie_count("Camp Perimeter", "rescue", true) < TacticalBalance.zombie_count("Camp Perimeter", "rescue", false) and TacticalBalance.zombie_count("Camp Perimeter", "rescue", false) == TacticalBalance.zombie_count("Camp Perimeter", "ambush"), "objective zombie balance"): return
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
    var base_camp_source := FileAccess.get_file_as_string("res://scripts/FFCampView.gd")
    var active_camp_source := FileAccess.get_file_as_string("res://scripts/FFCampViewSleepVirus.gd")
    var chore_minigame_source := FileAccess.get_file_as_string("res://scripts/FFCampChoreMinigame.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")
    var scene_source := FileAccess.get_file_as_string("res://main.tscn")
    if not _check(game_source.contains("const THREE_STAT_MODEL := \"%s\"" % THREE_STAT_MODEL), "three-stat save reset marker"): return
    if not _check(game_source.contains("skills.size() != 3") and game_source.contains("SaveCodecThree.invalidate"), "legacy skill saves reset"): return
    if not _check(project_source.contains("Game=\"*res://scripts/GameSleepVirus.gd\""), "sleep-virus game autoload active"): return
    if not _check(scene_source.contains("res://scripts/MainSleepVirus.gd"), "sleep-virus main active"): return
    if not _check(main_source.contains("FFCombatThreeStat.gd") and main_source.contains("FFInspectorThreeStat.gd"), "three-stat UI base routing"): return
    if not _check(active_main_source.contains("FFCombatVirus.gd") and active_main_source.contains("FFInspectorVirus.gd") and active_main_source.contains("FFCampViewSleepVirus.gd"), "sleep-virus UI routing"): return
    if not _check(active_game_source.count("func _resolve_daily_rations()") == 1 and active_game_source.contains("finalize_daily_activity") and active_game_source.contains("ate_normally") and active_game_source.contains("drank_normally"), "active camp life has one visible-consumption ration owner instead of hidden midnight rations"): return
    if not _check(base_camp_source.contains("\"eat_meal\": return \"EATING\"") and base_camp_source.contains("\"drink_water\": return \"DRINKING\""), "living camp visibly labels autonomous eating and drinking"): return
    if not _check(inspector_source.contains("ThreeStatRules.STAT_NAMES") and not inspector_source.contains("Scavenging\", \"Survival"), "inspector exposes three stats"): return
    if not _check(active_inspector_source.contains("ZOMBIE VIRUS") and active_inspector_source.contains("QUARANTINE") and active_inspector_source.contains("start_virus_treatment"), "virus choices exposed in inspector"): return
    if not _check(combat_source.contains("No armor layer") and combat_source.contains("target_actor.hp -= dmg"), "no armor damage mitigation"): return
    if not _check(combat_source.contains("zombie_attack_kind(rng)") and combat_source.contains("zombie_attack_hit_chance(target_actor, attack_kind, mob_size)") and combat_source.contains("zombie_attack_damage_range") and combat_source.contains("mob_attack_cost_multiplier"), "active three-stat combat uses scratch bite and mob attack tuning"): return
    if not _check(combat_source.contains("func reload_or_pump") and combat_source.contains("weapon_loaded") and combat_source.contains("weapon_needs_pump") and combat_source.contains("ranged_falloff_penalty") and combat_source.contains("func _fire_shotgun") and combat_source.contains("weapon_projectile_range") and not combat_source.contains("consume_combat_ammo"), "active ranged combat uses tactical magazines reloads falloff and physical shotgun projectile range"): return
    if not _check(not combat_source.contains("func guard():") and not combat_source.contains("KEY_G: guard()"), "guard removed from active combat"): return
    if not _check(combat_source.contains("btn_forward_primary") and combat_source.contains("draw_button(btn_forward_primary,\"FORWARD\""), "forward occupies former guard slot"): return
    if not _check(combat_source.contains("func shove()") and combat_source.contains("super.shove()"), "shove remains active"): return
    if not _check(combat_source.contains("func toggle_sprint()") and combat_source.contains("func stealth_attack"), "sprint and stealth actions"): return
    if not _check(combat_source.contains("vision_range_for_light") and combat_source.contains("vision_cone_min_dot"), "active sight uses light-sensitive cone geometry"): return
    if not _check(active_combat_source.contains("bite_hits") and active_combat_source.contains("companion_bite_hits") and active_combat_source.contains("outcome != \"bite_hit\"") and active_combat_source.contains("super.zombie_attack"), "only successful bites enter tactical virus tracking"): return
    var base_combat_source := FileAccess.get_file_as_string("res://scripts/FFCombat.gd")
    if not _check(base_combat_source.contains("rescue_contacted and not rescuee.is_empty()") and base_combat_source.contains("func search_loot_container"), "protected rescue opening and physical container search"): return
    if not _check(base_combat_source.contains("var loot_feedback") and base_combat_source.contains("func draw_loot_feedback") and base_combat_source.contains("_show_loot_feedback") and base_combat_source.contains("\"EMPTY\"") and base_combat_source.contains("\"CARRY FULL\""), "container searches give floating in-world loot empty and carry-full feedback"): return
    if not _check(base_game_source.contains("func _tactical_gear_find_chance") and base_game_source.contains("\"Camp Perimeter\": 0.30") and base_game_source.contains("\"Nearby Streets\": 0.50") and base_combat_source.contains("SEARCH COMPLETE") and base_combat_source.contains("SCAVENGE"), "very short and short exploration no longer guarantee named gear"): return
    var finish_expedition_start := base_game_source.find("func _finish_expedition")
    var finish_expedition_end := base_game_source.find("func _resolve_routine_danger", finish_expedition_start)
    var finish_expedition_source := base_game_source.substr(finish_expedition_start, finish_expedition_end - finish_expedition_start)
    if not _check(finish_expedition_start >= 0 and finish_expedition_end > finish_expedition_start and finish_expedition_source.contains("var loot: Dictionary = {}") and not finish_expedition_source.contains("_roll_loot(") and not finish_expedition_source.contains("_roll_gear("), "expedition return never invents abstract loot or gear"): return
    if not _check(finish_expedition_source.contains("living_returner_ids.is_empty()") and finish_expedition_source.find("living_returner_ids.is_empty()") < finish_expedition_source.find("_commit_expedition_return_payload(exp)") and finish_expedition_source.contains("return party from %s was lost"), "carried tactical loot only enters camp after at least one human returner survives the Away timer"): return
    if not _check(not base_game_source.contains("_queue_event(_build_field_event(exp[\"event_key\"], exp))") and not base_game_source.contains("_queue_event(_build_special_site_event(exp[\"special_site\"], exp))") and base_game_source.contains("nothing new is added to the haul"), "legacy field text rewards are unreachable from current expedition flow"): return
    if not _check(base_game_source.contains("\"remaining\": duration") and not base_game_source.contains("func _settle_expedition_time_cost") and not base_game_source.contains("func _advance_settlement_time_for_expedition_return") and base_game_source.contains("func _commit_expedition_return_payload"), "tactical pauses camp time then expedition return uses a live away timer instead of synchronous fast-forward"): return
    if not _check(base_game_source.contains("exp[\"recovered_loot\"] = recovered_loot") and base_game_source.contains("exp[\"recovered_gear\"] = recovered_gear") and base_game_source.contains("_format_tactical_container_loot") and not base_game_source.contains("func _grant_tactical_explore_reward"), "physical tactical haul stays on the away expedition until actual camp return"): return
    if not _check(base_combat_source.contains("func setup_locks") and base_combat_source.contains("locked_doors") and base_combat_source.contains("locked_containers") and base_combat_source.contains("func try_unlock") and base_combat_source.contains("Lock Pick"), "tactical doors and optional containers support persistent lock picking"): return
    if not _check(combat_source.contains("func use_secondary_item") and combat_source.contains("Flashlight") and combat_source.contains("Firecracker") and combat_source.contains("charge_per_tick"), "active off-hand runtime supports flashlight charge lock pick and one-use firecracker"): return
    if not _check(active_combat_source.contains("lead_secondary_item") and active_combat_source.contains("lead_secondary_state"), "tactical result returns persistent off-hand state"): return
    if not _check(base_game_source.contains("inventory_gear_states") and base_game_source.contains("func _default_gear_state") and base_game_source.contains("uses_left") and base_game_source.contains("resources.erase(\"Ammo\")"), "camp persistence retains off-hand durability and removes legacy ammo"): return
    if not _check(base_game_source.contains("const SAVE_SCHEMA_VERSION := 8") and base_game_source.contains("func _normalize_medical_supplies") and base_game_source.contains("resources.erase(\"Medicine\")") and base_game_source.contains("components.erase(\"Sterile Dressing\")") and base_game_source.contains("func _store_loot_item"), "schema-eight camp expansion reset retains medical normalization and tactical component loot"): return
    if not _check(base_game_source.contains("func survivor_carry_capacity") and base_game_source.contains("return 4") and base_combat_source.contains("func party_carry_capacity") and base_combat_source.contains("func _fit_loot_to_remaining_capacity") and combat_source.contains("CARRY %d/%d"), "tactical carry uses four base slots plus backpack party capacity"): return
    if not _check(base_combat_source.contains("func harvest_zombie_corpse") and base_combat_source.contains("\"Zombie Corpse\"") and base_combat_source.contains("\"harvested\"") and base_combat_source.contains("Carry full — no slot available for the corpse."), "killed infected corpses are physical slot-limited tactical loot and persist across reloads"): return
    if not _check(active_camp_source.contains("craft_station_pressed.emit(\"Infirmary\")"), "built infirmary exposes zombie cure crafting in the living camp"): return
    if not _check(combat_source.contains("nearest_exit_distance") and combat_source.contains("LOOT %d/%d"), "route-oriented tactical HUD"): return
    if not _check(not active_game_source.contains("SIM_TIME_SCALE") and base_game_source.contains("const DAY_SECONDS := 300.0") and active_game_source.contains("var camp_delta := float(delta)") and active_game_source.contains("func _advance_settlement_simulation") and active_game_source.contains("\"status\"] = \"Sleeping\"") and active_game_source.contains("func survivor_can_assign") and active_game_source.contains("func start_virus_treatment") and active_game_source.contains("func quarantine_survivor"), "single authoritative five-minute settlement day"): return
    if not _check(active_game_source.contains("func _begin_forced_rest_if_exhausted") and active_game_source.contains("\"status\"] = \"Exhausted\"") and active_game_source.contains("\"resume_task\":resume_task") and active_game_source.contains("survivor[\"fatigue\"] = maxf(0.0") and active_game_source.contains("survivor[\"fatigue\"] = 0.0") and not active_game_source.contains("AWAKE_FATIGUE_PER_SECOND"), "idle camp time lowers fatigue and 100 fatigue suspends work for forced full recovery"): return
    if not _check(active_camp_source.contains("status in [\"Sleeping\", \"Exhausted\"]") and active_camp_source.contains("_sleep_cell_for_survivor") and active_camp_source.contains("POUTING") and active_camp_source.contains("work_phase") and active_camp_source.contains("QUARANTINE"), "camp reflects sleep exhaustion and live chore animation"): return
    if not _check(active_game_source.contains("func camp_chore_needed") and active_game_source.contains("func start_training") and active_game_source.contains("\"Training\"") and active_main_source.contains("PLAY EXPEDITION") and active_camp_source.contains("MENU_VISIBLE_GRID_WIDTH := 8.5") and active_camp_source.contains("_continue_pan_drag"), "camp focus routing timed work and survivor training"): return
    if not _check(active_game_source.contains("func camp_condition_summary") and active_game_source.contains("previous_daily_activity") and active_game_source.contains("CampLifeRules.record_daily_activity") and active_game_source.contains("if not initialized or sim_paused or game_over"), "camp condition and daily activity stay behind settlement pause boundary"): return
    if not _check(base_game_source.contains("func _resolve_daily_rations") and active_game_source.contains("func _resolve_daily_rations") and active_game_source.contains("eat_meal") and active_game_source.contains("drink_water"), "autonomous meal water consumption overrides abstract daily ration batch"): return
    if not _check(active_game_source.contains("timed-maintenance-v1") and active_game_source.contains("func _process_maintenance_incidents") and active_game_source.contains("func daily_chore_deadline_hours") and active_game_source.contains("next_chore_at") and not active_game_source.contains("func _generate_daily_chore_set"), "camp maintenance is irregular deadline-driven rather than a daily chore quota"): return
    if not _check(active_game_source.contains("func assign_daily_chore") and active_game_source.contains("func perform_daily_chore_action") and active_game_source.contains("func duty_fairness_snapshot") and active_game_source.contains("Timed camp maintenance is handled from the camp work board."), "timed maintenance keeps the existing assignment/minigame path"): return
    if not _check(active_main_source.contains("CampChoreMinigame") and active_main_source.contains("ASSIGN & PLAY") and active_main_source.contains("CAMP MAINTENANCE") and active_main_source.contains("TIME LEFT") and active_main_source.contains("MISS:") and not active_main_source.contains("Only one or two chores are needed each day.") and not active_main_source.contains("chore_pause_before") and not active_main_source.contains("Game.set_paused(true)"), "maintenance work board exposes deadlines and consequences without pausing settlement time"): return
    if not _check(chore_minigame_source.contains("signal action_requested") and chore_minigame_source.contains("CHOP") and chore_minigame_source.contains("DEBRIS") and chore_minigame_source.contains("CRATE") and chore_minigame_source.contains("working in camp while you play"), "shared touch-first chore minigame supports four maintenance fantasies over live camp"): return
    if not _check(active_camp_source.contains("WORK_BOARD_CELL") and active_camp_source.contains("duties_pressed.emit()"), "physical work board remains the active maintenance entry point"): return
    if not _check(base_camp_source.contains("func _resident_bed_slots") and base_camp_source.contains("Game.population()") and base_camp_source.contains("func _draw_resident_beds") and active_camp_source.contains("return _shelter_sleep_slots()"), "visible beds match living residents while sleep targeting shares shelter geometry"): return
    if not _check(base_game_source.contains("func _build_camp_zombie_attack_event") and base_game_source.contains("func _resolve_camp_zombie_attack") and base_game_source.contains("func _break_camp_building") and base_game_source.contains("func _ruin_random_camp_supplies") and base_game_source.contains("func _build_solo_night_event") and base_game_source.contains("func _build_crowd_night_event") and base_game_source.contains("population() < 1"), "camp events include solo robust and destructive pressure paths"): return
    var attack_resolve_start := base_game_source.find("func _resolve_camp_zombie_attack")
    var attack_resolve_end := base_game_source.find("func _build_camp_spoil_event", attack_resolve_start)
    var attack_resolve_source := base_game_source.substr(attack_resolve_start, attack_resolve_end - attack_resolve_start)
    if not _check(attack_resolve_start >= 0 and attack_resolve_end > attack_resolve_start and attack_resolve_source.contains("CampLifeRules.camp_attack_outcome") and not attack_resolve_source.contains("skill_check") and not attack_resolve_source.contains("[\"skills\"]"), "random camp zombie attacks resolve from stored luck plus infrastructure, never survivor stats or player skill"): return
    if not _check(not active_game_source.contains("func _advance_settlement_time_for_expedition_return") and active_game_source.contains("not _camp_present_survivors().is_empty()") and base_game_source.contains("if _camp_present_survivors().is_empty():") and base_game_source.contains("_camp_present_survivors().size()"), "camp events and fresh maintenance require somebody physically home while away timers run in normal settlement time"): return
    if not _check(base_game_source.contains("buildings = {\"Fire Pit\": true, \"Sleeping Bag\": true, \"Storage Crate\": true}") and not base_game_source.contains("buildings[\"Workbench\"] = true") and not active_game_source.contains("buildings[\"Workbench\"] = true"), "starter camp begins with fire bedroll storage but no free workbench"): return
    if not _check(base_game_source.contains("func building_under_construction") and base_game_source.contains("building_under_construction(str(building))") and active_main_source.contains("CAMP EXPANSION") and active_main_source.contains("_draw_expansion_group") and active_main_source.contains("\"Large Tarp\", \"Barracks\", \"Dormitory\""), "work board owns duplicate-safe permanent camp expansion"): return
    if not _check(base_game_source.contains("if buildings.get(\"Dormitory\", false)") and base_game_source.contains("if buildings.get(\"Barracks\", false)") and base_game_source.contains("if buildings.get(\"Large Tarp\", false)") and base_game_source.contains("return 12") and base_game_source.contains("return 7") and base_game_source.contains("return 3"), "shelter capacity is tiered three seven twelve eighteen"): return
    if not _check(not base_game_source.contains("shelter_capacity() + 1") and base_game_source.contains("Shelter is full. First Fire has to turn this survivor away."), "shelter capacity is a hard recruitment cap with no squeeze-in exception"): return
    if not _check(base_game_source.contains("founder[\"equipment\"] = {\"Weapon\": \"Utility Knife\", \"Secondary\": \"\", \"Clothing\": \"\", \"Pack\": \"\", \"Tool\": \"\"}"), "founder starts with exactly one carried loot item"): return
    if not _check(active_camp_source.contains("func _draw_wilderness") and active_camp_source.contains("remain code/data only") and not active_camp_source.contains("build_plot_pressed.emit"), "sparse wilderness hides future build placeholders"): return
    if not _check(inspector_source.contains("CAMP LIFE") and inspector_source.contains("_start_training") and inspector_source.contains("physical camp work board") and not inspector_source.contains("camp_chore_needed"), "survivor inspector routes daily chores to physical work board"): return

    if not _check(is_equal_approx(VirusRules.bite_exposure_chance(), 0.03) and is_equal_approx(VirusRules.exposure_chance(1), VirusRules.exposure_chance(8)) and VirusRules.EXPOSED_NATURAL_CLEAR_CHANCE >= 0.50, "virus exposure is a fixed small independent chance per successful bite"): return
    if not _check(active_game_source.contains("bite_exposure_occurs(lead_bites, rng)") and active_game_source.contains("companion_bite_hits") and not active_game_source.contains("exposure_chance(infected_hits)"), "game resolves bite-only exposure without stacked hit chance"): return
    var early_plan: Dictionary = VirusRules.treatment_plan(VirusRules.STAGE_EXPOSED, false)
    var infected_plan: Dictionary = VirusRules.treatment_plan(VirusRules.STAGE_INFECTED, false)
    var fever_no_infirmary: Dictionary = VirusRules.treatment_plan(VirusRules.STAGE_FEVERISH, false)
    var fever_infirmary: Dictionary = VirusRules.treatment_plan(VirusRules.STAGE_FEVERISH, true)
    if not _check(int(early_plan.get("resources", {}).get("Clean Water", 0)) == 1 and int(early_plan.get("components", {}).get("Bandage", 0)) == 1, "early virus decontamination uses a crafted bandage plus clean water"): return
    if not _check(int(infected_plan.get("components", {}).get("Zombie Cure", 0)) == 1, "established virus consumes one zombie cure"): return
    if not _check(not bool(fever_no_infirmary.get("available", true)) and bool(fever_infirmary.get("available", false)) and int(fever_infirmary.get("components", {}).get("Zombie Cure", 0)) == 1, "feverish virus requires infirmary plus one zombie cure"): return

    if not _check(ExpeditionRules.zone_cap("Camp Perimeter") == 3, "perimeter cap"): return
    if not _check(ExpeditionRules.starting_routes() == ["Camp Perimeter", "Nearby Streets", "Residential Blocks", "Commercial Fringe"], "very short through far are available without a vehicle"): return
    if not _check(ExpeditionRules.MAX_PARTY_SIZE == 2, "tactical expedition party supports one lead plus one companion"): return
    if not _check(ExpeditionRules.route_band("Camp Perimeter") == "VERY SHORT" and ExpeditionRules.route_band("Nearby Streets") == "SHORT" and ExpeditionRules.route_band("Residential Blocks") == "MEDIUM" and ExpeditionRules.route_band("Commercial Fringe") == "FAR" and ExpeditionRules.route_band("Industrial Edge") == "VERY FAR", "five expedition distance bands"): return
    if not _check(ExpeditionRules.route_hours("Camp Perimeter") == 3.0 and ExpeditionRules.route_hours("Nearby Streets") == 5.0 and ExpeditionRules.route_hours("Residential Blocks") == 8.0 and ExpeditionRules.route_hours("Commercial Fringe") == 12.0 and ExpeditionRules.route_hours("Industrial Edge") == 18.0, "route hours stay authored by distance"): return
    if not _check(ExpeditionRules.route_duration_seconds("Camp Perimeter", 300.0) == 37.5 and ExpeditionRules.route_duration_seconds("Nearby Streets", 300.0) == 62.5, "route hours map onto the five-minute day"): return
    if not _check(ExpeditionRules.route_is_free("Camp Perimeter") and ExpeditionRules.route_is_free("Nearby Streets") and not ExpeditionRules.route_is_free("Residential Blocks"), "very short and short are free while medium is provisioned"): return
    var medium_two := ExpeditionRules.route_supply_cost("Residential Blocks", 2)
    var far_two := ExpeditionRules.route_supply_cost("Commercial Fringe", 2)
    if not _check(int(medium_two["Cooked Food"]) == 2 and int(medium_two["Clean Water"]) == 2 and int(far_two["Cooked Food"]) == 4 and int(far_two["Clean Water"]) == 4, "food and water costs multiply by party size"): return
    if not _check(ExpeditionRules.route_is_unlocked("Commercial Fringe", {}) and not ExpeditionRules.route_is_unlocked("Industrial Edge", {}) and ExpeditionRules.route_is_unlocked("Industrial Edge", {ExpeditionRules.VEHICLE_UNLOCK_FLAG:true}), "only very far requires expedition vehicle unlock"): return
    if not _check(ExpeditionRules.should_trigger_tactical_event("Camp Perimeter", RandomNumberGenerator.new()), "standard send out is always tactical"): return
    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Camp Perimeter"), "scenario catalog"): return
    if not _check(TacticalScenarios.outing_weight("quiet_explore") + TacticalScenarios.outing_weight("infected_explore") > TacticalScenarios.outing_weight("ambush") and TacticalScenarios.outing_weight("ambush") > TacticalScenarios.outing_weight("survivor_rescue") and TacticalScenarios.outing_weight("survivor_rescue") > TacticalScenarios.outing_weight("pet_rescue"), "outing rarity is explore then ambush then survivor then pet"): return
    if not _check(TacticalBalance.zombie_count_range("Camp Perimeter", "explore") == Vector2i(0, 3), "very short exploration can roll zero through three infected"): return
    if not _check(TacticalBalance.zombie_count_range("Nearby Streets", "explore", false, true).x >= 2 and TacticalBalance.zombie_count_range("Residential Blocks", "explore", false, true).x >= 2 and TacticalBalance.zombie_count_range("Industrial Edge", "explore", false, true).x >= 2, "only very short exploration can fall below two infected"): return
    if not _check(TacticalBalance.zombie_count_range("Commercial Fringe", "ambush") == Vector2i(5, 5), "ambush population is five infected"): return
    if not _check(TacticalBalance.zombie_count_range("Commercial Fringe", "rescue", true) == Vector2i(3, 3), "pet rescue population is three infected"): return
    if not _check(TacticalBalance.zombie_count_range("Commercial Fringe", "rescue", false) == Vector2i(5, 5), "survivor rescue population is five infected"): return
    if not _check(TacticalBalance.explore_site_count_range("Camp Perimeter") == Vector2i(1, 2) and TacticalBalance.explore_site_count_range("Nearby Streets") == Vector2i(2, 3) and TacticalBalance.explore_site_count_range("Industrial Edge").x >= 5, "very short and short routes are intentionally scarce while search opportunities rise with distance"): return
    if not _check(TacticalBalance.container_empty_chance("Camp Perimeter", "fridge", 0) > TacticalBalance.container_empty_chance("Industrial Edge", "fridge", 0) and TacticalBalance.container_empty_chance("Nearby Streets", "car", 85) > TacticalBalance.container_empty_chance("Nearby Streets", "car", 0), "early routes and picked-over zones produce more empty containers"): return
    if not _check(TacticalBalance.container_allows_item("fridge", "Raw Food") and not TacticalBalance.container_allows_item("fridge", "Scrap Metal") and TacticalBalance.container_allows_item("crate", "Scrap Metal") and not TacticalBalance.container_allows_item("crate", "Cooked Food") and TacticalBalance.container_allows_item("cabinet", "First Aid Kit"), "container families own loot-specific pools"): return
    var loot_rng := RandomNumberGenerator.new()
    loot_rng.seed = 20261002
    for _sample in range(80):
        var fridge_loot := TacticalBalance.roll_container_loot("Commercial Fringe", "fridge", loot_rng, 0)
        if not _check(not fridge_loot.has("Scrap Metal") and not fridge_loot.has("Hardware"), "fridge rolls stay food-water specific"): return
        var crate_loot := TacticalBalance.roll_container_loot("Commercial Fringe", "crate", loot_rng, 0)
        if not _check(not crate_loot.has("Raw Food") and not crate_loot.has("Clean Water"), "crate rolls stay salvage specific"): return
    if not _check(TacticalBalance.locked_container_chance("Industrial Edge") > TacticalBalance.locked_container_chance("Camp Perimeter") and TacticalBalance.locked_door_chance("Industrial Edge") > TacticalBalance.locked_door_chance("Camp Perimeter"), "lock frequency rises with expedition distance"): return
    if not _check(not game_source.contains("func start_expedition") and base_game_source.contains("func start_expedition(primary_id, zone, companion_id = -1)") and base_game_source.contains("_pay_expedition_cost(zone, party_ids.size())") and base_game_source.contains("\"time_cost_paid\": false") and base_game_source.contains("_begin_tactical_encounter(exp)") and not base_game_source.contains("_advance_settlement_time_for_departure"), "base send out commits supplies and launches tactical immediately without advancing camp time"): return
    if not _check(not base_game_source.contains("func _settle_expedition_time_cost") and base_game_source.contains("exp[\"tactical_resolved\"] = true") and base_game_source.contains("exp[\"remaining\"] = maxf(0.0, float(exp.get(\"duration\", 0.0)))") and base_game_source.contains("func _resume_expedition(eid)") and base_game_source.contains("exp[\"state\"] = \"traveling\""), "tactical resolution starts a live Away return timer instead of fast-forwarding camp time"): return
    if not _check(base_game_source.contains("sim_paused = true") and active_game_source.contains("if not initialized or sim_paused or game_over"), "tactical board freezes settlement simulation"): return
    if not _check(base_combat_source.contains("TacticalBalance.zombie_count(") and base_combat_source.contains("context.get(\"rescue_is_pet\", false)") and base_combat_source.contains("loot_containers"), "tactical runtime routes scenario subtype into authoritative infected population rules"): return
    if not _check(base_combat_source.contains("func supplement_distance_loot_containers") and base_combat_source.contains("while loot_containers.size() > target") and base_combat_source.contains("context.get(\"zone_pressure\", 0)") and base_game_source.contains("\"zone_pressure\": int(zone_pressure.get(str(exp[\"zone\"]), 0))") and base_combat_source.contains("func zombie_mob_size") and base_combat_source.contains("mob_attack_cost_multiplier") and base_combat_source.contains("direct_chase"), "tactical runtime trims authored search points to route scarcity and carries depletion pressure into container loot"): return
    if not _check(base_combat_source.contains("ids.size() > 1") and base_combat_source.contains("ally = make_actor(companion, ally_spawn, false)") and base_combat_source.contains("func ally_ready_to_extract"), "second expedition survivor is a real tactical companion and must extract"): return
    if not _check(base_game_source.contains("func start_special_site") and base_game_source.contains("\"outing\": \"special_site\""), "discovered special sites also route through tactical play"): return
    if not _check(active_main_source.contains("PLAY EXPEDITION") and active_main_source.contains("COMPANION — SOLO") and active_main_source.contains("Travel supplies:") and active_main_source.contains("expedition_supply_cost"), "gate presents party selection and scaled expedition logistics"): return
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
    if not _check(is_equal_approx(CampLifeRules.SLEEP_DURATION, 100.0) and is_equal_approx(CampLifeRules.FIRE_DECAY_PER_SECOND, 0.096) and CampLifeRules.FORCED_REST_MIN_HOURS == 3 and CampLifeRules.FORCED_REST_MAX_HOURS == 5, "normal sleep is eight in-game hours and forced exhaustion remains three to five hours"): return
    var exhaustion_rng := RandomNumberGenerator.new()
    exhaustion_rng.seed = 20261002
    var exhaustion_duration := CampLifeRules.forced_rest_duration(300.0, exhaustion_rng)
    if not _check(exhaustion_duration in [37.5, 50.0, 62.5], "100 fatigue forces three to five in-game hours of bed rest"): return
    if not _check(CampLifeRules.camp_condition_band(90.0) == "Well Kept" and CampLifeRules.camp_condition_mood_modifier(90.0) == 1, "well-kept camp mood bonus"): return
    if not _check(CampLifeRules.camp_condition_band(70.0) == "Acceptable" and CampLifeRules.camp_condition_mood_modifier(70.0) == 0, "acceptable camp is mood neutral"): return
    if not _check(CampLifeRules.camp_condition_mood_modifier(50.0) == -1 and CampLifeRules.camp_condition_mood_modifier(30.0) == -2 and CampLifeRules.camp_condition_mood_modifier(10.0) == -3, "neglected camp mood bands"): return
    if not _check(CampLifeRules.degrade_camp_condition(50.0, 10.0) < 50.0 and CampLifeRules.degrade_camp_condition(0.0, 999.0) == 0.0, "camp condition degrades within bounds"): return
    if not _check(CampLifeRules.recover_camp_condition(50.0, "clean_camp") > 50.0 and CampLifeRules.recover_camp_condition(90.0, "repair_perimeter") == 100.0, "camp maintenance recovery is bounded"): return
    var busy_activity := CampLifeRules.default_daily_activity(4)
    busy_activity = CampLifeRules.record_daily_activity(busy_activity, 4, "Crafting", "craft", 19.0, 12.0)
    busy_activity = CampLifeRules.record_daily_activity(busy_activity, 4, "Building", "build", 23.0, 30.0)
    busy_activity = CampLifeRules.finalize_daily_activity(busy_activity, 4)
    if not _check(bool(busy_activity["missed_meal"]) and bool(busy_activity["missed_sleep"]) and CampLifeRules.daily_workload_pressure(busy_activity, 4) == 3, "assigned work can crowd out meal and sleep windows"): return
    var free_activity := CampLifeRules.default_daily_activity(4)
    free_activity["meal_attempted"] = true
    free_activity["water_attempted"] = true
    free_activity["ate_normally"] = true
    free_activity["drank_normally"] = true
    free_activity = CampLifeRules.record_daily_activity(free_activity, 4, "Available", "", 19.0, 12.0)
    free_activity = CampLifeRules.record_daily_activity(free_activity, 4, "Sleeping", "sleep", 23.0, CampLifeRules.SLEEP_DURATION)
    free_activity = CampLifeRules.finalize_daily_activity(free_activity, 4)
    if not _check(not bool(free_activity["missed_meal"]) and not bool(free_activity["missed_water"]) and not bool(free_activity["missed_sleep"]) and bool(free_activity["ate_normally"]) and bool(free_activity["drank_normally"]) and bool(free_activity["slept_normally"]) and bool(free_activity["autonomous"]), "free survivor actually eats drinks and sleeps"): return
    if not _check(int(CampLifeRules.normalize_daily_activity(busy_activity, 5).get("day", -1)) == 5 and not bool(CampLifeRules.normalize_daily_activity(busy_activity, 5).get("assigned_work", true)), "daily activity resets at day transition"): return
    var missed_result := CampLifeRules.apply_missed_schedule_consequences(base_needs, 10.0, true, true, true)
    if not _check(float(missed_result["needs"]["hunger"]) < float(base_needs["hunger"]) and float(missed_result["needs"]["thirst"]) < float(base_needs["thirst"]) and float(missed_result["fatigue"]) > 10.0, "missed schedule uses existing hunger thirst and fatigue axes"): return
    var shortage_result := CampLifeRules.apply_daily_shortage_consequences(base_needs, true, true)
    if not _check(float(shortage_result["hunger"]) < float(base_needs["hunger"]) and float(shortage_result["thirst"]) < float(base_needs["thirst"]), "resource shortages penalize needs without fake positive rations"): return
    var chore_rng := RandomNumberGenerator.new()
    chore_rng.seed = 20261001
    var incident := CampLifeRules.generate_maintenance_incident(7, 1800.0, chore_rng)
    if not _check(str(incident.get("kind", "")) in CampLifeRules.DAILY_CHORE_KINDS and int(incident.get("day", -1)) == 7 and float(incident.get("deadline_at", 0.0)) > 1800.0, "maintenance incident uses approved catalog and carries an explicit future deadline"): return
    var persisted_incidents := CampLifeRules.normalize_daily_chores([incident], 8)
    if not _check(persisted_incidents.size() == 1 and str(persisted_incidents[0].get("id", "")) == str(incident.get("id", "")), "timed maintenance can persist across midnight without rerolling"): return
    var gap := CampLifeRules.maintenance_incident_gap(chore_rng)
    if not _check(gap >= CampLifeRules.CHORE_INCIDENT_GAP_MIN_SECONDS and gap <= CampLifeRules.CHORE_INCIDENT_GAP_MAX_SECONDS and CampLifeRules.CHORE_INCIDENT_GAP_MIN_SECONDS >= 240.0, "maintenance problems are deliberately spaced rather than forced daily"): return
    var poke_failure := CampLifeRules.maintenance_incident_consequence("poke_fire")
    var clear_failure := CampLifeRules.maintenance_incident_consequence("clear_area")
    if not _check(float(poke_failure.get("fire_loss", 0.0)) > 0.0 and float(clear_failure.get("condition_loss", 0.0)) > 0.0, "missed maintenance has explicit fire or camp-condition consequences"): return
    if not _check(CampLifeRules.camp_attack_outcome(1, "hold", false, false) == "killed" and CampLifeRules.camp_attack_outcome(100, "hold", false, false) == "repelled", "camp attack luck table spans lethal through repelled outcomes"): return
    if not _check(CampLifeRules.camp_attack_outcome(10, "hold", false, false) == "exposed" and CampLifeRules.camp_attack_outcome(10, "hold", true, true) == "wounded", "security infrastructure improves the same camp attack die roll without using survivor stats"): return
    if not _check(CampLifeRules.camp_attack_outcome(15, "draw_away", false, false) == "exposed" and CampLifeRules.camp_attack_outcome(70, "draw_away", false, false) == "repelled", "draw-away response remains a luck-driven personal-risk choice"): return
    if not _check(CampLifeRules.camp_weather_breaks(42, false) and not CampLifeRules.camp_weather_breaks(43, false) and not CampLifeRules.camp_weather_breaks(1, true), "storm building loss uses a deterministic hidden roll and bracing guarantees protection"): return
    if not _check(CampLifeRules.camp_spoil_goes_bad(45) and not CampLifeRules.camp_spoil_goes_bad(46), "supply spoilage gamble has a stable hidden-roll boundary"): return
    var poke_effect := CampLifeRules.daily_chore_effect("poke_fire")
    var chop_effect := CampLifeRules.daily_chore_effect("chop_wood")
    var clear_effect := CampLifeRules.daily_chore_effect("clear_area")
    var stack_effect := CampLifeRules.daily_chore_effect("stack_supplies")
    if not _check(float(poke_effect.get("fire_gain", 0.0)) > 0.0 and int(poke_effect.get("wood_gain", 0)) == 0, "poke fire improves fire without wood cost"): return
    if not _check(int(chop_effect.get("wood_gain", 0)) == 1, "chop wood reward is bounded"): return
    if not _check(float(clear_effect.get("condition_gain", 0.0)) > 0.0 and float(stack_effect.get("condition_gain", 0.0)) > 0.0 and not stack_effect.has("wood_gain"), "clear and stack improve condition without duplicating supplies"): return
    if not _check(CampLifeRules.daily_chore_target_index("poke_fire", 41, 0) >= 0 and CampLifeRules.daily_chore_target_index("poke_fire", 41, 0) < CampLifeRules.CHORE_TARGET_COUNT and CampLifeRules.daily_chore_target_index("poke_fire", 41, 0) != CampLifeRules.daily_chore_target_index("poke_fire", 41, 1), "minigame target varies deterministically by progress"): return
    if not _check(CampLifeRules.duty_fairness_pressure([6,7], [4,5,6,7], 7) == 2 and CampLifeRules.duty_fairness_pressure([], [], 7) == 0, "duty fairness only counts eligible days"): return
    var poke_fatigue := CampLifeRules.camp_chore_fatigue(CampLifeRules.daily_chore_duration("poke_fire"))
    var clear_fatigue := CampLifeRules.camp_chore_fatigue(CampLifeRules.daily_chore_duration("clear_area"))
    if not _check(poke_fatigue >= 6.0 and clear_fatigue > poke_fatigue, "camp chores apply a meaningful duration-scaled fatigue hit"): return
    var quick_craft_fatigue := CampLifeRules.crafting_fatigue(3.0)
    var long_craft_fatigue := CampLifeRules.crafting_fatigue(20.0)
    if not _check(quick_craft_fatigue >= 3.0 and long_craft_fatigue > quick_craft_fatigue, "crafting always costs fatigue and longer recipes cost more"): return
    var perimeter_fatigue := ExpeditionRules.route_fatigue_hit("Camp Perimeter")
    var street_fatigue := ExpeditionRules.route_fatigue_hit("Nearby Streets")
    var residential_fatigue := ExpeditionRules.route_fatigue_hit("Residential Blocks")
    var commercial_fatigue := ExpeditionRules.route_fatigue_hit("Commercial Fringe")
    var industrial_fatigue := ExpeditionRules.route_fatigue_hit("Industrial Edge")
    if not _check(perimeter_fatigue >= 20.0 and perimeter_fatigue < street_fatigue and street_fatigue < residential_fatigue and residential_fatigue < commercial_fatigue and commercial_fatigue < industrial_fatigue and industrial_fatigue >= 80.0, "expedition return fatigue is a large monotonic hit scaled to route distance"): return
    if not _check(active_game_source.contains("CampLifeRules.camp_chore_fatigue(duration)") and base_game_source.contains("CampLifeRules.crafting_fatigue(float(recipe[\"time\"]))") and base_game_source.contains("ExpeditionRules.route_fatigue_hit(zone)"), "runtime routes chores crafting and expedition return through the explicit fatigue rules"): return
    var pet_rng:=RandomNumberGenerator.new(); pet_rng.seed=7
    var pet_find:=CampLifeRules.pet_forage_resource("Dog",pet_rng)
    if not _check(CampLifeRules.default_pet_needs().size()==1 and CampLifeRules.default_pet_needs().has("affection"), "affection-only pet needs"): return
    if not _check(CampLifeRules.pet_should_leave({"affection":10}) and not CampLifeRules.pet_should_leave({"affection":60}), "neglected pets leave"): return
    if not _check(pet_find in ["Wood","Scrap Metal","Hardware","Cloth","Plastic","Raw Food"], "daily pet material reward"): return
    var schedule_rng := RandomNumberGenerator.new(); schedule_rng.seed = 13
    var sleep_decoupled := CampLifeRules.update_needs({"sleep":95,"hunger":90,"thirst":90,"fun":90,"safety":90,"hygiene":90}, 80.0, 0.0, 80.0, false, false)
    if not _check(is_equal_approx(float(sleep_decoupled["sleep"]), 95.0), "sleep need stays independent from work fatigue"): return
    var bedtime_needs := CampLifeRules.update_needs({"sleep":95,"hunger":90,"thirst":90,"fun":90,"safety":90,"hygiene":90}, 0.0, 175.0, 80.0, false, false)
    if not _check(float(bedtime_needs["sleep"]) <= CampLifeRules.SLEEP_START_NEED, "awake sleep need falls enough to trigger the nightly sleep window"): return
    var sleeping_needs := CampLifeRules.update_needs({"sleep":55,"hunger":90,"thirst":90,"fun":90,"safety":90,"hygiene":90}, 40.0, 30.0, 80.0, false, false, true)
    if not _check(is_equal_approx(float(sleeping_needs["sleep"]), 55.0), "sleep need does not keep decaying while survivor is in bed"): return
    if not _check(str(CampLifeRules.choose_available_activity({"sleep":50,"fun":90},0.0,5,1,0,false,schedule_rng,23.0,CampLifeRules.default_daily_activity(2),3,3).get("kind","")) == "rest", "nighttime sleep need selects real sleep"): return
    if not _check(str(CampLifeRules.choose_available_activity({"sleep":90,"hunger":90,"thirst":90,"fun":90,"safety":90,"hygiene":90},0.0,5,1,0,false,schedule_rng,12.5,CampLifeRules.default_daily_activity(2),3,3).get("kind","")) == "drink_water", "midday water window selects drinking"): return
    if not _check(str(CampLifeRules.choose_available_activity({"sleep":90,"hunger":90,"thirst":90,"fun":90,"safety":90,"hygiene":90},0.0,5,1,0,false,schedule_rng,19.0,CampLifeRules.default_daily_activity(2),3,3).get("kind","")) == "eat_meal", "evening meal window selects eating"): return
    var bedroll_sleep := CampLifeRules.complete_sleep({"sleep":40}, 90.0, 50.0, 0)
    var tarp_sleep := CampLifeRules.complete_sleep({"sleep":40}, 90.0, 50.0, 1)
    var barracks_sleep := CampLifeRules.complete_sleep({"sleep":40}, 90.0, 50.0, 2)
    var dorm_sleep := CampLifeRules.complete_sleep({"sleep":40}, 90.0, 50.0, 3)
    if not _check(float(tarp_sleep["needs"]["sleep"]) > float(bedroll_sleep["needs"]["sleep"]) and float(barracks_sleep["needs"]["sleep"]) > float(tarp_sleep["needs"]["sleep"]) and float(dorm_sleep["needs"]["sleep"]) > float(barracks_sleep["needs"]["sleep"]), "eight-hour sleep raises the Rested moodlet faster as shelter improves"): return
    if not _check(is_equal_approx(float(bedroll_sleep["stress"]), 50.0) and is_equal_approx(float(dorm_sleep["stress"]), 50.0), "normal sleep leaves the separate Stress axis unchanged"): return
    if not _check(str(CampLifeRules.choose_available_activity({"sleep":90,"hunger":90,"thirst":90,"fun":90,"safety":20,"hygiene":90},0.0,5,1,0,false,schedule_rng,16.0,CampLifeRules.default_daily_activity(2),3,3).get("kind","")) == "keep_watch", "low safety drives treeline watch outside need windows"): return
    if not _check(str(CampLifeRules.choose_available_activity({"sleep":90,"fun":90},0.0,5,1,0,false,RandomNumberGenerator.new()).get("kind","")) != "maintain_fire", "productive chores are not autonomous"): return
    var stress_fire_activity := CampLifeRules.choose_available_activity({"sleep":90,"hunger":90,"thirst":90,"fun":90,"safety":90,"hygiene":90},70.0,5,1,0,false,schedule_rng,16.0,CampLifeRules.default_daily_activity(2),3,3,0,60.0)
    if not _check(str(stress_fire_activity.get("kind","")) == "watch_fire" and CampLifeRules.fire_watch_stress_relief() > 0.0, "high Stress drives visible starter-camp fire watching even when Fun is healthy"): return
    var tavern_activity := CampLifeRules.choose_available_activity({"sleep":90,"hunger":90,"thirst":90,"fun":20,"safety":90,"hygiene":90},0.0,5,3,2,false,schedule_rng,16.0,CampLifeRules.default_daily_activity(2),3,3,0)
    var beer_activity := CampLifeRules.choose_available_activity({"sleep":90,"hunger":90,"thirst":90,"fun":20,"safety":90,"hygiene":90},0.0,5,3,3,false,schedule_rng,16.0,CampLifeRules.default_daily_activity(2),3,3,1)
    if not _check(str(tavern_activity.get("kind","")) == "tavern_social" and str(beer_activity.get("kind","")) == "tavern_drink", "progressive tavern social activity culminates in optional beer sessions"): return
    if not _check(base_game_source.contains("var pets := []") and base_game_source.contains("func start_camp_chore") and base_game_source.contains("func perform_camp_task_tap") and base_game_source.contains("rescue_is_pet"), "active camp work and pet rescue state"): return
    if not _check(CampSocial.candidate_standing({"id":1,"condition":"Healthy","skills":{"Leadership":5},"reputation":0,"relationships":{}}, []) == 30, "leadership drives politics"): return
    if not _check(D.BUILD_ORDER.size() == 15 and D.BUILDINGS.has("Large Tarp") and D.BUILDINGS.has("Tavern") and D.BUILDINGS.has("Tavern Kitchen") and D.BUILDINGS.has("Tavern Brewery") and D.BUILDINGS.has("Barracks") and D.BUILDINGS.has("Dormitory") and D.BUILDINGS.has("Armory") and not D.BUILDINGS.has("Cabin") and not D.BUILDINGS.has("Bunkhouse") and not D.BUILDINGS.has("Communal Table"), "camp expansion building tree includes three-stage tavern"): return
    if not _check(Array(D.BUILDINGS["Tavern"].get("requires", [])).has("Large Tarp") and Array(D.BUILDINGS["Tavern Kitchen"].get("requires", [])).has("Tavern") and Array(D.BUILDINGS["Tavern Kitchen"].get("requires", [])).has("Garden Plot") and Array(D.BUILDINGS["Tavern Brewery"].get("requires", [])).has("Tavern Kitchen") and Array(D.BUILDINGS["Tavern Brewery"].get("requires", [])).has("Barracks") and Array(D.BUILDINGS["Barracks"].get("requires", [])).has("Sewing Table") and Array(D.BUILDINGS["Infirmary"].get("requires", [])).has("Water Tank") and Array(D.BUILDINGS["Armory"].get("requires", [])).has("Watch Post") and Array(D.BUILDINGS["Dormitory"].get("requires", [])).has("Tavern Kitchen") and Array(D.BUILDINGS["Dormitory"].get("requires", [])).has("Water Tank"), "late buildings and tavern stages depend on established camp tech"): return
    if not _check(int(D.BUILDINGS["Workbench"].get("cost", {}).get("Wood", 0)) == 2 and int(D.BUILDINGS["Workbench"].get("cost", {}).get("Scrap Metal", 0)) == 1 and not D.BUILDINGS["Workbench"].has("requires"), "first workbench is a light direct starter build"): return
    var base_recovery := CampLifeRules.idle_recovery_rates(0, false, 0)
    if not _check(base_recovery.x > 0.0 and base_recovery.x <= 0.05, "idle fatigue recovery is gradual enough for work fatigue to persist"): return
    if not _check(base_recovery.y > 0.0 and base_recovery.y <= 0.02, "idle stress recovery is a slow background effect rather than an instant reset"): return
    if not _check(base_recovery.x * 300.0 < 10.0 and base_recovery.y * 300.0 < 10.0, "a full idle camp day only removes a modest amount of base fatigue and stress"): return
    if not _check(active_game_source.contains("if status == \"Available\":") and active_game_source.contains("survivor[\"fatigue\"] = maxf(0.0, float(survivor[\"fatigue\"]) - recovery.x * float(delta))") and active_game_source.contains("survivor[\"stress\"] = maxf(0.0, float(survivor[\"stress\"]) - recovery.y * float(delta))"), "available survivors recover fatigue and stress continuously while chilling in camp"): return
    var tarp_recovery := CampLifeRules.idle_recovery_rates(1, false, 0)
    var barracks_recovery := CampLifeRules.idle_recovery_rates(2, false, 1)
    var kitchen_recovery := CampLifeRules.idle_recovery_rates(2, false, 2)
    var brewery_recovery := CampLifeRules.idle_recovery_rates(2, false, 3)
    var dorm_recovery := CampLifeRules.idle_recovery_rates(3, false, 3)
    if not _check(tarp_recovery.y > base_recovery.y and barracks_recovery.x > tarp_recovery.x and kitchen_recovery.y > barracks_recovery.y and brewery_recovery.y > kitchen_recovery.y and dorm_recovery.x > brewery_recovery.x, "shelter and each tavern stage progressively improve recovery"): return
    var tavern_social_one := CampLifeRules.complete_activity({"fun":20,"safety":60}, 0.0, "tavern_social", 1)
    var tavern_social_three := CampLifeRules.complete_activity({"fun":20,"safety":60}, 0.0, "tavern_social", 3)
    if not _check(float(tavern_social_three["needs"]["fun"]) > float(tavern_social_one["needs"]["fun"]) and CampLifeRules.tavern_social_stress_relief(3, true) > CampLifeRules.tavern_social_stress_relief(1, false), "later tavern stages and beer provide stronger social mood recovery"): return
    if not _check(active_game_source.contains("resources[\"Beer\"] = int(resources.get(\"Beer\", 0)) - 1") and active_main_source.contains("\"Tavern\", \"Tavern Kitchen\", \"Tavern Brewery\""), "active runtime consumes beer socially and work board exposes the full tavern chain"): return
    if not _check(str(D.GEAR["Flashlight"].get("slot", "")) == "Secondary", "flashlight secondary"): return
    if not _check(TacticalTiles.item_region("Headlamp") >= 0, "atlas secondary item"): return
    if not _check(str(TacticalVisuals.weapon_visual("Pistol").get("kind", "")) == "pistol", "weapon visual catalog"): return
    if not _check(TacticalSound.display_label("gunshot") != "", "sound catalog"): return

    var path := "user://ff_architecture_smoke.json"
    var payload := {"save_schema": 8, "stat_model": THREE_STAT_MODEL, "virus_model": "zombie-virus-v1", "ok": true}
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