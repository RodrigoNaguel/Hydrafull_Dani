import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

(:test)
function testEnergyDrinkCatalogValues(logger as Test.Logger) as Boolean {
    logger.debug("checking Monster Zero and Red Bull presets");
    return DrinkCatalog.isKnown(DrinkCatalog.ID_MONSTER_ZERO_473)
        && DrinkCatalog.hydrationMl(
            DrinkCatalog.ID_MONSTER_ZERO_473) == 473
        && DrinkCatalog.caffeineMg(
            DrinkCatalog.ID_MONSTER_ZERO_473) == 142
        && DrinkCatalog.isKnown(DrinkCatalog.ID_MONSTER_ZERO_355)
        && DrinkCatalog.hydrationMl(
            DrinkCatalog.ID_MONSTER_ZERO_355) == 355
        && DrinkCatalog.caffeineMg(
            DrinkCatalog.ID_MONSTER_ZERO_355) == 107
        && DrinkCatalog.isKnown(DrinkCatalog.ID_RED_BULL_250)
        && DrinkCatalog.hydrationMl(
            DrinkCatalog.ID_RED_BULL_250) == 250
        && DrinkCatalog.caffeineMg(
            DrinkCatalog.ID_RED_BULL_250) == 80
        && DrinkCatalog.isKnown(DrinkCatalog.ID_RED_BULL_ZERO_250)
        && DrinkCatalog.hydrationMl(
            DrinkCatalog.ID_RED_BULL_ZERO_250) == 250
        && DrinkCatalog.caffeineMg(
            DrinkCatalog.ID_RED_BULL_ZERO_250) == 80
        && DrinkCatalog.isKnown(DrinkCatalog.ID_RED_BULL_355)
        && DrinkCatalog.hydrationMl(
            DrinkCatalog.ID_RED_BULL_355) == 355
        && DrinkCatalog.caffeineMg(
            DrinkCatalog.ID_RED_BULL_355) == 112
        && DrinkCatalog.isKnown(DrinkCatalog.ID_RED_BULL_ZERO_355)
        && DrinkCatalog.hydrationMl(
            DrinkCatalog.ID_RED_BULL_ZERO_355) == 355
        && DrinkCatalog.caffeineMg(
            DrinkCatalog.ID_RED_BULL_ZERO_355) == 112;
}

(:test)
function testDrinkCatalogRejectsUnknownIds(
        logger as Test.Logger) as Boolean {
    logger.debug("checking unknown drink IDs");
    return !DrinkCatalog.isKnown(0)
        && !DrinkCatalog.isKnown(999)
        && DrinkCatalog.hydrationMl(999) == 0
        && DrinkCatalog.caffeineMg(999) == 0;
}

(:test)
function testLocalDayOrdinalHandlesLeapDay(
        logger as Test.Logger) as Boolean {
    logger.debug("checking calendar-day ordinal");
    var feb28 = HydrationStore.dateOrdinal(2024, 2, 28);
    var feb29 = HydrationStore.dateOrdinal(2024, 2, 29);
    var mar1 = HydrationStore.dateOrdinal(2024, 3, 1);
    var nextYear = HydrationStore.dateOrdinal(2025, 2, 28);
    return feb29 - feb28 == 1
        && mar1 - feb29 == 1
        && nextYear - feb28 == 366;
}

(:test)
function testPhoneDrinkToggleIsConsumedOnce(
        logger as Test.Logger) as Boolean {
    logger.debug("checking repeated wakes consume a phone setting once");
    HydrationStore.ensureToday();

    var oldDrinkId = Properties.getValue("phone_drink_id");
    var oldServings = Properties.getValue("phone_drink_servings");
    var oldToken = Properties.getValue("phone_add_token");
    var oldWater = Storage.getValue("waterMl");
    var oldCaffeine = Storage.getValue("caffeineTodayMg");
    var oldWaterEvents = Storage.getValue("waterEventsV1");
    var oldCaffeineEvents = Storage.getValue("caffeineEventsV2");
    var oldDrinkEvents = Storage.getValue("drinkEventsV1");
    var oldQuietUntil = Storage.getValue("hydrationReminder.quietUntil");
    var oldLastToken = Storage.getValue("phoneDrink.lastTokenV1");
    var oldProcessedAt = Storage.getValue("phoneDrink.lastProcessedAt");
    var oldResult = Storage.getValue("phoneDrink.lastResult");

    var beforeWater = HydrationStore.getNumber("waterMl");
    var beforeCaffeine = HydrationStore.getNumber("caffeineTodayMg");
    Properties.setValue("phone_drink_id",
        DrinkCatalog.ID_MONSTER_ZERO_473);
    Properties.setValue("phone_drink_servings", 1);
    Properties.setValue("phone_add_token", true);
    Storage.setValue("phoneDrink.lastTokenV1", false);

    var first = PhoneDrinkBridge.processPending();
    var afterFirstWater = HydrationStore.getNumber("waterMl");
    var afterFirstCaffeine = HydrationStore.getNumber("caffeineTodayMg");
    var second = PhoneDrinkBridge.processPending();
    var afterSecondWater = HydrationStore.getNumber("waterMl");
    var afterSecondCaffeine = HydrationStore.getNumber("caffeineTodayMg");

    Properties.setValue("phone_drink_id", oldDrinkId);
    Properties.setValue("phone_drink_servings", oldServings);
    Properties.setValue("phone_add_token", oldToken);
    restoreStorageValue("waterMl", oldWater);
    restoreStorageValue("caffeineTodayMg", oldCaffeine);
    restoreStorageValue("waterEventsV1", oldWaterEvents);
    restoreStorageValue("caffeineEventsV2", oldCaffeineEvents);
    restoreStorageValue("drinkEventsV1", oldDrinkEvents);
    restoreStorageValue("hydrationReminder.quietUntil", oldQuietUntil);
    restoreStorageValue("phoneDrink.lastTokenV1", oldLastToken);
    restoreStorageValue("phoneDrink.lastProcessedAt", oldProcessedAt);
    restoreStorageValue("phoneDrink.lastResult", oldResult);

    return first && !second
        && afterFirstWater == beforeWater + 473
        && afterFirstCaffeine == beforeCaffeine + 142
        && afterSecondWater == afterFirstWater
        && afterSecondCaffeine == afterFirstCaffeine;
}

function restoreStorageValue(key, value) as Void {
    if (value == null) {
        Storage.deleteValue(key);
    } else {
        Storage.setValue(key, value);
    }
}
