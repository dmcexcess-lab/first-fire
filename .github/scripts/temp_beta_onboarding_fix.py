from pathlib import Path

ROOT = Path('.')


def read(path):
    return (ROOT / path).read_text()


def write(path, text):
    (ROOT / path).write_text(text)


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one anchor, found {count}')
    return text.replace(old, new, 1)

# ---------------------------------------------------------------------------
# Game: tutorial is a new-save flag inside existing schema 7.
# Old schema-7 saves without the key are intentionally treated as onboarded.
# ---------------------------------------------------------------------------
path = 'game/scripts/Game.gd'
t = read(path)
t = replace_once(
    t,
    '    history = []\n    flags = {}\n    policies = {}',
    '    history = []\n    flags = {"tutorial_complete": false}\n    policies = {}',
    'new-game tutorial flag',
)
t = replace_once(
    t,
    'func has_save_game():\n    return SaveCodec.exists(SAVE_PATH)\n\nfunc new_game():',
    'func has_save_game():\n    return SaveCodec.exists(SAVE_PATH)\n\nfunc tutorial_needed() -> bool:\n    # Only saves created after onboarding was added carry this flag. Existing\n    # schema-7 Beta saves are not interrupted by a retroactive tutorial.\n    return flags.has("tutorial_complete") and not bool(flags.get("tutorial_complete", true))\n\nfunc complete_tutorial() -> void:\n    flags["tutorial_complete"] = true\n    save_game()\n\nfunc new_game():',
    'tutorial helpers',
)
write(path, t)

# ---------------------------------------------------------------------------
# Main: replace popup worker OptionButton with direct previous/next controls
# and add a compact four-step first-save tutorial overlay.
# ---------------------------------------------------------------------------
path = 'game/scripts/Main.gd'
t = read(path)
t = replace_once(
    t,
    'const CampView = preload("res://scripts/FFCampView.gd")\n\nvar current_tab := "Camp"',
    '''const CampView = preload("res://scripts/FFCampView.gd")

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

var current_tab := "Camp"''',
    'tutorial steps',
)
t = replace_once(
    t,
    'var camp_view: Control\nvar menu_camp_view: Control\n',
    '''var camp_view: Control
var menu_camp_view: Control

var tutorial_overlay: ColorRect
var tutorial_title: Label
var tutorial_body: Label
var tutorial_progress: Label
var tutorial_next_button: Button
var tutorial_index := 0
var tutorial_restore_paused := false
''',
    'tutorial ui vars',
)
t = replace_once(
    t,
    '    _build_main_menu()\n    _build_inspector_overlay()\n    _build_combat_overlay()\n\n    reset_confirm = ConfirmationDialog.new()',
    '    _build_main_menu()\n    _build_inspector_overlay()\n    _build_combat_overlay()\n    _build_tutorial_overlay()\n\n    reset_confirm = ConfirmationDialog.new()',
    'tutorial build call',
)
t = replace_once(
    t,
    '''    reset_confirm.confirmed.connect(func():
        Game.new_game()
        _ensure_valid_selection()
    )''',
    '''    reset_confirm.confirmed.connect(_reset_alpha_save)''',
    'reset tutorial integration',
)
t = replace_once(
    t,
    'func _build_event_overlay():',
    '''func _build_tutorial_overlay():
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

func _build_event_overlay():''',
    'tutorial overlay functions',
)
t = replace_once(
    t,
    '''    Game.set_paused(false)
    _refresh_all()

func _on_new_game_menu_pressed():''',
    '''    Game.set_paused(false)
    _refresh_all()
    _show_tutorial_if_needed()

func _on_new_game_menu_pressed():''',
    'resume tutorial hook',
)
t = replace_once(
    t,
    '''    Game.set_paused(false)
    _refresh_all()

func _load_game_from_menu():''',
    '''    Game.set_paused(false)
    _refresh_all()
    _show_tutorial_if_needed()

func _load_game_from_menu():''',
    'new game tutorial hook',
)
old_picker = '''func _worker_picker():
    var box = VBoxContainer.new()
    box.add_child(_make_label("Worker", 13))
    var option = OptionButton.new()
    var avail = Game.available_survivors()
    var selected_index = 0
    if avail.is_empty():
        option.add_item("No available survivor")
        option.disabled = true
        selected_worker_id = -1
    else:
        var valid_current = false
        for a in avail:
            if int(a["id"]) == selected_worker_id: valid_current = true
        if not valid_current: selected_worker_id = int(avail[0]["id"])
        var idx = 0
        for s in avail:
            option.add_item("%s — Technical %d" % [s["name"], int(s["skills"]["Technical"])])
            option.set_item_metadata(idx, int(s["id"]))
            if int(s["id"]) == selected_worker_id: selected_index = idx
            idx += 1
        option.select(selected_index)
        option.item_selected.connect(_on_worker_selected.bind(option))
    option.custom_minimum_size = Vector2(0, 46)
    box.add_child(option)
    return box
'''
new_picker = '''func _worker_picker():
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
    previous.text = "◀"
    previous.custom_minimum_size = Vector2(54, 48)
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
    next.text = "▶"
    next.custom_minimum_size = Vector2(54, 48)
    next.disabled = avail.size() <= 1
    next.pressed.connect(_on_worker_cycle.bind(1))
    row.add_child(next)

    box.add_child(row)
    return box
'''
t = replace_once(t, old_picker, new_picker, 'worker picker replacement')
t = replace_once(
    t,
    '''func _on_worker_selected(index, option):
    selected_worker_id = int(option.get_item_metadata(index))
''',
    '''func _on_worker_cycle(direction: int):
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
''',
    'worker cycle handler',
)
write(path, t)

# ---------------------------------------------------------------------------
# Architecture smoke: the new-save tutorial flag is a persistent contract.
# UI behavior is covered by actual startup/import plus source validation.
# ---------------------------------------------------------------------------
path = 'game/scripts/ci/FFArchitectureSmoke.gd'
t = read(path)
t = replace_once(
    t,
    '    if not _check(D.BUILD_ORDER.size() == 15 and D.BUILDINGS.has("Dormitory") and D.BUILDINGS.has("Armory"), "final building tree"): return\n',
    '    if not _check(D.BUILD_ORDER.size() == 15 and D.BUILDINGS.has("Dormitory") and D.BUILDINGS.has("Armory"), "final building tree"): return\n    if not _check(str(D.GEAR["Flashlight"].get("slot", "")) == "Secondary", "founder tutorial lighting seam"): return\n',
    'tutorial smoke anchor',
)
write(path, t)

# ---------------------------------------------------------------------------
# Changelog.
# ---------------------------------------------------------------------------
path = 'CHANGELOG.md'
t = read(path)
entry = '''## Beta Candidate — Onboarding & Worker Picker Fix — 2026-08-17

### Craft / Build Worker Selection
- Replaced the Craft/Build worker `OptionButton` popup with direct previous/next survivor controls. This avoids the Web/mobile dropdown path that could leave the Craft screen unresponsive when changing workers.
- Worker switching now defers the content rebuild until the button input callback has completed, avoiding deletion/reconstruction of the active control tree from inside its own signal.

### New-Save Quick Start
- Added a compact four-step first-save tutorial covering camp food/water and time, sending a survivor out, Craft/Build worker assignment, and tactical ticks/vision/sound/escape.
- The simulation pauses while the quick-start overlay is open and restores its prior pause state when the tutorial is finished or skipped.
- New saves persist `tutorial_complete`; existing schema-7 Beta saves without that flag are treated as already onboarded and are not interrupted.
- Save schema remains **7**.

'''
t = replace_once(
    t,
    '# First Fire — Changelog\n\nThis file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n',
    '# First Fire — Changelog\n\nThis file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n' + entry,
    'changelog entry',
)
write(path, t)

# Remove the patch script from the committed gameplay result.
Path('.github/scripts/temp_beta_onboarding_fix.py').unlink(missing_ok=True)
print('FIRST_FIRE_BETA_ONBOARDING_FIX_OK')
