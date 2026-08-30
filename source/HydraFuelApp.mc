import Toybox.Application;
import Toybox.Background;
import Toybox.Notifications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:glance, :background)
class HydraFuelApp extends Application.AppBase {
    public var launchDrinkMenu as Boolean = false;
    public var mDashboardView = null;
    public var foregroundUiReady as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        HydrationStore.ensureToday();
        PhoneDrinkBridge.processPending();
        HydrationComplicationPublisher.publishCurrent();
        registerBackgroundEvents();

        if (state != null
                && state.hasKey(:launchedFromNotification)
                && NotificationManager.ACTION_OPEN_ADD_DRINK.equals(
                    state[:launchedFromNotification])) {
            launchDrinkMenu = true;
        }
    }

    function onSettingsChanged() as Void {
        if (PhoneDrinkBridge.processPending()) {
            WatchUi.requestUpdate();
        }
        HydrationComplicationPublisher.publishCurrent();
    }

    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function onNotificationMessage(message as Notifications.NotificationMessage) as Void {
        if (message.type == Notifications.NOTIFICATION_MESSAGE_TYPE_SELECTED) {
            if (NotificationManager.ACTION_OPEN_ADD_DRINK.equals(
                    message.action)) {
                launchDrinkMenu = true;
                if (foregroundUiReady && mDashboardView != null) {
                    try {
                        launchDrinkMenu = false;
                        DrinkMenuBuilder.pushMenu(mDashboardView);
                    } catch (error) {
                        launchDrinkMenu = true;
                        System.println("[HydraFuel] Notification action error: "
                            + error);
                    }
                }
            }
        }
    }

    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function getInitialView() {
        var dashboardView = new $.DashboardView();
        mDashboardView = dashboardView;
        var statsView = new $.StatsView();
        var historyView = new $.HistoryView();

        var viewPager = new $.ViewPager();
        viewPager.setViews([dashboardView, statsView, historyView]);
        viewPager.setProhibitSwipe(false); // Allow swiping

        var viewPagerIndicator = new $.PageIndicator();
        viewPagerIndicator.setDotCount(3);
        viewPagerIndicator.setDot(0, PAGE_INDICATOR_DOT_LIGHT);
        viewPagerIndicator.setDot(1, PAGE_INDICATOR_DOT_DARK);
        viewPagerIndicator.setDot(2, PAGE_INDICATOR_DOT_DARK);
        viewPager.setIndicator(viewPagerIndicator);

        if (Toybox has :Notifications
                && Toybox.Notifications has :registerForNotificationMessages) {
            try {
                Toybox.Notifications.registerForNotificationMessages(
                    method(:onNotificationMessage));
            } catch (error) {
                System.println("[HydraFuel] Notification callback error: "
                    + error);
            }
        }
        
        return [viewPager, new $.BaseDelegate(viewPager)];
    }

    (:typecheck(disableBackgroundCheck))
    function getGlanceView() {
        registerBackgroundEvents();
        return [new $.HydrationGlanceView()];
    }

    (:typecheck(disableGlanceCheck))
    function getServiceDelegate() {
        return [new $.HydrationServiceDelegate()];
    }

    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function onBackgroundData(data) {
        // Storage is shared; redraw the active foreground view with the
        // snapshot produced by the background service.
        WatchUi.requestUpdate();
    }

    private function registerBackgroundEvents() {
        if (!(Toybox has :Background) || !(System has :ServiceDelegate)) {
            System.println("[HydraFuel] Background API unavailable");
            return;
        }

        try {
            var registered = Background.getTemporalEventRegisteredTime();
            var needsTemporalRegistration = registered == null;
            if (registered instanceof Time.Duration) {
                needsTemporalRegistration = registered.value()
                    != AppConfig.REMINDER_CHECK_INTERVAL_SEC;
            } else if (registered != null) {
                // Replace a one-shot Moment with the configured periodic event.
                needsTemporalRegistration = true;
            }

            if (needsTemporalRegistration) {
                Background.registerForTemporalEvent(
                    new Time.Duration(AppConfig.REMINDER_CHECK_INTERVAL_SEC));
            }
            if ((Background has :registerForActivityCompletedEvent)
                    && ((!(Background has :getActivityCompletedEventRegistered))
                        || !Background.getActivityCompletedEventRegistered())) {
                Background.registerForActivityCompletedEvent();
            }
        } catch (error) {
            System.println("[HydraFuel] Background registration failed: " + error);
        }
    }
}

class BaseDelegate extends WatchUi.BehaviorDelegate {
    private var _viewPager as ViewPager;

    public function initialize(viewPager as ViewPager) {
        BehaviorDelegate.initialize();
        _viewPager = viewPager;
    }

    public function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    public function onSelect() {
        // The select action is now handled by the active view in the ViewPager
        var activeView = _viewPager.getActiveView();
        if (activeView instanceof DashboardView) {
            DrinkMenuBuilder.pushMenu(activeView);
        } else if (activeView instanceof HistoryView) {
            activeView.cyclePeriod();
        }
        return true;
    }

    public function onNextPage() as Boolean {
        _viewPager.switchToNextPage();
        return true;
    }

    public function onPreviousPage() as Boolean {
        _viewPager.switchToPreviousPage();
        return true;
    }

}
