import Toybox.Lang;
import Toybox.Notifications;
import Toybox.System;

(:background)
class NotificationManager {
    static function notificationsSupported() as Boolean {
        return (Toybox has :Notifications);
    }

    static function notifyReminder(message as String) as Boolean {
        if (!SettingsManager.notificationsEnabled()) {
            return false;
        }
        if (!(Toybox has :Notifications)) {
            return false;
        }

        return NotificationManager.showNotification(
            "HydraFuel",
            message,
            "reminder",
            HydrationStore.getNumber("hydrationReminder.remindersToday") == 0
        );
    }

    static function notifyCelebration(message as String) as Boolean {
        if (!SettingsManager.notificationsEnabled()) {
            return false;
        }
        if (!(Toybox has :Notifications)) {
            return false;
        }

        return NotificationManager.showNotification(
            "HydraFuel",
            message,
            "celebration",
            false
        );
    }

    static function notifyTest() as Boolean {
        if (!SettingsManager.notificationsEnabled()) {
            return false;
        }
        if (!(Toybox has :Notifications)) {
            return false;
        }

        return NotificationManager.showNotification(
            Rez.Strings.notification_test_title,
            Rez.Strings.notification_test_message,
            "test",
            false
        );
    }

    private static function showNotification(
            title as String or ResourceId,
            message as String or ResourceId,
            reason as String,
            dismissPrevious as Boolean) as Boolean {
        try {
            Notifications.showNotification(
                title,
                Rez.Strings.notification_subtitle,
                {
                    // These devices hide the subtitle in notification
                    // previews, so the rotating message belongs in the body.
                    :body => message,
                    :dismissPrevious => dismissPrevious
                }
            );
        } catch (error) {
            System.println("[HydraFuel] Notification error: " + error);
            return false;
        }

        // Notification delivery succeeded. Diagnostics are best effort and
        // must not turn that success into a retry that sends a duplicate.
        try {
            HydrationStore.recordNotification(reason);
        } catch (error) {
            System.println("[HydraFuel] Notification telemetry error: " + error);
        }
        return true;
    }
}
