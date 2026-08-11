(:glance, :background)
class HydrationCalculator {
    static function baselineWaterMl(weightKg) {
        var estimate = weightKg * AppConfig.BASE_WATER_ML_PER_KG;
        return clamp(estimate,
            AppConfig.BASE_WATER_MIN_ML,
            AppConfig.BASE_WATER_MAX_ML);
    }

    // Adjusts water target based on daily activity calories.
    // totalCalories comes from ActivityMonitor (BMR + active).
    // Resting baseline is estimated from weight (≈ Mifflin-St Jeor simplified)
    // so that a heavy, lean athlete is not penalised by a hardcoded 1600 kcal.
    // Each 100 kcal above resting adds ~80ml (0.8ml/kcal).
    // Stress > 60 adds 10%. Body Battery < 30 adds 10%.
    // Caffeine > 400mg adds 150ml per 200mg excess.
    static function adjustedWaterMl(weightKg, totalCalories, stress, bodyBattery, caffeineMg) {
        var baseline = baselineWaterMl(weightKg);
        // Rough weight-proportional resting estimate (BMR ≈ 10 * kg + 500).
        // This is deliberately conservative to ensure active calories are not
        // under-counted for lean, high-muscle athletes.
        var restingEstimate = (weightKg * 10.0 + 500.0).toNumber();
        if (totalCalories > restingEstimate) {
            var activeCalories = totalCalories - restingEstimate;
            baseline = baseline + (activeCalories.toFloat() * 0.8);
        }

        if (caffeineMg != null && caffeineMg > 400) {
            baseline += ((caffeineMg - 400).toFloat() / 200.0) * 150.0;
        }

        if (stress != null && stress > 60) {
            baseline *= 1.1;
        }

        if (bodyBattery != null && bodyBattery < 30) {
            baseline *= 1.1;
        }

        return clamp(baseline, AppConfig.BASE_WATER_MIN_ML, AppConfig.BASE_WATER_MAX_ML);
    }

    // Projects whether the user will finish below the daily target at their
    // current drinking pace.
    //   waterMl        – ml consumed so far today
    //   targetMl       – daily goal
    //   elapsedMinutes – minutes elapsed since the window start
    //   remainingMinutes – minutes left until window end
    //   recentWaterMl  - ml consumed in the recent window
    //   recentMinutes  - length of the recent window in minutes
    // Returns the projected shortfall (>0 means they will fall short).
    // Returns 0 when on pace or ahead of pace.
    static function projectedShortfallMl(waterMl, targetMl,
            elapsedMinutes, remainingMinutes, recentWaterMl, recentMinutes) {
        if (elapsedMinutes <= 0) { return 0.0; }
        
        var paceMlPerMin;
        if (elapsedMinutes <= recentMinutes) {
            paceMlPerMin = waterMl.toFloat() / elapsedMinutes.toFloat();
        } else {
            paceMlPerMin = recentWaterMl.toFloat() / recentMinutes.toFloat();
        }
        
        // Extrapolate to end of window
        var projectedTotal = waterMl + paceMlPerMin * remainingMinutes.toFloat();
        var shortfall = targetMl.toFloat() - projectedTotal;
        return shortfall < 0.0 ? 0.0 : shortfall;
    }

    // Field calibration: body-mass change plus fluid balance.
    static function measuredSweatRateLh(preKg, postKg, drinkL, urineL, hours) {
        if (hours <= 0) { return null; }
        // Keep negative values visible: they may indicate overdrinking or bad input.
        var balanceLiters = (preKg - postKg) + drinkL - urineL;
        return balanceLiters.toFloat() / hours.toFloat();
    }

    // Low-confidence population prior until a pre/post body-mass test exists.
    static function defaultSweatRateLh() {
        return AppConfig.DEFAULT_SWEAT_RATE_L_H;
    }

    static function defaultSweatRateRangeLh() {
        return [
            AppConfig.DEFAULT_SWEAT_RATE_LOW_L_H,
            AppConfig.DEFAULT_SWEAT_RATE_HIGH_L_H
        ];
    }

    static function sweatMeasurementNeedsReview(rateLh) {
        return rateLh < 0.2 || rateLh > 3.0;
    }

    static function exerciseFluidMl(sweatRateLh, durationMinutes) {
        if (durationMinutes <= 0) { return 0.0; }
        return sweatRateLh * durationMinutes.toFloat() / 60.0 * 1000.0;
    }

    static function sodiumLossMg(sweatLiters, sodiumMgPerLiter) {
        var loss = sweatLiters.toFloat() * sodiumMgPerLiter;
        return loss < 0.0 ? 0.0 : loss;
    }

    static function potassiumLossMg(sweatLiters, potassiumMgPerLiter) {
        var loss = sweatLiters.toFloat() * potassiumMgPerLiter;
        return loss < 0.0 ? 0.0 : loss;
    }

    static function caffeineMgKg(caffeineMg, weightKg) {
        return weightKg > 0 ? caffeineMg.toFloat() / weightKg : 0.0;
    }

    static function caffeineSingleWarningMg(weightKg) {
        var byWeight = weightKg * 3.0;
        return byWeight < AppConfig.SINGLE_CAFFEINE_WARNING_MG
            ? byWeight : AppConfig.SINGLE_CAFFEINE_WARNING_MG;
    }

    static function caffeineDailyWarningMg(weightKg) {
        var byWeight = weightKg * 5.7;
        return byWeight < AppConfig.DAILY_CAFFEINE_WARNING_MG
            ? byWeight : AppConfig.DAILY_CAFFEINE_WARNING_MG;
    }

    static function caffeinePerformanceBand(mgPerKg) {
        if (mgPerKg < 1.0) { return "efeito incerto"; }
        if (mgPerKg < 2.0) { return "beneficio possivel"; }
        if (mgPerKg < 3.0) { return "beneficio provavel"; }
        if (mgPerKg < 6.0) { return "evidencia consistente"; }
        if (mgPerKg < 9.0) { return "nao sugerir"; }
        return "alto risco";
    }

    static function needsElectrolytes(durationMinutes, intensityFactor, tempC, sweatRateLh) {
        return durationMinutes >= 60
            || intensityFactor >= 1.25
            || tempC >= 28.0
            || sweatRateLh >= 1.0;
    }

    static function dataConfidence(calibrationCount, coefficientVariationPct) {
        if (calibrationCount >= 3 && coefficientVariationPct <= 20.0) {
            return "alta";
        }
        if (calibrationCount >= 1) { return "media"; }
        return "baixa";
    }

    static function clamp(value, low, high) {
        if (value < low) { return low; }
        if (value > high) { return high; }
        return value;
    }
}
