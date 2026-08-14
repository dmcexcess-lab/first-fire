extends VBoxContainer
class_name FFSurvivorPanel

const D = preload("res://scripts/FFData.gd")

signal inspect_survivor(survivor_id: int)
signal inspect_inventory
signal send_survivor(survivor_id: int)

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 8)
    _build()

func _build() -> void:
    add_child(_tab_art())
    add_child(_heading("SURVIVORS", 26))

    if Game.survivors.is_empty():
        add_child(_make_label("No survivor data loaded. Start a NEW GAME from MENU to repair this run.", 14))
        return

    var living: int = 0
    var home: int = 0
    var away: int = 0
    var busy: int = 0
    var lost: int = 0
    for survivor in Game.survivors:
        if str(survivor.get("condition", "Healthy")) == "Dead":
            lost += 1
            continue
        living += 1
        var status: String = str(survivor.get("status", "Available"))
        if _is_away_status(status):
            away += 1
        elif status == "Available":
            home += 1
        else:
            busy += 1

    var summary = GridContainer.new()
    summary.columns = 4
    summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for pair in [["CAMP", home], ["OUT", away], ["BUSY", busy], ["LOST", lost]]:
        var box = VBoxContainer.new()
        box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var number = _make_label(str(int(pair[1])), 20)
        number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(number)
        var label = _make_label(str(pair[0]), 10)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(label)
        summary.add_child(box)
    add_child(summary)

    var inventory_button = Button.new()
    inventory_button.text = "CAMP INVENTORY"
    inventory_button.custom_minimum_size = Vector2(0, 48)
    inventory_button.pressed.connect(func(): inspect_inventory.emit())
    add_child(inventory_button)

    add_child(_separator())
    add_child(_heading("OUTSIDE CAMP", 19))
    if Game.expeditions.is_empty():
        add_child(_make_label("Everyone is inside the wire.", 13))
    else:
        for expedition in Game.expeditions:
            add_child(_expedition_card(expedition))

    add_child(_separator())
    add_child(_heading("RECENT RETURNS", 19))
    var returns: Array = _recent_returns(3)
    if returns.is_empty():
        add_child(_make_label("No recent expedition returns yet.", 13))
    else:
        for line in returns:
            var return_panel = PanelContainer.new()
            var return_margin = MarginContainer.new()
            return_margin.add_theme_constant_override("margin_left", 10)
            return_margin.add_theme_constant_override("margin_right", 10)
            return_margin.add_theme_constant_override("margin_top", 8)
            return_margin.add_theme_constant_override("margin_bottom", 8)
            return_panel.add_child(return_margin)
            return_margin.add_child(_make_label(str(line), 13))
            add_child(return_panel)

    add_child(_separator())
    add_child(_heading("ROSTER", 19))
    add_child(_make_label("Tap INSPECT for the full character sheet, skills, equipment, relationships, and history.", 12))
    for survivor in Game.survivors:
        add_child(_survivor_card(survivor))

func _expedition_card(expedition: Dictionary) -> Control:
    var panel = PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    panel.add_child(margin)
    var box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 3)
    margin.add_child(box)

    var ids: Array = expedition.get("survivor_ids", [])
    var names: String = Game._party_names(ids)
    var zone: String = str(expedition.get("zone", "Unknown"))
    var state: String = str(expedition.get("state", "traveling"))
    box.add_child(_make_label(names.to_upper(), 16))

    var state_text: String = "OUT • %s" % zone
    if state == "traveling":
        state_text += " • %.0fs remaining" % float(expedition.get("remaining", 0.0))
    elif state == "pending":
        state_text += " • DECISION WAITING"
    elif state == "combat":
        state_text += " • TACTICAL ENCOUNTER"
    box.add_child(_make_label(state_text, 13))
    return panel

func _survivor_card(survivor: Dictionary) -> Control:
    var panel = PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    panel.add_child(margin)
    var box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    margin.add_child(box)

    var sid: int = int(survivor.get("id", -1))
    var name: String = str(survivor.get("name", "Survivor"))
    var condition: String = str(survivor.get("condition", "Healthy"))
    var status: String = str(survivor.get("status", "Available"))

    var title_row = HBoxContainer.new()
    title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var name_label = _make_label(name, 17)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(name_label)
    var condition_label = _make_label(condition.to_upper(), 11)
    condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    title_row.add_child(condition_label)
    box.add_child(title_row)

    var activity: String = _activity_text(survivor)
    if _is_away_status(status):
        activity = "OUT • " + activity
    box.add_child(_make_label(activity, 13))
    box.add_child(_make_label("Fatigue %.0f  •  Stress %.0f" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 12))

    var actions = HBoxContainer.new()
    actions.add_theme_constant_override("separation", 4)
    var inspect = Button.new()
    inspect.text = "INSPECT"
    inspect.custom_minimum_size = Vector2(0, 44)
    inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inspect.pressed.connect(func(): inspect_survivor.emit(sid))
    actions.add_child(inspect)
    if condition != "Dead":
        var send = Button.new()
        send.text = "SEND OUT"
        send.custom_minimum_size = Vector2(0, 44)
        send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        send.disabled = status != "Available"
        send.pressed.connect(func(): send_survivor.emit(sid))
        actions.add_child(send)
    box.add_child(actions)
    return panel

func _recent_returns(limit: int) -> Array:
    var result: Array = []
    for index in range(Game.history.size() - 1, -1, -1):
        var line: String = str(Game.history[index])
        if " returned from " in line:
            result.append(line)
            if result.size() >= limit:
                break
    return result

func _is_away_status(status: String) -> bool:
    return ["Expedition", "Pending Expedition Event", "Tactical Encounter"].has(status)

func _activity_text(survivor: Dictionary) -> String:
    var status: String = str(survivor.get("status", "Available"))
    if status == "Expedition" or status == "Pending Expedition Event" or status == "Tactical Encounter":
        var task: Dictionary = survivor.get("task", {})
        var expedition_id: int = int(task.get("expedition_id", -1))
        var expedition: Variant = Game._find_expedition(expedition_id)
        if expedition != null:
            var zone: String = str(expedition.get("zone", "Unknown"))
            var state: String = str(expedition.get("state", "traveling"))
            if state == "pending":
                return "%s — decision pending" % zone
            if state == "combat":
                return "%s — tactical encounter" % zone
            return "%s — %.0fs remaining" % [zone, float(expedition.get("remaining", 0.0))]
    if ["Crafting", "Building", "Recovering", "Tending"].has(status):
        var active_task: Dictionary = survivor.get("task", {})
        if not active_task.is_empty():
            return "%s — %.0fs remaining" % [status, float(active_task.get("remaining", 0.0))]
    if status == "Available":
        return "At camp — available"
    return status

func _tab_art() -> Control:
    var frame = PanelContainer.new()
    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    frame.clip_contents = true
    var tex = TextureRect.new()
    tex.texture = load("res://assets/survivors.png")
    tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    tex.custom_minimum_size = Vector2(0, 150)
    tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    frame.add_child(tex)
    return frame

func _make_label(text: String, size: int = 16) -> Label:
    var label = Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return label

func _heading(text: String, size: int = 22) -> Label:
    return _make_label(text, size)

func _separator() -> HSeparator:
    var separator = HSeparator.new()
    separator.custom_minimum_size = Vector2(0, 8)
    return separator
