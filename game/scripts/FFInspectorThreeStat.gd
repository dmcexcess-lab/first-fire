extends "res://scripts/FFInspector.gd"

const ThreeStatRules = preload("res://scripts/FFThreeStatRules.gd")

func _render_survivor() -> void:
    _clear_body()
    var survivor: Variant = Game.get_survivor(current_survivor_id)
    if survivor == null:
        title_label.text = "SURVIVOR"
        body.add_child(_make_label("This survivor is no longer available.", 14))
        return
    title_label.text = str(survivor.get("name", "SURVIVOR")).to_upper()
    var condition := str(survivor.get("condition", "Healthy"))
    var status := str(survivor.get("status", "Available"))
    body.add_child(_make_label("%s  •  %s  •  %s" % [str(survivor.get("background", "Unknown")), condition, status], 14))
    body.add_child(_make_label("Traits: %s" % ", ".join(survivor.get("traits", [])), 13))
    body.add_child(_make_label("Fatigue %.0f / 100  •  Stress %.0f / 100" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 14))
    var treatment_status := _treatment_status_line(survivor)
    if treatment_status != "": body.add_child(_make_label(treatment_status, 12))

    body.add_child(_separator())
    body.add_child(_heading("STATS", 18))
    var stats: Dictionary = ThreeStatRules.normalize_stats(survivor.get("skills", {}))
    var xp: Dictionary = survivor.get("skill_xp", {})
    for stat in ThreeStatRules.STAT_NAMES:
        var rank := int(stats.get(stat, 0))
        var threshold := 20 + rank * 15
        body.add_child(_make_label("%s  %d  •  %d/%d XP" % [stat, rank, int(xp.get(stat, 0)), threshold], 14))
    body.add_child(_make_label("Combat: weapon handling and damage.  Agility: movement, stealth, sprint, avoidance.  Leadership: camp influence and social decisions.", 11))

    body.add_child(_separator())
    body.add_child(_heading("LOADOUT", 18))
    var equipment: Dictionary = survivor.get("equipment", {})
    for slot in ["Weapon", "Secondary", "Tool", "Clothing", "Pack"]:
        var gear_name := str(equipment.get(slot, ""))
        if gear_name == "":
            body.add_child(_make_label("%s: None" % slot, 13))
        else:
            var label := "%s: %s" % [slot, gear_name]
            if slot == "Weapon": label += "  •  %s" % str(ThreeStatRules.weapon_class(gear_name).get("label", ""))
            var equipped = Button.new()
            equipped.text = label + "  •  INFO"
            equipped.alignment = HORIZONTAL_ALIGNMENT_LEFT
            equipped.custom_minimum_size = Vector2(0, 42)
            equipped.pressed.connect(_open_item.bind(gear_name, "survivor"))
            body.add_child(equipped)

    if not Game.inventory_gear.is_empty() and condition != "Dead":
        body.add_child(_make_label("Camp gear available", 13))
        var counts := _gear_counts()
        for gear_name in counts.keys():
            var row = HBoxContainer.new()
            var info = Button.new()
            info.text = "%s ×%d" % [str(gear_name), int(counts[gear_name])]
            info.alignment = HORIZONTAL_ALIGNMENT_LEFT
            info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            info.custom_minimum_size = Vector2(0, 42)
            info.pressed.connect(_open_item.bind(str(gear_name), "survivor"))
            row.add_child(info)
            var equip = Button.new()
            equip.text = "EQUIP"
            equip.custom_minimum_size = Vector2(82, 42)
            equip.disabled = status != "Available"
            equip.pressed.connect(_equip_gear.bind(str(gear_name)))
            row.add_child(equip)
            body.add_child(row)

    body.add_child(_separator())
    body.add_child(_heading("ACTIONS", 18))
    if condition == "Dead":
        body.add_child(_make_label("No actions available.", 13))
    else:
        if condition == "Hurt": body.add_child(_make_label("Treatment: 1 Sterile Dressing. Cuts minor-injury recovery to at most 30s.", 11))
        elif condition == "Wounded": body.add_child(_make_label("Treatment: 1 Sterile Dressing. Starts timed wound recovery.", 11))
        elif condition == "Critical": body.add_child(_make_label("Treatment: 1 Medicine. Stabilizes the critical injury into a wound.", 11))
        var actions = HBoxContainer.new()
        var treat = Button.new()
        treat.text = "TREAT"; treat.size_flags_horizontal = Control.SIZE_EXPAND_FILL; treat.custom_minimum_size = Vector2(0, 46)
        treat.disabled = condition == "Healthy" or status != "Available"
        treat.pressed.connect(_treat_survivor); actions.add_child(treat)
        var send = Button.new()
        send.text = "SEND OUT"; send.size_flags_horizontal = Control.SIZE_EXPAND_FILL; send.custom_minimum_size = Vector2(0, 46)
        send.disabled = status != "Available"; send.pressed.connect(_handoff_send); actions.add_child(send)
        body.add_child(actions)

    body.add_child(_separator())
    body.add_child(_heading("RELATIONSHIPS", 18))
    var any_relationship := false
    var relationships: Dictionary = survivor.get("relationships", {})
    for other in Game.survivors:
        if int(other.get("id", -1)) == current_survivor_id or str(other.get("condition", "Healthy")) == "Dead": continue
        var relation_value := int(relationships.get(str(other.get("id", -1)), 0))
        body.add_child(_make_label("%s — %s (%d)" % [str(other.get("name", "Survivor")), Game.relationship_label(relation_value), relation_value], 13))
        any_relationship = true
    if not any_relationship: body.add_child(_make_label("No active relationships yet.", 13))

    body.add_child(_separator())
    body.add_child(_heading("HISTORY", 18))
    var survivor_history: Array = survivor.get("history", [])
    var start := maxi(0, survivor_history.size() - 12)
    for index in range(survivor_history.size() - 1, start - 1, -1):
        body.add_child(_make_label(str(survivor_history[index]), 12))

func _render_item() -> void:
    _clear_body()
    title_label.text = current_item.to_upper()
    var back = Button.new()
    back.text = "← BACK TO %s" % ("SURVIVOR" if item_return_mode == "survivor" else "CAMP INVENTORY")
    back.custom_minimum_size = Vector2(0, 44)
    back.pressed.connect(_back_from_item)
    body.add_child(back)
    body.add_child(_make_label("Owned in camp: %d" % _owned_count(current_item), 13))
    var description := str(ITEM_DESCRIPTIONS.get(current_item, "No field notes have been written for this item yet."))
    if current_item in ["Work Gloves", "Heavy Boots", "Leather Jacket", "Work Jacket", "Padded Jacket"]:
        description = "Wearable field clothing. Clothing has no armor or damage-reduction value in the current combat system."
    body.add_child(_make_label(description, 15))
    if D.GEAR.has(current_item):
        var data: Dictionary = D.GEAR[current_item]
        body.add_child(_separator())
        body.add_child(_heading("GEAR DATA", 18))
        body.add_child(_make_label("Slot: %s" % str(data.get("slot", "Unknown")), 13))
        if str(data.get("slot", "")) == "Weapon":
            var wc := ThreeStatRules.weapon_class(current_item)
            body.add_child(_make_label("Combat class: %s" % str(wc.get("label", "1H MELEE")), 13))
        if data.has("capacity"): body.add_child(_make_label("Carry capacity: %d" % int(data.get("capacity", 0)), 13))
        if data.has("ammo"): body.add_child(_make_label("Ammo per shot: %d" % int(data.get("ammo", 0)), 13))
        if data.has("tool"): body.add_child(_make_label("Tool tag: %s" % str(data.get("tool", "")), 13))
        if data.has("light"): body.add_child(_make_label("Light reach: %.0f tiles" % float(data.get("light_range", 0.0)), 13))
        if data.has("weight"): body.add_child(_make_label("Carried weight: %.1f" % float(data.get("weight", 0.0)), 13))
        body.add_child(_make_label("Inventory size: %d" % int(data.get("size", 0)), 13))
