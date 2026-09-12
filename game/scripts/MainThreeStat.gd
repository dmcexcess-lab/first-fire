extends "res://scripts/Main.gd"

const CombatThree = preload("res://scripts/FFCombatThreeStat.gd")
const InspectorThree = preload("res://scripts/FFInspectorThreeStat.gd")

func _build_inspector_overlay():
    inspector_overlay = InspectorThree.new()
    inspector_overlay.send_survivor.connect(_on_inspector_send)
    add_child(inspector_overlay)

func _build_combat_overlay():
    combat_overlay = CombatThree.new()
    combat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    combat_overlay.visible = false
    combat_overlay.encounter_finished.connect(_on_combat_finished)
    add_child(combat_overlay)

func _worker_picker():
    var box = VBoxContainer.new()
    box.add_child(_make_label("Worker", 13))
    var avail = Game.available_survivors()
    if avail.is_empty():
        selected_worker_id = -1
        var none = _make_label("No available survivor", 14)
        box.add_child(none)
        return box

    var valid_current := false
    for s in avail:
        if int(s["id"]) == selected_worker_id:
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
        var stats: Dictionary = current.get("skills", {})
        worker_text = "%s\nCOM %d  AGI %d  LEAD %d  •  %d/%d" % [
            current["name"],
            int(stats.get("Combat", 0)),
            int(stats.get("Agility", 0)),
            int(stats.get("Leadership", 0)),
            current_index + 1,
            avail.size()
        ]
    var current_label = _make_label(worker_text, 12)
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