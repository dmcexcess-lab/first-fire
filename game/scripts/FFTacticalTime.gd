extends RefCounted
class_name FFTacticalTime

static func movement_cost(actor: Dictionary, backwards := false) -> int:
    var crouched := bool(actor.get("crouched", false))
    var base := 148.0 if crouched else (118.0 if backwards else 100.0)
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    var survival := int(actor.get("skills", {}).get("Survival", 0))
    var multiplier := 1.0
    multiplier += fatigue * 0.0027
    multiplier -= minf(0.12, float(survival) * 0.015)
    match str(actor.get("condition", "Healthy")):
        "Hurt": multiplier += 0.05
        "Wounded": multiplier += 0.13
        "Critical": multiplier += 0.25
    return clampi(int(round(base * multiplier)), 72, 230)

static func turn_cost(actor: Dictionary) -> int:
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    return clampi(int(round(28.0 + fatigue * 0.08)), 25, 52)

static func stance_cost(actor: Dictionary) -> int:
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    return clampi(int(round(32.0 + fatigue * 0.05)), 30, 52)

static func interaction_cost(actor: Dictionary, base_cost: int) -> int:
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    return clampi(int(round(float(base_cost) * (1.0 + fatigue * 0.0015))), maxi(20, base_cost - 10), base_cost + 35)

static func attack_cost(actor: Dictionary, base_cost: int) -> int:
    var fatigue := clampf(float(actor.get("fatigue", 0.0)), 0.0, 100.0)
    var combat := int(actor.get("skills", {}).get("Combat", 0))
    var multiplier := 1.0 + fatigue * 0.0022
    multiplier -= minf(0.10, float(combat) * 0.012)
    return clampi(int(round(float(base_cost) * multiplier)), maxi(45, int(float(base_cost) * 0.78)), int(float(base_cost) * 1.55))

static func zombie_profile(rng: RandomNumberGenerator, look: Dictionary) -> Dictionary:
    var family := str(look.get("family", "civilian"))
    var pace := 118
    var mass := "MED"
    match family:
        "heavy":
            pace = 154
            mass = "HEAVY"
        "decayed":
            pace = 132
            mass = "LIGHT"
        "worker":
            pace = 126
            mass = "HEAVY"
        "service":
            pace = 112
            mass = "LIGHT"
        "medical":
            pace = 119
            mass = "MED"
        _:
            pace = 118
            mass = "MED"
    pace += rng.randi_range(-12, 13)
    var attack_cost := pace + rng.randi_range(-8, 22)
    return {"pace": clampi(pace, 90, 178), "attack_cost": clampi(attack_cost, 100, 195), "mass": mass}

static func zombie_move_cost(zombie: Dictionary) -> int:
    return clampi(int(zombie.get("pace", 125)), 90, 185)

static func zombie_attack_cost(zombie: Dictionary) -> int:
    return clampi(int(zombie.get("attack_cost", int(zombie.get("pace", 125)) + 10)), 100, 200)

static func breath_noise(actor: Dictionary) -> int:
    var fatigue := float(actor.get("fatigue", 0.0))
    if fatigue >= 90.0:
        return 20
    if fatigue >= 75.0:
        return 15
    if fatigue >= 60.0:
        return 11
    return 0
