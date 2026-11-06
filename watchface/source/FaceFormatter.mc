import Toybox.Complications;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Weather;

class FaceFormatter {
    static function hourText(hour as Number, is24Hour as Boolean) as String {
        var displayHour = hour;
        if (!is24Hour) {
            displayHour = hour % 12;
            if (displayHour == 0) { displayHour = 12; }
        }
        return displayHour.format("%02d");
    }

    static function minuteText(minute as Number) as String {
        return minute.format("%02d");
    }

    static function paletteColors(preset as Number) as Array<Number> {
        // Roles: background, halo, widget icons, clock accent, text, shadow.
        if (preset == FacePalettePreset.GREEN) {
            return [0x0F1F17, 0x1E3A2E, 0x3E5A3F, 0x6B7F67,
                0xC7CBB8, 0x3D4337];
        }
        if (preset == FacePalettePreset.BROWN) {
            return [0x1A120E, 0x3A2418, 0x6B4A2E, 0xA88462,
                0xD5C4AE, 0x4A4A46];
        }
        if (preset == FacePalettePreset.PURPLE) {
            return [0x0E0B1D, 0x2A1E4D, 0x5A3B8C, 0x8B7CC7,
                0xC9C2E3, 0x3A3A52];
        }
        return [];
    }

    static function weatherGlyph(condition as Number?) as Number {
        if (condition == null) { return FaceWeatherGlyph.CLOUD; }

        if (condition == Weather.CONDITION_CLEAR
                || condition == Weather.CONDITION_MOSTLY_CLEAR
                || condition == Weather.CONDITION_PARTLY_CLEAR) {
            return FaceWeatherGlyph.SUN;
        }
        if (condition == Weather.CONDITION_PARTLY_CLOUDY) {
            return FaceWeatherGlyph.PARTLY_CLOUDY;
        }
        if (condition == Weather.CONDITION_RAIN
                || condition == Weather.CONDITION_THUNDERSTORMS
                || condition == Weather.CONDITION_SCATTERED_SHOWERS
                || condition == Weather.CONDITION_SCATTERED_THUNDERSTORMS
                || condition == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS
                || condition == Weather.CONDITION_UNKNOWN_PRECIPITATION
                || condition == Weather.CONDITION_LIGHT_RAIN
                || condition == Weather.CONDITION_HEAVY_RAIN
                || condition == Weather.CONDITION_LIGHT_SHOWERS
                || condition == Weather.CONDITION_SHOWERS
                || condition == Weather.CONDITION_HEAVY_SHOWERS
                || condition == Weather.CONDITION_CHANCE_OF_SHOWERS
                || condition == Weather.CONDITION_DRIZZLE
                || condition == Weather.CONDITION_FREEZING_RAIN
                || condition == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN
                || condition == Weather.CONDITION_HAIL) {
            return FaceWeatherGlyph.RAIN;
        }
        if (condition == Weather.CONDITION_SNOW
                || condition == Weather.CONDITION_WINTRY_MIX
                || condition == Weather.CONDITION_LIGHT_SNOW
                || condition == Weather.CONDITION_HEAVY_SNOW
                || condition == Weather.CONDITION_LIGHT_RAIN_SNOW
                || condition == Weather.CONDITION_HEAVY_RAIN_SNOW
                || condition == Weather.CONDITION_RAIN_SNOW) {
            return FaceWeatherGlyph.SNOW;
        }
        return FaceWeatherGlyph.CLOUD;
    }

    static function valueText(value as Complications.Value?) as String {
        if (value == null) { return "--"; }
        if (value instanceof Lang.String) { return value as String; }
        if (value instanceof Lang.Float || value instanceof Lang.Double) {
            return value.format("%.0f");
        }
        return value.toString();
    }

    static function numberOrNull(value as Object?) as Number? {
        if (value instanceof Lang.Number) { return value as Number; }
        if (value instanceof Lang.Long) { return value.toNumber(); }
        if (value instanceof Lang.Float) { return value.toNumber(); }
        if (value instanceof Lang.Double) { return value.toNumber(); }
        return null;
    }

    static function compactValue(value as Complications.Value?) as String {
        if (value == null) { return "--"; }
        var number = FaceFormatter.numberOrNull(value);
        if (number == null) {
            var text = value.toString();
            return text.length() > 6
                ? text.substring(0, 6) as String : text;
        }
        // Daily calories are commonly four digits. Keep every value through
        // 9999 whole so the display never turns 1123 kcal into a compact
        // value such as 1K.
        if (number > -10000 && number < 10000) {
            return number.format("%d");
        }
        if (number >= 10000 || number <= -10000) {
            return (number.toFloat() / 1000.0).format("%.1f") + "K";
        }
        return number.format("%d");
    }

    // A null complication is unavailable; zero is an explicitly published
    // measurement and must remain distinguishable from that state.
    static function wholeNumberText(value as Number?) as String {
        if (value == null) { return "--"; }
        return value.format("%d");
    }

    static function temperatureText(
            value as Complications.Value?, fahrenheit as Boolean) as String {
        if (value == null) { return "--"; }

        var degrees = null;
        if (value instanceof Lang.Number) {
            degrees = (value as Number).toFloat();
        } else if (value instanceof Lang.Long) {
            degrees = (value as Long).toFloat();
        } else if (value instanceof Lang.Float) {
            degrees = value as Float;
        } else if (value instanceof Lang.Double) {
            degrees = (value as Double).toFloat();
        }
        if (degrees == null) { return "--"; }

        if (fahrenheit) {
            degrees = degrees * 9.0 / 5.0 + 32.0;
        }
        return degrees.format("%.0f") + "°";
    }

    static function progressPercent(consumed as Number, target as Number) as Number {
        if (target <= 0 || consumed <= 0) { return 0; }
        var percent = ((consumed.toFloat() / target.toFloat()) * 100.0).toNumber();
        if (percent < 0) { return 0; }
        if (percent > 100) { return 100; }
        return percent;
    }

    static function propertyNumber(key as String, fallback as Number) as Number {
        try {
            var value = Application.Properties.getValue(key);
            var number = FaceFormatter.numberOrNull(value);
            return number != null ? number : fallback;
        } catch (error) {
            return fallback;
        }
    }
}
