import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Application.WatchFaceConfig;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class HydraFuelFaceView extends WatchUi.WatchFace {
    private const HYDRATION_ID_KEY = "hydrafuel.complicationId";
    private const HYDRATION_SHORT_LABEL = "HYDRA";
    private const CAFFEINE_ID_KEY = "hydrafuel.caffeineComplicationId";
    private const CAFFEINE_SHORT_LABEL = "CAFFEINE";
    private const WATER_COLOR = 0x00B5FF;
    private const DEBUG_LAYOUT = false;

    private var _sleeping as Boolean = false;
    private var _isShown as Boolean = false;
    private var _requiresBurnInProtection as Boolean = false;
    private var _width as Number = 0;
    private var _height as Number = 0;

    private var _style as Number = FaceStyle.BALANCED;
    private var _theme as Number = FaceTheme.NEON_PURPLE;
    private var _accentColor as Number = 0xFF4FD8;
    private var _secondaryColor as Number = 0xB9A3FF;
    private var _dataColor as Number = Graphics.COLOR_WHITE;
    private var _backgroundColor as Number = Graphics.COLOR_BLACK;
    private var _bandColor as Number = 0x161047;
    private var _bandHighlightColor as Number = 0x38218A;
    private var _surfaceColor as Number = 0x0D0918;
    private var _unitFont as Graphics.VectorFont? = null;
    private var _compactValueFont as Graphics.VectorFont? = null;
    private var _smokeTexture as BitmapResource;

    private var _leftId as Complications.Id;
    private var _centerId as Complications.Id;
    private var _rightId as Complications.Id;
    private var _hydrationId as Complications.Id?;
    private var _caffeineId as Complications.Id?;

    private var _leftValue as String = "--";
    private var _centerValue as String = "--";
    private var _rightValue as String = "--";
    private var _waterMl as Number? = null;
    private var _targetMl as Number? = null;
    private var _caffeineValue as String = "--";
    private var _dataDirty as Boolean = true;
    private var _lastRefreshMinute as Number = -1;

    function initialize(editMode as Boolean) {
        WatchFace.initialize();
        _leftId = new Complications.Id(
            Complications.COMPLICATION_TYPE_CALORIES);
        _centerId = new Complications.Id(
            Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE);
        _rightId = new Complications.Id(
            Complications.COMPLICATION_TYPE_BODY_BATTERY);
        _smokeTexture = WatchUi.loadResource(
            Rez.Drawables.SmokeTexture) as BitmapResource;
        _hydrationId = null;
        _caffeineId = null;
    }

    function onLayout(dc as Dc) as Void {
        _width = dc.getWidth();
        _height = dc.getHeight();
        _requiresBurnInProtection =
            System.getDeviceSettings().requiresBurnInProtection;
        _unitFont = null;
        _compactValueFont = null;
        if (Graphics has :getVectorFont) {
            _unitFont = Graphics.getVectorFont({
                :font => Graphics.FONT_XTINY,
                :scale => 0.54
            });
            _compactValueFont = Graphics.getVectorFont({
                :font => Graphics.FONT_XTINY,
                :scale => 0.72
            });
        }
        reloadSettings();
    }

    function onShow() as Void {
        _isShown = true;
        subscribeToComplications();
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        _isShown = false;
        try {
            Complications.registerComplicationChangeCallback(null);
            Complications.unsubscribeFromAllUpdates();
        } catch (error) {
            System.println("[HydraFuelFace] unsubscribe error: " + error);
        }
    }

    function onEnterSleep() as Void { _sleeping = true; }
    function onExitSleep() as Void { _sleeping = false; }

    function onUpdate(dc as Dc) as Void {
        _width = dc.getWidth();
        _height = dc.getHeight();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var minute = System.getClockTime().min;
        if (_dataDirty || minute != _lastRefreshMinute) {
            refreshComplicationValues();
            _dataDirty = false;
            _lastRefreshMinute = minute;
        }
        if (_sleeping && _requiresBurnInProtection) {
            drawAlwaysOn(dc);
        } else {
            drawActive(dc);
        }
    }

    function reloadSettings() as Void {
        _style = FaceFormatter.propertyNumber("style", FaceStyle.BALANCED);
        _theme = FaceFormatter.propertyNumber(
            "background_theme", FaceTheme.NEON_PURPLE);
        _accentColor = FaceFormatter.propertyNumber(
            "accent_color", 0xFF4FD8);
        _secondaryColor = FaceFormatter.propertyNumber(
            "secondary_color", 0xB9A3FF);
        _dataColor = FaceFormatter.propertyNumber(
            "data_color", Graphics.COLOR_WHITE);
        _leftId = new Complications.Id(FaceFormatter.propertyNumber(
            "left_data", Complications.COMPLICATION_TYPE_CALORIES)
                as Complications.Type);
        _centerId = new Complications.Id(FaceFormatter.propertyNumber(
            "center_data", Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE)
                as Complications.Type);
        _rightId = new Complications.Id(FaceFormatter.propertyNumber(
            "right_data", Complications.COMPLICATION_TYPE_BODY_BATTERY)
                as Complications.Type);

        resolvePalette();
        loadNativeConfiguration();
        resolveHydrationComplication();
        _dataDirty = true;
        if (_isShown) { subscribeToComplications(); }
        WatchUi.requestUpdate();
    }

    function applyNativeConfiguration(
            config as WatchFaceConfig.Settings) as Void {
        applyNativeConfigurationValues(config);
        _dataDirty = true;
        if (_isShown) { subscribeToComplications(); }
        WatchUi.requestUpdate();
    }

    private function applyNativeConfigurationValues(
            config as WatchFaceConfig.Settings) as Void {
        var styleId = config.styleId;
        if (styleId != null) { _style = styleId; }

        var accent = config.accentColor;
        if (accent != null && accent.color != null) {
            _accentColor = accent.color as Number;
        }
        var dataColor = config.complicationColor;
        if (dataColor != null && dataColor.color != null) {
            _dataColor = dataColor.color as Number;
        }

        var settings = config.complicationSettings;
        if (settings != null) {
            for (var i = 0; i < settings.size(); i += 1) {
                var setting = settings[i];
                var id = setting.complicationId;
                if (id == null || setting.uniqueIdentifier == null) {
                    continue;
                }
                if (setting.uniqueIdentifier == FaceSlot.LEFT) {
                    _leftId = id;
                } else if (setting.uniqueIdentifier == FaceSlot.CENTER) {
                    _centerId = id;
                } else if (setting.uniqueIdentifier == FaceSlot.RIGHT) {
                    _rightId = id;
                }
            }
        }
    }

    function onComplicationChanged(id as Complications.Id) as Void {
        if (id.equals(_leftId) || id.equals(_centerId)
                || id.equals(_rightId)
                || (_hydrationId != null && id.equals(_hydrationId))) {
            _dataDirty = true;
            WatchUi.requestUpdate();
        }
        if (_caffeineId != null && id.equals(_caffeineId)) {
            _dataDirty = true;
            WatchUi.requestUpdate();
        }
    }

    function isInsideLeftSlot(x as Number, y as Number) as Boolean {
        return isInsideSlot(x, y, FaceSlot.LEFT);
    }

    function isInsideCenterSlot(x as Number, y as Number) as Boolean {
        return isInsideSlot(x, y, FaceSlot.CENTER);
    }

    function isInsideRightSlot(x as Number, y as Number) as Boolean {
        return isInsideSlot(x, y, FaceSlot.RIGHT);
    }

    function isInsideHydration(x as Number, y as Number) as Boolean {
        var size = screenSize();
        var regionX = hydrationX();
        var regionCenterY = screenCenterY();
        var dx = x - regionX;
        var dy = y - regionCenterY;
        var radius = size * 14 / 100;
        if ((dx * dx) + (dy * dy) <= radius * radius) {
            return true;
        }

        var progressX = goalX();
        var progressY = screenCenterY() + size * 29 / 100;
        dx = x - progressX;
        dy = y - progressY;
        radius = size * 11 / 100;
        return (dx * dx) + (dy * dy) <= radius * radius;
    }

    function getLeftId() as Complications.Id { return _leftId; }
    function getCenterId() as Complications.Id { return _centerId; }
    function getRightId() as Complications.Id { return _rightId; }
    function getHydrationId() as Complications.Id? { return _hydrationId; }

    function getSlotPreview(
            uniqueIdentifier as Number) as WatchUi.ComplicationDrawableRef? {
        if (_width <= 0 || _height <= 0) { return null; }
        if (uniqueIdentifier != FaceSlot.LEFT
                && uniqueIdentifier != FaceSlot.CENTER
                && uniqueIdentifier != FaceSlot.RIGHT) {
            return null;
        }
        var value = _leftValue;
        if (uniqueIdentifier == FaceSlot.CENTER) {
            value = _centerValue;
        } else if (uniqueIdentifier == FaceSlot.RIGHT) {
            value = _rightValue;
        }
        var bounds = slotBounds(uniqueIdentifier);
        var drawable = new SlotPreviewDrawable(bounds, value,
            _accentColor, _secondaryColor, _dataColor, _surfaceColor);
        return new WatchUi.ComplicationDrawableRef({
            :drawable => drawable,
            :boundingBox => bounds
        });
    }

    private function loadNativeConfiguration() as Void {
        if (!(Application has :WatchFaceConfig)) { return; }
        try {
            var config = WatchFaceConfig.getSettings(null);
            if (config != null) {
                applyNativeConfigurationValues(config);
            }
        } catch (error) {
            // Older products use the mobile properties.
        }
    }

    private function subscribeToComplications() as Void {
        if (!_isShown || _width <= 0 || _height <= 0) { return; }
        try {
            Complications.unsubscribeFromAllUpdates();
        } catch (error) {
            System.println("[HydraFuelFace] unsubscribe error: " + error);
        }
        try {
            Complications.registerComplicationChangeCallback(
                method(:onComplicationChanged));
        } catch (error) {
            System.println("[HydraFuelFace] callback error: " + error);
            return;
        }

        var subscriptions = [] as Array<Complications.Id>;
        var hydrationId = _hydrationId;
        if (hydrationId != null) {
            subscribeToComplication(hydrationId, subscriptions);
        }
        var caffeineId = _caffeineId;
        if (caffeineId != null) {
            subscribeToComplication(caffeineId, subscriptions);
        }
        subscribeToComplication(_leftId, subscriptions);
        subscribeToComplication(_centerId, subscriptions);
        subscribeToComplication(_rightId, subscriptions);
    }

    private function subscribeToComplication(id as Complications.Id,
            subscriptions as Array<Complications.Id>) as Void {
        for (var i = 0; i < subscriptions.size(); i += 1) {
            if (id.equals(subscriptions[i])) { return; }
        }
        subscriptions.add(id);
        try {
            if (!Complications.subscribeToUpdates(id)) {
                System.println(
                    "[HydraFuelFace] subscription unavailable: " + id);
            }
        } catch (error) {
            System.println("[HydraFuelFace] subscribe error: " + error);
        }
    }

    private function resolveHydrationComplication() as Void {
        var stored = Storage.getValue(HYDRATION_ID_KEY);
        if (stored instanceof Complications.Id) {
            _hydrationId = stored as Complications.Id;
            try {
                var saved = Complications.getComplication(
                    _hydrationId as Complications.Id);
                if (!HYDRATION_SHORT_LABEL.equals(saved.shortLabel)) {
                    _hydrationId = null;
                    Storage.deleteValue(HYDRATION_ID_KEY);
                }
            } catch (error) {
                _hydrationId = null;
                Storage.deleteValue(HYDRATION_ID_KEY);
            }
        } else if (stored != null) {
            Storage.deleteValue(HYDRATION_ID_KEY);
        }

        var storedCaffeine = Storage.getValue(CAFFEINE_ID_KEY);
        if (storedCaffeine instanceof Complications.Id) {
            _caffeineId = storedCaffeine as Complications.Id;
            try {
                var savedCaffeine = Complications.getComplication(
                    _caffeineId as Complications.Id);
                if (!CAFFEINE_SHORT_LABEL.equals(
                        savedCaffeine.shortLabel)) {
                    _caffeineId = null;
                    Storage.deleteValue(CAFFEINE_ID_KEY);
                }
            } catch (error) {
                _caffeineId = null;
                Storage.deleteValue(CAFFEINE_ID_KEY);
            }
        } else if (storedCaffeine != null) {
            Storage.deleteValue(CAFFEINE_ID_KEY);
        }

        try {
            var iterator = Complications.getComplications();
            var complication = iterator.next();
            while (complication != null) {
                if (complication.getType()
                        == Complications.COMPLICATION_TYPE_INVALID
                        && HYDRATION_SHORT_LABEL.equals(
                            complication.shortLabel)
                        && complication.complicationId != null) {
                    _hydrationId = complication.complicationId;
                    Storage.setValue(HYDRATION_ID_KEY, _hydrationId);
                }
                if (complication.getType()
                        == Complications.COMPLICATION_TYPE_INVALID
                        && CAFFEINE_SHORT_LABEL.equals(
                            complication.shortLabel)
                        && complication.complicationId != null) {
                    _caffeineId = complication.complicationId;
                    Storage.setValue(CAFFEINE_ID_KEY, _caffeineId);
                }
                complication = iterator.next();
            }
        } catch (error) {
            System.println(
                "[HydraFuelFace] hydration discovery error: " + error);
        }
    }

    private function refreshComplicationValues() as Void {
        var hydrationWasMissing = _hydrationId == null;
        var caffeineWasMissing = _caffeineId == null;
        if (hydrationWasMissing || caffeineWasMissing) {
            resolveHydrationComplication();
            if (_isShown
                    && ((hydrationWasMissing && _hydrationId != null)
                        || (caffeineWasMissing && _caffeineId != null))) {
                subscribeToComplications();
            }
        }

        _leftValue = readComplication(_leftId);
        _centerValue = readComplication(_centerId);
        _rightValue = readComplication(_rightId);
        _caffeineValue = readCaffeine();

        var hydrationId = _hydrationId;
        if (hydrationId == null) {
            _waterMl = null;
            _targetMl = null;
            return;
        }
        try {
            var complication = Complications.getComplication(hydrationId);
            var water = FaceFormatter.numberOrNull(complication.value);
            if (water == null) {
                _waterMl = null;
                _targetMl = null;
                return;
            }
            _waterMl = water;
            _targetMl = null;
            var ranges = complication.ranges;
            if (ranges != null && ranges.size() > 0) {
                var target = FaceFormatter.numberOrNull(
                    ranges[ranges.size() - 1]);
                if (target != null) { _targetMl = target; }
            }
        } catch (error) {
            _hydrationId = null;
            Storage.deleteValue(HYDRATION_ID_KEY);
            _waterMl = null;
            _targetMl = null;
        }
    }

    private function readCaffeine() as String {
        var caffeineId = _caffeineId;
        if (caffeineId == null) { return "--"; }
        try {
            var complication = Complications.getComplication(caffeineId);
            var value = FaceFormatter.numberOrNull(complication.value);
            if (value == null) { return "--"; }
            if (value < 0) { value = 0; }
            if (value > 9999) { value = 9999; }
            return value.format("%d");
        } catch (error) {
            _caffeineId = null;
            Storage.deleteValue(CAFFEINE_ID_KEY);
            return "--";
        }
    }

    private function readComplication(id as Complications.Id) as String {
        try {
            var complication = Complications.getComplication(id);
            var type = id.getType();
            if (type == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE) {
                return FaceFormatter.temperatureText(
                    complication.value,
                    System.getDeviceSettings().temperatureUnits
                        == System.UNIT_STATUTE);
            }
            var value = FaceFormatter.compactValue(complication.value);
            if (type == Complications.COMPLICATION_TYPE_BATTERY
                    && !value.equals("--")) {
                return value + "%";
            }
            return value;
        } catch (error) {
            return "--";
        }
    }

    private function drawActive(dc as Dc) as Void {
        drawBackground(dc);
        drawBands(dc);
        drawSystemHeader(dc);
        drawStackedTime(dc);
        if (_style != FaceStyle.MINIMAL) {
            drawDataSlot(dc, FaceSlot.LEFT, _leftId, _leftValue);
            drawDataSlot(dc, FaceSlot.CENTER, _centerId, _centerValue);
            drawDataSlot(dc, FaceSlot.RIGHT, _rightId, _rightValue);
        }
        drawHydration(dc);
        if (DEBUG_LAYOUT) {
            drawDebugLayout(dc);
        }
    }

    private function drawBackground(dc as Dc) as Void {
        dc.setColor(_backgroundColor, _backgroundColor);
        dc.clear();
        drawMist(dc);
    }

    private function drawMist(dc as Dc) as Void {
        var size = screenSize();
        dc.drawBitmap(screenCenterX() - size * 24 / 100,
            screenCenterY() - screenRadius(), _smokeTexture);
    }

    private function drawBands(dc as Dc) as Void {
        var size = screenSize();
        var radius = screenRadius();
        var topY = screenCenterY() - radius;
        var bandH = radius * 2;

        // Keep the divider compact and dark, then layer two progressively
        // finer violet/magenta details without expanding its footprint.
        var mainX = dividerX();
        dc.setColor(_bandColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mainX, topY, size * 6 / 100, bandH);

        dc.setColor(_secondaryColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mainX + size * 3 / 100, topY,
            size * 12 / 1000, bandH);

        dc.setColor(_accentColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mainX + size * 5 / 100, topY,
            size * 7 / 1000, bandH);
    }

    private function drawSystemHeader(dc as Dc) as Void {
        var size = screenSize();
        var mainCenterX = clockX();
        var headerY = screenCenterY() - size * 35 / 100;
        var iconWidth = size * 4 / 100;
        var iconHeight = iconWidth / 2;
        var battery = (System.getSystemStats().battery + 0.5).toNumber();
        var batteryText = battery.format("%d") + "%";
        var gap = size * 12 / 1000;
        var font = Graphics.FONT_XTINY;
        var textWidth = dc.getTextWidthInPixels(batteryText, font);
        var groupWidth = iconWidth + gap + textWidth;
        var startX = mainCenterX - groupWidth / 2;

        drawBattery(dc, startX, headerY - iconHeight / 2,
            iconWidth, iconHeight, battery);
        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + iconWidth + gap, headerY, font, batteryText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var date = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateText = date.day_of_week.toString()
            + " " + date.day.format("%02d");
        if (dc.getTextWidthInPixels(dateText, font) > size * 28 / 100) {
            dateText = date.day.format("%02d");
        }
        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mainCenterX, screenCenterY() - size * 27 / 100,
            font, dateText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawBattery(dc as Dc, x as Number, y as Number,
            width as Number, height as Number, level as Number) as Void {
        dc.setColor(_secondaryColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, width, height);
        dc.fillRectangle(x + width + 1, y + height / 3,
            width < 16 ? 2 : 3, height / 3 + 1);
        var fillWidth = (width - 4) * level / 100;
        if (fillWidth > 0) {
            dc.setColor(_accentColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 2, y + 2, fillWidth, height - 3);
        }
    }

    private function drawStackedTime(dc as Dc) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var hourText = hour.format("%02d");
        var minuteText = clock.min.format("%02d");
        var size = screenSize();
        var centerX = clockX();
        var font = selectTimeFont(dc, size);

        var hourY = screenCenterY() - size * 11 / 100;
        var minuteY = screenCenterY() + size * 14 / 100;

        dc.setColor(_accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, hourY, font, hourText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawOutlinedText(dc, centerX, minuteY,
            font, minuteText, _secondaryColor);
    }

    private function selectTimeFont(dc as Dc,
            size as Number) as Graphics.FontType {
        var font = Graphics.FONT_NUMBER_THAI_HOT;
        var maxWidth = size * 34 / 100;
        var maxHeight = size * 32 / 100;
        if (dc.getTextWidthInPixels("88", font) > maxWidth
                || dc.getFontHeight(font) > maxHeight) {
            font = Graphics.FONT_NUMBER_HOT;
        }
        if (dc.getTextWidthInPixels("88", font) > maxWidth
                || dc.getFontHeight(font) > maxHeight) {
            font = Graphics.FONT_NUMBER_MEDIUM;
        }
        return font;
    }

    private function drawOutlinedText(dc as Dc, x as Number, y as Number,
            font as Graphics.FontType, text as String,
            outlineColor as Number) as Void {
        var offset = screenSize() * 4 / 1000;
        if (offset < 1) { offset = 1; }
        dc.setColor(outlineColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x - offset, y, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x + offset, y, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x, y - offset, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x, y + offset, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x - offset, y - offset, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x + offset, y - offset, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x - offset, y + offset, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x + offset, y + offset, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawDataSlot(dc as Dc, slot as Number,
            id as Complications.Id, value as String) as Void {
        var circle = slotCircle(slot);
        var x = circle[0];
        var y = circle[1];
        var radius = circle[2];
        var fillColor = _style == FaceStyle.DATA_FOCUS
            ? Graphics.COLOR_BLACK : _surfaceColor;
        dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, radius - 1);

        var ringWidth = screenSize() * 9 / 1000;
        if (ringWidth < 2) { ringWidth = 2; }
        dc.setPenWidth(ringWidth);
        dc.setColor(_secondaryColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, radius);

        dc.setColor(_accentColor, Graphics.COLOR_TRANSPARENT);
        if (slot == FaceSlot.LEFT) {
            dc.drawArc(x, y, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                210, 255);
        } else if (slot == FaceSlot.CENTER) {
            dc.drawArc(x, y, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                235, 300);
        } else {
            dc.drawArc(x, y, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                285, 345);
        }

        dc.setPenWidth(1);

        var iconY = y - radius * 55 / 100;
        var iconSize = radius * 33 / 100;
        if (_caffeineId != null && id.equals(_caffeineId)) {
            drawCaffeine(dc, x, iconY, iconSize, _dataColor);
        } else {
            drawMetricIcon(dc, id.getType(), x, iconY, iconSize,
                _dataColor);
        }
        var maxWidth = radius * 165 / 100;

        // Caffeine is a private complication, so use its separately cached
        // value while keeping the normal system-complication data path intact.
        var displayValue = value;
        if (_caffeineId != null && id.equals(_caffeineId)) {
            displayValue = _caffeineValue;
        }

        var compactValueFont = _compactValueFont;
        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        if (dc.getTextWidthInPixels(displayValue, Graphics.FONT_XTINY) > maxWidth
                && compactValueFont != null) {
            dc.drawText(x, y + radius * 10 / 100, compactValueFont,
                displayValue,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(x, y + radius * 10 / 100, Graphics.FONT_XTINY,
                displayValue,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var unit = metricUnit(id.getType());
        var unitFont = _unitFont;
        if (unit.length() > 0 && unitFont != null) {
            var unitY = y + radius * 66 / 100;
            dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, unitY, unitFont,
                unit, Graphics.TEXT_JUSTIFY_CENTER
                    | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function metricUnit(type as Complications.Type) as String {
        if (type == Complications.COMPLICATION_TYPE_CALORIES) {
            return "kcal";
        } else if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) {
            return "%";
        } else if (type == Complications.COMPLICATION_TYPE_HEART_RATE) {
            return "bpm";
        } else if (type == Complications.COMPLICATION_TYPE_INVALID) {
            return "mg";
        }
        return "";
    }

    private function drawMetricIcon(dc as Dc, type as Complications.Type,
            x as Number, y as Number, size as Number,
            color as Number) as Void {
        if (type == Complications.COMPLICATION_TYPE_HEART_RATE) {
            drawHeart(dc, x, y, size, color);
        } else if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) {
            drawEnergyBolt(dc, x, y, size, color);
        } else if (type == Complications.COMPLICATION_TYPE_STEPS) {
            drawSteps(dc, x, y, size, color);
        } else if (type == Complications.COMPLICATION_TYPE_STRESS) {
            drawPulse(dc, x, y, size, color);
        } else if (type == Complications.COMPLICATION_TYPE_BATTERY) {
            drawBatteryGlyph(dc, x, y, size, color);
        } else if (type == Complications.COMPLICATION_TYPE_CALORIES) {
            drawFlame(dc, x, y, size, color);
        } else if (type
                == Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT) {
            drawBell(dc, x, y, size, color);
        } else if (type
                == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE) {
            drawThermometer(dc, x, y, size, color);
        } else {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, size / 2);
        }
    }

    private function drawCaffeine(dc as Dc, x as Number, y as Number,
            size as Number, color as Number) as Void {
        var stemHeight = size * 60 / 100;
        var cupWidth = size * 80 / 100;
        var cupHeight = size * 70 / 100;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - cupWidth / 2, y - stemHeight,
            size / 4, stemHeight);
        dc.fillPolygon([
            [x - cupWidth / 2, y - cupHeight / 2],
            [x + cupWidth / 2, y - cupHeight / 2],
            [x + cupWidth / 2 - size / 4, y + cupHeight / 2],
            [x - cupWidth / 2 + size / 4, y + cupHeight / 2]
        ]);
    }

    private function drawHeart(dc as Dc, x as Number, y as Number,
            size as Number, color as Number) as Void {
        var lobe = size * 48 / 100;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - lobe / 2, y - lobe / 3, lobe);
        dc.fillCircle(x + lobe / 2, y - lobe / 3, lobe);
        dc.fillPolygon([
            [x - size, y - lobe / 5],
            [x + size, y - lobe / 5],
            [x, y + size]
        ]);
    }

    private function drawEnergyBolt(dc as Dc, x as Number, y as Number,
            size as Number, color as Number) as Void {
        // Body Battery: a solid bolt stays recognizable on the FR165's
        // small display without relying on a font glyph.
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + size * 20 / 100, y - size * 80 / 100],
            [x - size * 50 / 100, y + size * 10 / 100],
            [x, y + size * 10 / 100],
            [x - size * 20 / 100, y + size * 90 / 100],
            [x + size * 50 / 100, y - size * 10 / 100],
            [x, y - size * 10 / 100]
        ]);
    }

    private function drawSteps(dc as Dc, x as Number, y as Number,
            size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var penW = size * 40 / 100;
        if (penW < 2) { penW = 2; }
        dc.setPenWidth(penW);
        dc.drawLine(x - size * 25 / 100, y + size * 20 / 100,
                    x - size * 25 / 100, y - size * 60 / 100);
        dc.drawLine(x + size * 25 / 100, y + size * 60 / 100,
                    x + size * 25 / 100, y - size * 20 / 100);
        dc.setPenWidth(1);
    }

    private function drawPulse(dc as Dc, x as Number, y as Number,
            size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var penW = size * 15 / 100;
        if (penW < 2) { penW = 2; }
        dc.setPenWidth(penW);
        dc.drawLine(x - size, y, x - size * 40 / 100, y);
        dc.drawLine(x - size * 40 / 100, y, x - size * 10 / 100, y - size * 70 / 100);
        dc.drawLine(x - size * 10 / 100, y - size * 70 / 100, x + size * 20 / 100, y + size * 70 / 100);
        dc.drawLine(x + size * 20 / 100, y + size * 70 / 100, x + size * 50 / 100, y);
        dc.drawLine(x + size * 50 / 100, y, x + size, y);
        dc.setPenWidth(1);
    }

    private function drawBatteryGlyph(dc as Dc, x as Number, y as Number,
            size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x - size, y - size / 2, size * 2, size);
        dc.fillRectangle(x + size + 1, y - size / 4,
            size / 3 + 1, size / 2 + 1);
        dc.fillRectangle(x - size + 2, y - size / 2 + 2,
            size, size - 3);
    }

    private function drawFlame(dc as Dc, x as Number, y as Number,
            size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x, y - size],
            [x + size * 62 / 100, y - size * 15 / 100],
            [x + size * 72 / 100, y + size * 40 / 100],
            [x + size * 38 / 100, y + size],
            [x - size * 42 / 100, y + size],
            [x - size * 72 / 100, y + size * 40 / 100],
            [x - size * 62 / 100, y - size * 15 / 100],
            [x - size * 20 / 100, y + size * 20 / 100]
        ]);
        dc.setColor(_surfaceColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x, y - size * 35 / 100],
            [x + size * 27 / 100, y + size * 20 / 100],
            [x, y + size * 62 / 100],
            [x - size * 24 / 100, y + size * 20 / 100]
        ]);
    }

    private function drawBell(dc as Dc, x as Number, y as Number,
            size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(size < 5 ? 1 : 2);
        dc.drawArc(x, y, size, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        dc.drawLine(x - size, y, x - size * 3 / 4,
            y + size * 3 / 4);
        dc.drawLine(x + size, y, x + size * 3 / 4,
            y + size * 3 / 4);
        dc.drawLine(x - size * 3 / 4, y + size * 3 / 4,
            x + size * 3 / 4, y + size * 3 / 4);
        dc.fillCircle(x, y + size, size / 4 + 1);
        dc.setPenWidth(1);
    }

    private function drawThermometer(dc as Dc, x as Number, y as Number,
            size as Number, color as Number) as Void {
        var stemWidth = size * 45 / 100;
        if (stemWidth < 2) { stemWidth = 2; }
        var bulbRadius = size * 55 / 100;
        if (bulbRadius < 2) { bulbRadius = 2; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - size * 70 / 100, stemWidth / 2);
        dc.fillRectangle(x - stemWidth / 2, y - size * 70 / 100,
            stemWidth, size * 125 / 100);
        dc.fillCircle(x, y + size * 55 / 100, bulbRadius);
    }

    // HYDRATION_REGION: right side of the screen, vertically centered.
    // BOTTOM_PROGRESS_REGION: bottom right arc and percentage.
    private function drawHydration(dc as Dc) as Void {
        var waterMl = _waterMl;
        var targetMl = _targetMl;
        var percent = 0;
        if (waterMl != null && targetMl != null) {
            percent = FaceFormatter.progressPercent(waterMl, targetMl);
        }
        var size = screenSize();
        var centerY = screenCenterY();
        var regionX = hydrationX();

        var dropY = centerY - size * 45 / 1000;
        var dropSize = size * 27 / 1000;
        drawDrop(dc, regionX, dropY, dropSize, WATER_COLOR);

        var valueY = centerY + size * 55 / 1000;
        var valueFont = Graphics.FONT_XTINY;
        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(regionX, valueY, valueFont,
            FaceFormatter.wholeNumberText(waterMl),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var mlY = centerY + size * 115 / 1000;
        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(regionX, mlY, Graphics.FONT_XTINY, "ml",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom-right progress stays inside the same circular safe area.
        var percentX = goalX();
        var percentY = centerY + size * 29 / 100;
        var percentText = waterMl != null && targetMl != null && targetMl > 0
            ? percent.format("%d") + "%" : "--%";
        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(percentX, percentY, valueFont, percentText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Arc follows the bezel while keeping the whole stroke in safe bounds.
        var arcWidth = size * 18 / 1000;
        if (arcWidth < 2) { arcWidth = 2; }
        var arcRadius = safeRadius() - arcWidth / 2 - size * 1 / 100;
        var arcStart = 292;
        var arcSpan = 23;

        dc.setPenWidth(arcWidth);
        dc.setColor(_bandHighlightColor, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(screenCenterX(), centerY, arcRadius,
            Graphics.ARC_COUNTER_CLOCKWISE,
            arcStart, arcStart + arcSpan);

        if (percent > 0) {
            dc.setColor(_accentColor, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(screenCenterX(), centerY, arcRadius,
                Graphics.ARC_COUNTER_CLOCKWISE,
                arcStart, arcStart + (arcSpan * percent / 100));
        }
        dc.setPenWidth(1);
    }

    private function drawAlwaysOn(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var timeText = hour.format("%02d")
            + ":" + clock.min.format("%02d");
        var centerX = _width / 2 + (clock.min % 9) - 4;
        var centerY = _height / 2 + ((clock.min / 9) % 9) - 4;
        var font = Graphics.FONT_NUMBER_HOT;
        if (dc.getTextWidthInPixels(timeText, font) > _width * 78 / 100) {
            font = Graphics.FONT_NUMBER_MEDIUM;
        }
        dc.setColor(0x666B6E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY - _height * 5 / 100,
            font, timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var waterMl = _waterMl;
        var targetMl = _targetMl;
        if (waterMl != null && targetMl != null && targetMl > 0) {
            var percent = FaceFormatter.progressPercent(waterMl, targetMl);
            dc.drawText(centerX, centerY + _height * 17 / 100,
                Graphics.FONT_XTINY,
                "H2O  " + percent.format("%d") + "%",
                Graphics.TEXT_JUSTIFY_CENTER
                    | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawDebugLayout(dc as Dc) as Void {
        var size = screenSize();
        var centerX = screenCenterX();
        var centerY = screenCenterY();
        dc.setPenWidth(1);

        // TOP_REGION: green
        dc.setColor(0x00FF00, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(centerX - size * 7 / 100,
            centerY - size * 38 / 100,
            size * 30 / 100, size * 17 / 100);

        // CLOCK_REGION: yellow circle
        dc.setColor(0xFFFF00, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX + size * 8 / 100,
            centerY + size * 1 / 100, size * 20 / 100);

        // LEFT_WIDGETS_REGION: cyan circles
        dc.setColor(0x00FFFF, Graphics.COLOR_TRANSPARENT);
        var firstSlot = slotCircle(FaceSlot.LEFT);
        var secondSlot = slotCircle(FaceSlot.CENTER);
        var thirdSlot = slotCircle(FaceSlot.RIGHT);
        dc.drawCircle(firstSlot[0], firstSlot[1], firstSlot[2]);
        dc.drawCircle(secondSlot[0], secondSlot[1], secondSlot[2]);
        dc.drawCircle(thirdSlot[0], thirdSlot[1], thirdSlot[2]);

        // HYDRATION_REGION: red box (right side)
        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(centerX + size * 26 / 100,
            centerY - size * 16 / 100,
            size * 16 / 100, size * 32 / 100);

        // Safe circular area: white circle outline
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, safeRadius());
    }

    private function drawDrop(dc as Dc, x as Number, y as Number,
            radius as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x, y - radius],
            [x - radius, y + radius / 3],
            [x - radius * 60 / 100, y + radius],
            [x + radius * 60 / 100, y + radius],
            [x + radius, y + radius / 3]
        ]);
        dc.fillCircle(x, y + radius / 2, radius * 70 / 100);
    }

    private function isInsideSlot(x as Number, y as Number,
            slot as Number) as Boolean {
        var circle = slotCircle(slot);
        var dx = x - circle[0];
        var dy = y - circle[1];
        return (dx * dx) + (dy * dy) <= circle[2] * circle[2];
    }

    private function slotCircle(slot as Number) as Array<Number> {
        var size = screenSize();
        var x = leftWidgetsX();
        var centerY = screenCenterY();
        var spacing = size * 19 / 100;
        var y1 = centerY - spacing;
        var y2 = centerY;
        var y3 = centerY + spacing;

        var radius = size * 9 / 100;
        if (slot == FaceSlot.LEFT) {
            return [x, y1, radius];
        } else if (slot == FaceSlot.CENTER) {
            return [x, y2, radius];
        } else {
            return [x, y3, radius];
        }
    }

    private function leftWidgetsX() as Number {
        return screenCenterX() - screenSize() * 23 / 100;
    }

    private function dividerX() as Number {
        return screenCenterX() - screenSize() * 10 / 100;
    }

    private function clockX() as Number {
        return screenCenterX() + screenSize() * 15 / 100;
    }

    private function hydrationX() as Number {
        return screenCenterX() + screenSize() * 36 / 100;
    }

    private function goalX() as Number {
        return screenCenterX() + screenSize() * 23 / 100;
    }

    private function slotBounds(slot as Number) as Graphics.BoundingBox {
        var circle = slotCircle(slot);
        var bounds = new Graphics.BoundingBox();
        bounds.addRectangle(circle[0] - circle[2],
            circle[1] - circle[2], circle[2] * 2, circle[2] * 2);
        return bounds;
    }

    private function screenSize() as Number {
        return _width < _height ? _width : _height;
    }

    private function screenCenterX() as Number {
        return _width / 2;
    }

    private function screenCenterY() as Number {
        return _height / 2;
    }

    private function screenRadius() as Number {
        return screenSize() / 2;
    }

    private function safeRadius() as Number {
        return screenRadius() * 88 / 100;
    }

    private function resolvePalette() as Void {
        _backgroundColor = Graphics.COLOR_BLACK;
        if (_theme == FaceTheme.DEEP_PURPLE) {
            _bandColor = 0x240B3D;
            _bandHighlightColor = 0x641B8C;
            _surfaceColor = 0x12071C;
        } else if (_theme == FaceTheme.MIDNIGHT_BLUE) {
            _bandColor = 0x071B54;
            _bandHighlightColor = 0x143C9C;
            _surfaceColor = 0x061020;
        } else if (_theme == FaceTheme.GRAPHITE) {
            _bandColor = 0x16191D;
            _bandHighlightColor = 0x30343A;
            _surfaceColor = 0x0E1012;
        } else if (_theme == FaceTheme.PURE_BLACK) {
            _bandColor = Graphics.COLOR_BLACK;
            _bandHighlightColor = Graphics.COLOR_BLACK;
            _surfaceColor = 0x080808;
        } else if (_theme == FaceTheme.GREEN) {
            _bandColor = 0x063A2B;
            _bandHighlightColor = 0x087A55;
            _surfaceColor = 0x071812;
        } else if (_theme == FaceTheme.BLUE) {
            _bandColor = 0x082A52;
            _bandHighlightColor = 0x145DA8;
            _surfaceColor = 0x071424;
        } else if (_theme == FaceTheme.RED) {
            _bandColor = 0x4A0B18;
            _bandHighlightColor = 0x92152A;
            _surfaceColor = 0x1D080D;
        } else {
            _bandColor = 0x161047;
            _bandHighlightColor = 0x38218A;
            _surfaceColor = 0x0D0918;
        }
    }
}
