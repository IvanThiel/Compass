using Toybox.WatchUi as Ui;
using Toybox.Background;

class CompassBehaviourDelegate extends Ui.BehaviorDelegate {


    function initialize() {
      BehaviorDelegate.initialize();
    }

    function onTap(evt) {
      var xx = evt.getCoordinates()[0];
      var yy = evt.getCoordinates()[1];

      GlobalTouched = 1;
      if ((xx<mW/3) && (yy>(mH/3)*2)) {
        GlobalTouched = 2;
      }
      Ui.requestUpdate();
      return true;    
    }

}