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
