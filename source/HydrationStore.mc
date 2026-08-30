import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:glance, :background)
class HydrationStore {
    private static const HISTORY_KEY = "dailyHistoryV1";
    private static const HISTORY_STRIDE = 4;
    private static const HISTORY_RETENTION_DAYS = 366;
    private static const DRINK_EVENTS_KEY = "drinkEventsV1";
    private static const DRINK_EVENT_STRIDE = 5;
    private static const MAX_DAILY_DRINK_EVENTS = 96;

    static function dayKey() {
        var date = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return date.year.format("%04d")
            + (date.month as Number).format("%02d")
            + date.day.format("%02d");
    }

    static function currentDayOrdinal() as Number {
        var date = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return HydrationStore.dateOrdinal(
            date.year, date.month as Number, date.day);
    }

    // A timezone-independent ordinal derived from the local calendar date.
    // Only differences between ordinals matter, so the epoch is arbitrary.
    static function dateOrdinal(
            year as Number, month as Number, day as Number) as Number {
        var adjustedYear = year;
        var adjustedMonth = month;
        if (adjustedMonth <= 2) {
            adjustedYear -= 1;
            adjustedMonth += 12;
        }
        return 365 * adjustedYear
            + adjustedYear / 4
            - adjustedYear / 100
            + adjustedYear / 400
            + (153 * (adjustedMonth - 3) + 2) / 5
            + day - 1;
    }

    static function ensureToday() {
        ensureMoment(Time.now());
    }

    // Derive both markers from one instant so a midnight boundary cannot
    // produce a YYYYMMDD key for one day and an ordinal for the next.
    static function ensureMoment(moment) {
        var date = Gregorian.info(moment, Time.FORMAT_SHORT);
        var today = date.year.format("%04d")
            + (date.month as Number).format("%02d")
            + date.day.format("%02d");
        var todayOrdinal = HydrationStore.dateOrdinal(
            date.year, date.month as Number, date.day);
        ensureDay(today, todayOrdinal);
    }

    // Kept separate from the clock lookup so calendar correction behavior can
    // be verified deterministically in unit tests.
    static function ensureDay(today as String, todayOrdinal as Number) {
        var storedDay = Storage.getValue("day");
        var storedOrdinal = numberOrNull(Storage.getValue("dayOrdinal"));

        // Older versions only persisted the YYYYMMDD marker. Recover its
        // ordinal before deciding whether this is a forward rollover.
        if (storedOrdinal == null && storedDay instanceof Lang.String) {
            storedOrdinal = dayOrdinalFromKey(storedDay as String);
            if (storedOrdinal != null) {
                Storage.setValue("dayOrdinal", storedOrdinal);
            }
        }

        // A timezone/date correction can move the local calendar backwards.
        // Keep the newer marker and its totals until the calendar catches up;
        // rebinding them to the older date would later archive both days as a
        // single total.
        if (!today.equals(storedDay) && storedOrdinal != null
                && storedOrdinal > todayOrdinal) {
            pruneCaffeineEvents();
            return;
        }

        if (!today.equals(storedDay)) {
            if (storedDay instanceof Lang.String) {
                if (storedOrdinal != null && storedOrdinal < todayOrdinal) {
                    archiveCompletedDay(storedOrdinal, todayOrdinal);
                }
            }

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
            Storage.setValue("waterEventsV1", [] as Array<Number>);
            Storage.setValue(DRINK_EVENTS_KEY, [] as Array<Number>);
            Storage.setValue("lastStress", 0);
            Storage.setValue("lastBodyBattery", 0);
            Storage.setValue("lastSnapshotAt", 0);
            Storage.setValue("dailyTargetMl",
                HydrationCalculator.baselineWaterMl(
                    WellnessReader.weightKg()).toNumber());
            Storage.setValue("dayOrdinal", todayOrdinal);
            if (numberOrNull(Storage.getValue("history.startedOrdinal")) == null) {
                Storage.setValue("history.startedOrdinal", todayOrdinal);
            }
            // Commit the day marker last so an interrupted reset is retried.
            Storage.setValue("day", today);
        } else {
            if (storedOrdinal == null) {
                Storage.setValue("dayOrdinal", todayOrdinal);
            }
            if (numberOrNull(Storage.getValue("history.startedOrdinal")) == null) {
                Storage.setValue("history.startedOrdinal", todayOrdinal);
            }
            var savedTarget = numberOrNull(Storage.getValue("dailyTargetMl"));
            if (savedTarget == null || savedTarget <= 0) {
                Storage.setValue("dailyTargetMl",
                    HydrationCalculator.baselineWaterMl(
                        WellnessReader.weightKg()).toNumber());
            }
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
        recordDrink(0, ml, 0, 1);
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
        recordDrink(0, 0, mg, 1);
    }

    // Records a beverage as one logical event while keeping the compact
    // water/caffeine indexes used by reminders and caffeine decay.
    static function recordDrink(
            drinkId as Number, hydrationMl as Number,
            caffeineMg as Number, source as Number) as Boolean {
        if (hydrationMl < 0 || caffeineMg < 0
                || (hydrationMl == 0 && caffeineMg == 0)) {
            return false;
        }
        var nowMoment = Time.now();
        ensureMoment(nowMoment);
        var nowValue = nowMoment.value();

        if (hydrationMl > 0) {
            var waterEvents = trimPairEvents(loadWaterEvents());
            waterEvents.add(nowValue);
            waterEvents.add(hydrationMl);
            Storage.setValue("waterEventsV1", waterEvents);

            var quietSeconds = quietPeriodSecondsForWater(hydrationMl);
            if (quietSeconds > 0) {
                Storage.setValue("hydrationReminder.quietUntil",
                    nowValue + quietSeconds);
            }
        }

        if (caffeineMg > 0) {
            // ensureMoment() already pruned entries older than 48 hours. Do
            // not apply the 96-event reminder index cap here: every dose
            // still inside the decay window contributes to the estimate.
            var caffeineEvents = loadCaffeineEvents();
            caffeineEvents.add(nowValue);
            caffeineEvents.add(caffeineMg);
            Storage.setValue("caffeineEventsV2", caffeineEvents);
        }

        var drinkEvents = loadDrinkEvents();
        if (drinkEvents.size()
                >= MAX_DAILY_DRINK_EVENTS * DRINK_EVENT_STRIDE) {
            var trimmedDrinks = [] as Array<Number>;
            var keepValues = (MAX_DAILY_DRINK_EVENTS - 1)
                * DRINK_EVENT_STRIDE;
            var drinkStart = drinkEvents.size() - keepValues;
            if (drinkStart < 0) { drinkStart = 0; }
            drinkStart -= drinkStart % DRINK_EVENT_STRIDE;
            for (var i = drinkStart;
                    i + DRINK_EVENT_STRIDE - 1 < drinkEvents.size();
                    i += DRINK_EVENT_STRIDE) {
                for (var j = 0; j < DRINK_EVENT_STRIDE; j += 1) {
                    trimmedDrinks.add(drinkEvents[i + j]);
                }
            }
            drinkEvents = trimmedDrinks;
        }
        drinkEvents.add(nowValue);
        drinkEvents.add(drinkId);
        drinkEvents.add(hydrationMl);
        drinkEvents.add(caffeineMg);
        drinkEvents.add(source);
        Storage.setValue(DRINK_EVENTS_KEY, drinkEvents);

        if (hydrationMl > 0) {
            Storage.setValue("waterMl",
                storedNumber("waterMl") + hydrationMl);
        }
        if (caffeineMg > 0) {
            Storage.setValue("caffeineTodayMg",
                storedNumber("caffeineTodayMg") + caffeineMg);
        }
        HydrationComplicationPublisher.publishCurrent();
        return true;
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

    static function dailyTargetMl() as Number {
        ensureToday();
        var target = HydrationCalculator.adjustedWaterMl(
            WellnessReader.weightKg(),
            storedNumber("lastCalories"),
            storedNumber("lastStress"),
            storedNumber("lastBodyBattery"),
            storedNumber("caffeineTodayMg")).toNumber();
        if (target > 0) {
            if (storedNumber("dailyTargetMl") != target) {
                Storage.setValue("dailyTargetMl", target);
            }
        }
        return target;
    }

    static function historyStartOrdinal() as Number {
        ensureToday();
        var value = numberOrNull(Storage.getValue("history.startedOrdinal"));
        return value != null ? value : currentDayOrdinal();
    }

    // Returns one compact record for every local calendar day in the chosen
    // interval: [ordinal, hydration ml, goal ml, caffeine mg].
    static function historyRecords(days as Number) as Array<Number> {
        ensureToday();
        var result = [] as Array<Number>;
        if (days <= 0) { return result; }

        var todayOrdinal = currentDayOrdinal();
        var startOrdinal = todayOrdinal - days + 1;
        var firstTracked = historyStartOrdinal();
        if (startOrdinal < firstTracked) { startOrdinal = firstTracked; }

        var history = loadDailyHistory();
        var fallbackTarget = storedNumber("dailyTargetMl");
        if (fallbackTarget <= 0) {
            fallbackTarget = HydrationCalculator.baselineWaterMl(
                WellnessReader.weightKg()).toNumber();
        }

        for (var ordinal = startOrdinal;
                ordinal <= todayOrdinal; ordinal += 1) {
            if (ordinal == todayOrdinal) {
                result.add(ordinal);
                result.add(storedNumber("waterMl"));
                result.add(fallbackTarget);
                result.add(storedNumber("caffeineTodayMg"));
                continue;
            }

            var foundIndex = historyIndexOf(history, ordinal);
            if (foundIndex >= 0) {
                for (var field = 0; field < HISTORY_STRIDE; field += 1) {
                    result.add(history[foundIndex + field]);
                }
            } else {
                result.add(ordinal);
                result.add(0);
                result.add(fallbackTarget);
                result.add(0);
            }
        }
        return result;
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
        // Persist the goal snapshot even when reminder evaluation returns
        // early because notifications are disabled or outside the window.
        dailyTargetMl();
        HydrationComplicationPublisher.publishCurrent();
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

    private static function archiveCompletedDay(
            previousOrdinal as Number, todayOrdinal as Number) as Void {
        var history = loadDailyHistory();
        var target = storedNumber("dailyTargetMl");
        if (target <= 0) {
            target = HydrationCalculator.baselineWaterMl(
                WellnessReader.weightKg()).toNumber();
        }

        var cutoff = todayOrdinal - HISTORY_RETENTION_DAYS + 1;
        if (previousOrdinal >= cutoff
                && historyIndexOf(history, previousOrdinal) < 0) {
            history.add(previousOrdinal);
            history.add(storedNumber("waterMl"));
            history.add(target);
            history.add(storedNumber("caffeineTodayMg"));
        }

        var gapStart = previousOrdinal + 1;
        if (gapStart < cutoff) { gapStart = cutoff; }
        for (var ordinal = gapStart; ordinal < todayOrdinal; ordinal += 1) {
            if (historyIndexOf(history, ordinal) >= 0) { continue; }
            history.add(ordinal);
            history.add(0);
            history.add(target);
            history.add(0);
        }

        var kept = [] as Array<Number>;
        for (var i = 0; i + HISTORY_STRIDE - 1 < history.size();
                i += HISTORY_STRIDE) {
            if (history[i] < cutoff || history[i] >= todayOrdinal) {
                continue;
            }
            for (var field = 0; field < HISTORY_STRIDE; field += 1) {
                kept.add(history[i + field]);
            }
        }
        Storage.setValue(HISTORY_KEY, kept);

        var firstTracked = numberOrNull(
            Storage.getValue("history.startedOrdinal"));
        var candidateStart = previousOrdinal > cutoff
            ? previousOrdinal : cutoff;
        if (firstTracked == null) {
            Storage.setValue("history.startedOrdinal", candidateStart);
        } else if (firstTracked < cutoff) {
            Storage.setValue("history.startedOrdinal", cutoff);
        } else if (candidateStart < firstTracked) {
            Storage.setValue("history.startedOrdinal", candidateStart);
        }
    }

    private static function loadDailyHistory() as Array<Number> {
        var stored = Storage.getValue(HISTORY_KEY);
        var clean = [] as Array<Number>;
        if (!(stored instanceof Lang.Array)) { return clean; }

        var raw = stored as Array<Storage.ValueType>;
        var changed = (raw.size() % HISTORY_STRIDE) != 0;
        for (var i = 0; i + HISTORY_STRIDE - 1 < raw.size();
                i += HISTORY_STRIDE) {
            var ordinal = numberOrNull(raw[i]);
            var hydration = numberOrNull(raw[i + 1]);
            var target = numberOrNull(raw[i + 2]);
            var caffeine = numberOrNull(raw[i + 3]);
            if (ordinal == null || hydration == null || target == null
                    || caffeine == null || hydration < 0
                    || target < 0 || caffeine < 0) {
                changed = true;
                continue;
            }
            clean.add(ordinal);
            clean.add(hydration);
            clean.add(target);
            clean.add(caffeine);
        }
        if (changed || clean.size() != raw.size()) {
            Storage.setValue(HISTORY_KEY, clean);
        }
        return clean;
    }

    private static function historyIndexOf(
            history as Array<Number>, ordinal as Number) as Number {
        for (var i = 0; i + HISTORY_STRIDE - 1 < history.size();
                i += HISTORY_STRIDE) {
            if (history[i] == ordinal) { return i; }
        }
        return -1;
    }

    private static function dayOrdinalFromKey(key as String) as Number? {
        if (key.length() != 8) { return null; }
        try {
            var year = key.substring(0, 4).toNumber();
            var month = key.substring(4, 6).toNumber();
            var day = key.substring(6, 8).toNumber();
            if (month < 1 || month > 12 || day < 1 || day > 31) {
                return null;
            }
            return dateOrdinal(year, month, day);
        } catch (error) {
            return null;
        }
    }

    private static function loadDrinkEvents() as Array<Number> {
        var stored = Storage.getValue(DRINK_EVENTS_KEY);
        var clean = [] as Array<Number>;
        if (!(stored instanceof Lang.Array)) { return clean; }

        var raw = stored as Array<Storage.ValueType>;
        var changed = (raw.size() % DRINK_EVENT_STRIDE) != 0;
        for (var i = 0; i + DRINK_EVENT_STRIDE - 1 < raw.size();
                i += DRINK_EVENT_STRIDE) {
            var valid = true;
            var values = [] as Array<Number>;
            for (var field = 0; field < DRINK_EVENT_STRIDE; field += 1) {
                var value = numberOrNull(raw[i + field]);
                if (value == null) {
                    valid = false;
                    break;
                }
                values.add(value);
            }
            if (!valid) {
                changed = true;
                continue;
            }
            for (var field = 0; field < values.size(); field += 1) {
                clean.add(values[field]);
            }
        }
        if (changed || clean.size() != raw.size()) {
            Storage.setValue(DRINK_EVENTS_KEY, clean);
        }
        return clean;
    }

    private static function trimPairEvents(
            events as Array<Number>) as Array<Number> {
        if (events.size() < 192) { return events; }
        var trimmed = [] as Array<Number>;
        var start = events.size() - 190;
        if ((start % 2) != 0) { start += 1; }
        for (var i = start; i + 1 < events.size(); i += 2) {
            trimmed.add(events[i]);
            trimmed.add(events[i + 1]);
        }
        return trimmed;
    }

    private static function storedNumber(key as String) as Number {
        var value = numberOrNull(Storage.getValue(key));
        return value != null ? value : 0;
    }

    private static function numberOrNull(value) as Number? {
        if (value instanceof Lang.Number) { return value; }
        if (value instanceof Lang.Long) { return value.toNumber(); }
        if (value instanceof Lang.Float) { return value.toNumber(); }
        if (value instanceof Lang.Double) { return value.toNumber(); }
        return null;
    }
}
