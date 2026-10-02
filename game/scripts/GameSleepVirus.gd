extends "res://scripts/GameThreeStat.gd"

const VirusRules = preload("res://scripts/FFVirusRules.gd")

func new_game():
    super.new_game()
    for survivor in survivors:
        survivor["virus"] = VirusRules.default_state()
        survivor["equipment_state"] = {}
        survivor["daily_activity"] = CampLifeRules.default_daily_activity(day)
        survivor["previous_daily_activity"] = {}
        survivor["duty_days"] = []
        survivor["duty_eligible_days"] = []
    flags["virus_model"] = "zombie-virus-v1"
    flags["camp_condition_model"] = "camp-condition-activity-v1"
    flags["daily_chores"] = _generate_daily_chore_set()
    flags["previous_daily_chores"] = []
    save_game()

func load_game():
    super.load_game()
    if survivors.is_empty():
        return
    # Communal storage is a physical baseline fixture. Workbench and all
    # expansion structures are progression projects under schema 8.
    buildings["Storage Crate"] = true
    for survivor in survivors:
        survivor["virus"] = VirusRules.normalize(survivor.get("virus", {}))
        _normalize_survivor_equipment_state(survivor)
        survivor["daily_activity"] = CampLifeRules.normalize_daily_activity(survivor.get("daily_activity", {}), day)
        if not survivor.has("previous_daily_activity"):
            survivor["previous_daily_activity"] = {}
        survivor["duty_days"] = CampLifeRules.normalize_duty_days(survivor.get("duty_days", []), day)
        survivor["duty_eligible_days"] = CampLifeRules.normalize_duty_days(survivor.get("duty_eligible_days", []), day)
        _migrate_passive_sleep(survivor)
        _normalize_health_status(survivor)
    flags["virus_model"] = "zombie-virus-v1"
    flags["camp_condition_model"] = "camp-condition-activity-v1"
    var normalized_chores := CampLifeRules.normalize_daily_chores(flags.get("daily_chores", []), day)
    flags["daily_chores"] = normalized_chores if not normalized_chores.is_empty() else _generate_daily_chore_set()
    if not flags.has("previous_daily_chores"):
        flags["previous_daily_chores"] = []
    sim_paused = true
    save_game()
    state_changed.emit()

func _generate_survivor(founder = false, preferred_background = ""):
    var survivor: Dictionary = super._generate_survivor(founder, preferred_background)
    survivor["virus"] = VirusRules.default_state()
    survivor["equipment_state"] = {}
    survivor["daily_activity"] = CampLifeRules.default_daily_activity(day)
    survivor["previous_daily_activity"] = {}
    survivor["duty_days"] = []
    survivor["duty_eligible_days"] = []
    return survivor

func _advance_settlement_simulation(amount: float, include_expeditions: bool = true, allow_camp_events: bool = true) -> void:
    var remaining := maxf(0.0, amount)
    while remaining > 0.0 and not game_over:
        var step := minf(0.5, remaining)
        day_elapsed += step
        camp_event_accum += step
        if camp_event_cooldown > 0.0:
            camp_event_cooldown = maxf(0.0, camp_event_cooldown - step)

        fire_level = maxf(0.0, fire_level - CampLifeRules.FIRE_DECAY_PER_SECOND * step)
        camp_maintenance = CampLifeRules.degrade_camp_condition(camp_maintenance, step)
        _process_pets(step)
        _process_survivors(step)
        _process_camp_chatter(step)
        if include_expeditions:
            _process_expeditions(step)
            if sim_paused:
                # A legacy/saved traveling expedition may still open tactical
                # from this loop. Stop this frame immediately at the pause edge.
                return

        while day_elapsed >= DAY_SECONDS and not game_over:
            day_elapsed -= DAY_SECONDS
            _daily_tick()

        if allow_camp_events and camp_event_accum >= CampLifeRules.CAMP_EVENT_INTERVAL:
            camp_event_accum -= CampLifeRules.CAMP_EVENT_INTERVAL
            _consider_camp_event()

        _consider_politics()
        _check_settlement_mature()
        remaining -= step

func _advance_settlement_time_for_expedition_return(seconds: float) -> void:
    # Expeditions open the tactical board immediately. When tactical play ends,
    # apply the authored route duration in one settlement jump while the party
    # is still marked away, then return them to camp.
    _advance_settlement_simulation(maxf(0.0, seconds), false, false)

func _process(delta):
    if not initialized or sim_paused or game_over:
        return
    var camp_delta := float(delta)
    _advance_settlement_simulation(camp_delta, true, true)

    # UI cadence and autosave stay real-time responsiveness concerns.
    ui_emit_accum += float(delta)
    autosave_accum += float(delta)
    if autosave_accum >= 10.0:
        autosave_accum = 0.0
        save_game()

    if ui_emit_accum >= 0.25:
        ui_emit_accum = 0.0
        tick.emit()

func virus_state(survivor) -> Dictionary:
    if survivor == null:
        return VirusRules.default_state()
    return VirusRules.normalize(survivor.get("virus", {}))

func virus_stage(survivor) -> String:
    return str(virus_state(survivor).get("stage", VirusRules.STAGE_CLEAR))

func camp_condition_summary() -> Dictionary:
    return {
        "score": camp_maintenance,
        "band": CampLifeRules.camp_condition_band(camp_maintenance),
        "mood": CampLifeRules.camp_condition_mood_modifier(camp_maintenance),
    }

func survivor_activity_today(sid: int) -> Dictionary:
    var survivor: Variant = get_survivor(sid)
    if survivor == null:
        return CampLifeRules.default_daily_activity(day)
    return CampLifeRules.normalize_daily_activity(survivor.get("daily_activity", {}), day)

func survivor_recent_activity(sid: int) -> Dictionary:
    var survivor: Variant = get_survivor(sid)
    if survivor == null:
        return {}
    return survivor.get("previous_daily_activity", {}).duplicate(true)

func survivor_workload_pressure(sid: int) -> int:
    return CampLifeRules.daily_workload_pressure(survivor_activity_today(sid), day)

func daily_chores() -> Array:
    return CampLifeRules.normalize_daily_chores(flags.get("daily_chores", []), day)

func _generate_daily_chore_set() -> Array:
    return CampLifeRules.generate_daily_chores(day, rng)

func _find_daily_chore_index(chore_id: String) -> int:
    var chores := daily_chores()
    for index in range(chores.size()):
        if str(chores[index].get("id", "")) == chore_id:
            return index
    return -1

func get_daily_chore(chore_id: String) -> Dictionary:
    for chore_value in daily_chores():
        var chore: Dictionary = chore_value
        if str(chore.get("id", "")) == chore_id:
            return chore.duplicate(true)
    return {}

func daily_chore_incomplete_count() -> int:
    return CampLifeRules.unfinished_daily_chore_count(daily_chores())

func daily_chore_target(chore_id: String) -> int:
    var chore := get_daily_chore(chore_id)
    if chore.is_empty(): return -1
    return CampLifeRules.daily_chore_target_index(
        str(chore.get("kind", "")),
        int(chore.get("minigame_seed", 1)),
        int(chore.get("minigame_progress", 0))
    )

func daily_chore_remaining(chore_id: String) -> float:
    var chore := get_daily_chore(chore_id)
    if chore.is_empty(): return 0.0
    var sid := int(chore.get("assigned_survivor_id", -1))
    var survivor: Variant = get_survivor(sid)
    if survivor == null: return 0.0
    var task: Dictionary = survivor.get("task", {})
    if str(task.get("kind", "")) != "daily_chore" or str(task.get("chore_id", "")) != chore_id:
        return 0.0
    return maxf(0.0, float(task.get("remaining", 0.0)))

func assign_daily_chore(chore_id: String, sid: int) -> bool:
    var chores := daily_chores()
    var index := -1
    for i in range(chores.size()):
        if str(chores[i].get("id", "")) == chore_id:
            index = i
            break
    if index < 0: return false
    var chore: Dictionary = chores[index]
    if bool(chore.get("complete", false)) or int(chore.get("assigned_survivor_id", -1)) >= 0:
        return false
    var survivor: Variant = get_survivor(sid)
    if not survivor_can_assign(survivor):
        return false

    var eligible_ids: Array = []
    for candidate_value in available_survivors():
        var candidate: Dictionary = candidate_value
        eligible_ids.append(int(candidate.get("id", -1)))
        candidate["duty_eligible_days"] = CampLifeRules.normalize_duty_days(candidate.get("duty_eligible_days", []), day)
        if not candidate["duty_eligible_days"].has(day):
            candidate["duty_eligible_days"].append(day)

    chore["assigned_survivor_id"] = sid
    chore["eligible_ids"] = eligible_ids
    chores[index] = chore
    flags["daily_chores"] = chores

    _clear_camp_activity(survivor)
    var kind := str(chore.get("kind", ""))
    var duration := CampLifeRules.daily_chore_duration(kind)
    survivor["status"] = "Chore"
    survivor["task"] = {
        "kind":"daily_chore",
        "chore_id":chore_id,
        "chore":kind,
        "label":CampLifeRules.daily_chore_label(kind),
        "remaining":duration,
        "duration":duration,
        "minigame_complete":false,
    }
    survivor["daily_activity"] = CampLifeRules.normalize_daily_activity(survivor.get("daily_activity", {}), day)
    survivor["daily_activity"]["assigned_work"] = true
    survivor["fatigue"] = minf(100.0, float(survivor.get("fatigue", 0.0)) + CampLifeRules.fatigue_gain(duration / 5.0))
    _begin_forced_rest_if_exhausted(survivor)
    save_game()
    state_changed.emit()
    return true

func perform_daily_chore_action(chore_id: String, target_index: int) -> bool:
    var chores := daily_chores()
    var index := -1
    for i in range(chores.size()):
        if str(chores[i].get("id", "")) == chore_id:
            index = i
            break
    if index < 0: return false
    var chore: Dictionary = chores[index]
    if bool(chore.get("complete", false)) or bool(chore.get("interaction_complete", false)):
        return false
    var sid := int(chore.get("assigned_survivor_id", -1))
    var survivor: Variant = get_survivor(sid)
    if survivor == null: return false
    var task: Dictionary = survivor.get("task", {})
    if str(task.get("kind", "")) != "daily_chore" or str(task.get("chore_id", "")) != chore_id:
        return false
    var expected := CampLifeRules.daily_chore_target_index(str(chore.get("kind", "")), int(chore.get("minigame_seed", 1)), int(chore.get("minigame_progress", 0)))
    if target_index != expected:
        return false

    chore["minigame_progress"] = mini(int(chore.get("minigame_goal", 1)), int(chore.get("minigame_progress", 0)) + 1)
    if int(chore["minigame_progress"]) >= int(chore.get("minigame_goal", 1)):
        chore["interaction_complete"] = true
        survivor["task"]["minigame_complete"] = true
    chores[index] = chore
    flags["daily_chores"] = chores
    if bool(chore.get("interaction_complete", false)) and float(survivor["task"].get("remaining", 0.0)) <= 0.0:
        _complete_task(survivor)
    else:
        save_game()
        state_changed.emit()
    return true

func _record_duty_completion(survivor: Dictionary, eligible_ids: Array) -> void:
    survivor["duty_days"] = CampLifeRules.normalize_duty_days(survivor.get("duty_days", []), day)
    if not survivor["duty_days"].has(day):
        survivor["duty_days"].append(day)
    for sid_value in eligible_ids:
        var candidate: Variant = get_survivor(int(sid_value))
        if candidate == null or candidate["condition"] == "Dead": continue
        candidate["duty_eligible_days"] = CampLifeRules.normalize_duty_days(candidate.get("duty_eligible_days", []), day)
        if not candidate["duty_eligible_days"].has(day):
            candidate["duty_eligible_days"].append(day)

func duty_fairness_snapshot() -> Dictionary:
    var overdue: Array = []
    var overused_id := -1
    var max_completed := -1
    var min_completed := 999
    for survivor in survivors:
        if survivor["condition"] == "Dead": continue
        var completed := CampLifeRules.normalize_duty_days(survivor.get("duty_days", []), day)
        var eligible := CampLifeRules.normalize_duty_days(survivor.get("duty_eligible_days", []), day)
        if eligible.is_empty(): continue
        var pressure := CampLifeRules.duty_fairness_pressure(completed, eligible, day)
        if pressure >= 2: overdue.append(int(survivor["id"]))
        if completed.size() > max_completed:
            max_completed = completed.size()
            overused_id = int(survivor["id"])
        min_completed = mini(min_completed, completed.size())
    return {
        "overused_survivor_id":overused_id,
        "overdue_survivor_ids":overdue,
        "spread":maxi(0, max_completed - (0 if min_completed == 999 else min_completed)),
    }

# Compatibility facade for stale callers/saves. New daily chores are assigned only
# through assign_daily_chore() from the physical camp work board.
func camp_chore_needed(_chore: String) -> bool:
    return false

func start_camp_chore(_sid: int, _chore: String) -> bool:
    toast_requested.emit("Daily camp chores are assigned from the camp work board.")
    return false

func start_training(sid: int, stat: String) -> bool:
    if stat not in ["Combat", "Agility", "Leadership"]:
        return false
    var survivor: Variant = get_survivor(sid)
    if not survivor_can_assign(survivor):
        return false
    var sessions := int(survivor.get("training_sessions_today", 0)) if int(survivor.get("training_day", -1)) == day else 0
    if sessions >= 2:
        toast_requested.emit("%s has already trained twice today." % survivor["name"])
        return false
    _clear_camp_activity(survivor)
    survivor["training_day"] = day
    survivor["training_sessions_today"] = sessions + 1
    survivor["status"] = "Training"
    survivor["task"] = {"kind":"training","stat":stat,"label":"Training %s" % stat,"remaining":10.0,"duration":10.0}
    survivor["fatigue"] = minf(100.0, float(survivor.get("fatigue",0.0)) + CampLifeRules.fatigue_gain(3.0))
    _begin_forced_rest_if_exhausted(survivor)
    save_game()
    state_changed.emit()
    return true

func start_pet_care(sid: int, pet_id: int, action: String) -> bool:
    var survivor: Variant = get_survivor(sid)
    var pet: Variant = get_pet(pet_id)
    if not survivor_can_assign(survivor) or pet == null or action not in ["play","love"]:
        return false
    _clear_camp_activity(survivor)
    survivor["status"] = "Pet Care"
    survivor["task"] = {"kind":"pet_care","pet_id":pet_id,"action":action,"label":"%s %s" % [action.capitalize(),pet["name"]],"remaining":5.0,"duration":5.0}
    save_game()
    state_changed.emit()
    return true

func survivor_can_assign(survivor) -> bool:
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead":
        return false
    if float(survivor.get("fatigue", 0.0)) >= 100.0:
        return false
    if str(survivor.get("status", "Available")) != "Available":
        return false
    if not survivor.get("task", {}).is_empty():
        return false
    var virus := virus_state(survivor)
    return not bool(virus.get("quarantined", false)) and not VirusRules.is_severe(virus)

func available_survivors():
    var result: Array = []
    for survivor in survivors:
        if survivor_can_assign(survivor):
            result.append(survivor)
    return result

func equip_gear(sid, gear_name):
    var survivor: Variant = get_survivor(sid)
    if not survivor_can_assign(survivor):
        return false
    return super.equip_gear(sid, gear_name)

func start_craft(sid, station, recipe_id):
    var survivor: Variant = get_survivor(sid)
    if not survivor_can_assign(survivor):
        return false
    var started: bool = bool(super.start_craft(sid, station, recipe_id))
    if started:
        _begin_forced_rest_if_exhausted(survivor)
        save_game()
        state_changed.emit()
    return started

func start_build(sid, building):
    var survivor: Variant = get_survivor(sid)
    if not survivor_can_assign(survivor):
        return false
    var started: bool = bool(super.start_build(sid, building))
    if started:
        _begin_forced_rest_if_exhausted(survivor)
        save_game()
        state_changed.emit()
    return started

func tend_garden(sid):
    var survivor: Variant = get_survivor(sid)
    if not survivor_can_assign(survivor):
        return false
    var started: bool = bool(super.tend_garden(sid))
    if started:
        _begin_forced_rest_if_exhausted(survivor)
        save_game()
        state_changed.emit()
    return started

func _home_idle_status(survivor) -> String:
    var virus := virus_state(survivor)
    if bool(virus.get("quarantined", false)):
        return "Quarantined"
    if VirusRules.is_severe(virus):
        return "Sick"
    return "Available"

func _begin_forced_rest_if_exhausted(survivor) -> bool:
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead":
        return false
    if float(survivor.get("fatigue", 0.0)) < 100.0:
        return false
    var status := str(survivor.get("status", "Available"))
    if status in ["Expedition", "Pending Expedition Event", "Tactical Encounter", "Exhausted", "Sleeping", "Recovering", "Quarantined", "Sick"]:
        return false
    var current_task_value = survivor.get("task", {})
    var current_task: Dictionary = current_task_value if current_task_value is Dictionary else {}
    var resume_task: Dictionary = {}
    var resume_status := ""
    if not current_task.is_empty():
        if status not in ["Crafting", "Building", "Tending", "Chore", "Pet Care", "Training"]:
            return false
        resume_task = current_task.duplicate(true)
        resume_status = status
    _clear_camp_activity(survivor)
    var duration := CampLifeRules.forced_rest_duration(DAY_SECONDS, rng)
    survivor["status"] = "Exhausted"
    survivor["task"] = {
        "kind":"forced_rest",
        "label":"Pouting on Bed",
        "remaining":duration,
        "duration":duration,
        "resume_status":resume_status,
        "resume_task":resume_task,
    }
    survivor["history"].append("Day %d — Hit 100 fatigue and collapsed onto a bed for %.0f in-game hours." % [day, duration / (DAY_SECONDS / 24.0)])
    return true

func _normalize_health_status(survivor) -> void:
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead":
        return
    survivor["virus"] = VirusRules.normalize(survivor.get("virus", {}))
    _normalize_survivor_equipment_state(survivor)
    if not survivor.has("task"):
        survivor["task"] = {}
    if not survivor.has("camp_activity"):
        survivor["camp_activity"] = {}
    survivor["daily_activity"] = CampLifeRules.normalize_daily_activity(survivor.get("daily_activity", {}), day)
    if not survivor.has("previous_daily_activity"):
        survivor["previous_daily_activity"] = {}
    survivor["duty_days"] = CampLifeRules.normalize_duty_days(survivor.get("duty_days", []), day)
    survivor["duty_eligible_days"] = CampLifeRules.normalize_duty_days(survivor.get("duty_eligible_days", []), day)
    var status := str(survivor.get("status", "Available"))
    if status in ["Available", "Quarantined", "Sick"] and survivor.get("task", {}).is_empty():
        survivor["status"] = _home_idle_status(survivor)

func _migrate_passive_sleep(survivor) -> void:
    if survivor == null or str(survivor.get("status", "Available")) != "Available":
        return
    var activity: Dictionary = survivor.get("camp_activity", {})
    if str(activity.get("kind", "")) != "rest":
        return
    survivor["camp_activity"] = {}
    survivor["status"] = "Sleeping"
    survivor["task"] = {
        "kind": "sleep",
        "label": "Sleeping",
        "remaining": maxf(0.1, float(activity.get("remaining", 7.0))),
        "duration": maxf(0.1, float(activity.get("duration", 7.0))),
    }

func _process_survivors(delta):
    var pop: int = int(population())
    var capacity: int = int(shelter_capacity())
    var hygiene_support := bool(buildings.get("Rain Catcher", false)) or bool(buildings.get("Water Tank", false))
    for survivor in survivors:
        if survivor["condition"] == "Dead":
            continue
        if not survivor.has("needs"):
            survivor["needs"] = CampLifeRules.default_needs()
        _normalize_health_status(survivor)
        _begin_forced_rest_if_exhausted(survivor)
        var status := str(survivor.get("status", "Available"))
        var away := status in ["Expedition", "Pending Expedition Event", "Tactical Encounter"]
        var task_kind := str(survivor.get("task", {}).get("kind", ""))
        survivor["daily_activity"] = CampLifeRules.record_daily_activity(
            survivor.get("daily_activity", {}),
            day,
            status,
            task_kind,
            CampLifeRules.settlement_hour(day_elapsed, DAY_SECONDS),
            float(delta)
        )
        var safety := CampLifeRules.safety_target(buildings, pop, capacity, fire_level, away, camp_maintenance)
        survivor["needs"] = CampLifeRules.update_needs(survivor.get("needs", {}), float(survivor.get("fatigue", 0.0)), float(delta), safety, hygiene_support, away)
        survivor["stress"] = clampf(float(survivor.get("stress", 0.0)) + CampLifeRules.need_stress_rate(survivor["needs"], camp_maintenance) * float(delta), 0.0, 100.0)

        var caretaker := false
        if leader_id != -1:
            var leader: Variant = get_survivor(leader_id)
            caretaker = leader != null and leader["leader_ability"] == "Caretaker"
        var recovery := CampLifeRules.idle_recovery_rates(
            CampLifeRules.shelter_tier(buildings),
            caretaker,
            CampLifeRules.tavern_tier(buildings)
        )

        if status == "Available":
            survivor["fatigue"] = maxf(0.0, float(survivor["fatigue"]) - recovery.x * float(delta))
            survivor["stress"] = maxf(0.0, float(survivor["stress"]) - recovery.y * float(delta))
            survivor["needs"] = CampLifeRules.update_needs(survivor["needs"], float(survivor["fatigue"]), 0.0, safety, hygiene_support, false)
            _process_camp_activity(survivor, float(delta), pop, hygiene_support)
        elif status in ["Sick", "Quarantined"]:
            survivor["camp_activity"] = {}
            survivor["fatigue"] = maxf(0.0, float(survivor["fatigue"]) - recovery.x * float(delta) * 0.6)
            survivor["stress"] = maxf(0.0, float(survivor["stress"]) - recovery.y * float(delta) * 0.6)
        elif status in ["Crafting", "Building", "Recovering", "Tending", "Sleeping", "Exhausted", "Chore", "Pet Care", "Training"]:
            survivor["camp_activity"] = {}
            if survivor["task"].is_empty():
                survivor["status"] = _home_idle_status(survivor)
                continue
            survivor["task"]["remaining"] = maxf(0.0, float(survivor["task"]["remaining"]) - float(delta))
            if float(survivor["task"]["remaining"]) <= 0.0:
                _complete_task(survivor)

        var current_status := str(survivor.get("status", ""))
        if current_status in ["Available", "Sleeping", "Exhausted", "Quarantined", "Sick"] and survivor["condition"] in ["Hurt", "Wounded"]:
            survivor["injury_remaining"] = maxf(0.0, float(survivor["injury_remaining"]) - float(delta) * CampLifeRules.injury_recovery_multiplier(bool(buildings.get("Infirmary", false))))
            if survivor["injury_remaining"] <= 0.0:
                if survivor["condition"] == "Wounded":
                    survivor["condition"] = "Hurt"
                    survivor["injury_remaining"] = 60.0
                    survivor["history"].append("Day %d — Recovered from a serious wound." % day)
                else:
                    survivor["condition"] = "Healthy"
                    survivor["history"].append("Day %d — Recovered from minor injuries." % day)

func _process_camp_activity(survivor: Dictionary, delta: float, pop: int, hygiene_support: bool) -> void:
    var activity: Dictionary = survivor.get("camp_activity", {})
    if activity.is_empty():
        activity = CampLifeRules.choose_available_activity(
            survivor.get("needs", {}),
            fire_level,
            int(resources.get("Wood", 0)),
            pop,
            CampLifeRules.tavern_tier(buildings),
            hygiene_support,
            rng,
            CampLifeRules.settlement_hour(day_elapsed, DAY_SECONDS),
            survivor.get("daily_activity", {}),
            int(resources.get("Cooked Food", 0)),
            int(resources.get("Clean Water", 0)),
            int(resources.get("Beer", 0))
        )
        if activity.is_empty():
            return
        if str(activity.get("kind", "")) == "rest":
            survivor["camp_activity"] = {}
            survivor["status"] = "Sleeping"
            survivor["task"] = {
                "kind": "sleep",
                "label": "Sleeping",
                "remaining": maxf(0.1, float(activity.get("remaining", 7.0))),
                "duration": maxf(0.1, float(activity.get("duration", 7.0))),
            }
            return
        survivor["camp_activity"] = activity
    activity["remaining"] = maxf(0.0, float(activity.get("remaining", 0.0)) - delta)
    survivor["camp_activity"] = activity
    if float(activity.get("remaining", 0.0)) > 0.0:
        return
    var kind := str(activity.get("kind", ""))
    if kind == "eat_meal":
        survivor["daily_activity"] = CampLifeRules.normalize_daily_activity(survivor.get("daily_activity", {}), day)
        survivor["daily_activity"]["meal_attempted"] = true
        if int(resources.get("Cooked Food", 0)) > 0:
            resources["Cooked Food"] = int(resources.get("Cooked Food", 0)) - 1
            var meal_result := CampLifeRules.complete_activity(survivor.get("needs", {}), float(survivor.get("fatigue", 0.0)), kind)
            survivor["needs"] = meal_result.get("needs", survivor.get("needs", {}))
            survivor["daily_activity"]["ate_normally"] = true
    elif kind == "drink_water":
        survivor["daily_activity"] = CampLifeRules.normalize_daily_activity(survivor.get("daily_activity", {}), day)
        survivor["daily_activity"]["water_attempted"] = true
        if int(resources.get("Clean Water", 0)) > 0:
            resources["Clean Water"] = int(resources.get("Clean Water", 0)) - 1
            var drink_result := CampLifeRules.complete_activity(survivor.get("needs", {}), float(survivor.get("fatigue", 0.0)), kind)
            survivor["needs"] = drink_result.get("needs", survivor.get("needs", {}))
            survivor["daily_activity"]["drank_normally"] = true
    else:
        var tavern_quality := CampLifeRules.tavern_tier(buildings)
        if kind == "tavern_drink":
            if int(resources.get("Beer", 0)) > 0:
                resources["Beer"] = int(resources.get("Beer", 0)) - 1
            else:
                kind = "tavern_social"
        var result := CampLifeRules.complete_activity(survivor.get("needs", {}), float(survivor.get("fatigue", 0.0)), kind, tavern_quality)
        survivor["needs"] = result.get("needs", survivor.get("needs", {}))
        survivor["fatigue"] = float(result.get("fatigue", survivor.get("fatigue", 0.0)))
        if kind in ["tavern_social", "tavern_drink"]:
            survivor["stress"] = maxf(0.0, float(survivor.get("stress", 0.0)) - CampLifeRules.tavern_social_stress_relief(tavern_quality, kind == "tavern_drink"))
        elif kind in ["watch_fire", "cards", "guitar"]:
            survivor["stress"] = maxf(0.0, float(survivor.get("stress", 0.0)) - 2.0)
    survivor["camp_activity"] = {}

func _complete_task(survivor):
    if survivor == null or survivor.get("task", {}).is_empty():
        return
    var task: Dictionary = survivor["task"].duplicate(true)
    var kind := str(task.get("kind", ""))
    if kind == "daily_chore":
        if not bool(task.get("minigame_complete", false)):
            return
        var chores := daily_chores()
        var chore_index := -1
        for index in range(chores.size()):
            if str(chores[index].get("id", "")) == str(task.get("chore_id", "")):
                chore_index = index
                break
        if chore_index < 0:
            survivor["task"] = {}
            survivor["status"] = _home_idle_status(survivor)
            save_game()
            state_changed.emit()
            return
        var chore: Dictionary = chores[chore_index]
        if not bool(chore.get("rewarded", false)):
            var effect := CampLifeRules.daily_chore_effect(str(chore.get("kind", "")))
            fire_level = clampf(fire_level + float(effect.get("fire_gain", 0.0)), 0.0, 100.0)
            resources["Wood"] = int(resources.get("Wood", 0)) + int(effect.get("wood_gain", 0))
            if float(effect.get("condition_gain", 0.0)) > 0.0:
                camp_maintenance = CampLifeRules.recover_camp_condition(camp_maintenance, str(chore.get("kind", "")))
            chore["rewarded"] = true
        chore["complete"] = true
        chore["interaction_complete"] = true
        chores[chore_index] = chore
        flags["daily_chores"] = chores
        _record_duty_completion(survivor, chore.get("eligible_ids", []))
        survivor["task"] = {}
        survivor["status"] = _home_idle_status(survivor)
        _begin_forced_rest_if_exhausted(survivor)
        survivor["history"].append("Day %d — Took a turn on camp duty: %s." % [day, str(chore.get("label", "Camp chore"))])
        _add_history("Day %d — %s completed %s." % [day, survivor["name"], str(chore.get("label", "camp duty")).to_lower()])
        toast_requested.emit("%s finished %s." % [survivor["name"], str(chore.get("label", "camp duty"))])
        save_game()
        state_changed.emit()
        return
    if kind == "forced_rest":
        survivor["fatigue"] = 0.0
        var rested_needs := CampLifeRules.normalize_needs(survivor.get("needs", {}))
        rested_needs["sleep"] = 100.0
        survivor["needs"] = rested_needs
        var resume_task_value = task.get("resume_task", {})
        var resume_task: Dictionary = resume_task_value if resume_task_value is Dictionary else {}
        var resume_status := str(task.get("resume_status", ""))
        if not resume_task.is_empty() and resume_status != "":
            survivor["task"] = resume_task
            survivor["status"] = resume_status
            survivor["history"].append("Day %d — Got back up fully rested and resumed %s." % [day, str(resume_task.get("label", "work")).to_lower()])
        else:
            survivor["task"] = {}
            survivor["status"] = _home_idle_status(survivor)
            survivor["history"].append("Day %d — Got back up fully rested after exhaustion." % day)
        save_game()
        state_changed.emit()
        return
    if kind == "sleep":
        survivor["task"] = {}
        var shelter_quality := CampLifeRules.shelter_tier(buildings)
        var result := CampLifeRules.complete_sleep(
            survivor.get("needs", {}),
            float(survivor.get("fatigue", 0.0)),
            float(survivor.get("stress", 0.0)),
            shelter_quality
        )
        survivor["needs"] = result.get("needs", survivor.get("needs", {}))
        survivor["fatigue"] = float(result.get("fatigue", survivor.get("fatigue", 0.0)))
        survivor["stress"] = float(result.get("stress", survivor.get("stress", 0.0)))
        survivor["status"] = _home_idle_status(survivor)
        save_game()
        state_changed.emit()
        return
    if kind == "training":
        survivor["task"] = {}
        var stat := str(task.get("stat", "Combat"))
        add_skill_xp(survivor, stat, 5)
        survivor["status"] = _home_idle_status(survivor)
        _begin_forced_rest_if_exhausted(survivor)
        survivor["history"].append("Day %d — Spent two camp hours training %s." % [day, stat])
        toast_requested.emit("%s finished %s training." % [survivor["name"], stat])
        save_game()
        state_changed.emit()
        return
    if kind == "virus_treatment":
        survivor["task"] = {}
        survivor["virus"] = VirusRules.default_state()
        survivor["status"] = "Available"
        survivor["stress"] = maxf(0.0, float(survivor.get("stress", 0.0)) - 8.0)
        survivor["history"].append("Day %d — Completed zombie-virus treatment and tested clear." % day)
        toast_requested.emit("%s completed zombie-virus treatment and is clear." % survivor["name"])
        save_game()
        state_changed.emit()
        return
    super._complete_task(survivor)
    if survivor["condition"] != "Dead" and survivor.get("task", {}).is_empty():
        survivor["status"] = _home_idle_status(survivor)
        _begin_forced_rest_if_exhausted(survivor)
        save_game()
        state_changed.emit()

func _process_camp_chatter(delta):
    var speakers: Array = available_survivors()
    if speakers.size() < 2 or not current_event.is_empty() or not current_combat.is_empty():
        camp_chatter_accum = 0.0
        return
    camp_chatter_accum += float(delta)
    if camp_chatter_accum < next_camp_chatter_at:
        return
    camp_chatter_accum = 0.0
    next_camp_chatter_at = rng.randf_range(CampLifeRules.CAMP_CHATTER_MIN_SECONDS, CampLifeRules.CAMP_CHATTER_MAX_SECONDS)
    var chatter: Dictionary = CampSocial.roll_chatter(speakers, leader_id, coordinator_id, food_shortage_days, water_shortage_days, policies, rng)
    if chatter.is_empty():
        return
    var speaker: Variant = get_survivor(int(chatter.get("speaker_id", -1)))
    var listener: Variant = get_survivor(int(chatter.get("listener_id", -1)))
    if speaker == null or listener == null:
        return
    var delta_ab := int(chatter.get("relationship_delta", 0))
    var delta_ba := int(chatter.get("reverse_delta", 0))
    if delta_ab != 0:
        _change_relationship(speaker, listener, delta_ab)
    if delta_ba != 0:
        _change_relationship(listener, speaker, delta_ba)
    speaker["stress"] = clampf(float(speaker.get("stress", 0.0)) + float(chatter.get("speaker_stress_delta", 0.0)), 0.0, 100.0)
    listener["stress"] = clampf(float(listener.get("stress", 0.0)) + float(chatter.get("listener_stress_delta", 0.0)), 0.0, 100.0)
    camp_chatter_requested.emit(chatter)

func _expose_survivor(survivor, source_note: String) -> bool:
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead" or virus_stage(survivor) != VirusRules.STAGE_CLEAR:
        return false
    survivor["virus"] = VirusRules.expose(survivor.get("virus", {}))
    survivor["history"].append("Day %d — Zombie-virus exposure: %s." % [day, source_note])
    _add_history("Day %d — %s was exposed to the zombie virus." % [day, survivor["name"]])
    return true

func quarantine_survivor(sid: int) -> bool:
    var survivor: Variant = get_survivor(sid)
    if survivor == null or survivor["condition"] == "Dead" or virus_stage(survivor) == VirusRules.STAGE_CLEAR:
        return false
    if str(survivor.get("status", "Available")) not in ["Available", "Sick"] or not survivor.get("task", {}).is_empty():
        toast_requested.emit("%s is busy and cannot enter quarantine yet." % survivor["name"])
        return false
    var virus := virus_state(survivor)
    virus["quarantined"] = true
    survivor["virus"] = virus
    _clear_camp_activity(survivor)
    survivor["status"] = "Quarantined"
    survivor["stress"] = minf(100.0, float(survivor.get("stress", 0.0)) + 4.0)
    survivor["history"].append("Day %d — Entered quarantine for zombie-virus exposure." % day)
    toast_requested.emit("%s is quarantined and unavailable for assignments." % survivor["name"])
    save_game()
    state_changed.emit()
    return true

func start_virus_treatment(sid: int) -> bool:
    var survivor: Variant = get_survivor(sid)
    if survivor == null or survivor["condition"] == "Dead":
        return false
    var stage_name := virus_stage(survivor)
    if stage_name == VirusRules.STAGE_CLEAR:
        return false
    if str(survivor.get("status", "Available")) not in ["Available", "Quarantined", "Sick"] or not survivor.get("task", {}).is_empty():
        toast_requested.emit("%s is already occupied." % survivor["name"])
        return false
    var plan: Dictionary = VirusRules.treatment_plan(stage_name, bool(buildings.get("Infirmary", false)))
    if not bool(plan.get("available", false)):
        toast_requested.emit(str(plan.get("reason", "Virus treatment is not available.")))
        return false
    var resource_cost: Dictionary = plan.get("resources", {})
    var component_cost: Dictionary = plan.get("components", {})
    if not _can_pay(resource_cost, component_cost):
        toast_requested.emit("Virus treatment needs %s." % str(plan.get("summary", "medical supplies")))
        return false
    _pay(resource_cost, component_cost)
    _clear_camp_activity(survivor)
    var virus := virus_state(survivor)
    virus["quarantined"] = true
    survivor["virus"] = virus
    survivor["status"] = "Recovering"
    survivor["task"] = {
        "kind": "virus_treatment",
        "label": str(plan.get("label", "Virus treatment")),
        "remaining": float(plan.get("duration", 60.0)),
        "duration": float(plan.get("duration", 60.0)),
        "target": sid,
    }
    survivor["history"].append("Day %d — Began %s." % [day, str(plan.get("label", "zombie-virus treatment")).to_lower()])
    toast_requested.emit("%s started %s." % [survivor["name"], str(plan.get("label", "virus treatment")).to_lower()])
    save_game()
    state_changed.emit()
    return true

func resolve_combat(result):
    if not current_combat.is_empty():
        var ids: Array = current_combat.get("survivor_ids", [])
        var lead: Variant = get_survivor(ids[0]) if not ids.is_empty() else null
        var lead_bites := int(result.get("bite_hits", 0))
        var lead_survived := int(result.get("lead_hp", 0)) > 0 and str(result.get("outcome", "dead")) == "escaped"
        if lead_survived and lead != null and lead_bites > 0 and virus_stage(lead) == VirusRules.STAGE_CLEAR:
            if VirusRules.bite_exposure_occurs(lead_bites, rng):
                if _expose_survivor(lead, "%d infected bite%s in the field" % [lead_bites, "" if lead_bites == 1 else "s"]):
                    lead["stress"] = minf(100.0, float(lead.get("stress", 0.0)) + 10.0)
                    toast_requested.emit("%s was exposed to the zombie virus by a bite. Early decontamination can stop it." % lead["name"])
        if ids.size() > 1:
            var companion: Variant = get_survivor(int(ids[1]))
            var companion_bites := int(result.get("companion_bite_hits", 0))
            var companion_survived := int(result.get("companion_hp", 0)) > 0 and str(result.get("outcome", "dead")) == "escaped"
            if companion_survived and companion != null and companion_bites > 0 and virus_stage(companion) == VirusRules.STAGE_CLEAR:
                if VirusRules.bite_exposure_occurs(companion_bites, rng):
                    if _expose_survivor(companion, "%d infected bite%s while accompanying an expedition" % [companion_bites, "" if companion_bites == 1 else "s"]):
                        companion["stress"] = minf(100.0, float(companion.get("stress", 0.0)) + 10.0)
                        toast_requested.emit("%s was exposed to the zombie virus by a bite." % companion["name"])
    super.resolve_combat(result)

func _resolve_daily_rations() -> void:
    var food_missing := 0
    var water_missing := 0
    for survivor in survivors:
        if survivor["condition"] == "Dead":
            continue
        var activity := CampLifeRules.finalize_daily_activity(survivor.get("daily_activity", {}), day)
        var supply_food_missing := not bool(activity.get("ate_normally", false)) and not bool(activity.get("missed_meal", false))
        var supply_water_missing := not bool(activity.get("drank_normally", false)) and not bool(activity.get("missed_water", false))
        if supply_food_missing: food_missing += 1
        if supply_water_missing: water_missing += 1
        if supply_food_missing or supply_water_missing:
            survivor["needs"] = CampLifeRules.apply_daily_shortage_consequences(survivor.get("needs", {}), supply_food_missing, supply_water_missing)

    if food_missing > 0:
        food_shortage_days += 1
        _apply_shortage("food", food_shortage_days)
    else:
        food_shortage_days = 0
    if water_missing > 0:
        water_shortage_days += 1
        _apply_shortage("water", water_shortage_days)
    else:
        water_shortage_days = 0

func _daily_tick():
    _process_daily_virus()
    if game_over:
        save_game()
        state_changed.emit()
        return

    var completed_activity := {}
    for survivor in survivors:
        if survivor["condition"] == "Dead":
            continue
        completed_activity[str(survivor["id"])] = CampLifeRules.finalize_daily_activity(survivor.get("daily_activity", {}), day)

    var ending_chores := daily_chores()
    var unfinished := CampLifeRules.unfinished_daily_chore_count(ending_chores)
    if unfinished > 0:
        camp_maintenance = CampLifeRules.apply_unfinished_chore_neglect(camp_maintenance, ending_chores)
        _add_history("Day %d — %d required camp chore%s went unfinished." % [day, unfinished, "" if unfinished == 1 else "s"])
    flags["previous_daily_chores"] = ending_chores.duplicate(true)
    for chore_value in ending_chores:
        var chore: Dictionary = chore_value
        if bool(chore.get("complete", false)): continue
        var sid := int(chore.get("assigned_survivor_id", -1))
        var worker: Variant = get_survivor(sid)
        if worker != null and str(worker.get("task", {}).get("kind", "")) == "daily_chore" and str(worker.get("task", {}).get("chore_id", "")) == str(chore.get("id", "")):
            worker["task"] = {}
            worker["status"] = _home_idle_status(worker)

    super._daily_tick()
    if game_over:
        return

    flags["daily_chores"] = _generate_daily_chore_set()
    for survivor in survivors:
        if survivor["condition"] == "Dead":
            continue
        var summary: Dictionary = completed_activity.get(str(survivor["id"]), {})
        survivor["previous_daily_activity"] = summary.duplicate(true)
        var missed_water := bool(summary.get("missed_water", false))
        var missed_meal := bool(summary.get("missed_meal", false))
        var missed_sleep := bool(summary.get("missed_sleep", false))
        if missed_water or missed_meal or missed_sleep:
            var consequence := CampLifeRules.apply_missed_schedule_consequences(
                survivor.get("needs", {}),
                float(survivor.get("fatigue", 0.0)),
                missed_meal,
                missed_sleep,
                missed_water
            )
            survivor["needs"] = consequence.get("needs", survivor.get("needs", {}))
            survivor["fatigue"] = float(consequence.get("fatigue", survivor.get("fatigue", 0.0)))
            survivor["stress"] = minf(100.0, float(survivor.get("stress", 0.0)) + (4.0 if missed_meal else 0.0) + (6.0 if missed_sleep else 0.0))
            var misses: Array = []
            if missed_water: misses.append("water break")
            if missed_meal: misses.append("meal")
            if missed_sleep: misses.append("sleep")
            survivor["history"].append("Day %d — Assigned work crowded out normal %s time." % [day - 1, " and ".join(misses)])
        survivor["daily_activity"] = CampLifeRules.default_daily_activity(day)
        survivor["duty_days"] = CampLifeRules.normalize_duty_days(survivor.get("duty_days", []), day)
        survivor["duty_eligible_days"] = CampLifeRules.normalize_duty_days(survivor.get("duty_eligible_days", []), day)
    save_game()
    state_changed.emit()

func _process_daily_virus() -> void:
    for survivor in survivors:
        if survivor["condition"] == "Dead":
            continue
        survivor["virus"] = VirusRules.normalize(survivor.get("virus", {}))
        if virus_stage(survivor) == VirusRules.STAGE_CLEAR:
            continue
        if str(survivor.get("task", {}).get("kind", "")) == "virus_treatment":
            continue
        var progressed: Dictionary = VirusRules.progress_day(survivor["virus"], rng)
        survivor["virus"] = progressed.get("state", survivor["virus"])
        match str(progressed.get("event", "")):
            "cleared":
                if str(survivor.get("status", "")) in ["Quarantined", "Sick"] and survivor.get("task", {}).is_empty():
                    survivor["status"] = "Available"
                survivor["history"].append("Day %d — Cleared a zombie-virus exposure without progressing." % day)
                toast_requested.emit("%s cleared the zombie-virus exposure." % survivor["name"])
            "infected":
                survivor["fatigue"] = minf(100.0, float(survivor.get("fatigue", 0.0)) + 12.0)
                survivor["stress"] = minf(100.0, float(survivor.get("stress", 0.0)) + 8.0)
                survivor["history"].append("Day %d — Zombie-virus infection established." % day)
                toast_requested.emit("%s is now infected. A Zombie Cure can still stop it." % survivor["name"])
            "feverish":
                survivor["fatigue"] = minf(100.0, float(survivor.get("fatigue", 0.0)) + 25.0)
                survivor["stress"] = minf(100.0, float(survivor.get("stress", 0.0)) + 15.0)
                if str(survivor.get("status", "")) in ["Available", "Quarantined", "Sick"] and survivor.get("task", {}).is_empty():
                    survivor["status"] = _home_idle_status(survivor)
                survivor["history"].append("Day %d — Zombie-virus fever became severe." % day)
                toast_requested.emit("%s is feverish. Without Infirmary treatment, the next day can be fatal." % survivor["name"])
            "terminal":
                _kill_survivor(survivor, "turned after an untreated zombie-virus infection")
    _spread_camp_virus()

func _spread_camp_virus() -> void:
    var candidates: Array = []
    for survivor in survivors:
        if survivor["condition"] == "Dead" or virus_stage(survivor) != VirusRules.STAGE_CLEAR:
            continue
        if str(survivor.get("status", "Available")) in ["Expedition", "Pending Expedition Event", "Tactical Encounter"]:
            continue
        candidates.append(survivor)
    if candidates.is_empty():
        return
    for source in survivors:
        if source["condition"] == "Dead" or str(source.get("status", "Available")) in ["Expedition", "Pending Expedition Event", "Tactical Encounter"]:
            continue
        var chance := VirusRules.spread_chance(source.get("virus", {}))
        if chance <= 0.0 or rng.randf() >= chance or candidates.is_empty():
            continue
        var target: Variant = candidates[rng.randi_range(0, candidates.size() - 1)]
        if _expose_survivor(target, "close contact with an unquarantined infected campmate"):
            target["stress"] = minf(100.0, float(target.get("stress", 0.0)) + 8.0)
            toast_requested.emit("%s was exposed in camp. Quarantine infected survivors to prevent close-contact spread." % target["name"])
            candidates.erase(target)
