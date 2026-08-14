extends RefCounted
class_name FFCampSocial

static func relationship_label(value: int) -> String:
    if value >= 60: return "Close"
    if value >= 25: return "Friendly"
    if value <= -60: return "Hostile"
    if value <= -25: return "Tense"
    return "Neutral"

static func change_relationship(a: Dictionary, b: Dictionary, amount: int, leader_id: int) -> void:
    if a.is_empty() or b.is_empty():
        return
    var key := str(b["id"])
    var adjusted := float(amount)
    if amount > 0 and a.get("traits", []).has("Friendly"):
        adjusted *= 1.25
    if amount > 0 and a.get("traits", []).has("Loner"):
        adjusted *= 0.5
    if amount < 0 and leader_id == int(a["id"]) and str(a.get("leader_ability", "")) == "Mediator":
        adjusted *= 0.75
    a["relationships"][key] = clampi(int(a["relationships"].get(key, 0)) + int(round(adjusted)), -100, 100)

static func camp_survivors(survivors: Array) -> Array:
    var result: Array = []
    for survivor_value in survivors:
        var survivor: Dictionary = survivor_value
        if str(survivor.get("condition", "Dead")) == "Dead":
            continue
        var status := str(survivor.get("status", "Available"))
        if status in ["Expedition", "Pending Expedition Event", "Tactical Encounter"]:
            continue
        var task: Dictionary = survivor.get("task", {})
        if task.has("expedition_id"):
            continue
        result.append(survivor)
    return result

static func pick_pair(survivors: Array, rng: RandomNumberGenerator) -> Array:
    var camp := camp_survivors(survivors)
    if camp.size() < 2:
        return []
    var first := rng.randi_range(0, camp.size() - 1)
    var second := rng.randi_range(0, camp.size() - 2)
    if second >= first:
        second += 1
    return [camp[first], camp[second]]

static func tense_pair(survivors: Array) -> Array:
    for a in survivors:
        if a["condition"] == "Dead": continue
        for b in survivors:
            if b["condition"] == "Dead" or int(a["id"]) >= int(b["id"]): continue
            if int(a["relationships"].get(str(b["id"]), 0)) <= -25 or int(b["relationships"].get(str(a["id"]), 0)) <= -25:
                return [a, b]
    return []

static func high_stress_survivor(survivors: Array) -> Variant:
    for survivor in survivors:
        if survivor["condition"] != "Dead" and (float(survivor["stress"]) >= 80.0 or float(survivor["fatigue"]) >= 85.0):
            return survivor
    return null

static func highest_stress_survivor(survivors: Array) -> Variant:
    var best: Variant = null
    for survivor in survivors:
        if survivor["condition"] == "Dead": continue
        if best == null or float(survivor["stress"]) > float(best["stress"]):
            best = survivor
    return best

static func highest_skill_survivor(survivors: Array, skill: String) -> Variant:
    var best: Variant = null
    for survivor in survivors:
        if survivor["condition"] == "Dead": continue
        if best == null or int(survivor["skills"].get(skill, 0)) > int(best["skills"].get(skill, 0)):
            best = survivor
    return best

static func candidate_standing(candidate: Dictionary, survivors: Array) -> int:
    var rel_sum := 0
    var rel_count := 0
    for other in survivors:
        if other["condition"] == "Dead" or int(other["id"]) == int(candidate["id"]): continue
        rel_sum += int(other["relationships"].get(str(candidate["id"]), 0))
        rel_count += 1
    var average: float = float(rel_sum) / float(rel_count) if rel_count > 0 else 0.0
    return int(candidate["skills"].get("Social", 0)) * 6 + int(candidate.get("reputation", 0)) + int(clampf(average * 0.5, -25.0, 25.0))

static func top_candidates(survivors: Array) -> Array:
    var living: Array = []
    for survivor in survivors:
        if survivor["condition"] != "Dead":
            living.append(survivor)
    living.sort_custom(func(a, b): return candidate_standing(a, survivors) > candidate_standing(b, survivors))
    if living.size() >= 2:
        return [living[0], living[1]]
    return living

static func strongest_challenger(survivors: Array, incumbent_id: int) -> Variant:
    var living: Array = []
    for survivor in survivors:
        if survivor["condition"] != "Dead" and int(survivor["id"]) != incumbent_id:
            living.append(survivor)
    living.sort_custom(func(a, b): return candidate_standing(a, survivors) > candidate_standing(b, survivors))
    return living[0] if not living.is_empty() else null

static func leader_support_score(leader: Variant, survivors: Array) -> float:
    if leader == null:
        return 0.0
    var total := 0.0
    var count := 0
    for survivor in survivors:
        if survivor["condition"] == "Dead" or int(survivor["id"]) == int(leader["id"]):
            continue
        total += int(survivor["relationships"].get(str(leader["id"]), 0)) + int(survivor.get("leader_support", 0))
        count += 1
    return total / float(count) if count > 0 else 0.0

static func _first_name(survivor: Dictionary) -> String:
    return str(survivor.get("name", "Survivor")).get_slice(" ", 0)

static func _find_survivor(survivors: Array, sid: int) -> Variant:
    for survivor in survivors:
        if int(survivor.get("id", -1)) == sid and survivor.get("condition", "Dead") != "Dead":
            return survivor
    return null

static func roll_chatter(survivors: Array, leader_id: int, coordinator_id: int, food_shortage_days: int, water_shortage_days: int, policies: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    var pair := pick_pair(survivors, rng)
    if pair.size() != 2:
        return {}
    var speaker: Dictionary = pair[0]
    var listener: Dictionary = pair[1]
    var rel := int(speaker["relationships"].get(str(listener["id"]), 0))
    var reverse_rel := int(listener["relationships"].get(str(speaker["id"]), 0))
    var text := "You holding up?"
    var tone := "neutral"
    var rel_delta := 0
    var reverse_delta := 0
    var speaker_stress_delta := 0.0
    var listener_stress_delta := 0.0
    var decided := false

    if water_shortage_days > 0 and rng.randf() < 0.35:
        text = "We need water before anything else."
        tone = "worry"
        decided = true
    elif food_shortage_days > 0 and rng.randf() < 0.35:
        text = "Food's getting too thin."
        tone = "worry"
        decided = true

    var active_leader_id := leader_id if leader_id != -1 else coordinator_id
    var leader: Variant = _find_survivor(survivors, active_leader_id) if active_leader_id != -1 else null
    if not decided and leader != null and int(speaker["id"]) != active_leader_id and rng.randf() < 0.40:
        var speaker_support := int(speaker["relationships"].get(str(active_leader_id), 0)) + int(speaker.get("leader_support", 0))
        var listener_support := int(listener["relationships"].get(str(active_leader_id), 0)) + int(listener.get("leader_support", 0))
        if speaker_support <= -20:
            text = "I don't trust %s's calls." % _first_name(leader)
            tone = "politics"
            rel_delta = 1 if listener_support <= -10 else -1
            reverse_delta = rel_delta
            decided = true
        elif speaker_support >= 20:
            text = "%s's keeping us together." % _first_name(leader)
            tone = "politics"
            rel_delta = 1 if listener_support >= 5 else -1
            reverse_delta = rel_delta
            decided = true

    if not decided and rel <= -60:
        text = "Stay out of my way."
        tone = "hostile"
        rel_delta = -1
        reverse_delta = -1 if reverse_rel <= -25 else 0
        speaker_stress_delta = 1.0
        decided = true
    elif not decided and rel <= -25:
        text = "I'm still not over that."
        tone = "tense"
        rel_delta = -1 if rng.randf() < 0.45 else 0
        decided = true
    elif not decided and rel >= 60:
        text = "Good to have you here."
        tone = "warm"
        rel_delta = 1
        reverse_delta = 1
        speaker_stress_delta = -1.5
        listener_stress_delta = -1.0
        decided = true
    elif not decided and rel >= 25:
        text = "Need a hand with anything?"
        tone = "friendly"
        rel_delta = 1 if rng.randf() < 0.40 else 0
        reverse_delta = rel_delta
        speaker_stress_delta = -0.5
        decided = true

    if not decided and str(policies.get("Expedition Duty", "")) == "Rotation" and rng.randf() < 0.25:
        text = "Rotation's fair. Nobody gets burned out."
        tone = "politics"
        decided = true
    if not decided and speaker.get("traits", []).has("Optimistic"):
        text = "We'll make this place work."
        tone = "warm"
        listener_stress_delta = -0.5
        decided = true
    if not decided and speaker.get("traits", []).has("Pessimistic"):
        text = "Don't get too comfortable."
        tone = "worry"
        decided = true
    if not decided and speaker.get("traits", []).has("Protective"):
        text = "You take a break. I'll keep an eye out."
        tone = "friendly"
        listener_stress_delta = -1.0
        decided = true
    if not decided and float(listener.get("stress", 0.0)) >= 65.0:
        text = "You look rough. Sit down a minute."
        tone = "friendly"
        listener_stress_delta = -1.0
        decided = true

    return {
        "speaker_id": int(speaker["id"]),
        "listener_id": int(listener["id"]),
        "speaker_name": _first_name(speaker),
        "listener_name": _first_name(listener),
        "text": text,
        "tone": tone,
        "relationship_delta": rel_delta,
        "reverse_delta": reverse_delta,
        "speaker_stress_delta": speaker_stress_delta,
        "listener_stress_delta": listener_stress_delta,
    }
