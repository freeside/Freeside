#this stuff is SG-specific (i.e. multi-customer company username hack)

package FS::ClientAPI::SGNG;

use strict;
use vars qw( $cache $DEBUG );
use Time::Local qw(timelocal timelocal_nocheck);
use Business::CreditCard;
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::cust_pkg;
use FS::ClientAPI::MyAccount; #qw( payment_info process_payment )

$DEBUG = 0;

sub _cache {
  $cache ||= new FS::ClientAPI_SessionCache( {
               'namespace' => 'FS::ClientAPI::MyAccount', #yes, share session_ids
             } );
}

#this might almost be general-purpose
sub decompify_pkgs {
  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  return { 'error' => 'Not a complimentary customer' }
    unless $cust_main->payby eq 'COMP';

  my $paydate =
    $cust_main->paydate =~ /^\S+$/ ? $cust_main->paydate : '2037-12-31';

  my ($payyear,$paymonth,$payday) = split (/-/,$paydate);

  my $date = timelocal(0,0,0,$payday,--$paymonth,$payyear);

  foreach my $cust_pkg (
    qsearch({ 'table'     => 'cust_pkg',
              'hashref'   => { 'custnum' => $custnum,
                               'bill'    => '',
                             },
              'extra_sql' => ' AND '. FS::cust_pkg->active_sql,
           })
  ) {
    $cust_pkg->set('bill', $date);
    my $error = $cust_pkg->replace;
    return { 'error' => $error } if $error;
  }

  return { 'error' => '' };

}

#find old payment info
# (should work just like MyAccount::payment_info, except returns previous info
#  too)
# definitly sg-specific, no one else stores past customer records like this
sub previous_payment_info {
  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $payment_info = FS::ClientAPI::MyAccount::payment_info($p);

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  #?
  return $payment_info if $cust_main->payby =~ /^(CARD|DCRD|CHEK|DCHK)$/;

  foreach my $prev_cust_main (
    reverse _previous_cust_main( 'custnum'       => $custnum, 
                                 'username'      => $cust_main->company,
                                 'with_payments' => 1,
                               )
  ) {

    next unless $prev_cust_main->payby =~ /^(CARD|DCRD|CHEK|DCHK)$/;

    if ( $prev_cust_main->payby =~ /^(CARD|DCRD)$/ ) {

      #card expired?
      my ($payyear,$paymonth,$payday) = split (/-/, $cust_main->paydate);

      my $expdate = timelocal_nocheck(0,0,0,1,$paymonth,$payyear);

      next if $expdate < time;

    } elsif ( $prev_cust_main->payby =~ /^(CHEK|DCHK)$/ ) {

      #any check?  or just skip these in favor of cards?

    }

    return { %$payment_info,
             #$prev_cust_main->payment_info
             _cust_main_payment_info( $prev_cust_main ),
             'previous_custnum' => $prev_cust_main->custnum,
           };

  }

  #still nothing?  return an error?
  return $payment_info;

}

#this is really FS::cust_main::payment_info, but here for now
sub _cust_main_payment_info {
  my $self = shift;

  my %return = ();

  $return{balance} = $self->balance;

  $return{payname} = $self->payname
                     || ( $self->first. ' '. $self->get('last') );

  $return{$_} = $self->get($_) for qw(address1 address2 city state zip);

  $return{payby} = $self->payby;
  $return{stateid_state} = $self->stateid_state;

  if ( $self->payby =~ /^(CARD|DCRD)$/ ) {
    $return{card_type} = cardtype($self->payinfo);
    $return{payinfo} = $self->paymask;

    @return{'month', 'year'} = $self->paydate_monthyear;

  }

  if ( $self->payby =~ /^(CHEK|DCHK)$/ ) {
    my ($payinfo1, $payinfo2) = split '@', $self->paymask;
    $return{payinfo1} = $payinfo1;
    $return{payinfo2} = $payinfo2;
    $return{paytype}  = $self->paytype;
    $return{paystate} = $self->paystate;

  }

  #doubleclick protection
  my $_date = time;
  $return{paybatch} = "webui-MyAccount-$_date-$$-". rand() * 2**32;

  %return;

}

#find old cust_main records (with payments)
sub _previous_cust_main {
  my %opt = @_;
  my $custnum  = $opt{'custnum'};
  my $username = $opt{'username'};
  
  my %search = ();
  if ( $opt{'with_payments'} ) {
    $search{'extra_sql'} =
      ' AND 0 < ( SELECT COUNT(*) FROM cust_pay
                    WHERE cust_pay.custnum = cust_main.custnum
                )
      ';
  }

  qsearch( {
    'table'    => 'cust_main', 
    'hashref'  => { 'company' => { op => 'ILIKE', value => $opt{'username'} },
                    'custnum' => { op => '!=',    value => $opt{'custnum'}  },
                  },
    'order_by' => 'ORDER BY custnum',
    %search,
  } );

}

#since we could be passing masked old CC data, need to look that up and
#replace it (like regular process_payment does) w/info from old customer record
sub previous_process_payment {
  my $p = shift;

  return FS::ClientAPI::MyAccount::process_payment($p)
    unless $p->{'previous_custnum'}
        && (    ( $p->{'payby'} =~ /^(CARD|DCRD)$/ && $p->{'payinfo'}  =~ /x/i )
             || ( $p->{'payby'} =~ /^(CHEK|DCHK)$/ && $p->{'payinfo1'} =~ /x/i )
           );

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  #make sure this is really a previous custnum of this customer
  my @previous_cust_main =
    grep { $_->custnum == $p->{'previous_custnum'} }
         _previous_cust_main( 'custnum'       => $custnum, 
                              'username'      => $cust_main->company,
                              'with_payments' => 1,
                            );

  my $previous_cust_main = $previous_cust_main[0];

  #causes problems with old data w/old masking method
  #if $previous_cust_main->paymask eq $payinfo;
  
  if ( $p->{'payby'} =~ /^(CHEK|DCHK)$/ && $p->{'payinfo1'} =~ /x/i ) {
    ( $p->{'payinfo1'}, $p->{'payinfo2'} ) =
      split('@', $previous_cust_main->payinfo);
  } elsif ( $p->{'payby'} =~ /^(CARD|DCRD)$/ && $p->{'payinfo'} =~ /x/i ) {
    $p->{'payinfo'} = $previous_cust_main->payinfo;
  }

  FS::ClientAPI::MyAccount::process_payment($p);

}

sub previous_process_payment_order_pkg {
  my $p = shift;

  my $hr = previous_process_payment($p);
  return $hr if $hr->{'error'};

  order_pkg($p);
}

sub previous_process_payment_change_pkg {
  my $p = shift;

  my $hr = previous_process_payment($p);
  return $hr if $hr->{'error'};

  change_pkg($p);
}

sub previous_process_payment_order_renew {
  my $p = shift;

  my $hr = previous_process_payment($p);
  return $hr if $hr->{'error'};

  order_renew($p);
}

1;

