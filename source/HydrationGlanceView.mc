import Toybox.Graphics;
import Toybox.WatchUi;

(:glance)
class HydrationGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        var waterMl = HydrationStore.getNumber("waterMl");
        var caffeineMg = HydrationStore.getNumber("caffeineTodayMg");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, 0, Graphics.FONT_SMALL,
            waterMl.format("%d") + " ml | "
                + caffeineMg.format("%d") + " mg",
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}

