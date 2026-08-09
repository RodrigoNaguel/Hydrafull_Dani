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
    return HydrationReminderEngine.cooldownSecondsForLevels(2, 1)
            == 45 * 60
        && HydrationReminderEngine.cooldownSecondsForLevels(1, 1)
            == 90 * 60
        && HydrationReminderEngine.cooldownSecondsForLevels(2, 2)
            == 75 * 60
        && HydrationReminderEngine.cooldownSecondsForLevels(3, 3)
            == 60 * 60;
}

(:test)
function testOnlyMeaningfulWaterStartsQuietPeriod(
        logger as Test.Logger) as Boolean {
    logger.debug("checking post-water quiet period");
    return HydrationStore.quietPeriodSecondsForWater(50) == 0
        && HydrationStore.quietPeriodSecondsForWater(110) == 0
        && HydrationStore.quietPeriodSecondsForWater(199) == 0
        && HydrationStore.quietPeriodSecondsForWater(200) == 45 * 60
        && HydrationStore.quietPeriodSecondsForWater(500) == 45 * 60;
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
function testReminderMessagesRotateWithoutConsecutiveRepeat(
        logger as Test.Logger) as Boolean {
    logger.debug("checking persistent per-level message rotation");
    var messages = PersonalMessages.reminderMessages(2) as Array<String>;
    var allLevelsCoverDailyLimit = true;
    for (var level = 1; level <= 3; level += 1) {
        var levelMessages = PersonalMessages.reminderMessages(level)
            as Array<String>;
        if (levelMessages.size()
                < AppConfig.REMINDER_MAX_DAILY_REMINDERS) {
            allLevelsCoverDailyLimit = false;
        }
    }
    return allLevelsCoverDailyLimit
        && HydrationReminderEngine.nextMessageIndex(messages, "", -1) == 0
        && HydrationReminderEngine.nextMessageIndex(
            messages, messages[0], -1) == 1
        && HydrationReminderEngine.nextMessageIndex(
            messages, messages[1], -1) == 2
        && HydrationReminderEngine.nextMessageIndex(
            messages, messages[1], 1) == 2
        && HydrationReminderEngine.nextMessageIndex(
            messages, messages[messages.size() - 1], -1) == 0;
}
