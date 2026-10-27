extends RefCounted

# Nine connected authored places. Every cell has an open road around its edge,
# so the camp-side exit remains reachable without requiring a random key.
const Places = preload("res://scripts/FFTacticalEnvironments.gd")
const WIDTH := 60
const HEIGHT := 54
const CELL_W := 20
const CELL_H := 18
const EXIT_CELLS := [Vector2i(29, 52), Vector2i(2, 36), Vector2i(57, 19), Vector2i(2, 1)]
# Route IDs and cells are stable across generated town variants and saves.
const ROUTES := [
    {"id": "camp_road", "name": "Camp Road", "cell": Vector2i(29, 52), "starting": true},
    {"id": "west_outskirts", "name": "West Outskirts", "cell": Vector2i(1, 50), "starting": true},
    {"id": "east_outskirts", "name": "East Outskirts", "cell": Vector2i(58, 50), "starting": true},
    {"id": "west_street", "name": "West Street", "cell": Vector2i(2, 36), "starting": false},
    {"id": "east_industrial", "name": "East Industrial", "cell": Vector2i(57, 19), "starting": false},
    {"id": "north_road", "name": "North Road", "cell": Vector2i(2, 1), "starting": false},
]

static func route_by_id(id: String) -> Dictionary:
    for route in ROUTES:
        if route.id == id: return route
    return {}

static func known_routes(discovered: Array) -> Array:
    var known: Array = []
    for route in ROUTES:
        if bool(route.starting) or discovered.has(route.id): known.append(route)
    return known

const LOCATIONS := [
    ["house", "apartment", "warehouse_yard"],
    ["corner_store", "gas_station", "house"],
    ["drainage_wash", "back_alley", "house"],
]

static func build(seed_value: int, entry_id: String = "") -> Dictionary:
    var spec := {"default_ground": "road", "ground_rects": [], "indoor_rects": [], "walls": [], "obstacles": [], "glass": [], "doors": [], "barrels": [], "props": [], "lights": [], "loot_containers": [], "player_spawn": Vector2i(29, 51), "ally_spawn": Vector2i(28, 51), "exit_cells": EXIT_CELLS.duplicate()}
    if entry_id != "":
        var entry := route_by_id(entry_id)
        if not entry.is_empty():
            spec.player_spawn = Vector2i(29, 51) if entry_id == "camp_road" else entry.cell
            spec.ally_spawn = spec.player_spawn + Vector2i(-1, 0)
        spec.exit_cells = []
        for route in ROUTES: spec.exit_cells.append(route.cell)
    for row in range(3):
        for col in range(3):
            var offset := Vector2i(col * CELL_W, row * CELL_H)
            var place: Dictionary = Places.build_layout(LOCATIONS[row][col], seed_value + row * 3 + col)
            spec.ground_rects.append([offset.x, offset.y, CELL_W, CELL_H, str(place.default_ground)])
            for key in ["ground_rects", "indoor_rects"]:
                for item_value in place.get(key, []):
                    var item: Array = item_value.duplicate(true)
                    item[0] += offset.x
                    item[1] += offset.y
                    spec[key].append(item)
            for key in ["walls", "obstacles", "glass", "barrels"]:
                for cell in place.get(key, []):
                    if not _road(cell): spec[key].append(cell + offset)
            for key in ["doors", "props", "lights", "loot_containers"]:
                for entry_value in place.get(key, []):
                    var entry: Array = entry_value.duplicate(true)
                    if _road(entry[0]): continue
                    entry[0] += offset
                    spec[key].append(entry)
    return spec

static func _road(p: Vector2i) -> bool:
    return p.x <= 1 or p.x >= CELL_W - 2 or p.y <= 1 or p.y >= CELL_H - 2

static func depth(cell: Vector2i) -> int:
    return clampi(2 - int(cell.y / CELL_H), 0, 2)
