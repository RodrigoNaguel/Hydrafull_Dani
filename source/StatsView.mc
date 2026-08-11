import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class StatsView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(UiHelper.Colors.BACKGROUND, UiHelper.Colors.BACKGROUND);
        dc.clear();

        var layout = new UiHelper.Layout(dc);
        var flow = new UiHelper.Flow(layout, layout.safeTop() + UiHelper.Spacing.SMALL);
        var bottomBound = layout.safeBottom() - layout.margin;

        var titleFont = Graphics.FONT_TINY;
        var titleHeight = dc.getFontHeight(titleFont);
        UiHelper.Text.drawWrapped(dc, WatchUi.loadResource(Rez.Strings.stats_title), titleFont, UiHelper.Colors.TEXT_PRIMARY, layout.centerX, flow.y(), layout.safeWidthAtY(flow.y()), Graphics.TEXT_JUSTIFY_CENTER, 1, false);
        flow.advance(titleHeight + UiHelper.Spacing.SMALL);

        var waterMl = HydrationStore.getNumber("waterMl");
        var weightKg = WellnessReader.weightKg();
        var totalCalories = HydrationStore.getNumber("lastCalories");
        var stress = HydrationStore.getNumber("lastStress");
        var bodyBattery = HydrationStore.getNumber("lastBodyBattery");
        var caffeine = HydrationStore.getNumber("caffeineTodayMg");
        var targetMl = HydrationCalculator.adjustedWaterMl(weightKg, totalCalories, stress, bodyBattery, caffeine).toNumber();
        var waterProgress = (targetMl > 0) ? (waterMl.toFloat() / targetMl) : 0.0;
        var unitMl = WatchUi.loadResource(Rez.Strings.unit_ml);
        var unitMg = WatchUi.loadResource(Rez.Strings.stats_unit_mg);
        var rowFont = Graphics.FONT_XTINY;
        var rowHeight = dc.getFontHeight(rowFont) + UiHelper.Spacing.SMALL;

        var waterText = WatchUi.loadResource(Rez.Strings.stats_water_title)
            + " " + waterMl + "/" + targetMl + " " + unitMl;
        UiHelper.Text.drawWrapped(dc, waterText, rowFont,
            UiHelper.Colors.ACCENT, layout.centerX, flow.y(),
            layout.safeWidthAtY(flow.y()), Graphics.TEXT_JUSTIFY_CENTER,
            1, true);
        flow.advance(rowHeight);

        var caffeineMg = HydrationStore.getNumber("caffeineTodayMg");
        var remainingCaffeine = HydrationStore.caffeineRemaining(
            AppConfig.DEFAULT_CAFFEINE_HALF_LIFE_HOURS).toNumber();
        var caffeineTotalText = WatchUi.loadResource(
            Rez.Strings.stats_caffeine_title)
            + " " + caffeineMg + " " + unitMg;
        UiHelper.Text.drawWrapped(dc, caffeineTotalText, rowFont,
            UiHelper.Colors.TEXT_SECONDARY, layout.centerX, flow.y(),
            layout.safeWidthAtY(flow.y()), Graphics.TEXT_JUSTIFY_CENTER,
            1, false);
        flow.advance(rowHeight);

        var caffeineActiveText = WatchUi.loadResource(Rez.Strings.label_active)
            + " " + remainingCaffeine + " " + unitMg;
        UiHelper.Text.drawWrapped(dc, caffeineActiveText, rowFont,
            UiHelper.Colors.ACCENT_WARN, layout.centerX, flow.y(),
            layout.safeWidthAtY(flow.y()), Graphics.TEXT_JUSTIFY_CENTER,
            1, false);
        flow.advance(rowHeight);

        var wellnessText = "";
        if (bodyBattery > 0) {
            wellnessText = WatchUi.loadResource(Rez.Strings.stats_wellness_body)
                + " " + bodyBattery;
        }
        if (stress > 0) {
            if (wellnessText.length() > 0) { wellnessText += " | "; }
            wellnessText += WatchUi.loadResource(Rez.Strings.stats_wellness_stress)
                + " " + stress;
        }
        if (wellnessText.length() == 0) {
            wellnessText = WatchUi.loadResource(Rez.Strings.stats_wellness_no_data);
        }
        UiHelper.Text.drawWrapped(dc, wellnessText, rowFont,
            UiHelper.Colors.TEXT_SECONDARY, layout.centerX, flow.y(),
            layout.safeWidthAtY(flow.y()), Graphics.TEXT_JUSTIFY_CENTER,
            1, true);
        flow.advance(rowHeight + UiHelper.Spacing.SMALL);

        var finalMessage;
        if (caffeineMg >= HydrationCalculator.caffeineDailyWarningMg(weightKg)) {
            finalMessage = WatchUi.loadResource(Rez.Strings.feedback_caffeine_high);
        } else if (waterProgress < 0.60) {
            finalMessage = WatchUi.loadResource(Rez.Strings.feedback_water_low);
        } else if (waterProgress < 1.0) {
            finalMessage = WatchUi.loadResource(Rez.Strings.feedback_water_mid);
        } else {
            finalMessage = WatchUi.loadResource(Rez.Strings.feedback_water_high);
        }

        if (flow.remainingHeight(bottomBound) >= dc.getFontHeight(rowFont)) {
            UiHelper.Text.drawWrapped(dc, finalMessage, rowFont,
                UiHelper.Colors.ACCENT_SUCCESS, layout.centerX, flow.y(),
                layout.safeWidthAtY(flow.y()), Graphics.TEXT_JUSTIFY_CENTER,
                2, true);
        }
    }
}
