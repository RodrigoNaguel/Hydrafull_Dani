import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class SlotPreviewDrawable extends WatchUi.Drawable {
    private var _bounds as Graphics.BoundingBox;
    private var _value as String;
    private var _accentColor as Number;
    private var _ringColor as Number;
    private var _dataColor as Number;
    private var _surfaceColor as Number;

    function initialize(bounds as Graphics.BoundingBox, value as String,
            accentColor as Number, ringColor as Number,
            dataColor as Number, surfaceColor as Number) {
        Drawable.initialize({
            :identifier => "ComplicationPreview",
            :locX => 0,
            :locY => 0,
            :width => 1,
            :height => 1,
            :visible => true
        });
        _bounds = bounds;
        _value = value;
        _accentColor = accentColor;
        _ringColor = ringColor;
        _dataColor = dataColor;
        _surfaceColor = surfaceColor;
    }

    function draw(dc as Dc) as Void {
        var x = _bounds.x;
        var y = _bounds.y;
        if (x == null) { x = 0; }
        if (y == null) { y = 0; }
        var radius = _bounds.width / 2;
        var centerX = x + radius;
        var centerY = y + _bounds.height / 2;

        dc.setColor(_surfaceColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY, radius - 1);
        dc.setPenWidth(radius < 30 ? 2 : 4);
        dc.setColor(_ringColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, radius);
        dc.setColor(_accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, radius,
            Graphics.ARC_COUNTER_CLOCKWISE, 245, 305);
        dc.setPenWidth(1);
        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY, Graphics.FONT_TINY, _value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
