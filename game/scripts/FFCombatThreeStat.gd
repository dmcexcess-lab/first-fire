extends "res://scripts/FFCombat.gd"

const ThreeStatRules = preload("res://scripts/FFThreeStatRules.gd")
const BalanceThree = preload("res://scripts/FFTacticalBalance.gd")
const TimeThree = preload("res://scripts/FFTacticalTime.gd")
const SoundThree = preload("res://scripts/FFTacticalSound.gd")
const LightingThree = preload("res://scripts/FFTacticalLighting.gd")

var btn_sprint := Rect2(148, 788, 98, 42)

func weapon_profile(name: String) -> Dictionary:
    return ThreeStatRules.weapon_profile(name)

func make_actor(s, pos: Vector2i, controlled: bool) -> Dictionary:
    var actor: Dictionary = super.make_actor(s, pos, controlled)
    if actor.is_empty(): return actor
    actor["skills"] = ThreeStatRules.normalize_stats(actor.get("skills", {}))
    actor["sprinting"] = false
    return actor

func setup_rescuee() -> void:
    super.setup_rescuee()
    if not rescuee.is_empty():
        rescuee["skills"] = ThreeStatRules.normalize_stats(rescuee.get("skills", {}))
        rescuee["sprinting"] = false

func restore_runtime():
    super.restore_runtime()
    if not player.is_empty(): player["sprinting"] = bool(runtime.get("sprinting", false))

func persist_runtime():
    super.persist_runtime()
    if not player.is_empty():
        runtime["sprinting"] = bool(player.get("sprinting", false))
        Game.update_combat_runtime(runtime)

func view_range() -> int:
    # The active three-stat model has no perception/survival skill. Portable
    # light and fatigue set the hard ceiling; actual cell light shapes the cone.
    var r := 5
    if player_light_on:
        r += LightingThree.item_view_bonus(str(player.get("secondary", "")))
    if float(player.get("fatigue", 0.0)) >= 80.0:
        r -= 1
    return clampi(r, 4, 8)

func recalc_visibility():
    recalc_lighting()
    visible_cells.clear()
    var max_range := view_range()
    for y in range(H):
        for x in range(W):
            var cell := Vector2i(x, y)
            var distance := manhattan(player.pos, cell)
            if cell == player.pos or distance <= 1:
                visible_cells[cell] = true
                memory[cell] = true
                continue
            if not line_clear(player.pos, cell):
                continue
            var light := float(light_levels.get(cell, 0.0))
            var lit_range := LightingThree.vision_range_for_light(light, max_range)
            var cone_dot := LightingThree.vision_cone_min_dot(light)
            if distance > lit_range or not in_cone(player.pos, player.facing, cell, lit_range, cone_dot):
                continue
            if LightingThree.visible_at_distance(light, distance, max_range):
                visible_cells[cell] = true
                memory[cell] = true
    for i in range(zombies.size()):
        if zombies[i].dead:
            last_seen.erase(i)
            continue
        if visible_cells.has(zombies[i].pos):
            last_seen[i] = zombies[i].pos
        elif last_seen.has(i) and visible_cells.has(last_seen[i]):
            last_seen.erase(i)

func _input(e):
    if not visible or not initialized: return
    if e is InputEventScreenTouch:
        get_viewport().set_input_as_handled()
        var touch_id := int(e.index)
        if e.pressed:
            if active_touch_ids.has(touch_id): return
            active_touch_ids[touch_id] = true
            dispatch_point(e.position)
        else: active_touch_ids.erase(touch_id)
        return
    if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
        if DisplayServer.is_touchscreen_available(): get_viewport().set_input_as_handled(); return
        if e.pressed: dispatch_point(e.position); get_viewport().set_input_as_handled()
        return
    if e is InputEventKey and e.pressed and not e.echo:
        get_viewport().set_input_as_handled()
        match e.keycode:
            KEY_Q: guarded_action("TURN_L", func(): rotate_player(-1))
            KEY_E: guarded_action("TURN_R", func(): rotate_player(1))
            KEY_W, KEY_UP: step_forward()
            KEY_S, KEY_DOWN: step_backward()
            KEY_C: toggle_crouch()
            KEY_SHIFT: toggle_sprint()
            KEY_G: guard()
            KEY_X: shove()
            KEY_L: toggle_player_light()
            KEY_F, KEY_SPACE: interact()

func dispatch_point(pos: Vector2):
    if game_over: return
    if btn_turn_left.has_point(pos): guarded_action("TURN_L", func(): rotate_player(-1)); return
    if btn_turn_right.has_point(pos): guarded_action("TURN_R", func(): rotate_player(1)); return
    if btn_forward.has_point(pos): step_forward(); return
    if btn_back.has_point(pos): step_backward(); return
    if btn_crouch.has_point(pos): toggle_crouch(); return
    if btn_sprint.has_point(pos): toggle_sprint(); return
    if btn_guard.has_point(pos): guard(); return
    if btn_light.has_point(pos): toggle_player_light(); return
    if btn_shove.has_point(pos): shove(); return
    if pos.y < MAP_TOP or pos.y >= CONTROL_TOP: return
    var cell := screen_to_cell(pos)
    if not inside(cell): return
    var delta: Vector2i = cell - player.pos
    if str(context.get("kind", "")) == "rescue" and rescuee_at(cell) and visible_cells.has(cell) and manhattan(player.pos, cell) == 1:
        player.facing = delta; contact_rescuee(); return
    if str(context.get("kind", "")) == "explore" and explore_cells.has(cell) and not explore_searched.has(cell) and (cell == player.pos or manhattan(player.pos, cell) == 1):
        if cell != player.pos: player.facing = delta
        search_explore_cell(cell); return
    if manhattan(player.pos, cell) == 1:
        player.facing = delta
        if zombie_at(cell) != -1: melee(cell); return
        if doors.has(cell) or glass.has(cell): interact(); return
        try_move(delta); return
    if visible_cells.has(cell):
        var zi := zombie_at(cell)
        if zi != -1:
            if bool(player.weapon.gun): shoot(zi)
            elif can_melee_reach(cell): melee(cell)
            else: msg = "Too far for %s." % player.weapon.name; queue_redraw()
            return
        if barrels.has(cell): shoot_barrel(cell); return

func toggle_crouch():
    player["guarding"] = false
    player["sprinting"] = false
    player.crouched = not bool(player.crouched)
    player.move_state = "CROUCH" if player.crouched else "STILL"
    msg = "Stealth on — quieter, slower." if player.crouched else "Stealth off."
    commit_action(TimeThree.stance_cost(player))

func toggle_sprint():
    player["guarding"] = false
    player.crouched = false
    player["sprinting"] = not bool(player.get("sprinting", false))
    player.move_state = "SPRINT" if player["sprinting"] else "STILL"
    msg = "Sprint on — fast and loud." if player["sprinting"] else "Sprint off."
    commit_action(maxi(22, TimeThree.stance_cost(player) / 2))

func rotate_player(step: int):
    player["sprinting"] = false
    super.rotate_player(step)

func step_backward():
    player["sprinting"] = false
    super.step_backward()

func try_move(dir: Vector2i):
    var dest: Vector2i = player.pos + dir
    player.facing = dir
    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest) or rescuee_at(dest):
        msg = "Blocked."; recalc_visibility(); refresh_intents(); queue_redraw(); return
    player["guarding"] = false
    player.pos = dest
    player.last_dir = dir
    var agility := int(player.get("skills", {}).get("Agility", 0))
    var sprinting := bool(player.get("sprinting", false))
    player.move_state = "SPRINT" if sprinting else ("CROUCH" if player.crouched else "WALK")
    var noise: int = ThreeStatRules.sprint_noise(agility) if sprinting else (ThreeStatRules.stealth_noise(agility) if player.crouched else 18)
    emit_noise(dest, noise, "running" if sprinting else SoundThree.surface_step_label(str(ground.get(dest, "asphalt")), bool(player.crouched)), true)
    if not sprinting:
        var breathing := TimeThree.breath_noise(player)
        if breathing > 0: emit_noise(dest, breathing, "breathing", true)
    check_objective_and_exit()
    var base_cost: int = TimeThree.movement_cost(player, false)
    var cost: int = ThreeStatRules.sprint_move_cost(agility, base_cost) if sprinting else (ThreeStatRules.stealth_move_cost(agility, base_cost) if player.crouched else ThreeStatRules.normal_move_cost(agility, base_cost))
    commit_action(cost)

func stealth_attack(z) -> bool:
    if not bool(player.crouched) or z.state == "CHASE": return false
    var to_player: Vector2i = player.pos - z.pos
    var positional: bool = dominant(to_player) == -z.facing or not zombie_sees_actor(z, player)
    if not positional: return false
    var agility := int(player.get("skills", {}).get("Agility", 0))
    return rng.randf() <= clampf(0.45 + float(agility) * 0.055, 0.45, 0.90)

func melee(target: Vector2i):
    var zi := zombie_at(target)
    if zi == -1: msg = "Nothing in reach."; queue_redraw(); return
    if not can_melee_reach(target): msg = "%s cannot reach that target." % player.weapon.name; queue_redraw(); return
    player["guarding"] = false; player["sprinting"] = false; player.facing = dominant(target - player.pos)
    stats["melee"] = int(stats.get("melee", 0)) + 1
    var z: Dictionary = zombies[zi]
    var stealth: bool = stealth_attack(z)
    var combat := int(player.get("skills", {}).get("Combat", 0))
    var chance: float = ThreeStatRules.attack_chance(combat, attack_penalty(player), float(player.weapon.get("accuracy", 0.0)), stealth)
    if rng.randf() <= chance:
        var d: int = ThreeStatRules.melee_damage(player.weapon, combat, stealth, rng)
        zombies[zi].hp -= d
        _flash_hit(z.pos, int(zombies[zi].hp) <= 0)
        msg = "%s %s hit for %d%s." % [str(player.weapon.get("class_label", "MELEE")), player.weapon.name, d, " — STEALTH" if stealth else ""]
        if int(zombies[zi].hp) <= 0: kill_zombie(zi, stealth)
        else:
            reveal_melee_target(zi)
            if int(player.weapon.get("push", 0)) > 0:
                var pushed: bool = push_zombie(zi, player.facing)
                zombies[zi].next += BalanceThree.shove_stagger_ticks(str(zombies[zi].get("mass", "MED")), not pushed) / 2
    else: msg = "%s misses." % player.weapon.name
    emit_noise(player.pos, maxi(8, int(player.weapon.noise)), "melee impact", true)
    commit_action(TimeThree.attack_cost(player, int(player.weapon.time)))

func shoot(i: int):
    if not bool(player.weapon.gun): msg = "No firearm equipped."; queue_redraw(); return
    var z: Dictionary = zombies[i]
    if z.dead or not visible_cells.has(z.pos): return
    if not Game.consume_combat_ammo(int(player.weapon.ammo)): msg = "No ammunition."; queue_redraw(); return
    player["guarding"] = false; player["sprinting"] = false; player.facing = dominant(z.pos - player.pos)
    var dist := manhattan(player.pos, z.pos)
    var combat := int(player.get("skills", {}).get("Combat", 0))
    var range_penalty := float(maxi(0, dist - 3)) * 0.04
    var chance: float = ThreeStatRules.attack_chance(combat, attack_penalty(player) + range_penalty, float(player.weapon.get("gaccuracy", 0.0)), false)
    stats.shots += 1; _flash_muzzle(player.pos, player.facing)
    if rng.randf() <= chance:
        var d: int = ThreeStatRules.gun_damage(player.weapon, combat, rng)
        zombies[i].hp -= d; _flash_hit(z.pos, int(zombies[i].hp) <= 0)
        msg = "%s %s hits for %d." % [str(player.weapon.get("class_label", "GUN")), player.weapon.name, d]
        if int(zombies[i].hp) <= 0: kill_zombie(i, false)
        else: reveal_melee_target(i)
        if int(player.weapon.get("hands", 1)) == 2 and player.weapon.name == "Shotgun": apply_shotgun_spread(i, z.pos, d)
    else: msg = "%s misses." % player.weapon.name
    emit_noise(player.pos, int(player.weapon.gnoise), "gunshot", true)
    commit_action(TimeThree.attack_cost(player, int(player.weapon.gtime)))

func guard():
    player["sprinting"] = false
    super.guard()

func shove():
    player["sprinting"] = false
    # Base shove explicitly clears guarding before resolution. Shoving always
    # sacrifices the defensive state even when the shove misses.
    super.shove()

func zombie_attack(i: int, target_actor: Dictionary):
    var guarded := bool(target_actor.get("guarding", false))
    var hit: float = BalanceThree.zombie_hit_chance(target_actor)
    if target_actor.controlled and guarded: target_actor["guarding"] = false
    if rng.randf() <= hit:
        var damage_range: Vector2i = BalanceThree.zombie_damage_range(str(zombies[i].get("mass", "MED")))
        var dmg := rng.randi_range(damage_range.x, damage_range.y)
        if guarded: dmg = maxi(1, dmg - 1)
        # No armor layer: clothing never reduces or cancels physical damage.
        target_actor.hp -= dmg
        _flash_hit(target_actor.pos, int(target_actor.hp) <= 0)
        if target_actor.controlled:
            stats.damage += dmg
            msg = "The infected breaks through your guard for %d." % dmg if guarded else "The infected hits you for %d." % dmg
        else: msg = "%s gets hit." % target_actor.name
        if target_actor.hp <= 0: target_actor.hp = 0; target_actor.dead = true
    elif target_actor.controlled:
        msg = "You deflect the grab." if guarded else ("You outrun the grab." if bool(target_actor.get("sprinting", false)) else "You avoid the grab.")
    zombies[i].next = tick + TimeThree.zombie_attack_cost(zombies[i])

func draw_hud():
    draw_rect(Rect2(0,0,SCREEN_W,INFO_H),Color(.035,.045,.04,.99))
    var scene_label := "%s  •  %s  •  %s" % [location_name, scene_time.to_upper(), "POWER" if power_on else "NO POWER"]
    draw_string(font,Vector2(10,22),scene_label,HORIZONTAL_ALIGNMENT_LEFT,370,14,Color.WHITE)
    draw_string(font,Vector2(10,47),"%s  HP %d/%d  %s"%[player.name,int(player.hp),int(player.max_hp),str(player.condition).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,370,13,Color(.70,.84,1))
    var weapon_line := "%s | %s" % [str(player.weapon.get("class_label", "1H MELEE")), str(player.weapon.name)]
    if bool(player.weapon.gun): weapon_line += " | Ammo %d" % int(Game.resources.get("Ammo", 0))
    draw_string(font, Vector2(10,69), weapon_line, HORIZONTAL_ALIGNMENT_LEFT, 370, 10, Color(.82,.84,.82))
    var stats_line := "COM %d  AGI %d  LEAD %d" % [int(player.skills.get("Combat",0)), int(player.skills.get("Agility",0)), int(player.skills.get("Leadership",0))]
    draw_string(font, Vector2(10,89), stats_line, HORIZONTAL_ALIGNMENT_LEFT, 370, 9, Color(.72,.78,.74))
    var objective_text := "ESCAPE"
    match str(context.get("kind","ambush")):
        "rescue":
            var rescue_name := str(rescuee.get("name", "SURVIVOR")).to_upper()
            if not rescuee.is_empty() and rescuee.dead: objective_text = "RESCUE FAILED | ESCAPE"
            elif rescue_contacted: objective_text = "ESCORT %s TO EXIT" % rescue_name
            else: objective_text = "REACH %s" % rescue_name
        "explore":
            var field_gear := str(context.get("field_gear", "LOOT"))
            objective_text = ("FOUND %s" % field_gear) if objective_done else ("SEARCH %d/%d | FIND %s" % [explore_searched.size(), explore_cells.size(), field_gear])
    objective_text += "  |  Exits %d" % exit_cells.size()
    draw_string(font,Vector2(10,112),"Objective: %s"%objective_text,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color(.96,.80,.34))
    draw_string(font,Vector2(10,133),msg,HORIZONTAL_ALIGNMENT_LEFT,370,10,Color(.93,.94,.90))
    if any_zombie_sees_player(): draw_string(font,Vector2(0,MAP_TOP+20),"!! SPOTTED !!",HORIZONTAL_ALIGNMENT_CENTER,SCREEN_W,18,Color(1,.22,.16))
    draw_rect(Rect2(0,CONTROL_TOP,SCREEN_W,SCREEN_H-CONTROL_TOP),Color(.025,.032,.028,.94)); draw_rect(Rect2(0,CONTROL_TOP,SCREEN_W,2),Color(.38,.42,.38))
    draw_button(btn_turn_left,"TURN L",false,17); draw_button(btn_crouch,"STEALTH",bool(player.crouched),10); draw_button(btn_forward,"FORWARD",false,11)
    draw_button(btn_turn_right,"TURN R",false,17); draw_button(btn_back,"BACK",false,11); draw_button(btn_guard,"GUARD",bool(player.get("guarding", false)),10)
    var portable_light := str(player.get("secondary", "")); var has_portable_light := LightingThree.item_emits_light(portable_light)
    draw_button(btn_light,"LIGHT ON" if player_light_on else "LIGHT OFF",has_portable_light and player_light_on,9); draw_button(btn_shove,"SHOVE",false,10); draw_button(btn_sprint,"SPRINT",bool(player.get("sprinting", false)),10)
    var agility := int(player.skills.get("Agility", 0)); var base_step: int = TimeThree.movement_cost(player, false)
    var step_cost: int = ThreeStatRules.sprint_move_cost(agility, base_step) if bool(player.get("sprinting", false)) else (ThreeStatRules.stealth_move_cost(agility, base_step) if player.crouched else ThreeStatRules.normal_move_cost(agility, base_step))
    draw_string(font,Vector2(258,821),"T %d  STEP %d  K %d"%[tick,step_cost,int(stats.kills)],HORIZONTAL_ALIGNMENT_CENTER,124,8,Color(.62,.68,.64))
