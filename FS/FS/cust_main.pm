package FS::cust_main;

use strict;
use vars qw( @ISA @EXPORT_OK $conf $DEBUG $import );
use vars qw( $realtime_bop_decline_quiet ); #ugh
use Safe;
use Carp;
use Exporter;
BEGIN {
  eval "use Time::Local;";
  die "Time::Local minimum version 1.05 required with Perl versions before 5.6"
    if $] < 5.006 && !defined($Time::Local::VERSION);
  #eval "use Time::Local qw(timelocal timelocal_nocheck);";
  eval "use Time::Local qw(timelocal_nocheck);";
}
use Date::Format;
#use Date::Manip;
use String::Approx qw(amatch);
use Business::CreditCard;
use FS::UID qw( getotaker dbh );
use FS::Record qw( qsearchs qsearch dbdef );
use FS::Misc qw( send_email );
use FS::cust_pkg;
use FS::cust_bill;
use FS::cust_bill_pkg;
use FS::cust_pay;
use FS::cust_pay_void;
use FS::cust_credit;
use FS::cust_refund;
use FS::part_referral;
use FS::cust_main_county;
use FS::agent;
use FS::cust_main_invoice;
use FS::cust_credit_bill;
use FS::cust_bill_pay;
use FS::prepay_credit;
use FS::queue;
use FS::part_pkg;
use FS::part_bill_event;
use FS::cust_bill_event;
use FS::cust_tax_exempt;
use FS::type_pkgs;
use FS::Msgcat qw(gettext);

@ISA = qw( FS::Record );

@EXPORT_OK = qw( smart_search );

$realtime_bop_decline_quiet = 0;

$DEBUG = 0;
#$DEBUG = 1;

$import = 0;

#ask FS::UID to run this stuff for us later
#$FS::UID::callback{'FS::cust_main'} = sub { 
install_callback FS::UID sub { 
  $conf = new FS::Conf;
  #yes, need it for stuff below (prolly should be cached)
};

sub _cache {
  my $self = shift;
  my ( $hashref, $cache ) = @_;
  if ( exists $hashref->{'pkgnum'} ) {
#    #@{ $self->{'_pkgnum'} } = ();
    my $subcache = $cache->subcache( 'pkgnum', 'cust_pkg', $hashref->{custnum});
    $self->{'_pkgnum'} = $subcache;
    #push @{ $self->{'_pkgnum'} },
    FS::cust_pkg->new_or_cached($hashref, $subcache) if $hashref->{pkgnum};
  }
}

=head1 NAME

FS::cust_main - Object methods for cust_main records

=head1 SYNOPSIS

  use FS::cust_main;

  $record = new FS::cust_main \%hash;
  $record = new FS::cust_main { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  @cust_pkg = $record->all_pkgs;

  @cust_pkg = $record->ncancelled_pkgs;

  @cust_pkg = $record->suspended_pkgs;

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

=item refnum - Advertising source (see L<FS::part_referral>)

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

=item fax - phone (optional)

=item ship_first - name

=item ship_last - name

=item ship_company - (optional)

=item ship_address1

=item ship_address2 - (optional)

=item ship_city

=item ship_county - (optional, see L<FS::cust_main_county>)

=item ship_state - (see L<FS::cust_main_county>)

=item ship_zip

=item ship_country - (see L<FS::cust_main_county>)

=item ship_daytime - phone (optional)

=item ship_night - phone (optional)

=item ship_fax - phone (optional)

=item payby - I<CARD> (credit card - automatic), I<DCRD> (credit card - on-demand), I<CHEK> (electronic check - automatic), I<DCHK> (electronic check - on-demand), I<LECB> (Phone bill billing), I<BILL> (billing), I<COMP> (free), or I<PREPAY> (special billing type: applies a credit - see L<FS::prepay_credit> and sets billing type to I<BILL>)

=item payinfo - card number, P.O., comp issuer (4-8 lowercase alphanumerics; think username) or prepayment identifier (see L<FS::prepay_credit>)

=item paycvv - Card Verification Value, "CVV2" (also known as CVC2 or CID), the 3 or 4 digit number on the back (or front, for American Express) of the credit card

=item paydate - expiration date, mm/yyyy, m/yyyy, mm/yy or m/yy

=item payname - name on card or billing name

=item tax - tax exempt, empty or `Y'

=item otaker - order taker (assigned automatically, see L<FS::UID>)

=item comments - comments (optional)

=item referral_custnum - referring customer number

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new customer.  To add the customer to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_main'; }

=item insert [ CUST_PKG_HASHREF [ , INVOICING_LIST_ARYREF ] [ , OPTION => VALUE ... ] ]

Adds this customer to the database.  If there is an error, returns the error,
otherwise returns false.

CUST_PKG_HASHREF: If you pass a Tie::RefHash data structure to the insert
method containing FS::cust_pkg and FS::svc_I<tablename> objects, all records
are inserted atomicly, or the transaction is rolled back.  Passing an empty
hash reference is equivalent to not supplying this parameter.  There should be
a better explanation of this, but until then, here's an example:

  use Tie::RefHash;
  tie %hash, 'Tie::RefHash'; #this part is important
  %hash = (
    $cust_pkg => [ $svc_acct ],
    ...
  );
  $cust_main->insert( \%hash );

INVOICING_LIST_ARYREF: If you pass an arrarref to the insert method, it will
be set as the invoicing list (see L<"invoicing_list">).  Errors return as
expected and rollback the entire transaction; it is not necessary to call 
check_invoicing_list first.  The invoicing_list is set after the records in the
CUST_PKG_HASHREF above are inserted, so it is now possible to set an
invoicing_list destination to the newly-created svc_acct.  Here's an example:

  $cust_main->insert( {}, [ $email, 'POST' ] );

Currently available options are: I<depend_jobnum> and I<noexport>.

If I<depend_jobnum> is set, all provisioning jobs will have a dependancy
on the supplied jobnum (they will not run until the specific job completes).
This can be used to defer provisioning until some action completes (such
as running the customer's credit card sucessfully).

The I<noexport> option is deprecated.  If I<noexport> is set true, no
provisioning jobs (exports) are scheduled.  (You can schedule them later with
the B<reexport> method.)

=cut

sub insert {
  my $self = shift;
  my $cust_pkgs = @_ ? shift : {};
  my $invoicing_list = @_ ? shift : '';
  my %options = @_;
  warn "FS::cust_main::insert called with options ".
       join(', ', map { "$_: $options{$_}" } keys %options ). "\n"
    if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $amount = 0;
  my $seconds = 0;
  if ( $self->payby eq 'PREPAY' ) {
    $self->payby('BILL');
    my $prepay_credit = qsearchs(
      'prepay_credit',
      { 'identifier' => $self->payinfo },
      '',
      'FOR UPDATE'
    );
    warn "WARNING: can't find pre-found prepay_credit: ". $self->payinfo
      unless $prepay_credit;
    $amount = $prepay_credit->amount;
    $seconds = $prepay_credit->seconds;
    my $error = $prepay_credit->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "removing prepay_credit (transaction rolled back): $error";
    }
  }

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    #return "inserting cust_main record (transaction rolled back): $error";
    return $error;
  }

  # invoicing list
  if ( $invoicing_list ) {
    $error = $self->check_invoicing_list( $invoicing_list );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "checking invoicing_list (transaction rolled back): $error";
    }
    $self->invoicing_list( $invoicing_list );
  }

  # packages
  $error = $self->order_pkgs($cust_pkgs, \$seconds, %options);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $seconds ) {
    $dbh->rollback if $oldAutoCommit;
    return "No svc_acct record to apply pre-paid time";
  }

  if ( $amount ) {
    my $cust_credit = new FS::cust_credit {
      'custnum' => $self->custnum,
      'amount'  => $amount,
    };
    $error = $cust_credit->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "inserting credit (transaction rolled back): $error";
    }
  }

  $error = $self->queue_fuzzyfiles_update;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "updating fuzzy search cache: $error";
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item order_pkgs HASHREF, [ SECONDSREF, [ , OPTION => VALUE ... ] ]

Like the insert method on an existing record, this method orders a package
and included services atomicaly.  Pass a Tie::RefHash data structure to this
method containing FS::cust_pkg and FS::svc_I<tablename> objects.  There should
be a better explanation of this, but until then, here's an example:

  use Tie::RefHash;
  tie %hash, 'Tie::RefHash'; #this part is important
  %hash = (
    $cust_pkg => [ $svc_acct ],
    ...
  );
  $cust_main->order_pkgs( \%hash, \'0', 'noexport'=>1 );

Currently available options are: I<depend_jobnum> and I<noexport>.

If I<depend_jobnum> is set, all provisioning jobs will have a dependancy
on the supplied jobnum (they will not run until the specific job completes).
This can be used to defer provisioning until some action completes (such
as running the customer's credit card sucessfully).

The I<noexport> option is deprecated.  If I<noexport> is set true, no
provisioning jobs (exports) are scheduled.  (You can schedule them later with
the B<reexport> method for each cust_pkg object.  Using the B<reexport> method
on the cust_main object is not recommended, as existing services will also be
reexported.)

=cut

sub order_pkgs {
  my $self = shift;
  my $cust_pkgs = shift;
  my $seconds = shift;
  my %options = @_;
  my %svc_options = ();
  $svc_options{'depend_jobnum'} = $options{'depend_jobnum'}
    if exists $options{'depend_jobnum'};
  warn "FS::cust_main::order_pkgs called with options ".
       join(', ', map { "$_: $options{$_}" } keys %options ). "\n"
    if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  local $FS::svc_Common::noexport_hack = 1 if $options{'noexport'};

  foreach my $cust_pkg ( keys %$cust_pkgs ) {
    $cust_pkg->custnum( $self->custnum );
    my $error = $cust_pkg->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "inserting cust_pkg (transaction rolled back): $error";
    }
    foreach my $svc_something ( @{$cust_pkgs->{$cust_pkg}} ) {
      $svc_something->pkgnum( $cust_pkg->pkgnum );
      if ( $seconds && $$seconds && $svc_something->isa('FS::svc_acct') ) {
        $svc_something->seconds( $svc_something->seconds + $$seconds );
        $$seconds = 0;
      }
      $error = $svc_something->insert(%svc_options);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        #return "inserting svc_ (transaction rolled back): $error";
        return $error;
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}

=item reexport

This method is deprecated.  See the I<depend_jobnum> option to the insert and
order_pkgs methods for a better way to defer provisioning.

Re-schedules all exports by calling the B<reexport> method of all associated
packages (see L<FS::cust_pkg>).  If there is an error, returns the error;
otherwise returns false.

=cut

sub reexport {
  my $self = shift;

  carp "warning: FS::cust_main::reexport is deprectated; ".
       "use the depend_jobnum option to insert or order_pkgs to delay export";

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $cust_pkg ( $self->ncancelled_pkgs ) {
    my $error = $cust_pkg->reexport;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete NEW_CUSTNUM

This deletes the customer.  If there is an error, returns the error, otherwise
returns false.

This will completely remove all traces of the customer record.  This is not
what you want when a customer cancels service; for that, cancel all of the
customer's packages (see L</cancel>).

If the customer has any uncancelled packages, you need to pass a new (valid)
customer number for those packages to be transferred to.  Cancelled packages
will be deleted.  Did I mention that this is NOT what you want when a customer
cancels service and that you really should be looking see L<FS::cust_pkg/cancel>?

You can't delete a customer with invoices (see L<FS::cust_bill>),
or credits (see L<FS::cust_credit>), payments (see L<FS::cust_pay>) or
refunds (see L<FS::cust_refund>).

=cut

sub delete {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $self->cust_bill ) {
    $dbh->rollback if $oldAutoCommit;
    return "Can't delete a customer with invoices";
  }
  if ( $self->cust_credit ) {
    $dbh->rollback if $oldAutoCommit;
    return "Can't delete a customer with credits";
  }
  if ( $self->cust_pay ) {
    $dbh->rollback if $oldAutoCommit;
    return "Can't delete a customer with payments";
  }
  if ( $self->cust_refund ) {
    $dbh->rollback if $oldAutoCommit;
    return "Can't delete a customer with refunds";
  }

  my @cust_pkg = $self->ncancelled_pkgs;
  if ( @cust_pkg ) {
    my $new_custnum = shift;
    unless ( qsearchs( 'cust_main', { 'custnum' => $new_custnum } ) ) {
      $dbh->rollback if $oldAutoCommit;
      return "Invalid new customer number: $new_custnum";
    }
    foreach my $cust_pkg ( @cust_pkg ) {
      my %hash = $cust_pkg->hash;
      $hash{'custnum'} = $new_custnum;
      my $new_cust_pkg = new FS::cust_pkg ( \%hash );
      my $error = $new_cust_pkg->replace($cust_pkg);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }
  my @cancelled_cust_pkg = $self->all_pkgs;
  foreach my $cust_pkg ( @cancelled_cust_pkg ) {
    my $error = $cust_pkg->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $cust_main_invoice ( #(email invoice destinations, not invoices)
    qsearch( 'cust_main_invoice', { 'custnum' => $self->custnum } )
  ) {
    my $error = $cust_main_invoice->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item replace OLD_RECORD [ INVOICING_LIST_ARYREF ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

INVOICING_LIST_ARYREF: If you pass an arrarref to the insert method, it will
be set as the invoicing list (see L<"invoicing_list">).  Errors return as
expected and rollback the entire transaction; it is not necessary to call 
check_invoicing_list first.  Here's an example:

  $new_cust_main->replace( $old_cust_main, [ $email, 'POST' ] );

=cut

sub replace {
  my $self = shift;
  my $old = shift;
  my @param = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  if ( $self->payby eq 'COMP' && $self->payby ne $old->payby
       && $conf->config('users-allow_comp')                  ) {
    return "You are not permitted to create complimentary accounts."
      unless grep { $_ eq getotaker } $conf->config('users-allow_comp');
  }

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::replace($old);

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( @param ) { # INVOICING_LIST_ARYREF
    my $invoicing_list = shift @param;
    $error = $self->check_invoicing_list( $invoicing_list );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    $self->invoicing_list( $invoicing_list );
  }

  if ( $self->payby =~ /^(CARD|CHEK|LECB)$/ &&
       grep { $self->get($_) ne $old->get($_) } qw(payinfo paydate payname) ) {
    # card/check/lec info has changed, want to retry realtime_ invoice events
    my $error = $self->retry_realtime;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $error = $self->queue_fuzzyfiles_update;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "updating fuzzy search cache: $error";
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item queue_fuzzyfiles_update

Used by insert & replace to update the fuzzy search cache

=cut

sub queue_fuzzyfiles_update {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $queue = new FS::queue { 'job' => 'FS::cust_main::append_fuzzyfiles' };
  my $error = $queue->insert($self->getfield('last'), $self->company);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "queueing job (transaction rolled back): $error";
  }

  if ( defined $self->dbdef_table->column('ship_last') && $self->ship_last ) {
    $queue = new FS::queue { 'job' => 'FS::cust_main::append_fuzzyfiles' };
    $error = $queue->insert($self->getfield('ship_last'), $self->ship_company);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "queueing job (transaction rolled back): $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item check

Checks all fields to make sure this is a valid customer record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  #warn "BEFORE: \n". $self->_dump;

  my $error =
    $self->ut_numbern('custnum')
    || $self->ut_number('agentnum')
    || $self->ut_number('refnum')
    || $self->ut_name('last')
    || $self->ut_name('first')
    || $self->ut_textn('company')
    || $self->ut_text('address1')
    || $self->ut_textn('address2')
    || $self->ut_text('city')
    || $self->ut_textn('county')
    || $self->ut_textn('state')
    || $self->ut_country('country')
    || $self->ut_anything('comments')
    || $self->ut_numbern('referral_custnum')
  ;
  #barf.  need message catalogs.  i18n.  etc.
  $error .= "Please select an advertising source."
    if $error =~ /^Illegal or empty \(numeric\) refnum: /;
  return $error if $error;

  return "Unknown agent"
    unless qsearchs( 'agent', { 'agentnum' => $self->agentnum } );

  return "Unknown refnum"
    unless qsearchs( 'part_referral', { 'refnum' => $self->refnum } );

  return "Unknown referring custnum ". $self->referral_custnum
    unless ! $self->referral_custnum 
           || qsearchs( 'cust_main', { 'custnum' => $self->referral_custnum } );

  if ( $self->ss eq '' ) {
    $self->ss('');
  } else {
    my $ss = $self->ss;
    $ss =~ s/\D//g;
    $ss =~ /^(\d{3})(\d{2})(\d{4})$/
      or return "Illegal social security number: ". $self->ss;
    $self->ss("$1-$2-$3");
  }


# bad idea to disable, causes billing to fail because of no tax rates later
#  unless ( $import ) {
    unless ( qsearch('cust_main_county', {
      'country' => $self->country,
      'state'   => '',
     } ) ) {
      return "Unknown state/county/country: ".
        $self->state. "/". $self->county. "/". $self->country
        unless qsearch('cust_main_county',{
          'state'   => $self->state,
          'county'  => $self->county,
          'country' => $self->country,
        } );
    }
#  }

  $error =
    $self->ut_phonen('daytime', $self->country)
    || $self->ut_phonen('night', $self->country)
    || $self->ut_phonen('fax', $self->country)
    || $self->ut_zip('zip', $self->country)
  ;
  return $error if $error;

  my @addfields = qw(
    last first company address1 address2 city county state zip
    country daytime night fax
  );

  if ( defined $self->dbdef_table->column('ship_last') ) {
    if ( scalar ( grep { $self->getfield($_) ne $self->getfield("ship_$_") }
                       @addfields )
         && scalar ( grep { $self->getfield("ship_$_") ne '' } @addfields )
       )
    {
      my $error =
        $self->ut_name('ship_last')
        || $self->ut_name('ship_first')
        || $self->ut_textn('ship_company')
        || $self->ut_text('ship_address1')
        || $self->ut_textn('ship_address2')
        || $self->ut_text('ship_city')
        || $self->ut_textn('ship_county')
        || $self->ut_textn('ship_state')
        || $self->ut_country('ship_country')
      ;
      return $error if $error;

      #false laziness with above
      unless ( qsearchs('cust_main_county', {
        'country' => $self->ship_country,
        'state'   => '',
       } ) ) {
        return "Unknown ship_state/ship_county/ship_country: ".
          $self->ship_state. "/". $self->ship_county. "/". $self->ship_country
          unless qsearchs('cust_main_county',{
            'state'   => $self->ship_state,
            'county'  => $self->ship_county,
            'country' => $self->ship_country,
          } );
      }
      #eofalse

      $error =
        $self->ut_phonen('ship_daytime', $self->ship_country)
        || $self->ut_phonen('ship_night', $self->ship_country)
        || $self->ut_phonen('ship_fax', $self->ship_country)
        || $self->ut_zip('ship_zip', $self->ship_country)
      ;
      return $error if $error;

    } else { # ship_ info eq billing info, so don't store dup info in database
      $self->setfield("ship_$_", '')
        foreach qw( last first company address1 address2 city county state zip
                    country daytime night fax );
    }
  }

  $self->payby =~ /^(CARD|DCRD|CHEK|DCHK|LECB|BILL|COMP|PREPAY)$/
    or return "Illegal payby: ". $self->payby;
  $self->payby($1);

  if ( $self->payby eq 'CARD' || $self->payby eq 'DCRD' ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $payinfo =~ /^(\d{13,16})$/
      or return gettext('invalid_card'); # . ": ". $self->payinfo;
    $payinfo = $1;
    $self->payinfo($payinfo);
    validate($payinfo)
      or return gettext('invalid_card'); # . ": ". $self->payinfo;
    return gettext('unknown_card_type')
      if cardtype($self->payinfo) eq "Unknown";
    if ( defined $self->dbdef_table->column('paycvv') ) {
      if ( length($self->paycvv) ) {
        if ( cardtype($self->payinfo) eq 'American Express card' ) {
          $self->paycvv =~ /^(\d{4})$/
            or return "CVV2 (CID) for American Express cards is four digits.";
          $self->paycvv($1);
        } else {
          $self->paycvv =~ /^(\d{3})$/
            or return "CVV2 (CVC2/CID) is three digits.";
          $self->paycvv($1);
        }
      } else {
        $self->paycvv('');
      }
    }

  } elsif ( $self->payby eq 'CHEK' || $self->payby eq 'DCHK' ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/[^\d\@]//g;
    $payinfo =~ /^(\d+)\@(\d{9})$/ or return 'invalid echeck account@aba';
    $payinfo = "$1\@$2";
    $self->payinfo($payinfo);
    $self->paycvv('') if $self->dbdef_table->column('paycvv');

  } elsif ( $self->payby eq 'LECB' ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $payinfo =~ /^1?(\d{10})$/ or return 'invalid btn billing telephone number';
    $payinfo = $1;
    $self->payinfo($payinfo);
    $self->paycvv('') if $self->dbdef_table->column('paycvv');

  } elsif ( $self->payby eq 'BILL' ) {

    $error = $self->ut_textn('payinfo');
    return "Illegal P.O. number: ". $self->payinfo if $error;
    $self->paycvv('') if $self->dbdef_table->column('paycvv');

  } elsif ( $self->payby eq 'COMP' ) {

    if ( !$self->custnum && $conf->config('users-allow_comp') ) {
      return "You are not permitted to create complimentary accounts."
        unless grep { $_ eq getotaker } $conf->config('users-allow_comp');
    }

    $error = $self->ut_textn('payinfo');
    return "Illegal comp account issuer: ". $self->payinfo if $error;
    $self->paycvv('') if $self->dbdef_table->column('paycvv');

  } elsif ( $self->payby eq 'PREPAY' ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\W//g; #anything else would just confuse things
    $self->payinfo($payinfo);
    $error = $self->ut_alpha('payinfo');
    return "Illegal prepayment identifier: ". $self->payinfo if $error;
    return "Unknown prepayment identifier"
      unless qsearchs('prepay_credit', { 'identifier' => $self->payinfo } );
    $self->paycvv('') if $self->dbdef_table->column('paycvv');

  }

  if ( $self->paydate eq '' || $self->paydate eq '-' ) {
    return "Expriation date required"
      unless $self->payby =~ /^(BILL|PREPAY|CHEK|LECB)$/;
    $self->paydate('');
  } else {
    my( $m, $y );
    if ( $self->paydate =~ /^(\d{1,2})[\/\-](\d{2}(\d{2})?)$/ ) {
      ( $m, $y ) = ( $1, length($2) == 4 ? $2 : "20$2" );
    } elsif ( $self->paydate =~ /^(20)?(\d{2})[\/\-](\d{1,2})[\/\-]\d+$/ ) {
      ( $m, $y ) = ( $3, "20$2" );
    } else {
      return "Illegal expiration date: ". $self->paydate;
    }
    $self->paydate("$y-$m-01");
    my($nowm,$nowy)=(localtime(time))[4,5]; $nowm++; $nowy+=1900;
    return gettext('expired_card')
      if !$import && ( $y<$nowy || ( $y==$nowy && $1<$nowm ) );
  }

  if ( $self->payname eq '' && $self->payby !~ /^(CHEK|DCHK)$/ &&
       ( ! $conf->exists('require_cardname')
         || $self->payby !~ /^(CARD|DCRD)$/  ) 
  ) {
    $self->payname( $self->first. " ". $self->getfield('last') );
  } else {
    $self->payname =~ /^([\w \,\.\-\']+)$/
      or return gettext('illegal_name'). " payname: ". $self->payname;
    $self->payname($1);
  }

  $self->tax =~ /^(Y?)$/ or return "Illegal tax: ". $self->tax;
  $self->tax($1);

  $self->otaker(getotaker) unless $self->otaker;

  #warn "AFTER: \n". $self->_dump;

  $self->SUPER::check;
}

=item all_pkgs

Returns all packages (see L<FS::cust_pkg>) for this customer.

=cut

sub all_pkgs {
  my $self = shift;
  if ( $self->{'_pkgnum'} ) {
    values %{ $self->{'_pkgnum'}->cache };
  } else {
    qsearch( 'cust_pkg', { 'custnum' => $self->custnum });
  }
}

=item ncancelled_pkgs

Returns all non-cancelled packages (see L<FS::cust_pkg>) for this customer.

=cut

sub ncancelled_pkgs {
  my $self = shift;
  if ( $self->{'_pkgnum'} ) {
    grep { ! $_->getfield('cancel') } values %{ $self->{'_pkgnum'}->cache };
  } else {
    @{ [ # force list context
      qsearch( 'cust_pkg', {
        'custnum' => $self->custnum,
        'cancel'  => '',
      }),
      qsearch( 'cust_pkg', {
        'custnum' => $self->custnum,
        'cancel'  => 0,
      }),
    ] };
  }
}

=item suspended_pkgs

Returns all suspended packages (see L<FS::cust_pkg>) for this customer.

=cut

sub suspended_pkgs {
  my $self = shift;
  grep { $_->susp } $self->ncancelled_pkgs;
}

=item unflagged_suspended_pkgs

Returns all unflagged suspended packages (see L<FS::cust_pkg>) for this
customer (thouse packages without the `manual_flag' set).

=cut

sub unflagged_suspended_pkgs {
  my $self = shift;
  return $self->suspended_pkgs
    unless dbdef->table('cust_pkg')->column('manual_flag');
  grep { ! $_->manual_flag } $self->suspended_pkgs;
}

=item unsuspended_pkgs

Returns all unsuspended (and uncancelled) packages (see L<FS::cust_pkg>) for
this customer.

=cut

sub unsuspended_pkgs {
  my $self = shift;
  grep { ! $_->susp } $self->ncancelled_pkgs;
}

=item num_cancelled_pkgs

Returns the number of cancelled packages (see L<FS::cust_pkg>) for this
customer.

=cut

sub num_cancelled_pkgs {
  my $self = shift;
  $self->num_pkgs("cancel IS NOT NULL AND cust_pkg.cancel != 0");
}

sub num_pkgs {
  my( $self, $sql ) = @_;
  my $sth = dbh->prepare(
    "SELECT COUNT(*) FROM cust_pkg WHERE custnum = ? AND $sql"
  ) or die dbh->errstr;
  $sth->execute($self->custnum) or die $sth->errstr;
  $sth->fetchrow_arrayref->[0];
}

=item unsuspend

Unsuspends all unflagged suspended packages (see L</unflagged_suspended_pkgs>
and L<FS::cust_pkg>) for this customer.  Always returns a list: an empty list
on success or a list of errors.

=cut

sub unsuspend {
  my $self = shift;
  grep { $_->unsuspend } $self->suspended_pkgs;
}

=item suspend

Suspends all unsuspended packages (see L<FS::cust_pkg>) for this customer.
Always returns a list: an empty list on success or a list of errors.

=cut

sub suspend {
  my $self = shift;
  grep { $_->suspend } $self->unsuspended_pkgs;
}

=item suspend_if_pkgpart PKGPART [ , PKGPART ... ]

Suspends all unsuspended packages (see L<FS::cust_pkg>) matching the listed
PKGPARTs (see L<FS::part_pkg>).  Always returns a list: an empty list on
success or a list of errors.

=cut

sub suspend_if_pkgpart {
  my $self = shift;
  my @pkgparts = @_;
  grep { $_->suspend }
    grep { my $pkgpart = $_->pkgpart; grep { $pkgpart eq $_ } @pkgparts }
      $self->unsuspended_pkgs;
}

=item suspend_unless_pkgpart PKGPART [ , PKGPART ... ]

Suspends all unsuspended packages (see L<FS::cust_pkg>) unless they match the
listed PKGPARTs (see L<FS::part_pkg>).  Always returns a list: an empty list
on success or a list of errors.

=cut

sub suspend_unless_pkgpart {
  my $self = shift;
  my @pkgparts = @_;
  grep { $_->suspend }
    grep { my $pkgpart = $_->pkgpart; ! grep { $pkgpart eq $_ } @pkgparts }
      $self->unsuspended_pkgs;
}

=item cancel [ OPTION => VALUE ... ]

Cancels all uncancelled packages (see L<FS::cust_pkg>) for this customer.

Available options are: I<quiet>

I<quiet> can be set true to supress email cancellation notices.

Always returns a list: an empty list on success or a list of errors.

=cut

sub cancel {
  my $self = shift;
  grep { $_ } map { $_->cancel(@_) } $self->ncancelled_pkgs;
}

=item agent

Returns the agent (see L<FS::agent>) for this customer.

=cut

sub agent {
  my $self = shift;
  qsearchs( 'agent', { 'agentnum' => $self->agentnum } );
}

=item bill OPTIONS

Generates invoices (see L<FS::cust_bill>) for this customer.  Usually used in
conjunction with the collect method.

Options are passed as name-value pairs.

Currently available options are:

resetup - if set true, re-charges setup fees.

time - bills the customer as if it were that time.  Specified as a UNIX
timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and
L<Date::Parse> for conversion functions.  For example:

 use Date::Parse;
 ...
 $cust_main->bill( 'time' => str2time('April 20th, 2001') );


If there is an error, returns the error, otherwise returns false.

=cut

sub bill {
  my( $self, %options ) = @_;
  return '' if $self->payby eq 'COMP';
  warn "bill customer ". $self->custnum if $DEBUG;

  my $time = $options{'time'} || time;

  my $error;

  #put below somehow?
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->select_for_update; #mutex

  # find the packages which are due for billing, find out how much they are
  # & generate invoice database.
 
  my( $total_setup, $total_recur ) = ( 0, 0 );
  #my( $taxable_setup, $taxable_recur ) = ( 0, 0 );
  my @cust_bill_pkg = ();
  #my $tax = 0;##
  #my $taxable_charged = 0;##
  #my $charged = 0;##

  my %tax;

  foreach my $cust_pkg (
    qsearch('cust_pkg', { 'custnum' => $self->custnum } )
  ) {

    #NO!! next if $cust_pkg->cancel;  
    next if $cust_pkg->getfield('cancel');  

    warn "  bill package ". $cust_pkg->pkgnum if $DEBUG;

    #? to avoid use of uninitialized value errors... ?
    $cust_pkg->setfield('bill', '')
      unless defined($cust_pkg->bill);
 
    my $part_pkg = $cust_pkg->part_pkg;

    my %hash = $cust_pkg->hash;
    my $old_cust_pkg = new FS::cust_pkg \%hash;

    my @details = ();

    # bill setup
    my $setup = 0;
    if ( !$cust_pkg->setup || $options{'resetup'} ) {
    
      warn "    bill setup" if $DEBUG;

      $setup = eval { $cust_pkg->calc_setup( $time ) };
      if ( $@ ) {
        $dbh->rollback if $oldAutoCommit;
        return $@;
      }

      $cust_pkg->setfield('setup', $time) unless $cust_pkg->setup;
    }

    #bill recurring fee
    my $recur = 0;
    my $sdate;
    if ( $part_pkg->getfield('freq') ne '0' &&
         ! $cust_pkg->getfield('susp') &&
         ( $cust_pkg->getfield('bill') || 0 ) <= $time
    ) {

      warn "    bill recur" if $DEBUG;

      # XXX shared with $recur_prog
      $sdate = $cust_pkg->bill || $cust_pkg->setup || $time;

      $recur = eval { $cust_pkg->calc_recur( \$sdate, \@details ) };
      if ( $@ ) {
        $dbh->rollback if $oldAutoCommit;
        return $@;
      }

      #change this bit to use Date::Manip? CAREFUL with timezones (see
      # mailing list archive)
      my ($sec,$min,$hour,$mday,$mon,$year) =
        (localtime($sdate) )[0,1,2,3,4,5];

      #pro-rating magic - if $recur_prog fiddles $sdate, want to use that
      # only for figuring next bill date, nothing else, so, reset $sdate again
      # here
      $sdate = $cust_pkg->bill || $cust_pkg->setup || $time;
      $cust_pkg->last_bill($sdate)
        if $cust_pkg->dbdef_table->column('last_bill');

      if ( $part_pkg->freq =~ /^\d+$/ ) {
        $mon += $part_pkg->freq;
        until ( $mon < 12 ) { $mon -= 12; $year++; }
      } elsif ( $part_pkg->freq =~ /^(\d+)w$/ ) {
        my $weeks = $1;
        $mday += $weeks * 7;
      } elsif ( $part_pkg->freq =~ /^(\d+)d$/ ) {
        my $days = $1;
        $mday += $days;
      } else {
        $dbh->rollback if $oldAutoCommit;
        return "unparsable frequency: ". $part_pkg->freq;
      }
      $cust_pkg->setfield('bill',
        timelocal_nocheck($sec,$min,$hour,$mday,$mon,$year));
    }

    warn "\$setup is undefined" unless defined($setup);
    warn "\$recur is undefined" unless defined($recur);
    warn "\$cust_pkg->bill is undefined" unless defined($cust_pkg->bill);

    if ( $cust_pkg->modified ) {

      warn "  package ". $cust_pkg->pkgnum. " modified; updating\n" if $DEBUG;

      $error=$cust_pkg->replace($old_cust_pkg);
      if ( $error ) { #just in case
        $dbh->rollback if $oldAutoCommit;
        return "Error modifying pkgnum ". $cust_pkg->pkgnum. ": $error";
      }

      $setup = sprintf( "%.2f", $setup );
      $recur = sprintf( "%.2f", $recur );
      if ( $setup < 0 && ! $conf->exists('allow_negative_charges') ) {
        $dbh->rollback if $oldAutoCommit;
        return "negative setup $setup for pkgnum ". $cust_pkg->pkgnum;
      }
      if ( $recur < 0 && ! $conf->exists('allow_negative_charges') ) {
        $dbh->rollback if $oldAutoCommit;
        return "negative recur $recur for pkgnum ". $cust_pkg->pkgnum;
      }
      if ( $setup != 0 || $recur != 0 ) {
        warn "    charges (setup=$setup, recur=$recur); queueing line items\n"
          if $DEBUG;
        my $cust_bill_pkg = new FS::cust_bill_pkg ({
          'pkgnum'  => $cust_pkg->pkgnum,
          'setup'   => $setup,
          'recur'   => $recur,
          'sdate'   => $sdate,
          'edate'   => $cust_pkg->bill,
          'details' => \@details,
        });
        push @cust_bill_pkg, $cust_bill_pkg;
        $total_setup += $setup;
        $total_recur += $recur;

        unless ( $self->tax =~ /Y/i || $self->payby eq 'COMP' ) {

          my @taxes = qsearch( 'cust_main_county', {
                                 'state'    => $self->state,
                                 'county'   => $self->county,
                                 'country'  => $self->country,
                                 'taxclass' => $part_pkg->taxclass,
                                                                      } );
          unless ( @taxes ) {
            @taxes =  qsearch( 'cust_main_county', {
                                  'state'    => $self->state,
                                  'county'   => $self->county,
                                  'country'  => $self->country,
                                  'taxclass' => '',
                                                                      } );
          }

          #one more try at a whole-country tax rate
          unless ( @taxes ) {
            @taxes =  qsearch( 'cust_main_county', {
                                  'state'    => '',
                                  'county'   => '',
                                  'country'  => $self->country,
                                  'taxclass' => '',
                                                                      } );
          }

          # maybe eliminate this entirely, along with all the 0% records
          unless ( @taxes ) {
            $dbh->rollback if $oldAutoCommit;
            return
              "fatal: can't find tax rate for state/county/country/taxclass ".
              join('/', ( map $self->$_(), qw(state county country) ),
                        $part_pkg->taxclass ).  "\n";
          }
  
          foreach my $tax ( @taxes ) {

            my $taxable_charged = 0;
            $taxable_charged += $setup
              unless $part_pkg->setuptax =~ /^Y$/i
                  || $tax->setuptax =~ /^Y$/i;
            $taxable_charged += $recur
              unless $part_pkg->recurtax =~ /^Y$/i
                  || $tax->recurtax =~ /^Y$/i;
            next unless $taxable_charged;

            if ( $tax->exempt_amount > 0 ) {
              my ($mon,$year) = (localtime($sdate) )[4,5];
              $mon++;
              my $freq = $part_pkg->freq || 1;
              if ( $freq !~ /(\d+)$/ ) {
                $dbh->rollback if $oldAutoCommit;
                return "daily/weekly package definitions not (yet?)".
                       " compatible with monthly tax exemptions";
              }
              my $taxable_per_month = sprintf("%.2f", $taxable_charged / $freq );
              foreach my $which_month ( 1 .. $freq ) {
                my %hash = (
                  'custnum' => $self->custnum,
                  'taxnum'  => $tax->taxnum,
                  'year'    => 1900+$year,
                  'month'   => $mon++,
                );
                #until ( $mon < 12 ) { $mon -= 12; $year++; }
                until ( $mon < 13 ) { $mon -= 12; $year++; }
                my $cust_tax_exempt =
                  qsearchs('cust_tax_exempt', \%hash)
                  || new FS::cust_tax_exempt( { %hash, 'amount' => 0 } );
                my $remaining_exemption = sprintf("%.2f",
                  $tax->exempt_amount - $cust_tax_exempt->amount );
                if ( $remaining_exemption > 0 ) {
                  my $addl = $remaining_exemption > $taxable_per_month
                    ? $taxable_per_month
                    : $remaining_exemption;
                  $taxable_charged -= $addl;
                  my $new_cust_tax_exempt = new FS::cust_tax_exempt ( {
                    $cust_tax_exempt->hash,
                    'amount' =>
                      sprintf("%.2f", $cust_tax_exempt->amount + $addl),
                  } );
                  $error = $new_cust_tax_exempt->exemptnum
                    ? $new_cust_tax_exempt->replace($cust_tax_exempt)
                    : $new_cust_tax_exempt->insert;
                  if ( $error ) {
                    $dbh->rollback if $oldAutoCommit;
                    return "fatal: can't update cust_tax_exempt: $error";
                  }
  
                } # if $remaining_exemption > 0
  
              } #foreach $which_month
  
            } #if $tax->exempt_amount

            $taxable_charged = sprintf( "%.2f", $taxable_charged);

            #$tax += $taxable_charged * $cust_main_county->tax / 100
            $tax{ $tax->taxname || 'Tax' } +=
              $taxable_charged * $tax->tax / 100

          } #foreach my $tax ( @taxes )

        } #unless $self->tax =~ /Y/i || $self->payby eq 'COMP'

      } #if $setup != 0 || $recur != 0
      
    } #if $cust_pkg->modified

  } #foreach my $cust_pkg

  my $charged = sprintf( "%.2f", $total_setup + $total_recur );
#  my $taxable_charged = sprintf( "%.2f", $taxable_setup + $taxable_recur );

  unless ( @cust_bill_pkg ) { #don't create invoices with no line items
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return '';
  } 

#  unless ( $self->tax =~ /Y/i
#           || $self->payby eq 'COMP'
#           || $taxable_charged == 0 ) {
#    my $cust_main_county = qsearchs('cust_main_county',{
#        'state'   => $self->state,
#        'county'  => $self->county,
#        'country' => $self->country,
#    } ) or die "fatal: can't find tax rate for state/county/country ".
#               $self->state. "/". $self->county. "/". $self->country. "\n";
#    my $tax = sprintf( "%.2f",
#      $taxable_charged * ( $cust_main_county->getfield('tax') / 100 )
#    );

  if ( dbdef->table('cust_bill_pkg')->column('itemdesc') ) { #1.5 schema

    foreach my $taxname ( grep { $tax{$_} > 0 } keys %tax ) {
      my $tax = sprintf("%.2f", $tax{$taxname} );
      $charged = sprintf( "%.2f", $charged+$tax );
  
      my $cust_bill_pkg = new FS::cust_bill_pkg ({
        'pkgnum'   => 0,
        'setup'    => $tax,
        'recur'    => 0,
        'sdate'    => '',
        'edate'    => '',
        'itemdesc' => $taxname,
      });
      push @cust_bill_pkg, $cust_bill_pkg;
    }
  
  } else { #1.4 schema

    my $tax = 0;
    foreach ( values %tax ) { $tax += $_ };
    $tax = sprintf("%.2f", $tax);
    if ( $tax > 0 ) {
      $charged = sprintf( "%.2f", $charged+$tax );

      my $cust_bill_pkg = new FS::cust_bill_pkg ({
        'pkgnum' => 0,
        'setup'  => $tax,
        'recur'  => 0,
        'sdate'  => '',
        'edate'  => '',
      });
      push @cust_bill_pkg, $cust_bill_pkg;
    }

  }

  my $cust_bill = new FS::cust_bill ( {
    'custnum' => $self->custnum,
    '_date'   => $time,
    'charged' => $charged,
  } );
  $error = $cust_bill->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "can't create invoice for customer #". $self->custnum. ": $error";
  }

  my $invnum = $cust_bill->invnum;
  my $cust_bill_pkg;
  foreach $cust_bill_pkg ( @cust_bill_pkg ) {
    #warn $invnum;
    $cust_bill_pkg->invnum($invnum);
    $error = $cust_bill_pkg->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't create invoice line item for customer #". $self->custnum.
             ": $error";
    }
  }
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}

=item collect OPTIONS

(Attempt to) collect money for this customer's outstanding invoices (see
L<FS::cust_bill>).  Usually used after the bill method.

Depending on the value of `payby', this may print or email an invoice (I<BILL>,
I<DCRD>, or I<DCHK>), charge a credit card (I<CARD>), charge via electronic
check/ACH (I<CHEK>), or just add any necessary (pseudo-)payment (I<COMP>).

Most actions are now triggered by invoice events; see L<FS::part_bill_event>
and the invoice events web interface.

If there is an error, returns the error, otherwise returns false.

Options are passed as name-value pairs.

Currently available options are:

invoice_time - Use this time when deciding when to print invoices and
late notices on those invoices.  The default is now.  It is specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse>
for conversion functions.

retry - Retry card/echeck/LEC transactions even when not scheduled by invoice
events.

retry_card - Deprecated alias for 'retry'

batch_card - This option is deprecated.  See the invoice events web interface
to control whether cards are batched or run against a realtime gateway.

report_badcard - This option is deprecated.

force_print - This option is deprecated; see the invoice events web interface.

quiet - set true to surpress email card/ACH decline notices.

=cut

sub collect {
  my( $self, %options ) = @_;
  my $invoice_time = $options{'invoice_time'} || time;

  #put below somehow?
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->select_for_update; #mutex

  my $balance = $self->balance;
  warn "collect customer ". $self->custnum. ": balance $balance" if $DEBUG;
  unless ( $balance > 0 ) { #redundant?????
    $dbh->rollback if $oldAutoCommit; #hmm
    return '';
  }

  if ( exists($options{'retry_card'}) ) {
    carp 'retry_card option passed to collect is deprecated; use retry';
    $options{'retry'} ||= $options{'retry_card'};
  }
  if ( exists($options{'retry'}) && $options{'retry'} ) {
    my $error = $self->retry_realtime;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $cust_bill ( $self->open_cust_bill ) {

    # don't try to charge for the same invoice if it's already in a batch
    #next if qsearchs( 'cust_pay_batch', { 'invnum' => $cust_bill->invnum } );

    last if $self->balance <= 0;

    warn "invnum ". $cust_bill->invnum. " (owed ". $cust_bill->owed. ")"
      if $DEBUG;

    foreach my $part_bill_event (
      sort {    $a->seconds   <=> $b->seconds
             || $a->weight    <=> $b->weight
             || $a->eventpart <=> $b->eventpart }
        grep { $_->seconds <= ( $invoice_time - $cust_bill->_date )
               && ! qsearch( 'cust_bill_event', {
                                'invnum'    => $cust_bill->invnum,
                                'eventpart' => $_->eventpart,
                                'status'    => 'done',
                                                                   } )
             }
          qsearch('part_bill_event', { 'payby'    => $self->payby,
                                       'disabled' => '',           } )
    ) {

      last if $cust_bill->owed <= 0  # don't run subsequent events if owed<=0
           || $self->balance   <= 0; # or if balance<=0

      warn "calling invoice event (". $part_bill_event->eventcode. ")\n"
        if $DEBUG;
      my $cust_main = $self; #for callback

      my $error;
      {
        local $realtime_bop_decline_quiet = 1 if $options{'quiet'};
        local $SIG{__DIE__}; # don't want Mason __DIE__ handler active
        $error = eval $part_bill_event->eventcode;
      }

      my $status = '';
      my $statustext = '';
      if ( $@ ) {
        $status = 'failed';
        $statustext = $@;
      } elsif ( $error ) {
        $status = 'done';
        $statustext = $error;
      } else {
        $status = 'done'
      }

      #add cust_bill_event
      my $cust_bill_event = new FS::cust_bill_event {
        'invnum'     => $cust_bill->invnum,
        'eventpart'  => $part_bill_event->eventpart,
        #'_date'      => $invoice_time,
        '_date'      => time,
        'status'     => $status,
        'statustext' => $statustext,
      };
      $error = $cust_bill_event->insert;
      if ( $error ) {
        #$dbh->rollback if $oldAutoCommit;
        #return "error: $error";

        # gah, even with transactions.
        $dbh->commit if $oldAutoCommit; #well.
        my $e = 'WARNING: Event run but database not updated - '.
                'error inserting cust_bill_event, invnum #'. $cust_bill->invnum.
                ', eventpart '. $part_bill_event->eventpart.
                ": $error";
        warn $e;
        return $e;
      }


    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item retry_realtime

Schedules realtime credit card / electronic check / LEC billing events for
for retry.  Useful if card information has changed or manual retry is desired.
The 'collect' method must be called to actually retry the transaction.

Implementation details: For each of this customer's open invoices, changes
the status of the first "done" (with statustext error) realtime processing
event to "failed".

=cut

sub retry_realtime {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $cust_bill (
    grep { $_->cust_bill_event }
      $self->open_cust_bill
  ) {
    my @cust_bill_event =
      sort { $a->part_bill_event->seconds <=> $b->part_bill_event->seconds }
        grep {
               #$_->part_bill_event->plan eq 'realtime-card'
               $_->part_bill_event->eventcode =~
                   /\$cust_bill\->realtime_(card|ach|lec)/
                 && $_->status eq 'done'
                 && $_->statustext
             }
          $cust_bill->cust_bill_event;
    next unless @cust_bill_event;
    my $error = $cust_bill_event[0]->retry;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error scheduling invoice event for retry: $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item realtime_bop METHOD AMOUNT [ OPTION => VALUE ... ]

Runs a realtime credit card, ACH (electronic check) or phone bill transaction
via a Business::OnlinePayment realtime gateway.  See
L<http://420.am/business-onlinepayment> for supported gateways.

Available methods are: I<CC>, I<ECHECK> and I<LEC>

Available options are: I<description>, I<invnum>, I<quiet>

The additional options I<payname>, I<address1>, I<address2>, I<city>, I<state>,
I<zip>, I<payinfo> and I<paydate> are also available.  Any of these options,
if set, will override the value from the customer record.

I<description> is a free-text field passed to the gateway.  It defaults to
"Internet services".

If an I<invnum> is specified, this payment (if sucessful) is applied to the
specified invoice.  If you don't specify an I<invnum> you might want to
call the B<apply_payments> method.

I<quiet> can be set true to surpress email decline notices.

(moved from cust_bill) (probably should get realtime_{card,ach,lec} here too)

=cut

sub realtime_bop {
  my( $self, $method, $amount, %options ) = @_;
  if ( $DEBUG ) {
    warn "$self $method $amount\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  $options{'description'} ||= 'Internet services';

  #pre-requisites
  die "Real-time processing not enabled\n"
    unless $conf->exists('business-onlinepayment');
  eval "use Business::OnlinePayment";  
  die $@ if $@;

  #load up config
  my $bop_config = 'business-onlinepayment';
  $bop_config .= '-ach'
    if $method eq 'ECHECK' && $conf->exists($bop_config. '-ach');
  my ( $processor, $login, $password, $action, @bop_options ) =
    $conf->config($bop_config);
  $action ||= 'normal authorization';
  pop @bop_options if scalar(@bop_options) % 2 && $bop_options[-1] =~ /^\s*$/;
  die "No real-time processor is enabled - ".
      "did you set the business-onlinepayment configuration value?\n"
    unless $processor;

  #massage data

  my $address = exists($options{'address1'})
                    ? $options{'address1'}
                    : $self->address1;
  my $address2 = exists($options{'address2'})
                    ? $options{'address2'}
                    : $self->address2;
  $address .= ", ". $address2 if length($address2);

  my $o_payname = exists($options{'payname'})
                    ? $options{'payname'}
                    : $self->payname;
  my($payname, $payfirst, $paylast);
  if ( $o_payname && $method ne 'ECHECK' ) {
    ($payname = $o_payname) =~ /^\s*([\w \,\.\-\']*)?\s+([\w\,\.\-\']+)\s*$/
      or return "Illegal payname $payname";
    ($payfirst, $paylast) = ($1, $2);
  } else {
    $payfirst = $self->getfield('first');
    $paylast = $self->getfield('last');
    $payname =  "$payfirst $paylast";
  }

  my @invoicing_list = grep { $_ ne 'POST' } $self->invoicing_list;
  if ( $conf->exists('emailinvoiceauto')
       || ( $conf->exists('emailinvoiceonly') && ! @invoicing_list ) ) {
    push @invoicing_list, $self->all_emails;
  }
  my $email = $invoicing_list[0];

  my $payinfo = exists($options{'payinfo'})
                  ? $options{'payinfo'}
                  : $self->payinfo;

  my %content = ();
  if ( $method eq 'CC' ) { 

    $content{card_number} = $payinfo;
    my $paydate = exists($options{'paydate'})
                    ? $options{'paydate'}
                    : $self->paydate;
    $paydate =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
    $content{expiration} = "$2/$1";

    if ( defined $self->dbdef_table->column('paycvv') ) {
      my $paycvv = exists($options{'paycvv'})
                     ? $options{'paycvv'}
                     : $self->paycvv;
      $content{cvv2} = $self->paycvv
        if length($paycvv);
    }

    $content{recurring_billing} = 'YES'
      if qsearch('cust_pay', { 'custnum' => $self->custnum,
                               'payby'   => 'CARD',
                               'payinfo' => $payinfo,
                             } );

  } elsif ( $method eq 'ECHECK' ) {
    ( $content{account_number}, $content{routing_code} ) =
      split('@', $payinfo);
    $content{bank_name} = $o_payname;
    $content{account_type} = 'CHECKING';
    $content{account_name} = $payname;
    $content{customer_org} = $self->company ? 'B' : 'I';
    $content{customer_ssn} = exists($options{'ss'})
                               ? $options{'ss'}
                               : $self->ss;
  } elsif ( $method eq 'LEC' ) {
    $content{phone} = $payinfo;
  }

  #transaction(s)

  my( $action1, $action2 ) = split(/\s*\,\s*/, $action );

  my $transaction = new Business::OnlinePayment( $processor, @bop_options );
  $transaction->content(
    'type'           => $method,
    'login'          => $login,
    'password'       => $password,
    'action'         => $action1,
    'description'    => $options{'description'},
    'amount'         => $amount,
    'invoice_number' => $options{'invnum'},
    'customer_id'    => $self->custnum,
    'last_name'      => $paylast,
    'first_name'     => $payfirst,
    'name'           => $payname,
    'address'        => $address,
    'city'           => ( exists($options{'city'})
                            ? $options{'city'}
                            : $self->city          ),
    'state'          => ( exists($options{'state'})
                            ? $options{'state'}
                            : $self->state          ),
    'zip'            => ( exists($options{'zip'})
                            ? $options{'zip'}
                            : $self->zip          ),
    'country'        => ( exists($options{'country'})
                            ? $options{'country'}
                            : $self->country          ),
    'referer'        => 'http://cleanwhisker.420.am/',
    'email'          => $email,
    'phone'          => $self->daytime || $self->night,
    %content, #after
  );
  $transaction->submit();

  if ( $transaction->is_success() && $action2 ) {
    my $auth = $transaction->authorization;
    my $ordernum = $transaction->can('order_number')
                   ? $transaction->order_number
                   : '';

    my $capture =
      new Business::OnlinePayment( $processor, @bop_options );

    my %capture = (
      %content,
      type           => $method,
      action         => $action2,
      login          => $login,
      password       => $password,
      order_number   => $ordernum,
      amount         => $amount,
      authorization  => $auth,
      description    => $options{'description'},
    );

    foreach my $field (qw( authorization_source_code returned_ACI                                          transaction_identifier validation_code           
                           transaction_sequence_num local_transaction_date    
                           local_transaction_time AVS_result_code          )) {
      $capture{$field} = $transaction->$field() if $transaction->can($field);
    }

    $capture->content( %capture );

    $capture->submit();

    unless ( $capture->is_success ) {
      my $e = "Authorization sucessful but capture failed, custnum #".
              $self->custnum. ': '.  $capture->result_code.
              ": ". $capture->error_message;
      warn $e;
      return $e;
    }

  }

  #remove paycvv after initial transaction
  #false laziness w/misc/process/payment.cgi - check both to make sure working
  # correctly
  if ( defined $self->dbdef_table->column('paycvv')
       && length($self->paycvv)
       && ! grep { $_ eq cardtype($payinfo) } $conf->config('cvv-save')
  ) {
    my $error = $self->remove_cvv;
    if ( $error ) {
      warn "error removing cvv: $error\n";
    }
  }

  #result handling
  if ( $transaction->is_success() ) {

    my %method2payby = (
      'CC'     => 'CARD',
      'ECHECK' => 'CHEK',
      'LEC'    => 'LECB',
    );

    my $paybatch = "$processor:". $transaction->authorization;
    $paybatch .= ':'. $transaction->order_number
      if $transaction->can('order_number')
      && length($transaction->order_number);

    my $cust_pay = new FS::cust_pay ( {
       'custnum'  => $self->custnum,
       'invnum'   => $options{'invnum'},
       'paid'     => $amount,
       '_date'     => '',
       'payby'    => $method2payby{$method},
       'payinfo'  => $payinfo,
       'paybatch' => $paybatch,
    } );
    my $error = $cust_pay->insert;
    if ( $error ) {
      $cust_pay->invnum(''); #try again with no specific invnum
      my $error2 = $cust_pay->insert;
      if ( $error2 ) {
        # gah, even with transactions.
        my $e = 'WARNING: Card/ACH debited but database not updated - '.
                "error inserting payment ($processor): $error2".
                " (previously tried insert with invnum #$options{'invnum'}" .
                ": $error )";
        warn $e;
        return $e;
      }
    }
    return ''; #no error

  } else {

    my $perror = "$processor error: ". $transaction->error_message;

    if ( !$options{'quiet'} && !$realtime_bop_decline_quiet
         && $conf->exists('emaildecline')
         && grep { $_ ne 'POST' } $self->invoicing_list
         && ! grep { $transaction->error_message =~ /$_/ }
                   $conf->config('emaildecline-exclude')
    ) {
      my @templ = $conf->config('declinetemplate');
      my $template = new Text::Template (
        TYPE   => 'ARRAY',
        SOURCE => [ map "$_\n", @templ ],
      ) or return "($perror) can't create template: $Text::Template::ERROR";
      $template->compile()
        or return "($perror) can't compile template: $Text::Template::ERROR";

      my $templ_hash = { error => $transaction->error_message };

      my $error = send_email(
        'from'    => $conf->config('invoice_from'),
        'to'      => [ grep { $_ ne 'POST' } $self->invoicing_list ],
        'subject' => 'Your payment could not be processed',
        'body'    => [ $template->fill_in(HASH => $templ_hash) ],
      );

      $perror .= " (also received error sending decline notification: $error)"
        if $error;

    }
  
    return $perror;
  }

}

=item remove_cvv

Removes the I<paycvv> field from the database directly.

If there is an error, returns the error, otherwise returns false.

=cut

sub remove_cvv {
  my $self = shift;
  my $sth = dbh->prepare("UPDATE cust_main SET paycvv = '' WHERE custnum = ?")
    or return dbh->errstr;
  $sth->execute($self->custnum)
    or return $sth->errstr;
  $self->paycvv('');
  '';
}

=item realtime_refund_bop METHOD [ OPTION => VALUE ... ]

Refunds a realtime credit card, ACH (electronic check) or phone bill transaction
via a Business::OnlinePayment realtime gateway.  See
L<http://420.am/business-onlinepayment> for supported gateways.

Available methods are: I<CC>, I<ECHECK> and I<LEC>

Available options are: I<amount>, I<reason>, I<paynum>

Most gateways require a reference to an original payment transaction to refund,
so you probably need to specify a I<paynum>.

I<amount> defaults to the original amount of the payment if not specified.

I<reason> specifies a reason for the refund.

Implementation note: If I<amount> is unspecified or equal to the amount of the
orignal payment, first an attempt is made to "void" the transaction via
the gateway (to cancel a not-yet settled transaction) and then if that fails,
the normal attempt is made to "refund" ("credit") the transaction via the
gateway is attempted.

#The additional options I<payname>, I<address1>, I<address2>, I<city>, I<state>,
#I<zip>, I<payinfo> and I<paydate> are also available.  Any of these options,
#if set, will override the value from the customer record.

#If an I<invnum> is specified, this payment (if sucessful) is applied to the
#specified invoice.  If you don't specify an I<invnum> you might want to
#call the B<apply_payments> method.

=cut

#some false laziness w/realtime_bop, not enough to make it worth merging
#but some useful small subs should be pulled out
sub realtime_refund_bop {
  my( $self, $method, %options ) = @_;
  if ( $DEBUG ) {
    warn "$self $method refund\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  #pre-requisites
  die "Real-time processing not enabled\n"
    unless $conf->exists('business-onlinepayment');
  eval "use Business::OnlinePayment";  
  die $@ if $@;

  #load up config
  my $bop_config = 'business-onlinepayment';
  $bop_config .= '-ach'
    if $method eq 'ECHECK' && $conf->exists($bop_config. '-ach');
  my ( $processor, $login, $password, $unused_action, @bop_options ) =
    $conf->config($bop_config);
  #$action ||= 'normal authorization';
  pop @bop_options if scalar(@bop_options) % 2 && $bop_options[-1] =~ /^\s*$/;
  die "No real-time processor is enabled - ".
      "did you set the business-onlinepayment configuration value?\n"
    unless $processor;

  my $cust_pay = '';
  my $amount = $options{'amount'};
  my( $pay_processor, $auth, $order_number ) = ( '', '', '' );
  if ( $options{'paynum'} ) {
    warn "FS::cust_main::realtime_bop: paynum: $options{paynum}\n" if $DEBUG;
    $cust_pay = qsearchs('cust_pay', { paynum=>$options{'paynum'} } )
      or return "Unknown paynum $options{'paynum'}";
    $amount ||= $cust_pay->paid;
    $cust_pay->paybatch =~ /^(\w+):(\w*)(:(\w+))?$/
      or return "Can't parse paybatch for paynum $options{'paynum'}: ".
                $cust_pay->paybatch;
    ( $pay_processor, $auth, $order_number ) = ( $1, $2, $4 );
    return "processor of payment $options{'paynum'} $pay_processor does not".
           " match current processor $processor"
      unless $pay_processor eq $processor;
  }
  return "neither amount nor paynum specified" unless $amount;

  my %content = (
    'type'           => $method,
    'login'          => $login,
    'password'       => $password,
    'order_number'   => $order_number,
    'amount'         => $amount,
    'referer'        => 'http://cleanwhisker.420.am/',
  );
  $content{authorization} = $auth
    if length($auth); #echeck/ACH transactions have an order # but no auth
                      #(at least with authorize.net)

  #first try void if applicable
  if ( $cust_pay && $cust_pay->paid == $amount ) { #and check dates?
    my $void = new Business::OnlinePayment( $processor, @bop_options );
    $void->content( 'action' => 'void', %content );
    $void->submit();
    if ( $void->is_success ) {
      my $error = $cust_pay->void($options{'reason'});
      if ( $error ) {
        # gah, even with transactions.
        my $e = 'WARNING: Card/ACH voided but database not updated - '.
                "error voiding payment: $error";
        warn $e;
        return $e;
      }
      return '';
    }
  }

  #massage data
  my $address = $self->address1;
  $address .= ", ". $self->address2 if $self->address2;

  my($payname, $payfirst, $paylast);
  if ( $self->payname && $method ne 'ECHECK' ) {
    $payname = $self->payname;
    $payname =~ /^\s*([\w \,\.\-\']*)?\s+([\w\,\.\-\']+)\s*$/
      or return "Illegal payname $payname";
    ($payfirst, $paylast) = ($1, $2);
  } else {
    $payfirst = $self->getfield('first');
    $paylast = $self->getfield('last');
    $payname =  "$payfirst $paylast";
  }

  if ( $method eq 'CC' ) { 

    $content{card_number} = $self->payinfo;
    $self->paydate =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
    $content{expiration} = "$2/$1";

    #$content{cvv2} = $self->paycvv
    #  if defined $self->dbdef_table->column('paycvv')
    #     && length($self->paycvv);

    #$content{recurring_billing} = 'YES'
    #  if qsearch('cust_pay', { 'custnum' => $self->custnum,
    #                           'payby'   => 'CARD',
    #                           'payinfo' => $self->payinfo, } );

  } elsif ( $method eq 'ECHECK' ) {
    ( $content{account_number}, $content{routing_code} ) =
      split('@', $self->payinfo);
    $content{bank_name} = $self->payname;
    $content{account_type} = 'CHECKING';
    $content{account_name} = $payname;
    $content{customer_org} = $self->company ? 'B' : 'I';
    $content{customer_ssn} = $self->ss;
  } elsif ( $method eq 'LEC' ) {
    $content{phone} = $self->payinfo;
  }

  #then try refund
  my $refund = new Business::OnlinePayment( $processor, @bop_options );
  $refund->content(
    'action'         => 'credit',
    'customer_id'    => $self->custnum,
    'last_name'      => $paylast,
    'first_name'     => $payfirst,
    'name'           => $payname,
    'address'        => $address,
    'city'           => $self->city,
    'state'          => $self->state,
    'zip'            => $self->zip,
    'country'        => $self->country,
    %content, #after
  );
  $refund->submit();

  return "$processor error: ". $refund->error_message
    unless $refund->is_success();

  my %method2payby = (
    'CC'     => 'CARD',
    'ECHECK' => 'CHEK',
    'LEC'    => 'LECB',
  );

  my $paybatch = "$processor:". $refund->authorization;
  $paybatch .= ':'. $refund->order_number
    if $refund->can('order_number') && $refund->order_number;

  while ( $cust_pay && $cust_pay->unappled < $amount ) {
    my @cust_bill_pay = $cust_pay->cust_bill_pay;
    last unless @cust_bill_pay;
    my $cust_bill_pay = pop @cust_bill_pay;
    my $error = $cust_bill_pay->delete;
    last if $error;
  }

  my $cust_refund = new FS::cust_refund ( {
    'custnum'  => $self->custnum,
    'paynum'   => $options{'paynum'},
    'refund'   => $amount,
    '_date'    => '',
    'payby'    => $method2payby{$method},
    'payinfo'  => $self->payinfo,
    'paybatch' => $paybatch,
    'reason'   => $options{'reason'} || 'card or ACH refund',
  } );
  my $error = $cust_refund->insert;
  if ( $error ) {
    $cust_refund->paynum(''); #try again with no specific paynum
    my $error2 = $cust_refund->insert;
    if ( $error2 ) {
      # gah, even with transactions.
      my $e = 'WARNING: Card/ACH refunded but database not updated - '.
              "error inserting refund ($processor): $error2".
              " (previously tried insert with paynum #$options{'paynum'}" .
              ": $error )";
      warn $e;
      return $e;
    }
  }

  ''; #no error

}

=item total_owed

Returns the total owed for this customer on all invoices
(see L<FS::cust_bill/owed>).

=cut

sub total_owed {
  my $self = shift;
  $self->total_owed_date(2145859200); #12/31/2037
}

=item total_owed_date TIME

Returns the total owed for this customer on all invoices with date earlier than
TIME.  TIME is specified as a UNIX timestamp; see L<perlfunc/"time">).  Also
see L<Time::Local> and L<Date::Parse> for conversion functions.

=cut

sub total_owed_date {
  my $self = shift;
  my $time = shift;
  my $total_bill = 0;
  foreach my $cust_bill (
    grep { $_->_date <= $time }
      qsearch('cust_bill', { 'custnum' => $self->custnum, } )
  ) {
    $total_bill += $cust_bill->owed;
  }
  sprintf( "%.2f", $total_bill );
}

=item apply_credits OPTION => VALUE ...

Applies (see L<FS::cust_credit_bill>) unapplied credits (see L<FS::cust_credit>)
to outstanding invoice balances in chronological order (or reverse
chronological order if the I<order> option is set to B<newest>) and returns the
value of any remaining unapplied credits available for refund (see
L<FS::cust_refund>).

=cut

sub apply_credits {
  my $self = shift;
  my %opt = @_;

  return 0 unless $self->total_credited;

  my @credits = sort { $b->_date <=> $a->_date} (grep { $_->credited > 0 }
      qsearch('cust_credit', { 'custnum' => $self->custnum } ) );

  my @invoices = $self->open_cust_bill;
  @invoices = sort { $b->_date <=> $a->_date } @invoices
    if defined($opt{'order'}) && $opt{'order'} eq 'newest';

  my $credit;
  foreach my $cust_bill ( @invoices ) {
    my $amount;

    if ( !defined($credit) || $credit->credited == 0) {
      $credit = pop @credits or last;
    }

    if ($cust_bill->owed >= $credit->credited) {
      $amount=$credit->credited;
    }else{
      $amount=$cust_bill->owed;
    }
    
    my $cust_credit_bill = new FS::cust_credit_bill ( {
      'crednum' => $credit->crednum,
      'invnum'  => $cust_bill->invnum,
      'amount'  => $amount,
    } );
    my $error = $cust_credit_bill->insert;
    die $error if $error;
    
    redo if ($cust_bill->owed > 0);

  }

  return $self->total_credited;
}

=item apply_payments

Applies (see L<FS::cust_bill_pay>) unapplied payments (see L<FS::cust_pay>)
to outstanding invoice balances in chronological order.

 #and returns the value of any remaining unapplied payments.

=cut

sub apply_payments {
  my $self = shift;

  #return 0 unless

  my @payments = sort { $b->_date <=> $a->_date } ( grep { $_->unapplied > 0 }
      qsearch('cust_pay', { 'custnum' => $self->custnum } ) );

  my @invoices = sort { $a->_date <=> $b->_date} (grep { $_->owed > 0 }
      qsearch('cust_bill', { 'custnum' => $self->custnum } ) );

  my $payment;

  foreach my $cust_bill ( @invoices ) {
    my $amount;

    if ( !defined($payment) || $payment->unapplied == 0 ) {
      $payment = pop @payments or last;
    }

    if ( $cust_bill->owed >= $payment->unapplied ) {
      $amount = $payment->unapplied;
    } else {
      $amount = $cust_bill->owed;
    }

    my $cust_bill_pay = new FS::cust_bill_pay ( {
      'paynum' => $payment->paynum,
      'invnum' => $cust_bill->invnum,
      'amount' => $amount,
    } );
    my $error = $cust_bill_pay->insert;
    die $error if $error;

    redo if ( $cust_bill->owed > 0);

  }

  return $self->total_unapplied_payments;
}

=item total_credited

Returns the total outstanding credit (see L<FS::cust_credit>) for this
customer.  See L<FS::cust_credit/credited>.

=cut

sub total_credited {
  my $self = shift;
  my $total_credit = 0;
  foreach my $cust_credit ( qsearch('cust_credit', {
    'custnum' => $self->custnum,
  } ) ) {
    $total_credit += $cust_credit->credited;
  }
  sprintf( "%.2f", $total_credit );
}

=item total_unapplied_payments

Returns the total unapplied payments (see L<FS::cust_pay>) for this customer.
See L<FS::cust_pay/unapplied>.

=cut

sub total_unapplied_payments {
  my $self = shift;
  my $total_unapplied = 0;
  foreach my $cust_pay ( qsearch('cust_pay', {
    'custnum' => $self->custnum,
  } ) ) {
    $total_unapplied += $cust_pay->unapplied;
  }
  sprintf( "%.2f", $total_unapplied );
}

=item balance

Returns the balance for this customer (total_owed minus total_credited
minus total_unapplied_payments).

=cut

sub balance {
  my $self = shift;
  sprintf( "%.2f",
    $self->total_owed - $self->total_credited - $self->total_unapplied_payments
  );
}

=item balance_date TIME

Returns the balance for this customer, only considering invoices with date
earlier than TIME (total_owed_date minus total_credited minus
total_unapplied_payments).  TIME is specified as a UNIX timestamp; see
L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion
functions.

=cut

sub balance_date {
  my $self = shift;
  my $time = shift;
  sprintf( "%.2f",
    $self->total_owed_date($time)
      - $self->total_credited
      - $self->total_unapplied_payments
  );
}

=item paydate_monthyear

Returns a two-element list consisting of the month and year of this customer's
paydate (credit card expiration date for CARD customers)

=cut

sub paydate_monthyear {
  my $self = shift;
  if ( $self->paydate  =~ /^(\d{4})-(\d{1,2})-\d{1,2}$/ ) { #Pg date format
    ( $2, $1 );
  } elsif ( $self->paydate =~ /^(\d{1,2})-(\d{1,2}-)?(\d{4}$)/ ) {
    ( $1, $3 );
  } else {
    ('', '');
  }
}

=item payinfo_masked

Returns a "masked" payinfo field with all but the last four characters replaced
by 'x'es.  Useful for displaying credit cards.

=cut

sub payinfo_masked {
  my $self = shift;
  my $payinfo = $self->payinfo;
  'x'x(length($payinfo)-4). substr($payinfo,(length($payinfo)-4));
}

=item invoicing_list [ ARRAYREF ]

If an arguement is given, sets these email addresses as invoice recipients
(see L<FS::cust_main_invoice>).  Errors are not fatal and are not reported
(except as warnings), so use check_invoicing_list first.

Returns a list of email addresses (with svcnum entries expanded).

Note: You can clear the invoicing list by passing an empty ARRAYREF.  You can
check it without disturbing anything by passing nothing.

This interface may change in the future.

=cut

sub invoicing_list {
  my( $self, $arrayref ) = @_;
  if ( $arrayref ) {
    my @cust_main_invoice;
    if ( $self->custnum ) {
      @cust_main_invoice = 
        qsearch( 'cust_main_invoice', { 'custnum' => $self->custnum } );
    } else {
      @cust_main_invoice = ();
    }
    foreach my $cust_main_invoice ( @cust_main_invoice ) {
      #warn $cust_main_invoice->destnum;
      unless ( grep { $cust_main_invoice->address eq $_ } @{$arrayref} ) {
        #warn $cust_main_invoice->destnum;
        my $error = $cust_main_invoice->delete;
        warn $error if $error;
      }
    }
    if ( $self->custnum ) {
      @cust_main_invoice = 
        qsearch( 'cust_main_invoice', { 'custnum' => $self->custnum } );
    } else {
      @cust_main_invoice = ();
    }
    my %seen = map { $_->address => 1 } @cust_main_invoice;
    foreach my $address ( @{$arrayref} ) {
      next if exists $seen{$address} && $seen{$address};
      $seen{$address} = 1;
      my $cust_main_invoice = new FS::cust_main_invoice ( {
        'custnum' => $self->custnum,
        'dest'    => $address,
      } );
      my $error = $cust_main_invoice->insert;
      warn $error if $error;
    }
  }
  if ( $self->custnum ) {
    map { $_->address }
      qsearch( 'cust_main_invoice', { 'custnum' => $self->custnum } );
  } else {
    ();
  }
}

=item check_invoicing_list ARRAYREF

Checks these arguements as valid input for the invoicing_list method.  If there
is an error, returns the error, otherwise returns false.

=cut

sub check_invoicing_list {
  my( $self, $arrayref ) = @_;
  foreach my $address ( @{$arrayref} ) {
    my $cust_main_invoice = new FS::cust_main_invoice ( {
      'custnum' => $self->custnum,
      'dest'    => $address,
    } );
    my $error = $self->custnum
                ? $cust_main_invoice->check
                : $cust_main_invoice->checkdest
    ;
    return $error if $error;
  }
  '';
}

=item set_default_invoicing_list

Sets the invoicing list to all accounts associated with this customer,
overwriting any previous invoicing list.

=cut

sub set_default_invoicing_list {
  my $self = shift;
  $self->invoicing_list($self->all_emails);
}

=item all_emails

Returns the email addresses of all accounts provisioned for this customer.

=cut

sub all_emails {
  my $self = shift;
  my %list;
  foreach my $cust_pkg ( $self->all_pkgs ) {
    my @cust_svc = qsearch('cust_svc', { 'pkgnum' => $cust_pkg->pkgnum } );
    my @svc_acct =
      map { qsearchs('svc_acct', { 'svcnum' => $_->svcnum } ) }
        grep { qsearchs('svc_acct', { 'svcnum' => $_->svcnum } ) }
          @cust_svc;
    $list{$_}=1 foreach map { $_->email } @svc_acct;
  }
  keys %list;
}

=item invoicing_list_addpost

Adds postal invoicing to this customer.  If this customer is already configured
to receive postal invoices, does nothing.

=cut

sub invoicing_list_addpost {
  my $self = shift;
  return if grep { $_ eq 'POST' } $self->invoicing_list;
  my @invoicing_list = $self->invoicing_list;
  push @invoicing_list, 'POST';
  $self->invoicing_list(\@invoicing_list);
}

=item referral_cust_main [ DEPTH [ EXCLUDE_HASHREF ] ]

Returns an array of customers referred by this customer (referral_custnum set
to this custnum).  If DEPTH is given, recurses up to the given depth, returning
customers referred by customers referred by this customer and so on, inclusive.
The default behavior is DEPTH 1 (no recursion).

=cut

sub referral_cust_main {
  my $self = shift;
  my $depth = @_ ? shift : 1;
  my $exclude = @_ ? shift : {};

  my @cust_main =
    map { $exclude->{$_->custnum}++; $_; }
      grep { ! $exclude->{ $_->custnum } }
        qsearch( 'cust_main', { 'referral_custnum' => $self->custnum } );

  if ( $depth > 1 ) {
    push @cust_main,
      map { $_->referral_cust_main($depth-1, $exclude) }
        @cust_main;
  }

  @cust_main;
}

=item referral_cust_main_ncancelled

Same as referral_cust_main, except only returns customers with uncancelled
packages.

=cut

sub referral_cust_main_ncancelled {
  my $self = shift;
  grep { scalar($_->ncancelled_pkgs) } $self->referral_cust_main;
}

=item referral_cust_pkg [ DEPTH ]

Like referral_cust_main, except returns a flat list of all unsuspended (and
uncancelled) packages for each customer.  The number of items in this list may
be useful for comission calculations (perhaps after a C<grep { my $pkgpart = $_->pkgpart; grep { $_ == $pkgpart } @commission_worthy_pkgparts> } $cust_main-> ).

=cut

sub referral_cust_pkg {
  my $self = shift;
  my $depth = @_ ? shift : 1;

  map { $_->unsuspended_pkgs }
    grep { $_->unsuspended_pkgs }
      $self->referral_cust_main($depth);
}

=item credit AMOUNT, REASON

Applies a credit to this customer.  If there is an error, returns the error,
otherwise returns false.

=cut

sub credit {
  my( $self, $amount, $reason ) = @_;
  my $cust_credit = new FS::cust_credit {
    'custnum' => $self->custnum,
    'amount'  => $amount,
    'reason'  => $reason,
  };
  $cust_credit->insert;
}

=item charge AMOUNT [ PKG [ COMMENT [ TAXCLASS ] ] ]

Creates a one-time charge for this customer.  If there is an error, returns
the error, otherwise returns false.

=cut

sub charge {
  my ( $self, $amount ) = ( shift, shift );
  my $pkg      = @_ ? shift : 'One-time charge';
  my $comment  = @_ ? shift : '$'. sprintf("%.2f",$amount);
  my $taxclass = @_ ? shift : '';

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $part_pkg = new FS::part_pkg ( {
    'pkg'      => $pkg,
    'comment'  => $comment,
    #'setup'    => $amount,
    #'recur'    => '0',
    'plan'     => 'flat',
    'plandata' => "setup_fee=$amount",
    'freq'     => 0,
    'disabled' => 'Y',
    'taxclass' => $taxclass,
  } );

  my $error = $part_pkg->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $pkgpart = $part_pkg->pkgpart;
  my %type_pkgs = ( 'typenum' => $self->agent->typenum, 'pkgpart' => $pkgpart );
  unless ( qsearchs('type_pkgs', \%type_pkgs ) ) {
    my $type_pkgs = new FS::type_pkgs \%type_pkgs;
    $error = $type_pkgs->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $cust_pkg = new FS::cust_pkg ( {
    'custnum' => $self->custnum,
    'pkgpart' => $pkgpart,
  } );

  $error = $cust_pkg->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item cust_bill

Returns all the invoices (see L<FS::cust_bill>) for this customer.

=cut

sub cust_bill {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch('cust_bill', { 'custnum' => $self->custnum, } )
}

=item open_cust_bill

Returns all the open (owed > 0) invoices (see L<FS::cust_bill>) for this
customer.

=cut

sub open_cust_bill {
  my $self = shift;
  grep { $_->owed > 0 } $self->cust_bill;
}

=item cust_credit

Returns all the credits (see L<FS::cust_credit>) for this customer.

=cut

sub cust_credit {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_credit', { 'custnum' => $self->custnum } )
}

=item cust_pay

Returns all the payments (see L<FS::cust_pay>) for this customer.

=cut

sub cust_pay {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_pay', { 'custnum' => $self->custnum } )
}

=item cust_pay_void

Returns all voided payments (see L<FS::cust_pay_void>) for this customer.

=cut

sub cust_pay_void {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_pay_void', { 'custnum' => $self->custnum } )
}


=item cust_refund

Returns all the refunds (see L<FS::cust_refund>) for this customer.

=cut

sub cust_refund {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_refund', { 'custnum' => $self->custnum } )
}

=item select_for_update

Selects this record with the SQL "FOR UPDATE" command.  This can be useful as
a mutex.

=cut

sub select_for_update {
  my $self = shift;
  qsearch('cust_main', { 'custnum' => $self->custnum }, '*', 'FOR UPDATE' );
}

=item name

Returns a name string for this customer, either "Company (Last, First)" or
"Last, First".

=cut

sub name {
  my $self = shift;
  my $name = $self->get('last'). ', '. $self->first;
  $name = $self->company. " ($name)" if $self->company;
  $name;
}

=item status

Returns a status string for this customer, currently:

=over 4

=item prospect - No packages have ever been ordered

=item active - One or more recurring packages is active

=item suspended - All non-cancelled recurring packages are suspended

=item cancelled - All recurring packages are cancelled

=back

=cut

sub status {
  my $self = shift;
  for my $status (qw( prospect active suspended cancelled )) {
    my $method = $status.'_sql';
    my $numnum = ( my $sql = $self->$method() ) =~ s/cust_main\.custnum/?/g;
    my $sth = dbh->prepare("SELECT $sql") or die dbh->errstr;
    $sth->execute( ($self->custnum) x $numnum ) or die $sth->errstr;
    return $status if $sth->fetchrow_arrayref->[0];
  }
}

=item statuscolor

Returns a hex triplet color string for this customer's status.

=cut

my %statuscolor = (
  'prospect'  => '000000',
  'active'    => '00CC00',
  'suspended' => 'FF9900',
  'cancelled' => 'FF0000',
);
sub statuscolor {
  my $self = shift;
  $statuscolor{$self->status};
}

=back

=head1 CLASS METHODS

=over 4

=item prospect_sql

Returns an SQL expression identifying prospective cust_main records (customers
with no packages ever ordered)

=cut

sub prospect_sql { "
  0 = ( SELECT COUNT(*) FROM cust_pkg
          WHERE cust_pkg.custnum = cust_main.custnum
      )
"; }

=item active_sql

Returns an SQL expression identifying active cust_main records.

=cut

sub active_sql { "
  0 < ( SELECT COUNT(*) FROM cust_pkg
          WHERE cust_pkg.custnum = cust_main.custnum
            AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
            AND ( cust_pkg.susp   IS NULL OR cust_pkg.susp   = 0 )
      )
"; }

=item susp_sql
=item suspended_sql

Returns an SQL expression identifying suspended cust_main records.

=cut

sub suspended_sql { susp_sql(@_); }
sub susp_sql { "
    0 < ( SELECT COUNT(*) FROM cust_pkg
            WHERE cust_pkg.custnum = cust_main.custnum
              AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
        )
    AND 0 = ( SELECT COUNT(*) FROM cust_pkg
                WHERE cust_pkg.custnum = cust_main.custnum
                  AND ( cust_pkg.susp IS NULL OR cust_pkg.susp = 0 )
                  AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
            )
"; }

=item cancel_sql
=item cancelled_sql

Returns an SQL expression identifying cancelled cust_main records.

=cut

sub cancelled_sql { cancel_sql(@_); }
sub cancel_sql { "
  0 < ( SELECT COUNT(*) FROM cust_pkg
          WHERE cust_pkg.custnum = cust_main.custnum
      )
  AND 0 = ( SELECT COUNT(*) FROM cust_pkg
              WHERE cust_pkg.custnum = cust_main.custnum
                AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
          )
"; }

=item fuzzy_search FUZZY_HASHREF [ HASHREF, SELECT, EXTRA_SQL, CACHE_OBJ ]

Performs a fuzzy (approximate) search and returns the matching FS::cust_main
records.  Currently, only I<last> or I<company> may be specified (the
appropriate ship_ field is also searched if applicable).

Additional options are the same as FS::Record::qsearch

=cut

sub fuzzy_search {
  my( $self, $fuzzy, $hash, @opt) = @_;
  #$self
  $hash ||= {};
  my @cust_main = ();

  check_and_rebuild_fuzzyfiles();
  foreach my $field ( keys %$fuzzy ) {
    my $sub = \&{"all_$field"};
    my %match = ();
    $match{$_}=1 foreach ( amatch($fuzzy->{$field}, ['i'], @{ &$sub() } ) );

    foreach ( keys %match ) {
      push @cust_main, qsearch('cust_main', { %$hash, $field=>$_}, @opt);
      push @cust_main, qsearch('cust_main', { %$hash, "ship_$field"=>$_}, @opt)
        if defined dbdef->table('cust_main')->column('ship_last');
    }
  }

  my %saw = ();
  @cust_main = grep { !$saw{$_->custnum}++ } @cust_main;

  @cust_main;

}

=back

=head1 SUBROUTINES

=over 4

=item smart_search OPTION => VALUE ...

Accepts the following options: I<search>, the string to search for.  The string
will be searched for as a customer number, last name or company name, first
searching for an exact match then fuzzy and substring matches.

Any additional options treated as an additional qualifier on the search
(i.e. I<agentnum>).

Returns a (possibly empty) array of FS::cust_main objects.

=cut

sub smart_search {
  my %options = @_;
  my $search = delete $options{'search'};
  my @cust_main = ();

  if ( $search =~ /^\s*(\d+)\s*$/ ) { # customer # search

    push @cust_main, qsearch('cust_main', { 'custnum' => $1, %options } );

  } elsif ( $search =~ /^\s*(\S.*\S)\s*$/ ) { #value search

    my $value = lc($1);
    my $q_value = dbh->quote($value);

    #exact
    my $sql = scalar(keys %options) ? ' AND ' : ' WHERE ';
    $sql .= " ( LOWER(last) = $q_value OR LOWER(company) = $q_value";
    $sql .= " OR LOWER(ship_last) = $q_value OR LOWER(ship_company) = $q_value"
      if defined dbdef->table('cust_main')->column('ship_last');
    $sql .= ' )';

    push @cust_main, qsearch( 'cust_main', \%options, '', $sql );

    unless ( @cust_main ) {  #no exact match, trying substring/fuzzy

      #still some false laziness w/ search/cust_main.cgi

      #substring
      push @cust_main, qsearch( 'cust_main',
                                { 'last'     => { 'op'    => 'ILIKE',
                                                  'value' => "%$q_value%" },
                                  %options,
                                }
                              );
      push @cust_main, qsearch( 'cust_main',
                                { 'ship_last' => { 'op'    => 'ILIKE',
                                                   'value' => "%$q_value%" },
                                  %options,

                                }
                              )
        if defined dbdef->table('cust_main')->column('ship_last');

      push @cust_main, qsearch( 'cust_main',
                                { 'company'  => { 'op'    => 'ILIKE',
                                                  'value' => "%$q_value%" },
                                  %options,
                                }
                              );
      push @cust_main, qsearch( 'cust_main',
                                { 'ship_company' => { 'op' => 'ILIKE',
                                                   'value' => "%$q_value%" },
                                  %options,
                                }
                              )
        if defined dbdef->table('cust_main')->column('ship_last');

      #fuzzy
      push @cust_main, FS::cust_main->fuzzy_search(
        { 'last'     => $value },
        \%options,
      );
      push @cust_main, FS::cust_main->fuzzy_search(
        { 'company'  => $value },
        \%options,
      );

    }

  }

  @cust_main;

}

=item check_and_rebuild_fuzzyfiles

=cut

sub check_and_rebuild_fuzzyfiles {
  my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;
  -e "$dir/cust_main.last" && -e "$dir/cust_main.company"
    or &rebuild_fuzzyfiles;
}

=item rebuild_fuzzyfiles

=cut

sub rebuild_fuzzyfiles {

  use Fcntl qw(:flock);

  my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;

  #last

  open(LASTLOCK,">>$dir/cust_main.last")
    or die "can't open $dir/cust_main.last: $!";
  flock(LASTLOCK,LOCK_EX)
    or die "can't lock $dir/cust_main.last: $!";

  my @all_last = map $_->getfield('last'), qsearch('cust_main', {});
  push @all_last,
                 grep $_, map $_->getfield('ship_last'), qsearch('cust_main',{})
    if defined dbdef->table('cust_main')->column('ship_last');

  open (LASTCACHE,">$dir/cust_main.last.tmp")
    or die "can't open $dir/cust_main.last.tmp: $!";
  print LASTCACHE join("\n", @all_last), "\n";
  close LASTCACHE or die "can't close $dir/cust_main.last.tmp: $!";

  rename "$dir/cust_main.last.tmp", "$dir/cust_main.last";
  close LASTLOCK;

  #company

  open(COMPANYLOCK,">>$dir/cust_main.company")
    or die "can't open $dir/cust_main.company: $!";
  flock(COMPANYLOCK,LOCK_EX)
    or die "can't lock $dir/cust_main.company: $!";

  my @all_company = grep $_ ne '', map $_->company, qsearch('cust_main',{});
  push @all_company,
       grep $_ ne '', map $_->ship_company, qsearch('cust_main', {})
    if defined dbdef->table('cust_main')->column('ship_last');

  open (COMPANYCACHE,">$dir/cust_main.company.tmp")
    or die "can't open $dir/cust_main.company.tmp: $!";
  print COMPANYCACHE join("\n", @all_company), "\n";
  close COMPANYCACHE or die "can't close $dir/cust_main.company.tmp: $!";

  rename "$dir/cust_main.company.tmp", "$dir/cust_main.company";
  close COMPANYLOCK;

}

=item all_last

=cut

sub all_last {
  my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;
  open(LASTCACHE,"<$dir/cust_main.last")
    or die "can't open $dir/cust_main.last: $!";
  my @array = map { chomp; $_; } <LASTCACHE>;
  close LASTCACHE;
  \@array;
}

=item all_company

=cut

sub all_company {
  my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;
  open(COMPANYCACHE,"<$dir/cust_main.company")
    or die "can't open $dir/cust_main.last: $!";
  my @array = map { chomp; $_; } <COMPANYCACHE>;
  close COMPANYCACHE;
  \@array;
}

=item append_fuzzyfiles LASTNAME COMPANY

=cut

sub append_fuzzyfiles {
  my( $last, $company ) = @_;

  &check_and_rebuild_fuzzyfiles;

  use Fcntl qw(:flock);

  my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;

  if ( $last ) {

    open(LAST,">>$dir/cust_main.last")
      or die "can't open $dir/cust_main.last: $!";
    flock(LAST,LOCK_EX)
      or die "can't lock $dir/cust_main.last: $!";

    print LAST "$last\n";

    flock(LAST,LOCK_UN)
      or die "can't unlock $dir/cust_main.last: $!";
    close LAST;
  }

  if ( $company ) {

    open(COMPANY,">>$dir/cust_main.company")
      or die "can't open $dir/cust_main.company: $!";
    flock(COMPANY,LOCK_EX)
      or die "can't lock $dir/cust_main.company: $!";

    print COMPANY "$company\n";

    flock(COMPANY,LOCK_UN)
      or die "can't unlock $dir/cust_main.company: $!";

    close COMPANY;
  }

  1;
}

=item batch_import

=cut

sub batch_import {
  my $param = shift;
  #warn join('-',keys %$param);
  my $fh = $param->{filehandle};
  my $agentnum = $param->{agentnum};
  my $refnum = $param->{refnum};
  my $pkgpart = $param->{pkgpart};
  my @fields = @{$param->{fields}};

  eval "use Date::Parse;";
  die $@ if $@;
  eval "use Text::CSV_XS;";
  die $@ if $@;

  my $csv = new Text::CSV_XS;
  #warn $csv;
  #warn $fh;

  my $imported = 0;
  #my $columns;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  
  #while ( $columns = $csv->getline($fh) ) {
  my $line;
  while ( defined($line=<$fh>) ) {

    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    my @columns = $csv->fields();
    #warn join('-',@columns);

    my %cust_main = (
      agentnum => $agentnum,
      refnum   => $refnum,
      country  => $conf->config('countrydefault') || 'US',
      payby    => 'BILL', #default
      paydate  => '12/2037', #default
    );
    my $billtime = time;
    my %cust_pkg = ( pkgpart => $pkgpart );
    foreach my $field ( @fields ) {
      if ( $field =~ /^cust_pkg\.(setup|bill|susp|expire|cancel)$/ ) {
        #$cust_pkg{$1} = str2time( shift @$columns );
        if ( $1 eq 'setup' ) {
          $billtime = str2time(shift @columns);
        } else {
          $cust_pkg{$1} = str2time( shift @columns );
        }
      } else {
        #$cust_main{$field} = shift @$columns; 
        $cust_main{$field} = shift @columns; 
      }
    }

    my $cust_pkg = new FS::cust_pkg ( \%cust_pkg ) if $pkgpart;
    my $cust_main = new FS::cust_main ( \%cust_main );
    use Tie::RefHash;
    tie my %hash, 'Tie::RefHash'; #this part is important
    $hash{$cust_pkg} = [] if $pkgpart;
    my $error = $cust_main->insert( \%hash );

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't insert customer for $line: $error";
    }

    #false laziness w/bill.cgi
    $error = $cust_main->bill( 'time' => $billtime );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't bill customer for $line: $error";
    }

    $cust_main->apply_payments;
    $cust_main->apply_credits;

    $error = $cust_main->collect();
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't collect customer for $line: $error";
    }

    $imported++;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return "Empty file!" unless $imported;

  ''; #no error

}

=item batch_charge

=cut

sub batch_charge {
  my $param = shift;
  #warn join('-',keys %$param);
  my $fh = $param->{filehandle};
  my @fields = @{$param->{fields}};

  eval "use Date::Parse;";
  die $@ if $@;
  eval "use Text::CSV_XS;";
  die $@ if $@;

  my $csv = new Text::CSV_XS;
  #warn $csv;
  #warn $fh;

  my $imported = 0;
  #my $columns;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  
  #while ( $columns = $csv->getline($fh) ) {
  my $line;
  while ( defined($line=<$fh>) ) {

    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    my @columns = $csv->fields();
    #warn join('-',@columns);

    my %row = ();
    foreach my $field ( @fields ) {
      $row{$field} = shift @columns;
    }

    my $cust_main = qsearchs('cust_main', { 'custnum' => $row{'custnum'} } );
    unless ( $cust_main ) {
      $dbh->rollback if $oldAutoCommit;
      return "unknown custnum $row{'custnum'}";
    }

    if ( $row{'amount'} > 0 ) {
      my $error = $cust_main->charge($row{'amount'}, $row{'pkg'});
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      $imported++;
    } elsif ( $row{'amount'} < 0 ) {
      my $error = $cust_main->credit( sprintf( "%.2f", 0-$row{'amount'} ),
                                      $row{'pkg'}                         );
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      $imported++;
    } else {
      #hmm?
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return "Empty file!" unless $imported;

  ''; #no error

}

=back

=head1 BUGS

The delete method.

The delete method should possibly take an FS::cust_main object reference
instead of a scalar customer number.

Bill and collect options should probably be passed as references instead of a
list.

There should probably be a configuration file with a list of allowed credit
card types.

No multiple currency support (probably a larger project than just this module).

payinfo_masked false laziness with cust_pay.pm and cust_refund.pm

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::cust_bill>, L<FS::cust_credit>
L<FS::agent>, L<FS::part_referral>, L<FS::cust_main_county>,
L<FS::cust_main_invoice>, L<FS::UID>, schema.html from the base documentation.

=cut

1;

