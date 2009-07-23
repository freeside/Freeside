package FS::Tron;
# a program to monitor outside systems

use strict;
use warnings;
use base 'Exporter';
use Net::SSH qw( sshopen2 ); #sshopen3 );
use FS::Record qw( qsearchs );
use FS::svc_external;
use FS::cust_svc_option;

our @EXPORT_OK = qw( tron_ping tron_scan tron_lint);

our %desired = (
  #less lenient, we need to make sure we upgrade deb 4 & pg 7.4 
  'freeside_version' => qr/^1\.(7\.3|9\.0)/,
  'debian_version'   => qr/^5/, #qr/^5.0.[2-9]$/ #qr/^4/,
  'apache_mpm'       => qw/^(Prefork|$)/,
  'pg_version'       => qr/^8\.[1-9]/,
  'apache_version'   => qr/^2/,

  #payment gateway survey
#  'payment_gateway'  => qw/^authorizenet$/,

  #stuff to add/replace later
  #'apache_mpm'       => qw/^Prefork/,
  #'pg_version'       => qr/^8\.[3-9]/,
);

sub _cust_svc_external {
  my $cust_svc_or_svcnum = shift;

  my ( $cust_svc, $svc_external );
  if ( ref($cust_svc_or_svcnum) ) {
    $cust_svc = $cust_svc_or_svcnum;
    $svc_external = $cust_svc->svc_x;
  } else {
    $svc_external = qsearchs('svc_external', { svcnum=>$cust_svc_or_svcnum } );
    $cust_svc = $svc_external->cust_svc;
  }

  ( $cust_svc, $svc_external );

}

sub tron_ping {
  my( $cust_svc, $svc_external ) = _cust_svc_external(shift);

  my %hash = ();
  my $machine = $svc_external->title; # or better as a cust_svc_option??
  sshopen2($machine, *READER, *WRITER, '/bin/echo pong');
  my $pong = scalar(<READER>);
  close READER;
  close WRITER;
  
  $pong =~ /pong/;
}

sub tron_scan {
  my( $cust_svc, $svc_external ) = _cust_svc_external(shift);

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
  #sshopen2($machine, *READER, *WRITER, '/usr/local/bin/freeside-yori all');
  #fix freeside users' patch if necessary, since packages put this in /usr/bin
  sshopen2($machine, *READER, *WRITER, 'freeside-yori all');
  while (<READER>) {
    chomp;
    my($option, $value) = split(/: ?/);
    next unless defined($option) && exists($desired{$option});
    $hash{$option} = $value;
  }
  close READER;
  close WRITER;

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

  push @lint, 'unchecked' unless scalar($cust_svc->options);

  @lint;

}

1;
