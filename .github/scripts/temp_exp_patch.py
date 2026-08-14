from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


# Expedition rules: make tactical combat reachable from the starting zone and
# prevent a streak of ordinary runs from hiding the tactical layer during Alpha.
p = Path("game/scripts/FFExpeditionRules.gd")
t = p.read_text()
t = replace_once(
    t,
    '''const TACTICAL_EVENT_CHANCE := {
    "Camp Perimeter": 0.0,
    "Nearby Streets": 0.55,
    "Residential Blocks": 0.65,
    "Commercial Fringe": 0.75,
    "Industrial Edge": 0.85,
}
''',
    '''const TACTICAL_EVENT_CHANCE := {
    "Camp Perimeter": 0.65,
    "Nearby Streets": 0.70,
    "Residential Blocks": 0.75,
    "Commercial Fringe": 0.82,
    "Industrial Edge": 0.90,
}
const TACTICAL_DROUGHT_LIMIT := 2
''',
    "tactical chance table",
)
marker = '''static func should_trigger_tactical_event(zone: String, rng: RandomNumberGenerator) -> bool:
    return rng.randf() < tactical_event_chance(zone)
'''
t = replace_once(
    t,
    marker,
    marker + '''
static func should_force_tactical(drought_count: int) -> bool:
    return drought_count >= TACTICAL_DROUGHT_LIMIT
''',
    "tactical drought helper",
)
p.write_text(t)


# Main UI: remove Loot Focus entirely. A normal expedition is survivor + zone +
# optional companion; loot comes from the place and the people, not a dropdown.
p = Path("game/scripts/Main.gd")
t = p.read_text()
t = replace_once(t, "var expedition_focus: OptionButton\n", "", "focus variable")
t = replace_once(
    t,
    '''    v.add_child(_make_label("Loot Focus", 13))
    expedition_focus = OptionButton.new()
    for focus in ["Balanced", "Food & Water", "Materials", "Gear"]:
        expedition_focus.add_item(focus)
    expedition_focus.custom_minimum_size = Vector2(0, 44)
    v.add_child(expedition_focus)

''',
    "",
    "focus UI block",
)
t = replace_once(
    t,
    '''    var zone = str(expedition_zone.get_item_metadata(expedition_zone.selected))
    var focus = expedition_focus.get_item_text(expedition_focus.selected)
    var companion = int(expedition_companion.get_item_metadata(expedition_companion.selected)) if expedition_companion.item_count > 0 else -1
    if Game.start_expedition(selected_survivor_id, companion, zone, focus):
''',
    '''    var zone = str(expedition_zone.get_item_metadata(expedition_zone.selected))
    var companion = int(expedition_companion.get_item_metadata(expedition_companion.selected)) if expedition_companion.item_count > 0 else -1
    if Game.start_expedition(selected_survivor_id, companion, zone):
''',
    "focus send path",
)
if "expedition_focus" in t or "Loot Focus" in t:
    raise SystemExit("focus UI remnants remain")
p.write_text(t)


# Game orchestration: remove focus as a gameplay input, add tactical drought
# protection using the already-persistent flags dictionary (schema-neutral), and
# make truly empty returns explicit instead of formatting an empty pair of parens.
p = Path("game/scripts/Game.gd")
t = p.read_text()
t = replace_once(
    t,
    "func start_expedition(primary_id, companion_id, zone, focus):",
    "func start_expedition(primary_id, companion_id, zone):",
    "start_expedition signature",
)
t = replace_once(
    t,
    '    var event_key = ""\n    var combat_kind = ""\n',
    '    var event_key = ""\n    var combat_kind = ""\n    var tactical_drought = int(flags.get("tactical_drought", 0))\n',
    "tactical drought state",
)
t = replace_once(
    t,
    '''    if event_key == "" and force_recruit:
        # Recruitment protection now guarantees a real rescue opportunity.
        # The tactical encounter only gets the stranger out; the existing
        # recruit popup still decides whether they actually join First Fire.
        eligible_expeditions_since_recruit = 0
        combat_kind = "rescue"
    elif event_key == "" and ExpeditionRules.should_trigger_tactical_event(str(zone), rng):
        # Alpha 0.3 tactical encounters have their own explicit pop rate so they
        # are common enough to playtest instead of being double-gated by legacy events.
        combat_kind = _pick_tactical_kind(zone)
    elif event_key == "" and rng.randf() < float(D.ZONES[zone]["event_chance"]):
        # Temporary legacy text events only roll when no tactical encounter fired.
        event_key = _select_field_event(zone)
''',
    '''    if event_key == "" and force_recruit:
        # Recruitment protection guarantees a real rescue opportunity.
        eligible_expeditions_since_recruit = 0
        combat_kind = "rescue"
        flags["tactical_drought"] = 0
    elif event_key == "" and ExpeditionRules.should_force_tactical(tactical_drought):
        # After two ordinary field runs without tactical combat, force the next
        # normal run tactical so Alpha playtesting cannot miss the system forever.
        combat_kind = _pick_tactical_kind(zone)
        flags["tactical_drought"] = 0
    elif event_key == "" and ExpeditionRules.should_trigger_tactical_event(str(zone), rng):
        combat_kind = _pick_tactical_kind(zone)
        flags["tactical_drought"] = 0
    elif event_key == "" and rng.randf() < float(D.ZONES[zone]["event_chance"]):
        # Temporary legacy text events only roll when no tactical encounter fired.
        event_key = _select_field_event(zone)
        flags["tactical_drought"] = tactical_drought + 1
    elif event_key == "":
        flags["tactical_drought"] = tactical_drought + 1
''',
    "encounter roll block",
)
t = t.replace('        "focus": focus,\n', '')
t = t.replace('        "zone": D.SPECIAL_SITES[site]["zone"], "focus": "Special",\n', '        "zone": D.SPECIAL_SITES[site]["zone"],\n')
t = t.replace('_weighted_loot_pick(exp["zone"], exp.get("focus", "General"))', '_weighted_loot_pick(exp["zone"])')
t = t.replace('_weighted_loot_pick(zone, exp["focus"])', '_weighted_loot_pick(zone)')
t = replace_once(
    t,
    '''func _weighted_loot_pick(zone, focus):
    var table = D.ZONES[zone]["loot"]
    var total = 0.0
    var weighted = []
    for key in table.keys():
        var w = float(table[key])
        if focus == "Food & Water" and ["Raw Food", "Cooked Food", "Dirty Water", "Clean Water"].has(key):
            w *= 2.0
        elif focus == "Materials" and ["Wood", "Scrap Metal", "Cloth", "Plastic", "Hardware"].has(key):
            w *= 1.75
        weighted.append([key, w])
        total += w
''',
    '''func _weighted_loot_pick(zone):
    var table = D.ZONES[zone]["loot"]
    var total = 0.0
    var weighted = []
    for key in table.keys():
        var w = float(table[key])
        weighted.append([key, w])
        total += w
''',
    "weighted loot focus removal",
)
t = t.replace('    if exp["focus"] == "Gear":\n        chance *= 2.0\n', '')
t = replace_once(
    t,
    '''    var names = _party_names(exp["survivor_ids"])
    _add_history("Day %d — %s returned from %s (%s)." % [day, names, zone, ", ".join(loot_text)])
    toast_requested.emit("%s returned: %s" % [names, ", ".join(loot_text)])
''',
    '''    if gear_found != "":
        loot_text.append("Found %s" % gear_found)
    var names = _party_names(exp["survivor_ids"])
    if loot_text.is_empty():
        _add_history("Day %d — %s returned from %s empty-handed." % [day, names, zone])
        toast_requested.emit("%s returned empty-handed." % names)
    else:
        var haul_summary = ", ".join(loot_text)
        _add_history("Day %d — %s returned from %s (%s)." % [day, names, zone, haul_summary])
        toast_requested.emit("%s returned: %s" % [names, haul_summary])
''',
    "empty return summary",
)
if 'exp["focus"]' in t or 'focus == "Food & Water"' in t or 'focus == "Materials"' in t:
    raise SystemExit("loot focus gameplay remnants remain")
p.write_text(t)


# Regression contract for the exact starting-zone bug and drought guard.
p = Path("game/scripts/ci/FFArchitectureSmoke.gd")
t = p.read_text()
marker = '    if not _check(ExpeditionRules.should_force_recruit(1, 1, 5, true), "solo recruit protection"): return\n'
t = replace_once(
    t,
    marker,
    marker
    + '    if not _check(ExpeditionRules.tactical_event_chance("Camp Perimeter") > 0.0, "starting zone tactical chance"): return\n'
    + '    if not _check(ExpeditionRules.should_force_tactical(2), "tactical drought protection"): return\n',
    "architecture tactical checks",
)
p.write_text(t)


# Durable project context: current tuning, simpler dispatch, and original-art rule.
p = Path("README_CONTEXT.md")
t = p.read_text()
pillar = '- **Phone/Web first.** Touch, portrait layout, browser lifecycle, storage, pause/resume, and mobile Safari constraints are architectural inputs.\n'
t = replace_once(
    t,
    pillar,
    pillar
    + '- **Original presentation.** First Fire art should avoid third-party franchise names, logos, characters, or other recognizable branded identifiers unless explicitly requested and appropriate.\n',
    "original art rule",
)
t = replace_once(
    t,
    '''- Tactical encounter chance now rolls independently from legacy text events: **55% Nearby / 65% Residential / 75% Commercial / 85% Industrial**. Camp Perimeter remains non-tactical.
- Fatigue gains from expeditions, tactical encounters, crafting/building, and garden work are currently **2×** their original Alpha values. Idle recovery rates are unchanged.
''',
    '''- Tactical encounter chance rolls independently from legacy text events and now includes the starting zone: **65% Camp Perimeter / 70% Nearby / 75% Residential / 82% Commercial / 90% Industrial**.
- Tactical drought protection guarantees a tactical encounter on the next normal field run after two consecutive ordinary runs without one.
- Expedition dispatch no longer has a loot-focus selector; routine loot follows the zone's natural loot table plus survivor skill/equipment rules.
- Fatigue gains from expeditions, tactical encounters, crafting/building, and garden work are currently **2×** their original Alpha values. Idle recovery rates are unchanged.
''',
    "context tuning section",
)
p.write_text(t)


# Player-facing changelog.
p = Path("CHANGELOG.md")
t = p.read_text()
heading = '# First Fire — Changelog\n\nThis file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n'
entry = '''## Alpha 0.3A — Tactical Spawn & Expedition Simplification — 2026-08-13

### Tactical Encounter Reliability
- Fixed the starting-zone oversight that made **Camp Perimeter incapable of spawning tactical encounters** even though it is the only zone unlocked in a new run.
- Tactical playtest rates are now 65% Camp Perimeter, 70% Nearby Streets, 75% Residential Blocks, 82% Commercial Fringe, and 90% Industrial Edge.
- Added drought protection: after two consecutive normal field runs without tactical combat, the next normal run is forced tactical.

### Expedition Dispatch
- Removed **Loot Focus** from the send-out screen. Expedition choice is now survivor, destination, and optional companion.
- Routine scavenging no longer receives Food/Water, Materials, or Gear focus multipliers; each zone's natural loot table is authoritative.
- Empty resource runs now report **returned empty-handed** instead of displaying an unexplained `()`.

### Presentation Policy
- Added a durable project rule that future First Fire art should avoid third-party franchise names/logos/characters unless explicitly requested and appropriate.

'''
t = replace_once(t, heading, heading + entry, "changelog header")
p.write_text(t)

print("FIRST_FIRE_EXPEDITION_PATCH_OK")
