extends "res://scripts/FFCombat.gd"

const ThreeStatRules = preload("res://scripts/FFThreeStatRules.gd")
const BalanceThree = preload("res://scripts/FFTacticalBalance.gd")
const TimeThree = preload("res://scripts/FFTacticalTime.gd")
const SoundThree = preload("res://scripts/FFTacticalSound.gd")
const LightingThree = preload("res://scripts/FFTacticalLighting.gd")

var btn_sprint := Rect2(148, 788, 98, 42)
var btn_forward_primary := Rect2(148, 654, 98, 42)
var btn_reload := Rect2(8, 654, 136, 38)

func weapon_profile(name: String) -> Dictionary:
    return ThreeStatRules.weapon_profile(name)

func make_actor(s, pos: Vector2i, controlled: bool) -> Dictionary:
    var actor: Dictionary = super.make_actor(s, pos, controlled)
    if actor.is_empty(): return actor
    actor["skills"] = ThreeStatRules.normalize_stats(actor.get("skills", {}))
    actor["sprinting"] = false
    actor["loaded"] = ThreeStatRules.weapon_mag_capacity(actor.get("weapon", {}))
    actor["needs_pump"] = false
    return actor

func setup_rescuee() -> void:
    super.setup_rescuee()
    if not rescuee.is_empty():
        rescuee["skills"] = ThreeStatRules.normalize_stats(rescuee.get("skills", {}))
        rescuee["sprinting"] = false

func restore_runtime():
    super.restore_runtime()
    if not player.is_empty():
        player["guarding"] = false
        player["sprinting"] = bool(runtime.get("sprinting", false))
        var cap := ThreeStatRules.weapon_mag_capacity(player.get("weapon", {}))
        player["loaded"] = clampi(int(runtime.get("weapon_loaded", cap)), 0, cap)
        player["needs_pump"] = bool(runtime.get("weapon_needs_pump", false))
        if runtime.has("secondary_item"):
            player["secondary"] = str(runtime.get("secondary_item", player.get("secondary", "")))
            player["equipment"]["Secondary"] = player["secondary"]
        if runtime.has("secondary_state"):
            var state_value = runtime.get("secondary_state", {})
            player["secondary_state"] = state_value.duplicate(true) if state_value is Dictionary else {}
        if str(player.get("secondary", "")) == "Flashlight" and float(player.get("secondary_state", {}).get("charge", 0.0)) <= 0.0:
            player_light_on = false
    runtime.erase("guarding")

func persist_runtime():
    if not player.is_empty(): player["guarding"] = false
    super.persist_runtime()
    runtime.erase("guarding")
    if not player.is_empty():
        runtime["sprinting"] = bool(player.get("sprinting", false))
        runtime["weapon_loaded"] = int(player.get("loaded", 0))
        runtime["weapon_needs_pump"] = bool(player.get("needs_pump", false))
        runtime["secondary_item"] = str(player.get("secondary", ""))
        runtime["secondary_state"] = player.get("secondary_state", {}).duplicate(true)
        Game.update_combat_runtime(runtime)

func view_range() -> int:
    # Weapon sightline matters for the ranged ladder. Darkness still contracts
    # actual visibility through FFTacticalLighting.
    var r := 5
    if player_light_on:
        r += LightingThree.item_view_bonus(str(player.get("secondary", "")))
    if bool(player.get("weapon", {}).get("gun", false)):
        r = maxi(r, mini(10, ThreeStatRules.weapon_sight_range(player.get("weapon", {}))))
    if float(player.get("fatigue", 0.0)) >= 80.0:
        r -= 1
    return clampi(r, 4, 10)

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
            KEY_X: shove()
            KEY_R: reload_or_pump()
            KEY_L: use_secondary_item()
            KEY_F, KEY_SPACE: interact()

func dispatch_point(pos: Vector2):
    if game_over: return
    if btn_turn_left.has_point(pos): guarded_action("TURN_L", func(): rotate_player(-1)); return
    if btn_turn_right.has_point(pos): guarded_action("TURN_R", func(): rotate_player(1)); return
    if btn_forward_primary.has_point(pos): step_forward(); return
    if btn_back.has_point(pos): step_backward(); return
    if btn_crouch.has_point(pos): toggle_crouch(); return
    if btn_sprint.has_point(pos): toggle_sprint(); return
    if btn_reload.has_point(pos): reload_or_pump(); return
    if btn_light.has_point(pos): use_secondary_item(); return
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
        if loot_containers.has(cell): search_loot_container(cell); return
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
    player["sprinting"] = false
    player.crouched = not bool(player.crouched)
    player.move_state = "CROUCH" if player.crouched else "STILL"
    msg = "Stealth on — quieter, slower." if player.crouched else "Stealth off."
    commit_action(TimeThree.stance_cost(player))

func toggle_sprint():
    player.crouched = false
    player["sprinting"] = not bool(player.get("sprinting", false))
    player.move_state = "SPRINT" if player["sprinting"] else "STILL"
    msg = "Sprint on — fast and loud." if player["sprinting"] else "Sprint off."
    commit_action(maxi(22, TimeThree.stance_cost(player) / 2))

func rotate_player(step: int):
    player["sprinting"] = false
    super.rotate_player(step)

func movement_action_cost(backwards: bool = false) -> int:
    var timing_actor:Dictionary=player.duplicate(false)
    timing_actor["crouched"]=false
    var base_cost:int=TimeThree.movement_cost(timing_actor,backwards)
    var agility:=int(player.get("skills",{}).get("Agility",0))
    if bool(player.get("sprinting",false)) and not backwards:
        return ThreeStatRules.sprint_move_cost(agility,base_cost)
    if bool(player.get("crouched",false)):
        return ThreeStatRules.stealth_move_cost(agility,base_cost)
    return ThreeStatRules.normal_move_cost(agility,base_cost)

func step_backward():
    player["sprinting"] = false
    super.step_backward()

func try_move(dir: Vector2i):
    var dest: Vector2i = player.pos + dir
    player.facing = dir
    if blocked(dest) or zombie_at(dest) != -1 or ally_at(dest) or rescuee_at(dest):
        msg = "Blocked."; recalc_visibility(); refresh_intents(); queue_redraw(); return
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
    commit_action(movement_action_cost(false))

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
    player["sprinting"] = false; player.facing = dominant(target - player.pos)
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

func _can_fire_ranged() -> bool:
    if not bool(player.get("weapon", {}).get("gun", false)):
        msg = "No ranged weapon equipped."
        queue_redraw()
        return false
    if bool(player.get("needs_pump", false)):
        msg = "Pump the shotgun before firing again."
        queue_redraw()
        return false
    if int(player.get("loaded", 0)) <= 0:
        msg = "%s is empty — reload." % str(player.weapon.name)
        queue_redraw()
        return false
    return true

func reload_or_pump() -> void:
    if not bool(player.get("weapon", {}).get("gun", false)):
        msg = "No ranged weapon to reload."
        queue_redraw()
        return
    player["sprinting"] = false
    if bool(player.get("needs_pump", false)):
        player["needs_pump"] = false
        msg = "Pump cycled — next shell chambered."
        emit_noise(player.pos, 12, "shotgun pump", true)
        commit_action(ThreeStatRules.weapon_pump_time(player.weapon))
        return
    var capacity := ThreeStatRules.weapon_mag_capacity(player.weapon)
    if int(player.get("loaded", 0)) >= capacity:
        msg = "%s is already loaded." % str(player.weapon.name)
        queue_redraw()
        return
    player["loaded"] = capacity
    msg = "%s reloaded — %d/%d." % [str(player.weapon.name), capacity, capacity]
    emit_noise(player.pos, 7, "reload", true)
    commit_action(ThreeStatRules.weapon_reload_time(player.weapon))

func _ranged_hit_chance(distance: int) -> float:
    var combat := int(player.get("skills", {}).get("Combat", 0))
    var penalty := attack_penalty(player) + ThreeStatRules.ranged_falloff_penalty(player.weapon, distance)
    return ThreeStatRules.attack_chance(combat, penalty, float(player.weapon.get("gaccuracy", 0.0)), false)

func _apply_ranged_hit(index: int, damage: int) -> void:
    if index < 0 or index >= zombies.size() or zombies[index].dead:
        return
    zombies[index].hp -= damage
    _flash_hit(zombies[index].pos, int(zombies[index].hp) <= 0)
    if int(zombies[index].hp) <= 0:
        kill_zombie(index, false)
    else:
        reveal_melee_target(index)

func _inside_shotgun_cone(cell: Vector2i, max_range: int, spread_scale: float) -> bool:
    var origin: Vector2i = player.pos
    var facing: Vector2i = player.facing
    var rel: Vector2i = cell - origin
    var forward: int = rel.x * facing.x + rel.y * facing.y
    if forward < 1 or forward > max_range:
        return false
    var side_axis := Vector2i(-facing.y, facing.x)
    var lateral := absi(rel.x * side_axis.x + rel.y * side_axis.y)
    var half_width := maxi(1, int(ceil(float(forward) * spread_scale)))
    return lateral <= half_width

func _fire_shotgun(primary_index: int) -> void:
    var projectile_range := ThreeStatRules.weapon_projectile_range(player.weapon)
    var projectile_count := ThreeStatRules.weapon_projectiles(player.weapon)
    var spread_scale := ThreeStatRules.weapon_spread_scale(player.weapon)
    var candidates: Array = []
    if primary_index >= 0 and primary_index < zombies.size() and not zombies[primary_index].dead:
        var primary_cell: Vector2i = zombies[primary_index].pos
        if _inside_shotgun_cone(primary_cell, projectile_range, spread_scale) and line_clear(player.pos, primary_cell):
            candidates.append(primary_index)
    for j in range(zombies.size()):
        if j == primary_index or zombies[j].dead:
            continue
        var cell: Vector2i = zombies[j].pos
        if _inside_shotgun_cone(cell, projectile_range, spread_scale) and line_clear(player.pos, cell):
            candidates.append(j)
    var hits := 0
    var pellets := mini(projectile_count, candidates.size())
    for n in range(pellets):
        var index := int(candidates[n])
        var distance := manhattan(player.pos, zombies[index].pos)
        if rng.randf() <= _ranged_hit_chance(distance):
            var damage := ThreeStatRules.gun_damage(player.weapon, int(player.get("skills", {}).get("Combat", 0)), rng)
            _apply_ranged_hit(index, damage)
            hits += 1
    if candidates.is_empty():
        msg = "%s fires, but the pellets fall short." % str(player.weapon.name)
    else:
        msg = "%s fires %d projectiles — %d hit." % [str(player.weapon.name), projectile_count, hits]

func _fire_single(primary_index: int) -> void:
    var distance := manhattan(player.pos, zombies[primary_index].pos)
    var hard_range := ThreeStatRules.weapon_projectile_range(player.weapon)
    if hard_range > 0 and distance > hard_range:
        msg = "%s fires, but the projectile falls short." % str(player.weapon.name)
        return
    if rng.randf() <= _ranged_hit_chance(distance):
        var damage := ThreeStatRules.gun_damage(player.weapon, int(player.get("skills", {}).get("Combat", 0)), rng)
        _apply_ranged_hit(primary_index, damage)
        msg = "%s hits for %d." % [str(player.weapon.name), damage]
    else:
        msg = "%s misses." % str(player.weapon.name)

func shoot(i: int):
    if not _can_fire_ranged():
        return
    var z: Dictionary = zombies[i]
    if z.dead or not visible_cells.has(z.pos):
        return
    player["sprinting"] = false
    player.facing = dominant(z.pos - player.pos)
    player["loaded"] = maxi(0, int(player.get("loaded", 0)) - 1)
    if ThreeStatRules.weapon_requires_pump(player.weapon):
        player["needs_pump"] = true
    stats.shots += 1
    if bool(player.weapon.get("firearm", false)):
        _flash_muzzle(player.pos, player.facing)
    if ThreeStatRules.weapon_pattern(player.weapon) == "shotgun":
        _fire_shotgun(i)
    else:
        _fire_single(i)
    emit_noise(player.pos, int(player.weapon.gnoise), "crossbow shot" if player.weapon.name == "Crossbow" else "gunshot", true)
    commit_action(TimeThree.attack_cost(player, int(player.weapon.gtime)))

func shoot_barrel(cell: Vector2i):
    if not _can_fire_ranged():
        return
    if not visible_cells.has(cell):
        return
    player["sprinting"] = false
    player.facing = dominant(cell - player.pos)
    player["loaded"] = maxi(0, int(player.get("loaded", 0)) - 1)
    if ThreeStatRules.weapon_requires_pump(player.weapon):
        player["needs_pump"] = true
    stats.shots += 1
    if bool(player.weapon.get("firearm", false)):
        _flash_muzzle(player.pos, player.facing)
    var distance := manhattan(player.pos, cell)
    var hard_range := ThreeStatRules.weapon_projectile_range(player.weapon)
    var can_reach := hard_range <= 0 or distance <= hard_range
    if can_reach and rng.randf() <= _ranged_hit_chance(distance):
        barrels.erase(cell)
        _flash_hit(cell, true)
        msg = "The container erupts."
        for j in range(zombies.size()):
            if zombies[j].dead:
                continue
            var blast_distance := manhattan(cell, zombies[j].pos)
            if blast_distance <= 2:
                zombies[j].hp -= 16 - blast_distance * 4
                if zombies[j].hp <= 0:
                    kill_zombie(j, false)
        blast_actor(player, cell)
        if not ally.is_empty() and not ally.dead:
            blast_actor(ally, cell)
        if not rescuee.is_empty() and not rescuee.dead:
            blast_actor(rescuee, cell)
        for glass_cell in glass.keys().duplicate():
            if manhattan(cell, glass_cell) <= 2:
                glass.erase(glass_cell)
        emit_noise(cell, 110, "explosion", true)
    else:
        msg = "%s misses the container." % str(player.weapon.name)
    emit_noise(player.pos, int(player.weapon.gnoise), "gunshot", true)
    commit_action(TimeThree.attack_cost(player, int(player.weapon.gtime)))

func secondary_button_label() -> String:
    var item := str(player.get("secondary", ""))
    if item == "Flashlight":
        var charge := int(round(float(player.get("secondary_state", {}).get("charge", 0.0))))
        return "LIGHT %d%%" % charge
    if item == "Lock Pick":
        return "LOCK PICK %d" % int(player.get("secondary_state", {}).get("uses_left", 0))
    if item == "Firecracker":
        return "FIRECRACKER"
    return "OFF-HAND"

func _consume_secondary_item() -> void:
    player["secondary"] = ""
    player["secondary_state"] = {}
    if player.has("equipment"):
        player["equipment"]["Secondary"] = ""
    player_light_on = false

func _throw_firecracker() -> void:
    var target: Vector2i = player.pos
    for step in range(1, 6):
        var next_cell: Vector2i = player.pos + player.facing * step
        if not inside(next_cell) or walls.has(next_cell) or obstacles.has(next_cell) or (doors.has(next_cell) and not bool(doors[next_cell])):
            break
        target = next_cell
    _consume_secondary_item()
    msg = "Firecracker thrown — every infected nearby hears it."
    emit_noise(target, 100, "firecracker", true)
    commit_action(TimeThree.interaction_cost(player, 70))

func use_secondary_item() -> void:
    var item := str(player.get("secondary", ""))
    if item == "Flashlight":
        var charge := float(player.get("secondary_state", {}).get("charge", 0.0))
        if charge <= 0.0:
            player_light_on = false
            msg = "The Flashlight is out of charge."
            queue_redraw()
            return
        player_light_on = not player_light_on
        msg = "Flashlight on." if player_light_on else "Flashlight off."
        recalc_visibility()
        queue_redraw()
        return
    if item == "Lock Pick":
        var facing_cell: Vector2i = player.pos + player.facing
        if locked_doors.has(facing_cell):
            try_unlock(facing_cell, false)
            return
        if locked_containers.has(facing_cell):
            try_unlock(facing_cell, true)
            return
        msg = "Face a locked door or container to use the Lock Pick."
        queue_redraw()
        return
    if item == "Firecracker":
        _throw_firecracker()
        return
    msg = "No usable off-hand item equipped."
    queue_redraw()

func _drain_flashlight(cost: int) -> void:
    if str(player.get("secondary", "")) != "Flashlight" or not player_light_on:
        return
    var state_value = player.get("secondary_state", {})
    var state: Dictionary = state_value if state_value is Dictionary else {}
    var drain_rate := float(D.GEAR["Flashlight"].get("charge_per_tick", 0.025))
    var charge := maxf(0.0, float(state.get("charge", 0.0)) - float(cost) * drain_rate)
    state["charge"] = charge
    player["secondary_state"] = state
    if charge <= 0.0:
        player_light_on = false
        msg = "The Flashlight battery dies."

func commit_action(cost: int):
    _drain_flashlight(cost)
    super.commit_action(cost)


func shove():
    player["sprinting"] = false
    super.shove()

func zombie_attack(i: int, target_actor: Dictionary):
    var attack_kind := BalanceThree.zombie_attack_kind(rng)
    var mob_size := zombie_mob_size(target_actor.pos, 2)
    var hit: float = BalanceThree.zombie_attack_hit_chance(target_actor, attack_kind, mob_size)
    var outcome := "%s_miss" % attack_kind
    if rng.randf() <= hit:
        var damage_range: Vector2i = BalanceThree.zombie_attack_damage_range(str(zombies[i].get("mass", "MED")), attack_kind)
        var dmg := rng.randi_range(damage_range.x, damage_range.y) + BalanceThree.mob_damage_bonus(mob_size)
        # No armor layer: clothing never reduces or cancels physical damage.
        target_actor.hp -= dmg
        _flash_hit(target_actor.pos, int(target_actor.hp) <= 0)
        outcome = "%s_hit" % attack_kind
        if target_actor.controlled:
            stats.damage += dmg
            if attack_kind == "bite":
                msg = "BITE — the infected tears in for %d." % dmg
            elif mob_size >= 3:
                msg = "The mob crowds you — scratch for %d." % dmg
            else:
                msg = "Scratch — %d damage." % dmg
        else:
            msg = "%s is bitten." % target_actor.name if attack_kind == "bite" else "%s is scratched." % target_actor.name
        if target_actor.hp <= 0:
            target_actor.hp = 0
            target_actor.dead = true
    elif target_actor.controlled:
        msg = "The bite misses." if attack_kind == "bite" else ("You outrun the scratch." if bool(target_actor.get("sprinting", false)) else "You avoid the scratch.")
    var base_attack_cost := TimeThree.zombie_attack_cost(zombies[i])
    zombies[i].next = tick + maxi(45, int(round(float(base_attack_cost) * BalanceThree.mob_attack_cost_multiplier(mob_size))))
    return outcome

func draw_hud():
    draw_rect(Rect2(0,0,SCREEN_W,INFO_H),Color(.035,.045,.04,.99))
    var scene_label := "%s  •  %s  •  %s" % [location_name, scene_time.to_upper(), "POWER" if power_on else "NO POWER"]
    draw_string(font,Vector2(10,22),scene_label,HORIZONTAL_ALIGNMENT_LEFT,370,14,Color.WHITE)
    draw_string(font,Vector2(10,47),"%s  HP %d/%d  %s"%[player.name,int(player.hp),int(player.max_hp),str(player.condition).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,370,13,Color(.70,.84,1))
    var weapon_line := "%s | %s" % [str(player.weapon.get("class_label", "1H MELEE")), str(player.weapon.name)]
    if bool(player.weapon.gun):
        var capacity := ThreeStatRules.weapon_mag_capacity(player.weapon)
        weapon_line += " | %d/%d" % [int(player.get("loaded", capacity)), capacity]
        if bool(player.get("needs_pump", false)):
            weapon_line += " | PUMP"
    draw_string(font, Vector2(10,69), weapon_line, HORIZONTAL_ALIGNMENT_LEFT, 370, 10, Color(.82,.84,.82))
    var stats_line := "COM %d  AGI %d  LEAD %d  CARRY %d/%d" % [int(player.skills.get("Combat",0)), int(player.skills.get("Agility",0)), int(player.skills.get("Leadership",0)), carried_loot_count(), party_carry_capacity()]
    draw_string(font, Vector2(10,89), stats_line, HORIZONTAL_ALIGNMENT_LEFT, 370, 9, Color(.72,.78,.74))
    var exit_steps := nearest_exit_distance(player.pos)
    var exit_text := "EXIT %d" % exit_steps if exit_steps >= 0 else "EXIT ?"
    var objective_text := "ESCAPE • %s" % exit_text
    match str(context.get("kind","ambush")):
        "rescue":
            var rescue_name := str(rescuee.get("name", "SURVIVOR")).to_upper()
            if not rescuee.is_empty() and rescuee.dead:
                objective_text = "RESCUE FAILED • %s" % exit_text
            elif rescue_contacted:
                objective_text = "ESCORT %s • %s" % [rescue_name, exit_text]
            else:
                var rescue_steps := tactical_path_distance(player.pos, rescuee.pos)
                objective_text = "REACH %s %d • THEN EXIT" % [rescue_name, rescue_steps]
        "explore":
            var field_gear := str(context.get("field_gear", "LOOT")).to_upper()
            objective_text = "LOOT %d/%d • %s • %s" % [explore_searched.size(), explore_cells.size(), field_gear, exit_text]
    draw_string(font,Vector2(10,112),"Objective: %s"%objective_text,HORIZONTAL_ALIGNMENT_LEFT,370,11,Color(.96,.80,.34))
    draw_string(font,Vector2(10,133),msg,HORIZONTAL_ALIGNMENT_LEFT,370,10,Color(.93,.94,.90))
    if any_zombie_sees_player(): draw_string(font,Vector2(0,MAP_TOP+20),"!! SPOTTED !!",HORIZONTAL_ALIGNMENT_CENTER,SCREEN_W,18,Color(1,.22,.16))
    draw_rect(Rect2(0,CONTROL_TOP,SCREEN_W,SCREEN_H-CONTROL_TOP),Color(.025,.032,.028,.94)); draw_rect(Rect2(0,CONTROL_TOP,SCREEN_W,2),Color(.38,.42,.38))
    draw_button(btn_turn_left,"TURN L",false,17); draw_button(btn_crouch,"STEALTH",bool(player.crouched),10); draw_button(btn_forward_primary,"FORWARD",false,11)
    draw_button(btn_turn_right,"TURN R",false,17); draw_button(btn_back,"BACK",false,11)
    if bool(player.weapon.gun):
        draw_button(btn_reload,"PUMP" if bool(player.get("needs_pump", false)) else "RELOAD",bool(player.get("needs_pump", false)),10)
    draw_button(btn_light,secondary_button_label(),str(player.get("secondary", "")) != "",8); draw_button(btn_shove,"SHOVE",false,10); draw_button(btn_sprint,"SPRINT",bool(player.get("sprinting", false)),10)
    var agility := int(player.skills.get("Agility", 0)); var base_step: int = TimeThree.movement_cost(player, false)
    var step_cost: int = ThreeStatRules.sprint_move_cost(agility, base_step) if bool(player.get("sprinting", false)) else (ThreeStatRules.stealth_move_cost(agility, base_step) if player.crouched else ThreeStatRules.normal_move_cost(agility, base_step))
    draw_string(font,Vector2(258,678),"T %d  STEP %d  K %d"%[tick,step_cost,int(stats.kills)],HORIZONTAL_ALIGNMENT_CENTER,124,8,Color(.62,.68,.64))
