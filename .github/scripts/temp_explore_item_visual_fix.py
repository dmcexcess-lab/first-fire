from pathlib import Path

path = Path('game/scripts/FFCombat.gd')
text = path.read_text()

old_intro = '''    elif context.get("kind", "ambush") == "explore":
        var field_gear := str(context.get("field_gear", "Field Loot"))
        msg = "Recover %s, then escape." % field_gear
        submsg = "You only keep it if you physically reach it and get out alive."
'''
new_intro = '''    elif context.get("kind", "ambush") == "explore":
        var field_gear := str(context.get("field_gear", "Field Loot"))
        msg = "Search the marked spots for %s." % field_gear
        submsg = "Each search takes time and makes noise. Leave whenever survival matters more."
'''
if old_intro not in text:
    raise SystemExit('missing explore intro')
text = text.replace(old_intro, new_intro, 1)

old_draw = '''func draw_explore_sites() -> void:
    for cell in explore_cells:
        var center := cell_center(cell)
        var searched := explore_searched.has(cell)
        var known := visible_cells.has(cell) or memory.has(cell)
        var alpha := 0.96 if known else 0.38
        var color := Color(0.28, 0.88, 0.48, alpha) if searched else Color(0.95, 0.75, 0.20, alpha)
        draw_rect(Rect2(cell.x * TILE + 4, cell.y * TILE + 4, TILE - 8, TILE - 8), color, false, 2)
        var label := "GEAR" if searched and cell == explore_gear_cell else ("DONE" if searched else "?")
        draw_string(font, center + Vector2(-14, 3), label, HORIZONTAL_ALIGNMENT_CENTER, 28, 8, color)
'''
new_draw = '''func draw_explore_sites() -> void:
    for cell in explore_cells:
        var center := cell_center(cell)
        var searched := explore_searched.has(cell)
        var known := visible_cells.has(cell) or memory.has(cell)
        var alpha := 0.96 if known else 0.38
        var color := Color(0.28, 0.88, 0.48, alpha) if searched else Color(0.95, 0.75, 0.20, alpha)
        draw_rect(Rect2(cell.x * TILE + 4, cell.y * TILE + 4, TILE - 8, TILE - 8), color, false, 2)
        if searched and cell == explore_gear_cell:
            var field_gear := str(context.get("field_gear", ""))
            var visual: Dictionary = TacticalVisuals.field_gear_visual(field_gear)
            var atlas_index := int(visual.get("atlas", -1))
            if atlas_index >= 0:
                TacticalTiles.draw_region(self, atlas_index, Rect2(center - Vector2(9, 9), Vector2(18, 18)))
            else:
                draw_circle(center, 8.0, Color(.08, .10, .09, .92))
                draw_string(font, center + Vector2(-6, 3), str(visual.get("badge", "?")), HORIZONTAL_ALIGNMENT_CENTER, 12, 9, Color(.98, .92, .70))
            draw_string(font, center + Vector2(-48, -14), field_gear, HORIZONTAL_ALIGNMENT_CENTER, 96, 7, Color(.98, .86, .40))
        else:
            var label := "DONE" if searched else "?"
            draw_string(font, center + Vector2(-14, 3), label, HORIZONTAL_ALIGNMENT_CENTER, 28, 8, color)
'''
if old_draw not in text:
    raise SystemExit('missing explore draw helper')
text = text.replace(old_draw, new_draw, 1)
path.write_text(text)
Path('.github/scripts/temp_explore_item_visual_fix.py').unlink()
print('FIRST_FIRE_EXPLORE_ITEM_VISUAL_FIX_OK')
