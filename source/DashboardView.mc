import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class DashboardView extends WatchUi.View {
    private const WATER_COLOR = 0x00AEEB;
    private const CAFFEINE_COLOR = 0xFF8A3D;
    private const MUTED_COLOR = 0xA8B0B8;

    private var mCelebrationTimer as Timer.Timer?;
    private var mCelebrationFrame as Number = -1;

    function initialize() {
        View.initialize();
    }

    function triggerCelebration() as Void {
        startCelebration();
    }

    function onHide() as Void {
        stopCelebration();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (mCelebrationFrame >= 0) {
            drawCelebration(dc);
            return;
        }

        try {
            drawDashboard(dc);
        } catch (error) {
            System.println("Dashboard error: " + error);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
                Graphics.FONT_XTINY, "ERRO AO DESENHAR",
                Graphics.TEXT_JUSTIFY_CENTER
                    | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawDashboard(dc) as Void {
        var layout = new UiHelper.Layout(dc);
        var flow = new UiHelper.Flow(layout, layout.safeTop() + UiHelper.Spacing.SMALL);

        var buttonHeight = dc.getHeight() * 0.12;
        if (buttonHeight < 44) { buttonHeight = 44; }
        if (buttonHeight > 56) { buttonHeight = 56; }
        var buttonBottom = layout.safeBottom() - UiHelper.Spacing.SMALL;
        var buttonY = buttonBottom - buttonHeight;
        var contentBottom = buttonY - UiHelper.Spacing.MEDIUM;

        var waterMl = HydrationStore.getNumber("waterMl");
        var targetMl = HydrationStore.dailyTargetMl();
        var rawProgress = (targetMl > 0) ? (waterMl.toFloat() / targetMl) : 0.0;
        var progress = HydrationCalculator.clamp(rawProgress, 0.0, 1.0);

        var unitMl = WatchUi.loadResource(Rez.Strings.unit_ml);

        var titleFont = Graphics.FONT_XTINY;
        var titleHeight = dc.getFontHeight(titleFont);
        UiHelper.Text.drawWrapped(dc, WatchUi.loadResource(Rez.Strings.title_hydration), titleFont, UiHelper.Colors.ACCENT, layout.centerX, flow.y(), layout.safeWidthAtY(flow.y()), Graphics.TEXT_JUSTIFY_CENTER, 1, false);
        flow.advance(titleHeight + 2);

        var goalFont = Graphics.FONT_XTINY;
        var goalText = WatchUi.loadResource(Rez.Strings.label_goal) + " " + targetMl.format("%d") + unitMl;
        var goalHeight = dc.getFontHeight(goalFont);
        UiHelper.Text.drawWrapped(dc, goalText, goalFont, UiHelper.Colors.TEXT_SECONDARY, layout.centerX, flow.y(), layout.safeWidthAtY(flow.y()), Graphics.TEXT_JUSTIFY_CENTER, 1, false);
        flow.advance(goalHeight + UiHelper.Spacing.SMALL);

        var valueNumFont = Graphics.FONT_NUMBER_MILD;
        var valueNumText = waterMl.format("%d");
        var unitFont = Graphics.FONT_XTINY;
        var unitText = unitMl;

        var valueNumWidth = dc.getTextWidthInPixels(valueNumText, valueNumFont);
        var unitWidth = dc.getTextWidthInPixels(unitText, unitFont);
        var totalValueWidth = valueNumWidth + unitWidth + UiHelper.Spacing.SMALL;

        var safeValueWidth = layout.safeWidthAtY(flow.y()) * 0.9;

        if (totalValueWidth > safeValueWidth
                || flow.y() + dc.getFontHeight(valueNumFont)
                    + UiHelper.Spacing.SMALL + 10 + UiHelper.Spacing.SMALL
                    + dc.getFontHeight(Graphics.FONT_XTINY) > contentBottom) {
            valueNumFont = Graphics.FONT_LARGE;
            valueNumWidth = dc.getTextWidthInPixels(valueNumText, valueNumFont);
            totalValueWidth = valueNumWidth + unitWidth + UiHelper.Spacing.SMALL;
        }

        var valueNumX = layout.centerX - totalValueWidth / 2 + valueNumWidth / 2;
        var unitX = layout.centerX + totalValueWidth / 2 - unitWidth / 2;
        var valueY = flow.y();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(valueNumX, valueY, valueNumFont, valueNumText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(unitX, valueY + dc.getFontHeight(valueNumFont) - dc.getFontHeight(unitFont) - 4, unitFont, unitText, Graphics.TEXT_JUSTIFY_CENTER);
        flow.advance(dc.getFontHeight(valueNumFont) + UiHelper.Spacing.SMALL);

        var barHeight = 10;
        var barWidth = layout.safeWidthAtY(flow.y()) * 0.9;
        var barX = layout.centerX - barWidth / 2;
        UiHelper.ProgressBar.draw(dc, barX, flow.y(), barWidth, barHeight, progress, UiHelper.ProgressBar.colorForProgress(progress));
        flow.advance(barHeight + UiHelper.Spacing.SMALL);

        var progressFont = Graphics.FONT_XTINY;
        var progressText;
        if (rawProgress >= 1.0) {
            progressText = (rawProgress * 100).toNumber() + "%" + " | +" + (waterMl - targetMl) + unitMl;
        } else {
            progressText = (rawProgress * 100).toNumber() + "%" + " | " + (targetMl - waterMl) + unitMl + " " + WatchUi.loadResource(Rez.Strings.label_missing);
        }
        var progressHeight = dc.getFontHeight(progressFont);
        UiHelper.Text.drawWrapped(dc, progressText, progressFont, UiHelper.Colors.TEXT_SECONDARY, layout.centerX, flow.y(), layout.safeWidthAtY(flow.y()), Graphics.TEXT_JUSTIFY_CENTER, 1, false);
        flow.advance(progressHeight);

        // Use the narrowest edge of the button on round displays so the pill
        // remains fully inside the visible circle.
        var buttonWidth = layout.safeWidthAtY(buttonBottom) * 0.8;
        var minButtonWidth = 120;
        var maxButtonWidth = 210;

        if (buttonWidth < minButtonWidth) {
            buttonWidth = minButtonWidth;
        }
        if (buttonWidth > maxButtonWidth) {
            buttonWidth = maxButtonWidth;
        }

        var buttonX = layout.centerX - buttonWidth / 2;
        var buttonText = WatchUi.loadResource(Rez.Strings.label_add_drink);

        dc.setColor(0x13202B, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(buttonX, buttonY, buttonWidth, buttonHeight, buttonHeight / 2);

        var buttonFont = Graphics.FONT_SMALL;
        if (dc.getTextWidthInPixels(buttonText, buttonFont) > buttonWidth - UiHelper.Spacing.LARGE) {
            buttonFont = Graphics.FONT_TINY;
        }
        dc.setColor(UiHelper.Colors.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        UiHelper.Text.drawWrapped(dc, buttonText, buttonFont, UiHelper.Colors.TEXT_SECONDARY,
            layout.centerX, buttonY + buttonHeight / 2 - dc.getFontHeight(buttonFont) / 2,
            buttonWidth - UiHelper.Spacing.LARGE, Graphics.TEXT_JUSTIFY_CENTER, 1, false);
    }

    private function startCelebration() as Void {
        stopCelebration();
        mCelebrationFrame = 0;
        var timer = new Timer.Timer();
        mCelebrationTimer = timer;
        timer.start(method(:onCelebrationTick), 100, true);
    }

    private function stopCelebration() as Void {
        if (mCelebrationTimer != null) {
            mCelebrationTimer.stop();
            mCelebrationTimer = null;
        }
        mCelebrationFrame = -1;
    }

    function onCelebrationTick() as Void {
        mCelebrationFrame += 1;
        if (mCelebrationFrame >= 22) {
            stopCelebration();
        }
        WatchUi.requestUpdate();
    }

    private function drawCelebration(dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var diameter = width < height ? width : height;
        var centerX = width / 2;

        dc.setColor(0x00151E, 0x00151E);
        dc.clear();
        drawConfetti(dc, width, height);

        var ringCenterY = scale(diameter, 325);
        var pulse = (mCelebrationFrame % 5) * scale(diameter, 6);
        var ringRadius = scale(diameter, 142) + pulse;
        dc.setPenWidth(6);
        dc.setColor(0x18D58B, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, ringCenterY, ringRadius);
        dc.setPenWidth(3);
        dc.setColor(0x0B6348, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, ringCenterY, ringRadius - scale(diameter, 18));

        dc.setPenWidth(8);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX - scale(diameter, 58), ringCenterY,
            centerX - scale(diameter, 13),
            ringCenterY + scale(diameter, 42));
        dc.drawLine(centerX - scale(diameter, 13),
            ringCenterY + scale(diameter, 42),
            centerX + scale(diameter, 70),
            ringCenterY - scale(diameter, 52));
        dc.setPenWidth(1);

        dc.setColor(0x18D58B, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 590), Graphics.FONT_SMALL,
            WatchUi.loadResource(Rez.Strings.label_congrats_title),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 700), Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.label_congrats_subtitle),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(WATER_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 785), Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.label_congrats_hydration),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(MUTED_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 885), Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.label_congrats_nice),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawConfetti(dc, width, height) as Void {
        for (var i = 0; i < 14; i += 1) {
            if ((i % 4) == 0) {
                dc.setColor(WATER_COLOR, Graphics.COLOR_TRANSPARENT);
            } else if ((i % 4) == 1) {
                dc.setColor(0x18D58B, Graphics.COLOR_TRANSPARENT);
            } else if ((i % 4) == 2) {
                dc.setColor(CAFFEINE_COLOR, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0xFFD166, Graphics.COLOR_TRANSPARENT);
            }
            var x = 20 + ((i * 67 + mCelebrationFrame * 11)
                % (width - 40));
            var y = 12 + ((i * 43 + mCelebrationFrame * (5 + (i % 3)))
                % (height - 24));
            dc.fillRectangle(x, y, 3 + (i % 3), 7 + (i % 4));
        }
    }

    private function scale(diameter, perThousand) {
        return diameter * perThousand / 1000;
    }
}

class DashboardDelegate extends WatchUi.BehaviorDelegate {
    private var mView;

    function initialize(view) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onNextPage() {
        return false;
    }

    function onPreviousPage() {
        return false;
    }

    function onSelect() {
        DrinkMenuBuilder.pushMenu(mView);
        return true;
    }
}
