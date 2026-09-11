from pathlib import Path
p = Path('game/scripts/FFCombat.gd')
s = p.read_text()
replacements = {
    '    var diff := target - player.pos\n': '    var diff: Vector2i = target - player.pos\n',
    '        var between := player.pos + dir * step\n': '        var between: Vector2i = player.pos + dir * step\n',
    '    var target := player.pos + player.facing\n': '    var target: Vector2i = player.pos + player.facing\n',
}
for old, new in replacements.items():
    if old not in s:
        raise SystemExit('missing type-fix anchor: ' + old.strip())
    s = s.replace(old, new, 1)
p.write_text(s)
Path('.github/scripts/temp_tactical_depth_type_fix.py').unlink()
print('FIRST_FIRE_TACTICAL_DEPTH_TYPE_FIX_OK')
