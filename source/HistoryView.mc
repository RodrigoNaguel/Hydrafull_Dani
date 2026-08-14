import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Compact hydration history for the watch. The delegate owns the SELECT
// action and calls cyclePeriod(); the view only owns period state and drawing.
class HistoryView extends WatchUi.View {
    private const PERIOD_SEVEN_DAYS = 0;
    private const PERIOD_FOUR_WEEKS = 1;
    private const PERIOD_ONE_YEAR = 2;
    private const PERIOD_COUNT = 3;

    private const REPORT_SUMMARY_SIZE = 6;
    private const REPORT_BUCKET_STRIDE = 2;

    private var mPeriod as Number;

    function initialize() {
        View.initialize();
        mPeriod = PERIOD_SEVEN_DAYS;
    }

    public function cyclePeriod() as Void {
        mPeriod = (mPeriod + 1) % PERIOD_COUNT;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(UiHelper.Colors.BACKGROUND,
            UiHelper.Colors.BACKGROUND);
        dc.clear();

        var layout = new UiHelper.Layout(dc);
        var compact = layout.width <= 218 || layout.height <= 218;
        var gap = compact ? 1 : UiHelper.Spacing.SMALL;
        var top = layout.safeTop();
        var bottom = layout.safeBottom() - gap;

        var titleFont = compact ? Graphics.FONT_XTINY
            : Graphics.FONT_TINY;
        var titleHeight = dc.getFontHeight(titleFont);
        UiHelper.Text.drawWrapped(dc,
            WatchUi.loadResource(Rez.Strings.history_title),
            titleFont, UiHelper.Colors.TEXT_PRIMARY, layout.centerX, top,
            layout.safeWidthAtY(top), Graphics.TEXT_JUSTIFY_CENTER,
            1, true);
        top += titleHeight + gap;

        var tabFont = Graphics.FONT_XTINY;
        var tabHeight = dc.getFontHeight(tabFont) + (compact ? 2 : 6);
        drawTabs(dc, layout, top, tabHeight, tabFont);
        top += tabHeight + gap;

        var days = periodDays();
        var bucketCount = periodBuckets();
        var endOrdinal = HydrationStore.currentDayOrdinal();
        var chartStartOrdinal = endOrdinal - days + 1;
        var summaryStartOrdinal = chartStartOrdinal;
        var availableStart = HydrationStore.historyStartOrdinal();
        if (availableStart > summaryStartOrdinal
                && availableStart <= endOrdinal) {
            summaryStartOrdinal = availableStart;
        }

        var records = HydrationStore.historyRecords(days);
        var chartReport = HydrationReport.build(records, chartStartOrdinal,
            endOrdinal, bucketCount);
        var summaryReport = chartReport;
        if (summaryStartOrdinal != chartStartOrdinal) {
            summaryReport = HydrationReport.build(records,
                summaryStartOrdinal, endOrdinal, bucketCount);
        }

        var metricFont = Graphics.FONT_XTINY;
        var metricHeight = dc.getFontHeight(metricFont);
        // Three summary lines: average, low/high, goals
        var summaryHeight = metricHeight * 3 + gap * 2;
        var chartBottom = bottom - summaryHeight - gap;
        var minimumChartHeight = compact ? 28 : 38;
        if (chartBottom - top < minimumChartHeight) {
            chartBottom = top + minimumChartHeight;
        }

        drawChart(dc, layout, chartReport, bucketCount, top, chartBottom);

        var unit = WatchUi.loadResource(Rez.Strings.unit_ml);
        var average = reportValue(summaryReport, 0);
        var low = reportValue(summaryReport, 1);
        var high = reportValue(summaryReport, 2);
        var goals = reportValue(summaryReport, 3);
        var dayCount = reportValue(summaryReport, 4);
        var summaryY = chartBottom + gap;

        // Line 1: average
        var averageText = WatchUi.loadResource(
            Rez.Strings.history_average) + " " + average.format("%d")
            + " " + unit;
        drawFittedLine(dc, layout, averageText, summaryY, metricFont,
            UiHelper.Colors.TEXT_PRIMARY);
        summaryY += metricHeight + gap;

        // Line 2: low / high (compact)
        var rangeText = WatchUi.loadResource(Rez.Strings.history_low)
            + " " + low.format("%d") + " " + unit + "  "
            + WatchUi.loadResource(Rez.Strings.history_high) + " "
            + high.format("%d") + " " + unit;
        drawFittedLine(dc, layout, rangeText, summaryY, metricFont,
            UiHelper.Colors.TEXT_SECONDARY);
        summaryY += metricHeight + gap;

        // Line 3: goals reached
        var goalsText = WatchUi.loadResource(Rez.Strings.history_goals)
            + " " + goals.format("%d") + "/"
            + dayCount.format("%d");
        drawFittedLine(dc, layout, goalsText, summaryY, metricFont,
            UiHelper.Colors.ACCENT_SUCCESS);
    }

    private function periodDays() as Number {
        if (mPeriod == PERIOD_FOUR_WEEKS) { return 28; }
        if (mPeriod == PERIOD_ONE_YEAR) { return 365; }
        return 7;
    }

    private function periodBuckets() as Number {
        if (mPeriod == PERIOD_FOUR_WEEKS) { return 4; }
        if (mPeriod == PERIOD_ONE_YEAR) { return 12; }
        return 7;
    }

    private function periodLabel(index as Number) {
        if (index == PERIOD_FOUR_WEEKS) {
            return WatchUi.loadResource(Rez.Strings.history_tab_4w);
        }
        if (index == PERIOD_ONE_YEAR) {
            return WatchUi.loadResource(Rez.Strings.history_tab_1y);
        }
        return WatchUi.loadResource(Rez.Strings.history_tab_7d);
    }

    private function drawTabs(dc as Dc, layout as UiHelper.Layout,
            y as Number, height as Number, font) as Void {
        var centerY = y + height / 2;
        var width = layout.safeWidthAtY(centerY) * 9 / 10;
        if (width > 300) { width = 300; }
        var left = layout.centerX - width / 2;
        var segmentWidth = width / PERIOD_COUNT;

        dc.setColor(UiHelper.Colors.BACKGROUND_CARD,
            Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, y, width, height, height / 2);

        var selectedLeft = left + segmentWidth * mPeriod;
        dc.setColor(UiHelper.Colors.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(selectedLeft, y, segmentWidth, height,
            height / 2);

        for (var i = 0; i < PERIOD_COUNT; i += 1) {
            var color = i == mPeriod ? UiHelper.Colors.TEXT_INVERSE
                : UiHelper.Colors.TEXT_SECONDARY;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + segmentWidth * i + segmentWidth / 2,
                centerY, font, periodLabel(i),
                Graphics.TEXT_JUSTIFY_CENTER
                    | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawChart(dc as Dc, layout as UiHelper.Layout,
            report, bucketCount as Number, top as Number,
            bottom as Number) as Void {
        if (bottom <= top || bucketCount <= 0) { return; }

        var middleY = top + (bottom - top) / 2;
        var width = layout.safeWidthAtY(top);
        var middleWidth = layout.safeWidthAtY(middleY);
        var bottomWidth = layout.safeWidthAtY(bottom);
        if (middleWidth < width) { width = middleWidth; }
        if (bottomWidth < width) { width = bottomWidth; }
        width = width * 9 / 10;
        if (width > 330) { width = 330; }
        if (width <= 0) { return; }

        var maximum = 1;
        for (var maxBucket = 0; maxBucket < bucketCount;
                maxBucket += 1) {
            var hydration = reportValue(report,
                REPORT_SUMMARY_SIZE
                    + maxBucket * REPORT_BUCKET_STRIDE);
            var target = reportValue(report,
                REPORT_SUMMARY_SIZE
                    + maxBucket * REPORT_BUCKET_STRIDE + 1);
            if (hydration > maximum) { maximum = hydration; }
            if (target > maximum) { maximum = target; }
        }

        var left = layout.centerX - width / 2;
        var baseline = bottom - 1;
        var usableHeight = baseline - top;
        var slotWidth = width / bucketCount;
        var barWidth = slotWidth * 5 / 10;
        if (barWidth < 3) { barWidth = 3; }
        if (barWidth > 16) { barWidth = 16; }

        dc.setPenWidth(1);
        dc.setColor(0x24282E, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, top + usableHeight / 2,
            left + width, top + usableHeight / 2);
        dc.drawLine(left, baseline, left + width, baseline);

        for (var bucket = 0; bucket < bucketCount; bucket += 1) {
            var hydrationValue = reportValue(report,
                REPORT_SUMMARY_SIZE + bucket * REPORT_BUCKET_STRIDE);
            var targetValue = reportValue(report,
                REPORT_SUMMARY_SIZE + bucket * REPORT_BUCKET_STRIDE + 1);
            var centerX = left + bucket * slotWidth + slotWidth / 2;
            var hydrationHeight = (hydrationValue.toFloat()
                / maximum * usableHeight).toNumber();
            var targetHeight = (targetValue.toFloat()
                / maximum * usableHeight).toNumber();

            if (targetHeight > 0) {
                dc.setColor(0x5D6670, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(centerX - barWidth / 2 - 1,
                    baseline - targetHeight,
                    centerX + barWidth / 2 + 1,
                    baseline - targetHeight);
            }

            var barColor = targetValue > 0
                    && hydrationValue >= targetValue
                ? UiHelper.Colors.ACCENT_SUCCESS
                : UiHelper.Colors.ACCENT;
            dc.setColor(barColor, Graphics.COLOR_TRANSPARENT);
            if (hydrationHeight > 0) {
                dc.fillRectangle(centerX - barWidth / 2,
                    baseline - hydrationHeight, barWidth,
                    hydrationHeight);
            } else {
                dc.fillCircle(centerX, baseline, 1);
            }
        }
    }

    private function reportValue(report, index as Number) as Number {
        if (!(report instanceof Lang.Array)) { return 0; }
        var values = report as Array<Number>;
        if (index >= 0 && index < values.size()) {
            return values[index];
        }
        return 0;
    }

    private function drawFittedLine(dc as Dc, layout as UiHelper.Layout,
            text, y as Number, preferredFont, color as Number) as Void {
        var font = preferredFont;
        var availableWidth = layout.safeWidthAtY(y);
        if (dc.getTextWidthInPixels(text, font) > availableWidth) {
            font = Graphics.FONT_GLANCE;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(layout.centerX, y, font, text,
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}
