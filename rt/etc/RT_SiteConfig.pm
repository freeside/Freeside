$RT::rtname = '%%%RT_DOMAIN%%%';
$RT::Organization = '%%%RT_DOMAIN%%%';

$RT::Timezone = '%%%RT_TIMEZONE%%%';

$RT::WebBaseURL = '';
$RT::WebPath = '/freeside/rt';

$RT::WebExternalAuth = 1;
$RT::WebFallbackToInternal = 1; #no
$RT::WebExternalAuto = 1;

$RT::URI::freeside::IntegrationType = 'Internal';
$RT::URI::freeside::URL = '%%%FREESIDE_URL%%%';

Set($DatabaseHost   , '');

#perl 5.8.0 - 5.8.2 experiment
#@EmailInputEncodings = qw(iso-8859-1 us-ascii utf-8); # unless (@EmailInputEncodings);
#Set($EmailOutputEncoding , 'iso-8859-1');

1;
