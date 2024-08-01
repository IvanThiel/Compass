using Toybox.Application as App;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications as Comm;
using Toybox.WatchUi as Ui;
using Toybox.Time;
using Toybox.Time.Gregorian;

var  _mainView;


class CompassApp extends App.AppBase {
    var inBackground=false;

    function initialize() {
      AppBase.initialize();
    }

    function onSettingsChanged() { // triggered by settings change in GCM
      _mainView.getSettings();
      Ui.requestUpdate();   // update the view to reflect changes  
    }

    function getInitialView() {
      _mainView = new CompassView();
      return [ _mainView, new CompassBehaviourDelegate() ];
    }

}