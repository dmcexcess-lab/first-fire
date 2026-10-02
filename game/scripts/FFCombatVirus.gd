extends "res://scripts/FFCombatThreeStat.gd"

func restore_runtime():
    super.restore_runtime()
    stats["bite_hits"] = int(runtime.get("bite_hits", 0))
    stats["companion_bite_hits"] = int(runtime.get("companion_bite_hits", 0))

func persist_runtime():
    super.persist_runtime()
    runtime["bite_hits"] = int(stats.get("bite_hits", 0))
    runtime["companion_bite_hits"] = int(stats.get("companion_bite_hits", 0))
    runtime.erase("infected_hits")
    Game.update_combat_runtime(runtime)

func check_objective_and_exit():
    if str(context.get("kind", "")) == "rescue" and exit_cells.has(player.pos) and rescue_contacted and not rescuee.is_empty() and not bool(rescuee.get("dead", false)) and not rescuee_ready_to_extract():
        msg = "Hold the exit — %s is catching up." % str(rescuee.get("name", "The survivor"))
        queue_redraw()
        return
    super.check_objective_and_exit()

func commit_action(cost: int):
    super.commit_action(cost)
    if game_over:
        return
    if str(context.get("kind", "")) == "rescue" and exit_cells.has(player.pos):
        check_objective_and_exit()

func zombie_attack(i: int, target_actor: Dictionary):
    var outcome := str(super.zombie_attack(i, target_actor))
    if outcome != "bite_hit":
        return outcome
    if bool(target_actor.get("controlled", false)):
        stats["bite_hits"] = int(stats.get("bite_hits", 0)) + 1
    elif not ally.is_empty() and int(target_actor.get("id", -1)) == int(ally.get("id", -2)):
        stats["companion_bite_hits"] = int(stats.get("companion_bite_hits", 0)) + 1
    return outcome

func finish_encounter(outcome: String):
    if game_over:
        return
    game_over = true
    persist_runtime()
    var result = {
        "outcome": outcome,
        "kind": str(context.get("kind", "ambush")),
        "objective_done": objective_done,
        "rescued": objective_done and str(context.get("kind", "")) == "rescue",
        "rescue_contacted": rescue_contacted,
        "rescue_survivor_alive": not rescuee.is_empty() and not bool(rescuee.get("dead", false)),
        "rescue_survivor_hp": int(rescuee.get("hp", -1)) if not rescuee.is_empty() else -1,
        "rescue_survivor_max_hp": int(rescuee.get("max_hp", -1)) if not rescuee.is_empty() else -1,
        "field_gear": str(context.get("field_gear", "")) if objective_done and str(context.get("kind", "")) == "explore" else "",
        "lead_hp": int(player.get("hp", 0)),
        "lead_max_hp": int(player.get("max_hp", 18)),
        "companion_hp": int(ally.get("hp", -1)) if not ally.is_empty() else -1,
        "companion_max_hp": int(ally.get("max_hp", -1)) if not ally.is_empty() else -1,
        "kills": int(stats.kills),
        "shots": int(stats.shots),
        "melee": int(stats.get("melee", 0)),
        "shoves": int(stats.get("shoves", 0)),
        "damage": int(stats.damage),
        "bite_hits": int(stats.get("bite_hits", 0)),
        "companion_bite_hits": int(stats.get("companion_bite_hits", 0)),
        "lead_secondary_item": str(player.get("secondary", "")),
        "lead_secondary_state": player.get("secondary_state", {}).duplicate(true),
        "searches_completed": explore_searched.size(),
        "search_sites_total": explore_cells.size(),
        "containers_opened": looted_containers.size(),
        "container_loot": collected_container_loot(),
    }
    encounter_finished.emit(result)
