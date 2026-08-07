import Toybox.Graphics;
import Toybox.Lang;

// UiHelper contains modules for consistent UI rendering.
// - Layout: Calculates screen metrics for responsive design.
// - Text: Provides text wrapping and drawing utilities.
// - Colors: Defines the app's color palette.
(:glance)
module UiHelper {
    module Colors {
        const ACCENT = 0x00AEEB; // Main cyan/blue
        const ACCENT_SUCCESS = 0x18D58B; // Green for positive states
        const ACCENT_WARN = 0xFFD166; // Yellow for attention
        const ACCENT_DANGER = 0xFF4D5A; // Red for alerts
        const TEXT_PRIMARY = Graphics.COLOR_WHITE;
        const TEXT_SECONDARY = 0xA8B0B8; // Light gray
        const TEXT_INVERSE = Graphics.COLOR_BLACK;
        const BACKGROUND = Graphics.COLOR_BLACK;
        const BACKGROUND_CARD = 0x171A1F; // Dark gray for cards
    }

    // The Layout class calculates dimensions and positions based on screen
    // geometry. It adapts to circular and rectangular screens.
    class Layout {
        public var width as Number;
        public var height as Number;
        public var centerX as Number;
        public var centerY as Number;
        public var isCircular as Boolean;

        // The safe drawable area, considering screen shape.
        private var _safeRadius as Float;
        private var _safeTop as Float;
        private var _safeBottom as Float;
        private var _safeLeft as Float;
        private var _safeRight as Float;

        function initialize(dc as Dc) {
            width = dc.getWidth();
            height = dc.getHeight();
            centerX = width / 2;
            centerY = height / 2;
            
            var deviceSettings = System.getDeviceSettings();
            isCircular = (deviceSettings.screenShape == System.SCREEN_SHAPE_ROUND);

            if (isCircular) {
                // For circular screens, the safe radius is a percentage of the
                // smallest dimension, creating a margin.
                var diameter = width < height ? width : height;
                _safeRadius = diameter * 0.46; // ~92% of diameter
                _safeTop = centerY - _safeRadius;
                _safeBottom = centerY + _safeRadius;
                _safeLeft = centerX - _safeRadius;
                _safeRight = centerX + _safeRadius;
            } else {
                // For rectangular screens, use a fixed margin.
                var margin = width * 0.05;
                _safeRadius = (width / 2) - margin;
                _safeTop = margin;
                _safeBottom = height - margin;
                _safeLeft = margin;
                _safeRight = width - margin;
            }
        }

        // Returns the Y coordinate for a percentage of the screen height.
        // 0.0 is top, 1.0 is bottom.
        function vPos(percentage as Float) as Float {
            return height * percentage;
        }
 
        // Returns the width of the safe drawable area at a given Y coordinate.
        // On circular screens, this is narrower near the top and bottom.
        function safeWidthAtY(y as Number) as Float {
            if (!isCircular || (y >= _safeTop && y <= _safeBottom)) {
                 if (!isCircular) {
                    return _safeRight - _safeLeft;
                 }
                 var dy = (y - centerY).abs();
                 // Using circular segment formula: 2 * sqrt(r^2 - d^2)
                 var chordWidth = 2 * Math.sqrt(_safeRadius * _safeRadius - dy * dy);
                 return chordWidth;
            }
            return 0.0;
        }

        // Gets a font based on a semantic size.
        function getFont(size as Symbol) as FontDefinition {
            var fonts = {
                :title => Graphics.FONT_TINY,
                :subtitle => Graphics.FONT_XTINY,
                :value_large => Graphics.FONT_NUMBER_THAI_HOT,
                :value_medium => Graphics.FONT_NUMBER_MEDIUM,
                :body => Graphics.FONT_SMALL,
                :small => Graphics.FONT_XTINY
            };

            var font = fonts[size];
            if (font != null) {
                return font;
            }
            return Graphics.FONT_XTINY;
        }
    }

    // The Text module provides advanced text drawing functions, like
    // automatic line wrapping.
    module Text {

        // Draws multi-line text, wrapped to fit within a specified width.
        // Returns the Y position of the bottom of the last line drawn.
        function drawWrapped(
            dc as Dc,
            text as String,
            font as FontDefinition,
            color as ColorType,
            x as Number,
            y as Number,
            maxWidth as Number,
            justification as TextJustification,
            maxLines as Number or Null
        ) as Number {
            var lines = wrapText(dc, text, font, maxWidth);
            var lineHeight = dc.getFontHeight(font);
            var currentY = y;

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);

            var linesToDraw = lines.size();
            if (maxLines != null && linesToDraw > maxLines) {
                linesToDraw = maxLines;
                // Add ellipsis to the last drawn line
                var lastLine = lines[linesToDraw - 1];
                if (lastLine.length() > 3) {
                   var truncatedLine = lastLine.substring(0, lastLine.length() - 2) + "...";
                   while(dc.getTextWidthInPixels(truncatedLine, font) > maxWidth && truncatedLine.length() > 3) {
                       truncatedLine = truncatedLine.substring(0, truncatedLine.length() - 4) + "...";
                   }
                   lines[linesToDraw-1] = truncatedLine;
                }
            }

            for (var i = 0; i < linesToDraw; i++) {
                dc.drawText(x, currentY, font, lines[i], justification);
                currentY += lineHeight;
            }

            return currentY;
        }

        // Splits a string into an array of lines that fit a max width.
        function wrapText(
            dc as Dc,
            text as String,
            font as FontDefinition,
            maxWidth as Number
        ) as Array<String> {
            var lines = [] as Array<String>;
            var words = splitString(text, " ");
            if (words.size() == 0) {
                return lines;
            }

            var currentLine = words[0];
            for (var i = 1; i < words.size(); i++) {
                var testLine = currentLine + " " + words[i];
                if (dc.getTextWidthInPixels(testLine, font) <= maxWidth) {
                    currentLine = testLine;
                } else {
                    lines.add(currentLine);
                    currentLine = words[i];
                }
            }
            lines.add(currentLine);

            return lines;
        }

        // Helper to split a string by a delimiter.
        function splitString(text as String, delimiter as String) as Array<String> {
            var result = [] as Array<String>;
            var temp = "";
            for (var i = 0; i < text.length(); i++) {
                var char = text.substring(i, i + 1);
                if (char.equals(delimiter)) {
                    if (temp.length() > 0) {
                        result.add(temp);
                        temp = "";
                    }
                } else {
                    temp += char;
                }
            }
            if (temp.length() > 0) {
                result.add(temp);
            }
            return result;
        }
    }
}
