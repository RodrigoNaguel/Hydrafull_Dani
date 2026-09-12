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

        var targetMl = HydrationStore.dailyTargetMl();
        var waterMl = HydrationStore.getNumber("waterMl");

        if (targetMl <= 0) {
            return "invalid-target";
        }

        if (waterMl >= targetMl) {
            return HydrationReminderEngine.showGoalCelebrationIfNeeded(nowValue);
        }

        if (HydrationReminderEngine.isQuietPeriodActive(nowValue)) {
            return "quiet";
        }

        var currentMinutes = HydrationReminderEngine.minutesOfDay(now);
        var startMinutes = AppConfig.REMINDER_WINDOW_START_HOUR * 60;
        var endMinutes = AppConfig.REMINDER_WINDOW_END_HOUR * 60
            + AppConfig.REMINDER_WINDOW_END_MINUTE;
        if (currentMinutes >= endMinutes) {
            return "end-of-day";
        }

        var expectedMl = HydrationReminderEngine.expectedProgressMlForMinutes(
            currentMinutes, targetMl);
        if (expectedMl <= 0) {
            return "before-start";
        }

        // --- Smart deficit: blend immediate deficit + forward projection ---
        //
        // immediateDeficit: how many ml behind the linear pace right now.
        //
        // projectedShortfall: if the user keeps drinking at their current
        //   pace until end of window, how many ml will they fall short?
        //   This catches "drinking fine now but pace is slowing" scenarios.
        //
        // timeWeight: 0 at window start → 1 at window end. Gives projection
        //   full voice late in the day while avoiding false alarms at 8 AM.
        //
        // effectiveDeficit = max(immediateDeficit, projectedShortfall × timeWeight)
        var immediateDeficit = expectedMl > waterMl
            ? (expectedMl - waterMl).toNumber() : 0;

        var elapsedMinutes = currentMinutes - startMinutes;
        var remainingMinutes = endMinutes - currentMinutes;
        var windowTotal = endMinutes - startMinutes;
        var timeWeight = windowTotal > 0
            ? elapsedMinutes.toFloat() / windowTotal.toFloat() : 0.0;

        var recentMinutes = 120;
        var recentWaterMl = HydrationStore.waterDrunkInLastSeconds(recentMinutes * 60);

        var projectedShortfall = HydrationCalculator.projectedShortfallMl(
            waterMl, targetMl, elapsedMinutes, remainingMinutes, recentWaterMl, recentMinutes);
        var projectedContrib = (projectedShortfall * timeWeight).toNumber();

        var deficitMl = immediateDeficit > projectedContrib
            ? immediateDeficit : projectedContrib;
        if (deficitMl <= 0) {
            return "on-track";
        }

        var inactionCount = HydrationReminderEngine.advanceInaction(nowValue);
        var currentLevel = HydrationReminderEngine.reminderLevelForState(
            deficitMl, inactionCount, remainingMinutes);
        if (currentLevel == 0) {
            return "on-track";
        }

        if (!HydrationReminderEngine.canShowReminder(
            nowValue, currentLevel, inactionCount, remainingMinutes)) {
            return "cooldown-L" + currentLevel;
        }

        var lastReminderLevel = HydrationReminderEngine.getNumberValue(
            "hydrationReminder.lastReminderLevel");
        if (currentLevel == lastReminderLevel
                && HydrationReminderEngine.shouldReserveNextLevel(
                    deficitMl, currentLevel, targetMl, currentMinutes)) {
            return "await-L" + (currentLevel + 1);
        }

        if (HydrationReminderEngine.remindersToday()
                >= AppConfig.REMINDER_MAX_DAILY_REMINDERS) {
            return "daily-limit";
        }

        // L2 and L3 include the volume still needed so the message always
        // conveys what action is required, not just that action is needed.
        var remainingMl = (targetMl - waterMl).toNumber();
        var message = HydrationReminderEngine.selectMessage(
            currentLevel, remainingMl, remainingMinutes);
        if (NotificationManager.notifyReminder(message)) {
            HydrationReminderEngine.recordReminder(nowValue, currentLevel);
            HydrationReminderEngine.recordReminderMessageSelection(
                message, currentLevel);
            return "sent-L" + currentLevel;
        }
        return "send-error";
    }

    static function reminderLevelForState(
            deficitMl, inactionCount as Number,
            minutesRemaining as Number) as Number {
        var level = HydrationReminderEngine.reminderLevelForDeficit(deficitMl);
        if (level < 2 && inactionCount >= AppConfig.REMINDER_INACTION_LEVEL2_COUNT
                && deficitMl >= AppConfig.REMINDER_DEFICIT_LEVEL1_ML) {
            level = 2;
        }
        if (level < 3 && inactionCount >= AppConfig.REMINDER_INACTION_LEVEL3_COUNT
                && minutesRemaining <= AppConfig.REMINDER_END_OF_DAY_MINUTES
                && deficitMl >= AppConfig.REMINDER_DEFICIT_LEVEL2_ML) {
            level = 3;
        }
        return level;
    }

    static function inactionCount() as Number {
        return HydrationReminderEngine.getNumberValue(
            "hydrationReminder.inactionCount");
    }

    static function recordInaction() as Void {
        var count = HydrationReminderEngine.inactionCount() + 1;
        if (count > AppConfig.REMINDER_INACTION_MAX_COUNT) {
            count = AppConfig.REMINDER_INACTION_MAX_COUNT;
        }
        Storage.setValue("hydrationReminder.inactionCount", count);
    }

    static function resetInaction() as Void {
        Storage.setValue("hydrationReminder.inactionCount", 0);
        Storage.setValue("hydrationReminder.lastInactionAt", 0);
    }

    static function advanceInaction(nowValue) as Number {
        var lastAt = HydrationReminderEngine.getNumberValue(
            "hydrationReminder.lastInactionAt");
        if (lastAt > 0
                && nowValue - lastAt < AppConfig.REMINDER_CHECK_INTERVAL_SEC) {
            return HydrationReminderEngine.inactionCount();
        }
        HydrationReminderEngine.recordInaction();
        Storage.setValue("hydrationReminder.lastInactionAt", nowValue);
        return HydrationReminderEngine.inactionCount();
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

        private static function canShowReminder(
            nowValue, currentLevel, inactionCount as Number,
            minutesRemaining as Number) {
        var quietUntil = HydrationReminderEngine.getNumberValue("hydrationReminder.quietUntil");
        if (quietUntil > nowValue) {
            return false;
        }

        var lastReminderTime = HydrationReminderEngine.getNumberValue("hydrationReminder.lastReminderTime");
        var lastReminderLevel = HydrationReminderEngine.getNumberValue(
            "hydrationReminder.lastReminderLevel");
        var cooldown = HydrationReminderEngine.cooldownSecondsForState(
            currentLevel, lastReminderLevel, inactionCount, minutesRemaining);
        return (nowValue - lastReminderTime) >= cooldown;
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

    static function cooldownSecondsForState(
            currentLevel as Number, lastLevel as Number,
            inactionCount as Number, minutesRemaining as Number) as Number {
        var cooldown = HydrationReminderEngine.cooldownSecondsForLevels(
            currentLevel, lastLevel);
        if (currentLevel > lastLevel && inactionCount >= 2) {
            cooldown = cooldown / 2;
        }
        if (minutesRemaining <= AppConfig.REMINDER_END_OF_DAY_MINUTES
                && currentLevel >= 2) {
            cooldown = cooldown / 2;
        }
        return cooldown;
    }

    // L1 messages are warm reminders (no volume shown — the pace gap is small).
    // L2/L3 messages include how much is still needed so the user knows
    // what action is required, not just that they are behind.
    private static function selectMessage(
            level as Number, remainingMl as Number,
            minutesLeft as Number) as String {
        if (level >= 2) {
            return HydrationReminderEngine.buildUrgentMessage(
                level, remainingMl, minutesLeft);
        }
        // Level 1: use rotating personal messages (no volume — gentle nudge).
        var messages = PersonalMessages.reminderMessages(level) as Array<String>;
        return HydrationReminderEngine.selectNextMessage(
            messages,
            HydrationReminderEngine.reminderCursorKey(level),
            "Amor, um golinho de água 💧");
    }

    // Builds an urgent message for L2/L3 that always states how many litres
    // remain and, if fewer than 2 h are left, also the time pressure.
    // The base string (from PersonalMessages) is stored under a separate key
    // so the cursor can be updated correctly even though the full message
    // includes a volume suffix that does not appear in the messages array.
    private static function buildUrgentMessage(
            level as Number, remainingMl as Number,
            minutesLeft as Number) as String {
        var liters = remainingMl.toFloat() / 1000.0;
        var volStr = liters.format("%.1f") + "L";

        // Select and advance the cursor for this level's base messages.
        var baseMessages = PersonalMessages.reminderMessages(level) as Array<String>;
        var base = HydrationReminderEngine.selectNextMessage(
            baseMessages,
            HydrationReminderEngine.reminderCursorKey(level),
            "Amor, água!");

        // Persist the base so recordReminderMessageSelection can update the
        // cursor without searching for the concatenated full message.
        Storage.setValue("hydrationReminder.lastUrgentBase", base);

        // Append volume context. If the window is closing (<= 2 h) also add
        // the time remaining so the urgency is self-evident.
        var suffix;
        if (minutesLeft <= 120) {
            var hours = minutesLeft / 60;
            var mins = minutesLeft % 60;
            var timeStr = hours > 0
                ? hours + "h" + mins.format("%02d")
                : mins + "min";
            suffix = " (" + volStr + " em " + timeStr + ")";
        } else {
            suffix = " (faltam " + volStr + ")";
        }
        return base + suffix;
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
        // For L2/L3 the notification body is base+suffix. The cursor should
        // track the base string (which exists in PersonalMessages), not the
        // full concatenated string.  buildUrgentMessage writes the base to
        // lastUrgentBase; fall back to the full message for L1.
        var trackText = message;
        if (level >= 2) {
            var stored = Storage.getValue("hydrationReminder.lastUrgentBase");
            if (stored instanceof Lang.String) { trackText = stored; }
        }
        HydrationReminderEngine.recordMessageSelection(
            trackText, messages,
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
