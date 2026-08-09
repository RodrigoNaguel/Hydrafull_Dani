import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.UserProfile;

(:glance, :background)
class WellnessReader {
    static function weightKg() as Float {
        try {
            var profile = UserProfile.getProfile();
            var weight = profile.weight;
            if (weight != null && weight > 0) {
                return weight.toFloat() / 1000.0;
            }
        } catch (error) {}
        return AppConfig.DEFAULT_WEIGHT_KG;
    }

    static function currentStress() {
        try {
            if ((Toybox has :SensorHistory)
                    && (Toybox.SensorHistory has :getStressHistory)) {
                var iterator = SensorHistory.getStressHistory({ :period => 1 });
                var sample = iterator.next();
                if (sample != null) { return sample.data; }
            }
        } catch (error) {}
        return null;
    }

    static function latestBodyBattery() {
        try {
            if ((Toybox has :SensorHistory)
                    && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                var iterator = SensorHistory.getBodyBatteryHistory({ :period => 1 });
                var sample = iterator.next();
                if (sample != null) { return sample.data; }
            }
        } catch (error) {}
        return null;
    }
}
