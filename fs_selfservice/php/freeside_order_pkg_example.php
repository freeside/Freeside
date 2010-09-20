<?php

require('freeside.class.php');
$freeside = new FreesideSelfService();

$response = $freeside->order_pkg( array( 
    'session_id' => $_POST['session_id'],
    'pkgpart'    => 15,             #Freesize 25
    #if needed# 'svcpart'    =>
    'id'         => $_POST['id'],   #unique integer ID
    'name'       => $_POST['name'], #text name
) );

$error = $response['error'];

if ( ! $error ) {

    // sucessful order

    $pkgnum = $response['pkgnum'];
    $svcnum = $response['svcnum'];

    error_log("[order_pkg] package ordered pkgnum=$pkgnum, svcnum=$svcnum");

    // store svcnum, to be used for the customer_status call

} else {

    // unsucessful order

    error_log("[order_pkg] error ordering package: $error");

    // display error message to user

}


?>
