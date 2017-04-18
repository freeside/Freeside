<?php
/*
Plugin Name: Freeside signup and self-service
Plugin URI:  http://freeside.biz/freeside
Description: Call the Freeside signup and self-service APIs from within Wordpress
Version:     0.20170417
Author:      Freeside Internet Services, Inc.
Author URI:  https://freeside.biz/freeside/
License URI: https://www.gnu.org/licenses/gpl-3.0.html
Text Domain: freeside_selfserivce
Domain Path: /languages
License:     LGPL

The Freeside signup and self-service plugin is free software: you can
redistribute it and/or modify it under the terms of the GNU Lesser General
Public License as published by the Free Software Foundation, either version
3 of the License, or any later version.
 
The Freeside signup and self-service plugin is distributed in the hope that
it will be useful, but WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Lesser General Public License for more details.
 
You should have received a copy of the GNU General Public License
along with this plugin. If not, see
https://www.gnu.org/licenses/lgpl-3.0.en.html
*/

add_action('admin_init', 'freeside_admin_init' );

add_action('init', 'freeside_init');

function freeside_admin_init() {
  register_setting( 'general', 'freeside_server', 'freeside.example.com' );
  add_settings_field( 'freeside_server', 'Freeside server', 'freeside_server_input', 'general' );
}

function freeside_server_input() {
  $value = get_option('freeside_server');
  //$value = ($value ? $value : 'freeside.example.com');
  ?>
    <INPUT TYPE="text" ID="freeside_server" NAME="freeside_server" VALUE="<?php echo htmlspecialchars($value); ?>">
  <?php
}

//TODO: remove freeside_server on uninstall

function freeside_init() {
  //error_log("FINALLY action run ". $FREESIDE_PROCESS_LOGIN);

  //error_log($GLOBALS['$FREESIDE_PROCESS_LOGIN']);
  if ( ! $GLOBALS['FREESIDE_PROCESS_LOGIN'] ) {
error_log("DACOOKIE: ". $_COOKIE['freeside_session_id']);
    $GLOBALS['FREESIDE_SESSION_ID'] = $_COOKIE['freeside_session_id'];
    return;
  } else {
    $GLOBALS['FREESIDE_PROCESS_LOGIN'] = false;
  }

  $freeside = new FreesideSelfService();

  $response = $freeside->login( array( 
    'email'    => strtolower($_POST['freeside_email']),
    'username' => strtolower($_POST['freeside_username']),
    'domain'   => strtolower($_POST['freeside_domain']),
    'password' => $_POST['freeside_password'],
  ) );

  #error_log("[login] received response from freeside: $response");

  $error = $response['error'];
  error_log($error);

  if ( $error ) {

    $url  = isset($_SERVER['HTTPS']) ? 'https://' : 'http://';
    $url .= $_SERVER['SERVER_NAME'];
    $url .= $_SERVER['REQUEST_URI'];

    wp_redirect(dirname($url). '/example_login.php?username='. urlencode($_POST['freeside_username']).
                             '&domain='.   urlencode($_POST['freeside_domain']).
                             '&email='.    urlencode($_POST['freeside_email']).
                             '&freeside_error='.    urlencode($error)
          );
    exit;

  }

  // sucessful login

  $session_id = $response['session_id'];

  error_log("[login] logged into freeside with session_id=$freeside_session_id, setting cookie");

// now what?  for now, always redirect to the main page (or the select a
// customer diversion).
// eventually, other options?

  setcookie('freeside_session_id', $session_id);

  $GLOBALS['FREESIDE_LOGIN_RESPONSE'] = $response;

}

function freeside_flatten($hash) {
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

class FreesideSelfService {

    function FreesideSelfService() {
      $this;
    }

    public function __call($name, $arguments) {
    
        $URL = 'http://'. get_option('freeside_server'). ':8080';
        error_log("[FreesideSelfService] $name called, sending to ". $URL);

        $request = xmlrpc_encode_request("FS.ClientAPI_XMLRPC.$name", freeside_flatten($arguments[0]));
        $context = stream_context_create( array( 'http' => array(
            'method' => "POST",
            'header' => "Content-Type: text/xml",
            'content' => $request
        )));
        $file = file_get_contents($URL, false, $context);
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
