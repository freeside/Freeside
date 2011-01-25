package FS::NetworkMonitoringSystem::Torrus_Internal;

use strict;
#use vars qw( $DEBUG $me );
use Fcntl qw(:flock);
use IO::File;
use File::Slurp qw(slurp);

#$DEBUG = 0;
#$me = '[FS::NetworkMonitoringSystem::Torrus_Internal]';

our $lock;
our $lockfile = '/usr/local/etc/torrus/discovery/FSLOCK';
our $ddxfile  = '/usr/local/etc/torrus/discovery/routers.ddx';

sub add_router {
  my($self, $ip) = @_;

  my $newhost = 
    qq(  <host>\n).
    qq(    <param name="snmp-host" value="$ip"/>\n).
    qq(  </host>\n);

  my $ddx = $self->_torrus_loadddx;

  $ddx =~ s{(</snmp-discovery>)}{$newhost$1};

  $self->_torrus_newddx($ddx);

sub add_interface {
  my($self, $router_ip, $interface, $serviceid ) = @_;

  $interface =~ s(\/)(_)g;

  #should just use a proper XML parser huh

  my $newline = "     $serviceid:$interface:Both:main,";

  my @ddx = split(/\n/, $self->_torrus_loadddx);
  my $new = '';

  my $added = 0;

  while ( my $line = shift(@ddx) ) {
    $new .= "$line\n";
    next unless $line =~ /^\s*<param\s+name="snmp-host"\s+value="$router_ip"\/?>/i;

    while ( my $hostline = shift(@ddx) ) {
      $new .= "$hostline\n";
      if ( $hostline =~ /^\s*<param name="RFC2863_IF_MIB::external-serviceid"\/?>/i ) {

        while ( my $paramline = shift(@ddx) ) {
          if ( $paramline =~ /^\s*</param>/ ) {
            $new .= "$newline\n$paramline";
            last; #paramline
          } else {
            $new .= $paramline;
          }
        }

        $added++;

      } elsif ( $hostline =~ /^\s+<\/host>\s*/i ) {
        unless ( $added ) {
          $new .= 
            qq(   <param name="RFC2863_IF_MIB::external-serviceid">\n).
            qq(     $newline\n").
            qq(   </param>\n).
        }
        $new .= $hostline;
        last; #hostline
      }
 
    }

  }

  $self->_torrus_newddx($new);

}

sub _torrus_lock {
  $lock = new IO:::File ">>$lockfile" or die $!;
  flock($lock, LOCK_EX);
}

sub _torrus_unlock {
  flock($lock, LOCK_UN);
  close $lock;
}

sub _torrus_loadddx {
  my($self) = @_;
  $self->_torrus_lock;
  return slurp($ddxfile);
}

sub _torrus_newddx {
  my($self, $ddx) = @_;

  my $new = new IO::File ">$ddxfile.new"
    or die "can't write to $ddxfile.new: $!";
  print $new $ddx;
  close $new;
  rename("$ddxfile", $ddxfile.`date +%Y%m%d%H%M%S`) or die $!;
  rename("$ddxfile.new", $ddxfile) or die $!;

  $self->_torrus_reload;
}

sub _torrus_reload {
  my($self) = @_;

  #i should have better error checking

  system('torrus', 'devdiscover', "--in=$ddxfile");

  system('torrus', 'compile', '--tree=main'); # , '--verbose'

  $self->_torrus_unlock;

}

1;
