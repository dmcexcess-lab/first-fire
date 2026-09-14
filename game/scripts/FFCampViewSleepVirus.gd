extends "res://scripts/FFCampView.gd"

signal survivor_pressed(survivor_id: int)
signal craft_station_pressed(station_name: String)
signal build_plot_pressed(building_name: String)
signal communal_inventory_pressed
signal duties_pressed
signal gate_pressed

const CAMP_CHEST_CELL := Vector2i(8, 6)
const MENU_VISIBLE_GRID_WIDTH := 15.5

var menu_mode := false

func _ready() -> void:
    super._ready()
    set_menu_mode(menu_mode)

func set_menu_mode(active: bool) -> void:
    menu_mode = active
    mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _camp_geometry() -> Dictionary:
    var visible_width := MENU_VISIBLE_GRID_WIDTH if menu_mode else float(GRID_W)
    var tile: float = minf(size.x / visible_width, size.y / float(GRID_H))
    var map_size := Vector2(tile * float(GRID_W), tile * float(GRID_H))
    var origin := (size - map_size) * 0.5
    return {"tile": tile, "origin": origin, "map_size": map_size}

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
    _draw_night(origin, tile)
    _draw_ambient_life(origin, tile)
    _draw_survivors(origin, tile)
    _draw_chatter(origin, tile)
    if menu_mode:
        _draw_menu_affordances(origin, tile)
    draw_rect(Rect2(origin, map_size), Color(0.38, 0.49, 0.40, 0.55), false, 1.0)
    var font: Font = get_theme_default_font()
    var title_size: int = maxi(9, int(tile * 0.38))
    draw_string(font, origin + Vector2(7.0, float(title_size) + 4.0), "FIRST FIRE CAMP  •  %s  •  %s" % [Game.formatted_time(), _day_phase()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.94, 0.94, 0.86, 0.95))

func _draw_build_plots(origin: Vector2, tile: float) -> void:
    if not menu_mode:
        return
    var font: Font = get_theme_default_font()
    for building_value in BUILDING_CELLS.keys():
        var building_name := str(building_value)
        if bool(Game.buildings.get(building_name, false)):
            continue
        var cell: Vector2i = BUILDING_CELLS[building_value]
        var rect := _cell_rect(cell, origin, tile).grow(-tile * 0.10)
        draw_rect(rect, Color(0.78, 0.70, 0.45, 0.09))
        draw_rect(rect, Color(0.82, 0.74, 0.48, 0.55), false, maxf(1.0, tile * 0.035))
        draw_line(rect.position + Vector2(rect.size.x * 0.28, rect.size.y * 0.50), rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.50), Color(0.93, 0.84, 0.58, 0.78), maxf(1.0, tile * 0.05))
        draw_line(rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.28), rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.72), Color(0.93, 0.84, 0.58, 0.78), maxf(1.0, tile * 0.05))
        if tile >= 22.0:
            draw_string(font, rect.position + Vector2(-tile * 0.12, rect.size.y + maxi(7, int(tile * 0.25))), "BUILD", HORIZONTAL_ALIGNMENT_CENTER, tile * 1.20, maxi(7, int(tile * 0.25)), Color(0.88, 0.80, 0.56, 0.82))

func _draw_communal_chest(origin: Vector2, tile: float) -> void:
    var rect := _cell_rect(CAMP_CHEST_CELL, origin, tile).grow(-tile * 0.14)
    Tiles.draw_prop(self, rect, "crate")
    draw_rect(rect, Color(0.87, 0.72, 0.39, 0.72), false, maxf(1.0, tile * 0.035))

func _draw_menu_affordances(origin: Vector2, tile: float) -> void:
    var font: Font = get_theme_default_font()
    var label_size := maxi(7, int(tile * 0.27))
    _draw_action_label(font, _cell_center(CAMP_CHEST_CELL, origin, tile) + Vector2(0, -tile * 0.58), "STASH", tile, label_size)
    _draw_action_label(font, _cell_center(FIRE_CELL, origin, tile) + Vector2(0, tile * 0.72), "DUTIES", tile, label_size)
    if bool(Game.buildings.get("Workbench", false)):
        _draw_action_label(font, _cell_center(building_cell("Workbench"), origin, tile) + Vector2(0, -tile * 0.58), "CRAFT", tile, label_size)
    if bool(Game.buildings.get("Sewing Table", false)):
        _draw_action_label(font, _cell_center(building_cell("Sewing Table"), origin, tile) + Vector2(0, -tile * 0.58), "CRAFT", tile, label_size)
    var gate_center := (_cell_center(Vector2i(7, GRID_H - 1), origin, tile) + _cell_center(Vector2i(8, GRID_H - 1), origin, tile)) * 0.5
    _draw_action_label(font, gate_center + Vector2(0, -tile * 0.45), "SEND OUT", tile * 1.4, label_size)

func _draw_action_label(font: Font, center: Vector2, text: String, width_scale: float, font_size: int) -> void:
    var width := maxf(width_scale, float(text.length()) * float(font_size) * 0.58 + 8.0)
    var height := float(font_size) + 7.0
    var box := Rect2(center - Vector2(width * 0.5, height * 0.5), Vector2(width, height))
    draw_rect(box, Color(0.02, 0.03, 0.025, 0.82))
    draw_rect(box, Color(0.76, 0.66, 0.38, 0.76), false, 1.0)
    draw_string(font, box.position + Vector2(3.0, height - 4.0), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 6.0, font_size, Color(0.96, 0.91, 0.72, 0.96))

func _gui_input(event: InputEvent) -> void:
    if not menu_mode:
        return
    if event is InputEventScreenTouch and event.pressed:
        _handle_camp_press(event.position)
        accept_event()
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _handle_camp_press(event.position)
        accept_event()

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
        if bool(Game.buildings.get(building_name, false)):
            continue
        var building_pos: Vector2i = BUILDING_CELLS[building_value]
        if cell == building_pos:
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
