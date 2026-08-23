extends ColorRect
class_name FFInspector

const D = preload("res://scripts/FFData.gd")
const MobileScroll = preload("res://scripts/FFMobileScroll.gd")

signal send_survivor(survivor_id: int)

const ITEM_DESCRIPTIONS := {
    "Raw Food": "Unprepared food. Cook it at the Fire Pit to turn one unit into two Cooked Food.",
    "Cooked Food": "Ready-to-eat camp food. This is what the settlement consumes during daily upkeep.",
    "Dirty Water": "Unsafe water gathered in the field. Boil it at the Fire Pit to turn one unit into two Clean Water.",
    "Clean Water": "Safe drinking water used by the camp and by some medical crafting.",
    "Wood": "Common construction and crafting stock used for shelters, tools, workstations, and structural components.",
    "Scrap Metal": "Recovered metal stock used in tools, weapons, workstations, and stronger construction.",
    "Cloth": "Fabric salvage used for clothing, shelter work, medical supplies, packs, and weatherproofing.",
    "Plastic": "Light salvage used in packs, weather protection, and improvised construction.",
    "Hardware": "Fasteners, fittings, hinges, and other small mechanical parts. Frequently required for useful infrastructure.",
    "Medicine": "General medical supplies used to improve treatment and keep badly injured survivors alive.",
    "Ammo": "Shared firearm ammunition. Tactical gunfire consumes this camp supply directly.",
    "Seeds": "Planting stock used to establish and support food-growing infrastructure.",
    "Sterile Dressing": "A clean wound-care component made from Cloth and Clean Water.",
    "Framing Kit": "Prepared structural hardware and timber used in major shelter construction.",
    "Pack Frame": "A rigid pack component used to build higher-capacity carrying gear.",
    "Weatherproofing Roll": "Prepared cloth and plastic used to seal major structures against weather.",
    "Utility Knife": "Compact cutting tool that doubles as a basic melee weapon.",
    "Kitchen Knife": "A common kitchen blade pressed into service as a basic melee weapon.",
    "Wooden Club": "Simple blunt weapon. Cheap, dependable, and better than fighting empty-handed.",
    "Baseball Bat": "A sturdy two-handed improvised melee weapon with good reach and impact.",
    "Hammer": "Compact blunt weapon that also functions as a useful hammering tool.",
    "Improvised Spear": "Long improvised melee weapon built from wood and metal.",
    "Crowbar": "Heavy pry bar useful both in a fight and for breaching obstacles.",
    "Hatchet": "Compact chopping weapon with stronger melee performance than basic improvised tools.",
    "Pistol": "Compact firearm. Strong combat value but consumes shared Ammo when fired tactically.",
    "Shotgun": "Powerful close-range firearm with high combat value and heavier ammunition use.",
    "Flashlight": "Focused handheld beam with the longest Secondary reach. Strong at cutting a path through darkness, but narrow enough that facing matters.",
    "Headlamp": "Shorter, wider directional light. Easier to keep useful while moving and turning, but it does not reach as far as a flashlight.",
    "Lantern": "Warm radial light that illuminates the survivor in every direction. Excellent for rooms, but it also makes the carrier easy to see.",
    "Glow Stick": "Compact green radial marker light. Weak and short-ranged, but light enough to carry when a full lamp is unnecessary.",
    "Road Flare": "Bright red radial field light. Strong local illumination with no directional blind side.",
    "Screwdriver Set": "Compact technical toolkit that improves Technical capability.",
    "Bolt Cutters": "Specialized cutting tool for chains, wire, and similar physical barriers.",
    "Toolbox": "General-purpose field toolkit that improves Technical capability.",
    "First Aid Kit": "Portable medical kit that improves Medical capability in the field.",
    "Pry Tool": "Compact breaching tool made for forcing open stubborn barriers.",
    "Work Gloves": "Basic protective workwear for hands-on camp and field activity.",
    "Heavy Boots": "Durable protective footwear suited to debris, rough ground, and hard travel.",
    "Leather Jacket": "Heavy clothing that provides meaningful protection against injury.",
    "Work Jacket": "Durable workwear that provides light protection.",
    "Padded Jacket": "Improvised protective clothing assembled from salvaged materials.",
    "Worn Backpack": "Small battered pack that increases how much a survivor can carry.",
    "School Backpack": "Common backpack with better capacity than a minimal field bag.",
    "Improvised Pack": "Camp-made carrying gear with useful early expedition capacity.",
    "Hiking Pack": "Large purpose-built pack with strong carrying capacity.",
    "Reinforced Pack": "Camp-built high-capacity pack strengthened around a rigid frame."
}

var previous_pause_state: bool = true
var mode: String = ""
var current_survivor_id: int = -1
var current_item: String = ""
var item_return_mode: String = "inventory"

var title_label: Label
var close_button: Button
var scroll: ScrollContainer
var body: VBoxContainer

func _ready() -> void:
    color = Color(0, 0, 0, 0.92)
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    _build_shell()

func _build_shell() -> void:
    var outer = MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left", 10)
    outer.add_theme_constant_override("margin_right", 10)
    outer.add_theme_constant_override("margin_top", 10)
    outer.add_theme_constant_override("margin_bottom", 10)
    add_child(outer)

    var panel = PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    outer.add_child(panel)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(margin)

    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 8)
    margin.add_child(root)

    var header = HBoxContainer.new()
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label = _make_label("INSPECT", 22)
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_label)
    close_button = Button.new()
    close_button.text = "CLOSE"
    close_button.custom_minimum_size = Vector2(88, 44)
    close_button.pressed.connect(_close_and_restore)
    header.add_child(close_button)
    root.add_child(header)

    scroll = ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    MobileScroll.configure(scroll)
    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 7)
    scroll.add_child(body)
    root.add_child(scroll)

func open_survivor(survivor_id: int) -> void:
    current_survivor_id = survivor_id
    mode = "survivor"
    _pause_for_inspection()
    _render_survivor()
    visible = true
    move_to_front()

func open_inventory() -> void:
    mode = "inventory"
    current_item = ""
    _pause_for_inspection()
    _render_inventory()
    visible = true
    move_to_front()

func force_close() -> void:
    visible = false
    mode = ""
    current_item = ""

func _pause_for_inspection() -> void:
    if not visible:
        previous_pause_state = Game.sim_paused
    if not Game.sim_paused:
        Game.set_paused(true)

func _close_and_restore() -> void:
    visible = false
    mode = ""
    current_item = ""
    if not Game.current_combat.is_empty():
        if not Game.sim_paused:
            Game.set_paused(true)
        return
    if Game.sim_paused != previous_pause_state:
        Game.set_paused(previous_pause_state)

func _handoff_send() -> void:
    var survivor_id: int = current_survivor_id
    visible = false
    mode = ""
    current_item = ""
    if Game.sim_paused != previous_pause_state:
        Game.set_paused(previous_pause_state)
    send_survivor.emit(survivor_id)

func _clear_body() -> void:
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()
    scroll.scroll_vertical = 0

func _render_survivor() -> void:
    _clear_body()
    var survivor: Variant = Game.get_survivor(current_survivor_id)
    if survivor == null:
        title_label.text = "SURVIVOR"
        body.add_child(_make_label("This survivor is no longer available.", 14))
        return

    title_label.text = str(survivor.get("name", "SURVIVOR")).to_upper()
    var condition: String = str(survivor.get("condition", "Healthy"))
    var status: String = str(survivor.get("status", "Available"))
    body.add_child(_make_label("%s  •  %s  •  %s" % [str(survivor.get("background", "Unknown")), condition, status], 14))
    body.add_child(_make_label("Traits: %s" % ", ".join(survivor.get("traits", [])), 13))
    body.add_child(_make_label("Fatigue %.0f / 100  •  Stress %.0f / 100" % [float(survivor.get("fatigue", 0.0)), float(survivor.get("stress", 0.0))], 14))
    body.add_child(_make_label("Expeditions completed: %d" % int(survivor.get("expeditions_done", 0)), 12))

    var ability: String = str(survivor.get("leader_ability", "Organizer"))
    body.add_child(_make_label("Leadership: %s — %s" % [ability, str(D.LEADER_ABILITIES.get(ability, "No leadership effect listed."))], 12))

    body.add_child(_separator())
    body.add_child(_heading("SKILLS", 18))
    var skill_grid = GridContainer.new()
    skill_grid.columns = 2
    skill_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var skills: Dictionary = survivor.get("skills", {})
    var skill_xp: Dictionary = survivor.get("skill_xp", {})
    for skill in ["Combat", "Scavenging", "Survival", "Medical", "Technical", "Social"]:
        var rank: int = int(skills.get(skill, 0))
        var threshold: int = 20 + rank * 15
        skill_grid.add_child(_make_label(skill, 14))
        var value = _make_label("%d  •  %d/%d XP" % [rank, int(skill_xp.get(skill, 0)), threshold], 13)
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        skill_grid.add_child(value)
    body.add_child(skill_grid)

    body.add_child(_separator())
    body.add_child(_heading("LOADOUT", 18))
    body.add_child(_make_label("Survivors currently carry equipped gear; expedition loot returns to camp storage.", 11))
    var equipment: Dictionary = survivor.get("equipment", {})
    for slot in ["Weapon", "Secondary", "Tool", "Clothing", "Pack"]:
        var gear_name: String = str(equipment.get(slot, ""))
        if gear_name == "":
            body.add_child(_make_label("%s: None" % slot, 13))
        else:
            var equipped = Button.new()
            equipped.text = "%s: %s  •  INFO" % [slot, gear_name]
            equipped.alignment = HORIZONTAL_ALIGNMENT_LEFT
            equipped.custom_minimum_size = Vector2(0, 42)
            equipped.pressed.connect(_open_item.bind(gear_name, "survivor"))
            body.add_child(equipped)

    if not Game.inventory_gear.is_empty() and condition != "Dead":
        body.add_child(_make_label("Camp gear available", 13))
        var counts: Dictionary = _gear_counts()
        for gear_name in counts.keys():
            var row = HBoxContainer.new()
            row.add_theme_constant_override("separation", 4)
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
        var actions = HBoxContainer.new()
        actions.add_theme_constant_override("separation", 4)
        var treat = Button.new()
        treat.text = "TREAT"
        treat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        treat.custom_minimum_size = Vector2(0, 46)
        treat.disabled = condition == "Healthy" or status != "Available"
        treat.pressed.connect(_treat_survivor)
        actions.add_child(treat)
        var send = Button.new()
        send.text = "SEND OUT"
        send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        send.custom_minimum_size = Vector2(0, 46)
        send.disabled = status != "Available"
        send.pressed.connect(_handoff_send)
        actions.add_child(send)
        body.add_child(actions)

    body.add_child(_separator())
    body.add_child(_heading("RELATIONSHIPS", 18))
    var relationships: Dictionary = survivor.get("relationships", {})
    var any_relationship: bool = false
    for other in Game.survivors:
        if int(other.get("id", -1)) == current_survivor_id or str(other.get("condition", "Healthy")) == "Dead":
            continue
        var relation_value: int = int(relationships.get(str(other.get("id", -1)), 0))
        body.add_child(_make_label("%s — %s (%d)" % [str(other.get("name", "Survivor")), Game.relationship_label(relation_value), relation_value], 13))
        any_relationship = true
    if not any_relationship:
        body.add_child(_make_label("No active relationships yet.", 13))

    body.add_child(_separator())
    body.add_child(_heading("HISTORY", 18))
    var survivor_history: Array = survivor.get("history", [])
    if survivor_history.is_empty():
        body.add_child(_make_label("No recorded history yet.", 13))
    else:
        var start: int = maxi(0, survivor_history.size() - 12)
        for index in range(survivor_history.size() - 1, start - 1, -1):
            body.add_child(_make_label(str(survivor_history[index]), 12))

func _render_inventory() -> void:
    _clear_body()
    title_label.text = "CAMP INVENTORY"
    body.add_child(_make_label("Tap any stored item for what it does and the stats First Fire currently uses.", 12))

    body.add_child(_separator())
    body.add_child(_heading("RESOURCES", 18))
    var any_resource: bool = false
    for resource_name in D.RESOURCE_ORDER:
        var count: int = int(Game.resources.get(resource_name, 0))
        if count <= 0:
            continue
        body.add_child(_inventory_item_button(resource_name, count))
        any_resource = true
    if not any_resource:
        body.add_child(_make_label("No stored resources.", 13))

    body.add_child(_separator())
    body.add_child(_heading("COMPONENTS", 18))
    var any_component: bool = false
    for component_name in Game.components.keys():
        var count: int = int(Game.components.get(component_name, 0))
        if count <= 0:
            continue
        body.add_child(_inventory_item_button(str(component_name), count))
        any_component = true
    if not any_component:
        body.add_child(_make_label("No crafted components.", 13))

    body.add_child(_separator())
    body.add_child(_heading("GEAR", 18))
    var counts: Dictionary = _gear_counts()
    if counts.is_empty():
        body.add_child(_make_label("No unequipped camp gear.", 13))
    else:
        for gear_name in counts.keys():
            body.add_child(_inventory_item_button(str(gear_name), int(counts[gear_name])))

func _inventory_item_button(item_name: String, count: int) -> Button:
    var button = Button.new()
    button.text = "%s ×%d" % [item_name, count]
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(0, 46)
    button.pressed.connect(_open_item.bind(item_name, "inventory"))
    return button

func _open_item(item_name: String, return_mode: String) -> void:
    current_item = item_name
    item_return_mode = return_mode
    mode = "item"
    _render_item()

func _render_item() -> void:
    _clear_body()
    title_label.text = current_item.to_upper()

    var back = Button.new()
    back.text = "← BACK TO %s" % ("SURVIVOR" if item_return_mode == "survivor" else "CAMP INVENTORY")
    back.custom_minimum_size = Vector2(0, 44)
    back.pressed.connect(_back_from_item)
    body.add_child(back)

    var owned_count: int = _owned_count(current_item)
    body.add_child(_make_label("Owned in camp: %d" % owned_count, 13))
    body.add_child(_make_label(str(ITEM_DESCRIPTIONS.get(current_item, "No field notes have been written for this item yet.")), 15))

    if D.GEAR.has(current_item):
        body.add_child(_separator())
        body.add_child(_heading("GEAR DATA", 18))
        var data: Dictionary = D.GEAR[current_item]
        body.add_child(_make_label("Slot: %s" % str(data.get("slot", "Unknown")), 13))
        if data.has("combat"):
            body.add_child(_make_label("Combat value: +%d" % int(data.get("combat", 0)), 13))
        if data.has("protect"):
            body.add_child(_make_label("Protection: %.0f%%" % (float(data.get("protect", 0.0)) * 100.0), 13))
        if data.has("capacity"):
            body.add_child(_make_label("Carry capacity: %d" % int(data.get("capacity", 0)), 13))
        if data.has("technical"):
            body.add_child(_make_label("Technical bonus: +%d" % int(data.get("technical", 0)), 13))
        if data.has("medical"):
            body.add_child(_make_label("Medical bonus: +%d" % int(data.get("medical", 0)), 13))
        if data.has("ammo"):
            body.add_child(_make_label("Ammo per tactical shot: %d" % int(data.get("ammo", 0)), 13))
        if data.has("tool"):
            body.add_child(_make_label("Tool tag: %s" % str(data.get("tool", "")), 13))
        if data.has("light"):
            body.add_child(_make_label("Directional light: %.0f-tile reach  •  View range +%d" % [float(data.get("light_range", 0.0)), int(data.get("view_bonus", 0))], 13))
        if data.has("weight"):
            body.add_child(_make_label("Carried weight: %.1f" % float(data.get("weight", 0.0)), 13))
        body.add_child(_make_label("Inventory size: %d" % int(data.get("size", 0)), 13))
    elif Game.components.has(current_item):
        body.add_child(_separator())
        body.add_child(_make_label("Crafted component. Used as an intermediate requirement for larger recipes or structures.", 13))
    elif Game.resources.has(current_item):
        body.add_child(_separator())
        body.add_child(_make_label("General camp resource. Quantity is shared across the settlement.", 13))

func _back_from_item() -> void:
    if item_return_mode == "survivor":
        mode = "survivor"
        _render_survivor()
    else:
        mode = "inventory"
        _render_inventory()

func _equip_gear(gear_name: String) -> void:
    Game.equip_gear(current_survivor_id, gear_name)
    _render_survivor()

func _treat_survivor() -> void:
    Game.treat_survivor(current_survivor_id)
    _render_survivor()

func _gear_counts() -> Dictionary:
    var counts: Dictionary = {}
    for gear_name in Game.inventory_gear:
        var key: String = str(gear_name)
        counts[key] = int(counts.get(key, 0)) + 1
    return counts

func _owned_count(item_name: String) -> int:
    if Game.resources.has(item_name):
        return int(Game.resources.get(item_name, 0))
    if Game.components.has(item_name):
        return int(Game.components.get(item_name, 0))
    var count: int = 0
    for gear_name in Game.inventory_gear:
        if str(gear_name) == item_name:
            count += 1
    for survivor in Game.survivors:
        var equipment: Dictionary = survivor.get("equipment", {})
        for equipped_name in equipment.values():
            if str(equipped_name) == item_name:
                count += 1
    return count

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
