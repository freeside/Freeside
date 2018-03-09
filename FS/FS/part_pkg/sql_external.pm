package FS::part_pkg::sql_external;
use base qw( FS::part_pkg::discount_Mixin FS::part_pkg::recur_Common );

use strict;
use vars qw( %info );
use DBI;
#use FS::Record qw(qsearch qsearchs);

tie our %query_style, 'Tie::IxHash', (
  'simple'    => 'Simple (a single value for the recurring charge)',
  'detailed'  => 'Detailed (multiple rows for invoice details)',
);

our @detail_cols = ( qw(amount format duration phonenum accountcode
                        startdate regionname detail)
                   );
%info = (
  'name' => 'Base charge plus additional fees for external services from a configurable SQL query',
  'shortname' => 'External SQL query',
  'inherit_fields' => [ 'prorate_Mixin', 'global_Mixin' ],
  'fields' => {
    'sync_bill_date' => { 'name' => 'Prorate first month to synchronize '.
                                    'with the customer\'s other packages',
                          'type' => 'checkbox',
                        },
    'cutoff_day'    => { 'name' => 'Billing Day (1 - 28) for prorating or '.
                                   'subscription',
                         'default' => '1',
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

    'query_style' => {
      'name' => 'Query output style',
      'type' => 'select',
      'select_options' => \%query_style,
    },

  },
  'fieldorder' => [qw( recur_method cutoff_day sync_bill_date),
                   FS::part_pkg::prorate_Mixin::fieldorder,
                   qw( datasrc db_username db_password query query_style
                  )],
  'weight' => '58',
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info(@_);
    $str .= " plus per-service charges" if $str;
    $str;
}

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;
  my $price = 0;
  my $quantity; # can be overridden; if not we use the default

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

    if ( $self->option('query_style') eq 'detailed' ) {

      while (my $row = $sth->fetchrow_hashref) {
        if (exists $row->{amount}) {
          if ( $row->{amount} eq '' ) {
            # treat as zero
          } elsif ( $row->{amount} =~ /^\d+(?:\.\d+)?$/ ) {
            $price += $row->{amount};
          } else {
            die "sql_external query returned non-numeric amount: $row->{amount}";
          }
        }
        if (defined $row->{quantity}) {
          if ( $row->{quantity} eq '' ) {
            # treat as zero
          } elsif ( $row->{quantity} =~ /^\d+$/ ) {
            $quantity += $row->{quantity};
          } else {
            die "sql_external query returned non-integer quantity: $row->{quantity}";
          }
        }

        my $detail = FS::cust_bill_pkg_detail->new;
        foreach my $field (@detail_cols) {
          if (exists $row->{$field}) {
            $detail->set($field, $row->{$field});
          }
        }
        if (!$detail->get('detail')) {
          die "sql_external query did not return detail description";
          # or make something up?
          # or just don't insert the detail?
        }

        push @$details, $detail;
      } # while $row

    } else {

      # simple style: returns only a single value, which is the price
      $price += $sth->fetchrow_arrayref->[0];

    }
  }
  $price = sprintf('%.2f', $price);

  # XXX probably shouldn't allow package quantity > 1 on these packages.
  if ($cust_pkg->quantity > 1) {
    warn "sql_external package #".$cust_pkg->pkgnum." has quantity > 1\n";
  }

  $param->{'override_quantity'} = $quantity;
  $param->{'override_charges'} = $price;
  ($cust_pkg->quantity || 1) * $self->calc_recur_Common($cust_pkg,$sdate,$details,$param);
}

sub cutoff_day {
  my( $self, $cust_pkg ) = @_;
  my $error = SUPER->cutoff_day($cust_pkg);
  #my $error = FS::part_pkg::flat::cutoff_day( $self, $cust_pkg ));
  return $error;
}

sub can_discount { 1; }

sub is_free { 0; }

1;
