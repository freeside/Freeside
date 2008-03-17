<?php
class FreesideSelfService  {

    //Change this to match the location of your selfservice xmlrpc.cgi or daemon
    //var $URL = 'https://www.example.com/selfservice/xmlrpc.cgi';
    var $URL = 'http://localhost/selfservice/xmlrpc.cgi';

    function FreesideSelfService() {
      $this;
    }

    public function __call($name, $arguments) {

        error_log("[FreesideSelfService] $name called, sending to ". $this->URL);

        $request = xmlrpc_encode_request("FS.SelfService.XMLRPC.$name", $arguments);
        $context = stream_context_create( array( 'http' => array(
            'method' => "POST",
            'header' => "Content-Type: text/xml",
            'content' => $request
        )));
        $file = file_get_contents($this->URL, false, $context);
        if (!$file) {
            trigger_error("[FreesideSelfService] XML-RPC communication error: file_get_contents did not return");
        } else {
            $response = xmlrpc_decode($file);
            if (xmlrpc_is_fault($response)) {
                trigger_error("[FreesideSelfService] XML-RPC communication error: $response[faultString] ($response[faultCode])");
            } else {
                //error_log("[FreesideSelfService] $response");
                return $response;
            }
        }
    }

}

?>
