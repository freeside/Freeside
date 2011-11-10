package FS::part_export::broadband_sqlradius;

use strict;
use vars qw($DEBUG @ISA %options %info $conf);
use Tie::IxHash;
use FS::Conf;
use FS::Record qw( dbh str2time_sql ); #qsearch qsearchs );
use FS::part_export::sqlradius qw(sqlradius_connect);

FS::UID->install_callback(sub { $conf = new FS::Conf });

@ISA = qw(FS::part_export::sqlradius);

$DEBUG = 0;

tie %options, 'Tie::IxHash',
  'datasrc'  => { label=>'DBI data source ' },
  'username' => { label=>'Database username' },
  'password' => { label=>'Database password' },
  'usergroup'=> { label   => 'Group table',
                  type    => 'select',
                  options => [qw( radusergroup usergroup )],
                },
# session report doesn't currently know about this export anyway
#  'hide_ip' => {
#    type  => 'checkbox',
#    label => 'Hide IP address on session reports',
#  },
  'mac_as_password' => { 
    type => 'checkbox',
    default => '1',
    label => 'Use MAC address as password',
  },
  'radius_password' => { label=>'Fixed password' },
  'ip_addr_as' => { label => 'Send IP address as',
                    default => 'Framed-IP-Address' },
;

%info = (
  'svc'      => 'svc_broadband',
  'desc'     => 'Real-time export to SQL-backed RADIUS (such as FreeRadius) for broadband services',
  'options'  => \%options,
  'nas'      => 'Y',
  'notes'    => <<END,
Real-time export of <b>radcheck</b>, <b>radreply</b>, and <b>usergroup</b> 
tables to any SQL database for 
<a href="http://www.freeradius.org/">FreeRADIUS</a>
or <a href="http://radius.innercite.com/">ICRADIUS</a>.
<br><br>

This export is for broadband service access control based on MAC address.  
For a more typical RADIUS export, see sqlradius.
<br><br>

See the
<a href="http://search.cpan.org/dist/DBI/DBI.pm#connect">DBI documentation</a>
and the
<a href="http://search.cpan.org/search?mode=module&query=DBD%3A%3A">documentation for your DBD</a>
for the exact syntax of a DBI data source.

END
);

sub rebless { shift; }

sub export_username {
  my($self, $svc_broadband) = (shift, shift);
  $svc_broadband->mac_addr;
}

sub radius_reply {
  my($self, $svc_broadband) = (shift, shift);
  my %reply;
  if (  length($self->option('ip_addr_as',1)) 
    and length($svc_broadband->ip_addr) ) {
    $reply{$self->option('ip_addr_as')} = $svc_broadband->ip_addr;
  }
  %reply;
}

sub radius_check {
  my($self, $svc_broadband) = (shift, shift);
  my $password_attrib = $conf->config('radius-password') || 'Password';
  my %check;
  if ( $self->option('mac_as_password') ) {
    $check{$password_attrib} = $svc_broadband->mac_addr; #formatting?
  }
  elsif ( length( $self->option('radius_password',1)) ) {
    $check{$password_attrib} = $self->option('radius_password');
  }
  %check;
}

sub _export_suspend {}
sub _export_unsuspend {}

sub update_svc {} #do nothing

1;

