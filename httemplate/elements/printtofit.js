$().ready(function() {
  // yuck
  var isChrome = /Chrome/.test(navigator.userAgent) && /Google Inc/.test(navigator.vendor);
  var beforePrint = function() {
    if ($('body').width() > 0) {
      // 7.5 inches * 96 DPI; maybe make the width a user pref?
      var maxwidth = 7.5 * 96;
      $('body').css('zoom', maxwidth / $('body').width());
      if (isChrome) {
        // Chrome doesn't respect page-break-* styles on table rows/cells,
        // so wrap the contents of table cells with a block element
        // ref. Chromium bug #99124, #87828, #59193
        // should be fixed with Chrome 53
        var nosplits = $('.nosplitrows td');
        if (nosplits.length > 0) {
          nosplits.wrapInner('<div class="nosplit autowrap" />');
        }
      }
    }
  };
  var afterPrint = function() {
    $('body').css('zoom', 1);
    // get the direct children of the wrapper divs.
    var nosplits = $('div.autowrap >');
    if (nosplits.length > 0) {
      nosplits.unwrap();
    }
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
