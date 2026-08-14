extends RefCounted
class_name FFTacticalLighting

const D = preload("res://scripts/FFData.gd")

# Lightweight tactical lighting math. Environments own where fixed lights are,
# FFCombat owns occlusion and when the light map is recalculated, and this module
# owns shared falloff/color/profile rules.
const AMBIENT_BY_THEME := {
    "alley": {"level": 0.13, "tint": "0b1120"},
    "gas": {"level": 0.20, "tint": "111523"},
    "house": {"level": 0.11, "tint": "141018"},
    "apartment": {"level": 0.12, "tint": "0d1420"},
    "store": {"level": 0.15, "tint": "0b1518"},
    "industrial": {"level": 0.10, "tint": "0d1214"},
    "wash": {"level": 0.08, "tint": "09101b"},
}

const SOURCE_PRESETS := {
    "neon_pink": {"radius": 5.2, "strength": 0.94, "color": "ff4fa3", "flicker": true},
    "neon_cyan": {"radius": 4.8, "strength": 0.88, "color": "54e2e8", "flicker": true},
    "canopy": {"radius": 5.5, "strength": 0.84, "color": "fff0bd", "flicker": false},
    "fluorescent": {"radius": 4.4, "strength": 0.72, "color": "b8eadf", "flicker": true},
    "warm": {"radius": 3.8, "strength": 0.64, "color": "ffc46f", "flicker": false},
    "security": {"radius": 4.6, "strength": 0.74, "color": "a9caff", "flicker": false},
    "flood": {"radius": 6.2, "strength": 0.88, "color": "eef2d8", "flicker": false},
    "warning_red": {"radius": 3.4, "strength": 0.62, "color": "ff5b48", "flicker": true},
}

static func ambient_level(theme: String) -> float:
    var profile: Dictionary = AMBIENT_BY_THEME.get(theme, AMBIENT_BY_THEME["alley"])
    return float(profile.get("level", 0.12))

static func ambient_tint(theme: String) -> Color:
    var profile: Dictionary = AMBIENT_BY_THEME.get(theme, AMBIENT_BY_THEME["alley"])
    return Color(str(profile.get("tint", "0b1120")))

static func make_source(pos: Vector2i, kind: String, seed_value: int = 0) -> Dictionary:
    var preset: Dictionary = SOURCE_PRESETS.get(kind, SOURCE_PRESETS["security"])
    return {
        "pos": pos,
        "kind": kind,
        "radius": float(preset.get("radius", 4.0)),
        "strength": float(preset.get("strength", 0.7)),
        "color": str(preset.get("color", "ffffff")),
        "flicker": bool(preset.get("flicker", false)),
        "seed": seed_value,
    }

static func radial_contribution(cell: Vector2i, source: Dictionary) -> float:
    var source_pos: Vector2i = source.get("pos", Vector2i(-99, -99))
    var radius: float = maxf(0.1, float(source.get("radius", 4.0)))
    var distance: float = Vector2(cell - source_pos).length()
    if distance > radius:
        return 0.0
    var falloff: float = 1.0 - distance / radius
    return clampf(float(source.get("strength", 0.7)) * pow(falloff, 0.72), 0.0, 1.0)

static func item_emits_light(item_name: String) -> bool:
    if item_name == "" or not D.GEAR.has(item_name):
        return false
    return str(D.GEAR[item_name].get("light", "")) != ""

static func secondary_item_from_equipment(equipment: Dictionary) -> String:
    var secondary: String = str(equipment.get("Secondary", ""))
    if secondary != "":
        return secondary
    # Schema-4 compatibility: Flashlight used to occupy Tool. Do not mutate the
    # save just to preserve an already-equipped Alpha flashlight.
    var legacy_tool: String = str(equipment.get("Tool", ""))
    if item_emits_light(legacy_tool):
        return legacy_tool
    return ""

static func item_view_bonus(item_name: String) -> int:
    if not item_emits_light(item_name):
        return 0
    return int(D.GEAR[item_name].get("view_bonus", 0))

static func item_light_color(item_name: String) -> Color:
    if not item_emits_light(item_name):
        return Color("ffffff")
    return Color(str(D.GEAR[item_name].get("light_color", "edf5d6")))

static func cone_contribution(origin: Vector2i, facing: Vector2i, cell: Vector2i, item_name: String) -> float:
    if not item_emits_light(item_name):
        return 0.0
    var diff := Vector2(cell - origin)
    var distance: float = diff.length()
    if distance <= 0.01:
        return 1.0
    var max_range: float = maxf(1.0, float(D.GEAR[item_name].get("light_range", 9.0)))
    if distance > max_range:
        return 0.0
    var min_dot: float = clampf(float(D.GEAR[item_name].get("light_spread", 0.52)), -1.0, 0.99)
    var dot: float = Vector2(facing).normalized().dot(diff.normalized())
    if dot < min_dot:
        return 0.0
    var cone_factor: float = clampf((dot - min_dot) / (1.0 - min_dot), 0.0, 1.0)
    var range_factor: float = clampf(1.0 - distance / max_range, 0.0, 1.0)
    var strength: float = float(D.GEAR[item_name].get("light_strength", 1.0))
    return clampf(strength * (0.28 + cone_factor * 0.72) * (0.34 + range_factor * 0.66), 0.0, 1.0)

static func darkness_alpha(light_level: float) -> float:
    return clampf(0.88 - clampf(light_level, 0.0, 1.0) * 0.76, 0.08, 0.84)

static func color_wash_alpha(light_level: float) -> float:
    return clampf((clampf(light_level, 0.0, 1.0) - 0.20) * 0.17, 0.0, 0.13)

static func has_animated_sources(sources: Array) -> bool:
    for source_value in sources:
        var source: Dictionary = source_value
        if bool(source.get("flicker", false)):
            return true
    return false

static func visual_strength(source: Dictionary, now_ms: int) -> float:
    var strength: float = float(source.get("strength", 0.7))
    if not bool(source.get("flicker", false)):
        return strength
    var seed_value: int = int(source.get("seed", 0))
    var phase: float = float(now_ms + seed_value * 83) / 180.0
    var pulse: float = 0.90 + sin(phase) * 0.10
    var bucket: int = int(now_ms / 140) + seed_value * 17
    var dip: float = 0.48 if posmod(bucket, 17) == 0 else 1.0
    return clampf(strength * pulse * dip, 0.0, 1.0)
