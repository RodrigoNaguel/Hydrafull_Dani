import Toybox.Lang;
import Toybox.Test;

(:test)
function testAfternoonReminderScenario(logger as Test.Logger) as Boolean {
    var expected = HydrationReminderEngine.expectedProgressMlForMinutes(
        16 * 60 + 54, 2322);
    var deficit = expected - 800;
    logger.debug("expected=" + expected + ", deficit=" + deficit);
    return expected > 1425.1 && expected < 1425.3
        && HydrationReminderEngine.reminderLevelForDeficit(deficit) == 2;
}

(:test)
function testReminderDeficitBoundaries(logger as Test.Logger) as Boolean {
    logger.debug("checking reminder deficit boundaries");
    return HydrationReminderEngine.reminderLevelForDeficit(199) == 0
        && HydrationReminderEngine.reminderLevelForDeficit(200) == 1
        && HydrationReminderEngine.reminderLevelForDeficit(449) == 1
        && HydrationReminderEngine.reminderLevelForDeficit(450) == 2
        && HydrationReminderEngine.reminderLevelForDeficit(799) == 2
        && HydrationReminderEngine.reminderLevelForDeficit(800) == 3;
}

(:test)
function testReminderEscalationAndRepeatCooldowns(
        logger as Test.Logger) as Boolean {
    logger.debug("checking reminder cooldown policy");
    // escalation (lastLevel > 0 and currentLevel > lastLevel) => 30 min
    return HydrationReminderEngine.cooldownSecondsForLevels(2, 1)
            == 30 * 60
        && HydrationReminderEngine.cooldownSecondsForLevels(1, 1)
            == 60 * 60
        && HydrationReminderEngine.cooldownSecondsForLevels(2, 2)
            == 45 * 60
        && HydrationReminderEngine.cooldownSecondsForLevels(3, 3)
            == 30 * 60;
}

(:test)
function testInactionModulatesLevelWithoutReplacingDeficit(
        logger as Test.Logger) as Boolean {
    logger.debug("checking inaction level modulation");
    return HydrationReminderEngine.reminderLevelForState(199, 3, 500) == 0
        && HydrationReminderEngine.reminderLevelForState(200, 1, 500) == 1
        && HydrationReminderEngine.reminderLevelForState(200, 2, 500) == 2
        && HydrationReminderEngine.reminderLevelForState(450, 3, 120) == 3
        && HydrationReminderEngine.reminderLevelForState(450, 3, 121) == 2;
}

(:test)
function testAdaptiveCooldownRespondsToInactionAndDayEnd(
        logger as Test.Logger) as Boolean {
    logger.debug("checking adaptive reminder cooldown");
    return HydrationReminderEngine.cooldownSecondsForState(2, 2, 0, 300)
            == 45 * 60
        && HydrationReminderEngine.cooldownSecondsForState(2, 1, 2, 300)
            == 15 * 60
        && HydrationReminderEngine.cooldownSecondsForState(3, 3, 0, 120)
            == 15 * 60;
}

(:test)
function testOnlyMeaningfulWaterStartsQuietPeriod(
        logger as Test.Logger) as Boolean {
    logger.debug("checking post-water quiet period");
    return HydrationStore.quietPeriodSecondsForWater(50) == 0
        && HydrationStore.quietPeriodSecondsForWater(110) == 0
        && HydrationStore.quietPeriodSecondsForWater(199) == 0
        && HydrationStore.quietPeriodSecondsForWater(200) == 45 * 60
        && HydrationStore.quietPeriodSecondsForWater(500) == 90 * 60
        && HydrationStore.quietPeriodSecondsForWater(1000) == 180 * 60;
}

(:test)
function testReminderWaitsForImminentEscalation(
        logger as Test.Logger) as Boolean {
    logger.debug("checking escalation look-ahead");
    return !HydrationReminderEngine.shouldReserveNextLevel(
            400, 1, 2322, 16 * 60)
        && HydrationReminderEngine.shouldReserveNextLevel(
            441, 1, 2322, 16 * 60)
        && !HydrationReminderEngine.shouldReserveNextLevel(
            750, 2, 2322, 17 * 60)
        && HydrationReminderEngine.shouldReserveNextLevel(
            790, 2, 2322, 17 * 60)
        && !HydrationReminderEngine.shouldReserveNextLevel(
            900, 3, 2322, 18 * 60)
        && !HydrationReminderEngine.shouldReserveNextLevel(
            790, 2, 2322, 22 * 60 + 20);
}

(:test)
function testProjectedShortfallDetectsSlowPace(
        logger as Test.Logger) as Boolean {
    // 08:00-22:30 window = 870 min total.
    // At 10:00 (120 min elapsed), user drank 500 ml.
    // Pace = 500/120 = 4.17 ml/min. Remaining = 750 min.
    // Projected total = 500 + 4.17*750 = 3625 ml.
    // Shortfall vs target 3800 ml = 175 ml.
    var shortfall1 = HydrationCalculator.projectedShortfallMl(
        500, 3800, 120, 750, 500, 120);
    logger.debug("shortfall1=" + shortfall1);
    // At 18:00 (600 min elapsed), user still only 500 ml.
    // Pace = 500/600 = 0.833 ml/min. Remaining = 270 min.
    // Projected total = 500 + 225 = 725 ml. Shortfall = 3075 ml -> L3.
    var shortfall2 = HydrationCalculator.projectedShortfallMl(
        500, 3800, 600, 270, 500, 600);
    logger.debug("shortfall2=" + shortfall2);
    return shortfall1 > 174.0 && shortfall1 < 176.0
        && shortfall2 > 3074.0 && shortfall2 < 3076.0
        && HydrationReminderEngine.reminderLevelForDeficit(
            shortfall2.toNumber()) == 3;
}

(:test)
function testReminderMessagesRotateWithoutConsecutiveRepeat(
        logger as Test.Logger) as Boolean {
    logger.debug("checking persistent per-level message rotation");
    var messages = PersonalMessages.reminderMessages(2) as Array<String>;
    return HydrationReminderEngine.nextMessageIndex(messages, "", -1) == 0
        && HydrationReminderEngine.nextMessageIndex(
            messages, messages[0], -1) == 1
        && HydrationReminderEngine.nextMessageIndex(
            messages, messages[1], -1) == 2
        && HydrationReminderEngine.nextMessageIndex(
            messages, messages[1], 1) == 2
        && HydrationReminderEngine.nextMessageIndex(
            messages, messages[messages.size() - 1], -1) == 0;
}
