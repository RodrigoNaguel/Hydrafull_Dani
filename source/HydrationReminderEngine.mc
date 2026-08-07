import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

class HydrationReminderEngine {
    static function evaluateAndNotify() {
        HydrationStore.ensureToday();

        if (!NotificationManager.notificationsSupported()) {
            return;
        }

        var now = Time.now();
        var nowValue = now.value();
        if (!HydrationReminderEngine.isWithinNotificationWindow(now)) {
            return;
        }

        if (HydrationReminderEngine.isQuietPeriodActive(nowValue)) {
            return;
        }

        var weightKg = WellnessReader.weightKg();
        var totalCalories = HydrationStore.getNumber("lastCalories");
        var targetMl = HydrationCalculator.adjustedWaterMl(weightKg, totalCalories).toNumber();
        var waterMl = HydrationStore.getNumber("waterMl");

        if (targetMl <= 0) {
            return;
        }

        if (waterMl >= targetMl) {
            HydrationReminderEngine.showGoalCelebrationIfNeeded(nowValue);
            return;
        }

        var expectedMl = HydrationReminderEngine.expectedProgressMl(now, targetMl);
        if (expectedMl <= 0) {
            return;
        }

        var deficitMl = expectedMl - waterMl;
        if (deficitMl <= 0) {
            return;
        }

        var currentLevel = HydrationReminderEngine.reminderLevel(deficitMl);
        if (currentLevel == 0) {
            return;
        }

        if (!HydrationReminderEngine.canShowReminder(nowValue, currentLevel)) {
            return;
        }

        if (HydrationReminderEngine.remindersToday() >= AppConfig.REMINDER_MAX_DAILY_REMINDERS) {
            return;
        }

        var message = HydrationReminderEngine.selectMessage(currentLevel);
        NotificationManager.notifyReminder(message);
        HydrationReminderEngine.recordReminder(nowValue, currentLevel);
    }

    private static function showGoalCelebrationIfNeeded(nowValue) {
        if (HydrationReminderEngine.hasGoalCelebrationShown()) {
            return;
        }
        var message = HydrationReminderEngine.selectCelebrationMessage();
        NotificationManager.notifyCelebration(message);
        Storage.setValue("hydrationReminder.goalCelebrationShown", true);
        Storage.setValue("hydrationReminder.lastReminderTime", nowValue);
        Storage.setValue("hydrationReminder.lastReminderLevel", 0);
    }

    private static function isWithinNotificationWindow(now) {
        var local = Gregorian.info(now, Time.FORMAT_SHORT);
        var minutes = local.hour * 60 + local.min;
        var start = AppConfig.REMINDER_WINDOW_START_HOUR * 60;
        var end = AppConfig.REMINDER_WINDOW_END_HOUR * 60 + AppConfig.REMINDER_WINDOW_END_MINUTE;
        return (minutes >= start) && (minutes <= end);
    }

    private static function expectedProgressMl(now, targetMl) {
        var local = Gregorian.info(now, Time.FORMAT_SHORT);
        var currentMinutes = local.hour * 60 + local.min;
        var start = AppConfig.REMINDER_WINDOW_START_HOUR * 60;
        var end = AppConfig.REMINDER_WINDOW_END_HOUR * 60 + AppConfig.REMINDER_WINDOW_END_MINUTE;
        if (currentMinutes <= start) {
            return 0.0;
        }
        if (currentMinutes >= end) {
            return targetMl;
        }
        var elapsed = currentMinutes - start;
        var total = end - start;
        return targetMl * (elapsed.toFloat() / total.toFloat());
    }

    private static function reminderLevel(deficitMl) {
        if (deficitMl < 200) {
            return 0;
        }
        if (deficitMl < 500) {
            return 1;
        }
        if (deficitMl < 900) {
            return 2;
        }
        return 3;
    }

    private static function canShowReminder(nowValue, currentLevel) {
        var quietUntil = HydrationReminderEngine.getNumberValue("hydrationReminder.quietUntil");
        if (quietUntil > nowValue) {
            return false;
        }

        var lastReminderTime = HydrationReminderEngine.getNumberValue("hydrationReminder.lastReminderTime");
        var cooldown = HydrationReminderEngine.cooldownSeconds(currentLevel);
        if ((nowValue - lastReminderTime) < cooldown) {
            return false;
        }

        return true;
    }

    private static function cooldownSeconds(level) {
        if (level == 1) {
            return AppConfig.REMINDER_COOLDOWN_LEVEL1_SEC;
        }
        if (level == 2) {
            return AppConfig.REMINDER_COOLDOWN_LEVEL2_SEC;
        }
        return AppConfig.REMINDER_COOLDOWN_LEVEL3_SEC;
    }

    private static function selectMessage(level) {
        var messages = PersonalMessages.reminderMessages(level) as Array<String>;
        var lastText = HydrationReminderEngine.getStringValue("hydrationReminder.lastMessageText");
        var count = messages.size();
        if (count == 0) {
            return "Amor, um golinho de água 💧";
        }
        var nextIndex = HydrationReminderEngine.getNumberValue("hydrationReminder.lastMessageIndex") + 1;
        nextIndex = nextIndex % count;
        if (nextIndex < 0) { nextIndex = 0; }

        if (messages[nextIndex].equals(lastText)) {
            nextIndex = (nextIndex + 1) % count;
        }

        var message = messages[nextIndex];
        Storage.setValue("hydrationReminder.lastMessageText", message);
        Storage.setValue("hydrationReminder.lastMessageIndex", nextIndex);
        return message;
    }

    private static function selectCelebrationMessage() {
        var messages = PersonalMessages.celebrationMessages() as Array<String>;
        var lastText = HydrationReminderEngine.getStringValue("hydrationReminder.lastMessageText");
        var count = messages.size();
        if (count == 0) {
            return "Boa, amor! Meta do dia atingida!";
        }
        var nextIndex = HydrationReminderEngine.getNumberValue("hydrationReminder.lastMessageIndex") + 1;
        nextIndex = nextIndex % count;
        if (nextIndex < 0) { nextIndex = 0; }

        if (messages[nextIndex].equals(lastText)) {
            nextIndex = (nextIndex + 1) % count;
        }

        var message = messages[nextIndex];
        Storage.setValue("hydrationReminder.lastMessageText", message);
        Storage.setValue("hydrationReminder.lastMessageIndex", nextIndex);
        return message;
    }

    private static function recordReminder(nowValue, level) {
        Storage.setValue("hydrationReminder.lastReminderTime", nowValue);
        Storage.setValue("hydrationReminder.lastReminderLevel", level);
        Storage.setValue("hydrationReminder.remindersToday", HydrationReminderEngine.remindersToday() + 1);
    }

    private static function remindersToday() {
        return HydrationReminderEngine.getNumberValue("hydrationReminder.remindersToday");
    }

    private static function hasGoalCelebrationShown() {
        var value = Storage.getValue("hydrationReminder.goalCelebrationShown");
        return value instanceof Lang.Boolean ? value : false;
    }

    private static function isQuietPeriodActive(nowValue) {
        return HydrationReminderEngine.getNumberValue("hydrationReminder.quietUntil") > nowValue;
    }

    private static function getNumberValue(key) {
        var value = Storage.getValue(key);
        return value instanceof Lang.Number ? value : 0;
    }

    private static function getStringValue(key) {
        var value = Storage.getValue(key);
        return value instanceof Lang.String ? value : "";
    }
}
