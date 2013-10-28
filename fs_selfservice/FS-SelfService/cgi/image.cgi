#!/usr/bin/perl -T
#!/usr/bin/perl -Tw

use strict;
use CGI;
use FS::SelfService qw( skin_info );

my $cgi = new CGI;

my($query) = $cgi->keywords;
my( $name, $agentnum ) = ( '', '' );
if ( $query =~ /^(\w+)$/ ) {
  $name = $1;
} else {
  $cgi->param('name') =~ /^(\w+)$/ or '' =~ /^()$/;
  $name = $1;
  if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
    $agentnum = $1;
  }
}

my $info = skin_info( agentnum=>$agentnum );

print $cgi->header( '-type'    => 'image/png', #for now
                    #'-expires' => 'now',
                  ).
      $info->{$name};

