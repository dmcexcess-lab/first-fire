extends RefCounted
class_name FFTacticalVisuals

const Tiles = preload("res://scripts/FFTacticalTiles.gd")

const SURVIVOR_ACCENTS := ["d89a3a", "b84e4e", "4f91b8", "7ca45a", "9b6fb3", "d5c261", "d08139", "70b0aa"]
const ZOMBIE_FAMILIES_BY_ZONE := {
    "Camp Perimeter": ["civilian", "civilian", "service", "worker"],
    "Nearby Streets": ["civilian", "civilian", "service", "worker", "decayed"],
    "Residential Blocks": ["civilian", "civilian", "decayed", "service", "medical"],
    "Commercial Fringe": ["service", "service", "civilian", "worker", "medical", "decayed"],
    "Industrial Edge": ["worker", "worker", "heavy", "decayed", "civilian"],
}
const ZOMBIE_VARIANTS_BY_FAMILY := {
    "civilian": [0, 1, 3],
    "service": [1, 6],
    "worker": [2, 5],
    "medical": [6],
    "decayed": [4, 7],
    "heavy": [5, 7],
}

static func _pick(values: Array, rng: RandomNumberGenerator) -> Variant:
    return values[rng.randi_range(0, values.size() - 1)] if not values.is_empty() else null

static func survivor_appearance(rng: RandomNumberGenerator) -> Dictionary:
    var sprite := rng.randi_range(0, 7)
    return {"sprite": sprite, "accent": SURVIVOR_ACCENTS[sprite]}

static func default_survivor_appearance(seed_value: int) -> Dictionary:
    var local_rng := RandomNumberGenerator.new()
    var safe_seed := absi(seed_value)
    local_rng.seed = maxi(1, safe_seed * 7919 + 104729)
    return survivor_appearance(local_rng)

static func zombie_appearance(rng: RandomNumberGenerator, zone: String) -> Dictionary:
    var families: Array = Array(ZOMBIE_FAMILIES_BY_ZONE.get(zone, ZOMBIE_FAMILIES_BY_ZONE["Nearby Streets"]))
    var family := str(_pick(families, rng))
    var variants: Array = Array(ZOMBIE_VARIANTS_BY_FAMILY.get(family, [0]))
    return {"family": family, "sprite": int(_pick(variants, rng))}

static func weapon_visual(name: String) -> Dictionary:
    match name:
        "Utility Knife", "Kitchen Knife": return {"kind": "knife", "atlas": 192}
        "Wooden Club", "Baseball Bat": return {"kind": "club", "atlas": 193}
        "Hammer": return {"kind": "hammer", "atlas": 194}
        "Improvised Spear": return {"kind": "spear", "atlas": 195}
        "Crowbar": return {"kind": "crowbar", "atlas": 196}
        "Hatchet": return {"kind": "hatchet", "atlas": 197}
        "Pistol": return {"kind": "pistol", "atlas": 198}
        "Shotgun": return {"kind": "shotgun", "atlas": 199}
        _: return {"kind": "none", "atlas": -1}

static func _facing_index(facing: Vector2i) -> int:
    if facing == Vector2i(0, -1): return 0
    if facing == Vector2i(1, 0): return 1
    if facing == Vector2i(0, 1): return 2
    return 3

static func _sprite_rect(center: Vector2, size: float) -> Rect2:
    return Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))

static func draw_survivor(canvas: CanvasItem, center: Vector2, actor: Dictionary, controlled: bool) -> void:
    var look: Dictionary = actor.get("appearance", {})
    var variant := clampi(int(look.get("sprite", 0)), 0, 7)
    var facing: Vector2i = actor.get("facing", Vector2i(1, 0))
    var dir_index := _facing_index(facing)
    var ring := Color(.24, .68, 1.0, .96) if controlled else Color(.73, .47, .94, .94)
    canvas.draw_circle(center, 12.4 if controlled else 11.7, Color(ring.r, ring.g, ring.b, .12))
    canvas.draw_circle(center, 12.4 if controlled else 11.7, ring, false, 1.7)
    if str(actor.get("pack", "")) != "":
        var f := Vector2(facing)
        canvas.draw_rect(Rect2(center - f * 7.0 - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color("40372b"))
    Tiles.draw_region(canvas, 96 + variant * 4 + dir_index, _sprite_rect(center, 29.0))
    _draw_weapon_icon(canvas, center, facing, actor)
    _draw_secondary_icon(canvas, center, facing, actor)
    if bool(actor.get("crouched", false)):
        canvas.draw_circle(center, 13.4, Color(.55, .75, 1.0, .76), false, 1.0)

static func _draw_weapon_icon(canvas: CanvasItem, center: Vector2, facing: Vector2i, actor: Dictionary) -> void:
    var weapon: Dictionary = actor.get("weapon", {})
    var visual: Dictionary = weapon_visual(str(weapon.get("name", "Bare Hands")))
    var atlas_index := int(visual.get("atlas", -1))
    if atlas_index < 0:
        return
    var f := Vector2(facing)
    var side := Vector2(-f.y, f.x)
    var p := center + side * 11.0 - f * 1.5
    canvas.draw_circle(p, 7.0, Color(0, 0, 0, .38))
    Tiles.draw_region(canvas, atlas_index, _sprite_rect(p, 14.0))

static func _draw_secondary_icon(canvas: CanvasItem, center: Vector2, facing: Vector2i, actor: Dictionary) -> void:
    var item_name := str(actor.get("secondary", ""))
    var atlas_index := Tiles.item_region(item_name)
    if atlas_index < 0:
        return
    var f := Vector2(facing)
    var side := Vector2(-f.y, f.x)
    var p := center - side * 10.5 - f * 1.0
    canvas.draw_circle(p, 6.2, Color(0, 0, 0, .42))
    Tiles.draw_region(canvas, atlas_index, _sprite_rect(p, 12.0))

static func draw_zombie(canvas: CanvasItem, center: Vector2, zombie: Dictionary) -> void:
    var look: Dictionary = zombie.get("look", {})
    var variant := clampi(int(look.get("sprite", 0)), 0, 7)
    var facing: Vector2i = zombie.get("facing", Vector2i(1, 0))
    Tiles.draw_region(canvas, 128 + variant * 4 + _facing_index(facing), _sprite_rect(center, 29.0))
    if str(zombie.get("mass", "MED")) == "HEAVY":
        canvas.draw_circle(center, 12.2, Color(.70, .24, .18, .28), false, 1.4)

static func draw_survivor_corpse(canvas: CanvasItem, center: Vector2, actor: Dictionary) -> void:
    var look: Dictionary = actor.get("appearance", {})
    var variant := clampi(int(look.get("sprite", 0)), 0, 7)
    Tiles.draw_region(canvas, 160 + variant, _sprite_rect(center, 28.0), Color(1, 1, 1, .82))

static func draw_zombie_corpse(canvas: CanvasItem, center: Vector2, zombie: Dictionary) -> void:
    var look: Dictionary = zombie.get("look", {})
    var variant := clampi(int(look.get("sprite", 0)), 0, 7)
    Tiles.draw_region(canvas, 176 + variant, _sprite_rect(center, 28.0), Color(1, 1, 1, .76))

static func draw_hit_flash(canvas: CanvasItem, center: Vector2, now_ms: int, until_ms: int) -> void:
    if now_ms >= until_ms:
        return
    var remaining := clampf(float(until_ms - now_ms) / 170.0, 0.0, 1.0)
    canvas.draw_circle(center, 9.0 + remaining * 5.0, Color(1.0, .34, .18, .24 + remaining * .35))
    canvas.draw_circle(center, 5.0, Color(1.0, .86, .55, .70 * remaining), false, 2.0)

static func draw_muzzle_flash(canvas: CanvasItem, center: Vector2, facing: Vector2i, now_ms: int, until_ms: int) -> void:
    if now_ms >= until_ms:
        return
    var remaining := clampf(float(until_ms - now_ms) / 90.0, 0.0, 1.0)
    var f := Vector2(facing)
    var side := Vector2(-f.y, f.x)
    var origin := center + f * 11.0
    canvas.draw_colored_polygon(PackedVector2Array([
        origin + f * 11.0,
        origin + side * 4.0,
        origin - side * 4.0,
    ]), Color(1.0, .83, .30, .75 * remaining))
    canvas.draw_circle(origin, 5.0, Color(1.0, .94, .68, .82 * remaining))
