import Toybox.Application;
import Toybox.Background;
import Toybox.System;
import Toybox.Time;

(:glance, :background)
class HydraFuelApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        HydrationStore.ensureToday();
    }

    function getInitialView() {
        System.println("HydraFuel getInitialView");
        registerBackgroundEvents();
        var view = new DashboardView();
        return [view, new DashboardDelegate(view)];
    }

    function getGlanceView() {
        System.println("HydraFuel getGlanceView");
        registerBackgroundEvents();
        return [new HydrationGlanceView()];
    }

    function getServiceDelegate() {
        return [new HydrationServiceDelegate()];
    }

    function onBackgroundData(data) {
        // Storage is shared; views reload it on their next redraw.
    }

    private function registerBackgroundEvents() {
        if (!(Toybox has :Background) || !(System has :ServiceDelegate)) {
            return;
        }

        try {
            if (Background.getTemporalEventRegisteredTime() == null) {
                Background.registerForTemporalEvent(new Time.Duration(30 * 60));
            }
            if ((Background has :registerForActivityCompletedEvent)
                    && !Background.getActivityCompletedEventRegistered()) {
                Background.registerForActivityCompletedEvent();
            }
        } catch (error) {
            System.println("Background unavailable");
        }
    }
}
