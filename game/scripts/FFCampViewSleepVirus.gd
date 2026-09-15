extends "res://scripts/FFCampView.gd"

signal survivor_pressed(survivor_id: int)
signal craft_station_pressed(station_name: String)
signal build_plot_pressed(building_name: String)
signal building_pressed(building_name: String)
signal communal_inventory_pressed
signal duties_pressed
signal gate_pressed

const CAMP_CHEST_CELL := Vector2i(8, 6)
const WORK_BOARD_CELL := Vector2i(5, 3)
const MENU_VISIBLE_GRID_WIDTH := 8.5
const PAN_DRAG_THRESHOLD := 8.0

var menu_mode := false
var menu_pan := Vector2.ZERO
var drag_active := false
var drag_start := Vector2.ZERO
var drag_pan_start := Vector2.ZERO
var drag_moved := false

func _ready() -> void:
    super._ready()
    set_menu_mode(menu_mode)

func set_menu_mode(active: bool) -> void:
    menu_mode = active
    mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _camp_geometry() -> Dictionary:
    if not menu_mode:
        var base_tile: float = minf(size.x / float(GRID_W), size.y / float(GRID_H))
        var base_map_size := Vector2(base_tile * float(GRID_W), base_tile * float(GRID_H))
        return {"tile": base_tile, "origin": (size - base_map_size) * 0.5, "map_size": base_map_size}
    var tile: float = maxf(size.x / MENU_VISIBLE_GRID_WIDTH, size.y / float(GRID_H))
    var map_size := Vector2(tile * float(GRID_W), tile * float(GRID_H))
    var base_origin := (size - map_size) * 0.5
    var origin := Vector2(
        _panned_axis_origin(size.x, map_size.x, base_origin.x, menu_pan.x),
        _panned_axis_origin(size.y, map_size.y, base_origin.y, menu_pan.y)
    )
    return {"tile": tile, "origin": origin, "map_size": map_size}

func _panned_axis_origin(view_size: float, map_size: float, base_origin: float, pan: float) -> float:
    if map_size <= view_size:
        return (view_size - map_size) * 0.5
    return clampf(base_origin + pan, view_size - map_size, 0.0)

func _set_menu_pan(value: Vector2) -> void:
    var tile: float = maxf(size.x / MENU_VISIBLE_GRID_WIDTH, size.y / float(GRID_H))
    var map_size := Vector2(tile * float(GRID_W), tile * float(GRID_H))
    var base_origin := (size - map_size) * 0.5
    var next := value
    if map_size.x <= size.x:
        next.x = 0.0
    else:
        next.x = clampf(next.x, size.x - map_size.x - base_origin.x, -base_origin.x)
    if map_size.y <= size.y:
        next.y = 0.0
    else:
        next.y = clampf(next.y, size.y - map_size.y - base_origin.y, -base_origin.y)
    menu_pan = next
    queue_redraw()

func _draw() -> void:
    if size.x <= 8.0 or size.y <= 8.0:
        return
    var geometry := _camp_geometry()
    var tile: float = float(geometry["tile"])
    var origin: Vector2 = geometry["origin"]
    var map_size: Vector2 = geometry["map_size"]
    draw_rect(Rect2(Vector2.ZERO, size), Color("050b09"))
    _draw_ground_layer(origin, tile)
    _draw_camp_zones(origin, tile)
    _draw_perimeter(origin, tile)
    _draw_build_plots(origin, tile)
    _draw_camp_details(origin, tile)
    _draw_structure_shadows(origin, tile)
    _draw_structures(origin, tile)
    _draw_construction(origin, tile)
    _draw_communal_chest(origin, tile)
    _draw_work_board(origin, tile)
    _draw_night(origin, tile)
    _draw_ambient_life(origin, tile)
    _draw_survivors(origin, tile)
    _draw_chatter(origin, tile)
    if menu_mode:
        _draw_menu_affordances(origin, tile)
    draw_rect(Rect2(origin, map_size), Color(0.38, 0.49, 0.40, 0.55), false, 1.0)
    var font: Font = get_theme_default_font()
    var title_size: int = maxi(9, int(tile * 0.38))
    var title_origin := Vector2(7.0, float(title_size) + 4.0) if menu_mode else origin + Vector2(7.0, float(title_size) + 4.0)
    draw_string(font, title_origin, "FIRST FIRE CAMP  •  DAY %d" % Game.day, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.94, 0.94, 0.86, 0.95))

func _draw_build_plots(origin: Vector2, tile: float) -> void:
    if not menu_mode:
        return
    for building_value in BUILDING_CELLS.keys():
        var building_name := str(building_value)
        if bool(Game.buildings.get(building_name, false)):
            continue
        var cell: Vector2i = BUILDING_CELLS[building_value]
        var rect := _cell_rect(cell, origin, tile).grow(-tile * 0.14)
        draw_rect(rect, Color(0.78, 0.70, 0.45, 0.04))
        draw_rect(rect, Color(0.82, 0.74, 0.48, 0.32), false, maxf(1.0, tile * 0.025))
        draw_line(rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.50), rect.position + Vector2(rect.size.x * 0.66, rect.size.y * 0.50), Color(0.93, 0.84, 0.58, 0.58), maxf(1.0, tile * 0.04))
        draw_line(rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.34), rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.66), Color(0.93, 0.84, 0.58, 0.58), maxf(1.0, tile * 0.04))

func _draw_communal_chest(origin: Vector2, tile: float) -> void:
    var rect := _cell_rect(CAMP_CHEST_CELL, origin, tile).grow(-tile * 0.14)
    Tiles.draw_prop(self, rect, "crate")
    draw_rect(rect, Color(0.87, 0.72, 0.39, 0.72), false, maxf(1.0, tile * 0.035))

func _draw_work_board(origin: Vector2, tile: float) -> void:
    var rect := _cell_rect(WORK_BOARD_CELL, origin, tile).grow(-tile * 0.16)
    draw_rect(rect, Color("493a28"))
    draw_rect(rect, Color("b49a62"), false, maxf(1.0, tile * 0.045))
    draw_line(rect.position + Vector2(tile * 0.18, rect.size.y), rect.position + Vector2(tile * 0.18, rect.size.y + tile * 0.28), Color("725338"), maxf(2.0, tile * 0.07))
    draw_line(rect.position + Vector2(rect.size.x - tile * 0.18, rect.size.y), rect.position + Vector2(rect.size.x - tile * 0.18, rect.size.y + tile * 0.28), Color("725338"), maxf(2.0, tile * 0.07))
    draw_line(rect.position + Vector2(tile * 0.12, tile * 0.20), rect.position + Vector2(rect.size.x - tile * 0.12, tile * 0.20), Color("d8cfaa"), maxf(1.0, tile * 0.035))
    draw_line(rect.position + Vector2(tile * 0.12, tile * 0.42), rect.position + Vector2(rect.size.x * 0.68, tile * 0.42), Color("d8cfaa"), maxf(1.0, tile * 0.035))

func _draw_menu_affordances(origin: Vector2, tile: float) -> void:
    _draw_interaction_ring(_cell_center(CAMP_CHEST_CELL, origin, tile), tile * 0.42)
    _draw_interaction_ring(_cell_center(FIRE_CELL, origin, tile), tile * 0.48)
    _draw_interaction_ring(_cell_center(WORK_BOARD_CELL, origin, tile), tile * 0.42)
    if bool(Game.buildings.get("Workbench", false)):
        _draw_interaction_ring(_cell_center(building_cell("Workbench"), origin, tile), tile * 0.42)
    if bool(Game.buildings.get("Sewing Table", false)):
        _draw_interaction_ring(_cell_center(building_cell("Sewing Table"), origin, tile), tile * 0.42)
    var gate_center := (_cell_center(Vector2i(7, GRID_H - 1), origin, tile) + _cell_center(Vector2i(8, GRID_H - 1), origin, tile)) * 0.5
    _draw_interaction_ring(gate_center, tile * 0.55)

    if Game.camp_chore_needed("stoke_fire"):
        _draw_alert_badge(_cell_center(FIRE_CELL, origin, tile) + Vector2(tile * 0.42, -tile * 0.38), tile)
    var clean_needed := Game.camp_chore_needed("clean_camp")
    var repair_needed := Game.camp_chore_needed("repair_perimeter")
    if clean_needed or repair_needed:
        _draw_alert_badge(_cell_center(WORK_BOARD_CELL, origin, tile) + Vector2(tile * 0.38, -tile * 0.38), tile)
    if clean_needed:
        for dirt_cell in [Vector2i(6, 8), Vector2i(9, 9), Vector2i(11, 8)]:
            var dirt_center := _cell_center(dirt_cell, origin, tile)
            draw_circle(dirt_center, tile * 0.09, Color(0.33, 0.24, 0.14, 0.48))
            draw_circle(dirt_center + Vector2(tile * 0.12, tile * 0.05), tile * 0.05, Color(0.25, 0.19, 0.12, 0.42))
    if repair_needed:
        var fence_rect := _cell_rect(Vector2i(16, 5), origin, tile).grow(-tile * 0.10)
        draw_line(fence_rect.position + Vector2(0, fence_rect.size.y * 0.25), fence_rect.end - Vector2(0, fence_rect.size.y * 0.25), Color(0.92, 0.56, 0.34, 0.92), maxf(2.0, tile * 0.06))
        draw_line(fence_rect.position + Vector2(fence_rect.size.x, fence_rect.size.y * 0.25), fence_rect.position + Vector2(0, fence_rect.size.y * 0.75), Color(0.92, 0.56, 0.34, 0.92), maxf(2.0, tile * 0.06))

func _draw_interaction_ring(center: Vector2, radius: float) -> void:
    draw_arc(center, radius, 0.0, TAU, 22, Color(0.83, 0.73, 0.46, 0.42), maxf(1.0, radius * 0.05))

func _draw_alert_badge(center: Vector2, tile: float) -> void:
    var radius := maxf(8.0, tile * 0.18)
    draw_circle(center, radius, Color(0.70, 0.24, 0.18, 0.94))
    draw_arc(center, radius, 0.0, TAU, 18, Color(0.98, 0.82, 0.45, 0.95), 1.0)
    var font := get_theme_default_font()
    var font_size := maxi(9, int(tile * 0.26))
    draw_string(font, center + Vector2(-radius, float(font_size) * 0.36), "!", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
    if not menu_mode:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            _begin_pan_drag(event.position)
        else:
            _finish_pan_drag(event.position)
        accept_event()
        return
    if event is InputEventScreenDrag and drag_active:
        _continue_pan_drag(event.position)
        accept_event()
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_pan_drag(event.position)
        else:
            _finish_pan_drag(event.position)
        accept_event()
        return
    if event is InputEventMouseMotion and drag_active:
        _continue_pan_drag(event.position)
        accept_event()

func _begin_pan_drag(position: Vector2) -> void:
    drag_active = true
    drag_start = position
    drag_pan_start = menu_pan
    drag_moved = false

func _continue_pan_drag(position: Vector2) -> void:
    if not drag_active:
        return
    var delta := position - drag_start
    if not drag_moved and delta.length() >= PAN_DRAG_THRESHOLD:
        drag_moved = true
    if drag_moved:
        _set_menu_pan(drag_pan_start + delta)

func _finish_pan_drag(position: Vector2) -> void:
    if not drag_active:
        return
    if not drag_moved:
        _handle_camp_press(position)
    drag_active = false
    drag_moved = false

func _handle_camp_press(local_pos: Vector2) -> void:
    var geometry := _camp_geometry()
    var tile: float = float(geometry["tile"])
    var origin: Vector2 = geometry["origin"]
    if tile <= 0.0:
        return

    var closest_survivor := -1
    var closest_distance := tile * 0.72
    for survivor_value in Game.survivors:
        var survivor: Dictionary = survivor_value
        if not _survivor_in_camp(survivor):
            continue
        var sid := int(survivor.get("id", -1))
        if not actor_positions.has(sid):
            continue
        var center := _grid_center(actor_positions[sid], origin, tile)
        var distance := center.distance_to(local_pos)
        if distance <= closest_distance:
            closest_distance = distance
            closest_survivor = sid
    if closest_survivor >= 0:
        survivor_pressed.emit(closest_survivor)
        return

    var relative := local_pos - origin
    var cell := Vector2i(floori(relative.x / tile), floori(relative.y / tile))
    if cell.x < 0 or cell.y < 0 or cell.x >= GRID_W or cell.y >= GRID_H:
        return

    if cell == CAMP_CHEST_CELL or (cell == building_cell("Storage Crate") and bool(Game.buildings.get("Storage Crate", false))):
        communal_inventory_pressed.emit()
        return
    if cell == FIRE_CELL:
        craft_station_pressed.emit("Fire Pit")
        return
    if cell == WORK_BOARD_CELL:
        duties_pressed.emit()
        return
    if cell == building_cell("Workbench") and bool(Game.buildings.get("Workbench", false)):
        craft_station_pressed.emit("Workbench")
        return
    if cell == building_cell("Sewing Table") and bool(Game.buildings.get("Sewing Table", false)):
        craft_station_pressed.emit("Sewing Table")
        return
    if cell.y == GRID_H - 1 and cell.x in [7, 8]:
        gate_pressed.emit()
        return
    for building_value in BUILDING_CELLS.keys():
        var building_name := str(building_value)
        var building_pos: Vector2i = BUILDING_CELLS[building_value]
        if cell != building_pos:
            continue
        if bool(Game.buildings.get(building_name, false)):
            building_pressed.emit(building_name)
        else:
            build_plot_pressed.emit(building_name)
        return

func _sleep_slots() -> Array:
    var slots: Array = [SLEEP_CELL]
    if bool(Game.buildings.get("Makeshift Shelter", false)):
        slots.append_array([Vector2i(3, 6), Vector2i(4, 6)])
    if bool(Game.buildings.get("Cabin", false)):
        slots.append_array([Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5), Vector2i(12, 6)])
    if bool(Game.buildings.get("Bunkhouse", false)):
        slots.append_array([Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8)])
    if bool(Game.buildings.get("Dormitory", false)):
        slots.append_array([Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7), Vector2i(9, 8), Vector2i(11, 8)])
    return slots

func _sleep_cell_for_survivor(survivor: Dictionary) -> Vector2i:
    var slots := _sleep_slots()
    var living_ids: Array = []
    for value in Game.survivors:
        if str(value.get("condition", "Dead")) != "Dead":
            living_ids.append(int(value.get("id", -1)))
    living_ids.sort()
    var index := living_ids.find(int(survivor.get("id", -1)))
    if index >= 0 and index < slots.size():
        return slots[index]
    return Vector2i(16, 8)

func _target_cell(survivor: Dictionary) -> Vector2i:
    var status := str(survivor.get("status", "Available"))
    var task: Dictionary = survivor.get("task", {})
    if status == "Crafting":
        var station := str(task.get("station", "Fire Pit"))
        var offset: Vector2i = STATION_OFFSETS.get(station, Vector2i(0, 1))
        return station_cell(station) + offset
    if status == "Building":
        return building_cell(str(task.get("building", ""))) + Vector2i(-1, 0)
    if status == "Tending":
        return building_cell("Garden Plot") + Vector2i(1, 0)
    if status == "Sleeping":
        return _sleep_cell_for_survivor(survivor)
    if status == "Recovering":
        return building_cell("Infirmary") + Vector2i(-1, 0) if bool(Game.buildings.get("Infirmary", false)) else _sleep_cell_for_survivor(survivor)
    if status in ["Quarantined", "Sick"]:
        return building_cell("Infirmary") + Vector2i(1, 0) if bool(Game.buildings.get("Infirmary", false)) else Vector2i(16, 7)
    if status == "Chore":
        match str(task.get("chore", "")):
            "stoke_fire": return FIRE_CELL + Vector2i(0, 1)
            "repair_perimeter": return Vector2i(16, 5)
            "clean_camp": return Vector2i(9, 9)
    if status == "Pet Care":
        return FIRE_CELL + Vector2i(1, 1)

    var activity: Dictionary = survivor.get("camp_activity", {})
    match str(activity.get("kind", "")):
        "maintain_fire", "watch_fire": return FIRE_CELL + Vector2i(0, 1)
        "wash": return building_cell("Water Tank") + Vector2i(1, 0) if bool(Game.buildings.get("Water Tank", false)) else building_cell("Rain Catcher") + Vector2i(1, 0)
    if float(survivor.get("stress", 0.0)) >= 68.0:
        return FIRE_CELL + Vector2i(0, 1)
    var sid := int(survivor.get("id", 0))
    var phase := int(floor(float(Game.day_elapsed) / 8.0))
    return IDLE_CELLS[posmod(sid + phase, IDLE_CELLS.size())]

func _draw_survivors(origin: Vector2, tile: float) -> void:
    var font: Font = get_theme_default_font()
    for survivor_value in Game.survivors:
        var survivor: Dictionary = survivor_value
        if not _survivor_in_camp(survivor):
            continue
        var sid := int(survivor.get("id", -1))
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
        var scale := clampf(tile / 32.0, 0.70, 1.18)
        var sleeping := status == "Sleeping"
        draw_set_transform(center, PI * 0.5 if sleeping else 0.0, Vector2(scale, scale))
        Visuals.draw_survivor(self, Vector2.ZERO, actor, false)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        var first_name := str(survivor.get("name", "Survivor")).get_slice(" ", 0)
        var font_size := maxi(8, int(tile * 0.34))
        draw_string(font, center + Vector2(-tile * 0.52, -tile * 0.50), first_name, HORIZONTAL_ALIGNMENT_CENTER, tile * 1.04, font_size, Color(0.97, 0.97, 0.91, 0.98))
        _draw_need_pips(survivor, center, tile)
        if menu_mode:
            _draw_glance_indicator(survivor, center, tile)
        var activity := _activity_short(survivor)
        if activity != "":
            draw_string(font, center + Vector2(-tile * 0.52, tile * 0.70), activity, HORIZONTAL_ALIGNMENT_CENTER, tile * 1.04, maxi(7, font_size - 2), Color(0.91, 0.80, 0.48, 0.96))

func _draw_glance_indicator(survivor: Dictionary, center: Vector2, tile: float) -> void:
    var needs: Dictionary = survivor.get("needs", {})
    var need_labels := {
        "hunger": "FOOD",
        "thirst": "WATER",
        "sleep": "SLEEP",
        "fun": "FUN",
        "safety": "SAFE",
        "hygiene": "WASH",
    }
    var lowest_key := ""
    var lowest_value := 101.0
    for key_value in need_labels.keys():
        var key := str(key_value)
        var value := float(needs.get(key, 100.0))
        if value < lowest_value:
            lowest_value = value
            lowest_key = key

    var stress := float(survivor.get("stress", 0.0))
    var mood := "GOOD"
    var border := Color(0.42, 0.72, 0.47, 0.86)
    if stress >= 70.0 or lowest_value < 25.0:
        mood = "BAD"
        border = Color(0.86, 0.34, 0.28, 0.92)
    elif stress >= 45.0 or lowest_value < 45.0:
        mood = "LOW"
        border = Color(0.86, 0.66, 0.28, 0.90)

    var bits: Array = [mood]
    if lowest_key != "" and lowest_value < 55.0:
        bits.append(str(need_labels[lowest_key]))
    var virus_stage := Game.virus_stage(survivor)
    if virus_stage != "Clear":
        bits.append("VIRUS")
        border = Color(0.88, 0.47, 0.25, 0.94)
    var text := " • ".join(bits)
    var font := get_theme_default_font()
    var font_size := maxi(7, int(tile * 0.27))
    var width := minf(tile * 3.4, maxf(tile * 1.45, float(text.length()) * float(font_size) * 0.54 + 8.0))
    var height := float(font_size) + 7.0
    var box_center := center + Vector2(0, -tile * 0.95)
    var box := Rect2(box_center - Vector2(width * 0.5, height * 0.5), Vector2(width, height))
    draw_rect(box, Color(0.015, 0.025, 0.022, 0.88))
    draw_rect(box, border, false, 1.0)
    draw_string(font, box.position + Vector2(3.0, height - 4.0), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 6.0, font_size, Color(0.96, 0.96, 0.90, 0.98))

func _draw_activity_graphic(survivor: Dictionary, center: Vector2, tile: float) -> void:
    var status := str(survivor.get("status", "Available"))
    if status == "Sleeping":
        var bed := Rect2(center + Vector2(-tile * 0.42, -tile * 0.20), Vector2(tile * 0.84, tile * 0.40))
        draw_rect(bed, Color(0.19, 0.24, 0.24, 0.92))
        draw_rect(Rect2(bed.position, Vector2(tile * 0.20, bed.size.y)), Color(0.70, 0.68, 0.55, 0.88))
        draw_rect(bed, Color(0.55, 0.62, 0.58, 0.74), false, maxf(1.0, tile * 0.035))
        var font := get_theme_default_font()
        draw_string(font, center + Vector2(tile * 0.18, -tile * 0.28), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(8, int(tile * 0.34)), Color(0.72, 0.82, 0.92, 0.92))
        return
    if str(survivor.get("task", {}).get("kind", "")) == "virus_treatment":
        draw_line(center + Vector2(-tile * 0.18, 0), center + Vector2(tile * 0.18, 0), Color(0.72, 0.94, 0.88, 0.90), maxf(2.0, tile * 0.07))
        draw_line(center + Vector2(0, -tile * 0.18), center + Vector2(0, tile * 0.18), Color(0.72, 0.94, 0.88, 0.90), maxf(2.0, tile * 0.07))
        return
    if status in ["Quarantined", "Sick"]:
        draw_arc(center, tile * 0.34, 0.0, TAU, 20, Color(0.90, 0.58, 0.30, 0.88), maxf(1.0, tile * 0.05))
        return
    super._draw_activity_graphic(survivor, center, tile)

func _activity_short(survivor: Dictionary) -> String:
    var status := str(survivor.get("status", "Available"))
    match status:
        "Sleeping": return "SLEEP"
        "Quarantined": return "QUARANTINE"
        "Sick": return "FEVER"
        "Recovering":
            if str(survivor.get("task", {}).get("kind", "")) == "virus_treatment":
                return "VIRUS CARE"
    var base := super._activity_short(survivor)
    if base != "":
        return base
    var stage := Game.virus_stage(survivor)
    return stage.to_upper() if stage != "Clear" else ""