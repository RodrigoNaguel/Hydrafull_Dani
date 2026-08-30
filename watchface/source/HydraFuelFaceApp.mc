import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class HydraFuelFaceApp extends Application.AppBase {
    private var _view as HydraFuelFaceView?;
    private var _editMode as Boolean = false;

    function initialize() {
        AppBase.initialize();
        _view = null;
    }

    function onStart(state as Dictionary?) as Void {
        if (state != null
                && state.hasKey(:launchedFromWatchFaceSettingsEditor)) {
            var launched = state[:launchedFromWatchFaceSettingsEditor]
                as Boolean?;
            _editMode = launched == true;
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new HydraFuelFaceView(_editMode);
        _view = view;
        return [view, new HydraFuelFaceDelegate(view, _editMode)];
    }

    function onSettingsChanged() as Void {
        var view = _view;
        if (view != null) {
            view.reloadSettings();
        }
    }
}

function getHydraFuelFaceApp() as HydraFuelFaceApp {
    return Application.getApp() as HydraFuelFaceApp;
}
