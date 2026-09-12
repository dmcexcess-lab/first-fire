extends RefCounted
class_name FFVirusRules

const STAGE_CLEAR := "Clear"
const STAGE_EXPOSED := "Exposed"
const STAGE_INFECTED := "Infected"
const STAGE_FEVERISH := "Feverish"
const STAGES := [STAGE_CLEAR, STAGE_EXPOSED, STAGE_INFECTED, STAGE_FEVERISH]
const EXPOSED_NATURAL_CLEAR_CHANCE := 0.30

static func default_state() -> Dictionary:
    return {"stage": STAGE_CLEAR, "days": 0, "quarantined": false}

static func normalize(value) -> Dictionary:
    var result := default_state()
    var incoming: Dictionary = value.duplicate(true) if value is Dictionary else {}
    var stage_name := str(incoming.get("stage", STAGE_CLEAR))
    if not STAGES.has(stage_name):
        stage_name = STAGE_CLEAR
    result["stage"] = stage_name
    result["days"] = maxi(0, int(incoming.get("days", 0)))
    result["quarantined"] = bool(incoming.get("quarantined", false)) if stage_name != STAGE_CLEAR else false
    return result

static func stage(value) -> String:
    return str(normalize(value).get("stage", STAGE_CLEAR))

static func is_active(value) -> bool:
    return stage(value) != STAGE_CLEAR

static func is_severe(value) -> bool:
    return stage(value) == STAGE_FEVERISH

static func exposure_chance(infected_hits: int) -> float:
    if infected_hits <= 0:
        return 0.0
    return clampf(0.18 + float(infected_hits - 1) * 0.12, 0.18, 0.54)

static func expose(value) -> Dictionary:
    var state := normalize(value)
    if str(state["stage"]) == STAGE_CLEAR:
        state["stage"] = STAGE_EXPOSED
        state["days"] = 0
        state["quarantined"] = false
    return state

static func progress_day(value, rng: RandomNumberGenerator) -> Dictionary:
    var state := normalize(value)
    var event := ""
    match str(state["stage"]):
        STAGE_EXPOSED:
            state["days"] = int(state["days"]) + 1
            if rng.randf() < EXPOSED_NATURAL_CLEAR_CHANCE:
                state = default_state()
                event = "cleared"
            else:
                state["stage"] = STAGE_INFECTED
                state["days"] = 0
                event = "infected"
        STAGE_INFECTED:
            state["days"] = int(state["days"]) + 1
            if int(state["days"]) >= 1:
                state["stage"] = STAGE_FEVERISH
                state["days"] = 0
                event = "feverish"
        STAGE_FEVERISH:
            state["days"] = int(state["days"]) + 1
            if int(state["days"]) >= 1:
                event = "terminal"
    return {"state": state, "event": event}

static func spread_chance(value) -> float:
    var state := normalize(value)
    if bool(state["quarantined"]):
        return 0.0
    match str(state["stage"]):
        STAGE_INFECTED: return 0.06
        STAGE_FEVERISH: return 0.18
        _: return 0.0

static func treatment_plan(stage_name: String, has_infirmary: bool) -> Dictionary:
    match stage_name:
        STAGE_EXPOSED:
            return {
                "available": true,
                "id": "decontaminate",
                "label": "Exposure decontamination",
                "duration": 20.0,
                "resources": {"Clean Water": 1},
                "components": {"Sterile Dressing": 1},
                "summary": "1 Clean Water + 1 Sterile Dressing",
            }
        STAGE_INFECTED:
            return {
                "available": true,
                "id": "medicine_course",
                "label": "Zombie-virus medicine course",
                "duration": 60.0,
                "resources": {"Medicine": 1},
                "components": {},
                "summary": "1 Medicine",
            }
        STAGE_FEVERISH:
            if not has_infirmary:
                return {
                    "available": false,
                    "reason": "Feverish zombie-virus cases need an Infirmary and 2 Medicine.",
                    "summary": "Infirmary + 2 Medicine",
                }
            return {
                "available": true,
                "id": "emergency_course",
                "label": "Emergency zombie-virus treatment",
                "duration": 90.0,
                "resources": {"Medicine": 2},
                "components": {},
                "summary": "2 Medicine in the Infirmary",
            }
        _:
            return {"available": false, "reason": "No zombie-virus treatment is needed.", "summary": "None"}
