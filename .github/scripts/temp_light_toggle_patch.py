from pathlib import Path

combat_path = Path('game/scripts/FFCombat.gd')
smoke_path = Path('game/scripts/ci/FFArchitectureSmoke.gd')
changelog_path = Path('CHANGELOG.md')
workflow_path = Path('.github/workflows/temp-light-toggle.yml')
script_path = Path('.github/scripts/temp_light_toggle_patch.py')

combat = combat_path.read_text()
repls = [
('var lighting_redraw_accum := 0.0\n', 'var lighting_redraw_accum := 0.0\nvar player_light_on := true\n'),
('var btn_shove := Rect2(148, 744, 98, 42)\n', 'var btn_shove := Rect2(148, 744, 98, 42)\nvar btn_light := Rect2(148, 700, 98, 40)\n'),
('    player["guarding"] = bool(runtime.get("guarding", false))\n', '    player["guarding"] = bool(runtime.get("guarding", false))\n    player_light_on = bool(runtime.get("player_light_on", true))\n'),
('        "guarding": bool(player.get("guarding", false)),\n', '        "guarding": bool(player.get("guarding", false)),\n        "player_light_on": player_light_on,\n'),
('            KEY_X: shove()\n            KEY_F, KEY_SPACE: interact()\n', '            KEY_X: shove()\n            KEY_L: toggle_player_light()\n            KEY_F, KEY_SPACE: interact()\n'),
('    if btn_guard.has_point(pos): guard(); return\n    if btn_shove.has_point(pos): shove(); return\n', '    if btn_guard.has_point(pos): guard(); return\n    if btn_light.has_point(pos): toggle_player_light(); return\n    if btn_shove.has_point(pos): shove(); return\n'),
('func guarded_action(action: String, callable: Callable):\n', 'func toggle_player_light() -> void:\n    var item := str(player.get("secondary", ""))\n    if not TacticalLighting.item_emits_light(item):\n        msg = "No portable light equipped."\n        queue_redraw()\n        return\n    player_light_on = not player_light_on\n    msg = "%s %s." % [item, "on" if player_light_on else "off"]\n    recalc_visibility()\n    refresh_intents()\n    persist_runtime()\n    queue_redraw()\n\nfunc guarded_action(action: String, callable: Callable):\n'),
('            if scene_time == "day" and indoors:\n                for window_pos in glass.keys():\n                    if not line_clear(window_pos, cell): continue\n                    var daylight := TacticalLighting.window_daylight_contribution(window_pos, cell)\n', '            if TacticalLighting.daylight_available(scene_time) and indoors:\n                for window_pos in glass.keys():\n                    if not line_clear(window_pos, cell): continue\n                    var daylight := TacticalLighting.window_daylight_contribution(window_pos, cell, TacticalLighting.daylight_strength(scene_time))\n'),
('            if TacticalLighting.item_emits_light(player_light) and line_clear(player.pos, cell):\n', '            if player_light_on and TacticalLighting.item_emits_light(player_light) and line_clear(player.pos, cell):\n'),
('    r += TacticalLighting.item_view_bonus(str(player.get("secondary", "")))\n', '    if player_light_on:\n        r += TacticalLighting.item_view_bonus(str(player.get("secondary", "")))\n'),
('        if TacticalLighting.item_emits_light(str(player.get("secondary", ""))): awareness += 0.5\n', '        if player_light_on and TacticalLighting.item_emits_light(str(player.get("secondary", ""))): awareness += 0.5\n'),
('    draw_button(btn_guard,"GUARD",bool(player.get("guarding", false)),10)\n    draw_button(btn_shove,"SHOVE",false,10)\n', '    draw_button(btn_guard,"GUARD",bool(player.get("guarding", false)),10)\n    var portable_light := str(player.get("secondary", ""))\n    var has_portable_light := TacticalLighting.item_emits_light(portable_light)\n    draw_button(btn_light,"LIGHT ON" if player_light_on else "LIGHT OFF",has_portable_light and player_light_on,9)\n    draw_button(btn_shove,"SHOVE",false,10)\n'),
]
for old, new in repls:
    if old not in combat:
        raise SystemExit(f'missing FFCombat seam: {old[:80]!r}')
    combat = combat.replace(old, new, 1)
combat_path.write_text(combat)

smoke = smoke_path.read_text()
needle = '    if not _check(TacticalLighting.item_contribution(Vector2i(5, 5), Vector2i(1, 0), Vector2i(2, 5), "Flashlight") == 0.0, "flashlight rear cutoff"): return\n'
insert = needle + '    var combat_source := FileAccess.get_file_as_string("res://scripts/FFCombat.gd")\n    if not _check(combat_source.contains("func toggle_player_light()"), "portable light tactical toggle"): return\n    if not _check(combat_source.contains("\\\"player_light_on\\\": player_light_on"), "portable light state persists"): return\n    if not _check(combat_source.contains("KEY_L: toggle_player_light()"), "portable light keyboard fallback"): return\n'
if needle not in smoke:
    raise SystemExit('missing smoke seam')
smoke_path.write_text(smoke.replace(needle, insert, 1))

changelog = changelog_path.read_text()
entry = '''## Beta Candidate — Tactical Clock & Portable Light Control — 2026-09-11\n\n- Tactical encounters now use the settlement clock at encounter creation, exposing DAWN / DAY / DUSK / NIGHT instead of an unrelated random day/night roll.\n- Dawn and dusk use intermediate ambient/daylight strength, and the tactical location header carries the encounter clock time.\n- Equipped Secondary lights now have an explicit touch-safe LIGHT ON / LIGHT OFF control plus an `L` keyboard fallback. Switching a light is immediate, recalculates visibility/detectability, and persists across tactical save/resume without advancing tactical time.\n- Portable-light view bonuses and sound-awareness assistance only apply while the light is switched on.\n- Save schema remains 7; the added tactical runtime flag is additive.\n\n'''
if not changelog.startswith('## Beta Candidate — Tactical Clock & Portable Light Control'):
    changelog_path.write_text(entry + changelog)

workflow_path.unlink(missing_ok=True)
script_path.unlink(missing_ok=True)
