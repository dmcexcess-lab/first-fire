from pathlib import Path
p = Path('game/scripts/FFData.gd')
s = p.read_text()
old = '''    "Nearby Streets": [\n        "Baseball Bat", "Hammer", "Headlamp", "Lantern", "Pry Tool",\n        "Work Jacket", "Heavy Boots", "First Aid Kit"\n    ],\n'''
new = '''    "Nearby Streets": [\n        "Baseball Bat", "Hammer", "Improvised Spear", "Headlamp", "Lantern", "Pry Tool",\n        "Work Jacket", "Heavy Boots", "First Aid Kit"\n    ],\n'''
if s.count(old) != 1:
    raise SystemExit(f'expected Nearby Streets gear tier once, found {s.count(old)}')
p.write_text(s.replace(old, new, 1))
print('tactical spear loot fix prepared')
