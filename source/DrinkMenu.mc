import Toybox.WatchUi;
import Toybox.Lang;

class DrinkMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var mDashboardView;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        mDashboardView = view;
    }

    function onSelect(item) {
        var itemId = item.getId();
        if (itemId instanceof Lang.String) {
            var actionId = itemId as String;
            if (actionId.equals("test_notification")) {
                NotificationManager.notifyTest();
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            return;
        }

        if (!(itemId instanceof Lang.Number)) { return; }
        var drinkId = itemId as Number;
        if (!DrinkCatalog.isKnown(drinkId)) { return; }

        var current = HydrationStore.getNumber("waterMl");
        if (!DrinkCatalog.record(
                drinkId, 1, DrinkCatalog.SOURCE_WATCH)) { return; }

        var after = HydrationStore.getNumber("waterMl");
        var target = HydrationStore.dailyTargetMl();

        if (current < target && after >= target) {
            mDashboardView.triggerCelebration();
        }

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

class DrinkMenuBuilder {
    static function pushMenu(view) {
        var menu = new WatchUi.Menu2({:title=>WatchUi.loadResource(Rez.Strings.menu_title)});

        addDrink(menu, Rez.Strings.menu_water250,
            Rez.Strings.menu_water250_sub, DrinkCatalog.ID_WATER_250);
        addDrink(menu, Rez.Strings.menu_water500,
            Rez.Strings.menu_water500_sub, DrinkCatalog.ID_WATER_500);
        addDrink(menu, Rez.Strings.menu_water1000,
            Rez.Strings.menu_water1000_sub, DrinkCatalog.ID_WATER_1000);
        addDrink(menu, Rez.Strings.menu_jungle,
            Rez.Strings.menu_jungle_sub, DrinkCatalog.ID_JUNGLE);
        addDrink(menu, Rez.Strings.menu_espresso,
            Rez.Strings.menu_espresso_sub, DrinkCatalog.ID_ESPRESSO);
        addDrink(menu, Rez.Strings.menu_cafelongo,
            Rez.Strings.menu_cafelongo_sub, DrinkCatalog.ID_LONG_COFFEE);
        addDrink(menu, Rez.Strings.menu_supercoffee,
            Rez.Strings.menu_supercoffee_sub, DrinkCatalog.ID_SUPERCOFFEE);
        addDrink(menu, Rez.Strings.menu_monsterzero,
            Rez.Strings.menu_monsterzero_sub,
            DrinkCatalog.ID_MONSTER_ZERO_473);
        addDrink(menu, Rez.Strings.menu_monsterzero_sm,
            Rez.Strings.menu_monsterzero_sm_sub,
            DrinkCatalog.ID_MONSTER_ZERO_355);
        addDrink(menu, Rez.Strings.menu_redbull_zero,
            Rez.Strings.menu_redbull_zero_sub,
            DrinkCatalog.ID_RED_BULL_ZERO_250);
        addDrink(menu, Rez.Strings.menu_redbull_zero_big,
            Rez.Strings.menu_redbull_zero_big_sub,
            DrinkCatalog.ID_RED_BULL_ZERO_355);
        addDrink(menu, Rez.Strings.menu_matcha,
            Rez.Strings.menu_matcha_sub, DrinkCatalog.ID_MATCHA);
        addDrink(menu, Rez.Strings.menu_matteleao,
            Rez.Strings.menu_matteleao_sub, DrinkCatalog.ID_MATTE_LEAO);
        addDrink(menu, Rez.Strings.menu_suco,
            Rez.Strings.menu_suco_sub, DrinkCatalog.ID_JUICE);
        addDrink(menu, Rez.Strings.menu_refrizero,
            Rez.Strings.menu_refrizero_sub, DrinkCatalog.ID_DIET_SODA);

        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_test_notification),
            "",
            "test_notification",
            {}
        ));

        WatchUi.pushView(menu, new DrinkMenuDelegate(view), WatchUi.SLIDE_UP);
    }

    private static function addDrink(menu, title, subtitle, drinkId) as Void {
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(title),
            WatchUi.loadResource(subtitle),
            drinkId,
            {}
        ));
    }
}
