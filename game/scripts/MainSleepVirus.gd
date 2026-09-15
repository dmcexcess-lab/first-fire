extends "res://scripts/MainThreeStat.gd"

const CombatVirus = preload("res://scripts/FFCombatVirus.gd")
const InspectorVirus = preload("res://scripts/FFInspectorVirus.gd")
const CampViewSleepVirus = preload("res://scripts/FFCampViewSleepVirus.gd")
const CampData = preload("res://scripts/FFData.gd")

const CAMP_TUTORIAL_STEPS := [
    {
        "title": "YOUR CAMP IS THE MENU",
        "body": "Watch First Fire directly. Drag the camp to look around. Tap survivors for stats and gear, the stash for communal inventory, structures for their work, empty plots to build, and the gate to leave camp."
    },
    {
        "title": "CRAFT AT THE FIRE",
        "body": "The First Fire is your starter crafting station from Day 1. Tap it to cook food, boil water, and make sterile dressings. Later, built Workbench and Sewing Table stations add their own recipes."
    },
    {
        "title": "ASSIGN FROM THE CAMP",
        "body": "The work board stays quiet until something actually needs attention. Tap it when an alert appears. Sleeping, eating, drinking, fun, recovery, and social downtime happen on their own."
    },
    {
        "title": "LEAVE THROUGH THE GATE",
        "body": "Tap the gate to choose a survivor and destination in one place, then LEAVE CAMP. Outside, tactical movement, darkness, sound, wounds, infection, loot, rescue and extraction determine what comes home."
    },
]

var camp_context_kind := ""
var camp_context_target := ""
var gate_survivor_ids: Array = []
var gate_survivor_index := 0
var gate_zone_names: Array = []
var gate_zone_index := 0
var expedition_return_notice: Button

func _build_ui():
    super._build_ui()
    camp_view = _replace_camp_view(camp_view, false)
    menu_camp_view = _replace_camp_view(menu_camp_view, true)
    _hide_legacy_navigation()
    _hide_development_placeholder()
    _apply_camp_menu_layout()
    _build_expedition_return_notice()
    if not Game.toast_requested.is_connected(_on_return_toast):
        Game.toast_requested.connect(_on_return_toast)

func _replace_camp_view(old_view: Control, menu_view: bool) -> Control:
    if old_view == null or old_view.get_parent() == null:
        return old_view
    var parent := old_view.get_parent()
    var index := old_view.get_index()
    var replacement := CampViewSleepVirus.new()
    replacement.custom_minimum_size = old_view.custom_minimum_size
    replacement.size_flags_horizontal = old_view.size_flags_horizontal
    replacement.size_flags_vertical = old_view.size_flags_vertical
    parent.remove_child(old_view)
    old_view.queue_free()
    parent.add_child(replacement)
    parent.move_child(replacement, index)
    if menu_view:
        replacement.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        replacement.set_menu_mode(false)
    else:
        replacement.survivor_pressed.connect(_on_camp_survivor_pressed)
        replacement.craft_station_pressed.connect(_on_camp_craft_station_pressed)
        replacement.build_plot_pressed.connect(_on_camp_build_plot_pressed)
        replacement.building_pressed.connect(_on_camp_building_pressed)
        replacement.communal_inventory_pressed.connect(_on_camp_inventory_pressed)
        replacement.duties_pressed.connect(_on_camp_duties_pressed)
        replacement.gate_pressed.connect(_on_camp_gate_pressed)
    return replacement

func _hide_legacy_navigation() -> void:
    if not nav_buttons.has("Camp"):
        return
    var camp_button: Button = nav_buttons["Camp"]
    var nav := camp_button.get_parent()
    if nav is Control:
        nav.visible = false
        nav.custom_minimum_size = Vector2.ZERO
    for button_value in nav_buttons.values():
        var button: Button = button_value
        button.visible = false
        button.custom_minimum_size = Vector2.ZERO

func _hide_development_placeholder() -> void:
    for node in find_children("*", "Label", true, false):
        if node is Label and str(node.text).begins_with("AD SPACE"):
            var panel := node.get_parent()
            if panel is Control:
                panel.visible = false
                panel.custom_minimum_size = Vector2.ZERO
            return

func _build_expedition_return_notice() -> void:
    expedition_return_notice = Button.new()
    expedition_return_notice.visible = false
    expedition_return_notice.z_index = 50
    expedition_return_notice.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    expedition_return_notice.offset_left = 14.0
    expedition_return_notice.offset_right = -14.0
    expedition_return_notice.offset_top = -90.0
    expedition_return_notice.offset_bottom = -14.0
    expedition_return_notice.custom_minimum_size = Vector2(0, 68)
    expedition_return_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    expedition_return_notice.add_theme_font_size_override("font_size", 13)
    expedition_return_notice.pressed.connect(_dismiss_return_notice)
    add_child(expedition_return_notice)

func _on_return_toast(message) -> void:
    if expedition_return_notice == null:
        return
    var source := str(message)
    var lower := source.to_lower()
    var marker := " returned: "
    var marker_index := lower.find(marker)
    var display := ""
    if marker_index >= 0:
        var who := source.substr(0, marker_index)
        var haul := source.substr(marker_index + marker.length())
        display = "%s RETURNED\n%s" % [who.to_upper(), haul]
    elif lower.ends_with(" returned empty-handed."):
        var suffix := " returned empty-handed."
        var who := source.substr(0, source.length() - suffix.length())
        display = "%s RETURNED\nEmpty-handed" % who.to_upper()
    else:
        return
    expedition_return_notice.text = display + "  •  TAP TO DISMISS"
    expedition_return_notice.visible = true

func _dismiss_return_notice() -> void:
    if expedition_return_notice != null:
        expedition_return_notice.visible = false

func _build_inspector_overlay():
    inspector_overlay = InspectorVirus.new()
    inspector_overlay.send_survivor.connect(_on_inspector_send)
    add_child(inspector_overlay)

func _build_combat_overlay():
    combat_overlay = CombatVirus.new()
    combat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    combat_overlay.visible = false
    combat_overlay.encounter_finished.connect(_on_combat_finished)
    add_child(combat_overlay)

func _on_tab_pressed(_tab):
    _close_camp_context()

func _refresh_content():
    if content_box == null:
        return
    _clear_content()
    match camp_context_kind:
        "craft": _draw_station_context(camp_context_target)
        "build", "building": _draw_building_context(camp_context_target)
        "duties": _draw_duties_context()
        "gate": _draw_gate_context()
    _apply_camp_menu_layout()

func _apply_camp_menu_layout() -> void:
    if camp_view == null or content_scroll == null:
        return
    current_tab = "Camp"
    var home := camp_context_kind == ""
    content_scroll.visible = not home
    var frame := camp_view.get_parent()
    if frame != null:
        frame.size_flags_vertical = Control.SIZE_EXPAND_FILL if home else Control.SIZE_SHRINK_BEGIN
        frame.custom_minimum_size = Vector2(0, 520 if home else 260)
    camp_view.custom_minimum_size = Vector2(0, 520 if home else 260)
    camp_view.set_menu_mode(true)
    camp_view.queue_redraw()

func _open_camp_context(kind: String, target: String = "") -> void:
    camp_context_kind = kind
    camp_context_target = target
    current_tab = "Camp"
    _refresh_content()
    content_scroll.scroll_vertical = 0

func _close_camp_context() -> void:
    camp_context_kind = ""
    camp_context_target = ""
    current_tab = "Camp"
    _refresh_content()

func _draw_context_header(title: String, body: String = "") -> void:
    var close := Button.new()
    close.text = "← CAMP"
    close.custom_minimum_size = Vector2(0, 44)
    close.pressed.connect(_close_camp_context)
    content_box.add_child(close)
    content_box.add_child(_heading(title, 23))
    if body != "":
        content_box.add_child(_make_label(body, 12))

func _on_camp_survivor_pressed(survivor_id: int) -> void:
    _open_survivor_inspector(survivor_id)

func _on_camp_craft_station_pressed(station_name: String) -> void:
    _open_camp_context("craft", station_name)
    _show_toast("%s — crafting" % station_name)

func _on_camp_build_plot_pressed(building_name: String) -> void:
    _open_camp_context("build", building_name)
    _show_toast("Build plot — %s" % building_name)

func _on_camp_building_pressed(building_name: String) -> void:
    _open_camp_context("building", building_name)

func _on_camp_inventory_pressed() -> void:
    _open_camp_inventory_inspector()

func _on_camp_duties_pressed() -> void:
    _open_camp_context("duties")

func _on_camp_gate_pressed() -> void:
    _prepare_gate_context(selected_survivor_id)
    _open_camp_context("gate")

func _draw_station_context(station_name: String) -> void:
    _draw_context_header(station_name, "Choose a free survivor, then make only what this station can produce.")
    if station_name != "Fire Pit" and not bool(Game.buildings.get(station_name, false)):
        content_box.add_child(_make_label("This station has not been built yet.", 13))
        return
    content_box.add_child(_worker_picker())
    var recipes: Array = CampData.RECIPES.get(station_name, [])
    for recipe_value in recipes:
        var recipe: Dictionary = recipe_value
        content_box.add_child(_separator())
        var panel := PanelContainer.new()
        var v := VBoxContainer.new()
        panel.add_child(v)
        v.add_child(_make_label(str(recipe.get("id", "Recipe")), 16))
        var desc: String = str(_format_cost(recipe.get("cost", {}), recipe.get("component_cost", {}))) + "  •  %.0fs base" % float(recipe.get("time", 0.0))
        var outputs: Array = []
        for out_key in recipe.get("gives_resource", {}).keys():
            outputs.append("%d %s" % [int(recipe["gives_resource"][out_key]), out_key])
        for out_key in recipe.get("gives_component", {}).keys():
            outputs.append("%d %s" % [int(recipe["gives_component"][out_key]), out_key])
        if str(recipe.get("gives_gear", "")) != "":
            outputs.append(str(recipe.get("gives_gear", "")))
        if not outputs.is_empty():
            desc += "  →  " + ", ".join(outputs)
        v.add_child(_make_label(desc, 12))
        var missing_text := _craft_missing_text(recipe)
        if missing_text != "":
            var missing_label: Label = _make_label("Missing: " + missing_text, 12)
            missing_label.modulate = Color(0.95, 0.67, 0.43, 1.0)
            v.add_child(missing_label)
        var req_ok := true
        if recipe.has("requires"):
            v.add_child(_make_label("Requires: " + ", ".join(recipe["requires"]), 12))
            for req in recipe["requires"]:
                if not bool(Game.buildings.get(req, false)):
                    req_ok = false
        var craft := Button.new()
        craft.text = "CRAFT"
        craft.custom_minimum_size = Vector2(0, 42)
        craft.disabled = selected_worker_id < 0 or not req_ok or not _can_pay_ui(recipe.get("cost", {}), recipe.get("component_cost", {}))
        craft.pressed.connect(_on_craft_pressed.bind(station_name, str(recipe.get("id", ""))))
        v.add_child(craft)
        content_box.add_child(panel)

func _craft_missing_text(recipe: Dictionary) -> String:
    var missing: Array = []
    var resource_cost: Dictionary = recipe.get("cost", {})
    for key_value in resource_cost.keys():
        var key := str(key_value)
        var needed := int(resource_cost[key_value])
        var have := int(Game.resources.get(key, 0))
        if have < needed:
            missing.append("%s %d/%d" % [key, have, needed])
    var component_cost: Dictionary = recipe.get("component_cost", {})
    for key_value in component_cost.keys():
        var key := str(key_value)
        var needed := int(component_cost[key_value])
        var have := int(Game.components.get(key, 0))
        if have < needed:
            missing.append("%s %d/%d" % [key, have, needed])
    return ", ".join(missing)

func _draw_building_context(building_name: String) -> void:
    if not CampData.BUILDINGS.has(building_name):
        _draw_context_header(building_name)
        content_box.add_child(_make_label("No additional interaction is available here yet.", 12))
        return
    var data: Dictionary = CampData.BUILDINGS[building_name]
    var built := bool(Game.buildings.get(building_name, false))
    _draw_context_header(building_name, str(data.get("description", "Camp structure")))
    if built:
        content_box.add_child(_make_label("BUILT", 14))
        if building_name == "Garden Plot":
            content_box.add_child(_worker_picker())
            var tend := Button.new()
            tend.text = "TEND GARDEN" + (" — done today" if Game.garden_tended_day == Game.day else "")
            tend.custom_minimum_size = Vector2(0, 44)
            tend.disabled = selected_worker_id < 0 or Game.garden_tended_day == Game.day
            tend.pressed.connect(func(): Game.tend_garden(selected_worker_id))
            content_box.add_child(tend)
        return
    content_box.add_child(_make_label(_format_cost(data.get("cost", {}), data.get("component_cost", {})) + "  •  %.0fs base" % float(data.get("time", 0.0)), 12))
    var req_ok := true
    if data.has("requires"):
        content_box.add_child(_make_label("Requires: " + ", ".join(data["requires"]), 12))
        for req in data["requires"]:
            if not bool(Game.buildings.get(req, false)):
                req_ok = false
    content_box.add_child(_worker_picker())
    var build := Button.new()
    build.text = "BUILD %s" % building_name.to_upper()
    build.custom_minimum_size = Vector2(0, 46)
    build.disabled = selected_worker_id < 0 or not req_ok or not _can_pay_ui(data.get("cost", {}), data.get("component_cost", {}))
    build.pressed.connect(_on_build_pressed.bind(building_name))
    content_box.add_child(build)

func _draw_duties_context() -> void:
    _draw_context_header("CAMP WORK BOARD", "Assign productive camp work here. Everyday eating, drinking, sleep and fun remain autonomous.")
    _draw_camp_work_board()

func _prepare_gate_context(preferred_id: int = -1) -> void:
    gate_survivor_ids.clear()
    for survivor_value in Game.survivors:
        var survivor: Dictionary = survivor_value
        if Game.survivor_can_assign(survivor):
            gate_survivor_ids.append(int(survivor.get("id", -1)))
    gate_survivor_index = 0
    if preferred_id >= 0 and gate_survivor_ids.has(preferred_id):
        gate_survivor_index = gate_survivor_ids.find(preferred_id)
    gate_zone_names.clear()
    for zone_value in CampData.ZONE_ORDER:
        var zone := str(zone_value)
        if Game.unlocked_zones.has(zone):
            gate_zone_names.append(zone)
    gate_zone_index = 0

func _draw_gate_context() -> void:
    _draw_context_header("CAMP GATE", "Choose who goes and where. This is the whole send-out flow.")
    if gate_survivor_ids.is_empty():
        content_box.add_child(_make_label("No survivor is currently free to leave camp.", 13))
        return
    gate_survivor_index = clampi(gate_survivor_index, 0, gate_survivor_ids.size() - 1)
    var survivor_id := int(gate_survivor_ids[gate_survivor_index])
    var survivor: Variant = Game.get_survivor(survivor_id)
    if survivor == null:
        content_box.add_child(_make_label("That survivor is no longer available.", 13))
        return
    selected_survivor_id = survivor_id
    var survivor_row := HBoxContainer.new()
    if gate_survivor_ids.size() > 1:
        var prev := Button.new()
        prev.text = "PREV"
        prev.custom_minimum_size = Vector2(64, 44)
        prev.pressed.connect(_cycle_gate_survivor.bind(-1))
        survivor_row.add_child(prev)
    var equipment: Dictionary = survivor.get("equipment", {})
    var survivor_text := "%s\n%s • %s • Fatigue %.0f • Stress %.0f" % [str(survivor.get("name", "Survivor")), str(equipment.get("Weapon", "Unarmed")), str(equipment.get("Pack", "No pack")), float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))]
    var survivor_label := _make_label(survivor_text, 12)
    survivor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    survivor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    survivor_row.add_child(survivor_label)
    if gate_survivor_ids.size() > 1:
        var next := Button.new()
        next.text = "NEXT"
        next.custom_minimum_size = Vector2(64, 44)
        next.pressed.connect(_cycle_gate_survivor.bind(1))
        survivor_row.add_child(next)
    content_box.add_child(survivor_row)
    var inspect := Button.new()
    inspect.text = "INSPECT %s" % str(survivor.get("name", "SURVIVOR")).get_slice(" ", 0).to_upper()
    inspect.custom_minimum_size = Vector2(0, 40)
    inspect.pressed.connect(_open_survivor_inspector.bind(survivor_id))
    content_box.add_child(inspect)

    content_box.add_child(_separator())
    if gate_zone_names.is_empty():
        content_box.add_child(_make_label("No expedition zone is currently unlocked.", 13))
        return
    gate_zone_index = clampi(gate_zone_index, 0, gate_zone_names.size() - 1)
    var zone := str(gate_zone_names[gate_zone_index])
    var zone_data: Dictionary = CampData.ZONES.get(zone, {})
    var zone_row := HBoxContainer.new()
    if gate_zone_names.size() > 1:
        var zone_prev := Button.new()
        zone_prev.text = "PREV"
        zone_prev.custom_minimum_size = Vector2(64, 44)
        zone_prev.pressed.connect(_cycle_gate_zone.bind(-1))
        zone_row.add_child(zone_prev)
    var zone_label := _make_label(zone, 15)
    zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    zone_row.add_child(zone_label)
    if gate_zone_names.size() > 1:
        var zone_next := Button.new()
        zone_next.text = "NEXT"
        zone_next.custom_minimum_size = Vector2(64, 44)
        zone_next.pressed.connect(_cycle_gate_zone.bind(1))
        zone_row.add_child(zone_next)
    content_box.add_child(zone_row)
    content_box.add_child(_make_label("%.0fs • %s • %s" % [float(zone_data.get("duration", 0.0)), str(zone_data.get("danger", "?")), Game.zone_loot_state(zone)], 12))
    content_box.add_child(_make_label("Likely finds: %s" % _zone_focus_text(zone), 12))
    var leave := Button.new()
    leave.text = "LEAVE CAMP"
    leave.custom_minimum_size = Vector2(0, 48)
    leave.pressed.connect(_leave_from_gate)
    content_box.add_child(leave)

    var found_site := false
    for site_value in Game.special_sites.keys():
        var site := str(site_value)
        var site_state: Dictionary = Game.special_sites[site]
        if not bool(site_state.get("discovered", false)) or bool(site_state.get("cleared", false)):
            continue
        if not found_site:
            content_box.add_child(_separator())
            content_box.add_child(_make_label("Known special sites", 13))
            found_site = true
        var site_button := Button.new()
        site_button.text = "%s — %.0fs" % [site, float(CampData.SPECIAL_SITES[site].get("duration", 0.0))]
        site_button.custom_minimum_size = Vector2(0, 42)
        site_button.pressed.connect(_leave_special_from_gate.bind(site))
        content_box.add_child(site_button)

func _cycle_gate_survivor(direction: int) -> void:
    if gate_survivor_ids.size() <= 1:
        return
    gate_survivor_index = posmod(gate_survivor_index + direction, gate_survivor_ids.size())
    call_deferred("_refresh_content")

func _cycle_gate_zone(direction: int) -> void:
    if gate_zone_names.size() <= 1:
        return
    gate_zone_index = posmod(gate_zone_index + direction, gate_zone_names.size())
    call_deferred("_refresh_content")

func _zone_focus_text(zone: String) -> String:
    match zone:
        "Camp Perimeter": return "food, water, wood"
        "Nearby Streets": return "food, water, mixed materials"
        "Residential Blocks": return "food, cloth, medicine"
        "Commercial Fringe": return "hardware, scrap, medicine"
        "Industrial Edge": return "scrap, hardware, ammo"
    return "mixed supplies"

func _leave_from_gate() -> void:
    if gate_survivor_ids.is_empty() or gate_zone_names.is_empty():
        return
    var survivor_id := int(gate_survivor_ids[clampi(gate_survivor_index, 0, gate_survivor_ids.size() - 1)])
    var zone := str(gate_zone_names[clampi(gate_zone_index, 0, gate_zone_names.size() - 1)])
    selected_survivor_id = survivor_id
    if Game.start_expedition(survivor_id, zone):
        _dismiss_return_notice()
        _close_camp_context()

func _leave_special_from_gate(site: String) -> void:
    if gate_survivor_ids.is_empty():
        return
    var survivor_id := int(gate_survivor_ids[clampi(gate_survivor_index, 0, gate_survivor_ids.size() - 1)])
    selected_survivor_id = survivor_id
    if Game.start_special_site(survivor_id, site):
        _close_camp_context()

func _send_survivor_from_panel(id):
    selected_survivor_id = int(id)
    _prepare_gate_context(selected_survivor_id)
    _open_camp_context("gate")

func _on_inspector_send(id):
    _send_survivor_from_panel(id)

func _worker_picker():
    var box := VBoxContainer.new()
    var avail: Array = Game.available_survivors()
    if avail.is_empty():
        selected_worker_id = -1
        box.add_child(_make_label("No available survivor", 13))
        return box
    var valid_current := false
    for survivor_value in avail:
        if int(survivor_value.get("id", -1)) == selected_worker_id:
            valid_current = true
            break
    if not valid_current:
        selected_worker_id = int(avail[0].get("id", -1))
    var current: Variant = Game.get_survivor(selected_worker_id)
    if avail.size() == 1:
        box.add_child(_make_label("Worker — %s" % str(current.get("name", "Survivor")), 13))
        return box
    var current_index := 0
    for i in range(avail.size()):
        if int(avail[i].get("id", -1)) == selected_worker_id:
            current_index = i
            break
    var row := HBoxContainer.new()
    var prev := Button.new()
    prev.text = "PREV"
    prev.custom_minimum_size = Vector2(64, 44)
    prev.pressed.connect(_on_worker_cycle.bind(-1))
    row.add_child(prev)
    var label := _make_label("%s  •  %d/%d" % [str(current.get("name", "Survivor")), current_index + 1, avail.size()], 12)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    var next := Button.new()
    next.text = "NEXT"
    next.custom_minimum_size = Vector2(64, 44)
    next.pressed.connect(_on_worker_cycle.bind(1))
    row.add_child(next)
    box.add_child(row)
    return box

func _refresh_tutorial_step():
    if tutorial_overlay == null or CAMP_TUTORIAL_STEPS.is_empty():
        return
    tutorial_index = clampi(tutorial_index, 0, CAMP_TUTORIAL_STEPS.size() - 1)
    var step: Dictionary = CAMP_TUTORIAL_STEPS[tutorial_index]
    tutorial_progress.text = "QUICK START  •  %d / %d" % [tutorial_index + 1, CAMP_TUTORIAL_STEPS.size()]
    tutorial_title.text = str(step.get("title", "FIRST FIRE"))
    tutorial_body.text = str(step.get("body", ""))
    tutorial_next_button.text = "GOT IT" if tutorial_index == CAMP_TUTORIAL_STEPS.size() - 1 else "NEXT"

func _activity_text(s):
    var status := str(s.get("status", "Available"))
    if status in ["Expedition", "Pending Expedition Event"]:
        return super._activity_text(s)
    if status in ["Crafting", "Building", "Recovering", "Tending", "Sleeping"] and not s.get("task", {}).is_empty():
        var task: Dictionary = s["task"]
        var label := "Virus treatment" if str(task.get("kind", "")) == "virus_treatment" else status
        return "%s — %.0fs remaining" % [label, float(task.get("remaining", 0.0))]
    if status == "Quarantined":
        return "Quarantined — virus %s" % Game.virus_stage(s)
    if status == "Sick":
        return "Feverish — needs zombie-virus care"
    var stage := Game.virus_stage(s)
    if stage != "Clear":
        return "%s — virus %s" % [status, stage]
    return status

func _refresh_status():
    if status_label == null:
        return
    status_label.text = "D%d  %s  •  FOOD %d  WATER %d" % [
        Game.day,
        Game.formatted_time(),
        int(Game.resources.get("Cooked Food", 0)),
        int(Game.resources.get("Clean Water", 0)),
    ]
    pause_button.text = "PAUSE"
    var active: Array = []
    for exp in Game.expeditions:
        var names := Game._party_names(exp["survivor_ids"])
        var zone := str(exp.get("zone", ""))
        if exp.get("state", "") == "traveling":
            active.append("AWAY • %s • %s • %.0fs" % [names, zone, float(exp["remaining"])])
        elif exp.get("state", "") == "pending":
            active.append("AWAY • %s • %s • DECISION" % [names, zone])
        elif exp.get("state", "") == "combat":
            active.append("TACTICAL • %s • %s" % [names, zone])
    for s in Game.survivors:
        var status := str(s.get("status", ""))
        if status in ["Crafting", "Building", "Recovering", "Tending", "Sleeping"] and not s.get("task", {}).is_empty():
            var task: Dictionary = s["task"]
            var label := "virus care" if str(task.get("kind", "")) == "virus_treatment" else status.to_lower()
            active.append("%s %s: %.0fs" % [s["name"], label, float(task.get("remaining", 0.0))])
        elif status in ["Chore", "Pet Care"] and not s.get("task", {}).is_empty():
            active.append("%s %s %d/%d" % [s["name"], s["task"].get("label", "work"), int(s["task"].get("progress", 0)), int(s["task"].get("goal", 1))])
        elif status in ["Quarantined", "Sick"]:
            active.append("%s: %s" % [s["name"], _activity_text(s)])
    var timer_text := "PAUSED" if Game.sim_paused else ""
    if not active.is_empty():
        timer_text += ("  •  " if timer_text != "" else "") + "  |  ".join(active)
    timer_label.text = timer_text
    timer_label.visible = timer_text != ""

func _draw_camp_work_board() -> void:
    content_box.add_child(_separator())
    content_box.add_child(_heading("Camp Work", 19))
    for survivor_value in Game.survivors:
        var survivor: Dictionary = survivor_value
        if str(survivor.get("status", "")) in ["Chore", "Pet Care"] and not survivor.get("task", {}).is_empty():
            var task: Dictionary = survivor["task"]
            var row := HBoxContainer.new()
            row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.add_child(_make_label("%s — %s  %d/%d" % [survivor["name"], task.get("label", "Work"), int(task.get("progress", 0)), int(task.get("goal", 1))], 12))
            var work := Button.new()
            work.text = "WORK"
            work.custom_minimum_size = Vector2(92, 44)
            work.pressed.connect(Game.perform_camp_task_tap.bind(int(survivor["id"])))
            row.add_child(work)
            content_box.add_child(row)

    var needed: Array = []
    if Game.camp_chore_needed("stoke_fire"):
        needed.append(["STOKE FIRE", "stoke_fire", int(Game.resources.get("Wood", 0)) > 0, "needs 1 Wood"])
    if Game.camp_chore_needed("clean_camp"):
        needed.append(["CLEAN CAMP", "clean_camp", true, ""])
    if Game.camp_chore_needed("repair_perimeter"):
        var repair_material := int(Game.resources.get("Scrap Metal", 0)) > 0 or int(Game.resources.get("Wood", 0)) > 0
        needed.append(["REPAIR PERIMETER", "repair_perimeter", repair_material, "needs Scrap Metal or Wood"])

    if needed.is_empty():
        content_box.add_child(_make_label("Nothing urgent right now. Watch the camp; the board will call for work when something actually needs attention.", 12))
    else:
        content_box.add_child(_worker_picker())
        for entry_value in needed:
            var entry: Array = entry_value
            var button := Button.new()
            button.text = str(entry[0]) + ("" if bool(entry[2]) else " — " + str(entry[3]))
            button.custom_minimum_size = Vector2(0, 44)
            button.disabled = selected_worker_id < 0 or not bool(entry[2])
            button.pressed.connect(Game.start_camp_chore.bind(selected_worker_id, str(entry[1])))
            content_box.add_child(button)
    content_box.add_child(_make_label("Fire %.0f%%  •  Maintenance %.0f%%" % [Game.fire_level, Game.camp_maintenance], 12))

    content_box.add_child(_separator())
    content_box.add_child(_heading("Pets", 19))
    if Game.pets.is_empty():
        content_box.add_child(_make_label("No camp pets yet. Some tactical rescue calls may be a stranded dog or cat.", 12))
        return
    content_box.add_child(_worker_picker())
    for pet_value in Game.pets:
        var pet: Dictionary = pet_value
        var panel := PanelContainer.new()
        var v := VBoxContainer.new()
        panel.add_child(v)
        v.add_child(_make_label("%s — %s — %s" % [pet.get("name", "Pet"), pet.get("species", "Animal"), Game.pet_mood_label(pet)], 16))
        var needs: Dictionary = Game.CampLifeRules.normalize_pet_needs(pet.get("needs", {}))
        v.add_child(_make_label("Bond %.0f  •  Play with and love them or they may leave camp." % needs["affection"], 12))
        v.add_child(_make_label("Each retained pet finds 1 material or Raw Food per day.", 11))
        var buttons := GridContainer.new()
        buttons.columns = 2
        for action in ["play", "love"]:
            var button := Button.new()
            button.text = action.to_upper()
            button.custom_minimum_size = Vector2(0, 42)
            button.disabled = selected_worker_id < 0
            button.pressed.connect(Game.start_pet_care.bind(selected_worker_id, int(pet["id"]), action))
            buttons.add_child(button)
        v.add_child(buttons)
        content_box.add_child(panel)
