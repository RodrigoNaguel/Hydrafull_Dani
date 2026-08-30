import Toybox.Lang;
import Toybox.Test;

(:test)
function testNotificationActionUsesRuntimeStringLabel(
        logger as Test.Logger) as Boolean {
    logger.debug("checking notification action label type");
    var action = NotificationManager.openAddDrinkAction();

    return action[:label] instanceof Lang.String
        && NotificationManager.ACTION_OPEN_ADD_DRINK.equals(action[:data]);
}
