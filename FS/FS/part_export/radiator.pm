package FS::part_export::radiator;

use vars qw(@ISA %info $radusers);
use Tie::IxHash;
use FS::part_export::sqlradius;

tie my %options, 'Tie::IxHash', %FS::part_export::sqlradius::options;

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export to RADIATOR',
  'options'  => \%options,
  'nodomain' => '',
  'no_machine' => 1,
  'default_svc_class' => 'Internet',
  'notes' => <<'END',
Real-time export of the <b>radusers</b> table to any SQL database in
<a href="http://www.open.com.au/radiator/">Radiator</a>-native format.
To setup accounting, see the RADIATOR documentation for hooks to update
a standard <b>radacct</b> table.
END
);

@ISA = qw(FS::part_export::sqlradius); #for regular sqlradius accounting

$radusers = 'RADUSERS'; #MySQL is case sensitive about table names!  huh

#sub export_username {
#  my($self, $svc_acct) = (shift, shift);
#  $svc_acct->email;
#}

sub _export_insert {
  my( $self, $svc_acct ) = (shift, shift);

  $self->radiator_queue(
    $svc_acct->svcnum,
    'insert',
    $self->_radiator_hash($svc_acct),
  );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

#  return "can't (yet) change domain with radiator export"
#    if $old->domain ne $new->domain;
#  return "can't (yet) change username with radiator export"
#    if $old->username ne $new->username;

  $self->radiator_queue(
    $new->svcnum,
    'replace',
    $self->export_username($old),
    $self->_radiator_hash($new),
  );
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);

  $self->radiator_queue(
    $svc_acct->svcnum,
    'delete',
    $self->export_username($svc_acct),
  );
}

sub _radiator_hash {
  my( $self, $svc_acct ) = @_;
  my %hash = (
    'username'  => $self->export_username($svc_acct),
    'pass_word' => $svc_acct->crypt_password,
    'fullname'  => $svc_acct->finger,
    map { my $method = "radius_$_"; $_ => $svc_acct->$method(); }
        qw( framed_filter_id framed_mtu framed_netmask framed_protocol
            framed_routing login_host login_service login_tcp_port )
  );
  $hash{'timeleft'} = $svc_acct->seconds
    if $svc_acct->seconds =~ /^\d+$/;
  $hash{'staticaddress'} = $svc_acct->slipip
    if $svc_acct->slipip =~ /^[\d\.]+$/; # and $self->slipip ne '0.0.0.0';

  $hash{'servicename'} = ( $svc_acct->radius_groups )[0];

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  $hash{'validto'} = $cust_pkg->bill
    if $cust_pkg && $cust_pkg->part_pkg->is_prepaid && $cust_pkg->bill;

  #some other random stuff, should probably be attributes or virtual fields
  #$hash{'state'} = 0; #only inserts
  #$hash{'badlogins'} = 0; #only inserts
  $hash{'maxlogins'} = 1;
  $hash{'addeddate'} = $cust_pkg->setup
    if $cust_pkg && $cust_pkg->setup;
  $hash{'validfrom'} = $cust_pkg->last_bill || $cust_pkg->setup
    if $cust_pkg &&  ( $cust_pkg->last_bill || $cust_pkg->setup );
  $hash{'state'} = $cust_pkg->susp ? 1 : 0
    if $cust_pkg;

  %hash;
}

sub radiator_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::radiator::radiator_$method",
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    @_,
  ); # or $queue;
}

sub radiator_insert { #subroutine, not method
  my $dbh = radiator_connect(shift, shift, shift);
  my %hash = @_;
  $hash{'state'} = 0; #see "random stuff" above
  $hash{'badlogins'} = 0; #see "random stuff" above

  my $sth = $dbh->prepare(
    "INSERT INTO $radusers ( ". join(', ', keys %hash ). ' ) '.
      'VALUES ( '. join(', ', map '?', keys %hash ). ' ) '
  ) or die $dbh->errstr;
  $sth->execute( values %hash )
    or die $sth->errstr;

  $dbh->disconnect;

}

sub radiator_replace { #subroutine, not method
  my $dbh = radiator_connect(shift, shift, shift);
  my ( $old_username, %hash ) = @_;

  my $sth = $dbh->prepare(
    "UPDATE $radusers SET ". join(', ', map " $_ = ?", keys %hash ).
      ' WHERE username = ?'
  ) or die $dbh->errstr;
  $sth->execute( values(%hash), $old_username )
    or die $sth->errstr;

  $dbh->disconnect;
}

sub radiator_delete { #subroutine, not method
  my $dbh = radiator_connect(shift, shift, shift);
  my ( $username ) = @_;

  my $sth = $dbh->prepare(
    "DELETE FROM $radusers WHERE username = ?"
  ) or die $dbh->errstr;
  $sth->execute( $username )
    or die $sth->errstr;

  $dbh->disconnect;
}


sub radiator_connect {
  #my($datasrc, $username, $password) = @_;
  #DBI->connect($datasrc, $username, $password) or die $DBI::errstr;
  DBI->connect(@_) or die $DBI::errstr;
}

1;
