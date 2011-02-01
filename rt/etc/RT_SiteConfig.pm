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
# Sometimes you may want to change domain, timezone, or freeside::URL later,
# everything else should probably stay untouched.

Set($rtname, '%%%RT_DOMAIN%%%');
Set($Organization, '%%%RT_DOMAIN%%%');

Set($Timezone, '%%%RT_TIMEZONE%%%');

Set($WebExternalAuth, 1);
Set($WebFallbackToInternal, 1); #no
Set($WebExternalAuto, 1);

$RT::URI::freeside::IntegrationType = 'Internal';
$RT::URI::freeside::URL = '%%%FREESIDE_URL%%%';

$RT::URI::freeside::URL =~ m(^(https?://[^/]+)(/.*)$)i;
Set($WebBaseURL, $1);
Set($WebPath, "$2/rt");

Set($DatabaseHost   , '');

# These settings are user-editable.

Set($WebDefaultStylesheet, 'freeside2.1');
Set($UsernameFormat, 'verbose'); #back to concise to hide email addresses

#uncomment to use
#Set($DefaultSummaryRows, 10);

Set($MessageBoxWidth, 80);
Set($MessageBoxRichTextHeight, 368);

#redirects to ticket display on quick create
#Set($QuickCreateRedirect, 1);

#Set(@Plugins,(qw(Extension::QuickDelete RT::FM)));

1;
