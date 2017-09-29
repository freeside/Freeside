#!/usr/bin/php5

<?php

$freeside = new FreesideAPI();

$result = $freeside->order_package( array(
  'secret'          => 'sharingiscaring', #config setting api_shared_secret
  'custnum'         => 619797,
  'pkgpart'         => 2,

  #the rest is optional
  'quantity'        => 5,
  'start_date'      => '12/1/2017',
  'invoice_details' => [ 'detail', 'even more detail' ],
  'address1'        => '5432 API Lane',
  'city'            => 'API Town',
  'state'           => 'AZ',
  'zip'             => '54321',
  'country'         => 'US',
  'setup_fee'       => '23',
  'recur_fee'       => '19000',
));

var_dump($result);

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

class FreesideAPI  {

    //Change this to match the location of your backoffice XML-RPC interface
    #var $URL = 'https://localhost/selfservice/xmlrpc.cgi';
    var $URL = 'http://localhost:8008/';

    function FreesideAPI() {
      $this;
    }

    public function __call($name, $arguments) {

        error_log("[FreesideAPI] $name called, sending to ". $this->URL);

        $request = xmlrpc_encode_request("FS.API.$name", flatten($arguments[0]));
        $context = stream_context_create( array( 'http' => array(
            'method' => "POST",
            'header' => "Content-Type: text/xml",
            'content' => $request
        )));
        $file = file_get_contents($this->URL, false, $context);
        $response = xmlrpc_decode($file);
        if (isset($response) && is_array($response) && xmlrpc_is_fault($response)) {
            trigger_error("[FreesideAPI] XML-RPC communication error: $response[faultString] ($response[faultCode])");
        } else {
            //error_log("[FreesideAPI] $response");
            return $response;
        }
    }

}

?>
