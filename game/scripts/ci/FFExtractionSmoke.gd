extends SceneTree

const Rules = preload("res://scripts/FFExtractionRules.gd")

func _initialize():
    call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
    if not ok:
        push_error("FIRST_FIRE_EXTRACTION_SMOKE_FAIL: " + label)
        quit(1)
    return ok

func _run():
    var Raid = load("res://scripts/FFCombatExtraction.gd")
    var game = root.get_node("Game")
    game.set_process(false)
    game.new_game()
    game.rng.seed = 42
    var survivor: Dictionary = game.survivors[0]
    var sid := int(survivor.id)
    var gun := "6-Shot Revolver"
    var empty := {"loaded": 0, "reserve": 2}
    var loaded := Rules.reload_state(gun, empty)
    if not _check(int(loaded.loaded) == 2 and int(loaded.reserve) == 0, "reload transfers only existing reserve"): return
    if not _check(Rules.reload_state(gun, {"loaded": 0, "reserve": 0}).loaded == 0, "empty reserve cannot create ammunition"): return
    if not _check(Rules.weapon_state("Utility Knife").is_empty(), "melee has no ammunition state"): return
    if not _check(Rules.extraction_progress(2.0, 0.1, false, true) == 0.0 and Rules.extraction_progress(2.0, 0.1, true, false) == 0.0, "leaving exit or missing escort resets hold"): return
    if not _check(game.start_expedition(sid, "Camp Perimeter"), "production gate launches raid"): return
    if not _check(game.current_combat.survivor_ids.size() == 1, "solo party"): return
    var data: Dictionary = game.current_combat.duplicate(true)
    data.kind = "ambush"
    data.erase("runtime")
    var raid = Raid.new()
    root.add_child(raid)
    raid.start_encounter(data)
    raid.set_process(false)
    var initial_tick := int(raid.tick)
    raid.advance_raid(0.5)
    if not _check(raid.tick == initial_tick, "raid begins paused"): return
    var camp_time := float(game.day_elapsed)
    var camp_resources: Dictionary = game.resources.duplicate(true)
    game.sim_paused = false
    game._process(10.0)
    if not _check(game.day_elapsed == camp_time and game.resources == camp_resources, "tactical boundary freezes camp even if pause toggles"): return
    game.sim_paused = true
    raid.raid_paused = false
    raid.walls.clear()
    raid.obstacles.clear()
    raid.doors.clear()
    raid.glass.clear()
    raid.barrels.clear()
    raid.player.pos = Vector2i(5, 6)
    raid.player.facing = Vector2i.RIGHT
    if not _check(not raid.zombies.is_empty(), "ambush supplies real infected"): return
    for z in raid.zombies:
        z.next = 100000
    raid.zombies[0].pos = Vector2i(6, 6)
    raid.zombies[0].next = 0
    raid.zombies[0].state = "CHASE"
    raid.advance_raid(0.05)
    if not _check(int(raid.zombies[0].next) > raid.tick and raid.tick > initial_tick, "infected acts without any player input"): return
    raid.recalc_visibility()
    var before_shot := int(raid.player.loaded)
    var shot_tick := int(raid.tick)
    raid._perform_action("fire")
    raid._perform_action("fire")
    if not _check(int(raid.player.loaded) == before_shot - 1 and raid.tick == shot_tick, "fire spends a round and cooldown rejects spam without advancing time"): return
    raid.zombies.clear()
    raid.action_ready_tick = raid.tick
    raid.movement_ready_tick = raid.tick
    var old_pos: Vector2i = raid.player.pos
    before_shot = int(raid.player.loaded)
    var move_touch := InputEventScreenTouch.new()
    move_touch.index = 0
    move_touch.pressed = true
    move_touch.position = Raid.RAID_UP.get_center()
    raid._input(move_touch)
    var fire_touch := InputEventScreenTouch.new()
    fire_touch.index = 1
    fire_touch.pressed = true
    fire_touch.position = Raid.RAID_FIRE.get_center()
    raid._input(fire_touch)
    raid.advance_raid(0.05)
    move_touch.pressed = false
    fire_touch.pressed = false
    raid._input(move_touch)
    raid._input(fire_touch)
    if not _check(raid.held_actions.is_empty(), "touch release clears held controls"): return
    if not _check(raid.player.pos == old_pos + Vector2i.UP and int(raid.player.loaded) == before_shot - 1, "two touch controls permit movement and fire together"): return
    var container: Vector2i = raid.player.pos + Vector2i.RIGHT
    raid.loot_containers = {container: "crate"}
    raid.container_contents = {container: {"Wood": 2}}
    raid.looted_containers.clear()
    raid.locked_containers.clear()
    raid.search_loot_container(container)
    if not _check(int(raid.collected_container_loot().get("Wood", 0)) == 2 and int(game.resources.Wood) == 0, "physical loot stays in raid before extraction"): return
    raid.held_actions = {0: "up"}
    raid._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    var focus_tick := int(raid.tick)
    raid.advance_raid(1.0)
    if not _check(raid.raid_paused and raid.held_actions.is_empty() and raid.tick == focus_tick, "focus loss pauses raid and releases held movement"): return
    var shots_before_resume := int(raid.stats.shots)
    raid.weapon_reserve = 1
    raid.extract_seconds = 1.25
    raid.persist_runtime()
    # Round-trip the actual disk/JSON save rather than just copying dictionaries.
    game.load_game()
    survivor = game.get_survivor(sid)
    if not _check(int(game.current_combat.runtime.weapon_reserve) == 1 and is_equal_approx(float(game.current_combat.runtime.extract_seconds), 1.25), "raid ammunition and extraction hold survive disk load"): return
    raid.stop_encounter()
    raid.free()
    raid = Raid.new()
    root.add_child(raid)
    raid.start_encounter(game.current_combat)
    raid.set_process(false)
    if not _check(raid.raid_paused and int(raid.player.loaded) == before_shot - 1 and raid.weapon_reserve == 1 and int(raid.stats.shots) == shots_before_resume and int(raid.collected_container_loot().get("Wood", 0)) == 2, "resume restores carried loot and finite ammunition while paused"): return
    raid.zombies.clear()
    raid.raid_paused = false
    raid.exit_cells = [raid.player.pos]
    raid.extract_seconds = 0.0
    raid.encounter_finished.connect(game.resolve_combat)
    for n in range(59): raid.advance_raid(0.05)
    if not _check(not raid.game_over and game.resources.Wood == 0, "cannot escape before full three-second hold"): return
    raid.advance_raid(0.05)
    raid.advance_raid(0.05)
    if not _check(raid.game_over and game.current_combat.is_empty() and game.resources.Wood == 0, "escape resolves raid but does not teleport loot into camp"): return
    var ammunition: Dictionary = survivor.equipment_state.Weapon.duplicate(true)
    if not _check(int(ammunition.reserve) == 1, "gun ammunition commits to persistent survivor equipment"): return
    game.resolve_event(0)
    if not _check(game.expeditions.size() == 1 and game.expeditions[0].state == "traveling", "acknowledged extraction begins ordinary Away timer"): return
    game._process_expeditions(1000.0)
    if not _check(game.resources.Wood == 2 and game.expeditions.is_empty(), "actual return deposits exact physical haul once"): return
    game._process_expeditions(1000.0)
    if not _check(game.resources.Wood == 2, "return cannot duplicate recovered loot"): return
    survivor.status = "Available"
    survivor.task = {}
    survivor.fatigue = 0.0
    survivor.condition = "Healthy"
    game.buildings.Workbench = true
    game.resources["Scrap Metal"] = 1
    if not _check(game.rearm_survivor(sid) and game.resources["Scrap Metal"] == 0 and survivor.equipment_state.Weapon == Rules.weapon_state(gun), "base resupply consumes recovered scrap and restores the carried gun"): return
    if not _check(not game.rearm_survivor(sid), "cannot rearm for free"): return
    # Swapping through communal storage must retain an empty weapon's state.
    survivor.equipment_state.Weapon = {"loaded": 0, "reserve": 0, "needs_pump": false}
    game.inventory_gear.append("Utility Knife")
    game.equip_gear(sid, "Utility Knife")
    game.equip_gear(sid, gun)
    if not _check(int(survivor.equipment_state.Weapon.loaded) == 0 and int(survivor.equipment_state.Weapon.reserve) == 0, "stash swap cannot refill an empty gun"): return
    survivor.equipment.Secondary = "Flashlight"
    survivor.equipment_state.Secondary = {"charge": 100.0}
    if not _check(game.start_expedition(sid, "Camp Perimeter"), "second raid launches from returned survivor"): return
    raid.stop_encounter()
    raid.start_encounter(game.current_combat)
    if not _check(raid.player.loaded == 0 and raid.weapon_reserve == 0, "new raid cannot refill ammunition"): return
    raid.player.hp = 0
    raid.raid_paused = false
    raid.advance_raid(0.05)
    if not _check(survivor.condition == "Dead" and str(survivor.equipment.get("Weapon", "")) == "" and survivor.equipment_state.is_empty() and game.expeditions.is_empty(), "raid death permanently loses survivor and equipped kit"): return
    raid.free()
    print("FIRST_FIRE_EXTRACTION_SMOKE_OK")
    quit(0)
