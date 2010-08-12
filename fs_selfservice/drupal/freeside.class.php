<?php

class FreesideSelfService  {

  public $URL = '';
    function FreesideSelfService() {
      $this->URL = 'http://' . variable_get('freeside_hostname','') . ':8080';
      $this;
    }

    public function __call($name, $arguments) {

        error_log("[FreesideSelfService] $name called, sending to ". $this->URL);

        $request = xmlrpc_encode_request("FS.ClientAPI_XMLRPC.$name", $arguments);
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
