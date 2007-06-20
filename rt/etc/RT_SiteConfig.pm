# Any configuration directives you include  here will override 
# RT's default configuration file, RT_Config.pm
#
# To include a directive here, just copy the equivalent statement
# from RT_Config.pm and change the value. We've included a single
# sample value below.
#
# This file is actually a perl module, so you can include valid
# perl code, as well.
#
# The converse is also true, if this file isn't valid perl, you're
# going to run into trouble. To check your SiteConfig file, use
# this comamnd:
#
#   perl -c /path/to/your/etc/RT_SiteConfig.pm

#Set( $rtname, 'example.com');

# These settings should have been inserted by the initial Freeside install.
# Somtimes you may want to change domain, timezone, or freeside::URL later,
# everything else should probably stay untouched.

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

# These settings are user-editable.

$RT::MyTicketsLength = 10;
$RT::QuickCreateLong = 0; #set to true to cause quick ticket creation to
                          #redirect to the "long" ticket creation screen
                          #instead of just creating a ticket with the subject.

1;
