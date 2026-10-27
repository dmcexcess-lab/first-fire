extends RefCounted

const ACTIONS_PER_TURN := 2

static func movement_range(mode: String) -> int:
    match mode:
        "crouch": return 3
        "sprint": return 8
        _: return 5

static func movement_cost(mode: String) -> int:
    return 2 if mode == "sprint" else 1
