import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;

// Garmin app settings are the only phone input surface available without a
// separate iOS/Android companion. Changing the toggle produces a one-shot
// request. The last consumed value prevents ordinary repeated background
// wakes from applying the same synchronized setting again.
(:glance, :background)
class PhoneDrinkBridge {
    private static const LAST_TOKEN_KEY = "phoneDrink.lastTokenV1";

    static function processPending() as Boolean {
        var token = SettingsManager.phoneAddToken();
        var stored = Storage.getValue(LAST_TOKEN_KEY);
        
        if (stored == null) {
            // First run on this device. Sync the baseline state without
            // triggering a drink, even if the cloud setting is true.
            Storage.setValue(LAST_TOKEN_KEY, token);
            return false;
        }

        var lastToken = stored as Boolean;
        if (token == lastToken) { return false; }

        // Consume first so an interrupted foreground/background wake cannot
        // add the same request twice. A power loss in the narrow interval
        // before record() can instead lose that request; App Settings do not
        // provide a transactional command queue.
        Storage.setValue(LAST_TOKEN_KEY, token);

        var recorded = DrinkCatalog.record(
            SettingsManager.phoneDrinkId(),
            SettingsManager.phoneDrinkServings(),
            DrinkCatalog.SOURCE_PHONE);

        if (recorded) { HydrationStore.dailyTargetMl(); }
        // Invalid requests remain consumed; otherwise every background wake
        // would retry a malformed setting forever.
        Storage.setValue("phoneDrink.lastProcessedAt", Toybox.Time.now().value());
        Storage.setValue("phoneDrink.lastResult",
            recorded ? "added" : "invalid");
        if (!recorded) {
            System.println("[HydraFuel] Invalid phone drink request");
        }
        return recorded;
    }
}
