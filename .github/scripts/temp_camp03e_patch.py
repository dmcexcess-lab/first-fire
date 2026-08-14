from pathlib import Path

ROOT = Path('.')

def text(path: str) -> str:
    return (ROOT / path).read_text()

def write(path: str, content: str) -> None:
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content)

def replace_once(path: str, old: str, new: str) -> None:
    src = text(path)
    count = src.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:80]!r}')
    write(path, src.replace(old, new, 1))

CAMP_VIEW = r'''extends Control
class_name FFCampView

const Tiles = preload("res://scripts/FFTacticalTiles.gd")
const Visuals = preload("res://scripts/FFTacticalVisuals.gd")

const GRID_W := 16
const GRID_H := 9
const FIRE_CELL := Vector2i(7, 4)
const SLEEP_CELL := Vector2i(5, 6)
const IDLE_CELLS := [
    Vector2i(6, 4), Vector2i(8, 4), Vector2i(7, 5), Vector2i(6, 5),
    Vector2i(8, 5), Vector2i(5, 4), Vector2i(9, 4), Vector2i(7, 3),
]
const BUILDING_CELLS := {
    "Rain Catcher": Vector2i(2, 2),
    "Makeshift Shelter": Vector2i(3, 6),
    "Storage Crate": Vector2i(9, 6),
    "Workbench": Vector2i(10, 2),
    "Sewing Table": Vector2i(13, 2),
    "Garden Plot": Vector2i(2, 4),
    "Noise Line": Vector2i(8, 1),
    "Cabin": Vector2i(12, 5),
}
const STATION_OFFSETS := {
    "Fire Pit": Vector2i(0, 1),
    "Workbench": Vector2i(-1, 0),
    "Sewing Table": Vector2i(1, 0),
}

var actor_positions := {}
var actor_facing := {}
var redraw_accum := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    custom_minimum_size = Vector2(0, 210)
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    var present := {}
    var moved := false
    for survivor_value in Game.survivors:
        var survivor: Dictionary = survivor_value
        if not _survivor_in_camp(survivor):
            continue
        var sid: int = int(survivor.get("id", -1))
        present[sid] = true
        var target_cell: Vector2i = _target_cell(survivor)
        var target := Vector2(float(target_cell.x), float(target_cell.y))
        if not actor_positions.has(sid):
            var spawn: Vector2i = _spawn_cell(sid)
            actor_positions[sid] = Vector2(float(spawn.x), float(spawn.y))
            actor_facing[sid] = Vector2i(0, 1)
        var current: Vector2 = actor_positions[sid]
        var difference: Vector2 = target - current
        if difference.length() > 0.025 and not Game.sim_paused:
            var step: float = minf(difference.length(), 2.2 * delta)
            current += difference.normalized() * step
            actor_positions[sid] = current
            actor_facing[sid] = _facing_from_delta(difference)
            moved = true
    for key in actor_positions.keys():
        var old_sid: int = int(key)
        if not present.has(old_sid):
            actor_positions.erase(old_sid)
            actor_facing.erase(old_sid)
            moved = true
    redraw_accum += delta
    if moved or redraw_accum >= 0.20:
        redraw_accum = 0.0
        queue_redraw()

static func station_cell(station_name: String) -> Vector2i:
    if station_name == "Fire Pit":
        return FIRE_CELL
    var value: Vector2i = BUILDING_CELLS.get(station_name, FIRE_CELL)
    return value

static func building_cell(building_name: String) -> Vector2i:
    var value: Vector2i = BUILDING_CELLS.get(building_name, FIRE_CELL)
    return value

func _survivor_in_camp(survivor: Dictionary) -> bool:
    if str(survivor.get("condition", "")) == "Dead":
        return false
    var status := str(survivor.get("status", "Available"))
    if status == "Expedition" or status == "Pending Expedition Event":
        return false
    var task: Dictionary = survivor.get("task", {})
    return not task.has("expedition_id")

func _spawn_cell(sid: int) -> Vector2i:
    return IDLE_CELLS[posmod(sid, IDLE_CELLS.size())]

func _target_cell(survivor: Dictionary) -> Vector2i:
    var status := str(survivor.get("status", "Available"))
    var task: Dictionary = survivor.get("task", {})
    if status == "Crafting":
        var station := str(task.get("station", "Fire Pit"))
        var offset: Vector2i = STATION_OFFSETS.get(station, Vector2i(0, 1))
        return station_cell(station) + offset
    if status == "Building":
        var building := str(task.get("building", ""))
        return building_cell(building) + Vector2i(-1, 0)
    if status == "Tending":
        return building_cell("Garden Plot") + Vector2i(1, 0)
    if status == "Recovering":
        return Vector2i(12, 6) if bool(Game.buildings.get("Cabin", false)) else SLEEP_CELL
    if float(survivor.get("fatigue", 0.0)) >= 78.0:
        return Vector2i(12, 6) if bool(Game.buildings.get("Cabin", false)) else SLEEP_CELL
    if float(survivor.get("stress", 0.0)) >= 68.0:
        return FIRE_CELL + Vector2i(0, 1)
    var sid: int = int(survivor.get("id", 0))
    var phase: int = int(floor(float(Game.day_elapsed) / 8.0))
    return IDLE_CELLS[posmod(sid + phase, IDLE_CELLS.size())]

func _facing_from_delta(delta: Vector2) -> Vector2i:
    if absf(delta.x) >= absf(delta.y):
        return Vector2i(1 if delta.x >= 0.0 else -1, 0)
    return Vector2i(0, 1 if delta.y >= 0.0 else -1)

func _draw() -> void:
    if size.x <= 8.0 or size.y <= 8.0:
        return
    var tile: float = minf(size.x / float(GRID_W), size.y / float(GRID_H))
    var map_size := Vector2(tile * float(GRID_W), tile * float(GRID_H))
    var origin := (size - map_size) * 0.5
    draw_rect(Rect2(Vector2.ZERO, size), Color("07100d"))
    for y in range(GRID_H):
        for x in range(GRID_W):
            var kind := "grass"
            if (y == 4 and x >= 2 and x <= 13) or (x == 7 and y >= 1 and y <= 7):
                kind = "dirt"
            Tiles.draw_ground(self, _cell_rect(Vector2i(x, y), origin, tile), kind)
    _draw_structures(origin, tile)
    _draw_construction(origin, tile)
    _draw_night(origin, tile)
    _draw_survivors(origin, tile)
    draw_rect(Rect2(origin, map_size), Color(0.30, 0.42, 0.35, 0.55), false, 1.0)
    var font: Font = get_theme_default_font()
    var title_size: int = maxi(9, int(tile * 0.38))
    draw_string(font, origin + Vector2(7.0, float(title_size) + 4.0), "FIRST FIRE CAMP  •  %s" % Game.formatted_time(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.92, 0.94, 0.88, 0.92))

func _cell_rect(cell: Vector2i, origin: Vector2, tile: float) -> Rect2:
    return Rect2(origin + Vector2(float(cell.x) * tile, float(cell.y) * tile), Vector2(tile, tile))

func _cell_center(cell: Vector2i, origin: Vector2, tile: float) -> Vector2:
    return origin + Vector2((float(cell.x) + 0.5) * tile, (float(cell.y) + 0.5) * tile)

func _grid_center(pos: Vector2, origin: Vector2, tile: float) -> Vector2:
    return origin + Vector2((pos.x + 0.5) * tile, (pos.y + 0.5) * tile)

func _draw_structures(origin: Vector2, tile: float) -> void:
    _draw_fire(origin, tile)
    Tiles.draw_prop(self, _cell_rect(SLEEP_CELL, origin, tile).grow(-tile * 0.08), "bed")

    if bool(Game.buildings.get("Rain Catcher", false)):
        Tiles.draw_barrel(self, _cell_rect(building_cell("Rain Catcher"), origin, tile).grow(-tile * 0.06))
    if bool(Game.buildings.get("Makeshift Shelter", false)):
        var r := _cell_rect(building_cell("Makeshift Shelter"), origin, tile).grow(-tile * 0.05)
        draw_colored_polygon(PackedVector2Array([
            r.position + Vector2(r.size.x * 0.08, r.size.y * 0.92),
            r.position + Vector2(r.size.x * 0.50, r.size.y * 0.10),
            r.position + Vector2(r.size.x * 0.92, r.size.y * 0.92),
        ]), Color("536f5a"))
        draw_polyline(PackedVector2Array([
            r.position + Vector2(r.size.x * 0.08, r.size.y * 0.92),
            r.position + Vector2(r.size.x * 0.50, r.size.y * 0.10),
            r.position + Vector2(r.size.x * 0.92, r.size.y * 0.92),
        ]), Color("9ca887"), 1.2)
    if bool(Game.buildings.get("Storage Crate", false)):
        Tiles.draw_prop(self, _cell_rect(building_cell("Storage Crate"), origin, tile).grow(-tile * 0.05), "crate")
    if bool(Game.buildings.get("Workbench", false)):
        Tiles.draw_prop(self, _cell_rect(building_cell("Workbench"), origin, tile).grow(-tile * 0.04), "counter")
    if bool(Game.buildings.get("Sewing Table", false)):
        Tiles.draw_prop(self, _cell_rect(building_cell("Sewing Table"), origin, tile).grow(-tile * 0.04), "table")
        var sc := _cell_center(building_cell("Sewing Table"), origin, tile)
        draw_circle(sc, tile * 0.10, Color("d7c7e7"))
    if bool(Game.buildings.get("Garden Plot", false)):
        var garden := building_cell("Garden Plot")
        var garden_rect := _cell_rect(garden, origin, tile).grow(-tile * 0.06)
        draw_rect(garden_rect, Color("563d28"))
        for i in range(3):
            var px := garden_rect.position.x + garden_rect.size.x * (0.24 + float(i) * 0.25)
            draw_line(Vector2(px, garden_rect.position.y + 3.0), Vector2(px, garden_rect.end.y - 3.0), Color("70a15f"), 1.8)
    if bool(Game.buildings.get("Noise Line", false)):
        _draw_noise_line(origin, tile)
    if bool(Game.buildings.get("Cabin", false)):
        _draw_cabin(origin, tile)

func _draw_fire(origin: Vector2, tile: float) -> void:
    var center := _cell_center(FIRE_CELL, origin, tile)
    draw_circle(center, tile * 0.28, Color("33261f"))
    draw_line(center + Vector2(-tile * 0.18, tile * 0.12), center + Vector2(tile * 0.18, -tile * 0.12), Color("6d4b2f"), maxf(1.0, tile * 0.07))
    draw_line(center + Vector2(-tile * 0.18, -tile * 0.12), center + Vector2(tile * 0.18, tile * 0.12), Color("6d4b2f"), maxf(1.0, tile * 0.07))
    draw_circle(center + Vector2(0, -tile * 0.03), tile * 0.16, Color(1.0, 0.34, 0.10, 0.88))
    draw_circle(center + Vector2(0, -tile * 0.08), tile * 0.09, Color(1.0, 0.82, 0.28, 0.94))

func _draw_noise_line(origin: Vector2, tile: float) -> void:
    var color := Color("8e826d")
    for x in range(4, 12):
        var p := _cell_center(Vector2i(x, 1), origin, tile)
        draw_line(p + Vector2(-tile * 0.45, 0), p + Vector2(tile * 0.45, 0), color, 1.0)
        draw_line(p + Vector2(0, -tile * 0.24), p + Vector2(0, tile * 0.24), Color("594f42"), 1.4)

func _draw_cabin(origin: Vector2, tile: float) -> void:
    for y in range(4, 7):
        for x in range(11, 14):
            Tiles.draw_ground(self, _cell_rect(Vector2i(x, y), origin, tile), "wood")
    for x in range(11, 14):
        Tiles.draw_wall(self, _cell_rect(Vector2i(x, 4), origin, tile), "house")
    Tiles.draw_wall(self, _cell_rect(Vector2i(11, 5), origin, tile), "house")
    Tiles.draw_wall(self, _cell_rect(Vector2i(13, 5), origin, tile), "house")
    Tiles.draw_wall(self, _cell_rect(Vector2i(11, 6), origin, tile), "house")
    Tiles.draw_wall(self, _cell_rect(Vector2i(13, 6), origin, tile), "house")
    Tiles.draw_door(self, _cell_rect(Vector2i(12, 6), origin, tile), true)
    Tiles.draw_window(self, _cell_rect(Vector2i(12, 4), origin, tile))

func _draw_construction(origin: Vector2, tile: float) -> void:
    for survivor_value in Game.survivors:
        var survivor: Dictionary = survivor_value
        if str(survivor.get("status", "")) != "Building":
            continue
        var task: Dictionary = survivor.get("task", {})
        var building := str(task.get("building", ""))
        if building == "":
            continue
        var cell := building_cell(building)
        var r := _cell_rect(cell, origin, tile).grow(-tile * 0.08)
        draw_rect(r, Color(0.84, 0.72, 0.42, 0.24))
        draw_rect(r, Color(0.90, 0.78, 0.48, 0.82), false, 1.5)
        var duration: float = maxf(0.01, float(task.get("duration", 1.0)))
        var remaining: float = clampf(float(task.get("remaining", duration)), 0.0, duration)
        var progress: float = 1.0 - remaining / duration
        draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3.0), Vector2(r.size.x * progress, 3.0)), Color("d6bd63"))

func _night_alpha() -> float:
    var fraction: float = clampf(float(Game.day_elapsed) / maxf(1.0, float(Game.DAY_SECONDS)), 0.0, 1.0)
    var hour: float = fmod(8.0 + fraction * 24.0, 24.0)
    if hour >= 20.0 or hour < 5.0:
        return 0.64
    if hour >= 18.0:
        return lerpf(0.0, 0.64, (hour - 18.0) / 2.0)
    if hour < 7.0:
        return lerpf(0.64, 0.0, (hour - 5.0) / 2.0)
    return 0.0

func _draw_night(origin: Vector2, tile: float) -> void:
    var alpha := _night_alpha()
    if alpha <= 0.001:
        return
    var map_rect := Rect2(origin, Vector2(tile * float(GRID_W), tile * float(GRID_H)))
    draw_rect(map_rect, Color(0.015, 0.035, 0.085, alpha))
    var fire_center := _cell_center(FIRE_CELL, origin, tile)
    draw_circle(fire_center, tile * 2.25, Color(1.0, 0.36, 0.10, 0.055))
    draw_circle(fire_center, tile * 1.55, Color(1.0, 0.48, 0.12, 0.085))
    draw_circle(fire_center, tile * 0.90, Color(1.0, 0.68, 0.20, 0.14))
    if bool(Game.buildings.get("Cabin", false)):
        var cabin_center := _cell_center(Vector2i(12, 5), origin, tile)
        draw_circle(cabin_center, tile * 1.7, Color(1.0, 0.72, 0.34, 0.075))

func _draw_survivors(origin: Vector2, tile: float) -> void:
    var font: Font = get_theme_default_font()
    for survivor_value in Game.survivors:
        var survivor: Dictionary = survivor_value
        if not _survivor_in_camp(survivor):
            continue
        var sid: int = int(survivor.get("id", -1))
        if not actor_positions.has(sid):
            continue
        var pos: Vector2 = actor_positions[sid]
        var center := _grid_center(pos, origin, tile)
        var equipment: Dictionary = survivor.get("equipment", {})
        var status := str(survivor.get("status", "Available"))
        var working := status != "Available"
        var actor := {
            "appearance": survivor.get("appearance", {}),
            "facing": actor_facing.get(sid, Vector2i(0, 1)),
            "pack": "" if working else str(equipment.get("Pack", "")),
            "weapon": {"name": "" if working else str(equipment.get("Weapon", ""))},
            "secondary": str(equipment.get("Secondary", "")),
            "crouched": false,
        }
        var scale: float = clampf(tile / 32.0, 0.70, 1.18)
        draw_set_transform(center, 0.0, Vector2(scale, scale))
        Visuals.draw_survivor(self, Vector2.ZERO, actor, false)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        var first_name := str(survivor.get("name", "Survivor")).get_slice(" ", 0)
        var font_size: int = maxi(8, int(tile * 0.34))
        draw_string(font, center + Vector2(-tile * 0.52, -tile * 0.48), first_name, HORIZONTAL_ALIGNMENT_CENTER, tile * 1.04, font_size, Color(0.96, 0.97, 0.92, 0.96))
        var activity := _activity_short(status)
        if activity != "":
            draw_string(font, center + Vector2(-tile * 0.52, tile * 0.62), activity, HORIZONTAL_ALIGNMENT_CENTER, tile * 1.04, maxi(7, font_size - 2), Color(0.87, 0.78, 0.49, 0.95))

func _activity_short(status: String) -> String:
    match status:
        "Crafting": return "CRAFT"
        "Building": return "BUILD"
        "Recovering": return "RECOVER"
        "Tending": return "GARDEN"
        _: return ""
'''
write('game/scripts/FFCampView.gd', CAMP_VIEW)

# Founder playtest light + deliberate Alpha reset.
replace_once('game/scripts/Game.gd', 'const SAVE_SCHEMA_VERSION := 5', 'const SAVE_SCHEMA_VERSION := 6')
replace_once(
    'game/scripts/Game.gd',
    'founder["equipment"] = {"Weapon": "Utility Knife", "Secondary": "", "Clothing": "", "Pack": "Worn Backpack", "Tool": ""}',
    'founder["equipment"] = {"Weapon": "Utility Knife", "Secondary": "Flashlight", "Clothing": "", "Pack": "Worn Backpack", "Tool": ""}'
)

# Mount one persistent living camp view across all management tabs and reuse it
# behind the pause/main menu. Retire the old per-tab splash art from active UI.
replace_once(
    'game/scripts/Main.gd',
    'const InspectorOverlay = preload("res://scripts/FFInspector.gd")\n',
    'const InspectorOverlay = preload("res://scripts/FFInspector.gd")\nconst CampView = preload("res://scripts/FFCampView.gd")\n'
)
replace_once(
    'game/scripts/Main.gd',
    'var load_game_button: Button\nvar nav_buttons := {}\nconst TAB_ART := {"Camp": "res://assets/camp.png", "Craft": "res://assets/craft.png", "Build": "res://assets/build.png", "Survivors": "res://assets/survivors.png"}\nconst MAIN_MENU_BG := "res://assets/menu_bg.jpg"\n',
    'var load_game_button: Button\nvar nav_buttons := {}\nvar camp_view: Control\nvar menu_camp_view: Control\n'
)
replace_once(
    'game/scripts/Main.gd',
    '    toast_timer.timeout.connect(func(): toast_panel.visible = false)\n    add_child(toast_timer)\n\n    content_scroll = ScrollContainer.new()\n',
    '''    toast_timer.timeout.connect(func(): toast_panel.visible = false)\n    add_child(toast_timer)\n\n    var camp_frame = PanelContainer.new()\n    camp_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n    camp_frame.clip_contents = true\n    camp_frame.custom_minimum_size = Vector2(0, 210)\n    camp_view = CampView.new()\n    camp_view.custom_minimum_size = Vector2(0, 210)\n    camp_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n    camp_view.size_flags_vertical = Control.SIZE_EXPAND_FILL\n    camp_frame.add_child(camp_view)\n    root.add_child(camp_frame)\n\n    content_scroll = ScrollContainer.new()\n'''
)
replace_once(
    'game/scripts/Main.gd',
    '''    var bg_tex = TextureRect.new()\n    bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n    bg_tex.texture = load(MAIN_MENU_BG)\n    bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE\n    bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED\n    main_menu_overlay.add_child(bg_tex)\n    var shade = ColorRect.new()\n''',
    '''    menu_camp_view = CampView.new()\n    menu_camp_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n    main_menu_overlay.add_child(menu_camp_view)\n    var shade = ColorRect.new()\n'''
)
replace_once(
    'game/scripts/Main.gd',
    '''func _tab_art(tab_name: String) -> Control:\n    var frame = PanelContainer.new()\n    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n    frame.clip_contents = true\n    var tex = TextureRect.new()\n    tex.texture = load(TAB_ART.get(tab_name, TAB_ART["Camp"]))\n    tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE\n    tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED\n    tex.custom_minimum_size = Vector2(0, 150)\n    tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n    frame.add_child(tex)\n    return frame\n\n''',
    ''
)
for call in [
    '    content_box.add_child(_tab_art("Camp"))\n',
    '    content_box.add_child(_tab_art("Craft"))\n',
    '    content_box.add_child(_tab_art("Build"))\n',
]:
    replace_once('game/scripts/Main.gd', call, '')

# Architecture smoke: camp presentation mapping is deterministic and testable.
replace_once(
    'game/scripts/ci/FFArchitectureSmoke.gd',
    'const CampSocial = preload("res://scripts/FFCampSocial.gd")\nconst TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\n',
    'const CampSocial = preload("res://scripts/FFCampSocial.gd")\nconst CampView = preload("res://scripts/FFCampView.gd")\nconst TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\n'
)
replace_once(
    'game/scripts/ci/FFArchitectureSmoke.gd',
    '    if not _check(TacticalTiles.item_region("Headlamp") >= 0, "atlas secondary item"): return\n',
    '    if not _check(TacticalTiles.item_region("Headlamp") >= 0, "atlas secondary item"): return\n    if not _check(CampView.station_cell("Workbench") == Vector2i(10, 2), "camp workbench visual station"): return\n    if not _check(CampView.building_cell("Cabin") == Vector2i(12, 5), "camp cabin visual anchor"): return\n'
)

# Permanent CI knows the new module, schema, integration, and founder testing gear.
replace_once(
    '.github/workflows/pages.yml',
    '          test -f game/scripts/FFCampSocial.gd\n          test -f game/scripts/ci/FFArchitectureSmoke.gd\n',
    '          test -f game/scripts/FFCampSocial.gd\n          test -f game/scripts/FFCampView.gd\n          test -f game/scripts/ci/FFArchitectureSmoke.gd\n'
)
replace_once(
    '.github/workflows/pages.yml',
    "          grep -q 'const TacticalVisuals = preload' game/scripts/Game.gd\n",
    "          grep -q 'const TacticalVisuals = preload' game/scripts/Game.gd\n          grep -q 'const CampView = preload' game/scripts/Main.gd\n"
)
replace_once(
    '.github/workflows/pages.yml',
    "          grep -q 'const SAVE_SCHEMA_VERSION := 5' game/scripts/Game.gd\n",
    "          grep -q 'const SAVE_SCHEMA_VERSION := 6' game/scripts/Game.gd\n          grep -Fq 'founder[\"equipment\"] = {\"Weapon\": \"Utility Knife\", \"Secondary\": \"Flashlight\"' game/scripts/Game.gd\n"
)

# SOP / architecture / context.
replace_once(
    'README_SOPS.md',
    '- `Main.gd` — UI/input/presentation.\n',
    '- `Main.gd` — UI/input/presentation.\n- `FFCampView.gd` — living 2D camp presentation using the tactical atlas; survivor positions are visual reflections of authoritative status/task state, never a second simulation.\n'
)
replace_once('README_SOPS.md', 'Current schema: **5**.', 'Current schema: **6**.')
replace_once(
    'README_SOPS.md',
    '- Camp recovery/vibe/cadence → `FFCampLifeRules`.\n',
    '- Camp recovery/vibe/cadence → `FFCampLifeRules`.\n- Living camp/menu visualization → `FFCampView`, reading `Game` state only.\n'
)

replace_once(
    'ARCHITECTURE.md',
    '### `FFSurvivorPanel.gd`\n',
    '''### `FFCampView.gd`\nLiving 2D camp presentation built from the tactical tile/character language. It reads authoritative buildings, survivor status/tasks, equipment, appearance, fatigue/stress, and camp clock state; it maps those facts to visual stations and cosmetic movement only. Crafting survivors walk to the real task station, builders move to the relevant construction anchor, tending survivors move to the garden, recovering survivors move toward shelter, and expedition survivors disappear from camp. It must never become the owner of work timing, survivor status, resource production, or pathfinding gameplay.\n\n### `FFSurvivorPanel.gd`\n'''
)
replace_once('ARCHITECTURE.md', 'Current schema: **5**.', 'Current schema: **6**.')
replace_once(
    'ARCHITECTURE.md',
    '### Future 3D camp presentation\nA dedicated presentation scene/controller should **read** authoritative survivor/camp/pet/vehicle state. It can visualize work, rest, conversations, pets, and repairs but must not become a second simulation.\n',
    '### Future 3D camp presentation\n`FFCampView.gd` is now the working 2D foundation for this idea. A later 3D renderer may replace or extend that presentation if it materially improves the game, but it should consume the same authoritative survivor/camp/pet/vehicle state and must not become a second simulation.\n'
)

replace_once(
    'README_CONTEXT.md',
    'Current milestone: **Alpha 0.3D — Tactical Senses, Timing & Art**.',
    'Current milestone: **Alpha 0.3E — Living Camp View**.'
)
replace_once('README_CONTEXT.md', 'Current save schema: **5**.', 'Current save schema: **6**.')
replace_once(
    'README_CONTEXT.md',
    '## Autonomous camp life\n',
    '''## Living camp presentation\n\nThe management menus now share a persistent **2D tactical-style living camp view** instead of separate decorative tab splash images. It uses the same tactical tile/character visual language while remaining presentation-only. Built structures appear at stable visual anchors; survivors physically move toward the station implied by their real task/status (crafting, building, tending, recovery), available survivors idle around camp, and expedition survivors are absent. The pause/main menu uses the same living camp as its background. Camp lighting follows the real settlement clock, with fire/cabin glow after dark.\n\nFor Alpha 0.3E playtesting, every new founder starts with a **Flashlight equipped in Secondary** so day/night and blackout tactical lighting can always be exercised immediately. Save schema 6 intentionally invalidates older Alpha state rather than carrying a compatibility path.\n\n## Autonomous camp life\n'''
)
replace_once(
    'README_CONTEXT.md',
    '- camp-life cadence/recovery → `FFCampLifeRules`\n',
    '- camp-life cadence/recovery → `FFCampLifeRules`\n- living camp/menu visualization → `FFCampView`\n'
)

# Roadmap: establish the 2D living camp now; keep 3D optional later.
replace_once(
    'ROADMAP.md',
    '\n---\n\n## Alpha 0.5 — Autonomous Camp Life\n',
    '''\n### Living camp presentation foundation — started in Alpha 0.3E\n\nThe menu now has a persistent 2D camp rendered in the same tactical visual language. It is a **view of simulation state**, not a new control mode: survivors visually walk to crafting/building/garden/recovery stations according to their existing status/task, structures appear as they are built, and survivors outside camp disappear from the scene.\n\nThis should grow alongside the simulation: social interactions, pets, vehicles, repairs, eating, resting, and future camp activity can become visible here when those systems have real state worth showing. The renderer can be enlarged or eventually replaced by 3D without changing who owns the simulation.\n\n---\n\n## Alpha 0.5 — Autonomous Camp Life\n'''
)
replace_once(
    'ROADMAP.md',
    '## Beta — Living 3D Camp Background\n\nThe long-planned 3D camp should arrive **after the simulation knows what it needs to display**.\n\nThe menu remains the primary interface. The 3D camp is a living representation of settlement state, not a second Sims-style control mode.\n',
    '## Beta — Living Camp Presentation / Optional 3D Renderer\n\nAlpha 0.3E establishes the living camp concept in 2D using the tactical renderer. By Beta, deepen that presentation based on what the finished simulation actually needs to display; move to 3D only if it provides a clear gain over the working 2D camp.\n\nThe menu remains the primary interface. Any 2D or 3D camp renderer is a living representation of settlement state, not a second Sims-style control mode.\n'
)

# Changelog.
replace_once(
    'CHANGELOG.md',
    'This file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n',
    '''This file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n## Alpha 0.3E — Living Camp View — 2026-08-13\n\n### Living Tactical Camp\n- Replaced the active per-tab Camp/Craft/Build splash banners with one persistent **living camp view** rendered from the same tactical tile and survivor art language used outside camp.\n- The pause/main menu now uses that same live camp scene as its background instead of the separate zombie photograph, unifying the game's presentation.\n- Camp structures appear at stable visual anchors as they are actually built: Fire Pit and sleeping space first, then rain catcher, shelter, storage, workbench, sewing table, garden, noise line, and cabin. Active construction gets a visible progress marker before completion.\n- Survivors are the real persistent survivor sprites. Their cosmetic camp position follows authoritative state: crafting walks them to the selected station, building sends them to the relevant construction anchor, garden work goes to the plot, recovery goes to sleeping/cabin space, available survivors idle around camp, and expedition survivors disappear from the settlement view.\n- Camp movement is presentation-only; work timers, status changes, resources, expeditions, and progression remain owned by the existing simulation.\n- Camp daylight follows the actual settlement clock. Night darkens the map while the First Fire and completed cabin add warm local glow.\n\n### Alpha Lighting Test Access\n- Every new founder now starts with **Flashlight** equipped in the Secondary slot so tactical day/night/blackout lighting can always be tested immediately.\n- Save schema advanced to **6** and older Alpha saves are intentionally invalidated instead of migrated.\n\n### Architecture / CI\n- Added `FFCampView.gd` as the living camp/menu presentation owner.\n- Expanded deterministic architecture smoke coverage for camp station/building anchors and permanent CI validation for the new module, schema, and founder flashlight guarantee.\n\n'''
)

# Remove the temporary integration artifacts from the resulting tree in the
# workflow's commit step. The workflow performs git rm after this script exits.
print('camp 0.3E patch prepared')
