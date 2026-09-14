extends "res://scripts/MainThreeStat.gd"

const CombatVirus = preload("res://scripts/FFCombatVirus.gd")
const InspectorVirus = preload("res://scripts/FFInspectorVirus.gd")
const CampViewSleepVirus = preload("res://scripts/FFCampViewSleepVirus.gd")
const CampData = preload("res://scripts/FFData.gd")

const CAMP_TUTORIAL_STEPS := [
    {
        "title": "YOUR CAMP IS THE MENU",
        "body": "Watch First Fire directly. Tap survivors for stats and gear, the stash for communal inventory, structures for their work, empty plots to build, and the gate to send someone out."
    },
    {
        "title": "CRAFT AT THE FIRE",
        "body": "The First Fire is your starter crafting station from Day 1. Tap it to cook food, boil water, and make sterile dressings. Later, built Workbench and Sewing Table stations add their own recipes."
    },
    {
        "title": "ASSIGN FROM THE CAMP",
        "body": "Tap the work board for chores and pet care. Tap empty plots to build. Sleeping, eating, drinking, fun, recovery, and social downtime happen through the living camp without menu micromanagement."
    },
    {
        "title": "LEAVE THROUGH THE GATE",
        "body": "Tap the camp gate to choose an available survivor and SEND OUT. Outside camp, tactical movement, darkness, sound, wounds, infection, loot, rescue and extraction determine what comes home."
    },
]

var camp_context_kind := ""
var camp_context_target := ""

func _build_ui():
    super._build_ui()
    camp_view = _replace_camp_view(camp_view, false)
    menu_camp_view = _replace_camp_view(menu_camp_view, true)
    _hide_legacy_navigation()
    _apply_camp_menu_layout()

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
        frame.custom_minimum_size = Vector2(0, 430 if home else 300)
    camp_view.custom_minimum_size = Vector2(0, 430 if home else 300)
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

func _draw_gate_context() -> void:
    _draw_context_header("CAMP GATE", "Choose who leaves First Fire. Busy, sleeping, sick, quarantined or recovering survivors cannot be sent out.")
    for survivor_value in Game.survivors:
        var survivor: Dictionary = survivor_value
        if str(survivor.get("condition", "Dead")) == "Dead":
            continue
        var panel := PanelContainer.new()
        var v := VBoxContainer.new()
        panel.add_child(v)
        v.add_child(_make_label("%s — %s" % [str(survivor.get("name", "Survivor")), _activity_text(survivor)], 15))
        var equipment: Dictionary = survivor.get("equipment", {})
        v.add_child(_make_label("%s  •  %s  •  Fatigue %.0f  Stress %.0f" % [str(equipment.get("Weapon", "Unarmed")), str(equipment.get("Pack", "No pack")), float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 11))
        var row := HBoxContainer.new()
        var inspect := Button.new()
        inspect.text = "INSPECT"
        inspect.custom_minimum_size = Vector2(0, 42)
        inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        inspect.pressed.connect(_open_survivor_inspector.bind(int(survivor.get("id", -1))))
        row.add_child(inspect)
        var send := Button.new()
        send.text = "SEND OUT"
        send.custom_minimum_size = Vector2(0, 42)
        send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        send.disabled = not Game.survivor_can_assign(survivor)
        send.pressed.connect(_send_survivor_from_panel.bind(int(survivor.get("id", -1))))
        row.add_child(send)
        v.add_child(row)
        content_box.add_child(panel)

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
    var pause_text := "PAUSED" if Game.sim_paused else "RUNNING"
    status_label.text = "Day %d  %s  •  Food %d  Water %d  •  Pop %d/%d  Beds %d" % [
        Game.day,
        Game.formatted_time(),
        int(Game.resources.get("Cooked Food", 0)),
        int(Game.resources.get("Clean Water", 0)),
        Game.population(),
        Game.MAX_POPULATION,
        Game.shelter_capacity(),
    ]
    pause_button.text = "PAUSE"
    var active: Array = []
    for exp in Game.expeditions:
        if exp.get("state", "") == "traveling":
            active.append("%s: %.0fs" % [Game._party_names(exp["survivor_ids"]), float(exp["remaining"])])
        elif exp.get("state", "") == "pending":
            active.append("%s: DECISION" % Game._party_names(exp["survivor_ids"]))
        elif exp.get("state", "") == "combat":
            active.append("%s: TACTICAL" % Game._party_names(exp["survivor_ids"]))
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
    timer_label.text = pause_text + ("  •  " + "  |  ".join(active) if not active.is_empty() else "")

func _draw_camp_work_board() -> void:
    content_box.add_child(_separator())
    content_box.add_child(_heading("Camp Duties", 19))
    content_box.add_child(_make_label("Meals and downtime happen on their own. Sleep is real downtime: tired survivors go to a bed and cannot be assigned until they wake. Treatment, chores, pet care, crafting, building and other active work also make survivors unavailable.", 12))
    content_box.add_child(_worker_picker())
    for s in Game.survivors:
        if ["Chore", "Pet Care"].has(str(s.get("status", ""))) and not s.get("task", {}).is_empty():
            var task: Dictionary = s["task"]
            var row := HBoxContainer.new()
            row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.add_child(_make_label("%s — %s  %d/%d" % [s["name"], task.get("label", "Work"), int(task.get("progress", 0)), int(task.get("goal", 1))], 12))
            var work := Button.new()
            work.text = "WORK"
            work.custom_minimum_size = Vector2(92, 44)
            work.pressed.connect(Game.perform_camp_task_tap.bind(int(s["id"])))
            row.add_child(work)
            content_box.add_child(row)
    var chores := GridContainer.new()
    chores.columns = 1
    chores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for entry in [["STOKE FIRE", "stoke_fire"], ["CLEAN CAMP", "clean_camp"], ["REPAIR PERIMETER", "repair_perimeter"]]:
        var button := Button.new()
        button.text = str(entry[0])
        button.custom_minimum_size = Vector2(0, 44)
        button.disabled = selected_worker_id < 0
        button.pressed.connect(Game.start_camp_chore.bind(selected_worker_id, str(entry[1])))
        chores.add_child(button)
    content_box.add_child(chores)
    content_box.add_child(_make_label("Fire %.0f%%  •  Camp maintenance %.0f%%" % [Game.fire_level, Game.camp_maintenance], 13))
    content_box.add_child(_separator())
    content_box.add_child(_heading("Pets", 19))
    if Game.pets.is_empty():
        content_box.add_child(_make_label("No camp pets yet. Some tactical rescue calls may be a stranded dog or cat.", 12))
        return
    for pet in Game.pets:
        var panel := PanelContainer.new()
        var v := VBoxContainer.new()
        panel.add_child(v)
        v.add_child(_make_label("%s — %s — %s" % [pet.get("name", "Pet"), pet.get("species", "Animal"), Game.pet_mood_label(pet)], 16))
        var needs: Dictionary = Game.CampLifeRules.normalize_pet_needs(pet.get("needs", {}))
        v.add_child(_make_label("Bond %.0f  •  Play with and love them or they may leave camp." % needs["affection"], 12))
        v.add_child(_make_label("Pets consume no food or water and each bring back 1 material or Raw Food per day.", 11))
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