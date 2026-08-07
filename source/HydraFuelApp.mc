import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

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

        var dashboardView = new DashboardView();
        var statsView = new StatsView();

        var viewPager = new ViewPager();
        viewPager.setViews([dashboardView, statsView]);
        viewPager.setProhibitSwipe(false); // Allow swiping

        var viewPagerIndicator = new PageIndicator();
        viewPagerIndicator.setDotCount(2);
        viewPagerIndicator.setDot(0, PAGE_INDICATOR_DOT_LIGHT);
        viewPagerIndicator.setDot(1, PAGE_INDICATOR_DOT_DARK);
        viewPager.setIndicator(viewPagerIndicator);
        
        return [viewPager, new BaseDelegate(viewPager)];
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
