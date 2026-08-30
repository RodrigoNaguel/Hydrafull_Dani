import Toybox.Lang;
import Toybox.Test;

(:test)
function testHydrationProgressIsClamped(logger as Test.Logger) as Boolean {
    logger.debug("checking hydration progress bounds");
    return FaceFormatter.progressPercent(0, 2500) == 0
        && FaceFormatter.progressPercent(1250, 2500) == 50
        && FaceFormatter.progressPercent(2500, 2500) == 100
        && FaceFormatter.progressPercent(3200, 2500) == 100
        && FaceFormatter.progressPercent(100, 0) == 0;
}

(:test)
function testComplicationValueFormatting(logger as Test.Logger) as Boolean {
    logger.debug("checking complication value formatting");
    return FaceFormatter.valueText(null).equals("--")
        && FaceFormatter.valueText(72).equals("72")
        && FaceFormatter.valueText(64.4).equals("64")
        && FaceFormatter.valueText("READY").equals("READY");
}

(:test)
function testCompactComplicationValue(logger as Test.Logger) as Boolean {
    logger.debug("checking compact complication values");
    return FaceFormatter.compactValue(72).equals("72")
        && FaceFormatter.compactValue(9999).equals("9999")
        && FaceFormatter.compactValue(12345).equals("12.3K")
        && FaceFormatter.compactValue(21.7).equals("21")
        && FaceFormatter.compactValue("LONG VALUE").equals("LONG V");
}

(:test)
function testCaloriesKeepAllFourDigits(logger as Test.Logger) as Boolean {
    logger.debug("checking complete calorie values");
    return FaceFormatter.compactValue(0).equals("0")
        && FaceFormatter.compactValue(87).equals("87")
        && FaceFormatter.compactValue(999).equals("999")
        && FaceFormatter.compactValue(1123).equals("1123")
        && FaceFormatter.compactValue(2049).equals("2049")
        && FaceFormatter.compactValue(9999).equals("9999")
        && FaceFormatter.compactValue(null).equals("--");
}

(:test)
function testHydrationDistinguishesUnavailableFromZero(
        logger as Test.Logger) as Boolean {
    logger.debug("checking hydration availability state");
    return FaceFormatter.wholeNumberText(null).equals("--")
        && FaceFormatter.wholeNumberText(0).equals("0")
        && FaceFormatter.wholeNumberText(200).equals("200")
        && FaceFormatter.wholeNumberText(2709).equals("2709");
}

(:test)
function testTemperatureFollowsDeviceUnits(logger as Test.Logger) as Boolean {
    logger.debug("checking Celsius and Fahrenheit complication values");
    return FaceFormatter.temperatureText(20, false).equals("20°")
        && FaceFormatter.temperatureText(20, true).equals("68°")
        && FaceFormatter.temperatureText(-40, false).equals("-40°")
        && FaceFormatter.temperatureText(-40, true).equals("-40°")
        && FaceFormatter.temperatureText(null, true).equals("--");
}
