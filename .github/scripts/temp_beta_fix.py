from pathlib import Path
p = Path('game/scripts/Game.gd')
s = p.read_text()
old = '''        var base = 45.0 if s["condition"] == "Wounded" else 120.0
        var medical_skill = _best_available_skill("Medical", sid)
        var reduction = min(0.35, medical_skill * 0.04)
        var treatment_time := base * (1.0 - reduction) * CampLifeRules.treatment_time_multiplier(bool(buildings.get("Infirmary", false)))
'''
new = '''        var base: float = 45.0 if s["condition"] == "Wounded" else 120.0
        var medical_skill: int = int(_best_available_skill("Medical", sid))
        var reduction: float = minf(0.35, float(medical_skill) * 0.04)
        var treatment_time: float = base * (1.0 - reduction) * CampLifeRules.treatment_time_multiplier(bool(buildings.get("Infirmary", false)))
'''
if s.count(old) != 1:
    raise SystemExit('expected treatment block exactly once')
p.write_text(s.replace(old, new, 1))
print('beta parse fix prepared')
