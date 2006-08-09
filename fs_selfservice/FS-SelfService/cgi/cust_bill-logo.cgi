#!/usr/bin/perl -Tw

use strict;
use CGI;
use FS::SelfService qw( invoice_logo );

$cgi = new CGI;

my($query) = $cgi->keywords;
$query =~ /^([^\.\/]*)$/ or '' =~ /^()$/;
my $templatename = $1;
invoice_logo($templatename);

print $cgi->header( '-type'    => $content_type,
                    '-expires' => 'now',
                  ).
      $logo;

