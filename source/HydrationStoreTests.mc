import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

(:test)
function testDailyRolloverArchivesTotalsAndKeepsActiveCaffeine(
        logger as Test.Logger) as Boolean {
    logger.debug("checking daily archive and 48-hour caffeine retention");
    var today = HydrationStore.currentDayOrdinal();
    var yesterday = today - 1;
    var caffeineAt = Time.now().value() - 3600;

    Storage.setValue("day", "forced-yesterday");
    Storage.setValue("dayOrdinal", yesterday);
    Storage.setValue("history.startedOrdinal", yesterday);
    Storage.setValue("dailyHistoryV1", [] as Array<Number>);
    Storage.setValue("waterMl", 1200);
    Storage.setValue("caffeineTodayMg", 90);
    Storage.setValue("dailyTargetMl", 2000);
    Storage.setValue("waterEventsV1", [] as Array<Number>);
    Storage.setValue("caffeineEventsV2", [caffeineAt, 90]
        as Array<Number>);

    HydrationStore.ensureToday();
    var records = HydrationStore.historyRecords(2);
    var remaining = HydrationStore.caffeineRemaining(5.0);

    var passed = records.size() == 8
        && records[0] == yesterday
        && records[1] == 1200
        && records[2] == 2000
        && records[3] == 90
        && records[4] == today
        && records[5] == 0
        && HydrationStore.getNumber("caffeineTodayMg") == 0
        && remaining > 0.0;

    Storage.deleteValue("dailyHistoryV1");
    Storage.setValue("history.startedOrdinal", today);
    Storage.deleteValue("caffeineEventsV2");
    return passed;
}

(:test)
function testHistoryRetentionKeepsFullRollingWindow(
        logger as Test.Logger) as Boolean {
    logger.debug("checking 366-day rolling history boundary");
    var today = HydrationStore.currentDayOrdinal();
    var oldest = today - 367;
    var history = [] as Array<Number>;
    for (var ordinal = oldest; ordinal <= today - 2; ordinal += 1) {
        history.add(ordinal);
        history.add(1000);
        history.add(2000);
        history.add(0);
    }

    Storage.setValue("dailyHistoryV1", history);
    Storage.setValue("history.startedOrdinal", oldest);
    Storage.setValue("day", "forced-retention-rollover");
    Storage.setValue("dayOrdinal", today - 1);
    Storage.setValue("waterMl", 1500);
    Storage.setValue("caffeineTodayMg", 0);
    Storage.setValue("dailyTargetMl", 2100);

    HydrationStore.ensureToday();
    var expectedStart = today - 365;
    var records = HydrationStore.historyRecords(366);
    var passed = HydrationStore.historyStartOrdinal() == expectedStart
        && records.size() == 366 * 4
        && records[0] == expectedStart
        && records[records.size() - 4] == today;

    Storage.deleteValue("dailyHistoryV1");
    Storage.setValue("history.startedOrdinal", today);
    return passed;
}

(:test)
function testCalendarRegressionKeepsMarkerThroughCatchUp(
        logger as Test.Logger) as Boolean {
    logger.debug("checking backwards calendar correction and catch-up");
    var oldDay = Storage.getValue("day");
    var oldOrdinal = Storage.getValue("dayOrdinal");
    var oldWater = Storage.getValue("waterMl");
    var oldCaffeine = Storage.getValue("caffeineTodayMg");
    var oldStarted = Storage.getValue("history.startedOrdinal");
    var oldEvents = Storage.getValue("caffeineEventsV2");

    var futureOrdinal = HydrationStore.dateOrdinal(2099, 1, 1);
    var regressedOrdinal = HydrationStore.dateOrdinal(2098, 12, 31);
    Storage.setValue("day", "20990101");
    // Exercise migration from the older day marker without dayOrdinal.
    Storage.deleteValue("dayOrdinal");
    Storage.setValue("waterMl", 875);
    Storage.setValue("caffeineTodayMg", 80);
    Storage.setValue("history.startedOrdinal", futureOrdinal);

    HydrationStore.ensureDay("20981231", regressedOrdinal);
    var storedDay = Storage.getValue("day");
    var keptDuringRegression = storedDay instanceof Lang.String
        && (storedDay as String).equals("20990101")
        && Storage.getValue("dayOrdinal") == futureOrdinal
        && Storage.getValue("waterMl") == 875
        && Storage.getValue("caffeineTodayMg") == 80;

    // When the calendar reaches the original marker again, the totals still
    // belong to that marker and must not be archived or reset.
    HydrationStore.ensureDay("20990101", futureOrdinal);
    storedDay = Storage.getValue("day");
    var keptAfterCatchUp = storedDay instanceof Lang.String
        && (storedDay as String).equals("20990101")
        && Storage.getValue("dayOrdinal") == futureOrdinal
        && Storage.getValue("waterMl") == 875
        && Storage.getValue("caffeineTodayMg") == 80;

    restoreHydrationTestValue("day", oldDay);
    restoreHydrationTestValue("dayOrdinal", oldOrdinal);
    restoreHydrationTestValue("waterMl", oldWater);
    restoreHydrationTestValue("caffeineTodayMg", oldCaffeine);
    restoreHydrationTestValue("history.startedOrdinal", oldStarted);
    restoreHydrationTestValue("caffeineEventsV2", oldEvents);
    return keptDuringRegression && keptAfterCatchUp;
}

(:test)
function testCaffeineRetentionKeepsMoreThanNinetySixActiveDoses(
        logger as Test.Logger) as Boolean {
    logger.debug("checking active caffeine doses are not count-capped");
    HydrationStore.ensureToday();
    var oldCaffeine = Storage.getValue("caffeineTodayMg");
    var oldEvents = Storage.getValue("caffeineEventsV2");
    var oldDrinkEvents = Storage.getValue("drinkEventsV1");

    Storage.setValue("caffeineTodayMg", 0);
    Storage.setValue("caffeineEventsV2", [] as Array<Number>);
    Storage.setValue("drinkEventsV1", [] as Array<Number>);
    for (var i = 0; i < 97; i += 1) {
        HydrationStore.recordDrink(0, 0, 1, DrinkCatalog.SOURCE_WATCH);
    }
    var remaining = HydrationStore.caffeineRemaining(1000000.0);

    restoreHydrationTestValue("caffeineTodayMg", oldCaffeine);
    restoreHydrationTestValue("caffeineEventsV2", oldEvents);
    restoreHydrationTestValue("drinkEventsV1", oldDrinkEvents);
    return remaining > 96.9;
}

function restoreHydrationTestValue(key, value) as Void {
    if (value == null) {
        Storage.deleteValue(key);
    } else {
        Storage.setValue(key, value);
    }
}

function hydrationUndoTestKeys() as Array<String> {
    return ["day", "dayOrdinal", "waterMl", "caffeineTodayMg",
        "dailyTargetMl", "waterEventsV1", "caffeineEventsV2", "drinkEventsV1",
        "drinkRevisionV1", "drinkQuietBeforeV1", "drinkEvictedWaterV1",
        "drinkUndoJournalV1", "drinkUndoCalendarV1", "lastCalories",
        "lastStress", "lastBodyBattery", "lastSnapshotAt", "dailyHistoryV1",
        "history.startedOrdinal", "hydrationReminder.quietUntil",
        "hydrationReminder.lastReminderTime", "hydrationReminder.lastReminderLevel",
        "hydrationReminder.remindersToday", "hydrationReminder.goalCelebrationShown",
        "hydrationReminder.lastNotificationAt", "hydrationReminder.lastNotificationReason",
        "hydrationReminder.eodCursor", "hydrationReminder.lastUrgentBase",
        "background.lastRunAt", "background.lastRunReason", "phoneDrink.lastTokenV1"];
}

function beginHydrationUndoTest() as Dictionary {
    HydrationStore.ensureToday();
    var saved = {};
    var keys = hydrationUndoTestKeys();
    for (var i = 0; i < keys.size(); i += 1) {
        saved[keys[i]] = Storage.getValue(keys[i]);
    }
    Storage.setValue("waterMl", 0);
    Storage.setValue("caffeineTodayMg", 0);
    Storage.setValue("waterEventsV1", [] as Array<Number>);
    Storage.setValue("caffeineEventsV2", [] as Array<Number>);
    Storage.setValue("drinkEventsV1", [] as Array<Number>);
    Storage.setValue("drinkQuietBeforeV1", [] as Array<Number>);
    Storage.setValue("drinkEvictedWaterV1", [] as Array<Number>);
    Storage.setValue("hydrationReminder.quietUntil", 0);
    Storage.setValue("lastCalories", 0);
    Storage.setValue("lastStress", 0);
    Storage.setValue("lastBodyBattery", 50);
    Storage.deleteValue("drinkUndoJournalV1");
    return saved;
}

function endHydrationUndoTest(saved as Dictionary) as Void {
    var keys = hydrationUndoTestKeys();
    for (var i = 0; i < keys.size(); i += 1) {
        restoreHydrationTestValue(keys[i], saved[keys[i]]);
    }
    HydrationComplicationPublisher.publishCurrent();
}

function hydrationTestArraysEqual(actual, expected as Array<Number>) as Boolean {
    if (!(actual instanceof Lang.Array) || actual.size() != expected.size()) {
        return false;
    }
    for (var i = 0; i < expected.size(); i += 1) {
        if (actual[i] != expected[i]) { return false; }
    }
    return true;
}

(:test)
function testUndoCaffeinatedDrinkRestoresTotalsAndPreservesOtherState(
        logger as Test.Logger) as Boolean {
    logger.debug("undo restores doses, target, and phone/notification state");
    var saved = beginHydrationUndoTest();
    var now = Time.now().value();
    var oldWaterEvents = [now - 60, 1000] as Array<Number>;
    var oldCaffeineEvents = [now - 24 * 3600, 120, now - 60, 390]
        as Array<Number>;
    Storage.setValue("waterMl", 1000);
    Storage.setValue("caffeineTodayMg", 390);
    Storage.setValue("waterEventsV1", oldWaterEvents);
    Storage.setValue("caffeineEventsV2", oldCaffeineEvents);
    Storage.setValue("phoneDrink.lastTokenV1", true);
    Storage.setValue("hydrationReminder.remindersToday", 3);
    Storage.setValue("hydrationReminder.lastReminderTime", now - 900);
    Storage.setValue("hydrationReminder.goalCelebrationShown", true);
    var beforeTarget = HydrationStore.dailyTargetMl();
    var recorded = DrinkCatalog.record(DrinkCatalog.ID_ESPRESSO, 1,
        DrinkCatalog.SOURCE_PHONE);
    var snapshot = HydrationStore.lastDrinkForUndo();
    var targetWithDrink = HydrationStore.dailyTargetMl();
    var undone = snapshot != null && HydrationStore.undoLastDrink(snapshot);
    var passed = recorded && undone
        && targetWithDrink >= beforeTarget
        && HydrationStore.getNumber("waterMl") == 1000
        && HydrationStore.getNumber("caffeineTodayMg") == 390
        && HydrationStore.dailyTargetMl() == beforeTarget
        && hydrationTestArraysEqual(Storage.getValue("waterEventsV1"), oldWaterEvents)
        && hydrationTestArraysEqual(Storage.getValue("caffeineEventsV2"), oldCaffeineEvents)
        && HydrationStore.lastDrinkForUndo() == null
        && Storage.getValue("phoneDrink.lastTokenV1") == true
        && Storage.getValue("hydrationReminder.remindersToday") == 3
        && Storage.getValue("hydrationReminder.lastReminderTime") == now - 900
        && Storage.getValue("hydrationReminder.goalCelebrationShown") == true;
    endHydrationUndoTest(saved);
    return passed;
}

(:test)
function testUndoRejectsStaleAndRepeatedIdenticalDrinks(
        logger as Test.Logger) as Boolean {
    logger.debug("revision distinguishes identical drinks within one second");
    var saved = beginHydrationUndoTest();
    HydrationStore.recordDrink(1, 250, 0, 1);
    var first = HydrationStore.lastDrinkForUndo();
    if (first == null) { endHydrationUndoTest(saved); return false; }
    HydrationStore.recordDrink(1, 250, 0, 1);
    // Force equal timestamps so this remains deterministic across slow devices.
    Storage.setValue("drinkEventsV1", [first[2], 1, 250, 0, 1,
        first[2], 1, 250, 0, 1] as Array<Number>);
    Storage.setValue("waterEventsV1", [first[2], 250, first[2], 250]
        as Array<Number>);
    var second = HydrationStore.lastDrinkForUndo();
    var staleRejected = !HydrationStore.undoLastDrink(first);
    var undone = second != null && HydrationStore.undoLastDrink(second);
    var repeatedRejected = second != null && !HydrationStore.undoLastDrink(second);
    var passed = staleRejected && undone && repeatedRejected
        && HydrationStore.getNumber("waterMl") == 250
        && hydrationTestArraysEqual(Storage.getValue("waterEventsV1"),
            [first[2], 250] as Array<Number>);
    endHydrationUndoTest(saved);
    return passed;
}

(:test)
function testSecondDrinkKeepsLongerQuietPeriodAndUndoRestoresIt(
        logger as Test.Logger) as Boolean {
    logger.debug("a small second drink cannot shorten the earlier quiet period");
    var saved = beginHydrationUndoTest();
    HydrationStore.recordDrink(3, 1000, 0, 1);
    var originalQuiet = Storage.getValue("hydrationReminder.quietUntil");
    HydrationStore.recordDrink(1, 250, 0, 1);
    var kept = Storage.getValue("hydrationReminder.quietUntil") == originalQuiet;
    var latest = HydrationStore.lastDrinkForUndo();
    var undone = latest != null && HydrationStore.undoLastDrink(latest);
    var passed = kept && undone
        && Storage.getValue("hydrationReminder.quietUntil") == originalQuiet
        && HydrationStore.getNumber("waterMl") == 1000;
    endHydrationUndoTest(saved);
    return passed;
}

(:test)
function testUndoBeyondNinetySixDrinksKeepsTotalsAndEvictedWater(
        logger as Test.Logger) as Boolean {
    logger.debug("undo restores the capped water index without deriving totals from it");
    var saved = beginHydrationUndoTest();
    var timestamp = Time.now().value() - 60;
    var waters = [] as Array<Number>;
    var drinks = [] as Array<Number>;
    for (var i = 0; i < 96; i += 1) {
        waters.add(timestamp);
        waters.add(250);
        drinks.add(timestamp);
        drinks.add(1);
        drinks.add(250);
        drinks.add(0);
        drinks.add(1);
    }
    Storage.setValue("waterEventsV1", waters);
    Storage.setValue("drinkEventsV1", drinks);
    Storage.setValue("waterMl", 50000);
    var longQuiet = Time.now().value() + 12 * 3600;
    Storage.setValue("hydrationReminder.quietUntil", longQuiet);
    HydrationStore.recordDrink(1, 250, 0, 1);
    var latest = HydrationStore.lastDrinkForUndo();
    var undone = latest != null && HydrationStore.undoLastDrink(latest);
    var passed = undone && HydrationStore.getNumber("waterMl") == 50000
        && hydrationTestArraysEqual(Storage.getValue("waterEventsV1"), waters)
        && Storage.getValue("hydrationReminder.quietUntil") == longQuiet;
    endHydrationUndoTest(saved);
    return passed;
}

(:test)
function testUndoRejectsPreviousDayAndCalendarRegression(
        logger as Test.Logger) as Boolean {
    logger.debug("confirmation cannot survive a changed local calendar day");
    var saved = beginHydrationUndoTest();
    HydrationStore.recordDrink(1, 250, 0, 1);
    var latest = HydrationStore.lastDrinkForUndo();
    if (latest == null) { endHydrationUndoTest(saved); return false; }
    var yesterdaySnapshot = [] as Array<Number>;
    for (var i = 0; i < latest.size(); i += 1) { yesterdaySnapshot.add(latest[i]); }
    yesterdaySnapshot[0] -= 1;
    var oldDayRejected = !HydrationStore.undoLastDrink(yesterdaySnapshot);
    HydrationStore.ensureDay("calendar-regression", latest[0] - 1);
    // Returning to the original day still invalidates the old revision.
    var regressionRejected = !HydrationStore.undoLastDrink(latest);
    var passed = oldDayRejected && regressionRejected
        && HydrationStore.getNumber("waterMl") == 250;
    endHydrationUndoTest(saved);
    return passed;
}

(:test)
function testLegacyDrinkUndoRequiresMatchingDoseIndexes(
        logger as Test.Logger) as Boolean {
    logger.debug("legacy rows can be undone only when their contributions are present");
    var saved = beginHydrationUndoTest();
    var timestamp = Time.now().value();
    Storage.deleteValue("drinkRevisionV1");
    Storage.deleteValue("drinkQuietBeforeV1");
    Storage.deleteValue("drinkEvictedWaterV1");
    Storage.setValue("waterMl", 250);
    Storage.setValue("drinkEventsV1", [timestamp, 1, 250, 0, 1]
        as Array<Number>);
    var legacy = HydrationStore.lastDrinkForUndo();
    var missingRejected = legacy != null && !HydrationStore.undoLastDrink(legacy);
    Storage.setValue("waterEventsV1", [timestamp, 250] as Array<Number>);
    var undone = legacy != null && HydrationStore.undoLastDrink(legacy);
    var passed = missingRejected && undone && HydrationStore.getNumber("waterMl") == 0;
    endHydrationUndoTest(saved);
    return passed;
}

function hydrationTestUndoJournal(day, ordinal, revision, water, caffeine,
        waters, caffeines, drinks) {
    return {"day" => day, "dayOrdinal" => ordinal, "after" => {
        "waterMl" => water, "caffeineTodayMg" => caffeine,
        "dailyTargetMl" => 2200, "waterEventsV1" => waters,
        "caffeineEventsV2" => caffeines, "drinkEventsV1" => drinks,
        "drinkQuietBeforeV1" => [] as Array<Number>,
        "drinkEvictedWaterV1" => [] as Array<Number>,
        "hydrationReminder.quietUntil" => 0,
        "drinkRevisionV1" => revision
    }};
}

(:test)
function testUndoJournalReplaysPartialWritesBeforeNextDrink(
        logger as Test.Logger) as Boolean {
    logger.debug("restart completes an interrupted undo once before a new drink");
    var saved = beginHydrationUndoTest();
    var today = HydrationStore.currentDayOrdinal();
    var timestamp = Time.now().value();
    var revision = HydrationStore.getNumber("drinkRevisionV1") + 1;
    var journal = hydrationTestUndoJournal(HydrationStore.dayKey(), today,
        revision, 1000, 80, [] as Array<Number>,
        [timestamp - 3600, 80] as Array<Number>, [] as Array<Number>);
    // Model a power loss after writing some final values but before indexes.
    Storage.setValue("waterMl", 1000);
    Storage.setValue("caffeineTodayMg", 160);
    Storage.setValue("waterEventsV1", [timestamp, 50] as Array<Number>);
    Storage.setValue("drinkRevisionV1", revision);
    Storage.setValue("drinkUndoJournalV1", journal);
    HydrationStore.ensureToday();
    HydrationStore.ensureToday();
    var recovered = Storage.getValue("drinkUndoJournalV1") == null
        && HydrationStore.getNumber("waterMl") == 1000
        && HydrationStore.getNumber("caffeineTodayMg") == 80
        && hydrationTestArraysEqual(Storage.getValue("waterEventsV1"), []);
    // Pending intent must also be applied when recordDrink is the next entry.
    Storage.setValue("drinkUndoJournalV1", journal);
    HydrationStore.recordDrink(1, 250, 0, 1);
    var passed = recovered && HydrationStore.getNumber("waterMl") == 1250
        && HydrationStore.getNumber("caffeineTodayMg") == 80
        && Storage.getValue("drinkUndoJournalV1") == null;
    endHydrationUndoTest(saved);
    return passed;
}

(:test)
function testUndoJournalFinishesBeforeMidnightArchive(
        logger as Test.Logger) as Boolean {
    logger.debug("rollover archives corrected values after an interrupted undo");
    var saved = beginHydrationUndoTest();
    var today = HydrationStore.currentDayOrdinal();
    var revision = HydrationStore.getNumber("drinkRevisionV1") + 1;
    Storage.setValue("day", "pending-previous-day");
    Storage.setValue("dayOrdinal", today - 1);
    Storage.setValue("history.startedOrdinal", today - 1);
    Storage.setValue("dailyHistoryV1", [] as Array<Number>);
    Storage.setValue("waterMl", 1250);
    Storage.setValue("caffeineTodayMg", 80);
    Storage.setValue("drinkUndoJournalV1", hydrationTestUndoJournal(
        "pending-previous-day", today - 1, revision, 1000, 0,
        [] as Array<Number>, [] as Array<Number>, [] as Array<Number>));
    HydrationStore.ensureToday();
    var records = HydrationStore.historyRecords(2);
    var passed = records.size() == 8 && records[0] == today - 1
        && records[1] == 1000 && records[3] == 0
        && records[5] == 0 && Storage.getValue("drinkUndoJournalV1") == null
        && HydrationStore.lastDrinkForUndo() == null;
    endHydrationUndoTest(saved);
    return passed;
}

(:test)
function testUnknownBodyBatteryDoesNotIncreaseStoredTarget(
        logger as Test.Logger) as Boolean {
    logger.debug("missing and legacy-invalid battery samples remain unknown");
    var saved = beginHydrationUndoTest();
    var baseline = HydrationCalculator.adjustedWaterMl(
        WellnessReader.weightKg(), 0, 0, null, 0).toNumber();
    var passed = true;
    var invalid = [0, -1, 101];
    for (var i = 0; i < invalid.size(); i += 1) {
        Storage.setValue("lastBodyBattery", invalid[i]);
        if (HydrationStore.dailyTargetMl() != baseline) { passed = false; }
    }
    Storage.deleteValue("lastBodyBattery");
    HydrationStore.saveWellnessSnapshot(0, 0, null);
    passed = passed && HydrationStore.dailyTargetMl() == baseline;
    HydrationStore.saveWellnessSnapshot(0, 0, 20);
    var expectedLow = HydrationCalculator.adjustedWaterMl(
        WellnessReader.weightKg(), 0, 0, 20, 0).toNumber();
    passed = passed && HydrationStore.dailyTargetMl() == expectedLow;
    endHydrationUndoTest(saved);
    return passed;
}
