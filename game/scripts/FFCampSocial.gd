extends RefCounted
class_name FFCampSocial

# Current relationship/social selection rules live here. Alpha 0.5 can grow this
# into autonomous survivor interaction logic without making Game.gd own it.
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
    if amount > 0 and a["traits"].has("Friendly"):
        adjusted *= 1.25
    if amount > 0 and a["traits"].has("Loner"):
        adjusted *= 0.5
    if amount < 0 and leader_id == int(a["id"]) and a["leader_ability"] == "Mediator":
        adjusted *= 0.75
    a["relationships"][key] = clampi(int(a["relationships"].get(key, 0)) + int(round(adjusted)), -100, 100)

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
