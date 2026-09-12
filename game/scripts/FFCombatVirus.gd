extends "res://scripts/FFCombatThreeStat.gd"

func restore_runtime():
    super.restore_runtime()
    stats["infected_hits"] = int(runtime.get("infected_hits", 0))

func persist_runtime():
    super.persist_runtime()
    runtime["infected_hits"] = int(stats.get("infected_hits", 0))
    Game.update_combat_runtime(runtime)

func zombie_attack(i: int, target_actor: Dictionary):
    var hp_before := int(target_actor.get("hp", 0))
    super.zombie_attack(i, target_actor)
    if bool(target_actor.get("controlled", false)) and int(target_actor.get("hp", 0)) < hp_before:
        stats["infected_hits"] = int(stats.get("infected_hits", 0)) + 1

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
        "infected_hits": int(stats.get("infected_hits", 0)),
        "searches_completed": explore_searched.size(),
        "search_sites_total": explore_cells.size(),
        "containers_opened": looted_containers.size(),
        "container_loot": collected_container_loot(),
    }
    encounter_finished.emit(result)
