from pathlib import Path
p=Path('game/scripts/Game.gd')
t=p.read_text()
old='    var pop:=population(); var capacity:=shelter_capacity()\n'
new='    var pop: int = int(population())\n    var capacity: int = int(shelter_capacity())\n'
assert old in t
t=t.replace(old,new,1)
old='    var everyone_fed:=food_missing==0; var everyone_watered:=water_missing==0\n'
new='    var everyone_fed: bool = int(food_missing) == 0\n    var everyone_watered: bool = int(water_missing) == 0\n'
assert old in t
t=t.replace(old,new,1)
p.write_text(t)
