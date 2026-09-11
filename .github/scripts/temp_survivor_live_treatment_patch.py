from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'missing expected block in {path}: {old[:120]!r}')
    if text.count(old) != 1:
        raise SystemExit(f'expected exactly one block in {path}, found {text.count(old)}')
    p.write_text(text.replace(old, new, 1))

# Live survivor roster values without rebuilding the control tree.
p = Path('game/scripts/FFSurvivorPanel.gd')
text = p.read_text()
text = text.replace(
'''signal inspect_survivor(survivor_id: int)\nsignal inspect_inventory\nsignal send_survivor(survivor_id: int)\n\nfunc _ready() -> void:\n    size_flags_horizontal = Control.SIZE_EXPAND_FILL\n    add_theme_constant_override("separation", 8)\n    _build()\n''',
'''signal inspect_survivor(survivor_id: int)\nsignal inspect_inventory\nsignal send_survivor(survivor_id: int)\n\nvar condition_labels: Dictionary = {}\nvar activity_labels: Dictionary = {}\nvar vitals_labels: Dictionary = {}\nvar send_buttons: Dictionary = {}\nvar expedition_state_labels: Dictionary = {}\n\nfunc _ready() -> void:\n    size_flags_horizontal = Control.SIZE_EXPAND_FILL\n    add_theme_constant_override("separation", 8)\n    Game.tick.connect(_refresh_live_values)\n    _build()\n\nfunc _clear_live_refs() -> void:\n    condition_labels.clear()\n    activity_labels.clear()\n    vitals_labels.clear()\n    send_buttons.clear()\n    expedition_state_labels.clear()\n''')
text = text.replace(
'''func _build() -> void:\n    add_child(_tab_art())\n''',
'''func _build() -> void:\n    _clear_live_refs()\n    add_child(_tab_art())\n''')
text = text.replace(
'''    var state_text: String = "OUT • %s" % zone\n    if state == "traveling":\n        state_text += " • %.0fs remaining" % float(expedition.get("remaining", 0.0))\n    elif state == "pending":\n        state_text += " • DECISION WAITING"\n    elif state == "combat":\n        state_text += " • TACTICAL ENCOUNTER"\n    box.add_child(_make_label(state_text, 13))\n    return panel\n''',
'''    var state_label = _make_label(_expedition_state_text(expedition), 13)\n    box.add_child(state_label)\n    expedition_state_labels[int(expedition.get("id", -1))] = state_label\n    return panel\n\nfunc _expedition_state_text(expedition: Dictionary) -> String:\n    var zone: String = str(expedition.get("zone", "Unknown"))\n    var state: String = str(expedition.get("state", "traveling"))\n    var state_text: String = "OUT • %s" % zone\n    if state == "traveling":\n        state_text += " • %.0fs remaining" % float(expedition.get("remaining", 0.0))\n    elif state == "pending":\n        state_text += " • DECISION WAITING"\n    elif state == "combat":\n        state_text += " • TACTICAL ENCOUNTER"\n    return state_text\n''')
text = text.replace(
'''    var condition_label = _make_label(condition.to_upper(), 11)\n    condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT\n    title_row.add_child(condition_label)\n    box.add_child(title_row)\n\n    var activity: String = _activity_text(survivor)\n    if _is_away_status(status):\n        activity = "OUT • " + activity\n    box.add_child(_make_label(activity, 13))\n    box.add_child(_make_label("Fatigue %.0f  •  Stress %.0f" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 12))\n''',
'''    var condition_label = _make_label(condition.to_upper(), 11)\n    condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT\n    title_row.add_child(condition_label)\n    condition_labels[sid] = condition_label\n    box.add_child(title_row)\n\n    var activity: String = _activity_text(survivor)\n    if _is_away_status(status):\n        activity = "OUT • " + activity\n    var activity_label = _make_label(activity, 13)\n    box.add_child(activity_label)\n    activity_labels[sid] = activity_label\n    var vitals_label = _make_label("Fatigue %.0f  •  Stress %.0f" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 12)\n    box.add_child(vitals_label)\n    vitals_labels[sid] = vitals_label\n''')
text = text.replace(
'''        send.disabled = status != "Available"\n        send.pressed.connect(func(): send_survivor.emit(sid))\n        actions.add_child(send)\n''',
'''        send.disabled = status != "Available"\n        send.pressed.connect(func(): send_survivor.emit(sid))\n        actions.add_child(send)\n        send_buttons[sid] = send\n''')
anchor = '''func _recent_returns(limit: int) -> Array:\n'''
live_fn = '''func _refresh_live_values() -> void:\n    if not is_inside_tree():\n        return\n    for survivor in Game.survivors:\n        var sid: int = int(survivor.get("id", -1))\n        var condition: String = str(survivor.get("condition", "Healthy"))\n        var status: String = str(survivor.get("status", "Available"))\n        if condition_labels.has(sid) and is_instance_valid(condition_labels[sid]):\n            condition_labels[sid].text = condition.to_upper()\n        if activity_labels.has(sid) and is_instance_valid(activity_labels[sid]):\n            var activity: String = _activity_text(survivor)\n            if _is_away_status(status):\n                activity = "OUT • " + activity\n            activity_labels[sid].text = activity\n        if vitals_labels.has(sid) and is_instance_valid(vitals_labels[sid]):\n            vitals_labels[sid].text = "Fatigue %.0f  •  Stress %.0f" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))]\n        if send_buttons.has(sid) and is_instance_valid(send_buttons[sid]):\n            send_buttons[sid].disabled = condition == "Dead" or status != "Available"\n    for expedition in Game.expeditions:\n        var expedition_id: int = int(expedition.get("id", -1))\n        if expedition_state_labels.has(expedition_id) and is_instance_valid(expedition_state_labels[expedition_id]):\n            expedition_state_labels[expedition_id].text = _expedition_state_text(expedition)\n\n'''
if anchor not in text:
    raise SystemExit('missing recent returns anchor')
text = text.replace(anchor, live_fn + anchor, 1)
p.write_text(text)

# Make treatment effects visible in the inspector.
p = Path('game/scripts/FFInspector.gd')
text = p.read_text()
text = text.replace(
'''    body.add_child(_make_label("Fatigue %.0f / 100  •  Stress %.0f / 100" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 14))\n    body.add_child(_make_label("Expeditions completed: %d" % int(survivor.get("expeditions_done", 0)), 12))\n''',
'''    body.add_child(_make_label("Fatigue %.0f / 100  •  Stress %.0f / 100" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 14))\n    var treatment_status: String = _treatment_status_line(survivor)\n    if treatment_status != "":\n        body.add_child(_make_label(treatment_status, 12))\n    body.add_child(_make_label("Expeditions completed: %d" % int(survivor.get("expeditions_done", 0)), 12))\n''')
text = text.replace(
'''        var treat = Button.new()\n        treat.text = "TREAT"\n        treat.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n''',
'''        if condition == "Hurt":\n            body.add_child(_make_label("Treatment: 1 Sterile Dressing. Cuts minor-injury recovery to at most 30s.", 11))\n        elif condition == "Wounded" or condition == "Critical":\n            body.add_child(_make_label("Treatment: 1 Medicine. Starts timed recovery; close this inspector to let camp time advance.", 11))\n        var treat = Button.new()\n        treat.text = "TREAT"\n        treat.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n''')
text = text.replace(
'''func _treat_survivor() -> void:\n    Game.treat_survivor(current_survivor_id)\n    _render_survivor()\n\nfunc _gear_counts() -> Dictionary:\n''',
'''func _treat_survivor() -> void:\n    if Game.treat_survivor(current_survivor_id):\n        _render_survivor()\n\nfunc _treatment_status_line(survivor) -> String:\n    var condition: String = str(survivor.get("condition", "Healthy"))\n    if condition == "Healthy" or condition == "Dead":\n        return ""\n    var status: String = str(survivor.get("status", "Available"))\n    var task: Dictionary = survivor.get("task", {})\n    if status == "Recovering" and str(task.get("kind", "")) == "treatment":\n        return "Treatment underway — %.0fs remaining. Camp time is paused while this inspector is open." % float(task.get("remaining", 0.0))\n    if condition == "Critical":\n        return "Critical injury — active treatment is required before condition can improve."\n    var remaining: float = float(survivor.get("injury_remaining", 0.0))\n    if remaining > 0.0:\n        return "Injury recovery — about %.0fs remaining while camp time runs." % remaining\n    return "Injured — treatment/recovery state pending."\n\nfunc _gear_counts() -> Dictionary:\n''')
p.write_text(text)

# Treatment already worked; add explicit success feedback/history in the simulation owner.
p = Path('game/scripts/Game.gd')
text = p.read_text()
text = text.replace(
'''        components["Sterile Dressing"] -= 1\n        s["injury_remaining"] = min(float(s["injury_remaining"]), 30.0)\n        s["status"] = "Available"\n    else:\n''',
'''        components["Sterile Dressing"] -= 1\n        s["injury_remaining"] = min(float(s["injury_remaining"]), 30.0)\n        s["status"] = "Available"\n        s["history"].append("Day %d — Treated a minor injury with a Sterile Dressing." % day)\n        toast_requested.emit("%s treated — Sterile Dressing applied; about %.0fs recovery remains." % [s["name"], float(s["injury_remaining"])])\n    else:\n''')
text = text.replace(
'''        var treatment_time: float = base * (1.0 - reduction) * CampLifeRules.treatment_time_multiplier(bool(buildings.get("Infirmary", false)))\n        s["task"] = {"kind": "treatment", "remaining": treatment_time, "duration": base, "target": sid}\n    save_game()\n''',
'''        var treatment_time: float = base * (1.0 - reduction) * CampLifeRules.treatment_time_multiplier(bool(buildings.get("Infirmary", false)))\n        s["task"] = {"kind": "treatment", "remaining": treatment_time, "duration": base, "target": sid}\n        s["history"].append("Day %d — Began treatment for %s injuries." % [day, s["condition"].to_lower()])\n        toast_requested.emit("%s is being treated — about %.0fs of camp time." % [s["name"], treatment_time])\n    save_game()\n''')
p.write_text(text)

# Durable context and changelog.
p = Path('README_CONTEXT.md')
text = p.read_text()
needle = '''`FFCampLifeRules.gd` owns camp-life cadence/recovery tuning.\n\n`FFCampSocial.gd` owns relationship/social-selection rules, political standing, and autonomous camp chatter.'''
replacement = '''`FFCampLifeRules.gd` owns camp-life cadence/recovery tuning. The SURVIVORS roster now updates fatigue, stress, condition, activity and expedition countdowns in place on the regular simulation tick, without rebuilding the menu or requiring a tab change. Treatment remains simulation-owned: Hurt consumes a Sterile Dressing and caps minor-injury recovery at 30 seconds; Wounded/Critical consumes Medicine and begins a timed recovery task. The survivor inspector explains the requirement/result and reminds the player that its modal pause stops treatment time until closed.\n\n`FFCampSocial.gd` owns relationship/social-selection rules, political standing, and autonomous camp chatter.'''
if needle not in text:
    raise SystemExit('context treatment anchor missing')
p.write_text(text.replace(needle, replacement, 1))

p = Path('CHANGELOG.md')
text = p.read_text()
entry = '''## Beta Candidate — Live Survivor Vitals & Treatment Feedback — 2026-09-11\n\n- Survivor roster cards now update fatigue, stress, condition, activity/recovery state, expedition countdowns, and SEND OUT availability in place on the normal simulation tick; switching tabs is no longer required to see values change.\n- Confirmed the existing TREAT simulation path was functional: Hurt consumes a Sterile Dressing and caps recovery at 30 seconds; Wounded/Critical consumes Medicine and starts a timed recovery task.\n- Treatment now gives explicit success toasts/history instead of silently mutating hidden recovery state.\n- Survivor inspection now shows injury/treatment time remaining and the treatment resource requirement, including the fact that the inspector pauses camp time while open.\n- Save schema remains 7.\n\n'''
if 'Live Survivor Vitals & Treatment Feedback' not in text:
    text = entry + text
p.write_text(text)

# Self-clean patch payload; workflow is removed through connector after it commits.
Path('.github/scripts/temp_survivor_live_treatment_patch.py').unlink()
print('FIRST_FIRE_SURVIVOR_LIVE_TREATMENT_PATCH_OK')
