import Toybox.ActivityMonitor;
import Toybox.Background;
import Toybox.Lang;
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

    private function snapshotAndExit(reason as String) {
        var exitReason = reason;
        try {
            HydrationStore.ensureToday();
            var phoneDrinkAdded = PhoneDrinkBridge.processPending();
            var lastSnapshotAt = HydrationStore.getNumber("lastSnapshotAt");
            var snapshotDue = reason.equals("activity")
                || lastSnapshotAt <= 0
                || (Toybox.Time.now().value() - lastSnapshotAt)
                    >= AppConfig.WELLNESS_SNAPSHOT_INTERVAL_SEC;
            if (snapshotDue) {
                snapshotWellness();
            }
            var evaluation = HydrationReminderEngine.evaluateAndNotify();
            exitReason = reason + "/" + evaluation;
            if (phoneDrinkAdded) { exitReason += "/phone-added"; }
            HydrationStore.recordBackgroundRun(exitReason);
        } catch (error) {
            System.println("[HydraFuel] Background service error: " + error);
            exitReason = reason + "/error";
            try {
                HydrationStore.recordBackgroundRun(exitReason);
            } catch (storageError) {}
        }
        Background.exit(exitReason);
    }

    private function snapshotWellness() as Void {
        var calories = null;
        var stress = null;
        var bodyBattery = null;

        try {
            var info = ActivityMonitor.getInfo();
            var dailyCalories = info.calories;
            if (dailyCalories != null) { calories = dailyCalories; }
        } catch (error) {}

        try {
            if ((Toybox has :SensorHistory)
                    && (Toybox.SensorHistory has :getStressHistory)) {
                var stressIterator = SensorHistory.getStressHistory({ :period => 1 });
                var stressSample = stressIterator.next();
                if (stressSample != null) { stress = stressSample.data; }
            }
        } catch (error) {}

        try {
            if ((Toybox has :SensorHistory)
                    && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                var iterator = SensorHistory.getBodyBatteryHistory({ :period => 1 });
                var sample = iterator.next();
                if (sample != null) { bodyBattery = sample.data; }
            }
        } catch (error) {}

        HydrationStore.saveWellnessSnapshot(calories, stress, bodyBattery);
    }
}
