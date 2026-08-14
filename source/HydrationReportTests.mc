import Toybox.Lang;
import Toybox.Test;

(:test)
function testHydrationReportSevenDays(logger as Test.Logger) as Boolean {
    var records = [
        100, 1000, 2000, 50,
        101, 2000, 2000, 100,
        102, 3000, 2500, 150,
        103, 1000, 2000, 50,
        104, 2000, 2000, 100,
        105, 3000, 2500, 150,
        106, 2000, 2500, 100
    ] as Array<Number>;
    var report = HydrationReport.build(records, 100, 106, 1);
    logger.debug("seven-day report=" + report);

    return report.size() == 8
        && report[HydrationReport.INDEX_AVERAGE_HYDRATION] == 2000
        && report[HydrationReport.INDEX_MINIMUM_HYDRATION] == 1000
        && report[HydrationReport.INDEX_MAXIMUM_HYDRATION] == 3000
        && report[HydrationReport.INDEX_GOALS_REACHED] == 4
        && report[HydrationReport.INDEX_DAY_COUNT] == 7
        && report[HydrationReport.INDEX_AVERAGE_CAFFEINE] == 100;
}

(:test)
function testHydrationReportBucketsAreChronological(
        logger as Test.Logger) as Boolean {
    var records = [
        100, 1000, 2000, 50,
        101, 2000, 2000, 100,
        102, 3000, 2500, 150,
        103, 1000, 2000, 50,
        104, 2000, 2000, 100,
        105, 3000, 2500, 150,
        106, 2000, 2500, 100
    ] as Array<Number>;
    var report = HydrationReport.build(records, 100, 106, 3);
    logger.debug("bucket report=" + report);

    return report.size() == 12
        && report[HydrationReport.bucketHydrationIndex(0)] == 2000
        && report[HydrationReport.bucketTargetIndex(0)] == 2166
        && report[HydrationReport.bucketHydrationIndex(1)] == 1500
        && report[HydrationReport.bucketTargetIndex(1)] == 2000
        && report[HydrationReport.bucketHydrationIndex(2)] == 2500
        && report[HydrationReport.bucketTargetIndex(2)] == 2500;
}

(:test)
function testHydrationReportMissingDaysCountAsZero(
        logger as Test.Logger) as Boolean {
    var records = [
        200, 2100, 2000, 100,
        202, 1000, 2000, 50
    ] as Array<Number>;
    var report = HydrationReport.build(records, 200, 202, 3);
    logger.debug("missing-day report=" + report);

    return report[HydrationReport.INDEX_AVERAGE_HYDRATION] == 1033
        && report[HydrationReport.INDEX_MINIMUM_HYDRATION] == 0
        && report[HydrationReport.INDEX_MAXIMUM_HYDRATION] == 2100
        && report[HydrationReport.INDEX_GOALS_REACHED] == 1
        && report[HydrationReport.INDEX_DAY_COUNT] == 3
        && report[HydrationReport.INDEX_AVERAGE_CAFFEINE] == 50
        && report[HydrationReport.bucketHydrationIndex(0)] == 2100
        && report[HydrationReport.bucketTargetIndex(0)] == 2000
        && report[HydrationReport.bucketHydrationIndex(1)] == 0
        && report[HydrationReport.bucketTargetIndex(1)] == 0
        && report[HydrationReport.bucketHydrationIndex(2)] == 1000
        && report[HydrationReport.bucketTargetIndex(2)] == 2000;
}

(:test)
function testHydrationReportPartialPeriodAlignsTodayRight(
        logger as Test.Logger) as Boolean {
    var records = [106, 1800, 2000, 80] as Array<Number>;
    var report = HydrationReport.build(records, 100, 106, 7);
    logger.debug("partial-period report=" + report);

    return report[HydrationReport.bucketHydrationIndex(0)] == 0
        && report[HydrationReport.bucketHydrationIndex(5)] == 0
        && report[HydrationReport.bucketHydrationIndex(6)] == 1800
        && report[HydrationReport.bucketTargetIndex(6)] == 2000;
}

(:test)
function testHydrationReportFiltersOutsidePeriod(
        logger as Test.Logger) as Boolean {
    var records = [
        299, 9000, 1000, 900,
        300, 1000, 2000, 10,
        301, 2000, 2000, 20,
        302, 3000, 2500, 30,
        303, 9000, 1000, 900
    ] as Array<Number>;
    var report = HydrationReport.build(records, 300, 302, 1);
    logger.debug("period-filter report=" + report);

    return report[HydrationReport.INDEX_AVERAGE_HYDRATION] == 2000
        && report[HydrationReport.INDEX_MINIMUM_HYDRATION] == 1000
        && report[HydrationReport.INDEX_MAXIMUM_HYDRATION] == 3000
        && report[HydrationReport.INDEX_GOALS_REACHED] == 2
        && report[HydrationReport.INDEX_DAY_COUNT] == 3
        && report[HydrationReport.INDEX_AVERAGE_CAFFEINE] == 20
        && report[HydrationReport.bucketHydrationIndex(0)] == 2000
        && report[HydrationReport.bucketTargetIndex(0)] == 2166;
}

(:test)
function testHydrationReportRejectsInvalidInput(
        logger as Test.Logger) as Boolean {
    var malformed = [1, 2000, 2500] as Array<Number>;
    var invalidValues = [
        10, -1, 2000, 0,
        11, 1000, -1, 0,
        12, 1000, 2000, -1
    ] as Array<Number>;
    var invalidRange = HydrationReport.build(malformed, 2, 1, 1);
    var invalidBuckets = HydrationReport.build(malformed, 1, 2, 0);
    var ignoredRecords = HydrationReport.build(invalidValues, 10, 12, 1);
    logger.debug("invalid records report=" + ignoredRecords);

    return invalidRange.size() == 0
        && invalidBuckets.size() == 0
        && ignoredRecords.size() == 8
        && ignoredRecords[HydrationReport.INDEX_AVERAGE_HYDRATION] == 0
        && ignoredRecords[HydrationReport.INDEX_MINIMUM_HYDRATION] == 0
        && ignoredRecords[HydrationReport.INDEX_MAXIMUM_HYDRATION] == 0
        && ignoredRecords[HydrationReport.INDEX_GOALS_REACHED] == 0
        && ignoredRecords[HydrationReport.INDEX_DAY_COUNT] == 3
        && ignoredRecords[HydrationReport.INDEX_AVERAGE_CAFFEINE] == 0;
}
