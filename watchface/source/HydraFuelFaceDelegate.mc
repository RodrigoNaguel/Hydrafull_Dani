import Toybox.Application.WatchFaceConfig;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.WatchUi;

class HydraFuelFaceDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as HydraFuelFaceView;
    private var _editMode as Boolean;

    function initialize(view as HydraFuelFaceView, editMode as Boolean) {
        WatchFaceDelegate.initialize();
        _view = view;
        _editMode = editMode;
    }

    function onWatchFaceConfigEdited(options as {
            :configId as WatchFaceConfig.Id,
            :type as WatchFaceConfigType?,
            :committed as Boolean}) as Void {
        var config = WatchFaceConfig.getSettings(options[:configId]);
        if (config != null) {
            _view.applyNativeConfiguration(config);
        }
    }

    function getComplicationDrawable(
            complication as WatchFaceConfig.ComplicationRef)
            as Drawable or ComplicationDrawableRef or Null {
        var uniqueIdentifier = complication.uniqueIdentifier;
        if (uniqueIdentifier instanceof Lang.Number) {
            return _view.getSlotPreview(uniqueIdentifier as Number);
        }
        return null;
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        if (!_editMode) { return false; }
        var coordinates = clickEvent.getCoordinates();
        if (_view.isInsideTopLeftSlot(coordinates[0], coordinates[1])) {
            setSelectedComplication(FaceSlot.TOP_LEFT);
            return true;
        }
        if (_view.isInsideBottomLeftSlot(coordinates[0], coordinates[1])) {
            setSelectedComplication(FaceSlot.BOTTOM_LEFT);
            return true;
        }
        if (_view.isInsideTopRightSlot(coordinates[0], coordinates[1])) {
            setSelectedComplication(FaceSlot.TOP_RIGHT);
            return true;
        }
        return false;
    }

    function onPress(clickEvent as ClickEvent) as Boolean {
        if (_editMode) { return false; }
        var coordinates = clickEvent.getCoordinates();
        var id = null;

        if (_view.isInsideTopLeftSlot(coordinates[0], coordinates[1])) {
            id = _view.getTopLeftId();
        } else if (_view.isInsideBottomLeftSlot(coordinates[0], coordinates[1])) {
            id = _view.getBottomLeftId();
        } else if (_view.isInsideTopRightSlot(coordinates[0], coordinates[1])) {
            id = _view.getTopRightId();
        } else if (_view.isInsideHeartRate(coordinates[0], coordinates[1])) {
            id = _view.getHeartRateId();
        } else if (_view.isInsideHydration(coordinates[0], coordinates[1])) {
            id = _view.getHydrationId();
        }

        if (id == null) { return false; }
        try {
            Complications.exitTo(id as Complications.Id);
            return true;
        } catch (error) {
            return false;
        }
    }
}
