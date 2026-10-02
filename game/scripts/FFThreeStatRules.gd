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
        "", "Bare Hands", "Utility Knife", "Kitchen Knife", "Hammer", "Crowbar", "Hatchet":
            return {"kind": "melee", "hands": 1, "label": "1H MELEE"}
        "Wooden Club", "Baseball Bat", "Improvised Spear", "Sledgehammer":
            return {"kind": "melee", "hands": 2, "label": "2H MELEE"}
        "Crossbow":
            return {"kind": "ranged", "hands": 2, "label": "CROSSBOW"}
        "Pistol":
            return {"kind": "gun", "hands": 1, "label": "1H GUN"}
        "Shotgun", "Rifle":
            return {"kind": "gun", "hands": 2, "label": "2H GUN"}
        _:
            return {"kind": "melee", "hands": 1, "label": "1H MELEE"}

static func weapon_profile(name: String) -> Dictionary:
    var display_name := name if name != "" else "Bare Hands"
    match display_name:
        "Bare Hands":
            return {"name": display_name, "class_label": "FISTS", "hands": 1, "gun": false, "ammo": 0, "dmin": 2, "dmax": 3, "time": 78, "noise": 4, "push": 0, "stealth": 0, "accuracy": 0.04, "reach": 1, "range": 1, "pattern": "melee"}
        "Utility Knife":
            return {"name": display_name, "class_label": "1H MELEE", "hands": 1, "gun": false, "ammo": 0, "dmin": 4, "dmax": 5, "time": 88, "noise": 5, "push": 1, "stealth": 3, "accuracy": 0.05, "reach": 1, "range": 1, "pattern": "melee"}
        "Kitchen Knife", "Hammer", "Crowbar":
            return {"name": display_name, "class_label": "1H MELEE", "hands": 1, "gun": false, "ammo": 0, "dmin": 5, "dmax": 6, "time": 92, "noise": 6, "push": 1, "stealth": 2, "accuracy": 0.03, "reach": 1, "range": 1, "pattern": "melee"}
        "Wooden Club", "Baseball Bat", "Improvised Spear":
            var reach := 2 if display_name == "Improvised Spear" else 1
            return {"name": display_name, "class_label": "2H MELEE", "hands": 2, "gun": false, "ammo": 0, "dmin": 6, "dmax": 8, "time": 118, "noise": 9, "push": 2, "stealth": 1, "accuracy": 0.00, "reach": reach, "range": reach, "pattern": "melee"}
        "Sledgehammer":
            return {"name": display_name, "class_label": "2H MELEE", "hands": 2, "gun": false, "ammo": 0, "dmin": 10, "dmax": 12, "time": 142, "noise": 12, "push": 3, "stealth": 0, "accuracy": -0.04, "reach": 1, "range": 1, "pattern": "melee"}
        "Hatchet":
            return {"name": display_name, "class_label": "1H MELEE", "hands": 1, "gun": false, "ammo": 0, "dmin": 10, "dmax": 11, "time": 102, "noise": 7, "push": 1, "stealth": 1, "accuracy": 0.02, "reach": 1, "range": 1, "pattern": "melee"}
        "Crossbow":
            return {"name": display_name, "class_label": "CROSSBOW", "hands": 2, "gun": true, "ammo": 1, "dmin": 0, "dmax": 0, "time": 118, "noise": 4, "push": 0, "stealth": 0, "accuracy": 0.02, "reach": 1, "gmin": 4, "gmax": 5, "gtime": 138, "gnoise": 16, "gaccuracy": 0.05, "range": 7, "pattern": "single"}
        "Pistol":
            return {"name": display_name, "class_label": "1H GUN", "hands": 1, "gun": true, "ammo": 1, "dmin": 0, "dmax": 0, "time": 92, "noise": 6, "push": 0, "stealth": 0, "accuracy": 0.02, "reach": 1, "gmin": 10, "gmax": 12, "gtime": 104, "gnoise": 70, "gaccuracy": 0.06, "range": 4, "pattern": "single"}
        "Shotgun":
            return {"name": display_name, "class_label": "2H GUN", "hands": 2, "gun": true, "ammo": 2, "dmin": 0, "dmax": 0, "time": 118, "noise": 8, "push": 1, "stealth": 0, "accuracy": 0.00, "reach": 1, "gmin": 12, "gmax": 14, "gtime": 146, "gnoise": 94, "gaccuracy": 0.04, "range": 4, "pattern": "cone"}
        "Rifle":
            return {"name": display_name, "class_label": "2H GUN", "hands": 2, "gun": true, "ammo": 1, "dmin": 0, "dmax": 0, "time": 122, "noise": 8, "push": 0, "stealth": 0, "accuracy": 0.00, "reach": 1, "gmin": 12, "gmax": 15, "gtime": 132, "gnoise": 84, "gaccuracy": 0.08, "range": 10, "pattern": "single"}
        _:
            return {"name": display_name, "class_label": str(weapon_class(display_name).get("label", "1H MELEE")), "hands": 1, "gun": false, "ammo": 0, "dmin": 5, "dmax": 6, "time": 92, "noise": 6, "push": 1, "stealth": 1, "accuracy": 0.02, "reach": 1, "range": 1, "pattern": "melee"}

static func weapon_range(profile: Dictionary) -> int:
    return maxi(1, int(profile.get("range", profile.get("reach", 1))))

static func weapon_pattern(profile: Dictionary) -> String:
    return str(profile.get("pattern", "melee"))


static func attack_chance(combat: int, penalty: float, weapon_accuracy: float, stealth: bool = false) -> float:
    var chance := 0.58 + float(combat) * 0.045 + weapon_accuracy - penalty
    if stealth:
        chance += 0.12
    return clampf(chance, 0.15, 0.96)

static func melee_damage(profile: Dictionary, _combat: int, stealth: bool, rng: RandomNumberGenerator) -> int:
    # Weapon tier owns damage/kill count. Combat improves attack reliability,
    # while stealth adds only a small positional bonus.
    var damage := rng.randi_range(int(profile.get("dmin", 2)), int(profile.get("dmax", 4)))
    if stealth:
        damage += 2
    return maxi(1, damage)

static func gun_damage(profile: Dictionary, _combat: int, rng: RandomNumberGenerator) -> int:
    # Ranged weapon tier owns lethality; Combat is accuracy/handling.
    return maxi(1, rng.randi_range(int(profile.get("gmin", 6)), int(profile.get("gmax", 10))))

static func normal_move_cost(agility: int, base_cost: int) -> int:
    var reduction:=minf(0.20,float(agility)*0.02)
    return maxi(52,int(round(float(base_cost)*(1.0-reduction))))

static func sprint_move_cost(agility: int, base_cost: int) -> int:
    var reduction:=0.38+minf(0.20,float(agility)*0.02)
    return maxi(28,int(round(float(base_cost)*(1.0-reduction))))

static func stealth_move_cost(agility: int, base_cost: int) -> int:
    var surcharge:=maxf(0.30,0.45-float(agility)*0.015)
    return maxi(78,int(round(float(base_cost)*(1.0+surcharge))))

static func stealth_noise(agility: int) -> int:
    return maxi(2, 8 - int(floor(float(agility) * 0.65)))

static func sprint_noise(agility: int) -> int:
    return maxi(22, 34 - int(floor(float(agility) * 0.8)))

static func sprint_evasion_bonus(agility: int) -> float:
    return minf(0.22, 0.05 + float(agility) * 0.017)
