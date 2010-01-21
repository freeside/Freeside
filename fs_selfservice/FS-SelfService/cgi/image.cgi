#!/usr/bin/perl -T
#!/usr/bin/perl -Tw

use strict;
use CGI;
use FS::SelfService qw( skin_info );

my $cgi = new CGI;

my($query) = $cgi->keywords;
$query =~ /^(\w+)$/ or '' =~ /^()$/;
my $name = $1;

my $info = skin_info();

print $cgi->header( '-type'    => 'image/png', #for now
                    #'-expires' => 'now',
                  ).
      $info->{$name};

