package FS::cust_main::Credit_Limit;

use strict;
use vars qw( $conf $default_credit_limit $credit_limit_delay );
use FS::UID qw( dbh );
use FS::Record qw( qsearchs );
use FS::cust_main_credit_limit;

#ask FS::UID to run this stuff for us later
install_callback FS::UID sub { 
  $conf = new FS::Conf;
  #yes, need it for stuff below (prolly should be cached)
  $default_credit_limit = $conf->config('default_credit_limit') || 0;
};

$credit_limit_delay = 6 * 60 * 60; #6 hours?  conf?

sub check_credit_limit {
  my $self = shift;

  my $credit_limit = $self->credit_limit || $default_credit_limit;

  return '' unless $credit_limit > 0;

  #see if we've already triggered this credit limit recently
  return ''
    if qsearchs({
         'table'    => 'cust_main_credit_limit',
         'hashref'  => {
           'custnum'      => $self->custnum,
           'credit_limit' => { op=>'>=', value=> $credit_limit },
           '_date'        => { op=>'>=', value=> time - $credit_limit_delay, },
         },
         'order_by' => 'LIMIT 1',
       });

  #count up prerated CDRs

  my @cust_svc = map $_->cust_svc_unsorted( 'svcdb'=>'svc_phone' ),
                   $self->all_pkgs;
  my @svcnum = map $_->svcnum, @cust_svc;

  #false laziness  w/svc_phone->sum_cdrs / psearch_cdrs
  my $sum = qsearchs( {
    'select'    => 'SUM(rated_price) AS rated_price',
    'table'     => 'cdr',
    'hashref'   => { 'status' => 'rated', },
    'extra_sql' => ' AND svcnum IN ('. join(',',@svcnum). ') ',
  } );

  return '' unless $sum->rated_price > $credit_limit;

  #XXX trigger an alert
  # (email send / ticket create / nagios alert export) ?
  # maybe an over_credit_limit cust_main export or some such?

  # record we did it so we don't do it continuously
  my $cust_main_credit_limit = new FS::cust_main_credit_limit {
    'custnum'      => $self->custnum,
    '_date'        => time,
    'credit_limit' => $credit_limit,
    'amount'       => sprintf('%.2f', $sum->rated_price ),
  };
  my $error = $cust_main_credit_limit->insert;
  if ( $error ) {
    #"should never happen", but better to survive e.g. database going
    # away and coming back and resume doing our thing
    warn $error;
    sleep 30;
  }

}

sub num_cust_main_credit_limit {
  my $self = shift;

  my $sql = 'SELECT COUNT(*) FROM cust_main_credit_limit WHERE custnum = ?';
  my $sth = dbh->prepare($sql)   or die  dbh->errstr;
  $sth->execute( $self->custnum) or die $sth->errstr;

  $sth->fetchrow_arrayref->[0];
}

1;
