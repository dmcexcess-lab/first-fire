from pathlib import Path
import re

ROOT = Path('.')


def read(path):
    return (ROOT / path).read_text()


def write(path, text):
    (ROOT / path).write_text(text)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'MISSING {label}')
    if text.count(old) != 1:
        raise SystemExit(f'NONUNIQUE {label}: {text.count(old)}')
    return text.replace(old, new, 1)


def regex_once(text, pattern, repl, label, flags=0):
    new, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'REGEX {label}: {count}')
    return new

# ---------------------------------------------------------------------------
# Scenario mix: rescue is now available from the starting zone.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFTacticalScenarios.gd'
text = read(path)
text = replace_once(
    text,
    '    "Camp Perimeter": [["explore", 0.65], ["ambush", 1.00]],',
    '    "Camp Perimeter": [["rescue", 0.20], ["explore", 0.65], ["ambush", 1.00]],',
    'camp perimeter rescue weight',
)
write(path, text)

# ---------------------------------------------------------------------------
# Tactical balance: rescue is slightly lighter than a normal location because
# the civilian is vulnerable and cannot fight.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFTacticalBalance.gd'
text = read(path)
text = replace_once(
    text,
    'const ZOMBIE_BASE_COUNTS := {\n    "Camp Perimeter": 3,\n    "Nearby Streets": 4,\n    "Residential Blocks": 5,\n    "Commercial Fringe": 6,\n    "Industrial Edge": 7,\n}\n',
    'const ZOMBIE_BASE_COUNTS := {\n    "Camp Perimeter": 3,\n    "Nearby Streets": 4,\n    "Residential Blocks": 5,\n    "Commercial Fringe": 6,\n    "Industrial Edge": 7,\n}\n\nconst RESCUE_SURVIVOR_HP := 12\nconst RESCUE_CONTACT_TICKS := 70\nconst RESCUE_PACE_PENALTY := 18\n',
    'rescue tuning constants',
)
text = replace_once(
    text,
    '    if kind == "explore":\n        count -= 1\n    elif kind == "ambush":\n        count += 1\n',
    '    if kind == "explore":\n        count -= 1\n    elif kind == "rescue":\n        count -= 1\n    elif kind == "ambush":\n        count += 1\n',
    'rescue infected count',
)
write(path, text)

# ---------------------------------------------------------------------------
# Combat: turn the old SOS marker into a physical civilian escort objective.
# ---------------------------------------------------------------------------
path = 'game/scripts/FFCombat.gd'
text = read(path)
text = replace_once(text, 'var ally := {}\n', 'var ally := {}\nvar rescuee := {}\nvar rescue_contacted := false\n', 'rescuee state vars')
text = replace_once(text, '    make_party()\n    spawn_zombies()\n', '    make_party()\n    setup_rescuee()\n    spawn_zombies()\n', 'setup rescuee before infected')
text = replace_once(
    text,
    '    if context.get("kind", "ambush") == "rescue":\n        msg = "Find the survivor, then get back out."\n        submsg = "They will decide whether to join after you escape."\n',
    '    if context.get("kind", "ambush") == "rescue":\n        var rescue_name := str(rescuee.get("name", "the survivor"))\n        msg = "Reach %s, then get both of you out." % rescue_name\n        submsg = "They cannot fight. Once contacted, they will stay close and can be hurt."\n',
    'rescue encounter intro',
)

insert_after_make_party = '''func make_party():
    var ids: Array = context.get("survivor_ids", [])
    var lead = Game.get_survivor(ids[0]) if not ids.is_empty() else null
    player = make_actor(lead, player_spawn, true)
    ally = {}

'''
rescue_setup = '''func make_party():
    var ids: Array = context.get("survivor_ids", [])
    var lead = Game.get_survivor(ids[0]) if not ids.is_empty() else null
    player = make_actor(lead, player_spawn, true)
    ally = {}

func setup_rescuee() -> void:
    rescuee = {}
    rescue_contacted = false
    if str(context.get("kind", "")) != "rescue":
        return
    var candidate: Dictionary = {}
    var raw_candidate = context.get("rescue_candidate", {})
    if raw_candidate is Dictionary:
        candidate = raw_candidate.duplicate(true)
    if candidate.is_empty():
        candidate = {
            "id": -1000,
            "name": "Stranded Survivor",
            "skills": {"Combat": 0, "Scavenging": 0, "Survival": 1, "Medical": 0, "Technical": 0, "Social": 0},
            "traits": [],
            "fatigue": 25.0,
            "stress": 55.0,
            "condition": "Healthy",
            "equipment": {"Weapon": "", "Secondary": "", "Clothing": "", "Pack": "", "Tool": ""},
            "appearance": TacticalVisuals.survivor_appearance(rng),
        }
    rescuee = make_actor(candidate, rescue_cell, false)
    rescuee["max_hp"] = mini(int(rescuee.get("max_hp", 18)), TacticalBalance.RESCUE_SURVIVOR_HP)
    rescuee["hp"] = int(rescuee["max_hp"])
    rescuee["weapon"] = weapon_profile("")
    rescuee["active"] = false
    rescuee["crouched"] = true
    rescuee["next"] = 2147483000

'''
text = replace_once(text, insert_after_make_party, rescue_setup, 'setup rescuee function')

text = replace_once(
    text,
    '            if blocked(p) or p == player.get("pos", player_spawn) or p == ally.get("pos", Vector2i(-1,-1)) or explore_cells.has(p):\n',
    '            if blocked(p) or p == player.get("pos", player_spawn) or p == ally.get("pos", Vector2i(-1,-1)) or rescuee_at(p) or explore_cells.has(p):\n',
    'exclude rescuee from infected spawn',
)

text = replace_once(
    text,
    '    if not ally.is_empty():\n        ally["hp"] = clamp(int(runtime.get("ally_hp", ally["max_hp"])), 0, int(ally["max_hp"]))\n        ally["dead"] = int(ally["hp"]) <= 0\n        if runtime.has("ally_pos"):\n            ally["pos"] = arr_to_v2i(runtime["ally_pos"], ally["pos"])\n    objective_done = bool(runtime.get("objective_done", false))\n',
    '    if not ally.is_empty():\n        ally["hp"] = clamp(int(runtime.get("ally_hp", ally["max_hp"])), 0, int(ally["max_hp"]))\n        ally["dead"] = int(ally["hp"]) <= 0\n        if runtime.has("ally_pos"):\n            ally["pos"] = arr_to_v2i(runtime["ally_pos"], ally["pos"])\n    if not rescuee.is_empty():\n        rescuee["hp"] = clampi(int(runtime.get("rescue_hp", rescuee["hp"])), 0, int(rescuee["max_hp"]))\n        rescuee["dead"] = int(rescuee["hp"]) <= 0\n        if runtime.has("rescue_pos"):\n            rescuee["pos"] = arr_to_v2i(runtime["rescue_pos"], rescuee["pos"])\n        rescue_contacted = bool(runtime.get("rescue_contacted", runtime.get("objective_done", false)))\n        rescuee["active"] = rescue_contacted and not bool(rescuee["dead"])\n        rescuee["crouched"] = not rescue_contacted\n        rescuee["next"] = int(runtime.get("rescue_next", rescuee.get("next", 2147483000)))\n    objective_done = bool(runtime.get("objective_done", false))\n',
    'restore rescuee runtime',
)

text = replace_once(
    text,
    '        "guarding": bool(player.get("guarding", false)),\n        "objective_done": objective_done,\n',
    '        "guarding": bool(player.get("guarding", false)),\n        "objective_done": objective_done,\n        "rescue_hp": int(rescuee.get("hp", -1)) if not rescuee.is_empty() else -1,\n        "rescue_pos": [rescuee.pos.x, rescuee.pos.y] if not rescuee.is_empty() else [-1, -1],\n        "rescue_contacted": rescue_contacted,\n        "rescue_next": int(rescuee.get("next", 2147483000)) if not rescuee.is_empty() else 2147483000,\n',
    'persist rescuee runtime',
)

text = replace_once(
    text,
    '    var delta: Vector2i = cell - player.pos\n    if str(context.get("kind", "")) == "explore" and explore_cells.has(cell) and not explore_searched.has(cell) and (cell == player.pos or manhattan(player.pos, cell) == 1):\n',
    '    var delta: Vector2i = cell - player.pos\n    if str(context.get("kind", "")) == "rescue" and rescuee_at(cell) and visible_cells.has(cell) and manhattan(player.pos, cell) == 1:\n        player.facing = delta\n        contact_rescuee()\n        return\n    if str(context.get("kind", "")) == "explore" and explore_cells.has(cell) and not explore_searched.has(cell) and (cell == player.pos or manhattan(player.pos, cell) == 1):\n',
    'tap rescuee interaction',
)

text = replace_once(
    text,
    'func step_forward():\n    var cell: Vector2i = player.pos + player.facing\n    if zombie_at(cell) != -1:\n',
    'func step_forward():\n    var cell: Vector2i = player.pos + player.facing\n    if rescuee_at(cell):\n        contact_rescuee(); return\n    if zombie_at(cell) != -1:\n',
    'forward contact rescuee',
)
text = replace_once(text, '    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest):\n', '    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest) or rescuee_at(dest):\n', 'backward rescuee collision')
text = replace_once(text, '    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest):\n', '    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest) or rescuee_at(dest):\n', 'forward rescuee collision')

old_check = '''func check_objective_and_exit():
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
new_check = '''func rescuee_ready_to_extract() -> bool:
    if rescuee.is_empty() or bool(rescuee.get("dead", false)) or not rescue_contacted:
        return false
    if exit_cells.has(rescuee.pos):
        return true
    return manhattan(player.pos, rescuee.pos) <= 1

func check_objective_and_exit():
    var kind := str(context.get("kind", "ambush"))
    if exit_cells.has(player.pos):
        if kind == "rescue":
            var rescue_name := str(rescuee.get("name", "The survivor"))
            if rescuee_ready_to_extract():
                objective_done = true
                msg = "%s makes it out with you." % rescue_name
            elif not rescuee.is_empty() and bool(rescuee.get("dead", false)):
                msg = "You escape. %s did not make it." % rescue_name
            elif rescue_contacted:
                msg = "You leave before %s reaches the exit." % rescue_name
            else:
                msg = "You abandon the rescue and get out alive."
        elif objective_done:
            msg = "You made it out."
        elif kind == "ambush":
            msg = "You broke contact and escaped."
        elif kind == "explore" and not explore_searched.is_empty():
            msg = "You leave with what you found and abandon the marked gear."
        else:
            msg = "You abandon the objective and get out alive."
        finish_encounter("escaped")
'''
text = replace_once(text, old_check, new_check, 'rescue extraction logic')

text = replace_once(
    text,
    'func interact():\n    var p: Vector2i = player.pos + player.facing\n    if str(context.get("kind", "")) == "explore":\n',
    'func interact():\n    var p: Vector2i = player.pos + player.facing\n    if str(context.get("kind", "")) == "rescue" and rescuee_at(p):\n        contact_rescuee()\n        return\n    if str(context.get("kind", "")) == "explore":\n',
    'interact rescuee',
)

text = replace_once(
    text,
    '    blast_actor(player, cell)\n    if not ally.is_empty() and not ally.dead: blast_actor(ally, cell)\n',
    '    blast_actor(player, cell)\n    if not ally.is_empty() and not ally.dead: blast_actor(ally, cell)\n    if not rescuee.is_empty() and not rescuee.dead: blast_actor(rescuee, cell)\n',
    'explosion can hurt rescuee',
)

anchor = 'func search_explore_cell(cell: Vector2i) -> void:\n'
rescue_funcs = '''func contact_rescuee() -> void:
    if rescuee.is_empty():
        msg = "There is nobody here to rescue."
        queue_redraw()
        return
    if bool(rescuee.get("dead", false)):
        msg = "%s is already gone." % str(rescuee.get("name", "The survivor"))
        queue_redraw()
        return
    if rescue_contacted:
        msg = "%s is already following you." % str(rescuee.get("name", "The survivor"))
        queue_redraw()
        return
    if manhattan(player.pos, rescuee.pos) != 1:
        msg = "Get next to the survivor first."
        queue_redraw()
        return
    player["guarding"] = false
    rescue_contacted = true
    rescuee["active"] = true
    rescuee["crouched"] = false
    rescuee["next"] = tick + TacticalBalance.RESCUE_CONTACT_TICKS + TacticalBalance.RESCUE_PACE_PENALTY
    msg = "%s is with you. Reach an exit together." % str(rescuee.get("name", "The survivor"))
    emit_noise(rescuee.pos, 12, "whispered reply", false)
    commit_action(TacticalBalance.RESCUE_CONTACT_TICKS)

func rescuee_act() -> void:
    if rescuee.is_empty() or bool(rescuee.get("dead", false)) or not rescue_contacted:
        return
    var current_distance := manhattan(rescuee.pos, player.pos)
    var best := Vector2i.ZERO
    var best_threat := 999
    var best_distance := current_distance
    for dir_value in DIRS:
        var dir: Vector2i = dir_value
        var candidate: Vector2i = rescuee.pos + dir
        if blocked(candidate) or zombie_at(candidate) != -1 or candidate == player.pos or ally_at(candidate):
            continue
        var distance := manhattan(candidate, player.pos)
        if distance >= current_distance:
            continue
        var threat := 0
        for z in zombies:
            if not z.dead and manhattan(candidate, z.pos) <= 1:
                threat += 1
        if threat < best_threat or (threat == best_threat and distance < best_distance):
            best = dir
            best_threat = threat
            best_distance = distance
    if best != Vector2i.ZERO:
        rescuee["facing"] = best
        rescuee["pos"] = rescuee.pos + best
        rescuee["move_state"] = "WALK"
        emit_noise(rescuee.pos, 11, TacticalSound.surface_step_label(str(ground.get(rescuee.pos, "asphalt")), false), false)
    else:
        rescuee["move_state"] = "STILL"
    rescuee["next"] = tick + TacticalTime.movement_cost(rescuee, false) + TacticalBalance.RESCUE_PACE_PENALTY

'''
text = replace_once(text, anchor, rescue_funcs + anchor, 'rescue contact and escort functions')

# Add rescuee to the tick scheduler.
text = replace_once(
    text,
    '        if not ally.is_empty() and not ally.dead and int(ally.next) <= target_tick and int(ally.next) < next_time:\n            next_time = int(ally.next); next_kind = "ally"\n        for i in range(zombies.size()):\n',
    '        if not ally.is_empty() and not ally.dead and int(ally.next) <= target_tick and int(ally.next) < next_time:\n            next_time = int(ally.next); next_kind = "ally"\n        if not rescuee.is_empty() and not rescuee.dead and rescue_contacted and int(rescuee.next) <= target_tick and int(rescuee.next) < next_time:\n            next_time = int(rescuee.next); next_kind = "rescuee"\n        for i in range(zombies.size()):\n',
    'rescuee scheduler selection',
)
text = replace_once(
    text,
    '        if next_kind == "ally": companion_act()\n        else: zombie_act(next_index)\n',
    '        if next_kind == "ally": companion_act()\n        elif next_kind == "rescuee": rescuee_act()\n        else: zombie_act(next_index)\n',
    'rescuee scheduler action',
)

text = replace_once(
    text,
    '    if zombie_sees_actor(z, player): candidates.append(player)\n    if not ally.is_empty() and not ally.dead and zombie_sees_actor(z, ally): candidates.append(ally)\n',
    '    if zombie_sees_actor(z, player): candidates.append(player)\n    if not ally.is_empty() and not ally.dead and zombie_sees_actor(z, ally): candidates.append(ally)\n    if not rescuee.is_empty() and not rescuee.dead and zombie_sees_actor(z, rescuee): candidates.append(rescuee)\n',
    'infected can target rescuee',
)
text = replace_once(
    text,
    '        if not ally.is_empty() and p == ally.pos and from != ally.pos: continue\n',
    '        if not ally.is_empty() and p == ally.pos and from != ally.pos: continue\n        if not rescuee.is_empty() and p == rescuee.pos and from != rescuee.pos: continue\n',
    'pathing avoids rescuee cell',
)

text = replace_once(
    text,
    '    elif kind == "rescue" and not objective_done:\n        draw_circle(cell_center(rescue_cell), 9, Color(.95,.75,.20), false, 3)\n        draw_string(font, cell_center(rescue_cell)+Vector2(-10,-12), "SOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.95,.8,.35))\n',
    '    elif kind == "rescue" and not rescuee.is_empty() and not rescuee.dead and not rescue_contacted:\n        draw_circle(cell_center(rescuee.pos), 9, Color(.95,.75,.20), false, 3)\n        draw_string(font, cell_center(rescuee.pos)+Vector2(-10,-12), "SOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(.95,.8,.35))\n',
    'moving rescue marker',
)

text = replace_once(
    text,
    '    if not ally.is_empty() and visible_cells.has(ally.pos):\n',
    '    if not rescuee.is_empty() and visible_cells.has(rescuee.pos):\n        if rescuee.dead:\n            TacticalVisuals.draw_survivor_corpse(self, cell_center(rescuee.pos), rescuee)\n        else:\n            TacticalVisuals.draw_survivor(self, cell_center(rescuee.pos), rescuee, false)\n            var rescue_label := "FOLLOW" if rescue_contacted else "RESCUE"\n            draw_string(font, cell_center(rescuee.pos) + Vector2(-24, -13), rescue_label, HORIZONTAL_ALIGNMENT_CENTER, 48, 7, Color(.98, .82, .36))\n\n    if not ally.is_empty() and visible_cells.has(ally.pos):\n',
    'draw physical rescuee',
)

text = replace_once(
    text,
    '        "rescue": objective_text = "RESCUE + ESCAPE" if not objective_done else "ESCAPE WITH SURVIVOR"\n',
    '        "rescue":\n            var rescue_name := str(rescuee.get("name", "SURVIVOR")).to_upper()\n            if not rescuee.is_empty() and rescuee.dead:\n                objective_text = "RESCUE FAILED | ESCAPE"\n            elif rescue_contacted:\n                objective_text = "ESCORT %s TO EXIT" % rescue_name\n            else:\n                objective_text = "REACH %s" % rescue_name\n',
    'rescue hud objective',
)

text = replace_once(
    text,
    '        "rescued": objective_done and str(context.get("kind", "")) == "rescue",\n        "field_gear": str(context.get("field_gear", "")) if objective_done and str(context.get("kind", "")) == "explore" else "",\n',
    '        "rescued": objective_done and str(context.get("kind", "")) == "rescue",\n        "rescue_contacted": rescue_contacted,\n        "rescue_survivor_alive": not rescuee.is_empty() and not bool(rescuee.get("dead", false)),\n        "rescue_survivor_hp": int(rescuee.get("hp", -1)) if not rescuee.is_empty() else -1,\n        "rescue_survivor_max_hp": int(rescuee.get("max_hp", -1)) if not rescuee.is_empty() else -1,\n        "field_gear": str(context.get("field_gear", "")) if objective_done and str(context.get("kind", "")) == "explore" else "",\n',
    'rescue result state',
)

text = replace_once(
    text,
    'func ally_at(p: Vector2i) -> bool:\n    return not ally.is_empty() and not ally.dead and ally.pos == p\n\n',
    'func ally_at(p: Vector2i) -> bool:\n    return not ally.is_empty() and not ally.dead and ally.pos == p\n\nfunc rescuee_at(p: Vector2i) -> bool:\n    return not rescuee.is_empty() and rescuee.pos == p\n\n',
    'rescuee occupancy helper',
)
write(path, text)

# ---------------------------------------------------------------------------
# Game orchestration: prebuild the actual rescue candidate and preserve that
# person's identity into the recruitment offer after successful extraction.
# ---------------------------------------------------------------------------
path = 'game/scripts/Game.gd'
text = read(path)
text = replace_once(
    text,
    '    var scene_state: Dictionary = TacticalScenarios.pick_scene_state(environment_id, rng)\n    current_combat = {\n',
    '    var scene_state: Dictionary = TacticalScenarios.pick_scene_state(environment_id, rng)\n    var rescue_candidate := {}\n    if combat_kind == "rescue":\n        rescue_candidate = _generate_survivor(false)\n        rescue_candidate["status"] = "Awaiting Rescue"\n        rescue_candidate["task"] = {}\n        rescue_candidate["stress"] = rng.randf_range(35.0, 60.0)\n        rescue_candidate["fatigue"] = rng.randf_range(15.0, 35.0)\n    current_combat = {\n',
    'generate tactical rescue candidate',
)
text = replace_once(
    text,
    '        "kind": combat_kind,\n        "environment_id": environment_id,\n',
    '        "kind": combat_kind,\n        "rescue_candidate": rescue_candidate.duplicate(true) if combat_kind == "rescue" else {},\n        "environment_id": environment_id,\n',
    'store tactical rescue candidate',
)

recruit_insert = '''func _add_recruit_candidate(candidate: Dictionary, rescuer_ids = []) -> Variant:
    if candidate.is_empty():
        return _add_recruit("", rescuer_ids)
    if population() >= MAX_POPULATION:
        toast_requested.emit("First Fire is at its %d-person limit." % MAX_POPULATION)
        return null
    if population() >= mini(MAX_POPULATION, shelter_capacity() + 1):
        toast_requested.emit("There is no room to squeeze another survivor into camp right now.")
        return null
    var s: Dictionary = candidate.duplicate(true)
    if int(s.get("id", -1)) < 0:
        s["id"] = next_survivor_id
        next_survivor_id += 1
    else:
        next_survivor_id = maxi(next_survivor_id, int(s["id"]) + 1)
    s["status"] = "Available"
    s["task"] = {}
    s["relationships"] = {}
    if not s.has("history"):
        s["history"] = []
    _initialize_relationships(s)
    for rid in rescuer_ids:
        s["relationships"][str(rid)] = rng.randi_range(15, 25)
        var rescuer: Variant = get_survivor(rid)
        if rescuer != null:
            rescuer["relationships"][str(s["id"])] = rng.randi_range(5, 15)
            _change_reputation(rescuer, 5)
    survivors.append(s)
    s["history"].append("Day %d — Rescued in the field and joined First Fire." % day)
    _add_history("Day %d — %s joined First Fire after a field rescue." % [day, s["name"]])
    eligible_expeditions_since_recruit = 0
    save_game()
    state_changed.emit()
    return s

'''
text = replace_once(text, 'func relationship_label(value):\n', recruit_insert + 'func relationship_label(value):\n', 'prebuilt rescue recruit helper')

text = replace_once(
    text,
    'func _queue_recruit_offer(event, title, body, source = "stranger", preferred_background = ""):\n    var context = event.get("context", {}).duplicate(true)\n    context["recruit_source"] = source\n    context["preferred_background"] = preferred_background\n',
    'func _queue_recruit_offer(event, title, body, source = "stranger", preferred_background = "", recruit_candidate = {}):\n    var context = event.get("context", {}).duplicate(true)\n    context["recruit_source"] = source\n    context["preferred_background"] = preferred_background\n    if recruit_candidate is Dictionary and not recruit_candidate.is_empty():\n        context["recruit_candidate"] = recruit_candidate.duplicate(true)\n',
    'recruit offer candidate passthrough',
)

text = replace_once(
    text,
    '            var recruit: Variant = _add_recruit(preferred, ids)\n',
    '            var recruit_candidate: Dictionary = event.get("context", {}).get("recruit_candidate", {})\n            var recruit: Variant = null\n            if not recruit_candidate.is_empty():\n                recruit = _add_recruit_candidate(recruit_candidate, ids)\n            else:\n                recruit = _add_recruit(preferred, ids)\n',
    'accept exact rescued survivor',
)

candidate_helper = '''func _prepare_rescue_candidate(candidate_value, hp: int, max_hp: int) -> Dictionary:
    var candidate: Dictionary = candidate_value.duplicate(true) if candidate_value is Dictionary else {}
    if candidate.is_empty():
        return candidate
    var ratio := float(maxi(0, hp)) / float(maxi(1, max_hp))
    var condition := "Healthy"
    var injury_time := 0.0
    if ratio < 0.25:
        condition = "Critical"; injury_time = 360.0
    elif ratio < 0.55:
        condition = "Wounded"; injury_time = 180.0
    elif ratio < 0.80:
        condition = "Hurt"; injury_time = 60.0
    candidate["condition"] = condition
    candidate["injury_remaining"] = injury_time
    candidate["stress"] = min(100.0, float(candidate.get("stress", 10.0)) + float(maxi(0, max_hp - hp)) * 3.0)
    candidate["status"] = "Available"
    candidate["task"] = {}
    if condition != "Healthy":
        var candidate_history: Array = candidate.get("history", [])
        candidate_history.append("Day %d — Injured during rescue: %s." % [day, condition])
        candidate["history"] = candidate_history
    return candidate

'''
text = replace_once(text, 'func _grant_tactical_explore_reward(exp, lead, searches_completed: int):\n', candidate_helper + 'func _grant_tactical_explore_reward(exp, lead, searches_completed: int):\n', 'rescue candidate health helper')

old_rescue_success = '    if kind == "rescue" and bool(result.get("rescued", false)):\n        _queue_recruit_offer(event, "A Survivor Makes It Out", "You get the stranger out of %s alive. Away from the infected and with a little room to breathe, they finally decide whether they trust First Fire enough to come back with you." % place, "tactical_rescue")\n'
new_rescue_success = '    if kind == "rescue" and bool(result.get("rescued", false)):\n        var rescue_candidate: Dictionary = _prepare_rescue_candidate(encounter.get("rescue_candidate", {}), int(result.get("rescue_survivor_hp", 1)), int(result.get("rescue_survivor_max_hp", TacticalBalance.RESCUE_SURVIVOR_HP)))\n        var rescue_name := str(rescue_candidate.get("name", "The survivor"))\n        _queue_recruit_offer(event, "%s Makes It Out" % rescue_name, "You get %s out of %s alive. Away from the infected and with a little room to breathe, they finally decide whether they trust First Fire enough to come back with you." % [rescue_name, place], "tactical_rescue", "", rescue_candidate)\n'
text = replace_once(text, old_rescue_success, new_rescue_success, 'successful rescue preserves identity')

old_rescue_fail = '    elif kind == "rescue" and not bool(result.get("objective_done", false)):\n        _queue_field_result(event, "Withdrew from %s" % place, "You found a way out and chose survival over the rescue. The expedition can continue, but the opportunity here is gone.", "The party withdrew from %s before completing the tactical objective." % place)\n'
new_rescue_fail = '''    elif kind == "rescue" and not bool(result.get("objective_done", false)):
        var rescue_name := str(encounter.get("rescue_candidate", {}).get("name", "the survivor"))
        if not bool(result.get("rescue_survivor_alive", true)):
            _queue_field_result(event, "Rescue Failed", "%s did not survive the encounter at %s. You still make it back out, but there is nobody left to bring home." % [rescue_name, place], "The attempted rescue at %s failed, but the expedition survivor escaped." % place)
        elif bool(result.get("rescue_contacted", false)):
            _queue_field_result(event, "Separated at %s" % place, "You reached %s, but extracted before both of you could reach the exit. The expedition continues, but the rescue opportunity is lost." % rescue_name, "The party reached a stranded survivor at %s but could not extract them." % place)
        else:
            _queue_field_result(event, "Withdrew from %s" % place, "You found a way out and chose survival over the rescue. The expedition can continue, but the opportunity here is gone.", "The party withdrew from %s before completing the tactical objective." % place)
'''
text = replace_once(text, old_rescue_fail, new_rescue_fail, 'rescue failure outcomes')
write(path, text)

# ---------------------------------------------------------------------------
# Deterministic architecture regressions.
# ---------------------------------------------------------------------------
path = 'game/scripts/ci/FFArchitectureSmoke.gd'
text = read(path)
text = replace_once(
    text,
    '    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Camp Perimeter"), "starting zone scenario catalog"): return\n',
    '    if not _check(TacticalScenarios.KIND_WEIGHTS.has("Camp Perimeter"), "starting zone scenario catalog"): return\n    if not _check(str(TacticalScenarios.KIND_WEIGHTS["Camp Perimeter"][0][0]) == "rescue", "starting zone rescue tactical option"): return\n',
    'starting rescue smoke',
)
text = replace_once(
    text,
    '    if not _check(TacticalBalance.zombie_count("Residential Blocks", "explore") < TacticalBalance.zombie_count("Residential Blocks", "ambush"), "objective-specific zombie balance"): return\n',
    '    if not _check(TacticalBalance.zombie_count("Residential Blocks", "explore") < TacticalBalance.zombie_count("Residential Blocks", "ambush"), "objective-specific zombie balance"): return\n    if not _check(TacticalBalance.zombie_count("Nearby Streets", "rescue") < TacticalBalance.zombie_count("Nearby Streets", "ambush"), "rescue escort pressure balance"): return\n    if not _check(TacticalBalance.RESCUE_SURVIVOR_HP > 0 and TacticalBalance.RESCUE_CONTACT_TICKS > 0, "rescue escort tuning"): return\n',
    'rescue balance smoke',
)
write(path, text)

# ---------------------------------------------------------------------------
# Docs / changelog.
# ---------------------------------------------------------------------------
path = 'README_CONTEXT.md'
text = read(path)
old = 'Current tactical encounter types include:\n\n- **Survivor Rescue**\n- **Explore Location**\n- **Ambush**\n'
new = 'Current tactical encounter types include:\n\n- **Survivor Rescue** — now a physical escort objective: reach a named stranded survivor, make contact, keep them alive, and extract together. The rescued person cannot fight; infected can attack them; abandoning the rescue remains a valid self-extraction. The same survivor identity/appearance/condition carries into the post-extraction recruitment offer. Rescue can now occur from Camp Perimeter onward.\n- **Explore Location**\n- **Ambush**\n'
text = replace_once(text, old, new, 'context rescue description')
write(path, text)

path = 'ARCHITECTURE.md'
text = read(path)
text = replace_once(
    text,
    '### `FFCombat.gd`\nTactical runtime once a physical scenario exists: board state, actors, movement/action timing, zombie behavior, vision/fog, facing, sound, doors/glass/hazards, melee/firearms, objectives, and completion.\n',
    '### `FFCombat.gd`\nTactical runtime once a physical scenario exists: board state, actors, movement/action timing, zombie behavior, vision/fog, facing, sound, doors/glass/hazards, melee/firearms, objectives, temporary rescue-civilian escort behavior, and completion. A rescue civilian is an objective NPC, not a second expedition survivor or combat companion.\n',
    'architecture rescue ownership',
)
text = replace_once(
    text,
    '### `FFTacticalBalance.gd`\nPure Beta tuning rules for tactical combat and exploration: objective-specific infected counts, multi-search sizing/rewards, search time/noise, melee/firearm accuracy, Guard defense, Shove resistance/stagger, and infected mass damage. Keeping these values outside `FFCombat.gd` makes balance iteration deterministic and testable without creating a new gameplay pillar.\n',
    '### `FFTacticalBalance.gd`\nPure Beta tuning rules for tactical combat, rescue, and exploration: objective-specific infected counts, rescue civilian durability/contact/escort pacing, multi-search sizing/rewards, search time/noise, melee/firearm accuracy, Guard defense, Shove resistance/stagger, and infected mass damage. Keeping these values outside `FFCombat.gd` makes balance iteration deterministic and testable without creating a new gameplay pillar.\n',
    'architecture balance rescue',
)
write(path, text)

path = 'CHANGELOG.md'
text = read(path)
entry = '''## Beta Candidate — Physical Survivor Rescue — 2026-09-10

- Promoted Survivor Rescue from an abstract SOS-cell objective into a physical tactical escort encounter.
- Rescue encounters now generate a real named survivor with a persistent appearance and identity before the board opens.
- The player must reach the survivor and explicitly make contact; the civilian then follows the player but does not fight.
- Infected can see, target, injure, and kill the rescue civilian, so route choice, noise, Guard/Shove use, and extraction timing matter.
- Successful rescue requires the expedition survivor and rescue civilian to reach an exit together; self-extraction remains valid at the cost of the rescue.
- The exact rescued survivor, including tactical injury condition, carries into the post-extraction recruitment offer instead of generating a different person afterward.
- Rescue is now available in Camp Perimeter as well as later zones; rescue encounters run one infected below zone baseline to account for the vulnerable escort.
- Active rescue position, HP, contact state, and escort timing persist across tactical save/resume without changing save schema 7.

'''
text = replace_once(text, '# First Fire — Changelog\n\n', '# First Fire — Changelog\n\n' + entry, 'changelog rescue entry')
write(path, text)

# Remove this patcher from the resulting repository commit.
Path('.github/scripts/temp_rescue_tactical_patch.py').unlink()
print('FIRST_FIRE_RESCUE_TACTICAL_PATCH_OK')
