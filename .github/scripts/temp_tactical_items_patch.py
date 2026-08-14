from pathlib import Path

ROOT = Path('.')

def text(path): return (ROOT / path).read_text()
def write(path, value): (ROOT / path).write_text(value)
def replace_once(path, old, new):
    s = text(path)
    if s.count(old) != 1:
        raise SystemExit(f'{path}: expected one match, found {s.count(old)} for {old[:100]!r}')
    write(path, s.replace(old, new, 1))

# Data-driven unlock tiers. Later zones accumulate earlier pools, so rare/advanced
# equipment enters the physical field-loot table without replacing common finds.
replace_once(
    'game/scripts/FFData.gd',
    '''    "Reinforced Pack": {"slot": "Pack", "capacity": 12, "size": 0},\n}\n\nconst RECIPES := {\n''',
    '''    "Reinforced Pack": {"slot": "Pack", "capacity": 12, "size": 0},\n}\n\nconst TACTICAL_GEAR_UNLOCKS_BY_ZONE := {\n    "Camp Perimeter": [\n        "Utility Knife", "Kitchen Knife", "Wooden Club", "Flashlight", "Glow Stick",\n        "Road Flare", "Screwdriver Set", "Work Gloves", "Worn Backpack",\n        "School Backpack", "Improvised Pack"\n    ],\n    "Nearby Streets": [\n        "Baseball Bat", "Hammer", "Headlamp", "Lantern", "Pry Tool",\n        "Work Jacket", "Heavy Boots", "First Aid Kit"\n    ],\n    "Residential Blocks": [\n        "Crowbar", "Hatchet", "Toolbox", "Padded Jacket", "Leather Jacket",\n        "Hiking Pack"\n    ],\n    "Commercial Fringe": ["Bolt Cutters", "Reinforced Pack", "Pistol"],\n    "Industrial Edge": ["Shotgun"],\n}\n\nconst RECIPES := {\n'''
)

# Visual descriptor: weapons and portable lights use their authored atlas art;
# other slots get a compact slot badge while the full item name is rendered by
# the tactical board/HUD.
replace_once(
    'game/scripts/FFTacticalVisuals.gd',
    'const Tiles = preload("res://scripts/FFTacticalTiles.gd")\n',
    'const Tiles = preload("res://scripts/FFTacticalTiles.gd")\nconst D = preload("res://scripts/FFData.gd")\n'
)
replace_once(
    'game/scripts/FFTacticalVisuals.gd',
    '''static func equipment_summary_lines(equipment: Dictionary) -> Array:\n''',
    '''static func field_gear_visual(name: String) -> Dictionary:\n    var weapon := weapon_visual(name)\n    if int(weapon.get("atlas", -1)) >= 0:\n        return {"atlas": int(weapon["atlas"]), "badge": "W", "slot": "Weapon"}\n    var item_atlas := Tiles.item_region(name)\n    if item_atlas >= 0:\n        return {"atlas": item_atlas, "badge": "S", "slot": "Secondary"}\n    var slot := str(D.GEAR.get(name, {}).get("slot", ""))\n    return {\n        "atlas": -1,\n        "badge": {"Tool": "T", "Clothing": "C", "Pack": "P"}.get(slot, "?"),\n        "slot": slot,\n    }\n\nstatic func equipment_summary_lines(equipment: Dictionary) -> Array:\n'''
)

# Game chooses the gear once when the encounter context is created; save/resume
# therefore cannot reroll it. A pickup is only committed after successful escape.
replace_once(
    'game/scripts/Game.gd',
    '''func _pick_tactical_kind(zone):\n    return TacticalScenarios.pick_kind(str(zone), rng)\n\nfunc _combat_condition_hp(s):\n''',
    '''func _pick_tactical_kind(zone):\n    return TacticalScenarios.pick_kind(str(zone), rng)\n\nfunc _tactical_gear_pool(zone: String) -> Array:\n    var pool: Array = []\n    var zone_index := D.ZONE_ORDER.find(zone)\n    if zone_index < 0:\n        zone_index = 0\n    for i in range(zone_index + 1):\n        var tier_zone := str(D.ZONE_ORDER[i])\n        pool.append_array(Array(D.TACTICAL_GEAR_UNLOCKS_BY_ZONE.get(tier_zone, [])))\n    return pool\n\nfunc _pick_tactical_gear(zone: String) -> String:\n    var pool := _tactical_gear_pool(zone)\n    if pool.is_empty():\n        return ""\n    return str(pool[rng.randi_range(0, pool.size() - 1)])\n\nfunc _combat_condition_hp(s):\n'''
)
replace_once(
    'game/scripts/Game.gd',
    '''        "location_name": TacticalScenarios.environment_name(environment_id),\n        "seed": rng.randi_range(1, 2147483000),\n        "runtime": {\n''',
    '''        "location_name": TacticalScenarios.environment_name(environment_id),\n        "field_gear": _pick_tactical_gear(str(exp["zone"])) if combat_kind == "explore" else "",\n        "seed": rng.randi_range(1, 2147483000),\n        "runtime": {\n'''
)
replace_once(
    'game/scripts/Game.gd',
    '''    elif kind == "explore" and bool(result.get("objective_done", false)):\n        var reward = _grant_tactical_explore_reward(exp, lead)\n        _queue_field_result(event, "%s Searched" % place, "You searched the place under real pressure and got back out. Extra find: %s." % reward, "The party searched %s tactically and escaped." % place)\n''',
    '''    elif kind == "explore" and bool(result.get("objective_done", false)):\n        var reward := _grant_tactical_explore_reward(exp, lead)\n        var recovered_gear := str(result.get("field_gear", ""))\n        if recovered_gear != "" and D.GEAR.has(recovered_gear):\n            inventory_gear.append(recovered_gear)\n            reward = (reward + ", " if reward != "" else "") + recovered_gear\n        _queue_field_result(event, "%s Searched" % place, "You physically recovered the marked field loot and got back out. Find: %s." % reward, "The party searched %s tactically and escaped with %s." % [place, recovered_gear if recovered_gear != "" else "supplies"])\n'''
)

# Tactical board renders/reports the actual pickup and only sends it home in the
# result after the survivor reaches it and then escapes.
replace_once(
    'game/scripts/FFCombat.gd',
    '''    elif context.get("kind", "ambush") == "explore":\n        msg = "Search the marked spot, then escape."\n        submsg = "This is extra opportunity, not a requirement to clear the map."\n''',
    '''    elif context.get("kind", "ambush") == "explore":\n        var field_gear := str(context.get("field_gear", "Field Loot"))\n        msg = "Recover %s, then escape." % field_gear\n        submsg = "You only keep it if you physically reach it and get out alive."\n'''
)
replace_once(
    'game/scripts/FFCombat.gd',
    '''            else:\n                msg = "Search complete. Reach any exit."\n                emit_noise(target, 10, "rummaging", true)\n''',
    '''            else:\n                var field_gear := str(context.get("field_gear", "field loot"))\n                msg = "Recovered %s. Reach any exit." % field_gear\n                emit_noise(target, 10, "rummaging", true)\n'''
)
replace_once(
    'game/scripts/FFCombat.gd',
    '''        "rescued": objective_done and str(context.get("kind", "")) == "rescue",\n        "lead_hp": int(player.get("hp",0)), "lead_max_hp": int(player.get("max_hp",18)),\n''',
    '''        "rescued": objective_done and str(context.get("kind", "")) == "rescue",\n        "field_gear": str(context.get("field_gear", "")) if objective_done and str(context.get("kind", "")) == "explore" else "",\n        "lead_hp": int(player.get("hp",0)), "lead_max_hp": int(player.get("max_hp",18)),\n'''
)
replace_once(
    'game/scripts/FFCombat.gd',
    '''    if kind == "explore" and not objective_done:\n        draw_rect(Rect2(objective_cell.x*TILE+4,objective_cell.y*TILE+4,TILE-8,TILE-8), Color(.95,.75,.20), false, 3)\n''',
    '''    if kind == "explore" and not objective_done:\n        var objective_rect := Rect2(objective_cell.x*TILE+3, objective_cell.y*TILE+3, TILE-6, TILE-6)\n        draw_rect(objective_rect, Color(.95,.75,.20), false, 3)\n        var field_gear := str(context.get("field_gear", ""))\n        var visual: Dictionary = TacticalVisuals.field_gear_visual(field_gear)\n        var atlas_index := int(visual.get("atlas", -1))\n        var center := cell_center(objective_cell)\n        if atlas_index >= 0:\n            TacticalTiles.draw_region(self, atlas_index, Rect2(center - Vector2(9,9), Vector2(18,18)))\n        else:\n            draw_circle(center, 8.0, Color(.08,.10,.09,.92))\n            draw_circle(center, 8.0, Color(.95,.75,.20), false, 1.5)\n            draw_string(font, center + Vector2(-6,3), str(visual.get("badge", "?")), HORIZONTAL_ALIGNMENT_CENTER, 12, 9, Color(.98,.92,.70))\n        draw_string(font, center + Vector2(-52,-14), field_gear, HORIZONTAL_ALIGNMENT_CENTER, 104, 7, Color(.98,.86,.40))\n'''
)
replace_once(
    'game/scripts/FFCombat.gd',
    '''        "explore": objective_text = "SEARCH + ESCAPE" if not objective_done else "ESCAPE"\n''',
    '''        "explore":\n            var field_gear := str(context.get("field_gear", "LOOT"))\n            objective_text = ("TAKE %s + ESCAPE" % field_gear) if not objective_done else "ESCAPE"\n'''
)

# Smoke coverage: every gear item is in a physical field tier and every visual
# slot can produce a tactical representation.
replace_once(
    'game/scripts/ci/FFArchitectureSmoke.gd',
    '''    for gear_name in D.GEAR.keys():\n        if not _check(craftable_gear.has(gear_name), "craftable gear: %s" % gear_name): return\n    if not _check(D.BUILD_ORDER.size() == 15 and D.BUILDINGS.has("Dormitory") and D.BUILDINGS.has("Armory"), "final building tree"): return\n''',
    '''    var field_gear := {}\n    for zone_name in D.TACTICAL_GEAR_UNLOCKS_BY_ZONE.keys():\n        for gear_name in D.TACTICAL_GEAR_UNLOCKS_BY_ZONE[zone_name]:\n            field_gear[str(gear_name)] = true\n    for gear_name in D.GEAR.keys():\n        if not _check(craftable_gear.has(gear_name), "craftable gear: %s" % gear_name): return\n        if not _check(field_gear.has(gear_name), "physical tactical gear: %s" % gear_name): return\n    if not _check(int(TacticalVisuals.field_gear_visual("Flashlight").get("atlas", -1)) >= 0, "field secondary sprite"): return\n    if not _check(str(TacticalVisuals.field_gear_visual("First Aid Kit").get("badge", "")) == "T", "field tool badge"): return\n    if not _check(str(TacticalVisuals.field_gear_visual("Leather Jacket").get("badge", "")) == "C", "field clothing badge"): return\n    if not _check(str(TacticalVisuals.field_gear_visual("Hiking Pack").get("badge", "")) == "P", "field pack badge"): return\n    if not _check(D.BUILD_ORDER.size() == 15 and D.BUILDINGS.has("Dormitory") and D.BUILDINGS.has("Armory"), "final building tree"): return\n'''
)

# Player-facing docs/changelog: distinguish real physical loot from HUD-only gear.
replace_once(
    'CHANGELOG.md',
    '''- Tactical HUD now exposes all five equipment slots—Weapon, Secondary, Tool, Clothing and Pack—so every equipped item is visible during field play.\n- Added deterministic smoke coverage that every gear catalog entry has a crafting path, final building count is complete, social chatter can resolve, and tactical equipment summaries expose all slots.\n''',
    '''- Tactical HUD now exposes all five equipment slots—Weapon, Secondary, Tool, Clothing and Pack—so every equipped item is visible during field play.\n- Explore encounters now place a **real named gear pickup** on the tactical board. The survivor must physically reach it and still escape alive to bring it home. Weapons/portable lights use authored atlas icons; Tool/Clothing/Pack finds use readable slot badges plus the real item name.\n- Every current gear item belongs to a zone-tiered physical tactical loot pool, from common perimeter tools/packs through late Commercial/Industrial firearms.\n- Added deterministic smoke coverage that every gear catalog entry has both a crafting path and a physical tactical loot path, final building count is complete, social chatter can resolve, and tactical equipment summaries expose all slots.\n'''
)
replace_once(
    'ROADMAP.md',
    '''The tactical HUD must expose all five equipment slots: Weapon, Secondary, Tool, Clothing and Pack.\n\nFuture work here is balance/art/readability, not introducing a second inventory system.\n''',
    '''The tactical HUD exposes all five equipment slots: Weapon, Secondary, Tool, Clothing and Pack. Explore objectives also place a real named gear pickup on the board; it is only retained after physical recovery and successful escape. Every current gear catalog entry belongs to a zone-tiered field-loot pool.\n\nFuture work here is balance/art/readability, not introducing a second inventory system.\n'''
)
replace_once(
    'README_CONTEXT.md',
    '''For Alpha 0.3E playtesting, every new founder starts with a **Flashlight equipped in Secondary** so day/night and blackout tactical lighting can always be exercised immediately. Save schema 7 is the final planned Alpha invalidation before Beta save stability. Every new founder still starts with a Flashlight equipped in Secondary.\n''',
    '''For Alpha/Beta-candidate playtesting, every new founder starts with a **Flashlight equipped in Secondary** so day/night and blackout tactical lighting can always be exercised immediately. Save schema 7 is the final planned Alpha invalidation before Beta save stability. Explore tactical objectives now expose real named gear pickups from a zone-tiered catalog; a pickup is only committed to camp inventory after the survivor reaches it and escapes alive.\n'''
)

print('physical tactical gear pass prepared')
