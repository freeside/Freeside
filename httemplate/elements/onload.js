<%doc>
Filter component to attach a window.onload handler.

Usage:
  <script>
  <&| elements/onload.js &>
    if ( the_stars_are_right ) {
      run_this_function();
    }
  </&>
  </script>

</%doc>
(function() {
  var myonload = function() {
<% $m->content %>
  }
  if ( window.addEventListener ) {
    window.addEventListener('load', myonload);
  } else if ( window.attachEvent ) {
    window.attachEvent('onload', myonload);
  }
})();
