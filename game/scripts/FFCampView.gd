extends Control
class_name FFCampView

const Tiles = preload("res://scripts/FFTacticalTiles.gd")
const Visuals = preload("res://scripts/FFTacticalVisuals.gd")

const GRID_W := 18
const GRID_H := 11
const FIRE_CELL := Vector2i(7, 4)
const SLEEP_CELL := Vector2i(5, 6)
const IDLE_CELLS := [
    Vector2i(6, 4), Vector2i(8, 4), Vector2i(7, 5), Vector2i(6, 5),
    Vector2i(8, 5), Vector2i(5, 4), Vector2i(9, 4), Vector2i(7, 3),
    Vector2i(4, 9), Vector2i(8, 9), Vector2i(12, 8), Vector2i(15, 8),
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
    "Water Tank": Vector2i(1, 2),
    "Communal Table": Vector2i(7, 6),
    "Infirmary": Vector2i(14, 6),
    "Watch Post": Vector2i(14, 2),
    "Bunkhouse": Vector2i(3, 7),
    "Armory": Vector2i(14, 4),
    "Dormitory": Vector2i(10, 7),
}
const STATION_OFFSETS := {
    "Fire Pit": Vector2i(0, 1),
    "Workbench": Vector2i(-1, 0),
    "Sewing Table": Vector2i(1, 0),
}

var actor_positions := {}
var actor_facing := {}
var redraw_accum := 0.0
var chatter_entry := {}
var chatter_until_ms := 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    custom_minimum_size = Vector2(0, 270)
    set_process(true)
    if not Game.camp_chatter_requested.is_connected(_on_camp_chatter):
        Game.camp_chatter_requested.connect(_on_camp_chatter)
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
    var now_ms := Time.get_ticks_msec()
    if not chatter_entry.is_empty() and now_ms >= chatter_until_ms:
        chatter_entry = {}
        moved = true
    elif not chatter_entry.is_empty():
        moved = true
    redraw_accum += delta
    if moved or redraw_accum >= 0.16:
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
    var camp_activity: Dictionary = survivor.get("camp_activity", {})
    match str(camp_activity.get("kind", "")):
        "maintain_fire", "watch_fire": return FIRE_CELL + Vector2i(0, 1)
        "rest": return Vector2i(12, 6) if bool(Game.buildings.get("Cabin", false)) else SLEEP_CELL
        "wash": return building_cell("Water Tank") + Vector2i(1, 0) if bool(Game.buildings.get("Water Tank", false)) else building_cell("Rain Catcher") + Vector2i(1, 0)
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
    draw_rect(Rect2(Vector2.ZERO, size), Color("050b09"))
    _draw_ground_layer(origin, tile)
    _draw_camp_zones(origin, tile)
    _draw_perimeter(origin, tile)
    _draw_camp_details(origin, tile)
    _draw_structure_shadows(origin, tile)
    _draw_structures(origin, tile)
    _draw_construction(origin, tile)
    _draw_night(origin, tile)
    _draw_ambient_life(origin, tile)
    _draw_survivors(origin, tile)
    _draw_chatter(origin, tile)
    draw_rect(Rect2(origin, map_size), Color(0.38, 0.49, 0.40, 0.55), false, 1.0)
    var font: Font = get_theme_default_font()
    var title_size: int = maxi(9, int(tile * 0.38))
    draw_string(font, origin + Vector2(7.0, float(title_size) + 4.0), "FIRST FIRE CAMP  •  %s  •  %s" % [Game.formatted_time(), _day_phase()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.94, 0.94, 0.86, 0.95))

func _cell_rect(cell: Vector2i, origin: Vector2, tile: float) -> Rect2:
    return Rect2(origin + Vector2(float(cell.x) * tile, float(cell.y) * tile), Vector2(tile, tile))

func _cell_center(cell: Vector2i, origin: Vector2, tile: float) -> Vector2:
    return origin + Vector2((float(cell.x) + 0.5) * tile, (float(cell.y) + 0.5) * tile)

func _grid_center(pos: Vector2, origin: Vector2, tile: float) -> Vector2:
    return origin + Vector2((pos.x + 0.5) * tile, (pos.y + 0.5) * tile)

func _path_cell(cell: Vector2i) -> bool:
    if cell.y == 4 and cell.x >= 2 and cell.x <= 15:
        return true
    if cell.x == 7 and cell.y >= 1 and cell.y <= 9:
        return true
    if cell.y == 8 and cell.x >= 3 and cell.x <= 15:
        return true
    if cell.x == 3 and cell.y >= 4 and cell.y <= 8:
        return true
    if cell.x == 12 and cell.y >= 4 and cell.y <= 8:
        return true
    if cell.y == 2 and cell.x >= 7 and cell.x <= 14:
        return true
    return false

func _cell_variation(cell: Vector2i, salt: int) -> float:
    var value: int = posmod(cell.x * 73 + cell.y * 151 + salt * 37, 997)
    return float(value) / 996.0

func _draw_ground_layer(origin: Vector2, tile: float) -> void:
    for y in range(GRID_H):
        for x in range(GRID_W):
            var cell := Vector2i(x, y)
            var kind := "dirt" if _path_cell(cell) else "grass"
            var rect := _cell_rect(cell, origin, tile)
            Tiles.draw_ground(self, rect, kind)
            if kind == "grass":
                var variation := _cell_variation(cell, 1)
                if variation > 0.62:
                    var center := rect.get_center()
                    var offset := Vector2((variation - 0.75) * tile * 0.70, (_cell_variation(cell, 3) - 0.5) * tile * 0.50)
                    var tuft := center + offset
                    draw_line(tuft + Vector2(-tile * 0.05, tile * 0.08), tuft, Color(0.28, 0.43, 0.25, 0.62), maxf(1.0, tile * 0.025))
                    draw_line(tuft + Vector2(tile * 0.05, tile * 0.08), tuft, Color(0.34, 0.49, 0.29, 0.56), maxf(1.0, tile * 0.025))
            elif _cell_variation(cell, 5) > 0.80:
                var pebble := rect.get_center() + Vector2((_cell_variation(cell, 8) - 0.5) * tile * 0.55, (_cell_variation(cell, 9) - 0.5) * tile * 0.35)
                draw_circle(pebble, maxf(1.0, tile * 0.035), Color(0.33, 0.30, 0.25, 0.60))

func _draw_camp_zones(origin: Vector2, tile: float) -> void:
    var fire_center := _cell_center(FIRE_CELL, origin, tile)
    draw_circle(fire_center, tile * 1.28, Color(0.20, 0.14, 0.08, 0.25))
    draw_circle(fire_center, tile * 1.12, Color(0.48, 0.34, 0.16, 0.22), false, maxf(1.0, tile * 0.035))

    var sleep_zone := Rect2(_cell_rect(Vector2i(2, 5), origin, tile).position, Vector2(tile * 4.2, tile * 4.1)).grow(-tile * 0.08)
    draw_rect(sleep_zone, Color(0.16, 0.20, 0.17, 0.22))
    draw_rect(sleep_zone, Color(0.42, 0.48, 0.36, 0.22), false, maxf(1.0, tile * 0.025))

    var work_zone := Rect2(_cell_rect(Vector2i(9, 1), origin, tile).position, Vector2(tile * 6.4, tile * 2.8)).grow(-tile * 0.08)
    draw_rect(work_zone, Color(0.20, 0.18, 0.14, 0.22))
    draw_rect(work_zone, Color(0.53, 0.45, 0.30, 0.20), false, maxf(1.0, tile * 0.025))

    var service_zone := Rect2(_cell_rect(Vector2i(9, 5), origin, tile).position, Vector2(tile * 6.5, tile * 3.8)).grow(-tile * 0.08)
    draw_rect(service_zone, Color(0.14, 0.18, 0.18, 0.18))
    draw_rect(service_zone, Color(0.39, 0.52, 0.50, 0.16), false, maxf(1.0, tile * 0.025))

func _draw_perimeter(origin: Vector2, tile: float) -> void:
    var fence := Color("5c5446")
    var wire := Color(0.46, 0.46, 0.39, 0.55)
    for x in range(1, GRID_W - 1):
        if x in [7, 8]:
            continue
        if x % 2 == 0:
            var top := _cell_center(Vector2i(x, 0), origin, tile)
            var bottom := _cell_center(Vector2i(x, GRID_H - 1), origin, tile)
            draw_line(top + Vector2(0, -tile * 0.34), top + Vector2(0, tile * 0.34), fence, maxf(1.0, tile * 0.055))
            draw_line(bottom + Vector2(0, -tile * 0.34), bottom + Vector2(0, tile * 0.34), fence, maxf(1.0, tile * 0.055))
    for y in range(1, GRID_H - 1):
        if y % 2 == 0:
            var left := _cell_center(Vector2i(0, y), origin, tile)
            var right := _cell_center(Vector2i(GRID_W - 1, y), origin, tile)
            draw_line(left + Vector2(-tile * 0.34, 0), left + Vector2(tile * 0.34, 0), fence, maxf(1.0, tile * 0.055))
            draw_line(right + Vector2(-tile * 0.34, 0), right + Vector2(tile * 0.34, 0), fence, maxf(1.0, tile * 0.055))
    draw_line(_cell_center(Vector2i(1, 0), origin, tile), _cell_center(Vector2i(16, 0), origin, tile), wire, maxf(1.0, tile * 0.025))
    draw_line(_cell_center(Vector2i(1, 10), origin, tile), _cell_center(Vector2i(6, 10), origin, tile), wire, maxf(1.0, tile * 0.025))
    draw_line(_cell_center(Vector2i(9, 10), origin, tile), _cell_center(Vector2i(16, 10), origin, tile), wire, maxf(1.0, tile * 0.025))
    var gate_left := _cell_center(Vector2i(6, 10), origin, tile)
    var gate_right := _cell_center(Vector2i(9, 10), origin, tile)
    draw_line(gate_left, gate_left + Vector2(tile * 0.62, -tile * 0.18), Color("857b62"), maxf(1.0, tile * 0.05))
    draw_line(gate_right, gate_right + Vector2(-tile * 0.62, -tile * 0.18), Color("857b62"), maxf(1.0, tile * 0.05))

func _draw_camp_details(origin: Vector2, tile: float) -> void:
    var fire := _cell_center(FIRE_CELL, origin, tile)
    draw_line(fire + Vector2(-tile * 0.82, tile * 0.66), fire + Vector2(-tile * 0.28, tile * 0.66), Color("705038"), maxf(2.0, tile * 0.13))
    draw_line(fire + Vector2(tile * 0.28, tile * 0.66), fire + Vector2(tile * 0.82, tile * 0.66), Color("705038"), maxf(2.0, tile * 0.13))
    draw_line(fire + Vector2(-tile * 0.66, -tile * 0.66), fire + Vector2(-tile * 0.20, -tile * 0.66), Color("604633"), maxf(2.0, tile * 0.10))

    if int(Game.resources.get("Wood", 0)) > 0:
        var wood_center := _cell_center(Vector2i(9, 3), origin, tile)
        var shown: int = mini(6, maxi(1, int(Game.resources.get("Wood", 0))))
        for i in range(shown):
            var row: int = i / 3
            var col: int = i % 3
            var offset := Vector2((float(col) - 1.0) * tile * 0.18, (float(row) - 0.5) * tile * 0.17)
            draw_line(wood_center + offset + Vector2(-tile * 0.14, 0), wood_center + offset + Vector2(tile * 0.14, 0), Color("765034"), maxf(2.0, tile * 0.085))
            draw_circle(wood_center + offset + Vector2(tile * 0.14, 0), maxf(1.0, tile * 0.035), Color("a17b4f"))

    if bool(Game.buildings.get("Water Tank", false)) or bool(Game.buildings.get("Rain Catcher", false)):
        var wash_cell := building_cell("Water Tank") + Vector2i(1, 0) if bool(Game.buildings.get("Water Tank", false)) else building_cell("Rain Catcher") + Vector2i(1, 0)
        var basin := _cell_rect(wash_cell, origin, tile).grow(-tile * 0.24)
        draw_circle(basin.get_center() + Vector2(0, tile * 0.04), tile * 0.25, Color(0.08, 0.10, 0.10, 0.45))
        draw_circle(basin.get_center(), tile * 0.22, Color("435a61"))
        draw_circle(basin.get_center(), tile * 0.15, Color(0.38, 0.68, 0.78, 0.78))
        draw_arc(basin.get_center(), tile * 0.22, 0.0, TAU, 20, Color("9cb6b5"), maxf(1.0, tile * 0.04))

    Tiles.draw_prop(self, _cell_rect(Vector2i(16, 8), origin, tile).grow(-tile * 0.15), "crate")
    Tiles.draw_prop(self, _cell_rect(Vector2i(4, 9), origin, tile).grow(-tile * 0.18), "barrel")
    Tiles.draw_prop(self, _cell_rect(Vector2i(16, 3), origin, tile).grow(-tile * 0.20), "pallet")
    if bool(Game.buildings.get("Storage Crate", false)):
        Tiles.draw_prop(self, _cell_rect(Vector2i(10, 6), origin, tile).grow(-tile * 0.22), "crate")
    if bool(Game.buildings.get("Communal Table", false)):
        var table_center := _cell_center(building_cell("Communal Table"), origin, tile)
        for offset in [Vector2(-0.46, 0.0), Vector2(0.46, 0.0), Vector2(0.0, 0.46)]:
            draw_circle(table_center + offset * tile, tile * 0.10, Color("5b4834"))

func _draw_structure_shadows(origin: Vector2, tile: float) -> void:
    for building_name in BUILDING_CELLS.keys():
        if not bool(Game.buildings.get(building_name, false)):
            continue
        var cell: Vector2i = BUILDING_CELLS[building_name]
        var center := _cell_center(cell, origin, tile)
        if building_name == "Cabin":
            draw_rect(Rect2(_cell_rect(Vector2i(11, 4), origin, tile).position + Vector2(tile * 0.14, tile * 0.18), Vector2(tile * 3.0, tile * 3.0)), Color(0.01, 0.02, 0.015, 0.30))
        else:
            draw_circle(center + Vector2(tile * 0.08, tile * 0.14), tile * 0.43, Color(0.01, 0.02, 0.015, 0.28))

func _draw_structures(origin: Vector2, tile: float) -> void:
    _draw_fire(origin, tile)
    _draw_bedroll(origin, tile)

    if bool(Game.buildings.get("Rain Catcher", false)):
        _draw_rain_catcher(origin, tile)
    if bool(Game.buildings.get("Makeshift Shelter", false)):
        _draw_tent(origin, tile)
    if bool(Game.buildings.get("Storage Crate", false)):
        _draw_storage(origin, tile)
    if bool(Game.buildings.get("Workbench", false)):
        _draw_workbench(origin, tile)
    if bool(Game.buildings.get("Sewing Table", false)):
        _draw_sewing_table(origin, tile)
    if bool(Game.buildings.get("Garden Plot", false)):
        _draw_garden(origin, tile)
    if bool(Game.buildings.get("Noise Line", false)):
        _draw_noise_line(origin, tile)
    if bool(Game.buildings.get("Cabin", false)):
        _draw_cabin(origin, tile)
    if bool(Game.buildings.get("Water Tank", false)):
        _draw_water_tank(origin, tile)
    if bool(Game.buildings.get("Communal Table", false)):
        _draw_communal_table(origin, tile)
    if bool(Game.buildings.get("Infirmary", false)):
        _draw_infirmary(origin, tile)
    if bool(Game.buildings.get("Watch Post", false)):
        _draw_watch_post(origin, tile)
    if bool(Game.buildings.get("Bunkhouse", false)):
        _draw_bunkhouse(origin, tile)
    if bool(Game.buildings.get("Armory", false)):
        _draw_armory(origin, tile)
    if bool(Game.buildings.get("Dormitory", false)):
        _draw_dormitory(origin, tile)

func _draw_bedroll(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(SLEEP_CELL, origin, tile).grow(-tile * 0.11)
    Tiles.draw_prop(self, r, "bed")
    draw_rect(Rect2(r.position + Vector2(tile * 0.10, tile * 0.60), Vector2(r.size.x * 0.70, tile * 0.10)), Color(0.25, 0.31, 0.28, 0.65))

func _draw_rain_catcher(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Rain Catcher"), origin, tile).grow(-tile * 0.08)
    Tiles.draw_barrel(self, Rect2(r.position + Vector2(r.size.x * 0.18, r.size.y * 0.42), r.size * 0.55))
    draw_line(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.22), r.position + Vector2(r.size.x * 0.88, r.size.y * 0.10), Color("78939a"), maxf(1.0, tile * 0.05))
    draw_line(r.position + Vector2(r.size.x * 0.18, r.size.y * 0.18), r.position + Vector2(r.size.x * 0.18, r.size.y * 0.62), Color("6a6253"), maxf(1.0, tile * 0.04))
    draw_line(r.position + Vector2(r.size.x * 0.82, r.size.y * 0.12), r.position + Vector2(r.size.x * 0.82, r.size.y * 0.62), Color("6a6253"), maxf(1.0, tile * 0.04))

func _draw_tent(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Makeshift Shelter"), origin, tile).grow(-tile * 0.03)
    draw_colored_polygon(PackedVector2Array([
        r.position + Vector2(r.size.x * 0.04, r.size.y * 0.92),
        r.position + Vector2(r.size.x * 0.50, r.size.y * 0.08),
        r.position + Vector2(r.size.x * 0.96, r.size.y * 0.92),
    ]), Color("526b58"))
    draw_colored_polygon(PackedVector2Array([
        r.position + Vector2(r.size.x * 0.50, r.size.y * 0.08),
        r.position + Vector2(r.size.x * 0.96, r.size.y * 0.92),
        r.position + Vector2(r.size.x * 0.66, r.size.y * 0.92),
    ]), Color("3c5043"))
    draw_line(r.position + Vector2(r.size.x * 0.50, r.size.y * 0.10), r.position + Vector2(r.size.x * 0.50, r.size.y * 0.92), Color("c1b690"), maxf(1.0, tile * 0.035))
    draw_line(r.position + Vector2(r.size.x * 0.04, r.size.y * 0.92), r.position + Vector2(r.size.x * 0.96, r.size.y * 0.92), Color("95876b"), maxf(1.0, tile * 0.04))

func _draw_storage(origin: Vector2, tile: float) -> void:
    var cell := building_cell("Storage Crate")
    Tiles.draw_prop(self, _cell_rect(cell, origin, tile).grow(-tile * 0.06), "crate")
    Tiles.draw_prop(self, Rect2(_cell_rect(cell, origin, tile).position + Vector2(tile * 0.48, tile * 0.44), Vector2(tile * 0.42, tile * 0.42)), "crate")

func _draw_workbench(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Workbench"), origin, tile).grow(-tile * 0.05)
    Tiles.draw_prop(self, r, "counter")
    var top_y := r.position.y + r.size.y * 0.30
    draw_line(Vector2(r.position.x + r.size.x * 0.20, top_y), Vector2(r.position.x + r.size.x * 0.80, top_y), Color("bf9a62"), maxf(1.0, tile * 0.05))
    draw_line(r.position + Vector2(r.size.x * 0.64, r.size.y * 0.20), r.position + Vector2(r.size.x * 0.78, r.size.y * 0.42), Color("9fa7a1"), maxf(1.0, tile * 0.04))
    draw_circle(r.position + Vector2(r.size.x * 0.36, r.size.y * 0.28), tile * 0.055, Color("7d8888"))

func _draw_sewing_table(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Sewing Table"), origin, tile).grow(-tile * 0.05)
    Tiles.draw_prop(self, r, "table")
    var machine := Rect2(r.position + Vector2(r.size.x * 0.48, r.size.y * 0.22), Vector2(r.size.x * 0.30, r.size.y * 0.28))
    draw_rect(machine, Color("a6aaa1"))
    draw_circle(r.position + Vector2(r.size.x * 0.28, r.size.y * 0.32), tile * 0.10, Color("c4a3c7"))
    draw_line(r.position + Vector2(r.size.x * 0.24, r.size.y * 0.33), r.position + Vector2(r.size.x * 0.62, r.size.y * 0.35), Color("dfd3df"), maxf(1.0, tile * 0.025))

func _draw_garden(origin: Vector2, tile: float) -> void:
    var garden_rect := _cell_rect(building_cell("Garden Plot"), origin, tile).grow(-tile * 0.04)
    draw_rect(garden_rect, Color("49331f"))
    for row in range(3):
        var py := garden_rect.position.y + garden_rect.size.y * (0.24 + float(row) * 0.25)
        draw_line(Vector2(garden_rect.position.x + tile * 0.06, py), Vector2(garden_rect.end.x - tile * 0.06, py), Color("6a4a2b"), maxf(1.0, tile * 0.04))
        for col in range(3):
            var px := garden_rect.position.x + garden_rect.size.x * (0.22 + float(col) * 0.28)
            draw_line(Vector2(px, py + tile * 0.05), Vector2(px, py - tile * 0.07), Color("668f52"), maxf(1.0, tile * 0.035))
            draw_circle(Vector2(px - tile * 0.04, py - tile * 0.06), tile * 0.035, Color("79a660"))
            draw_circle(Vector2(px + tile * 0.04, py - tile * 0.06), tile * 0.035, Color("79a660"))

func _draw_noise_line(origin: Vector2, tile: float) -> void:
    var color := Color("8e826d")
    for x in range(4, 12):
        var p := _cell_center(Vector2i(x, 1), origin, tile)
        draw_line(p + Vector2(-tile * 0.45, 0), p + Vector2(tile * 0.45, 0), color, maxf(1.0, tile * 0.03))
        draw_line(p + Vector2(0, -tile * 0.24), p + Vector2(0, tile * 0.24), Color("594f42"), maxf(1.0, tile * 0.045))
        if x % 2 == 0:
            draw_circle(p + Vector2(tile * 0.18, tile * 0.05), tile * 0.055, Color("9c8d6f"))

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
    var roof_y := _cell_rect(Vector2i(11, 4), origin, tile).position.y + tile * 0.10
    draw_line(Vector2(_cell_rect(Vector2i(11, 4), origin, tile).position.x, roof_y), Vector2(_cell_rect(Vector2i(14, 4), origin, tile).position.x, roof_y), Color("6b4937"), maxf(2.0, tile * 0.08))

func _draw_water_tank(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Water Tank"), origin, tile).grow(-tile * 0.05)
    Tiles.draw_barrel(self, Rect2(r.position + Vector2(r.size.x * 0.18, 0), r.size * 0.68))
    draw_line(r.position + Vector2(r.size.x * 0.25, r.size.y * 0.66), r.position + Vector2(r.size.x * 0.16, r.size.y), Color("726c5c"), maxf(1.0, tile * 0.05))
    draw_line(r.position + Vector2(r.size.x * 0.70, r.size.y * 0.66), r.position + Vector2(r.size.x * 0.80, r.size.y), Color("726c5c"), maxf(1.0, tile * 0.05))
    draw_circle(r.position + Vector2(r.size.x * 0.53, r.size.y * 0.34), tile * 0.27, Color(0.42, 0.70, 0.86, 0.42), false, maxf(1.0, tile * 0.035))

func _draw_communal_table(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Communal Table"), origin, tile).grow(-tile * 0.05)
    Tiles.draw_prop(self, r, "table")
    draw_line(r.position + Vector2(r.size.x * 0.18, r.size.y * 0.30), r.position + Vector2(r.size.x * 0.82, r.size.y * 0.30), Color("9c7149"), maxf(1.0, tile * 0.045))

func _draw_infirmary(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Infirmary"), origin, tile).grow(-tile * 0.04)
    draw_rect(r, Color(0.25, 0.34, 0.33, 0.88))
    Tiles.draw_prop(self, Rect2(r.position + Vector2(r.size.x * 0.06, r.size.y * 0.22), r.size * 0.78), "bed")
    var c := r.position + Vector2(r.size.x * 0.76, r.size.y * 0.25)
    draw_rect(Rect2(c - Vector2(tile * 0.13, tile * 0.05), Vector2(tile * 0.26, tile * 0.10)), Color("d6e6df"))
    draw_rect(Rect2(c - Vector2(tile * 0.05, tile * 0.13), Vector2(tile * 0.10, tile * 0.26)), Color("d6e6df"))
    draw_line(r.position + Vector2(0, r.size.y * 0.08), r.position + Vector2(r.size.x, r.size.y * 0.08), Color("9fc1ba"), maxf(1.0, tile * 0.04))

func _draw_watch_post(origin: Vector2, tile: float) -> void:
    var c := _cell_center(building_cell("Watch Post"), origin, tile)
    var platform := Rect2(c - Vector2(tile * 0.34, tile * 0.30), Vector2(tile * 0.68, tile * 0.30))
    draw_rect(platform, Color("4d5147"))
    draw_rect(platform, Color("a59674"), false, maxf(1.0, tile * 0.04))
    draw_line(c + Vector2(-tile * 0.26, 0), c + Vector2(-tile * 0.38, tile * 0.48), Color("897e65"), maxf(1.0, tile * 0.06))
    draw_line(c + Vector2(tile * 0.26, 0), c + Vector2(tile * 0.38, tile * 0.48), Color("897e65"), maxf(1.0, tile * 0.06))
    draw_line(c + Vector2(0, -tile * 0.30), c + Vector2(0, -tile * 0.48), Color("9f9478"), maxf(1.0, tile * 0.04))

func _draw_bunkhouse(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Bunkhouse"), origin, tile).grow(-tile * 0.03)
    draw_rect(r, Color("56594f"))
    draw_colored_polygon(PackedVector2Array([
        r.position + Vector2(-tile * 0.05, r.size.y * 0.28),
        r.position + Vector2(r.size.x * 0.50, -tile * 0.08),
        r.position + Vector2(r.size.x + tile * 0.05, r.size.y * 0.28),
    ]), Color("70644f"))
    draw_rect(Rect2(r.position + Vector2(r.size.x * 0.18, r.size.y * 0.52), Vector2(r.size.x * 0.20, r.size.y * 0.32)), Color("2c342f"))
    draw_rect(Rect2(r.position + Vector2(r.size.x * 0.58, r.size.y * 0.52), Vector2(r.size.x * 0.20, r.size.y * 0.32)), Color("2c342f"))

func _draw_armory(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Armory"), origin, tile).grow(-tile * 0.04)
    draw_rect(r, Color("3c423d"))
    Tiles.draw_prop(self, Rect2(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.30), r.size * 0.58), "crate")
    draw_rect(r, Color(0.62, 0.24, 0.18, 0.85), false, maxf(1.0, tile * 0.055))
    draw_line(r.position + Vector2(r.size.x * 0.64, r.size.y * 0.20), r.position + Vector2(r.size.x * 0.78, r.size.y * 0.76), Color("a5aaa2"), maxf(1.0, tile * 0.035))
    draw_line(r.position + Vector2(r.size.x * 0.74, r.size.y * 0.20), r.position + Vector2(r.size.x * 0.88, r.size.y * 0.76), Color("a5aaa2"), maxf(1.0, tile * 0.035))

func _draw_dormitory(origin: Vector2, tile: float) -> void:
    var r := _cell_rect(building_cell("Dormitory"), origin, tile).grow(-tile * 0.02)
    draw_rect(r, Color("4d5a55"))
    draw_colored_polygon(PackedVector2Array([
        r.position + Vector2(-tile * 0.04, r.size.y * 0.26),
        r.position + Vector2(r.size.x * 0.50, -tile * 0.08),
        r.position + Vector2(r.size.x + tile * 0.04, r.size.y * 0.26),
    ]), Color("667064"))
    Tiles.draw_window(self, Rect2(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.36), r.size * 0.30))
    Tiles.draw_window(self, Rect2(r.position + Vector2(r.size.x * 0.58, r.size.y * 0.36), r.size * 0.26))

func _draw_fire(origin: Vector2, tile: float) -> void:
    var center := _cell_center(FIRE_CELL, origin, tile)
    var fire_scale := clampf(float(Game.fire_level) / 100.0, 0.08, 1.0)
    for i in range(10):
        var angle := TAU * float(i) / 10.0
        var stone := center + Vector2(cos(angle), sin(angle)) * tile * 0.31
        draw_circle(stone, tile * 0.075, Color("6b6357"))
        draw_circle(stone, tile * 0.055, Color("8b8172"))
    draw_line(center + Vector2(-tile * 0.21, tile * 0.13), center + Vector2(tile * 0.21, -tile * 0.13), Color("704b2d"), maxf(2.0, tile * 0.085))
    draw_line(center + Vector2(-tile * 0.21, -tile * 0.13), center + Vector2(tile * 0.21, tile * 0.13), Color("704b2d"), maxf(2.0, tile * 0.085))
    var flicker := 0.90 + 0.10 * sin(float(Time.get_ticks_msec()) * 0.014)
    var flame_h := tile * (0.22 + 0.30 * fire_scale) * flicker
    draw_colored_polygon(PackedVector2Array([
        center + Vector2(-tile * 0.18 * fire_scale, tile * 0.14),
        center + Vector2(0, -flame_h),
        center + Vector2(tile * 0.18 * fire_scale, tile * 0.14),
    ]), Color(1.0, 0.28, 0.07, 0.72 + 0.24 * fire_scale))
    draw_colored_polygon(PackedVector2Array([
        center + Vector2(-tile * 0.09 * fire_scale, tile * 0.10),
        center + Vector2(tile * 0.02, -flame_h * 0.62),
        center + Vector2(tile * 0.09 * fire_scale, tile * 0.10),
    ]), Color(1.0, 0.78, 0.20, 0.86))
    draw_circle(center + Vector2(-tile * 0.12, tile * 0.10), tile * 0.035, Color("ffb42e"))
    draw_circle(center + Vector2(tile * 0.13, tile * 0.08), tile * 0.028, Color("e86a26"))

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
        draw_rect(r, Color(0.84, 0.72, 0.42, 0.20))
        draw_rect(r, Color(0.90, 0.78, 0.48, 0.88), false, maxf(1.0, tile * 0.045))
        draw_line(r.position, r.end, Color(0.90, 0.78, 0.48, 0.56), maxf(1.0, tile * 0.03))
        draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(0.90, 0.78, 0.48, 0.56), maxf(1.0, tile * 0.03))
        var duration: float = maxf(0.01, float(task.get("duration", 1.0)))
        var remaining: float = clampf(float(task.get("remaining", duration)), 0.0, duration)
        var progress: float = 1.0 - remaining / duration
        draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3.0), Vector2(r.size.x, 3.0)), Color(0.05, 0.06, 0.05, 0.80))
        draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3.0), Vector2(r.size.x * progress, 3.0)), Color("d6bd63"))

func _camp_hour() -> float:
    var fraction: float = clampf(float(Game.day_elapsed) / maxf(1.0, float(Game.DAY_SECONDS)), 0.0, 1.0)
    return fmod(8.0 + fraction * 24.0, 24.0)

func _day_phase() -> String:
    var hour := _camp_hour()
    if hour >= 20.0 or hour < 5.0: return "NIGHT"
    if hour < 7.0: return "DAWN"
    if hour >= 18.0: return "DUSK"
    return "DAY"

func _night_alpha() -> float:
    var hour := _camp_hour()
    if hour >= 20.0 or hour < 5.0:
        return 0.66
    if hour >= 18.0:
        return lerpf(0.0, 0.66, (hour - 18.0) / 2.0)
    if hour < 7.0:
        return lerpf(0.66, 0.0, (hour - 5.0) / 2.0)
    return 0.0

func _draw_night(origin: Vector2, tile: float) -> void:
    var hour := _camp_hour()
    var map_rect := Rect2(origin, Vector2(tile * float(GRID_W), tile * float(GRID_H)))
    if hour >= 17.0 and hour < 20.0:
        var dusk_alpha := 0.16 * clampf((hour - 17.0) / 3.0, 0.0, 1.0)
        draw_rect(map_rect, Color(0.42, 0.15, 0.05, dusk_alpha))
    elif hour >= 5.0 and hour < 7.0:
        var dawn_alpha := 0.12 * clampf((7.0 - hour) / 2.0, 0.0, 1.0)
        draw_rect(map_rect, Color(0.10, 0.18, 0.34, dawn_alpha))
    var alpha := _night_alpha()
    if alpha <= 0.001:
        return
    draw_rect(map_rect, Color(0.010, 0.025, 0.070, alpha))
    var fire_center := _cell_center(FIRE_CELL, origin, tile)
    var fire_strength := clampf(float(Game.fire_level) / 100.0, 0.0, 1.0)
    var flicker := 0.92 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.012)
    draw_circle(fire_center, tile * (1.1 + 1.75 * fire_strength) * flicker, Color(1.0, 0.30, 0.08, 0.050 * fire_strength))
    draw_circle(fire_center, tile * (0.75 + 1.20 * fire_strength) * flicker, Color(1.0, 0.46, 0.10, 0.090 * fire_strength))
    draw_circle(fire_center, tile * (0.45 + 0.65 * fire_strength), Color(1.0, 0.70, 0.22, 0.17 * fire_strength))
    if bool(Game.buildings.get("Cabin", false)):
        var window_rect := _cell_rect(Vector2i(12, 4), origin, tile).grow(-tile * 0.24)
        draw_rect(window_rect, Color(1.0, 0.69, 0.30, 0.34))
        draw_circle(window_rect.get_center(), tile * 1.80, Color(1.0, 0.66, 0.28, 0.07))
    if bool(Game.buildings.get("Infirmary", false)):
        var infirmary_center := _cell_center(building_cell("Infirmary"), origin, tile)
        draw_circle(infirmary_center, tile * 1.25, Color(0.58, 0.82, 0.90, 0.07))
    if bool(Game.buildings.get("Watch Post", false)):
        var watch_center := _cell_center(building_cell("Watch Post"), origin, tile)
        draw_circle(watch_center, tile * 0.92, Color(0.78, 0.86, 0.72, 0.065))

func _draw_ambient_life(origin: Vector2, tile: float) -> void:
    var fire_strength := clampf(float(Game.fire_level) / 100.0, 0.0, 1.0)
    if fire_strength <= 0.03:
        return
    var center := _cell_center(FIRE_CELL, origin, tile)
    var t := float(Time.get_ticks_msec()) * 0.001
    for i in range(3):
        var phase := fmod(t * (0.34 + float(i) * 0.06) + float(i) * 0.31, 1.0)
        var smoke_pos := center + Vector2(sin(t * 1.4 + float(i)) * tile * 0.10, -tile * (0.45 + phase * 0.95))
        var smoke_color := Color(0.54, 0.55, 0.50, (0.10 - phase * 0.07) * fire_strength)
        draw_circle(smoke_pos, tile * (0.10 + phase * 0.12), smoke_color)
    for i in range(2):
        var spark_phase := fmod(t * (0.75 + float(i) * 0.12) + float(i) * 0.48, 1.0)
        var spark := center + Vector2((float(i) * 2.0 - 1.0) * tile * (0.10 + spark_phase * 0.16), -tile * (0.20 + spark_phase * 0.62))
        draw_circle(spark, maxf(1.0, tile * 0.026), Color(1.0, 0.55, 0.12, (1.0 - spark_phase) * 0.78 * fire_strength))

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
        draw_set_transform(center + Vector2(tile * 0.03, tile * 0.27), 0.0, Vector2(1.0, 0.34))
        draw_circle(Vector2.ZERO, tile * 0.25, Color(0.01, 0.02, 0.015, 0.34))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        _draw_activity_graphic(survivor, center, tile)
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
        draw_string(font, center + Vector2(-tile * 0.52, -tile * 0.50), first_name, HORIZONTAL_ALIGNMENT_CENTER, tile * 1.04, font_size, Color(0.97, 0.97, 0.91, 0.98))
        _draw_need_pips(survivor, center, tile)
        var activity := _activity_short(survivor)
        if activity != "":
            draw_string(font, center + Vector2(-tile * 0.52, tile * 0.70), activity, HORIZONTAL_ALIGNMENT_CENTER, tile * 1.04, maxi(7, font_size - 2), Color(0.91, 0.80, 0.48, 0.96))

func _draw_activity_graphic(survivor: Dictionary, center: Vector2, tile: float) -> void:
    var activity: Dictionary = survivor.get("camp_activity", {})
    var kind := str(activity.get("kind", ""))
    if kind == "maintain_fire":
        draw_line(center + Vector2(-tile * 0.34, tile * 0.28), center + Vector2(tile * 0.05, tile * 0.08), Color("805336"), maxf(2.0, tile * 0.08))
        draw_circle(center + Vector2(tile * 0.26, -tile * 0.20), tile * 0.045, Color("f2b143"))
        draw_circle(center + Vector2(tile * 0.36, -tile * 0.30), tile * 0.030, Color("e46f32"))
    elif kind == "watch_fire":
        draw_line(center + Vector2(-tile * 0.30, tile * 0.34), center + Vector2(tile * 0.30, tile * 0.34), Color("704f37"), maxf(2.0, tile * 0.10))
        draw_arc(center + Vector2(0, -tile * 0.05), tile * 0.22, PI * 0.15, PI * 0.85, 10, Color(0.95, 0.70, 0.30, 0.70), maxf(1.0, tile * 0.04))
    elif kind == "rest":
        var font := get_theme_default_font()
        var z_size: int = maxi(8, int(tile * 0.34))
        draw_string(font, center + Vector2(tile * 0.16, -tile * 0.25), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, z_size, Color(0.72, 0.82, 0.92, 0.90))
        draw_string(font, center + Vector2(tile * 0.30, -tile * 0.42), "z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(7, z_size - 2), Color(0.72, 0.82, 0.92, 0.72))
    elif kind == "wash":
        draw_circle(center + Vector2(-tile * 0.25, -tile * 0.16), tile * 0.06, Color(0.42, 0.76, 0.90, 0.82))
        draw_circle(center + Vector2(tile * 0.24, -tile * 0.10), tile * 0.05, Color(0.42, 0.76, 0.90, 0.72))
        draw_arc(center + Vector2(0, tile * 0.28), tile * 0.24, 0.0, PI, 12, Color("8fb7bd"), maxf(1.0, tile * 0.05))

func _draw_need_pips(survivor: Dictionary, center: Vector2, tile: float) -> void:
    var needs: Dictionary = survivor.get("needs", {})
    if needs.is_empty():
        return
    var values := [
        float(needs.get("hunger", 100.0)),
        float(needs.get("thirst", 100.0)),
        float(needs.get("sleep", 100.0)),
        float(needs.get("fun", 100.0)),
        float(needs.get("safety", 100.0)),
        float(needs.get("hygiene", 100.0)),
    ]
    var colors := [Color("d69b52"), Color("66a8d7"), Color("879bd0"), Color("c28ad0"), Color("7eaf78"), Color("7fc0bd")]
    var radius: float = maxf(1.5, tile * 0.055)
    var start_x: float = center.x - tile * 0.36
    for i in range(values.size()):
        var value: float = values[i]
        var alpha: float = 0.30 if value >= 60.0 else (0.70 if value >= 35.0 else 1.0)
        var p := Vector2(start_x + float(i) * tile * 0.145, center.y + tile * 0.49)
        var c: Color = colors[i]
        c.a = alpha
        draw_circle(p, radius, c)
        if value < 35.0:
            draw_arc(p, radius + 1.0, 0.0, TAU, 12, Color(0.95, 0.90, 0.76, 0.90), 1.0)

func _on_camp_chatter(data: Dictionary) -> void:
    if not is_visible_in_tree():
        return
    var speaker_id := int(data.get("speaker_id", -1))
    if not actor_positions.has(speaker_id):
        return
    chatter_entry = data.duplicate(true)
    chatter_until_ms = Time.get_ticks_msec() + 3400
    queue_redraw()

func _draw_chatter(origin: Vector2, tile: float) -> void:
    if chatter_entry.is_empty() or Time.get_ticks_msec() >= chatter_until_ms:
        return
    var sid := int(chatter_entry.get("speaker_id", -1))
    if not actor_positions.has(sid):
        return
    var center := _grid_center(actor_positions[sid], origin, tile)
    var width := minf(tile * 6.2, tile * float(GRID_W) - 8.0)
    var height := maxf(34.0, tile * 1.35)
    var x := clampf(center.x - width * 0.5, origin.x + 4.0, origin.x + tile * float(GRID_W) - width - 4.0)
    var y := clampf(center.y - height - tile * 0.65, origin.y + 20.0, origin.y + tile * float(GRID_H) - height - 4.0)
    var box := Rect2(Vector2(x, y), Vector2(width, height))
    var tone := str(chatter_entry.get("tone", "neutral"))
    var border := Color("d7bd58")
    if tone in ["friendly", "warm"]: border = Color("78b987")
    elif tone in ["hostile", "tense"]: border = Color("c35a4d")
    elif tone == "politics": border = Color("8f78c7")
    elif tone == "worry": border = Color("c9a15a")
    draw_rect(box, Color(0.025, 0.035, 0.032, 0.92))
    draw_rect(box, border, false, 1.3)
    var font := get_theme_default_font()
    var header := "%s → %s" % [str(chatter_entry.get("speaker_name", "?")), str(chatter_entry.get("listener_name", "?"))]
    draw_string(font, box.position + Vector2(4.0, 11.0), header, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 8.0, 8, border)
    draw_string(font, box.position + Vector2(4.0, 25.0), str(chatter_entry.get("text", "...")), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 8.0, 8, Color(0.94, 0.94, 0.88, 0.98))

func _activity_short(survivor: Dictionary) -> String:
    var status := str(survivor.get("status", "Available"))
    match status:
        "Crafting": return "CRAFT"
        "Building": return "BUILD"
        "Recovering": return "RECOVER"
        "Tending": return "GARDEN"
    var a: Dictionary = survivor.get("camp_activity", {})
    match str(a.get("kind", "")):
        "maintain_fire": return "FIRE"
        "watch_fire": return "WATCH FIRE"
        "rest": return "REST"
        "wash": return "WASH"
    return ""