extends RefCounted
class_name FFCampLifeRules

# Final feature-freeze camp cadence/tuning. Social selection lives in
# FFCampSocial; presentation lives in FFCampView.
const CAMP_EVENT_INTERVAL := 45.0
const NEW_GAME_EVENT_COOLDOWN := 20.0
const FATIGUE_GAIN_MULTIPLIER := 2.0
const CAMP_CHATTER_MIN_SECONDS := 7.0
const CAMP_CHATTER_MAX_SECONDS := 14.0

static func fatigue_gain(base_amount: float) -> float:
    return maxf(0.0, base_amount) * FATIGUE_GAIN_MULTIPLIER

static func idle_recovery_rates(has_cabin: bool, caretaker_leader: bool, has_communal_table: bool = false) -> Vector2:
    var fatigue_rate: float = 0.5 if has_cabin else (1.0 / 3.0)
    var stress_rate: float = (1.0 / 6.0) if has_cabin else 0.1
    if has_communal_table:
        stress_rate *= 1.25
    if caretaker_leader:
        fatigue_rate *= 1.2
        stress_rate *= 1.2
    return Vector2(fatigue_rate, stress_rate)

static func injury_recovery_multiplier(has_infirmary: bool) -> float:
    return 1.45 if has_infirmary else 1.0

static func treatment_time_multiplier(has_infirmary: bool) -> float:
    return 0.72 if has_infirmary else 1.0

static func critical_decline_chance(has_infirmary: bool) -> float:
    return 0.10 if has_infirmary else 0.25

static func rain_catcher_yield(has_water_tank: bool) -> int:
    return 2 if has_water_tank else 1

static func outside_injury_chance(has_noise_line: bool, has_watch_post: bool) -> float:
    if has_noise_line and has_watch_post:
        return 0.02
    if has_watch_post:
        return 0.05
    if has_noise_line:
        return 0.08
    return 0.22
