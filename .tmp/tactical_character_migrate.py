from pathlib import Path

DRAW_BLOCK = 'func draw_units():\n    for key in last_seen.keys():\n        var i := int(key)\n        if i < 0 or i >= zombies.size() or zombies[i].dead or visible_cells.has(zombies[i].pos):\n            continue\n        var c := cell_center(last_seen[i])\n        draw_circle(c, 8, Color(.55, .58, .55, .5), false, 2)\n        draw_string(font, c + Vector2(-10, -11), "LAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(.65, .68, .65, .75))\n\n    for i in range(zombies.size()):\n        var z: Dictionary = zombies[i]\n        if z.dead:\n            if visible_cells.has(z.pos):\n                TacticalVisuals.draw_zombie_corpse(self, cell_center(z.pos), z)\n            continue\n        if not visible_cells.has(z.pos):\n            continue\n        TacticalVisuals.draw_zombie(self, cell_center(z.pos), z)\n        var c := cell_center(z.pos)\n        if zombie_sees_actor(z, player):\n            draw_circle(c, 12, Color(1, .17, .12, .92), false, 2)\n        else:\n            var intent_text := str(intent_reads.get(i, "?"))\n            if intent_text != "":\n                draw_string(font, c + Vector2(-16, -12), intent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, .84, .35))\n\n    if not ally.is_empty() and visible_cells.has(ally.pos):\n        if ally.dead:\n            TacticalVisuals.draw_survivor_corpse(self, cell_center(ally.pos), ally)\n        else:\n            TacticalVisuals.draw_survivor(self, cell_center(ally.pos), ally, false)\n\n    if not player.is_empty():\n        TacticalVisuals.draw_survivor(self, cell_center(player.pos), player, true)\n\nfunc _flash_hit(cell: Vector2i, lethal := false):\n    hit_flash_cell = cell\n    hit_flash_until_ms = Time.get_ticks_msec() + (170 if lethal else 110)\n    fx_active_last_frame = true\n    queue_redraw()\n\nfunc _flash_muzzle(cell: Vector2i, facing: Vector2i):\n    muzzle_flash_cell = cell\n    muzzle_flash_facing = facing\n    muzzle_flash_until_ms = Time.get_ticks_msec() + 90\n    fx_active_last_frame = true\n    queue_redraw()\n\nfunc draw_character_fx():\n    var now := Time.get_ticks_msec()\n    if hit_flash_cell != Vector2i(-1, -1):\n        TacticalVisuals.draw_hit_flash(self, cell_center(hit_flash_cell), now, hit_flash_until_ms)\n    if muzzle_flash_cell != Vector2i(-1, -1):\n        TacticalVisuals.draw_muzzle_flash(self, cell_center(muzzle_flash_cell), muzzle_flash_facing, now, muzzle_flash_until_ms)\n\n'
CHANGELOG_SECTION = '## Alpha 0.3A — Tactical Character Graphics — 2026-08-13\n\n### Survivors\n- Tactical survivors now use persistent modular appearances generated when the survivor is created, including body build, skin tone, hair, clothing palette, accent color, and optional headwear.\n- The same survivor keeps the same tactical identity across encounters instead of reverting to a generic colored circle.\n- Lead and companion survivors retain distinct selection rings, readable facing, backpacks when equipped, and now render as small top-down people rather than tokens.\n- Equipped weapons render as separate silhouettes floating beside the survivor and rotate with facing. Knives, clubs/bats, hammer, spear, crowbar, hatchet, pistol, and shotgun have distinct shapes.\n\n### Infected\n- Infected now vary visually across civilian, worker, service/retail, medical, decayed, and heavy silhouettes.\n- Zone weighting makes industrial areas favor worker/heavy looks, commercial areas favor service looks, and residential areas favor civilian/decayed looks.\n- These are cosmetic families only in 0.3A; zombie combat behavior/stats were not rebalanced.\n- Dead infected now remain as visible corpse silhouettes rather than red X markers.\n\n### Combat Feedback\n- Melee/firearm hits get a brief impact flash.\n- Firearms get a short muzzle-flash effect.\n- Companion attacks and infected hits use the same visual feedback language.\n- Character art is procedural/vector-style for now, keeping Web/mobile payload small while allowing authored sprite layers later.\n\n### Persistence / Architecture\n- Added `FFTacticalVisuals.gd` as the presentation-data owner for survivor appearance, zombie visual families, and weapon silhouettes.\n- Survivor appearance is now persistent state, so save schema advanced to **4**. Older Alpha saves are intentionally invalidated rather than migrated.\n\n'

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing anchor: {label}")
    return text.replace(old, new, 1)

path = Path("game/scripts/Game.gd")
text = path.read_text()
text = replace_once(text, 'const CampSocial = preload("res://scripts/FFCampSocial.gd")\n', 'const CampSocial = preload("res://scripts/FFCampSocial.gd")\nconst TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\n', "Game visual preload")
text = replace_once(text, 'const SAVE_SCHEMA_VERSION := 3', 'const SAVE_SCHEMA_VERSION := 4', "save schema")
text = replace_once(text, '        "equipment": {"Weapon": "", "Clothing": "", "Pack": "", "Tool": ""},\n', '        "equipment": {"Weapon": "", "Clothing": "", "Pack": "", "Tool": ""},\n        "appearance": {},\n', "survivor appearance slot")
text = replace_once(text, '    s["name"] = "%s %s" % [D.FIRST_NAMES[rng.randi_range(0, D.FIRST_NAMES.size() - 1)], D.LAST_NAMES[rng.randi_range(0, D.LAST_NAMES.size() - 1)]]\n', '    s["name"] = "%s %s" % [D.FIRST_NAMES[rng.randi_range(0, D.FIRST_NAMES.size() - 1)], D.LAST_NAMES[rng.randi_range(0, D.LAST_NAMES.size() - 1)]]\n    s["appearance"] = TacticalVisuals.survivor_appearance(rng)\n', "appearance generation")
text = replace_once(text, '"version": "0.2.0"', '"version": "0.3.0"', "save version")
path.write_text(text)

path = Path("game/scripts/FFCombat.gd")
text = path.read_text()
text = replace_once(text, 'const D = preload("res://scripts/FFData.gd")\n', 'const D = preload("res://scripts/FFData.gd")\nconst TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\n', "combat visual preload")
text = replace_once(text, 'var initialized := false\n\nvar btn_turn_left', 'var initialized := false\nvar hit_flash_cell := Vector2i(-1, -1)\nvar hit_flash_until_ms := -1\nvar muzzle_flash_cell := Vector2i(-1, -1)\nvar muzzle_flash_facing := Vector2i(1, 0)\nvar muzzle_flash_until_ms := -1\nvar fx_active_last_frame := false\n\nvar btn_turn_left', "combat fx state")
text = replace_once(text, '    set_process_input(true)\n    visible = false\n\nfunc start_encounter', '    set_process_input(true)\n    set_process(true)\n    visible = false\n\nfunc _process(_delta):\n    if not initialized:\n        return\n    var now := Time.get_ticks_msec()\n    var active := now < hit_flash_until_ms or now < muzzle_flash_until_ms\n    if active or fx_active_last_frame:\n        queue_redraw()\n    fx_active_last_frame = active\n\nfunc start_encounter', "combat fx process")
text = replace_once(text, '    last_guard_ms = -10000\n    tick = int(runtime.get("tick", 0))\n', '    last_guard_ms = -10000\n    hit_flash_cell = Vector2i(-1, -1)\n    hit_flash_until_ms = -1\n    muzzle_flash_cell = Vector2i(-1, -1)\n    muzzle_flash_until_ms = -1\n    fx_active_last_frame = false\n    tick = int(runtime.get("tick", 0))\n', "combat fx reset")
text = replace_once(text, '        "equipment": s.get("equipment", {}).duplicate(true),\n        "weapon": weapon_profile(str(s.get("equipment", {}).get("Weapon", ""))),\n', '        "equipment": s.get("equipment", {}).duplicate(true),\n        "appearance": s.get("appearance", TacticalVisuals.default_survivor_appearance(int(s.get("id", -1)))).duplicate(true),\n        "weapon": weapon_profile(str(s.get("equipment", {}).get("Weapon", ""))),\n', "actor appearance")
text = replace_once(text, '            "next": rng.randi_range(65, 170), "dead": false\n', '            "next": rng.randi_range(65, 170), "dead": false,\n            "look": TacticalVisuals.zombie_appearance(rng, zone)\n', "zombie appearance")
text = replace_once(text, '            zombies[i]["next"] = int(zsave.get("next", zombies[i].next))\n', '            zombies[i]["next"] = int(zsave.get("next", zombies[i].next))\n            if zsave.has("look"):\n                zombies[i]["look"] = zsave["look"].duplicate(true)\n', "restore zombie look")
text = replace_once(text, '            "next": int(z.next)\n', '            "next": int(z.next), "look": z.get("look", {}).duplicate(true)\n', "persist zombie look")
text = replace_once(text, '        zombies[zi].hp -= d\n        msg = "%s hit for %d%s."', '        zombies[zi].hp -= d\n        _flash_hit(z.pos, int(zombies[zi].hp) <= 0)\n        msg = "%s hit for %d%s."', "melee hit flash")
text = replace_once(text, '    stats.shots += 1\n    if rng.randf() <= chance:\n', '    stats.shots += 1\n    _flash_muzzle(player.pos, player.facing)\n    if rng.randf() <= chance:\n', "shoot muzzle flash")
text = replace_once(text, '        zombies[i].hp -= d\n        msg = "%s hits for %d."', '        zombies[i].hp -= d\n        _flash_hit(z.pos, int(zombies[i].hp) <= 0)\n        msg = "%s hits for %d."', "shoot hit flash")
text = replace_once(text, '    barrels.erase(cell)\n    stats.shots += 1\n    msg = "The container erupts."\n', '    barrels.erase(cell)\n    stats.shots += 1\n    _flash_muzzle(player.pos, player.facing)\n    _flash_hit(cell, true)\n    msg = "The container erupts."\n', "barrel flash")
text = replace_once(text, '        zombies[i].hp -= d\n        if zombies[i].hp <= 0: kill_zombie(i, false)\n    emit_noise(ally.pos', '        zombies[i].hp -= d\n        _flash_hit(zombies[i].pos, int(zombies[i].hp) <= 0)\n        if zombies[i].hp <= 0: kill_zombie(i, false)\n    emit_noise(ally.pos', "companion hit flash")
text = replace_once(text, '        target_actor.hp -= dmg\n        if target_actor.controlled:\n', '        target_actor.hp -= dmg\n        _flash_hit(target_actor.pos, int(target_actor.hp) <= 0)\n        if target_actor.controlled:\n', "survivor hit flash")
text = replace_once(text, '    draw_units()\n    draw_fog()\n    draw_sounds()\n', '    draw_units()\n    draw_fog()\n    draw_sounds()\n    draw_character_fx()\n', "draw character fx")
start = text.index('func draw_units():\n')
end = text.index('func draw_fog():\n', start)
text = text[:start] + DRAW_BLOCK + text[end:]
path.write_text(text)

path = Path("game/scripts/ci/FFArchitectureSmoke.gd")
text = path.read_text()
text = replace_once(text, 'const CampSocial = preload("res://scripts/FFCampSocial.gd")\n', 'const CampSocial = preload("res://scripts/FFCampSocial.gd")\nconst TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\n', "smoke visual preload")
text = replace_once(text, '    if not _check(CampSocial.relationship_label(70) == "Close", "social relationship bands"): return\n', '    if not _check(CampSocial.relationship_label(70) == "Close", "social relationship bands"): return\n    var visual_rng := RandomNumberGenerator.new()\n    visual_rng.seed = 12345\n    var survivor_look: Dictionary = TacticalVisuals.survivor_appearance(visual_rng)\n    if not _check(survivor_look.has("skin") and survivor_look.has("top") and survivor_look.has("body"), "survivor visual identity"): return\n    var zombie_look: Dictionary = TacticalVisuals.zombie_appearance(visual_rng, "Industrial Edge")\n    if not _check(str(zombie_look.get("family", "")) != "", "zombie visual family"): return\n    if not _check(str(TacticalVisuals.weapon_visual("Pistol").get("kind", "")) == "pistol", "weapon visual catalog"): return\n', "smoke visual assertions")
path.write_text(text)

path = Path(".github/workflows/pages.yml")
text = path.read_text()
text = replace_once(text, '          test -f game/scripts/FFCombat.gd\n', '          test -f game/scripts/FFCombat.gd\n          test -f game/scripts/FFTacticalVisuals.gd\n', "pages visual module check")
text = replace_once(text, "grep -q 'const SAVE_SCHEMA_VERSION := 3' game/scripts/Game.gd", "grep -q 'const SAVE_SCHEMA_VERSION := 4' game/scripts/Game.gd", "pages schema check")
path.write_text(text)

path = Path("README_SOPS.md")
text = path.read_text()
text = replace_once(text, '- `FFCombat.gd` — tactical runtime mechanics.\n', '- `FFCombat.gd` — tactical runtime mechanics.\n- `FFTacticalVisuals.gd` — tactical character appearance, zombie variation, weapon silhouettes, and character drawing; presentation only.\n', "SOP visual owner")
text = text.replace('Current schema: **3**.', 'Current schema: **4**.')
path.write_text(text)

path = Path("README_CONTEXT.md")
text = path.read_text()
text = text.replace('Current milestone: **Alpha 0.2 — Tactical Expedition Encounters**.', 'Current milestone: **Alpha 0.3A — Tactical Character Graphics**.')
text = replace_once(text, '`FFCombat.gd` owns tactical runtime mechanics. `FFTacticalScenarios.gd` owns what kind of physical situation/location/layout is created and is the intended Alpha 0.3/0.4 expansion seam.\n', '`FFCombat.gd` owns tactical runtime mechanics. `FFTacticalScenarios.gd` owns what kind of physical situation/location/layout is created and is the intended Alpha 0.3/0.4 expansion seam. `FFTacticalVisuals.gd` owns persistent survivor appearance generation, zombie visual families, weapon silhouettes, and character rendering; tactical mechanics remain in `FFCombat.gd`.\n\nSurvivors now keep persistent modular tactical appearances. Zombies use varied civilian/worker/service/medical/decayed/heavy visual families, while those families remain cosmetic until a future gameplay change explicitly says otherwise. Equipped weapons are drawn as separate readable silhouettes beside survivors.\n', "context tactical visuals")
text = text.replace('Current save schema: **3**.', 'Current save schema: **4**.')
path.write_text(text)

path = Path("ARCHITECTURE.md")
text = path.read_text()
text = replace_once(text, '### `FFTacticalScenarios.gd`\nTactical scenario/catalog ownership: encounter-kind weights, location catalogs, and layout selection. Alpha 0.3/0.4 should grow this toward data-driven physical versions of all outside-world events, authored chunks, objective combinations, hazards, human/survivor situations, and optional objectives.\n\n', '### `FFTacticalScenarios.gd`\nTactical scenario/catalog ownership: encounter-kind weights, location catalogs, and layout selection. Alpha 0.3/0.4 should grow this toward data-driven physical versions of all outside-world events, authored chunks, objective combinations, hazards, human/survivor situations, and optional objectives.\n\n### `FFTacticalVisuals.gd`\nTactical character presentation owner. Generates persistent survivor appearance dictionaries, zone-weighted infected visual families, weapon silhouettes, and the procedural character/corpse/impact drawing used by `FFCombat.gd`. It is presentation-only: infected visual families do not imply different stats or AI unless a future gameplay change explicitly adds them.\n\n', "architecture visual owner")
text = text.replace('Current schema: **3**.', 'Current schema: **4**.')
path.write_text(text)

path = Path("CHANGELOG.md")
text = path.read_text()
marker = 'This file tracks player-facing changes to the playable Alpha builds, plus major technical changes that affect development/reliability.\n\n'
text = replace_once(text, marker, marker + CHANGELOG_SECTION, "changelog header")
path.write_text(text)

checks = {
    "game/scripts/Game.gd": ['SAVE_SCHEMA_VERSION := 4', '"appearance": {}', 'TacticalVisuals.survivor_appearance'],
    "game/scripts/FFCombat.gd": ['FFTacticalVisuals.gd', 'TacticalVisuals.draw_survivor', 'TacticalVisuals.draw_zombie', '_flash_muzzle'],
    "game/scripts/FFTacticalVisuals.gd": ['class_name FFTacticalVisuals', 'weapon_visual', 'draw_survivor', 'draw_zombie'],
    ".github/workflows/pages.yml": ['FFTacticalVisuals.gd', 'SAVE_SCHEMA_VERSION := 4'],
}
for filename, needles in checks.items():
    body = Path(filename).read_text()
    for needle in needles:
        if needle not in body:
            raise SystemExit(f"post-write assertion failed {filename}: {needle}")
