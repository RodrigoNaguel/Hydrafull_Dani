(:glance, :background)
class AppConfig {
    static const WATER_STEP_ML = 250;
    static const CAFFEINE_STEP_MG = 80;
    // Onboarding heuristic, not a clinical requirement.
    // 35ml/kg is the sports-science baseline for active individuals;
    // sedentary adults sit closer to 30ml/kg.
    static const BASE_WATER_ML_PER_KG = 35.0;
    static const BASE_WATER_MIN_ML = 1800.0;
    // No hard cap on the activity-adjusted target; HydrationCalculator
    // applies its own ceiling via clamp after adding sweat losses.
    static const BASE_WATER_MAX_ML = 5000.0;
    static const DEFAULT_WEIGHT_KG = 70.0;
    static const DEFAULT_CAFFEINE_HALF_LIFE_HOURS = 5.0;
    static const DAILY_CAFFEINE_WARNING_MG = 400;
    static const SINGLE_CAFFEINE_WARNING_MG = 200;
    static const DEFAULT_SWEAT_RATE_L_H = 0.7;
    static const DEFAULT_SWEAT_RATE_LOW_L_H = 0.4;
    static const DEFAULT_SWEAT_RATE_HIGH_L_H = 1.0;
    static const REMINDER_WINDOW_START_HOUR = 8;
    static const REMINDER_WINDOW_END_HOUR = 22;
    static const REMINDER_WINDOW_END_MINUTE = 30;
    // High enough that the smart deficit + projection logic can send
    // catch-up reminders without hitting the daily cap prematurely.
    static const REMINDER_MAX_DAILY_REMINDERS = 10;
    static const REMINDER_CHECK_INTERVAL_SEC = 15 * 60;
    static const WELLNESS_SNAPSHOT_INTERVAL_SEC = 60 * 60;
    static const REMINDER_MIN_WATER_FOR_QUIET_ML = 200;
    static const REMINDER_AFTER_WATER_SEC = 45 * 60;
    static const REMINDER_DEFICIT_LEVEL1_ML = 200;
    static const REMINDER_DEFICIT_LEVEL2_ML = 450;
    static const REMINDER_DEFICIT_LEVEL3_ML = 800;
    static const REMINDER_ESCALATION_COOLDOWN_SEC = 30 * 60;
    static const REMINDER_REPEAT_LEVEL1_SEC = 60 * 60;
    static const REMINDER_REPEAT_LEVEL2_SEC = 45 * 60;
    static const REMINDER_REPEAT_LEVEL3_SEC = 30 * 60;
    // Estimated sweat concentration is distinct from beverage concentration.
    static const DEFAULT_SWEAT_SODIUM_MG_PER_LITER = 920.0;
    static const DEFAULT_SWEAT_POTASSIUM_MG_PER_LITER = 156.0;
    static const BEVERAGE_SODIUM_LOW_MG_PER_LITER = 500.0;
    static const BEVERAGE_SODIUM_HIGH_MG_PER_LITER = 700.0;
}
