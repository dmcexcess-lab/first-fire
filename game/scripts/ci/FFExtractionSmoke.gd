extends SceneTree

const Rules = preload("res://scripts/FFExtractionRules.gd")
const TurnRules = preload("res://scripts/FFTurnRules.gd")
const World = preload("res://scripts/FFTacticalWorld.gd")
const Balance = preload("res://scripts/FFTacticalBalance.gd")

func _initialize():
    call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
    if not ok:
        push_error("FIRST_FIRE_EXTRACTION_SMOKE_FAIL: " + label)
        quit(1)
    return ok

func _run():
    var Raid = load("res://scripts/FFCombatTurn.gd")
    var game = root.get_node("Game")
    game.set_process(false)
    game.new_game()
    game.rng.seed = 42
    var survivor: Dictionary = game.survivors[0]
    var sid := int(survivor.id)
    var gun := "6-Shot Revolver"
    if not _check(Rules.reload_state(gun, {"loaded": 0, "reserve": 2}).loaded == 2 and Rules.reload_state(gun, {"loaded": 0, "reserve": 0}).loaded == 0, "finite reload transfers only available ammunition"): return
    if not _check(TurnRules.movement_range("walk") == 5 and TurnRules.movement_range("crouch") == 3 and TurnRules.movement_range("sprint") == 8 and TurnRules.movement_cost("sprint") == 2, "movement modes use the designed ranges and AP"): return
    if not _check(game.start_expedition(sid, "Camp Perimeter") and game.current_combat.survivor_ids.size() == 1, "production gate starts one survivor"): return
    var raid = Raid.new()
    root.add_child(raid)
    raid.start_encounter(game.current_combat)
    raid.set_process(false)
    if not _check(raid.raid_paused and raid.action_points == 2 and raid.player.pos == Vector2i(29, 51) and raid.exit_cells.size() == 4, "paused start, two AP, connected neighborhood and exits"): return
    if not _check(int(raid.player.loaded) == 6 and raid.weapon_reserve == 12, "starter firearm starts with its loaded and spare ammunition"): return
    var civilian: Dictionary = survivor.duplicate(true)
    civilian.equipment["Weapon"] = ""
    raid.make_actor(civilian, Vector2i(3, 3), false)
    if not _check(raid.weapon_reserve == 12, "unarmed rescue or companion cannot erase lead ammunition"): return
    var reachable: Dictionary = raid._reachable_distances(raid.player.pos)
    for cell in raid.exit_cells:
        if not _check(reachable.has(cell), "each exit has a physical route from entry"): return
    var depth_counts := [0, 0, 0]
    for z in raid.zombies: depth_counts[World.depth(z.pos)] += 1
    if not _check(depth_counts[0] >= 5 and depth_counts[1] >= 10 and depth_counts[2] >= 15, "existing zombie population increases with depth"): return
    var start_tick := int(raid.tick)
    var camp_time := float(game.day_elapsed)
    var camp_resources: Dictionary = game.resources.duplicate(true)
    game.sim_paused = false
    game._process(5.0)
    raid._process(5.0)
    if not _check(game.day_elapsed == camp_time and game.resources == camp_resources and raid.tick == start_tick, "camp and enemies do not advance while planning"): return
    game.sim_paused = true
    raid.raid_paused = false
    var start_pos: Vector2i = raid.player.pos
    var destination := Vector2i(-1, -1)
    for d in raid.DIRS:
        var candidate: Vector2i = start_pos + d
        if not raid.blocked(candidate) and raid.visible_cells.has(candidate) and raid.zombie_at(candidate) < 0:
            destination = candidate
            break
    if not _check(destination != Vector2i(-1, -1), "entry has a reachable known neighboring tile"): return
    raid._preview_cell(destination)
    if not _check(raid._preview_noise() == 18, "walking noise preview matches actual footstep volume"): return
    var preview_mode: String = raid.move_mode
    raid.move_mode = "sprint"
    if not _check(raid._preview_noise() == raid.ThreeStatRules.sprint_noise(int(raid.player.skills.get("Agility", 0))), "sprint noise preview matches actual sound"): return
    raid.move_mode = preview_mode
    if not _check(raid.pending_kind == "move" and raid.action_points == 2 and raid.player.pos == start_pos, "preview is free and does not move survivor"): return
    raid._confirm_preview()
    if not _check(raid.player.pos == destination and raid.action_points == 1 and raid.tick == start_tick, "movement costs one AP without an enemy turn"): return
    var old_turn := int(raid.turn_number)
    raid._end_turn()
    if not _check(raid.turn_number == old_turn + 1 and raid.action_points == 2 and raid.tick == start_tick + 100, "ending turn advances enemies and replenishes AP"): return
    var count: int = raid.zombies.size()
    var z: Dictionary = raid.zombies[0]
    var source: Vector2i = raid.player.pos
    z.pos = source + Vector2i(4, 0)
    z.state = "IDLE"
    z.heard = Vector2i(-1, -1)
    for x in range(source.x, source.x + 5): raid.walls.erase(Vector2i(x, source.y))
    raid.emit_noise(source, 6, "quiet", true)
    if not _check(z.state == "IDLE", "quiet sound does not alert a distant zombie"): return
    raid.emit_noise(source, 72, "gunshot", true)
    if not _check(z.state == "INVESTIGATE" and z.heard != Vector2i(-1, -1) and raid.zombies.size() == count, "gunshot attracts an existing zombie without spawning a horde"): return
    for enemy in raid.zombies: enemy.dead = true
    z.dead = false
    z.next = 0
    z.state = "INVESTIGATE"
    z.heard = source
    for x in range(source.x, source.x + 5):
        raid.obstacles.erase(Vector2i(x, source.y))
        raid.doors.erase(Vector2i(x, source.y))
        raid.glass.erase(Vector2i(x, source.y))
    var zombie_before: Vector2i = z.pos
    raid._end_turn()
    if not _check(z.pos != zombie_before and raid.zombies.size() == count, "an alerted existing zombie actually moves on the zombie phase"): return
    z.dead = true
    # Unlocking consumes one action; opening is a separate action.
    var lock_cell: Vector2i = raid.player.pos + Vector2i.UP
    raid.loot_containers = {lock_cell: "crate"}
    raid.container_contents = {lock_cell: {"Wood": 1}}
    raid.locked_containers = {lock_cell: true}
    raid.player.secondary = "Lock Pick"
    raid.player.secondary_state = {"uses_left": 2}
    raid.action_points = 2
    raid.search_loot_container(lock_cell)
    if not _check(raid.action_points == 1 and not raid.locked_containers.has(lock_cell) and not raid.looted_containers.has(lock_cell), "unlock is one AP and does not automatically search"): return
    raid.search_loot_container(lock_cell)
    if not _check(raid.action_points == 2 and raid.looted_containers.has(lock_cell), "separate search uses the remaining AP and advances the zombie phase"): return
    raid.player.secondary = ""
    raid.player.secondary_state = {}
    # Searches keep excess loot available for a deliberate one-AP swap.
    var near: Vector2i = raid.player.pos + Vector2i.RIGHT
    var second: Vector2i = raid.player.pos + Vector2i.LEFT
    raid.loot_containers = {near: "crate", second: "crate"}
    raid.container_contents = {near: {"Wood": 4}, second: {"Cloth": 2}}
    raid.looted_containers.clear()
    raid.locked_containers.clear()
    raid.action_points = 2
    raid.search_loot_container(near)
    raid.search_loot_container(second)
    if not _check(raid.carried_loot_count() == 4 and raid.leftovers.has(second) and int(raid.leftovers[second].Cloth) == 2 and game.resources.Wood == 0, "full pack leaves physical loot available without depositing it at camp"): return
    raid.swap_cell = second
    raid.swap_take = "Cloth"
    raid._complete_swap("Wood")
    var carried: Dictionary = raid.collected_container_loot()
    if not _check(int(carried.get("Wood", 0)) == 3 and int(carried.get("Cloth", 0)) == 1 and int(raid.leftovers[second].Wood) == 1 and raid.action_points == 1, "one-AP swap exchanges a carried item for leftover loot"): return
    raid.discovered_exits[raid.exit_cells[1]] = true
    raid.weapon_reserve = 1
    raid.persist_runtime()
    game.load_game()
    survivor = game.get_survivor(sid)
    raid.stop_encounter()
    raid.free()
    raid = Raid.new()
    root.add_child(raid)
    raid.start_encounter(game.current_combat)
    raid.set_process(false)
    if not _check(raid.raid_paused and raid.action_points == 1 and raid.weapon_reserve == 1 and raid.discovered_exits.size() >= 2 and int(raid.leftovers[second].Wood) == 1 and raid.collected_container_loot() == carried, "disk load restores AP, ammo, map knowledge, leftover and carried loot"): return
    raid.raid_paused = false
    raid.action_points = 2
    raid.exit_cells = [raid.player.pos]
    raid.encounter_finished.connect(game.resolve_combat)
    # Choose a seeded adjacent zombie attack that is guaranteed to hit.
    for enemy in raid.zombies: enemy.dead = true
    var attacker: Dictionary = raid.zombies[0]
    attacker.dead = false
    attacker.pos = raid.player.pos + Vector2i.RIGHT
    attacker.facing = Vector2i.LEFT
    attacker.state = "CHASE"
    attacker.next = 0
    raid.walls.erase(attacker.pos)
    raid.obstacles.erase(attacker.pos)
    raid.doors.erase(attacker.pos)
    var seed_value := -1
    for candidate_seed in range(1, 1000):
        var trial := RandomNumberGenerator.new()
        trial.seed = candidate_seed
        var kind := Balance.zombie_attack_kind(trial)
        if trial.randf() <= Balance.zombie_attack_hit_chance(raid.player, kind, 1):
            seed_value = candidate_seed
            break
    if not _check(seed_value > 0, "find deterministic hit seed"): return
    raid.rng.seed = seed_value
    var hp := int(raid.player.hp)
    raid._begin_extract()
    if not _check(not raid.game_over and int(raid.player.hp) < hp and raid.action_points == 2 and not raid.pending_extract, "a hit during extraction interrupts it"): return
    attacker.dead = true
    raid._begin_extract()
    if not _check(raid.game_over and game.current_combat.is_empty() and game.resources.Wood == 0, "successful extraction retains loot for the journey, not immediate deposit"): return
    if not _check(int(survivor.equipment_state.Weapon.reserve) == 1, "remaining ammunition persists on equipped weapon"): return
    game.resolve_event(0)
    if not _check(game.expeditions.size() == 1 and game.expeditions[0].state == "traveling", "result begins Away timer"): return
    game._process_expeditions(1000.0)
    if not _check(int(game.resources.Wood) == 3 and int(game.resources.Cloth) == 1 and game.expeditions.is_empty(), "exact swapped physical haul reaches camp once"): return
    game._process_expeditions(1000.0)
    if not _check(int(game.resources.Wood) == 3 and int(game.resources.Cloth) == 1, "return cannot duplicate loot"): return
    survivor.status = "Available"
    survivor.task = {}
    survivor.fatigue = 0.0
    survivor.condition = "Healthy"
    game.buildings.Workbench = true
    game.resources["Scrap Metal"] = 1
    if not _check(game.rearm_survivor(sid) and game.resources["Scrap Metal"] == 0, "Workbench resupply costs recovered scrap"): return
    survivor.equipment_state.Weapon = {"loaded": 0, "reserve": 0, "needs_pump": false}
    game.inventory_gear.append("Utility Knife")
    game.equip_gear(sid, "Utility Knife")
    game.equip_gear(sid, gun)
    if not _check(int(survivor.equipment_state.Weapon.loaded) == 0 and int(survivor.equipment_state.Weapon.reserve) == 0, "stash swap cannot refill an empty gun"): return
    survivor.equipment.Secondary = "Flashlight"
    survivor.equipment_state.Secondary = {"charge": 100.0}
    if not _check(game.start_expedition(sid, "Camp Perimeter"), "second raid launches"): return
    raid.stop_encounter()
    raid.start_encounter(game.current_combat)
    if not _check(raid.player.loaded == 0 and raid.weapon_reserve == 0, "empty weapon remains empty on next raid"): return
    raid.player.hp = 0
    raid.raid_paused = false
    raid._end_turn()
    if not _check(survivor.condition == "Dead" and str(survivor.equipment.get("Weapon", "")) == "" and survivor.equipment_state.is_empty() and game.expeditions.is_empty(), "death permanently loses survivor and equipped kit"): return
    raid.free()
    # Named Explore gear must occupy one of the same finite carry slots and
    # stay in the container when the pack is full.
    game.new_game()
    var fresh_sid := int(game.survivors[0].id)
    if not _check(game.start_expedition(fresh_sid, "Camp Perimeter"), "gear-capacity fixture launches"): return
    raid = Raid.new()
    root.add_child(raid)
    raid.start_encounter(game.current_combat)
    raid.set_process(false)
    raid.raid_paused = false
    for enemy in raid.zombies: enemy.dead = true
    raid.context.kind = "explore"
    raid.context.field_gear = "Hiking Pack"
    var wood_cell: Vector2i = raid.player.pos + Vector2i.RIGHT
    var gear_cell: Vector2i = raid.player.pos + Vector2i.LEFT
    raid.loot_containers = {wood_cell: "crate", gear_cell: "crate"}
    raid.container_contents = {wood_cell: {"Wood": 4}, gear_cell: {}}
    raid.looted_containers.clear()
    raid.locked_containers.clear()
    raid.explore_cells = [gear_cell]
    raid.explore_gear_cell = gear_cell
    raid.objective_done = false
    raid.action_points = 2
    raid.search_loot_container(wood_cell)
    raid.search_loot_container(gear_cell)
    if not _check(raid.carried_loot_count() == 4 and not raid.field_gear_carried and not raid.objective_done and int(raid.leftovers[gear_cell]["Hiking Pack"]) == 1, "full pack cannot acquire marked gear for free"): return
    raid.swap_cell = gear_cell
    raid.swap_take = "Hiking Pack"
    raid._complete_swap("Wood")
    if not _check(raid.carried_loot_count() == 4 and raid.field_gear_carried and raid.objective_done and int(raid.collected_container_loot().Wood) == 3, "swapping for marked gear consumes exactly one carry slot"): return
    raid.stop_encounter()
    raid.free()
    # A schema-8 real-time encounter must remain on its original map across
    # repeated resume cycles, with lead health and ammo intact.
    game.new_game()
    fresh_sid = int(game.survivors[0].id)
    if not _check(game.start_expedition(fresh_sid, "Camp Perimeter"), "legacy fixture launches"): return
    var OldRaid = load("res://scripts/FFCombatExtraction.gd")
    var old_raid = OldRaid.new()
    root.add_child(old_raid)
    old_raid.start_encounter(game.current_combat)
    old_raid.player.hp = 11
    old_raid.weapon_reserve = 4
    old_raid.persist_runtime()
    var old_position: Vector2i = old_raid.player.pos
    var old_count: int = old_raid.zombies.size()
    old_raid.stop_encounter()
    old_raid.free()
    raid = Raid.new()
    root.add_child(raid)
    raid.start_encounter(game.current_combat)
    raid.set_process(false)
    if not _check(raid.legacy_raid and raid.player.pos == old_position and raid.player.hp == 11 and raid.weapon_reserve == 4 and raid.zombies.size() == old_count, "legacy real-time encounter resumes as a turn-based encounter without losing state"): return
    raid.persist_runtime()
    game.load_game()
    raid.stop_encounter()
    raid.free()
    raid = Raid.new()
    root.add_child(raid)
    raid.start_encounter(game.current_combat)
    if not _check(raid.legacy_raid and raid.player.pos == old_position and raid.player.hp == 11 and raid.weapon_reserve == 4 and raid.zombies.size() == old_count, "legacy map remains stable after another save and resume"): return
    raid.stop_encounter()
    raid.free()
    print("FIRST_FIRE_EXTRACTION_SMOKE_OK")
    quit(0)
