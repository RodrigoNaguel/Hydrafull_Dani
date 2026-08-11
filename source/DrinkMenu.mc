import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;

class DrinkMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var mDashboardView;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        mDashboardView = view;
    }

    function onSelect(item) {
        var itemId = item.getId();
        if (!(itemId instanceof Lang.String)) { return; }
        var id = itemId as String;
        if (id.length() >= 10 && id.substring(0, 10).equals("separator_")) {
            return;
        }
        if (id.equals("test_notification")) {
            NotificationManager.notifyTest();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return;
        }

        var weight = WellnessReader.weightKg();
        var calories = HydrationStore.getNumber("lastCalories");
        var stress = HydrationStore.getNumber("lastStress");
        var bodyBattery = HydrationStore.getNumber("lastBodyBattery");
        var caffeine = HydrationStore.getNumber("caffeineTodayMg");
        var target = HydrationCalculator.adjustedWaterMl(
            weight, calories, stress, bodyBattery, caffeine).toNumber();
        var current = HydrationStore.getNumber("waterMl");

        // Water amounts
        if (id.equals("water250")) {
            HydrationStore.addWater(250);
        } else if (id.equals("water500")) {
            HydrationStore.addWater(500);
        } else if (id.equals("water1000")) {
            HydrationStore.addWater(1000);
        // Electrolytes
        } else if (id.equals("jungle")) {
            HydrationStore.addWater(500);
        // Coffees
        } else if (id.equals("espresso")) {
            HydrationStore.addWater(50);
            HydrationStore.addCaffeine(80);
        } else if (id.equals("cafelongo")) {
            HydrationStore.addWater(110);
            HydrationStore.addCaffeine(80);
        } else if (id.equals("supercoffee")) {
            HydrationStore.addWater(200);
            HydrationStore.addCaffeine(200);
        // Teas
        } else if (id.equals("matcha")) {
            HydrationStore.addWater(250);
            HydrationStore.addCaffeine(30);
        } else if (id.equals("matteleao")) {
            HydrationStore.addWater(250);
            HydrationStore.addCaffeine(20);        // Others
        } else if (id.equals("suco")) {
            HydrationStore.addWater(250);
        } else if (id.equals("refrizero")) {
            HydrationStore.addWater(315); // ~90% of 350ml
        }

        var after = HydrationStore.getNumber("waterMl");

        if (current < target && after >= target) {
            mDashboardView.triggerCelebration();
        }

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

class DrinkMenuBuilder {
    static function pushMenu(view) {
        var menu = new WatchUi.Menu2({:title=>WatchUi.loadResource(Rez.Strings.menu_title)});

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_water250),
            WatchUi.loadResource(Rez.Strings.menu_water250_sub),
            "water250",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_water500),
            WatchUi.loadResource(Rez.Strings.menu_water500_sub),
            "water500",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_water1000),
            WatchUi.loadResource(Rez.Strings.menu_water1000_sub),
            "water1000",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_jungle),
            WatchUi.loadResource(Rez.Strings.menu_jungle_sub),
            "jungle",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_espresso),
            WatchUi.loadResource(Rez.Strings.menu_espresso_sub),
            "espresso",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_cafelongo),
            WatchUi.loadResource(Rez.Strings.menu_cafelongo_sub),
            "cafelongo",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_supercoffee),
            WatchUi.loadResource(Rez.Strings.menu_supercoffee_sub),
            "supercoffee",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_matcha),
            WatchUi.loadResource(Rez.Strings.menu_matcha_sub),
            "matcha",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_matteleao),
            WatchUi.loadResource(Rez.Strings.menu_matteleao_sub),
            "matteleao",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_suco),
            WatchUi.loadResource(Rez.Strings.menu_suco_sub),
            "suco",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_refrizero),
            WatchUi.loadResource(Rez.Strings.menu_refrizero_sub),
            "refrizero",
            {}
        ));

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_test_notification),
            "",
            "test_notification",
            {}
        ));

        WatchUi.pushView(menu, new DrinkMenuDelegate(view), WatchUi.SLIDE_UP);
    }
}
