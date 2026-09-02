import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class SlotPreviewDrawable extends WatchUi.Drawable {
    private var _bounds as Graphics.BoundingBox;
    private var _value as String;
    private var _dataColor as Number;

    function initialize(bounds as Graphics.BoundingBox, value as String, dataColor as Number) {
        var x = bounds.x;
        var y = bounds.y;
        if (x == null) { x = 0; }
        if (y == null) { y = 0; }
        Drawable.initialize({
            :identifier => "ComplicationPreview",
            :locX => x,
            :locY => y,
            :width => bounds.width,
            :height => bounds.height,
            :visible => true
        });
        _bounds = bounds;
        _value = value;
        _dataColor = dataColor;
    }

    function draw(dc as Dc) as Void {
        var x = _bounds.x;
        var y = _bounds.y;
        if (x == null) { x = 0; }
        if (y == null) { y = 0; }
        var radius = _bounds.width / 2;
        var centerX = x + radius;
        var centerY = y + _bounds.height / 2;

        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY, Graphics.FONT_TINY, _value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
