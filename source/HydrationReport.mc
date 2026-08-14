import Toybox.Lang;

// Pure aggregation for stored daily hydration records.
//
// Input records use a flat, storage-friendly stride of four values:
// [dayOrdinal, hydrationMl, targetMl, caffeineMg]. A repeated day replaces
// the earlier value, which makes replaying the same daily snapshot idempotent.
class HydrationReport {
    static const RECORD_STRIDE = 4;

    static const INDEX_AVERAGE_HYDRATION = 0;
    static const INDEX_MINIMUM_HYDRATION = 1;
    static const INDEX_MAXIMUM_HYDRATION = 2;
    static const INDEX_GOALS_REACHED = 3;
    static const INDEX_DAY_COUNT = 4;
    static const INDEX_AVERAGE_CAFFEINE = 5;
    static const SUMMARY_SIZE = 6;

    static const BUCKET_STRIDE = 2;
    static const BUCKET_HYDRATION_OFFSET = 0;
    static const BUCKET_TARGET_OFFSET = 1;

    static function bucketHydrationIndex(bucket as Number) as Number {
        return SUMMARY_SIZE + bucket * BUCKET_STRIDE
            + BUCKET_HYDRATION_OFFSET;
    }

    static function bucketTargetIndex(bucket as Number) as Number {
        return SUMMARY_SIZE + bucket * BUCKET_STRIDE
            + BUCKET_TARGET_OFFSET;
    }

    // Averages are integer millilitres/milligrams because the public result
    // is Array<Number>. Division therefore truncates any fractional unit.
    static function build(records, startOrdinal, endOrdinal, bucketCount)
            as Array<Number> {
        var start = HydrationReport.numberOrNull(startOrdinal);
        var end = HydrationReport.numberOrNull(endOrdinal);
        var requestedBuckets = HydrationReport.numberOrNull(bucketCount);

        if (start == null || end == null || requestedBuckets == null
                || requestedBuckets <= 0 || end < start) {
            return [] as Array<Number>;
        }

        var dayCount = end - start + 1;
        if (dayCount <= 0) {
            return [] as Array<Number>;
        }

        var hydrationByDay = [] as Array<Number>;
        var targetByDay = [] as Array<Number>;
        var caffeineByDay = [] as Array<Number>;
        for (var dayIndex = 0; dayIndex < dayCount; dayIndex += 1) {
            hydrationByDay.add(0);
            targetByDay.add(0);
            caffeineByDay.add(0);
        }

        // A missing or non-array record collection represents an interval
        // with no samples. Incomplete and invalid record strides are ignored.
        if (records instanceof Lang.Array) {
            for (var offset = 0;
                    offset + RECORD_STRIDE - 1 < records.size();
                    offset += RECORD_STRIDE) {
                var ordinal = HydrationReport.numberOrNull(records[offset]);
                var hydration = HydrationReport.numberOrNull(
                    records[offset + 1]);
                var target = HydrationReport.numberOrNull(records[offset + 2]);
                var caffeine = HydrationReport.numberOrNull(
                    records[offset + 3]);

                if (ordinal == null || hydration == null || target == null
                        || caffeine == null || hydration < 0 || target < 0
                        || caffeine < 0 || ordinal < start || ordinal > end) {
                    continue;
                }

                var index = ordinal - start;
                hydrationByDay[index] = hydration;
                targetByDay[index] = target;
                caffeineByDay[index] = caffeine;
            }
        }

        var totalHydration = 0;
        var totalCaffeine = 0;
        var minimumHydration = hydrationByDay[0];
        var maximumHydration = hydrationByDay[0];
        var goalsReached = 0;

        var bucketHydration = [] as Array<Number>;
        var bucketTarget = [] as Array<Number>;
        var bucketDays = [] as Array<Number>;
        for (var bucket = 0; bucket < requestedBuckets; bucket += 1) {
            bucketHydration.add(0);
            bucketTarget.add(0);
            bucketDays.add(0);
        }

        for (var i = 0; i < dayCount; i += 1) {
            var dailyHydration = hydrationByDay[i];
            var dailyTarget = targetByDay[i];
            var dailyCaffeine = caffeineByDay[i];

            totalHydration += dailyHydration;
            totalCaffeine += dailyCaffeine;
            if (dailyHydration < minimumHydration) {
                minimumHydration = dailyHydration;
            }
            if (dailyHydration > maximumHydration) {
                maximumHydration = dailyHydration;
            }
            if (dailyTarget > 0 && dailyHydration >= dailyTarget) {
                goalsReached += 1;
            }

            // Mapping by proportional day offset keeps buckets ordered and
            // distributes the complete interval without dropping a day.
            var bucketIndex = (i * requestedBuckets) / dayCount;
            if (bucketIndex >= requestedBuckets) {
                bucketIndex = requestedBuckets - 1;
            }
            bucketHydration[bucketIndex] += dailyHydration;
            bucketTarget[bucketIndex] += dailyTarget;
            bucketDays[bucketIndex] += 1;
        }

        var result = [] as Array<Number>;
        result.add(totalHydration / dayCount);
        result.add(minimumHydration);
        result.add(maximumHydration);
        result.add(goalsReached);
        result.add(dayCount);
        result.add(totalCaffeine / dayCount);

        for (var resultBucket = 0;
                resultBucket < requestedBuckets;
                resultBucket += 1) {
            var daysInBucket = bucketDays[resultBucket];
            if (daysInBucket <= 0) {
                result.add(0);
                result.add(0);
            } else {
                result.add(bucketHydration[resultBucket] / daysInBucket);
                result.add(bucketTarget[resultBucket] / daysInBucket);
            }
        }
        return result;
    }

    private static function numberOrNull(value) as Number? {
        if (value instanceof Lang.Number) { return value; }
        if (value instanceof Lang.Long) { return value.toNumber(); }
        if (value instanceof Lang.Float) { return value.toNumber(); }
        if (value instanceof Lang.Double) { return value.toNumber(); }
        return null;
    }
}
