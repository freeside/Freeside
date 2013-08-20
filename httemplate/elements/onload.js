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
  var tmp = window.onload;
  window.onload = function() {
    if (typeof(tmp)== 'function') {
      tmp();
    }
<% $m->content %>
  };
})();
