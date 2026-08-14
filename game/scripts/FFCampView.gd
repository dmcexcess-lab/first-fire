extends Control
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
    custom_minimum_size = Vector2(0, 210)
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
    _draw_chatter(origin, tile)
    draw_rect(Rect2(origin, map_size), Color(0.30, 0.42, 0.35, 0.55), false, 1.0)
    var font: Font = get_theme_default_font()
    var title_size: int = maxi(9, int(tile * 0.38))
    draw_string(font, origin + Vector2(7.0, float(title_size) + 4.0), "FIRST FIRE CAMP  •  %s  •  %s" % [Game.formatted_time(), _day_phase()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.92, 0.94, 0.88, 0.92))

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
    if bool(Game.buildings.get("Water Tank", false)):
        var tank_rect := _cell_rect(building_cell("Water Tank"), origin, tile).grow(-tile * 0.03)
        Tiles.draw_barrel(self, tank_rect)
        draw_circle(tank_rect.get_center(), tile * 0.38, Color(0.42, 0.70, 0.86, 0.65), false, 1.5)
    if bool(Game.buildings.get("Communal Table", false)):
        Tiles.draw_prop(self, _cell_rect(building_cell("Communal Table"), origin, tile).grow(-tile * 0.04), "table")
    if bool(Game.buildings.get("Infirmary", false)):
        var infirmary_rect := _cell_rect(building_cell("Infirmary"), origin, tile).grow(-tile * 0.04)
        Tiles.draw_prop(self, infirmary_rect, "bed")
        var ic := infirmary_rect.get_center()
        draw_line(ic + Vector2(-tile * 0.11, 0), ic + Vector2(tile * 0.11, 0), Color("d7e7df"), 2.0)
        draw_line(ic + Vector2(0, -tile * 0.11), ic + Vector2(0, tile * 0.11), Color("d7e7df"), 2.0)
    if bool(Game.buildings.get("Watch Post", false)):
        var wc := _cell_center(building_cell("Watch Post"), origin, tile)
        draw_rect(Rect2(wc - Vector2(tile * 0.30, tile * 0.30), Vector2(tile * 0.60, tile * 0.60)), Color("4b5146"))
        draw_line(wc + Vector2(0, tile * 0.28), wc + Vector2(-tile * 0.20, tile * 0.48), Color("897e65"), 2.0)
        draw_line(wc + Vector2(0, tile * 0.28), wc + Vector2(tile * 0.20, tile * 0.48), Color("897e65"), 2.0)
    if bool(Game.buildings.get("Bunkhouse", false)):
        var br := _cell_rect(building_cell("Bunkhouse"), origin, tile).grow(-tile * 0.03)
        draw_rect(br, Color("5a594d"))
        draw_polyline(PackedVector2Array([br.position + Vector2(0, br.size.y * 0.35), br.position + Vector2(br.size.x * 0.5, 0), br.position + Vector2(br.size.x, br.size.y * 0.35)]), Color("a69c7b"), 2.0)
    if bool(Game.buildings.get("Armory", false)):
        var ar := _cell_rect(building_cell("Armory"), origin, tile).grow(-tile * 0.04)
        Tiles.draw_prop(self, ar, "crate")
        draw_rect(ar, Color(0.62, 0.24, 0.18, 0.85), false, 2.0)
    if bool(Game.buildings.get("Dormitory", false)):
        var dr := _cell_rect(building_cell("Dormitory"), origin, tile).grow(-tile * 0.02)
        draw_rect(dr, Color("4d5a55"))
        Tiles.draw_window(self, Rect2(dr.position + Vector2(dr.size.x * 0.18, dr.size.y * 0.18), dr.size * 0.34))
        Tiles.draw_window(self, Rect2(dr.position + Vector2(dr.size.x * 0.55, dr.size.y * 0.18), dr.size * 0.28))

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
        return 0.64
    if hour >= 18.0:
        return lerpf(0.0, 0.64, (hour - 18.0) / 2.0)
    if hour < 7.0:
        return lerpf(0.64, 0.0, (hour - 5.0) / 2.0)
    return 0.0

func _draw_night(origin: Vector2, tile: float) -> void:
    var hour := _camp_hour()
    var map_rect := Rect2(origin, Vector2(tile * float(GRID_W), tile * float(GRID_H)))
    if hour >= 17.0 and hour < 20.0:
        var dusk_alpha := 0.10 * clampf((hour - 17.0) / 3.0, 0.0, 1.0)
        draw_rect(map_rect, Color(0.34, 0.12, 0.05, dusk_alpha))
    elif hour >= 5.0 and hour < 7.0:
        var dawn_alpha := 0.08 * clampf((7.0 - hour) / 2.0, 0.0, 1.0)
        draw_rect(map_rect, Color(0.10, 0.18, 0.30, dawn_alpha))
    var alpha := _night_alpha()
    if alpha <= 0.001:
        return
    draw_rect(map_rect, Color(0.015, 0.035, 0.085, alpha))
    var fire_center := _cell_center(FIRE_CELL, origin, tile)
    draw_circle(fire_center, tile * 2.25, Color(1.0, 0.36, 0.10, 0.055))
    draw_circle(fire_center, tile * 1.55, Color(1.0, 0.48, 0.12, 0.085))
    draw_circle(fire_center, tile * 0.90, Color(1.0, 0.68, 0.20, 0.14))
    if bool(Game.buildings.get("Cabin", false)):
        var cabin_center := _cell_center(Vector2i(12, 5), origin, tile)
        draw_circle(cabin_center, tile * 1.7, Color(1.0, 0.72, 0.34, 0.075))
    if bool(Game.buildings.get("Infirmary", false)):
        var infirmary_center := _cell_center(building_cell("Infirmary"), origin, tile)
        draw_circle(infirmary_center, tile * 1.20, Color(0.58, 0.82, 0.90, 0.065))
    if bool(Game.buildings.get("Watch Post", false)):
        var watch_center := _cell_center(building_cell("Watch Post"), origin, tile)
        draw_circle(watch_center, tile * 0.80, Color(0.78, 0.86, 0.72, 0.055))

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

func _activity_short(status: String) -> String:
    match status:
        "Crafting": return "CRAFT"
        "Building": return "BUILD"
        "Recovering": return "RECOVER"
        "Tending": return "GARDEN"
        _: return ""
