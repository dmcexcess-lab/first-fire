from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


# Give the starting zone its own tactical content instead of falling back to
# Industrial Edge definitions. Perimeter tactical runs intentionally exclude
# rescue encounters; early recruitment remains governed by its dedicated rules.
p = Path("game/scripts/FFTacticalScenarios.gd")
t = p.read_text()
t = replace_once(
    t,
    '''const KIND_WEIGHTS := {
    "Nearby Streets": [["rescue", 0.35], ["explore", 0.70], ["ambush", 1.00]],
''',
    '''const KIND_WEIGHTS := {
    "Camp Perimeter": [["explore", 0.65], ["ambush", 1.00]],
    "Nearby Streets": [["rescue", 0.35], ["explore", 0.70], ["ambush", 1.00]],
''',
    "camp tactical kind catalog",
)
t = replace_once(
    t,
    '''const LOCATIONS_BY_ZONE := {
    "Nearby Streets": ["Corner Store", "Abandoned Duplex", "Bus Stop Shops", "Detached Garage"],
''',
    '''const LOCATIONS_BY_ZONE := {
    "Camp Perimeter": ["Vacant Lot", "Drainage Wash", "Abandoned Shed", "Edge Street"],
    "Nearby Streets": ["Corner Store", "Abandoned Duplex", "Bus Stop Shops", "Detached Garage"],
''',
    "camp tactical locations",
)
p.write_text(t)


# Once an expedition has already been selected to become tactical, reaching its
# trigger point must not allow the normal completion path to skip the encounter
# merely because another narrative overlay is temporarily open.
p = Path("game/scripts/Game.gd")
t = p.read_text()
t = replace_once(
    t,
    '''        exp["remaining"] = max(0.0, float(exp["remaining"]) - delta)
        if exp.get("combat_kind", "") != "" and not exp.get("combat_triggered", false) and float(exp["remaining"]) <= float(exp.get("combat_trigger_remaining", -1.0)) and current_combat.is_empty() and current_event.is_empty():
            _begin_tactical_encounter(exp)
            continue
        if exp.get("event_key", "") != "" and not exp.get("event_triggered", false) and float(exp["remaining"]) <= float(exp["event_trigger_remaining"]):
''',
    '''        exp["remaining"] = max(0.0, float(exp["remaining"]) - delta)
        var tactical_due = exp.get("combat_kind", "") != "" and not exp.get("combat_triggered", false) and float(exp["remaining"]) <= float(exp.get("combat_trigger_remaining", -1.0))
        if tactical_due:
            if current_combat.is_empty() and current_event.is_empty():
                _begin_tactical_encounter(exp)
            else:
                # Hold at the encounter point until the tactical board can open.
                # Never silently finish a run that was already assigned combat.
                exp["remaining"] = maxf(0.01, float(exp.get("combat_trigger_remaining", 0.01)))
            continue
        if exp.get("event_key", "") != "" and not exp.get("event_triggered", false) and float(exp["remaining"]) <= float(exp["event_trigger_remaining"]):
''',
    "tactical trigger completion guard",
)
p.write_text(t)


# Regression contract: starting zone must own actual scenario data, not just a
# nonzero roll chance.
p = Path("game/scripts/ci/FFArchitectureSmoke.gd")
t = p.read_text()
marker = '    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Residential Blocks"), "scenario catalog"): return\n'
t = replace_once(
    t,
    marker,
    marker + '    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Camp Perimeter"), "starting zone scenario catalog"): return\n    if not _check(TacticalScenarios.LOCATIONS_BY_ZONE.has("Camp Perimeter"), "starting zone tactical locations"): return\n',
    "starting zone tactical smoke checks",
)
p.write_text(t)


# Record the additional reliability fix in the existing top changelog entry.
p = Path("CHANGELOG.md")
t = p.read_text()
marker = '- Added drought protection: after two consecutive normal field runs without tactical combat, the next normal run is forced tactical.\n'
t = replace_once(
    t,
    marker,
    marker + '- Camp Perimeter now has its own explore/ambush scenario mix and perimeter-specific location names instead of falling through to Industrial Edge content.\n- A tactical run that reaches its encounter point while another narrative overlay is open now waits there; it can no longer silently complete before the tactical board opens.\n',
    "changelog tactical reliability detail",
)
p.write_text(t)

print("FIRST_FIRE_TACTICAL_TRIGGER_GUARD_OK")
