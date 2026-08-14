extends RefCounted
class_name FFTacticalVisuals

const SKIN_TONES := ["f2c7a5", "dba47d", "bd805f", "9a644b", "734936", "523629"]
const HAIR_COLORS := ["1b1714", "33251c", "5a3a24", "7b5837", "b28a55", "c5c0b4", "6b2f24"]
const TOP_COLORS := ["3b5368", "6a4634", "596447", "684c63", "7a5538", "365e5b", "4d4e55", "755044"]
const PANTS_COLORS := ["26313a", "3d4039", "43372e", "273b43", "403c48", "2f3430"]
const ACCENT_COLORS := ["d89a3a", "b84e4e", "4f91b8", "7ca45a", "9b6fb3", "d5c261"]
const HAIR_STYLES := ["short", "crop", "long", "bun", "messy", "bald"]
const BODY_TYPES := ["slim", "average", "average", "stocky"]
const HEADWEAR := ["none", "none", "none", "cap", "beanie", "bandana"]

const INFECTED_SKIN := ["75806a", "879075", "666f5f", "8a7868", "5c6658", "817b67"]
const ZOMBIE_TOPS := ["4a4e45", "5a4038", "3f4d54", "625648", "4f3b43", "53584b"]
const ZOMBIE_PANTS := ["292d2b", "343533", "302e2b", "28343a", "40352e"]
const ZOMBIE_FAMILIES_BY_ZONE := {
    "Camp Perimeter": ["civilian", "civilian", "service", "worker"],
    "Nearby Streets": ["civilian", "civilian", "service", "worker", "decayed"],
    "Residential Blocks": ["civilian", "civilian", "decayed", "service", "medical"],
    "Commercial Fringe": ["service", "service", "civilian", "worker", "medical", "decayed"],
    "Industrial Edge": ["worker", "worker", "heavy", "decayed", "civilian"],
}

static func _pick(values: Array, rng: RandomNumberGenerator) -> Variant:
    if values.is_empty():
        return null
    return values[rng.randi_range(0, values.size() - 1)]

static func survivor_appearance(rng: RandomNumberGenerator) -> Dictionary:
    return {
        "body": str(_pick(BODY_TYPES, rng)),
        "skin": str(_pick(SKIN_TONES, rng)),
        "hair": str(_pick(HAIR_STYLES, rng)),
        "hair_color": str(_pick(HAIR_COLORS, rng)),
        "top": str(_pick(TOP_COLORS, rng)),
        "pants": str(_pick(PANTS_COLORS, rng)),
        "accent": str(_pick(ACCENT_COLORS, rng)),
        "headwear": str(_pick(HEADWEAR, rng)),
    }

static func default_survivor_appearance(seed_value: int) -> Dictionary:
    var local_rng := RandomNumberGenerator.new()
    var safe_seed: int = seed_value if seed_value >= 0 else -seed_value
    local_rng.seed = maxi(1, safe_seed * 7919 + 104729)
    return survivor_appearance(local_rng)

static func zombie_appearance(rng: RandomNumberGenerator, zone: String) -> Dictionary:
    var families: Array = Array(ZOMBIE_FAMILIES_BY_ZONE.get(zone, ZOMBIE_FAMILIES_BY_ZONE["Nearby Streets"]))
    var family: String = str(_pick(families, rng))
    var body: String = "stocky" if family == "heavy" else str(_pick(BODY_TYPES, rng))
    var top: String = str(_pick(ZOMBIE_TOPS, rng))
    var accent: String = str(_pick(ACCENT_COLORS, rng))
    var headwear := "none"
    if family == "worker" and rng.randf() < 0.55:
        headwear = "hardhat"
        accent = "d7a33d"
    elif family == "service" and rng.randf() < 0.35:
        headwear = "cap"
    elif family == "medical":
        top = "8aa0a0"
        accent = "d9e5df"
    elif family == "decayed":
        top = "3a3d37"
    return {
        "family": family,
        "body": body,
        "skin": str(_pick(INFECTED_SKIN, rng)),
        "hair": str(_pick(HAIR_STYLES, rng)),
        "hair_color": str(_pick(HAIR_COLORS, rng)),
        "top": top,
        "pants": str(_pick(ZOMBIE_PANTS, rng)),
        "accent": accent,
        "headwear": headwear,
    }

static func weapon_visual(name: String) -> Dictionary:
    match name:
        "Utility Knife", "Kitchen Knife":
            return {"kind": "knife", "length": 7.0, "color": "d9ddd6", "accent": "6d4732"}
        "Wooden Club", "Baseball Bat":
            return {"kind": "club", "length": 10.0, "color": "8a623f", "accent": "4b3527"}
        "Hammer":
            return {"kind": "hammer", "length": 8.0, "color": "b7b9b5", "accent": "71503a"}
        "Improvised Spear":
            return {"kind": "spear", "length": 13.0, "color": "c6c9c4", "accent": "7c5a39"}
        "Crowbar":
            return {"kind": "crowbar", "length": 10.0, "color": "8d3d34", "accent": "5c2926"}
        "Hatchet":
            return {"kind": "hatchet", "length": 8.0, "color": "b7b9b5", "accent": "785337"}
        "Pistol":
            return {"kind": "pistol", "length": 7.0, "color": "6b7377", "accent": "202529"}
        "Shotgun":
            return {"kind": "shotgun", "length": 13.0, "color": "5e6668", "accent": "765036"}
        _:
            return {"kind": "none", "length": 0.0, "color": "ffffff", "accent": "ffffff"}

static func _look_color(look: Dictionary, key: String, fallback: Color) -> Color:
    var value: String = str(look.get(key, ""))
    return Color(value) if value != "" else fallback

static func _body_half_width(body: String, zombie := false) -> float:
    if body == "slim":
        return 2.8
    if body == "stocky":
        return 4.5 if zombie else 4.2
    return 3.5

static func _torso_points(center: Vector2, facing: Vector2i, half_width: float, half_length: float) -> PackedVector2Array:
    var f := Vector2(facing)
    var side := Vector2(-f.y, f.x)
    return PackedVector2Array([
        center + f * half_length + side * half_width,
        center + f * half_length - side * half_width,
        center - f * half_length - side * half_width,
        center - f * half_length + side * half_width,
    ])

static func draw_survivor(canvas: CanvasItem, center: Vector2, actor: Dictionary, controlled: bool):
    var look: Dictionary = actor.get("appearance", {})
    var facing: Vector2i = actor.get("facing", Vector2i(1, 0))
    var f := Vector2(facing)
    var side := Vector2(-f.y, f.x)
    var body_width := _body_half_width(str(look.get("body", "average")))
    var skin := _look_color(look, "skin", Color("c99774"))
    var top := _look_color(look, "top", Color("466783"))
    var pants := _look_color(look, "pants", Color("303842"))
    var accent := _look_color(look, "accent", Color("d6a142"))
    var hair := _look_color(look, "hair_color", Color("2a211b"))

    var ring := Color(.24, .68, 1.0, .95) if controlled else Color(.73, .47, .94, .92)
    canvas.draw_circle(center, 11.5 if controlled else 10.8, Color(ring.r, ring.g, ring.b, .13))
    canvas.draw_circle(center, 11.5 if controlled else 10.8, ring, false, 1.8)

    if str(actor.get("pack", "")) != "":
        var pack_center := center - f * 4.6
        canvas.draw_circle(pack_center, body_width + 1.0, Color(.19, .16, .13))
        canvas.draw_circle(pack_center, body_width, Color(.38, .30, .22))

    var foot_back := center - f * 4.0
    canvas.draw_line(foot_back + side * 2.1, center - f * 8.0 + side * 2.4, pants, 2.6)
    canvas.draw_line(foot_back - side * 2.1, center - f * 8.0 - side * 2.4, pants, 2.6)
    canvas.draw_colored_polygon(_torso_points(center, facing, body_width, 4.6), top)
    canvas.draw_line(center + side * body_width, center + side * (body_width + 1.8) + f * 2.4, skin, 2.0)
    canvas.draw_line(center - side * body_width, center - side * (body_width + 1.8) + f * 2.4, skin, 2.0)

    var head_center := center + f * 5.4
    _draw_head(canvas, head_center, f, side, skin, hair, accent, str(look.get("hair", "short")), str(look.get("headwear", "none")))
    _draw_weapon(canvas, actor, center, f, side)
    canvas.draw_line(head_center + f * 1.5, head_center + f * 5.0, Color(1, 1, 1, .88), 1.2)
    if bool(actor.get("crouched", false)):
        canvas.draw_circle(center, 13.0, Color(.55, .75, 1.0, .78), false, 1.0)

static func _draw_head(canvas: CanvasItem, head_center: Vector2, f: Vector2, side: Vector2, skin: Color, hair: Color, accent: Color, hair_style: String, headwear: String):
    if hair_style != "bald":
        var hair_radius := 4.2 if hair_style == "long" or hair_style == "messy" else 3.7
        canvas.draw_circle(head_center - f * 1.1, hair_radius, hair)
        if hair_style == "long":
            canvas.draw_line(head_center - f * 1.5 + side * 2.7, head_center - f * 4.0 + side * 3.0, hair, 2.0)
            canvas.draw_line(head_center - f * 1.5 - side * 2.7, head_center - f * 4.0 - side * 3.0, hair, 2.0)
        elif hair_style == "bun":
            canvas.draw_circle(head_center - f * 4.0, 1.8, hair)
    canvas.draw_circle(head_center + f * .4, 2.9, skin)

    if headwear == "cap":
        canvas.draw_line(head_center - side * 3.3, head_center + side * 3.3, accent, 2.2)
        canvas.draw_line(head_center + f * 1.0, head_center + f * 3.8, accent, 1.5)
    elif headwear == "beanie":
        canvas.draw_arc(head_center - f * .4, 3.6, PI, TAU, 8, accent, 2.2)
    elif headwear == "bandana":
        canvas.draw_line(head_center - side * 3.0, head_center + side * 3.0, accent, 1.8)
    elif headwear == "hardhat":
        canvas.draw_arc(head_center, 4.0, PI, TAU, 8, accent, 2.4)
        canvas.draw_line(head_center - side * 3.8, head_center + side * 3.8, accent, 1.6)

static func _draw_weapon(canvas: CanvasItem, actor: Dictionary, center: Vector2, f: Vector2, side: Vector2):
    var weapon: Dictionary = actor.get("weapon", {})
    var weapon_name := str(weapon.get("name", "Bare Hands"))
    var visual: Dictionary = weapon_visual(weapon_name)
    var kind := str(visual.get("kind", "none"))
    if kind == "none":
        return
    var length := float(visual.get("length", 8.0))
    var metal := Color(str(visual.get("color", "c8ccc8")))
    var accent := Color(str(visual.get("accent", "684936")))
    var base := center + side * 8.0 - f * (length * .30)
    var tip := base + f * length

    canvas.draw_line(base - f * 1.0, tip + f * 1.0, Color(0, 0, 0, .72), 3.8)
    match kind:
        "knife":
            canvas.draw_line(base, tip, metal, 2.0)
            canvas.draw_line(base - f * 2.0, base + side * 2.2, accent, 2.0)
        "club":
            canvas.draw_line(base, tip, accent, 3.2)
            canvas.draw_circle(tip, 2.0, metal)
        "hammer":
            canvas.draw_line(base, tip, accent, 2.4)
            canvas.draw_line(tip - side * 3.0, tip + side * 3.0, metal, 3.0)
        "spear":
            canvas.draw_line(base, tip, accent, 2.0)
            canvas.draw_colored_polygon(PackedVector2Array([tip + f * 3.0, tip - f * 1.0 + side * 2.2, tip - f * 1.0 - side * 2.2]), metal)
        "crowbar":
            canvas.draw_line(base, tip, metal, 2.6)
            canvas.draw_line(tip, tip + side * 3.0 - f * 1.0, metal, 2.2)
        "hatchet":
            canvas.draw_line(base, tip, accent, 2.3)
            canvas.draw_colored_polygon(PackedVector2Array([tip + side * 3.5, tip - side * .5 + f * 2.0, tip - side * .5 - f * 2.0]), metal)
        "pistol":
            canvas.draw_line(base, tip, metal, 3.4)
            canvas.draw_line(base + f * 1.0, base - side * 3.0, accent, 2.8)
        "shotgun":
            canvas.draw_line(base, tip, metal, 3.0)
            canvas.draw_line(base - f * 1.0, base + f * 4.2, accent, 4.2)

static func draw_zombie(canvas: CanvasItem, center: Vector2, z: Dictionary):
    var look: Dictionary = z.get("look", {})
    var facing: Vector2i = z.get("facing", Vector2i(1, 0))
    var f := Vector2(facing)
    var side := Vector2(-f.y, f.x)
    var family := str(look.get("family", "civilian"))
    var body_width := _body_half_width(str(look.get("body", "average")), true)
    if family == "heavy":
        body_width += 1.0
    var skin := _look_color(look, "skin", Color("74806c"))
    var top := _look_color(look, "top", Color("4c5048"))
    var pants := _look_color(look, "pants", Color("2e322f"))
    var accent := _look_color(look, "accent", Color("b68d45"))
    var hair := _look_color(look, "hair_color", Color("27231f"))

    canvas.draw_line(center - f * 3.5 + side * 2.0, center - f * 7.0 + side * 2.3, pants, 2.7)
    canvas.draw_line(center - f * 3.5 - side * 2.0, center - f * 7.0 - side * 2.3, pants, 2.7)
    canvas.draw_colored_polygon(_torso_points(center, facing, body_width, 4.4), top)
    var reach_a := 4.6 if family != "decayed" else 2.8
    canvas.draw_line(center + side * body_width, center + side * (body_width + 1.4) + f * reach_a, skin, 2.1)
    canvas.draw_line(center - side * body_width, center - side * (body_width + 2.0) + f * 3.5, skin, 2.1)

    var head_center := center + f * 5.0
    _draw_head(canvas, head_center, f, side, skin, hair, accent, str(look.get("hair", "messy")), str(look.get("headwear", "none")))
    if family == "medical":
        canvas.draw_line(center - side * 2.0, center + side * 2.0, accent, 1.4)
        canvas.draw_line(center - f * 2.0, center + f * 2.0, accent, 1.4)
    elif family == "service":
        canvas.draw_line(center - side * body_width, center + side * body_width, accent.darkened(.25), 1.4)
    elif family == "worker":
        canvas.draw_line(center - side * body_width, center + side * body_width, accent, 1.2)
    canvas.draw_line(head_center + f * 1.0, head_center + f * 4.0, Color(.76, .90, .70, .85), 1.2)

static func draw_zombie_corpse(canvas: CanvasItem, center: Vector2, z: Dictionary):
    var look: Dictionary = z.get("look", {})
    var facing: Vector2i = z.get("facing", Vector2i(1, 0))
    var f := Vector2(facing)
    var side := Vector2(-f.y, f.x)
    var skin := _look_color(look, "skin", Color("74806c")).darkened(.48)
    var top := _look_color(look, "top", Color("4c5048")).darkened(.50)
    canvas.draw_circle(center + f * 1.0, 7.5, Color(.18, .035, .03, .48))
    canvas.draw_line(center - side * 6.0, center + side * 5.0, top, 5.0)
    canvas.draw_circle(center + side * 6.5, 3.0, skin)
    canvas.draw_line(center - side * 2.0, center - side * 7.5 + f * 2.5, top.darkened(.1), 2.0)

static func draw_survivor_corpse(canvas: CanvasItem, center: Vector2, actor: Dictionary):
    var look: Dictionary = actor.get("appearance", {})
    var facing: Vector2i = actor.get("facing", Vector2i(1, 0))
    var f := Vector2(facing)
    var side := Vector2(-f.y, f.x)
    var skin := _look_color(look, "skin", Color("c99774")).darkened(.35)
    var top := _look_color(look, "top", Color("466783")).darkened(.45)
    canvas.draw_circle(center, 9.5, Color(.12, .02, .02, .40))
    canvas.draw_line(center - side * 6.0, center + side * 5.0, top, 5.0)
    canvas.draw_circle(center + side * 6.5, 3.0, skin)

static func draw_hit_flash(canvas: CanvasItem, center: Vector2, now_ms: int, until_ms: int):
    if now_ms >= until_ms:
        return
    var pulse := 0.45 + 0.25 * sin(float(now_ms % 90) / 90.0 * TAU)
    canvas.draw_circle(center, 10.5, Color(1.0, .78, .38, pulse), false, 2.2)
    canvas.draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), Color(1, .92, .65, .9), 1.4)
    canvas.draw_line(center + Vector2(0, -6), center + Vector2(0, 6), Color(1, .92, .65, .9), 1.4)

static func draw_muzzle_flash(canvas: CanvasItem, center: Vector2, facing: Vector2i, now_ms: int, until_ms: int):
    if now_ms >= until_ms:
        return
    var f := Vector2(facing)
    var flash_center := center + f * 14.0
    var side := Vector2(-f.y, f.x)
    canvas.draw_circle(flash_center, 6.0, Color(1.0, .78, .20, .70))
    canvas.draw_circle(flash_center, 3.0, Color(1.0, .96, .70, .95))
    canvas.draw_line(flash_center, flash_center + f * 7.0, Color(1, .86, .35, .95), 2.0)
    canvas.draw_line(flash_center, flash_center + side * 5.0, Color(1, .72, .18, .82), 1.2)
    canvas.draw_line(flash_center, flash_center - side * 5.0, Color(1, .72, .18, .82), 1.2)
