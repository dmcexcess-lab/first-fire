from pathlib import Path

def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected 1 match, found {count} for {old[:80]!r}")
    p.write_text(text.replace(old, new, 1))

replace_once(
    "game/scripts/FFExpeditionRules.gd",
    'const TACTICAL_EVENT_SHARE := 0.55\n',
    """const TACTICAL_EVENT_CHANCE := {
    "Camp Perimeter": 0.0,
    "Nearby Streets": 0.55,
    "Residential Blocks": 0.65,
    "Commercial Fringe": 0.75,
    "Industrial Edge": 0.85,
}
"""
)
replace_once(
    "game/scripts/FFExpeditionRules.gd",
    """static func should_use_tactical_event(zone: String, rng: RandomNumberGenerator) -> bool:
    return zone != "Camp Perimeter" and rng.randf() < TACTICAL_EVENT_SHARE
""",
    """static func tactical_event_chance(zone: String) -> float:
    return float(TACTICAL_EVENT_CHANCE.get(zone, 0.0))

static func should_trigger_tactical_event(zone: String, rng: RandomNumberGenerator) -> bool:
    return rng.randf() < tactical_event_chance(zone)
"""
)

replace_once(
    "game/scripts/FFCampLifeRules.gd",
    'const NEW_GAME_EVENT_COOLDOWN := 20.0\n',
    """const NEW_GAME_EVENT_COOLDOWN := 20.0
const FATIGUE_GAIN_MULTIPLIER := 2.0

static func fatigue_gain(base_amount: float) -> float:
    return maxf(0.0, base_amount) * FATIGUE_GAIN_MULTIPLIER
"""
)

replace_once(
    "game/scripts/Game.gd",
    's["fatigue"] = min(100.0, float(s["fatigue"]) + float(recipe["time"]) / 5.0)',
    's["fatigue"] = min(100.0, float(s["fatigue"]) + CampLifeRules.fatigue_gain(float(recipe["time"]) / 5.0))'
)
replace_once(
    "game/scripts/Game.gd",
    's["fatigue"] = min(100.0, float(s["fatigue"]) + float(data["time"]) / 5.0)',
    's["fatigue"] = min(100.0, float(s["fatigue"]) + CampLifeRules.fatigue_gain(float(data["time"]) / 5.0))'
)
replace_once(
    "game/scripts/Game.gd",
    """    s["status"] = "Tending"
    s["task"] = {"kind": "garden", "remaining": _work_duration(s, 8.0), "duration": 8.0}
""",
    """    s["status"] = "Tending"
    s["fatigue"] = min(100.0, float(s["fatigue"]) + CampLifeRules.fatigue_gain(4.0))
    s["task"] = {"kind": "garden", "remaining": _work_duration(s, 8.0), "duration": 8.0}
"""
)

replace_once(
    "game/scripts/Game.gd",
    """    elif event_key == "" and rng.randf() < float(D.ZONES[zone]["event_chance"]):
        # Keep text encounters alive, but let a little over half of random field
        # encounters become playable tactical situations outside the perimeter.
        if ExpeditionRules.should_use_tactical_event(zone, rng):
            combat_kind = _pick_tactical_kind(zone)
        else:
            event_key = _select_field_event(zone)
""",
    """    elif event_key == "" and ExpeditionRules.should_trigger_tactical_event(str(zone), rng):
        # Alpha 0.3 tactical encounters have their own explicit pop rate so they
        # are common enough to playtest instead of being double-gated by legacy events.
        combat_kind = _pick_tactical_kind(zone)
    elif event_key == "" and rng.randf() < float(D.ZONES[zone]["event_chance"]):
        # Temporary legacy text events only roll when no tactical encounter fired.
        event_key = _select_field_event(zone)
"""
)

replace_once(
    "game/scripts/Game.gd",
    'lead["fatigue"] = min(100.0, float(lead["fatigue"]) + 6.0)',
    'lead["fatigue"] = min(100.0, float(lead["fatigue"]) + CampLifeRules.fatigue_gain(6.0))'
)
replace_once(
    "game/scripts/Game.gd",
    'companion["fatigue"] = min(100.0, float(companion["fatigue"]) + 4.0)',
    'companion["fatigue"] = min(100.0, float(companion["fatigue"]) + CampLifeRules.fatigue_gain(4.0))'
)
replace_once(
    "game/scripts/Game.gd",
    's["fatigue"] = min(100.0, float(s["fatigue"]) + float(D.ZONES[zone]["fatigue"]))',
    's["fatigue"] = min(100.0, float(s["fatigue"]) + CampLifeRules.fatigue_gain(float(D.ZONES[zone]["fatigue"])))'
)
replace_once(
    "game/scripts/Game.gd",
    'helper["fatigue"] = min(100.0, float(helper["fatigue"]) + 8.0)',
    'helper["fatigue"] = min(100.0, float(helper["fatigue"]) + CampLifeRules.fatigue_gain(8.0))'
)

replace_once(
    "game/scripts/Main.gd",
    'const PAUSE_BG := "res://assets/pause_bg.png"',
    'const MAIN_MENU_BG := "res://assets/menu_bg.jpg"'
)
replace_once(
    "game/scripts/Main.gd",
    'bg_tex.texture = load(PAUSE_BG)',
    'bg_tex.texture = load(MAIN_MENU_BG)'
)

replace_once(
    "game/scripts/ci/FFArchitectureSmoke.gd",
    """    if not _check(ExpeditionRules.should_force_recruit(1, 1, 5, true), "solo recruit protection"): return
    if not _check(not ExpeditionRules.should_force_recruit(1, 1, 4, true), "solo recruit threshold"): return
""",
    """    if not _check(ExpeditionRules.should_force_recruit(1, 1, 5, true), "solo recruit protection"): return
    if not _check(not ExpeditionRules.should_force_recruit(1, 1, 4, true), "solo recruit threshold"): return
    if not _check(abs(ExpeditionRules.tactical_event_chance("Nearby Streets") - 0.55) < 0.001, "nearby tactical pop rate"): return
    if not _check(abs(ExpeditionRules.tactical_event_chance("Industrial Edge") - 0.85) < 0.001, "industrial tactical pop rate"): return
"""
)
replace_once(
    "game/scripts/ci/FFArchitectureSmoke.gd",
    """    var rates := CampLifeRules.idle_recovery_rates(true, false)
    if not _check(rates.x > 0.0 and rates.y > 0.0, "camp recovery rules"): return
""",
    """    var rates := CampLifeRules.idle_recovery_rates(true, false)
    if not _check(rates.x > 0.0 and rates.y > 0.0, "camp recovery rules"): return
    if not _check(abs(CampLifeRules.fatigue_gain(5.0) - 10.0) < 0.001, "fatigue gain multiplier"): return
"""
)

context_path = Path("README_CONTEXT.md")
context = context_path.read_text()
marker = "## Saves\n"
insert = """## Current Alpha 0.3A playtest tuning

- Tactical encounter chance now rolls independently from legacy text events: **55% Nearby / 65% Residential / 75% Commercial / 85% Industrial**. Camp Perimeter remains non-tactical.
- Fatigue gains from expeditions, tactical encounters, crafting/building, and garden work are currently **2×** their original Alpha values. Idle recovery rates are unchanged.

"""
if insert not in context:
    if marker not in context:
        raise SystemExit("README_CONTEXT.md: Saves marker missing")
    context_path.write_text(context.replace(marker, insert + marker, 1))

changelog_path = Path("CHANGELOG.md")
changelog = changelog_path.read_text()
heading = "## Alpha 0.3A — Encounter, Fatigue & Menu Tuning — 2026-08-13\n"
section = """## Alpha 0.3A — Encounter, Fatigue & Menu Tuning — 2026-08-13

### Tactical Encounters
- Tactical encounters now roll independently from the temporary legacy text-event chance instead of being double-gated.
- Alpha playtest rates are now 55% on Nearby Streets, 65% in Residential Blocks, 75% on the Commercial Fringe, and 85% at the Industrial Edge.
- Camp Perimeter remains a routine non-tactical scavenging zone.
- Legacy text field events can still occur when a tactical encounter does not fire; they remain temporary pending the planned all-tactical field conversion.

### Fatigue
- Added one central fatigue-gain multiplier in `FFCampLifeRules.gd`.
- Fatigue gained from normal expeditions, tactical encounters, crafting, building, and garden tending is now doubled.
- Automatic idle fatigue recovery is unchanged, so repeated work/runs should now create meaningful exhaustion pressure.

### Main Menu
- Replaced the previous main-menu zombie art with the newly generated darker PG-13 survival-horror zombie background.
- The new art is stored as a Web/mobile-friendly JPEG to keep the browser payload modest.

"""
if heading not in changelog:
    intro = "This file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n"
    if intro not in changelog:
        raise SystemExit("CHANGELOG intro missing")
    changelog_path.write_text(changelog.replace(intro, intro + section, 1))

Path(".tmp/apply_tuning.py").unlink()
