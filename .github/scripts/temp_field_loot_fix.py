from pathlib import Path
p = Path('game/scripts/Game.gd')
s = p.read_text()
old = '        var reward := _grant_tactical_explore_reward(exp, lead)\n'
new = '        var reward: String = str(_grant_tactical_explore_reward(exp, lead))\n'
if s.count(old) != 1:
    raise SystemExit(f'expected reward line once, found {s.count(old)}')
p.write_text(s.replace(old, new, 1))
print('field loot typing fix prepared')
