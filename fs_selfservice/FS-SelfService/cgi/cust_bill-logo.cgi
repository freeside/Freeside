#!/usr/bin/perl -T
#!/usr/bin/perl -Tw

use strict;
use CGI;
use FS::SelfService qw( invoice_logo );

my $cgi = new CGI;

my %hash = ();
if ( $cgi->param('invnum') ) {
  $hash{$_} = scalar($cgi->param($_)) foreach qw( invnum template );
} else {
  my($query) = $cgi->keywords;
  $query =~ /^([^\.\/]*)$/ or '' =~ /^()$/;
  $hash{'template'} = $1;
}

my $hashref = invoice_logo(%hash);

print $cgi->header( '-type'    => $hashref->{'content_type'},
                    '-expires' => 'now',
                  ).
      $hashref->{'logo'};

