import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class StatsView extends WatchUi.View {
    private const WATER_COLOR = 0x00AEEB;
    private const CAFFEINE_COLOR = 0xFF8A3D;
    private const DANGER_COLOR = 0xFF4D5A;
    private const CARD_COLOR = 0x171A1F;
    private const MUTED_COLOR = 0xA8B0B8;
    private const SUCCESS_COLOR = 0x18D58B;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, 30, Graphics.FONT_TINY, WatchUi.loadResource(Rez.Strings.stats_title), Graphics.TEXT_JUSTIFY_CENTER);

        drawCaffeineCard(dc, width, height);
        drawWellnessCard(dc, width, height);
        drawFeedbackCard(dc, width, height);
    }

    private function drawCaffeineCard(dc as Dc, width as Number, height as Number) as Void {
        var caffeineMg = HydrationStore.getNumber("caffeineTodayMg");
        var remaining = HydrationStore.caffeineRemaining(AppConfig.DEFAULT_CAFFEINE_HALF_LIFE_HOURS).toNumber();
        var weightKg = WellnessReader.weightKg();
        var caffeineWarning = HydrationCalculator.caffeineDailyWarningMg(weightKg);
        var caffeineAccent = caffeineMg >= caffeineWarning ? DANGER_COLOR : CAFFEINE_COLOR;
        var unitMg = WatchUi.loadResource(Rez.Strings.stats_unit_mg);

        var cardY = 60;
        var cardHeight = 65;
        dc.setColor(CARD_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(15, cardY, width - 30, cardHeight, 10);
        
        dc.setColor(caffeineAccent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, cardY + 10, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.stats_caffeine_title) + ": " + caffeineMg.format("%d") + unitMg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(MUTED_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, cardY + 35, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.label_active) + " " + remaining.format("%d") + unitMg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawWellnessCard(dc as Dc, width as Number, height as Number) as Void {
        var bodyBattery = HydrationStore.getNumber("lastBodyBattery");
        var stress = HydrationStore.getNumber("lastStress");
        var calories = HydrationStore.getNumber("lastCalories");

        var cardY = 135;
        var cardHeight = 65;

        dc.setColor(CARD_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(15, cardY, width - 30, cardHeight, 10);

        var textY = cardY + cardHeight / 2;

        if (bodyBattery > 0) {
            dc.setColor(SUCCESS_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 4, textY, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.stats_wellness_body) + ": " + bodyBattery, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        if (stress > 0) {
            dc.setColor(DANGER_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, textY, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.stats_wellness_stress) + ": " + stress, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        if (calories > 0) {
             dc.setColor(CAFFEINE_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width * 3 / 4, textY, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.stats_wellness_calories) + ": " + calories, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (bodyBattery <= 0 && stress <= 0 && calories <= 0) {
            dc.setColor(MUTED_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, textY, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.stats_wellness_no_data), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawFeedbackCard(dc as Dc, width as Number, height as Number) as Void {
        var waterMl = HydrationStore.getNumber("waterMl");
        var weightKg = WellnessReader.weightKg();
        var totalCalories = HydrationStore.getNumber("lastCalories");
        var targetMl = HydrationCalculator.adjustedWaterMl(weightKg, totalCalories).toNumber();
        var rawProgress = (targetMl > 0) ? (waterMl.toFloat() / targetMl) : 0.0;

        var caffeineMg = HydrationStore.getNumber("caffeineTodayMg");
        var caffeineWarning = HydrationCalculator.caffeineDailyWarningMg(weightKg);

        var waterFeedbackText = "";
        var caffeineFeedbackText = "";
        var waterFeedbackColor = SUCCESS_COLOR;
        var caffeineFeedbackColor = CAFFEINE_COLOR;

        if (rawProgress < 0.5) {
            waterFeedbackText = WatchUi.loadResource(Rez.Strings.feedback_water_low);
            waterFeedbackColor = WATER_COLOR;
        } else if (rawProgress < 1.0) {
            waterFeedbackText = WatchUi.loadResource(Rez.Strings.feedback_water_mid);
            waterFeedbackColor = SUCCESS_COLOR;
        } else {
            waterFeedbackText = WatchUi.loadResource(Rez.Strings.feedback_water_high);
            waterFeedbackColor = SUCCESS_COLOR;
        }

        if (caffeineMg > caffeineWarning) {
            caffeineFeedbackText = WatchUi.loadResource(Rez.Strings.feedback_caffeine_high);
            caffeineFeedbackColor = DANGER_COLOR;
        } else if (caffeineMg > 0) {
            caffeineFeedbackText = WatchUi.loadResource(Rez.Strings.feedback_caffeine_ok);
        }
        
        var cardY = 210;
        var cardHeight = 65;

        dc.setColor(CARD_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(15, cardY, width - 30, cardHeight, 10);

        var font = Graphics.FONT_XTINY;
        
        dc.setColor(waterFeedbackColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, cardY + 15, font, waterFeedbackText, Graphics.TEXT_JUSTIFY_CENTER);

        if (!caffeineFeedbackText.equals("")) {
            dc.setColor(caffeineFeedbackColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, cardY + 40, font, caffeineFeedbackText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
