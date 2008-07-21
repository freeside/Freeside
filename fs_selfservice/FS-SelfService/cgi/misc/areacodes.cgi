#!/usr/bin/perl -w

use strict;
use CGI;
use FS::SelfService qw( mason_comp );

my $cgi = new CGI;

my $rv = mason_comp( 'comp'         => '/misc/areacodes.cgi',
                     'query_string' => $cgi->query_string, #pass CGI params...
                   );

#hmm.
my $output = $rv->{'error'} || $rv->{'output'};

print $cgi->header( '-expires' => 'now' ).
      $output;

