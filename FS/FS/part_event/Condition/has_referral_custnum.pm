package FS::part_event::Condition::has_referral_custnum;

use strict;
use FS::cust_main;

use base qw( FS::part_event::Condition );

sub description { 'Customer has a referring customer'; }

sub option_fields {
  (
    'active' => { 'label' => 'Referring customer is active',
                  'type'  => 'checkbox',
                  'value' => 'Y',
                },
    'check_bal' => { 'label' => 'Check referring custoemr balance',
                     'type'  => 'checkbox',
                     'value' => 'Y',
                   },
    'balance' => { 'label'      => 'Referring customer balance under (or equal to)',
                   'type'       => 'money',
                   'value'      => '0.00', #default
                 },
    'age'     => { 'label'      => 'Referring customer balance age',
                   'type'       => 'freq',
                 },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

  if ( $self->option('active') ) {
    return 0 unless $cust_main->referral_custnum;
    #check for no cust_main for referral_custnum? (deleted?)
    return 0 unless $cust_main->referral_custnum_cust_main->status eq 'active';
  } else {
    return 0 unless $cust_main->referral_custnum; # ? 1 : 0;
  }

  return 1 unless $self->option('check_bal');

  my $referring_cust_main = $cust_main->referral_custnum_cust_main;

  #false laziness w/ balance_age_under
  my $under = $self->option('balance');
  $under = 0 unless length($under);

  my $age = $self->option_age_from('age', $opt{'time'} );

  $referring_cust_main->balance_date($age) <= $under;

}

#this is incomplete wrt checking referring customer balances, but that's okay.
# false positives are acceptable here, its just an optimizaiton
sub condition_sql {
  my( $class, $table ) = @_;

  my $sql = FS::cust_main->active_sql;
  $sql =~ s/cust_main.custnum/cust_main.referral_custnum/;
  $sql = 'cust_main.referral_custnum IS NOT NULL AND ('.
          $class->condition_sql_option('active') . ' IS NULL OR '.$sql.')';
  return $sql;
}

1;
