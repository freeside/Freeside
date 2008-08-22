package FS::Tron;
# a program to monitor outside systems

use strict;
use warnings;
use base 'Exporter';
use Net::SSH qw( sshopen2 ); #sshopen3 );
use FS::Record qw( qsearchs );
use FS::svc_external;
use FS::cust_svc_option;

our @EXPORT_OK = qw( tron_scan tron_lint);

our %desired = (
  #lenient for now, so we can fix up important stuff
  'freeside_version' => qr/^1\.(7\.3|9\.0)/,
  'debian_version'   => qr/^4/,
  'apache_mpm'       => qw/^(Prefork|$)/,

  #stuff to add/replace later
  #'pg_version'       => qr/^8\.[1-9]/,
  #'apache_version'   => qr/^2/,
  #'apache_mpm'       => qw/^Prefork/,
);

sub tron_scan {
  my $cust_svc = shift;

  my $svc_external;
  if ( ref($cust_svc) ) {
    $svc_external = $cust_svc->svc_x;
  } else {
    $svc_external = qsearchs('svc_external', { 'svcnum' => $cust_svc } );
    $cust_svc = $svc_external->cust_svc;
  }

  #don't scan again if things are okay
  my $bad = 0;
  foreach my $option ( keys %desired ) {
    my $current = $cust_svc->option($option);
    $bad++ unless $current =~ $desired{$option};
  }
  return '' unless $bad;

  #do the scan
  my %hash = ();
  my $machine = $svc_external->title; # or better as a cust_svc_option??
  sshopen2($machine, *READER, *WRITER, '/usr/local/bin/freeside-yori all');
  while (<READER>) {
    chomp;
    my($option, $value) = split(/: ?/);
    next unless defined($option) && exists($desired{$option});
    $hash{$option} = $value;
  }
  close READER;

  unless ( keys %hash ) {
    return "error scanning $machine\n";
  }

  # store the results
  foreach my $option ( keys %hash ) {
    my %opthash = ( 'optionname' => $option,
                    'svcnum'     => $cust_svc->svcnum,
                  );
    my $cust_svc_option =  qsearchs('cust_svc_option', \%opthash )
                          || new FS::cust_svc_option   \%opthash;
    next if $cust_svc_option->optionvalue eq $hash{$option};
    $cust_svc_option->optionvalue( $hash{$option} );
    my $error = $cust_svc_option->optionnum
                  ? $cust_svc_option->replace
                  : $cust_svc_option->insert;
    return $error if $error;
  }
  
  '';

}

sub tron_lint {
  my $cust_svc = shift;

  my @lint;
  foreach my $option ( keys %desired ) {
    my $current = $cust_svc->option($option);
    push @lint, "$option is $current" unless $current =~ $desired{$option};
  }

  @lint;

}

1;
