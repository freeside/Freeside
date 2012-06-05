<?php

#pre-php 5.4 compatible version?
function flatten($hash) {
  if ( !is_array($hash) ) return $hash;
  $flat = array();

  array_walk($hash, function($value, $key, &$to) { 
    array_push($to, $key, $value);
  }, $flat);

  if ( PHP_VERSION_ID >= 50400 ) {

    #php 5.4+ (deb 7+)
    foreach ($hash as $key => $value) {
      $flat[] = $key;
      $flat[] = $value;
    }

  }

  return($flat);
}

#php 5.4+?
#function flatten($hash) {
#  if ( !is_array($hash) ) return $hash;
#
#  $flat = array();
#
#  foreach ($hash as $key => $value) {
#    $flat[] = $key;
#    $flat[] = $value;
#  }
#
#  return($flat);
#}

class FreesideSelfService  {

    //Change this to match the location of your selfservice xmlrpc.cgi or daemon
    #var $URL = 'https://localhost/selfservice/xmlrpc.cgi';
    var $URL = 'http://localhost/selfservice/xmlrpc.cgi';

    function FreesideSelfService() {
      $this;
    }

    public function __call($name, $arguments) {

        error_log("[FreesideSelfService] $name called, sending to ". $this->URL);

        $request = xmlrpc_encode_request("FS.ClientAPI_XMLRPC.$name", flatten($arguments[0]));
        $context = stream_context_create( array( 'http' => array(
            'method' => "POST",
            'header' => "Content-Type: text/xml",
            'content' => $request
        )));
        $file = file_get_contents($this->URL, false, $context);
        $response = xmlrpc_decode($file);
        if (xmlrpc_is_fault($response)) {
            trigger_error("[FreesideSelfService] XML-RPC communication error: $response[faultString] ($response[faultCode])");
        } else {
            //error_log("[FreesideSelfService] $response");
            return $response;
        }
    }

}

?>
