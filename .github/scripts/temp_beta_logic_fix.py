from pathlib import Path

# Restore one-bed-over temporary overcrowding while preserving hard cap.
p = Path('game/scripts/Game.gd')
s = p.read_text()
old = '''    if population() >= MAX_POPULATION:\n        toast_requested.emit("First Fire is at its %d-person limit." % MAX_POPULATION)\n        return null\n    if population() >= shelter_capacity():\n        toast_requested.emit("There is no open shelter space right now.")\n        return null\n'''
new = '''    if population() >= MAX_POPULATION:\n        toast_requested.emit("First Fire is at its %d-person limit." % MAX_POPULATION)\n        return null\n    if population() >= mini(MAX_POPULATION, shelter_capacity() + 1):\n        toast_requested.emit("There is no room to squeeze another survivor into camp right now.")\n        return null\n'''
if s.count(old) != 1:
    raise SystemExit('recruit capacity block mismatch')
s = s.replace(old, new, 1)
old2 = '''func _has_room_for_recruit():\n    return population() < MAX_POPULATION and population() < shelter_capacity()\n'''
new2 = '''func _has_room_for_recruit():\n    return population() < MAX_POPULATION and population() < mini(MAX_POPULATION, shelter_capacity() + 1)\n'''
if s.count(old2) != 1:
    raise SystemExit('room helper mismatch')
s = s.replace(old2, new2, 1)
p.write_text(s)

p = Path('game/scripts/FFExpeditionRules.gd')
s = p.read_text()
old = '''    if not recruit_eligible or population >= mini(shelter_capacity, max_population):\n        return false\n'''
new = '''    if not recruit_eligible or population >= max_population:\n        return false\n'''
if s.count(old) != 1:
    raise SystemExit('force recruit gate mismatch')
p.write_text(s.replace(old, new, 1))
print('beta recruitment consistency fix prepared')
