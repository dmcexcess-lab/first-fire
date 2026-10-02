extends Control
class_name FFCampChoreMinigame

signal action_requested(chore_id: String, target_index: int)
signal closed

const CampLifeRules = preload("res://scripts/FFCampLifeRules.gd")

var active_chore_id := ""
var target_index := -1
var title_label: Label
var worker_label: Label
var instruction_label: Label
var progress_label: Label
var target_buttons: Array = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 90
    visible = false
    _build_ui()

func _build_ui() -> void:
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.02, 0.018, 0.42)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(shade)

    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.anchor_left = 0.08
    panel.anchor_right = 0.92
    panel.anchor_top = 0.46
    panel.anchor_bottom = 0.985
    panel.offset_left = 0
    panel.offset_right = 0
    panel.offset_top = 0
    panel.offset_bottom = 0
    add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 16)
    panel.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 6)
    margin.add_child(column)

    var close_button := Button.new()
    close_button.text = "← BACK TO WORK BOARD"
    close_button.custom_minimum_size = Vector2(0, 36)
    close_button.pressed.connect(func(): closed.emit())
    column.add_child(close_button)

    title_label = Label.new()
    title_label.add_theme_font_size_override("font_size", 20)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title_label)

    worker_label = Label.new()
    worker_label.add_theme_font_size_override("font_size", 13)
    worker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(worker_label)

    instruction_label = Label.new()
    instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    instruction_label.add_theme_font_size_override("font_size", 14)
    instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(instruction_label)

    progress_label = Label.new()
    progress_label.add_theme_font_size_override("font_size", 15)
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(progress_label)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    column.add_child(grid)

    for index in range(CampLifeRules.CHORE_TARGET_COUNT):
        var button := Button.new()
        button.custom_minimum_size = Vector2(0, 52)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.size_flags_vertical = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 16)
        button.pressed.connect(_on_target_pressed.bind(index))
        grid.add_child(button)
        target_buttons.append(button)

func configure(chore: Dictionary, worker_name: String, next_target_index: int) -> void:
    active_chore_id = str(chore.get("id", ""))
    target_index = next_target_index
    var kind := str(chore.get("kind", ""))
    title_label.text = CampLifeRules.daily_chore_label(kind).to_upper()
    worker_label.text = "%s is working in camp while you play." % worker_name
    instruction_label.text = CampLifeRules.daily_chore_instruction(kind)
    var progress := int(chore.get("minigame_progress", 0))
    var goal := maxi(1, int(chore.get("minigame_goal", 1)))
    progress_label.text = "%d / %d" % [progress, goal]
    for index in range(target_buttons.size()):
        var button: Button = target_buttons[index]
        var is_target := index == target_index
        match kind:
            "poke_fire": button.text = "POKE" if is_target else "EMBER"
            "chop_wood": button.text = "CHOP" if is_target else "LOG"
            "clear_area": button.text = "CLEAR" if is_target else "DEBRIS"
            "stack_supplies": button.text = "STACK" if is_target else "CRATE"
            _: button.text = "TAP" if is_target else "..."
        button.disabled = false
    visible = true

func _on_target_pressed(index: int) -> void:
    if active_chore_id == "":
        return
    action_requested.emit(active_chore_id, index)
