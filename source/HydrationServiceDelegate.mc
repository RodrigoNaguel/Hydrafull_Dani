import Toybox.ActivityMonitor;
import Toybox.Background;
import Toybox.SensorHistory;
import Toybox.System;

(:background)
class HydrationServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() {
        snapshotAndExit("temporal");
    }

    function onActivityCompleted(activity) {
        snapshotAndExit("activity");
    }

    private function snapshotAndExit(reason) {
        var calories = null;
        var stress = null;
        var bodyBattery = null;

        try {
            var info = ActivityMonitor.getInfo();
            if (info.calories != null) { calories = info.calories; }
        } catch (error) {}

        try {
            if ((Toybox has :SensorHistory)
                    && (Toybox.SensorHistory has :getStressHistory)) {
                var stressIterator = SensorHistory.getStressHistory({ :period => 1 });
                var stressSample = stressIterator.next();
                if (stressSample != null) { stress = stressSample.data; }
            }
            if ((Toybox has :SensorHistory)
                    && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                var iterator = SensorHistory.getBodyBatteryHistory({ :period => 1 });
                var sample = iterator.next();
                if (sample != null) { bodyBattery = sample.data; }
            }
        } catch (error) {}

        try {
            HydrationStore.saveWellnessSnapshot(calories, stress, bodyBattery);
        } catch (error) {}
        Background.exit({ "reason" => reason, "updated" => true });
    }
}
