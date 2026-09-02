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
    private const WATER_COLOR = 0x0089CA;
    private const UNIT_COLOR = 0xD0D0D0;

    // Reference layout, expressed in thousandths of the shortest screen side.
    // Keeping these anchors together prevents independent settings from moving
    // widgets outside the circular safe area.
    private const SIDE_X = 334;
    private const BATTERY_Y = 144;
    private const DATE_Y = 222;
    private const HOUR_Y = 411;
    private const MINUTE_Y = 651;
    private const TOP_ICON_Y = 303;
    private const TOP_VALUE_Y = 389;
    private const TOP_UNIT_Y = 449;
    private const BOTTOM_ICON_Y = 585;
    private const BOTTOM_VALUE_Y = 670;
    private const BOTTOM_UNIT_Y = 729;
    private const HEART_RATE_Y = 856;

    private var _sleeping as Boolean = false;
    private var _isShown as Boolean = false;
    private var _requiresBurnInProtection as Boolean = false;
    private var _width as Number = 0;
    private var _height as Number = 0;

    private var _style as Number = FaceStyle.BALANCED;
    private var _theme as Number = FaceTheme.NEON_PURPLE;
    private var _accentColor as Number = 0x873FD1;
    private var _dataColor as Number = Graphics.COLOR_WHITE;
    private var _backgroundColor as Number = Graphics.COLOR_BLACK;
    private var _smokeTexture as BitmapResource;
    private var _timeFont as Graphics.VectorFont? = null;
    private var _minuteFont as Graphics.VectorFont? = null;
    private var _headerFont as Graphics.VectorFont? = null;
    private var _dateFont as Graphics.VectorFont? = null;
    private var _valueFont as Graphics.VectorFont? = null;
    private var _unitFont as Graphics.VectorFont? = null;
    private var _heartFont as Graphics.VectorFont? = null;

    private var _topLeftId as Complications.Id;
    private var _bottomLeftId as Complications.Id;
    private var _topRightId as Complications.Id;
    private var _heartRateId as Complications.Id;
    private var _hydrationId as Complications.Id?;
    private var _caffeineId as Complications.Id?;

    private var _topLeftValue as String = "--";
    private var _bottomLeftValue as String = "--";
    private var _topRightValue as String = "--";
    private var _heartRateValue as String = "--";
    private var _waterMl as Number? = null;
    private var _targetMl as Number? = null;
    private var _caffeineValue as String = "--";
    private var _dataDirty as Boolean = true;
    private var _lastRefreshMinute as Number = -1;

    function initialize(editMode as Boolean) {
        WatchFace.initialize();
        _topLeftId = new Complications.Id(Complications.COMPLICATION_TYPE_CALORIES);
        _bottomLeftId = new Complications.Id(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE);
        _topRightId = new Complications.Id(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        _heartRateId = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE);
        _smokeTexture = WatchUi.loadResource(Rez.Drawables.SmokeTextureNeonPurple) as BitmapResource;
        _hydrationId = null;
        _caffeineId = null;
    }

    function onLayout(dc as Dc) as Void {
        _width = dc.getWidth();
        _height = dc.getHeight();
        _requiresBurnInProtection = System.getDeviceSettings().requiresBurnInProtection;
        loadResponsiveFonts();
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
        _theme = FaceFormatter.propertyNumber("background_theme", FaceTheme.NEON_PURPLE);
        _accentColor = FaceFormatter.propertyNumber("accent_color", 0x873FD1);
        _dataColor = FaceFormatter.propertyNumber("data_color", Graphics.COLOR_WHITE);

        _topLeftId = new Complications.Id(FaceFormatter.propertyNumber(
            "left_data", Complications.COMPLICATION_TYPE_CALORIES) as Complications.Type);
        _bottomLeftId = new Complications.Id(FaceFormatter.propertyNumber(
            "center_data", Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE) as Complications.Type);
        _topRightId = new Complications.Id(FaceFormatter.propertyNumber(
            "right_data", Complications.COMPLICATION_TYPE_BODY_BATTERY) as Complications.Type);

        resolvePalette();
        loadNativeConfiguration();
        resolveHydrationComplication();
        _dataDirty = true;
        if (_isShown) { subscribeToComplications(); }
        WatchUi.requestUpdate();
    }

    function applyNativeConfiguration(config as WatchFaceConfig.Settings) as Void {
        applyNativeConfigurationValues(config);
        _dataDirty = true;
        if (_isShown) { subscribeToComplications(); }
        WatchUi.requestUpdate();
    }

    private function applyNativeConfigurationValues(config as WatchFaceConfig.Settings) as Void {
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
                if (id == null || setting.uniqueIdentifier == null) { continue; }

                if (setting.uniqueIdentifier == FaceSlot.TOP_LEFT) {
                    _topLeftId = id;
                } else if (setting.uniqueIdentifier == FaceSlot.BOTTOM_LEFT) {
                    _bottomLeftId = id;
                } else if (setting.uniqueIdentifier == FaceSlot.TOP_RIGHT) {
                    _topRightId = id;
                }
            }
        }
    }

    function onComplicationChanged(id as Complications.Id) as Void {
        if (id.equals(_topLeftId) || id.equals(_bottomLeftId)
                || id.equals(_topRightId) || id.equals(_heartRateId)
                || (_hydrationId != null && id.equals(_hydrationId))
                || (_caffeineId != null && id.equals(_caffeineId))) {
            _dataDirty = true;
            WatchUi.requestUpdate();
        }
    }

    function isInsideTopLeftSlot(x as Number, y as Number) as Boolean {
        return isInsideSlot(x, y, FaceSlot.TOP_LEFT);
    }

    function isInsideBottomLeftSlot(x as Number, y as Number) as Boolean {
        return isInsideSlot(x, y, FaceSlot.BOTTOM_LEFT);
    }

    function isInsideTopRightSlot(x as Number, y as Number) as Boolean {
        return isInsideSlot(x, y, FaceSlot.TOP_RIGHT);
    }

    function isInsideHydration(x as Number, y as Number) as Boolean {
        var circle = slotCircle(FaceSlot.BOTTOM_RIGHT);
        var dx = x - circle[0];
        var dy = y - circle[1];
        return (dx * dx) + (dy * dy) <= circle[2] * circle[2];
    }

    function getTopLeftId() as Complications.Id { return _topLeftId; }
    function getBottomLeftId() as Complications.Id { return _bottomLeftId; }
    function getTopRightId() as Complications.Id { return _topRightId; }
    function getHydrationId() as Complications.Id? { return _hydrationId; }

    function getSlotPreview(uniqueIdentifier as Number) as WatchUi.ComplicationDrawableRef? {
        if (_width <= 0 || _height <= 0) { return null; }
        if (uniqueIdentifier != FaceSlot.TOP_LEFT
                && uniqueIdentifier != FaceSlot.BOTTOM_LEFT
                && uniqueIdentifier != FaceSlot.TOP_RIGHT) {
            return null;
        }

        var value = "--";
        if (uniqueIdentifier == FaceSlot.TOP_LEFT) { value = _topLeftValue; }
        else if (uniqueIdentifier == FaceSlot.BOTTOM_LEFT) { value = _bottomLeftValue; }
        else if (uniqueIdentifier == FaceSlot.TOP_RIGHT) { value = _topRightValue; }

        var bounds = slotBounds(uniqueIdentifier);
        var drawable = new SlotPreviewDrawable(bounds, value, _dataColor);
        return new WatchUi.ComplicationDrawableRef({
            :drawable => drawable,
            :boundingBox => bounds
        });
    }

    private function loadNativeConfiguration() as Void {
        if (!(Application has :WatchFaceConfig)) { return; }
        try {
            var config = WatchFaceConfig.getSettings(null);
            if (config != null) { applyNativeConfigurationValues(config); }
        } catch (error) {}
    }

    private function subscribeToComplications() as Void {
        if (!_isShown || _width <= 0 || _height <= 0) { return; }
        try { Complications.unsubscribeFromAllUpdates(); } catch (error) {}
        try {
            Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
        } catch (error) { return; }

        var subscriptions = [] as Array<Complications.Id>;
        if (_hydrationId != null) { subscribeToComplication(_hydrationId, subscriptions); }
        if (_caffeineId != null) { subscribeToComplication(_caffeineId, subscriptions); }
        subscribeToComplication(_topLeftId, subscriptions);
        subscribeToComplication(_bottomLeftId, subscriptions);
        subscribeToComplication(_topRightId, subscriptions);
        subscribeToComplication(_heartRateId, subscriptions);
    }

    private function subscribeToComplication(id as Complications.Id, subscriptions as Array<Complications.Id>) as Void {
        for (var i = 0; i < subscriptions.size(); i += 1) {
            if (id.equals(subscriptions[i])) { return; }
        }
        subscriptions.add(id);
        try { Complications.subscribeToUpdates(id); } catch (error) {}
    }

    private function resolveHydrationComplication() as Void {
        var stored = Storage.getValue(HYDRATION_ID_KEY);
        if (stored instanceof Complications.Id) {
            _hydrationId = stored as Complications.Id;
            try {
                var saved = Complications.getComplication(_hydrationId as Complications.Id);
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
                var savedCaffeine = Complications.getComplication(_caffeineId as Complications.Id);
                if (!CAFFEINE_SHORT_LABEL.equals(savedCaffeine.shortLabel)) {
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
                if (complication.getType() == Complications.COMPLICATION_TYPE_INVALID
                        && complication.complicationId != null) {
                    if (HYDRATION_SHORT_LABEL.equals(complication.shortLabel)) {
                        _hydrationId = complication.complicationId;
                        Storage.setValue(HYDRATION_ID_KEY, _hydrationId);
                    }
                    if (CAFFEINE_SHORT_LABEL.equals(complication.shortLabel)) {
                        _caffeineId = complication.complicationId;
                        Storage.setValue(CAFFEINE_ID_KEY, _caffeineId);
                    }
                }
                complication = iterator.next();
            }
        } catch (error) {}
    }

    private function refreshComplicationValues() as Void {
        var hydrationWasMissing = _hydrationId == null;
        var caffeineWasMissing = _caffeineId == null;
        if (hydrationWasMissing || caffeineWasMissing) {
            resolveHydrationComplication();
            if (_isShown && ((hydrationWasMissing && _hydrationId != null)
                    || (caffeineWasMissing && _caffeineId != null))) {
                subscribeToComplications();
            }
        }

        _topLeftValue = readComplication(_topLeftId);
        _bottomLeftValue = readComplication(_bottomLeftId);
        _topRightValue = readComplication(_topRightId);
        _heartRateValue = readComplication(_heartRateId);
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
                var target = FaceFormatter.numberOrNull(ranges[ranges.size() - 1]);
                if (target != null) { _targetMl = target; }
            }
        } catch (error) {
            _hydrationId = null;
            Storage.deleteValue(HYDRATION_ID_KEY);
            _waterMl = null;
            _targetMl = null;
        }
    }

    private function readComplication(id as Complications.Id) as String {
        try {
            var complication = Complications.getComplication(id);
            var type = id.getType();
            if (type == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE) {
                return FaceFormatter.temperatureText(
                    complication.value,
                    System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE);
            }
            var value = FaceFormatter.compactValue(complication.value);
            if (type == Complications.COMPLICATION_TYPE_BATTERY && !value.equals("--")) {
                return value + "%";
            }
            return value;
        } catch (error) { return "--"; }
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

    private function loadResponsiveFonts() as Void {
        _timeFont = null;
        _minuteFont = null;
        _headerFont = null;
        _dateFont = null;
        _valueFont = null;
        _unitFont = null;
        _heartFont = null;
        if (!(Graphics has :getVectorFont)) { return; }
        try {
            // The first faces match the reference on current devices. The
            // remaining native faces keep the same visual hierarchy on models
            // such as Venu 3S, which expose a smaller vector-font set.
            var boldFaces = ["RobotoCondensedBold", "NanumGothicBold"];
            var headerFaces = ["YantramanavRegular", "RobotoRegular",
                "PridiRegular"];
            var valueFaces = ["RobotoRegular", "YantramanavRegular",
                "PridiRegular"];
            var unitFaces = ["YantramanavRegular", "RobotoRegular",
                "PridiRegular"];
            _timeFont = Graphics.getVectorFont({
                :face => boldFaces,
                :size => screenSize() * 392 / 1000
            });
            _minuteFont = Graphics.getVectorFont({
                :face => boldFaces,
                :size => screenSize() * 378 / 1000
            });
            _headerFont = Graphics.getVectorFont({
                :face => headerFaces,
                :size => screenSize() * 96 / 1000
            });
            _dateFont = Graphics.getVectorFont({
                :face => headerFaces,
                :size => screenSize() * 101 / 1000
            });
            _valueFont = Graphics.getVectorFont({
                :face => valueFaces,
                :size => screenSize() * 78 / 1000
            });
            _unitFont = Graphics.getVectorFont({
                :face => unitFaces,
                :size => screenSize() * 67 / 1000
            });
            _heartFont = Graphics.getVectorFont({
                :face => valueFaces,
                :size => screenSize() * 94 / 1000
            });
        } catch (error) {
            // Built-in fonts below remain a safe fallback on every target.
        }
    }

    private function drawActive(dc as Dc) as Void {
        // Render order is intentional: background -> header -> side widgets ->
        // clock -> hydration. The side widgets live outside the clock area.
        drawBackground(dc);
        drawSystemHeader(dc);

        var size = screenSize();
        var centerX = screenCenterX();
        var centerY = screenCenterY();

        if (_style != FaceStyle.MINIMAL) {
            drawDataSlot(dc, FaceSlot.TOP_LEFT, _topLeftId, _topLeftValue);
            drawDataSlot(dc, FaceSlot.BOTTOM_LEFT, _bottomLeftId, _bottomLeftValue);
            drawDataSlot(dc, FaceSlot.TOP_RIGHT, _topRightId, _topRightValue);
        }

        drawWaterQuadrant(dc, centerX, centerY, size);
        drawTimeCenter(dc, centerX, centerY, size);
        drawHeartRate(dc, centerX, size);
    }

    private function drawTimeCenter(dc as Dc, centerX as Number, centerY as Number, size as Number) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }

        var hourText = "" + hour.format("%02d"); 
        var minuteText = "" + clock.min.format("%02d");
        var hourFont = selectTimeFont();
        var minuteFont = selectMinuteFont();
        var hourY = layoutY(HOUR_Y);
        var minuteY = layoutY(MINUTE_Y);

        // Paint the minute line first so the white hour stays visually in
        // front at the narrow overlap, as in the reference image.
        if (_accentColor == 0x873FD1) {
            drawReferenceMinuteText(dc, centerX + 1, minuteY, minuteFont,
                minuteText, size);
        } else {
            drawCleanMinuteText(dc, centerX + 1, minuteY, minuteFont,
                minuteText, _accentColor, size);
        }
        drawCleanTimeText(dc, centerX - 1, hourY, hourFont,
            hourText, Graphics.COLOR_WHITE);
    }

    private function drawReferenceMinuteText(dc as Dc, x as Number,
            y as Number, font as Graphics.FontType, text as String,
            size as Number) as Void {
        var justify = Graphics.TEXT_JUSTIFY_CENTER
            | Graphics.TEXT_JUSTIFY_VCENTER;
        var tightening = size * 12 / 1000;
        var first = text.substring(0, 1) as String;
        var second = text.substring(1, 2) as String;
        var firstWidth = dc.getTextWidthInPixels(first, font);
        var secondWidth = dc.getTextWidthInPixels(second, font);
        var pairWidth = firstWidth + secondWidth - tightening;
        var firstX = x - pairWidth / 2 + firstWidth / 2;
        var secondX = x + pairWidth / 2 - secondWidth / 2;
        // Three-pixel interpolation of samples taken from the reference. Every
        // band reuses the same glyph origins, so the outline remains natural.
        var gradientColors = [
            0x4C2570, 0x4E2772, 0x502873, 0x532977,
            0x55297B, 0x5E2D89, 0x673197, 0x6D34A1,
            0x7337AB, 0x7639B0, 0x783AB4, 0x783AB5,
            0x783AB5, 0x773AB5, 0x7639B5, 0x7639B5,
            0x7538B5, 0x7538B5, 0x7437B5, 0x7337B5,
            0x7236B4, 0x7236B4, 0x7135B4, 0x7135B4,
            0x7035B3, 0x7035B3, 0x6F35B2, 0x6F35B2,
            0x6F34B1, 0x6F34B1, 0x6F34B0, 0x6F34B0
        ];
        var gradientTop = y - size * 120 / 1000;
        var bandHeight = size * 8 / 1000;
        if (bandHeight < 1) { bandHeight = 1; }
        for (var i = 0; i < gradientColors.size(); i += 1) {
            dc.setClip(0, gradientTop + bandHeight * i,
                _width, bandHeight + 1);
            dc.setColor(gradientColors[i], Graphics.COLOR_TRANSPARENT);
            dc.drawText(firstX, y, font, first, justify);
            dc.drawText(secondX, y, font, second, justify);
        }
        dc.clearClip();
    }

    private function drawCleanMinuteText(dc as Dc, x as Number,
            y as Number, font as Graphics.FontType, text as String,
            color as Number, size as Number) as Void {
        var tightening = size * 12 / 1000;
        var justify = Graphics.TEXT_JUSTIFY_CENTER
            | Graphics.TEXT_JUSTIFY_VCENTER;
        var first = text.substring(0, 1) as String;
        var second = text.substring(1, 2) as String;
        var firstWidth = dc.getTextWidthInPixels(first, font);
        var secondWidth = dc.getTextWidthInPixels(second, font);
        var pairWidth = firstWidth + secondWidth - tightening;
        var firstX = x - pairWidth / 2 + firstWidth / 2;
        var secondX = x + pairWidth / 2 - secondWidth / 2;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(firstX, y, font, first, justify);
        dc.drawText(secondX, y, font, second, justify);
    }

    private function drawCleanTimeText(dc as Dc, x as Number, y as Number,
            font as Graphics.FontType, text as String,
            color as Number) as Void {
        var justify = Graphics.TEXT_JUSTIFY_CENTER
            | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, justify);
    }

    private function drawHeartRate(dc as Dc, centerX as Number,
            size as Number) as Void {
        var font = heartFont();
        var y = layoutY(HEART_RATE_Y);
        var iconSize = size * 34 / 1000;
        var gap = size * 18 / 1000;
        var textWidth = dc.getTextWidthInPixels(_heartRateValue, font);
        var groupWidth = iconSize * 2 + gap + textWidth;
        var startX = centerX - groupWidth / 2;

        drawHeart(dc, startX + iconSize, y, iconSize, _accentColor);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + iconSize * 2 + gap, y, font,
            _heartRateValue,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawWaterQuadrant(dc as Dc, centerX as Number, centerY as Number, size as Number) as Void {
        var layout = widgetLayout(FaceSlot.BOTTOM_RIGHT);
        var x = layout[0];
        var iconY = layout[1];
        var valueY = layout[2];
        var unitY = layout[3];
        var iconSize = (size * 42 / 1000).toNumber();

        drawDrop(dc, x - 1, iconY, iconSize, WATER_COLOR);

        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, valueY, valueFont(),
            FaceFormatter.wholeNumberText(_waterMl),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(unitDisplayColor(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, unitY, unitFont(),
            "ml", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawBackground(dc as Dc) as Void {
        dc.setColor(_backgroundColor, _backgroundColor);
        dc.clear();
        dc.drawBitmap(screenCenterX() - _smokeTexture.getWidth() / 2,
            screenCenterY() - screenRadius(), _smokeTexture);
    }

    private function drawSystemHeader(dc as Dc) as Void {
        var size = screenSize();
        var centerX = screenCenterX();
        var batteryY = layoutY(BATTERY_Y);
        var dateY = layoutY(DATE_Y);
        var font = headerFont();
        var dateFace = dateFont();

        var battery = (System.getSystemStats().battery + 0.5).toNumber();
        var batteryText = battery.format("%d") + "%";
        drawBatteryStatus(dc, centerX, batteryY, size, battery, batteryText, font);

        var date = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateText = date.day_of_week.toString()
            + " " + date.day.format("%02d");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, dateY, dateFace, dateText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawBatteryStatus(dc as Dc, centerX as Number,
            centerY as Number, size as Number, battery as Number,
            text as String, font as Graphics.FontType) as Void {
        var iconWidth = (size * 48 / 1000).toNumber();
        var iconHeight = (size * 26 / 1000).toNumber();
        var gap = (size * 12 / 1000).toNumber();
        if (iconWidth < 12) { iconWidth = 12; }
        if (iconHeight < 7) { iconHeight = 7; }
        if (gap < 4) { gap = 4; }

        var textWidth = dc.getTextWidthInPixels(text, font);
        var groupWidth = iconWidth + gap + textWidth;
        var iconX = centerX - groupWidth / 2;
        var iconY = centerY - iconHeight / 2;
        var terminalWidth = iconHeight / 4;
        if (terminalWidth < 2) { terminalWidth = 2; }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(iconX, iconY, iconWidth, iconHeight);
        dc.fillRectangle(iconX + iconWidth + 1,
            centerY - terminalWidth / 2, terminalWidth, terminalWidth);

        var fillWidth = ((iconWidth - 4) * battery / 100).toNumber();
        if (fillWidth > 0) {
            dc.fillRectangle(iconX + 2, iconY + 2,
                fillWidth, iconHeight - 4);
        }

        dc.drawText(iconX + iconWidth + gap, centerY, font, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function selectTimeFont() as Graphics.FontType {
        var font = _timeFont;
        if (font != null) { return font; }
        return Graphics.FONT_NUMBER_HOT;
    }

    private function selectMinuteFont() as Graphics.FontType {
        var font = _minuteFont;
        if (font != null) { return font; }
        return selectTimeFont();
    }

    private function headerFont() as Graphics.FontType {
        var font = _headerFont;
        if (font != null) { return font; }
        return Graphics.FONT_TINY;
    }

    private function dateFont() as Graphics.FontType {
        var font = _dateFont;
        if (font != null) { return font; }
        return headerFont();
    }

    private function valueFont() as Graphics.FontType {
        var font = _valueFont;
        if (font != null) { return font; }
        return Graphics.FONT_TINY;
    }

    private function unitFont() as Graphics.FontType {
        var font = _unitFont;
        if (font != null) { return font; }
        return Graphics.FONT_XTINY;
    }

    private function heartFont() as Graphics.FontType {
        var font = _heartFont;
        if (font != null) { return font; }
        return Graphics.FONT_SMALL;
    }

    private function drawDataSlot(dc as Dc, slot as Number, id as Complications.Id, value as String) as Void {
        var layout = widgetLayout(slot);
        var x = layout[0];
        var iconY = layout[1];
        var valueY = layout[2];
        var unitY = layout[3];
        var iconSize = (screenSize() * 42 / 1000).toNumber();

        var isCaffeine = _caffeineId != null && id.equals(_caffeineId);
        if (isCaffeine) {
            drawCaffeine(dc, x, iconY, iconSize, _dataColor);
        } else if (hasCustomMetricIcon(id.getType())) {
            drawMetricIcon(dc, id.getType(), x, iconY, iconSize, _dataColor);
        } else {
            drawOfficialComplicationIcon(dc, id, x, iconY, iconSize, _dataColor);
        }

        var displayValue = isCaffeine ? _caffeineValue : value;
        dc.setColor(_dataColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, valueY, valueFont(), displayValue,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var unit = isCaffeine ? "mg" : metricUnit(id.getType());
        if (unit.length() > 0) {
            dc.setColor(unitDisplayColor(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, unitY, unitFont(), unit,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function unitDisplayColor() as Number {
        return _dataColor == Graphics.COLOR_WHITE ? UNIT_COLOR : _dataColor;
    }

    private function hasCustomMetricIcon(type as Complications.Type) as Boolean {
        return type == Complications.COMPLICATION_TYPE_HEART_RATE
            || type == Complications.COMPLICATION_TYPE_BODY_BATTERY
            || type == Complications.COMPLICATION_TYPE_STEPS
            || type == Complications.COMPLICATION_TYPE_STRESS
            || type == Complications.COMPLICATION_TYPE_BATTERY
            || type == Complications.COMPLICATION_TYPE_CALORIES
            || type == Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT
            || type == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE;
    }

    private function metricUnit(type as Complications.Type) as String {
        if (type == Complications.COMPLICATION_TYPE_CALORIES) { return "kcal"; }
        else if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) { return "%"; }
        else if (type == Complications.COMPLICATION_TYPE_HEART_RATE) { return "bpm"; }
        return "";
    }

    private function drawMetricIcon(dc as Dc, type as Complications.Type, x as Number, y as Number, size as Number, color as Number) as Void {
        if (type == Complications.COMPLICATION_TYPE_HEART_RATE) { drawHeart(dc, x, y, size, color); }
        else if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) { drawEnergyBolt(dc, x - 2, y - 1, size, color); }
        else if (type == Complications.COMPLICATION_TYPE_STEPS) { drawSteps(dc, x, y, size, color); }
        else if (type == Complications.COMPLICATION_TYPE_STRESS) { drawPulse(dc, x, y, size, color); }
        else if (type == Complications.COMPLICATION_TYPE_BATTERY) { drawBatteryGlyph(dc, x, y, size, color); }
        else if (type == Complications.COMPLICATION_TYPE_CALORIES) { drawFlame(dc, x, y - 1, size, color); }
        else if (type == Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT) { drawBell(dc, x, y, size, color); }
        else if (type == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE) { drawWeatherIcon(dc, x, y, size, color); }
        else {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, size / 2);
        }
    }

    private function drawOfficialComplicationIcon(dc as Dc, id as Complications.Id, x as Number, y as Number, size as Number, color as Number) as Void {
        try {
            var complication = Complications.getComplication(id);
            if (complication != null) {
                var icon = complication.getIcon();
                if (icon != null) {
                    var bitmap = icon as BitmapResource;
                    var iconWidth = bitmap.getWidth();
                    var iconHeight = bitmap.getHeight();
                    dc.drawBitmap(x - iconWidth / 2, y - iconHeight / 2, bitmap);
                    return;
                }
            }
        } catch (e) {}
        drawMetricIcon(dc, id.getType(), x, y, size, color);
    }

    private function drawEnergyBolt(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + size * 30 / 100, y - size * 108 / 100],
            [x + size * 22 / 100, y - size * 105 / 100],
            [x - size * 60 / 100, y + size * 12 / 100],
            [x - size * 57 / 100, y + size * 18 / 100],
            [x - size * 6 / 100, y + size * 15 / 100],
            [x - size * 1 / 100, y + size * 21 / 100],
            [x - size * 9 / 100, y + size * 100 / 100],
            [x + size * 78 / 100, y - size * 17 / 100],
            [x + size * 75 / 100, y - size * 23 / 100],
            [x + size * 19 / 100, y - size * 26 / 100]
        ]);
    }

    private function drawFlame(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + size * 19 / 100, y - size * 94 / 100],
            [x + size * 1 / 100, y - size * 81 / 100],
            [x - size * 10 / 100, y - size * 60 / 100],
            [x - size * 7 / 100, y - size * 29 / 100],
            [x + size * 24 / 100, y + size * 17 / 100],
            [x + size * 19 / 100, y + size * 41 / 100],
            [x + size * 1 / 100, y + size * 51 / 100],
            [x - size * 15 / 100, y + size * 43 / 100],
            [x - size * 17 / 100, y + size * 25 / 100],
            [x - size * 10 / 100, y + size * 15 / 100],
            [x - size * 10 / 100, y - size * 1 / 100],
            [x - size * 20 / 100, y + size * 10 / 100],
            [x - size * 30 / 100, y + size * 10 / 100],
            [x - size * 38 / 100, y + size * 2 / 100],
            [x - size * 33 / 100, y - size * 24 / 100],
            [x - size * 49 / 100, y - size * 8 / 100],
            [x - size * 59 / 100, y + size * 23 / 100],
            [x - size * 56 / 100, y + size * 46 / 100],
            [x - size * 43 / 100, y + size * 69 / 100],
            [x - size * 7 / 100, y + size * 90 / 100],
            [x + size * 35 / 100, y + size * 85 / 100],
            [x + size * 63 / 100, y + size * 59 / 100],
            [x + size * 71 / 100, y + size * 38 / 100],
            [x + size * 68 / 100, y + size * 2 / 100],
            [x + size * 24 / 100, y - size * 60 / 100],
            [x + size * 16 / 100, y - size * 81 / 100]
        ]);
    }

    private function drawHeart(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        var lobeRadius = size * 54 / 100;
        var lobeOffset = size * 46 / 100;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - lobeOffset, y - size * 29 / 100, lobeRadius);
        dc.fillCircle(x + lobeOffset, y - size * 29 / 100, lobeRadius);
        dc.fillPolygon([
            [x - size, y - size * 2 / 100],
            [x + size, y - size * 2 / 100],
            [x, y + size * 105 / 100]
        ]);
    }

    private function drawSteps(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
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

    private function drawPulse(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
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

    private function drawBatteryGlyph(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x - size, y - size / 2, size * 2, size);
        dc.fillRectangle(x + size + 1, y - size / 4,
            size / 3 + 1, size / 2 + 1);
        dc.fillRectangle(x - size + 2, y - size / 2 + 2,
            size, size - 3);
    }

    private function drawBell(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
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

    private function drawThermometer(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
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

    private function drawCaffeine(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
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

    private function drawWeatherIcon(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        // The reference uses one clean cloud glyph. The temperature value still
        // comes from the selected current-temperature complication.
        drawCloud(dc, x + 2, y + 1, size * 165 / 100, color);
    }

    private function drawCloud(dc as Dc, x as Number, y as Number, size as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x - size * 53 / 100, y - size * 24 / 100],
            [x - size * 58 / 100, y - size * 13 / 100],
            [x - size * 58 / 100, y + size * 5 / 100],
            [x - size * 51 / 100, y + size * 17 / 100],
            [x - size * 36 / 100, y + size * 28 / 100],
            [x + size * 24 / 100, y + size * 30 / 100],
            [x + size * 43 / 100, y + size * 17 / 100],
            [x + size * 45 / 100, y - size * 2 / 100],
            [x + size * 40 / 100, y - size * 11 / 100],
            [x + size * 31 / 100, y - size * 18 / 100],
            [x + size * 14 / 100, y - size * 19 / 100],
            [x - size * 6 / 100, y - size * 38 / 100],
            [x - size * 34 / 100, y - size * 38 / 100]
        ]);
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
        var timeText = hour.format("%02d") + ":" + clock.min.format("%02d");
        var centerX = _width / 2 + (clock.min % 9) - 4;
        var centerY = _height / 2 + ((clock.min / 9) % 9) - 4;
        var font = Graphics.FONT_NUMBER_MEDIUM;
        dc.setColor(0x666B6E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY - _height * 5 / 100, font, timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var waterMl = _waterMl;
        var targetMl = _targetMl;
        if (waterMl != null && targetMl != null && targetMl > 0) {
            var percent = FaceFormatter.progressPercent(waterMl, targetMl);
            dc.drawText(centerX, centerY + _height * 17 / 100, Graphics.FONT_XTINY,
                "H2O  " + percent.format("%d") + "%",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawDrop(dc as Dc, x as Number, y as Number, radius as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x, y - radius * 69 / 100],
            [x - radius * 12 / 100, y - radius * 53 / 100],
            [x - radius * 26 / 100, y - radius * 37 / 100],
            [x - radius * 37 / 100, y - radius * 20 / 100],
            [x - radius * 45 / 100, y - radius * 4 / 100],
            [x - radius * 49 / 100, y + radius * 12 / 100],
            [x - radius * 48 / 100, y + radius * 29 / 100],
            [x - radius * 43 / 100, y + radius * 45 / 100],
            [x - radius * 29 / 100, y + radius * 61 / 100],
            [x - radius * 12 / 100, y + radius * 69 / 100],
            [x, y + radius * 71 / 100],
            [x + radius * 12 / 100, y + radius * 69 / 100],
            [x + radius * 29 / 100, y + radius * 61 / 100],
            [x + radius * 43 / 100, y + radius * 45 / 100],
            [x + radius * 48 / 100, y + radius * 29 / 100],
            [x + radius * 49 / 100, y + radius * 12 / 100],
            [x + radius * 45 / 100, y - radius * 4 / 100],
            [x + radius * 37 / 100, y - radius * 20 / 100],
            [x + radius * 26 / 100, y - radius * 37 / 100],
            [x + radius * 12 / 100, y - radius * 53 / 100]
        ]);
    }

    private function isInsideSlot(x as Number, y as Number, slot as Number) as Boolean {
        var circle = slotCircle(slot);
        var dx = x - circle[0];
        var dy = y - circle[1];
        return (dx * dx) + (dy * dy) <= circle[2] * circle[2];
    }

    private function slotCircle(slot as Number) as Array<Number> {
        var size = screenSize();
        var layout = widgetLayout(slot);
        var centerY = (layout[1] + layout[3]) / 2;
        return [layout[0], centerY, size * 105 / 1000];
    }

    private function widgetLayout(slot as Number) as Array<Number> {
        var size = screenSize();
        var centerX = screenCenterX();
        var x = slot == FaceSlot.TOP_LEFT || slot == FaceSlot.BOTTOM_LEFT
            ? centerX - size * SIDE_X / 1000
            : centerX + size * SIDE_X / 1000;

        if (slot == FaceSlot.TOP_LEFT || slot == FaceSlot.TOP_RIGHT) {
            return [x, layoutY(TOP_ICON_Y), layoutY(TOP_VALUE_Y),
                layoutY(TOP_UNIT_Y)];
        }
        return [x, layoutY(BOTTOM_ICON_Y), layoutY(BOTTOM_VALUE_Y),
            layoutY(BOTTOM_UNIT_Y)];
    }

    private function slotBounds(slot as Number) as Graphics.BoundingBox {
        var size = screenSize();
        var layout = widgetLayout(slot);
        var halfWidth = size * 105 / 1000;
        var top = layout[1] - size * 60 / 1000;
        var bottom = layout[3] + size * 35 / 1000;
        var bounds = new Graphics.BoundingBox();
        bounds.addRectangle(layout[0] - halfWidth, top,
            halfWidth * 2, bottom - top);
        return bounds;
    }

    private function screenSize() as Number { return _width < _height ? _width : _height; }
    private function screenCenterX() as Number { return _width / 2; }
    private function screenCenterY() as Number { return _height / 2; }
    private function screenRadius() as Number { return screenSize() / 2; }

    private function layoutY(anchor as Number) as Number {
        return screenCenterY() - screenSize() / 2
            + screenSize() * anchor / 1000;
    }

    private function resolvePalette() as Void {
        _backgroundColor = Graphics.COLOR_BLACK;

        if (_theme == FaceTheme.DEEP_PURPLE) {
            _smokeTexture = WatchUi.loadResource(
                Rez.Drawables.SmokeTextureDeepPurple) as BitmapResource;
        } else if (_theme == FaceTheme.MIDNIGHT_BLUE) {
            _smokeTexture = WatchUi.loadResource(
                Rez.Drawables.SmokeTextureMidnightBlue) as BitmapResource;
        } else if (_theme == FaceTheme.GRAPHITE) {
            _smokeTexture = WatchUi.loadResource(
                Rez.Drawables.SmokeTextureGraphite) as BitmapResource;
        } else if (_theme == FaceTheme.PURE_BLACK) {
            _smokeTexture = WatchUi.loadResource(
                Rez.Drawables.SmokeTextureBlack) as BitmapResource;
        } else if (_theme == FaceTheme.GREEN) {
            _smokeTexture = WatchUi.loadResource(
                Rez.Drawables.SmokeTextureGreen) as BitmapResource;
        } else if (_theme == FaceTheme.BLUE) {
            _smokeTexture = WatchUi.loadResource(
                Rez.Drawables.SmokeTextureBlue) as BitmapResource;
        } else if (_theme == FaceTheme.RED) {
            _smokeTexture = WatchUi.loadResource(
                Rez.Drawables.SmokeTextureRed) as BitmapResource;
        } else {
            _smokeTexture = WatchUi.loadResource(
                Rez.Drawables.SmokeTextureNeonPurple) as BitmapResource;
        }
    }
}
