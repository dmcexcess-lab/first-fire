extends RefCounted
class_name FFTacticalSound

static func surface_step_label(ground_kind: String, crouched: bool) -> String:
    if crouched:
        return "soft step"
    match ground_kind:
        "wood": return "creak"
        "tile", "linoleum": return "tap"
        "grass": return "rustle"
        "dirt": return "scuff"
        "wash_concrete", "concrete": return "footstep"
        _: return "steps"

static func zombie_location_error(received_intensity: int) -> int:
    if received_intensity >= 42:
        return 0
    if received_intensity >= 26:
        return 1
    return 2

static func player_location_error(awareness: float, received_intensity: int, distance: int) -> int:
    var error: int = 3
    if awareness >= 3.0:
        error -= 1
    if awareness >= 6.0:
        error -= 1
    if awareness >= 9.0:
        error -= 1
    if received_intensity >= 36:
        error -= 1
    if distance <= 4:
        error -= 1
    return clampi(error, 0, 3)

static func estimate_location(source: Vector2i, listener: Vector2i, max_error: int, rng: RandomNumberGenerator, width: int, height: int) -> Vector2i:
    if max_error <= 0:
        return source
    var candidates: Array = []
    for y in range(source.y - max_error, source.y + max_error + 1):
        for x in range(source.x - max_error, source.x + max_error + 1):
            var p: Vector2i = Vector2i(x, y)
            if p.x < 1 or p.y < 1 or p.x >= width - 1 or p.y >= height - 1:
                continue
            var error_distance: int = absi(p.x - source.x) + absi(p.y - source.y)
            if error_distance <= max_error:
                candidates.append(p)
    if candidates.is_empty():
        return source
    # Prefer estimates close to the real source while retaining a little lateral
    # uncertainty. This prevents the old random-square marker from pointing to a
    # completely unrelated part of the board.
    var weighted: Array = []
    var true_listener_distance: int = absi(source.x - listener.x) + absi(source.y - listener.y)
    for candidate_value in candidates:
        var candidate: Vector2i = candidate_value
        var from_source: int = absi(candidate.x - source.x) + absi(candidate.y - source.y)
        var listener_delta: int = absi(candidate.x - listener.x) + absi(candidate.y - listener.y)
        var weight: int = 5 - from_source
        if listener_delta < true_listener_distance:
            weight += 1
        for i in range(maxi(1, weight)):
            weighted.append(candidate)
    var result: Vector2i = weighted[rng.randi_range(0, weighted.size() - 1)]
    return result

static func display_label(raw_label: String) -> String:
    var label: String = raw_label.strip_edges().to_upper()
    if label.length() <= 16:
        return label
    return label.substr(0, 15) + "…"

static func ambient_profile(theme: String, time_of_day: String, power_on: bool, rng: RandomNumberGenerator) -> Dictionary:
    var options: Array = []
    if power_on:
        options.append({"label": "electric buzz", "intensity": 18})
        if theme in ["gas", "store", "industrial", "apartment"]:
            options.append({"label": "fixture hum", "intensity": 17})
    match theme:
        "alley":
            options.append({"label": "metal rattle", "intensity": 20})
            options.append({"label": "distant clatter", "intensity": 24})
        "house":
            options.append({"label": "house creak", "intensity": 17})
        "apartment":
            options.append({"label": "pipe knock", "intensity": 20})
        "store":
            options.append({"label": "shelf tick", "intensity": 16})
        "industrial":
            options.append({"label": "sheet metal", "intensity": 23})
        "wash":
            options.append({"label": "wind", "intensity": 19})
            options.append({"label": "loose gravel", "intensity": 18})
        "gas":
            options.append({"label": "sign creak", "intensity": 18})
    if time_of_day == "night":
        options.append({"label": "night wind", "intensity": 17})
    if options.is_empty():
        return {}
    var selected: Dictionary = options[rng.randi_range(0, options.size() - 1)]
    return selected
