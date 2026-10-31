import Toybox.Activity;
import Toybox.AntPlus;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Passt sich der Feldgröße an. Gedacht für das große Feld einer Seite mit 6 Feldern
// (Edge 850: 420 x 236) oder ein halbes Display (420 x 299).
// Oben ein schmaler Streifen mit Vorgabe und Tacx-Soll, darunter die Buttons:
//   hohes Feld:  -10 | +10      flaches Feld:  -50 | -10 | +10 | +50
//                -50 | +50
class TacxErgView extends WatchUi.DataField {

    // Reihenfolge = Raster zeilenweise von links oben
    private const STEPS_GRID = [-10, 10, -50, 50];
    private const STEPS_ROW = [-50, -10, 10, 50];
    // Ab dieser Höhe der Button-Fläche werden 2 Reihen verwendet
    private const MIN_GRID_HEIGHT = 150;
    // Startwert und Untergrenze zugleich
    private const MIN_WATT = 70;
    private const MAX_WATT = 2000;
    // Sekunden zwischen Wiederholungen, falls der Trainer die Vorgabe nicht übernimmt
    private const RESEND_INTERVAL = 3;
    private const GAP = 4;

    private var _trainer as AntPlus.FitnessEquipment;
    // Beim Start immer 70 W, unabhängig davon, was der Trainer gerade eingestellt hat
    private var _target as Number = MIN_WATT;
    private var _tacxTarget as Number? = null;
    // Gleich beim ersten compute() senden
    private var _secondsSinceSend as Number = RESEND_INTERVAL;

    // Layout, berechnet in onLayout()
    private var _width as Number = 1;
    private var _height as Number = 1;
    private var _headerH as Number = 0;
    private var _headerFont as Graphics.FontDefinition = Graphics.FONT_SMALL;
    private var _btnFont as Graphics.FontDefinition = Graphics.FONT_SMALL;
    private var _steps as Array<Number> = STEPS_GRID;
    private var _cols as Number = 2;
    private var _rows as Number = 2;

    function initialize() {
        DataField.initialize();
        _trainer = new AntPlus.FitnessEquipment(null);
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _width = dc.getWidth();
        _height = dc.getHeight();

        // Kopfzeile: größte Schrift, die in eine halbe Breite und ein Fünftel der Höhe passt
        _headerFont = pickFont(dc,
            [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY],
            "Tacx 2000", _width / 2 - 2 * GAP, _height / 5);
        _headerH = dc.getFontHeight(_headerFont) + 2;

        // Hohe Felder: 2x2-Raster, flache Felder: 4 Buttons nebeneinander
        if (_height - _headerH >= MIN_GRID_HEIGHT) {
            _steps = STEPS_GRID;
            _cols = 2;
            _rows = 2;
        } else {
            _steps = STEPS_ROW;
            _cols = 4;
            _rows = 1;
        }

        var btnW = _width / _cols - 2 * GAP;
        var btnH = (_height - _headerH) / _rows - 2 * GAP;
        _btnFont = pickFont(dc,
            [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD,
             Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL],
            "+50", btnW - 2 * GAP, btnH);
    }

    // Erste Schrift aus der Liste, deren Text in maxW x maxH passt, sonst die letzte
    private function pickFont(dc as Graphics.Dc, fonts as Array<Graphics.FontDefinition>,
            text as String, maxW as Number, maxH as Number) as Graphics.FontDefinition {
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getFontHeight(fonts[i]) <= maxH && dc.getTextWidthInPixels(text, fonts[i]) <= maxW) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    // Wird jede Sekunde aufgerufen
    function compute(info as Activity.Info) as Void {
        var settings = _trainer.getTargetPowerSettings();
        _tacxTarget = null;
        if (settings != null && settings.targetPower != null) {
            _tacxTarget = settings.targetPower.toNumber();
        }

        // Vorgabe wiederholen, bis der Trainer sie übernommen hat
        // (auch beim Start, falls der Trainer noch nicht verbunden ist)
        _secondsSinceSend++;
        if (_tacxTarget != _target && _secondsSinceSend >= RESEND_INTERVAL) {
            sendTarget();
        }
    }

    function handleTap(x as Number, y as Number) as Void {
        // Taps auf die Kopfzeile ignorieren
        if (y < _headerH) {
            return;
        }
        var col = clamp(x * _cols / _width, 0, _cols - 1);
        var row = clamp((y - _headerH) * _rows / (_height - _headerH), 0, _rows - 1);

        _target = clamp(_target + _steps[row * _cols + col], MIN_WATT, MAX_WATT);

        sendTarget();
        WatchUi.requestUpdate();
    }

    private function clamp(v as Number, lo as Number, hi as Number) as Number {
        if (v < lo) {
            return lo;
        }
        if (v > hi) {
            return hi;
        }
        return v;
    }

    private function sendTarget() as Void {
        _trainer.controlEquipment(AntPlus.TRAINER_TARGET_POWER, _target.toFloat());
        _secondsSinceSend = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var bg = getBackgroundColor();
        var fg = (bg == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cy = _headerH / 2;

        dc.setColor(fg, bg);
        dc.clear();

        // Kopfzeile: "Soll 180 W" links, "Tacx 180" rechts (rot, solange abweichend)
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 4, cy, _headerFont,
            "Soll " + _target.toString() + " W",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (_tacxTarget != _target) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(w * 3 / 4, cy, _headerFont,
            "Tacx " + (_tacxTarget != null ? _tacxTarget.toString() : "--"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Buttons über die restliche Fläche
        var btnW = w / _cols;
        var btnH = (h - _headerH) / _rows;
        for (var i = 0; i < _steps.size(); i++) {
            var step = _steps[i];
            var x = (i % _cols) * btnW;
            var y = _headerH + (i / _cols) * btnH;
            dc.setColor(step < 0 ? Graphics.COLOR_BLUE : Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + GAP, y + GAP, btnW - 2 * GAP, btnH - 2 * GAP, 10);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + btnW / 2, y + btnH / 2, _btnFont,
                (step > 0 ? "+" : "") + step.toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
