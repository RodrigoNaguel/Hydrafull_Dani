import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

(:glance)
module UiHelper {
    module Colors {
        const ACCENT = 0x00AEEB;
        const ACCENT_SUCCESS = 0x18D58B;
        const ACCENT_WARN = 0xFFD166;
        const ACCENT_DANGER = 0xFF4D5A;
        const TEXT_PRIMARY = Graphics.COLOR_WHITE;
        const TEXT_SECONDARY = 0xA8B0B8;
        const TEXT_INVERSE = Graphics.COLOR_BLACK;
        const BACKGROUND = Graphics.COLOR_BLACK;
        const BACKGROUND_CARD = 0x171A1F;
    }

    module Spacing {
        const SMALL = 4;
        const MEDIUM = 8;
        const LARGE = 12;
        const XLARGE = 16;
    }

    class Layout {
        public var width as Number;
        public var height as Number;
        public var centerX as Number;
        public var centerY as Number;
        public var isCircular as Boolean;
        public var margin as Number;

        private var _safeRadius as Float;

        function initialize(dc as Dc) {
            width = dc.getWidth();
            height = dc.getHeight();
            centerX = width / 2;
            centerY = height / 2;
            margin = Spacing.MEDIUM;

            var deviceSettings = System.getDeviceSettings();
            // A GlanceView receives a rectangular, bounded Dc even on round
            // watches. Only apply circular-screen geometry to a full display.
            isCircular = (deviceSettings.screenShape == System.SCREEN_SHAPE_ROUND)
                && (width == height);

            var diameter = width < height ? width : height;
            if (isCircular) {
                _safeRadius = diameter / 2.0;
            } else {
                _safeRadius = width / 2.0;
            }
        }

        function safeWidthAtY(y as Number) as Number {
            if (!isCircular) {
                return width - 2 * margin;
            }
            var dy = (y - centerY).abs();
            if (dy >= _safeRadius) {
                return 0;
            }
            var chordWidth = 2 * Math.sqrt(_safeRadius * _safeRadius - dy * dy);
            var safeWidth = chordWidth.toNumber() - 2 * margin;
            return safeWidth > 0 ? safeWidth : 0;
        }

        function safeLeft(y as Number) as Number {
            return centerX - (safeWidthAtY(y) / 2);
        }
 
        function safeRight(y as Number) as Number {
            return centerX + (safeWidthAtY(y) / 2);
        }

        function safeTop() as Number {
            if (!isCircular) {
                return margin;
            }
            return (centerY - _safeRadius * Math.sin(Math.PI / 4.0)).toNumber();
        }

        function safeBottom() as Number {
            if (!isCircular) {
                return height - margin;
            }
            return (centerY + _safeRadius * Math.sin(Math.PI / 4.0)).toNumber();
        }

        function getFont(size as Symbol) as FontDefinition {
            var fonts = {
                :title => Graphics.FONT_TINY,
                :subtitle => Graphics.FONT_XTINY,
                :value_large => Graphics.FONT_NUMBER_THAI_HOT,
                :value_medium => Graphics.FONT_NUMBER_MEDIUM,
                :body => Graphics.FONT_SMALL,
                :small => Graphics.FONT_XTINY
            } as Dictionary<Symbol, FontDefinition>;

            var font = fonts[size];
            if (font != null) {
                return font;
            }
            return Graphics.FONT_XTINY;
        }
    }

    class Flow {
        private var _y as Number;
        public var layout as Layout;

        function initialize(layout as Layout, startY as Number) {
            self.layout = layout;
            _y = startY;
        }

        function y() as Number {
            return _y;
        }

        function advance(pixels as Number) as Number {
            _y += pixels;
            return _y;
        }

        function remainingHeight(bottomBound as Number) as Number {
            return bottomBound - _y;
        }
    }

    module Text {
        function drawWrapped(dc, text, font, color, x, y, maxWidth, justification, maxLines, addEllipsis) {
            var lines = wrapText(dc, text, font, maxWidth);
            var lineHeight = dc.getFontHeight(font);
            var currentY = y;

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);

            var linesToDraw = lines.size();
            if (maxLines != null && linesToDraw > maxLines) {
                linesToDraw = maxLines;
                if (addEllipsis) {
                    var lastLine = (lines as Array<String>)[linesToDraw - 1] as String;
                    if (lastLine.length() > 3) {
                       var truncatedLine = lastLine.substring(0, lastLine.length() - 2) + "...";
                       while(dc.getTextWidthInPixels(truncatedLine, font) > maxWidth && truncatedLine.length() > 3) {
                           truncatedLine = truncatedLine.substring(0, truncatedLine.length() - 4) + "...";
                       }
                       (lines as Array<String>)[linesToDraw-1] = truncatedLine;
                    }
                }
            }

            var drawJustification = justification & ~Graphics.TEXT_JUSTIFY_VCENTER;
            if ((justification & Graphics.TEXT_JUSTIFY_VCENTER) != 0) {
                currentY -= lineHeight * linesToDraw / 2;
            }

            for (var i = 0; i < linesToDraw; i++) {
                var line = (lines as Array<String>)[i] as String;
                dc.drawText(x, currentY, font, line, drawJustification);
                currentY += lineHeight;
            }
            return currentY;
        }

        function drawFittedText(dc, text, y, preferredFont, fallbackFont, justification) {
            var layout = new UiHelper.Layout(dc);
            var maxWidth = layout.safeWidthAtY(y);

            var font = preferredFont;
            if (dc.getTextWidthInPixels(text, font) > maxWidth) {
                font = fallbackFont;
            }

            dc.drawText(layout.centerX, y, font, text, justification);
            return dc.getFontHeight(font);
        }

        function wrapText(dc, text, font, maxWidth) {
            var lines = [] as Array<String>;
            if (maxWidth <= 0) {
                return lines;
            }
            var words = splitString(text, " ");
            if (words.size() == 0) {
                return lines;
            }

            var currentLine = (words as Array<String>)[0] as String;
            for (var i = 1; i < words.size(); i++) {
                var word = (words as Array<String>)[i] as String;
                var testLine = currentLine + " " + word;
                if (dc.getTextWidthInPixels(testLine, font) <= maxWidth) {
                    currentLine = testLine;
                } else {
                    lines.add(currentLine);
                    currentLine = word;
                }
            }
            lines.add(currentLine);

            return lines;
        }

        function splitString(text, delimiter) {
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

    class ProgressBar {
        static function draw(dc, x, y, width, height, progress, fillColor) {
            var radius = height / 2;
            var trackColor = 0x1C2330;
            dc.setColor(trackColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, width, height, radius);

            var clampedProgress = progress;
            if (clampedProgress < 0.0) { clampedProgress = 0.0; }
            if (clampedProgress > 1.0) { clampedProgress = 1.0; }

            var fillWidth = (clampedProgress * width).toNumber();
            if (fillWidth > 0) {
                var fillRadius = fillWidth < height ? fillWidth / 2 : radius;
                dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x, y, fillWidth, height, fillRadius);
            }
        }

        static function colorForProgress(progress) {
            if (progress < 0.25) { return 0x35B5E1; }
            if (progress < 0.60) { return 0x00AEEB; }
            if (progress < 0.90) { return 0x1FA1F2; }
            return 0x18D58B;
        }
    }
}
