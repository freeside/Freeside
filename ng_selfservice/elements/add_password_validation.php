<SCRIPT>
function add_password_validation (fieldid,nologin) {
  var inputfield = document.getElementById(fieldid);
  inputfield.onchange = function () {
    var fieldid = this.id+'_result';
    var resultfield = document.getElementById(fieldid);
    var svcnum = '';
    var svcfield = document.getElementById(this.id+'_svcnum');
    if (svcfield) {
      svcnum = svcfield.options[svcfield.selectedIndex].value;
    }
    if (this.value) {
      resultfield.innerHTML = '<SPAN STYLE="color: blue;">Validating password...</SPAN>';
      var validate_data = {
        fieldid: fieldid,
        check_password: this.value,
      };
      if (!nologin) {
        validate_data['svcnum'] = svcnum;
      }
      $.ajax({
        url: 'xmlrpc_validate_passwd.php',
        data: validate_data,
        method: 'POST',
        success: function ( result ) {
          result = JSON.parse(result);
          var resultfield = document.getElementById(fieldid);
          if (resultfield) {
            var errorimg = '<IMG SRC="images/error.png" style="width: 1em; display: inline-block; padding-right: .5em">';
            var validimg = '<IMG SRC="images/tick.png" style="width: 1em; display: inline-block; padding-right: .5em">';
            if (result.password_valid) {
              resultfield.innerHTML = validimg+'<SPAN STYLE="color: green;">Password valid!</SPAN>';
            } else if (result.password_invalid) {
              resultfield.innerHTML = errorimg+'<SPAN STYLE="color: red;">'+result.password_invalid+'</SPAN>';
            } else {
              resultfield.innerHTML = '';
            }
          }
        },
        error: function (  jqXHR, textStatus, errorThrown ) {
          var resultfield = document.getElementById(fieldid);
          console.log('ajax error: '+textStatus+'+'+errorThrown);
          if (resultfield) {
            resultfield.innerHTML = '';
          }
        },
      });
    }
  };
}
</SCRIPT>
