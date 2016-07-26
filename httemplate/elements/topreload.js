window.topreload = function() {
  if (window != window.top) {
    window.top.location.reload();
  }
}
