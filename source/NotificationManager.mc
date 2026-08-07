import Toybox.Attention;
import Toybox.Lang;
import Toybox.Notifications;
import Toybox.System;

class NotificationManager {
    static function notificationsSupported() {
        return (Toybox has :Notifications);
    }

    static function notifyReminder(message) {
        if (!(Toybox has :Notifications)) { return; }
        try {
            Notifications.showNotification(message,
                "Toca para abrir HydraFuel",
                null);
            NotificationManager.requestAttention();
        } catch (error) {
            System.println("Notification error: " + error);
        }
    }

    static function notifyCelebration(message) {
        if (!(Toybox has :Notifications)) { return; }
        try {
            Notifications.showNotification(message,
                "Meta do dia atingida!",
                null);
            NotificationManager.requestAttention();
        } catch (error) {
            System.println("Notification error: " + error);
        }
    }

    private static function requestAttention() {
        if (!(Toybox has :Attention)) { return; }
        try {
            if (Attention has :vibrate) {
                Attention.vibrate([
                    new Attention.VibeProfile(25, 400)
                ]);
            }
        } catch (error) {
            System.println("Attention error: " + error);
        }
    }
}