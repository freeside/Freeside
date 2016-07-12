$().ready(function() {
  var beforePrint = function() {
    if ($('body').width() > 0) {
      // 7.5 inches * 96 DPI; maybe make the width a user pref?
      var maxwidth = 7.5 * 96;
      $('body').css('zoom', maxwidth / $('body').width());
    }
  };
  var afterPrint = function() {
    $('body').css('zoom', 1);
  }

  if (window.matchMedia) { // chrome, most importantly; also IE10?
    window.matchMedia('print').addListener(
      function(mq) {
        mq.matches ?  beforePrint() : afterPrint();
      }
    );
  } else { // other IE
    $(window).on('beforeprint', beforePrint);
    $(window).on('afterprint', afterPrint);
  }
  // got nothing for firefox
  // https://bugzilla.mozilla.org/show_bug.cgi?id=774398
  // but firefox already has "shrink to fit"
});
