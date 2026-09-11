from pathlib import Path

ROOT = Path('.')


def read(path):
    return (ROOT / path).read_text()


def write(path, text):
    (ROOT / path).write_text(text)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing replacement anchor: {label}')
    return text.replace(old, new, 1)


def replace_func(text, name, next_name, new_body):
    start_token = f'func {name}'
    end_token = f'\nfunc {next_name}'
    start = text.find(start_token)
    if start < 0:
        raise SystemExit(f'missing function: {name}')
    end = text.find(end_token, start)
    if end < 0:
        raise SystemExit(f'missing next function {next_name} after {name}')
    return text[:start] + new_body.rstrip() + text[end:]


balance = '''extends RefCounted
class_name FFTacticalBalance

# Beta tuning owner for the tactical layer. These are pure rules so combat,
# exploration rewards, and CI all read the same numbers.
const EXPLORE_SITE_COUNTS := {
    "Camp Perimeter": 3,
    "Nearby Streets": 3,
    "Residential Blocks": 4,
    "Commercial Fringe": 4,
    "Industrial Edge": 5,
}

const ZOMBIE_BASE_COUNTS := {
    "Camp Perimeter": 3,
    "Nearby Streets": 4,
    "Residential Blocks": 5,
    "Commercial Fringe": 6,
    "Industrial Edge": 7,
}

static func explore_site_count(zone: String) -> int:
    return int(EXPLORE_SITE_COUNTS.get(zone, 3))

static func zombie_count(zone: String, kind: String) -> int:
    var count := int(ZOMBIE_BASE_COUNTS.get(zone, 4))
    # Exploration asks the player to cover more ground, so it gets slightly
    # more breathing room. Ambush remains the combat-heaviest objective.
    if kind == "explore":
        count -= 1
    elif kind == "ambush":
        count += 1
    return maxi(2, count)

static func explore_reward_rolls(searches: int, scavenging: int) -> int:
    if searches <= 0:
        return 0
    var rolls := 1
    if searches >= 3:
        rolls += 1
    if searches >= 5:
        rolls += 1
    if scavenging >= 4 and searches >= 2:
        rolls += 1
    if scavenging >= 7 and searches >= 4:
        rolls += 1
    return clampi(rolls, 1, 4)

static func search_cost(actor: Dictionary) -> int:
    var scavenging := int(actor.get("skills", {}).get("Scavenging", 0))
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    var cost := 108.0 - float(scavenging) * 5.0 + fatigue * 0.18
    if bool(actor.get("crouched", false)):
        cost += 10.0
    return clampi(int(round(cost)), 62, 138)

static func search_noise(actor: Dictionary) -> int:
    var scavenging := int(actor.get("skills", {}).get("Scavenging", 0))
    var noise := 31 - scavenging * 2
    if bool(actor.get("crouched", false)):
        noise -= 9
    if str(actor.get("clothing", "")) == "Heavy Boots":
        noise += 3
    return clampi(noise, 12, 34)

static func melee_hit_chance(combat: int, penalty: float, stealth: bool, accuracy: float) -> float:
    var chance := 0.56 + float(combat) * 0.045 + accuracy - penalty
    if stealth:
        chance += 0.26
    return clampf(chance, 0.15, 0.96)

static func gun_hit_chance(combat: int, distance: int, penalty: float, accuracy: float) -> float:
    var range_penalty := float(maxi(0, distance - 3)) * 0.045
    return clampf(0.58 + float(combat) * 0.045 + accuracy - range_penalty - penalty, 0.12, 0.94)

static func shove_chance(actor: Dictionary, mass: String, weapon_push: int) -> float:
    var combat := int(actor.get("skills", {}).get("Combat", 0))
    var survival := int(actor.get("skills", {}).get("Survival", 0))
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    var mass_penalty := 0.0
    if mass == "HEAVY":
        mass_penalty = 0.22
    elif mass == "MED":
        mass_penalty = 0.08
    var chance := 0.72 + float(combat) * 0.025 + float(survival) * 0.012
    chance += float(weapon_push) * 0.025
    chance -= fatigue * 0.0022 + mass_penalty
    return clampf(chance, 0.25, 0.94)

static func shove_stagger_ticks(mass: String, pinned: bool) -> int:
    var stagger := 55
    if mass == "LIGHT":
        stagger = 75
    elif mass == "HEAVY":
        stagger = 35
    if pinned:
        stagger += 25
    return stagger

static func guard_bonus(actor: Dictionary) -> float:
    var combat := int(actor.get("skills", {}).get("Combat", 0))
    var survival := int(actor.get("skills", {}).get("Survival", 0))
    return clampf(0.18 + float(combat) * 0.008 + float(survival) * 0.006, 0.18, 0.30)

static func zombie_hit_chance(actor: Dictionary) -> float:
    var combat := int(actor.get("skills", {}).get("Combat", 0))
    var survival := int(actor.get("skills", {}).get("Survival", 0))
    var fatigue := float(actor.get("fatigue", 0.0))
    var chance := 0.64 - float(combat) * 0.018 - float(survival) * 0.012
    if fatigue >= 80.0:
        chance += 0.08
    elif fatigue >= 60.0:
        chance += 0.04
    if bool(actor.get("guarding", false)):
        chance -= guard_bonus(actor)
    return clampf(chance, 0.18, 0.82)

static func zombie_damage_range(mass: String) -> Vector2i:
    if mass == "LIGHT":
        return Vector2i(1, 4)
    if mass == "HEAVY":
        return Vector2i(3, 6)
    return Vector2i(2, 5)
'''
write('game/scripts/FFTacticalBalance.gd', balance)

combat_path = 'game/scripts/FFCombat.gd'
combat = read(combat_path)
combat = replace_once(
    combat,
    'const TacticalSound = preload("res://scripts/FFTacticalSound.gd")\n',
    'const TacticalSound = preload("res://scripts/FFTacticalSound.gd")\nconst TacticalBalance = preload("res://scripts/FFTacticalBalance.gd")\n',
    'combat balance preload',
)
combat = replace_once(
    combat,
    'var objective_done := false\nvar game_over := false\n',
    'var objective_done := false\nvar explore_cells: Array = []\nvar explore_searched := {}\nvar explore_gear_cell := Vector2i(-1, -1)\nvar game_over := false\n',
    'explore runtime vars',
)
combat = replace_once(
    combat,
    'var btn_turn_left := Rect2(8, 700, 136, 78)\nvar btn_crouch := Rect2(28, 788, 96, 42)\nvar btn_forward := Rect2(264, 654, 108, 38)\nvar btn_turn_right := Rect2(246, 700, 136, 78)\nvar btn_back := Rect2(264, 788, 108, 42)\n',
    'var btn_turn_left := Rect2(8, 700, 136, 78)\nvar btn_crouch := Rect2(28, 788, 96, 42)\nvar btn_forward := Rect2(264, 654, 108, 38)\nvar btn_turn_right := Rect2(246, 700, 136, 78)\nvar btn_back := Rect2(264, 788, 108, 42)\nvar btn_guard := Rect2(148, 654, 98, 42)\nvar btn_shove := Rect2(148, 744, 98, 42)\n',
    'combat buttons',
)
combat = replace_once(
    combat,
    '    build_map(environment_id, environment_variant)\n    make_party()\n',
    '    build_map(environment_id, environment_variant)\n    setup_explore_sites()\n    make_party()\n',
    'explore setup call',
)
combat = replace_once(
    combat,
    '        "crouched": false,\n        "dead": false,\n',
    '        "crouched": false,\n        "guarding": false,\n        "dead": false,\n',
    'guard actor state',
)

weapon_func = '''func weapon_profile(name: String) -> Dictionary:
    match name:
        "Utility Knife", "Kitchen Knife":
            return {"name": name if name != "" else "Knife", "dmin": 4, "dmax": 7, "time": 82, "noise": 3, "push": 0, "stealth": 5, "accuracy": 0.06, "reach": 1, "gun": false, "ammo": 0}
        "Wooden Club", "Baseball Bat":
            return {"name": name, "dmin": 5, "dmax": 9, "time": 118, "noise": 9, "push": 2, "stealth": 1, "accuracy": -0.02, "reach": 1, "gun": false, "ammo": 0}
        "Hammer":
            return {"name": name, "dmin": 5, "dmax": 9, "time": 104, "noise": 8, "push": 1, "stealth": 2, "accuracy": 0.01, "reach": 1, "gun": false, "ammo": 0}
        "Improvised Spear":
            return {"name": name, "dmin": 6, "dmax": 10, "time": 122, "noise": 7, "push": 1, "stealth": 3, "accuracy": -0.03, "reach": 2, "gun": false, "ammo": 0}
        "Crowbar":
            return {"name": name, "dmin": 5, "dmax": 8, "time": 108, "noise": 8, "push": 2, "stealth": 2, "accuracy": 0.00, "reach": 1, "gun": false, "ammo": 0}
        "Hatchet":
            return {"name": name, "dmin": 7, "dmax": 11, "time": 140, "noise": 11, "push": 1, "stealth": 2, "accuracy": -0.03, "reach": 1, "gun": false, "ammo": 0}
        "Pistol":
            return {"name": name, "dmin": 3, "dmax": 5, "time": 95, "noise": 7, "push": 0, "stealth": 1, "accuracy": 0.02, "reach": 1, "gun": true, "ammo": 1, "gmin": 8, "gmax": 14, "gtime": 118, "gnoise": 72, "gaccuracy": 0.05}
        "Shotgun":
            return {"name": name, "dmin": 4, "dmax": 7, "time": 115, "noise": 9, "push": 1, "stealth": 1, "accuracy": -0.02, "reach": 1, "gun": true, "ammo": 2, "gmin": 13, "gmax": 20, "gtime": 155, "gnoise": 96, "gaccuracy": -0.02}
        _:
            return {"name": "Bare Hands", "dmin": 2, "dmax": 4, "time": 108, "noise": 5, "push": 0, "stealth": 0, "accuracy": -0.08, "reach": 1, "gun": false, "ammo": 0}
'''
combat = replace_func(combat, 'weapon_profile(name: String) -> Dictionary:', 'build_map', weapon_func)

explore_helpers = '''
func setup_explore_sites() -> void:
    explore_cells.clear()
    explore_searched.clear()
    explore_gear_cell = Vector2i(-1, -1)
    if str(context.get("kind", "ambush")) != "explore":
        return
    var wanted := TacticalBalance.explore_site_count(str(context.get("zone", "Nearby Streets")))
    explore_cells = choose_explore_cells(wanted)
    if explore_cells.is_empty():
        explore_cells = [objective_cell]
    explore_gear_cell = explore_cells[rng.randi_range(0, explore_cells.size() - 1)]
    objective_cell = explore_gear_cell

func choose_explore_cells(wanted: int) -> Array:
    var distances := {player_spawn: 0}
    var queue: Array = [player_spawn]
    while not queue.is_empty():
        var p: Vector2i = queue.pop_front()
        var base_distance := int(distances[p])
        for d in DIRS:
            var n: Vector2i = p + Vector2i(d)
            if not inside(n) or walls.has(n) or obstacles.has(n) or distances.has(n):
                continue
            distances[n] = base_distance + 1
            queue.append(n)
    var preferred: Array = []
    var fallback: Array = []
    for key in distances.keys():
        var p: Vector2i = key
        if int(distances[p]) < 4 or p == player_spawn or p == ally_spawn or exit_cells.has(p):
            continue
        if walls.has(p) or obstacles.has(p) or glass.has(p) or doors.has(p) or barrels.has(p):
            continue
        fallback.append(p)
        var near_fixture := false
        for d in DIRS:
            var adjacent := p + Vector2i(d)
            if props.has(adjacent) or obstacles.has(adjacent) or barrels.has(adjacent):
                near_fixture = true
                break
        if near_fixture:
            preferred.append(p)
    var result: Array = []
    for pass_pool in [preferred, fallback]:
        var pool: Array = pass_pool.duplicate()
        while not pool.is_empty() and result.size() < wanted:
            var eligible: Array = []
            for p in pool:
                var spaced := true
                for chosen in result:
                    if manhattan(p, chosen) < 4:
                        spaced = false
                        break
                if spaced:
                    eligible.append(p)
            if eligible.is_empty():
                break
            var choice: Vector2i = eligible[rng.randi_range(0, eligible.size() - 1)]
            result.append(choice)
            pool.erase(choice)
        if result.size() >= wanted:
            break
    return result
'''
anchor = '\nfunc spawn_zombies():'
if anchor not in combat:
    raise SystemExit('missing spawn_zombies anchor')
combat = combat.replace(anchor, explore_helpers + anchor, 1)

combat = replace_once(
    combat,
    '    var count: int = int({"Camp Perimeter": 3, "Nearby Streets": 4, "Residential Blocks": 5, "Commercial Fringe": 6, "Industrial Edge": 7}.get(zone, 4))\n    if context.get("kind", "") == "ambush": count += 1\n',
    '    var kind := str(context.get("kind", "ambush"))\n    var count: int = TacticalBalance.zombie_count(zone, kind)\n',
    'zombie count tuning',
)
combat = replace_once(
    combat,
    '            if blocked(p) or p == player.get("pos", player_spawn) or p == ally.get("pos", Vector2i(-1,-1)):\n                continue\n',
    '            if blocked(p) or p == player.get("pos", player_spawn) or p == ally.get("pos", Vector2i(-1,-1)) or explore_cells.has(p):\n                continue\n',
    'exclude explore sites from zombie spawn',
)
combat = replace_once(
    combat,
    '    player["crouched"] = bool(runtime.get("crouched", false))\n',
    '    player["crouched"] = bool(runtime.get("crouched", false))\n    player["guarding"] = bool(runtime.get("guarding", false))\n    if str(context.get("kind", "")) == "explore":\n        if runtime.has("explore_cells"):\n            explore_cells.clear()\n            for value in runtime.get("explore_cells", []):\n                explore_cells.append(arr_to_v2i(value, Vector2i(-1, -1)))\n        if runtime.has("explore_gear_cell"):\n            explore_gear_cell = arr_to_v2i(runtime.get("explore_gear_cell", []), explore_gear_cell)\n            objective_cell = explore_gear_cell\n        explore_searched.clear()\n        for value in runtime.get("explore_searched", []):\n            var searched_cell := arr_to_v2i(value, Vector2i(-1, -1))\n            if searched_cell != Vector2i(-1, -1):\n                explore_searched[searched_cell] = true\n',
    'restore tactical depth state',
)
combat = replace_once(
    combat,
    '    var removed_barrels := []\n    for p in base_barrels.keys():\n        if not barrels.has(p): removed_barrels.append([p.x, p.y])\n    runtime = {\n',
    '    var removed_barrels := []\n    for p in base_barrels.keys():\n        if not barrels.has(p): removed_barrels.append([p.x, p.y])\n    var saved_explore_cells := []\n    for p in explore_cells:\n        saved_explore_cells.append([p.x, p.y])\n    var saved_explore_searched := []\n    for p in explore_searched.keys():\n        saved_explore_searched.append([p.x, p.y])\n    runtime = {\n',
    'persist explore arrays prep',
)
combat = replace_once(
    combat,
    '        "crouched": bool(player.crouched),\n        "objective_done": objective_done,\n',
    '        "crouched": bool(player.crouched),\n        "guarding": bool(player.get("guarding", false)),\n        "objective_done": objective_done,\n        "explore_cells": saved_explore_cells,\n        "explore_searched": saved_explore_searched,\n        "explore_gear_cell": [explore_gear_cell.x, explore_gear_cell.y],\n',
    'persist tactical depth state',
)
combat = replace_once(
    combat,
    '            KEY_C: toggle_crouch()\n            KEY_F, KEY_SPACE: interact()\n',
    '            KEY_C: toggle_crouch()\n            KEY_G: guard()\n            KEY_X: shove()\n            KEY_F, KEY_SPACE: interact()\n',
    'keyboard guard shove',
)

old_dispatch = '''func dispatch_point(pos: Vector2):
    if game_over: return
    if btn_turn_left.has_point(pos):
        guarded_action("TURN_L", func(): rotate_player(-1)); return
    if btn_turn_right.has_point(pos):
        guarded_action("TURN_R", func(): rotate_player(1)); return
    if btn_forward.has_point(pos): step_forward(); return
    if btn_back.has_point(pos): step_backward(); return
    if btn_crouch.has_point(pos): toggle_crouch(); return
    if pos.y < MAP_TOP or pos.y >= CONTROL_TOP: return
    var cell := screen_to_cell(pos)
    if not inside(cell): return
    var delta: Vector2i = cell - player.pos
    if manhattan(player.pos, cell) == 1:
        player.facing = delta
        if zombie_at(cell) != -1: melee(cell); return
        if doors.has(cell): interact(); return
        if glass.has(cell): interact(); return
        try_move(delta); return
    if visible_cells.has(cell):
        var zi := zombie_at(cell)
        if zi != -1:
            if bool(player.weapon.gun): shoot(zi)
            else:
                msg = "Too far for %s." % player.weapon.name
                queue_redraw()
            return
        if barrels.has(cell): shoot_barrel(cell); return
'''
new_dispatch = '''func dispatch_point(pos: Vector2):
    if game_over: return
    if btn_turn_left.has_point(pos):
        guarded_action("TURN_L", func(): rotate_player(-1)); return
    if btn_turn_right.has_point(pos):
        guarded_action("TURN_R", func(): rotate_player(1)); return
    if btn_forward.has_point(pos): step_forward(); return
    if btn_back.has_point(pos): step_backward(); return
    if btn_crouch.has_point(pos): toggle_crouch(); return
    if btn_guard.has_point(pos): guard(); return
    if btn_shove.has_point(pos): shove(); return
    if pos.y < MAP_TOP or pos.y >= CONTROL_TOP: return
    var cell := screen_to_cell(pos)
    if not inside(cell): return
    var delta: Vector2i = cell - player.pos
    if str(context.get("kind", "")) == "explore" and explore_cells.has(cell) and not explore_searched.has(cell) and (cell == player.pos or manhattan(player.pos, cell) == 1):
        if cell != player.pos:
            player.facing = delta
        search_explore_cell(cell)
        return
    if manhattan(player.pos, cell) == 1:
        player.facing = delta
        if zombie_at(cell) != -1: melee(cell); return
        if doors.has(cell): interact(); return
        if glass.has(cell): interact(); return
        try_move(delta); return
    if visible_cells.has(cell):
        var zi := zombie_at(cell)
        if zi != -1:
            if bool(player.weapon.gun):
                shoot(zi)
            elif can_melee_reach(cell):
                melee(cell)
            else:
                msg = "Too far for %s." % player.weapon.name
                queue_redraw()
            return
        if barrels.has(cell): shoot_barrel(cell); return
'''
if old_dispatch not in combat:
    raise SystemExit('dispatch block mismatch')
combat = combat.replace(old_dispatch, new_dispatch, 1)

combat = replace_once(
    combat,
    '    player.facing = DIRS[idx]\n    player.last_dir = Vector2i.ZERO\n',
    '    player["guarding"] = false\n    player.facing = DIRS[idx]\n    player.last_dir = Vector2i.ZERO\n',
    'turn clears guard',
)
combat = replace_once(
    combat,
    '    player.pos = dest\n    player.facing = keep\n',
    '    player["guarding"] = false\n    player.pos = dest\n    player.facing = keep\n',
    'back clears guard',
)
combat = replace_once(
    combat,
    'func toggle_crouch():\n    player.crouched = not player.crouched\n',
    'func toggle_crouch():\n    player["guarding"] = false\n    player.crouched = not player.crouched\n',
    'crouch clears guard',
)
combat = replace_once(
    combat,
    '    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest):\n        msg = "Blocked."\n        recalc_visibility(); refresh_intents(); queue_redraw(); return\n    player.pos = dest\n',
    '    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest):\n        msg = "Blocked."\n        recalc_visibility(); refresh_intents(); queue_redraw(); return\n    player["guarding"] = false\n    player.pos = dest\n',
    'forward clears guard',
)

check_func = '''func check_objective_and_exit():
    var kind := str(context.get("kind", "ambush"))
    if not objective_done and kind == "rescue":
        if player.pos == rescue_cell or (not ally.is_empty() and not ally.dead and ally.pos == rescue_cell):
            objective_done = true
            msg = "Survivor found. Reach any exit."
            emit_noise(rescue_cell, 9, "struggle", true)
    if exit_cells.has(player.pos):
        if objective_done:
            msg = "You made it out."
        elif kind == "ambush":
            msg = "You broke contact and escaped."
        elif kind == "explore" and not explore_searched.is_empty():
            msg = "You leave with what you found and abandon the marked gear."
        else:
            msg = "You abandon the objective and get out alive."
        finish_encounter("escaped")
'''
combat = replace_func(combat, 'check_objective_and_exit():', 'interact', check_func)

interact_func = '''func interact():
    var p: Vector2i = player.pos + player.facing
    if str(context.get("kind", "")) == "explore":
        if explore_cells.has(player.pos) and not explore_searched.has(player.pos):
            search_explore_cell(player.pos)
            return
        if explore_cells.has(p) and not explore_searched.has(p):
            search_explore_cell(p)
            return
    if doors.has(p):
        player["guarding"] = false
        doors[p] = not doors[p]
        msg = "Door opened." if doors[p] else "Door closed."
        emit_noise(p, 20 if doors[p] else 16, "door open" if doors[p] else "door close", true)
        commit_action(TacticalTime.interaction_cost(player, 60)); return
    if glass.has(p):
        player["guarding"] = false
        glass.erase(p)
        msg = "Glass breaks. Loud."
        emit_noise(p, 58, "breaking glass", true)
        commit_action(TacticalTime.interaction_cost(player, 100)); return
    msg = "Nothing useful there."
    queue_redraw()
'''
combat = replace_func(combat, 'interact():', 'melee', interact_func)

melee_func = '''func melee(target: Vector2i):
    var zi := zombie_at(target)
    if zi == -1:
        msg = "Nothing in reach."; queue_redraw(); return
    if not can_melee_reach(target):
        msg = "%s cannot reach that target." % player.weapon.name; queue_redraw(); return
    player["guarding"] = false
    player.facing = dominant(target - player.pos)
    stats["melee"] = int(stats.get("melee", 0)) + 1
    var z: Dictionary = zombies[zi]
    var stealth := stealth_attack(z)
    var combat_skill := int(player.skills.get("Combat", 0))
    var chance := TacticalBalance.melee_hit_chance(combat_skill, attack_penalty(player), stealth, float(player.weapon.get("accuracy", 0.0)))
    if rng.randf() <= chance:
        var d := rng.randi_range(int(player.weapon.dmin), int(player.weapon.dmax)) + int(floor(combat_skill / 3.0))
        if stealth: d = int(round(float(d + int(player.weapon.stealth) + combat_skill) * 1.35))
        zombies[zi].hp -= d
        _flash_hit(z.pos, int(zombies[zi].hp) <= 0)
        msg = "%s hit for %d%s." % [player.weapon.name, d, " — STEALTH" if stealth else ""]
        if int(zombies[zi].hp) <= 0:
            kill_zombie(zi, stealth)
        else:
            reveal_melee_target(zi)
            if int(player.weapon.push) > 0:
                var pushed := push_zombie(zi, player.facing)
                zombies[zi].next += TacticalBalance.shove_stagger_ticks(str(zombies[zi].get("mass", "MED")), not pushed) / 2
    else:
        msg = "%s misses." % player.weapon.name
    emit_noise(player.pos, maxi(8, int(player.weapon.noise)), "melee impact", true)
    commit_action(TacticalTime.attack_cost(player, int(player.weapon.time)))

func can_melee_reach(target: Vector2i) -> bool:
    var distance := manhattan(player.pos, target)
    var reach := maxi(1, int(player.weapon.get("reach", 1)))
    if distance < 1 or distance > reach:
        return false
    var diff := target - player.pos
    if diff.x != 0 and diff.y != 0:
        return false
    var dir := dominant(diff)
    for step in range(1, distance):
        var between := player.pos + dir * step
        if blocked(between) or zombie_at(between) != -1:
            return false
    return line_clear(player.pos, target)
'''
combat = replace_func(combat, 'melee(target: Vector2i):', 'shoot', melee_func)

shoot_func = '''func shoot(i: int):
    if not bool(player.weapon.gun):
        msg = "No firearm equipped."; queue_redraw(); return
    var z: Dictionary = zombies[i]
    if z.dead or not visible_cells.has(z.pos): return
    var ammo_cost := int(player.weapon.ammo)
    if not Game.consume_combat_ammo(ammo_cost):
        msg = "No ammunition."; queue_redraw(); return
    player["guarding"] = false
    player.facing = dominant(z.pos - player.pos)
    var dist := manhattan(player.pos, z.pos)
    var combat_skill := int(player.skills.get("Combat", 0))
    var accuracy := float(player.weapon.get("gaccuracy", 0.0))
    if player.weapon.name == "Shotgun" and dist <= 3:
        accuracy += 0.08
    var chance := TacticalBalance.gun_hit_chance(combat_skill, dist, attack_penalty(player), accuracy)
    stats.shots += 1
    _flash_muzzle(player.pos, player.facing)
    if rng.randf() <= chance:
        var d := rng.randi_range(int(player.weapon.gmin), int(player.weapon.gmax)) + int(floor(combat_skill / 2.0))
        if player.weapon.name == "Shotgun" and dist <= 3: d += 4
        zombies[i].hp -= d
        _flash_hit(z.pos, int(zombies[i].hp) <= 0)
        msg = "%s hits for %d." % [player.weapon.name, d]
        if int(zombies[i].hp) <= 0:
            kill_zombie(i, false)
        else:
            reveal_melee_target(i)
        if player.weapon.name == "Shotgun":
            apply_shotgun_spread(i, z.pos, d)
    else:
        msg = "%s misses." % player.weapon.name
    emit_noise(player.pos, int(player.weapon.gnoise), "gunshot", true)
    commit_action(TacticalTime.attack_cost(player, int(player.weapon.gtime)))

func apply_shotgun_spread(primary_index: int, impact_cell: Vector2i, primary_damage: int) -> void:
    for j in range(zombies.size()):
        if j == primary_index or zombies[j].dead:
            continue
        if manhattan(impact_cell, zombies[j].pos) > 1 or not line_clear(player.pos, zombies[j].pos):
            continue
        var splash := maxi(2, int(round(float(primary_damage) * 0.42)))
        zombies[j].hp -= splash
        _flash_hit(zombies[j].pos, int(zombies[j].hp) <= 0)
        if int(zombies[j].hp) <= 0:
            kill_zombie(j, false)
        else:
            reveal_melee_target(j)
'''
combat = replace_func(combat, 'shoot(i: int):', 'shoot_barrel', shoot_func)
combat = replace_once(
    combat,
    '    barrels.erase(cell)\n    stats.shots += 1\n',
    '    player["guarding"] = false\n    barrels.erase(cell)\n    stats.shots += 1\n',
    'barrel shot clears guard',
)

push_func = '''func push_zombie(i: int, dir: Vector2i) -> bool:
    var dest: Vector2i = zombies[i].pos + dir
    if not blocked(dest) and zombie_at(dest) == -1 and dest != player.pos and not ally_at(dest):
        zombies[i].pos = dest
        return true
    return false

func guard() -> void:
    if bool(player.get("guarding", false)):
        msg = "Already guarding. Move or attack when you are ready."
        queue_redraw()
        return
    player["guarding"] = true
    player.last_dir = Vector2i.ZERO
    player.move_state = "STILL"
    msg = "Guard up — the next grab is much harder to land."
    commit_action(TacticalTime.interaction_cost(player, 55))

func shove() -> void:
    var target := player.pos + player.facing
    var zi := zombie_at(target)
    if zi == -1:
        msg = "No infected directly in front of you to shove."
        queue_redraw()
        return
    player["guarding"] = false
    stats["shoves"] = int(stats.get("shoves", 0)) + 1
    var mass := str(zombies[zi].get("mass", "MED"))
    var chance := TacticalBalance.shove_chance(player, mass, int(player.weapon.get("push", 0)))
    if rng.randf() <= chance:
        var pushed := push_zombie(zi, player.facing)
        var stagger := TacticalBalance.shove_stagger_ticks(mass, not pushed)
        zombies[zi].next += stagger
        msg = "Shove lands — %s%s." % ["space created" if pushed else "it slams into the obstacle", "" if mass != "HEAVY" else " despite its weight"]
    else:
        msg = "The shove fails to move it."
    reveal_melee_target(zi)
    emit_noise(player.pos, 18, "shove", true)
    commit_action(TacticalTime.interaction_cost(player, 78))

func search_explore_cell(cell: Vector2i) -> void:
    if str(context.get("kind", "")) != "explore" or not explore_cells.has(cell) or explore_searched.has(cell):
        return
    if cell != player.pos and manhattan(player.pos, cell) > 1:
        msg = "Get closer to search there."
        queue_redraw()
        return
    player["guarding"] = false
    explore_searched[cell] = true
    stats["searches"] = int(stats.get("searches", 0)) + 1
    var field_gear := str(context.get("field_gear", "field gear"))
    if cell == explore_gear_cell:
        objective_done = true
        msg = "Found %s. You can leave now or keep searching." % field_gear
    else:
        var remaining := explore_cells.size() - explore_searched.size()
        msg = "Useful supplies. %d search spot%s left." % [remaining, "" if remaining == 1 else "s"]
    emit_noise(cell, TacticalBalance.search_noise(player), "rummaging", true)
    commit_action(TacticalBalance.search_cost(player))
'''
combat = replace_func(combat, 'push_zombie(i: int, dir: Vector2i):', 'kill_zombie', push_func)

zombie_attack_func = '''func zombie_attack(i: int, target_actor: Dictionary):
    var guarded := bool(target_actor.get("guarding", false))
    var hit := TacticalBalance.zombie_hit_chance(target_actor)
    if target_actor.controlled and guarded:
        target_actor["guarding"] = false
    if rng.randf() <= hit:
        var damage_range := TacticalBalance.zombie_damage_range(str(zombies[i].get("mass", "MED")))
        var dmg := rng.randi_range(damage_range.x, damage_range.y)
        if guarded:
            dmg = maxi(1, dmg - 1)
        var protection := clothing_protection(target_actor.clothing)
        if rng.randf() < protection: dmg = maxi(1, dmg - 2)
        target_actor.hp -= dmg
        _flash_hit(target_actor.pos, int(target_actor.hp) <= 0)
        if target_actor.controlled:
            stats.damage += dmg
            msg = "The infected breaks through your guard for %d." % dmg if guarded else "The infected hits you for %d." % dmg
        else:
            msg = "%s gets hit." % target_actor.name
        if target_actor.hp <= 0:
            target_actor.hp = 0; target_actor.dead = true
    elif target_actor.controlled:
        msg = "You deflect the grab." if guarded else "You avoid the grab."
    zombies[i].next = tick + TacticalTime.zombie_attack_cost(zombies[i])
'''
combat = replace_func(combat, 'zombie_attack(i: int, target_actor: Dictionary):', 'clothing_protection', zombie_attack_func)

combat = replace_once(
    combat,
    '        "kills": int(stats.kills), "shots": int(stats.shots), "damage": int(stats.damage)\n',
    '        "kills": int(stats.kills), "shots": int(stats.shots), "melee": int(stats.get("melee", 0)), "shoves": int(stats.get("shoves", 0)), "damage": int(stats.damage),\n        "searches_completed": explore_searched.size(), "search_sites_total": explore_cells.size()\n',
    'combat result stats',
)
combat = replace_once(
    combat,
    'var stats := {"kills": 0, "shots": 0, "noise": 0, "damage": 0}\n',
    'var stats := {"kills": 0, "shots": 0, "melee": 0, "shoves": 0, "searches": 0, "noise": 0, "damage": 0}\n',
    'initial stats shape',
)
combat = replace_once(
    combat,
    '    stats = {"kills": 0, "shots": 0, "noise": 0, "damage": 0}\n',
    '    stats = {"kills": 0, "shots": 0, "melee": 0, "shoves": 0, "searches": 0, "noise": 0, "damage": 0}\n',
    'reset stats shape',
)

old_explore_draw = '''    if kind == "explore" and not objective_done:
        var objective_rect := Rect2(objective_cell.x*TILE+3, objective_cell.y*TILE+3, TILE-6, TILE-6)
        draw_rect(objective_rect, Color(.95,.75,.20), false, 3)
        var field_gear := str(context.get("field_gear", ""))
        var visual: Dictionary = TacticalVisuals.field_gear_visual(field_gear)
        var atlas_index := int(visual.get("atlas", -1))
        var center := cell_center(objective_cell)
        if atlas_index >= 0:
            TacticalTiles.draw_region(self, atlas_index, Rect2(center - Vector2(9,9), Vector2(18,18)))
        else:
            draw_circle(center, 8.0, Color(.08,.10,.09,.92))
            draw_circle(center, 8.0, Color(.95,.75,.20), false, 1.5)
            draw_string(font, center + Vector2(-6,3), str(visual.get("badge", "?")), HORIZONTAL_ALIGNMENT_CENTER, 12, 9, Color(.98,.92,.70))
        draw_string(font, center + Vector2(-52,-14), field_gear, HORIZONTAL_ALIGNMENT_CENTER, 104, 7, Color(.98,.86,.40))
    elif kind == "rescue" and not objective_done:
'''
new_explore_draw = '''    if kind == "explore":
        draw_explore_sites()
    elif kind == "rescue" and not objective_done:
'''
if old_explore_draw not in combat:
    raise SystemExit('explore draw block mismatch')
combat = combat.replace(old_explore_draw, new_explore_draw, 1)

explore_draw_helper = '''
func draw_explore_sites() -> void:
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
anchor = '\nfunc draw_escape_markers():'
if anchor not in combat:
    raise SystemExit('draw_escape_markers anchor missing')
combat = combat.replace(anchor, explore_draw_helper + anchor, 1)

combat = replace_once(
    combat,
    '        "explore":\n            var field_gear := str(context.get("field_gear", "LOOT"))\n            objective_text = ("TAKE %s + ESCAPE" % field_gear) if not objective_done else "ESCAPE"\n',
    '        "explore":\n            var field_gear := str(context.get("field_gear", "LOOT"))\n            if objective_done:\n                objective_text = "FOUND %s | SEARCH %d/%d" % [field_gear, explore_searched.size(), explore_cells.size()]\n            else:\n                objective_text = "SEARCH %d/%d | FIND %s" % [explore_searched.size(), explore_cells.size(), field_gear]\n',
    'explore hud objective',
)
combat = replace_once(
    combat,
    '    draw_button(btn_back,"BACK",false,11)\n    var step_cost := TacticalTime.movement_cost(player, false)\n    var load_label := TacticalTime.load_band(TacticalTime.equipment_weight(player))\n    draw_string(font,Vector2(148,716),"T %d  STEP %d"%[tick,step_cost],HORIZONTAL_ALIGNMENT_CENTER,98,8,Color(.62,.68,.64))\n    draw_string(font,Vector2(148,731),"K %d  %s"%[int(stats.kills),load_label],HORIZONTAL_ALIGNMENT_CENTER,98,8,Color(.55,.60,.56))\n',
    '    draw_button(btn_back,"BACK",false,11)\n    draw_button(btn_guard,"GUARD",bool(player.get("guarding", false)),10)\n    draw_button(btn_shove,"SHOVE",false,10)\n    var step_cost := TacticalTime.movement_cost(player, false)\n    var load_label := TacticalTime.load_band(TacticalTime.equipment_weight(player))\n    draw_string(font,Vector2(148,806),"T %d  STEP %d"%[tick,step_cost],HORIZONTAL_ALIGNMENT_CENTER,98,8,Color(.62,.68,.64))\n    draw_string(font,Vector2(148,821),"K %d  %s"%[int(stats.kills),load_label],HORIZONTAL_ALIGNMENT_CENTER,98,8,Color(.55,.60,.56))\n',
    'combat control draw',
)
write(combat_path, combat)

game_path = 'game/scripts/Game.gd'
game = read(game_path)
game = replace_once(
    game,
    'const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\n',
    'const TacticalVisuals = preload("res://scripts/FFTacticalVisuals.gd")\nconst TacticalBalance = preload("res://scripts/FFTacticalBalance.gd")\n',
    'game balance preload',
)

reward_func = '''func _grant_tactical_explore_reward(exp, lead, searches_completed: int):
    var scavenging := int(lead["skills"].get("Scavenging", 0)) if lead != null else 0
    var count := TacticalBalance.explore_reward_rolls(searches_completed, scavenging)
    var found = {}
    for i in range(count):
        var key = _weighted_loot_pick(exp["zone"])
        resources[key] = int(resources.get(key, 0)) + 1
        found[key] = int(found.get(key, 0)) + 1
    var bits = []
    for key in found.keys():
        bits.append("+%d %s" % [found[key], key])
    return ", ".join(bits)
'''
game = replace_func(game, '_grant_tactical_explore_reward(exp, lead):', 'resolve_combat', reward_func)

game = replace_once(
    game,
    '        lead["fatigue"] = min(100.0, float(lead["fatigue"]) + CampLifeRules.fatigue_gain(6.0))\n        lead["stress"] = min(100.0, float(lead["stress"]) + min(18.0, float(result.get("damage", 0)) * 1.5))\n        add_skill_xp(lead, "Combat", min(22, 4 + int(result.get("kills", 0)) * 3))\n',
    '        lead["fatigue"] = min(100.0, float(lead["fatigue"]) + CampLifeRules.fatigue_gain(4.0))\n        lead["stress"] = min(100.0, float(lead["stress"]) + min(18.0, float(result.get("damage", 0)) * 1.5))\n        var combat_xp := mini(20, int(result.get("kills", 0)) * 2 + int(result.get("melee", 0)) + int(result.get("shots", 0)))\n        if combat_xp > 0:\n            add_skill_xp(lead, "Combat", combat_xp)\n',
    'tactical fatigue and combat xp balance',
)

old_explore_result = '''    elif kind == "explore" and bool(result.get("objective_done", false)):
        var reward: String = str(_grant_tactical_explore_reward(exp, lead))
        var recovered_gear := str(result.get("field_gear", ""))
        if recovered_gear != "" and D.GEAR.has(recovered_gear):
            inventory_gear.append(recovered_gear)
            reward = (reward + ", " if reward != "" else "") + recovered_gear
        _queue_field_result(event, "%s Searched" % place, "You physically recovered the marked field loot and got back out. Find: %s." % reward, "The party searched %s tactically and escaped with %s." % [place, recovered_gear if recovered_gear != "" else "supplies"])
    elif kind in ["rescue", "explore"] and not bool(result.get("objective_done", false)):
        _queue_field_result(event, "Withdrew from %s" % place, "You found a way out and chose survival over the objective. The expedition can continue, but the opportunity here is gone.", "The party withdrew from %s before completing the tactical objective." % place)
'''
new_explore_result = '''    elif kind == "explore":
        var searches := int(result.get("searches_completed", 0))
        var total_sites := maxi(searches, int(result.get("search_sites_total", searches)))
        var reward: String = str(_grant_tactical_explore_reward(exp, lead, searches))
        if lead != null and searches > 0:
            add_skill_xp(lead, "Scavenging", mini(10, searches * 2))
        var recovered_gear := str(result.get("field_gear", "")) if bool(result.get("objective_done", false)) else ""
        if recovered_gear != "" and D.GEAR.has(recovered_gear):
            inventory_gear.append(recovered_gear)
            reward = (reward + ", " if reward != "" else "") + recovered_gear
        if bool(result.get("objective_done", false)):
            _queue_field_result(event, "%s Searched" % place, "You searched %d/%d marked spots, recovered the target gear, and got back out. Find: %s." % [searches, total_sites, reward if reward != "" else "nothing extra"], "The party searched %s tactically and escaped with %s." % [place, recovered_gear if recovered_gear != "" else "supplies"])
        elif searches > 0:
            _queue_field_result(event, "Partial Search of %s" % place, "You searched %d/%d marked spots and escaped before finding the target gear. You still keep the supplies you physically recovered: %s." % [searches, total_sites, reward if reward != "" else "nothing useful"], "The party partially searched %s and withdrew alive." % place)
        else:
            _queue_field_result(event, "Withdrew from %s" % place, "You found a way out before committing to the search. The expedition can continue, but the marked gear opportunity here is gone.", "The party withdrew from %s before searching the tactical objective." % place)
    elif kind == "rescue" and not bool(result.get("objective_done", false)):
        _queue_field_result(event, "Withdrew from %s" % place, "You found a way out and chose survival over the rescue. The expedition can continue, but the opportunity here is gone.", "The party withdrew from %s before completing the tactical objective." % place)
'''
if old_explore_result not in game:
    raise SystemExit('explore result block mismatch')
game = game.replace(old_explore_result, new_explore_result, 1)

game = replace_once(
    game,
    '    var gear_found = _roll_gear(exp, living_party)\n    if gear_found != "":\n',
    '    var gear_found = ""\n    if not (bool(exp.get("tactical_resolved", false)) and str(exp.get("combat_kind", "")) == "explore"):\n        gear_found = _roll_gear(exp, living_party)\n    if gear_found != "":\n',
    'avoid duplicate explore gear roll',
)
write(game_path, game)

smoke_path = 'game/scripts/ci/FFArchitectureSmoke.gd'
smoke = read(smoke_path)
smoke = replace_once(
    smoke,
    'const TacticalSound = preload("res://scripts/FFTacticalSound.gd")\n',
    'const TacticalSound = preload("res://scripts/FFTacticalSound.gd")\nconst TacticalBalance = preload("res://scripts/FFTacticalBalance.gd")\n',
    'smoke balance preload',
)
smoke = replace_once(
    smoke,
    '    if not _check(TacticalTime.movement_cost(heavy_actor, false) > TacticalTime.movement_cost(light_actor, false), "encumbrance changes timeline"): return\n\n',
    '    if not _check(TacticalTime.movement_cost(heavy_actor, false) > TacticalTime.movement_cost(light_actor, false), "encumbrance changes timeline"): return\n    if not _check(TacticalBalance.explore_site_count("Industrial Edge") > TacticalBalance.explore_site_count("Camp Perimeter"), "exploration grows by zone"): return\n    if not _check(TacticalBalance.explore_reward_rolls(4, 5) > TacticalBalance.explore_reward_rolls(1, 1), "exploration reward scales with search depth"): return\n    if not _check(TacticalBalance.zombie_count("Residential Blocks", "explore") < TacticalBalance.zombie_count("Residential Blocks", "ambush"), "objective-specific zombie balance"): return\n    var unguarded_actor := light_actor.duplicate(true)\n    unguarded_actor["guarding"] = false\n    var guarded_actor := light_actor.duplicate(true)\n    guarded_actor["guarding"] = true\n    if not _check(TacticalBalance.zombie_hit_chance(guarded_actor) < TacticalBalance.zombie_hit_chance(unguarded_actor), "guard changes incoming hit chance"): return\n    if not _check(TacticalBalance.shove_chance(light_actor, "LIGHT", 0) > TacticalBalance.shove_chance(light_actor, "HEAVY", 0), "infected mass changes shove resistance"): return\n    var skilled_searcher := light_actor.duplicate(true)\n    skilled_searcher["skills"]["Scavenging"] = 7\n    if not _check(TacticalBalance.search_cost(skilled_searcher) < TacticalBalance.search_cost(light_actor), "scavenging speeds tactical search"): return\n\n',
    'balance smoke contracts',
)
write(smoke_path, smoke)

architecture_path = 'ARCHITECTURE.md'
architecture = read(architecture_path)
architecture = replace_once(
    architecture,
    '### `FFTacticalTime.gd`\nPure tactical action-timing rules. Converts survivor equipment weight, fatigue, condition, skills, stance, and zombie pace/mass profiles into actual timeline costs used by `FFCombat.gd`.\n\n',
    '### `FFTacticalTime.gd`\nPure tactical action-timing rules. Converts survivor equipment weight, fatigue, condition, skills, stance, and zombie pace/mass profiles into actual timeline costs used by `FFCombat.gd`.\n\n### `FFTacticalBalance.gd`\nPure Beta tuning rules for tactical combat and exploration: objective-specific infected counts, multi-search sizing/rewards, search time/noise, melee/firearm accuracy, Guard defense, Shove resistance/stagger, and infected mass damage. Keeping these values outside `FFCombat.gd` makes balance iteration deterministic and testable without creating a new gameplay pillar.\n\n',
    'architecture balance owner',
)
write(architecture_path, architecture)

context_path = 'README_CONTEXT.md'
ctx = read(context_path)
ctx = replace_once(
    ctx,
    'Tactical action time is authoritative: equipped weight, fatigue, injuries, stance, survivor skill, weapon action time, and per-zombie pace/mass profiles feed the actual tick scheduler. Sound markers use bounded fuzzy localization near the true source, surface-specific footsteps and more ambient/infected noises, and nearby infected share awareness when one spots the party. A nonlethal melee hit reveals the attacker to that infected even when the approach was stealthy. Adjacent doors are now tap/click interactions, allowing explicit closing instead of treating an open door tap as movement.\n',
    'Tactical action time is authoritative: equipped weight, fatigue, injuries, stance, survivor skill, weapon action time, and per-zombie pace/mass profiles feed the actual tick scheduler. Sound markers use bounded fuzzy localization near the true source, surface-specific footsteps and more ambient/infected noises, and nearby infected share awareness when one spots the party. A nonlethal melee hit reveals the attacker to that infected even when the approach was stealthy. Adjacent doors are now tap/click interactions, allowing explicit closing instead of treating an open door tap as movement.\n\nBeta tactical depth adds two explicit defensive decisions without adding a new combat mode: **Guard** spends time to sharply reduce the next infected grab chance, while **Shove** trades damage for spacing/stagger and is harder against heavier infected. Weapon handling is more distinct: knives are quick/accurate, the improvised spear can attack two cells in a straight line, heavier melee weapons create more displacement, and a shotgun can catch infected adjacent to its primary impact.\n\nExplore encounters are now a multi-search mini-game rather than a single pickup. Each location contains several physically reachable search spots (3 in early zones up to 5 in Industrial), the marked gear is hidden in one of them, each search consumes tactical time and makes rummaging noise, and partial supplies survive an early retreat even when the target gear was not found. Exploration gets slightly fewer infected than an ambush so the larger traversal/search loop remains playable rather than becoming a mandatory clear.\n',
    'context tactical depth',
)
write(context_path, ctx)

changelog_path = 'CHANGELOG.md'
changelog = read(changelog_path)
entry = '''## Beta Candidate — Tactical Depth, Exploration & Balance — 2026-09-10

- Added **Guard**: spend tactical time to reduce the next infected grab chance; a guarded hit also loses one damage.
- Added **Shove**: create space without dealing normal damage. Infected mass now matters to shove resistance and stagger duration.
- Differentiated weapons further: knives gain accuracy, the improvised spear reaches two straight-line cells, blunt/pry weapons displace better, and shotguns can damage infected adjacent to the primary impact.
- Rebalanced infected attacks so light/medium/heavy mass produces different damage ranges while existing per-infected pace continues to drive chase timing.
- Expanded Explore into a real sweep: 3–5 search locations depending on zone, one hidden target-gear cache, explicit tactical search time/noise, and persistent searched-state across tactical save/resume.
- Partial Explore retreats now keep a bounded amount of supplies from physically searched caches even when the marked gear was not found.
- Exploration spawns one fewer infected than the zone baseline; ambushes remain one above baseline. This preserves encounter identity instead of scaling every objective the same way.
- Tactical search rewards scale with search depth and Scavenging skill but are capped to avoid stacking into huge loot piles alongside the normal expedition haul.
- A successful Explore no longer also rolls a second random post-expedition gear drop; the physical marked item is the gear reward for that tactical objective.
- Tactical encounter fatigue was reduced from a 6-point base to 4 before the existing fatigue multiplier, while Combat XP now comes from actual attacks/shots/kills instead of receiving a flat participation award.
- Added deterministic smoke contracts for exploration scale/rewards, objective-specific infected counts, Guard, Shove mass resistance, and Scavenging search speed.
- Save schema remains 7; the added tactical runtime fields are additive.

'''
if not changelog.startswith('#'):
    raise SystemExit('unexpected changelog header')
# Preserve the title line, then insert the new entry.
first_nl = changelog.find('\n')
changelog = changelog[:first_nl + 1] + '\n' + entry + changelog[first_nl + 1:].lstrip('\n')
write(changelog_path, changelog)

# Remove the temporary patch script from the gameplay commit. The workflow file
# cannot be removed by the Actions token and is cleaned through the connector.
Path('.github/scripts/temp_tactical_depth_balance_patch.py').unlink()
print('FIRST_FIRE_TACTICAL_DEPTH_BALANCE_PATCH_OK')
