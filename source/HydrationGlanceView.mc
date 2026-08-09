import Toybox.Graphics;
import Toybox.WatchUi;

(:glance)
class HydrationGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        var layout = new UiHelper.Layout(dc);
        var waterMl = HydrationStore.getNumber("waterMl");
        var caffeineMg = HydrationStore.getNumber("caffeineTodayMg");
        var targetMl = HydrationCalculator.adjustedWaterMl(WellnessReader.weightKg(), HydrationStore.getNumber("lastCalories")).toNumber();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // The Dc is already clipped to the rectangular glance content area.
        // Keep two compact text rows and a progress bar inside that rectangle.
        var maxWidth = layout.width - (UiHelper.Spacing.MEDIUM * 2);
        var waterText = waterMl.format("%d") + "/" + targetMl.format("%d")
            + " " + WatchUi.loadResource(Rez.Strings.unit_ml);
        var caffeineText = WatchUi.loadResource(Rez.Strings.stats_caffeine_title)
            + " " + caffeineMg.format("%d") + " "
            + WatchUi.loadResource(Rez.Strings.stats_unit_mg);

        var waterFont = Graphics.FONT_GLANCE;
        if (dc.getTextWidthInPixels(waterText, waterFont) > maxWidth) {
            waterFont = Graphics.FONT_XTINY;
        }
        var caffeineFont = Graphics.FONT_GLANCE;
        if (dc.getTextWidthInPixels(caffeineText, caffeineFont) > maxWidth) {
            caffeineFont = Graphics.FONT_XTINY;
        }

        var barHeight = 8;
        var contentHeight = dc.getFontHeight(waterFont)
            + dc.getFontHeight(caffeineFont)
            + barHeight + UiHelper.Spacing.MEDIUM * 2;
        var currentY = (layout.height - contentHeight) / 2;
        if (currentY < 0) { currentY = 0; }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(layout.centerX, currentY, waterFont, waterText,
            Graphics.TEXT_JUSTIFY_CENTER);
        currentY += dc.getFontHeight(waterFont) + UiHelper.Spacing.SMALL;

        var progress = targetMl > 0
            ? HydrationCalculator.clamp(waterMl.toFloat() / targetMl, 0.0, 1.0)
            : 0.0;
        var barWidth = (maxWidth * 0.82).toNumber();
        UiHelper.ProgressBar.draw(dc, layout.centerX - barWidth / 2,
            currentY, barWidth, barHeight, progress,
            UiHelper.ProgressBar.colorForProgress(progress));
        currentY += barHeight + UiHelper.Spacing.SMALL;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(layout.centerX, currentY, caffeineFont, caffeineText,
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}
