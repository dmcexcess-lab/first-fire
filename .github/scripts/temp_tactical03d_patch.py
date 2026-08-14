from pathlib import Path
import re

ROOT = Path('.')


def read(path):
    return (ROOT / path).read_text()


def write(path, text):
    (ROOT / path).write_text(text)


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    return text.replace(old, new, 1)


def replace_func(text, name, next_name, body):
    pattern = rf'func {re.escape(name)}\b.*?(?=\nfunc {re.escape(next_name)}\b)'
    new_text, count = re.subn(pattern, body.rstrip() + '\n', text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'function {name}: expected one block, found {count}')
    return new_text


# ---------------------------------------------------------------------------
# Data: secondary light variety and explicit Alpha schema-era gear.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFData.gd'
t = read(path)
t = replace_once(
    t,
    '    "Flashlight": {"slot": "Secondary", "size": 2, "tool": "Light", "light": "cone", "light_range": 10.0, "light_spread": 0.52, "light_strength": 1.0, "light_color": "edf5d6", "view_bonus": 2},',
    '    "Flashlight": {"slot": "Secondary", "size": 2, "weight": 0.8, "light": "cone", "light_range": 8.5, "light_spread": 0.52, "light_strength": 1.0, "light_color": "edf5d6", "view_bonus": 2},\n'
    '    "Headlamp": {"slot": "Secondary", "size": 1, "weight": 0.4, "light": "cone", "light_range": 7.0, "light_spread": 0.34, "light_strength": 0.88, "light_color": "f1edc5", "view_bonus": 1},\n'
    '    "Lantern": {"slot": "Secondary", "size": 2, "weight": 1.4, "light": "radial", "light_range": 4.5, "light_strength": 0.88, "light_color": "ffc46f", "view_bonus": 0},\n'
    '    "Glow Stick": {"slot": "Secondary", "size": 1, "weight": 0.2, "light": "radial", "light_range": 3.0, "light_strength": 0.58, "light_color": "71ef68", "view_bonus": 0},\n'
    '    "Road Flare": {"slot": "Secondary", "size": 1, "weight": 0.3, "light": "radial", "light_range": 4.8, "light_strength": 0.92, "light_color": "ff5b48", "view_bonus": 0},',
    'secondary lighting items',
)
t = replace_once(
    t,
    '        {"id": "Flashlight", "time": 7.0, "cost": {"Plastic": 1, "Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Flashlight"},\n        {"id": "Hammer",',
    '        {"id": "Flashlight", "time": 7.0, "cost": {"Plastic": 1, "Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Flashlight"},\n'
    '        {"id": "Headlamp", "time": 8.0, "cost": {"Plastic": 1, "Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Headlamp"},\n'
    '        {"id": "Lantern", "time": 9.0, "cost": {"Scrap Metal": 1, "Hardware": 2}, "gives_gear": "Lantern"},\n'
    '        {"id": "Hammer",',
    'lighting recipes',
)
write(path, t)


# ---------------------------------------------------------------------------
# Game: schema 5, Secondary on every new survivor, random scene state, loot.
# ---------------------------------------------------------------------------
path = 'game/scripts/Game.gd'
t = read(path)
t = replace_once(t, 'const SAVE_SCHEMA_VERSION := 4', 'const SAVE_SCHEMA_VERSION := 5', 'schema 5')
t = t.replace('# Legacy filename is intentionally preserved so this behavior-only refactor does not reset Alpha saves.\n', '# Alpha saves are disposable; the filename remains stable while schema changes invalidate old state cleanly.\n')
t = replace_once(
    t,
    'founder["equipment"] = {"Weapon": "Utility Knife", "Clothing": "", "Pack": "Worn Backpack", "Tool": ""}',
    'founder["equipment"] = {"Weapon": "Utility Knife", "Secondary": "", "Clothing": "", "Pack": "Worn Backpack", "Tool": ""}',
    'founder secondary',
)
t = replace_once(
    t,
    '"equipment": {"Weapon": "", "Clothing": "", "Pack": "", "Tool": ""},',
    '"equipment": {"Weapon": "", "Secondary": "", "Clothing": "", "Pack": "", "Tool": ""},',
    'generated survivor secondary',
)
t = replace_once(
    t,
    '    var environment_variant := TacticalScenarios.environment_variant(environment_id, rng)\n    current_combat = {',
    '    var environment_variant := TacticalScenarios.environment_variant(environment_id, rng)\n    var scene_state: Dictionary = TacticalScenarios.pick_scene_state(environment_id, rng)\n    current_combat = {',
    'scene state selection',
)
t = replace_once(
    t,
    '        "environment_variant": environment_variant,\n        "location_name": TacticalScenarios.environment_name(environment_id),',
    '        "environment_variant": environment_variant,\n        "time_of_day": str(scene_state.get("time_of_day", "day")),\n        "power_on": bool(scene_state.get("power_on", false)),\n        "location_name": TacticalScenarios.environment_name(environment_id),',
    'scene state context',
)
t = t.replace(
    'pool = ["Kitchen Knife", "Work Gloves", "Heavy Boots", "School Backpack"]',
    'pool = ["Kitchen Knife", "Work Gloves", "Heavy Boots", "School Backpack", "Glow Stick"]'
)
t = t.replace(
    'pool = ["Kitchen Knife", "Baseball Bat", "Flashlight", "Screwdriver Set", "First Aid Kit", "School Backpack", "Leather Jacket"]',
    'pool = ["Kitchen Knife", "Baseball Bat", "Flashlight", "Lantern", "Glow Stick", "Screwdriver Set", "First Aid Kit", "School Backpack", "Leather Jacket"]'
)
t = t.replace(
    'pool = ["Crowbar", "Hatchet", "Flashlight", "Bolt Cutters", "Toolbox", "First Aid Kit", "Pistol", "Hiking Pack", "Leather Jacket"]',
    'pool = ["Crowbar", "Hatchet", "Flashlight", "Headlamp", "Lantern", "Road Flare", "Bolt Cutters", "Toolbox", "First Aid Kit", "Pistol", "Hiking Pack", "Leather Jacket"]'
)
t = t.replace(
    'pool = ["Crowbar", "Hatchet", "Bolt Cutters", "Toolbox", "Pistol", "Shotgun", "Hiking Pack", "Heavy Boots", "Work Jacket"]',
    'pool = ["Crowbar", "Hatchet", "Headlamp", "Glow Stick", "Road Flare", "Bolt Cutters", "Toolbox", "Pistol", "Shotgun", "Hiking Pack", "Heavy Boots", "Work Jacket"]'
)
write(path, t)


# ---------------------------------------------------------------------------
# Inspector: show the expanded Secondary family and encumbrance metadata.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFInspector.gd'
t = read(path)
t = replace_once(
    t,
    '    "Flashlight": "Portable directional field light. Equip it in Secondary so a survivor can carry it alongside both a weapon and a general Tool. Tactical maps render its beam and extended view range.",',
    '    "Flashlight": "Focused handheld beam with the longest Secondary reach. Strong at cutting a path through darkness, but narrow enough that facing matters.",\n'
    '    "Headlamp": "Shorter, wider directional light. Easier to keep useful while moving and turning, but it does not reach as far as a flashlight.",\n'
    '    "Lantern": "Warm radial light that illuminates the survivor in every direction. Excellent for rooms, but it also makes the carrier easy to see.",\n'
    '    "Glow Stick": "Compact green radial marker light. Weak and short-ranged, but light enough to carry when a full lamp is unnecessary.",\n'
    '    "Road Flare": "Bright red radial field light. Strong local illumination with no directional blind side.",',
    'lighting item notes',
)
t = replace_once(
    t,
    '        body.add_child(_make_label("Inventory size: %d" % int(data.get("size", 0)), 13))',
    '        if data.has("weight"):\n            body.add_child(_make_label("Carried weight: %.1f" % float(data.get("weight", 0.0)), 13))\n        body.add_child(_make_label("Inventory size: %d" % int(data.get("size", 0)), 13))',
    'item weight display',
)
# Schema 5 has no legacy Tool-slot flashlight path.
t = t.replace(
    '    var legacy_secondary: String = ""\n    if str(equipment.get("Secondary", "")) == "" and str(equipment.get("Tool", "")) == "Flashlight":\n        legacy_secondary = "Flashlight"\n',
    ''
)
t = t.replace(
    '        if slot == "Secondary" and gear_name == "" and legacy_secondary != "":\n            gear_name = legacy_secondary\n        elif slot == "Tool" and gear_name == "Flashlight" and legacy_secondary != "":\n            gear_name = ""\n',
    ''
)
write(path, t)


# ---------------------------------------------------------------------------
# Environment physical logic: power probabilities, interiors, occluders, spawn
# validation. Geometry remains authored; appearance is handled by the atlas.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFTacticalEnvironments.gd'
t = read(path)
for key, chance in [
    ('back_alley', '0.28'), ('gas_station', '0.52'), ('house', '0.22'),
    ('apartment', '0.42'), ('corner_store', '0.48'), ('warehouse_yard', '0.30'),
    ('drainage_wash', '0.00')]:
    pattern = rf'("{key}": \{{.*?"kinds": \[[^\n]+\],\n)(\s+"variants": 2,)'
    repl = rf'\1        "power_chance": {chance},\n\2'
    t, count = re.subn(pattern, repl, t, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'power chance {key}: {count}')

t = replace_once(
    t,
    'static func all_ids() -> Array:\n',
    'const OPAQUE_PROPS := ["dumpster", "car", "store_shelf", "fridge", "crate", "forklift", "machine", "ice_box"]\n\n'
    'static func all_ids() -> Array:\n',
    'opaque prop catalog',
)
t = replace_once(
    t,
    'static func theme_name(environment_id: String) -> String:\n    var data: Dictionary = CATALOG.get(environment_id, CATALOG["back_alley"])\n    return str(data.get("theme", "alley"))\n',
    'static func theme_name(environment_id: String) -> String:\n    var data: Dictionary = CATALOG.get(environment_id, CATALOG["back_alley"])\n    return str(data.get("theme", "alley"))\n\n'
    'static func power_chance(environment_id: String) -> float:\n    var data: Dictionary = CATALOG.get(environment_id, CATALOG["back_alley"])\n    return clampf(float(data.get("power_chance", 0.0)), 0.0, 1.0)\n\n'
    'static func prop_blocks_sight(prop_kind: String) -> bool:\n    return OPAQUE_PROPS.has(prop_kind)\n',
    'environment metadata helpers',
)
validate = '''static func validate_layout(spec: Dictionary) -> bool:
    var spawn: Vector2i = spec.get("player_spawn", Vector2i(-1, -1))
    var ally_spawn: Vector2i = spec.get("ally_spawn", Vector2i(-1, -1))
    var exits: Array = spec.get("exit_cells", [])
    if exits.is_empty() or not _inside(spawn) or not _inside(ally_spawn) or spawn == ally_spawn:
        return false
    var blocked := {}
    for p in spec.get("walls", []): blocked[p] = true
    for p in spec.get("obstacles", []): blocked[p] = true
    for p in spec.get("glass", []): blocked[p] = true
    if blocked.has(spawn) or blocked.has(ally_spawn):
        return false
    for entry in spec.get("doors", []):
        var door_pos: Vector2i = entry[0]
        if door_pos == spawn or door_pos == ally_spawn:
            return false
    for exit_cell in exits:
        if not _inside(exit_cell) or blocked.has(exit_cell):
            return false
    for entry_value in spec.get("lights", []):
        var entry: Array = entry_value
        if entry.size() < 2 or not _inside(entry[0]):
            return false
    var seen := {spawn: true}
    var queue: Array = [spawn]
    while not queue.is_empty():
        var p: Vector2i = queue.pop_front()
        for d in [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]:
            var n: Vector2i = p + d
            if not _inside(n) or spec.get("walls", []).has(n) or spec.get("obstacles", []).has(n) or seen.has(n):
                continue
            seen[n] = true
            queue.append(n)
    if not seen.has(ally_spawn):
        return false
    for exit_cell in exits:
        if not seen.has(exit_cell):
            return false
    return true
'''
t = replace_func(t, 'validate_layout', '_inside', validate)
t = replace_once(t, '        "ground_rects": [],\n        "walls": [],', '        "ground_rects": [],\n        "indoor_rects": [],\n        "walls": [],', 'indoor rect storage')
t = replace_once(
    t,
    'static func _ground(spec: Dictionary, x: int, y: int, w: int, h: int, kind: String) -> void:\n    spec["ground_rects"].append([x, y, w, h, kind])\n',
    'static func _ground(spec: Dictionary, x: int, y: int, w: int, h: int, kind: String) -> void:\n    spec["ground_rects"].append([x, y, w, h, kind])\n\n'
    'static func _indoor(spec: Dictionary, x: int, y: int, w: int, h: int) -> void:\n    spec["indoor_rects"].append([x, y, w, h])\n',
    'indoor helper',
)
t = replace_once(
    t,
    'static func _light(spec: Dictionary, p: Vector2i, light_kind: String) -> void:\n    spec["lights"].append([p, light_kind])',
    'static func _light(spec: Dictionary, p: Vector2i, light_kind: String, requires_power := true) -> void:\n    spec["lights"].append([p, light_kind, requires_power])',
    'power-aware fixed lights',
)
# Author interior footprints independent of floor texture.
for old, new, label in [
    ('    _ground(spec, 11, 2, 8, 9, "tile")', '    _ground(spec, 11, 2, 8, 9, "tile")\n    _indoor(spec, 11, 2, 8, 9)', 'gas interior'),
    ('    _ground(spec, 13, 3, 4, 5, "linoleum")', '    _ground(spec, 13, 3, 4, 5, "linoleum")\n    _indoor(spec, 5, 2, 13, 13)', 'house interior'),
    ('    _ground(spec, 8, 2, 3, 13, "concrete")', '    _ground(spec, 8, 2, 3, 13, "concrete")\n    _indoor(spec, 3, 2, 15, 13)', 'apartment interior'),
    ('    _ground(spec, 4, 3, 15, 11, "tile")', '    _ground(spec, 4, 3, 15, 11, "tile")\n    _indoor(spec, 4, 3, 15, 11)', 'store interior'),
    ('    _ground(spec, 10, 2, 9, 9, "concrete")', '    _ground(spec, 10, 2, 9, 9, "concrete")\n    _indoor(spec, 10, 2, 9, 9)', 'warehouse interior'),
]:
    t = replace_once(t, old, new, label)
write(path, t)


# ---------------------------------------------------------------------------
# Combat: atlas drawing, real light/perception coupling, weighted action time,
# localized sound, group awareness, and tap-to-interact doors.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFCombat.gd'
t = read(path)
t = replace_once(
    t,
    'const TacticalLighting = preload("res://scripts/FFTacticalLighting.gd")',
    'const TacticalLighting = preload("res://scripts/FFTacticalLighting.gd")\n'
    'const TacticalTiles = preload("res://scripts/FFTacticalTiles.gd")\n'
    'const TacticalTime = preload("res://scripts/FFTacticalTime.gd")\n'
    'const TacticalSound = preload("res://scripts/FFTacticalSound.gd")',
    'combat module preloads',
)
t = replace_once(
    t,
    'var props := {}\nvar ground := {}\nvar light_sources: Array = []',
    'var props := {}\nvar ground := {}\nvar indoor_cells := {}\nvar opaque_obstacles := {}\nvar light_sources: Array = []',
    'combat physical maps',
)
t = replace_once(
    t,
    'var environment_id := "back_alley"\nvar objective_cell',
    'var environment_id := "back_alley"\nvar scene_time := "day"\nvar power_on := false\nvar objective_cell',
    'scene state vars',
)
t = replace_once(
    t,
    '    set_process_input(true)\n    set_process(true)',
    '    set_process_input(true)\n    set_process(true)\n    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST',
    'nearest atlas filter',
)
t = t.replace('TacticalLighting.has_animated_sources(light_sources)', 'TacticalLighting.has_animated_sources(light_sources, power_on)')
t = replace_once(
    t,
    '    location_name = str(context.get("location_name", TacticalEnvironments.display_name(environment_id)))\n    build_map(environment_id, environment_variant)',
    '    location_name = str(context.get("location_name", TacticalEnvironments.display_name(environment_id)))\n    scene_time = str(context.get("time_of_day", "day"))\n    power_on = bool(context.get("power_on", false))\n    build_map(environment_id, environment_variant)',
    'combat scene state load',
)

build_map = '''func build_map(new_environment_id: String, variant: int):
    environment_id = new_environment_id
    walls.clear(); obstacles.clear(); glass.clear(); doors.clear(); barrels.clear(); props.clear(); ground.clear(); indoor_cells.clear(); opaque_obstacles.clear(); exit_cells.clear(); light_sources.clear(); light_levels.clear(); light_tints.clear()
    for x in range(W):
        walls[Vector2i(x, 0)] = true
        walls[Vector2i(x, H - 1)] = true
    for y in range(H):
        walls[Vector2i(0, y)] = true
        walls[Vector2i(W - 1, y)] = true

    var spec: Dictionary = TacticalEnvironments.build_layout(environment_id, variant)
    player_spawn = spec.get("player_spawn", Vector2i(2, H - 2))
    ally_spawn = spec.get("ally_spawn", Vector2i(2, H - 3))
    exit_cells = spec.get("exit_cells", [Vector2i(1, H - 2)]).duplicate()
    var default_ground := str(spec.get("default_ground", TacticalEnvironments.default_ground(environment_id)))
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            ground[Vector2i(x, y)] = default_ground
    for entry in spec.get("ground_rects", []):
        var gx := int(entry[0]); var gy := int(entry[1]); var gw := int(entry[2]); var gh := int(entry[3]); var ground_kind := str(entry[4])
        for y in range(gy, gy + gh):
            for x in range(gx, gx + gw):
                var gp := Vector2i(x, y)
                if inside(gp): ground[gp] = ground_kind
    for entry in spec.get("indoor_rects", []):
        for y in range(int(entry[1]), int(entry[1]) + int(entry[3])):
            for x in range(int(entry[0]), int(entry[0]) + int(entry[2])):
                var ip := Vector2i(x, y)
                if inside(ip): indoor_cells[ip] = true
    for p in spec.get("walls", []): walls[p] = true
    for p in spec.get("obstacles", []): obstacles[p] = true
    for p in spec.get("glass", []): glass[p] = true
    for entry in spec.get("doors", []): doors[entry[0]] = bool(entry[1])
    for p in spec.get("barrels", []): barrels[p] = true
    for entry in spec.get("props", []):
        var prop_pos: Vector2i = entry[0]
        var prop_kind := str(entry[1])
        props[prop_pos] = prop_kind
        if TacticalEnvironments.prop_blocks_sight(prop_kind): opaque_obstacles[prop_pos] = true
    for p in obstacles.keys():
        if not props.has(p): opaque_obstacles[p] = true
    for entry_value in spec.get("lights", []):
        var light_entry: Array = entry_value
        var light_pos: Vector2i = light_entry[0]
        var requires_power := bool(light_entry[2]) if light_entry.size() >= 3 else true
        light_sources.append(TacticalLighting.make_source(light_pos, str(light_entry[1]), light_sources.size(), requires_power))

    base_glass = glass.duplicate(true)
    base_barrels = barrels.duplicate(true)
    objective_cell = choose_far_open_cell()
    rescue_cell = objective_cell
'''
t = replace_func(t, 'build_map', 'choose_far_open_cell', build_map)

spawn = '''func spawn_zombies():
    zombies.clear()
    var zone := str(context.get("zone", "Nearby Streets"))
    var count: int = int({"Camp Perimeter": 3, "Nearby Streets": 4, "Residential Blocks": 5, "Commercial Fringe": 6, "Industrial Edge": 7}.get(zone, 4))
    if context.get("kind", "") == "ambush": count += 1
    var candidates := []
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            var p := Vector2i(x, y)
            if blocked(p) or p == player.get("pos", player_spawn) or p == ally.get("pos", Vector2i(-1,-1)):
                continue
            var d := manhattan(player_spawn, p)
            if context.get("kind", "") == "ambush":
                if d >= 4 and d <= 11: candidates.append(p)
            elif d >= 7:
                candidates.append(p)
    for i in range(count):
        if candidates.is_empty(): break
        var pick := rng.randi_range(0, candidates.size() - 1)
        var p: Vector2i = candidates[pick]
        candidates.remove_at(pick)
        var state := "INVESTIGATE" if context.get("kind", "") == "ambush" and i < 2 else "IDLE"
        var look: Dictionary = TacticalVisuals.zombie_appearance(rng, zone)
        var timing: Dictionary = TacticalTime.zombie_profile(rng, look)
        zombies.append({
            "id": i, "pos": p, "facing": DIRS[rng.randi_range(0,3)],
            "hp": rng.randi_range(8, 13), "state": state,
            "target": player_spawn if state == "INVESTIGATE" else Vector2i(-1,-1),
            "heard": player_spawn if state == "INVESTIGATE" else Vector2i(-1,-1),
            "pace": int(timing.get("pace", 125)), "attack_cost": int(timing.get("attack_cost", 135)), "mass": str(timing.get("mass", "MED")),
            "next": rng.randi_range(45, int(timing.get("pace", 125))), "dead": false,
            "look": look
        })
'''
t = replace_func(t, 'spawn_zombies', 'restore_runtime', spawn)

# Touch: tapping an adjacent door means USE, never accidental movement through it.
dispatch = '''func dispatch_point(pos: Vector2):
    if game_over: return
    if btn_turn_left.has_point(pos):
        guarded_action("TURN_L", func(): rotate_player(-1)); return
    if btn_turn_right.has_point(pos):
        guarded_action("TURN_R", func(): rotate_player(1)); return
    if btn_forward.has_point(pos): step_forward(); return
    if btn_back.has_point(pos): step_backward(); return
    if btn_crouch.has_point(pos): toggle_crouch(); return
    if pos.y < MAP_TOP or pos.y >= CONTROL_TOP: return
    var cell := screen_to_cell(pos)
    if not inside(cell): return
    var delta: Vector2i = cell - player.pos
    if manhattan(player.pos, cell) == 1:
        player.facing = delta
        if zombie_at(cell) != -1: melee(cell); return
        if doors.has(cell): interact(); return
        if glass.has(cell): interact(); return
        try_move(delta); return
    if visible_cells.has(cell):
        var zi := zombie_at(cell)
        if zi != -1:
            if bool(player.weapon.gun): shoot(zi)
            else:
                msg = "Too far for %s." % player.weapon.name
                queue_redraw()
            return
        if barrels.has(cell): shoot_barrel(cell); return
'''
t = replace_func(t, 'dispatch_point', 'guarded_action', dispatch)

t = replace_func(t, 'rotate_player', 'step_forward', '''func rotate_player(step: int):
    var idx := DIRS.find(player.facing)
    idx = posmod(idx + step, 4)
    player.facing = DIRS[idx]
    player.last_dir = Vector2i.ZERO
    player.move_state = "STILL"
    msg = "Turned %s." % DIR_NAMES[idx]
    commit_action(TacticalTime.turn_cost(player))
''')

t = replace_func(t, 'step_backward', 'toggle_crouch', '''func step_backward():
    var keep: Vector2i = player.facing
    var dest := player.pos - keep
    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest):
        msg = "Blocked behind you."
        queue_redraw(); return
    player.pos = dest
    player.facing = keep
    player.last_dir = Vector2i.ZERO
    player.move_state = "CROUCH" if player.crouched else "WALK"
    var noise := 7 if player.crouched else 17
    if player.clothing == "Heavy Boots": noise += 4
    emit_noise(dest, noise, TacticalSound.surface_step_label(str(ground.get(dest, "asphalt")), bool(player.crouched)), true)
    var breathing := TacticalTime.breath_noise(player)
    if breathing > 0: emit_noise(dest, breathing, "breathing", true)
    check_objective_and_exit()
    commit_action(TacticalTime.movement_cost(player, true))
''')

t = replace_func(t, 'toggle_crouch', 'try_move', '''func toggle_crouch():
    player.crouched = not player.crouched
    player.move_state = "CROUCH" if player.crouched else "STILL"
    msg = "Crouched: quieter, slower." if player.crouched else "Standing."
    commit_action(TacticalTime.stance_cost(player))
''')

t = replace_func(t, 'try_move', 'check_objective_and_exit', '''func try_move(dir: Vector2i):
    var dest: Vector2i = player.pos + dir
    player.facing = dir
    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest):
        msg = "Blocked."
        recalc_visibility(); refresh_intents(); queue_redraw(); return
    player.pos = dest
    player.last_dir = dir
    player.move_state = "CROUCH" if player.crouched else "WALK"
    var noise := 7 if player.crouched else 19
    if player.clothing == "Heavy Boots": noise += 4
    emit_noise(dest, noise, TacticalSound.surface_step_label(str(ground.get(dest, "asphalt")), bool(player.crouched)), true)
    var breathing := TacticalTime.breath_noise(player)
    if breathing > 0: emit_noise(dest, breathing, "breathing", true)
    check_objective_and_exit()
    commit_action(TacticalTime.movement_cost(player, false))
''')

t = replace_func(t, 'interact', 'melee', '''func interact():
    var p: Vector2i = player.pos + player.facing
    if doors.has(p):
        doors[p] = not doors[p]
        msg = "Door opened." if doors[p] else "Door closed."
        emit_noise(p, 20 if doors[p] else 16, "door open" if doors[p] else "door close", true)
        commit_action(TacticalTime.interaction_cost(player, 60)); return
    if glass.has(p):
        glass.erase(p)
        msg = "Glass breaks. Loud."
        emit_noise(p, 58, "breaking glass", true)
        commit_action(TacticalTime.interaction_cost(player, 100)); return
    msg = "Nothing useful there."
    queue_redraw()
''')

melee = '''func melee(target: Vector2i):
    var zi := zombie_at(target)
    if zi == -1:
        msg = "Nothing in reach."; queue_redraw(); return
    var z: Dictionary = zombies[zi]
    var stealth := stealth_attack(z)
    var combat := int(player.skills.get("Combat", 0))
    var chance := clamp(0.54 + combat * 0.055 - attack_penalty(player) + (0.30 if stealth else 0.0), 0.12, 0.97)
    if rng.randf() <= chance:
        var d := rng.randi_range(int(player.weapon.dmin), int(player.weapon.dmax)) + int(floor(combat / 3.0))
        if stealth: d = int(round(float(d + int(player.weapon.stealth) + combat) * 1.45))
        zombies[zi].hp -= d
        _flash_hit(z.pos, int(zombies[zi].hp) <= 0)
        msg = "%s hit for %d%s." % [player.weapon.name, d, " — STEALTH" if stealth else ""]
        if int(zombies[zi].hp) <= 0:
            kill_zombie(zi, stealth)
        else:
            reveal_melee_target(zi)
            if int(player.weapon.push) > 0: push_zombie(zi, player.facing)
    else:
        msg = "%s misses." % player.weapon.name
    emit_noise(player.pos, maxi(8, int(player.weapon.noise)), "melee impact", true)
    commit_action(TacticalTime.attack_cost(player, int(player.weapon.time)))
'''
t = replace_func(t, 'melee', 'shoot', melee)

shoot = '''func shoot(i: int):
    if not bool(player.weapon.gun):
        msg = "No firearm equipped."; queue_redraw(); return
    var ammo_cost := int(player.weapon.ammo)
    if not Game.consume_combat_ammo(ammo_cost):
        msg = "No ammunition."; queue_redraw(); return
    var z: Dictionary = zombies[i]
    if z.dead or not visible_cells.has(z.pos): return
    player.facing = dominant(z.pos - player.pos)
    var dist := manhattan(player.pos, z.pos)
    var combat := int(player.skills.get("Combat", 0))
    var chance := clamp(0.52 + combat * 0.06 - max(0, dist - 3) * 0.035 - attack_penalty(player), 0.10, 0.95)
    stats.shots += 1
    _flash_muzzle(player.pos, player.facing)
    if rng.randf() <= chance:
        var d := rng.randi_range(int(player.weapon.gmin), int(player.weapon.gmax)) + int(floor(combat / 2.0))
        if player.weapon.name == "Shotgun" and dist <= 3: d += 4
        zombies[i].hp -= d
        _flash_hit(z.pos, int(zombies[i].hp) <= 0)
        msg = "%s hits for %d." % [player.weapon.name, d]
        if int(zombies[i].hp) <= 0: kill_zombie(i, false)
        else: reveal_melee_target(i)
    else:
        msg = "%s misses." % player.weapon.name
    emit_noise(player.pos, int(player.weapon.gnoise), "gunshot", true)
    commit_action(TacticalTime.attack_cost(player, int(player.weapon.gtime)))
'''
t = replace_func(t, 'shoot', 'shoot_barrel', shoot)
t = t.replace('    commit_action(150)\n\nfunc blast_actor', '    commit_action(TacticalTime.attack_cost(player, 150))\n\nfunc blast_actor', 1)

commit = '''func commit_action(cost: int):
    if game_over: return
    # Player position/facing/doors may have changed before the timeline advances.
    # Update light now so AI perception during this action sees the real state.
    recalc_lighting()
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
    maybe_emit_ambient_sound()
    recalc_visibility(); refresh_intents(); persist_runtime(); queue_redraw()
'''
t = replace_func(t, 'commit_action', 'companion_act', commit)

companion = '''func companion_act():
    if ally.is_empty() or ally.dead: return
    var nearest := -1
    var best := 999
    for i in range(zombies.size()):
        if zombies[i].dead: continue
        var d := manhattan(ally.pos, zombies[i].pos)
        if d < best: best = d; nearest = i
    if nearest != -1 and best == 1:
        companion_melee(nearest)
        ally.next = tick + TacticalTime.attack_cost(ally, int(ally.weapon.time))
        return
    if manhattan(ally.pos, player.pos) > 1:
        var step := best_step_toward(ally.pos, player.pos, true)
        if step != Vector2i.ZERO:
            ally.facing = step
            ally.pos += step
            emit_noise(ally.pos, 16, TacticalSound.surface_step_label(str(ground.get(ally.pos, "asphalt")), false), true)
            if TacticalLighting.item_emits_light(str(ally.get("secondary", ""))): recalc_lighting()
    ally.next = tick + TacticalTime.movement_cost(ally, false)
'''
t = replace_func(t, 'companion_act', 'companion_melee', companion)

zact = '''func zombie_act(i: int):
    if zombies[i].dead: return
    var z: Dictionary = zombies[i]
    var target_actor: Dictionary = choose_zombie_target(z)
    var sees := not target_actor.is_empty()
    if sees:
        z.state = "CHASE"
        z.target = target_actor.pos
        z.heard = target_actor.pos
        zombies[i] = z
        alert_zombie_group(i, target_actor.pos, 4)
    elif z.state == "CHASE":
        z.state = "INVESTIGATE"
        z.target = z.heard
        zombies[i] = z

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
            var d := DIRS[rng.randi_range(0,3)]
            var p := z.pos + d
            z.facing = d
            if not blocked(p) and zombie_at(p) == -1 and p != player.pos and not ally_at(p):
                z.pos = p; moved = true
        zombies[i] = z
        if rng.randf() < 0.08:
            emit_noise(z.pos, 25, "moan", false)
    if moved and rng.randf() < 0.42:
        emit_noise(zombies[i].pos, 14, "shuffle", false)
    if not zombies[i].dead:
        zombies[i].next = tick + (TacticalTime.zombie_move_cost(zombies[i]) if moved else TacticalTime.zombie_move_cost(zombies[i]) + 30)
'''
t = replace_func(t, 'zombie_act', 'choose_zombie_target', zact)

t = replace_func(t, 'zombie_attack', 'clothing_protection', '''func zombie_attack(i: int, target_actor: Dictionary):
    var defense := int(target_actor.skills.get("Combat", 0)) * 0.02 + int(target_actor.skills.get("Survival", 0)) * 0.012
    var hit := clamp(0.67 - defense + (0.08 if float(target_actor.fatigue) >= 80 else 0.0), 0.25, 0.82)
    if rng.randf() <= hit:
        var dmg := rng.randi_range(2, 5)
        var protection := clothing_protection(target_actor.clothing)
        if rng.randf() < protection: dmg = max(1, dmg - 2)
        target_actor.hp -= dmg
        _flash_hit(target_actor.pos, int(target_actor.hp) <= 0)
        if target_actor.controlled:
            stats.damage += dmg
            msg = "The infected hits you for %d." % dmg
        else:
            msg = "%s gets hit." % target_actor.name
        if target_actor.hp <= 0:
            target_actor.hp = 0; target_actor.dead = true
    elif target_actor.controlled:
        msg = "You avoid the grab."
    zombies[i].next = tick + TacticalTime.zombie_attack_cost(zombies[i])
''')

helpers = '''func alert_zombie_group(source_index: int, target_pos: Vector2i, radius: int) -> void:
    if source_index < 0 or source_index >= zombies.size() or zombies[source_index].dead: return
    var origin: Vector2i = zombies[source_index].pos
    for i in range(zombies.size()):
        if i == source_index or zombies[i].dead: continue
        if manhattan(origin, zombies[i].pos) <= radius and zombies[i].state != "CHASE":
            zombies[i].state = "INVESTIGATE"
            zombies[i].heard = target_pos
            zombies[i].target = target_pos

func reveal_melee_target(index: int) -> void:
    if index < 0 or index >= zombies.size() or zombies[index].dead: return
    zombies[index].state = "CHASE"
    zombies[index].heard = player.pos
    zombies[index].target = player.pos
    alert_zombie_group(index, player.pos, 3)

func maybe_emit_ambient_sound() -> void:
    if rng.randf() >= 0.12: return
    var profile: Dictionary = TacticalSound.ambient_profile(TacticalEnvironments.theme_name(environment_id), scene_time, power_on, rng)
    if profile.is_empty(): return
    var source := player.pos
    var candidates: Array = []
    for source_value in light_sources:
        var light_source: Dictionary = source_value
        if TacticalLighting.source_active(light_source, power_on): candidates.append(light_source.get("pos", player.pos))
    if candidates.is_empty(): candidates = props.keys()
    if not candidates.is_empty(): source = candidates[rng.randi_range(0, candidates.size() - 1)]
    emit_noise(source, int(profile.get("intensity", 18)), str(profile.get("label", "noise")), false)

'''
t = replace_once(t, 'func emit_noise(source: Vector2i, intensity: int, label: String, player_made: bool):\n', helpers + 'func emit_noise(source: Vector2i, intensity: int, label: String, player_made: bool):\n', 'combat awareness helpers')

emit = '''func emit_noise(source: Vector2i, intensity: int, label: String, player_made: bool):
    stats.noise = max(int(stats.noise), intensity)
    var costs := sound_map(source, intensity)
    for i in range(zombies.size()):
        if zombies[i].dead: continue
        var received := intensity - int(costs.get(zombies[i].pos, 99999))
        if received >= 8 and zombies[i].state != "CHASE":
            var error := TacticalSound.zombie_location_error(received)
            var estimate := TacticalSound.estimate_location(source, zombies[i].pos, error, rng, W, H)
            zombies[i].state = "INVESTIGATE"
            zombies[i].heard = estimate
            zombies[i].target = estimate
    if not player_made:
        var heard := intensity - int(costs.get(player.pos, 99999))
        var awareness := float(player.skills.get("Survival", 0))
        if TacticalLighting.item_emits_light(str(player.get("secondary", ""))): awareness += 0.5
        if heard + awareness * 2.0 >= 12:
            var error := TacticalSound.player_location_error(awareness, heard, manhattan(player.pos, source))
            var approx := TacticalSound.estimate_location(source, player.pos, error, rng, W, H)
            sound_marks.append({"pos": approx, "source": source, "label": label, "time": tick})
            while sound_marks.size() > 6: sound_marks.pop_front()
'''
t = replace_func(t, 'emit_noise', 'sound_map', emit)

lighting = '''func recalc_lighting():
    light_levels.clear()
    light_tints.clear()
    var theme := TacticalEnvironments.theme_name(environment_id)
    var player_light := str(player.get("secondary", ""))
    var ally_light := str(ally.get("secondary", "")) if not ally.is_empty() and not bool(ally.get("dead", false)) else ""
    for y in range(H):
        for x in range(W):
            var cell := Vector2i(x, y)
            var indoors := indoor_cells.has(cell)
            var level := TacticalLighting.ambient_level(theme, scene_time, indoors)
            var strongest := 0.0
            var tint_hex := ""
            for source_value in light_sources:
                var source: Dictionary = source_value
                if not TacticalLighting.source_active(source, power_on): continue
                var source_pos: Vector2i = source.get("pos", Vector2i(-99, -99))
                if not line_clear(source_pos, cell): continue
                var contribution := TacticalLighting.radial_contribution(cell, source)
                level = maxf(level, contribution)
                if contribution > strongest:
                    strongest = contribution
                    tint_hex = str(source.get("color", "ffffff"))
            if scene_time == "day" and indoors:
                for window_pos in glass.keys():
                    if not line_clear(window_pos, cell): continue
                    var daylight := TacticalLighting.window_daylight_contribution(window_pos, cell)
                    level = maxf(level, daylight)
                    if daylight > strongest:
                        strongest = daylight
                        tint_hex = "fff1c5"
            if TacticalLighting.item_emits_light(player_light) and line_clear(player.pos, cell):
                var player_level := TacticalLighting.item_contribution(player.pos, player.facing, cell, player_light)
                level = maxf(level, player_level)
                if player_level > strongest:
                    strongest = player_level
                    tint_hex = str(D.GEAR[player_light].get("light_color", "edf5d6"))
            if ally_light != "" and TacticalLighting.item_emits_light(ally_light) and line_clear(ally.pos, cell):
                var ally_level := TacticalLighting.item_contribution(ally.pos, ally.facing, cell, ally_light)
                level = maxf(level, ally_level)
                if ally_level > strongest:
                    strongest = ally_level
                    tint_hex = str(D.GEAR[ally_light].get("light_color", "edf5d6"))
            light_levels[cell] = clampf(level, 0.0, 1.0)
            if tint_hex != "": light_tints[cell] = tint_hex
'''
t = replace_func(t, 'recalc_lighting', 'recalc_visibility', lighting)

t = replace_func(t, 'recalc_visibility', 'view_range', '''func recalc_visibility():
    recalc_lighting()
    visible_cells.clear()
    var vr := view_range()
    for y in range(H):
        for x in range(W):
            var p := Vector2i(x, y)
            var dist := manhattan(player.pos, p)
            if p == player.pos or dist <= 1:
                visible_cells[p] = true; memory[p] = true; continue
            if dist > vr or not in_cone(player.pos, player.facing, p, vr, 0.14) or not line_clear(player.pos, p):
                continue
            var light := float(light_levels.get(p, 0.0))
            if TacticalLighting.visible_at_distance(light, dist, vr):
                visible_cells[p] = true
                memory[p] = true
    for i in range(zombies.size()):
        if zombies[i].dead:
            last_seen.erase(i); continue
        if visible_cells.has(zombies[i].pos):
            last_seen[i] = zombies[i].pos
        elif last_seen.has(i) and visible_cells.has(last_seen[i]):
            last_seen.erase(i)
''')

t = replace_func(t, 'view_range', 'refresh_intents', '''func view_range() -> int:
    var r := 5 + int(floor(int(player.skills.get("Survival", 0)) / 4.0))
    r += TacticalLighting.item_view_bonus(str(player.get("secondary", "")))
    if float(player.fatigue) >= 80: r -= 1
    return clampi(r, 4, 8)
''')

t = replace_func(t, 'zombie_sees_actor', 'any_zombie_sees_player', '''func zombie_sees_actor(z, actor: Dictionary) -> bool:
    if actor.is_empty() or actor.get("dead", false): return false
    var dist := manhattan(z.pos, actor.pos)
    var target_light := float(light_levels.get(actor.pos, 0.0))
    var sight_range := 3 + int(round(target_light * 3.0))
    if actor.get("crouched", false): sight_range -= 1
    sight_range = clampi(sight_range, 2, 6)
    if dist > sight_range: return false
    return in_cone(z.pos, z.facing, actor.pos, sight_range, 0.0) and line_clear(z.pos, actor.pos)
''')

t = replace_func(t, 'line_clear', 'in_cone', '''func line_clear(a: Vector2i, b: Vector2i) -> bool:
    var x0 := a.x; var y0 := a.y; var x1 := b.x; var y1 := b.y
    var dx := abs(x1-x0); var sx := 1 if x0<x1 else -1
    var dy := -abs(y1-y0); var sy := 1 if y0<y1 else -1
    var err := dx+dy
    while true:
        var p := Vector2i(x0,y0)
        if p != a and p != b:
            # Windows transmit sight/light. Tall physical obstacles and closed
            # doors do not. Movement still treats all obstacles/glass separately.
            if walls.has(p) or opaque_obstacles.has(p) or (doors.has(p) and not doors[p]): return false
        if x0==x1 and y0==y1: break
        var e2 := 2*err
        if e2>=dy: err+=dy; x0+=sx
        if e2<=dx: err+=dx; y0+=sy
    return true
''')

# Add keyboard interaction without changing the phone-first controls.
t = t.replace('            KEY_C: toggle_crouch()\n', '            KEY_C: toggle_crouch()\n            KEY_F, KEY_SPACE: interact()\n')

# Atlas map rendering replaces the long procedural prop renderer.
draw_map = '''func draw_map():
    var theme := TacticalEnvironments.theme_name(environment_id)
    var grid_color := TacticalEnvironments.grid_color(environment_id)
    for y in range(H):
        for x in range(W):
            var p := Vector2i(x,y)
            var r := Rect2(x*TILE,y*TILE,TILE,TILE)
            var ground_kind := str(ground.get(p, TacticalEnvironments.default_ground(environment_id)))
            TacticalTiles.draw_ground(self, r, ground_kind)
            draw_rect(r, grid_color, false, 1)
            if walls.has(p):
                TacticalTiles.draw_wall(self, r, theme)
            elif doors.has(p):
                TacticalTiles.draw_door(self, r, bool(doors[p]))
            elif glass.has(p):
                TacticalTiles.draw_window(self, r)
            elif barrels.has(p):
                TacticalTiles.draw_barrel(self, r)
            elif props.has(p):
                TacticalTiles.draw_prop(self, r, str(props[p]))
            elif obstacles.has(p):
                TacticalTiles.draw_prop(self, r, "crate")
    var kind := str(context.get("kind","ambush"))
    if kind == "explore" and not objective_done:
        draw_rect(Rect2(objective_cell.x*TILE+4,objective_cell.y*TILE+4,TILE-8,TILE-8), Color(.95,.75,.20), false, 3)
    elif kind == "rescue" and not objective_done:
        draw_circle(cell_center(rescue_cell), 9, Color(.95,.75,.20), false, 3)
        draw_string(font, cell_center(rescue_cell)+Vector2(-10,-12), "SOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.95,.8,.35))
'''
t = replace_func(t, 'draw_map', 'draw_escape_markers', draw_map)
t = replace_func(t, 'draw_environment_prop', 'draw_units', '''func draw_environment_prop(p: Vector2i, kind: String):
    TacticalTiles.draw_prop(self, Rect2(p.x*TILE,p.y*TILE,TILE,TILE), kind)
''')

t = replace_func(t, 'draw_lighting', 'draw_light_source_glows', '''func draw_lighting():
    var theme := TacticalEnvironments.theme_name(environment_id)
    var dark_tint := TacticalLighting.ambient_tint(theme, scene_time)
    for y in range(H):
        for x in range(W):
            var cell := Vector2i(x, y)
            var r := Rect2(x * TILE, y * TILE, TILE, TILE)
            var ambient := TacticalLighting.ambient_level(theme, scene_time, indoor_cells.has(cell))
            var level := float(light_levels.get(cell, ambient))
            var darkness := TacticalLighting.darkness_alpha(level)
            draw_rect(r, Color(dark_tint.r, dark_tint.g, dark_tint.b, darkness))
            if light_tints.has(cell):
                var tint := Color(str(light_tints[cell]))
                var wash := TacticalLighting.color_wash_alpha(level)
                if wash > 0.0: draw_rect(r.grow(-1), Color(tint.r, tint.g, tint.b, wash))
''')

t = replace_func(t, 'draw_light_source_glows', 'draw_fog', '''func draw_light_source_glows():
    var now := Time.get_ticks_msec()
    for source_value in light_sources:
        var source: Dictionary = source_value
        if not TacticalLighting.source_active(source, power_on): continue
        var source_pos: Vector2i = source.get("pos", Vector2i(-99, -99))
        if not inside(source_pos): continue
        var c := cell_center(source_pos)
        var source_color := Color(str(source.get("color", "ffffff")))
        var strength := TacticalLighting.visual_strength(source, now)
        draw_circle(c, 15.0, Color(source_color.r, source_color.g, source_color.b, 0.035 * strength))
        draw_circle(c, 9.0, Color(source_color.r, source_color.g, source_color.b, 0.075 * strength))
        draw_circle(c, 3.0, Color(source_color.r, source_color.g, source_color.b, 0.72 * strength))
''')

t = replace_func(t, 'draw_fog', 'draw_sounds', '''func draw_fog():
    for y in range(H):
        for x in range(W):
            var p := Vector2i(x,y)
            if visible_cells.has(p): continue
            var alpha := .62 if memory.has(p) else .96
            draw_rect(Rect2(x*TILE,y*TILE,TILE,TILE),Color(0.005,0.008,0.010,alpha))
''')

t = replace_func(t, 'draw_sounds', 'draw_hud', '''func draw_sounds():
    for s in sound_marks:
        if tick-int(s.time)>750: continue
        if s.has("source") and visible_cells.has(s.source): continue
        var c := cell_center(s.pos)
        var label := TacticalSound.display_label(str(s.label))
        var box := Rect2(c.x - 54, c.y - 10, 108, 16)
        draw_rect(box, Color(0.03,0.04,0.04,.78))
        draw_rect(box, Color(.78,.68,.30,.78), false, 1)
        draw_string(font,Vector2(box.position.x,c.y+2),label,HORIZONTAL_ALIGNMENT_CENTER,box.size.x,8,Color(.98,.86,.40))
''')

# HUD makes scene state and actual timing visible to the player.
t = t.replace(
    '    draw_string(font,Vector2(10,22),location_name,HORIZONTAL_ALIGNMENT_LEFT,370,17,Color.WHITE)',
    '    var scene_label := "%s  •  %s  •  %s" % [location_name, scene_time.to_upper(), "POWER" if power_on else "NO POWER"]\n    draw_string(font,Vector2(10,22),scene_label,HORIZONTAL_ALIGNMENT_LEFT,370,14,Color.WHITE)'
)
t = t.replace(
    '    draw_string(font,Vector2(148,724),"K %d\\nT %d"%[int(stats.kills),tick],HORIZONTAL_ALIGNMENT_CENTER,98,9,Color(.55,.60,.56))',
    '    var step_cost := TacticalTime.movement_cost(player, false)\n    var load_label := TacticalTime.load_band(TacticalTime.equipment_weight(player))\n    draw_string(font,Vector2(148,716),"T %d  STEP %d"%[tick,step_cost],HORIZONTAL_ALIGNMENT_CENTER,98,8,Color(.62,.68,.64))\n    draw_string(font,Vector2(148,731),"K %d  %s"%[int(stats.kills),load_label],HORIZONTAL_ALIGNMENT_CENTER,98,8,Color(.55,.60,.56))'
)
write(path, t)


# ---------------------------------------------------------------------------
# Smoke checks: prove the systems are connected rather than decorative.
# ---------------------------------------------------------------------------
path = 'game/scripts/ci/FFArchitectureSmoke.gd'
t = read(path)
t = replace_once(
    t,
    'const TacticalLighting = preload("res://scripts/FFTacticalLighting.gd")',
    'const TacticalLighting = preload("res://scripts/FFTacticalLighting.gd")\nconst TacticalTiles = preload("res://scripts/FFTacticalTiles.gd")\nconst TacticalTime = preload("res://scripts/FFTacticalTime.gd")\nconst TacticalSound = preload("res://scripts/FFTacticalSound.gd")',
    'smoke new modules',
)
t = t.replace(
    '    if not _check(TacticalLighting.secondary_item_from_equipment({"Tool": "Flashlight"}) == "Flashlight", "legacy flashlight compatibility"): return\n',
    ''
)
t = t.replace('TacticalLighting.cone_contribution(Vector2i(5, 5), Vector2i(1, 0), Vector2i(10, 5), "Flashlight")', 'TacticalLighting.item_contribution(Vector2i(5, 5), Vector2i(1, 0), Vector2i(10, 5), "Flashlight")')
t = t.replace('TacticalLighting.cone_contribution(Vector2i(5, 5), Vector2i(1, 0), Vector2i(2, 5), "Flashlight")', 'TacticalLighting.item_contribution(Vector2i(5, 5), Vector2i(1, 0), Vector2i(2, 5), "Flashlight")')
t = replace_once(
    t,
    '    if not _check(TacticalEnvironments.build_layout("gas_station", 0).get("lights", []).size() >= 3, "gas station authored lights"): return\n',
    '    if not _check(TacticalEnvironments.build_layout("gas_station", 0).get("lights", []).size() >= 3, "gas station authored lights"): return\n'
    '    if not _check(TacticalScenarios.pick_scene_state("gas_station", visual_rng).has("time_of_day"), "scene day night state"): return\n'
    '    if not _check(TacticalTiles.item_region("Headlamp") >= 0, "atlas secondary item"): return\n'
    '    var light_actor := {"equipment": {"Weapon": "Utility Knife", "Secondary": "", "Tool": "", "Clothing": "", "Pack": ""}, "fatigue": 0.0, "condition": "Healthy", "skills": {"Survival": 3, "Combat": 2}, "crouched": false}\n'
    '    var heavy_actor := light_actor.duplicate(true)\n'
    '    heavy_actor["equipment"] = {"Weapon": "Shotgun", "Secondary": "Lantern", "Tool": "Toolbox", "Clothing": "Leather Jacket", "Pack": "Hiking Pack"}\n'
    '    if not _check(TacticalTime.movement_cost(heavy_actor, false) > TacticalTime.movement_cost(light_actor, false), "encumbrance changes timeline"): return\n'
    '    var sound_rng := RandomNumberGenerator.new(); sound_rng.seed = 7\n'
    '    var estimate := TacticalSound.estimate_location(Vector2i(10,10), Vector2i(2,2), 2, sound_rng, 20, 18)\n'
    '    if not _check(abs(estimate.x-10)+abs(estimate.y-10) <= 2, "sound stays in source vicinity"): return\n',
    'new tactical smoke contracts',
)
t = t.replace(
    '    if not _check(survivor_look.has("skin") and survivor_look.has("top") and survivor_look.has("body"), "survivor visual identity"): return',
    '    if not _check(survivor_look.has("sprite") and survivor_look.has("accent"), "survivor sprite identity"): return'
)
write(path, t)


# ---------------------------------------------------------------------------
# Docs / durable context.
# ---------------------------------------------------------------------------
path = 'ARCHITECTURE.md'
t = read(path)
t = t.replace('Current schema: **4**.', 'Current schema: **5**.')
t = replace_once(
    t,
    '### `FFTacticalLighting.gd`\nTactical lighting rules/presentation helper.',
    '### `FFTacticalTiles.gd`\nTactical environment atlas renderer. Owns atlas-region lookup and drawing for ground, structural tiles, props, and carried-item icons. Physical geometry/occlusion remains authoritative in `FFTacticalEnvironments.gd` / `FFCombat.gd`.\n\n'
    '### `FFTacticalTime.gd`\nPure tactical action-timing rules. Converts survivor equipment weight, fatigue, condition, skills, stance, and zombie pace/mass profiles into actual timeline costs used by `FFCombat.gd`.\n\n'
    '### `FFTacticalSound.gd`\nPure tactical sound presentation/localization rules: surface-aware labels, bounded fuzzy source estimates, and ambient sound profiles. `FFCombat.gd` still owns propagation and AI reaction state.\n\n'
    '### `FFTacticalLighting.gd`\nTactical lighting rules/presentation helper.',
    'architecture new owners',
)
write(path, t)

path = 'README_CONTEXT.md'
t = read(path)
t = t.replace('Current milestone: **Alpha 0.3C — Tactical Lighting & Secondary Gear**.', 'Current milestone: **Alpha 0.3D — Tactical Senses, Timing & Art**.')
t = t.replace('Current save schema: **4**.', 'Current save schema: **5**.')
needle = 'Alpha 0.3C adds low-light tactical rendering with authored neon, canopy, fluorescent, warm, security, flood, and warning-light sources. Lighting occlusion is recalculated only when tactical state changes; cheap source glow animation redraws at low refresh for phone/Web performance. Flashlights now use a real **Secondary** equipment slot independent of Weapon and Tool, cast an occluded directional cone, tint/brighten the board, and preserve their existing view-range benefit. An old schema-4 survivor with Flashlight still stored in Tool is recognized without mutating the save.\n'
replacement = '''Alpha 0.3D replaces the procedural tactical tokens/flat prop drawing with a reusable original sprite/tile atlas and adds randomized **day/night + powered/unpowered** scene states. The same authored place can therefore play in daylight, powered night light, or near-black blackout conditions. Daylight enters authored interiors through windows; glass transmits vision/light while walls, closed doors, and tall props occlude it.

Player vision is now shorter and truly light-dependent instead of being a light-independent cone with a dark filter drawn afterward. Zombie sight also responds to how illuminated the target is, so carrying a bright radial light improves awareness while making the carrier easier to detect.

Tactical action time is authoritative: equipped weight, fatigue, injuries, stance, survivor skill, weapon action time, and per-zombie pace/mass profiles feed the actual tick scheduler. Sound markers use bounded fuzzy localization near the true source, surface-specific footsteps and more ambient/infected noises, and nearby infected share awareness when one spots the party. A nonlethal melee hit reveals the attacker to that infected even when the approach was stealthy. Adjacent doors are now tap/click interactions, allowing explicit closing instead of treating an open door tap as movement.
'''
if needle in t:
    t = t.replace(needle, replacement)
else:
    raise SystemExit('context 0.3C paragraph missing')
write(path, t)

path = 'README_SOPS.md'
t = read(path)
t = t.replace('Current schema: **4**.', 'Current schema: **5**.')
t = replace_once(
    t,
    '- `FFTacticalLighting.gd` — tactical light profiles/falloff and Secondary light-item beam rules; environments place fixed sources and combat owns occlusion/draw integration.\n',
    '- `FFTacticalLighting.gd` — tactical day/night/power light profiles, Secondary light-item math, window daylight, and light-dependent sight thresholds.\n'
    '- `FFTacticalTiles.gd` — tactical sprite/tile atlas-region rendering; physical geometry remains outside presentation.\n'
    '- `FFTacticalTime.gd` — pure derived tactical action timing from gear load, survivor state, and infected pace/mass.\n'
    '- `FFTacticalSound.gd` — pure tactical sound labeling/localization helpers; combat owns propagation and reactions.\n',
    'sop tactical owners',
)
write(path, t)

path = 'CHANGELOG.md'
t = read(path)
entry = '''## Alpha 0.3D — Tactical Senses, Timing & Art — 2026-08-13

### Sprite / Tile Overhaul
- Replaced the flat tactical ground/prop primitives and procedural actor bodies with an original reusable tactical atlas covering ground materials, themed walls, open/closed doors, windows, furniture, shelves, vehicles, industrial clutter, survivors, infected, corpses, weapons, and Secondary light items.
- Survivor appearance remains randomized/persistent but now selects from eight readable sprite identities; infected use eight sprite variants weighted by their existing environment families.
- Equipped weapons and Secondary lighting gear remain visible beside the survivor, now as atlas art instead of tiny generic lines.
- Doors and windows now read as actual structural tiles instead of ambiguous outlines, and authored layout validation checks both party spawns as well as exits.

### Day / Night / Power
- Every tactical encounter independently rolls day or night plus an environment-specific power state. The same Gas Station, House, Apartment, Store, Alley, or Warehouse can therefore appear under different lighting conditions.
- Locations have different chances of retained power; Drainage Wash has none.
- Authored interiors are now explicit physical metadata rather than inferred from floor color.
- Daylight enters interiors through windows. Glass transmits sight and light, while walls, closed doors, and tall props block them.
- Powered fixtures illuminate the same authored locations at night; blackout versions remain dark enough for portable lights to matter.

### Light / Vision Interaction
- Shortened the survivor vision cone and made actual cell light determine whether distant cells inside that cone are visible.
- Bright fixtures, windows, flashlight beams, and radial lights can reveal pockets beyond surrounding darkness instead of lighting being merely a cosmetic overlay.
- Infected vision now also depends on target illumination, so a lantern or flashlight can help you see while making you easier to spot.
- Added Headlamp, Lantern, Glow Stick, and Road Flare Secondary gear alongside Flashlight, with directional vs radial light profiles and distinct colors/ranges.

### Real Tactical Time
- Tactical ticks now derive survivor movement/turn/stance/interaction/attack costs from equipped load, fatigue, wounds, skills, stance, and weapon timing.
- Infected receive persistent pace, attack-speed, and mass profiles; different infected can match a survivor tile-for-tile, lose ground over successive moves, or remain persistently faster/slower.
- Companion movement and attacks use the same derived timing rules instead of a fixed universal cadence.
- HUD now exposes current tick, derived step cost, and load band so the scheduler is inspectable rather than hidden.

### Sound / Awareness / Interaction
- Footstep labels now reflect surface (creak/tap/rustle/scuff/etc.) and high fatigue/load can generate breathing noise.
- Added more infected and environmental sounds including shuffle, moan, fixture hum/buzz, house creaks, pipe knocks, metal rattle, shelf ticks, wind, and gravel.
- Off-screen sound estimates are now fuzzy within a bounded radius of the true source instead of a random square that could point somewhere unrelated.
- Sound labels render in a wider bounded callout so longer words no longer clip off the tile.
- Infected hearing also uses approximate locations for weaker sounds rather than perfect coordinates.
- When one infected visually spots a survivor, nearby infected are alerted to the same vicinity instead of behaving as isolated units.
- A nonlethal melee hit reveals the attacker to the struck infected even when the approach qualified as stealth.
- Tapping/clicking an adjacent door now explicitly uses it, so open doors can be closed; the FORWARD control still handles movement through an already-open doorway.

### Alpha Saves / Architecture
- Save schema advanced to **5** and old Alpha saves are invalidated rather than migrated.
- Removed the schema-4 Tool-slot Flashlight compatibility path.
- Added `FFTacticalTiles.gd`, `FFTacticalTime.gd`, and `FFTacticalSound.gd` as durable owners for presentation atlas rendering, derived action timing, and sound-localization rules.
- Added deterministic smoke checks proving encumbrance changes real movement cost and fuzzy sounds remain near their true source.

'''
anchor = '# First Fire — Changelog\n\nThis file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n'
t = replace_once(t, anchor, anchor + entry, '0.3D changelog')
write(path, t)

print('FIRST_FIRE_TACTICAL_03D_PATCH_OK')
