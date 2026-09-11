extends RefCounted
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
