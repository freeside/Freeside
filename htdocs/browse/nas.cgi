#!/usr/bin/perl -Tw

use strict;
use vars qw( $cgi $p );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Date::Format;
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch); # qsearchs);
use FS::CGI qw(header menubar table popurl);
use FS::nas;
use FS::port;
use FS::session;

$cgi = new CGI;
&cgisuidsetup($cgi);

$p=popurl(2);

print $cgi->header( '-expires' => 'now' ), header('NAS ports', menubar(
  'Main Menu' => $p,
));

my $now = time;

foreach my $nas ( sort { $a->nasnum <=> $b->nasnum } qsearch( 'nas', {} ) ) {
  print $nas->nasnum. ": ". $nas->nas. " ".
        $nas->nasfqdn. " (". $nas->nasip. ") ".
        "as of ". time2str("%c",$nas->last).
        " (". &pretty_interval($now - $nas->last). " ago)<br>".
        &table(). "<TR><TH>Nas<BR>Port #</TH><TH>Global<BR>Port #</BR></TH>".
        "<TH>IP address</TH><TH>User</TH><TH>Since</TH><TH>Duration</TH><TR>",
  ;
  foreach my $port ( sort {
    $a->nasport <=> $b->nasport || $a->portnum <=> $b->portnum
  } qsearch( 'port' ) ) {
    print "<TR><TD>". $port->nasport. "</TD><TD>". $port->portnum. "</TD><TD>".
          $port->ip. "</TD><TD>". 'user'. "</TD><TD>". 'since'. "</TD><TD>". 
          'duration'. "</TD></TR>"
    ;
  }
  print "</TABLE><BR>";
}

sub pretty_interval {
  my $interval = shift;
  my %howlong = (
    '604800' => 'week',
    '86400'  => 'day',
    '3600'   => 'hour',
    '60'     => 'minute',
    '1'      => 'second',
  );

  my $pretty = "";
  foreach my $key ( sort { $b <=> $a } keys %howlong ) {
    my $value = int( $interval / $key );
    if ( $value  ) {
      if ( $value == 1 ) {
        $pretty .=
          ( $howlong{$key} eq 'hour' ? 'an ' : 'a ' ). $howlong{$key}. " "
      } else {
        $pretty .= $value. ' '. $howlong{$key}. 's ';
      }
    }
    $interval -= $value * $key;
  }
  $pretty =~ /^\s*(\S.*\S)\s*$/;
  $1;
} 

#print &table(), <<END;
#<TR>
#  <TH>#</TH>
#  <TH>NAS</
