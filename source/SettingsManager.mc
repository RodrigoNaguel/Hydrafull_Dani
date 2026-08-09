import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;

(:glance, :background)
class SettingsManager {
    static function notificationsEnabled() {
        return SettingsManager.getBoolean("notifications_enabled", true);
    }

    static function setNotificationsEnabled(enabled as Boolean) {
        SettingsManager.setBoolean("notifications_enabled", enabled);
    }

    static function remindersEnabled() {
        return SettingsManager.getBoolean("reminders_enabled", true);
    }

    static function setRemindersEnabled(enabled as Boolean) {
        SettingsManager.setBoolean("reminders_enabled", enabled);
    }

    static function quickAddMl() {
        var value = SettingsManager.getNumber("quick_add_ml", AppConfig.WATER_STEP_ML);
        if (value <= 0) { return AppConfig.WATER_STEP_ML; }
        return value;
    }

    static function setQuickAddMl(amount as Number) {
        SettingsManager.setNumber("quick_add_ml", amount);
    }

    private static function getBoolean(key as String, defaultValue as Boolean) as Boolean {
        try {
            var value = Properties.getValue(key);
            return value instanceof Lang.Boolean ? value : defaultValue;
        } catch (error) {
            System.println("[HydraFuel] SettingsManager getBoolean(" + key + ") error: " + error);
            return defaultValue;
        }
    }

    private static function getNumber(key as String, defaultValue as Number) as Number {
        try {
            var value = Properties.getValue(key);
            if (value instanceof Lang.Number) { return value; }
            if (value instanceof Lang.Long) { return value.toNumber(); }
            return defaultValue;
        } catch (error) {
            System.println("[HydraFuel] SettingsManager getNumber(" + key + ") error: " + error);
            return defaultValue;
        }
    }

    private static function setBoolean(key as String, value as Boolean) {
        try {
            Properties.setValue(key, value);
        } catch (error) {
            System.println("[HydraFuel] SettingsManager setBoolean(" + key + ") error: " + error);
        }
    }

    private static function setNumber(key as String, value as Number) {
        try {
            Properties.setValue(key, value);
        } catch (error) {
            System.println("[HydraFuel] SettingsManager setNumber(" + key + ") error: " + error);
        }
    }
}
