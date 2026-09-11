extends RefCounted
class_name FFTacticalBalance

# Beta tuning owner for the tactical layer. Combat is intentionally built on
# only three survivor stats: Combat, Agility, and Leadership.
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

const RESCUE_SURVIVOR_HP := 12
const RESCUE_CONTACT_TICKS := 70
const RESCUE_PACE_PENALTY := 18

static func explore_site_count(zone: String) -> int:
    return int(EXPLORE_SITE_COUNTS.get(zone, 3))

static func zombie_count(zone: String, kind: String) -> int:
    var count := int(ZOMBIE_BASE_COUNTS.get(zone, 4))
    if kind in ["explore", "rescue"]:
        count -= 1
    elif kind == "ambush":
        count += 1
    return maxi(2, count)

static func explore_reward_rolls(searches: int, unused_skill: int = 0) -> int:
    if searches <= 0:
        return 0
    var rolls := 1
    if searches >= 3: rolls += 1
    if searches >= 5: rolls += 1
    return clampi(rolls, 1, 3)

static func search_cost(actor: Dictionary) -> int:
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    var cost := 108.0 + fatigue * 0.18
    if bool(actor.get("crouched", false)):
        cost += 8.0
    return clampi(int(round(cost)), 84, 138)

static func search_noise(actor: Dictionary) -> int:
    var noise := 28
    if bool(actor.get("crouched", false)):
        noise -= 8
    return clampi(noise, 16, 32)

static func melee_hit_chance(combat: int, penalty: float, stealth: bool, accuracy: float) -> float:
    var chance := 0.58 + float(combat) * 0.045 + accuracy - penalty
    if stealth: chance += 0.12
    return clampf(chance, 0.15, 0.96)

static func gun_hit_chance(combat: int, distance: int, penalty: float, accuracy: float) -> float:
    var range_penalty := float(maxi(0, distance - 3)) * 0.04
    return clampf(0.58 + float(combat) * 0.045 + accuracy - range_penalty - penalty, 0.12, 0.94)

static func shove_chance(actor: Dictionary, mass: String, weapon_push: int) -> float:
    var combat := int(actor.get("skills", {}).get("Combat", 0))
    var agility := int(actor.get("skills", {}).get("Agility", 0))
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    var mass_penalty := 0.22 if mass == "HEAVY" else (0.08 if mass == "MED" else 0.0)
    var chance := 0.68 + float(combat) * 0.03 + float(agility) * 0.012 + float(weapon_push) * 0.03
    chance -= fatigue * 0.0022 + mass_penalty
    return clampf(chance, 0.25, 0.94)

static func shove_stagger_ticks(mass: String, pinned: bool) -> int:
    var stagger := 55
    if mass == "LIGHT": stagger = 75
    elif mass == "HEAVY": stagger = 35
    if pinned: stagger += 25
    return stagger

static func guard_bonus(actor: Dictionary) -> float:
    var combat := int(actor.get("skills", {}).get("Combat", 0))
    var agility := int(actor.get("skills", {}).get("Agility", 0))
    return clampf(0.17 + float(combat) * 0.008 + float(agility) * 0.006, 0.17, 0.30)

static func zombie_hit_chance(actor: Dictionary) -> float:
    var agility := int(actor.get("skills", {}).get("Agility", 0))
    var fatigue := float(actor.get("fatigue", 0.0))
    var chance := 0.66 - float(agility) * 0.018
    if fatigue >= 80.0: chance += 0.08
    elif fatigue >= 60.0: chance += 0.04
    if bool(actor.get("sprinting", false)):
        chance -= minf(0.22, 0.05 + float(agility) * 0.017)
    if bool(actor.get("guarding", false)):
        chance -= guard_bonus(actor)
    return clampf(chance, 0.18, 0.82)

static func zombie_damage_range(mass: String) -> Vector2i:
    if mass == "LIGHT": return Vector2i(1, 4)
    if mass == "HEAVY": return Vector2i(3, 6)
    return Vector2i(2, 5)
