extends "res://scripts/FFCampView.gd"

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
        var activity := _activity_short(survivor)
        if activity != "":
            draw_string(font, center + Vector2(-tile * 0.52, tile * 0.70), activity, HORIZONTAL_ALIGNMENT_CENTER, tile * 1.04, maxi(7, font_size - 2), Color(0.91, 0.80, 0.48, 0.96))

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
