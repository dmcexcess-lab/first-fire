extends "res://scripts/GameThreeStat.gd"

const VirusRules = preload("res://scripts/FFVirusRules.gd")
const SIM_TIME_SCALE := 0.5

func new_game():
    super.new_game()
    for survivor in survivors:
        survivor["virus"] = VirusRules.default_state()
    flags["virus_model"] = "zombie-virus-v1"
    save_game()

func load_game():
    super.load_game()
    if survivors.is_empty():
        return
    for survivor in survivors:
        survivor["virus"] = VirusRules.normalize(survivor.get("virus", {}))
        _migrate_passive_sleep(survivor)
        _normalize_health_status(survivor)
    flags["virus_model"] = "zombie-virus-v1"
    sim_paused = true
    state_changed.emit()

func _generate_survivor(founder = false, preferred_background = ""):
    var survivor: Dictionary = super._generate_survivor(founder, preferred_background)
    survivor["virus"] = VirusRules.default_state()
    return survivor

func _process(delta):
    if not initialized or sim_paused or game_over:
        return
    var sim_delta := float(delta) * SIM_TIME_SCALE
    day_elapsed += sim_delta
    ui_emit_accum += float(delta)
    autosave_accum += float(delta)
    camp_event_accum += sim_delta
    if camp_event_cooldown > 0.0:
        camp_event_cooldown = maxf(0.0, camp_event_cooldown - sim_delta)

    fire_level = maxf(0.0, fire_level - CampLifeRules.FIRE_DECAY_PER_SECOND * sim_delta)
    camp_maintenance = maxf(0.0, camp_maintenance - CampLifeRules.CAMP_MAINTENANCE_DECAY_PER_SECOND * sim_delta)
    _process_pets(sim_delta)
    _process_survivors(sim_delta)
    _process_camp_chatter(sim_delta)
    _process_expeditions(sim_delta)

    if day_elapsed >= DAY_SECONDS:
        while day_elapsed >= DAY_SECONDS and not game_over:
            day_elapsed -= DAY_SECONDS
            _daily_tick()

    if camp_event_accum >= CampLifeRules.CAMP_EVENT_INTERVAL:
        camp_event_accum -= CampLifeRules.CAMP_EVENT_INTERVAL
        _consider_camp_event()

    _consider_politics()
    _check_settlement_mature()

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

func survivor_can_assign(survivor) -> bool:
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead":
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

func _home_idle_status(survivor) -> String:
    var virus := virus_state(survivor)
    if bool(virus.get("quarantined", false)):
        return "Quarantined"
    if VirusRules.is_severe(virus):
        return "Sick"
    return "Available"

func _normalize_health_status(survivor) -> void:
    if survivor == null or str(survivor.get("condition", "Dead")) == "Dead":
        return
    survivor["virus"] = VirusRules.normalize(survivor.get("virus", {}))
    if not survivor.has("task"):
        survivor["task"] = {}
    if not survivor.has("camp_activity"):
        survivor["camp_activity"] = {}
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
        var status := str(survivor.get("status", "Available"))
        var away := status in ["Expedition", "Pending Expedition Event", "Tactical Encounter"]
        var safety := CampLifeRules.safety_target(buildings, pop, capacity, fire_level, away, camp_maintenance)
        survivor["needs"] = CampLifeRules.update_needs(survivor.get("needs", {}), float(survivor.get("fatigue", 0.0)), float(delta), safety, hygiene_support, away)
        survivor["stress"] = clampf(float(survivor.get("stress", 0.0)) + CampLifeRules.need_stress_rate(survivor["needs"]) * float(delta), 0.0, 100.0)

        var caretaker := false
        if leader_id != -1:
            var leader: Variant = get_survivor(leader_id)
            caretaker = leader != null and leader["leader_ability"] == "Caretaker"
        var recovery := CampLifeRules.idle_recovery_rates(bool(buildings.get("Cabin", false)), caretaker, bool(buildings.get("Communal Table", false)))

        if status == "Available":
            survivor["fatigue"] = maxf(0.0, float(survivor["fatigue"]) - recovery.x * float(delta))
            survivor["stress"] = maxf(0.0, float(survivor["stress"]) - recovery.y * float(delta))
            survivor["needs"] = CampLifeRules.update_needs(survivor["needs"], float(survivor["fatigue"]), 0.0, safety, hygiene_support, false)
            _process_camp_activity(survivor, float(delta), pop, hygiene_support)
        elif status in ["Sick", "Quarantined"]:
            survivor["camp_activity"] = {}
            survivor["fatigue"] = maxf(0.0, float(survivor["fatigue"]) - recovery.x * float(delta) * 0.6)
            survivor["stress"] = maxf(0.0, float(survivor["stress"]) - recovery.y * float(delta) * 0.6)
        elif status in ["Chore", "Pet Care"]:
            survivor["camp_activity"] = {}
            if survivor["task"].is_empty():
                survivor["status"] = _home_idle_status(survivor)
        elif status in ["Crafting", "Building", "Recovering", "Tending", "Sleeping"]:
            survivor["camp_activity"] = {}
            if survivor["task"].is_empty():
                survivor["status"] = _home_idle_status(survivor)
                continue
            survivor["task"]["remaining"] = maxf(0.0, float(survivor["task"]["remaining"]) - float(delta))
            if float(survivor["task"]["remaining"]) <= 0.0:
                _complete_task(survivor)

        var current_status := str(survivor.get("status", ""))
        if current_status in ["Available", "Sleeping", "Quarantined", "Sick"] and survivor["condition"] in ["Hurt", "Wounded"]:
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
        activity = CampLifeRules.choose_available_activity(survivor.get("needs", {}), fire_level, int(resources.get("Wood", 0)), pop, bool(buildings.get("Communal Table", false)), hygiene_support, rng)
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
    if kind == "maintain_fire":
        if int(resources.get("Wood", 0)) > 0:
            resources["Wood"] = int(resources.get("Wood", 0)) - 1
            fire_level = clampf(fire_level + CampLifeRules.FIRE_MAINTAIN_GAIN, 0.0, 100.0)
            survivor["stress"] = maxf(0.0, float(survivor.get("stress", 0.0)) - 1.0)
    else:
        var result := CampLifeRules.complete_activity(survivor.get("needs", {}), float(survivor.get("fatigue", 0.0)), kind)
        survivor["needs"] = result.get("needs", survivor.get("needs", {}))
        survivor["fatigue"] = float(result.get("fatigue", survivor.get("fatigue", 0.0)))
        if kind in ["watch_fire", "cards", "guitar"]:
            survivor["stress"] = maxf(0.0, float(survivor.get("stress", 0.0)) - 2.0)
    survivor["camp_activity"] = {}

func _complete_task(survivor):
    if survivor == null or survivor.get("task", {}).is_empty():
        return
    var task: Dictionary = survivor["task"].duplicate(true)
    var kind := str(task.get("kind", ""))
    if kind == "sleep":
        survivor["task"] = {}
        var result := CampLifeRules.complete_activity(survivor.get("needs", {}), float(survivor.get("fatigue", 0.0)), "rest")
        survivor["needs"] = result.get("needs", survivor.get("needs", {}))
        survivor["fatigue"] = float(result.get("fatigue", survivor.get("fatigue", 0.0)))
        survivor["status"] = _home_idle_status(survivor)
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
        save_game()
        state_changed.emit()

func _process_camp_chatter(delta):
    var speakers := available_survivors()
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
        var infected_hits := int(result.get("infected_hits", 0))
        var survived := int(result.get("lead_hp", 0)) > 0 and str(result.get("outcome", "dead")) == "escaped"
        if survived and lead != null and infected_hits > 0 and virus_stage(lead) == VirusRules.STAGE_CLEAR:
            if rng.randf() < VirusRules.exposure_chance(infected_hits):
                if _expose_survivor(lead, "%d direct infected hit%s in the field" % [infected_hits, "" if infected_hits == 1 else "s"]):
                    lead["stress"] = minf(100.0, float(lead.get("stress", 0.0)) + 10.0)
                    toast_requested.emit("%s was exposed to the zombie virus. Early decontamination can stop it." % lead["name"])
    super.resolve_combat(result)

func _daily_tick():
    _process_daily_virus()
    if game_over:
        save_game()
        state_changed.emit()
        return
    super._daily_tick()

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
                toast_requested.emit("%s is now infected. Medicine can still stop it." % survivor["name"])
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
