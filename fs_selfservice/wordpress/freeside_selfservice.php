<?php
/*
Plugin Name: Freeside signup and self-service plugin
Plugin URI:  http://freeside.biz/freeside
Description: Call the Freeside signup and self-service APIs from within Wordpress
Version:     0.20170403
Author:      Freeside Internet Services, Inc.
Author URI:  https://freeside.biz/freeside/
License:     GPL3
License URI: https://www.gnu.org/licenses/gpl-3.0.html
Text Domain: freeside_selfserivce
Domain Path: /languages
*/

add_action('admin_init', 'freeside_admin_init' );

function freeside_admin_init {
  register_setting( 'misc', 'freeside_selfservice_url', 'https://freeside.server:8080' );
}

function flatten($hash) {
  if ( !is_array($hash) ) return $hash;
  $flat = array();

  array_walk($hash, function($value, $key, &$to) { 
    array_push($to, $key, $value);
  }, $flat);

  foreach ($hash as $key => $value) {
    $flat[] = $key;
    $flat[] = $value;
  }

  return($flat);
}

class FreesideSelfService  {

    //Change this to match the location of your selfservice xmlrpc.cgi or daemon
    #var $URL = 'https://localhost/selfservice/xmlrpc.cgi';
    # XXX freeide_selfservice_url config value
    #var $URL = 'http://localhost/selfservice/xmlrpc.cgi';
    var $URL = get_opgion('freeside_selfservice_url');

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
