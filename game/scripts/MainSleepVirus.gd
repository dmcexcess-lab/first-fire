extends "res://scripts/MainThreeStat.gd"

const CombatVirus = preload("res://scripts/FFCombatVirus.gd")
const InspectorVirus = preload("res://scripts/FFInspectorVirus.gd")
const CampViewSleepVirus = preload("res://scripts/FFCampViewSleepVirus.gd")

var camp_details_open := false

func _build_ui():
    super._build_ui()
    camp_view = _replace_camp_view(camp_view, false)
    menu_camp_view = _replace_camp_view(menu_camp_view, true)
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
        replacement.communal_inventory_pressed.connect(_on_camp_inventory_pressed)
        replacement.duties_pressed.connect(_on_camp_duties_pressed)
        replacement.gate_pressed.connect(_on_camp_gate_pressed)
    return replacement

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

func _on_tab_pressed(tab):
    camp_details_open = false
    super._on_tab_pressed(tab)

func _refresh_content():
    super._refresh_content()
    _apply_camp_menu_layout()

func _apply_camp_menu_layout() -> void:
    if camp_view == null or content_scroll == null:
        return
    var focus := current_tab == "Camp" and not camp_details_open
    content_scroll.visible = not focus
    var frame := camp_view.get_parent()
    if frame != null:
        frame.size_flags_vertical = Control.SIZE_EXPAND_FILL if focus else Control.SIZE_SHRINK_BEGIN
        frame.custom_minimum_size = Vector2(0, 430 if focus else 210)
    camp_view.custom_minimum_size = Vector2(0, 430 if focus else 210)
    camp_view.set_menu_mode(focus)
    camp_view.queue_redraw()

func _on_camp_survivor_pressed(survivor_id: int) -> void:
    _open_survivor_inspector(survivor_id)

func _on_camp_craft_station_pressed(station_name: String) -> void:
    camp_details_open = false
    current_tab = "Craft"
    _show_toast("%s — crafting" % station_name)
    _refresh_nav_buttons()
    _refresh_content()
    content_scroll.scroll_vertical = 0

func _on_camp_build_plot_pressed(building_name: String) -> void:
    camp_details_open = false
    current_tab = "Build"
    _show_toast("Build plot — %s" % building_name)
    _refresh_nav_buttons()
    _refresh_content()
    content_scroll.scroll_vertical = 0

func _on_camp_inventory_pressed() -> void:
    _open_camp_inventory_inspector()

func _on_camp_duties_pressed() -> void:
    camp_details_open = true
    current_tab = "Camp"
    _refresh_nav_buttons()
    _refresh_content()
    content_scroll.scroll_vertical = 0

func _on_camp_gate_pressed() -> void:
    camp_details_open = false
    current_tab = "Survivors"
    _show_toast("Choose a survivor, then SEND OUT.")
    _refresh_nav_buttons()
    _refresh_content()
    content_scroll.scroll_vertical = 0

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
