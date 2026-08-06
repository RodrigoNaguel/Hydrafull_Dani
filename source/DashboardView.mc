import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class DashboardView extends WatchUi.View {
    private const WATER_COLOR = 0x00AEEB;
    private const WATER_DARK = 0x062A38;
    private const CAFFEINE_COLOR = 0xFF8A3D;
    private const DANGER_COLOR = 0xFF4D5A;
    private const CARD_COLOR = 0x171A1F;
    private const MUTED_COLOR = 0xA8B0B8;

    private var mCelebrationTimer as Timer.Timer?;
    private var mCelebrationFrame as Number = -1;
    private var mCactusTimer as Timer.Timer?;
    private var mCactusFrame as Number = 0;

    function initialize() {
        View.initialize();
    }

    function triggerCelebration() as Void {
        startCelebration();
    }

    function onShow() as Void {
        if (mCactusTimer == null) {
            mCactusTimer = new Timer.Timer();
            mCactusTimer.start(method(:onCactusTick), 200, true);
        }
    }

    function onCactusTick() as Void {
        mCactusFrame = (mCactusFrame + 1) % 4;
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        stopCelebration();
        if (mCactusTimer != null) {
            mCactusTimer.stop();
            mCactusTimer = null;
        }
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
        var width = dc.getWidth();
        var height = dc.getHeight();
        var diameter = width < height ? width : height;
        var centerX = width / 2;
        var centerY = height / 2;
        var waterMl = HydrationStore.getNumber("waterMl");
        var caffeineMg = HydrationStore.getNumber("caffeineTodayMg");
        var weightKg = WellnessReader.weightKg();
        var totalCalories = HydrationStore.getNumber("lastCalories");
        var targetMl = HydrationCalculator.adjustedWaterMl(
            weightKg, totalCalories).toNumber();
        var rawProgress = waterMl.toFloat() / targetMl;
        var progress = HydrationCalculator.clamp(rawProgress, 0.0, 1.0);
        var percent = (rawProgress * 100.0).toNumber();
        var missingMl = targetMl - waterMl;
        if (missingMl < 0) { missingMl = 0; }

        // Edge progress arc (subtle arc around screen border)
        drawEdgeArc(dc, centerX, centerY, diameter, progress);

        // Title
        dc.setColor(WATER_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 80), Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.title_hydration),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Show daily target (meta)
        dc.setColor(MUTED_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 140), Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.label_goal) + " " + targetMl.format("%d") + " ml",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Water amount - big centered number
        var waterText = waterMl.format("%d") + " ml";
        var valueFont = Graphics.FONT_LARGE;
        if (dc.getTextWidthInPixels(waterText, valueFont)
                > scale(diameter, 600)) {
            valueFont = Graphics.FONT_MEDIUM;
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 300), valueFont, waterText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Percentage and missing
        var progressText;
        if (waterMl >= targetMl) {
            progressText = percent.format("%d") + "% | +"
                + (waterMl - targetMl).format("%d") + " ML";
        } else {
            progressText = percent.format("%d") + "% | " 
                + WatchUi.loadResource(Rez.Strings.label_missing) + " "
                + missingMl.format("%d") + " ML";
        }
        dc.setColor(MUTED_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 420), Graphics.FONT_XTINY,
            progressText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Personalized messages
        var resultTitle;
        var resultDetail;
        if (rawProgress < 0.25) {
            resultTitle = WatchUi.loadResource(Rez.Strings.label_daniela_warn);
            resultDetail = WatchUi.loadResource(Rez.Strings.label_cactus_msg);
        } else if (rawProgress < 0.80) {
            resultTitle = WatchUi.loadResource(Rez.Strings.label_love_remind);
            resultDetail = WatchUi.loadResource(Rez.Strings.label_forget_water);
        } else if (rawProgress < 1.0) {
            resultTitle = WatchUi.loadResource(Rez.Strings.label_almost);
            resultDetail = WatchUi.loadResource(Rez.Strings.label_just_more) + " " + missingMl.format("%d") + " ML";
        } else {
            resultTitle = WatchUi.loadResource(Rez.Strings.label_congrats);
            resultDetail = WatchUi.loadResource(Rez.Strings.label_hydrated);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 500), Graphics.FONT_XTINY,
            resultTitle,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(WATER_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 560), Graphics.FONT_XTINY,
            resultDetail,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Cactus when low hydration
        if (rawProgress < 0.25) {
            drawCactusAnimation(dc, centerX, scale(diameter, 720), diameter);
        }

        // Caffeine card (when not showing cactus)
        if (rawProgress >= 0.25) {
            var remaining = HydrationStore.caffeineRemaining(
                AppConfig.DEFAULT_CAFFEINE_HALF_LIFE_HOURS).toNumber();
            var caffeineWarning = HydrationCalculator.caffeineDailyWarningMg(weightKg);
            var caffeineAccent = caffeineMg >= caffeineWarning
                ? DANGER_COLOR : CAFFEINE_COLOR;
            var cardX = scale(diameter, 120);
            var cardY = scale(diameter, 650);
            var cardWidth = scale(diameter, 760);
            var cardHeight = scale(diameter, 95);
            dc.setColor(CARD_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cardX, cardY, cardWidth, cardHeight,
                cardHeight / 2);
            dc.setColor(caffeineAccent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX,
                cardY + cardHeight / 2, Graphics.FONT_XTINY,
                caffeineMg.format("%d") + "mg | " + WatchUi.loadResource(Rez.Strings.label_active) 
                    + remaining.format("%d") + "mg",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Bottom hint
        dc.setColor(MUTED_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 820), Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.label_tap_add),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawCactusAnimation(dc, x, y, diameter) as Void {
        var vibrationX = (mCactusFrame == 1) ? 2 : ((mCactusFrame == 3) ? -2 : 0);
        var cx = x + vibrationX;
        var cy = y;

        // Base/vaso
        dc.setColor(0x8B4513, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - scale(diameter, 40), cy + scale(diameter, 50), scale(diameter, 80), scale(diameter, 40));
        
        // Corpo do cacto
        dc.setColor(0x228B22, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - scale(diameter, 30), cy - scale(diameter, 80), scale(diameter, 60), scale(diameter, 140), scale(diameter, 30));
        
        // Braco esquerdo
        dc.fillRoundedRectangle(cx - scale(diameter, 70), cy - scale(diameter, 20), scale(diameter, 50), scale(diameter, 30), scale(diameter, 15));
        dc.fillRoundedRectangle(cx - scale(diameter, 70), cy - scale(diameter, 50), scale(diameter, 30), scale(diameter, 50), scale(diameter, 15));

        // Braco direito
        dc.fillRoundedRectangle(cx + scale(diameter, 20), cy, scale(diameter, 50), scale(diameter, 30), scale(diameter, 15));
        dc.fillRoundedRectangle(cx + scale(diameter, 40), cy - scale(diameter, 30), scale(diameter, 30), scale(diameter, 50), scale(diameter, 15));

        // Olhos bravos
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - scale(diameter, 12), cy - scale(diameter, 40), scale(diameter, 8));
        dc.fillCircle(cx + scale(diameter, 12), cy - scale(diameter, 40), scale(diameter, 8));
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - scale(diameter, 12), cy - scale(diameter, 40), scale(diameter, 4));
        dc.fillCircle(cx + scale(diameter, 12), cy - scale(diameter, 40), scale(diameter, 4));
        
        // Sobrancelhas bravas
        dc.setPenWidth(3);
        dc.drawLine(cx - scale(diameter, 25), cy - scale(diameter, 55), cx - scale(diameter, 5), cy - scale(diameter, 45));
        dc.drawLine(cx + scale(diameter, 5), cy - scale(diameter, 45), cx + scale(diameter, 25), cy - scale(diameter, 55));
        dc.setPenWidth(1);
        
        // Espinhos (tracinhos)
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            dc.drawLine(cx - scale(diameter, 20), cy - scale(diameter, 60) + i*20, cx - scale(diameter, 25), cy - scale(diameter, 65) + i*20);
            dc.drawLine(cx + scale(diameter, 20), cy - scale(diameter, 50) + i*20, cx + scale(diameter, 25), cy - scale(diameter, 55) + i*20);
        }
    }

    private function drawEdgeArc(dc, centerX, centerY, diameter, progress) as Void {
        // Thin arc hugging the screen edge as progress indicator
        var edgeRadius = diameter / 2 - 4;
        dc.setPenWidth(8);
        dc.setColor(WATER_DARK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, edgeRadius,
            Graphics.ARC_CLOCKWISE, 90, 270);
        if (progress > 0.0) {
            dc.setColor(WATER_COLOR, Graphics.COLOR_TRANSPARENT);
            var sweepAngle = (360.0 * progress).toNumber();
            if (sweepAngle > 360) { sweepAngle = 360; }
            var endAngle = 90 - sweepAngle;
            if (endAngle < -270) { endAngle = -270; }
            dc.drawArc(centerX, centerY, edgeRadius,
                Graphics.ARC_CLOCKWISE, 90, endAngle);
        }
        dc.setPenWidth(1);
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
            "PARABENS!",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 700), Graphics.FONT_XTINY,
            "VOCE BATEU A META",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(WATER_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 785), Graphics.FONT_XTINY,
            "HIDRATACAO EM DIA",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(MUTED_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, scale(diameter, 885), Graphics.FONT_XTINY,
            "MANDOU BEM!",
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
        return true;
    }

    function onPreviousPage() {
        return true;
    }

    function onSelect() {
        DrinkMenuBuilder.pushMenu(mView);
        return true;
    }
}
