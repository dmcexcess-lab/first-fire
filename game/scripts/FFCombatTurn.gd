extends "res://scripts/FFCombatExtraction.gd"

const World = preload("res://scripts/FFTacticalWorld.gd")
const Procedural = preload("res://scripts/FFProceduralWorld.gd")
const HordeTurn = preload("res://scripts/FFHordeTurn.gd")
const TURN_RULES = preload("res://scripts/FFTurnRules.gd")
const BTN_WALK := Rect2(8, 652, 118, 50)
const BTN_CROUCH := Rect2(136, 652, 118, 50)
const BTN_SPRINT := Rect2(264, 652, 118, 50)
const BTN_USE := Rect2(8, 706, 118, 50)
const BTN_RELOAD := Rect2(136, 706, 118, 50)
const BTN_TOOL := Rect2(264, 706, 118, 50)
const BTN_SHOVE := Rect2(8, 760, 118, 64)
const BTN_EXTRACT := Rect2(136, 760, 118, 64)
const BTN_END := Rect2(264, 760, 118, 64)
const BTN_CENTER := Rect2(282, 107, 48, 34)
const BTN_ZOOM := Rect2(334, 107, 48, 34)

var action_points := 2
var turn_number := 1
var move_mode := "walk"
var pending_extract := false
var moving_path := false
var deferred_action := false
var field_gear_carried := false
var pending_cell := Vector2i(-1, -1)
var pending_kind := ""
var pending_path: Array = []
var discovered_exits := {}
var camera_offset := Vector2.ZERO
var drag_start := Vector2.ZERO
var drag_last := Vector2.ZERO
var dragging := false
var pointer_down := false
var legacy_raid := false
var turn_processing := false
var map_zoom := 1.0
var leftovers := {}
var swap_cell := Vector2i(-1, -1)
var swap_take := ""
var generated_world := {}
var horde_frames: Array = []
var horde_attacks := {}
var horde_visual_time := 0.0
var phase_outcome := ""
var animate_horde := true
var horde_flow_cache := {}

func start_encounter(data: Dictionary):
    var old_runtime: Dictionary = data.get("runtime", {})
    legacy_raid = str(old_runtime.get("raid_model", "")) == "extraction-v1" or str(old_runtime.get("world_layout", "")) == "legacy"
    animate_horde = DisplayServer.get_name() != "headless"
    generated_world.clear()
    horde_frames.clear()
    horde_attacks.clear()
    horde_visual_time = 0.0
    phase_outcome = ""
    action_points = 2
    turn_number = 1
    move_mode = "walk"
    pending_extract = false
    field_gear_carried = false
    turn_processing = false
    camera_offset = Vector2.ZERO
    discovered_exits.clear()
    leftovers.clear()
    swap_cell = Vector2i(-1, -1)
    swap_take = ""
    map_zoom = 1.0
    _clear_preview()
    super.start_encounter(data)
    raid_paused = true
    if legacy_raid:
        for cell in exit_cells: discovered_exits[cell] = true
    elif _is_procedural():
        # Initial intel identifies two random exits nearest the insertion.
        var by_distance: Array = exit_cells.duplicate()
        by_distance.sort_custom(func(a, b): return manhattan(a, player_spawn) < manhattan(b, player_spawn))
        for cell in by_distance.slice(0, 2): discovered_exits[cell] = true
    elif str(context.get("entry_route_id", "")) != "":
        for route in World.known_routes(Game.flags.get("discovered_raid_routes", [])):
            if exit_cells.has(route.cell): discovered_exits[route.cell] = true
    elif not exit_cells.is_empty():
        discovered_exits[exit_cells[0]] = true
    _discover_exits()
    turn_processing = phase_outcome != ""
    msg = "Tap a destination or target twice. END TURN moves the horde."
    persist_runtime()

func _is_procedural() -> bool:
    return not legacy_raid and str(context.get("world_model", "")) == "procedural-v1"

func _world_depth(cell: Vector2i) -> int:
    return Procedural.depth(cell, player_spawn, W, H) if _is_procedural() else World.depth(cell)

func tactical_layout(location: String, variant: int) -> Dictionary:
    if _is_procedural():
        generated_world = Procedural.build(int(context.get("seed", 1)), str(context.get("map_type", "suburbs")))
        return generated_world
    if legacy_raid:
        return TacticalEnvironments.build_layout(location, variant)
    return World.build(int(context.get("seed", 1)), str(context.get("entry_route_id", "")))

func build_map(location: String, variant: int):
    super.build_map(location, variant)
    if legacy_raid:
        for x in range(TacticalEnvironments.BOARD_W): walls[Vector2i(x, TacticalEnvironments.BOARD_H - 1)] = true
        for y in range(TacticalEnvironments.BOARD_H): walls[Vector2i(TacticalEnvironments.BOARD_W - 1, y)] = true

func supplement_distance_loot_containers() -> void:
    if legacy_raid:
        super.supplement_distance_loot_containers()
        return
    # Keep a modest randomized set in each depth band, instead of applying
    # one small-map quota to the whole connected neighborhood.
    for depth in range(3):
        var cells: Array = []
        for cell in loot_containers.keys():
            if _world_depth(cell) == depth: cells.append(cell)
        var wanted := mini(cells.size(), ([8, 12, 18] if _is_procedural() else [5, 8, 12])[depth])
        while cells.size() > wanted:
            var index := rng.randi_range(0, cells.size() - 1)
            var removed: Vector2i = cells.pop_at(index)
            loot_containers.erase(removed)
            container_contents.erase(removed)
        # Deeper blocks use the existing richer zone loot tables.
        var zones := ["Camp Perimeter", "Residential Blocks", "Industrial Edge"]
        for cell in cells:
            container_contents[cell] = TacticalBalance.roll_container_loot(zones[depth], str(loot_containers[cell]), rng, int(context.get("zone_pressure", 0)))
            if _is_procedural() and bool(context.get("provider_bonus", false)) and not container_contents[cell].is_empty() and rng.randf() < 0.15:
                var item: String = str(container_contents[cell].keys()[0])
                container_contents[cell][item] += 1

func spawn_zombies():
    if _is_procedural():
        _spawn_procedural_zombies()
        return
    super.spawn_zombies()
    var saved: Array = runtime.get("zombies", [])
    var desired := saved.size() if legacy_raid and runtime.has("zombies") else -1
    if desired >= 0:
        while zombies.size() > desired: zombies.pop_back()
        while zombies.size() < desired: _append_zombie(player_spawn + Vector2i(2, 0))
        return
    # Place a few local infected for stealth, plus small pre-existing groups
    # across each depth. Groups are never spawned by the noise director.
    var nearby: Array = []
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            var cell := Vector2i(x, y)
            var distance := manhattan(cell, player_spawn)
            if distance < 6 or distance > 9 or blocked(cell) or zombie_at(cell) >= 0 or rescuee_at(cell) or exit_cells.has(cell): continue
            nearby.append(cell)
    for i in range(mini(3, nearby.size())):
        var index := rng.randi_range(0, nearby.size() - 1)
        _append_zombie(nearby.pop_at(index))
    for depth in range(3):
        var candidates: Array = []
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                var cell := Vector2i(x, y)
                if World.depth(cell) != depth or blocked(cell) or manhattan(cell, player_spawn) < 10 or zombie_at(cell) >= 0 or rescuee_at(cell) or exit_cells.has(cell): continue
                candidates.append(cell)
        var count: int = [5, 10, 15][depth]
        var anchor := Vector2i(-1, -1)
        for i in range(mini(count, candidates.size())):
            if i % 5 == 0:
                anchor = candidates[rng.randi_range(0, candidates.size() - 1)]
            var cluster: Array = []
            for candidate in candidates:
                if manhattan(candidate, anchor) <= 4: cluster.append(candidate)
            var cell: Vector2i = cluster[rng.randi_range(0, cluster.size() - 1)] if not cluster.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]
            candidates.erase(cell)
            _append_zombie(cell)
    # Existing raids may have been saved before the population tuning changed.
    if runtime.has("zombies"):
        while zombies.size() > saved.size(): zombies.pop_back()
        while zombies.size() < saved.size(): _append_zombie(player_spawn + Vector2i(2, 0))

func _spawn_procedural_zombies() -> void:
    zombies.clear()
    var bands: Array = [[], [], []]
    var local: Array = []
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            var cell := Vector2i(x, y)
            if blocked(cell) or exit_cells.has(cell) or rescuee_at(cell): continue
            var distance := manhattan(player_spawn, cell)
            if distance >= 6 and distance <= 9: local.append(cell)
            elif distance >= 10: bands[_world_depth(cell)].append(cell)
    for _i in range(mini(3, local.size())):
        _append_zombie(local.pop_at(rng.randi_range(0, local.size() - 1)))
    var target := int(generated_world.get("population", 64))
    for depth in range(3):
        var candidates: Array = bands[depth]
        var count := int(float(target) * [0.2, 0.3, 0.5][depth])
        var anchor := Vector2i.ZERO
        for i in range(mini(count, candidates.size())):
            if i % 5 == 0: anchor = candidates[rng.randi_range(0, candidates.size() - 1)]
            var cluster: Array = []
            for cell in candidates:
                if manhattan(cell, anchor) <= 4: cluster.append(cell)
            var chosen: Vector2i = cluster[rng.randi_range(0, cluster.size() - 1)] if not cluster.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]
            candidates.erase(chosen)
            _append_zombie(chosen)
    if runtime.has("zombies"):
        var saved: Array = runtime.zombies
        while zombies.size() > saved.size(): zombies.pop_back()
        while zombies.size() < saved.size(): _append_zombie(player_spawn + Vector2i.UP)

func _append_zombie(cell: Vector2i) -> void:
    var look: Dictionary = TacticalVisuals.zombie_appearance(rng, str(context.get("zone", "Nearby Streets")))
    var timing: Dictionary = TacticalTime.zombie_profile(rng, look)
    var mass := str(timing.get("mass", "MED"))
    var hp_range := TacticalBalance.zombie_hp_range(mass)
    zombies.append({"id": zombies.size(), "pos": cell, "facing": DIRS[rng.randi_range(0, 3)], "hp": rng.randi_range(hp_range.x, hp_range.y), "state": "IDLE", "target": Vector2i(-1, -1), "heard": Vector2i(-1, -1), "pace": int(timing.get("pace", 125)), "attack_cost": int(timing.get("attack_cost", 135)), "mass": mass, "next": 0, "dead": false, "harvested": false, "look": look})

func restore_runtime():
    super.restore_runtime()
    action_points = clampi(int(runtime.get("action_points", 2)), 0, 2)
    turn_number = maxi(1, int(runtime.get("turn_number", 1)))
    move_mode = str(runtime.get("move_mode", "walk"))
    pending_extract = bool(runtime.get("pending_extract", false))
    phase_outcome = str(runtime.get("phase_outcome", ""))
    field_gear_carried = bool(runtime.get("field_gear_carried", bool(runtime.get("objective_done", false)) and str(context.get("field_gear", "")) != "" and str(context.get("kind", "")) == "explore"))
    memory.clear()
    for pair in runtime.get("known_cells", []):
        var cell := arr_to_v2i(pair, Vector2i(-1, -1))
        if inside(cell): memory[cell] = true
    leftovers.clear()
    for entry in runtime.get("leftovers", []):
        var cell := arr_to_v2i(entry.get("cell", []), Vector2i(-1, -1))
        if inside(cell) and entry.get("items", {}) is Dictionary: leftovers[cell] = entry.items.duplicate(true)
    discovered_exits.clear()
    for pair in runtime.get("known_exits", []):
        var cell := arr_to_v2i(pair, Vector2i(-1, -1))
        if exit_cells.has(cell): discovered_exits[cell] = true

func persist_runtime(save_to_disk: bool = true):
    super.persist_runtime(false)
    if not initialized: return
    runtime["raid_model"] = "turn-neighborhood-v1"
    runtime["world_layout"] = "legacy" if legacy_raid else ("procedural-v1" if _is_procedural() else "neighborhood")
    runtime["phase_outcome"] = phase_outcome
    runtime["action_points"] = action_points
    runtime["turn_number"] = turn_number
    runtime["move_mode"] = move_mode
    runtime["pending_extract"] = pending_extract
    runtime["field_gear_carried"] = field_gear_carried
    var known: Array = []
    for cell in memory.keys(): known.append([cell.x, cell.y])
    runtime["known_cells"] = known
    var known_exits: Array = []
    for cell in discovered_exits.keys(): known_exits.append([cell.x, cell.y])
    runtime["known_exits"] = known_exits
    var left_state: Array = []
    for cell in leftovers.keys(): left_state.append({"cell": [cell.x, cell.y], "items": leftovers[cell].duplicate(true)})
    runtime["leftovers"] = left_state
    Game.update_combat_runtime(runtime, save_to_disk)

func _process(delta):
    # Only presentation advances between actions. The entire phase was already
    # resolved and saved; a suspended/reloaded browser cannot reroll the turn.
    if not initialized or game_over or raid_paused: return
    if not horde_frames.is_empty():
        horde_visual_time += minf(float(delta), 0.05)
        if horde_visual_time >= 0.64: _finish_horde_presentation()
        queue_redraw()
    elif phase_outcome != "":
        _finish_horde_presentation()

func zombie_draw_center(index: int) -> Vector2:
    if horde_frames.size() < 3: return super.zombie_draw_center(index)
    var beat := mini(1, int(horde_visual_time / 0.32))
    var fraction := clampf(fmod(horde_visual_time, 0.32) / 0.26, 0.0, 1.0)
    var from: Vector2i = horde_frames[beat].get(index, zombies[index].pos)
    var to: Vector2i = horde_frames[beat + 1].get(index, zombies[index].pos)
    var center := cell_center(from).lerp(cell_center(to), smoothstep(0.0, 1.0, fraction))
    if horde_attacks.get(index, -1) == beat:
        var direction := Vector2(player.pos - to).normalized()
        center += direction * sin(fraction * PI) * 7.0
    return center

func _finish_horde_presentation() -> void:
    horde_frames.clear()
    horde_attacks.clear()
    turn_processing = false
    var outcome := phase_outcome
    phase_outcome = ""
    if outcome != "": finish_encounter(outcome)
    else: persist_runtime()
    queue_redraw()

func commit_action(_cost: int):
    if moving_path:
        deferred_action = true
        return
    if turn_processing or game_over: return
    _spend_action(1)

func carried_loot_count() -> int:
    return super.carried_loot_count() + (1 if field_gear_carried else 0)

func _spend_action(cost: int) -> void:
    action_points = maxi(0, action_points - cost)
    _clear_preview()
    recalc_visibility()
    _discover_exits()
    refresh_intents()
    if action_points <= 0:
        _end_turn()
    else:
        persist_runtime()
        queue_redraw()

func _end_turn() -> void:
    if game_over or turn_processing: return
    turn_processing = true
    _clear_preview()
    var start_hp := int(player.hp)
    var start_pos: Vector2i = player.pos
    tick += 100
    recalc_lighting()
    horde_flow_cache.clear()
    horde_frames = [_horde_positions()]
    horde_attacks.clear()
    var eligible := {}
    var attacked := {}
    for i in range(zombies.size()):
        if not zombies[i].dead and int(zombies[i].next) <= tick + 50: eligible[i] = true
    for beat in range(2):
        _resolve_horde_beat(eligible, attacked, beat)
        horde_frames.append(_horde_positions())
    if not ally.is_empty() and not ally.dead: companion_act()
    if not rescuee.is_empty() and rescue_contacted and not rescuee.dead: rescuee_act()
    _drain_flashlight(100)
    phase_outcome = ""
    if int(player.hp) <= 0:
        player.hp = 0
        player.dead = true
        phase_outcome = "dead"
    elif pending_extract:
        if int(player.hp) == start_hp and player.pos == start_pos and exit_cells.has(player.pos) and ally_ready_to_extract() and (not rescue_contacted or rescuee.is_empty() or bool(rescuee.get("dead", false)) or rescuee_ready_to_extract()):
            if str(context.get("kind", "")) == "rescue": objective_done = rescuee_ready_to_extract()
            phase_outcome = "escaped"
        else:
            msg = "Extraction interrupted. Clear a path and try again."
    pending_extract = false
    turn_number += 1
    action_points = 2
    recalc_visibility()
    _discover_exits()
    refresh_intents()
    persist_runtime()
    horde_visual_time = 0.0
    if not animate_horde: _finish_horde_presentation()
    queue_redraw()

func _horde_positions() -> Dictionary:
    var positions := {}
    for i in range(zombies.size()):
        if not zombies[i].dead: positions[i] = zombies[i].pos
    return positions

func _resolve_horde_beat(eligible: Dictionary, attacked: Dictionary, beat: int) -> void:
    var positions := _horde_positions()
    var proposals := {}
    var attacks := {}
    var alerts: Array = []
    # Every intent reads the same positions. No zombie gets a free tile or an
    # extra sight check because it happened to occur earlier in an array.
    for i in positions:
        if not eligible.has(i) or attacked.has(i): continue
        var z: Dictionary = zombies[i]
        var nearby := manhattan(z.pos, player.pos) <= 12 or visible_cells.has(z.pos)
        if not nearby and beat == 1: continue
        var target_actor: Dictionary = choose_zombie_target(z) if nearby else {}
        if not target_actor.is_empty():
            z.state = "CHASE"
            z.target = target_actor.pos
            z.heard = target_actor.pos
            alerts.append([i, target_actor.pos])
            if manhattan(z.pos, target_actor.pos) == 1:
                z.facing = target_actor.pos - z.pos
                attacks[i] = target_actor
                continue
        elif z.state == "CHASE":
            z.state = "INVESTIGATE"
            z.target = z.heard
        var goal: Vector2i = z.get("heard", Vector2i(-1, -1))
        if goal == z.pos:
            z.heard = Vector2i(-1, -1)
            z.target = Vector2i(-1, -1)
            z.state = "IDLE"
        elif goal != Vector2i(-1, -1):
            var step := _horde_step(z.pos, goal, nearby)
            if step != Vector2i.ZERO: proposals[i] = z.pos + step
        elif nearby and rng.randf() < 0.30:
            var destination: Vector2i = z.pos + DIRS[rng.randi_range(0, 3)]
            if _horde_open(destination): proposals[i] = destination
    var moves: Dictionary = HordeTurn.resolve_moves(positions, proposals, turn_number + beat)
    for i in moves:
        zombies[i].facing = moves[i] - zombies[i].pos
        zombies[i].pos = moves[i]
    for alert in alerts:
        alert_zombie_group(int(alert[0]), alert[1], 4, false)
    for i in attacks:
        attacked[i] = true
        horde_attacks[i] = beat
        zombie_attack(i, attacks[i])
    for i in eligible:
        if not attacked.has(i): zombies[i].next = tick + 125

func _horde_open(cell: Vector2i) -> bool:
    return not blocked(cell) and cell != player.pos and not ally_at(cell) and not rescuee_at(cell)

func _horde_step(from: Vector2i, goal: Vector2i, detailed: bool) -> Vector2i:
    var field := {}
    if detailed:
        if not horde_flow_cache.has(goal):
            field = {goal: 0}
            var frontier: Array = [goal]
            var cursor := 0
            while cursor < frontier.size():
                var cell: Vector2i = frontier[cursor]
                cursor += 1
                if int(field[cell]) >= 22: continue
                for direction in DIRS:
                    var next: Vector2i = cell + direction
                    if blocked(next) or field.has(next): continue
                    field[next] = int(field[cell]) + 1
                    frontier.append(next)
            horde_flow_cache[goal] = field
        field = horde_flow_cache[goal]
    var best := Vector2i.ZERO
    var distance := int(field.get(from, 9999)) if detailed else manhattan(from, goal)
    for direction in DIRS:
        var cell: Vector2i = from + direction
        if not _horde_open(cell): continue
        var candidate := int(field.get(cell, 9999)) if detailed else manhattan(cell, goal)
        if candidate < distance:
            distance = candidate
            best = direction
    return best

func _begin_extract() -> void:
    if turn_processing: return
    if not exit_cells.has(player.pos):
        msg = "Stand on a discovered exit to extract."
    elif action_points < 2:
        msg = "Extraction requires both action points."
    else:
        pending_extract = true
        msg = "Extracting — survive this zombie turn."
        _spend_action(2)

func _discover_exits() -> void:
    for cell in exit_cells:
        if visible_cells.has(cell) or memory.has(cell):
            discovered_exits[cell] = true


# Old in-progress raids retain their harvestable corpses. New raids bring only
# basic supplies and physical equipment home.
func harvestable_corpse_at(p: Vector2i) -> int:
    if _is_procedural() or (not legacy_raid and str(context.get("entry_route_id", "")) != ""): return -1
    return super.harvestable_corpse_at(p)

func check_objective_and_exit():
    if not exit_cells.has(player.pos): pending_extract = false

func _notification(what):
    if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
        if initialized and not game_over:
            raid_paused = true
            pointer_down = false
            _clear_preview()
            persist_runtime()
            queue_redraw()

func _set_pause() -> void:
    raid_paused = not raid_paused
    _clear_preview()
    persist_runtime()
    queue_redraw()

func _clear_preview() -> void:
    pending_cell = Vector2i(-1, -1)
    pending_kind = ""
    pending_path.clear()

func _path_to(destination: Vector2i) -> Array:
    var max_steps: int = TURN_RULES.movement_range(move_mode)
    var queue: Array = [player.pos]
    var previous := {player.pos: Vector2i(-1, -1)}
    var distances := {player.pos: 0}
    var cursor := 0
    while cursor < queue.size():
        var cell: Vector2i = queue[cursor]
        cursor += 1
        if cell == destination: break
        if int(distances[cell]) >= max_steps: continue
        for direction in DIRS:
            var next: Vector2i = cell + direction
            if previous.has(next) or not inside(next) or blocked(next) or zombie_at(next) >= 0 or ally_at(next) or rescuee_at(next): continue
            if not visible_cells.has(next) and not memory.has(next): continue
            previous[next] = cell
            distances[next] = int(distances[cell]) + 1
            queue.append(next)
    if not previous.has(destination) or destination == player.pos: return []
    var path: Array = []
    var cursor_cell := destination
    while cursor_cell != player.pos:
        path.push_front(cursor_cell)
        cursor_cell = previous[cursor_cell]
    return path

func _preview_cell(cell: Vector2i) -> void:
    if turn_processing: return
    if not inside(cell) or action_points <= 0: return
    if cell == pending_cell:
        _confirm_preview()
        return
    _clear_preview()
    if zombie_at(cell) >= 0 and visible_cells.has(cell):
        var target := zombie_at(cell)
        if bool(player.weapon.gun):
            var chance := int(round(_ranged_hit_chance(manhattan(player.pos, cell)) * 100.0))
            msg = "FIRE %d%% • 1 AP • VERY LOUD • tap again" % chance
            pending_kind = "shoot"
        elif can_melee_reach(cell):
            msg = "MELEE • 1 AP • LOW NOISE • tap again"
            pending_kind = "melee"
        else:
            msg = "Target is out of melee reach."
            queue_redraw()
            return
    elif loot_containers.has(cell) and manhattan(player.pos, cell) <= 1:
        if looted_containers.has(cell) and leftovers.has(cell) and not leftovers[cell].is_empty():
            msg = "REVIEW LEFTOVER LOOT • tap again"
            pending_kind = "review"
        else:
            msg = "SEARCH • 1 AP • LOW NOISE • tap again"
            pending_kind = "search"
    elif rescuee_at(cell) and manhattan(player.pos, cell) == 1:
        msg = "CONTACT • 1 AP • tap again"
        pending_kind = "rescue"
    elif (doors.has(cell) or glass.has(cell)) and manhattan(player.pos, cell) == 1:
        msg = "OPEN / BREAK • 1 AP • tap again"
        pending_kind = "interact"
    elif harvestable_corpse_at(cell) >= 0 and manhattan(player.pos, cell) == 1:
        msg = "HARVEST • 1 AP • tap again"
        pending_kind = "harvest"
    else:
        pending_path = _path_to(cell)
        var cost := TURN_RULES.movement_cost(move_mode)
        if pending_path.is_empty() or action_points < cost:
            msg = "No known path in range or not enough AP."
            queue_redraw()
            return
        pending_kind = "move"
        msg = "%s %d tiles • %d AP • %s NOISE • tap again" % [move_mode.to_upper(), pending_path.size(), cost, "LOW" if move_mode == "crouch" else ("LOUD" if move_mode == "sprint" else "LOW")]
    pending_cell = cell
    queue_redraw()

func _confirm_preview() -> void:
    if turn_processing or action_points <= 0: return
    var cell := pending_cell
    var kind := pending_kind
    if kind == "move":
        var path := _path_to(cell)
        var cost := TURN_RULES.movement_cost(move_mode)
        if path.is_empty() or action_points < cost: _clear_preview(); return
        player.crouched = move_mode == "crouch"
        player.sprinting = move_mode == "sprint"
        moving_path = true
        for step in path:
            var direction: Vector2i = step - player.pos
            try_move(direction)
        moving_path = false
        msg = "Moved %d tiles. Zombies act after your turn." % path.size()
        _spend_action(cost)
    elif kind == "shoot":
        var index := zombie_at(cell)
        _clear_preview()
        if index >= 0 and visible_cells.has(cell): shoot(index)
    elif kind == "melee":
        _clear_preview()
        melee(cell)
    elif kind == "search":
        _clear_preview()
        search_loot_container(cell)
    elif kind == "review":
        _clear_preview()
        swap_cell = cell
        swap_take = ""
        queue_redraw()
    elif kind == "harvest":
        var index := harvestable_corpse_at(cell)
        _clear_preview()
        if index >= 0: harvest_zombie_corpse(index)
    elif kind in ["rescue", "interact"]:
        player.facing = cell - player.pos
        _clear_preview()
        interact()

func _input(event):
    if not visible or not initialized or game_over: return
    if turn_processing and event is InputEventKey:
        if event.pressed and event.keycode in [KEY_ESCAPE, KEY_P]: _set_pause()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventScreenTouch:
        get_viewport().set_input_as_handled()
        if event.pressed: _press(event.position)
        else: _release(event.position)
    elif event is InputEventScreenDrag:
        get_viewport().set_input_as_handled()
        _drag(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        get_viewport().set_input_as_handled()
        if DisplayServer.is_touchscreen_available(): return
        if event.pressed: _press(event.position)
        else: _release(event.position)
    elif event is InputEventMouseMotion and pointer_down:
        _drag(event.position)
    elif event is InputEventKey and event.pressed and not event.echo:
        get_viewport().set_input_as_handled()
        match event.keycode:
            KEY_ESCAPE, KEY_P: _set_pause()
            KEY_SPACE, KEY_ENTER: if not raid_paused: _end_turn()
            KEY_R: if not raid_paused: reload_or_pump()
            KEY_F: if not raid_paused: interact()
            KEY_X: if not raid_paused: shove()
            KEY_C: if not raid_paused: _set_mode("crouch")
            KEY_SHIFT: if not raid_paused: _set_mode("sprint")
            KEY_W, KEY_UP: if not raid_paused: _keyboard_move(Vector2i.UP)
            KEY_S, KEY_DOWN: if not raid_paused: _keyboard_move(Vector2i.DOWN)
            KEY_A, KEY_LEFT: if not raid_paused: _keyboard_move(Vector2i.LEFT)
            KEY_D, KEY_RIGHT: if not raid_paused: _keyboard_move(Vector2i.RIGHT)

func _keyboard_move(direction: Vector2i) -> void:
    _preview_cell(player.pos + direction)
    if pending_kind == "move": _confirm_preview()

func _press(pos: Vector2) -> void:
    pointer_down = true
    dragging = false
    drag_start = pos
    drag_last = pos

func _drag(pos: Vector2) -> void:
    if not pointer_down or drag_start.y < MAP_TOP or drag_start.y >= CONTROL_TOP: return
    if pos.distance_to(drag_start) > 8.0: dragging = true
    if dragging:
        camera_offset += pos - drag_last
        drag_last = pos
        _clear_preview()
        queue_redraw()

func _release(pos: Vector2) -> void:
    if not pointer_down: return
    pointer_down = false
    if dragging: return
    if RAID_PAUSE.has_point(pos): _set_pause(); return
    if raid_paused or turn_processing: return
    if swap_cell != Vector2i(-1, -1): _swap_touch(pos); return
    if BTN_ZOOM.has_point(pos): map_zoom = 0.75 if is_equal_approx(map_zoom, 1.0) else 1.0; _clear_preview(); queue_redraw(); return
    if BTN_CENTER.has_point(pos): camera_offset = Vector2.ZERO; _clear_preview(); queue_redraw(); return
    if BTN_WALK.has_point(pos): _set_mode("walk"); return
    if BTN_CROUCH.has_point(pos): _set_mode("crouch"); return
    if BTN_SPRINT.has_point(pos): _set_mode("sprint"); return
    if BTN_USE.has_point(pos): interact(); return
    if BTN_RELOAD.has_point(pos): reload_or_pump(); return
    if BTN_TOOL.has_point(pos): use_secondary_item(); return
    if BTN_SHOVE.has_point(pos): shove(); return
    if BTN_EXTRACT.has_point(pos): _begin_extract(); return
    if BTN_END.has_point(pos): _end_turn(); return
    if pos.y >= MAP_TOP and pos.y < CONTROL_TOP:
        _preview_cell(screen_to_cell(pos))

func _set_mode(mode: String) -> void:
    move_mode = mode
    player.crouched = mode == "crouch"
    player.sprinting = mode == "sprint"
    _clear_preview()
    recalc_visibility()
    _discover_exits()
    persist_runtime()
    queue_redraw()

func map_origin() -> Vector2:
    var x := SCREEN_W * 0.5 - (float(player.pos.x) + 0.5) * TILE * map_zoom + camera_offset.x
    var y := (MAP_TOP + CONTROL_TOP) * 0.5 - (float(player.pos.y) + 0.5) * TILE * map_zoom + camera_offset.y
    return Vector2(clampf(x, SCREEN_W - W * TILE * map_zoom, 0.0), clampf(y, CONTROL_TOP - H * TILE * map_zoom, MAP_TOP))

func screen_to_cell(pos: Vector2) -> Vector2i:
    var local := (pos - map_origin()) / map_zoom
    return Vector2i(int(floor(local.x / TILE)), int(floor(local.y / TILE)))

func visible_columns() -> Array:
    var origin := map_origin()
    return range(maxi(0, int(floor(-origin.x / (TILE * map_zoom))) - 1), mini(W, int(ceil((SCREEN_W - origin.x) / (TILE * map_zoom))) + 1))

func visible_rows() -> Array:
    var origin := map_origin()
    return range(maxi(0, int(floor((MAP_TOP - origin.y) / (TILE * map_zoom))) - 1), mini(H, int(ceil((CONTROL_TOP - origin.y) / (TILE * map_zoom))) + 1))

func draw_escape_markers():
    for cell in discovered_exits.keys():
        var center := cell_center(cell)
        draw_rect(Rect2(cell.x * TILE + 3, cell.y * TILE + 3, TILE - 6, TILE - 6), Color(0.18, 0.82, 0.38, 1), false, 3)
        draw_string(font, center + Vector2(-12, -10), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 24, 7, Color.WHITE)

func _draw():
    if not initialized: return
    draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color("0b1011"))
    draw_set_transform(map_origin(), 0.0, Vector2(map_zoom, map_zoom))
    draw_map()
    draw_units()
    draw_lighting()
    draw_light_source_glows()
    draw_fog()
    draw_objective_markers()
    draw_escape_markers()
    draw_sounds()
    draw_loot_feedback()
    draw_character_fx()
    if pending_kind != "":
        var noise := _preview_noise()
        var sources: Array = pending_path if pending_kind == "move" else [pending_cell if pending_kind in ["search", "harvest"] else player.pos]
        var costs := {}
        for source in sources:
            var footprint: Dictionary = sound_map(source, noise)
            for cell in footprint.keys(): costs[cell] = true
        for y in visible_rows():
            for x in visible_columns():
                var cell := Vector2i(x, y)
                if costs.has(cell): draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color(1.0, 0.66, 0.16, 0.10))
        if pending_kind in ["shoot", "melee"]:
            # A highlighted zombie can move up to two tiles on its next active turn;
            # it can instead move one tile and attack, or attack in place.
            var frontier: Array = [pending_cell]
            var threat_cells := {pending_cell: 0}
            var cursor := 0
            while cursor < frontier.size():
                var from: Vector2i = frontier[cursor]
                cursor += 1
                if int(threat_cells[from]) >= 2: continue
                for direction in DIRS:
                    var threatened: Vector2i = from + direction
                    if not inside(threatened) or blocked(threatened) or threat_cells.has(threatened): continue
                    threat_cells[threatened] = int(threat_cells[from]) + 1
                    frontier.append(threatened)
                    draw_rect(Rect2(threatened.x * TILE + 2, threatened.y * TILE + 2, TILE - 4, TILE - 4), Color(1.0, 0.25, 0.18, 0.55), false, 2)
        for cell in pending_path:
            draw_rect(Rect2(cell.x * TILE + 5, cell.y * TILE + 5, TILE - 10, TILE - 10), Color(0.2, 0.8, 1.0, 0.6))
        if inside(pending_cell): draw_rect(Rect2(pending_cell.x * TILE + 2, pending_cell.y * TILE + 2, TILE - 4, TILE - 4), Color(1.0, 0.8, 0.2, 1), false, 3)
    draw_set_transform(Vector2.ZERO)
    draw_hud()
    if pending_kind in ["shoot", "melee"]:
        var low := int(player.weapon.get("gmin", 0)) if pending_kind == "shoot" else int(player.weapon.get("dmin", 0))
        var high := int(player.weapon.get("gmax", 0)) if pending_kind == "shoot" else int(player.weapon.get("dmax", 0))
        draw_rect(Rect2(0, MAP_TOP, SCREEN_W, 25), Color(0.04, 0.07, 0.05, 0.92))
        draw_string(font, Vector2(10, MAP_TOP + 17), "DAMAGE %d–%d • red outline: zombie movement • amber: sound" % [low, high], HORIZONTAL_ALIGNMENT_LEFT, 370, 10, Color.WHITE)
    if swap_cell != Vector2i(-1, -1) and not raid_paused: _draw_swap()

func _preview_noise() -> int:
    match pending_kind:
        "move":
            var agility := int(player.get("skills", {}).get("Agility", 0))
            var footstep := ThreeStatRules.stealth_noise(agility) if move_mode == "crouch" else (ThreeStatRules.sprint_noise(agility) if move_mode == "sprint" else 18)
            return maxi(footstep, TimeThree.breath_noise(player) if move_mode != "sprint" else 0)
        "shoot": return int(player.weapon.get("gnoise", 0))
        "melee": return maxi(8, int(player.weapon.get("noise", 0)))
        "search": return TacticalBalance.container_search_noise(str(loot_containers.get(pending_cell, "crate")))
        "harvest": return 8
        "rescue": return 12
        "interact": return 58 if glass.has(pending_cell) else 20
        _: return 0

func draw_hud():
    draw_rect(Rect2(0, 0, SCREEN_W, INFO_H), Color("101916"))
    draw_string(font, Vector2(10, 24), "%s • TURN %d • AP %d/2" % [location_name, turn_number, action_points], HORIZONTAL_ALIGNMENT_LEFT, 275, 13, Color.WHITE)
    draw_button(RAID_PAUSE, "RESUME" if raid_paused else "PAUSE", raid_paused, 12)
    draw_string(font, Vector2(10, 47), "%s  HP %d/%d  •  CARRY %d/%d" % [player.name, int(player.hp), int(player.max_hp), carried_loot_count(), party_carry_capacity()], HORIZONTAL_ALIGNMENT_LEFT, 370, 12, Color("afd9f5"))
    draw_string(font, Vector2(10, 68), "%s • %d loaded / %d spare" % [player.weapon.name, int(player.get("loaded", 0)), weapon_reserve], HORIZONTAL_ALIGNMENT_LEFT, 370, 11, Color.WHITE)
    var depth: String = "NEAR" if legacy_raid else str(["NEAR", "MIDDLE", "DEEP"][_world_depth(player.pos)])
    var nearest := 9999
    var bearing := ""
    for exit_cell in discovered_exits.keys():
        var offset: Vector2i = exit_cell - player.pos
        var distance := manhattan(player.pos, exit_cell)
        if distance < nearest:
            nearest = distance
            bearing = "HERE" if distance == 0 else ("E" if offset.x > 0 else "W") if abs(offset.x) >= abs(offset.y) else ("S" if offset.y > 0 else "N")
    var exit_status := "EXIT HERE" if nearest == 0 else ("EXIT ~%d %s (straight line)" % [nearest, bearing] if nearest < 9999 else "NO KNOWN EXIT")
    draw_string(font, Vector2(10, 87), "%s • %s • %d known" % [depth, exit_status, discovered_exits.size()], HORIZONTAL_ALIGNMENT_LEFT, 370, 11, Color("edce75"))
    draw_string(font, Vector2(10, 113), "THE HORDE MOVES" if turn_processing else msg, HORIZONTAL_ALIGNMENT_LEFT, 270, 10, Color.WHITE)
    draw_button(BTN_CENTER, "HOME", false, 11)
    draw_button(BTN_ZOOM, "ZOOM", false, 11)
    draw_rect(Rect2(0, CONTROL_TOP, SCREEN_W, SCREEN_H - CONTROL_TOP), Color("0b120e"))
    draw_button(BTN_WALK, "WALK", move_mode == "walk", 13)
    draw_button(BTN_CROUCH, "CROUCH", move_mode == "crouch", 13)
    draw_button(BTN_SPRINT, "SPRINT", move_mode == "sprint", 13)
    draw_button(BTN_USE, "USE", false, 13)
    draw_button(BTN_RELOAD, "PUMP" if bool(player.get("needs_pump", false)) else "RELOAD", false, 12)
    draw_button(BTN_TOOL, secondary_button_label(), false, 9)
    draw_button(BTN_SHOVE, "SHOVE", false, 12)
    draw_button(BTN_EXTRACT, "EXTRACT", false, 12)
    draw_button(BTN_END, "END TURN", false, 12)
    if raid_paused:
        draw_rect(Rect2(0, MAP_TOP, SCREEN_W, CONTROL_TOP - MAP_TOP), Color(0.02, 0.04, 0.03, 0.88))
        draw_string(font, Vector2(0, 335), "RAID PAUSED", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 27, Color.WHITE)
        draw_string(font, Vector2(0, 370), "Tap RESUME when ready", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 17, Color("edce75"))
        draw_string(font, Vector2(0, 405), "Tap a destination or target to preview", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 13, Color.WHITE)
        draw_string(font, Vector2(0, 428), "Tap again to act • Drag the map to look", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 13, Color.WHITE)
        draw_string(font, Vector2(0, 451), "Two AP each turn • Zombies act afterward", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 13, Color.WHITE)
        draw_string(font, Vector2(0, 474), "EXTRACT costs both AP; survive the turn", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 13, Color.WHITE)

# An unlock is its own action. The caller must explicitly search/open on a
# later action, even when unlocking consumed the last AP of the turn.
func try_unlock(cell: Vector2i, container_lock: bool) -> bool:
    var locks: Dictionary = locked_containers if container_lock else locked_doors
    var was_locked := locks.has(cell)
    var success: bool = super.try_unlock(cell, container_lock)
    return success and not was_locked

func search_loot_container(cell: Vector2i) -> void:
    var before: Dictionary = container_contents.get(cell, {}).duplicate(true)
    var already := looted_containers.has(cell)
    var gear_name := str(context.get("field_gear", ""))
    var has_gear := str(context.get("kind", "")) == "explore" and gear_name != "" and cell == explore_gear_cell and not already and not locked_containers.has(cell)
    var reserved_gear := has_gear and carried_loot_count() < party_carry_capacity()
    if reserved_gear: field_gear_carried = true
    deferred_action = false
    moving_path = true
    super.search_loot_container(cell)
    moving_path = false
    if not already and looted_containers.has(cell):
        var taken: Dictionary = container_contents.get(cell, {})
        var remaining := {}
        for item in before.keys():
            var count := maxi(0, int(before[item]) - int(taken.get(item, 0)))
            if count > 0: remaining[item] = count
        if has_gear and not reserved_gear:
            objective_done = false
            remaining[gear_name] = int(remaining.get(gear_name, 0)) + 1
            msg = "Pack full — the marked gear is still in the container."
        if not remaining.is_empty(): leftovers[cell] = remaining
    elif reserved_gear:
        field_gear_carried = false
    if deferred_action: _spend_action(1)
    elif not game_over: queue_redraw()


func _swap_items() -> Array:
    var source: Dictionary = leftovers.get(swap_cell, {}) if swap_take == "" else collected_container_loot()
    var names: Array = source.keys()
    if swap_take != "" and field_gear_carried:
        var gear := str(context.get("field_gear", ""))
        if gear != "" and not names.has(gear): names.append(gear)
    names.sort()
    return names

func _draw_swap() -> void:
    draw_rect(Rect2(15, 165, 360, 450), Color(0.03, 0.05, 0.04, 0.98))
    draw_string(font, Vector2(25, 194), "SELECT ITEM TO TAKE" if swap_take == "" else "DROP ONE ITEM FOR %s" % swap_take.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 335, 14, Color.WHITE)
    draw_string(font, Vector2(25, 215), "Swap costs 1 AP • Tap CANCEL to close", HORIZONTAL_ALIGNMENT_LEFT, 335, 10, Color("edce75"))
    var source: Dictionary = leftovers.get(swap_cell, {}) if swap_take == "" else collected_container_loot()
    var names := _swap_items()
    for i in range(mini(names.size(), 9)):
        var quantity := int(source.get(names[i], 0))
        if quantity == 0 and field_gear_carried and str(names[i]) == str(context.get("field_gear", "")): quantity = 1
        draw_button(Rect2(25, 225 + i * 37, 340, 34), "%s  x%d" % [str(names[i]), quantity], false, 11)
    draw_button(Rect2(25, 563, 340, 42), "CANCEL", false, 12)

func _swap_touch(pos: Vector2) -> void:
    if Rect2(25, 563, 340, 42).has_point(pos):
        swap_cell = Vector2i(-1, -1)
        swap_take = ""
        queue_redraw()
        return
    var names := _swap_items()
    for i in range(mini(names.size(), 9)):
        if not Rect2(25, 225 + i * 37, 340, 34).has_point(pos): continue
        var name := str(names[i])
        if swap_take == "":
            swap_take = name
            if carried_loot_count() < party_carry_capacity(): _complete_swap("")
            else: queue_redraw()
        else:
            _complete_swap(name)
        return

func _complete_swap(drop: String) -> void:
    if swap_take == "" or not leftovers.has(swap_cell): return
    if drop != "" and not _remove_carried_item(drop): return
    var items: Dictionary = leftovers[swap_cell]
    if int(items.get(swap_take, 0)) <= 0: return
    items[swap_take] = int(items[swap_take]) - 1
    if int(items[swap_take]) <= 0: items.erase(swap_take)
    if swap_take == str(context.get("field_gear", "")) and str(context.get("kind", "")) == "explore":
        field_gear_carried = true
        objective_done = true
    else:
        var carried: Dictionary = container_contents.get(swap_cell, {})
        carried[swap_take] = int(carried.get(swap_take, 0)) + 1
        container_contents[swap_cell] = carried
    if items.is_empty(): leftovers.erase(swap_cell)
    msg = "Took %s%s." % [swap_take, ("; left %s behind" % drop) if drop != "" else ""]
    emit_noise(swap_cell, 12, "rummaging", true)
    swap_cell = Vector2i(-1, -1)
    swap_take = ""
    _spend_action(1)

func _remove_carried_item(item: String) -> bool:
    if field_gear_carried and item == str(context.get("field_gear", "")):
        field_gear_carried = false
        objective_done = false
        var dropped: Dictionary = leftovers.get(swap_cell, {})
        dropped[item] = int(dropped.get(item, 0)) + 1
        leftovers[swap_cell] = dropped
        return true
    for cell in looted_containers.keys():
        var content: Dictionary = container_contents.get(cell, {})
        if int(content.get(item, 0)) <= 0: continue
        content[item] = int(content[item]) - 1
        if int(content[item]) <= 0: content.erase(item)
        container_contents[cell] = content
        var dropped: Dictionary = leftovers.get(swap_cell, {})
        dropped[item] = int(dropped.get(item, 0)) + 1
        leftovers[swap_cell] = dropped
        return true
    if item == "Zombie Corpse":
        for zombie in zombies:
            if bool(zombie.get("dead", false)) and bool(zombie.get("harvested", false)):
                zombie.harvested = false
                return true
    return false
