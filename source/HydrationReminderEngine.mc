import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:background)
class HydrationReminderEngine {
    static function evaluateAndNotify() as String {
        HydrationStore.ensureToday();

        if (!SettingsManager.notificationsEnabled()) {
            return "notifications-off";
        }

        if (!SettingsManager.remindersEnabled()) {
            return "reminders-off";
        }

        if (!NotificationManager.notificationsSupported()) {
            return "api-off";
        }

        var now = Time.now();
        var nowValue = now.value();
        if (!HydrationReminderEngine.isWithinNotificationWindow(now)) {
            return "outside-window";
        }

        var weightKg = WellnessReader.weightKg();
        var totalCalories = HydrationStore.getNumber("lastCalories");
        var targetMl = HydrationCalculator.adjustedWaterMl(weightKg, totalCalories).toNumber();
        var waterMl = HydrationStore.getNumber("waterMl");

        if (targetMl <= 0) {
            return "invalid-target";
        }

        if (waterMl >= targetMl) {
            return HydrationReminderEngine.showGoalCelebrationIfNeeded(
                nowValue);
        }

        if (HydrationReminderEngine.isQuietPeriodActive(nowValue)) {
            return "quiet";
        }

        var expectedMl = HydrationReminderEngine.expectedProgressMl(now, targetMl);
        if (expectedMl <= 0) {
            return "before-start";
        }

        var deficitMl = expectedMl - waterMl;
        if (deficitMl <= 0) {
            return "on-track";
        }

        var currentLevel = HydrationReminderEngine.reminderLevelForDeficit(deficitMl);
        if (currentLevel == 0) {
            return "on-track";
        }

        if (!HydrationReminderEngine.canShowReminder(nowValue, currentLevel)) {
            return "cooldown-L" + currentLevel;
        }

        var lastReminderLevel = HydrationReminderEngine.getNumberValue(
            "hydrationReminder.lastReminderLevel");
        if (currentLevel == lastReminderLevel
                && HydrationReminderEngine.shouldReserveNextLevel(
                    deficitMl, currentLevel, targetMl,
                    HydrationReminderEngine.minutesOfDay(now))) {
            // Avoid a lower-level repeat immediately before the next level;
            // otherwise that repeat would postpone the more relevant alert.
            return "await-L" + (currentLevel + 1);
        }

        if (HydrationReminderEngine.remindersToday()
                >= AppConfig.REMINDER_MAX_DAILY_REMINDERS) {
            return "daily-limit";
        }

        var message = HydrationReminderEngine.selectMessage(currentLevel);
        if (NotificationManager.notifyReminder(message)) {
            HydrationReminderEngine.recordReminder(nowValue, currentLevel);
            HydrationReminderEngine.recordReminderMessageSelection(
                message, currentLevel);
            return "sent-L" + currentLevel;
        }
        return "send-error";
    }

    private static function showGoalCelebrationIfNeeded(nowValue) as String {
        if (HydrationReminderEngine.hasGoalCelebrationShown()) {
            return "goal-reached";
        }
        var message = HydrationReminderEngine.selectCelebrationMessage();
        if (NotificationManager.notifyCelebration(message)) {
            // Mark the goal first so an interrupted secondary write cannot
            // cause the same celebration to be delivered again.
            Storage.setValue("hydrationReminder.goalCelebrationShown", true);
            Storage.setValue("hydrationReminder.lastReminderTime", nowValue);
            Storage.setValue("hydrationReminder.lastReminderLevel", 0);
            HydrationReminderEngine.recordCelebrationMessageSelection(message);
            return "goal-sent";
        }
        return "goal-error";
    }

    private static function isWithinNotificationWindow(now) {
        var local = Gregorian.info(now, Time.FORMAT_SHORT);
        var minutes = local.hour * 60 + local.min;
        var start = AppConfig.REMINDER_WINDOW_START_HOUR * 60;
        var end = AppConfig.REMINDER_WINDOW_END_HOUR * 60 + AppConfig.REMINDER_WINDOW_END_MINUTE;
        return (minutes >= start) && (minutes <= end);
    }

    private static function expectedProgressMl(now, targetMl) {
        return HydrationReminderEngine.expectedProgressMlForMinutes(
            HydrationReminderEngine.minutesOfDay(now), targetMl);
    }

    static function expectedProgressMlForMinutes(currentMinutes, targetMl) {
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

    static function reminderLevelForDeficit(deficitMl) as Number {
        if (deficitMl < AppConfig.REMINDER_DEFICIT_LEVEL1_ML) {
            return 0;
        }
        if (deficitMl < AppConfig.REMINDER_DEFICIT_LEVEL2_ML) {
            return 1;
        }
        if (deficitMl < AppConfig.REMINDER_DEFICIT_LEVEL3_ML) {
            return 2;
        }
        return 3;
    }

    static function shouldReserveNextLevel(
            deficitMl, currentLevel as Number, targetMl,
            currentMinutes as Number) as Boolean {
        if (currentLevel < 1 || currentLevel >= 3 || targetMl <= 0) {
            return false;
        }

        var endMinutes = AppConfig.REMINDER_WINDOW_END_HOUR * 60
            + AppConfig.REMINDER_WINDOW_END_MINUTE;
        var intervalMinutes = AppConfig.REMINDER_CHECK_INTERVAL_SEC / 60;
        if ((currentMinutes + intervalMinutes) > endMinutes) {
            return false;
        }

        var nextThreshold = currentLevel == 1
            ? AppConfig.REMINDER_DEFICIT_LEVEL2_ML
            : AppConfig.REMINDER_DEFICIT_LEVEL3_ML;
        var remainingMl = nextThreshold - deficitMl;
        if (remainingMl <= 0) {
            return false;
        }

        var windowMinutes = (AppConfig.REMINDER_WINDOW_END_HOUR * 60
            + AppConfig.REMINDER_WINDOW_END_MINUTE)
            - (AppConfig.REMINDER_WINDOW_START_HOUR * 60);
        var expectedPerCheckMl = targetMl.toFloat()
            * AppConfig.REMINDER_CHECK_INTERVAL_SEC.toFloat()
            / (windowMinutes * 60).toFloat();
        return remainingMl <= expectedPerCheckMl;
    }

    private static function minutesOfDay(now) as Number {
        var local = Gregorian.info(now, Time.FORMAT_SHORT);
        return local.hour * 60 + local.min;
    }

    private static function canShowReminder(nowValue, currentLevel) {
        var quietUntil = HydrationReminderEngine.getNumberValue("hydrationReminder.quietUntil");
        if (quietUntil > nowValue) {
            return false;
        }

        var lastReminderTime = HydrationReminderEngine.getNumberValue("hydrationReminder.lastReminderTime");
        var lastReminderLevel = HydrationReminderEngine.getNumberValue(
            "hydrationReminder.lastReminderLevel");
        var cooldown = HydrationReminderEngine.cooldownSecondsForLevels(
            currentLevel, lastReminderLevel);
        if ((nowValue - lastReminderTime) < cooldown) {
            return false;
        }

        return true;
    }

    static function cooldownSecondsForLevels(
            currentLevel as Number, lastLevel as Number) as Number {
        if (lastLevel > 0 && currentLevel > lastLevel) {
            return AppConfig.REMINDER_ESCALATION_COOLDOWN_SEC;
        }
        if (currentLevel == 1) {
            return AppConfig.REMINDER_REPEAT_LEVEL1_SEC;
        }
        if (currentLevel == 2) {
            return AppConfig.REMINDER_REPEAT_LEVEL2_SEC;
        }
        return AppConfig.REMINDER_REPEAT_LEVEL3_SEC;
    }

    private static function selectMessage(level) {
        var messages = PersonalMessages.reminderMessages(level) as Array<String>;
        return HydrationReminderEngine.selectNextMessage(
            messages,
            HydrationReminderEngine.reminderCursorKey(level),
            "Amor, um golinho de água 💧");
    }

    private static function selectCelebrationMessage() {
        var messages = PersonalMessages.celebrationMessages() as Array<String>;
        return HydrationReminderEngine.selectNextMessage(
            messages,
            "hydrationReminder.celebrationCursor",
            "Boa, amor! Meta do dia atingida!");
    }

    private static function selectNextMessage(
            messages as Array<String>, cursorKey as String,
            fallback as String) as String {
        var count = messages.size();
        if (count == 0) {
            return fallback;
        }

        var lastText = HydrationReminderEngine.getStringValue(
            "hydrationReminder.lastMessageText");
        var cursor = HydrationReminderEngine.getCursorValue(cursorKey);
        var nextIndex = HydrationReminderEngine.nextMessageIndex(
            messages, lastText, cursor);
        return messages[nextIndex];
    }

    static function nextMessageIndex(
            messages as Array<String>, lastText as String,
            cursor as Number) as Number {
        var count = messages.size();
        if (count == 0) {
            return -1;
        }

        var nextIndex = cursor;
        if (nextIndex < 0 || nextIndex >= count) {
            nextIndex = 0;
            for (var i = 0; i < count; i += 1) {
                if (messages[i].equals(lastText)) {
                    nextIndex = (i + 1) % count;
                    break;
                }
            }
        }

        // The text is a second guard for upgrades from versions that did not
        // persist per-level cursors or for a partially written Storage state.
        if (count > 1 && messages[nextIndex].equals(lastText)) {
            nextIndex = (nextIndex + 1) % count;
        }
        return nextIndex;
    }

    private static function recordReminderMessageSelection(
            message as String, level as Number) as Void {
        var messages = PersonalMessages.reminderMessages(level) as Array<String>;
        HydrationReminderEngine.recordMessageSelection(
            message, messages,
            HydrationReminderEngine.reminderCursorKey(level));
    }

    private static function recordCelebrationMessageSelection(
            message as String) as Void {
        var messages = PersonalMessages.celebrationMessages() as Array<String>;
        HydrationReminderEngine.recordMessageSelection(
            message, messages, "hydrationReminder.celebrationCursor");
    }

    private static function recordMessageSelection(
            message as String, messages as Array<String>,
            cursorKey as String) as Void {
        for (var i = 0; i < messages.size(); i += 1) {
            if (messages[i].equals(message)) {
                // The per-level cursor is the primary, single-key state. Save
                // it first so switching levels or an interrupted secondary
                // write cannot restart this level's sequence.
                Storage.setValue(cursorKey, (i + 1) % messages.size());
                break;
            }
        }
        // Global text is only a migration/cross-level consecutive guard.
        Storage.setValue("hydrationReminder.lastMessageText", message);
    }

    private static function reminderCursorKey(level as Number) as String {
        return "hydrationReminder.messageCursorL" + level;
    }

    private static function getCursorValue(key as String) as Number {
        var value = Storage.getValue(key);
        if (value instanceof Lang.Number) { return value; }
        if (value instanceof Lang.Long) { return value.toNumber(); }
        return -1;
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
        if (value instanceof Lang.Number) { return value; }
        if (value instanceof Lang.Long) { return value.toNumber(); }
        if (value instanceof Lang.Float) { return value.toNumber(); }
        if (value instanceof Lang.Double) { return value.toNumber(); }
        return 0;
    }

    private static function getStringValue(key) {
        var value = Storage.getValue(key);
        return value instanceof Lang.String ? value : "";
    }
}
