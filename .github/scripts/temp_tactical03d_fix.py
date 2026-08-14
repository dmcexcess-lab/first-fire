from pathlib import Path


def patch(path, replacements):
    p = Path(path)
    text = p.read_text()
    for old, new, label in replacements:
        count = text.count(old)
        if count != 1:
            raise SystemExit(f'{label}: expected 1, found {count}')
        text = text.replace(old, new, 1)
    p.write_text(text)

patch('game/scripts/FFTacticalTiles.gd', [
    ('const ATLAS: Texture2D = preload("res://assets/tactical_atlas.svg")', 'const ATLAS: Texture2D = preload("res://assets/tactical_atlas.png")', 'png atlas preload'),
    ('canvas.draw_texture_rect_region(rect, ATLAS, region(index), modulate, false, true)', 'canvas.draw_texture_rect_region(ATLAS, rect, region(index), modulate, false, true)', 'draw argument order'),
])

patch('game/scripts/FFCombat.gd', [
    ('    var dest := player.pos - keep', '    var dest: Vector2i = player.pos - keep', 'backward dest type'),
    ('        var target = rescue_cell if kind == "rescue" else objective_cell', '        var target: Vector2i = rescue_cell if kind == "rescue" else objective_cell', 'objective target type'),
    ('    var chance := clamp(0.54 + combat * 0.055 - attack_penalty(player) + (0.30 if stealth else 0.0), 0.12, 0.97)', '    var chance: float = clampf(0.54 + combat * 0.055 - attack_penalty(player) + (0.30 if stealth else 0.0), 0.12, 0.97)', 'melee chance type'),
    ('    var chance := clamp(0.52 + combat * 0.06 - max(0, dist - 3) * 0.035 - attack_penalty(player), 0.10, 0.95)', '    var chance: float = clampf(0.52 + combat * 0.06 - maxi(0, dist - 3) * 0.035 - attack_penalty(player), 0.10, 0.95)', 'shoot chance type'),
    ('            var d := DIRS[rng.randi_range(0,3)]', '            var d: Vector2i = DIRS[rng.randi_range(0,3)]', 'zombie wander dir type'),
    ('            var p := z.pos + d', '            var p: Vector2i = z.pos + d', 'zombie wander cell type'),
    ('    var hit := clamp(0.67 - defense + (0.08 if float(target_actor.fatigue) >= 80 else 0.0), 0.25, 0.82)', '    var hit: float = clampf(0.67 - defense + (0.08 if float(target_actor.fatigue) >= 80 else 0.0), 0.25, 0.82)', 'zombie hit type'),
    ('    var source := player.pos', '    var source: Vector2i = player.pos', 'ambient source type'),
    ('    var x0 := a.x; var y0 := a.y; var x1 := b.x; var y1 := b.y\n    var dx := abs(x1-x0); var sx := 1 if x0<x1 else -1\n    var dy := -abs(y1-y0); var sy := 1 if y0<y1 else -1\n    var err := dx+dy', '    var x0: int = a.x; var y0: int = a.y; var x1: int = b.x; var y1: int = b.y\n    var dx: int = absi(x1-x0); var sx: int = 1 if x0<x1 else -1\n    var dy: int = -absi(y1-y0); var sy: int = 1 if y0<y1 else -1\n    var err: int = dx+dy', 'line clear integer types'),
    ('        var e2 := 2*err', '        var e2: int = 2*err', 'line clear e2 type'),
])

print('FIRST_FIRE_TACTICAL_03D_FIX_OK')
