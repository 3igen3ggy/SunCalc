using Toybox.Application as App;

class SunCalcApp extends App.AppBase {
	//! Return the initial view of your application here
	function getInitialView() {
		var view;
		view = new SunCalcView();
		return [ view, new SunCalcDelegate(view, false) ];
	}

}
