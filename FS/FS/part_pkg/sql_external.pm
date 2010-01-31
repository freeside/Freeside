package FS::part_pkg::sql_external;

use strict;
use vars qw(@ISA %info);
use DBI;
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Base charge plus additional fees for external services from a configurable SQL query',
  'shortname' => 'External SQL query',
  'fields' => {
    'setup_fee' => { 'name' => 'Setup fee for this package',
                     'default' => 0,
                   },
    'recur_fee' => { 'name' => 'Base recurring fee for this package',
                     'default' => 0,
                   },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
    'datasrc' => { 'name' => 'DBI data source',
                   'default' => '',
                 },
    'db_username' => { 'name' => 'Database username',
                       'default' => '',
                     },
    'db_password' => { 'name' => 'Database password',
                       'default' => '',
                     },
    'query' => { 'name' => 'SQL query',
                 'default' => '',
               },
  },
  'fieldorder' => [qw( setup_fee recur_fee unused_credit datasrc db_username db_password query )],
  #'setup' => 'what.setup_fee.value',
  #'recur' => q!'my $dbh = DBI->connect("' + what.datasrc.value + '", "' + what.db_username.value + '", "' + what.db_password.value + '" ) or die $DBI::errstr; my $sth = $dbh->prepare("' + what.query.value + '") or die $dbh->errstr; my $price = ' + what.recur_fee.value + '; foreach my $cust_svc ( grep { $_->part_svc->svcdb eq "svc_external" } $cust_pkg->cust_svc ){ my $id = $cust_svc->svc_x->id; $sth->execute($id) or die $sth->errstr; $price += $sth->fetchrow_arrayref->[0]; } $price;'!,
  'weight' => '58',
);

sub calc_recur {
  my($self, $cust_pkg ) = @_;

  my $dbh = DBI->connect( map { $self->option($_) }
                              qw( datasrc db_username db_password )
                        )
    or die $DBI::errstr;

  my $sth = $dbh->prepare( $self->option('query') )
    or die $dbh->errstr;

  my $price = $self->option('recur_fee');

  foreach my $cust_svc (
    grep { $_->part_svc->svcdb eq "svc_external" } $cust_pkg->cust_svc
  ) {
    my $id = $cust_svc->svc_x->id;
    $sth->execute($id) or die $sth->errstr;
    $price += $sth->fetchrow_arrayref->[0];
  }

  $price;
}

sub can_discount { 0; }

sub is_free { 0; }

sub base_recur {
  my($self, $cust_pkg) = @_;
  $self->option('recur_fee');
}

1;
