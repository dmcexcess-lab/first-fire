extends Control

const D = preload("res://scripts/FFData.gd")
const FFCombat = preload("res://scripts/FFCombat.gd")
const SurvivorPanel = preload("res://scripts/FFSurvivorPanel.gd")
const InspectorOverlay = preload("res://scripts/FFInspector.gd")
const CampView = preload("res://scripts/FFCampView.gd")
const MobileScroll = preload("res://scripts/FFMobileScroll.gd")

const TUTORIAL_STEPS := [
    {
        "title": "KEEP THE FIRE GOING",
        "body": "Camp time runs whenever the game is unpaused. Each survivor needs food and clean water each day. Use CAMP to watch supplies, current work, shelter and the settlement's recent history."
    },
    {
        "title": "SEND ONE SURVIVOR OUT",
        "body": "Open SURVIVORS, inspect someone, then SEND OUT. Choose an unlocked zone. Expeditions take real camp time and can become tactical encounters. Getting to an EXIT is always a valid way to survive."
    },
    {
        "title": "CRAFT AND BUILD",
        "body": "CRAFT turns raw food and dirty water into safe supplies and later makes equipment. BUILD expands shelter and camp capability. Use the left/right worker buttons to choose any currently available survivor."
    },
    {
        "title": "TACTICAL SURVIVAL",
        "body": "Outside camp, movement and actions spend tactical ticks. Facing, darkness, sound, doors, injuries and equipment matter. You usually do not need to kill everything: take what you can, rescue who you can, and escape alive."
    },
]

var current_tab := "Camp"
var selected_worker_id := -1
var selected_survivor_id := -1

var status_label: Label
var timer_label: Label
var content_scroll: ScrollContainer
var content_box: VBoxContainer
var pause_button: Button
var menu_button: Button
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer: Timer

var event_overlay: ColorRect
var event_title: Label
var event_body: Label
var event_choices: VBoxContainer

var combat_overlay: Control
var combat_uid := ""
var inspector_overlay: Control

var expedition_overlay: ColorRect
var expedition_title: Label
var expedition_zone: OptionButton
var expedition_specials: VBoxContainer

var reset_confirm: ConfirmationDialog
var new_game_confirm: ConfirmationDialog
var main_menu_overlay: ColorRect
var load_game_button: Button
var nav_buttons := {}
var camp_view: Control
var menu_camp_view: Control

var tutorial_overlay: ColorRect
var tutorial_title: Label
var tutorial_body: Label
var tutorial_progress: Label
var tutorial_next_button: Button
var tutorial_index := 0
var tutorial_restore_paused := false

func _ready():
    _build_ui()
    Game.state_changed.connect(_refresh_all)
    Game.tick.connect(_refresh_status)
    Game.event_changed.connect(_refresh_event_overlay)
    Game.combat_changed.connect(_refresh_combat_overlay)
    Game.toast_requested.connect(_show_toast)
    _ensure_valid_selection()
    Game.set_paused(true)
    _refresh_all()
    _refresh_event_overlay()
    _refresh_combat_overlay()
    if Game.current_combat.is_empty():
        _show_main_menu()

func _build_ui():
    var bg = ColorRect.new()
    bg.color = Color("101416")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var root = VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 8
    root.offset_top = 8
    root.offset_right = -8
    root.offset_bottom = -8
    root.clip_contents = true
    root.add_theme_constant_override("separation", 6)
    add_child(root)

    var ad_panel = PanelContainer.new()
    ad_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ad_panel.custom_minimum_size = Vector2(0, 34)
    var ad_label = _make_label("AD SPACE — development placeholder", 12)
    ad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ad_panel.add_child(ad_label)
    root.add_child(ad_panel)

    var status_panel = PanelContainer.new()
    status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var status_v = VBoxContainer.new()
    status_v.add_theme_constant_override("separation", 2)
    status_panel.add_child(status_v)
    var status_row = HBoxContainer.new()
    status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_label = _make_label("", 14)
    status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    status_row.add_child(status_label)
    pause_button = Button.new()
    pause_button.custom_minimum_size = Vector2(84, 42)
    pause_button.pressed.connect(_on_pause_pressed)
    status_row.add_child(pause_button)
    menu_button = Button.new()
    menu_button.text = "MENU"
    menu_button.custom_minimum_size = Vector2(0, 0)
    menu_button.visible = false
    menu_button.pressed.connect(_show_main_menu)
    status_row.add_child(menu_button)
    status_v.add_child(status_row)
    timer_label = _make_label("", 12)
    timer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_v.add_child(timer_label)
    root.add_child(status_panel)

    toast_panel = PanelContainer.new()
    toast_panel.visible = false
    toast_label = _make_label("", 13)
    toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    toast_panel.add_child(toast_label)
    root.add_child(toast_panel)
    toast_timer = Timer.new()
    toast_timer.one_shot = true
    toast_timer.wait_time = 3.0
    toast_timer.timeout.connect(func(): toast_panel.visible = false)
    add_child(toast_timer)

    var camp_frame = PanelContainer.new()
    camp_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    camp_frame.clip_contents = true
    camp_frame.custom_minimum_size = Vector2(0, 210)
    camp_view = CampView.new()
    camp_view.custom_minimum_size = Vector2(0, 210)
    camp_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    camp_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    camp_frame.add_child(camp_view)
    root.add_child(camp_frame)

    content_scroll = ScrollContainer.new()
    content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content_scroll.clip_contents = true
    MobileScroll.configure(content_scroll)
    content_box = VBoxContainer.new()
    content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_box.custom_minimum_size = Vector2(0, 0)
    content_box.add_theme_constant_override("separation", 8)
    content_scroll.add_child(content_box)
    root.add_child(content_scroll)

    var nav = GridContainer.new()
    nav.columns = 4
    nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nav.custom_minimum_size = Vector2(0, 52)
    nav.add_theme_constant_override("h_separation", 4)
    for tab in ["Camp", "Craft", "Build", "Survivors"]:
        var b = Button.new()
        b.text = tab.to_upper()
        b.custom_minimum_size = Vector2(0, 52)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.add_theme_font_size_override("font_size", 12)
        b.pressed.connect(_on_tab_pressed.bind(tab))
        nav_buttons[tab] = b
        nav.add_child(b)
    root.add_child(nav)

    _build_event_overlay()
    _build_expedition_overlay()
    _build_main_menu()
    _build_inspector_overlay()
    _build_combat_overlay()
    _build_tutorial_overlay()

    reset_confirm = ConfirmationDialog.new()
    reset_confirm.title = "Reset Alpha Save?"
    reset_confirm.dialog_text = "This deletes the current First Fire run and starts over."
    reset_confirm.confirmed.connect(_reset_alpha_save)
    add_child(reset_confirm)

    new_game_confirm = ConfirmationDialog.new()
    new_game_confirm.title = "Start New Game?"
    new_game_confirm.dialog_text = "This replaces the current First Fire save."
    new_game_confirm.confirmed.connect(_start_new_game_from_menu)
    add_child(new_game_confirm)

func _build_main_menu():
    main_menu_overlay = ColorRect.new()
    main_menu_overlay.color = Color(0, 0, 0, 0.9)
    main_menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    main_menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(main_menu_overlay)

    menu_camp_view = CampView.new()
    menu_camp_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    main_menu_overlay.add_child(menu_camp_view)
    var shade = ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0, 0, 0, 0.38)
    main_menu_overlay.add_child(shade)

    var center = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    main_menu_overlay.add_child(center)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(330, 0)
    center.add_child(panel)
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_bottom", 28)
    panel.add_child(margin)
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    margin.add_child(v)

    var title = _make_label("FIRST FIRE", 32)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(title)
    var subtitle = _make_label("Paused — one fire, one survivor", 14)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(subtitle)
    v.add_child(_separator())

    var new_button = Button.new()
    new_button.text = "NEW GAME"
    new_button.custom_minimum_size = Vector2(0, 54)
    new_button.pressed.connect(_on_new_game_menu_pressed)
    v.add_child(new_button)

    load_game_button = Button.new()
    load_game_button.text = "LOAD GAME"
    load_game_button.custom_minimum_size = Vector2(0, 54)
    load_game_button.pressed.connect(_load_game_from_menu)
    v.add_child(load_game_button)

    var return_button = Button.new()
    return_button.text = "RESUME"
    return_button.custom_minimum_size = Vector2(0, 48)
    return_button.pressed.connect(_close_main_menu)
    v.add_child(return_button)

    var exit_button = Button.new()
    exit_button.text = "EXIT"
    exit_button.custom_minimum_size = Vector2(0, 48)
    exit_button.pressed.connect(_on_exit_pressed)
    v.add_child(exit_button)

    var note = _make_label("The simulation is paused while this menu is open.", 12)
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(note)

func _build_tutorial_overlay():
    tutorial_overlay = ColorRect.new()
    tutorial_overlay.color = Color(0, 0, 0, 0.88)
    tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    tutorial_overlay.visible = false
    add_child(tutorial_overlay)

    var center = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tutorial_overlay.add_child(center)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(350, 0)
    center.add_child(panel)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    panel.add_child(margin)

    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    margin.add_child(v)

    tutorial_progress = _make_label("", 12)
    tutorial_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(tutorial_progress)

    tutorial_title = _make_label("", 23)
    tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tutorial_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(tutorial_title)

    tutorial_body = _make_label("", 15)
    tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(tutorial_body)

    var buttons = HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 8)
    v.add_child(buttons)

    var skip = Button.new()
    skip.text = "SKIP"
    skip.custom_minimum_size = Vector2(105, 48)
    skip.pressed.connect(_finish_tutorial)
    buttons.add_child(skip)

    tutorial_next_button = Button.new()
    tutorial_next_button.text = "NEXT"
    tutorial_next_button.custom_minimum_size = Vector2(0, 48)
    tutorial_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tutorial_next_button.pressed.connect(_advance_tutorial)
    buttons.add_child(tutorial_next_button)

func _show_tutorial_if_needed():
    if tutorial_overlay == null or not Game.tutorial_needed() or not Game.current_combat.is_empty():
        return
    tutorial_index = 0
    tutorial_restore_paused = Game.sim_paused
    Game.set_paused(true)
    _refresh_tutorial_step()
    tutorial_overlay.visible = true
    tutorial_overlay.move_to_front()

func _refresh_tutorial_step():
    if tutorial_overlay == null or TUTORIAL_STEPS.is_empty():
        return
    tutorial_index = clampi(tutorial_index, 0, TUTORIAL_STEPS.size() - 1)
    var step: Dictionary = TUTORIAL_STEPS[tutorial_index]
    tutorial_progress.text = "QUICK START  •  %d / %d" % [tutorial_index + 1, TUTORIAL_STEPS.size()]
    tutorial_title.text = str(step.get("title", "FIRST FIRE"))
    tutorial_body.text = str(step.get("body", ""))
    tutorial_next_button.text = "GOT IT" if tutorial_index == TUTORIAL_STEPS.size() - 1 else "NEXT"

func _advance_tutorial():
    if tutorial_index >= TUTORIAL_STEPS.size() - 1:
        _finish_tutorial()
        return
    tutorial_index += 1
    _refresh_tutorial_step()

func _finish_tutorial():
    if tutorial_overlay != null:
        tutorial_overlay.visible = false
    Game.complete_tutorial()
    if not Game.current_combat.is_empty():
        Game.set_paused(true)
    else:
        Game.set_paused(tutorial_restore_paused)
    _refresh_all()

func _reset_alpha_save():
    Game.new_game()
    Game.save_existed_on_boot = true
    selected_survivor_id = -1
    selected_worker_id = -1
    current_tab = "Camp"
    _ensure_valid_selection()
    _refresh_all()
    _show_tutorial_if_needed()

func _build_event_overlay():
    event_overlay = ColorRect.new()
    event_overlay.color = Color(0, 0, 0, 0.82)
    event_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    event_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    event_overlay.visible = false
    add_child(event_overlay)

    var center = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    event_overlay.add_child(center)
    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(350, 0)
    center.add_child(panel)
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 16)
    panel.add_child(margin)
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 10)
    margin.add_child(v)
    event_title = _make_label("", 24)
    event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(event_title)
    event_body = _make_label("", 16)
    event_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(event_body)
    event_choices = VBoxContainer.new()
    event_choices.add_theme_constant_override("separation", 6)
    v.add_child(event_choices)

func _build_expedition_overlay():
    expedition_overlay = ColorRect.new()
    expedition_overlay.color = Color(0, 0, 0, 0.86)
    expedition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    expedition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    expedition_overlay.visible = false
    add_child(expedition_overlay)

    var center = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    expedition_overlay.add_child(center)
    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(350, 0)
    center.add_child(panel)
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 16)
    panel.add_child(margin)
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 8)
    margin.add_child(v)

    expedition_title = _make_label("SEND OUT", 22)
    expedition_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(expedition_title)

    v.add_child(_make_label("Zone", 13))
    expedition_zone = OptionButton.new()
    expedition_zone.custom_minimum_size = Vector2(0, 44)
    v.add_child(expedition_zone)

    var send = Button.new()
    send.text = "SEND"
    send.custom_minimum_size = Vector2(0, 48)
    send.pressed.connect(_on_expedition_send)
    v.add_child(send)

    expedition_specials = VBoxContainer.new()
    expedition_specials.add_theme_constant_override("separation", 4)
    v.add_child(expedition_specials)

    var close = Button.new()
    close.text = "CANCEL"
    close.custom_minimum_size = Vector2(0, 44)
    close.pressed.connect(func(): expedition_overlay.visible = false)
    v.add_child(close)

func _build_inspector_overlay():
    inspector_overlay = InspectorOverlay.new()
    inspector_overlay.send_survivor.connect(_on_inspector_send)
    add_child(inspector_overlay)

func _build_combat_overlay():
    combat_overlay = FFCombat.new()
    combat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    combat_overlay.visible = false
    combat_overlay.encounter_finished.connect(_on_combat_finished)
    add_child(combat_overlay)

func _refresh_combat_overlay():
    if combat_overlay == null:
        return
    if Game.current_combat.is_empty():
        combat_uid = ""
        if combat_overlay.visible:
            combat_overlay.stop_encounter()
        combat_overlay.visible = false
        return
    if main_menu_overlay != null:
        main_menu_overlay.visible = false
    if expedition_overlay != null:
        expedition_overlay.visible = false
    if event_overlay != null:
        event_overlay.visible = false
    if inspector_overlay != null and inspector_overlay.visible:
        inspector_overlay.force_close()
    var uid = str(Game.current_combat.get("uid", ""))
    if uid != combat_uid or not combat_overlay.visible:
        combat_uid = uid
        combat_overlay.start_encounter(Game.current_combat)
    combat_overlay.visible = true
    combat_overlay.move_to_front()

func _on_combat_finished(result):
    Game.resolve_combat(result)

func _ensure_valid_selection():
    if Game.survivors.is_empty():
        selected_survivor_id = -1
        selected_worker_id = -1
        return
    if Game.get_survivor(selected_survivor_id) == null:
        selected_survivor_id = int(Game.survivors[0]["id"])
    var avail = Game.available_survivors()
    if avail.is_empty():
        selected_worker_id = -1
    elif Game.get_survivor(selected_worker_id) == null or Game.get_survivor(selected_worker_id)["status"] != "Available":
        selected_worker_id = int(avail[0]["id"])

func _show_main_menu():
    if not Game.current_combat.is_empty():
        _refresh_combat_overlay()
        return
    if inspector_overlay != null and inspector_overlay.visible:
        inspector_overlay.force_close()
    Game.set_paused(true)
    if main_menu_overlay != null:
        load_game_button.disabled = not Game.save_existed_on_boot
        main_menu_overlay.visible = true
        main_menu_overlay.move_to_front()

func _close_main_menu():
    if main_menu_overlay != null:
        main_menu_overlay.visible = false
    current_tab = current_tab if current_tab != "" else "Camp"
    _ensure_valid_selection()
    if not Game.current_combat.is_empty():
        Game.set_paused(true)
        _refresh_combat_overlay()
        return
    Game.set_paused(false)
    _refresh_all()
    _show_tutorial_if_needed()

func _on_new_game_menu_pressed():
    if Game.save_existed_on_boot:
        new_game_confirm.popup_centered()
    else:
        _start_new_game_from_menu()

func _start_new_game_from_menu():
    Game.new_game()
    Game.save_existed_on_boot = true
    selected_survivor_id = -1
    selected_worker_id = -1
    _ensure_valid_selection()
    current_tab = "Camp"
    if main_menu_overlay != null:
        main_menu_overlay.visible = false
    Game.set_paused(false)
    _refresh_all()
    _show_tutorial_if_needed()

func _load_game_from_menu():
    Game.load_game()
    Game.save_existed_on_boot = true
    selected_survivor_id = -1
    selected_worker_id = -1
    _ensure_valid_selection()
    current_tab = "Camp"
    if main_menu_overlay != null:
        main_menu_overlay.visible = false
    if Game.current_combat.is_empty():
        Game.set_paused(false)
        _refresh_all()
    else:
        Game.set_paused(true)
        _refresh_combat_overlay()

func _make_label(text: String, size = 16) -> Label:
    var l = Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return l

func _heading(text: String, size = 22) -> Label:
    var l = _make_label(text, size)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func _separator():
    var sep = HSeparator.new()
    sep.custom_minimum_size = Vector2(0, 8)
    return sep


func _refresh_nav_buttons():
    for tab in nav_buttons.keys():
        var b = nav_buttons[tab]
        b.disabled = (tab == current_tab)

func _clear_content():
    for child in content_box.get_children():
        content_box.remove_child(child)
        child.queue_free()

func _refresh_all():
    _ensure_valid_selection()
    _refresh_status()
    _refresh_nav_buttons()
    _refresh_content()
    _refresh_event_overlay()
    _refresh_combat_overlay()

func _refresh_status():
    if status_label == null:
        return
    var pause_text = "PAUSED" if Game.sim_paused else "RUNNING"
    status_label.text = "Day %d  %s  •  Food %d  Water %d  •  Pop %d/%d  Beds %d" % [
        Game.day,
        Game.formatted_time(),
        int(Game.resources.get("Cooked Food", 0)),
        int(Game.resources.get("Clean Water", 0)),
        Game.population(),
        Game.MAX_POPULATION,
        Game.shelter_capacity()
    ]
    pause_button.text = "PAUSE"
    var active = []
    for exp in Game.expeditions:
        if exp.get("state", "") == "traveling":
            active.append("%s: %.0fs" % [Game._party_names(exp["survivor_ids"]), float(exp["remaining"])])
        elif exp.get("state", "") == "pending":
            active.append("%s: DECISION" % Game._party_names(exp["survivor_ids"]))
        elif exp.get("state", "") == "combat":
            active.append("%s: TACTICAL" % Game._party_names(exp["survivor_ids"]))
    for s in Game.survivors:
        if ["Crafting", "Building", "Recovering", "Tending"].has(s["status"]) and not s["task"].is_empty():
            active.append("%s %s: %.0fs" % [s["name"], s["status"].to_lower(), float(s["task"].get("remaining", 0.0))])
    timer_label.text = (pause_text + ("  •  " + "  |  ".join(active) if not active.is_empty() else ""))

func _refresh_content():
    if content_box == null:
        return
    _clear_content()
    match current_tab:
        "Camp": _draw_camp()
        "Craft": _draw_craft()
        "Build": _draw_build()
        "Survivors": _draw_survivors()

func _draw_camp():
    content_box.add_child(_heading("FIRST FIRE", 26))
    content_box.add_child(_make_label("A tiny camp trying to become something permanent.", 14))

    content_box.add_child(_separator())
    content_box.add_child(_heading("Camp Status", 19))
    var stats = GridContainer.new()
    stats.columns = 2
    stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var stat_pairs = [
        ["Population", "%d / %d" % [Game.population(), Game.MAX_POPULATION]],
        ["Shelter Beds", "%d" % Game.shelter_capacity()],
        ["Settlement", "MATURE" if Game.settlement_mature else "GROWING"],
        ["Ready Food", str(int(Game.resources.get("Cooked Food", 0)))],
        ["Clean Water", str(int(Game.resources.get("Clean Water", 0)))],
                ["Threat", "LOW" if Game.buildings.get("Noise Line", false) else "MINIMAL"],
        ["Cohesion", _cohesion_label()]
    ]
    for pair in stat_pairs:
        stats.add_child(_make_label(str(pair[0]), 14))
        var val = _make_label(str(pair[1]), 14)
        val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        stats.add_child(val)
    content_box.add_child(stats)

    content_box.add_child(_separator())
    content_box.add_child(_heading("Resources", 19))
    var grid = GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for key in D.RESOURCE_ORDER:
        grid.add_child(_make_label(key, 14))
        var value = _make_label(str(int(Game.resources.get(key, 0))), 14)
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        grid.add_child(value)
    content_box.add_child(grid)

    var component_parts = []
    for key in Game.components.keys():
        if int(Game.components[key]) > 0:
            component_parts.append("%s ×%d" % [key, int(Game.components[key])])
    if not component_parts.is_empty():
        content_box.add_child(_make_label("Components: " + ", ".join(component_parts), 13))

    content_box.add_child(_separator())
    content_box.add_child(_heading("Current Work", 19))
    var any_work = false
    for s in Game.survivors:
        if s["condition"] == "Dead":
            continue
        content_box.add_child(_make_label("%s — %s" % [s["name"], _activity_text(s)], 14))
        any_work = true
    if not any_work:
        content_box.add_child(_make_label("No one remains.", 14))

    content_box.add_child(_separator())
    content_box.add_child(_heading("Leadership", 19))
    var leader: Variant = Game.get_survivor(Game.leader_id if Game.leader_id != -1 else Game.coordinator_id)
    if leader == null:
        content_box.add_child(_make_label("No recognized leader yet.", 14))
    else:
        content_box.add_child(_make_label("%s: %s — %s" % [Game.leadership_form, leader["name"], leader["leader_ability"]], 14))
        content_box.add_child(_make_label(D.LEADER_ABILITIES[leader["leader_ability"]], 13))
        content_box.add_child(_make_label("Support: %s" % Game.leader_support_label(), 13))
    if not Game.policies.is_empty():
        for key in Game.policies.keys():
            content_box.add_child(_make_label("%s: %s" % [key, Game.policies[key]], 13))

    content_box.add_child(_separator())
    content_box.add_child(_heading("Camp", 19))
    var built = []
    for b in ["Fire Pit", "Sleeping Bag"] + D.BUILD_ORDER:
        if Game.buildings.get(b, false): built.append(b)
    content_box.add_child(_make_label(", ".join(built), 14))

    var sites = []
    for site in Game.special_sites.keys():
        if Game.special_sites[site]["discovered"] and not Game.special_sites[site]["cleared"]:
            sites.append(site)
    if not sites.is_empty():
        content_box.add_child(_make_label("Known special sites: " + ", ".join(sites), 14))

    content_box.add_child(_separator())
    content_box.add_child(_heading("Recent History", 19))
    var start = max(0, Game.history.size() - 10)
    for i in range(Game.history.size() - 1, start - 1, -1):
        content_box.add_child(_make_label(Game.history[i], 13))

    var reset = Button.new()
    reset.text = "RESET ALPHA SAVE"
    reset.custom_minimum_size = Vector2(0, 44)
    reset.pressed.connect(func(): reset_confirm.popup_centered())
    content_box.add_child(reset)

func _draw_craft():
    content_box.add_child(_heading("CRAFT", 26))
    var worker = _worker_picker()
    content_box.add_child(worker)

    for station in ["Fire Pit", "Workbench", "Sewing Table"]:
        if station != "Fire Pit" and not Game.buildings.get(station, false):
            continue
        content_box.add_child(_separator())
        content_box.add_child(_heading(station, 19))
        for recipe in D.RECIPES.get(station, []):
            var panel = PanelContainer.new()
            var v = VBoxContainer.new()
            panel.add_child(v)
            v.add_child(_make_label(recipe["id"], 16))
            var desc = _format_cost(recipe.get("cost", {}), recipe.get("component_cost", {})) + "  •  %.0fs base" % float(recipe["time"])
            var outputs = []
            for out_key in recipe.get("gives_resource", {}).keys():
                outputs.append("%d %s" % [int(recipe["gives_resource"][out_key]), out_key])
            for out_key in recipe.get("gives_component", {}).keys():
                outputs.append("%d %s" % [int(recipe["gives_component"][out_key]), out_key])
            if recipe.get("gives_gear", "") != "":
                outputs.append(str(recipe["gives_gear"]))
            if not outputs.is_empty():
                desc += "  →  " + ", ".join(outputs)
            v.add_child(_make_label(desc, 12))
            var recipe_req_ok := true
            if recipe.has("requires"):
                v.add_child(_make_label("Requires: " + ", ".join(recipe["requires"]), 12))
                for req in recipe["requires"]:
                    if not Game.buildings.get(req, false): recipe_req_ok = false
            var b = Button.new()
            b.text = "CRAFT"
            b.custom_minimum_size = Vector2(0, 40)
            b.disabled = selected_worker_id < 0 or not recipe_req_ok or not _can_pay_ui(recipe.get("cost", {}), recipe.get("component_cost", {}))
            b.pressed.connect(_on_craft_pressed.bind(station, recipe["id"]))
            v.add_child(b)
            content_box.add_child(panel)

func _draw_build():
    content_box.add_child(_heading("BUILD", 26))
    content_box.add_child(_make_label("This is the final First Fire building tree. Gray BUILD buttons mean you are missing materials, a worker, or a prerequisite.", 13))
    content_box.add_child(_worker_picker())
    if Game.buildings.get("Garden Plot", false):
        var tend = Button.new()
        tend.text = "TEND GARDEN" + (" — done today" if Game.garden_tended_day == Game.day else "")
        tend.custom_minimum_size = Vector2(0, 44)
        tend.disabled = selected_worker_id < 0 or Game.garden_tended_day == Game.day
        tend.pressed.connect(func(): Game.tend_garden(selected_worker_id))
        content_box.add_child(tend)

    for building in D.BUILD_ORDER:
        content_box.add_child(_separator())
        var panel = PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var v = VBoxContainer.new()
        v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.add_child(v)
        v.add_child(_make_label(building, 17))
        if Game.buildings.get(building, false):
            v.add_child(_make_label("BUILT", 13))
            content_box.add_child(panel)
            continue
        var data = D.BUILDINGS[building]
        if str(data.get("description", "")) != "":
            v.add_child(_make_label(str(data["description"]), 12))
        v.add_child(_make_label(_format_cost(data.get("cost", {}), data.get("component_cost", {})) + "  •  %.0fs base" % float(data["time"]), 12))
        if data.has("requires"):
            v.add_child(_make_label("Requires: " + ", ".join(data["requires"]), 12))
        var b = Button.new()
        b.text = "BUILD"
        b.custom_minimum_size = Vector2(0, 42)
        var req_ok = true
        for req in data.get("requires", []):
            if not Game.buildings.get(req, false): req_ok = false
        b.disabled = selected_worker_id < 0 or not req_ok or not _can_pay_ui(data.get("cost", {}), data.get("component_cost", {}))
        b.pressed.connect(_on_build_pressed.bind(building))
        v.add_child(b)
        content_box.add_child(panel)

func _draw_survivors():
    var panel = SurvivorPanel.new()
    panel.inspect_survivor.connect(_open_survivor_inspector)
    panel.inspect_inventory.connect(_open_camp_inventory_inspector)
    panel.send_survivor.connect(_send_survivor_from_panel)
    content_box.add_child(panel)

func _worker_picker():
    var box = VBoxContainer.new()
    box.add_child(_make_label("Worker", 13))
    var avail = Game.available_survivors()
    if avail.is_empty():
        selected_worker_id = -1
        var none = _make_label("No available survivor", 14)
        none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        none.custom_minimum_size = Vector2(0, 46)
        box.add_child(none)
        return box

    var valid_current := false
    for survivor in avail:
        if int(survivor["id"]) == selected_worker_id:
            valid_current = true
            break
    if not valid_current:
        selected_worker_id = int(avail[0]["id"])

    var current: Variant = Game.get_survivor(selected_worker_id)
    var current_index := 0
    for i in range(avail.size()):
        if int(avail[i]["id"]) == selected_worker_id:
            current_index = i
            break

    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)

    var previous = Button.new()
    previous.text = "PREV"
    previous.custom_minimum_size = Vector2(64, 48)
    previous.disabled = avail.size() <= 1
    previous.pressed.connect(_on_worker_cycle.bind(-1))
    row.add_child(previous)

    var worker_text := "Unknown survivor"
    if current != null:
        worker_text = "%s\nTechnical %d  •  %d/%d" % [current["name"], int(current["skills"]["Technical"]), current_index + 1, avail.size()]
    var current_label = _make_label(worker_text, 13)
    current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    current_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    current_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    current_label.custom_minimum_size = Vector2(0, 48)
    row.add_child(current_label)

    var next = Button.new()
    next.text = "NEXT"
    next.custom_minimum_size = Vector2(64, 48)
    next.disabled = avail.size() <= 1
    next.pressed.connect(_on_worker_cycle.bind(1))
    row.add_child(next)

    box.add_child(row)
    return box

func _format_cost(cost, component_cost = {}):
    var parts = []
    for key in cost.keys():
        parts.append("%d %s" % [int(cost[key]), key])
    for key in component_cost.keys():
        parts.append("%d %s" % [int(component_cost[key]), key])
    return ", ".join(parts) if not parts.is_empty() else "No cost"

func _can_pay_ui(cost, component_cost = {}):
    for key in cost.keys():
        if int(Game.resources.get(key, 0)) < int(cost[key]): return false
    for key in component_cost.keys():
        if int(Game.components.get(key, 0)) < int(component_cost[key]): return false
    return true

func _activity_text(s):
    if s["status"] == "Expedition" or s["status"] == "Pending Expedition Event":
        var eid = int(s["task"].get("expedition_id", -1))
        var exp = Game._find_expedition(eid)
        if exp != null:
            if exp["state"] == "pending": return "%s — decision pending" % exp["zone"]
            return "%s — %.0fs remaining" % [exp["zone"], float(exp["remaining"])]
    if ["Crafting", "Building", "Recovering", "Tending"].has(s["status"]) and not s["task"].is_empty():
        return "%s — %.0fs remaining" % [s["status"], float(s["task"].get("remaining", 0.0))]
    return s["status"]

func _cohesion_label():
    var hostile = 0
    var tense = 0
    for s in Game.survivors:
        for v in s["relationships"].values():
            if int(v) <= -60: hostile += 1
            elif int(v) <= -25: tense += 1
    if hostile > 0: return "FRACTURED"
    if tense > 0: return "TENSE"
    return "STABLE"

func _on_exit_pressed():
    Game.save_game()
    if OS.has_feature("web"):
        # A Web export cannot really "quit" a browser tab. Redirecting avoids
        # leaving a frozen canvas that looks like the browser locked up.
        await get_tree().create_timer(0.20).timeout
        JavaScriptBridge.eval("window.location.href='https://www.google.com/';", true)
    else:
        get_tree().quit()

func _on_pause_pressed():
    _show_main_menu()

func _on_tab_pressed(tab):
    current_tab = tab
    _refresh_nav_buttons()
    _refresh_content()
    content_scroll.scroll_vertical = 0

func _on_worker_cycle(direction: int):
    var avail = Game.available_survivors()
    if avail.size() <= 1:
        return
    var current_index := 0
    for i in range(avail.size()):
        if int(avail[i]["id"]) == selected_worker_id:
            current_index = i
            break
    var next_index := posmod(current_index + direction, avail.size())
    selected_worker_id = int(avail[next_index]["id"])
    # Rebuild after the pressed signal unwinds instead of deleting the active
    # control tree from inside its own input callback.
    call_deferred("_refresh_content")

func _open_survivor_inspector(id):
    selected_survivor_id = int(id)
    if inspector_overlay != null:
        inspector_overlay.open_survivor(selected_survivor_id)

func _open_camp_inventory_inspector():
    if inspector_overlay != null:
        inspector_overlay.open_inventory()

func _send_survivor_from_panel(id):
    selected_survivor_id = int(id)
    _open_expedition_overlay()

func _on_inspector_send(id):
    selected_survivor_id = int(id)
    _open_expedition_overlay()

func _on_craft_pressed(station, recipe_id):
    Game.start_craft(selected_worker_id, station, recipe_id)

func _on_build_pressed(building):
    Game.start_build(selected_worker_id, building)

func _open_expedition_overlay():
    var s: Variant = Game.get_survivor(selected_survivor_id)
    if s == null or s["status"] != "Available":
        return
    expedition_title.text = "SEND OUT — %s" % s["name"]
    expedition_zone.clear()
    for zone in D.ZONE_ORDER:
        if Game.unlocked_zones.has(zone):
            var data = D.ZONES[zone]
            expedition_zone.add_item("%s — %.0fs — %s — Loot %s" % [zone, float(data["duration"]), data["danger"], Game.zone_loot_state(zone)])
            expedition_zone.set_item_metadata(expedition_zone.item_count - 1, zone)
    for child in expedition_specials.get_children():
        expedition_specials.remove_child(child)
        child.queue_free()
    var found_site = false
    for site in Game.special_sites.keys():
        if Game.special_sites[site]["discovered"] and not Game.special_sites[site]["cleared"]:
            if not found_site:
                expedition_specials.add_child(_make_label("SPECIAL SITES", 14))
                found_site = true
            var b = Button.new()
            b.text = "%s — %.0fs" % [site, float(D.SPECIAL_SITES[site]["duration"])]
            b.custom_minimum_size = Vector2(0, 42)
            b.pressed.connect(_on_special_site_pressed.bind(site))
            expedition_specials.add_child(b)
    expedition_overlay.visible = true

func _on_expedition_send():
    if expedition_zone.item_count == 0:
        return
    var zone = str(expedition_zone.get_item_metadata(expedition_zone.selected))
    if Game.start_expedition(selected_survivor_id, zone):
        expedition_overlay.visible = false

func _on_special_site_pressed(site):
    if Game.start_special_site(selected_survivor_id, site):
        expedition_overlay.visible = false

func _refresh_event_overlay():
    if event_overlay == null:
        return
    if not Game.current_combat.is_empty():
        event_overlay.visible = false
        return
    if Game.current_event.is_empty():
        event_overlay.visible = false
        return
    event_overlay.visible = true
    event_title.text = Game.current_event.get("title", "EVENT")
    event_body.text = Game.current_event.get("body", "")
    for child in event_choices.get_children():
        event_choices.remove_child(child)
        child.queue_free()
    var choices = Game.current_event.get("choices", [])
    for i in range(choices.size()):
        var choice = choices[i]
        var b = Button.new()
        b.text = choice.get("text", "Continue")
        b.custom_minimum_size = Vector2(0, 48)
        b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        b.disabled = choice.get("disabled", false)
        b.pressed.connect(_on_event_choice.bind(i))
        event_choices.add_child(b)

func _on_event_choice(index):
    Game.resolve_event(index)

func _show_toast(message):
    toast_label.text = str(message)
    toast_panel.visible = true
    toast_timer.start()
