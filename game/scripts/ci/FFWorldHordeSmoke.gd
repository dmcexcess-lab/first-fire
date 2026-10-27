extends SceneTree

const World = preload("res://scripts/FFProceduralWorld.gd")
const Horde = preload("res://scripts/FFHordeTurn.gd")
const TimeRules = preload("res://scripts/FFTacticalTime.gd")
const Life = preload("res://scripts/FFCampLifeRules.gd")
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

func _initialize():
    call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
    if not ok:
        push_error("FIRST_FIRE_WORLD_HORDE_SMOKE_FAIL: " + message)
        quit(1)
    return ok

func _run():
    for seed_value in range(1, 9):
        var counts: Array = []
        for map_type in World.TYPES:
            var spec: Dictionary = World.build(seed_value, map_type)
            if not _check(spec == World.build(seed_value, map_type), "same seed and biome rebuild the same raid"): return
            if not _check(spec != World.build(seed_value + 100, map_type), "new seed changes geography and exits"): return
            if not _check(int(spec.width) >= 80 and int(spec.height) >= 72 and spec.exit_cells.size() >= 4 and spec.exit_cells.size() <= 7, "large maps have multiple random exfils"): return
            var blocked := {}
            for cell in spec.walls + spec.obstacles: blocked[cell] = true
            var reachable := {spec.player_spawn: true}
            var queue: Array = [spec.player_spawn]
            var cursor := 0
            while cursor < queue.size():
                var cell: Vector2i = queue[cursor]
                cursor += 1
                for direction in DIRS:
                    var next: Vector2i = cell + direction
                    if next.x <= 0 or next.y <= 0 or next.x >= int(spec.width) - 1 or next.y >= int(spec.height) - 1 or blocked.has(next) or reachable.has(next): continue
                    reachable[next] = true
                    queue.append(next)
            var unique_exits := {}
            for cell in spec.exit_cells:
                if not _check(reachable.has(cell) and not unique_exits.has(cell), "each random exit has a physical reachable path"): return
                unique_exits[cell] = true
            counts.append(int(spec.population))
        if not _check(counts[0] < counts[1] and counts[1] < counts[2], "map type determines increasing zombie density"): return
    var positions := {0: Vector2i(1, 1), 1: Vector2i(2, 1)}
    var convoy := Horde.resolve_moves(positions, {0: Vector2i(2, 1), 1: Vector2i(3, 1)}, 0)
    if not _check(convoy.size() == 2, "a horde can advance together into vacated cells"): return
    if not _check(Horde.resolve_moves(positions, {0: Vector2i(2, 1)}, 0).is_empty(), "stationary infected block a convoy"): return
    if not _check(Horde.resolve_moves(positions, {0: Vector2i(2, 1), 1: Vector2i(1, 1)}, 0).is_empty(), "head-on swaps cannot cross bodies"): return
    positions = {0: Vector2i(1, 1), 1: Vector2i(3, 1)}
    var choices := {0: Vector2i(2, 1), 1: Vector2i(2, 1)}
    if not _check(Horde.resolve_moves(positions, choices, 0).size() == 1 and Horde.resolve_moves(positions, choices, 0) != Horde.resolve_moves(positions, choices, 1), "contention has one winner and rotating priority"): return
    var reversed := {1: positions[1], 0: positions[0]}
    if not _check(Horde.resolve_moves(reversed, choices, 0) == Horde.resolve_moves(positions, choices, 0), "dictionary iteration order does not change simultaneous motion"): return
    var random := RandomNumberGenerator.new()
    for family in ["heavy", "worker", "decayed", "civilian", "medical"]:
        if not _check(TimeRules.zombie_profile(random, {"family":family}) == {"pace":125, "attack_cost":135, "mass":"MED"}, "all zombie appearances share one physical profile"): return
    var game = root.get_node("Game")
    game.set_process(false)
    game.new_game()
    game.rng.seed = 31
    var founder: Dictionary = game.survivors[0]
    game.buildings["Large Tarp"] = true
    game.resources.Wood = 5
    founder.leader_ability = "Organizer"
    game.leader_id = int(founder.id)
    game.leadership_form = "Elected Leader"
    game.current_event = game._event_base("politics_coordinator", "Old vote", "", [])
    game._kill_survivor(founder, "was lost in the field")
    if not _check(game.current_event.is_empty(), "an obsolete resident vote cannot block an empty camp"): return
    if not _check(game.population() == 0 and not game.game_over and game.leader_id == -1 and game.buildings["Large Tarp"] and game.resources.Wood == 5, "the camp survives its final resident and keeps infrastructure and stores"): return
    game.sim_paused = false
    var clock := float(game.day_elapsed)
    game._advance_settlement_simulation(5.0)
    if not _check(float(game.day_elapsed) > clock and game.population() == 0, "empty camp time advances without an instant replacement"): return
    # Saved terminal states from the previous rule are safely resumable.
    game.game_over = true
    game.current_event = game._event_base("game_over", "Old ending", "", [])
    game.save_game()
    game.load_game()
    if not _check(not game.game_over and game.current_event.is_empty() and game.population() == 0 and game.resources.Wood == 5, "empty camp save loads without an obsolete game-over event"): return
    var low := Life.empty_camp_arrival_chance(Life.empty_camp_attraction(0.0, 0.0, 0))
    var high := Life.empty_camp_arrival_chance(Life.empty_camp_attraction(100.0, 100.0, 15))
    if not _check(low > 0.0 and high > low, "nicer empty camps attract arrivals faster and neglected camps can recover"): return
    game.current_event = {}
    game.event_queue.clear()
    game.camp_event_cooldown = 0.0
    game.flags["camp_story_recruit_cooldown_until_time"] = 0.0
    for _i in range(100):
        game._consider_camp_event()
        if not game.current_event.is_empty(): break
    if not _check(str(game.current_event.get("key", "")) == "camp_arrival" and game.population() == 0, "empty camp produces an arrival offer through the normal event queue"): return
    game.resolve_event(0)
    if not _check(game.population() == 1 and game.resources.Wood == 5 and game.buildings["Large Tarp"], "accepting the next camper resettles existing camp"): return
    # Real production horde phase: two adjacent infected move in the same beat,
    # interpolate together, and player input cannot begin another turn mid-phase.
    game.new_game()
    founder = game.survivors[0]
    founder.leader_ability = "Provider"
    game.leader_id = int(founder.id)
    if not _check(game.start_expedition(int(founder.id), "Camp Perimeter", -1, "city") and bool(game.current_combat.provider_bonus), "leader perk is carried into physical raid supplies"): return
    var Raid = load("res://scripts/FFCombatTurn.gd")
    var raid = Raid.new()
    root.add_child(raid)
    raid.start_encounter(game.current_combat)
    raid.set_process(false)
    raid.raid_paused = false
    raid.animate_horde = true
    raid.player.pos = Vector2i(40, raid.H - 4)
    for enemy in raid.zombies: enemy.dead = true
    for x in range(38, 49):
        var cell := Vector2i(x, raid.player.pos.y)
        raid.walls.erase(cell)
        raid.obstacles.erase(cell)
        raid.glass.erase(cell)
        raid.doors.erase(cell)
    for i in range(2):
        var enemy: Dictionary = raid.zombies[i]
        enemy.dead = false
        enemy.pos = raid.player.pos + Vector2i(4 + i, 0)
        enemy.heard = raid.player.pos
        enemy.target = raid.player.pos
        enemy.state = "CHASE"
        enemy.facing = Vector2i.LEFT
        enemy.next = 0
    raid.recalc_visibility()
    var first: Vector2i = raid.zombies[0].pos
    var second: Vector2i = raid.zombies[1].pos
    raid._end_turn()
    if not _check(raid.turn_processing and raid.horde_frames.size() == 3 and raid.horde_frames[1][0] == first + Vector2i.LEFT and raid.horde_frames[1][1] == second + Vector2i.LEFT, "existing infected move together from one occupancy snapshot"): return
    var phase_tick := int(raid.tick)
    raid._end_turn()
    if not _check(int(raid.tick) == phase_tick, "input cannot advance an overlapping zombie phase"): return
    raid._process(0.05)
    var draw_center: Vector2 = raid.zombie_draw_center(0)
    if not _check(draw_center.x < raid.cell_center(first).x and draw_center.x > raid.cell_center(first + Vector2i.LEFT).x, "zombie movement is visibly interpolated"): return
    for _i in range(15): raid._process(0.05)
    if not _check(not raid.turn_processing and raid.horde_frames.is_empty(), "shared movement animation completes before player control returns"): return
    for enemy in raid.zombies: enemy.dead = true
    raid.exit_cells = [raid.player.pos]
    raid.action_points = 2
    raid._begin_extract()
    if not _check(raid.phase_outcome == "escaped" and not raid.game_over, "extraction waits for zombie-phase presentation"): return
    game.load_game()
    raid.stop_encounter()
    raid.free()
    raid = Raid.new()
    root.add_child(raid)
    raid.start_encounter(game.current_combat)
    raid.set_process(false)
    raid.encounter_finished.connect(game.resolve_combat)
    if not _check(raid.raid_paused and raid.phase_outcome == "escaped", "reload preserves a resolved extraction without rerolling enemies"): return
    raid.raid_paused = false
    raid._process(0.05)
    if not _check(game.current_combat.is_empty() and raid.game_over, "resumed resolved extraction finishes exactly once"): return
    raid.free()
    print("FIRST_FIRE_WORLD_HORDE_SMOKE_OK")
    quit(0)
