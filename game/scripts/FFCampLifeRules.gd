extends RefCounted
class_name FFCampLifeRules

# Camp-life tuning belongs here so Alpha 0.5 social autonomy and Alpha 0.6 pets
# can build on the same simulation cadence instead of hiding rules in UI code.
const CAMP_EVENT_INTERVAL := 45.0
const NEW_GAME_EVENT_COOLDOWN := 20.0
const FATIGUE_GAIN_MULTIPLIER := 2.0

static func fatigue_gain(base_amount: float) -> float:
    return maxf(0.0, base_amount) * FATIGUE_GAIN_MULTIPLIER

static func idle_recovery_rates(has_cabin: bool, caretaker_leader: bool) -> Vector2:
    var fatigue_rate: float = 0.5 if has_cabin else (1.0 / 3.0)
    var stress_rate: float = (1.0 / 6.0) if has_cabin else 0.1
    if caretaker_leader:
        fatigue_rate *= 1.2
        stress_rate *= 1.2
    return Vector2(fatigue_rate, stress_rate)
