import Toybox.Complications;
import Toybox.Application;
import Toybox.Lang;

class FaceFormatter {
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
