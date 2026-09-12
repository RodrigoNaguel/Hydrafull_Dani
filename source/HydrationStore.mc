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
    private static const DRINK_REVISION_KEY = "drinkRevisionV1";
    private static const DRINK_QUIET_BEFORE_KEY = "drinkQuietBeforeV1";
    private static const DRINK_EVICTED_WATER_KEY = "drinkEvictedWaterV1";
    private static const UNDO_JOURNAL_KEY = "drinkUndoJournalV1";
    private static const UNDO_CALENDAR_KEY = "drinkUndoCalendarV1";

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
        // Finish a committed drink change before archiving its original day.
        var recoveredUndo = recoverPendingUndo();
        var observedDay = numberOrNull(Storage.getValue(UNDO_CALENDAR_KEY));
        if (observedDay != null && observedDay != todayOrdinal) {
            Storage.setValue(DRINK_REVISION_KEY,
                storedNumber(DRINK_REVISION_KEY) + 1);
        }
        if (observedDay == null || observedDay != todayOrdinal) {
            Storage.setValue(UNDO_CALENDAR_KEY, todayOrdinal);
        }
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
            if (recoveredUndo) { HydrationComplicationPublisher.publishCurrent(); }
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
            Storage.setValue(DRINK_QUIET_BEFORE_KEY, [] as Array<Number>);
            Storage.setValue(DRINK_EVICTED_WATER_KEY, [] as Array<Number>);
            Storage.setValue("lastStress", 0);
            Storage.deleteValue("lastBodyBattery");
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
        if (recoveredUndo) { HydrationComplicationPublisher.publishCurrent(); }
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
        var quietBefore = storedNumber("hydrationReminder.quietUntil");
        var nextRevision = storedNumber(DRINK_REVISION_KEY) + 1;
        var evictedWaterAt = 0;
        var evictedWaterMl = 0;
        var waterEvents = loadWaterEvents();
        var caffeineEvents = loadCaffeineEvents();
        var quietUntil = quietBefore;

        if (hydrationMl > 0) {
            var previousWater = waterEvents;
            if (previousWater.size() >= 192) {
                // Restore the last evicted pair on undo, keeping the newest
                // 96 original rows even when migrating an oversized index.
                evictedWaterAt = previousWater[previousWater.size() - 192];
                evictedWaterMl = previousWater[previousWater.size() - 191];
            }
            waterEvents = trimPairEvents(previousWater);
            waterEvents.add(nowValue);
            waterEvents.add(hydrationMl);

            var quietSeconds = quietPeriodSecondsForWater(hydrationMl);
            if (quietSeconds > 0 && nowValue + quietSeconds > quietBefore) {
                quietUntil = nowValue + quietSeconds;
            }
        }

        if (caffeineMg > 0) {
            // ensureMoment() already pruned entries older than 48 hours. Do
            // not apply the 96-event reminder index cap here: every dose
            // still inside the decay window contributes to the estimate.
            caffeineEvents.add(nowValue);
            caffeineEvents.add(caffeineMg);
        }

        var drinkEvents = loadDrinkEvents();
        var quietBeforeEvents = loadQuietBeforeEvents(
            drinkEvents.size() / DRINK_EVENT_STRIDE);
        var evictedWaterEvents = loadEvictedWaterEvents(
            drinkEvents.size() / DRINK_EVENT_STRIDE);
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
            var trimmedQuiet = [] as Array<Number>;
            for (var q = drinkStart / DRINK_EVENT_STRIDE;
                    q < quietBeforeEvents.size(); q += 1) {
                trimmedQuiet.add(quietBeforeEvents[q]);
            }
            quietBeforeEvents = trimmedQuiet;
            var trimmedEvicted = [] as Array<Number>;
            for (var p = (drinkStart / DRINK_EVENT_STRIDE) * 2;
                    p < evictedWaterEvents.size(); p += 1) {
                trimmedEvicted.add(evictedWaterEvents[p]);
            }
            evictedWaterEvents = trimmedEvicted;
        }
        drinkEvents.add(nowValue);
        drinkEvents.add(drinkId);
        drinkEvents.add(hydrationMl);
        drinkEvents.add(caffeineMg);
        drinkEvents.add(source);
        quietBeforeEvents.add(quietBefore);
        evictedWaterEvents.add(evictedWaterAt);
        evictedWaterEvents.add(evictedWaterMl);
        var afterCaffeine = storedNumber("caffeineTodayMg") + caffeineMg;
        return commitDrinkState({
            "waterMl" => storedNumber("waterMl") + hydrationMl,
            "caffeineTodayMg" => afterCaffeine,
            "dailyTargetMl" => HydrationCalculator.adjustedWaterMl(
                WellnessReader.weightKg(), storedNumber("lastCalories"),
                storedNumber("lastStress"), storedBodyBattery(),
                afterCaffeine).toNumber(),
            "waterEventsV1" => waterEvents,
            "caffeineEventsV2" => caffeineEvents,
            DRINK_EVENTS_KEY => drinkEvents,
            DRINK_QUIET_BEFORE_KEY => quietBeforeEvents,
            DRINK_EVICTED_WATER_KEY => evictedWaterEvents,
            "hydrationReminder.quietUntil" => quietUntil,
            DRINK_REVISION_KEY => nextRevision
        });
    }

    // Immutable confirmation identity: day, revision, then the five stored
    // drink fields. Never identify an event by its timestamp alone.
    static function lastDrinkForUndo() as Array<Number>? {
        var now = Time.now();
        ensureMoment(now);
        var today = currentDayOrdinal();
        if (storedNumber("dayOrdinal") != today
                || !dayKey().equals(Storage.getValue("day"))) {
            return null;
        }
        var drinks = loadDrinkEvents();
        if (drinks.size() < DRINK_EVENT_STRIDE) { return null; }
        var last = drinks.size() - DRINK_EVENT_STRIDE;
        var timestamp = drinks[last];
        if (timestamp <= 0 || timestamp > now.value()) { return null; }
        var date = Gregorian.info(new Time.Moment(timestamp), Time.FORMAT_SHORT);
        if (dateOrdinal(date.year, date.month as Number, date.day) != today
                || drinks[last + 2] < 0 || drinks[last + 3] < 0
                || (drinks[last + 2] == 0 && drinks[last + 3] == 0)) {
            return null;
        }
        var snapshot = [today, storedNumber(DRINK_REVISION_KEY)]
            as Array<Number>;
        for (var i = 0; i < DRINK_EVENT_STRIDE; i += 1) {
            snapshot.add(drinks[last + i]);
        }
        return snapshot;
    }

    static function undoLastDrink(snapshot as Array<Number>) as Boolean {
        var current = lastDrinkForUndo();
        if (current == null || snapshot.size() != current.size()) {
            return false;
        }
        for (var i = 0; i < current.size(); i += 1) {
            if (snapshot[i] != current[i]) { return false; }
        }

        var water = storedNumber("waterMl");
        var caffeine = storedNumber("caffeineTodayMg");
        if (water < snapshot[4] || caffeine < snapshot[5]) { return false; }
        var waterEvents = loadWaterEvents();
        var caffeineEvents = loadCaffeineEvents();
        var waterIndex = snapshot[4] > 0
            ? lastPairIndex(waterEvents, snapshot[2], snapshot[4]) : -1;
        var caffeineIndex = snapshot[5] > 0
            ? lastPairIndex(caffeineEvents, snapshot[2], snapshot[5]) : -1;
        // Legacy events are reversible only when both indexes still identify
        // the exact contributions; never guess or subtract unrelated doses.
        if ((snapshot[4] > 0 && waterIndex < 0)
                || (snapshot[5] > 0 && caffeineIndex < 0)) {
            return false;
        }
        var remainingWater = withoutPair(waterEvents, waterIndex);
        var remainingCaffeine = withoutPair(caffeineEvents, caffeineIndex);
        var drinks = loadDrinkEvents();
        var quietBefore = loadQuietBeforeEvents(
            drinks.size() / DRINK_EVENT_STRIDE);
        var evictedWater = loadEvictedWaterEvents(
            drinks.size() / DRINK_EVENT_STRIDE);
        var evictedIndex = evictedWater.size() - 2;
        if (evictedWater[evictedIndex] > 0
                && evictedWater[evictedIndex + 1] > 0) {
            var restoredWater = [evictedWater[evictedIndex],
                evictedWater[evictedIndex + 1]] as Array<Number>;
            for (var r = 0; r < remainingWater.size(); r += 1) {
                restoredWater.add(remainingWater[r]);
            }
            remainingWater = restoredWater;
        }
        var remainingDrinks = [] as Array<Number>;
        for (var d = 0; d < drinks.size() - DRINK_EVENT_STRIDE; d += 1) {
            remainingDrinks.add(drinks[d]);
        }
        var remainingQuiet = [] as Array<Number>;
        for (var q = 0; q < quietBefore.size() - 1; q += 1) {
            remainingQuiet.add(quietBefore[q]);
        }
        var remainingEvicted = [] as Array<Number>;
        for (var p = 0; p < evictedIndex; p += 1) {
            remainingEvicted.add(evictedWater[p]);
        }
        var restoredQuiet = quietBefore[quietBefore.size() - 1];
        if (restoredQuiet < 0) { restoredQuiet = 0; }
        // The saved predecessor preserves valid contributions beyond the
        // 96-entry water index. Legacy rows fall back to retained water rows.
        for (var w = 0; w + 1 < remainingWater.size(); w += 2) {
            var duration = quietPeriodSecondsForWater(remainingWater[w + 1]);
            var until = remainingWater[w] + duration;
            if (duration > 0 && until > restoredQuiet) { restoredQuiet = until; }
        }
        var afterCaffeine = caffeine - snapshot[5];
        var afterTarget = HydrationCalculator.adjustedWaterMl(
            WellnessReader.weightKg(), storedNumber("lastCalories"),
            storedNumber("lastStress"), storedBodyBattery(),
            afterCaffeine).toNumber();
        var after = {
            "waterMl" => water - snapshot[4],
            "caffeineTodayMg" => afterCaffeine,
            "dailyTargetMl" => afterTarget,
            "waterEventsV1" => remainingWater,
            "caffeineEventsV2" => remainingCaffeine,
            DRINK_EVENTS_KEY => remainingDrinks,
            DRINK_QUIET_BEFORE_KEY => remainingQuiet,
            DRINK_EVICTED_WATER_KEY => remainingEvicted,
            "hydrationReminder.quietUntil" => restoredQuiet,
            DRINK_REVISION_KEY => snapshot[1] + 1
        };
        return commitDrinkState(after);
    }

    private static function commitDrinkState(after as Dictionary) as Boolean {
        // Commit intent first. All following writes use final absolute values,
        // so a restart replays the same add/undo without splitting its totals
        // from its dose indexes and undo metadata.
        Storage.setValue(UNDO_JOURNAL_KEY, {
            "day" => Storage.getValue("day"),
            "dayOrdinal" => Storage.getValue("dayOrdinal"),
            "after" => after
        });
        if (!recoverPendingUndo()) { return false; }
        HydrationComplicationPublisher.publishCurrent();
        return true;
    }

    private static function recoverPendingUndo() as Boolean {
        var pending = Storage.getValue(UNDO_JOURNAL_KEY);
        if (!(pending instanceof Lang.Dictionary)) { return false; }
        var journal = pending as Dictionary;
        var day = journal["day"];
        var ordinal = numberOrNull(journal["dayOrdinal"]);
        var state = journal["after"];
        if (!(day instanceof Lang.String) || ordinal == null
                || !(state instanceof Lang.Dictionary)
                || !(day as String).equals(Storage.getValue("day"))
                || ordinal != numberOrNull(Storage.getValue("dayOrdinal"))) {
            Storage.deleteValue(UNDO_JOURNAL_KEY);
            return false;
        }
        var after = state as Dictionary;
        var numberKeys = ["waterMl", "caffeineTodayMg", "dailyTargetMl",
            "hydrationReminder.quietUntil", DRINK_REVISION_KEY];
        var arrayKeys = ["waterEventsV1", "caffeineEventsV2",
            DRINK_EVENTS_KEY, DRINK_QUIET_BEFORE_KEY, DRINK_EVICTED_WATER_KEY];
        for (var n = 0; n < numberKeys.size(); n += 1) {
            if (numberOrNull(after[numberKeys[n]]) == null) {
                Storage.deleteValue(UNDO_JOURNAL_KEY);
                return false;
            }
        }
        for (var a = 0; a < arrayKeys.size(); a += 1) {
            if (!(after[arrayKeys[a]] instanceof Lang.Array)) {
                Storage.deleteValue(UNDO_JOURNAL_KEY);
                return false;
            }
        }
        if (storedNumber(DRINK_REVISION_KEY) > after[DRINK_REVISION_KEY]) {
            Storage.deleteValue(UNDO_JOURNAL_KEY);
            return false;
        }
        for (var k = 0; k < numberKeys.size(); k += 1) {
            Storage.setValue(numberKeys[k], after[numberKeys[k]]);
        }
        for (var e = 0; e < arrayKeys.size(); e += 1) {
            Storage.setValue(arrayKeys[e], after[arrayKeys[e]]);
        }
        // Notification counters, celebration flags, and the phone command
        // token are deliberately outside this transaction.
        Storage.deleteValue(UNDO_JOURNAL_KEY);
        return true;
    }

    private static function lastPairIndex(
            events as Array<Number>, timestamp as Number,
            dose as Number) as Number {
        for (var i = events.size() - 2; i >= 0; i -= 2) {
            if (events[i] == timestamp && events[i + 1] == dose) { return i; }
        }
        return -1;
    }

    private static function withoutPair(
            events as Array<Number>, index as Number) as Array<Number> {
        var result = [] as Array<Number>;
        for (var i = 0; i + 1 < events.size(); i += 2) {
            if (i == index) { continue; }
            result.add(events[i]);
            result.add(events[i + 1]);
        }
        return result;
    }

    private static function loadQuietBeforeEvents(count as Number)
            as Array<Number> {
        var saved = Storage.getValue(DRINK_QUIET_BEFORE_KEY);
        var result = [] as Array<Number>;
        for (var i = 0; i < count; i += 1) {
            var value = -1;
            if (saved instanceof Lang.Array && saved.size() == count) {
                var number = numberOrNull(saved[i]);
                if (number != null && number >= 0) { value = number; }
            }
            result.add(value);
        }
        return result;
    }

    private static function validBodyBattery(value) as Number? {
        var number = numberOrNull(value);
        return number != null && number >= 1 && number <= 100 ? number : null;
    }

    private static function loadEvictedWaterEvents(count as Number)
            as Array<Number> {
        var saved = Storage.getValue(DRINK_EVICTED_WATER_KEY);
        var result = [] as Array<Number>;
        for (var i = 0; i < count * 2; i += 1) {
            var value = 0;
            if (saved instanceof Lang.Array && saved.size() == count * 2) {
                var number = numberOrNull(saved[i]);
                if (number != null && number >= 0) { value = number; }
            }
            result.add(value);
        }
        return result;
    }

    private static function storedBodyBattery() as Number? {
        return validBodyBattery(Storage.getValue("lastBodyBattery"));
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
            storedBodyBattery(),
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
        var battery = validBodyBattery(bodyBattery);
        if (battery != null) { Storage.setValue("lastBodyBattery", battery); }
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
