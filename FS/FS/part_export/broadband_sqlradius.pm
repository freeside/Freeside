package FS::part_export::broadband_sqlradius;

use strict;
use vars qw($DEBUG @ISA @pw_set %options %info $conf);
use Tie::IxHash;
use FS::Conf;
use FS::Record qw( dbh str2time_sql ); #qsearch qsearchs );
use FS::part_export::sqlradius qw(sqlradius_connect);

FS::UID->install_callback(sub { $conf = new FS::Conf });

@ISA = qw(FS::part_export::sqlradius);

$DEBUG = 0;

@pw_set = ( 'a'..'z', 'A'..'Z', '0'..'9', '(', ')', '#', '.', ',' );

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
  'mac_case' => {
    label => 'Export MAC address as',
    type  => 'select',
    options => [ qw(uppercase lowercase) ],
  },
  'mac_delimiter' => {
    label => 'Separate MAC address octets with',
    default => '-',
  },
  'mac_as_password' => { 
    type => 'checkbox',
    default => '1',
    label => 'Use MAC address as password',
  },
  'radius_password' => { label=>'Fixed password' },
  'ip_addr_as' => { label => 'Send IP address as',
                    default => 'Framed-IP-Address' },
  'export_attrs' => { 
    type => 'checkbox', 
    label => 'Export RADIUS group attributes to this database', 
  },
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
  $svc_broadband->mac_addr_formatted(
    $self->option('mac_case'), $self->option('mac_delimiter')
  );
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
    $check{$password_attrib} = $self->export_username($svc_broadband);
  }
  elsif ( length( $self->option('radius_password',1)) ) {
    $check{$password_attrib} = $self->option('radius_password');
  }
  %check;
}

sub radius_check_suspended {
  my($self, $svc_broadband) = (shift, shift);

  return () unless $self->option('mac_as_password')
                || length( $self->option('radius_password',1));

  my $password_attrib = $conf->config('radius-password') || 'Password';
  (
    $password_attrib => join('',map($pw_set[ int(rand $#pw_set) ], (0..7) ) )
  );
}

#false laziness w/sqlradius.pm
sub _export_suspend {
  my( $self, $svc_broadband ) = (shift, shift);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my @newgroups = $self->suspended_usergroups($svc_broadband);

  unless (@newgroups) { #don't change password if assigning to a suspended group

    my $err_or_queue = $self->sqlradius_queue(
       $svc_broadband->svcnum, 'insert',
      'check', $self->export_username($svc_broadband),
      $self->radius_check_suspended($svc_broadband)
    );
    unless ( ref($err_or_queue) ) {
      $dbh->rollback if $oldAutoCommit;
      return $err_or_queue;
    }

  }

  my $error =
    $self->sqlreplace_usergroups(
      $svc_broadband->svcnum,
      $self->export_username($svc_broadband),
      '',
      [ $svc_broadband->radius_groups('hashref') ],
      \@newgroups,
    );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

sub update_svc {} #do nothing

1;

