extends RefCounted

# Resolve one simultaneous movement beat from an immutable occupancy snapshot.
# Destination contention rotates fairly by turn. Convoys may enter cells vacated
# in this beat; head-on swaps and moves into stationary occupants are rejected.
static func resolve_moves(positions: Dictionary, proposals: Dictionary, priority: int) -> Dictionary:
    var occupancy := {}
    for id in positions: occupancy[positions[id]] = id
    var ids: Array = positions.keys()
    ids.sort()
    var moves := {}
    var claimed := {}
    for offset in range(ids.size()):
        var id = ids[(offset + posmod(priority, maxi(1, ids.size()))) % ids.size()]
        if not proposals.has(id): continue
        var destination: Vector2i = proposals[id]
        if destination == positions[id] or claimed.has(destination): continue
        claimed[destination] = id
        moves[id] = destination
    var changed := true
    while changed:
        changed = false
        for id in moves.keys():
            var occupant = occupancy.get(moves[id], -1)
            if occupant == -1: continue
            if not moves.has(occupant) or moves[occupant] == positions[id]:
                moves.erase(id)
                changed = true
    return moves
