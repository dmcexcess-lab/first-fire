extends "res://scripts/FFCombatVirus.gd"

const Extraction = preload("res://scripts/FFExtractionRules.gd")
const RAID_PAUSE := Rect2(290, 6, 92, 36)
const RAID_UP := Rect2(65, 652, 56, 54)
const RAID_LEFT := Rect2(8, 708, 56, 54)
const RAID_DOWN := Rect2(65, 708, 56, 54)
const RAID_RIGHT := Rect2(122, 708, 56, 54)
const RAID_FIRE := Rect2(260, 652, 122, 72)
const RAID_USE := Rect2(186, 652, 68, 72)
const RAID_RELOAD := Rect2(260, 730, 122, 50)
const RAID_MELEE := Rect2(186, 730, 68, 50)
const RAID_STANCE := Rect2(8, 784, 113, 48)
const RAID_SPRINT := Rect2(126, 784, 128, 48)
const RAID_TOOL := Rect2(260, 784, 122, 48)

var raid_paused := true
var raid_accumulator := 0.0
var action_ready_tick := 0
var movement_ready_tick := 0
var committing_movement := false
var extract_seconds := 0.0
var weapon_reserve := 0
var held_actions := {}
var raid_save_accumulator := 0.0

func start_encounter(data: Dictionary):
    raid_paused = true
    held_actions.clear()
    raid_accumulator = 0.0
    raid_save_accumulator = 0.0
    action_ready_tick = 0
    movement_ready_tick = 0
    extract_seconds = 0.0
    super.start_encounter(data)
    msg = "Hold arrows to move. Tap infected to shoot. Hold EXIT to escape."
    persist_runtime()

func make_actor(s, pos: Vector2i, controlled: bool) -> Dictionary:
    var actor: Dictionary = super.make_actor(s, pos, controlled)
    if actor.is_empty():
        return actor
    var ammo := Extraction.weapon_state(str(actor.weapon.name), actor.get("equipment_state", {}).get("Weapon", {}))
    if not ammo.is_empty():
        actor.loaded = int(ammo.loaded)
        actor.needs_pump = bool(ammo.needs_pump)
        if controlled:
            weapon_reserve = int(ammo.reserve)
    else:
        weapon_reserve = 0
    return actor

func restore_runtime():
    # The inherited restore defaults to a fresh full magazine. Seed its default
    # from the persistent carried weapon so an empty gun stays empty next raid.
    runtime["weapon_loaded"] = int(runtime.get("weapon_loaded", player.get("loaded", 0)))
    runtime["weapon_needs_pump"] = bool(runtime.get("weapon_needs_pump", player.get("needs_pump", false)))
    weapon_reserve = maxi(0, int(runtime.get("weapon_reserve", weapon_reserve)))
    action_ready_tick = int(runtime.get("action_ready_tick", tick))
    movement_ready_tick = int(runtime.get("movement_ready_tick", tick))
    extract_seconds = clampf(float(runtime.get("extract_seconds", 0.0)), 0.0, Extraction.EXTRACTION_SECONDS)
    super.restore_runtime()
    var saved_stats = runtime.get("raid_stats", {})
    if saved_stats is Dictionary:
        stats.merge(saved_stats, true)
    if runtime.has("random_state"):
        rng.state = int(str(runtime["random_state"]))

func persist_runtime(save_to_disk: bool = true):
    super.persist_runtime(false)
    if not initialized:
        return
    runtime["weapon_reserve"] = weapon_reserve
    runtime["action_ready_tick"] = action_ready_tick
    runtime["movement_ready_tick"] = movement_ready_tick
    runtime["random_state"] = str(rng.state)
    runtime["extract_seconds"] = extract_seconds
    runtime["raid_model"] = "extraction-v1"
    runtime["raid_stats"] = stats.duplicate(true)
    Game.update_combat_runtime(runtime, save_to_disk)

func _notification(what):
    if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
        if initialized and not game_over:
            raid_paused = true
            held_actions.clear()
            persist_runtime()
            Game.save_game()
            queue_redraw()

func _process(delta):
    super._process(delta)
    if not initialized or not visible or game_over or raid_paused:
        return
    # Never fast-forward a raid after a suspended browser tab or long frame.
    raid_accumulator += minf(float(delta), 0.1)
    while raid_accumulator >= Extraction.STEP_SECONDS and not game_over:
        raid_accumulator -= Extraction.STEP_SECONDS
        advance_raid(Extraction.STEP_SECONDS)

func advance_raid(seconds: float) -> void:
    if raid_paused or game_over:
        return
    tick += maxi(1, int(round(seconds * Extraction.TICKS_PER_SECOND)))
    _repeat_held_actions()
    recalc_lighting()
    for i in range(zombies.size()):
        if not zombies[i].dead and int(zombies[i].next) <= tick:
            zombie_act(i)
    if not ally.is_empty() and not ally.dead and int(ally.next) <= tick:
        companion_act()
    if not rescuee.is_empty() and rescue_contacted and not rescuee.dead and int(rescuee.next) <= tick:
        rescuee_act()
    if int(player.hp) <= 0:
        player.hp = 0
        player.dead = true
        finish_encounter("dead")
        return
    _drain_flashlight(maxi(1, int(round(seconds * Extraction.TICKS_PER_SECOND))))
    var escort_ready := ally_ready_to_extract()
    if rescue_contacted and not rescuee.is_empty() and not bool(rescuee.get("dead", false)):
        escort_ready = escort_ready and rescuee_ready_to_extract()
    extract_seconds = Extraction.extraction_progress(extract_seconds, seconds, exit_cells.has(player.pos), escort_ready)
    if extract_seconds >= Extraction.EXTRACTION_SECONDS:
        if str(context.get("kind", "")) == "rescue":
            objective_done = rescuee_ready_to_extract()
        finish_encounter("escaped")
        return
    recalc_visibility()
    refresh_intents()
    raid_save_accumulator += seconds
    if raid_save_accumulator >= 0.5:
        raid_save_accumulator = 0.0
        persist_runtime()
    queue_redraw()

func commit_action(cost: int):
    if game_over:
        return
    # Input consumes player recovery time; it never advances infected time.
    if committing_movement:
        movement_ready_tick = tick + maxi(10, cost)
    else:
        action_ready_tick = tick + maxi(10, cost)
    recalc_visibility()
    refresh_intents()
    persist_runtime()
    queue_redraw()

func check_objective_and_exit():
    if not exit_cells.has(player.pos):
        extract_seconds = 0.0

func reload_or_pump() -> void:
    if not bool(player.weapon.gun):
        msg = "No ranged weapon equipped."
        return
    if bool(player.get("needs_pump", false)):
        super.reload_or_pump()
        return
    var state := Extraction.reload_state(str(player.weapon.name), {"loaded": int(player.loaded), "reserve": weapon_reserve})
    if int(state.get("loaded", 0)) == int(player.loaded):
        msg = "No spare ammunition." if weapon_reserve <= 0 else "Already loaded."
        return
    player.loaded = int(state.loaded)
    weapon_reserve = int(state.reserve)
    msg = "Reloading. %d spare rounds remain." % weapon_reserve
    emit_noise(player.pos, 7, "reload", true)
    commit_action(ThreeStatRules.weapon_reload_time(player.weapon))

func finish_encounter(outcome: String):
    if game_over:
        return
    # Store the carried gun before the inherited result signal resolves the
    # expedition. Stash transfers already preserve equipment_state by slot.
    var survivor: Variant = Game.get_survivor(int(player.get("id", -1)))
    if survivor != null:
        Game._normalize_survivor_equipment_state(survivor)
        var state := Extraction.weapon_state(str(player.weapon.name), {"loaded": int(player.get("loaded", 0)), "reserve": weapon_reserve, "needs_pump": bool(player.get("needs_pump", false))})
        if not state.is_empty():
            survivor["equipment_state"]["Weapon"] = state
    held_actions.clear()
    super.finish_encounter(outcome)

func _set_pause() -> void:
    raid_paused = not raid_paused
    held_actions.clear()
    raid_accumulator = 0.0
    persist_runtime()
    Game.save_game()
    queue_redraw()

func _action_at(pos: Vector2) -> String:
    if RAID_UP.has_point(pos): return "up"
    if RAID_DOWN.has_point(pos): return "down"
    if RAID_LEFT.has_point(pos): return "left"
    if RAID_RIGHT.has_point(pos): return "right"
    if RAID_FIRE.has_point(pos): return "fire"
    if RAID_USE.has_point(pos): return "use"
    if RAID_RELOAD.has_point(pos): return "reload"
    if RAID_MELEE.has_point(pos): return "melee"
    if RAID_STANCE.has_point(pos): return "stance"
    if RAID_SPRINT.has_point(pos): return "sprint"
    if RAID_TOOL.has_point(pos): return "tool"
    return ""

func _input(event):
    if not visible or not initialized or game_over:
        return
    if event is InputEventScreenTouch:
        get_viewport().set_input_as_handled()
        if event.pressed:
            _pointer_down(int(event.index), event.position)
        else:
            held_actions.erase(int(event.index))
    elif event is InputEventScreenDrag:
        get_viewport().set_input_as_handled()
        if held_actions.has(int(event.index)):
            held_actions[int(event.index)] = _action_at(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        get_viewport().set_input_as_handled()
        if DisplayServer.is_touchscreen_available(): return
        if event.pressed: _pointer_down(-1, event.position)
        else: held_actions.erase(-1)
    elif event is InputEventMouseMotion and held_actions.has(-1):
        held_actions[-1] = _action_at(event.position)
    elif event is InputEventKey and not event.echo:
        var action := ""
        match event.keycode:
            KEY_ESCAPE, KEY_P:
                if event.pressed: _set_pause()
                return
            KEY_W, KEY_UP: action = "up"
            KEY_S, KEY_DOWN: action = "down"
            KEY_A, KEY_LEFT: action = "left"
            KEY_D, KEY_RIGHT: action = "right"
            KEY_SPACE: action = "fire"
            KEY_F: action = "use"
            KEY_R: action = "reload"
            KEY_X: action = "melee"
            KEY_C: action = "stance"
            KEY_SHIFT: action = "sprint"
            KEY_L: action = "tool"
        if action != "":
            get_viewport().set_input_as_handled()
            var key := 1000 + int(event.keycode)
            if event.pressed:
                if action in ["up", "down", "left", "right", "fire"]: held_actions[key] = action
                _perform_action(action)
            else: held_actions.erase(key)

func _pointer_down(id: int, pos: Vector2) -> void:
    if RAID_PAUSE.has_point(pos):
        _set_pause()
        return
    if raid_paused: return
    var action := _action_at(pos)
    if action != "":
        if action in ["up", "down", "left", "right", "fire"]: held_actions[id] = action
        _perform_action(action)
    elif pos.y >= MAP_TOP and pos.y < CONTROL_TOP and tick >= action_ready_tick:
        var cell := screen_to_cell(pos)
        if not inside(cell): return
        var enemy := zombie_at(cell)
        if enemy >= 0 and visible_cells.has(cell):
            if bool(player.weapon.gun): shoot(enemy)
            elif can_melee_reach(cell): melee(cell)
        elif manhattan(player.pos, cell) <= 1:
            if cell != player.pos: player.facing = cell - player.pos
            interact()
        else:
            player.facing = dominant(cell - player.pos)
            recalc_visibility()
            persist_runtime()
            queue_redraw()

func _repeat_held_actions() -> void:
    for value in held_actions.values():
        _perform_action(str(value))

func _perform_action(action: String) -> void:
    if raid_paused or game_over: return
    if action in ["up", "down", "left", "right"]:
        if tick < movement_ready_tick: return
        committing_movement = true
        match action:
            "up": try_move(Vector2i.UP)
            "down": try_move(Vector2i.DOWN)
            "left": try_move(Vector2i.LEFT)
            "right": try_move(Vector2i.RIGHT)
        committing_movement = false
        return
    if tick < action_ready_tick: return
    match action:
        "fire": _fire_forward()
        "use": interact()
        "reload": reload_or_pump()
        "melee":
            var cell: Vector2i = player.pos + player.facing
            if zombie_at(cell) >= 0 and not bool(player.weapon.gun): melee(cell)
            else: shove()
        "stance": toggle_crouch()
        "sprint": toggle_sprint()
        "tool": use_secondary_item()

func _fire_forward() -> void:
    if not bool(player.weapon.gun):
        var cell: Vector2i = player.pos + player.facing
        if zombie_at(cell) >= 0: melee(cell)
        return
    # Hitscan on the aimed cardinal ray. Tapping a visible infected provides
    # direct touch aiming; firing into empty space still spends a round.
    for distance in range(1, W + H):
        var cell: Vector2i = player.pos + player.facing * distance
        if not inside(cell) or not line_clear(player.pos, cell): break
        var enemy := zombie_at(cell)
        if enemy >= 0 and visible_cells.has(cell):
            shoot(enemy)
            return
        if barrels.has(cell) and visible_cells.has(cell):
            shoot_barrel(cell)
            return
    if not _can_fire_ranged(): return
    player.loaded = maxi(0, int(player.loaded) - 1)
    player.needs_pump = ThreeStatRules.weapon_requires_pump(player.weapon)
    stats.shots += 1
    _flash_muzzle(player.pos, player.facing)
    emit_noise(player.pos, int(player.weapon.gnoise), "gunshot", true)
    commit_action(TimeThree.attack_cost(player, int(player.weapon.gtime)))

func draw_hud():
    draw_rect(Rect2(0, 0, SCREEN_W, INFO_H), Color("101916"))
    draw_string(font, Vector2(10, 25), location_name, HORIZONTAL_ALIGNMENT_LEFT, 274, 15, Color.WHITE)
    draw_button(RAID_PAUSE, "RESUME" if raid_paused else "PAUSE", raid_paused, 12)
    draw_string(font, Vector2(10, 51), "%s  HP %d/%d  •  CARRY %d/%d" % [player.name, int(player.hp), int(player.max_hp), carried_loot_count(), party_carry_capacity()], HORIZONTAL_ALIGNMENT_LEFT, 370, 12, Color("afd9f5"))
    draw_string(font, Vector2(10, 73), "%s  %d loaded / %d spare" % [str(player.weapon.name), int(player.get("loaded", 0)), weapon_reserve], HORIZONTAL_ALIGNMENT_LEFT, 370, 12, Color.WHITE)
    var exit_distance := nearest_exit_distance(player.pos)
    var objective := "EXIT %d • Loot is at risk until extraction" % exit_distance
    if exit_cells.has(player.pos): objective = "EXTRACTING %.1f / %.1fs • Stay here" % [extract_seconds, Extraction.EXTRACTION_SECONDS]
    if str(context.get("kind", "")) == "rescue" and not rescue_contacted: objective = "SOS: rescue optional • %s" % objective
    draw_string(font, Vector2(10, 96), objective, HORIZONTAL_ALIGNMENT_LEFT, 370, 11, Color("edce75"))
    draw_string(font, Vector2(10, 117), msg, HORIZONTAL_ALIGNMENT_LEFT, 370, 10, Color.WHITE)
    draw_string(font, Vector2(10, 138), "REAL TIME • %s • %s" % [scene_time.to_upper(), "READY" if tick >= action_ready_tick else "RECOVERING / RELOADING"], HORIZONTAL_ALIGNMENT_LEFT, 370, 10, Color("9baea2"))
    draw_rect(Rect2(0, CONTROL_TOP, SCREEN_W, SCREEN_H - CONTROL_TOP), Color("0b120e"))
    draw_button(RAID_UP, "UP", false, 12)
    draw_button(RAID_LEFT, "LEFT", false, 11)
    draw_button(RAID_DOWN, "DOWN", false, 11)
    draw_button(RAID_RIGHT, "RIGHT", false, 11)
    draw_button(RAID_FIRE, "FIRE", false, 20)
    draw_button(RAID_USE, "USE", false, 13)
    draw_button(RAID_RELOAD, "PUMP" if bool(player.get("needs_pump", false)) else "RELOAD", false, 12)
    draw_button(RAID_MELEE, "SHOVE" if bool(player.weapon.gun) else "MELEE", false, 11)
    draw_button(RAID_STANCE, "STEALTH", bool(player.crouched), 12)
    draw_button(RAID_SPRINT, "SPRINT", bool(player.get("sprinting", false)), 12)
    draw_button(RAID_TOOL, secondary_button_label(), false, 9)
    if raid_paused:
        draw_rect(Rect2(0, MAP_TOP, SCREEN_W, CONTROL_TOP - MAP_TOP), Color(0.02, 0.04, 0.03, 0.85))
        draw_string(font, Vector2(0, 350), "RAID PAUSED", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 27, Color.WHITE)
        draw_string(font, Vector2(0, 386), "Tap RESUME when ready", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 17, Color("edce75"))
        draw_string(font, Vector2(0, 417), "Arrows / WASD: move • Tap infected: shoot", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 13, Color.WHITE)
        draw_string(font, Vector2(0, 443), "USE / F: search, open, rescue • R: reload", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 13, Color.WHITE)
        draw_string(font, Vector2(0, 469), "Hold an exit for 3 seconds to keep your loot", HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 13, Color.WHITE)
