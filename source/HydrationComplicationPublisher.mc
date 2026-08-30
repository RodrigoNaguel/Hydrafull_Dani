import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;

(:glance, :background)
class HydrationComplicationPublisher {
    private static const COMPLICATION_INDEX = 0;
    private static const CAFFEINE_COMPLICATION_INDEX = 1;

    static function publishCurrent() as Void {
        try {
            var waterMl = HydrationStore.getNumber("waterMl");
            var targetMl = HydrationStore.dailyTargetMl();
            if (targetMl > 0) {
                var quarter = targetMl / 4;
                var ranges = [
                    0,
                    quarter,
                    quarter * 2,
                    quarter * 3,
                    targetMl
                ] as Array<Complications.RangeValue>;

                Complications.updateComplication(COMPLICATION_INDEX, {
                    :value => waterMl,
                    :shortLabel => "HYDRA",
                    :unit => "ml",
                    :ranges => ranges
                } as Complications.Data);
            } else {
                Complications.updateComplication(COMPLICATION_INDEX, {
                    :value => 0,
                    :shortLabel => "HYDRA",
                    :unit => "ml"
                } as Complications.Data);
            }
            Complications.updateComplication(CAFFEINE_COMPLICATION_INDEX, {
                :value => HydrationStore.getNumber("caffeineTodayMg"),
                :shortLabel => "CAFFEINE",
                :unit => "mg"
            } as Complications.Data);
        } catch (error) {
            // Publishing is best effort: hydration recording must never fail
            // because the companion face is absent or temporarily unavailable.
            System.println("[HydraFuel] Complication publish error: " + error);
        }
    }
}
