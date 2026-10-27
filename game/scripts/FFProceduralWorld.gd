extends RefCounted

# Seeded raid geography. Each raid owns its seed/type; an active save rebuilds
# exactly the same geometry, while the next launch gets a fresh seed.
const Places = preload("res://scripts/FFTacticalEnvironments.gd")
const CELL_W := 20
const CELL_H := 18
const TYPES := ["country", "suburbs", "city"]
const PROFILES := {
    "country": {"name": "Country", "density": "SPARSE ZOMBIES", "ground": "grass", "occupancy": 0.40, "infected_per_plot": 2, "places": ["house", "drainage_wash", "warehouse_yard", "gas_station"]},
    "suburbs": {"name": "Suburbs", "density": "MIXED DENSITY", "ground": "grass", "occupancy": 0.78, "infected_per_plot": 4, "places": ["house", "house", "house", "corner_store", "gas_station", "apartment"]},
    "city": {"name": "City", "density": "DENSE CROWDS", "ground": "sidewalk", "occupancy": 0.98, "infected_per_plot": 7, "places": ["apartment", "apartment", "corner_store", "back_alley", "warehouse_yard"]},
}

static func profile(map_type: String) -> Dictionary:
    return PROFILES.get(map_type, PROFILES.suburbs)

static func build(seed_value: int, map_type: String) -> Dictionary:
    var random := RandomNumberGenerator.new()
    random.seed = seed_value
    var config := profile(map_type)
    var cols := random.randi_range(4, 5)
    var rows := random.randi_range(4, 5)
    var width := cols * CELL_W
    var height := rows * CELL_H
    var spec := {"width": width, "height": height, "default_ground": str(config.ground), "ground_rects": [], "indoor_rects": [], "walls": [], "obstacles": [], "glass": [], "doors": [], "barrels": [], "props": [], "lights": [], "loot_containers": [], "exit_cells": [], "plot_types": [], "population": cols * rows * int(config.infected_per_plot)}
    # A connected road/track lattice bounds each randomized plot. Buildings
    # never close these corridors, so no random key can invalidate extraction.
    var road := "dirt" if map_type == "country" else "road"
    for row in range(rows):
        spec.ground_rects.append([0, row * CELL_H, width, 2, road])
        spec.ground_rects.append([0, (row + 1) * CELL_H - 2, width, 2, road])
    for col in range(cols):
        spec.ground_rects.append([col * CELL_W, 0, 2, height, road])
        spec.ground_rects.append([(col + 1) * CELL_W - 2, 0, 2, height, road])
    for row in range(rows):
        for col in range(cols):
            var offset := Vector2i(col * CELL_W, row * CELL_H)
            if random.randf() > float(config.occupancy):
                spec.plot_types.append("field" if map_type == "country" else "vacant_lot")
                for _i in range(random.randi_range(3, 8)):
                    var cell := offset + Vector2i(random.randi_range(4, 15), random.randi_range(4, 13))
                    spec.props.append([cell, "scrub"])
                    spec.loot_containers.append([cell, "debris"])
                continue
            var pool: Array = config.places
            var place_id := str(pool[random.randi_range(0, pool.size() - 1)])
            spec.plot_types.append(place_id)
            var place: Dictionary = Places.build_layout(place_id, random.randi())
            var mirror_x := random.randf() < 0.5
            var mirror_y := random.randf() < 0.5
            for key in ["ground_rects", "indoor_rects"]:
                for value in place.get(key, []):
                    var rect: Array = value.duplicate(true)
                    if mirror_x: rect[0] = CELL_W - int(rect[0]) - int(rect[2])
                    if mirror_y: rect[1] = CELL_H - int(rect[1]) - int(rect[3])
                    rect[0] += offset.x
                    rect[1] += offset.y
                    spec[key].append(rect)
            for key in ["walls", "obstacles", "glass", "barrels"]:
                for cell in place.get(key, []):
                    var mapped := _mirror(cell, mirror_x, mirror_y)
                    if not _corridor(mapped): spec[key].append(mapped + offset)
            for key in ["doors", "props", "lights", "loot_containers"]:
                for value in place.get(key, []):
                    var item: Array = value.duplicate(true)
                    var mapped := _mirror(item[0], mirror_x, mirror_y)
                    if _corridor(mapped): continue
                    item[0] = mapped + offset
                    spec[key].append(item)
    var entry := Vector2i(random.randi_range(2, width - 3), height - 2)
    spec.player_spawn = entry
    spec.ally_spawn = entry + Vector2i.LEFT
    var candidates: Array = []
    # Exits can be at roadsides or inner crossroads, not just map corners.
    for row in range(rows):
        for col in range(cols):
            candidates.append(Vector2i(col * CELL_W + 1, row * CELL_H + 1))
    for _i in range(8):
        candidates.append(Vector2i(random.randi_range(2, width - 3), 1))
        candidates.append(Vector2i(1 if random.randf() < 0.5 else width - 2, random.randi_range(2, height - 3)))
    var target := random.randi_range(4, 7)
    while spec.exit_cells.size() < target and not candidates.is_empty():
        var cell: Vector2i = candidates.pop_at(random.randi_range(0, candidates.size() - 1))
        if _distance(cell, entry) < 12: continue
        var separated := true
        for other in spec.exit_cells:
            if _distance(cell, other) < 14: separated = false
        if separated: spec.exit_cells.append(cell)
    # Large candidates lattice guarantees enough separated points; retain a
    # fallback for future geography changes rather than generating no exit.
    if spec.exit_cells.is_empty(): spec.exit_cells.append(Vector2i(1, 1))
    return spec

static func _mirror(cell: Vector2i, flip_x: bool, flip_y: bool) -> Vector2i:
    return Vector2i(CELL_W - 1 - cell.x if flip_x else cell.x, CELL_H - 1 - cell.y if flip_y else cell.y)

static func _corridor(cell: Vector2i) -> bool:
    return cell.x <= 1 or cell.x >= CELL_W - 2 or cell.y <= 1 or cell.y >= CELL_H - 2

static func _distance(a: Vector2i, b: Vector2i) -> int:
    return absi(a.x - b.x) + absi(a.y - b.y)

static func depth(cell: Vector2i, entry: Vector2i, width: int, height: int) -> int:
    var reach := maxi(entry.x, width - 1 - entry.x) + maxi(entry.y, height - 1 - entry.y)
    return clampi(int(float(_distance(cell, entry)) * 3.0 / float(maxi(1, reach))), 0, 2)
