import Toybox.Lang;
import Toybox.Test;
import Toybox.Weather;

(:test)
function testFaceTimeTextUsesConsistentTwoDigitFormatting(
        logger as Test.Logger) as Boolean {
    return FaceFormatter.hourText(0, true).equals("00")
        && FaceFormatter.hourText(12, true).equals("12")
        && FaceFormatter.hourText(23, true).equals("23")
        && FaceFormatter.hourText(0, false).equals("12")
        && FaceFormatter.hourText(12, false).equals("12")
        && FaceFormatter.hourText(13, false).equals("01")
        && FaceFormatter.minuteText(0).equals("00")
        && FaceFormatter.minuteText(9).equals("09")
        && FaceFormatter.minuteText(59).equals("59");
}

(:test)
function testFaceCombinedPaletteColorRoles(logger as Test.Logger) as Boolean {
    var green = FaceFormatter.paletteColors(FacePalettePreset.GREEN);
    var brown = FaceFormatter.paletteColors(FacePalettePreset.BROWN);
    var purple = FaceFormatter.paletteColors(FacePalettePreset.PURPLE);
    var custom = FaceFormatter.paletteColors(FacePalettePreset.CUSTOM);
    var expectedGreen = [0x0F1F17, 0x1E3A2E, 0x3E5A3F,
        0x6B7F67, 0xC7CBB8, 0x3D4337] as Array<Number>;
    var expectedBrown = [0x1A120E, 0x3A2418, 0x6B4A2E,
        0xA88462, 0xD5C4AE, 0x4A4A46] as Array<Number>;
    var expectedPurple = [0x0E0B1D, 0x2A1E4D, 0x5A3B8C,
        0x8B7CC7, 0xC9C2E3, 0x3A3A52] as Array<Number>;

    logger.debug("palette role count green=" + green.size());
    return samePalette(green, expectedGreen)
        && samePalette(brown, expectedBrown)
        && samePalette(purple, expectedPurple)
        && custom.size() == 0;
}

function samePalette(actual as Array<Number>,
        expected as Array<Number>) as Boolean {
    if (actual.size() != expected.size()) { return false; }
    for (var i = 0; i < actual.size(); i += 1) {
        if (actual[i] != expected[i]) { return false; }
    }
    return true;
}

(:test)
function testFaceWeatherGlyphMapsCurrentConditionsSafely(
        logger as Test.Logger) as Boolean {
    return FaceFormatter.weatherGlyph(Weather.CONDITION_CLEAR)
            == FaceWeatherGlyph.SUN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_MOSTLY_CLEAR)
            == FaceWeatherGlyph.SUN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_PARTLY_CLOUDY)
            == FaceWeatherGlyph.PARTLY_CLOUDY
        && FaceFormatter.weatherGlyph(Weather.CONDITION_CLOUDY)
            == FaceWeatherGlyph.CLOUD
        && FaceFormatter.weatherGlyph(Weather.CONDITION_HEAVY_RAIN)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_LIGHT_SHOWERS)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_SHOWERS)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_HEAVY_SHOWERS)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_CHANCE_OF_SHOWERS)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_DRIZZLE)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_FREEZING_RAIN)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_CHANCE_OF_THUNDERSTORMS)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_THUNDERSTORMS)
            == FaceWeatherGlyph.RAIN
        && FaceFormatter.weatherGlyph(Weather.CONDITION_SNOW)
            == FaceWeatherGlyph.SNOW
        && FaceFormatter.weatherGlyph(Weather.CONDITION_RAIN_SNOW)
            == FaceWeatherGlyph.SNOW
        && FaceFormatter.weatherGlyph(null) == FaceWeatherGlyph.CLOUD
        && FaceFormatter.weatherGlyph(999) == FaceWeatherGlyph.CLOUD;
}

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
