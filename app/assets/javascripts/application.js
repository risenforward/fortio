//= require es5-shim.min
//= require es5-sham.min
//= require jquery
//= require jquery_ujs
//= require bootstrap
//= require bootstrap-switch.min
//
//= require scrollIt
//= require moment
//= require bignumber
//= require underscore
//= require handlebars.runtime
//= require introjs
//= require ZeroClipboard
//= require flight.min
//= require pusher.min
//= require highstock
//= require highstock_config
//= require list
//= require helper
//= require jquery.mousewheel
//= require jquery-timing.min
//= require qrcode
//= require cookies.min

//= require_tree ./component_mixin
//= require_tree ./component_data
//= require_tree ./component_ui
//= require_tree ./templates
//= require notifier
//= require app
//= require_self


$(function(){
  notifier = window.notifier = new Notifier();
});
