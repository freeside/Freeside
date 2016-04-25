<?

$DEBUG = 1;

require_once('freeside.class.php');

$xml = file_get_contents('php://input');
//error_log($xml);

$doc = new SimpleXMLElement($xml);
$cd = $doc->CustomerDetails;
if ($DEBUG) {
    error_log(var_dump($cd));
}

// State and Country are names rather than codes, but we fix that on the other
// end.
// It doesn't look like TowerCoverage ever sends a company name.
$map_fields = Array(
    'first'           => 'FirstName',
    'last'            => 'LastName',
    'address1'        => 'StreetAddress',
    'city'            => 'City',
    'state'           => 'State',
    'country'         => 'Country',
    'zip'             => 'ZIP',
    'phone_daytime'   => 'PhoneNumber',
    'emailaddress'    => 'EmailAddress',
    'comment'         => 'Comment',
    'referral_title'  => 'HearAbout',
);

$prospect = Array();
// missing from this: any way to set the agent. this should use the API key.
foreach ($map_fields as $k => $v) {
    $prospect[$k] = (string)($cd->$v);
}
error_log(var_dump($prospect));
$freeside = new FreesideSelfService();
$result = $freeside->new_prospect($prospect);
error_log(var_dump($result));

?>
