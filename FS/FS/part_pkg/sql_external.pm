package FS::part_pkg::sql_external;

use strict;
use base qw( FS::part_pkg::recur_Common );
use vars qw( %info );
use DBI;
#use FS::Record qw(qsearch qsearchs);

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
    'cutoff_day'    => { 'name' => 'Billing Day (1 - 28) for prorating or '.
                                   'subscription',
                         'default' => '1',
                       },
    'add_full_period'=> { 'name' => 'When prorating first month, also bill '.
                                    'for one full period after that',
                          'type' => 'checkbox',
                       },

    'recur_method'  => { 'name' => 'Recurring fee method',
                         #'type' => 'radio',
                         #'options' => \%recur_method,
                         'type' => 'select',
                         'select_options' => \%FS::part_pkg::recur_Common::recur_method,
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
  'fieldorder' => [qw( setup_fee recur_fee unused_credit recur_method cutoff_day
                      add_full_period datasrc db_username db_password query 
                  )],
  'weight' => '58',
);

sub calc_recur {
  my $self = shift;
  my($cust_pkg) = @_; #, $sdate, $details, $param ) = @_;

  my $price = $self->calc_recur_Common(@_);

  my $dbh = DBI->connect( map { $self->option($_) }
                              qw( datasrc db_username db_password )
                        )
    or die $DBI::errstr;

  my $sth = $dbh->prepare( $self->option('query') )
    or die $dbh->errstr;

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

1;
