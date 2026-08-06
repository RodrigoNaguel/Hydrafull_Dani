import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:glance, :background)
class HydrationStore {
    static function dayKey() {
        var date = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return date.year.format("%04d")
            + date.month.format("%02d")
            + date.day.format("%02d");
    }

    static function ensureToday() {
        var today = dayKey();
        if (!today.equals(Storage.getValue("day"))) {
            Storage.setValue("day", today);
            Storage.setValue("waterMl", 0);
            Storage.setValue("caffeineTodayMg", 0);
        }
        pruneCaffeineEvents();
    }

    static function getNumber(key) {
        ensureToday();
        var value = Storage.getValue(key);
        return value instanceof Lang.Number ? value : 0;
    }

    static function addWater(ml) {
        ensureToday();
        Storage.setValue("waterMl", getNumber("waterMl") + ml);
    }

    static function addCaffeine(mg as Number) {
        ensureToday();
        var events = loadCaffeineEvents();
        // Store flat timestamp/dose pairs. A homogeneous Array<Number>
        // keeps Monkey Types precise and is valid for Application.Storage.
        if (events.size() >= 192) {
            var trimmed = [] as Array<Number>;
            var start = events.size() - 190;
            if ((start % 2) != 0) { start += 1; }
            for (var i = start; i + 1 < events.size(); i += 2) {
                trimmed.add(events[i]);
                trimmed.add(events[i + 1]);
            }
            events = trimmed;
        }
        events.add(Time.now().value());
        events.add(mg);
        Storage.setValue("caffeineEventsV2", events);
        Storage.setValue("caffeineTodayMg", getNumber("caffeineTodayMg") + mg);
    }

    static function caffeineRemaining(halfLifeHours) {
        ensureToday();
        var events = loadCaffeineEvents();
        if (halfLifeHours <= 0) {
            return 0.0;
        }

        var now = Time.now().value();
        var remaining = 0.0;
        for (var i = 0; i + 1 < events.size(); i += 2) {
            var elapsedHours = (now - events[i]).toFloat() / 3600.0;
            remaining += events[i + 1]
                * Math.pow(0.5, elapsedHours / halfLifeHours);
        }
        return remaining;
    }

    static function saveWellnessSnapshot(calories, stress, bodyBattery) {
        if (calories != null) { Storage.setValue("lastCalories", calories); }
        if (stress != null) { Storage.setValue("lastStress", stress); }
        if (bodyBattery != null) { Storage.setValue("lastBodyBattery", bodyBattery); }
        Storage.setValue("lastSnapshotAt", Time.now().value());
    }

    private static function pruneCaffeineEvents() {
        var events = loadCaffeineEvents();
        if (events.size() == 0) { return; }

        var cutoff = Time.now().value() - (48 * 3600);
        var kept = [] as Array<Number>;
        for (var i = 0; i + 1 < events.size(); i += 2) {
            if (events[i] >= cutoff) {
                kept.add(events[i]);
                kept.add(events[i + 1]);
            }
        }
        if (kept.size() != events.size()) {
            Storage.setValue("caffeineEventsV2", kept);
        }
    }

    private static function loadCaffeineEvents() as Array<Number> {
        var stored = Storage.getValue("caffeineEventsV2");
        if (stored instanceof Lang.Array) {
            return stored as Array<Number>;
        }
        return [] as Array<Number>;
    }
}
