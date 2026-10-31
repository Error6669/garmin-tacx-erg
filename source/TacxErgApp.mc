import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TacxErgApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new TacxErgView();
        return [view, new TacxErgDelegate(view)];
    }
}

// Taps auf das Datenfeld: horizontale Position bestimmt den Button.
class TacxErgDelegate extends WatchUi.InputDelegate {

    private var _view as TacxErgView;

    function initialize(view as TacxErgView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var xy = evt.getCoordinates();
        _view.handleTap(xy[0], xy[1]);
        // true = Tap verbraucht, sonst blendet der Edge sein Menü ein
        return true;
    }
}
