import Toybox.Background;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class DiagnosticsView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var layout = new UiHelper.Layout(dc);
        var currentY = layout.safeTop() + UiHelper.Spacing.SMALL;

        dc.setColor(UiHelper.Colors.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(layout.centerX, currentY, Graphics.FONT_TINY,
            WatchUi.loadResource(Rez.Strings.menu_diagnostics),
            Graphics.TEXT_JUSTIFY_CENTER);
        currentY += dc.getFontHeight(Graphics.FONT_TINY)
            + UiHelper.Spacing.SMALL;

        var notificationsOn = SettingsManager.notificationsEnabled();
        var remindersOn = SettingsManager.remindersEnabled();
        var registered = "NO";
        var temporal = null;
        if ((Toybox has :Background) && (Background has :getTemporalEventRegisteredTime)) {
            temporal = Background.getTemporalEventRegisteredTime();
            registered = temporal != null ? "YES" : "NO";
        }

        var lastRun = DiagnosticsView.formatMoment(HydrationStore.getBackgroundLastRunAt());
        var lastRunReason = HydrationStore.getBackgroundLastRunReason();
        var lastNotificationAt = DiagnosticsView.formatMoment(HydrationStore.getNotificationLastAt());
        var lastNotificationReason = HydrationStore.getNotificationLastReason();
        var remindersToday = HydrationStore.getNumber(
            "hydrationReminder.remindersToday");
        var lastReminderLevel = HydrationStore.getNumber(
            "hydrationReminder.lastReminderLevel");
        var quietUntil = HydrationStore.getNumber(
            "hydrationReminder.quietUntil");
        var quietText = quietUntil > Time.now().value()
            ? DiagnosticsView.formatMoment(quietUntil) : "-";

        var lines = [
            "N " + (notificationsOn ? "ON" : "OFF")
                + " | R " + (remindersOn ? "ON" : "OFF")
                + " | API " + ((Toybox has :Notifications) ? "YES" : "NO"),
            "BG " + registered
                + " | " + DiagnosticsView.formatTemporal(temporal),
            "Run: " + lastRun + " " + lastRunReason,
            "Notif: " + lastNotificationAt + " " + lastNotificationReason,
            "Today: " + remindersToday + "/"
                + AppConfig.REMINDER_MAX_DAILY_REMINDERS
                + " | Level: " + lastReminderLevel,
            "Quiet: " + quietText
        ];

        var lineHeight = dc.getFontHeight(Graphics.FONT_XTINY)
            + UiHelper.Spacing.SMALL;
        for (var i = 0; i < lines.size(); i++) {
            UiHelper.Text.drawWrapped(dc, lines[i], Graphics.FONT_XTINY,
                Graphics.COLOR_WHITE, layout.centerX, currentY,
                layout.safeWidthAtY(currentY), Graphics.TEXT_JUSTIFY_CENTER,
                1, true);
            currentY += lineHeight;
        }
    }

    private static function formatMoment(value) {
        if (value == null) { return "-"; }
        var moment;
        if (value instanceof Time.Moment) {
            moment = value;
        } else if (value instanceof Lang.Number && value > 0) {
            moment = new Time.Moment(value);
        } else {
            return "-";
        }
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }

    private static function formatTemporal(value) {
        if (value == null) { return "NONE"; }
        if (value instanceof Time.Moment) {
            return DiagnosticsView.formatMoment(value);
        }
        if (value instanceof Time.Duration) {
            var seconds = value.value();
            if (seconds >= 3600 && (seconds % 3600) == 0) {
                return (seconds / 3600) + "h";
            }
            if (seconds >= 60) {
                return (seconds / 60) + "m";
            }
            return seconds + "s";
        }
        return "-";
    }
}

class DiagnosticsDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
