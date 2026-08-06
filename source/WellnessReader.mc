import Toybox.SensorHistory;
import Toybox.UserProfile;

class WellnessReader {
    static function weightKg() {
        try {
            var profile = UserProfile.getProfile();
            if (profile.weight != null && profile.weight > 0) {
                return profile.weight.toFloat() / 1000.0;
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
