extends RefCounted
class_name FFVirusRules

const STAGE_CLEAR := "Clear"
const STAGE_EXPOSED := "Exposed"
const STAGE_INFECTED := "Infected"
const STAGE_FEVERISH := "Feverish"
const STAGES := [STAGE_CLEAR, STAGE_EXPOSED, STAGE_INFECTED, STAGE_FEVERISH]

const BITE_EXPOSURE_CHANCE := 0.03
const UNQUARANTINED_TURN_DAYS_MIN := 1
const UNQUARANTINED_TURN_DAYS_MAX := 2
const QUARANTINED_TURN_DAYS_MIN := 3
const QUARANTINED_TURN_DAYS_MAX := 4
const AMPUTATION_RECOVERY_SECONDS := 100.0

static func default_state() -> Dictionary:
    return {
        "stage": STAGE_CLEAR,
        "days": 0,
        "quarantined": false,
        "turn_days": 0,
    }

static func normalize(value) -> Dictionary:
    var incoming: Dictionary = value.duplicate(true) if value is Dictionary else {}
    var stage_name := str(incoming.get("stage", STAGE_CLEAR))
    if not STAGES.has(stage_name):
        stage_name = STAGE_CLEAR
    if stage_name == STAGE_CLEAR:
        return default_state()

    var result := default_state()
    result["stage"] = stage_name
    result["days"] = maxi(0, int(incoming.get("days", 0)))
    result["quarantined"] = bool(incoming.get("quarantined", false))
    var fallback_turn_days := QUARANTINED_TURN_DAYS_MAX if bool(result["quarantined"]) else UNQUARANTINED_TURN_DAYS_MAX
    result["turn_days"] = maxi(int(result["days"]) + 1, int(incoming.get("turn_days", fallback_turn_days)))
    return result

static func stage(value) -> String:
    return str(normalize(value).get("stage", STAGE_CLEAR))

static func is_active(value) -> bool:
    return stage(value) != STAGE_CLEAR

static func is_severe(value) -> bool:
    return stage(value) == STAGE_FEVERISH

static func bite_exposure_chance() -> float:
    return BITE_EXPOSURE_CHANCE

static func bite_exposure_occurs(successful_bites: int, rng: RandomNumberGenerator) -> bool:
    for _bite in range(maxi(0, successful_bites)):
        if rng.randf() < BITE_EXPOSURE_CHANCE:
            return true
    return false

static func exposure_chance(infected_hits: int) -> float:
    return BITE_EXPOSURE_CHANCE if infected_hits > 0 else 0.0

static func roll_turn_days(quarantined: bool, rng: RandomNumberGenerator) -> int:
    if quarantined:
        return rng.randi_range(QUARANTINED_TURN_DAYS_MIN, QUARANTINED_TURN_DAYS_MAX)
    return rng.randi_range(UNQUARANTINED_TURN_DAYS_MIN, UNQUARANTINED_TURN_DAYS_MAX)

static func expose(value, turn_days: int = UNQUARANTINED_TURN_DAYS_MAX) -> Dictionary:
    var state := normalize(value)
    if str(state["stage"]) == STAGE_CLEAR:
        state["stage"] = STAGE_EXPOSED
        state["days"] = 0
        state["quarantined"] = false
        state["turn_days"] = clampi(turn_days, UNQUARANTINED_TURN_DAYS_MIN, UNQUARANTINED_TURN_DAYS_MAX)
    return state

static func quarantine(value, additional_days: int) -> Dictionary:
    var state := normalize(value)
    if str(state["stage"]) == STAGE_CLEAR:
        return state
    state["quarantined"] = true
    state["turn_days"] = int(state["days"]) + clampi(additional_days, QUARANTINED_TURN_DAYS_MIN, QUARANTINED_TURN_DAYS_MAX)
    return state

static func days_until_turn(value) -> int:
    var state := normalize(value)
    if str(state["stage"]) == STAGE_CLEAR:
        return 0
    return maxi(0, int(state["turn_days"]) - int(state["days"]))

static func can_amputate(value, amputation_used: bool) -> bool:
    var state := normalize(value)
    return (
        not amputation_used
        and str(state["stage"]) == STAGE_EXPOSED
        and int(state["days"]) == 0
        and not bool(state["quarantined"])
    )

static func cure(value) -> Dictionary:
    if is_active(value):
        return default_state()
    return normalize(value)

static func progress_day(value) -> Dictionary:
    var state := normalize(value)
    if str(state["stage"]) == STAGE_CLEAR:
        return {"state": state, "event": ""}

    var previous_stage := str(state["stage"])
    state["days"] = int(state["days"]) + 1
    if int(state["days"]) >= int(state["turn_days"]):
        state["stage"] = STAGE_FEVERISH
        return {"state": state, "event": "terminal"}

    if int(state["days"]) >= int(state["turn_days"]) - 1:
        state["stage"] = STAGE_FEVERISH
    else:
        state["stage"] = STAGE_INFECTED

    var event := ""
    if str(state["stage"]) != previous_stage:
        event = "feverish" if str(state["stage"]) == STAGE_FEVERISH else "infected"
    return {"state": state, "event": event}
