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
    var quarantined := bool(virus.get("quarantined", false))
    var quarantine_note := "  •  QUARANTINED / FORCED REST" if quarantined else ""
    body.add_child(_make_label("Status: %s%s" % [stage.to_upper(), quarantine_note], 14))

    if bool(survivor.get("amputation_used", false)):
        body.add_child(_make_label("Emergency amputation already used. It already applied its one-time Combat −1 and Agility −1 hit.", 11))

    if stage == VirusRules.STAGE_CLEAR:
        body.add_child(_make_label("No current zombie-virus exposure detected.", 11))
        return

    var days_left := VirusRules.days_until_turn(virus)
    body.add_child(_make_label("Turn clock: about %d daily transition%s remaining." % [days_left, "" if days_left == 1 else "s"], 12))
    body.add_child(_make_label("Zombie-virus infection does not spread between camp survivors. The danger is entirely this survivor's personal clock.", 11))

    if quarantined:
        body.add_child(_make_label("Quarantine incapacitates this survivor in forced rest and slows the turn clock to 3–4 days from when quarantine began. They remain unavailable until cured or dead.", 11))
    else:
        body.add_child(_make_label("Unquarantined infection turns in only 1–2 days. Quarantine buys time to find a Zombie Cure.", 11))

    var can_amputate := VirusRules.can_amputate(virus, bool(survivor.get("amputation_used", false)))
    if can_amputate:
        body.add_child(_make_label("EARLY CHOICE: amputate now with 1 First Aid Kit, permanently lose 1 Combat and 1 Agility, then endure 8 in-game hours of forced recovery — or keep the limb and hunt for a Zombie Cure.", 11))
        var amputate := Button.new()
        amputate.text = "AMPUTATE NOW"
        amputate.custom_minimum_size = Vector2(0, 46)
        amputate.disabled = str(survivor.get("status", "")) != "Available" or not survivor.get("task", {}).is_empty() or int(Game.components.get("First Aid Kit", 0)) <= 0
        amputate.pressed.connect(_amputate_virus)
        body.add_child(amputate)
    elif stage == VirusRules.STAGE_EXPOSED:
        body.add_child(_make_label("The amputation window is closed. The remaining choices are quarantine and/or finding a Zombie Cure.", 11))

    var actions := HBoxContainer.new()

    var cure := Button.new()
    cure.text = "USE ZOMBIE CURE"
    cure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cure.custom_minimum_size = Vector2(0, 46)
    cure.disabled = int(Game.components.get("Zombie Cure", 0)) <= 0 or str(survivor.get("status", "")) not in ["Available", "Quarantined", "Sick"] or not survivor.get("task", {}).is_empty()
    cure.pressed.connect(_cure_virus)
    actions.add_child(cure)

    var quarantine := Button.new()
    quarantine.text = "QUARANTINE"
    quarantine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quarantine.custom_minimum_size = Vector2(0, 46)
    quarantine.disabled = quarantined or str(survivor.get("status", "")) not in ["Available", "Sick"] or not survivor.get("task", {}).is_empty()
    quarantine.pressed.connect(_quarantine_virus)
    actions.add_child(quarantine)

    body.add_child(actions)

func _amputate_virus() -> void:
    if Game.start_amputation(current_survivor_id):
        _render_survivor()

func _cure_virus() -> void:
    if Game.use_zombie_cure(current_survivor_id):
        _render_survivor()

func _quarantine_virus() -> void:
    if Game.quarantine_survivor(current_survivor_id):
        _render_survivor()

func _render_item() -> void:
    if current_item not in ["Bandage", "First Aid Kit", "Zombie Cure"]:
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
    if current_item == "Bandage":
        body.add_child(_make_label("Craftable wound-care material made at the First Fire from Cloth + Clean Water. Used for ordinary Hurt/Wounded physical injuries; it no longer treats zombie-virus exposure.", 15))
    elif current_item == "First Aid Kit":
        body.add_child(_make_label("Rare, found-only emergency medical supply. Critical physical trauma consumes one. A survivor in the immediate Exposed window can also spend one on a one-time emergency amputation.", 15))
    else:
        body.add_child(_make_label("The rarest direct medical find. A built Infirmary can craft one from 2 recovered Zombie Corpses. Using one immediately clears any active zombie-virus stage; no Infirmary is required to administer it.", 15))
