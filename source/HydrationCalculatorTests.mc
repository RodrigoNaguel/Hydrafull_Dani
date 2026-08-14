import Toybox.Lang;
import Toybox.Test;

(:test)
function testBaselineWaterTargetIsClamped(logger as Test.Logger) as Boolean {
    logger.debug("checking baseline target limits");
    // 35ml/kg: 40kg -> 1400 -> clamped to 1800; 70kg -> 2450;
    // 150kg -> 5250 -> clamped to 5000.
    return HydrationCalculator.baselineWaterMl(40.0) == 1800.0
        && HydrationCalculator.baselineWaterMl(70.0) == 2450.0
        && HydrationCalculator.baselineWaterMl(150.0) == 5000.0;
}

(:test)
function testActivityCaloriesIncreaseTarget(logger as Test.Logger) as Boolean {
    var target = HydrationCalculator.adjustedWaterMl(70.0, 2000, null, null, null);
    logger.debug("adjusted target = " + target);
    return target > 3089.9 && target < 3090.1;
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
