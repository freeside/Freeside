package FS::ClientAPI::PrepaidPhone;

use strict;
#use vars qw($DEBUG $me);
use FS::Record qw(qsearchs);
use FS::rate;
use FS::svc_phone;

#$DEBUG = 0;
#$me = '[FS::ClientAPI::PrepaidPhone]';

#TODO:
# - shared-secret auth? (set a conf value)

=item call_time HASHREF

HASHREF contains the following parameters:

=over 4

=item src

Source number (with countrycode)

=item dst

Destination number (with countrycode)

=back

Always returns a hashref.  If there is an error, the hashref contains a single
"error" key with the error message as a value.  Otherwise, returns a hashref
with the following keys:

=over 4

=item custnum

Empty if no customer is found associated with the number, customer number
otherwise.

=item seconds

Number of seconds remaining for a call to destination number

=back

=cut

sub call_time {
  my $packet = shift;

  my $src = $packet->{'src'};
  my $dst = $packet->{'dst'};

  my $chargeto;
  my $rateby;
  #my $conf = new FS::Conf;
  #if ( #XXX toll-free?  collect?
  #  $phonenum = $dst;
  #} else { #use the src to find the customer
    $chargeto = $src;
    $rateby = $dst;
  #}

  my( $countrycode, $phonenum );
  if ( $chargeto #an interesting regex to parse out 1&2 digit countrycodes
         =~ /^(2[078]|3[0-469]|4[013-9]|5[1-8]|6[0-6]|7|8[1-469]|9[0-58])(\d*)$/
       || $chargeto =~ /^(\d{3})(\d*)$/
     )
  {
    $countrycode = $1;
    $phonenum = $2;
  } else { 
    return { 'error' => "unparsable billing number: $chargeto" };
  }


  my $svc_phone = qsearchs('svc_phone', { 'countrycode' => $countrycode,
                                          'phonenum'    => $phonenum,
                                        }
                          );

  unless ( $svc_phone ) {
    return { 'error' => "can't find customer for +$countrycode $phonenum" };
#    return { 'custnum' => '',
#             'seconds' => 0,
#             #'balance' => 0,
#           };
  };

  my $cust_pkg = $svc_phone->cust_svc->cust_pkg;
  my $cust_main = $cust_pkg->cust_main;

  my $part_pkg = $cust_pkg->part_pkg;
  my @part_pkg = ( $part_pkg, map $_->dst_pkg, $part_pkg->bill_part_pkg_link );
  #XXX uuh, behavior indeterminate if you have more than one voip_cdr+prefix
  #add-on, i guess.
  @part_pkg =
    grep { $_->plan eq 'voip_cdr' && $_->option('rating_method') eq 'prefix' }
         @part_pkg;

  my %return = (
    'custnum' => $cust_pkg->custnum,
    #'balance' => $cust_pkg->cust_main->balance,
  );

  return \%return unless @part_pkg;

  my $rate = qsearchs('rate', { 'ratenum'=>$part_pkg[0]->option('ratenum') } );

  #rate the call and arrive at a max # of seconds for the customer's balance

  my( $rate_countrycode, $rate_phonenum );
  if ( $rateby #this is an interesting regex to parse out 1&2 digit countrycodes
         =~ /^(2[078]|3[0-469]|4[013-9]|5[1-8]|6[0-6]|7|8[1-469]|9[0-58])(\d*)$/
       || $rateby =~ /^(\d{3})(\d*)$/
     )
  {
    $rate_countrycode = $1;
    $rate_phonenum = $2;
  } else { 
    return { 'error' => "unparsable rating number: $rateby" };
  }

  my $rate_detail = $rate->dest_detail({ 'countrycode' => $rate_countrycode,
                                         'phonenum'    => $rate_phonenum,
                                       });
  unless ( $rate_detail ) {
    return { 'error'=>"can't find rate for +$rate_countrycode $rate_phonenum"};
  }

  unless ( $rate_detail->min_charge > 0 ) {
    #XXX no charge??  return lots of seconds, a default, 0 or what?
    #return { 'error' => '0 rate for +$rate_countrycode $rate_phonenum; prepaid service not available" };
    $return{'seconds'} = 1800; #half hour?!
    return \%return;
  }

  #XXX granularity?  included minutes?  another day...
  $return{'seconds'} = int(60 * $cust_main->balance / $rate_detail->min_charge);

  return \%return;
 
}

=item call_time_nanpa 

Like I<call_time>, except countrycode 1 is not required, and all other
countrycodes must be prefixed with 011.

=cut

# - everything is assumed to be countrycode 1 unless it starts with 011(ccode)
sub call_time_nanpa {
  my $packet = shift;

  foreach (qw( src dst )) {
    if ( $packet->{$_} =~ /^011(\d+)/ ) {
      $packet->{$_} = $1;
    } elsif ( $packet->{$_} !~ /^1/ ) {
      $packet->{$_} = '1'.$packet->{$_};
    }
  }

  call_time($packet);

}

=item phonenum_balance HASHREF

HASHREF contains the following parameters:

=over 4

=item countrycode

Optional countrycode.  Defaults to 1.

=item phonenum

Phone number.

=back

Always returns a hashref.  If there is an error, the hashref contains a single
"error" key with the error message as a value.  Otherwise, returns a hashref
with the following keys:

=over 4

=item custnum

Empty if no customer is found associated with the number, customer number
otherwise.

=item balance

Customer balance.

=back

=cut

sub phonenum_balance {
  my $packet = shift;

  my $svc_phone = qsearchs('svc_phone', {
    'countrycode' => ( $packet->{'countrycode'} || 1 ),
    'phonenum'    => $packet->{'phonenum'},
  });

  unless ( $svc_phone ) {
    return { 'custnum' => '',
             'balance' => 0,
           };
  };

  my $cust_pkg = $svc_phone->cust_svc->cust_pkg;

  return {
    'custnum' => $cust_pkg->custnum,
    'balance' => $cust_pkg->cust_main->balance,
  };

}

1;
