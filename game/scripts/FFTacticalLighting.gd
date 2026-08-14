extends RefCounted
class_name FFTacticalLighting

const D = preload("res://scripts/FFData.gd")

const NIGHT_AMBIENT_BY_THEME := {
    "alley": {"level": 0.10, "tint": "081020"},
    "gas": {"level": 0.11, "tint": "0a1020"},
    "house": {"level": 0.07, "tint": "120d16"},
    "apartment": {"level": 0.075, "tint": "09121b"},
    "store": {"level": 0.085, "tint": "091519"},
    "industrial": {"level": 0.065, "tint": "0b1113"},
    "wash": {"level": 0.055, "tint": "07101a"},
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

static func ambient_level(theme: String, time_of_day: String, indoors: bool) -> float:
    if time_of_day == "day":
        return 0.48 if indoors else 0.88
    var profile: Dictionary = NIGHT_AMBIENT_BY_THEME.get(theme, NIGHT_AMBIENT_BY_THEME["alley"])
    var level := float(profile.get("level", 0.08))
    return level * 0.72 if indoors else level

static func ambient_tint(theme: String, time_of_day: String) -> Color:
    if time_of_day == "day":
        return Color("20221f")
    var profile: Dictionary = NIGHT_AMBIENT_BY_THEME.get(theme, NIGHT_AMBIENT_BY_THEME["alley"])
    return Color(str(profile.get("tint", "081020")))

static func make_source(pos: Vector2i, kind: String, seed_value: int = 0, requires_power := true) -> Dictionary:
    var preset: Dictionary = SOURCE_PRESETS.get(kind, SOURCE_PRESETS["security"])
    return {
        "pos": pos,
        "kind": kind,
        "radius": float(preset.get("radius", 4.0)),
        "strength": float(preset.get("strength", 0.7)),
        "color": str(preset.get("color", "ffffff")),
        "flicker": bool(preset.get("flicker", false)),
        "requires_power": requires_power,
        "seed": seed_value,
    }

static func source_active(source: Dictionary, power_on: bool) -> bool:
    return power_on or not bool(source.get("requires_power", true))

static func radial_contribution(cell: Vector2i, source: Dictionary) -> float:
    var source_pos: Vector2i = source.get("pos", Vector2i(-99, -99))
    var radius: float = maxf(0.1, float(source.get("radius", 4.0)))
    var distance: float = Vector2(cell - source_pos).length()
    if distance > radius:
        return 0.0
    var falloff: float = 1.0 - distance / radius
    return clampf(float(source.get("strength", 0.7)) * pow(falloff, 0.72), 0.0, 1.0)

static func window_daylight_contribution(window_pos: Vector2i, cell: Vector2i) -> float:
    var distance := Vector2(cell - window_pos).length()
    if distance > 4.5:
        return 0.0
    return clampf(0.92 * pow(1.0 - distance / 4.5, 0.65), 0.0, 0.92)

static func item_emits_light(item_name: String) -> bool:
    if item_name == "" or not D.GEAR.has(item_name):
        return false
    return str(D.GEAR[item_name].get("light", "")) != ""

static func secondary_item_from_equipment(equipment: Dictionary) -> String:
    return str(equipment.get("Secondary", ""))

static func item_view_bonus(item_name: String) -> int:
    if not item_emits_light(item_name):
        return 0
    return int(D.GEAR[item_name].get("view_bonus", 0))

static func item_light_color(item_name: String) -> Color:
    if not item_emits_light(item_name):
        return Color("ffffff")
    return Color(str(D.GEAR[item_name].get("light_color", "edf5d6")))

static func item_contribution(origin: Vector2i, facing: Vector2i, cell: Vector2i, item_name: String) -> float:
    if not item_emits_light(item_name):
        return 0.0
    var data: Dictionary = D.GEAR[item_name]
    var light_kind := str(data.get("light", "cone"))
    var diff := Vector2(cell - origin)
    var distance: float = diff.length()
    var max_range: float = maxf(1.0, float(data.get("light_range", 8.0)))
    if distance <= 0.01:
        return minf(1.0, float(data.get("light_strength", 1.0)))
    if distance > max_range:
        return 0.0
    var range_factor := clampf(1.0 - distance / max_range, 0.0, 1.0)
    var strength := float(data.get("light_strength", 1.0))
    if light_kind == "radial":
        return clampf(strength * pow(range_factor, 0.72), 0.0, 1.0)
    var min_dot: float = clampf(float(data.get("light_spread", 0.52)), -1.0, 0.99)
    var dot: float = Vector2(facing).normalized().dot(diff.normalized())
    if dot < min_dot:
        return 0.0
    var cone_factor := clampf((dot - min_dot) / (1.0 - min_dot), 0.0, 1.0)
    return clampf(strength * (0.24 + cone_factor * 0.76) * (0.30 + range_factor * 0.70), 0.0, 1.0)

static func visible_at_distance(light_level: float, distance: int, max_range: int) -> bool:
    if distance <= 1:
        return true
    if distance > max_range:
        return false
    var required := 0.11 + float(maxi(0, distance - 2)) * 0.085
    if distance == max_range:
        required += 0.06
    return light_level >= required

static func darkness_alpha(light_level: float) -> float:
    return clampf(0.92 - clampf(light_level, 0.0, 1.0) * 0.86, 0.025, 0.89)

static func color_wash_alpha(light_level: float) -> float:
    return clampf((clampf(light_level, 0.0, 1.0) - 0.18) * 0.20, 0.0, 0.15)

static func has_animated_sources(sources: Array, power_on: bool) -> bool:
    for source_value in sources:
        var source: Dictionary = source_value
        if source_active(source, power_on) and bool(source.get("flicker", false)):
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
