function add_password_validation (fieldid,nologin) {
  var inputfield = document.getElementById(fieldid);
  inputfield.onchange = function () {
    var fieldid = this.id+'_result';
    var resultfield = document.getElementById(fieldid);
    var svcnum = '';
    var agentnum = '';
    var svcfield = document.getElementById(this.id+'_svcnum');
    if (svcfield) {
      svcnum = svcfield.options[svcfield.selectedIndex].value;
    } else {
      var agentfield = document.getElementsByName('agentnum');
      if (agentfield[0]) {
        agentnum = agentfield[0].value;
      }
    }
    if (this.value) {
      resultfield.innerHTML = '<SPAN STYLE="color: blue;">Validating password...</SPAN>';
      var action = nologin ? 'validate_password_nologin' : 'validate_password';
      send_xmlhttp('selfservice.cgi',
        ['action',action,'fieldid',fieldid,'svcnum',svcnum,'check_password',this.value,'agentnum',agentnum],
        function (result) {
          result = JSON.parse(result);
          var resultfield = document.getElementById(result.fieldid);
          if (resultfield) {
            var errorimg = '<IMG SRC="images/error.png" style="width: 1em; display: inline-block; padding-right: .5em">';
            var validimg = '<IMG SRC="images/tick.png" style="width: 1em; display: inline-block; padding-right: .5em">';
            if (result.valid) {
              resultfield.innerHTML = validimg+'<SPAN STYLE="color: green;">Password valid!</SPAN>';
            } else if (result.error) {
              resultfield.innerHTML = errorimg+'<SPAN STYLE="color: red;">'+result.error+'</SPAN>';
            } else {
              result.syserror = result.syserror || 'Server error';
              resultfield.innerHTML = errorimg+'<SPAN STYLE="color: red;">'+result.syserror+'</SPAN>';
            }
          }
        }
      );
    } else {
      resultfield.innerHTML = '';
    }
  };
}

