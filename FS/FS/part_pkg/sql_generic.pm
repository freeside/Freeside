package FS::part_pkg::sql_generic;

use strict;
use vars qw(@ISA %info);
use DBI;
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Base charge plus a per-domain metered rate from a configurable SQL query',
  'shortname' => 'Bulk (per-domain from SQL query)',
  'inherit_fields' => [ 'global_Mixin' ],
  'fields' => {
    'recur_included' => { 'name' => 'Units included',
                          'default' => 0,
                        },
    'recur_unit_charge' => { 'name' => 'Additional charge per unit',
                             'default' => 0,
                           },
    'datasrc' => { 'name' => 'DBI data source',
                   'default' => '',
                 },
    'db_username' => { 'name' => 'Database username',
                       'default' => '',
                     },
    'db_password' => { 'name' => 'Database username',
                       'default' => '',
                     },
    'query' => { 'name' => 'SQL query',
                 'default' => '',
               },
  },
  'fieldorder' => [qw( recur_included recur_unit_charge datasrc db_username db_password query )],
 # 'setup' => 'what.setup_fee.value',
 # 'recur' => '\'my $dbh = DBI->connect(\"\' + what.datasrc.value + \'\", \"\' + what.db_username.value + \'\") or die $DBI::errstr; \'',
 #'recur' => '\'my $dbh = DBI->connect(\"\' + what.datasrc.value + \'\", \"\' + what.db_username.value + \'\", \"\' + what.db_password.value + \'\" ) or die $DBI::errstr; my $sth = $dbh->prepare(\"\' + what.query.value + \'\") or die $dbh->errstr; my $units = 0; foreach my $cust_svc ( grep { $_->part_svc->svcdb eq \"svc_domain\" } $cust_pkg->cust_svc ) { my $domain = $cust_svc->svc_x->domain; $sth->execute($domain) or die $sth->errstr; $units += $sth->fetchrow_arrayref->[0]; } $units -= \' + what.recur_included.value + \'; $units = 0 if $units < 0; \' + what.recur_fee.value + \' + $units * \' + what.recur_unit_charge.value + \';\'',
  #'recur' => '\'my $dbh = DBI->connect("\' + what.datasrc.value + \'", "\' + what.db_username.value + \'", "\' what.db_password.value + \'" ) or die $DBI::errstr; my $sth = $dbh->prepare("\' + what.query.value + \'") or die $dbh->errstr; my $units = 0; foreach my $cust_svc ( grep { $_->part_svc->svcdb eq "svc_domain" } $cust_pkg->cust_svc ) { my $domain = $cust_svc->svc_x->domain; $sth->execute($domain) or die $sth->errstr; $units += $sth->fetchrow_arrayref->[0]; } $units -= \' + what.recur_included.value + \'; $units = 0 if $units < 0; \' + what.recur_fee.value + \' + $units * \' + what.recur_unit_charge + \';\'',
  'weight' => '56',
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info;
    $str .= " plus per-service charges" if $str;
    $str;
}

sub calc_recur {
  my($self, $cust_pkg ) = @_;

  my $dbh = DBI->connect( map { $self->option($_) }
                              qw( datasrc db_username db_password )
                        )
    or die $DBI::errstr;

  my $sth = $dbh->prepare( $self->option('query') )
    or die $dbh->errstr;

  my $units = 0;
  foreach my $cust_svc (
    grep { $_->part_svc->svcdb eq "svc_domain" } $cust_pkg->cust_svc
  ) {
    my $domain = $cust_svc->svc_x->domain;
    $sth->execute($domain) or die $sth->errstr;

    $units += $sth->fetchrow_arrayref->[0];
  }

  $units -= $self->option('recur_included');
  $units = 0 if $units < 0;

  $self->option('recur_fee') + $units * $self->option('recur_unit_charge');
}

sub can_discount { 0; }

sub is_free_options {
  qw( setup_fee recur_fee recur_unit_charge );
}

sub base_recur {
  my($self, $cust_pkg) = @_;
  $self->option('recur_fee');
}

1;
