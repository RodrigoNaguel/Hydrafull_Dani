import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

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
                if (NotificationManager.notifyTest()) {
                    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                } else {
                    WatchUi.showToast(
                        Rez.Strings.notification_test_failed, null);
                }
            } else if (actionId.equals("undo_drink")) {
                var snapshot = HydrationStore.lastDrinkForUndo();
                if (snapshot == null) {
                    WatchUi.showToast(Rez.Strings.drink_undo_unavailable, null);
                    return;
                }
                DrinkMenuBuilder.pushConfirmation(mDashboardView,
                    snapshot[3], snapshot);
            }
            return;
        }

        if (!(itemId instanceof Lang.Number)) { return; }
        var drinkId = itemId as Number;
        if (!DrinkCatalog.isKnown(drinkId)) { return; }

        DrinkMenuBuilder.pushConfirmation(mDashboardView, drinkId, null);
    }
}

// Selecting a drink only prepares this menu. Storage changes happen once,
// after the user explicitly chooses the confirmation action.
class DrinkConfirmationDelegate extends WatchUi.Menu2InputDelegate {
    private var mDashboardView;
    private var mDrinkId as Number;
    private var mUndoSnapshot as Array<Number>?;
    private var mHandled as Boolean = false;

    function initialize(view, drinkId as Number, snapshot as Array<Number>?) {
        Menu2InputDelegate.initialize();
        mDashboardView = view;
        mDrinkId = drinkId;
        mUndoSnapshot = snapshot;
    }

    function onSelect(item) {
        if (mHandled) { return; }
        var action = item.getId();
        if ("cancel".equals(action)) {
            mHandled = true;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        if (!"confirm".equals(action)) { return; }
        mHandled = true;

        var celebrate = false;
        var snapshot = mUndoSnapshot;
        try {
            var current = HydrationStore.getNumber("waterMl");
            var changed = snapshot != null
                ? HydrationStore.undoLastDrink(snapshot)
                : DrinkCatalog.record(mDrinkId, 1, DrinkCatalog.SOURCE_WATCH);
            if (!changed) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                WatchUi.showToast(snapshot != null
                    ? Rez.Strings.drink_undo_unavailable
                    : Rez.Strings.drink_save_failed, null);
                return;
            }
            if (snapshot == null) {
                var after = HydrationStore.getNumber("waterMl");
                var target = HydrationStore.dailyTargetMl();
                celebrate = current < target && after >= target;
            }
        } catch (error) {
            System.println("[HydraFuel] Drink action error: " + error);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.showToast(Rez.Strings.drink_save_failed, null);
            WatchUi.requestUpdate();
            return;
        }

        // Close the confirmation and the beverage menu, returning to the
        // dashboard. Cancellation/back only closes the confirmation.
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (celebrate) { mDashboardView.triggerCelebration(); }
        WatchUi.requestUpdate();
    }
}

class DrinkMenuBuilder {
    static function pushMenu(view) {
        var menu = new WatchUi.Menu2({:title=>WatchUi.loadResource(Rez.Strings.menu_title)});

        var hasUndo = HydrationStore.lastDrinkForUndo() != null;
        if (hasUndo) {
            menu.addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.drink_undo_last),
                WatchUi.loadResource(Rez.Strings.drink_today), "undo_drink", {}));
        }

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

        // Set focus only after the indexed item has been added.
        if (hasUndo) { menu.setFocus(1); }
        WatchUi.pushView(menu, new DrinkMenuDelegate(view), WatchUi.SLIDE_UP);
    }

    static function pushConfirmation(view, drinkId as Number,
            snapshot as Array<Number>?) as Void {
        var hydration = snapshot == null
            ? DrinkCatalog.hydrationMl(drinkId) : snapshot[4];
        var caffeine = snapshot == null
            ? DrinkCatalog.caffeineMg(drinkId) : snapshot[5];
        var title = WatchUi.loadResource(drinkTitle(drinkId)) as String;
        if (snapshot != null) {
            var date = Gregorian.info(new Time.Moment(snapshot[2]), Time.FORMAT_SHORT);
            title += " " + date.hour.format("%02d") + ":" + date.min.format("%02d");
        }
        var detail = hydration.format("%d") + " ml | "
            + caffeine.format("%d") + " mg";
        var menu = new WatchUi.Menu2({ :title => title });
        // Cancel is the initial selection so a repeated button press cannot
        // confirm an accidental drink or remove one without review.
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.drink_cancel), detail, "cancel", {}));
        menu.addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(snapshot == null
                ? Rez.Strings.drink_register : Rez.Strings.drink_undo_confirm),
            detail, "confirm", {}));
        WatchUi.pushView(menu, new DrinkConfirmationDelegate(view, drinkId, snapshot),
            WatchUi.SLIDE_IMMEDIATE);
    }

    private static function drinkTitle(drinkId as Number) as ResourceId {
        switch (drinkId) {
            case DrinkCatalog.ID_WATER_250: return Rez.Strings.menu_water250;
            case DrinkCatalog.ID_WATER_500: return Rez.Strings.menu_water500;
            case DrinkCatalog.ID_WATER_1000: return Rez.Strings.menu_water1000;
            case DrinkCatalog.ID_JUNGLE: return Rez.Strings.menu_jungle;
            case DrinkCatalog.ID_ESPRESSO: return Rez.Strings.menu_espresso;
            case DrinkCatalog.ID_LONG_COFFEE: return Rez.Strings.menu_cafelongo;
            case DrinkCatalog.ID_SUPERCOFFEE: return Rez.Strings.menu_supercoffee;
            case DrinkCatalog.ID_MONSTER_ZERO_473: return Rez.Strings.menu_monsterzero;
            case DrinkCatalog.ID_MONSTER_ZERO_355: return Rez.Strings.menu_monsterzero_sm;
            case DrinkCatalog.ID_RED_BULL_250: return Rez.Strings.menu_redbull;
            case DrinkCatalog.ID_RED_BULL_ZERO_250: return Rez.Strings.menu_redbull_zero;
            case DrinkCatalog.ID_RED_BULL_355: return Rez.Strings.menu_redbull_big;
            case DrinkCatalog.ID_RED_BULL_ZERO_355: return Rez.Strings.menu_redbull_zero_big;
            case DrinkCatalog.ID_MATCHA: return Rez.Strings.menu_matcha;
            case DrinkCatalog.ID_MATTE_LEAO: return Rez.Strings.menu_matteleao;
            case DrinkCatalog.ID_JUICE: return Rez.Strings.menu_suco;
            case DrinkCatalog.ID_DIET_SODA: return Rez.Strings.menu_refrizero;
        }
        return Rez.Strings.drink_generic;
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
