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
# FFData: real Secondary slot + data-driven light profile + craft access.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFData.gd'
t = read(path)
t = replace_once(
    t,
    '    "Flashlight": {"slot": "Tool", "size": 2, "tool": "Light"},',
    '    "Flashlight": {"slot": "Secondary", "size": 2, "tool": "Light", "light": "cone", "light_range": 10.0, "light_spread": 0.52, "light_strength": 1.0, "light_color": "edf5d6", "view_bonus": 2},',
    'flashlight secondary slot',
)
t = replace_once(
    t,
    '        {"id": "Pry Tool", "time": 8.0, "cost": {"Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Pry Tool"},\n        {"id": "Hammer", "time": 8.0, "cost": {"Wood": 1, "Scrap Metal": 1}, "gives_gear": "Hammer"},',
    '        {"id": "Pry Tool", "time": 8.0, "cost": {"Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Pry Tool"},\n        {"id": "Flashlight", "time": 7.0, "cost": {"Plastic": 1, "Scrap Metal": 1, "Hardware": 1}, "gives_gear": "Flashlight"},\n        {"id": "Hammer", "time": 8.0, "cost": {"Wood": 1, "Scrap Metal": 1}, "gives_gear": "Hammer"},',
    'flashlight workbench recipe',
)
write(path, t)


# ---------------------------------------------------------------------------
# Inspector: expose Secondary separately, preserve old Tool-flashlight display,
# and show actual lighting data.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFInspector.gd'
t = read(path)
t = replace_once(
    t,
    '    "Flashlight": "Portable light source for dark or obscured situations.",',
    '    "Flashlight": "Portable directional field light. Equip it in Secondary so a survivor can carry it alongside both a weapon and a general Tool. Tactical maps render its beam and extended view range.",',
    'flashlight inspector description',
)
old_loadout = '''    var equipment: Dictionary = survivor.get("equipment", {})
    for slot in ["Weapon", "Clothing", "Pack", "Tool"]:
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
'''
new_loadout = '''    var equipment: Dictionary = survivor.get("equipment", {})
    var legacy_secondary: String = ""
    if str(equipment.get("Secondary", "")) == "" and str(equipment.get("Tool", "")) == "Flashlight":
        legacy_secondary = "Flashlight"
    for slot in ["Weapon", "Secondary", "Tool", "Clothing", "Pack"]:
        var gear_name: String = str(equipment.get(slot, ""))
        if slot == "Secondary" and gear_name == "" and legacy_secondary != "":
            gear_name = legacy_secondary
        elif slot == "Tool" and gear_name == "Flashlight" and legacy_secondary != "":
            gear_name = ""
        if gear_name == "":
            body.add_child(_make_label("%s: None" % slot, 13))
        else:
            var equipped = Button.new()
            equipped.text = "%s: %s  •  INFO" % [slot, gear_name]
            equipped.alignment = HORIZONTAL_ALIGNMENT_LEFT
            equipped.custom_minimum_size = Vector2(0, 42)
            equipped.pressed.connect(_open_item.bind(gear_name, "survivor"))
            body.add_child(equipped)
'''
t = replace_once(t, old_loadout, new_loadout, 'secondary loadout display')
t = replace_once(
    t,
    '        if data.has("tool"):\n            body.add_child(_make_label("Tool tag: %s" % str(data.get("tool", "")), 13))\n        body.add_child(_make_label("Inventory size: %d" % int(data.get("size", 0)), 13))',
    '        if data.has("tool"):\n            body.add_child(_make_label("Tool tag: %s" % str(data.get("tool", "")), 13))\n        if data.has("light"):\n            body.add_child(_make_label("Directional light: %.0f-tile reach  •  View range +%d" % [float(data.get("light_range", 0.0)), int(data.get("view_bonus", 0))], 13))\n        body.add_child(_make_label("Inventory size: %d" % int(data.get("size", 0)), 13))',
    'lighting item stats',
)
write(path, t)


# ---------------------------------------------------------------------------
# Environments: authored fixed light placement belongs with authored geometry.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFTacticalEnvironments.gd'
t = read(path)
t = replace_once(
    t,
    '    if blocked.has(spawn):\n        return false\n    var seen := {spawn: true}',
    '    if blocked.has(spawn):\n        return false\n    for entry_value in spec.get("lights", []):\n        var entry: Array = entry_value\n        if entry.size() < 2:\n            return false\n        var light_pos: Vector2i = entry[0]\n        if not _inside(light_pos):\n            return false\n    var seen := {spawn: true}',
    'validate fixed lights',
)
t = replace_once(
    t,
    '        "barrels": [],\n        "props": [],\n        "player_spawn": player_spawn,',
    '        "barrels": [],\n        "props": [],\n        "lights": [],\n        "player_spawn": player_spawn,',
    'environment light collection',
)
t = replace_once(
    t,
    'static func _prop(spec: Dictionary, p: Vector2i, prop_kind: String) -> void:\n    spec["props"].append([p, prop_kind])\n\nstatic func _back_alley',
    'static func _prop(spec: Dictionary, p: Vector2i, prop_kind: String) -> void:\n    spec["props"].append([p, prop_kind])\n\nstatic func _light(spec: Dictionary, p: Vector2i, light_kind: String) -> void:\n    spec["lights"].append([p, light_kind])\n\nstatic func _back_alley',
    'environment light helper',
)
t = replace_once(
    t,
    '    _prop(spec, Vector2i(14, 3), "neon_sign")\n    spec["barrels"].append(Vector2i(6, 12))',
    '    _prop(spec, Vector2i(14, 3), "neon_sign")\n    _light(spec, Vector2i(14, 3), "neon_pink")\n    _light(spec, Vector2i(9, 7), "security")\n    spec["barrels"].append(Vector2i(6, 12))',
    'back alley lights',
)
t = replace_once(
    t,
    '    _obstacle(spec, Vector2i(3, 3), "gas_sign")\n    _obstacle(spec, Vector2i(10, 10), "ice_box")\n    spec["barrels"].append(Vector2i(17, 8))',
    '    _obstacle(spec, Vector2i(3, 3), "gas_sign")\n    _obstacle(spec, Vector2i(10, 10), "ice_box")\n    _light(spec, Vector2i(6, 4), "canopy")\n    _light(spec, Vector2i(9, 4), "canopy")\n    _light(spec, Vector2i(14, 6), "fluorescent")\n    _light(spec, Vector2i(3, 3), "neon_cyan")\n    spec["barrels"].append(Vector2i(17, 8))',
    'gas station lights',
)
t = replace_once(
    t,
    '    _obstacle(spec, Vector2i(14, 4), "kitchen")\n    _obstacle(spec, Vector2i(15, 4), "kitchen")\n    _obstacle(spec, Vector2i(16, 6), "fridge")\n    return spec',
    '    _obstacle(spec, Vector2i(14, 4), "kitchen")\n    _obstacle(spec, Vector2i(15, 4), "kitchen")\n    _obstacle(spec, Vector2i(16, 6), "fridge")\n    _light(spec, Vector2i(8, 6), "warm")\n    _light(spec, Vector2i(15, 6), "fluorescent")\n    return spec',
    'house lights',
)
t = replace_once(
    t,
    '    _obstacle(spec, Vector2i(16, 6), "washer")\n    _prop(spec, Vector2i(9, 3), "apt_sign")\n    return spec',
    '    _obstacle(spec, Vector2i(16, 6), "washer")\n    _prop(spec, Vector2i(9, 3), "apt_sign")\n    _light(spec, Vector2i(9, 4), "fluorescent")\n    _light(spec, Vector2i(9, 11), "fluorescent")\n    if variant == 1:\n        _light(spec, Vector2i(14, 12), "warm")\n    return spec',
    'apartment lights',
)
t = replace_once(
    t,
    '    _obstacle(spec, Vector2i(17, 11), "vending")\n    _prop(spec, Vector2i(10, 4), "shop_sign")\n    spec["barrels"].append(Vector2i(17, 4))',
    '    _obstacle(spec, Vector2i(17, 11), "vending")\n    _prop(spec, Vector2i(10, 4), "shop_sign")\n    _light(spec, Vector2i(10, 4), "neon_cyan")\n    _light(spec, Vector2i(10, 6), "fluorescent")\n    _light(spec, Vector2i(14, 9), "fluorescent")\n    spec["barrels"].append(Vector2i(17, 4))',
    'corner store lights',
)
t = replace_once(
    t,
    '    spec["barrels"].append(Vector2i(17, 13))\n    _prop(spec, Vector2i(12, 3), "warehouse_sign")\n    return spec',
    '    spec["barrels"].append(Vector2i(17, 13))\n    _prop(spec, Vector2i(12, 3), "warehouse_sign")\n    _light(spec, Vector2i(9, 12), "flood")\n    _light(spec, Vector2i(16, 8), "warning_red")\n    return spec',
    'warehouse lights',
)
write(path, t)


# ---------------------------------------------------------------------------
# Combat: consume environment sources + Secondary flashlight. Lighting is an
# action-recalculated cell map; only cheap glow animation redraws while idle.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFCombat.gd'
t = read(path)
t = replace_once(
    t,
    'const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\nconst TacticalEnvironments = preload("res://scripts/FFTacticalEnvironments.gd")',
    'const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\nconst TacticalEnvironments = preload("res://scripts/FFTacticalEnvironments.gd")\nconst TacticalLighting = preload("res://scripts/FFTacticalLighting.gd")',
    'lighting preload',
)
t = replace_once(
    t,
    'var props := {}\nvar ground := {}\nvar base_glass := {}',
    'var props := {}\nvar ground := {}\nvar light_sources: Array = []\nvar light_levels := {}\nvar light_tints := {}\nvar base_glass := {}',
    'lighting runtime state',
)
t = replace_once(
    t,
    'var fx_active_last_frame := false\n\nvar btn_turn_left',
    'var fx_active_last_frame := false\nvar lighting_redraw_accum := 0.0\n\nvar btn_turn_left',
    'lighting redraw accumulator',
)
old_process = '''func _process(_delta):
    if not initialized:
        return
    var now := Time.get_ticks_msec()
    var active := now < hit_flash_until_ms or now < muzzle_flash_until_ms
    if active or fx_active_last_frame:
        queue_redraw()
    fx_active_last_frame = active
'''
new_process = '''func _process(delta):
    if not initialized:
        return
    var now := Time.get_ticks_msec()
    var active := now < hit_flash_until_ms or now < muzzle_flash_until_ms
    lighting_redraw_accum += float(delta)
    var lighting_animation_due := false
    if lighting_redraw_accum >= 0.12 and TacticalLighting.has_animated_sources(light_sources):
        lighting_redraw_accum = 0.0
        lighting_animation_due = true
    if active or fx_active_last_frame or lighting_animation_due:
        queue_redraw()
    fx_active_last_frame = active
'''
t = replace_once(t, old_process, new_process, 'low-refresh lighting animation')
t = replace_once(
    t,
    '    fx_active_last_frame = false\n    tick = int(runtime.get("tick", 0))',
    '    fx_active_last_frame = false\n    lighting_redraw_accum = 0.0\n    tick = int(runtime.get("tick", 0))',
    'lighting start reset',
)
t = replace_once(
    t,
    '    var max_hp := condition_max_hp(str(s.get("condition", "Healthy")))\n    var actor = {',
    '    var max_hp := condition_max_hp(str(s.get("condition", "Healthy")))\n    var equipment: Dictionary = s.get("equipment", {}).duplicate(true)\n    var secondary_item: String = TacticalLighting.secondary_item_from_equipment(equipment)\n    var actor = {',
    'actor equipment cache',
)
t = replace_once(
    t,
    '        "equipment": s.get("equipment", {}).duplicate(true),',
    '        "equipment": equipment,',
    'actor equipment dictionary',
)
t = replace_once(
    t,
    '        "weapon": weapon_profile(str(s.get("equipment", {}).get("Weapon", ""))),\n        "clothing": str(s.get("equipment", {}).get("Clothing", "")),\n        "tool": str(s.get("equipment", {}).get("Tool", "")),\n        "pack": str(s.get("equipment", {}).get("Pack", "")),',
    '        "weapon": weapon_profile(str(equipment.get("Weapon", ""))),\n        "clothing": str(equipment.get("Clothing", "")),\n        "tool": str(equipment.get("Tool", "")),\n        "secondary": secondary_item,\n        "pack": str(equipment.get("Pack", "")),',
    'actor secondary item',
)
t = replace_once(
    t,
    '    walls.clear(); obstacles.clear(); glass.clear(); doors.clear(); barrels.clear(); props.clear(); ground.clear(); exit_cells.clear()',
    '    walls.clear(); obstacles.clear(); glass.clear(); doors.clear(); barrels.clear(); props.clear(); ground.clear(); exit_cells.clear(); light_sources.clear(); light_levels.clear(); light_tints.clear()',
    'clear lighting state',
)
t = replace_once(
    t,
    '    for p in spec.get("barrels", []): barrels[p] = true\n    for entry in spec.get("props", []): props[entry[0]] = str(entry[1])\n\n    base_glass',
    '    for p in spec.get("barrels", []): barrels[p] = true\n    for entry in spec.get("props", []): props[entry[0]] = str(entry[1])\n    for entry_value in spec.get("lights", []):\n        var light_entry: Array = entry_value\n        var light_pos: Vector2i = light_entry[0]\n        light_sources.append(TacticalLighting.make_source(light_pos, str(light_entry[1]), light_sources.size()))\n\n    base_glass',
    'consume environment lights',
)
lighting_functions = r'''func recalc_lighting():
    light_levels.clear()
    light_tints.clear()
    var theme: String = TacticalEnvironments.theme_name(environment_id)
    var ambient: float = TacticalLighting.ambient_level(theme)
    var player_light: String = str(player.get("secondary", ""))
    var ally_light: String = str(ally.get("secondary", "")) if not ally.is_empty() and not bool(ally.get("dead", false)) else ""
    for y in range(H):
        for x in range(W):
            var cell := Vector2i(x, y)
            var level: float = ambient
            var strongest: float = 0.0
            var tint_hex := ""
            for source_value in light_sources:
                var source: Dictionary = source_value
                var source_pos: Vector2i = source.get("pos", Vector2i(-99, -99))
                if not line_clear(source_pos, cell):
                    continue
                var contribution: float = TacticalLighting.radial_contribution(cell, source)
                level = maxf(level, contribution)
                if contribution > strongest:
                    strongest = contribution
                    tint_hex = str(source.get("color", "ffffff"))
            if TacticalLighting.item_emits_light(player_light) and line_clear(player.pos, cell):
                var flashlight_level: float = TacticalLighting.cone_contribution(player.pos, player.facing, cell, player_light)
                level = maxf(level, flashlight_level)
                if flashlight_level > strongest:
                    strongest = flashlight_level
                    tint_hex = str(D.GEAR[player_light].get("light_color", "edf5d6"))
            if ally_light != "" and TacticalLighting.item_emits_light(ally_light) and line_clear(ally.pos, cell):
                var ally_flashlight_level: float = TacticalLighting.cone_contribution(ally.pos, ally.facing, cell, ally_light)
                level = maxf(level, ally_flashlight_level)
                if ally_flashlight_level > strongest:
                    strongest = ally_flashlight_level
                    tint_hex = str(D.GEAR[ally_light].get("light_color", "edf5d6"))
            light_levels[cell] = clampf(level, 0.0, 1.0)
            if tint_hex != "":
                light_tints[cell] = tint_hex

'''
t = replace_once(t, 'func recalc_visibility():\n', lighting_functions + 'func recalc_visibility():\n    recalc_lighting()\n', 'lighting recalculation')
t = replace_once(
    t,
    '    if player.tool == "Flashlight": awareness += 0.5',
    '    if TacticalLighting.item_emits_light(str(player.get("secondary", ""))): awareness += 0.5',
    'flashlight awareness source',
)
t = replace_once(
    t,
    '    if player.tool == "Flashlight": r += 2',
    '    r += TacticalLighting.item_view_bonus(str(player.get("secondary", "")))',
    'flashlight view bonus',
)
t = replace_once(
    t,
    '    draw_map()\n    draw_units()\n    draw_fog()',
    '    draw_map()\n    draw_units()\n    draw_lighting()\n    draw_light_source_glows()\n    draw_fog()',
    'lighting draw order',
)
lighting_draw = r'''func draw_lighting():
    var theme: String = TacticalEnvironments.theme_name(environment_id)
    var dark_tint: Color = TacticalLighting.ambient_tint(theme)
    var ambient: float = TacticalLighting.ambient_level(theme)
    for y in range(H):
        for x in range(W):
            var cell := Vector2i(x, y)
            var r := Rect2(x * TILE, y * TILE, TILE, TILE)
            var level: float = float(light_levels.get(cell, ambient))
            var darkness: float = TacticalLighting.darkness_alpha(level)
            draw_rect(r, Color(dark_tint.r, dark_tint.g, dark_tint.b, darkness))
            if light_tints.has(cell):
                var tint := Color(str(light_tints[cell]))
                var wash: float = TacticalLighting.color_wash_alpha(level)
                if wash > 0.0:
                    draw_rect(r.grow(-1), Color(tint.r, tint.g, tint.b, wash))

func draw_light_source_glows():
    var now: int = Time.get_ticks_msec()
    for source_value in light_sources:
        var source: Dictionary = source_value
        var source_pos: Vector2i = source.get("pos", Vector2i(-99, -99))
        if not inside(source_pos):
            continue
        var c := cell_center(source_pos)
        var source_color := Color(str(source.get("color", "ffffff")))
        var visual_strength: float = TacticalLighting.visual_strength(source, now)
        draw_circle(c, 15.0, Color(source_color.r, source_color.g, source_color.b, 0.035 * visual_strength))
        draw_circle(c, 9.0, Color(source_color.r, source_color.g, source_color.b, 0.075 * visual_strength))
        draw_circle(c, 3.0, Color(source_color.r, source_color.g, source_color.b, 0.72 * visual_strength))
        draw_circle(c, 3.0, Color(1.0, 1.0, 1.0, 0.55 * visual_strength), false, 1.0)

'''
t = replace_once(t, 'func draw_fog():\n', lighting_draw + 'func draw_fog():\n', 'lighting drawing helpers')
t = replace_once(
    t,
    '    if player.clothing!="": gear_line += "  |  %s"%player.clothing\n    draw_string(font,Vector2(10,69),gear_line',
    '    if player.clothing!="": gear_line += "  |  %s"%player.clothing\n    if TacticalLighting.item_emits_light(str(player.get("secondary", ""))): gear_line += "  |  LIGHT"\n    draw_string(font,Vector2(10,69),gear_line',
    'lighting HUD status',
)
write(path, t)


# ---------------------------------------------------------------------------
# Architecture smoke: validate the new durable contracts deterministically.
# ---------------------------------------------------------------------------
path = 'game/scripts/ci/FFArchitectureSmoke.gd'
t = read(path)
t = replace_once(
    t,
    'extends SceneTree\n\nconst ExpeditionRules',
    'extends SceneTree\n\nconst D = preload("res://scripts/FFData.gd")\nconst ExpeditionRules',
    'smoke data preload',
)
t = replace_once(
    t,
    'const TacticalEnvironments = preload("res://scripts/FFTacticalEnvironments.gd")\nconst LegacyFieldEvents',
    'const TacticalEnvironments = preload("res://scripts/FFTacticalEnvironments.gd")\nconst TacticalLighting = preload("res://scripts/FFTacticalLighting.gd")\nconst LegacyFieldEvents',
    'smoke lighting preload',
)
t = replace_once(
    t,
    '    if not _check(TacticalEnvironments.exit_count("gas_station", 1) >= 3, "multi-exit gas station variant"): return\n    for environment_id in TacticalEnvironments.all_ids():',
    '    if not _check(TacticalEnvironments.exit_count("gas_station", 1) >= 3, "multi-exit gas station variant"): return\n    if not _check(str(D.GEAR["Flashlight"].get("slot", "")) == "Secondary", "flashlight secondary slot"): return\n    if not _check(TacticalLighting.secondary_item_from_equipment({"Secondary": "Flashlight", "Tool": ""}) == "Flashlight", "secondary light lookup"): return\n    if not _check(TacticalLighting.secondary_item_from_equipment({"Tool": "Flashlight"}) == "Flashlight", "legacy flashlight compatibility"): return\n    if not _check(TacticalLighting.cone_contribution(Vector2i(5, 5), Vector2i(1, 0), Vector2i(10, 5), "Flashlight") > 0.0, "flashlight forward cone"): return\n    if not _check(TacticalLighting.cone_contribution(Vector2i(5, 5), Vector2i(1, 0), Vector2i(2, 5), "Flashlight") == 0.0, "flashlight rear cutoff"): return\n    if not _check(TacticalEnvironments.build_layout("gas_station", 0).get("lights", []).size() >= 3, "gas station authored lights"): return\n    for environment_id in TacticalEnvironments.all_ids():',
    'lighting smoke contracts',
)
write(path, t)


# ---------------------------------------------------------------------------
# Permanent CI now knows lighting is canonical.
# ---------------------------------------------------------------------------
path = '.github/workflows/pages.yml'
t = read(path)
t = replace_once(
    t,
    '          test -f game/scripts/FFTacticalEnvironments.gd\n          test -f game/scripts/FFExpeditionRules.gd',
    '          test -f game/scripts/FFTacticalEnvironments.gd\n          test -f game/scripts/FFTacticalLighting.gd\n          test -f game/scripts/FFExpeditionRules.gd',
    'ci lighting file gate',
)
t = replace_once(
    t,
    "          grep -q 'const TacticalEnvironments = preload' game/scripts/FFCombat.gd\n          grep -q 'const Environments = preload' game/scripts/FFTacticalScenarios.gd",
    "          grep -q 'const TacticalEnvironments = preload' game/scripts/FFCombat.gd\n          grep -q 'const TacticalLighting = preload' game/scripts/FFCombat.gd\n          grep -q 'const Environments = preload' game/scripts/FFTacticalScenarios.gd",
    'ci lighting integration gate',
)
write(path, t)


# ---------------------------------------------------------------------------
# Architecture/context/changelog documentation.
# ---------------------------------------------------------------------------
path = 'ARCHITECTURE.md'
t = read(path)
t = replace_once(
    t,
    '### `FFTacticalVisuals.gd`\nTactical character presentation owner.',
    '### `FFTacticalLighting.gd`\nTactical lighting rules/presentation helper. Owns ambient low-light profiles, fixed-light falloff/color presets, data-driven Secondary light-item cone math, and cheap glow animation rules. `FFTacticalEnvironments.gd` owns fixed light placement; `FFCombat.gd` owns occlusion, light-map recalculation, fog/vision, and draw order. Lighting does not advance settlement simulation.\n\n### `FFTacticalVisuals.gd`\nTactical character presentation owner.',
    'architecture lighting owner',
)
write(path, t)

path = 'README_SOPS.md'
t = read(path)
t = replace_once(
    t,
    '- `FFTacticalVisuals.gd` — tactical character appearance, zombie variation, weapon silhouettes, and character drawing; presentation only.\n- `FFTacticalScenarios.gd`',
    '- `FFTacticalVisuals.gd` — tactical character appearance, zombie variation, weapon silhouettes, and character drawing; presentation only.\n- `FFTacticalLighting.gd` — tactical light profiles/falloff and Secondary light-item beam rules; environments place fixed sources and combat owns occlusion/draw integration.\n- `FFTacticalScenarios.gd`',
    'sop lighting ownership',
)
write(path, t)

path = 'README_CONTEXT.md'
t = read(path)
t = replace_once(
    t,
    'Current milestone: **Alpha 0.3B — Tactical Environments & Escape Routes**.',
    'Current milestone: **Alpha 0.3C — Tactical Lighting & Secondary Gear**.',
    'context milestone',
)
t = replace_once(
    t,
    'Survivors keep persistent modular tactical appearances. Zombies use varied civilian/worker/service/medical/decayed/heavy visual families, while those families remain cosmetic until a future gameplay change explicitly says otherwise. Equipped weapons are drawn as separate readable silhouettes beside survivors.',
    'Survivors keep persistent modular tactical appearances. Zombies use varied civilian/worker/service/medical/decayed/heavy visual families, while those families remain cosmetic until a future gameplay change explicitly says otherwise. Equipped weapons are drawn as separate readable silhouettes beside survivors.\n\nAlpha 0.3C adds low-light tactical rendering with authored neon, canopy, fluorescent, warm, security, flood, and warning-light sources. Lighting occlusion is recalculated only when tactical state changes; cheap source glow animation redraws at low refresh for phone/Web performance. Flashlights now use a real **Secondary** equipment slot independent of Weapon and Tool, cast an occluded directional cone, tint/brighten the board, and preserve their existing view-range benefit. An old schema-4 survivor with Flashlight still stored in Tool is recognized without mutating the save.',
    'context lighting summary',
)
write(path, t)

path = 'CHANGELOG.md'
t = read(path)
entry = '''## Alpha 0.3C — Tactical Lighting & Secondary Gear — 2026-08-13

### Lighting Overhaul
- Tactical boards now render through a real low-light pass instead of uniform flat brightness.
- Added authored fixed lighting to the 0.3B environments: alley neon/security light, gas-station canopy/store light, house lamps, apartment fluorescents, shop neon/fluorescents, and warehouse flood/warning lights. Drainage washes intentionally remain mostly dark.
- Fixed light color and falloff are data-driven and respect tactical wall/door/obstacle occlusion.
- Neon/fluorescent/warning emitters get subtle low-refresh flicker/glow animation while the more expensive light map only recalculates when tactical state changes, keeping the Web/mobile path lightweight.
- Darkness overlays both environment and characters, while visible light sources add colored wash so pink/cyan neon, warm interiors, cold fluorescents, and flashlights read differently.

### Flashlights / Secondary Slot
- Flashlight moved from the general Tool slot to a new **Secondary** equipment slot, allowing Weapon + Secondary + Tool to coexist.
- The existing slot-driven equipment backend handles Secondary generically, leaving room for future radios, binoculars, detectors, or other field utility items without special-case inventory code.
- Equipped flashlights cast an occluded directional cone from the survivor's facing and retain a +2 tactical view-range benefit.
- Companion flashlights illuminate from the companion's own position/facing too.
- Existing schema-4 saves remain valid; an older survivor who already had Flashlight in Tool is recognized as carrying the light without rewriting the save.
- Flashlights can still be scavenged and are now craftable at a Workbench from Plastic, Scrap Metal, and Hardware.
- Survivor inspection now shows Secondary separately and displays implemented light reach/view data.

### Architecture / Performance
- Added `FFTacticalLighting.gd` as the durable owner for ambient profiles, light-source presets/falloff, Secondary light-item cone math, and glow animation rules.
- `FFTacticalEnvironments.gd` owns authored fixed-light placement; `FFCombat.gd` owns occlusion, recalculation timing, and render integration.
- Save schema remains **4**; Secondary is an optional equipment dictionary key and therefore does not require a reset.

'''
t = replace_once(
    t,
    '# First Fire — Changelog\n\nThis file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n',
    '# First Fire — Changelog\n\nThis file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n' + entry,
    'changelog 03c entry',
)
write(path, t)

print('FIRST_FIRE_LIGHTING_03C_PATCH_OK')
