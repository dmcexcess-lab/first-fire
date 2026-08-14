extends Control

signal encounter_finished(result)

const D = preload("res://scripts/FFData.gd")
const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")

const SCREEN_W := 390.0
const SCREEN_H := 844.0
const INFO_H := 145.0
const MAP_TOP := 152.0
const CONTROL_TOP := 648.0
const TILE := 26
const W := 20
const H := 18
const DIRS := [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
const DIR_NAMES := ["N", "E", "S", "W"]

var rng := RandomNumberGenerator.new()
var font: Font
var context := {}
var runtime := {}
var player := {}
var ally := {}
var zombies: Array = []
var walls := {}
var obstacles := {}
var glass := {}
var doors := {}
var barrels := {}
var base_glass := {}
var base_barrels := {}
var visible_cells := {}
var memory := {}
var last_seen := {}
var intent_reads := {}
var sound_marks: Array = []
var tick := 0
var exit_cell := Vector2i(1, H - 2)
var objective_cell := Vector2i(W - 3, 3)
var rescue_cell := Vector2i(W - 3, 4)
var objective_done := false
var game_over := false
var msg := ""
var submsg := ""
var location_name := "Field Encounter"
var stats := {"kills": 0, "shots": 0, "noise": 0, "damage": 0}
var active_touch_ids := {}
var last_guard_action := ""
var last_guard_ms := -10000
var initialized := false
var hit_flash_cell := Vector2i(-1, -1)
var hit_flash_until_ms := -1
var muzzle_flash_cell := Vector2i(-1, -1)
var muzzle_flash_facing := Vector2i(1, 0)
var muzzle_flash_until_ms := -1
var fx_active_last_frame := false

var btn_turn_left := Rect2(8, 700, 136, 78)
var btn_crouch := Rect2(28, 788, 96, 42)
var btn_forward := Rect2(264, 654, 108, 38)
var btn_turn_right := Rect2(246, 700, 136, 78)
var btn_back := Rect2(264, 788, 108, 42)

func _ready():
    font = ThemeDB.fallback_font
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_process_input(true)
    set_process(true)
    visible = false

func _process(_delta):
    if not initialized:
        return
    var now := Time.get_ticks_msec()
    var active := now < hit_flash_until_ms or now < muzzle_flash_until_ms
    if active or fx_active_last_frame:
        queue_redraw()
    fx_active_last_frame = active

func start_encounter(data: Dictionary):
    context = data.duplicate(true)
    runtime = context.get("runtime", {}).duplicate(true)
    rng.seed = int(context.get("seed", 1))
    initialized = true
    game_over = false
    stats = {"kills": 0, "shots": 0, "noise": 0, "damage": 0}
    sound_marks.clear()
    memory.clear()
    last_seen.clear()
    intent_reads.clear()
    active_touch_ids.clear()
    last_guard_action = ""
    last_guard_ms = -10000
    hit_flash_cell = Vector2i(-1, -1)
    hit_flash_until_ms = -1
    muzzle_flash_cell = Vector2i(-1, -1)
    muzzle_flash_until_ms = -1
    fx_active_last_frame = false
    tick = int(runtime.get("tick", 0))
    location_name = str(context.get("location_name", "Field Encounter"))
    build_map(int(context.get("layout", 0)))
    make_party()
    spawn_zombies()
    restore_runtime()
    objective_done = bool(runtime.get("objective_done", context.get("kind", "ambush") == "ambush"))
    if context.get("kind", "ambush") == "rescue":
        msg = "Find the survivor, then get back out."
        submsg = "They will decide whether to join after you escape."
    elif context.get("kind", "ambush") == "explore":
        msg = "Search the marked spot, then escape."
        submsg = "This is extra opportunity, not a requirement to clear the map."
    else:
        msg = "You got jumped. Break contact and escape."
        submsg = "You do not need to kill anything."
    recalc_visibility()
    refresh_intents()
    visible = true
    queue_redraw()

func stop_encounter():
    initialized = false
    visible = false
    context = {}
    runtime = {}
    queue_redraw()

func make_party():
    var ids: Array = context.get("survivor_ids", [])
    var lead = Game.get_survivor(ids[0]) if not ids.is_empty() else null
    player = make_actor(lead, Vector2i(2, H - 2), true)
    ally = {}
    if ids.size() > 1:
        var companion = Game.get_survivor(ids[1])
        if companion != null and companion.get("condition", "Dead") != "Dead":
            ally = make_actor(companion, Vector2i(2, H - 3), false)
            ally["next"] = 85

func make_actor(s, pos: Vector2i, controlled: bool) -> Dictionary:
    if s == null:
        return {}
    var max_hp := condition_max_hp(str(s.get("condition", "Healthy")))
    var actor = {
        "id": int(s.get("id", -1)),
        "name": str(s.get("name", "Survivor")),
        "skills": s.get("skills", {}).duplicate(true),
        "traits": s.get("traits", []).duplicate(true),
        "fatigue": float(s.get("fatigue", 0.0)),
        "stress": float(s.get("stress", 0.0)),
        "condition": str(s.get("condition", "Healthy")),
        "equipment": s.get("equipment", {}).duplicate(true),
        "appearance": s.get("appearance", TacticalVisuals.default_survivor_appearance(int(s.get("id", -1)))).duplicate(true),
        "weapon": weapon_profile(str(s.get("equipment", {}).get("Weapon", ""))),
        "clothing": str(s.get("equipment", {}).get("Clothing", "")),
        "tool": str(s.get("equipment", {}).get("Tool", "")),
        "pack": str(s.get("equipment", {}).get("Pack", "")),
        "hp": max_hp,
        "max_hp": max_hp,
        "pos": pos,
        "facing": Vector2i(1, 0),
        "last_dir": Vector2i.ZERO,
        "move_state": "STILL",
        "crouched": false,
        "dead": false,
        "controlled": controlled
    }
    return actor

func condition_max_hp(condition: String) -> int:
    match condition:
        "Hurt": return 14
        "Wounded": return 10
        "Critical": return 6
        _: return 18

func weapon_profile(name: String) -> Dictionary:
    match name:
        "Utility Knife", "Kitchen Knife":
            return {"name": name if name != "" else "Knife", "dmin": 4, "dmax": 7, "time": 80, "noise": 3, "push": 0, "stealth": 5, "gun": false, "ammo": 0}
        "Wooden Club", "Baseball Bat":
            return {"name": name, "dmin": 5, "dmax": 9, "time": 120, "noise": 9, "push": 2, "stealth": 1, "gun": false, "ammo": 0}
        "Hammer":
            return {"name": name, "dmin": 5, "dmax": 9, "time": 105, "noise": 8, "push": 1, "stealth": 2, "gun": false, "ammo": 0}
        "Improvised Spear":
            return {"name": name, "dmin": 6, "dmax": 10, "time": 125, "noise": 7, "push": 1, "stealth": 3, "gun": false, "ammo": 0}
        "Crowbar":
            return {"name": name, "dmin": 5, "dmax": 8, "time": 110, "noise": 8, "push": 1, "stealth": 2, "gun": false, "ammo": 0}
        "Hatchet":
            return {"name": name, "dmin": 7, "dmax": 11, "time": 145, "noise": 11, "push": 1, "stealth": 2, "gun": false, "ammo": 0}
        "Pistol":
            return {"name": name, "dmin": 3, "dmax": 5, "time": 95, "noise": 7, "push": 0, "stealth": 1, "gun": true, "ammo": 1, "gmin": 8, "gmax": 14, "gtime": 120, "gnoise": 72}
        "Shotgun":
            return {"name": name, "dmin": 4, "dmax": 7, "time": 115, "noise": 9, "push": 1, "stealth": 1, "gun": true, "ammo": 2, "gmin": 13, "gmax": 20, "gtime": 155, "gnoise": 96}
        _:
            return {"name": "Bare Hands", "dmin": 2, "dmax": 4, "time": 105, "noise": 5, "push": 0, "stealth": 0, "gun": false, "ammo": 0}

func build_map(layout: int):
    walls.clear(); obstacles.clear(); glass.clear(); doors.clear(); barrels.clear()
    for x in range(W):
        walls[Vector2i(x, 0)] = true
        walls[Vector2i(x, H - 1)] = true
    for y in range(H):
        walls[Vector2i(0, y)] = true
        walls[Vector2i(W - 1, y)] = true

    if layout % 3 == 0:
        # Small storefront with aisles and two entries.
        for x in range(6, 19):
            walls[Vector2i(x, 2)] = true
            walls[Vector2i(x, 13)] = true
        for y in range(2, 14):
            walls[Vector2i(6, y)] = true
            walls[Vector2i(18, y)] = true
        walls.erase(Vector2i(11, 13)); doors[Vector2i(11, 13)] = false
        walls.erase(Vector2i(18, 6)); doors[Vector2i(18, 6)] = false
        for x in range(8, 11): obstacles[Vector2i(x, 5)] = true
        for x in range(13, 17): obstacles[Vector2i(x, 5)] = true
        for x in range(8, 11): obstacles[Vector2i(x, 8)] = true
        for x in range(13, 17): obstacles[Vector2i(x, 8)] = true
        for x in range(8, 11): obstacles[Vector2i(x, 11)] = true
        glass[Vector2i(8, 13)] = true
        glass[Vector2i(9, 13)] = true
        walls.erase(Vector2i(8, 13)); walls.erase(Vector2i(9, 13))
        barrels[Vector2i(17, 11)] = true
    elif layout % 3 == 1:
        # House / office: rooms create blind corners and door decisions.
        for x in range(5, 19):
            walls[Vector2i(x, 2)] = true
            walls[Vector2i(x, 14)] = true
        for y in range(2, 15):
            walls[Vector2i(5, y)] = true
            walls[Vector2i(18, y)] = true
        walls.erase(Vector2i(10, 14)); doors[Vector2i(10, 14)] = false
        for x in range(6, 18): walls[Vector2i(x, 8)] = true
        walls.erase(Vector2i(9, 8)); doors[Vector2i(9, 8)] = false
        walls.erase(Vector2i(15, 8)); doors[Vector2i(15, 8)] = false
        for y in range(3, 8): walls[Vector2i(12, y)] = true
        walls.erase(Vector2i(12, 5)); doors[Vector2i(12, 5)] = false
        obstacles[Vector2i(7, 4)] = true; obstacles[Vector2i(8, 4)] = true
        obstacles[Vector2i(15, 4)] = true; obstacles[Vector2i(16, 4)] = true
        obstacles[Vector2i(7, 11)] = true; obstacles[Vector2i(15, 11)] = true
        glass[Vector2i(6, 14)] = true; walls.erase(Vector2i(6, 14))
        barrels[Vector2i(17, 3)] = true
    else:
        # Alley / loading yard with staggered cover.
        for p in [Vector2i(5,4),Vector2i(6,4),Vector2i(5,5),Vector2i(6,5),Vector2i(10,3),Vector2i(10,4),Vector2i(10,5),Vector2i(14,6),Vector2i(15,6),Vector2i(16,6),Vector2i(8,10),Vector2i(9,10),Vector2i(13,12),Vector2i(14,12),Vector2i(15,12)]:
            obstacles[p] = true
        for y in range(2, 10): walls[Vector2i(18, y)] = true
        walls.erase(Vector2i(18, 6)); doors[Vector2i(18, 6)] = false
        glass[Vector2i(18, 5)] = true; walls.erase(Vector2i(18, 5))
        barrels[Vector2i(12, 7)] = true
        barrels[Vector2i(17, 13)] = true

    base_glass = glass.duplicate(true)
    base_barrels = barrels.duplicate(true)
    objective_cell = choose_far_open_cell()
    rescue_cell = objective_cell

func choose_far_open_cell() -> Vector2i:
    var candidates := []
    for y in range(2, H - 2):
        for x in range(2, W - 2):
            var p = Vector2i(x, y)
            if not blocked(p) and manhattan(Vector2i(2, H - 2), p) >= 13:
                candidates.append(p)
    if candidates.is_empty():
        return Vector2i(W - 3, 3)
    return candidates[rng.randi_range(0, candidates.size() - 1)]

func spawn_zombies():
    zombies.clear()
    var zone := str(context.get("zone", "Nearby Streets"))
    var count: int = int({"Camp Perimeter": 3, "Nearby Streets": 4, "Residential Blocks": 5, "Commercial Fringe": 6, "Industrial Edge": 7}.get(zone, 4))
    if context.get("kind", "") == "ambush": count += 1
    var candidates := []
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            var p = Vector2i(x, y)
            if blocked(p) or p == player.get("pos", Vector2i(2, H - 2)) or p == ally.get("pos", Vector2i(-1,-1)):
                continue
            var d = manhattan(Vector2i(2, H - 2), p)
            if context.get("kind", "") == "ambush":
                if d >= 4 and d <= 11: candidates.append(p)
            elif d >= 7:
                candidates.append(p)
    for i in range(count):
        if candidates.is_empty(): break
        var pick = rng.randi_range(0, candidates.size() - 1)
        var p: Vector2i = candidates[pick]
        candidates.remove_at(pick)
        var state = "INVESTIGATE" if context.get("kind", "") == "ambush" and i < 2 else "IDLE"
        zombies.append({
            "id": i, "pos": p, "facing": DIRS[rng.randi_range(0,3)],
            "hp": rng.randi_range(8, 13), "state": state,
            "target": Vector2i(2, H - 2) if state == "INVESTIGATE" else Vector2i(-1,-1),
            "heard": Vector2i(2, H - 2) if state == "INVESTIGATE" else Vector2i(-1,-1),
            "next": rng.randi_range(65, 170), "dead": false,
            "look": TacticalVisuals.zombie_appearance(rng, zone)
        })

func restore_runtime():
    if runtime.is_empty():
        persist_runtime()
        return
    if runtime.has("lead_hp"):
        player["hp"] = clamp(int(runtime["lead_hp"]), 0, int(player["max_hp"]))
    if runtime.has("player_pos"):
        player["pos"] = arr_to_v2i(runtime["player_pos"], player["pos"])
    if runtime.has("facing"):
        player["facing"] = DIRS[posmod(int(runtime["facing"]), 4)]
    player["crouched"] = bool(runtime.get("crouched", false))
    if not ally.is_empty():
        ally["hp"] = clamp(int(runtime.get("ally_hp", ally["max_hp"])), 0, int(ally["max_hp"]))
        ally["dead"] = int(ally["hp"]) <= 0
        if runtime.has("ally_pos"):
            ally["pos"] = arr_to_v2i(runtime["ally_pos"], ally["pos"])
    objective_done = bool(runtime.get("objective_done", false))
    tick = int(runtime.get("tick", tick))

    var open_doors: Array = runtime.get("open_doors", [])
    for a in open_doors:
        var p = arr_to_v2i(a, Vector2i(-1,-1))
        if doors.has(p): doors[p] = true
    for a in runtime.get("broken_glass", []):
        glass.erase(arr_to_v2i(a, Vector2i(-1,-1)))
    for a in runtime.get("removed_barrels", []):
        barrels.erase(arr_to_v2i(a, Vector2i(-1,-1)))

    var saved_z: Array = runtime.get("zombies", [])
    if saved_z.size() == zombies.size():
        for i in range(saved_z.size()):
            var zsave: Dictionary = saved_z[i]
            zombies[i]["pos"] = Vector2i(int(zsave.get("x", zombies[i].pos.x)), int(zsave.get("y", zombies[i].pos.y)))
            zombies[i]["facing"] = Vector2i(int(zsave.get("fx", zombies[i].facing.x)), int(zsave.get("fy", zombies[i].facing.y)))
            zombies[i]["hp"] = int(zsave.get("hp", zombies[i].hp))
            zombies[i]["dead"] = bool(zsave.get("dead", false))
            zombies[i]["state"] = str(zsave.get("state", "IDLE"))
            zombies[i]["target"] = Vector2i(int(zsave.get("tx", -1)), int(zsave.get("ty", -1)))
            zombies[i]["heard"] = Vector2i(int(zsave.get("hx", -1)), int(zsave.get("hy", -1)))
            zombies[i]["next"] = int(zsave.get("next", zombies[i].next))
            if zsave.has("look"):
                zombies[i]["look"] = zsave["look"].duplicate(true)

func arr_to_v2i(value, fallback: Vector2i) -> Vector2i:
    if value is Array and value.size() >= 2:
        return Vector2i(int(value[0]), int(value[1]))
    return fallback

func persist_runtime():
    if not initialized:
        return
    var zsave := []
    for z in zombies:
        zsave.append({
            "x": z.pos.x, "y": z.pos.y, "fx": z.facing.x, "fy": z.facing.y,
            "hp": int(z.hp), "dead": bool(z.dead), "state": str(z.state),
            "tx": z.target.x, "ty": z.target.y, "hx": z.heard.x, "hy": z.heard.y,
            "next": int(z.next), "look": z.get("look", {}).duplicate(true)
        })
    var open_doors := []
    for p in doors.keys():
        if doors[p]: open_doors.append([p.x, p.y])
    var broken_glass := []
    for p in base_glass.keys():
        if not glass.has(p): broken_glass.append([p.x, p.y])
    var removed_barrels := []
    for p in base_barrels.keys():
        if not barrels.has(p): removed_barrels.append([p.x, p.y])
    runtime = {
        "lead_hp": int(player.get("hp", 0)),
        "ally_hp": int(ally.get("hp", 0)) if not ally.is_empty() else -1,
        "player_pos": [player.pos.x, player.pos.y],
        "ally_pos": [ally.pos.x, ally.pos.y] if not ally.is_empty() else [-1,-1],
        "facing": DIRS.find(player.facing),
        "crouched": bool(player.crouched),
        "objective_done": objective_done,
        "tick": tick,
        "zombies": zsave,
        "open_doors": open_doors,
        "broken_glass": broken_glass,
        "removed_barrels": removed_barrels
    }
    Game.update_combat_runtime(runtime)

func _input(e):
    if not visible or not initialized:
        return
    if e is InputEventScreenTouch:
        get_viewport().set_input_as_handled()
        var touch_id := int(e.index)
        if e.pressed:
            if active_touch_ids.has(touch_id): return
            active_touch_ids[touch_id] = true
            dispatch_point(e.position)
        else:
            active_touch_ids.erase(touch_id)
        return
    if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
        if DisplayServer.is_touchscreen_available():
            get_viewport().set_input_as_handled()
            return
        if e.pressed:
            dispatch_point(e.position)
            get_viewport().set_input_as_handled()
        return
    if e is InputEventKey and e.pressed and not e.echo:
        get_viewport().set_input_as_handled()
        match e.keycode:
            KEY_Q: guarded_action("TURN_L", func(): rotate_player(-1))
            KEY_E: guarded_action("TURN_R", func(): rotate_player(1))
            KEY_W, KEY_UP: step_forward()
            KEY_S, KEY_DOWN: step_backward()
            KEY_C: toggle_crouch()

func dispatch_point(pos: Vector2):
    if game_over: return
    if btn_turn_left.has_point(pos):
        guarded_action("TURN_L", func(): rotate_player(-1)); return
    if btn_turn_right.has_point(pos):
        guarded_action("TURN_R", func(): rotate_player(1)); return
    if btn_forward.has_point(pos): step_forward(); return
    if btn_back.has_point(pos): step_backward(); return
    if btn_crouch.has_point(pos): toggle_crouch(); return
    if pos.y < MAP_TOP or pos.y >= CONTROL_TOP: return
    var cell = screen_to_cell(pos)
    if not inside(cell): return
    var delta: Vector2i = cell - player.pos
    if manhattan(player.pos, cell) == 1:
        player.facing = delta
        recalc_visibility(); refresh_intents()
        if zombie_at(cell) != -1: melee(cell); return
        if doors.has(cell):
            if not doors[cell]:
                interact()
            else:
                try_move(delta)
            return
        if glass.has(cell): interact(); return
        try_move(delta); return
    if visible_cells.has(cell):
        var zi = zombie_at(cell)
        if zi != -1:
            if bool(player.weapon.gun): shoot(zi)
            else:
                msg = "Too far for %s." % player.weapon.name
                queue_redraw()
            return
        if barrels.has(cell): shoot_barrel(cell); return

func guarded_action(action: String, callable: Callable):
    var now := Time.get_ticks_msec()
    if action == last_guard_action and now - last_guard_ms < 420:
        return
    last_guard_action = action
    last_guard_ms = now
    callable.call()

func rotate_player(step: int):
    var idx := DIRS.find(player.facing)
    idx = posmod(idx + step, 4)
    player.facing = DIRS[idx]
    player.last_dir = Vector2i.ZERO
    player.move_state = "STILL"
    msg = "Turned %s." % DIR_NAMES[idx]
    commit_action(20)

func step_forward():
    var cell: Vector2i = player.pos + player.facing
    if zombie_at(cell) != -1:
        melee(cell); return
    if doors.has(cell):
        if not doors[cell]: interact()
        else: try_move(player.facing)
        return
    if glass.has(cell): interact(); return
    try_move(player.facing)

func step_backward():
    var keep: Vector2i = player.facing
    var dest = player.pos - keep
    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest):
        msg = "Blocked behind you."
        queue_redraw(); return
    player.pos = dest
    player.facing = keep
    player.last_dir = Vector2i.ZERO
    player.move_state = "CROUCH" if player.crouched else "WALK"
    emit_noise(dest, 2 if player.crouched else 6, "steps", true)
    check_objective_and_exit()
    commit_action(145 if player.crouched else 115)

func toggle_crouch():
    player.crouched = not player.crouched
    player.move_state = "CROUCH" if player.crouched else "STILL"
    msg = "Crouched: quieter, slower." if player.crouched else "Standing."
    recalc_visibility(); refresh_intents(); persist_runtime(); queue_redraw()

func try_move(dir: Vector2i):
    var dest: Vector2i = player.pos + dir
    player.facing = dir
    recalc_visibility(); refresh_intents()
    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest):
        msg = "Blocked."
        queue_redraw(); return
    player.pos = dest
    player.last_dir = dir
    player.move_state = "CROUCH" if player.crouched else "WALK"
    var cost := 150 if player.crouched else 100
    var noise := 2 if player.crouched else 7
    if player.clothing == "Heavy Boots": noise += 2
    emit_noise(dest, noise, "steps", true)
    check_objective_and_exit()
    commit_action(cost)

func check_objective_and_exit():
    var kind := str(context.get("kind", "ambush"))
    if not objective_done and (kind == "explore" or kind == "rescue"):
        var target = rescue_cell if kind == "rescue" else objective_cell
        if player.pos == target or (not ally.is_empty() and not ally.dead and ally.pos == target):
            objective_done = true
            if kind == "rescue":
                msg = "Survivor found. Get everyone back to the exit."
                emit_noise(target, 9, "struggle", true)
            else:
                msg = "Search complete. Get back to the exit."
                emit_noise(target, 10, "rummaging", true)
    if player.pos == exit_cell:
        if objective_done:
            finish_encounter("escaped")
        else:
            msg = "You still have something to do here."

func interact():
    var p: Vector2i = player.pos + player.facing
    if doors.has(p):
        doors[p] = not doors[p]
        msg = "Door opened." if doors[p] else "Door closed."
        emit_noise(p, 7, "door", true)
        commit_action(65); return
    if glass.has(p):
        glass.erase(p)
        msg = "Glass breaks. Loud."
        emit_noise(p, 52, "breaking glass", true)
        commit_action(100); return
    msg = "Nothing useful there."
    queue_redraw()

func melee(target: Vector2i):
    var zi := zombie_at(target)
    if zi == -1:
        msg = "Nothing in reach."; queue_redraw(); return
    var z = zombies[zi]
    var stealth := stealth_attack(z)
    var combat := int(player.skills.get("Combat", 0))
    var chance = clamp(0.54 + combat * 0.055 - attack_penalty(player) + (0.30 if stealth else 0.0), 0.12, 0.97)
    if rng.randf() <= chance:
        var d = rng.randi_range(int(player.weapon.dmin), int(player.weapon.dmax)) + int(floor(combat / 3.0))
        if stealth: d = int(round(float(d + int(player.weapon.stealth) + combat) * 1.45))
        zombies[zi].hp -= d
        _flash_hit(z.pos, int(zombies[zi].hp) <= 0)
        msg = "%s hit for %d%s." % [player.weapon.name, d, " — STEALTH" if stealth else ""]
        if int(zombies[zi].hp) <= 0: kill_zombie(zi, stealth)
        elif int(player.weapon.push) > 0: push_zombie(zi, player.facing)
    else:
        msg = "%s misses." % player.weapon.name
    emit_noise(player.pos, int(player.weapon.noise), "melee", true)
    commit_action(int(player.weapon.time))

func shoot(i: int):
    if not bool(player.weapon.gun):
        msg = "No firearm equipped."; queue_redraw(); return
    var ammo_cost := int(player.weapon.ammo)
    if not Game.consume_combat_ammo(ammo_cost):
        msg = "No ammunition."; queue_redraw(); return
    var z = zombies[i]
    if z.dead or not visible_cells.has(z.pos): return
    player.facing = dominant(z.pos - player.pos)
    var dist := manhattan(player.pos, z.pos)
    var combat := int(player.skills.get("Combat", 0))
    var chance = clamp(0.52 + combat * 0.06 - max(0, dist - 3) * 0.035 - attack_penalty(player), 0.10, 0.95)
    stats.shots += 1
    _flash_muzzle(player.pos, player.facing)
    if rng.randf() <= chance:
        var d = rng.randi_range(int(player.weapon.gmin), int(player.weapon.gmax)) + int(floor(combat / 2.0))
        if player.weapon.name == "Shotgun" and dist <= 3: d += 4
        zombies[i].hp -= d
        _flash_hit(z.pos, int(zombies[i].hp) <= 0)
        msg = "%s hits for %d." % [player.weapon.name, d]
        if int(zombies[i].hp) <= 0: kill_zombie(i, false)
    else:
        msg = "%s misses." % player.weapon.name
    emit_noise(player.pos, int(player.weapon.gnoise), "gunshot", true)
    commit_action(int(player.weapon.gtime))

func shoot_barrel(cell: Vector2i):
    if not bool(player.weapon.gun):
        msg = "You need a firearm to hit that safely."; queue_redraw(); return
    if not Game.consume_combat_ammo(int(player.weapon.ammo)):
        msg = "No ammunition."; queue_redraw(); return
    barrels.erase(cell)
    stats.shots += 1
    _flash_muzzle(player.pos, player.facing)
    _flash_hit(cell, true)
    msg = "The container erupts."
    for i in range(zombies.size()):
        if zombies[i].dead: continue
        var d = manhattan(cell, zombies[i].pos)
        if d <= 2:
            zombies[i].hp -= 16 - d * 4
            if zombies[i].hp <= 0: kill_zombie(i, false)
    blast_actor(player, cell)
    if not ally.is_empty() and not ally.dead: blast_actor(ally, cell)
    for p in glass.keys().duplicate():
        if manhattan(cell, p) <= 2: glass.erase(p)
    emit_noise(cell, 110, "explosion", true)
    commit_action(150)

func blast_actor(actor: Dictionary, cell: Vector2i):
    var d := manhattan(cell, actor.pos)
    if d > 2: return
    var dmg: int = maxi(2, 13 - d * 4)
    actor.hp -= dmg
    if actor.controlled: stats.damage += dmg
    if actor.hp <= 0:
        actor.hp = 0; actor.dead = true

func stealth_attack(z) -> bool:
    if z.state == "CHASE": return false
    var to_player: Vector2i = player.pos - z.pos
    return dominant(to_player) == -z.facing or not zombie_sees_actor(z, player)

func push_zombie(i: int, dir: Vector2i):
    var dest: Vector2i = zombies[i].pos + dir
    if not blocked(dest) and zombie_at(dest) == -1 and dest != player.pos and not ally_at(dest):
        zombies[i].pos = dest

func kill_zombie(i: int, stealth: bool):
    if zombies[i].dead: return
    zombies[i].dead = true
    zombies[i].hp = 0
    zombies[i].state = "DEAD"
    stats.kills += 1
    if stealth: msg += " Quiet kill."

func commit_action(cost: int):
    if game_over: return
    var target_tick := tick + cost
    while not game_over:
        var next_time := target_tick + 1
        var next_kind := ""
        var next_index := -1
        if not ally.is_empty() and not ally.dead and int(ally.next) <= target_tick and int(ally.next) < next_time:
            next_time = int(ally.next); next_kind = "ally"
        for i in range(zombies.size()):
            if zombies[i].dead: continue
            if int(zombies[i].next) <= target_tick and int(zombies[i].next) < next_time:
                next_time = int(zombies[i].next); next_kind = "zombie"; next_index = i
        if next_kind == "": break
        tick = next_time
        if next_kind == "ally": companion_act()
        else: zombie_act(next_index)
    tick = target_tick
    if int(player.hp) <= 0:
        player.hp = 0; player.dead = true
        finish_encounter("dead")
        return
    recalc_visibility(); refresh_intents(); persist_runtime(); queue_redraw()

func companion_act():
    if ally.is_empty() or ally.dead: return
    var nearest := -1
    var best := 999
    for i in range(zombies.size()):
        if zombies[i].dead: continue
        var d = manhattan(ally.pos, zombies[i].pos)
        if d < best: best = d; nearest = i
    if nearest != -1 and best == 1:
        companion_melee(nearest)
        ally.next = tick + int(ally.weapon.time)
        return
    if manhattan(ally.pos, player.pos) > 1:
        var step = best_step_toward(ally.pos, player.pos, true)
        if step != Vector2i.ZERO:
            ally.facing = step
            ally.pos += step
            emit_noise(ally.pos, 6, "steps", true)
    ally.next = tick + 105

func companion_melee(i: int):
    var combat := int(ally.skills.get("Combat", 0))
    var chance = clamp(0.50 + combat * 0.055 - attack_penalty(ally), 0.15, 0.94)
    if rng.randf() <= chance:
        var d = rng.randi_range(int(ally.weapon.dmin), int(ally.weapon.dmax)) + int(floor(combat / 3.0))
        zombies[i].hp -= d
        _flash_hit(zombies[i].pos, int(zombies[i].hp) <= 0)
        if zombies[i].hp <= 0: kill_zombie(i, false)
    emit_noise(ally.pos, int(ally.weapon.noise), "melee", true)

func zombie_act(i: int):
    if zombies[i].dead: return
    var z = zombies[i]
    var target_actor: Dictionary = choose_zombie_target(z)
    var sees := not target_actor.is_empty()
    if sees:
        z.state = "CHASE"
        z.target = target_actor.pos
        z.heard = target_actor.pos
    elif z.state == "CHASE":
        z.state = "INVESTIGATE"
        z.target = z.heard

    if sees and manhattan(z.pos, target_actor.pos) == 1:
        z.facing = target_actor.pos - z.pos
        zombies[i] = z
        zombie_attack(i, target_actor)
        return

    var moved := false
    if z.state == "CHASE":
        zombies[i] = z
        moved = zombie_move(i, z.target)
    elif z.heard != Vector2i(-1,-1):
        z.state = "INVESTIGATE"
        z.target = z.heard
        zombies[i] = z
        if z.pos == z.target:
            zombies[i].heard = Vector2i(-1,-1)
            zombies[i].target = Vector2i(-1,-1)
            zombies[i].state = "IDLE"
        else:
            moved = zombie_move(i, z.target)
    else:
        if rng.randf() < 0.30:
            var d = DIRS[rng.randi_range(0,3)]
            var p = z.pos + d
            z.facing = d
            if not blocked(p) and zombie_at(p) == -1 and p != player.pos and not ally_at(p):
                z.pos = p; moved = true
        zombies[i] = z
        if rng.randf() < 0.055:
            emit_noise(z.pos, 24, "moan", false)
    if not zombies[i].dead:
        zombies[i].next = tick + (125 if moved else 160)

func choose_zombie_target(z) -> Dictionary:
    var candidates := []
    if zombie_sees_actor(z, player): candidates.append(player)
    if not ally.is_empty() and not ally.dead and zombie_sees_actor(z, ally): candidates.append(ally)
    if candidates.is_empty(): return {}
    var best: Dictionary = candidates[0]
    for a in candidates:
        if manhattan(z.pos, a.pos) < manhattan(z.pos, best.pos): best = a
    return best

func zombie_attack(i: int, target_actor: Dictionary):
    var defense = int(target_actor.skills.get("Combat", 0)) * 0.02 + int(target_actor.skills.get("Survival", 0)) * 0.012
    var hit = clamp(0.67 - defense + (0.08 if float(target_actor.fatigue) >= 80 else 0.0), 0.25, 0.82)
    if rng.randf() <= hit:
        var dmg := rng.randi_range(2, 5)
        var protection := clothing_protection(target_actor.clothing)
        if rng.randf() < protection:
            dmg = max(1, dmg - 2)
        target_actor.hp -= dmg
        _flash_hit(target_actor.pos, int(target_actor.hp) <= 0)
        if target_actor.controlled:
            stats.damage += dmg
            msg = "The infected hits you for %d." % dmg
        else:
            msg = "%s gets hit." % target_actor.name
        if target_actor.hp <= 0:
            target_actor.hp = 0; target_actor.dead = true
    else:
        if target_actor.controlled: msg = "You avoid the grab."
    zombies[i].next = tick + 125

func clothing_protection(name: String) -> float:
    if name != "" and D.GEAR.has(name):
        return float(D.GEAR[name].get("protect", 0.0))
    return 0.0

func zombie_move(i: int, goal: Vector2i) -> bool:
    var z = zombies[i]
    var step = best_step_toward(z.pos, goal, false)
    if step == Vector2i.ZERO:
        zombies[i] = z; return false
    z.facing = step
    z.pos += step
    zombies[i] = z
    return true

func best_step_toward(from: Vector2i, goal: Vector2i, for_ally: bool) -> Vector2i:
    var options := DIRS.duplicate()
    var best := Vector2i.ZERO
    var best_d := manhattan(from, goal)
    for d in options:
        var p = from + d
        if blocked(p) or zombie_at(p) != -1:
            continue
        if p == player.pos and (ally.is_empty() or from != ally.pos): continue
        if not ally.is_empty() and p == ally.pos and from != ally.pos: continue
        var dist = manhattan(p, goal)
        if dist < best_d:
            best_d = dist; best = d
    return best

func emit_noise(source: Vector2i, intensity: int, label: String, player_made: bool):
    stats.noise = max(int(stats.noise), intensity)
    var costs = sound_map(source, intensity)
    for i in range(zombies.size()):
        if zombies[i].dead: continue
        var received = intensity - int(costs.get(zombies[i].pos, 99999))
        if received >= 12 and zombies[i].state != "CHASE":
            zombies[i].state = "INVESTIGATE"
            zombies[i].heard = source
            zombies[i].target = source
    if not player_made:
        var heard = intensity - int(costs.get(player.pos, 99999))
        var awareness = float(player.skills.get("Survival", 0))
        if player.tool == "Flashlight": awareness += 0.5
        if heard + awareness * 2.0 >= 14:
            var fuzz := 4
            if awareness >= 2: fuzz = 3
            if awareness >= 4: fuzz = 2
            if awareness >= 6: fuzz = 1
            if awareness >= 8: fuzz = 0
            var approx = source + Vector2i(rng.randi_range(-fuzz,fuzz), rng.randi_range(-fuzz,fuzz))
            sound_marks.append({"pos": clamp_cell(approx), "source": source, "label": label.to_lower(), "time": tick})
            while sound_marks.size() > 5: sound_marks.pop_front()

func sound_map(source: Vector2i, intensity: int) -> Dictionary:
    var cost := {source: 0}
    var queue := [source]
    while not queue.is_empty():
        var p: Vector2i = queue.pop_front()
        var base := int(cost[p])
        for d in DIRS:
            var n = p + d
            if not inside(n) or walls.has(n): continue
            var step_cost := 6
            if doors.has(n) and not doors[n]: step_cost += 10
            if glass.has(n): step_cost += 5
            var nc := base + step_cost
            if nc > intensity: continue
            if not cost.has(n) or nc < int(cost[n]):
                cost[n] = nc; queue.append(n)
    return cost

func recalc_visibility():
    visible_cells.clear()
    var vr := view_range()
    for y in range(H):
        for x in range(W):
            var p = Vector2i(x,y)
            if p == player.pos or (manhattan(player.pos,p) <= vr and in_cone(player.pos, player.facing, p, vr, -0.10) and line_clear(player.pos,p)):
                visible_cells[p] = true
                memory[p] = true
    for i in range(zombies.size()):
        if zombies[i].dead:
            last_seen.erase(i); continue
        if visible_cells.has(zombies[i].pos):
            last_seen[i] = zombies[i].pos
        elif last_seen.has(i) and visible_cells.has(last_seen[i]):
            last_seen.erase(i)

func view_range() -> int:
    var r := 6 + int(floor(int(player.skills.get("Survival",0)) / 3.0))
    if player.tool == "Flashlight": r += 2
    if float(player.fatigue) >= 80: r -= 1
    return clamp(r, 5, 10)

func refresh_intents():
    intent_reads.clear()
    var awareness := int(player.skills.get("Survival", 0))
    for i in range(zombies.size()):
        var z = zombies[i]
        if z.dead or not visible_cells.has(z.pos): continue
        if zombie_sees_actor(z, player):
            intent_reads[i] = ""
        elif awareness < 2:
            intent_reads[i] = "?"
        else:
            var chance = clamp(0.30 + awareness * 0.07 - float(player.stress) * 0.0025, 0.2, 0.95)
            intent_reads[i] = ("SEARCH" if z.state == "INVESTIGATE" else "IDLE") if rng.randf() <= chance else "?"

func zombie_sees_actor(z, actor: Dictionary) -> bool:
    if actor.is_empty() or actor.get("dead", false): return false
    var dist := manhattan(z.pos, actor.pos)
    if dist > 6: return false
    if actor.get("crouched", false) and dist > 3: return false
    return in_cone(z.pos, z.facing, actor.pos, 6, 0.0) and line_clear(z.pos, actor.pos)

func any_zombie_sees_player() -> bool:
    for z in zombies:
        if not z.dead and zombie_sees_actor(z, player): return true
    return false

func line_clear(a: Vector2i, b: Vector2i) -> bool:
    var x0=a.x; var y0=a.y; var x1=b.x; var y1=b.y
    var dx=abs(x1-x0); var sx=1 if x0<x1 else -1
    var dy=-abs(y1-y0); var sy=1 if y0<y1 else -1
    var err=dx+dy
    while true:
        var p=Vector2i(x0,y0)
        if p != a and p != b:
            if walls.has(p) or obstacles.has(p) or glass.has(p) or (doors.has(p) and not doors[p]): return false
        if x0==x1 and y0==y1: break
        var e2=2*err
        if e2>=dy: err+=dy; x0+=sx
        if e2<=dx: err+=dx; y0+=sy
    return true

func in_cone(origin: Vector2i, facing: Vector2i, p: Vector2i, max_range: int, min_dot: float) -> bool:
    var diff := Vector2(p - origin)
    if diff.length() == 0: return true
    if manhattan(origin,p) > max_range: return false
    return Vector2(facing).normalized().dot(diff.normalized()) >= min_dot

func attack_penalty(actor: Dictionary) -> float:
    var penalty := 0.0
    if float(actor.fatigue) >= 80: penalty += 0.12
    elif float(actor.fatigue) >= 60: penalty += 0.06
    if float(actor.stress) >= 80: penalty += 0.08
    elif float(actor.stress) >= 55: penalty += 0.04
    if actor.get("condition", "Healthy") == "Wounded": penalty += 0.08
    elif actor.get("condition", "Healthy") == "Critical": penalty += 0.16
    return penalty

func finish_encounter(outcome: String):
    if game_over: return
    game_over = true
    persist_runtime()
    var result = {
        "outcome": outcome,
        "kind": str(context.get("kind", "ambush")),
        "objective_done": objective_done,
        "rescued": objective_done and str(context.get("kind", "")) == "rescue",
        "lead_hp": int(player.get("hp",0)), "lead_max_hp": int(player.get("max_hp",18)),
        "companion_hp": int(ally.get("hp",-1)) if not ally.is_empty() else -1,
        "companion_max_hp": int(ally.get("max_hp",-1)) if not ally.is_empty() else -1,
        "kills": int(stats.kills), "shots": int(stats.shots), "damage": int(stats.damage)
    }
    encounter_finished.emit(result)

func blocked(p: Vector2i) -> bool:
    if not inside(p): return true
    if walls.has(p) or obstacles.has(p) or glass.has(p): return true
    if doors.has(p) and not doors[p]: return true
    return false

func inside(p: Vector2i) -> bool:
    return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H

func zombie_at(p: Vector2i) -> int:
    for i in range(zombies.size()):
        if not zombies[i].dead and zombies[i].pos == p: return i
    return -1

func ally_at(p: Vector2i) -> bool:
    return not ally.is_empty() and not ally.dead and ally.pos == p

func manhattan(a: Vector2i, b: Vector2i) -> int:
    return abs(a.x-b.x)+abs(a.y-b.y)

func dominant(v: Vector2i) -> Vector2i:
    if abs(v.x) >= abs(v.y): return Vector2i(1 if v.x>=0 else -1,0)
    return Vector2i(0,1 if v.y>=0 else -1)

func clamp_cell(p: Vector2i) -> Vector2i:
    return Vector2i(clamp(p.x,1,W-2), clamp(p.y,1,H-2))

func map_origin() -> Vector2:
    var map_width := float(W * TILE)
    var player_center := (float(player.pos.x) + 0.5) * TILE
    var ideal_x := SCREEN_W * 0.5 - player_center
    var x: float = clampf(ideal_x, SCREEN_W - map_width, 0.0)
    return Vector2(x, MAP_TOP)

func screen_to_cell(pos: Vector2) -> Vector2i:
    var local = pos - map_origin()
    return Vector2i(int(floor(local.x / TILE)), int(floor(local.y / TILE)))

func cell_center(p: Vector2i) -> Vector2:
    return Vector2(float(p.x*TILE + TILE/2), float(p.y*TILE + TILE/2))

func _draw():
    if not initialized: return
    draw_rect(Rect2(0,0,SCREEN_W,SCREEN_H), Color("0b1011"))
    var origin := map_origin()
    draw_set_transform(origin)
    draw_map()
    draw_units()
    draw_fog()
    draw_sounds()
    draw_character_fx()
    draw_set_transform(Vector2.ZERO)
    draw_hud()

func draw_map():
    for y in range(H):
        for x in range(W):
            var p=Vector2i(x,y)
            var r=Rect2(x*TILE,y*TILE,TILE,TILE)
            draw_rect(r, Color(.10,.12,.11))
            draw_rect(r, Color(.17,.19,.18), false, 1)
            if walls.has(p): draw_rect(r, Color(.25,.27,.25))
            elif obstacles.has(p): draw_rect(r.grow(-3), Color(.28,.23,.17))
            elif glass.has(p):
                draw_line(r.position+Vector2(3,TILE-4), r.position+Vector2(TILE-3,4), Color(.55,.75,.82), 2)
            elif doors.has(p):
                draw_rect(r.grow(-4), Color(.34,.24,.14) if not doors[p] else Color(.18,.15,.11), false, 3)
            elif barrels.has(p):
                draw_circle(cell_center(p), 8, Color(.55,.25,.10))
    draw_rect(Rect2(exit_cell.x*TILE+4,exit_cell.y*TILE+4,TILE-8,TILE-8), Color(.18,.58,.30), false, 3)
    var kind := str(context.get("kind","ambush"))
    if kind == "explore" and not objective_done:
        draw_rect(Rect2(objective_cell.x*TILE+5,objective_cell.y*TILE+5,TILE-10,TILE-10), Color(.95,.75,.20), false, 3)
    elif kind == "rescue" and not objective_done:
        draw_circle(cell_center(rescue_cell), 8, Color(.95,.75,.20), false, 3)
        draw_string(font, cell_center(rescue_cell)+Vector2(-9,-12), "SOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.95,.8,.35))

func draw_units():
    for key in last_seen.keys():
        var i := int(key)
        if i < 0 or i >= zombies.size() or zombies[i].dead or visible_cells.has(zombies[i].pos):
            continue
        var c := cell_center(last_seen[i])
        draw_circle(c, 8, Color(.55, .58, .55, .5), false, 2)
        draw_string(font, c + Vector2(-10, -11), "LAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(.65, .68, .65, .75))

    for i in range(zombies.size()):
        var z: Dictionary = zombies[i]
        if z.dead:
            if visible_cells.has(z.pos):
                TacticalVisuals.draw_zombie_corpse(self, cell_center(z.pos), z)
            continue
        if not visible_cells.has(z.pos):
            continue
        TacticalVisuals.draw_zombie(self, cell_center(z.pos), z)
        var c := cell_center(z.pos)
        if zombie_sees_actor(z, player):
            draw_circle(c, 12, Color(1, .17, .12, .92), false, 2)
        else:
            var intent_text := str(intent_reads.get(i, "?"))
            if intent_text != "":
                draw_string(font, c + Vector2(-16, -12), intent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .84, .35))

    if not ally.is_empty() and visible_cells.has(ally.pos):
        if ally.dead:
            TacticalVisuals.draw_survivor_corpse(self, cell_center(ally.pos), ally)
        else:
            TacticalVisuals.draw_survivor(self, cell_center(ally.pos), ally, false)

    if not player.is_empty():
        TacticalVisuals.draw_survivor(self, cell_center(player.pos), player, true)

func _flash_hit(cell: Vector2i, lethal := false):
    hit_flash_cell = cell
    hit_flash_until_ms = Time.get_ticks_msec() + (170 if lethal else 110)
    fx_active_last_frame = true
    queue_redraw()

func _flash_muzzle(cell: Vector2i, facing: Vector2i):
    muzzle_flash_cell = cell
    muzzle_flash_facing = facing
    muzzle_flash_until_ms = Time.get_ticks_msec() + 90
    fx_active_last_frame = true
    queue_redraw()

func draw_character_fx():
    var now := Time.get_ticks_msec()
    if hit_flash_cell != Vector2i(-1, -1):
        TacticalVisuals.draw_hit_flash(self, cell_center(hit_flash_cell), now, hit_flash_until_ms)
    if muzzle_flash_cell != Vector2i(-1, -1):
        TacticalVisuals.draw_muzzle_flash(self, cell_center(muzzle_flash_cell), muzzle_flash_facing, now, muzzle_flash_until_ms)

func draw_fog():
    for y in range(H):
        for x in range(W):
            var p=Vector2i(x,y)
            if visible_cells.has(p): continue
            var alpha=.50 if memory.has(p) else .92
            draw_rect(Rect2(x*TILE,y*TILE,TILE,TILE),Color(0.01,0.015,0.015,alpha))

func draw_sounds():
    for s in sound_marks:
        if tick-int(s.time)>650: continue
        if s.has("source") and visible_cells.has(s.source): continue
        var c=cell_center(s.pos)
        draw_string(font,c+Vector2(-20,4),str(s.label),HORIZONTAL_ALIGNMENT_CENTER,40,9,Color(.98,.85,.36))

func draw_hud():
    draw_rect(Rect2(0,0,SCREEN_W,INFO_H),Color(.035,.045,.04,.99))
    draw_string(font,Vector2(10,22),location_name,HORIZONTAL_ALIGNMENT_LEFT,370,17,Color.WHITE)
    draw_string(font,Vector2(10,47),"%s  HP %d/%d  %s"%[player.name,int(player.hp),int(player.max_hp),str(player.condition).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,370,13,Color(.70,.84,1))
    var gear_line="%s"%player.weapon.name
    if bool(player.weapon.gun): gear_line += "  |  Ammo %d"%int(Game.resources.get("Ammo",0))
    if player.clothing!="": gear_line += "  |  %s"%player.clothing
    draw_string(font,Vector2(10,69),gear_line,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color(.82,.84,.82))
    if not ally.is_empty():
        draw_string(font,Vector2(10,90),"With: %s  HP %d/%d  %s"%[ally.name,int(ally.hp),int(ally.max_hp),"DOWN" if ally.dead else ally.weapon.name],HORIZONTAL_ALIGNMENT_LEFT,370,10,Color(.76,.64,.90))
    var objective_text := "ESCAPE"
    match str(context.get("kind","ambush")):
        "rescue": objective_text = "RESCUE + ESCAPE" if not objective_done else "ESCAPE WITH SURVIVOR"
        "explore": objective_text = "SEARCH + ESCAPE" if not objective_done else "ESCAPE"
    draw_string(font,Vector2(10,112),"Objective: %s"%objective_text,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color(.96,.80,.34))
    draw_string(font,Vector2(10,133),msg,HORIZONTAL_ALIGNMENT_LEFT,370,10,Color(.93,.94,.90))
    if any_zombie_sees_player():
        draw_string(font,Vector2(0,MAP_TOP+20),"!! SPOTTED !!",HORIZONTAL_ALIGNMENT_CENTER,SCREEN_W,18,Color(1,.22,.16))

    draw_rect(Rect2(0,CONTROL_TOP,SCREEN_W,SCREEN_H-CONTROL_TOP),Color(.025,.032,.028,.94))
    draw_rect(Rect2(0,CONTROL_TOP,SCREEN_W,2),Color(.38,.42,.38))
    draw_button(btn_turn_left,"TURN L",false,17)
    draw_button(btn_crouch,"CROUCH",player.crouched,11)
    draw_button(btn_forward,"FORWARD",false,11)
    draw_button(btn_turn_right,"TURN R",false,17)
    draw_button(btn_back,"BACK",false,11)
    draw_string(font,Vector2(148,724),"K %d\nT %d"%[int(stats.kills),tick],HORIZONTAL_ALIGNMENT_CENTER,98,9,Color(.55,.60,.56))

func draw_button(rect: Rect2, text: String, active: bool, size: int):
    var fill=Color(.24,.30,.25,.96) if active else Color(.08,.10,.09,.94)
    var edge=Color(.95,.8,.36) if active else Color(.70,.74,.70)
    draw_rect(rect,fill); draw_rect(rect,edge,false,2)
    var y=rect.position.y+rect.size.y*.5+float(size)*.34
    draw_string(font,Vector2(rect.position.x,y),text,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,size,Color.WHITE)
