extends RefCounted

# Real-time raid tuning. Existing tactical action costs remain the common
# timing unit, but the world clock now advances independently of input.
const TICKS_PER_SECOND := 100.0
const STEP_SECONDS := 0.05
const EXTRACTION_SECONDS := 3.0
const REARM_SCRAP_COST := 1
const SPARE_MAGAZINES := 2
const Weapons = preload("res://scripts/FFThreeStatRules.gd")

static func weapon_state(weapon_name: String, saved: Dictionary = {}) -> Dictionary:
    var capacity := Weapons.weapon_mag_capacity(Weapons.weapon_profile(weapon_name))
    if capacity <= 0:
        return {}
    return {
        "loaded": clampi(int(saved.get("loaded", capacity)), 0, capacity),
        "reserve": clampi(int(saved.get("reserve", capacity * SPARE_MAGAZINES)), 0, capacity * SPARE_MAGAZINES),
        "needs_pump": bool(saved.get("needs_pump", false)),
    }

static func reload_state(weapon_name: String, saved: Dictionary) -> Dictionary:
    var state := weapon_state(weapon_name, saved)
    if state.is_empty():
        return state
    var capacity := Weapons.weapon_mag_capacity(Weapons.weapon_profile(weapon_name))
    var transfer := mini(capacity - int(state.loaded), int(state.reserve))
    state.loaded = int(state.loaded) + transfer
    state.reserve = int(state.reserve) - transfer
    return state

static func extraction_progress(previous: float, seconds: float, at_exit: bool, escort_ready: bool) -> float:
    if not at_exit or not escort_ready:
        return 0.0
    return minf(EXTRACTION_SECONDS, previous + maxf(0.0, seconds))
