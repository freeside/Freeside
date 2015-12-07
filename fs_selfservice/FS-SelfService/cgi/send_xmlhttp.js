function rs_init_object () {
  var A;
  try {
    A=new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) {
    try {
      A=new ActiveXObject("Microsoft.XMLHTTP");
    } catch (oc) {
      A=null;
    }
  }
  if(!A && typeof XMLHttpRequest != "undefined")
    A = new XMLHttpRequest();
  if (!A)
    alert("Can't create XMLHttpRequest object");
  return A;
}

function send_xmlhttp (url,args,callback) {
  args = args || [];
  callback = callback || function (data) { return data };
  var content = '';
  for (var i = 0; i < args.length; i = i + 2) {
    content = content + "&" + args[i] + "=" + escape(args[i+1]);
  }
  content = content.replace( /[+]/g, '%2B'); // fix unescaped plus signs 

  var xmlhttp = rs_init_object();
  xmlhttp.open("POST", url, true);

  xmlhttp.onreadystatechange = function() {
    if (xmlhttp.readyState != 4) 
      return;
    if (xmlhttp.status == 200) {
      var data = xmlhttp.responseText;
      callback(data);
    }
  };

  xmlhttp.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
  xmlhttp.send(content);
}

