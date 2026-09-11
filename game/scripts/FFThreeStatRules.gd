extends RefCounted
class_name FFThreeStatRules

const STAT_NAMES := ["Combat", "Agility", "Leadership"]

static func default_stats() -> Dictionary:
    return {"Combat": 0, "Agility": 0, "Leadership": 0}

static func normalize_stats(value) -> Dictionary:
    var out := default_stats()
    var source: Dictionary = value if value is Dictionary else {}
    for stat in STAT_NAMES:
        out[stat] = clampi(int(source.get(stat, 0)), 0, 10)
    return out

static func background_bonus(background: String) -> Dictionary:
    match background:
        "Security Guard", "Police Officer", "Soldier": return {"Combat": 2, "Agility": 0, "Leadership": 1}
        "Construction Worker", "Mechanic", "Warehouse Worker": return {"Combat": 1, "Agility": 1, "Leadership": 0}
        "Nursing Assistant", "Teacher", "Manager": return {"Combat": 0, "Agility": 0, "Leadership": 2}
        "College Student", "Cook", "Retail Worker": return {"Combat": 0, "Agility": 2, "Leadership": 0}
        "Retiree": return {"Combat": 0, "Agility": 0, "Leadership": 1}
        _: return {"Combat": 0, "Agility": 1, "Leadership": 0}

static func weapon_class(name: String) -> Dictionary:
    match name:
        "Utility Knife", "Kitchen Knife", "Hammer", "Crowbar", "Hatchet":
            return {"kind": "melee", "hands": 1, "label": "1H MELEE"}
        "Wooden Club", "Baseball Bat", "Improvised Spear":
            return {"kind": "melee", "hands": 2, "label": "2H MELEE"}
        "Pistol":
            return {"kind": "gun", "hands": 1, "label": "1H GUN"}
        "Shotgun":
            return {"kind": "gun", "hands": 2, "label": "2H GUN"}
        _:
            return {"kind": "melee", "hands": 1, "label": "1H MELEE"}

static func weapon_profile(name: String) -> Dictionary:
    var wc := weapon_class(name)
    var kind := str(wc["kind"])
    var hands := int(wc["hands"])
    if kind == "gun" and hands == 1:
        return {"name": name, "class_label": "1H GUN", "hands": 1, "gun": true, "ammo": 1, "dmin": 2, "dmax": 4, "time": 92, "noise": 6, "push": 0, "stealth": 0, "accuracy": 0.02, "reach": 1, "gmin": 7, "gmax": 12, "gtime": 104, "gnoise": 70, "gaccuracy": 0.06}
    if kind == "gun" and hands == 2:
        return {"name": name, "class_label": "2H GUN", "hands": 2, "gun": true, "ammo": 2, "dmin": 3, "dmax": 5, "time": 118, "noise": 8, "push": 1, "stealth": 0, "accuracy": 0.00, "reach": 1, "gmin": 12, "gmax": 19, "gtime": 146, "gnoise": 94, "gaccuracy": 0.00}
    if kind == "melee" and hands == 2:
        var reach := 2 if name == "Improvised Spear" else 1
        return {"name": name, "class_label": "2H MELEE", "hands": 2, "gun": false, "ammo": 0, "dmin": 6, "dmax": 10, "time": 122, "noise": 9, "push": 2, "stealth": 2, "accuracy": -0.01, "reach": reach}
    var display_name := name if name != "" else "Bare Hands"
    return {"name": display_name, "class_label": "1H MELEE", "hands": 1, "gun": false, "ammo": 0, "dmin": 3, "dmax": 7, "time": 88, "noise": 5, "push": 1, "stealth": 3, "accuracy": 0.05, "reach": 1}

static func attack_chance(combat: int, penalty: float, weapon_accuracy: float, stealth: bool = false) -> float:
    var chance := 0.58 + float(combat) * 0.045 + weapon_accuracy - penalty
    if stealth:
        chance += 0.12
    return clampf(chance, 0.15, 0.96)

static func melee_damage(profile: Dictionary, combat: int, stealth: bool, rng: RandomNumberGenerator) -> int:
    var damage := rng.randi_range(int(profile.get("dmin", 2)), int(profile.get("dmax", 4)))
    damage += int(floor(float(combat) * (0.45 if int(profile.get("hands", 1)) == 2 else 0.30)))
    if stealth:
        damage += 2 + int(floor(float(combat) * 0.5))
    return maxi(1, damage)

static func gun_damage(profile: Dictionary, combat: int, rng: RandomNumberGenerator) -> int:
    var damage := rng.randi_range(int(profile.get("gmin", 6)), int(profile.get("gmax", 10)))
    damage += int(floor(float(combat) * (0.55 if int(profile.get("hands", 1)) == 2 else 0.40)))
    return maxi(1, damage)

static func normal_move_cost(agility: int, base_cost: int) -> int:
    return maxi(38, int(round(float(base_cost) * (1.0 - minf(0.25, float(agility) * 0.025)))))

static func sprint_move_cost(agility: int, base_cost: int) -> int:
    var reduction := 0.35 + minf(0.25, float(agility) * 0.025)
    return maxi(24, int(round(float(base_cost) * (1.0 - reduction))))

static func stealth_move_cost(agility: int, base_cost: int) -> int:
    var surcharge := maxf(0.05, 0.30 - float(agility) * 0.025)
    return maxi(45, int(round(float(base_cost) * (1.0 + surcharge))))

static func stealth_noise(agility: int) -> int:
    return maxi(2, 8 - int(floor(float(agility) * 0.65)))

static func sprint_noise(agility: int) -> int:
    return maxi(22, 34 - int(floor(float(agility) * 0.8)))

static func sprint_evasion_bonus(agility: int) -> float:
    return minf(0.22, 0.05 + float(agility) * 0.017)
