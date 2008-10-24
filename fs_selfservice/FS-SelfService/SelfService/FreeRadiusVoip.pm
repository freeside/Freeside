#Add this to the modules section of radiusd.conf
# perl {
#   #path to this module
#   module=/usr/local/share/perl/5.8.8/FS/SelfService/FreeRadiusVoip.pm
#   func_authenticate = authenticate
# }
#
#In the Authorize section 
#Make sure that you have 'files' uncommented. Then add a line containing 'perl'
# after it. 
#
#In the Authentication section add 
# Auth-Type Perl { 
#   perl 
# } 
#
# #N/A# Add a line containing 'perl' to the Accounting section. 
# 
# In the users file comment the 'DEFAULT Auth-Type = System' lines 
# and then add 
#  DEFAULT Auth-Type = Perl 
#  Fall-Through = 1 
#
# and on debian systems, add this to /etc/init.d/freeradius, with the
# correct path (http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=416266)
#               LD_PRELOAD=/usr/lib/libperl.so.5.8.8
#               export LD_PRELOAD

BEGIN { $FS::SelfService::skip_uid_check = 1; } 

use strict;
use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);
#use Data::Dumper;
use FS::SelfService qw(call_time);

use constant RLM_MODULE_REJECT=>   0; #immediately reject the request
use constant RLM_MODULE_FAIL=>     1; #module failed, don't reply
use constant RLM_MODULE_OK=>       2; #the module is OK, continue
use constant RLM_MODULE_HANDLED=>  3; #the module handled the request, so stop
use constant RLM_MODULE_INVALID=>  4; #the module considers the request invalid
use constant RLM_MODULE_USERLOCK=> 5; #reject the request (user is locked out)
use constant RLM_MODULE_NOTFOUND=> 6; #user not found
use constant RLM_MODULE_NOOP=>     7; #module succeeded without doing anything
use constant RLM_MODULE_UPDATED=>  8; #OK (pairs modified)
use constant RLM_MODULE_NUMCODES=> 9; #How many return codes there are

sub authorize {
  return $LM_MODULE_OK;
}

sub authenticate {

  #my $src = $RAD_REQUEST{'User-Name'};

#  my $response = call_time( 'src' => $RAD_REQUEST{'Calling-Station-Id'},
#                            'dst' => $RAD_REQUEST{'Called-Station-Id'},  );
#
#  if $response{$

  $RAD_REPLY{'Session-Timeout'} = 420;
  return RLM_MODULE_UPDATED;

}

sub log_request_attributes {
       # This shouldn't be done in production environments!
       # This is only meant for debugging!
       for (keys %RAD_REQUEST) {
               &radiusd::radlog(1, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
       }
}

