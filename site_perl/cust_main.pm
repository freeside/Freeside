#this is so kludgy i'd be embarassed if it wasn't cybercash's fault
package main;
use vars qw($paymentserversecret $paymentserverport $paymentserverhost);

package FS::cust_main;

use strict;
use vars qw(@ISA @EXPORT_OK $conf $lpr $processor $xaction $E_NoErr);
use Safe;
use Exporter;
use Carp;
use Time::Local;
use Date::Format;
use Date::Manip;
use Business::CreditCard;
use FS::UID qw(getotaker);
use FS::Record qw(fields hfields qsearchs qsearch);
use FS::cust_pkg;
use FS::cust_bill;
use FS::cust_bill_pkg;
use FS::cust_pay;
#use FS::cust_pay_batch;

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(hfields);

$conf = new FS::Conf;
$lpr = $conf->config('lpr');

if ( $conf->exists('cybercash3.2') ) {
  require CCMckLib3_2;
    #qw($MCKversion %Config InitConfig CCError CCDebug CCDebug2);
  require CCMckDirectLib3_2;
    #qw(SendCC2_1Server);
  require CCMckErrno3_2;
    #qw(MCKGetErrorMessage $E_NoErr);
  import CCMckErrno3_2 qw($E_NoErr);
  my $merchant_conf;
  ($merchant_conf,$xaction)= $conf->config('cybercash3.2');
  my $status = &CCMckLib3_2::InitConfig($merchant_conf);
  if ( $status != $E_NoErr ) {
    warn "CCMckLib3_2::InitConfig error:\n";
    foreach my $key (keys %CCMckLib3_2::Config) {
      warn "  $key => $CCMckLib3_2::Config{$key}\n"
    }
    my($errmsg) = &CCMckErrno3_2::MCKGetErrorMessage($status);
    die "CCMckLib3_2::InitConfig fatal error: $errmsg\n";
  }
  $processor='cybercash3.2';
} elsif ( $conf->exists('cybercash2') ) {
  require CCLib;
    #qw(sendmserver);
  ( $main::paymentserverhost, 
    $main::paymentserverport, 
    $main::paymentserversecret,
    $xaction,
  ) = $conf->config('cybercash2');
  $processor='cybercash2';
}

=head1 NAME

FS::cust_main - Object methods for cust_main records

=head1 SYNOPSIS

  use FS::cust_main;

  $record = create FS::cust_main \%hash;
  $record = create FS::cust_main { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  @cust_pkg = $record->all_pkgs;

  @cust_pkg = $record->ncancelled_pkgs;

  $error = $record->bill;
  $error = $record->bill %options;
  $error = $record->bill 'time' => $time;

  $error = $record->collect;
  $error = $record->collect %options;
  $error = $record->collect 'invoice_time'   => $time,
                            'batch_card'     => 'yes',
                            'report_badcard' => 'yes',
                          ;

=head1 DESCRIPTION

An FS::cust_main object represents a customer.  FS::cust_main inherits from 
FS::Record.  The following fields are currently supported:

=over 4

=item custnum - primary key (assigned automatically for new customers)

=item agentnum - agent (see L<FS::agent>)

=item refnum - referral (see L<FS::part_referral>)

=item first - name

=item last - name

=item ss - social security number (optional)

=item company - (optional)

=item address1

=item address2 - (optional)

=item city

=item county - (optional, see L<FS::cust_main_county>)

=item state - (see L<FS::cust_main_county>)

=item zip

=item country - (see L<FS::cust_main_county>)

=item daytime - phone (optional)

=item night - phone (optional)

=item payby - `CARD' (credit cards), `BILL' (billing), or `COMP' (free)

=item payinfo - card number, P.O.#, or comp issuer (4-8 lowercase alphanumerics; think username)

=item paydate - expiration date, mm/yyyy, m/yyyy, mm/yy or m/yy

=item payname - name on card or billing name

=item tax - tax exempt, empty or `Y'

=item otaker - order taker (assigned automatically, see L<FS::UID>)

=back

=head1 METHODS

=over 4

=item create HASHREF

Creates a new customer.  To add the customer to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my $field;
  #foreach $field (fields('cust_main')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('cust_main',$hashref);
}

=item insert

Adds this customer to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  #no callbacks in check, only data checks
  #local $SIG{HUP} = 'IGNORE';
  #local $SIG{INT} = 'IGNORE';
  #local $SIG{QUIT} = 'IGNORE';
  #local $SIG{TERM} = 'IGNORE';
  #local $SIG{TSTP} = 'IGNORE';

  $self->check or
  $self->add;
}

=item delete

Currently unimplemented.  Maybe cancel all of this customer's
packages (cust_pkg)?

I don't remove the customer record in the database because there would then
be no record the customer ever existed (which is bad, no?)

=cut

# Usage: $error = $record -> delete;
sub delete {
   return "Can't (yet?) delete customers.";
#  my($self)=@_;
#
#  $self->del;
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a cust_main record!" unless $old->table eq "cust_main";
  return "Can't change custnum!"
    unless $old->getfield('custnum') eq $new->getfield('custnum');
  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid customer record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my($self)=@_;

  return "Not a cust_main record!" unless $self->table eq "cust_main";

  my $error =
    $self->ut_number('agentnum')
    || $self->ut_number('refnum')
    || $self->ut_textn('company')
    || $self->ut_text('address1')
    || $self->ut_textn('address2')
    || $self->ut_text('city')
    || $self->ut_textn('county')
    || $self->ut_text('state')
    || $self->ut_phonen('daytime')
    || $self->ut_phonen('night')
    || $self->ut_phonen('fax')
  ;
  return $error if $error;

  return "Unknown agent"
    unless qsearchs('agent',{'agentnum'=>$self->agentnum});

  return "Unknown referral"
    unless qsearchs('part_referral',{'refnum'=>$self->refnum});

  $self->getfield('last') =~ /^([\w \,\.\-\']+)$/ or return "Illegal last name";
  $self->setfield('last',$1);

  $self->first =~ /^([\w \,\.\-\']+)$/ or return "Illegal first name";
  $self->first($1);

  if ( $self->ss eq '' ) {
    $self->ss('');
  } else {
    my $ss = $self->ss;
    $ss =~ s/\D//g;
    $ss =~ /^(\d{3})(\d{2})(\d{4})$/
      or return "Illegal social security number";
    $self->ss("$1-$2-$3");
  }

  return "Unknown state/county/country"
    unless qsearchs('cust_main_county',{
      'state'  => $self->state,
      'county' => $self->county,
    } );

  #int'l zips?
  $self->zip =~ /^(\d{5}(-\d{4})?)$/ or return "Illegal zip";
  $self->zip($1);

  #int'l countries!
  $self->country =~ /^(US)$/ or return "Illegal country";
  $self->country($1);

  $self->payby =~ /^(CARD|BILL|COMP)$/ or return "Illegal payby";
  $self->payby($1);

  if ( $self->payby eq 'CARD' ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $payinfo =~ /^(\d{13,16})$/
      or return "Illegal credit card number";
    $payinfo = $1;
    $self->payinfo($payinfo);
    validate($payinfo) or return "Illegal credit card number";
    my $type = cardtype($payinfo);
    return "Unknown credit card type"
      unless ( $type =~ /^VISA/ ||
               $type =~ /^MasterCard/ ||
               $type =~ /^American Express/ ||
               $type =~ /^Discover/ );

  } elsif ( $self->payby eq 'BILL' ) {

    $self->payinfo =~ /^([\w \-]*)$/ or return "Illegal P.O. number";
    $self->payinfo($1);

  } elsif ( $self->payby eq 'COMP' ) {

    $self->payinfo =~ /^(\w{2,8})$/ or return "Illegal comp account issuer";
    $self->payinfo($1);

  }

  if ( $self->paydate eq '' ) {
    return "Expriation date required" unless $self->payby eq 'BILL';
    $self->paydate('');
  } else {
    $self->paydate =~ /^(\d{1,2})[\/\-](\d{2}(\d{2})?)$/
      or return "Illegal expiration date";
    if ( length($2) == 4 ) {
      $self->paydate("$2-$1-01");
    } elsif ( $2 > 97 ) { #should pry change to check for "this year"
      $self->paydate("19$2-$1-01");
    } else {
      $self->paydate("20$2-$1-01");
    }
  }

  if ( $self->payname eq '' ) {
    $self->payname( $self->first. " ". $self->getfield('last') );
  } else {
    $self->payname =~ /^([\w \,\.\-\']+)$/
      or return "Illegal billing name";
    $self->payname($1);
  }

  $self->tax =~ /^(Y?)$/ or return "Illegal tax";
  $self->tax($1);

  $self->otaker(getotaker);

  ''; #no error
}

=item all_pkgs

Returns all packages (see L<FS::cust_pkg>) for this customer.

=cut

sub all_pkgs {
  my($self)=@_;
  qsearch( 'cust_pkg', { 'custnum' => $self->custnum });
}

=item ncancelled_pkgs

Returns all non-cancelled packages (see L<FS::cust_pkg>) for this customer.

=cut

sub ncancelled_pkgs {
  my($self)=@_;
  qsearch( 'cust_pkg', {
    'custnum' => $self->custnum,
    'cancel'  => '',
  });
}

=item bill OPTIONS

Generates invoices (see L<FS::cust_bill>) for this customer.  Usually used in
conjunction with the collect method.

The only currently available option is `time', which bills the customer as if
it were that time.  It is specified as a UNIX timestamp; see
L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion
functions.

If there is an error, returns the error, otherwise returns false.

=cut

sub bill {
  my($self,%options)=@_;
  my($time) = $options{'time'} || $^T;

  my($error);

  #put below somehow?
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  # find the packages which are due for billing, find out how much they are
  # & generate invoice database.
 
  my($total_setup,$total_recur)=(0,0);

  my(@cust_bill_pkg);

  my($cust_pkg);
  foreach $cust_pkg (
    qsearch('cust_pkg',{'custnum'=> $self->getfield('custnum') } )
  ) {

    bless($cust_pkg,"FS::cust_pkg");
 
    next if ( $cust_pkg->getfield('cancel') );  

    #? to avoid use of uninitialized value errors... ?
    $cust_pkg->setfield('bill', '')
      unless defined($cust_pkg->bill);
 
    my($part_pkg)=
      qsearchs('part_pkg',{'pkgpart'=> $cust_pkg->pkgpart } );

    #so we don't modify cust_pkg record unnecessarily
    my($cust_pkg_mod_flag)=0;
    my(%hash)=$cust_pkg->hash;
    my($old_cust_pkg)=create FS::cust_pkg(\%hash);

    # bill setup
    my($setup)=0;
    unless ( $cust_pkg->setup ) {
      my($setup_prog)=$part_pkg->getfield('setup');
      my($cpt) = new Safe;
      #$cpt->permit(); #what is necessary?
      $cpt->share(qw($cust_pkg)); #can $cpt now use $cust_pkg methods?
      $setup = $cpt->reval($setup_prog);
      unless ( defined($setup) ) {
        warn "Error reval-ing part_pkg->setup pkgpart ", 
             $part_pkg->pkgpart, ": $@";
      } else {
        $cust_pkg->setfield('setup',$time);
        $cust_pkg_mod_flag=1; 
      }
    }

    #bill recurring fee
    my($recur)=0;
    my($sdate);
    if ( $part_pkg->getfield('freq') > 0 &&
         ! $cust_pkg->getfield('susp') &&
         ( $cust_pkg->getfield('bill') || 0 ) < $time
    ) {
      my($recur_prog)=$part_pkg->getfield('recur');
      my($cpt) = new Safe;
      #$cpt->permit(); #what is necessary?
      $cpt->share(qw($cust_pkg)); #can $cpt now use $cust_pkg methods?
      $recur = $cpt->reval($recur_prog);
      unless ( defined($recur) ) {
        warn "Error reval-ing part_pkg->recur pkgpart ",
             $part_pkg->pkgpart, ": $@";
      } else {
        #change this bit to use Date::Manip?
        #$sdate=$cust_pkg->bill || time;
        #$sdate=$cust_pkg->bill || $time;
        $sdate=$cust_pkg->bill || $cust_pkg->setup || $time;
        my($sec,$min,$hour,$mday,$mon,$year)=
          (localtime($sdate) )[0,1,2,3,4,5];
        $mon += $part_pkg->getfield('freq');
        until ( $mon < 12 ) { $mon -= 12; $year++; }
        $cust_pkg->setfield('bill',timelocal($sec,$min,$hour,$mday,$mon,$year));
        $cust_pkg_mod_flag=1; 
      }
    }

    warn "setup is undefinded" unless defined($setup);
    warn "recur is undefinded" unless defined($recur);
    warn "cust_pkg bill is undefinded" unless defined($cust_pkg->bill);

    if ($cust_pkg_mod_flag) {
      $error=$cust_pkg->replace($old_cust_pkg);
      if ( $error ) {
        warn "Error modifying pkgnum ", $cust_pkg->pkgnum, ": $error";
      } else {
        #just in case
        $setup=sprintf("%.2f",$setup);
        $recur=sprintf("%.2f",$recur);
        my($cust_bill_pkg)=create FS::cust_bill_pkg ({
          'pkgnum' => $cust_pkg->pkgnum,
          'setup'  => $setup,
          'recur'  => $recur,
          'sdate'  => $sdate,
          'edate'  => $cust_pkg->bill,
        });
        push @cust_bill_pkg, $cust_bill_pkg;
        $total_setup += $setup;
        $total_recur += $recur;
      }
    }

  }

  my($charged)=sprintf("%.2f",$total_setup + $total_recur);

  return '' if scalar(@cust_bill_pkg) == 0;

  unless ( $self->getfield('tax') eq 'Y' ||
           $self->getfield('tax') eq 'y' ||
           $self->getfield('payby') eq 'COMP'
  ) {
    my($cust_main_county) = qsearchs('cust_main_county',{
      'county' => $self->getfield('county'),
      'state'  => $self->getfield('state'),
    } );
    my($tax) = sprintf("%.2f",
      $charged * ( $cust_main_county->getfield('tax') / 100 )
    );
    $charged = sprintf("%.2f",$charged+$tax);

    my($cust_bill_pkg)=create FS::cust_bill_pkg ({
      'pkgnum' => 0,
      'setup'  => $tax,
      'recur'  => 0,
      'sdate'  => '',
      'edate'  => '',
    });
    push @cust_bill_pkg, $cust_bill_pkg;
  }

  my($cust_bill) = create FS::cust_bill ( {
    'custnum' => $self->getfield('custnum'),
    '_date' => $time,
    'charged' => $charged,
  } );
  $error=$cust_bill->insert;
  #shouldn't happen, but how else to handle this? (wrap me in eval, to catch 
  # fatal errors)
  die "Error creating cust_bill record: $error!\n",
      "Check updated but unbilled packages for customer", $self->custnum, "\n"
    if $error;

  my($invnum)=$cust_bill->invnum;
  my($cust_bill_pkg);
  foreach $cust_bill_pkg ( @cust_bill_pkg ) {
    $cust_bill_pkg->setfield('invnum',$invnum);
    $error=$cust_bill_pkg->insert;
    #shouldn't happen, but how else tohandle this?
    die "Error creating cust_bill_pkg record: $error!\n",
        "Check incomplete invoice ", $invnum, "\n"
      if $error;
  }
  
  ''; #no error
}

=item collect OPTIONS

(Attempt to) collect money for this customer's outstanding invoices (see
L<FS::cust_bill>).  Usually used after the bill method.

Depending on the value of `payby', this may print an invoice (`BILL'), charge
a credit card (`CARD'), or just add any necessary (pseudo-)payment (`COMP').

If there is an error, returns the error, otherwise returns false.

Currently available options are:

invoice_time - Use this time when deciding when to print invoices and
late notices on those invoices.  The default is now.  It is specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse>
for conversion functions.

batch_card - Set this true to batch cards (see L<cust_pay_batch>).  By
default, cards are processed immediately, which will generate an error if
CyberCash is not installed.

report_badcard - Set this true if you want bad card transactions to
return an error.  By default, they don't.

=cut

sub collect {
  my($self,%options)=@_;
  my($invoice_time) = $options{'invoice_time'} || $^T;

  my($total_owed) = $self->balance;
  return '' unless $total_owed > 0; #redundant?????

  #put below somehow?
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  foreach my $cust_bill ( qsearch('cust_bill', {
    'custnum' => $self->getfield('custnum'),
  } ) ) {

    bless($cust_bill,"FS::cust_bill");

    #this has to be before next's
    my($amount) = sprintf("%.2f", $total_owed < $cust_bill->owed
                                  ? $total_owed
                                  : $cust_bill->owed
    );
    $total_owed = sprintf("%.2f",$total_owed-$amount);

    next unless $cust_bill->owed > 0;

    next if qsearchs('cust_pay_batch',{'invnum'=> $cust_bill->invnum });

    #warn "invnum ". $cust_bill->invnum. " (owed ". $cust_bill->owed. ", amount $amount, total_owed $total_owed)";

    next unless $amount > 0;

    if ( $self->getfield('payby') eq 'BILL' ) {

      #30 days 2592000
      my($since)=$invoice_time - ( $cust_bill->_date || 0 );
      #warn "$invoice_time ", $cust_bill->_date, " $since";
      if ( $since >= 0 #don't print future invoices
           && ( $cust_bill->printed * 2592000 ) <= $since
      ) {

        open(LPR,"|$lpr") or die "Can't open $lpr: $!";
        print LPR $cust_bill->print_text; #( date )
        close LPR
          or die $! ? "Error closing $lpr: $!"
                       : "Exit status $? from $lpr";

        my(%hash)=$cust_bill->hash;
        $hash{'printed'}++;
        my($new_cust_bill)=create FS::cust_bill(\%hash);
        my($error)=$new_cust_bill->replace($cust_bill);
        if ( $error ) {
          warn "Error updating $cust_bill->printed: $error";
        }

      }

    } elsif ( $self->getfield('payby') eq 'COMP' ) {
      my($cust_pay) = create FS::cust_pay ( {
         'invnum' => $cust_bill->getfield('invnum'),
         'paid' => $amount,
         '_date' => '',
         'payby' => 'COMP',
         'payinfo' => $self->getfield('payinfo'),
         'paybatch' => ''
      } );
      my($error)=$cust_pay->insert;
      return 'Error COMPing invnum #' . $cust_bill->getfield('invnum') .
             ':' . $error if $error;
    } elsif ( $self->getfield('payby') eq 'CARD' ) {

      if ( $options{'batch_card'} ne 'yes' ) {

        return "Real time card processing not enabled!" unless $processor;

        if ( $processor =~ /cybercash/ ) {

          #fix exp. date for cybercash
          $self->getfield('paydate') =~ /^(\d+)\/\d*(\d{2})$/;
          my($exp)="$1/$2";

          my($paybatch)= $cust_bill->getfield('invnum') . 
                         '-' . time2str("%y%m%d%H%M%S",time);

          my($payname)= $self->getfield('payname') ||
                        $self->getfield('first') . ' ' .$self->getfield('last');

          my($address)= $self->getfield('address1');
          $address .= ", " . $self->getfield('address2')
            if $self->getfield('address2');

          my($country) = $self->getfield('country') eq 'US' ?
                         'USA' : $self->getfield('country');

          my(@full_xaction)=($xaction,
            'Order-ID'     => $paybatch,
            'Amount'       => "usd $amount",
            'Card-Number'  => $self->getfield('payinfo'),
            'Card-Name'    => $payname,
            'Card-Address' => $address,
            'Card-City'    => $self->getfield('city'),
            'Card-State'   => $self->getfield('state'),
            'Card-Zip'     => $self->getfield('zip'),
            'Card-Country' => $country,
            'Card-Exp'     => $exp,
          );

          my(%result);
          if ( $processor eq 'cybercash2' ) {
            $^W=0; #CCLib isn't -w safe, ugh!
            %result = &CCLib::sendmserver(@full_xaction);
            $^W=1;
          } elsif ( $processor eq 'cybercash3.2' ) {
            %result = &CCMckDirectLib3_2::SendCC2_1Server(@full_xaction);
          } else {
            return "Unkonwn real-time processor $processor\n";
          }
         
          #if ( $result{'MActionCode'} == 7 ) { #cybercash smps v.1.1.3
          #if ( $result{'action-code'} == 7 ) { #cybercash smps v.2.1
          if ( $result{'MStatus'} eq 'success' ) { #cybercash smps v.2 or 3
            my($cust_pay) = create FS::cust_pay ( {
               'invnum'   => $cust_bill->getfield('invnum'),
               'paid'     => $amount,
               '_date'     => '',
               'payby'    => 'CARD',
               'payinfo'  => $self->getfield('payinfo'),
               'paybatch' => "$processor:$paybatch",
            } );
            my($error)=$cust_pay->insert;
            return 'Error applying payment, invnum #' . 
              $cust_bill->getfield('invnum') . ':' . $error if $error;
          } elsif ( $result{'Mstatus'} ne 'failure-bad-money'
                 || $options{'report_badcard'} ) {
             return 'Cybercash error, invnum #' . 
               $cust_bill->getfield('invnum') . ':' . $result{'MErrMsg'};
          } else {
            return '';
          }

        } else {
          return "Unkonwn real-time processor $processor\n";
        }

      } else { #batch card

#       my($cust_pay_batch) = create FS::cust_pay_batch ( {
       my($cust_pay_batch) = new FS::Record ('cust_pay_batch', {
         'invnum'   => $cust_bill->getfield('invnum'),
         'custnum'  => $self->getfield('custnum'),
         'last'     => $self->getfield('last'),
         'first'    => $self->getfield('first'),
         'address1' => $self->getfield('address1'),
         'address2' => $self->getfield('address2'),
         'city'     => $self->getfield('city'),
         'state'    => $self->getfield('state'),
         'zip'      => $self->getfield('zip'),
         'country'  => $self->getfield('country'),
         'trancode' => 77,
         'cardnum'  => $self->getfield('payinfo'),
         'exp'      => $self->getfield('paydate'),
         'payname'  => $self->getfield('payname'),
         'amount'   => $amount,
       } );
#       my($error)=$cust_pay_batch->insert;
       my($error)=$cust_pay_batch->add;
       return "Error adding to cust_pay_batch: $error" if $error;

      }

    } else {
      return "Unknown payment type ".$self->getfield('payby');
    }

  }
  '';

}

=item total_owed

Returns the total owed for this customer on all invoices
(see L<FS::cust_bill>).

=cut

sub total_owed {
  my($self) = @_;
  my($total_bill) = 0;
  my($cust_bill);
  foreach $cust_bill ( qsearch('cust_bill', {
    'custnum' => $self->getfield('custnum'),
  } ) ) {
    $total_bill += $cust_bill->getfield('owed');
  }
  sprintf("%.2f",$total_bill);
}

=item total_credited

Returns the total credits (see L<FS::cust_credit>) for this customer.

=cut

sub total_credited {
  my($self) = @_;
  my($total_credit) = 0;
  my($cust_credit);
  foreach $cust_credit ( qsearch('cust_credit', {
    'custnum' => $self->getfield('custnum'),
  } ) ) {
    $total_credit += $cust_credit->getfield('credited');
  }
  sprintf("%.2f",$total_credit);
}

=item balance

Returns the balance for this customer (total owed minus total credited).

=cut

sub balance {
  my($self) = @_;
  sprintf("%.2f",$self->total_owed - $self->total_credited);
}

=back

=head1 BUGS

The delete method.

It doesn't properly override FS::Record yet.

hfields should be removed.

Bill and collect options should probably be passed as references instead of a
list.

CyberCash v2 forces us to define some variables in package main.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::cust_bill>, L<FS::cust_credit>
L<FS::cust_pay_batch>, L<FS::agent>, L<FS::part_referral>,
L<FS::cust_main_county>, L<FS::UID>, schema.html from the base documentation.

=head1 HISTORY

ivan@voicenet.com 97-jul-28

Changed to standard Business::CreditCard
no more TableUtil
EXPORT_OK FS::Record's hfields
removed unique calls and locking (not needed here now)
wrapped the (now) optional fields in if statements in sub check (notyetdone!)
ivan@sisd.com 97-nov-12

updated paydate with SQL-type date info ivan@sisd.com 98-mar-5

Added export of datasrc from UID.pm for Pg6.3
changed 'day' to 'daytime' because Pg6.3 reserves the day word
	bmccane@maxbaud.net	98-apr-3

in ->create, s/svc_acct/cust_main/, now it should actually eliminate the
warnings it was meant to ivan@sisd.com 98-jul-16

don't require a phone number and allow '/' in company names
ivan@sisd.com 98-jul-18

use ut_ and rewrite &check, &*_pkgs ivan@sisd.com 98-sep-5

pod, merge with FS::Bill (about time!), total_owed, total_credited and balance
methods, cleaned collect method, source modifications no longer necessary to
enable cybercash, cybercash v3 support, don't need to import
FS::UID::{datasrc,checkruid} ivan@sisd.com 98-sep-19-21

$Log: cust_main.pm,v $
Revision 1.2  1998-11-07 10:24:25  ivan
don't use depriciated FS::Bill and FS::Invoice, other miscellania


=cut

1;


