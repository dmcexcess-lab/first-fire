extends "res://scripts/FFInspectorThreeStat.gd"

const VirusRules = preload("res://scripts/FFVirusRules.gd")

func _render_survivor() -> void:
    super._render_survivor()
    var survivor: Variant = Game.get_survivor(current_survivor_id)
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead":
        return

    body.add_child(_separator())
    body.add_child(_heading("ZOMBIE VIRUS", 18))
    var virus: Dictionary = Game.virus_state(survivor)
    var stage := str(virus.get("stage", VirusRules.STAGE_CLEAR))
    var quarantine_note := "  •  QUARANTINED" if bool(virus.get("quarantined", false)) else ""
    body.add_child(_make_label("Status: %s%s" % [stage.to_upper(), quarantine_note], 14))

    if stage == VirusRules.STAGE_CLEAR:
        body.add_child(_make_label("No current zombie-virus exposure detected.", 11))
        return

    body.add_child(_make_label("Direct infected contact can establish the virus independently of physical wounds. Quarantine prevents close-contact spread inside camp but makes this survivor unavailable.", 11))
    var task: Dictionary = survivor.get("task", {})
    if str(task.get("kind", "")) == "virus_treatment":
        body.add_child(_make_label("Treatment underway — %.0fs of camp time remaining. Close this inspector to let camp time advance." % float(task.get("remaining", 0.0)), 12))
        return

    var plan: Dictionary = VirusRules.treatment_plan(stage, bool(Game.buildings.get("Infirmary", false)))
    if stage == VirusRules.STAGE_EXPOSED:
        body.add_child(_make_label("Options: decontaminate now, quarantine and observe, or risk waiting. Untreated exposure has one 30% natural-clear chance before infection establishes.", 11))
    elif stage == VirusRules.STAGE_INFECTED:
        body.add_child(_make_label("The infection is established. Medicine can still clear it; otherwise it progresses to severe fever at the next daily transition.", 11))
    else:
        body.add_child(_make_label("Severe fever is the final treatable stage. Without emergency care, the next untreated daily transition can be fatal.", 11))
    body.add_child(_make_label("Treatment requirement: %s" % str(plan.get("summary", "None")), 12))
    if not bool(plan.get("available", false)) and str(plan.get("reason", "")) != "":
        body.add_child(_make_label(str(plan.get("reason", "")), 11))

    var actions := HBoxContainer.new()
    var treat := Button.new()
    treat.text = "DECONTAMINATE" if stage == VirusRules.STAGE_EXPOSED else ("EMERGENCY CARE" if stage == VirusRules.STAGE_FEVERISH else "TREAT VIRUS")
    treat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    treat.custom_minimum_size = Vector2(0, 46)
    treat.disabled = str(survivor.get("status", "")) not in ["Available", "Quarantined", "Sick"] or not survivor.get("task", {}).is_empty() or not bool(plan.get("available", false))
    treat.pressed.connect(_treat_virus)
    actions.add_child(treat)

    var quarantine := Button.new()
    quarantine.text = "QUARANTINE"
    quarantine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quarantine.custom_minimum_size = Vector2(0, 46)
    quarantine.disabled = bool(virus.get("quarantined", false)) or str(survivor.get("status", "")) not in ["Available", "Sick"] or not survivor.get("task", {}).is_empty()
    quarantine.pressed.connect(_quarantine_virus)
    actions.add_child(quarantine)
    body.add_child(actions)

func _treat_virus() -> void:
    if Game.start_virus_treatment(current_survivor_id):
        _render_survivor()

func _quarantine_virus() -> void:
    if Game.quarantine_survivor(current_survivor_id):
        _render_survivor()

func _render_item() -> void:
    if current_item not in ["Medicine", "Sterile Dressing"]:
        super._render_item()
        return
    _clear_body()
    title_label.text = current_item.to_upper()
    var back := Button.new()
    back.text = "← BACK TO %s" % ("SURVIVOR" if item_return_mode == "survivor" else "CAMP INVENTORY")
    back.custom_minimum_size = Vector2(0, 44)
    back.pressed.connect(_back_from_item)
    body.add_child(back)
    body.add_child(_make_label("Owned in camp: %d" % _owned_count(current_item), 13))
    if current_item == "Medicine":
        body.add_child(_make_label("High-grade medical supplies used for Critical trauma stabilization and established zombie-virus treatment. Feverish virus cases require two Medicine in a built Infirmary.", 15))
    else:
        body.add_child(_make_label("Clean wound-care material used for Hurt/Wounded physical injuries and, together with Clean Water, early zombie-virus exposure decontamination.", 15))
