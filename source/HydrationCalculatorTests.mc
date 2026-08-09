import Toybox.Lang;
import Toybox.Test;

(:test)
function testBaselineWaterTargetIsClamped(logger as Test.Logger) as Boolean {
    logger.debug("checking baseline target limits");
    return HydrationCalculator.baselineWaterMl(40.0) == 1600.0
        && HydrationCalculator.baselineWaterMl(70.0) == 2100.0
        && HydrationCalculator.baselineWaterMl(120.0) == 3000.0;
}

(:test)
function testActivityCaloriesIncreaseTarget(logger as Test.Logger) as Boolean {
    var target = HydrationCalculator.adjustedWaterMl(70.0, 2000);
    logger.debug("adjusted target = " + target);
    return target > 2419.9 && target < 2420.1;
}

(:test)
function testMeasuredSweatRate(logger as Test.Logger) as Boolean {
    var rate = HydrationCalculator.measuredSweatRateLh(
        70.0, 69.5, 0.5, 0.0, 1.0);
    logger.debug("measured sweat rate = " + rate);
    return rate != null && rate > 0.99 && rate < 1.01;
}

(:test)
function testInvalidSweatDuration(logger as Test.Logger) as Boolean {
    logger.debug("checking invalid sweat-test duration");
    return HydrationCalculator.measuredSweatRateLh(
        70.0, 69.5, 0.5, 0.0, 0.0) == null;
}

(:test)
function testCaffeineWarningsAreConservative(logger as Test.Logger) as Boolean {
    logger.debug("checking caffeine warning caps");
    return HydrationCalculator.caffeineSingleWarningMg(50.0) == 150.0
        && HydrationCalculator.caffeineSingleWarningMg(80.0) == 200
        && HydrationCalculator.caffeineDailyWarningMg(50.0) == 285.0
        && HydrationCalculator.caffeineDailyWarningMg(80.0) == 400;
}
