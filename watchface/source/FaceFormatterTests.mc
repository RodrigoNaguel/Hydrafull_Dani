import Toybox.Lang;
import Toybox.Test;

(:test)
function testFaceCaloriesPreserveWholeValues(logger as Test.Logger) as Boolean {
    var values = [0, 87, 999, 1123, 2049, 9999, 10000] as Array<Number>;
    var expected = ["0", "87", "999", "1123", "2049", "9999", "10.0K"]
        as Array<String>;
    for (var i = 0; i < values.size(); i += 1) {
        var actual = FaceFormatter.compactValue(values[i]);
        if (!actual.equals(expected[i])) {
            logger.debug("calories=" + values[i] + " formatted as " + actual);
            return false;
        }
    }
    return FaceFormatter.compactValue(null).equals("--");
}

(:test)
function testFaceHydrationDistinguishesUnavailableAndZero(
        logger as Test.Logger) as Boolean {
    var unavailable = FaceFormatter.wholeNumberText(null);
    var zero = FaceFormatter.wholeNumberText(0);
    logger.debug("hydration unavailable=" + unavailable + ", zero=" + zero);

    return unavailable.equals("--")
        && zero.equals("0")
        && FaceFormatter.wholeNumberText(750).equals("750")
        && FaceFormatter.wholeNumberText(10000).equals("10000");
}

(:test)
function testFaceTemperatureRespectsUnitsAndMissingData(
        logger as Test.Logger) as Boolean {
    var celsius = FaceFormatter.temperatureText(25.0, false);
    var fahrenheit = FaceFormatter.temperatureText(25.0, true);
    logger.debug("temperature C=" + celsius + ", F=" + fahrenheit);

    return celsius.equals("25°")
        && fahrenheit.equals("77°")
        && FaceFormatter.temperatureText(0, false).equals("0°")
        && FaceFormatter.temperatureText(0, true).equals("32°")
        && FaceFormatter.temperatureText(-40, true).equals("-40°")
        && FaceFormatter.temperatureText(null, false).equals("--")
        && FaceFormatter.temperatureText(null, true).equals("--")
        && FaceFormatter.temperatureText("unknown", false).equals("--");
}

(:test)
function testFaceHydrationProgressStaysWithinBounds(
        logger as Test.Logger) as Boolean {
    var partial = FaceFormatter.progressPercent(750, 2000);
    logger.debug("hydration progress 750/2000=" + partial);

    return partial == 37
        && FaceFormatter.progressPercent(0, 2000) == 0
        && FaceFormatter.progressPercent(-100, 2000) == 0
        && FaceFormatter.progressPercent(750, 0) == 0
        && FaceFormatter.progressPercent(750, -1) == 0
        && FaceFormatter.progressPercent(2000, 2000) == 100
        && FaceFormatter.progressPercent(3000, 2000) == 100;
}

(:test)
function testFaceNumericConversionRejectsMissingAndTextValues(
        logger as Test.Logger) as Boolean {
    var zero = FaceFormatter.numberOrNull(0);
    var fraction = FaceFormatter.numberOrNull(42.9);
    logger.debug("numeric conversion zero=" + zero + ", fraction=" + fraction);

    return zero == 0
        && fraction == 42
        && FaceFormatter.numberOrNull(null) == null
        && FaceFormatter.numberOrNull("0") == null
        && FaceFormatter.numberOrNull(false) == null;
}
