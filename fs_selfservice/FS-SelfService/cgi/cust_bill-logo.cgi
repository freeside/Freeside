#!/usr/bin/perl -T
#!/usr/bin/perl -Tw

use strict;
use CGI;
use FS::SelfService qw( invoice_logo );

my $cgi = new CGI;

my($query) = $cgi->keywords;
$query =~ /^([^\.\/]*)$/ or '' =~ /^()$/;
my $templatename = $1;
my $hashref = invoice_logo('templatename' => $templatename);

print $cgi->header( '-type'    => $hashref->{'content_type'},
                    '-expires' => 'now',
                  ).
      $hashref->{'logo'};

