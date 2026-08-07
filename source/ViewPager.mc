import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

class ViewPager extends WatchUi.View {
    private var _views as Array<WatchUi.View>;
    private var _currentIndex as Number;
    private var _indicator as PageIndicator?;

    public function initialize() {
        View.initialize();
        _views = [];
        _currentIndex = 0;
        _indicator = null;
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
    }
    
    public function onShow() as Void {
        if (_currentIndex < _views.size()) {
            _views[_currentIndex].onShow();
        }
    }

    public function onHide() as Void {
        if (_currentIndex < _views.size()) {
            _views[_currentIndex].onHide();
        }
    }

    public function setViews(views as Array<WatchUi.View>) as Void {
        _views = views;
        _currentIndex = 0;
        if (_views.size() > 0) {
            _views[0].onShow();
        }
        requestUpdate();
    }

    public function setIndicator(indicator as PageIndicator) as Void {
        _indicator = indicator;
    }

    public function getActiveView() as WatchUi.View? {
        if (_currentIndex < _views.size()) {
            return _views[_currentIndex];
        }
        return null;
    }

    public function switchToNextPage() as Boolean {
        if (_currentIndex < _views.size() - 1) {
            _views[_currentIndex].onHide();
            _currentIndex++;
            _views[_currentIndex].onShow();
            if (_indicator != null) {
                 _indicator.setDot(_currentIndex -1, PAGE_INDICATOR_DOT_DARK);
                 _indicator.setDot(_currentIndex, PAGE_INDICATOR_DOT_LIGHT);
            }
            requestUpdate();
            return true;
        }
        return false;
    }

    public function switchToPreviousPage() as Boolean {
        if (_currentIndex > 0) {
            _views[_currentIndex].onHide();
            _currentIndex--;
            _views[_currentIndex].onShow();
            if (_indicator != null) {
               _indicator.setDot(_currentIndex + 1, PAGE_INDICATOR_DOT_DARK);
               _indicator.setDot(_currentIndex, PAGE_INDICATOR_DOT_LIGHT);
            }
            requestUpdate();
            return true;
        }
        return false;
    }
    
    public function setProhibitSwipe(prohibit as Boolean) as Void {}
}

class PageIndicator {
    public function initialize() {}
    public function setDotCount(count as Number) as Void {}
    public function setDot(index as Number, type as Number) as Void {}
}

const PAGE_INDICATOR_DOT_LIGHT = 0;
const PAGE_INDICATOR_DOT_DARK = 1;
