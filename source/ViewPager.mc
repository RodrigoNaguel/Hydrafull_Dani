import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

class ViewPager extends WatchUi.View {
    private var _views as Array<WatchUi.View>;
    private var _currentIndex as Number;
    private var _indicator as PageIndicator?;
    private var _isShown as Boolean;
    private var _prohibitSwipe as Boolean;

    public function initialize() {
        View.initialize();
        _views = [];
        _currentIndex = 0;
        _indicator = null;
        _isShown = false;
        _prohibitSwipe = false;
    }

    public function onUpdate(dc as Dc) as Void {
        // Clear the screen before drawing the view
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_currentIndex < _views.size()) {
            var view = _views[_currentIndex];
            // The onUpdate of the view should handle its own drawing.
            view.onUpdate(dc);
        }
        var indicator = _indicator;
        if (indicator != null) {
            indicator.draw(dc);
        }
    }

    public function onShow() as Void {
        if (!_isShown && _currentIndex < _views.size()) {
            _isShown = true;
            _views[_currentIndex].onShow();
        }
    }

    public function onHide() as Void {
        if (_isShown && _currentIndex < _views.size()) {
            _views[_currentIndex].onHide();
            _isShown = false;
        }
    }

    public function setViews(views as Array<WatchUi.View>) as Void {
        if (_isShown && _currentIndex < _views.size()) {
            _views[_currentIndex].onHide();
        }
        _views = views;
        _currentIndex = 0;
        if (_isShown && _views.size() > 0) {
            _views[0].onShow();
        }
        WatchUi.requestUpdate();
    }

    public function setIndicator(indicator as PageIndicator) as Void {
        _indicator = indicator;
        WatchUi.requestUpdate();
    }

    public function getActiveView() as WatchUi.View? {
        if (_currentIndex < _views.size()) {
            return _views[_currentIndex];
        }
        return null;
    }

    public function switchToNextPage() as Boolean {
        if (!_prohibitSwipe && _currentIndex < _views.size() - 1) {
            if (_isShown) { _views[_currentIndex].onHide(); }
            _currentIndex++;
            if (_isShown) { _views[_currentIndex].onShow(); }
            var indicator = _indicator;
            if (indicator != null) {
                 indicator.setDot(_currentIndex -1, PAGE_INDICATOR_DOT_DARK);
                 indicator.setDot(_currentIndex, PAGE_INDICATOR_DOT_LIGHT);
            }
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    public function switchToPreviousPage() as Boolean {
        if (!_prohibitSwipe && _currentIndex > 0) {
            if (_isShown) { _views[_currentIndex].onHide(); }
            _currentIndex--;
            if (_isShown) { _views[_currentIndex].onShow(); }
            var indicator = _indicator;
            if (indicator != null) {
               indicator.setDot(_currentIndex + 1, PAGE_INDICATOR_DOT_DARK);
               indicator.setDot(_currentIndex, PAGE_INDICATOR_DOT_LIGHT);
            }
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    public function setProhibitSwipe(prohibit as Boolean) as Void {
        _prohibitSwipe = prohibit;
    }
}

class PageIndicator {
    private var _dots as Array<Number>;

    public function initialize() {
        _dots = [];
    }

    public function setDotCount(count as Number) as Void {
        _dots = [];
        for (var i = 0; i < count; i++) {
            _dots.add(PAGE_INDICATOR_DOT_DARK);
        }
    }

    public function setDot(index as Number, type as Number) as Void {
        if (index >= 0 && index < _dots.size()) {
            _dots[index] = type;
        }
    }

    public function draw(dc as Dc) as Void {
        if (_dots.size() == 0) { return; }
        var spacing = 12;
        var startX = dc.getWidth() / 2
            - ((_dots.size() - 1) * spacing) / 2;
        var y = dc.getHeight() - 10;
        for (var i = 0; i < _dots.size(); i++) {
            var color = _dots[i] == PAGE_INDICATOR_DOT_LIGHT
                ? Graphics.COLOR_WHITE : 0x555555;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(startX + i * spacing, y, 3);
        }
    }
}

const PAGE_INDICATOR_DOT_LIGHT = 0;
const PAGE_INDICATOR_DOT_DARK = 1;
