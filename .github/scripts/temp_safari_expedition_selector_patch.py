from pathlib import Path

ROOT = Path('.')


def read(path):
    return (ROOT / path).read_text()


def write(path, text):
    (ROOT / path).write_text(text)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'MISSING {label}')
    if text.count(old) != 1:
        raise SystemExit(f'NONUNIQUE {label}: {text.count(old)}')
    return text.replace(old, new, 1)

# Main UI: remove the popup OptionButton from SEND OUT and replace it with
# explicit touch-safe PREV/NEXT controls. The expedition overlay also becomes
# a true modal pause boundary.
path = 'game/scripts/Main.gd'
text = read(path)
text = replace_once(
    text,
    'var expedition_title: Label\nvar expedition_zone: OptionButton\nvar expedition_specials: VBoxContainer\n',
    'var expedition_title: Label\nvar expedition_zone_label: Label\nvar expedition_zone_detail: Label\nvar expedition_zone_names: Array = []\nvar expedition_zone_index := 0\nvar expedition_restore_paused := false\nvar expedition_specials: VBoxContainer\n',
    'expedition selector vars',
)
text = replace_once(
    text,
    '''    v.add_child(_make_label("Zone", 13))
    expedition_zone = OptionButton.new()
    expedition_zone.custom_minimum_size = Vector2(0, 44)
    v.add_child(expedition_zone)

''',
    '''    v.add_child(_make_label("Zone", 13))
    var zone_row = HBoxContainer.new()
    zone_row.add_theme_constant_override("separation", 6)
    v.add_child(zone_row)

    var zone_prev = Button.new()
    zone_prev.text = "PREV"
    zone_prev.custom_minimum_size = Vector2(72, 46)
    zone_prev.pressed.connect(_cycle_expedition_zone.bind(-1))
    zone_row.add_child(zone_prev)

    expedition_zone_label = _make_label("", 14)
    expedition_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    expedition_zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    expedition_zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    expedition_zone_label.custom_minimum_size = Vector2(170, 46)
    zone_row.add_child(expedition_zone_label)

    var zone_next = Button.new()
    zone_next.text = "NEXT"
    zone_next.custom_minimum_size = Vector2(72, 46)
    zone_next.pressed.connect(_cycle_expedition_zone.bind(1))
    zone_row.add_child(zone_next)

    expedition_zone_detail = _make_label("", 12)
    expedition_zone_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    expedition_zone_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(expedition_zone_detail)

''',
    'expedition selector controls',
)
text = replace_once(
    text,
    '    close.pressed.connect(func(): expedition_overlay.visible = false)\n',
    '    close.pressed.connect(_close_expedition_overlay)\n',
    'expedition cancel handler',
)
old_handlers = '''func _open_expedition_overlay():
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
'''
new_handlers = '''func _open_expedition_overlay():
    var s: Variant = Game.get_survivor(selected_survivor_id)
    if s == null or s["status"] != "Available":
        return
    if not expedition_overlay.visible:
        expedition_restore_paused = Game.sim_paused
    expedition_title.text = "SEND OUT — %s" % s["name"]
    expedition_zone_names.clear()
    for zone in D.ZONE_ORDER:
        if Game.unlocked_zones.has(zone):
            expedition_zone_names.append(str(zone))
    expedition_zone_index = 0
    _refresh_expedition_zone_ui()
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
    expedition_overlay.move_to_front()
    if not Game.sim_paused:
        Game.set_paused(true)

func _cycle_expedition_zone(direction: int) -> void:
    if expedition_zone_names.size() <= 1:
        return
    expedition_zone_index = posmod(expedition_zone_index + direction, expedition_zone_names.size())
    _refresh_expedition_zone_ui()

func _refresh_expedition_zone_ui() -> void:
    if expedition_zone_label == null or expedition_zone_detail == null:
        return
    if expedition_zone_names.is_empty():
        expedition_zone_label.text = "NO UNLOCKED ZONES"
        expedition_zone_detail.text = ""
        return
    expedition_zone_index = clampi(expedition_zone_index, 0, expedition_zone_names.size() - 1)
    var zone := str(expedition_zone_names[expedition_zone_index])
    var data: Dictionary = D.ZONES.get(zone, {})
    expedition_zone_label.text = zone
    expedition_zone_detail.text = "%.0fs | %s | Loot %s" % [float(data.get("duration", 0.0)), str(data.get("danger", "?")), Game.zone_loot_state(zone)]

func _close_expedition_overlay() -> void:
    if expedition_overlay == null:
        return
    expedition_overlay.visible = false
    if not Game.current_combat.is_empty():
        if not Game.sim_paused:
            Game.set_paused(true)
        return
    if Game.sim_paused != expedition_restore_paused:
        Game.set_paused(expedition_restore_paused)

func _on_expedition_send():
    if expedition_zone_names.is_empty():
        return
    expedition_zone_index = clampi(expedition_zone_index, 0, expedition_zone_names.size() - 1)
    var zone := str(expedition_zone_names[expedition_zone_index])
    if Game.start_expedition(selected_survivor_id, zone):
        _close_expedition_overlay()

func _on_special_site_pressed(site):
    if Game.start_special_site(selected_survivor_id, site):
        _close_expedition_overlay()
'''
text = replace_once(text, old_handlers, new_handlers, 'expedition handlers')
write(path, text)

# Regression guard: the mobile expedition picker must remain popup-free and
# keep an explicit modal close/restore path.
path = 'game/scripts/ci/FFArchitectureSmoke.gd'
text = read(path)
anchor = '    if not _check(MobileScroll.touch_scroll_value(50.0, 100.0, 0.0, 100.0, 20.0) == 40, "mobile scrollbar touch mapping"): return\n'
addition = anchor + '''    var main_source := FileAccess.get_file_as_string("res://scripts/Main.gd")
    if not _check(not main_source.contains("expedition_zone = OptionButton.new()"), "Safari expedition selector avoids popup OptionButton"): return
    if not _check(main_source.contains("func _close_expedition_overlay()"), "expedition overlay has modal pause restore"): return
'''
text = replace_once(text, anchor, addition, 'Safari expedition smoke checks')
write(path, text)

# Durable context note.
path = 'README_CONTEXT.md'
text = read(path)
anchor = '`FFExpeditionRules.gd` owns current travel duration, recruit protection, tactical-event mix, zone caps, and routine haul-count rules.\n\nExpeditions are permanently single-survivor. Multi-survivor dispatch, companion AI, and vehicle logistics are cut from scope.\n'
replacement = '`FFExpeditionRules.gd` owns current travel duration, recruit protection, tactical-event mix, zone caps, and routine haul-count rules.\n\nThe SEND OUT location chooser deliberately avoids Godot popup/OptionButton controls because mobile Safari can fail to accept selections from those Web popups. Zone selection uses explicit PREV/NEXT buttons, and the expedition-selection overlay pauses camp simulation until SEND or CANCEL restores the previous pause state.\n\nExpeditions are permanently single-survivor. Multi-survivor dispatch, companion AI, and vehicle logistics are cut from scope.\n'
text = replace_once(text, anchor, replacement, 'context Safari expedition picker')
write(path, text)

# Changelog.
path = 'CHANGELOG.md'
text = read(path)
entry = '''## Beta Candidate — Safari SEND OUT Selector Fix — 2026-09-11

- Replaced the SEND OUT zone `OptionButton` popup with explicit touch-safe PREV / NEXT controls and a visible selected-zone detail line.
- Opening SEND OUT now pauses camp simulation; SEND and CANCEL restore the pause state that existed before the modal opened.
- Special-site dispatch uses the same modal close/restore path.
- Added a deterministic architecture smoke guard so the expedition selector cannot silently regress back to a popup `OptionButton`.
- Save schema remains 7; this is UI/input behavior only.

'''
text = entry + text
write(path, text)

# Remove this one-shot patcher from the resulting gameplay commit.
patch_path = ROOT / '.github/scripts/temp_safari_expedition_selector_patch.py'
if patch_path.exists():
    patch_path.unlink()

print('FIRST_FIRE_SAFARI_EXPEDITION_SELECTOR_PATCH_OK')
