import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:glance, :background)
class HydrationStore {
    static function dayKey() {
        var date = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return date.year.format("%04d")
            + (date.month as Number).format("%02d")
            + date.day.format("%02d");
    }

    static function ensureToday() {
        var today = dayKey();
        if (!today.equals(Storage.getValue("day"))) {
            Storage.setValue("waterMl", 0);
            Storage.setValue("caffeineTodayMg", 0);
            Storage.setValue("hydrationReminder.lastReminderTime", 0);
            Storage.setValue("hydrationReminder.lastReminderLevel", 0);
            Storage.setValue("hydrationReminder.remindersToday", 0);
            Storage.setValue("hydrationReminder.quietUntil", 0);
            Storage.setValue("hydrationReminder.goalCelebrationShown", false);
            Storage.setValue("hydrationReminder.lastNotificationAt", 0);
            Storage.setValue("hydrationReminder.lastNotificationReason", "-");
            Storage.setValue("hydrationReminder.eodCursor", 0);
            Storage.setValue("hydrationReminder.lastUrgentBase", "");
            Storage.setValue("background.lastRunAt", 0);
            Storage.setValue("background.lastRunReason", "-");
            Storage.setValue("lastCalories", 0);
            Storage.setValue("caffeineEventsV2", [] as Array<Number>);
            Storage.setValue("waterEventsV1", [] as Array<Number>);
            Storage.setValue("caffeineTodayMg", 0);
            Storage.setValue("lastStress", 0);
            Storage.setValue("lastBodyBattery", 0);
            Storage.setValue("lastSnapshotAt", 0);
            // Commit the day marker last so an interrupted reset is retried.
            Storage.setValue("day", today);
        }
        pruneCaffeineEvents();
    }

    static function getNumber(key) {
        ensureToday();
        var value = Storage.getValue(key);
        var number = numberOrNull(value);
        return number != null ? number : 0;
    }

    static function addWater(ml as Number) {
        ensureToday();
        Storage.setValue("waterMl", getNumber("waterMl") + ml);
        var quietSeconds = HydrationStore.quietPeriodSecondsForWater(ml);
        if (quietSeconds > 0) {
            Storage.setValue("hydrationReminder.quietUntil",
                Time.now().value() + quietSeconds);
        }
        
        var events = loadWaterEvents();
        if (events.size() >= 192) {
            var trimmed = [] as Array<Number>;
            var start = events.size() - 190;
            if ((start % 2) != 0) { start += 1; }
            for (var i = start; i + 1 < events.size(); i += 2) {
                trimmed.add(events[i]);
                trimmed.add(events[i + 1]);
            }
            events = trimmed;
        }
        events.add(Time.now().value());
        events.add(ml);
        Storage.setValue("waterEventsV1", events);
    }

    static function quietPeriodSecondsForWater(ml) as Number {
        if (ml < AppConfig.REMINDER_MIN_WATER_FOR_QUIET_ML) {
            return 0;
        }
        var baseMin = AppConfig.REMINDER_AFTER_WATER_SEC / 60; // usually 45
        var propMin = (ml * 0.18).toNumber();
        var quietMin = propMin > baseMin ? propMin : baseMin;
        return quietMin * 60;
    }

    static function addCaffeine(mg as Number) {
        ensureToday();
        var events = loadCaffeineEvents();
        // Store flat timestamp/dose pairs. A homogeneous Array<Number>
        // keeps Monkey Types precise and is valid for Application.Storage.
        if (events.size() >= 192) {
            var trimmed = [] as Array<Number>;
            var start = events.size() - 190;
            if ((start % 2) != 0) { start += 1; }
            for (var i = start; i + 1 < events.size(); i += 2) {
                trimmed.add(events[i]);
                trimmed.add(events[i + 1]);
            }
            events = trimmed;
        }
        events.add(Time.now().value());
        events.add(mg);
        Storage.setValue("caffeineEventsV2", events);
        Storage.setValue("caffeineTodayMg", getNumber("caffeineTodayMg") + mg);
    }

    static function caffeineRemaining(halfLifeHours) {
        ensureToday();
        var events = loadCaffeineEvents();
        if (halfLifeHours <= 0) {
            return 0.0;
        }

        var now = Time.now().value();
        var remaining = 0.0;
        for (var i = 0; i + 1 < events.size(); i += 2) {
            var elapsedHours = (now - events[i]).toFloat() / 3600.0;
            remaining += events[i + 1]
                * Math.pow(0.5, elapsedHours / halfLifeHours);
        }
        return remaining;
    }

    static function saveWellnessSnapshot(calories, stress, bodyBattery) {
        if (calories != null) { Storage.setValue("lastCalories", calories); }
        if (stress != null) { Storage.setValue("lastStress", stress); }
        if (bodyBattery != null) { Storage.setValue("lastBodyBattery", bodyBattery); }
        // Calories influence the hydration target. If that critical read
        // fails, keep the old timestamp so the next temporal event retries.
        if (calories != null) {
            Storage.setValue("lastSnapshotAt", Time.now().value());
        }
    }

    static function recordBackgroundRun(reason) {
        Storage.setValue("background.lastRunAt", Time.now().value());
        Storage.setValue("background.lastRunReason", reason);
    }

    static function recordNotification(reason) {
        Storage.setValue("hydrationReminder.lastNotificationAt", Time.now().value());
        Storage.setValue("hydrationReminder.lastNotificationReason", reason);
    }

    static function getBackgroundLastRunAt() {
        return HydrationStore.getNumber("background.lastRunAt");
    }

    static function getBackgroundLastRunReason() {
        var value = Storage.getValue("background.lastRunReason");
        return value instanceof Lang.String ? value : "-";
    }

    static function getNotificationLastAt() {
        return HydrationStore.getNumber("hydrationReminder.lastNotificationAt");
    }

    static function getNotificationLastReason() {
        var value = Storage.getValue("hydrationReminder.lastNotificationReason");
        return value instanceof Lang.String ? value : "-";
    }

    static function getString(key) {
        ensureToday();
        var value = Storage.getValue(key);
        return value instanceof Lang.String ? value : "";
    }

    private static function pruneCaffeineEvents() {
        var events = loadCaffeineEvents();
        if (events.size() == 0) { return; }

        var cutoff = Time.now().value() - (48 * 3600);
        var kept = [] as Array<Number>;
        for (var i = 0; i + 1 < events.size(); i += 2) {
            if (events[i] >= cutoff) {
                kept.add(events[i]);
                kept.add(events[i + 1]);
            }
        }
        if (kept.size() != events.size()) {
            Storage.setValue("caffeineEventsV2", kept);
        }
    }

    private static function loadCaffeineEvents() as Array<Number> {
        var stored = Storage.getValue("caffeineEventsV2");
        var clean = [] as Array<Number>;
        if (!(stored instanceof Lang.Array)) {
            return clean;
        }

        var raw = stored as Array<Storage.ValueType>;
        var changed = (raw.size() % 2) != 0;
        for (var i = 0; i + 1 < raw.size(); i += 2) {
            var timestamp = numberOrNull(raw[i]);
            var dose = numberOrNull(raw[i + 1]);
            if (timestamp == null || dose == null) {
                changed = true;
                continue;
            }
            clean.add(timestamp);
            clean.add(dose);
        }

        if (changed || clean.size() != raw.size()) {
            Storage.setValue("caffeineEventsV2", clean);
        }
        return clean;
    }

    private static function loadWaterEvents() as Array<Number> {
        var stored = Storage.getValue("waterEventsV1");
        var clean = [] as Array<Number>;
        if (!(stored instanceof Lang.Array)) {
            return clean;
        }

        var raw = stored as Array<Storage.ValueType>;
        var changed = (raw.size() % 2) != 0;
        for (var i = 0; i + 1 < raw.size(); i += 2) {
            var timestamp = numberOrNull(raw[i]);
            var dose = numberOrNull(raw[i + 1]);
            if (timestamp == null || dose == null) {
                changed = true;
                continue;
            }
            clean.add(timestamp);
            clean.add(dose);
        }

        if (changed || clean.size() != raw.size()) {
            Storage.setValue("waterEventsV1", clean);
        }
        return clean;
    }

    static function waterDrunkInLastSeconds(seconds as Number) as Number {
        ensureToday();
        var events = loadWaterEvents();
        var now = Time.now().value();
        var cutoff = now - seconds;
        var total = 0;
        for (var i = 0; i + 1 < events.size(); i += 2) {
            if (events[i] >= cutoff) {
                total += events[i + 1];
            }
        }
        return total;
    }

    private static function numberOrNull(value) as Number? {
        if (value instanceof Lang.Number) { return value; }
        if (value instanceof Lang.Long) { return value.toNumber(); }
        if (value instanceof Lang.Float) { return value.toNumber(); }
        if (value instanceof Lang.Double) { return value.toNumber(); }
        return null;
    }
}
