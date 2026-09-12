import Toybox.Lang;

(:glance, :background)
class DrinkCatalog {
    // Stable drink identifiers. Never reuse an identifier for a different
    // beverage because persisted history and phone commands depend on them.
    static const ID_WATER_250 = 1;
    static const ID_WATER_500 = 2;
    static const ID_WATER_1000 = 3;
    static const ID_JUNGLE = 4;
    static const ID_ESPRESSO = 5;
    static const ID_LONG_COFFEE = 6;
    static const ID_SUPERCOFFEE = 7;
    static const ID_MATCHA = 8;
    static const ID_MATTE_LEAO = 9;
    static const ID_JUICE = 10;
    static const ID_DIET_SODA = 11;
    static const ID_MONSTER_ZERO_473 = 12;
    static const ID_RED_BULL_250 = 13;
    static const ID_RED_BULL_ZERO_250 = 14;
    static const ID_RED_BULL_355 = 15;
    static const ID_RED_BULL_ZERO_355 = 16;
    static const ID_MONSTER_ZERO_355 = 17;

    // Stable source identifiers shared by watch input and phone sync.
    static const SOURCE_WATCH = 1;
    static const SOURCE_PHONE = 2;

    static function hydrationMl(drinkId as Number) as Number {
        if (drinkId == ID_WATER_250) { return 250; }
        if (drinkId == ID_WATER_500) { return 500; }
        if (drinkId == ID_WATER_1000) { return 1000; }
        if (drinkId == ID_JUNGLE) { return 500; }
        if (drinkId == ID_ESPRESSO) { return 50; }
        if (drinkId == ID_LONG_COFFEE) { return 110; }
        if (drinkId == ID_SUPERCOFFEE) { return 200; }
        if (drinkId == ID_MATCHA) { return 250; }
        if (drinkId == ID_MATTE_LEAO) { return 250; }
        if (drinkId == ID_JUICE) { return 250; }
        if (drinkId == ID_DIET_SODA) { return 315; }

        // Brazilian 473 ml can/variant reference: Monster Energy Zero Sugar,
        // 142 mg caffeine. Other markets and Monster variants can differ.
        if (drinkId == ID_MONSTER_ZERO_473) { return 473; }
        if (drinkId == ID_MONSTER_ZERO_355) { return 355; }
        if (drinkId == ID_RED_BULL_250) { return 250; }
        if (drinkId == ID_RED_BULL_ZERO_250) { return 250; }
        if (drinkId == ID_RED_BULL_355) { return 355; }
        if (drinkId == ID_RED_BULL_ZERO_355) { return 355; }
        return 0;
    }

    static function caffeineMg(drinkId as Number) as Number {
        if (drinkId == ID_ESPRESSO) { return 80; }
        if (drinkId == ID_LONG_COFFEE) { return 80; }
        if (drinkId == ID_SUPERCOFFEE) { return 200; }
        if (drinkId == ID_MATCHA) { return 30; }
        if (drinkId == ID_MATTE_LEAO) { return 20; }
        if (drinkId == ID_MONSTER_ZERO_473) { return 142; }
        if (drinkId == ID_MONSTER_ZERO_355) { return 107; }
        if (drinkId == ID_RED_BULL_250) { return 80; }
        if (drinkId == ID_RED_BULL_ZERO_250) { return 80; }
        if (drinkId == ID_RED_BULL_355) { return 112; }
        if (drinkId == ID_RED_BULL_ZERO_355) { return 112; }
        return 0;
    }

    static function isKnown(drinkId as Number) as Boolean {
        return drinkId == ID_WATER_250
            || drinkId == ID_WATER_500
            || drinkId == ID_WATER_1000
            || drinkId == ID_JUNGLE
            || drinkId == ID_ESPRESSO
            || drinkId == ID_LONG_COFFEE
            || drinkId == ID_SUPERCOFFEE
            || drinkId == ID_MATCHA
            || drinkId == ID_MATTE_LEAO
            || drinkId == ID_JUICE
            || drinkId == ID_DIET_SODA
            || drinkId == ID_MONSTER_ZERO_473
            || drinkId == ID_MONSTER_ZERO_355
            || drinkId == ID_RED_BULL_250
            || drinkId == ID_RED_BULL_ZERO_250
            || drinkId == ID_RED_BULL_355
            || drinkId == ID_RED_BULL_ZERO_355;
    }

    static function record(
            drinkId as Number, servings as Number,
            source as Number) as Boolean {
        if (!isKnown(drinkId)
                || servings < 1 || servings > 3
                || (source != SOURCE_WATCH && source != SOURCE_PHONE)) {
            return false;
        }

        return HydrationStore.recordDrink(
            drinkId,
            hydrationMl(drinkId) * servings,
            caffeineMg(drinkId) * servings,
            source);
    }
}
