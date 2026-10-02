extends RefCounted
class_name FFTacticalBalance

const D = preload("res://scripts/FFData.gd")

# Beta tuning owner for the tactical layer. Combat is intentionally built on
# only three survivor stats: Combat, Agility, and Leadership.
const EXPLORE_SITE_COUNT_RANGES := {
    # Very Short / Short are intentionally picked-over and sparse. Farther
    # travel buys more search opportunities rather than simply larger numbers.
    "Camp Perimeter": Vector2i(1, 2),
    "Nearby Streets": Vector2i(2, 3),
    "Residential Blocks": Vector2i(3, 5),
    "Commercial Fringe": Vector2i(4, 6),
    "Industrial Edge": Vector2i(5, 7),
}

const ZOMBIE_BASE_COUNTS := {
    "Camp Perimeter": 2,
    "Nearby Streets": 3,
    "Residential Blocks": 4,
    "Commercial Fringe": 5,
    "Industrial Edge": 6,
}

const RESCUE_SURVIVOR_HP := 14
const RESCUE_CONTACT_TICKS := 55
const RESCUE_PACE_PENALTY := 12

const CONTAINER_POOLS := {
    "fridge": ["Raw Food", "Dirty Water", "Clean Water", "Cooked Food"],
    "ice_box": ["Raw Food", "Dirty Water", "Clean Water", "Cooked Food"],
    "shelf": ["Raw Food", "Dirty Water", "Clean Water", "Plastic", "Cloth"],
    "vending": ["Raw Food", "Clean Water", "Plastic"],
    "cabinet": ["Cloth", "Plastic", "Hardware", "First Aid Kit", "Zombie Cure"],
    "crate": ["Scrap Metal", "Hardware", "Plastic", "Cloth", "Wood"],
    "washer": ["Cloth", "Hardware", "Plastic"],
    "car": ["Scrap Metal", "Hardware", "Cloth", "Plastic"],
    "dumpster": ["Scrap Metal", "Plastic", "Cloth", "Wood"],
    "trash": ["Plastic", "Cloth", "Scrap Metal"],
    "cart": ["Scrap Metal", "Cloth", "Plastic", "Raw Food"],
    "debris": ["Scrap Metal", "Wood", "Hardware", "Plastic"],
}

const CONTAINER_BIASES := {
    "fridge": {"Raw Food": 18, "Dirty Water": 10, "Clean Water": 8, "Cooked Food": 2},
    "ice_box": {"Raw Food": 16, "Dirty Water": 10, "Clean Water": 7, "Cooked Food": 2},
    "shelf": {"Raw Food": 9, "Plastic": 8, "Cloth": 5, "Clean Water": 4},
    "vending": {"Raw Food": 10, "Clean Water": 10, "Plastic": 5},
    "cabinet": {"Cloth": 8, "Plastic": 7, "Hardware": 6, "First Aid Kit": 3, "Zombie Cure": 1},
    "crate": {"Scrap Metal": 14, "Hardware": 12, "Plastic": 7, "Cloth": 5, "Wood": 6},
    "washer": {"Cloth": 16, "Hardware": 4, "Plastic": 4},
    "car": {"Scrap Metal": 12, "Hardware": 10, "Cloth": 5, "Plastic": 4},
    "dumpster": {"Scrap Metal": 10, "Plastic": 10, "Cloth": 7, "Wood": 6},
    "trash": {"Plastic": 11, "Cloth": 8, "Scrap Metal": 5},
    "cart": {"Scrap Metal": 7, "Cloth": 6, "Plastic": 5, "Raw Food": 3},
    "debris": {"Scrap Metal": 12, "Wood": 9, "Hardware": 6, "Plastic": 4},
}

static func explore_site_count_range(zone: String) -> Vector2i:
    return EXPLORE_SITE_COUNT_RANGES.get(zone, Vector2i(3, 5))

static func explore_site_count(zone: String, rng: RandomNumberGenerator = null) -> int:
    var count_range := explore_site_count_range(zone)
    if count_range.x >= count_range.y or rng == null:
        return count_range.x
    return rng.randi_range(count_range.x, count_range.y)

static func loot_container_target(zone: String, rng: RandomNumberGenerator = null) -> int:
    return explore_site_count(zone, rng)

static func locked_container_chance(zone: String) -> float:
    return float({
        "Camp Perimeter": 0.10,
        "Nearby Streets": 0.16,
        "Residential Blocks": 0.22,
        "Commercial Fringe": 0.30,
        "Industrial Edge": 0.36,
    }.get(zone, 0.16))

static func locked_door_chance(zone: String) -> float:
    return float({
        "Camp Perimeter": 0.06,
        "Nearby Streets": 0.10,
        "Residential Blocks": 0.16,
        "Commercial Fringe": 0.22,
        "Industrial Edge": 0.28,
    }.get(zone, 0.10))

static func zombie_count_range(zone: String, kind: String, rescue_is_pet: bool = false, quiet: bool = false) -> Vector2i:
    if kind == "ambush":
        return Vector2i(5, 5)
    if kind == "rescue":
        return Vector2i(3, 3) if rescue_is_pet else Vector2i(5, 5)
    if zone == "Camp Perimeter":
        # Very Short is the only route where the party can get lucky enough
        # to encounter zero or one infected.
        return Vector2i(0, 3)
    var count := int(ZOMBIE_BASE_COUNTS.get(zone, 4))
    if quiet:
        count -= 1
    count = maxi(2, count)
    return Vector2i(count, count)

static func zombie_count(zone: String, kind: String, rescue_is_pet: bool = false, quiet: bool = false, rng: RandomNumberGenerator = null) -> int:
    var count_range := zombie_count_range(zone, kind, rescue_is_pet, quiet)
    if count_range.x >= count_range.y:
        return count_range.x
    if rng == null:
        return count_range.y
    return rng.randi_range(count_range.x, count_range.y)

static func explore_reward_rolls(searches: int, unused_skill: int = 0) -> int:
    if searches <= 0:
        return 0
    var rolls := 1
    if searches >= 3: rolls += 1
    if searches >= 5: rolls += 1
    return clampi(rolls, 1, 3)

static func zombie_hp_range(mass: String) -> Vector2i:
    # All infected stay fragile enough for the authored weapon kill ladder.
    # Mass changes shove/attack behavior more than raw durability.
    if mass == "LIGHT": return Vector2i(7, 9)
    if mass == "HEAVY": return Vector2i(9, 10)
    return Vector2i(8, 10)

static func container_label(container_kind: String) -> String:
    match container_kind:
        "ice_box": return "ice box"
        "dumpster": return "dumpster"
        "trash": return "trash pile"
        "car": return "car"
        "shelf": return "shelf"
        "fridge": return "fridge"
        "cabinet": return "cabinet"
        "crate": return "crate"
        "washer": return "washer"
        "vending": return "vending machine"
        "cart": return "shopping cart"
        "debris": return "debris cache"
        _: return "container"

static func container_search_cost(actor: Dictionary) -> int:
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    return clampi(int(round(78.0 + fatigue * 0.16)), 72, 104)

static func container_search_noise(container_kind: String) -> int:
    if container_kind in ["dumpster", "debris", "car"]: return 26
    if container_kind in ["crate", "washer"]: return 22
    return 17

static func container_empty_chance(zone: String, container_kind: String, zone_pressure: int = 0) -> float:
    var base := float({
        "Camp Perimeter": 0.42,
        "Nearby Streets": 0.32,
        "Residential Blocks": 0.22,
        "Commercial Fringe": 0.15,
        "Industrial Edge": 0.10,
    }.get(zone, 0.25))
    if container_kind in ["trash", "dumpster"]:
        base += 0.06
    elif container_kind in ["car", "vending"]:
        base += 0.03
    if zone_pressure >= 85:
        base += 0.28
    elif zone_pressure >= 60:
        base += 0.18
    elif zone_pressure >= 30:
        base += 0.08
    return clampf(base, 0.05, 0.82)

static func container_allows_item(container_kind: String, item_name: String) -> bool:
    var pool: Array = CONTAINER_POOLS.get(container_kind, [])
    return pool.has(item_name)

static func roll_container_loot(zone: String, container_kind: String, rng: RandomNumberGenerator, zone_pressure: int = 0) -> Dictionary:
    if rng.randf() < container_empty_chance(zone, container_kind, zone_pressure):
        return {}

    var zone_data: Dictionary = D.ZONES.get(zone, D.ZONES["Nearby Streets"])
    var zone_weights: Dictionary = zone_data.get("loot", {})
    var allowed: Array = CONTAINER_POOLS.get(container_kind, [])
    var bias: Dictionary = CONTAINER_BIASES.get(container_kind, {})
    var weights: Dictionary = {}
    for item_value in allowed:
        var item_name := str(item_value)
        var zone_weight := maxi(0, int(zone_weights.get(item_name, 0)))
        if zone_weight <= 0:
            continue
        weights[item_name] = zone_weight + maxi(0, int(bias.get(item_name, 0)))

    var rolls := 1
    var extra_roll_chance := float({
        "Camp Perimeter": 0.10,
        "Nearby Streets": 0.16,
        "Residential Blocks": 0.24,
        "Commercial Fringe": 0.32,
        "Industrial Edge": 0.40,
    }.get(zone, 0.20))
    if rng.randf() < extra_roll_chance:
        rolls += 1
    if zone == "Commercial Fringe" and rng.randf() < 0.10:
        rolls += 1
    elif zone == "Industrial Edge" and rng.randf() < 0.18:
        rolls += 1

    var found: Dictionary = {}
    for _roll in range(rolls):
        var key := _weighted_pick(weights, rng)
        if key != "":
            found[key] = int(found.get(key, 0)) + 1
    return found

static func _weighted_pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
    var total := 0
    for key in weights.keys():
        total += maxi(0, int(weights[key]))
    if total <= 0:
        return ""
    var roll := rng.randi_range(1, total)
    var running := 0
    for key in weights.keys():
        running += maxi(0, int(weights[key]))
        if roll <= running:
            return str(key)
    return ""

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

static func mob_hit_bonus(mob_size: int) -> float:
    return minf(0.18, float(maxi(0, mob_size - 1)) * 0.06)

static func mob_damage_bonus(mob_size: int) -> int:
    if mob_size >= 5:
        return 2
    if mob_size >= 3:
        return 1
    return 0

static func mob_attack_cost_multiplier(mob_size: int) -> float:
    return maxf(0.82, 1.0 - float(maxi(0, mob_size - 1)) * 0.06)

static func mob_alert_radius(pack_size: int) -> int:
    return 3 + mini(3, maxi(0, pack_size - 1))

const BITE_ATTEMPT_CHANCE := 0.20

static func zombie_attack_kind(rng: RandomNumberGenerator) -> String:
    return "bite" if rng.randf() < BITE_ATTEMPT_CHANCE else "scratch"

static func zombie_attack_hit_chance(actor: Dictionary, attack_kind: String, mob_size: int = 1) -> float:
    var agility := int(actor.get("skills", {}).get("Agility", 0))
    var fatigue := float(actor.get("fatigue", 0.0))
    var base := 0.72 if attack_kind == "scratch" else 0.32
    var mob_bonus := mob_hit_bonus(mob_size) if attack_kind == "scratch" else mob_hit_bonus(mob_size) * 0.60
    var chance := base - float(agility) * 0.018 + mob_bonus
    if fatigue >= 80.0: chance += 0.08
    elif fatigue >= 60.0: chance += 0.04
    if bool(actor.get("sprinting", false)):
        chance -= minf(0.22, 0.05 + float(agility) * 0.017)
    return clampf(chance, 0.12 if attack_kind == "bite" else 0.24, 0.68 if attack_kind == "bite" else 0.92)

static func zombie_attack_damage_range(mass: String, attack_kind: String) -> Vector2i:
    if attack_kind == "bite":
        if mass == "LIGHT": return Vector2i(3, 5)
        if mass == "HEAVY": return Vector2i(5, 7)
        return Vector2i(4, 6)
    if mass == "LIGHT": return Vector2i(1, 2)
    if mass == "HEAVY": return Vector2i(1, 3)
    return Vector2i(1, 2)

# Compatibility helpers for the inherited base runtime. Active combat uses the
# explicit scratch/bite helpers above.
static func zombie_hit_chance(actor: Dictionary, mob_size: int = 1) -> float:
    return zombie_attack_hit_chance(actor, "scratch", mob_size)

static func zombie_damage_range(mass: String) -> Vector2i:
    return zombie_attack_damage_range(mass, "scratch")
