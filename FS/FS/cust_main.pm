package FS::cust_main;
use base qw( FS::cust_main::Packages
             FS::cust_main::Status
             FS::cust_main::NationalID
             FS::cust_main::Billing
             FS::cust_main::Billing_Realtime
             FS::cust_main::Billing_Batch
             FS::cust_main::Billing_Discount
             FS::cust_main::Billing_ThirdParty
             FS::cust_main::Location
             FS::cust_main::Credit_Limit
             FS::cust_main::Merge
             FS::cust_main::API
             FS::otaker_Mixin FS::payinfo_Mixin FS::cust_main_Mixin
             FS::geocode_Mixin FS::Quotable_Mixin FS::Sales_Mixin
             FS::o2m_Common
             FS::Record
           );

require 5.006;
use strict;
use Carp;
use Try::Tiny;
use Scalar::Util qw( blessed );
use List::Util qw(min);
use Tie::IxHash;
use File::Temp; #qw( tempfile );
use Data::Dumper;
use Time::Local qw(timelocal);
use Date::Format;
#use Date::Manip;
use Email::Address;
use Business::CreditCard 0.28;
use FS::UID qw( dbh driver_name );
use FS::Record qw( qsearchs qsearch dbdef regexp_sql );
use FS::Cursor;
use FS::Misc qw( generate_ps do_print money_pretty card_types );
use FS::Msgcat qw(gettext);
use FS::CurrentUser;
use FS::TicketSystem;
use FS::payby;
use FS::cust_pkg;
use FS::cust_svc;
use FS::cust_bill;
use FS::cust_bill_void;
use FS::legacy_cust_bill;
use FS::cust_pay;
use FS::cust_pay_pending;
use FS::cust_pay_void;
use FS::cust_pay_batch;
use FS::cust_credit;
use FS::cust_refund;
use FS::part_referral;
use FS::cust_main_county;
use FS::cust_location;
use FS::cust_class;
use FS::tax_status;
use FS::cust_main_exemption;
use FS::cust_tax_adjustment;
use FS::cust_tax_location;
use FS::agent_currency;
use FS::cust_main_invoice;
use FS::cust_tag;
use FS::prepay_credit;
use FS::queue;
use FS::part_pkg;
use FS::part_export;
#use FS::cust_event;
use FS::type_pkgs;
use FS::payment_gateway;
use FS::agent_payment_gateway;
use FS::banned_pay;
use FS::cust_main_note;
use FS::cust_attachment;
use FS::cust_contact;
use FS::Locales;
use FS::upgrade_journal;
use FS::sales;
use FS::cust_payby;
use FS::contact;
use FS::reason;

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
our $DEBUG = 0;
our $me = '[FS::cust_main]';

our $import = 0;
our $ignore_expired_card = 0;
our $ignore_banned_card = 0;
our $ignore_invalid_card = 0;

our $skip_fuzzyfiles = 0;

our $ucfirst_nowarn = 0;

#this info is in cust_payby as of 4.x
#this and the fields themselves can be removed in 5.x
our @encrypted_fields = ('payinfo', 'paycvv');
sub nohistory_fields { ('payinfo', 'paycvv'); }

our $conf;
our $default_agent_custid;
our $custnum_display_length;
#ask FS::UID to run this stuff for us later
#$FS::UID::callback{'FS::cust_main'} = sub { 
install_callback FS::UID sub { 
  $conf = new FS::Conf;
  $ignore_invalid_card    = $conf->exists('allow_invalid_cards');
  $default_agent_custid   = $conf->exists('cust_main-default_agent_custid');
  $custnum_display_length = $conf->config('cust_main-custnum-display_length');
};

sub _cache {
  my $self = shift;
  my ( $hashref, $cache ) = @_;
  if ( exists $hashref->{'pkgnum'} ) {
    #@{ $self->{'_pkgnum'} } = ();
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
                          ;

=head1 DESCRIPTION

An FS::cust_main object represents a customer.  FS::cust_main inherits from 
FS::Record.  The following fields are currently supported:

=over 4

=item custnum

Primary key (assigned automatically for new customers)

=item agentnum

Agent (see L<FS::agent>)

=item refnum

Advertising source (see L<FS::part_referral>)

=item first

First name

=item last

Last name

=item ss

Cocial security number (optional)

=item company

(optional)

=item daytime

phone (optional)

=item night

phone (optional)

=item fax

phone (optional)

=item mobile

phone (optional)

=item payby

Payment Type (See L<FS::payinfo_Mixin> for valid payby values)

=item payinfo

Payment Information (See L<FS::payinfo_Mixin> for data format)

=item paymask

Masked payinfo (See L<FS::payinfo_Mixin> for how this works)

=item paycvv

Card Verification Value, "CVV2" (also known as CVC2 or CID), the 3 or 4 digit number on the back (or front, for American Express) of the credit card

=item paydate

Expiration date, mm/yyyy, m/yyyy, mm/yy or m/yy

=item paystart_month

Start date month (maestro/solo cards only)

=item paystart_year

Start date year (maestro/solo cards only)

=item payissue

Issue number (maestro/solo cards only)

=item payname

Name on card or billing name

=item payip

IP address from which payment information was received

=item tax

Tax exempt, empty or `Y'

=item usernum

Order taker (see L<FS::access_user>)

=item comments

Comments (optional)

=item referral_custnum

Referring customer number

=item spool_cdr

Enable individual CDR spooling, empty or `Y'

=item dundate

A suggestion to events (see L<FS::part_bill_event">) to delay until this unix timestamp

=item squelch_cdr

Discourage individual CDR printing, empty or `Y'

=item edit_subject

Allow self-service editing of ticket subjects, empty or 'Y'

=item calling_list_exempt

Do not call, empty or 'Y'

=item invoice_ship_address

Display ship_address ("Service address") on invoices for this customer, empty or 'Y'

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

Usually the customer's location will not yet exist in the database, and
the C<bill_location> and C<ship_location> pseudo-fields must be set to 
uninserted L<FS::cust_location> objects.  These will be inserted and linked
(in both directions) to the new customer record.  If they're references 
to the same object, they will become the same location.

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

INVOICING_LIST_ARYREF: No longer supported.

Currently available options are: I<depend_jobnum>, I<noexport>,
I<tax_exemption>, I<prospectnum>, I<contact> and I<contact_params>.

If I<depend_jobnum> is set, all provisioning jobs will have a dependancy
on the supplied jobnum (they will not run until the specific job completes).
This can be used to defer provisioning until some action completes (such
as running the customer's credit card successfully).

The I<noexport> option is deprecated.  If I<noexport> is set true, no
provisioning jobs (exports) are scheduled.  (You can schedule them later with
the B<reexport> method.)

The I<tax_exemption> option can be set to an arrayref of tax names or a hashref
of tax names and exemption numbers.  FS::cust_main_exemption records will be
created and inserted.

If I<prospectnum> is set, moves contacts and locations from that prospect.

If I<contact> is set to an arrayref of FS::contact objects, those will be
inserted.

If I<contact_params> is set to a hashref of CGI parameters (and I<contact> is
unset), inserts those new contacts with this new customer.  Handles CGI
paramaters for an "m2" multiple entry field as passed by edit/cust_main.cgi

If I<cust_payby_params> is set to a hashref o fCGI parameters, inserts those
new stored payment records with this new customer.  Handles CGI parameters
for an "m2" multiple entry field as passed by edit/cust_main.cgi

=cut

sub insert {
  my $self = shift;
  my $cust_pkgs = @_ ? shift : {};
  my $invoicing_list;
  if ( $_[0] and ref($_[0]) eq 'ARRAY' ) {
    warn "cust_main::insert using deprecated invoicing list argument";
    $invoicing_list = shift;
  }
  my %options = @_;
  warn "$me insert called with options ".
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

  my $prepay_identifier = '';
  my( $amount, $seconds, $upbytes, $downbytes, $totalbytes ) = (0, 0, 0, 0, 0);
  my $payby = '';
  if ( $self->payby eq 'PREPAY' ) {

    $self->payby(''); #'BILL');
    $prepay_identifier = $self->payinfo;
    $self->payinfo('');

    warn "  looking up prepaid card $prepay_identifier\n"
      if $DEBUG > 1;

    my $error = $self->get_prepay( $prepay_identifier,
                                   'amount_ref'     => \$amount,
                                   'seconds_ref'    => \$seconds,
                                   'upbytes_ref'    => \$upbytes,
                                   'downbytes_ref'  => \$downbytes,
                                   'totalbytes_ref' => \$totalbytes,
                                 );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      #return "error applying prepaid card (transaction rolled back): $error";
      return $error;
    }

    $payby = 'PREP' if $amount;

  } elsif ( $self->payby =~ /^(CASH|WEST|MCRD|MCHK|PPAL)$/ ) {

    $payby = $1;
    $self->payby(''); #'BILL');
    $amount = $self->paid;

  }

  # insert locations
  foreach my $l (qw(bill_location ship_location)) {

    my $loc = delete $self->hashref->{$l} or next;

    if ( !$loc->locationnum ) {
      # warn the location that we're going to insert it with no custnum
      $loc->set(custnum_pending => 1);
      warn "  inserting $l\n"
        if $DEBUG > 1;
      my $error = $loc->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        my $label = $l eq 'ship_location' ? 'service' : 'billing';
        return "$error (in $label location)";
      }

    } elsif ( $loc->prospectnum ) {

      $loc->prospectnum('');
      $loc->set(custnum_pending => 1);
      my $error = $loc->replace;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        my $label = $l eq 'ship_location' ? 'service' : 'billing';
        return "$error (moving $label location)";
      }

    } elsif ( ($loc->custnum || 0) > 0 ) {
      # then it somehow belongs to another customer--shouldn't happen
      $dbh->rollback if $oldAutoCommit;
      return "$l belongs to customer ".$loc->custnum;
    }
    # else it already belongs to this customer 
    # (happens when ship_location is identical to bill_location)

    $self->set($l.'num', $loc->locationnum);

    if ( $self->get($l.'num') eq '' ) {
      $dbh->rollback if $oldAutoCommit;
      return "$l not set";
    }
  }

  warn "  inserting $self\n"
    if $DEBUG > 1;

  $self->signupdate(time) unless $self->signupdate;

  $self->auto_agent_custid()
    if $conf->config('cust_main-auto_agent_custid') && ! $self->agent_custid;

  my $error =  $self->check_payinfo_cardtype
            || $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    #return "inserting cust_main record (transaction rolled back): $error";
    return $error;
  }

  # now set cust_location.custnum
  foreach my $l (qw(bill_location ship_location)) {
    warn "  setting $l.custnum\n"
      if $DEBUG > 1;
    my $loc = $self->$l or next;
    unless ( $loc->custnum ) {
      $loc->set(custnum => $self->custnum);
      $error ||= $loc->replace;
    }

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error setting $l custnum: $error";
    }
  }

  warn "  setting customer tags\n"
    if $DEBUG > 1;

  foreach my $tagnum ( @{ $self->tagnum || [] } ) {
    my $cust_tag = new FS::cust_tag { 'tagnum'  => $tagnum,
                                      'custnum' => $self->custnum };
    my $error = $cust_tag->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $prospectnum = delete $options{'prospectnum'};
  if ( $prospectnum ) {

    warn "  moving contacts and locations from prospect $prospectnum\n"
      if $DEBUG > 1;

    my $prospect_main =
      qsearchs('prospect_main', { 'prospectnum' => $prospectnum } );
    unless ( $prospect_main ) {
      $dbh->rollback if $oldAutoCommit;
      return "Unknown prospectnum $prospectnum";
    }
    $prospect_main->custnum($self->custnum);
    $prospect_main->disabled('Y');
    my $error = $prospect_main->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

    foreach my $prospect_contact ( $prospect_main->prospect_contact ) {
      my $cust_contact = new FS::cust_contact {
        'custnum' => $self->custnum,
        'invoice_dest' => 'Y', # invoice_dest currently not set for prospect contacts
        map { $_ => $prospect_contact->$_() } qw( contactnum classnum comment )
      };
      my $error =  $cust_contact->insert
                || $prospect_contact->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }

    my @cust_location = $prospect_main->cust_location;
    my @qual = $prospect_main->qual;

    foreach my $r ( @cust_location, @qual ) {
      $r->prospectnum('');
      $r->custnum($self->custnum);
      my $error = $r->replace;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
    # since we set invoice_dest on all migrated prospect contacts (for now),
    # don't process invoicing_list.
    delete $options{'invoicing_list'};
    $invoicing_list = undef;
  }

  warn "  setting contacts\n"
    if $DEBUG > 1;

  $invoicing_list ||= $options{'invoicing_list'};
  if ( $invoicing_list ) {

    $invoicing_list = [ $invoicing_list ] if !ref($invoicing_list);

    my $email = '';
    foreach my $dest (@$invoicing_list ) {
      if ($dest eq 'POST') {
        $self->set('postal_invoice', 'Y');
      } else {

        my $contact_email = qsearchs('contact_email', { emailaddress => $dest });
        if ( $contact_email ) {
          my $cust_contact = FS::cust_contact->new({
              contactnum    => $contact_email->contactnum,
              custnum       => $self->custnum,
          });
          $cust_contact->set('invoice_dest', 'Y');
          my $error = $cust_contact->insert;
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return "$error (linking to email address $dest)";
          }

        } else {
          # this email address is not yet linked to any contact
          $email .= ',' if length($email);
          $email .= $dest;
        }
      }
    }

    if ( $email ) {

      my $contact = FS::contact->new({
        'custnum'       => $self->get('custnum'),
        'last'          => $self->get('last'),
        'first'         => $self->get('first'),
        'emailaddress'  => $email,
        'invoice_dest'  => 'Y', # yes, you can set this via the contact
      });
      my $error = $contact->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

    }

  }

  if ( my $contact = delete $options{'contact'} ) {

    foreach my $c ( @$contact ) {
      $c->custnum($self->custnum);
      my $error = $c->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

    }

  } elsif ( my $contact_params = delete $options{'contact_params'} ) {

    my $error = $self->process_o2m( 'table'  => 'contact',
                                    'fields' => FS::contact->cgi_contact_fields,
                                    'params' => $contact_params,
                                  );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  warn "  setting cust_payby\n"
    if $DEBUG > 1;

  if ( $options{cust_payby} ) {

    foreach my $cust_payby ( @{ $options{cust_payby} } ) {
      $cust_payby->custnum($self->custnum);
      my $error = $cust_payby->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }

  } elsif ( my $cust_payby_params = delete $options{'cust_payby_params'} ) {

    my $error = $self->process_o2m(
      'table'         => 'cust_payby',
      'fields'        => FS::cust_payby->cgi_cust_payby_fields,
      'params'        => $cust_payby_params,
      'hash_callback' => \&FS::cust_payby::cgi_hash_callback,
    );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  warn "  setting cust_main_exemption\n"
    if $DEBUG > 1;

  my $tax_exemption = delete $options{'tax_exemption'};
  if ( $tax_exemption ) {

    $tax_exemption = { map { $_ => '' } @$tax_exemption }
      if ref($tax_exemption) eq 'ARRAY';

    foreach my $taxname ( keys %$tax_exemption ) {
      my $cust_main_exemption = new FS::cust_main_exemption {
        'custnum'       => $self->custnum,
        'taxname'       => $taxname,
        'exempt_number' => $tax_exemption->{$taxname},
      };
      my $error = $cust_main_exemption->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "inserting cust_main_exemption (transaction rolled back): $error";
      }
    }
  }

  warn "  ordering packages\n"
    if $DEBUG > 1;

  $error = $self->order_pkgs( $cust_pkgs,
                              %options,
                              'seconds_ref'    => \$seconds,
                              'upbytes_ref'    => \$upbytes,
                              'downbytes_ref'  => \$downbytes,
                              'totalbytes_ref' => \$totalbytes,
                            );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $seconds ) {
    $dbh->rollback if $oldAutoCommit;
    return "No svc_acct record to apply pre-paid time";
  }
  if ( $upbytes || $downbytes || $totalbytes ) {
    $dbh->rollback if $oldAutoCommit;
    return "No svc_acct record to apply pre-paid data";
  }

  if ( $amount ) {
    warn "  inserting initial $payby payment of $amount\n"
      if $DEBUG > 1;
    $error = $self->insert_cust_pay($payby, $amount, $prepay_identifier);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "inserting payment (transaction rolled back): $error";
    }
  }

  unless ( $import || $skip_fuzzyfiles ) {
    warn "  queueing fuzzyfiles update\n"
      if $DEBUG > 1;
    $error = $self->queue_fuzzyfiles_update;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "updating fuzzy search cache: $error";
    }
  }

  # FS::geocode_Mixin::after_insert or something?
  if ( $conf->config('tax_district_method') and !$import ) {
    # if anything non-empty, try to look it up
    my $queue = new FS::queue {
      'job'     => 'FS::geocode_Mixin::process_district_update',
      'custnum' => $self->custnum,
    };
    my $error = $queue->insert( ref($self), $self->custnum );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "queueing tax district update: $error";
    }
  }

  # cust_main exports!
  warn "  exporting\n" if $DEBUG > 1;

  my $export_args = $options{'export_args'} || [];

  my @part_export =
    map qsearch( 'part_export', {exportnum=>$_} ),
      $conf->config('cust_main-exports'); #, $agentnum

  foreach my $part_export ( @part_export ) {
    my $error = $part_export->export_insert($self, @$export_args);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "exporting to ". $part_export->exporttype.
             " (transaction rolled back): $error";
    }
  }

  #foreach my $depend_jobnum ( @$depend_jobnums ) {
  #    warn "[$me] inserting dependancies on supplied job $depend_jobnum\n"
  #      if $DEBUG;
  #    foreach my $jobnum ( @jobnums ) {
  #      my $queue = qsearchs('queue', { 'jobnum' => $jobnum } );
  #      warn "[$me] inserting dependancy for job $jobnum on $depend_jobnum\n"
  #        if $DEBUG;
  #      my $error = $queue->depend_insert($depend_jobnum);
  #      if ( $error ) {
  #        $dbh->rollback if $oldAutoCommit;
  #        return "error queuing job dependancy: $error";
  #      }
  #    }
  #  }
  #
  #}
  #
  #if ( exists $options{'jobnums'} ) {
  #  push @{ $options{'jobnums'} }, @jobnums;
  #}

  warn "  insert complete; committing transaction\n"
    if $DEBUG > 1;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

use File::CounterFile;
sub auto_agent_custid {
  my $self = shift;

  my $format = $conf->config('cust_main-auto_agent_custid');
  my $agent_custid;
  if ( $format eq '1YMMXXXXXXXX' ) {

    my $counter = new File::CounterFile 'cust_main.agent_custid';
    $counter->lock;

    my $ym = 100000000000 + time2str('%y%m00000000', time);
    if ( $ym > $counter->value ) {
      $counter->{'value'} = $agent_custid = $ym;
      $counter->{'updated'} = 1;
    } else {
      $agent_custid = $counter->inc;
    }

    $counter->unlock;

  } else {
    die "Unknown cust_main-auto_agent_custid format: $format";
  }

  $self->agent_custid($agent_custid);

}

=item PACKAGE METHODS

Documentation on customer package methods has been moved to
L<FS::cust_main::Packages>.

=item recharge_prepay IDENTIFIER | PREPAY_CREDIT_OBJ [ , AMOUNTREF, SECONDSREF, UPBYTEREF, DOWNBYTEREF ]

Recharges this (existing) customer with the specified prepaid card (see
L<FS::prepay_credit>), specified either by I<identifier> or as an
FS::prepay_credit object.  If there is an error, returns the error, otherwise
returns false.

Optionally, five scalar references can be passed as well.  They will have their
values filled in with the amount, number of seconds, and number of upload,
download, and total bytes applied by this prepaid card.

=cut

#the ref bullshit here should be refactored like get_prepay.  MyAccount.pm is
#the only place that uses these args
sub recharge_prepay { 
  my( $self, $prepay_credit, $amountref, $secondsref, 
      $upbytesref, $downbytesref, $totalbytesref ) = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my( $amount, $seconds, $upbytes, $downbytes, $totalbytes) = ( 0, 0, 0, 0, 0 );

  my $error = $self->get_prepay( $prepay_credit,
                                 'amount_ref'     => \$amount,
                                 'seconds_ref'    => \$seconds,
                                 'upbytes_ref'    => \$upbytes,
                                 'downbytes_ref'  => \$downbytes,
                                 'totalbytes_ref' => \$totalbytes,
                               )
           || $self->increment_seconds($seconds)
           || $self->increment_upbytes($upbytes)
           || $self->increment_downbytes($downbytes)
           || $self->increment_totalbytes($totalbytes)
           || $self->insert_cust_pay_prepay( $amount,
                                             ref($prepay_credit)
                                               ? $prepay_credit->identifier
                                               : $prepay_credit
                                           );

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( defined($amountref)  ) { $$amountref  = $amount;  }
  if ( defined($secondsref) ) { $$secondsref = $seconds; }
  if ( defined($upbytesref) ) { $$upbytesref = $upbytes; }
  if ( defined($downbytesref) ) { $$downbytesref = $downbytes; }
  if ( defined($totalbytesref) ) { $$totalbytesref = $totalbytes; }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item get_prepay IDENTIFIER | PREPAY_CREDIT_OBJ [ , OPTION => VALUE ... ]

Looks up and deletes a prepaid card (see L<FS::prepay_credit>),
specified either by I<identifier> or as an FS::prepay_credit object.

Available options are: I<amount_ref>, I<seconds_ref>, I<upbytes_ref>, I<downbytes_ref>, and I<totalbytes_ref>.  The scalars (provided by references) will be
incremented by the values of the prepaid card.

If the prepaid card specifies an I<agentnum> (see L<FS::agent>), it is used to
check or set this customer's I<agentnum>.

If there is an error, returns the error, otherwise returns false.

=cut


sub get_prepay {
  my( $self, $prepay_credit, %opt ) = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  unless ( ref($prepay_credit) ) {

    my $identifier = $prepay_credit;

    $prepay_credit = qsearchs(
      'prepay_credit',
      { 'identifier' => $identifier },
      '',
      'FOR UPDATE'
    );

    unless ( $prepay_credit ) {
      $dbh->rollback if $oldAutoCommit;
      return "Invalid prepaid card: ". $identifier;
    }

  }

  if ( $prepay_credit->agentnum ) {
    if ( $self->agentnum && $self->agentnum != $prepay_credit->agentnum ) {
      $dbh->rollback if $oldAutoCommit;
      return "prepaid card not valid for agent ". $self->agentnum;
    }
    $self->agentnum($prepay_credit->agentnum);
  }

  my $error = $prepay_credit->delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "removing prepay_credit (transaction rolled back): $error";
  }

  ${ $opt{$_.'_ref'} } += $prepay_credit->$_()
    for grep $opt{$_.'_ref'}, qw( amount seconds upbytes downbytes totalbytes );

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item increment_upbytes SECONDS

Updates this customer's single or primary account (see L<FS::svc_acct>) by
the specified number of upbytes.  If there is an error, returns the error,
otherwise returns false.

=cut

sub increment_upbytes {
  _increment_column( shift, 'upbytes', @_);
}

=item increment_downbytes SECONDS

Updates this customer's single or primary account (see L<FS::svc_acct>) by
the specified number of downbytes.  If there is an error, returns the error,
otherwise returns false.

=cut

sub increment_downbytes {
  _increment_column( shift, 'downbytes', @_);
}

=item increment_totalbytes SECONDS

Updates this customer's single or primary account (see L<FS::svc_acct>) by
the specified number of totalbytes.  If there is an error, returns the error,
otherwise returns false.

=cut

sub increment_totalbytes {
  _increment_column( shift, 'totalbytes', @_);
}

=item increment_seconds SECONDS

Updates this customer's single or primary account (see L<FS::svc_acct>) by
the specified number of seconds.  If there is an error, returns the error,
otherwise returns false.

=cut

sub increment_seconds {
  _increment_column( shift, 'seconds', @_);
}

=item _increment_column AMOUNT

Updates this customer's single or primary account (see L<FS::svc_acct>) by
the specified number of seconds or bytes.  If there is an error, returns
the error, otherwise returns false.

=cut

sub _increment_column {
  my( $self, $column, $amount ) = @_;
  warn "$me increment_column called: $column, $amount\n"
    if $DEBUG;

  return '' unless $amount;

  my @cust_pkg = grep { $_->part_pkg->svcpart('svc_acct') }
                      $self->ncancelled_pkgs;

  if ( ! @cust_pkg ) {
    return 'No packages with primary or single services found'.
           ' to apply pre-paid time';
  } elsif ( scalar(@cust_pkg) > 1 ) {
    #maybe have a way to specify the package/account?
    return 'Multiple packages found to apply pre-paid time';
  }

  my $cust_pkg = $cust_pkg[0];
  warn "  found package pkgnum ". $cust_pkg->pkgnum. "\n"
    if $DEBUG > 1;

  my @cust_svc =
    $cust_pkg->cust_svc( $cust_pkg->part_pkg->svcpart('svc_acct') );

  if ( ! @cust_svc ) {
    return 'No account found to apply pre-paid time';
  } elsif ( scalar(@cust_svc) > 1 ) {
    return 'Multiple accounts found to apply pre-paid time';
  }
  
  my $svc_acct = $cust_svc[0]->svc_x;
  warn "  found service svcnum ". $svc_acct->pkgnum.
       ' ('. $svc_acct->email. ")\n"
    if $DEBUG > 1;

  $column = "increment_$column";
  $svc_acct->$column($amount);

}

=item insert_cust_pay_prepay AMOUNT [ PAYINFO ]

Inserts a prepayment in the specified amount for this customer.  An optional
second argument can specify the prepayment identifier for tracking purposes.
If there is an error, returns the error, otherwise returns false.

=cut

sub insert_cust_pay_prepay {
  shift->insert_cust_pay('PREP', @_);
}

=item insert_cust_pay_cash AMOUNT [ PAYINFO ]

Inserts a cash payment in the specified amount for this customer.  An optional
second argument can specify the payment identifier for tracking purposes.
If there is an error, returns the error, otherwise returns false.

=cut

sub insert_cust_pay_cash {
  shift->insert_cust_pay('CASH', @_);
}

=item insert_cust_pay_west AMOUNT [ PAYINFO ]

Inserts a Western Union payment in the specified amount for this customer.  An
optional second argument can specify the prepayment identifier for tracking
purposes.  If there is an error, returns the error, otherwise returns false.

=cut

sub insert_cust_pay_west {
  shift->insert_cust_pay('WEST', @_);
}

sub insert_cust_pay {
  my( $self, $payby, $amount ) = splice(@_, 0, 3);
  my $payinfo = scalar(@_) ? shift : '';

  my $cust_pay = new FS::cust_pay {
    'custnum' => $self->custnum,
    'paid'    => sprintf('%.2f', $amount),
    #'_date'   => #date the prepaid card was purchased???
    'payby'   => $payby,
    'payinfo' => $payinfo,
  };
  $cust_pay->insert;

}

=item delete [ OPTION => VALUE ... ]

This deletes the customer.  If there is an error, returns the error, otherwise
returns false.

This will completely remove all traces of the customer record.  This is not
what you want when a customer cancels service; for that, cancel all of the
customer's packages (see L</cancel>).

If the customer has any uncancelled packages, you need to pass a new (valid)
customer number for those packages to be transferred to, as the "new_customer"
option.  Cancelled packages will be deleted.  Did I mention that this is NOT
what you want when a customer cancels service and that you really should be
looking at L<FS::cust_pkg/cancel>?  

You can't delete a customer with invoices (see L<FS::cust_bill>),
statements (see L<FS::cust_statement>), credits (see L<FS::cust_credit>),
payments (see L<FS::cust_pay>) or refunds (see L<FS::cust_refund>), unless you
set the "delete_financials" option to a true value.

=cut

sub delete {
  my( $self, %opt ) = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( qsearch('agent', { 'agent_custnum' => $self->custnum } ) ) {
     $dbh->rollback if $oldAutoCommit;
     return "Can't delete a master agent customer";
  }

  #use FS::access_user
  if ( qsearch('access_user', { 'user_custnum' => $self->custnum } ) ) {
     $dbh->rollback if $oldAutoCommit;
     return "Can't delete a master employee customer";
  }

  tie my %financial_tables, 'Tie::IxHash',
    'cust_bill'      => 'invoices',
    'cust_statement' => 'statements',
    'cust_credit'    => 'credits',
    'cust_pay'       => 'payments',
    'cust_refund'    => 'refunds',
  ;
   
  foreach my $table ( keys %financial_tables ) {

    my @records = $self->$table();

    if ( @records && ! $opt{'delete_financials'} ) {
      $dbh->rollback if $oldAutoCommit;
      return "Can't delete a customer with ". $financial_tables{$table};
    }

    foreach my $record ( @records ) {
      my $error = $record->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error deleting ". $financial_tables{$table}. ": $error\n";
      }
    }

  }

  my @cust_pkg = $self->ncancelled_pkgs;
  if ( @cust_pkg ) {
    my $new_custnum = $opt{'new_custnum'};
    unless ( qsearchs( 'cust_main', { 'custnum' => $new_custnum } ) ) {
      $dbh->rollback if $oldAutoCommit;
      return "Invalid new customer number: $new_custnum";
    }
    foreach my $cust_pkg ( @cust_pkg ) {
      my %hash = $cust_pkg->hash;
      $hash{'custnum'} = $new_custnum;
      my $new_cust_pkg = new FS::cust_pkg ( \%hash );
      my $error = $new_cust_pkg->replace($cust_pkg,
                                         options => { $cust_pkg->options },
                                        );
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

  #cust_tax_adjustment in financials?
  #cust_pay_pending?  ouch
  foreach my $table (qw(
    cust_main_invoice cust_main_exemption cust_tag cust_attachment contact
    cust_payby cust_location cust_main_note cust_tax_adjustment
    cust_pay_void cust_pay_batch queue cust_tax_exempt
  )) {
    foreach my $record ( qsearch( $table, { 'custnum' => $self->custnum } ) ) {
      my $error = $record->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  my $sth = $dbh->prepare(
    'UPDATE cust_main SET referral_custnum = NULL WHERE referral_custnum = ?'
  ) or do {
    my $errstr = $dbh->errstr;
    $dbh->rollback if $oldAutoCommit;
    return $errstr;
  };
  $sth->execute($self->custnum) or do {
    my $errstr = $sth->errstr;
    $dbh->rollback if $oldAutoCommit;
    return $errstr;
  };

  #tickets

  my $ticket_dbh = '';
  if ($conf->config('ticket_system') eq 'RT_Internal') {
    $ticket_dbh = $dbh;
  } elsif ($conf->config('ticket_system') eq 'RT_External') {
    my ($datasrc, $user, $pass) = $conf->config('ticket_system-rt_external_datasrc');
    $ticket_dbh = DBI->connect($datasrc, $user, $pass, { 'ChopBlanks' => 1 });
      #or die "RT_External DBI->connect error: $DBI::errstr\n";
  }

  if ( $ticket_dbh ) {

    my $ticket_sth = $ticket_dbh->prepare(
      'DELETE FROM Links WHERE Target = ?'
    ) or do {
      my $errstr = $ticket_dbh->errstr;
      $dbh->rollback if $oldAutoCommit;
      return $errstr;
    };
    $ticket_sth->execute('freeside://freeside/cust_main/'.$self->custnum)
      or do {
        my $errstr = $ticket_sth->errstr;
        $dbh->rollback if $oldAutoCommit;
        return $errstr;
      };

    #check and see if the customer is the only link on the ticket, and
    #if so, set the ticket to deleted status in RT?
    #maybe someday, for now this will at least fix tickets not displaying

  }

  #delete the customer record

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  # cust_main exports!

  #my $export_args = $options{'export_args'} || [];

  my @part_export =
    map qsearch( 'part_export', {exportnum=>$_} ),
      $conf->config('cust_main-exports'); #, $agentnum

  foreach my $part_export ( @part_export ) {
    my $error = $part_export->export_delete( $self ); #, @$export_args);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "exporting to ". $part_export->exporttype.
             " (transaction rolled back): $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item replace [ OLD_RECORD ] [ INVOICING_LIST_ARYREF ] [ , OPTION => VALUE ... ] ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

To change the customer's address, set the pseudo-fields C<bill_location> and
C<ship_location>.  The address will still only change if at least one of the
address fields differs from the existing values.

INVOICING_LIST_ARYREF: If you pass an arrayref to this method, it will be
set as the contact email address for a default contact with the same name as
the customer.

Currently available options are: I<tax_exemption>, I<cust_payby_params>, 
I<contact_params>, I<invoicing_list>.

The I<tax_exemption> option can be set to an arrayref of tax names or a hashref
of tax names and exemption numbers.  FS::cust_main_exemption records will be
deleted and inserted as appropriate.

I<cust_payby_params> and I<contact_params> can be hashrefs of named parameter
groups (describing the customer's payment methods and contacts, respectively)
in the style supported by L<FS::o2m_Common/process_o2m>. See L<FS::cust_payby>
and L<FS::contact> for the fields these can contain.

I<invoicing_list> is a synonym for the INVOICING_LIST_ARYREF parameter, and
should be used instead if possible.

=cut

sub replace {
  my $self = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $self->replace_old;

  my @param = @_;

  warn "$me replace called\n"
    if $DEBUG;

  my $curuser = $FS::CurrentUser::CurrentUser;
  return "You are not permitted to create complimentary accounts."
    if $self->complimentary eq 'Y'
    && $self->complimentary ne $old->complimentary
    && ! $curuser->access_right('Complimentary customer');

  local($ignore_expired_card) = 1
    if $old->payby  =~ /^(CARD|DCRD)$/
    && $self->payby =~ /^(CARD|DCRD)$/
    && ( $old->payinfo eq $self->payinfo || $old->paymask eq $self->paymask );

  local($ignore_banned_card) = 1
    if (    $old->payby  =~ /^(CARD|DCRD)$/ && $self->payby =~ /^(CARD|DCRD)$/
         || $old->payby  =~ /^(CHEK|DCHK)$/ && $self->payby =~ /^(CHEK|DCHK)$/ )
    && ( $old->payinfo eq $self->payinfo || $old->paymask eq $self->paymask );

  if (    $self->payby =~ /^(CARD|DCRD)$/
       && $old->payinfo ne $self->payinfo
       && $old->paymask ne $self->paymask )
  {
    my $error = $self->check_payinfo_cardtype;
    return $error if $error;
  }

  return "Invoicing locale is required"
    if $old->locale
    && ! $self->locale
    && $conf->exists('cust_main-require_locale');

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  for my $l (qw(bill_location ship_location)) {
    #my $old_loc = $old->$l;
    my $new_loc = $self->$l or next;

    # find the existing location if there is one
    $new_loc->set('custnum' => $self->custnum);
    my $error = $new_loc->find_or_insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    $self->set($l.'num', $new_loc->locationnum);
  } #for $l

  my $invoicing_list;
  if ( @param && ref($param[0]) eq 'ARRAY' ) { # INVOICING_LIST_ARYREF
    warn "cust_main::replace: using deprecated invoicing list argument";
    $invoicing_list = shift @param;
  }

  my %options = @param;

  $invoicing_list ||= $options{invoicing_list};

  my @contacts = map { $_->contact } $self->cust_contact;
  # find a contact that matches the customer's name
  my ($implicit_contact) = grep { $_->first eq $old->get('first')
                              and $_->last  eq $old->get('last') }
                            @contacts;
  $implicit_contact ||= FS::contact->new({
      'custnum'       => $self->custnum,
      'locationnum'   => $self->get('bill_locationnum'),
  });

  # for any of these that are already contact emails, link to the existing
  # contact
  if ( $invoicing_list ) {
    my $email = '';

    # kind of like process_m2m on these, except:
    # - the other side is two tables in a join
    # - and we might have to create new contact_emails
    # - and possibly a new contact
    # 
    # Find existing invoice emails that aren't on the implicit contact.
    # Any of these that are not on the new invoicing list will be removed.
    my %old_email_cust_contact;
    foreach my $cust_contact ($self->cust_contact) {
      next if !$cust_contact->invoice_dest;
      next if $cust_contact->contactnum == ($implicit_contact->contactnum || 0);

      foreach my $contact_email ($cust_contact->contact->contact_email) {
        $old_email_cust_contact{ $contact_email->emailaddress } = $cust_contact;
      }
    }

    foreach my $dest (@$invoicing_list) {

      if ($dest eq 'POST') {

        $self->set('postal_invoice', 'Y');

      } elsif ( exists($old_email_cust_contact{$dest}) ) {

        delete $old_email_cust_contact{$dest}; # don't need to remove it, then

      } else {

        # See if it belongs to some other contact; if so, link it.
        my $contact_email = qsearchs('contact_email', { emailaddress => $dest });
        if ( $contact_email
             and $contact_email->contactnum != ($implicit_contact->contactnum || 0) ) {
          my $cust_contact = qsearchs('cust_contact', {
              contactnum  => $contact_email->contactnum,
              custnum     => $self->custnum,
          }) || FS::cust_contact->new({
              contactnum    => $contact_email->contactnum,
              custnum       => $self->custnum,
          });
          $cust_contact->set('invoice_dest', 'Y');
          my $error = $cust_contact->custcontactnum ?
                        $cust_contact->replace : $cust_contact->insert;
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return "$error (linking to email address $dest)";
          }

        } else {
          # This email address is not yet linked to any contact, so it will
          # be added to the implicit contact.
          $email .= ',' if length($email);
          $email .= $dest;
        }
      }
    }

    foreach my $remove_dest (keys %old_email_cust_contact) {
      my $cust_contact = $old_email_cust_contact{$remove_dest};
      # These were not in the list of requested destinations, so take them off.
      $cust_contact->set('invoice_dest', '');
      my $error = $cust_contact->replace;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "$error (unlinking email address $remove_dest)";
      }
    }

    # make sure it keeps up with the changed customer name, if any
    $implicit_contact->set('last', $self->get('last'));
    $implicit_contact->set('first', $self->get('first'));
    $implicit_contact->set('emailaddress', $email);
    $implicit_contact->set('invoice_dest', 'Y');
    $implicit_contact->set('custnum', $self->custnum);

    my $error;
    if ( $implicit_contact->contactnum ) {
      $error = $implicit_contact->replace;
    } elsif ( length($email) ) { # don't create a new contact if not needed
      $error = $implicit_contact->insert;
    }

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "$error (adding email address $email)";
    }

  }

  # replace the customer record
  my $error = $self->SUPER::replace($old);

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  # now move packages to the new service location
  $self->set('ship_location', ''); #flush cache
  if ( $old->ship_locationnum and # should only be null during upgrade...
       $old->ship_locationnum != $self->ship_locationnum ) {
    $error = $old->ship_location->move_to($self->ship_location);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }
  # don't move packages based on the billing location, but 
  # disable it if it's no longer in use
  if ( $old->bill_locationnum and
       $old->bill_locationnum != $self->bill_locationnum ) {
    $error = $old->bill_location->disable_if_unused;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( $self->exists('tagnum') ) { #so we don't delete these on edit by accident

    #this could be more efficient than deleting and re-inserting, if it matters
    foreach my $cust_tag (qsearch('cust_tag', {'custnum'=>$self->custnum} )) {
      my $error = $cust_tag->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
    foreach my $tagnum ( @{ $self->tagnum || [] } ) {
      my $cust_tag = new FS::cust_tag { 'tagnum'  => $tagnum,
                                        'custnum' => $self->custnum };
      my $error = $cust_tag->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }

  }

  my $tax_exemption = delete $options{'tax_exemption'};
  if ( $tax_exemption ) {

    $tax_exemption = { map { $_ => '' } @$tax_exemption }
      if ref($tax_exemption) eq 'ARRAY';

    my %cust_main_exemption =
      map { $_->taxname => $_ }
          qsearch('cust_main_exemption', { 'custnum' => $old->custnum } );

    foreach my $taxname ( keys %$tax_exemption ) {

      if ( $cust_main_exemption{$taxname} && 
           $cust_main_exemption{$taxname}->exempt_number eq $tax_exemption->{$taxname}
         )
      {
        delete $cust_main_exemption{$taxname};
        next;
      }

      my $cust_main_exemption = new FS::cust_main_exemption {
        'custnum'       => $self->custnum,
        'taxname'       => $taxname,
        'exempt_number' => $tax_exemption->{$taxname},
      };
      my $error = $cust_main_exemption->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "inserting cust_main_exemption (transaction rolled back): $error";
      }
    }

    foreach my $cust_main_exemption ( values %cust_main_exemption ) {
      my $error = $cust_main_exemption->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "deleting cust_main_exemption (transaction rolled back): $error";
      }
    }

  }

  if ( my $cust_payby_params = delete $options{'cust_payby_params'} ) {

    my $error = $self->process_o2m(
      'table'         => 'cust_payby',
      'fields'        => FS::cust_payby->cgi_cust_payby_fields,
      'params'        => $cust_payby_params,
      'hash_callback' => \&FS::cust_payby::cgi_hash_callback,
    );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  if ( my $contact_params = delete $options{'contact_params'} ) {

    # this can potentially replace contacts that were created by the
    # invoicing list argument, but the UI shouldn't allow both of them
    # to be specified

    my $error = $self->process_o2m(
      'table'         => 'contact',
      'fields'        => FS::contact->cgi_contact_fields,
      'params'        => $contact_params,
    );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  unless ( $import || $skip_fuzzyfiles ) {
    $error = $self->queue_fuzzyfiles_update;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "updating fuzzy search cache: $error";
    }
  }

  # tax district update in cust_location

  # cust_main exports!

  my $export_args = $options{'export_args'} || [];

  my @part_export =
    map qsearch( 'part_export', {exportnum=>$_} ),
      $conf->config('cust_main-exports'); #, $agentnum

  foreach my $part_export ( @part_export ) {
    my $error = $part_export->export_replace( $self, $old, @$export_args);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "exporting to ". $part_export->exporttype.
             " (transaction rolled back): $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item queue_fuzzyfiles_update

Used by insert & replace to update the fuzzy search cache

=cut

use FS::cust_main::Search;
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

  foreach my $field ( 'first', 'last', 'company', 'ship_company' ) {
    my $queue = new FS::queue { 
      'job' => 'FS::cust_main::Search::append_fuzzyfiles_fuzzyfield'
    };
    my @args = "cust_main.$field", $self->get($field);
    my $error = $queue->insert( @args );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "queueing job (transaction rolled back): $error";
    }
  }

  my @locations = ();
  push @locations, $self->bill_location if $self->bill_locationnum;
  push @locations, $self->ship_location if @locations && $self->has_ship_address;
  foreach my $location (@locations) {
    my $queue = new FS::queue { 
      'job' => 'FS::cust_main::Search::append_fuzzyfiles_fuzzyfield'
    };
    my @args = 'cust_location.address1', $location->address1;
    my $error = $queue->insert( @args );
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
and replace methods.

=cut

sub check {
  my $self = shift;

  warn "$me check BEFORE: \n". $self->_dump
    if $DEBUG > 2;

  my $error =
    $self->ut_numbern('custnum')
    || $self->ut_number('agentnum')
    || $self->ut_textn('agent_custid')
    || $self->ut_number('refnum')
    || $self->ut_foreign_keyn('bill_locationnum', 'cust_location','locationnum')
    || $self->ut_foreign_keyn('ship_locationnum', 'cust_location','locationnum')
    || $self->ut_foreign_keyn('classnum', 'cust_class', 'classnum')
    || $self->ut_foreign_keyn('salesnum', 'sales', 'salesnum')
    || $self->ut_foreign_keyn('taxstatusnum', 'tax_status', 'taxstatusnum')
    || $self->ut_textn('custbatch')
    || $self->ut_name('last')
    || $self->ut_name('first')
    || $self->ut_snumbern('signupdate')
    || $self->ut_snumbern('birthdate')
    || $self->ut_namen('spouse_last')
    || $self->ut_namen('spouse_first')
    || $self->ut_snumbern('spouse_birthdate')
    || $self->ut_snumbern('anniversary_date')
    || $self->ut_textn('company')
    || $self->ut_textn('ship_company')
    || $self->ut_anything('comments')
    || $self->ut_numbern('referral_custnum')
    || $self->ut_textn('stateid')
    || $self->ut_textn('stateid_state')
    || $self->ut_textn('invoice_terms')
    || $self->ut_floatn('cdr_termination_percentage')
    || $self->ut_floatn('credit_limit')
    || $self->ut_numbern('billday')
    || $self->ut_numbern('prorate_day')
    || $self->ut_flag('force_prorate_day')
    || $self->ut_flag('edit_subject')
    || $self->ut_flag('calling_list_exempt')
    || $self->ut_flag('invoice_noemail')
    || $self->ut_flag('message_noemail')
    || $self->ut_enum('locale', [ '', FS::Locales->locales ])
    || $self->ut_currencyn('currency')
    || $self->ut_textn('po_number')
    || $self->ut_enum('complimentary', [ '', 'Y' ])
    || $self->ut_flag('invoice_ship_address')
    || $self->ut_flag('invoice_dest')
  ;

  foreach (qw(company ship_company)) {
    my $company = $self->get($_);
    $company =~ s/^\s+//; 
    $company =~ s/\s+$//; 
    $company =~ s/\s+/ /g;
    $self->set($_, $company);
  }

  #barf.  need message catalogs.  i18n.  etc.
  $error .= "Please select an advertising source."
    if $error =~ /^Illegal or empty \(numeric\) refnum: /;
  return $error if $error;

  my $agent = qsearchs( 'agent', { 'agentnum' => $self->agentnum } )
    or return "Unknown agent";

  if ( $self->currency ) {
    my $agent_currency = qsearchs( 'agent_currency', {
      'agentnum' => $agent->agentnum,
      'currency' => $self->currency,
    })
      or return "Agent ". $agent->agent.
                " not permitted to offer ".  $self->currency. " invoicing";
  }

  return "Unknown refnum"
    unless qsearchs( 'part_referral', { 'refnum' => $self->refnum } );

  return "Unknown referring custnum: ". $self->referral_custnum
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

  #turn off invoice_ship_address if ship & bill are the same
  if ($self->bill_locationnum eq $self->ship_locationnum) {
    $self->invoice_ship_address('');
  }

  # cust_main_county verification now handled by cust_location check

  $error =
       $self->ut_phonen('daytime', $self->country)
    || $self->ut_phonen('night',   $self->country)
    || $self->ut_phonen('fax',     $self->country)
    || $self->ut_phonen('mobile',  $self->country)
  ;
  return $error if $error;

  if ( $conf->exists('cust_main-require_phone', $self->agentnum)
       && ! $import
       && ! length($self->daytime) && ! length($self->night) && ! length($self->mobile)
     ) {

    my $daytime_label = FS::Msgcat::_gettext('daytime') =~ /^(daytime)?$/
                          ? 'Day Phone'
                          : FS::Msgcat::_gettext('daytime');
    my $night_label = FS::Msgcat::_gettext('night') =~ /^(night)?$/
                        ? 'Night Phone'
                        : FS::Msgcat::_gettext('night');

    my $mobile_label = FS::Msgcat::_gettext('mobile') =~ /^(mobile)?$/
                        ? 'Mobile Phone'
                        : FS::Msgcat::_gettext('mobile');

    return "$daytime_label, $night_label or $mobile_label is required"
  
  }

  ### start of stuff moved to cust_payby
  # then mostly kept here to support upgrades (can remove in 5.x)
  #  but modified to allow everything to be empty

  if ( $self->payby ) {
    FS::payby->can_payby($self->table, $self->payby)
      or return "Illegal payby: ". $self->payby;
  } else {
    $self->payby('');
  }

  $error =    $self->ut_numbern('paystart_month')
           || $self->ut_numbern('paystart_year')
           || $self->ut_numbern('payissue')
           || $self->ut_textn('paytype')
  ;
  return $error if $error;

  if ( $self->payip eq '' ) {
    $self->payip('');
  } else {
    $error = $self->ut_ip('payip');
    return $error if $error;
  }

  # If it is encrypted and the private key is not availaible then we can't
  # check the credit card.
  my $check_payinfo = ! $self->is_encrypted($self->payinfo);

  # Need some kind of global flag to accept invalid cards, for testing
  # on scrubbed data.
  if ( !$import && !$ignore_invalid_card && $check_payinfo && 
    $self->payby =~ /^(CARD|DCRD)$/ ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $payinfo =~ /^(\d{13,16}|\d{8,9})$/
      or return gettext('invalid_card'); # . ": ". $self->payinfo;
    $payinfo = $1;
    $self->payinfo($payinfo);
    validate($payinfo)
      or return gettext('invalid_card'); # . ": ". $self->payinfo;

    return gettext('unknown_card_type')
      if $self->payinfo !~ /^99\d{14}$/ #token
      && cardtype($self->payinfo) eq "Unknown";

    unless ( $ignore_banned_card ) {
      my $ban = FS::banned_pay->ban_search( %{ $self->_banned_pay_hashref } );
      if ( $ban ) {
        if ( $ban->bantype eq 'warn' ) {
          #or others depending on value of $ban->reason ?
          return '_duplicate_card'.
                 ': disabled from'. time2str('%a %h %o at %r', $ban->_date).
                 ' until '.         time2str('%a %h %o at %r', $ban->_end_date).
                 ' (ban# '. $ban->bannum. ')'
            unless $self->override_ban_warn;
        } else {
          return 'Banned credit card: banned on '.
                 time2str('%a %h %o at %r', $ban->_date).
                 ' by '. $ban->otaker.
                 ' (ban# '. $ban->bannum. ')';
        }
      }
    }

    if (length($self->paycvv) && !$self->is_encrypted($self->paycvv)) {
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

    my $cardtype = cardtype($payinfo);
    if ( $cardtype =~ /^(Switch|Solo)$/i ) {

      return "Start date or issue number is required for $cardtype cards"
        unless $self->paystart_month && $self->paystart_year or $self->payissue;

      return "Start month must be between 1 and 12"
        if $self->paystart_month
           and $self->paystart_month < 1 || $self->paystart_month > 12;

      return "Start year must be 1990 or later"
        if $self->paystart_year
           and $self->paystart_year < 1990;

      return "Issue number must be beween 1 and 99"
        if $self->payissue
          and $self->payissue < 1 || $self->payissue > 99;

    } else {
      $self->paystart_month('');
      $self->paystart_year('');
      $self->payissue('');
    }

  } elsif ( !$ignore_invalid_card && $check_payinfo && 
    $self->payby =~ /^(CHEK|DCHK)$/ ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/[^\d\@\.]//g;
    if ( $conf->config('echeck-country') eq 'CA' ) {
      $payinfo =~ /^(\d+)\@(\d{5})\.(\d{3})$/
        or return 'invalid echeck account@branch.bank';
      $payinfo = "$1\@$2.$3";
    } elsif ( $conf->config('echeck-country') eq 'US' ) {
      $payinfo =~ /^(\d+)\@(\d{9})$/ or return 'invalid echeck account@aba';
      $payinfo = "$1\@$2";
    } else {
      $payinfo =~ /^(\d+)\@(\d+)$/ or return 'invalid echeck account@routing';
      $payinfo = "$1\@$2";
    }
    $self->payinfo($payinfo);
    $self->paycvv('');

    unless ( $ignore_banned_card ) {
      my $ban = FS::banned_pay->ban_search( %{ $self->_banned_pay_hashref } );
      if ( $ban ) {
        if ( $ban->bantype eq 'warn' ) {
          #or others depending on value of $ban->reason ?
          return '_duplicate_ach' unless $self->override_ban_warn;
        } else {
          return 'Banned ACH account: banned on '.
                 time2str('%a %h %o at %r', $ban->_date).
                 ' by '. $ban->otaker.
                 ' (ban# '. $ban->bannum. ')';
        }
      }
    }

  } elsif ( $self->payby eq 'LECB' ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $payinfo =~ /^1?(\d{10})$/ or return 'invalid btn billing telephone number';
    $payinfo = $1;
    $self->payinfo($payinfo);
    $self->paycvv('');

  } elsif ( $self->payby eq 'BILL' ) {

    $error = $self->ut_textn('payinfo');
    return "Illegal P.O. number: ". $self->payinfo if $error;
    $self->paycvv('');

  } elsif ( $self->payby eq 'COMP' ) {

    my $curuser = $FS::CurrentUser::CurrentUser;
    if (    ! $self->custnum
         && ! $curuser->access_right('Complimentary customer')
       )
    {
      return "You are not permitted to create complimentary accounts."
    }

    $error = $self->ut_textn('payinfo');
    return "Illegal comp account issuer: ". $self->payinfo if $error;
    $self->paycvv('');

  } elsif ( $self->payby eq 'PREPAY' ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\W//g; #anything else would just confuse things
    $self->payinfo($payinfo);
    $error = $self->ut_alpha('payinfo');
    return "Illegal prepayment identifier: ". $self->payinfo if $error;
    return "Unknown prepayment identifier"
      unless qsearchs('prepay_credit', { 'identifier' => $self->payinfo } );
    $self->paycvv('');

  }

  return "You are not permitted to create complimentary accounts."
    if ! $self->custnum
    && $self->complimentary eq 'Y'
    && ! $FS::CurrentUser::CurrentUser->access_right('Complimentary customer');

  if ( $self->paydate eq '' || $self->paydate eq '-' ) {
    return "Expiration date required"
      # shouldn't payinfo_check do this?
      unless ! $self->payby
            || $self->payby =~ /^(BILL|PREPAY|CHEK|DCHK|LECB|CASH|WEST|MCRD|PPAL)$/;
    $self->paydate('');
  } else {
    my( $m, $y );
    if ( $self->paydate =~ /^(\d{1,2})[\/\-](\d{2}(\d{2})?)$/ ) {
      ( $m, $y ) = ( $1, length($2) == 4 ? $2 : "20$2" );
    } elsif ( $self->paydate =~ /^19(\d{2})[\/\-](\d{1,2})[\/\-]\d+$/ ) {
      ( $m, $y ) = ( $2, "19$1" );
    } elsif ( $self->paydate =~ /^(20)?(\d{2})[\/\-](\d{1,2})[\/\-]\d+$/ ) {
      ( $m, $y ) = ( $3, "20$2" );
    } else {
      return "Illegal expiration date: ". $self->paydate;
    }
    $m = sprintf('%02d',$m);
    $self->paydate("$y-$m-01");
    my($nowm,$nowy)=(localtime(time))[4,5]; $nowm++; $nowy+=1900;
    return gettext('expired_card')
      if !$import
      && !$ignore_expired_card 
      && ( $y<$nowy || ( $y==$nowy && $1<$nowm ) );
  }

  if ( $self->payname eq '' && $self->payby !~ /^(CHEK|DCHK)$/ &&
       ( ! $conf->exists('require_cardname')
         || $self->payby !~ /^(CARD|DCRD)$/  ) 
  ) {
    $self->payname( $self->first. " ". $self->getfield('last') );
  } else {

    if ( $self->payby =~ /^(CHEK|DCHK)$/ ) {
      $self->payname =~ /^([\w \,\.\-\']*)$/
        or return gettext('illegal_name'). " payname: ". $self->payname;
      $self->payname($1);
    } else {
      $self->payname =~ /^([\w \,\.\-\'\&]*)$/
        or return gettext('illegal_name'). " payname: ". $self->payname;
      $self->payname($1);
    }

  }

  ### end of stuff moved to cust_payby

  return "Please select an invoicing locale"
    if ! $self->locale
    && ! $self->custnum
    && $conf->exists('cust_main-require_locale');

  return "Please select a customer class"
    if ! $self->classnum
    && $conf->exists('cust_main-require_classnum');

  foreach my $flag (qw( tax spool_cdr squelch_cdr archived email_csv_cdr )) {
    $self->$flag() =~ /^(Y?)$/ or return "Illegal $flag: ". $self->$flag();
    $self->$flag($1);
  }

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  warn "$me check AFTER: \n". $self->_dump
    if $DEBUG > 2;

  $self->SUPER::check;
}

sub check_payinfo_cardtype {
  my $self = shift;

  return '' unless $self->payby =~ /^(CARD|DCRD)$/;

  my $payinfo = $self->payinfo;
  $payinfo =~ s/\D//g;

  return '' if $payinfo =~ /^99\d{14}$/; #token

  my %bop_card_types = map { $_=>1 } values %{ card_types() };
  my $cardtype = cardtype($payinfo);

  return "$cardtype not accepted" unless $bop_card_types{$cardtype};

  '';

}

=item replace_check

Additional checks for replace only.

=cut

sub replace_check {
  my ($new,$old) = @_;
  #preserve old value if global config is set
  if ($old && $conf->exists('invoice-ship_address')) {
    $new->invoice_ship_address($old->invoice_ship_address);
  }
  return '';
}

=item addr_fields 

Returns a list of fields which have ship_ duplicates.

=cut

sub addr_fields {
  qw( last first company
      locationname
      address1 address2 city county state zip country
      latitude longitude
      daytime night fax mobile
    );
}

=item has_ship_address

Returns true if this customer record has a separate shipping address.

=cut

sub has_ship_address {
  my $self = shift;
  $self->bill_locationnum != $self->ship_locationnum;
}

=item location_hash

Returns a list of key/value pairs, with the following keys: address1, 
adddress2, city, county, state, zip, country, district, and geocode.  The 
shipping address is used if present.

=cut

sub location_hash {
  my $self = shift;
  $self->ship_location->location_hash;
}

=item cust_location

Returns all locations (see L<FS::cust_location>) for this customer.

=cut

sub cust_location {
  my $self = shift;
  qsearch({
    'table'   => 'cust_location',
    'hashref' => { 'custnum'     => $self->custnum,
                   'prospectnum' => '',
                 },
    'order_by' => 'ORDER BY country, LOWER(state), LOWER(city), LOWER(county), LOWER(address1), LOWER(address2)',
  });
}

=item cust_contact

Returns all contact associations (see L<FS::cust_contact>) for this customer.

=cut

sub cust_contact {
  my $self = shift;
  qsearch('cust_contact', { 'custnum' => $self->custnum } );
}

=item cust_payby PAYBY

Returns all payment methods (see L<FS::cust_payby>) for this customer.

If one or more PAYBY are specified, returns only payment methods for specified PAYBY.
Does not validate PAYBY.

=cut

sub cust_payby {
  my $self = shift;
  my @payby = @_;
  my $search = {
    'table'    => 'cust_payby',
    'hashref'  => { 'custnum' => $self->custnum },
    'order_by' => "ORDER BY payby IN ('CARD','CHEK') DESC, weight ASC",
  };
  $search->{'extra_sql'} = ' AND payby IN ( '.
                               join(',', map dbh->quote($_), @payby).
                             ' ) '
    if @payby;

  qsearch($search);
}

=item has_cust_payby_auto

Returns true if customer has an automatic payment method ('CARD' or 'CHEK')

=cut

sub has_cust_payby_auto {
  my $self = shift;
  scalar( qsearch({ 
    'table'     => 'cust_payby',
    'hashref'   => { 'custnum' => $self->custnum, },
    'extra_sql' => " AND payby IN ( 'CARD', 'CHEK' ) ",
    'order_by'  => 'LIMIT 1',
  }) );

}

=item unsuspend

Unsuspends all unflagged suspended packages (see L</unflagged_suspended_pkgs>
and L<FS::cust_pkg>) for this customer, except those on hold.

Returns a list: an empty list on success or a list of errors.

=cut

sub unsuspend {
  my $self = shift;
  grep { ($_->get('setup')) && $_->unsuspend } $self->suspended_pkgs;
}

=item release_hold

Unsuspends all suspended packages in the on-hold state (those without setup 
dates) for this customer. 

=cut

sub release_hold {
  my $self = shift;
  grep { (!$_->setup) && $_->unsuspend } $self->suspended_pkgs;
}

=item suspend

Suspends all unsuspended packages (see L<FS::cust_pkg>) for this customer.

Returns a list: an empty list on success or a list of errors.

=cut

sub suspend {
  my $self = shift;
  grep { $_->suspend(@_) } $self->unsuspended_pkgs;
}

=item suspend_if_pkgpart HASHREF | PKGPART [ , PKGPART ... ]

Suspends all unsuspended packages (see L<FS::cust_pkg>) matching the listed
PKGPARTs (see L<FS::part_pkg>).  Preferred usage is to pass a hashref instead
of a list of pkgparts; the hashref has the following keys:

=over 4

=item pkgparts - listref of pkgparts

=item (other options are passed to the suspend method)

=back


Returns a list: an empty list on success or a list of errors.

=cut

sub suspend_if_pkgpart {
  my $self = shift;
  my (@pkgparts, %opt);
  if (ref($_[0]) eq 'HASH'){
    @pkgparts = @{$_[0]{pkgparts}};
    %opt      = %{$_[0]};
  }else{
    @pkgparts = @_;
  }
  grep { $_->suspend(%opt) }
    grep { my $pkgpart = $_->pkgpart; grep { $pkgpart eq $_ } @pkgparts }
      $self->unsuspended_pkgs;
}

=item suspend_unless_pkgpart HASHREF | PKGPART [ , PKGPART ... ]

Suspends all unsuspended packages (see L<FS::cust_pkg>) unless they match the
given PKGPARTs (see L<FS::part_pkg>).  Preferred usage is to pass a hashref
instead of a list of pkgparts; the hashref has the following keys:

=over 4

=item pkgparts - listref of pkgparts

=item (other options are passed to the suspend method)

=back

Returns a list: an empty list on success or a list of errors.

=cut

sub suspend_unless_pkgpart {
  my $self = shift;
  my (@pkgparts, %opt);
  if (ref($_[0]) eq 'HASH'){
    @pkgparts = @{$_[0]{pkgparts}};
    %opt      = %{$_[0]};
  }else{
    @pkgparts = @_;
  }
  grep { $_->suspend(%opt) }
    grep { my $pkgpart = $_->pkgpart; ! grep { $pkgpart eq $_ } @pkgparts }
      $self->unsuspended_pkgs;
}

=item cancel [ OPTION => VALUE ... ]

Cancels all uncancelled packages (see L<FS::cust_pkg>) for this customer.
The cancellation time will be now.

=back

Always returns a list: an empty list on success or a list of errors.

=cut

sub cancel {
  my $self = shift;
  my %opt = @_;
  warn "$me cancel called on customer ". $self->custnum. " with options ".
       join(', ', map { "$_: $opt{$_}" } keys %opt ). "\n"
    if $DEBUG;
  my @pkgs = $self->ncancelled_pkgs;

  $self->cancel_pkgs( %opt, 'cust_pkg' => \@pkgs );
}

=item cancel_pkgs OPTIONS

Cancels a specified list of packages. OPTIONS can include:

=over 4

=item cust_pkg - an arrayref of the packages. Required.

=item time - the cancellation time, used to calculate final bills and
unused-time credits if any. Will be passed through to the bill() and
FS::cust_pkg::cancel() methods.

=item quiet - can be set true to supress email cancellation notices.

=item reason - can be set to a cancellation reason (see L<FS:reason>), either a
reasonnum of an existing reason, or passing a hashref will create a new reason.
The hashref should have the following keys:
typenum - Reason type (see L<FS::reason_type>)
reason - Text of the new reason.

=item cust_pkg_reason - can be an arrayref of L<FS::cust_pkg_reason> objects
for the individual packages, parallel to the C<cust_pkg> argument. The
reason and reason_otaker arguments will be taken from those objects.

=item ban - can be set true to ban this customer's credit card or ACH information, if present.

=item nobill - can be set true to skip billing if it might otherwise be done.

=cut

sub cancel_pkgs {
  my( $self, %opt ) = @_;

  # we're going to cancel services, which is not reversible
  die "cancel_pkgs cannot be run inside a transaction"
    if $FS::UID::AutoCommit == 0;

  local $FS::UID::AutoCommit = 0;

  return ( 'access denied' )
    unless $FS::CurrentUser::CurrentUser->access_right('Cancel customer');

  if ( $opt{'ban'} ) {

    foreach my $cust_payby ( $self->cust_payby ) {

      #well, if they didn't get decrypted on search, then we don't have to 
      # try again... queue a job for the server that does have decryption
      # capability if we're in a paranoid multi-server implementation?
      return ( "Can't (yet) ban encrypted credit cards" )
        if $cust_payby->is_encrypted($cust_payby->payinfo);

      my $ban = new FS::banned_pay $cust_payby->_new_banned_pay_hashref;
      my $error = $ban->insert;
      if ($error) {
        dbh->rollback;
        return ( $error );
      }

    }

  }

  my @pkgs = @{ delete $opt{'cust_pkg'} };
  my $cancel_time = $opt{'time'} || time;

  # bill all packages first, so we don't lose usage, service counts for
  # bulk billing, etc.
  if ( !$opt{nobill} && $conf->exists('bill_usage_on_cancel') ) {
    $opt{nobill} = 1;
    my $error = $self->bill( 'pkg_list' => [ @pkgs ],
                             'cancel'   => 1,
                             'time'     => $cancel_time );
    if ($error) {
      warn "Error billing during cancel, custnum ". $self->custnum. ": $error";
      dbh->rollback;
      return ( "Error billing during cancellation: $error" );
    }
  }
  dbh->commit;

  $FS::UID::AutoCommit = 1;
  my @errors;
  # now cancel all services, the same way we would for individual packages.
  # if any of them fail, cancel the rest anyway.
  my @cust_svc = map { $_->cust_svc } @pkgs;
  my @sorted_cust_svc =
    map  { $_->[0] }
    sort { $a->[1] <=> $b->[1] }
    map  { [ $_, $_->svc_x ? $_->svc_x->table_info->{'cancel_weight'} : -1 ]; } @cust_svc
  ;
  warn "$me removing ".scalar(@sorted_cust_svc)." service(s) for customer ".
    $self->custnum."\n"
    if $DEBUG;
  foreach my $cust_svc (@sorted_cust_svc) {
    my $part_svc = $cust_svc->part_svc;
    next if ( defined($part_svc) and $part_svc->preserve );
    my $error = $cust_svc->cancel; # immediate cancel, no date option
    push @errors, $error if $error;
  }
  if (@errors) {
    return @errors;
  }

  warn "$me cancelling ". scalar(@pkgs) ." package(s) for customer ".
    $self->custnum. "\n"
    if $DEBUG;

  my @cprs;
  if ($opt{'cust_pkg_reason'}) {
    @cprs = @{ delete $opt{'cust_pkg_reason'} };
  }
  my $null_reason;
  foreach (@pkgs) {
    my %lopt = %opt;
    if (@cprs) {
      my $cpr = shift @cprs;
      if ( $cpr ) {
        $lopt{'reason'}        = $cpr->reasonnum;
        $lopt{'reason_otaker'} = $cpr->otaker;
      } else {
        warn "no reason found when canceling package ".$_->pkgnum."\n";
        # we're not actually required to pass a reason to cust_pkg::cancel,
        # but if we're getting to this point, something has gone awry.
        $null_reason ||= FS::reason->new_or_existing(
          reason  => 'unknown reason',
          type    => 'Cancel Reason',
          class   => 'C',
        );
        $lopt{'reason'} = $null_reason->reasonnum;
        $lopt{'reason_otaker'} = $FS::CurrentUser::CurrentUser->username;
      }
    }
    my $error = $_->cancel(%lopt);
    push @errors, 'pkgnum '.$_->pkgnum.': '.$error if $error;
  }

  return @errors;
}

sub _banned_pay_hashref {
  my $self = shift;

  my %payby2ban = (
    'CARD' => 'CARD',
    'DCRD' => 'CARD',
    'CHEK' => 'CHEK',
    'DCHK' => 'CHEK'
  );

  {
    'payby'   => $payby2ban{$self->payby},
    'payinfo' => $self->payinfo,
    #don't ever *search* on reason! #'reason'  =>
  };
}

=item notes

Returns all notes (see L<FS::cust_main_note>) for this customer.

=cut

sub notes {
  my($self,$orderby_classnum) = (shift,shift);
  my $orderby = "sticky DESC, _date DESC";
  $orderby = "classnum ASC, $orderby" if $orderby_classnum;
  qsearch( 'cust_main_note',
           { 'custnum' => $self->custnum },
           '',
           "ORDER BY $orderby",
         );
}

=item agent

Returns the agent (see L<FS::agent>) for this customer.

=item agent_name

Returns the agent name (see L<FS::agent>) for this customer.

=cut

sub agent_name {
  my $self = shift;
  $self->agent->agent;
}

=item cust_tag

Returns any tags associated with this customer, as FS::cust_tag objects,
or an empty list if there are no tags.

=item part_tag

Returns any tags associated with this customer, as FS::part_tag objects,
or an empty list if there are no tags.

=cut

sub part_tag {
  my $self = shift;
  map $_->part_tag, $self->cust_tag; 
}


=item cust_class

Returns the customer class, as an FS::cust_class object, or the empty string
if there is no customer class.

=item categoryname 

Returns the customer category name, or the empty string if there is no customer
category.

=cut

sub categoryname {
  my $self = shift;
  my $cust_class = $self->cust_class;
  $cust_class
    ? $cust_class->categoryname
    : '';
}

=item classname 

Returns the customer class name, or the empty string if there is no customer
class.

=cut

sub classname {
  my $self = shift;
  my $cust_class = $self->cust_class;
  $cust_class
    ? $cust_class->classname
    : '';
}

=item tax_status

Returns the external tax status, as an FS::tax_status object, or the empty 
string if there is no tax status.

=cut

sub tax_status {
  my $self = shift;
  if ( $self->taxstatusnum ) {
    qsearchs('tax_status', { 'taxstatusnum' => $self->taxstatusnum } );
  } else {
    return '';
  } 
}

=item taxstatus

Returns the tax status code if there is one.

=cut

sub taxstatus {
  my $self = shift;
  my $tax_status = $self->tax_status;
  $tax_status
    ? $tax_status->taxstatus
    : '';
}

=item BILLING METHODS

Documentation on billing methods has been moved to
L<FS::cust_main::Billing>.

=item REALTIME BILLING METHODS

Documentation on realtime billing methods has been moved to
L<FS::cust_main::Billing_Realtime>.

=item remove_cvv

Removes the I<paycvv> field from the database directly.

If there is an error, returns the error, otherwise returns false.

DEPRECATED.  Use L</remove_cvv_from_cust_payby> instead.

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

  my $custnum = $self->custnum;

  my $owed_sql = FS::cust_bill->owed_sql;

  my $sql = "
    SELECT SUM($owed_sql) FROM cust_bill
      WHERE custnum = $custnum
        AND _date <= $time
  ";

  sprintf( "%.2f", $self->scalar_sql($sql) || 0 );

}

=item total_owed_pkgnum PKGNUM

Returns the total owed on all invoices for this customer's specific package
when using experimental package balances (see L<FS::cust_bill/owed_pkgnum>).

=cut

sub total_owed_pkgnum {
  my( $self, $pkgnum ) = @_;
  $self->total_owed_date_pkgnum(2145859200, $pkgnum); #12/31/2037
}

=item total_owed_date_pkgnum TIME PKGNUM

Returns the total owed for this customer's specific package when using
experimental package balances on all invoices with date earlier than
TIME.  TIME is specified as a UNIX timestamp; see L<perlfunc/"time">).  Also
see L<Time::Local> and L<Date::Parse> for conversion functions.

=cut

sub total_owed_date_pkgnum {
  my( $self, $time, $pkgnum ) = @_;

  my $total_bill = 0;
  foreach my $cust_bill (
    grep { $_->_date <= $time }
      qsearch('cust_bill', { 'custnum' => $self->custnum, } )
  ) {
    $total_bill += $cust_bill->owed_pkgnum($pkgnum);
  }
  sprintf( "%.2f", $total_bill );

}

=item total_paid

Returns the total amount of all payments.

=cut

sub total_paid {
  my $self = shift;
  my $total = 0;
  $total += $_->paid foreach $self->cust_pay;
  sprintf( "%.2f", $total );
}

=item total_unapplied_credits

Returns the total outstanding credit (see L<FS::cust_credit>) for this
customer.  See L<FS::cust_credit/credited>.

=item total_credited

Old name for total_unapplied_credits.  Don't use.

=cut

sub total_credited {
  #carp "total_credited deprecated, use total_unapplied_credits";
  shift->total_unapplied_credits(@_);
}

sub total_unapplied_credits {
  my $self = shift;

  my $custnum = $self->custnum;

  my $unapplied_sql = FS::cust_credit->unapplied_sql;

  my $sql = "
    SELECT SUM($unapplied_sql) FROM cust_credit
      WHERE custnum = $custnum
  ";

  sprintf( "%.2f", $self->scalar_sql($sql) || 0 );

}

=item total_unapplied_credits_pkgnum PKGNUM

Returns the total outstanding credit (see L<FS::cust_credit>) for this
customer.  See L<FS::cust_credit/credited>.

=cut

sub total_unapplied_credits_pkgnum {
  my( $self, $pkgnum ) = @_;
  my $total_credit = 0;
  $total_credit += $_->credited foreach $self->cust_credit_pkgnum($pkgnum);
  sprintf( "%.2f", $total_credit );
}


=item total_unapplied_payments

Returns the total unapplied payments (see L<FS::cust_pay>) for this customer.
See L<FS::cust_pay/unapplied>.

=cut

sub total_unapplied_payments {
  my $self = shift;

  my $custnum = $self->custnum;

  my $unapplied_sql = FS::cust_pay->unapplied_sql;

  my $sql = "
    SELECT SUM($unapplied_sql) FROM cust_pay
      WHERE custnum = $custnum
  ";

  sprintf( "%.2f", $self->scalar_sql($sql) || 0 );

}

=item total_unapplied_payments_pkgnum PKGNUM

Returns the total unapplied payments (see L<FS::cust_pay>) for this customer's
specific package when using experimental package balances.  See
L<FS::cust_pay/unapplied>.

=cut

sub total_unapplied_payments_pkgnum {
  my( $self, $pkgnum ) = @_;
  my $total_unapplied = 0;
  $total_unapplied += $_->unapplied foreach $self->cust_pay_pkgnum($pkgnum);
  sprintf( "%.2f", $total_unapplied );
}


=item total_unapplied_refunds

Returns the total unrefunded refunds (see L<FS::cust_refund>) for this
customer.  See L<FS::cust_refund/unapplied>.

=cut

sub total_unapplied_refunds {
  my $self = shift;
  my $custnum = $self->custnum;

  my $unapplied_sql = FS::cust_refund->unapplied_sql;

  my $sql = "
    SELECT SUM($unapplied_sql) FROM cust_refund
      WHERE custnum = $custnum
  ";

  sprintf( "%.2f", $self->scalar_sql($sql) || 0 );

}

=item balance

Returns the balance for this customer (total_owed plus total_unrefunded, minus
total_unapplied_credits minus total_unapplied_payments).

=cut

sub balance {
  my $self = shift;
  $self->balance_date_range;
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
  $self->balance_date_range(shift);
}

=item balance_date_range [ START_TIME [ END_TIME [ OPTION => VALUE ... ] ] ]

Returns the balance for this customer, optionally considering invoices with
date earlier than START_TIME, and not later than END_TIME
(total_owed_date minus total_unapplied_credits minus total_unapplied_payments).

Times are specified as SQL fragments or numeric
UNIX timestamps; see L<perlfunc/"time">).  Also see L<Time::Local> and
L<Date::Parse> for conversion functions.  The empty string can be passed
to disable that time constraint completely.

Accepts the same options as L<balance_date_sql>:

=over 4

=item unapplied_date

set to true to disregard unapplied credits, payments and refunds outside the specified time period - by default the time period restriction only applies to invoices (useful for reporting, probably a bad idea for event triggering)

=item cutoff

An absolute cutoff time.  Payments, credits, and refunds I<applied> after this 
time will be ignored.  Note that START_TIME and END_TIME only limit the date 
range for invoices and I<unapplied> payments, credits, and refunds.

=back

=cut

sub balance_date_range {
  my $self = shift;
  my $sql = 'SELECT SUM('. $self->balance_date_sql(@_).
            ') FROM cust_main WHERE custnum='. $self->custnum;
  sprintf( '%.2f', $self->scalar_sql($sql) || 0 );
}

=item balance_pkgnum PKGNUM

Returns the balance for this customer's specific package when using
experimental package balances (total_owed plus total_unrefunded, minus
total_unapplied_credits minus total_unapplied_payments)

=cut

sub balance_pkgnum {
  my( $self, $pkgnum ) = @_;

  sprintf( "%.2f",
      $self->total_owed_pkgnum($pkgnum)
# n/a - refunds aren't part of pkg-balances since they don't apply to invoices
#    + $self->total_unapplied_refunds_pkgnum($pkgnum)
    - $self->total_unapplied_credits_pkgnum($pkgnum)
    - $self->total_unapplied_payments_pkgnum($pkgnum)
  );
}

=item payment_info

Returns a hash of useful information for making a payment.

=over 4

=item balance

Current balance.

=item payby

'CARD' (credit card - automatic), 'DCRD' (credit card - on-demand),
'CHEK' (electronic check - automatic), 'DCHK' (electronic check - on-demand),
'LECB' (Phone bill billing), 'BILL' (billing), or 'COMP' (free).

=back

For credit card transactions:

=over 4

=item card_type 1

=item payname

Exact name on card

=back

For electronic check transactions:

=over 4

=item stateid_state

=back

=cut

sub payment_info {
  my $self = shift;

  my %return = ();

  $return{balance} = $self->balance;

  $return{payname} = $self->payname
                     || ( $self->first. ' '. $self->get('last') );

  $return{$_} = $self->bill_location->$_
    for qw(address1 address2 city state zip);

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

=item paydate_epoch

Returns the next payment expiration date for this customer. If they have no
payment methods that will expire, returns 0.

=cut

sub paydate_epoch {
  my $self = shift;
  # filter out the ones that individually return 0, but then return 0 if
  # there are no results
  my @epochs = grep { $_ > 0 } map { $_->paydate_epoch } $self->cust_payby;
  min( @epochs ) || 0;
}

=item paydate_epoch_sql

Returns an SQL expression to get the next payment expiration date for a
customer. Returns 2143260000 (2037-12-01) if there are no payment expiration
dates, so that it's safe to test for "will it expire before date X" for any
date up to then.

=cut

sub paydate_epoch_sql {
  my $class = shift;
  my $paydate = FS::cust_payby->paydate_epoch_sql;
  "(SELECT COALESCE(MIN($paydate), 2143260000) FROM cust_payby WHERE cust_payby.custnum = cust_main.custnum)";
}

sub tax_exemption {
  my( $self, $taxname ) = @_;

  qsearchs( 'cust_main_exemption', { 'custnum' => $self->custnum,
                                     'taxname' => $taxname,
                                   },
          );
}

=item cust_main_exemption

=item invoicing_list

Returns a list of email addresses (with svcnum entries expanded), and the word
'POST' if the customer receives postal invoices.

=cut

sub invoicing_list {
  my( $self, $arrayref ) = @_;

  if ( $arrayref ) {
    warn "FS::cust_main::invoicing_list(ARRAY) is no longer supported.";
  }
  
  my @emails = $self->invoicing_list_emailonly;
  push @emails, 'POST' if $self->get('postal_invoice');

  @emails;
}

=item check_invoicing_list ARRAYREF

Checks these arguements as valid input for the invoicing_list method.  If there
is an error, returns the error, otherwise returns false.

=cut

sub check_invoicing_list {
  my( $self, $arrayref ) = @_;

  foreach my $address ( @$arrayref ) {

    if ($address eq 'FAX' and $self->getfield('fax') eq '') {
      return 'Can\'t add FAX invoice destination with a blank FAX number.';
    }

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

  return "Email address required"
    if $conf->exists('cust_main-require_invoicing_list_email', $self->agentnum)
    && ! grep { $_ !~ /^([A-Z]+)$/ } @$arrayref;

  '';
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
  if ( $self->get('postal_invoice') eq '' ) {
    $self->set('postal_invoice', 'Y');
    my $error = $self->replace;
    warn $error if $error; # should fail harder, but this is traditional
  }
}

=item invoicing_list_emailonly

Returns the list of email invoice recipients (invoicing_list without non-email
destinations such as POST and FAX).

=cut

sub invoicing_list_emailonly {
  my $self = shift;
  warn "$me invoicing_list_emailonly called"
    if $DEBUG;
  return () if !$self->custnum; # not yet inserted
  return map { $_->emailaddress }
    qsearch({
        table     => 'cust_contact',
        select    => 'emailaddress',
        addl_from => ' JOIN contact USING (contactnum) '.
                     ' JOIN contact_email USING (contactnum)',
        hashref   => { 'custnum' => $self->custnum, },
        extra_sql => q( AND cust_contact.invoice_dest = 'Y'),
    });
}

=item invoicing_list_emailonly_scalar

Returns the list of email invoice recipients (invoicing_list without non-email
destinations such as POST and FAX) as a comma-separated scalar.

=cut

sub invoicing_list_emailonly_scalar {
  my $self = shift;
  warn "$me invoicing_list_emailonly_scalar called"
    if $DEBUG;
  join(', ', $self->invoicing_list_emailonly);
}

=item contact_list [ CLASSNUM, ... ]

Returns a list of contacts (L<FS::contact> objects) for the customer. If
a list of contact classnums is given, returns only contacts in those
classes. If the pseudo-classnum 'invoice' is given, returns contacts that
are marked as invoice destinations. If '0' is given, also returns contacts
with no class.

If no arguments are given, returns all contacts for the customer.

=cut

sub contact_list {
  my $self = shift;
  my $search = {
    table       => 'contact',
    select      => 'contact.*, cust_contact.invoice_dest',
    addl_from   => ' JOIN cust_contact USING (contactnum)',
    extra_sql   => ' WHERE cust_contact.custnum = '.$self->custnum,
  };

  my @orwhere;
  my @classnums;
  foreach (@_) {
    if ( $_ eq 'invoice' ) {
      push @orwhere, 'cust_contact.invoice_dest = \'Y\'';
    } elsif ( $_ eq '0' ) {
      push @orwhere, 'cust_contact.classnum is null';
    } elsif ( /^\d+$/ ) {
      push @classnums, $_;
    } else {
      die "bad classnum argument '$_'";
    }
  }

  if (@classnums) {
    push @orwhere, 'cust_contact.classnum IN ('.join(',', @classnums).')';
  }
  if (@orwhere) {
    $search->{extra_sql} .= ' AND (' .
                            join(' OR ', map "( $_ )", @orwhere) .
                            ')';
  }

  qsearch($search);
}

=item contact_list_email [ CLASSNUM, ... ]

Same as L</contact_list>, but returns email destinations instead of contact
objects.

=cut

sub contact_list_email {
  my $self = shift;
  my @contacts = $self->contact_list(@_);
  my @emails;
  foreach my $contact (@contacts) {
    foreach my $contact_email ($contact->contact_email) {
      push @emails,  Email::Address->new( $contact->firstlast,
                                          $contact_email->emailaddress
                     )->format;
    }
  }
  @emails;
}

=item referral_custnum_cust_main

Returns the customer who referred this customer (or the empty string, if
this customer was not referred).

Note the difference with referral_cust_main method: This method,
referral_custnum_cust_main returns the single customer (if any) who referred
this customer, while referral_cust_main returns an array of customers referred
BY this customer.

=cut

sub referral_custnum_cust_main {
  my $self = shift;
  return '' unless $self->referral_custnum;
  qsearchs('cust_main', { 'custnum' => $self->referral_custnum } );
}

=item referral_cust_main [ DEPTH [ EXCLUDE_HASHREF ] ]

Returns an array of customers referred by this customer (referral_custnum set
to this custnum).  If DEPTH is given, recurses up to the given depth, returning
customers referred by customers referred by this customer and so on, inclusive.
The default behavior is DEPTH 1 (no recursion).

Note the difference with referral_custnum_cust_main method: This method,
referral_cust_main, returns an array of customers referred BY this customer,
while referral_custnum_cust_main returns the single customer (if any) who
referred this customer.

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
be useful for commission calculations (perhaps after a C<grep { my $pkgpart = $_->pkgpart; grep { $_ == $pkgpart } @commission_worthy_pkgparts> } $cust_main-> ).

=cut

sub referral_cust_pkg {
  my $self = shift;
  my $depth = @_ ? shift : 1;

  map { $_->unsuspended_pkgs }
    grep { $_->unsuspended_pkgs }
      $self->referral_cust_main($depth);
}

=item referring_cust_main

Returns the single cust_main record for the customer who referred this customer
(referral_custnum), or false.

=cut

sub referring_cust_main {
  my $self = shift;
  return '' unless $self->referral_custnum;
  qsearchs('cust_main', { 'custnum' => $self->referral_custnum } );
}

=item credit AMOUNT, REASON [ , OPTION => VALUE ... ]

Applies a credit to this customer.  If there is an error, returns the error,
otherwise returns false.

REASON can be a text string, an FS::reason object, or a scalar reference to
a reasonnum.  If a text string, it will be automatically inserted as a new
reason, and a 'reason_type' option must be passed to indicate the
FS::reason_type for the new reason.

An I<addlinfo> option may be passed to set the credit's I<addlinfo> field.
Likewise for I<eventnum>, I<commission_agentnum>, I<commission_salesnum> and
I<commission_pkgnum>.

Any other options are passed to FS::cust_credit::insert.

=cut

sub credit {
  my( $self, $amount, $reason, %options ) = @_;

  my $cust_credit = new FS::cust_credit {
    'custnum' => $self->custnum,
    'amount'  => $amount,
  };

  if ( ref($reason) ) {

    if ( ref($reason) eq 'SCALAR' ) {
      $cust_credit->reasonnum( $$reason );
    } else {
      $cust_credit->reasonnum( $reason->reasonnum );
    }

  } else {
    $cust_credit->set('reason', $reason)
  }

  $cust_credit->$_( delete $options{$_} )
    foreach grep exists($options{$_}),
              qw( addlinfo eventnum ),
              map "commission_$_", qw( agentnum salesnum pkgnum );

  $cust_credit->insert(%options);

}

=item charge HASHREF || AMOUNT [ PKG [ COMMENT [ TAXCLASS ] ] ]

Creates a one-time charge for this customer.  If there is an error, returns
the error, otherwise returns false.

New-style, with a hashref of options:

  my $error = $cust_main->charge(
                                  {
                                    'amount'     => 54.32,
                                    'quantity'   => 1,
                                    'start_date' => str2time('7/4/2009'),
                                    'pkg'        => 'Description',
                                    'comment'    => 'Comment',
                                    'additional' => [], #extra invoice detail
                                    'classnum'   => 1,  #pkg_class

                                    'setuptax'   => '', # or 'Y' for tax exempt

                                    'locationnum'=> 1234, # optional

                                    #internal taxation
                                    'taxclass'   => 'Tax class',

                                    #vendor taxation
                                    'taxproduct' => 2,  #part_pkg_taxproduct
                                    'override'   => {}, #XXX describe

                                    #will be filled in with the new object
                                    'cust_pkg_ref' => \$cust_pkg,

                                    #generate an invoice immediately
                                    'bill_now' => 0,
                                    'invoice_terms' => '', #with these terms
                                  }
                                );

Old-style:

  my $error = $cust_main->charge( 54.32, 'Description', 'Comment', 'Tax class' );

=cut

#super false laziness w/quotation::charge
sub charge {
  my $self = shift;
  my ( $amount, $setup_cost, $quantity, $start_date, $classnum );
  my ( $pkg, $comment, $additional );
  my ( $setuptax, $taxclass );   #internal taxes
  my ( $taxproduct, $override ); #vendor (CCH) taxes
  my $no_auto = '';
  my $separate_bill = '';
  my $cust_pkg_ref = '';
  my ( $bill_now, $invoice_terms ) = ( 0, '' );
  my $locationnum;
  if ( ref( $_[0] ) ) {
    $amount     = $_[0]->{amount};
    $setup_cost = $_[0]->{setup_cost};
    $quantity   = exists($_[0]->{quantity}) ? $_[0]->{quantity} : 1;
    $start_date = exists($_[0]->{start_date}) ? $_[0]->{start_date} : '';
    $no_auto    = exists($_[0]->{no_auto}) ? $_[0]->{no_auto} : '';
    $pkg        = exists($_[0]->{pkg}) ? $_[0]->{pkg} : 'One-time charge';
    $comment    = exists($_[0]->{comment}) ? $_[0]->{comment}
                                           : '$'. sprintf("%.2f",$amount);
    $setuptax   = exists($_[0]->{setuptax}) ? $_[0]->{setuptax} : '';
    $taxclass   = exists($_[0]->{taxclass}) ? $_[0]->{taxclass} : '';
    $classnum   = exists($_[0]->{classnum}) ? $_[0]->{classnum} : '';
    $additional = $_[0]->{additional} || [];
    $taxproduct = $_[0]->{taxproductnum};
    $override   = { '' => $_[0]->{tax_override} };
    $cust_pkg_ref = exists($_[0]->{cust_pkg_ref}) ? $_[0]->{cust_pkg_ref} : '';
    $bill_now = exists($_[0]->{bill_now}) ? $_[0]->{bill_now} : '';
    $invoice_terms = exists($_[0]->{invoice_terms}) ? $_[0]->{invoice_terms} : '';
    $locationnum = $_[0]->{locationnum} || $self->ship_locationnum;
    $separate_bill = $_[0]->{separate_bill} || '';
  } else { # yuck
    $amount     = shift;
    $setup_cost = '';
    $quantity   = 1;
    $start_date = '';
    $pkg        = @_ ? shift : 'One-time charge';
    $comment    = @_ ? shift : '$'. sprintf("%.2f",$amount);
    $setuptax   = '';
    $taxclass   = @_ ? shift : '';
    $additional = [];
  }

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
    'pkg'           => $pkg,
    'comment'       => $comment,
    'plan'          => 'flat',
    'freq'          => 0,
    'disabled'      => 'Y',
    'classnum'      => ( $classnum ? $classnum : '' ),
    'setuptax'      => $setuptax,
    'taxclass'      => $taxclass,
    'taxproductnum' => $taxproduct,
    'setup_cost'    => $setup_cost,
  } );

  my %options = ( ( map { ("additional_info$_" => $additional->[$_] ) }
                        ( 0 .. @$additional - 1 )
                  ),
                  'additional_count' => scalar(@$additional),
                  'setup_fee' => $amount,
                );

  my $error = $part_pkg->insert( options       => \%options,
                                 tax_overrides => $override,
                               );
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
    'custnum'    => $self->custnum,
    'pkgpart'    => $pkgpart,
    'quantity'   => $quantity,
    'start_date' => $start_date,
    'no_auto'    => $no_auto,
    'separate_bill' => $separate_bill,
    'locationnum'=> $locationnum,
  } );

  $error = $cust_pkg->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  } elsif ( $cust_pkg_ref ) {
    ${$cust_pkg_ref} = $cust_pkg;
  }

  if ( $bill_now ) {
    my $error = $self->bill( 'invoice_terms' => $invoice_terms,
                             'pkg_list'      => [ $cust_pkg ],
                           );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }   
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  return '';

}

#=item charge_postal_fee
#
#Applies a one time charge this customer.  If there is an error,
#returns the error, returns the cust_pkg charge object or false
#if there was no charge.
#
#=cut
#
# This should be a customer event.  For that to work requires that bill
# also be a customer event.

sub charge_postal_fee {
  my $self = shift;

  my $pkgpart = $conf->config('postal_invoice-fee_pkgpart', $self->agentnum);
  return '' unless ($pkgpart && grep { $_ eq 'POST' } $self->invoicing_list);

  my $cust_pkg = new FS::cust_pkg ( {
    'custnum'  => $self->custnum,
    'pkgpart'  => $pkgpart,
    'quantity' => 1,
  } );

  my $error = $cust_pkg->insert;
  $error ? $error : $cust_pkg;
}

=item num_cust_attachment_deleted

Returns the number of deleted attachments for this customer (see
L<FS::num_cust_attachment>).

=cut

sub num_cust_attachments_deleted {
  my $self = shift;
  $self->scalar_sql(
    " SELECT COUNT(*) FROM cust_attachment ".
      " WHERE custnum = ? AND disabled IS NOT NULL AND disabled > 0",
    $self->custnum
  );
}

=item cust_bill [ OPTION => VALUE... | EXTRA_QSEARCH_PARAMS_HASHREF ]

Returns all the invoices (see L<FS::cust_bill>) for this customer.

Optionally, a list or hashref of additional arguments to the qsearch call can
be passed.

=cut

sub cust_bill {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };

  #return $self->num_cust_bill unless wantarray || keys %$opt;

  $opt->{'table'} = 'cust_bill';
  $opt->{'hashref'} ||= {}; #i guess it would autovivify anyway...
  $opt->{'hashref'}{'custnum'} = $self->custnum;
  $opt->{'order_by'} ||= 'ORDER BY _date ASC';

  map { $_ } #behavior of sort undefined in scalar context
    sort { $a->_date <=> $b->_date }
      qsearch($opt);
}

=item open_cust_bill

Returns all the open (owed > 0) invoices (see L<FS::cust_bill>) for this
customer.

=cut

sub open_cust_bill {
  my $self = shift;

  $self->cust_bill(
    'extra_sql' => ' AND '. FS::cust_bill->owed_sql. ' > 0',
    #@_
  );

}

=item legacy_cust_bill [ OPTION => VALUE... | EXTRA_QSEARCH_PARAMS_HASHREF ]

Returns all the legacy invoices (see L<FS::legacy_cust_bill>) for this customer.

=cut

sub legacy_cust_bill {
  my $self = shift;

  #return $self->num_legacy_cust_bill unless wantarray;

  map { $_ } #behavior of sort undefined in scalar context
    sort { $a->_date <=> $b->_date }
      qsearch({ 'table'    => 'legacy_cust_bill',
                'hashref'  => { 'custnum' => $self->custnum, },
                'order_by' => 'ORDER BY _date ASC',
             });
}

=item cust_statement [ OPTION => VALUE... | EXTRA_QSEARCH_PARAMS_HASHREF ]

Returns all the statements (see L<FS::cust_statement>) for this customer.

Optionally, a list or hashref of additional arguments to the qsearch call can
be passed.

=cut

=item cust_bill_void

Returns all the voided invoices (see L<FS::cust_bill_void>) for this customer.

=cut

sub cust_bill_void {
  my $self = shift;

  map { $_ } #return $self->num_cust_bill_void unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_bill_void', { 'custnum' => $self->custnum } )
}

sub cust_statement {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };

  #return $self->num_cust_statement unless wantarray || keys %$opt;

  $opt->{'table'} = 'cust_statement';
  $opt->{'hashref'} ||= {}; #i guess it would autovivify anyway...
  $opt->{'hashref'}{'custnum'} = $self->custnum;
  $opt->{'order_by'} ||= 'ORDER BY _date ASC';

  map { $_ } #behavior of sort undefined in scalar context
    sort { $a->_date <=> $b->_date }
      qsearch($opt);
}

=item svc_x SVCDB [ OPTION => VALUE | EXTRA_QSEARCH_PARAMS_HASHREF ]

Returns all services of type SVCDB (such as 'svc_acct') for this customer.  

Optionally, a list or hashref of additional arguments to the qsearch call can 
be passed following the SVCDB.

=cut

sub svc_x {
  my $self = shift;
  my $svcdb = shift;
  if ( ! $svcdb =~ /^svc_\w+$/ ) {
    warn "$me svc_x requires a svcdb";
    return;
  }
  my $opt = ref($_[0]) ? shift : { @_ };

  $opt->{'table'} = $svcdb;
  $opt->{'addl_from'} = 
    'LEFT JOIN cust_svc USING (svcnum) LEFT JOIN cust_pkg USING (pkgnum) '.
    ($opt->{'addl_from'} || '');

  my $custnum = $self->custnum;
  $custnum =~ /^\d+$/ or die "bad custnum '$custnum'";
  my $where = "cust_pkg.custnum = $custnum";

  my $extra_sql = $opt->{'extra_sql'} || '';
  if ( keys %{ $opt->{'hashref'} } ) {
    $extra_sql = " AND $where $extra_sql";
  }
  else {
    if ( $opt->{'extra_sql'} =~ /^\s*where\s(.*)/si ) {
      $extra_sql = "WHERE $where AND $1";
    }
    else {
      $extra_sql = "WHERE $where $extra_sql";
    }
  }
  $opt->{'extra_sql'} = $extra_sql;

  qsearch($opt);
}

# required for use as an eventtable; 
sub svc_acct {
  my $self = shift;
  $self->svc_x('svc_acct', @_);
}

=item cust_credit

Returns all the credits (see L<FS::cust_credit>) for this customer.

=cut

sub cust_credit {
  my $self = shift;

  #return $self->num_cust_credit unless wantarray;

  map { $_ } #behavior of sort undefined in scalar context
    sort { $a->_date <=> $b->_date }
      qsearch( 'cust_credit', { 'custnum' => $self->custnum } )
}

=item cust_credit_pkgnum

Returns all the credits (see L<FS::cust_credit>) for this customer's specific
package when using experimental package balances.

=cut

sub cust_credit_pkgnum {
  my( $self, $pkgnum ) = @_;
  map { $_ } #return $self->num_cust_credit_pkgnum($pkgnum) unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_credit', { 'custnum' => $self->custnum,
                              'pkgnum'  => $pkgnum,
                            }
    );
}

=item cust_credit_void

Returns all voided credits (see L<FS::cust_credit_void>) for this customer.

=cut

sub cust_credit_void {
  my $self = shift;
  map { $_ }
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_credit_void', { 'custnum' => $self->custnum } )
}

=item cust_pay

Returns all the payments (see L<FS::cust_pay>) for this customer.

=cut

sub cust_pay {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };

  return $self->num_cust_pay unless wantarray || keys %$opt;

  $opt->{'table'} = 'cust_pay';
  $opt->{'hashref'}{'custnum'} = $self->custnum;

  map { $_ } #behavior of sort undefined in scalar context
    sort { $a->_date <=> $b->_date }
      qsearch($opt);

}

=item num_cust_pay

Returns the number of payments (see L<FS::cust_pay>) for this customer.  Also
called automatically when the cust_pay method is used in a scalar context.

=cut

sub num_cust_pay {
  my $self = shift;
  my $sql = "SELECT COUNT(*) FROM cust_pay WHERE custnum = ?";
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute($self->custnum) or die $sth->errstr;
  $sth->fetchrow_arrayref->[0];
}

=item unapplied_cust_pay

Returns all the unapplied payments (see L<FS::cust_pay>) for this customer.

=cut

sub unapplied_cust_pay {
  my $self = shift;

  $self->cust_pay(
    'extra_sql' => ' AND '. FS::cust_pay->unapplied_sql. ' > 0',
    #@_
  );

}

=item cust_pay_pkgnum

Returns all the payments (see L<FS::cust_pay>) for this customer's specific
package when using experimental package balances.

=cut

sub cust_pay_pkgnum {
  my( $self, $pkgnum ) = @_;
  map { $_ } #return $self->num_cust_pay_pkgnum($pkgnum) unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_pay', { 'custnum' => $self->custnum,
                           'pkgnum'  => $pkgnum,
                         }
    );
}

=item cust_pay_void

Returns all voided payments (see L<FS::cust_pay_void>) for this customer.

=cut

sub cust_pay_void {
  my $self = shift;
  map { $_ } #return $self->num_cust_pay_void unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_pay_void', { 'custnum' => $self->custnum } )
}

=item cust_pay_pending

Returns all pending payments (see L<FS::cust_pay_pending>) for this customer
(without status "done").

=cut

sub cust_pay_pending {
  my $self = shift;
  return $self->num_cust_pay_pending unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_pay_pending', {
                                   'custnum' => $self->custnum,
                                   'status'  => { op=>'!=', value=>'done' },
                                 },
           );
}

=item cust_pay_pending_attempt

Returns all payment attempts / declined payments for this customer, as pending
payments objects (see L<FS::cust_pay_pending>), with status "done" but without
a corresponding payment (see L<FS::cust_pay>).

=cut

sub cust_pay_pending_attempt {
  my $self = shift;
  return $self->num_cust_pay_pending_attempt unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_pay_pending', {
                                   'custnum' => $self->custnum,
                                   'status'  => 'done',
                                   'paynum'  => '',
                                 },
           );
}

=item num_cust_pay_pending

Returns the number of pending payments (see L<FS::cust_pay_pending>) for this
customer (without status "done").  Also called automatically when the
cust_pay_pending method is used in a scalar context.

=cut

sub num_cust_pay_pending {
  my $self = shift;
  $self->scalar_sql(
    " SELECT COUNT(*) FROM cust_pay_pending ".
      " WHERE custnum = ? AND status != 'done' ",
    $self->custnum
  );
}

=item num_cust_pay_pending_attempt

Returns the number of pending payments (see L<FS::cust_pay_pending>) for this
customer, with status "done" but without a corresp.  Also called automatically when the
cust_pay_pending method is used in a scalar context.

=cut

sub num_cust_pay_pending_attempt {
  my $self = shift;
  $self->scalar_sql(
    " SELECT COUNT(*) FROM cust_pay_pending ".
      " WHERE custnum = ? AND status = 'done' AND paynum IS NULL",
    $self->custnum
  );
}

=item cust_refund

Returns all the refunds (see L<FS::cust_refund>) for this customer.

=cut

sub cust_refund {
  my $self = shift;
  map { $_ } #return $self->num_cust_refund unless wantarray;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_refund', { 'custnum' => $self->custnum } )
}

=item display_custnum

Returns the displayed customer number for this customer: agent_custid if
cust_main-default_agent_custid is set and it has a value, custnum otherwise.

=cut

sub display_custnum {
  my $self = shift;

  return $self->agent_custid
    if $default_agent_custid && $self->agent_custid;

  my $prefix = $conf->config('cust_main-custnum-display_prefix', $self->agentnum) || '';

  if ( $prefix ) {
    return $prefix . 
           sprintf('%0'.($custnum_display_length||8).'d', $self->custnum)
  } elsif ( $custnum_display_length ) {
    return sprintf('%0'.$custnum_display_length.'d', $self->custnum);
  } else {
    return $self->custnum;
  }
}

=item name

Returns a name string for this customer, either "Company (Last, First)" or
"Last, First".

=cut

sub name {
  my $self = shift;
  my $name = $self->contact;
  $name = $self->company. " ($name)" if $self->company;
  $name;
}

=item service_contact

Returns the L<FS::contact> object for this customer that has the 'Service'
contact class, or undef if there is no such contact.  Deprecated; don't use
this in new code.

=cut

sub service_contact {
  my $self = shift;
  if ( !exists($self->{service_contact}) ) {
    my $classnum = $self->scalar_sql(
      'SELECT classnum FROM contact_class WHERE classname = \'Service\''
    ) || 0; #if it's zero, qsearchs will return nothing
    my $cust_contact = qsearchs('cust_contact', { 
        'classnum' => $classnum,
        'custnum'  => $self->custnum,
    });
    $self->{service_contact} = $cust_contact->contact if $cust_contact;
  }
  $self->{service_contact};
}

=item ship_name

Returns a name string for this (service/shipping) contact, either
"Company (Last, First)" or "Last, First".

=cut

sub ship_name {
  my $self = shift;

  my $name = $self->ship_contact;
  $name = $self->company. " ($name)" if $self->company;
  $name;
}

=item name_short

Returns a name string for this customer, either "Company" or "First Last".

=cut

sub name_short {
  my $self = shift;
  $self->company !~ /^\s*$/ ? $self->company : $self->contact_firstlast;
}

=item ship_name_short

Returns a name string for this (service/shipping) contact, either "Company"
or "First Last".

=cut

sub ship_name_short {
  my $self = shift;
  $self->service_contact 
    ? $self->ship_contact_firstlast 
    : $self->name_short
}

=item contact

Returns this customer's full (billing) contact name only, "Last, First"

=cut

sub contact {
  my $self = shift;
  $self->get('last'). ', '. $self->first;
}

=item ship_contact

Returns this customer's full (shipping) contact name only, "Last, First"

=cut

sub ship_contact {
  my $self = shift;
  my $contact = $self->service_contact || $self;
  $contact->get('last') . ', ' . $contact->get('first');
}

=item contact_firstlast

Returns this customers full (billing) contact name only, "First Last".

=cut

sub contact_firstlast {
  my $self = shift;
  $self->first. ' '. $self->get('last');
}

=item ship_contact_firstlast

Returns this customer's full (shipping) contact name only, "First Last".

=cut

sub ship_contact_firstlast {
  my $self = shift;
  my $contact = $self->service_contact || $self;
  $contact->get('first') . ' '. $contact->get('last');
}

sub bill_country_full {
  my $self = shift;
  $self->bill_location->country_full;
}

sub ship_country_full {
  my $self = shift;
  $self->ship_location->country_full;
}

=item county_state_county [ PREFIX ]

Returns a string consisting of just the county, state and country.

=cut

sub county_state_country {
  my $self = shift;
  my $locationnum;
  if ( @_ && $_[0] && $self->has_ship_address ) {
    $locationnum = $self->ship_locationnum;
  } else {
    $locationnum = $self->bill_locationnum;
  }
  my $cust_location = qsearchs('cust_location', { locationnum=>$locationnum });
  $cust_location->county_state_country;
}

=item geocode DATA_VENDOR

Returns a value for the customer location as encoded by DATA_VENDOR.
Currently this only makes sense for "CCH" as DATA_VENDOR.

=cut

=item cust_status

=item status

Returns a status string for this customer, currently:

=over 4

=item prospect

No packages have ever been ordered.  Displayed as "No packages".

=item ordered

Recurring packages all are new (not yet billed).

=item active

One or more recurring packages is active.

=item inactive

No active recurring packages, but otherwise unsuspended/uncancelled (the inactive status is new - previously inactive customers were mis-identified as cancelled).

=item suspended

All non-cancelled recurring packages are suspended.

=item cancelled

All recurring packages are cancelled.

=back

Behavior of inactive vs. cancelled edge cases can be adjusted with the
cust_main-status_module configuration option.

=cut

sub status { shift->cust_status(@_); }

sub cust_status {
  my $self = shift;
  return $self->hashref->{cust_status} if $self->hashref->{cust_status};
  for my $status ( FS::cust_main->statuses() ) {
    my $method = $status.'_sql';
    my $numnum = ( my $sql = $self->$method() ) =~ s/cust_main\.custnum/?/g;
    my $sth = dbh->prepare("SELECT $sql") or die dbh->errstr;
    $sth->execute( ($self->custnum) x $numnum )
      or die "Error executing 'SELECT $sql': ". $sth->errstr;
    if ( $sth->fetchrow_arrayref->[0] ) {
      $self->hashref->{cust_status} = $status;
      return $status;
    }
  }
}

=item is_status_delay_cancel

Returns true if customer status is 'suspended'
and all suspended cust_pkg return true for
cust_pkg->is_status_delay_cancel.

This is not a real status, this only meant for hacking display 
values, because otherwise treating the customer as suspended is 
really the whole point of the delay_cancel option.

=cut

sub is_status_delay_cancel {
  my ($self) = @_;
  return 0 unless $self->status eq 'suspended';
  foreach my $cust_pkg ($self->ncancelled_pkgs) {
    return 0 unless $cust_pkg->is_status_delay_cancel;
  }
  return 1;
}

=item ucfirst_cust_status

=item ucfirst_status

Deprecated, use the cust_status_label method instead.

Returns the status with the first character capitalized.

=cut

sub ucfirst_status {
  carp "ucfirst_status deprecated, use cust_status_label" unless $ucfirst_nowarn;
  local($ucfirst_nowarn) = 1;
  shift->ucfirst_cust_status(@_);
}

sub ucfirst_cust_status {
  carp "ucfirst_cust_status deprecated, use cust_status_label" unless $ucfirst_nowarn;
  my $self = shift;
  ucfirst($self->cust_status);
}

=item cust_status_label

=item status_label

Returns the display label for this status.

=cut

sub status_label { shift->cust_status_label(@_); }

sub cust_status_label {
  my $self = shift;
  __PACKAGE__->statuslabels->{$self->cust_status};
}

=item statuscolor

Returns a hex triplet color string for this customer's status.

=cut

sub statuscolor { shift->cust_statuscolor(@_); }

sub cust_statuscolor {
  my $self = shift;
  __PACKAGE__->statuscolors->{$self->cust_status};
}

=item tickets [ STATUS ]

Returns an array of hashes representing the customer's RT tickets.

An optional status (or arrayref or hashref of statuses) may be specified.

=cut

sub tickets {
  my $self = shift;
  my $status = ( @_ && $_[0] ) ? shift : '';

  my $num = $conf->config('cust_main-max_tickets') || 10;
  my @tickets = ();

  if ( $conf->config('ticket_system') ) {
    unless ( $conf->config('ticket_system-custom_priority_field') ) {

      @tickets = @{ FS::TicketSystem->customer_tickets( $self->custnum,
                                                        $num,
                                                        undef,
                                                        $status,
                                                      )
                  };

    } else {

      foreach my $priority (
        $conf->config('ticket_system-custom_priority_field-values'), ''
      ) {
        last if scalar(@tickets) >= $num;
        push @tickets, 
          @{ FS::TicketSystem->customer_tickets( $self->custnum,
                                                 $num - scalar(@tickets),
                                                 $priority,
                                                 $status,
                                               )
           };
      }
    }
  }
  (@tickets);
}

=item appointments [ STATUS ]

Returns an array of hashes representing the customer's RT tickets which
are appointments.

=cut

sub appointments {
  my $self = shift;
  my $status = ( @_ && $_[0] ) ? shift : '';

  return () unless $conf->config('ticket_system');

  my $queueid = $conf->config('ticket_system-appointment-queueid');

  @{ FS::TicketSystem->customer_tickets( $self->custnum,
                                         99,
                                         undef,
                                         $status,
                                         $queueid,
                                       )
  };
}

# Return services representing svc_accts in customer support packages
sub support_services {
  my $self = shift;
  my %packages = map { $_ => 1 } $conf->config('support_packages');

  grep { $_->pkg_svc && $_->pkg_svc->primary_svc eq 'Y' }
    grep { $_->part_svc->svcdb eq 'svc_acct' }
    map { $_->cust_svc }
    grep { exists $packages{ $_->pkgpart } }
    $self->ncancelled_pkgs;

}

# Return a list of latitude/longitude for one of the services (if any)
sub service_coordinates {
  my $self = shift;

  my @svc_X = 
    grep { $_->latitude && $_->longitude }
    map { $_->svc_x }
    map { $_->cust_svc }
    $self->ncancelled_pkgs;

  scalar(@svc_X) ? ( $svc_X[0]->latitude, $svc_X[0]->longitude ) : ()
}

=item masked FIELD

Returns a masked version of the named field

=cut

sub masked {
my ($self,$field) = @_;

# Show last four

'x'x(length($self->getfield($field))-4).
  substr($self->getfield($field), (length($self->getfield($field))-4));

}

=item payment_history

Returns an array of hashrefs standardizing information from cust_bill, cust_pay,
cust_credit and cust_refund objects.  Each hashref has the following fields:

I<type> - one of 'Line item', 'Invoice', 'Payment', 'Credit', 'Refund' or 'Previous'

I<date> - value of _date field, unix timestamp

I<date_pretty> - user-friendly date

I<description> - user-friendly description of item

I<amount> - impact of item on user's balance 
(positive for Invoice/Refund/Line item, negative for Payment/Credit.)
Not to be confused with the native 'amount' field in cust_credit, see below.

I<amount_pretty> - includes money char

I<balance> - customer balance, chronologically as of this item

I<balance_pretty> - includes money char

I<charged> - amount charged for cust_bill (Invoice or Line item) records, undef for other types

I<paid> - amount paid for cust_pay records, undef for other types

I<credit> - amount credited for cust_credit records, undef for other types.
Literally the 'amount' field from cust_credit, renamed here to avoid confusion.

I<refund> - amount refunded for cust_refund records, undef for other types

The four table-specific keys always have positive values, whether they reflect charges or payments.

The following options may be passed to this method:

I<line_items> - if true, returns charges ('Line item') rather than invoices

I<start_date> - unix timestamp, only include records on or after.
If specified, an item of type 'Previous' will also be included.
It does not have table-specific fields.

I<end_date> - unix timestamp, only include records before

I<reverse_sort> - order from newest to oldest (default is oldest to newest)

I<conf> - optional already-loaded FS::Conf object.

=cut

# Caution: this gets used by FS::ClientAPI::MyAccount::billing_history,
# and also for sending customer statements, which should both be kept customer-friendly.
# If you add anything that shouldn't be passed on through the API or exposed 
# to customers, add a new option to include it, don't include it by default
sub payment_history {
  my $self = shift;
  my $opt = ref($_[0]) ? $_[0] : { @_ };

  my $conf = $$opt{'conf'} || new FS::Conf;
  my $money_char = $conf->config("money_char") || '$',

  #first load entire history, 
  #need previous to calculate previous balance
  #loading after end_date shouldn't hurt too much?
  my @history = ();
  if ( $$opt{'line_items'} ) {

    foreach my $cust_bill ( $self->cust_bill ) {

      push @history, {
        'type'        => 'Line item',
        'description' => $_->desc( $self->locale ).
                           ( $_->sdate && $_->edate
                               ? ' '. time2str('%d-%b-%Y', $_->sdate).
                                 ' To '. time2str('%d-%b-%Y', $_->edate)
                               : ''
                           ),
        'amount'      => sprintf('%.2f', $_->setup + $_->recur ),
        'charged'     => sprintf('%.2f', $_->setup + $_->recur ),
        'date'        => $cust_bill->_date,
        'date_pretty' => $self->time2str_local('short', $cust_bill->_date ),
      }
        foreach $cust_bill->cust_bill_pkg;

    }

  } else {

    push @history, {
                     'type'        => 'Invoice',
                     'description' => 'Invoice #'. $_->display_invnum,
                     'amount'      => sprintf('%.2f', $_->charged ),
                     'charged'     => sprintf('%.2f', $_->charged ),
                     'date'        => $_->_date,
                     'date_pretty' => $self->time2str_local('short', $_->_date ),
                   }
      foreach $self->cust_bill;

  }

  push @history, {
                   'type'        => 'Payment',
                   'description' => 'Payment', #XXX type
                   'amount'      => sprintf('%.2f', 0 - $_->paid ),
                   'paid'        => sprintf('%.2f', $_->paid ),
                   'date'        => $_->_date,
                   'date_pretty' => $self->time2str_local('short', $_->_date ),
                 }
    foreach $self->cust_pay;

  push @history, {
                   'type'        => 'Credit',
                   'description' => 'Credit', #more info?
                   'amount'      => sprintf('%.2f', 0 -$_->amount ),
                   'credit'      => sprintf('%.2f', $_->amount ),
                   'date'        => $_->_date,
                   'date_pretty' => $self->time2str_local('short', $_->_date ),
                 }
    foreach $self->cust_credit;

  push @history, {
                   'type'        => 'Refund',
                   'description' => 'Refund', #more info?  type, like payment?
                   'amount'      => $_->refund,
                   'refund'      => $_->refund,
                   'date'        => $_->_date,
                   'date_pretty' => $self->time2str_local('short', $_->_date ),
                 }
    foreach $self->cust_refund;

  #put it all in chronological order
  @history = sort { $a->{'date'} <=> $b->{'date'} } @history;

  #calculate balance, filter items outside date range
  my $previous = 0;
  my $balance = 0;
  my @out = ();
  foreach my $item (@history) {
    last if $$opt{'end_date'} && ($$item{'date'} >= $$opt{'end_date'});
    $balance += $$item{'amount'};
    if ($$opt{'start_date'} && ($$item{'date'} < $$opt{'start_date'})) {
      $previous += $$item{'amount'};
      next;
    }
    $$item{'balance'} = sprintf("%.2f",$balance);
    foreach my $key ( qw(amount balance) ) {
      $$item{$key.'_pretty'} = money_pretty($$item{$key});
    }
    push(@out,$item);
  }

  # start with previous balance, if there was one
  if ($previous) {
    my $item = {
      'type'        => 'Previous',
      'description' => 'Previous balance',
      'amount'      => sprintf("%.2f",$previous),
      'balance'     => sprintf("%.2f",$previous),
      'date'        => $$opt{'start_date'},
      'date_pretty' => $self->time2str_local('short', $$opt{'start_date'} ),
    };
    #false laziness with above
    foreach my $key ( qw(amount balance) ) {
      $$item{$key.'_pretty'} = $$item{$key};
      $$item{$key.'_pretty'} =~ s/^(-?)/$1$money_char/;
    }
    unshift(@out,$item);
  }

  @out = reverse @history if $$opt{'reverse_sort'};

  return @out;
}

=item save_cust_payby

Saves a new cust_payby for this customer, replacing an existing entry only
in select circumstances.  Does not validate input.

If auto is specified, marks this as the customer's primary method, or the 
specified weight.  Existing payment methods have their weight incremented as
appropriate.

If bill_location is specified with auto, also sets location in cust_main.

Will not insert complete duplicates of existing records, or records in which the
only difference from an existing record is to turn off automatic payment (will
return without error.)  Will replace existing records in which the only difference 
is to add a value to a previously empty preserved field and/or turn on automatic payment.
Fields marked as preserved are optional, and existing values will not be overwritten with 
blanks when replacing.

Accepts the following named parameters:

=over 4

=item payment_payby

either CARD or CHEK

=item auto

save as an automatic payment type (CARD/CHEK if true, DCRD/DCHK if false)

=item weight

optional, set higher than 1 for secondary, etc.

=item payinfo

required

=item paymask

optional, but should be specified for anything that might be tokenized, will be preserved when replacing

=item payname

required

=item payip

optional, will be preserved when replacing

=item paydate

CARD only, required

=item bill_location

CARD only, required, FS::cust_location object

=item paystart_month

CARD only, optional, will be preserved when replacing

=item paystart_year

CARD only, optional, will be preserved when replacing

=item payissue

CARD only, optional, will be preserved when replacing

=item paycvv

CARD only, only used if conf cvv-save is set appropriately

=item paytype

CHEK only

=item paystate

CHEK only

=back

=cut

#The code for this option is in place, but it's not currently used
#
# =item replace
#
# existing cust_payby object to be replaced (must match custnum)

# stateid/stateid_state/ss are not currently supported in cust_payby,
# might not even work properly in 4.x, but will need to work here if ever added

sub save_cust_payby {
  my $self = shift;
  my %opt = @_;

  my $old = $opt{'replace'};
  my $new = new FS::cust_payby { $old ? $old->hash : () };
  return "Customer number does not match" if $new->custnum and $new->custnum != $self->custnum;
  $new->set( 'custnum' => $self->custnum );

  my $payby = $opt{'payment_payby'};
  return "Bad payby" unless grep(/^$payby$/,('CARD','CHEK'));

  # don't allow turning off auto when replacing
  $opt{'auto'} ||= 1 if $old and $old->payby !~ /^D/;

  my @check_existing; # payby relevant to this payment_payby

  # set payby based on auto
  if ( $payby eq 'CARD' ) { 
    $new->set( 'payby' => ( $opt{'auto'} ? 'CARD' : 'DCRD' ) );
    @check_existing = qw( CARD DCRD );
  } elsif ( $payby eq 'CHEK' ) {
    $new->set( 'payby' => ( $opt{'auto'} ? 'CHEK' : 'DCHK' ) );
    @check_existing = qw( CHEK DCHK );
  }

  $new->set( 'weight' => $opt{'auto'} ? $opt{'weight'} : '' );

  # basic fields
  $new->payinfo($opt{'payinfo'}); # sets default paymask, but not if it's already tokenized
  $new->paymask($opt{'paymask'}) if $opt{'paymask'}; # in case it's been tokenized, override with loaded paymask
  $new->set( 'payname' => $opt{'payname'} );
  $new->set( 'payip' => $opt{'payip'} ); # will be preserved below

  my $conf = new FS::Conf;

  # compare to FS::cust_main::realtime_bop - check both to make sure working correctly
  if ( $payby eq 'CARD' &&
       ( (grep { $_ eq cardtype($opt{'payinfo'}) } $conf->config('cvv-save')) 
         || $conf->exists('business-onlinepayment-verification') 
       )
  ) {
    $new->set( 'paycvv' => $opt{'paycvv'} );
  } else {
    $new->set( 'paycvv' => '');
  }

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  # set fields specific to payment_payby
  if ( $payby eq 'CARD' ) {
    if ($opt{'bill_location'}) {
      $opt{'bill_location'}->set('custnum' => $self->custnum);
      my $error = $opt{'bill_location'}->find_or_insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      $new->set( 'locationnum' => $opt{'bill_location'}->locationnum );
    }
    foreach my $field ( qw( paydate paystart_month paystart_year payissue ) ) {
      $new->set( $field => $opt{$field} );
    }
  } else {
    foreach my $field ( qw(paytype paystate) ) {
      $new->set( $field => $opt{$field} );
    }
  }

  # other cust_payby to compare this to
  my @existing = $self->cust_payby(@check_existing);

  # fields that can overwrite blanks with values, but not values with blanks
  my @preserve = qw( paymask locationnum paystart_month paystart_year payissue payip );

  my $skip_cust_payby = 0; # true if we don't need to save or reweight cust_payby
  unless ($old) {
    # generally, we don't want to overwrite existing cust_payby with this,
    # but we can replace if we're only marking it auto or adding a preserved field
    # and we can avoid saving a total duplicate or merely turning off auto
PAYBYLOOP:
    foreach my $cust_payby (@existing) {
      # check fields that absolutely should not change
      foreach my $field ($new->fields) {
        next if grep(/^$field$/, qw( custpaybynum payby weight ) );
        next if grep(/^$field$/, @preserve );
        next PAYBYLOOP unless $new->get($field) eq $cust_payby->get($field);
      }
      # now check fields that can replace if one value is blank
      my $replace = 0;
      foreach my $field (@preserve) {
        if (
          ( $new->get($field) and !$cust_payby->get($field) ) or
          ( $cust_payby->get($field) and !$new->get($field) )
        ) {
          # prevention of overwriting values with blanks happens farther below
          $replace = 1;
        } elsif ( $new->get($field) ne $cust_payby->get($field) ) {
          next PAYBYLOOP;
        }
      }
      unless ( $replace ) {
        # nearly identical, now check weight
        if ($new->get('weight') eq $cust_payby->get('weight') or !$new->get('weight')) {
          # ignore identical cust_payby, and ignore attempts to turn off auto
          # no need to save or re-weight cust_payby (but still need to update/commit $self)
          $skip_cust_payby = 1;
          last PAYBYLOOP;
        }
        # otherwise, only change is to mark this as primary
      }
      # if we got this far, we're definitely replacing
      $old = $cust_payby;
      last PAYBYLOOP;
    } #PAYBYLOOP
  }

  if ($old) {
    $new->set( 'custpaybynum' => $old->custpaybynum );
    # don't turn off automatic payment (but allow it to be turned on)
    if ($new->payby =~ /^D/ and $new->payby ne $old->payby) {
      $opt{'auto'} = 1;
      $new->set( 'payby' => $old->payby );
      $new->set( 'weight' => 1 );
    }
    # make sure we're not overwriting values with blanks
    foreach my $field (@preserve) {
      if ( $old->get($field) and !$new->get($field) ) {
        $new->set( $field => $old->get($field) );
      }
    }
  }

  # only overwrite cust_main bill_location if auto
  if ($opt{'auto'} && $opt{'bill_location'}) {
    $self->set('bill_location' => $opt{'bill_location'});
    my $error = $self->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  # done with everything except reweighting and saving cust_payby
  # still need to commit changes to cust_main and cust_location
  if ($skip_cust_payby) {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return '';
  }

  # re-weight existing primary cust_pay for this payby
  if ($opt{'auto'}) {
    foreach my $cust_payby (@existing) {
      # relies on cust_payby return order
      last unless $cust_payby->payby !~ /^D/;
      last if $cust_payby->weight > 1;
      next if $new->custpaybynum eq $cust_payby->custpaybynum;
      next if $cust_payby->weight < ($opt{'weight'} || 1);
      $cust_payby->weight( $cust_payby->weight + 1 );
      my $error = $cust_payby->replace;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error reweighting cust_payby: $error";
      }
    }
  }

  # finally, save cust_payby
  my $error = $old ? $new->replace($old) : $new->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item remove_cvv_from_cust_payby PAYINFO

Removes paycvv from associated cust_payby with matching PAYINFO.

=cut

sub remove_cvv_from_cust_payby {
  my ($self,$payinfo) = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $cust_payby ( qsearch('cust_payby',{ custnum => $self->custnum }) ) {
    next unless $cust_payby->payinfo eq $payinfo; # can't qsearch on payinfo
    $cust_payby->paycvv('');
    my $error = $cust_payby->replace;
    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=back

=head1 CLASS METHODS

=over 4

=item statuses

Class method that returns the list of possible status strings for customers
(see L<the status method|/status>).  For example:

  @statuses = FS::cust_main->statuses();

=cut

sub statuses {
  my $self = shift;
  keys %{ $self->statuscolors };
}

=item cust_status_sql

Returns an SQL fragment to determine the status of a cust_main record, as a 
string.

=cut

sub cust_status_sql {
  my $sql = 'CASE';
  for my $status ( FS::cust_main->statuses() ) {
    my $method = $status.'_sql';
    $sql .= ' WHEN ('.FS::cust_main->$method.") THEN '$status'";
  }
  $sql .= ' END';
  return $sql;
}


=item prospect_sql

Returns an SQL expression identifying prospective cust_main records (customers
with no packages ever ordered)

=cut

use vars qw($select_count_pkgs);
$select_count_pkgs =
  "SELECT COUNT(*) FROM cust_pkg
    WHERE cust_pkg.custnum = cust_main.custnum";

sub select_count_pkgs_sql {
  $select_count_pkgs;
}

sub prospect_sql {
  " 0 = ( $select_count_pkgs ) ";
}

=item ordered_sql

Returns an SQL expression identifying ordered cust_main records (customers with
no active packages, but recurring packages not yet setup or one time charges
not yet billed).

=cut

sub ordered_sql {
  FS::cust_main->none_active_sql.
  " AND 0 < ( $select_count_pkgs AND ". FS::cust_pkg->not_yet_billed_sql. " ) ";
}

=item active_sql

Returns an SQL expression identifying active cust_main records (customers with
active recurring packages).

=cut

sub active_sql {
  " 0 < ( $select_count_pkgs AND ". FS::cust_pkg->active_sql. " ) ";
}

=item none_active_sql

Returns an SQL expression identifying cust_main records with no active
recurring packages.  This includes customers of status prospect, ordered,
inactive, and suspended.

=cut

sub none_active_sql {
  " 0 = ( $select_count_pkgs AND ". FS::cust_pkg->active_sql. " ) ";
}

=item inactive_sql

Returns an SQL expression identifying inactive cust_main records (customers with
no active recurring packages, but otherwise unsuspended/uncancelled).

=cut

sub inactive_sql {
  FS::cust_main->none_active_sql.
  " AND 0 < ( $select_count_pkgs AND ". FS::cust_pkg->inactive_sql. " ) ";
}

=item susp_sql
=item suspended_sql

Returns an SQL expression identifying suspended cust_main records.

=cut


sub suspended_sql { susp_sql(@_); }
sub susp_sql {
  FS::cust_main->none_active_sql.
  " AND 0 < ( $select_count_pkgs AND ". FS::cust_pkg->suspended_sql. " ) ";
}

=item cancel_sql
=item cancelled_sql

Returns an SQL expression identifying cancelled cust_main records.

=cut

sub cancel_sql { shift->cancelled_sql(@_); }

=item uncancel_sql
=item uncancelled_sql

Returns an SQL expression identifying un-cancelled cust_main records.

=cut

sub uncancelled_sql { uncancel_sql(@_); }
sub uncancel_sql {
  my $self = shift;
  "( NOT (".$self->cancelled_sql.") )"; #sensitive to cust_main-status_module
}

=item balance_sql

Returns an SQL fragment to retreive the balance.

=cut

sub balance_sql { "
    ( SELECT COALESCE( SUM(charged), 0 ) FROM cust_bill
        WHERE cust_bill.custnum   = cust_main.custnum     )
  - ( SELECT COALESCE( SUM(paid),    0 ) FROM cust_pay
        WHERE cust_pay.custnum    = cust_main.custnum     )
  - ( SELECT COALESCE( SUM(amount),  0 ) FROM cust_credit
        WHERE cust_credit.custnum = cust_main.custnum     )
  + ( SELECT COALESCE( SUM(refund),  0 ) FROM cust_refund
        WHERE cust_refund.custnum = cust_main.custnum     )
"; }

=item balance_date_sql [ START_TIME [ END_TIME [ OPTION => VALUE ... ] ] ]

Returns an SQL fragment to retreive the balance for this customer, optionally
considering invoices with date earlier than START_TIME, and not
later than END_TIME (total_owed_date minus total_unapplied_credits minus
total_unapplied_payments).

Times are specified as SQL fragments or numeric
UNIX timestamps; see L<perlfunc/"time">).  Also see L<Time::Local> and
L<Date::Parse> for conversion functions.  The empty string can be passed
to disable that time constraint completely.

Available options are:

=over 4

=item unapplied_date

set to true to disregard unapplied credits, payments and refunds outside the specified time period - by default the time period restriction only applies to invoices (useful for reporting, probably a bad idea for event triggering)

=item total

(unused.  obsolete?)
set to true to remove all customer comparison clauses, for totals

=item where

(unused.  obsolete?)
WHERE clause hashref (elements "AND"ed together) (typically used with the total option)

=item join

(unused.  obsolete?)
JOIN clause (typically used with the total option)

=item cutoff

An absolute cutoff time.  Payments, credits, and refunds I<applied> after this 
time will be ignored.  Note that START_TIME and END_TIME only limit the date 
range for invoices and I<unapplied> payments, credits, and refunds.

=back

=cut

sub balance_date_sql {
  my( $class, $start, $end, %opt ) = @_;

  my $cutoff = $opt{'cutoff'};

  my $owed         = FS::cust_bill->owed_sql($cutoff);
  my $unapp_refund = FS::cust_refund->unapplied_sql($cutoff);
  my $unapp_credit = FS::cust_credit->unapplied_sql($cutoff);
  my $unapp_pay    = FS::cust_pay->unapplied_sql($cutoff);

  my $j = $opt{'join'} || '';

  my $owed_wh   = $class->_money_table_where( 'cust_bill',   $start,$end,%opt );
  my $refund_wh = $class->_money_table_where( 'cust_refund', $start,$end,%opt );
  my $credit_wh = $class->_money_table_where( 'cust_credit', $start,$end,%opt );
  my $pay_wh    = $class->_money_table_where( 'cust_pay',    $start,$end,%opt );

  "   ( SELECT COALESCE(SUM($owed),         0) FROM cust_bill   $j $owed_wh   )
    + ( SELECT COALESCE(SUM($unapp_refund), 0) FROM cust_refund $j $refund_wh )
    - ( SELECT COALESCE(SUM($unapp_credit), 0) FROM cust_credit $j $credit_wh )
    - ( SELECT COALESCE(SUM($unapp_pay),    0) FROM cust_pay    $j $pay_wh    )
  ";

}

=item unapplied_payments_date_sql START_TIME [ END_TIME ]

Returns an SQL fragment to retreive the total unapplied payments for this
customer, only considering payments with date earlier than START_TIME, and
optionally not later than END_TIME.

Times are specified as SQL fragments or numeric
UNIX timestamps; see L<perlfunc/"time">).  Also see L<Time::Local> and
L<Date::Parse> for conversion functions.  The empty string can be passed
to disable that time constraint completely.

Available options are:

=cut

sub unapplied_payments_date_sql {
  my( $class, $start, $end, %opt ) = @_;

  my $cutoff = $opt{'cutoff'};

  my $unapp_pay    = FS::cust_pay->unapplied_sql($cutoff);

  my $pay_where = $class->_money_table_where( 'cust_pay', $start, $end,
                                                          'unapplied_date'=>1 );

  " ( SELECT COALESCE(SUM($unapp_pay), 0) FROM cust_pay $pay_where ) ";
}

=item _money_table_where TABLE START_TIME [ END_TIME [ OPTION => VALUE ... ] ]

Helper method for balance_date_sql; name (and usage) subject to change
(suggestions welcome).

Returns a WHERE clause for the specified monetary TABLE (cust_bill,
cust_refund, cust_credit or cust_pay).

If TABLE is "cust_bill" or the unapplied_date option is true, only
considers records with date earlier than START_TIME, and optionally not
later than END_TIME .

=cut

sub _money_table_where {
  my( $class, $table, $start, $end, %opt ) = @_;

  my @where = ();
  push @where, "cust_main.custnum = $table.custnum" unless $opt{'total'};
  if ( $table eq 'cust_bill' || $opt{'unapplied_date'} ) {
    push @where, "$table._date <= $start" if defined($start) && length($start);
    push @where, "$table._date >  $end"   if defined($end)   && length($end);
  }
  push @where, @{$opt{'where'}} if $opt{'where'};
  my $where = scalar(@where) ? 'WHERE '. join(' AND ', @where ) : '';

  $where;

}

#for dyanmic FS::$table->search in httemplate/misc/email_customers.html
use FS::cust_main::Search;
sub search {
  my $class = shift;
  FS::cust_main::Search->search(@_);
}

=back

=head1 SUBROUTINES

=over 4

#=item notify CUSTOMER_OBJECT TEMPLATE_NAME OPTIONS

#Deprecated.  Use event notification and message templates 
#(L<FS::msg_template>) instead.

#Sends a templated email notification to the customer (see L<Text::Template>).

#OPTIONS is a hash and may include

#I<from> - the email sender (default is invoice_from)

#I<to> - comma-separated scalar or arrayref of recipients 
#   (default is invoicing_list)

#I<subject> - The subject line of the sent email notification
#   (default is "Notice from company_name")

#I<extra_fields> - a hashref of name/value pairs which will be substituted
#   into the template

#The following variables are vavailable in the template.

#I<$first> - the customer first name
#I<$last> - the customer last name
#I<$company> - the customer company
#I<$payby> - a description of the method of payment for the customer
#            # would be nice to use FS::payby::shortname
#I<$payinfo> - the account information used to collect for this customer
#I<$expdate> - the expiration of the customer payment in seconds from epoch

#=cut

#sub notify {
#  my ($self, $template, %options) = @_;

#  return unless $conf->exists($template);

#  my $from = $conf->invoice_from_full($self->agentnum)
#    if $conf->exists('invoice_from', $self->agentnum);
#  $from = $options{from} if exists($options{from});

#  my $to = join(',', $self->invoicing_list_emailonly);
#  $to = $options{to} if exists($options{to});
#  
#  my $subject = "Notice from " . $conf->config('company_name', $self->agentnum)
#    if $conf->exists('company_name', $self->agentnum);
#  $subject = $options{subject} if exists($options{subject});

#  my $notify_template = new Text::Template (TYPE => 'ARRAY',
#                                            SOURCE => [ map "$_\n",
#                                              $conf->config($template)]
#                                           )
#    or die "can't create new Text::Template object: Text::Template::ERROR";
#  $notify_template->compile()
#    or die "can't compile template: Text::Template::ERROR";

#  $FS::notify_template::_template::company_name =
#    $conf->config('company_name', $self->agentnum);
#  $FS::notify_template::_template::company_address =
#    join("\n", $conf->config('company_address', $self->agentnum) ). "\n";

#  my $paydate = $self->paydate || '2037-12-31';
#  $FS::notify_template::_template::first = $self->first;
#  $FS::notify_template::_template::last = $self->last;
#  $FS::notify_template::_template::company = $self->company;
#  $FS::notify_template::_template::payinfo = $self->mask_payinfo;
#  my $payby = $self->payby;
#  my ($payyear,$paymonth,$payday) = split (/-/,$paydate);
#  my $expire_time = timelocal(0,0,0,$payday,--$paymonth,$payyear);

#  #credit cards expire at the end of the month/year of their exp date
#  if ($payby eq 'CARD' || $payby eq 'DCRD') {
#    $FS::notify_template::_template::payby = 'credit card';
#    ($paymonth < 11) ? $paymonth++ : ($paymonth=0, $payyear++);
#    $expire_time = timelocal(0,0,0,$payday,$paymonth,$payyear);
#    $expire_time--;
#  }elsif ($payby eq 'COMP') {
#    $FS::notify_template::_template::payby = 'complimentary account';
#  }else{
#    $FS::notify_template::_template::payby = 'current method';
#  }
#  $FS::notify_template::_template::expdate = $expire_time;

#  for (keys %{$options{extra_fields}}){
#    no strict "refs";
#    ${"FS::notify_template::_template::$_"} = $options{extra_fields}->{$_};
#  }

#  send_email(from => $from,
#             to => $to,
#             subject => $subject,
#             body => $notify_template->fill_in( PACKAGE =>
#                                                'FS::notify_template::_template'                                              ),
#            );

#}

=item generate_letter CUSTOMER_OBJECT TEMPLATE_NAME OPTIONS

Generates a templated notification to the customer (see L<Text::Template>).

OPTIONS is a hash and may include

I<extra_fields> - a hashref of name/value pairs which will be substituted
   into the template.  These values may override values mentioned below
   and those from the customer record.

I<template_text> - if present, ignores TEMPLATE_NAME and uses the provided text

The following variables are available in the template instead of or in addition
to the fields of the customer record.

I<$payby> - a description of the method of payment for the customer
            # would be nice to use FS::payby::shortname
I<$payinfo> - the masked account information used to collect for this customer
I<$expdate> - the expiration of the customer payment method in seconds from epoch
I<$returnaddress> - the return address defaults to invoice_latexreturnaddress or company_address

=cut

# a lot like cust_bill::print_latex
sub generate_letter {
  my ($self, $template, %options) = @_;

  warn "Template $template does not exist" && return
    unless $conf->exists($template) || $options{'template_text'};

  my $template_source = $options{'template_text'} 
                        ? [ $options{'template_text'} ] 
                        : [ map "$_\n", $conf->config($template) ];

  my $letter_template = new Text::Template
                        ( TYPE       => 'ARRAY',
                          SOURCE     => $template_source,
                          DELIMITERS => [ '[@--', '--@]' ],
                        )
    or die "can't create new Text::Template object: Text::Template::ERROR";

  $letter_template->compile()
    or die "can't compile template: Text::Template::ERROR";

  my %letter_data = map { $_ => $self->$_ } $self->fields;
  $letter_data{payinfo} = $self->mask_payinfo;

  #my $paydate = $self->paydate || '2037-12-31';
  my $paydate = $self->paydate =~ /^\S+$/ ? $self->paydate : '2037-12-31';

  my $payby = $self->payby;
  my ($payyear,$paymonth,$payday) = split (/-/,$paydate);
  my $expire_time = timelocal(0,0,0,$payday,--$paymonth,$payyear);

  #credit cards expire at the end of the month/year of their exp date
  if ($payby eq 'CARD' || $payby eq 'DCRD') {
    $letter_data{payby} = 'credit card';
    ($paymonth < 11) ? $paymonth++ : ($paymonth=0, $payyear++);
    $expire_time = timelocal(0,0,0,$payday,$paymonth,$payyear);
    $expire_time--;
  }elsif ($payby eq 'COMP') {
    $letter_data{payby} = 'complimentary account';
  }else{
    $letter_data{payby} = 'current method';
  }
  $letter_data{expdate} = $expire_time;

  for (keys %{$options{extra_fields}}){
    $letter_data{$_} = $options{extra_fields}->{$_};
  }

  unless(exists($letter_data{returnaddress})){
    my $retadd = join("\n", $conf->config_orbase( 'invoice_latexreturnaddress',
                                                  $self->agent_template)
                     );
    if ( length($retadd) ) {
      $letter_data{returnaddress} = $retadd;
    } elsif ( grep /\S/, $conf->config('company_address', $self->agentnum) ) {
      $letter_data{returnaddress} =
        join( "\n", map { s/( {2,})/'~' x length($1)/eg;
                          s/$/\\\\\*/;
                          $_;
                        }
                    ( $conf->config('company_name', $self->agentnum),
                      $conf->config('company_address', $self->agentnum),
                    )
        );
    } else {
      $letter_data{returnaddress} = '~';
    }
  }

  $letter_data{conf_dir} = "$FS::UID::conf_dir/conf.$FS::UID::datasrc";

  $letter_data{company_name} = $conf->config('company_name', $self->agentnum);

  my $dir = $FS::UID::conf_dir."/cache.". $FS::UID::datasrc;

  my $lh = new File::Temp( TEMPLATE => 'letter.'. $self->custnum. '.XXXXXXXX',
                           DIR      => $dir,
                           SUFFIX   => '.eps',
                           UNLINK   => 0,
                         ) or die "can't open temp file: $!\n";
  print $lh $conf->config_binary('logo.eps', $self->agentnum)
    or die "can't write temp file: $!\n";
  close $lh;
  $letter_data{'logo_file'} = $lh->filename;

  my $fh = new File::Temp( TEMPLATE => 'letter.'. $self->custnum. '.XXXXXXXX',
                           DIR      => $dir,
                           SUFFIX   => '.tex',
                           UNLINK   => 0,
                         ) or die "can't open temp file: $!\n";

  $letter_template->fill_in( OUTPUT => $fh, HASH => \%letter_data );
  close $fh;
  $fh->filename =~ /^(.*).tex$/ or die "unparsable filename: ". $fh->filename;
  return ($1, $letter_data{'logo_file'});

}

=item print_ps TEMPLATE 

Returns an postscript letter filled in from TEMPLATE, as a scalar.

=cut

sub print_ps {
  my $self = shift;
  my($file, $lfile) = $self->generate_letter(@_);
  my $ps = FS::Misc::generate_ps($file);
  unlink($file.'.tex');
  unlink($lfile);

  $ps;
}

=item print TEMPLATE

Prints the filled in template.

TEMPLATE is the name of a L<Text::Template> to fill in and print.

=cut

sub queueable_print {
  my %opt = @_;

  my $self = qsearchs('cust_main', { 'custnum' => $opt{custnum} } )
    or die "invalid customer number: " . $opt{custnum};

#do not backport this change to 3.x
#  my $error = $self->print( { 'template' => $opt{template} } );
  my $error = $self->print( $opt{'template'} );
  die $error if $error;
}

sub print {
  my ($self, $template) = (shift, shift);
  do_print(
    [ $self->print_ps($template) ],
    'agentnum' => $self->agentnum,
  );
}

#these three subs should just go away once agent stuff is all config overrides

sub agent_template {
  my $self = shift;
  $self->_agent_plandata('agent_templatename');
}

sub agent_invoice_from {
  my $self = shift;
  $self->_agent_plandata('agent_invoice_from');
}

sub _agent_plandata {
  my( $self, $option ) = @_;

  #yuck.  this whole thing needs to be reconciled better with 1.9's idea of
  #agent-specific Conf

  use FS::part_event::Condition;
  
  my $agentnum = $self->agentnum;

  my $regexp = regexp_sql();

  my $part_event_option =
    qsearchs({
      'select'    => 'part_event_option.*',
      'table'     => 'part_event_option',
      'addl_from' => q{
        LEFT JOIN part_event USING ( eventpart )
        LEFT JOIN part_event_option AS peo_agentnum
          ON ( part_event.eventpart = peo_agentnum.eventpart
               AND peo_agentnum.optionname = 'agentnum'
               AND peo_agentnum.optionvalue }. $regexp. q{ '(^|,)}. $agentnum. q{(,|$)'
             )
        LEFT JOIN part_event_condition
          ON ( part_event.eventpart = part_event_condition.eventpart
               AND part_event_condition.conditionname = 'cust_bill_age'
             )
        LEFT JOIN part_event_condition_option
          ON ( part_event_condition.eventconditionnum = part_event_condition_option.eventconditionnum
               AND part_event_condition_option.optionname = 'age'
             )
      },
      #'hashref'   => { 'optionname' => $option },
      #'hashref'   => { 'part_event_option.optionname' => $option },
      'extra_sql' =>
        " WHERE part_event_option.optionname = ". dbh->quote($option).
        " AND action = 'cust_bill_send_agent' ".
        " AND ( disabled IS NULL OR disabled != 'Y' ) ".
        " AND peo_agentnum.optionname = 'agentnum' ".
        " AND ( agentnum IS NULL OR agentnum = $agentnum ) ".
        " ORDER BY
           CASE WHEN part_event_condition_option.optionname IS NULL
           THEN -1
           ELSE ". FS::part_event::Condition->age2seconds_sql('part_event_condition_option.optionvalue').
        " END
          , part_event.weight".
        " LIMIT 1"
    });
    
  unless ( $part_event_option ) {
    return $self->agent->invoice_template || ''
      if $option eq 'agent_templatename';
    return '';
  }

  $part_event_option->optionvalue;

}

sub process_o2m_qsearch {
  my $self = shift;
  my $table = shift;
  return qsearch($table, @_) unless $table eq 'contact';

  my $hashref = shift;
  my %hash = %$hashref;
  ( my $custnum = delete $hash{'custnum'} ) =~ /^(\d+)$/
    or die 'guru meditation #4343';

  qsearch({ 'table'     => 'contact',
            'addl_from' => 'LEFT JOIN cust_contact USING ( contactnum )',
            'hashref'   => \%hash,
            'extra_sql' => ( keys %hash ? ' AND ' : ' WHERE ' ).
                           " cust_contact.custnum = $custnum "
         });                
}

sub process_o2m_qsearchs {
  my $self = shift;
  my $table = shift;
  return qsearchs($table, @_) unless $table eq 'contact';

  my $hashref = shift;
  my %hash = %$hashref;
  ( my $custnum = delete $hash{'custnum'} ) =~ /^(\d+)$/
    or die 'guru meditation #2121';

  qsearchs({ 'table'     => 'contact',
             'addl_from' => 'LEFT JOIN cust_contact USING ( contactnum )',
             'hashref'   => \%hash,
             'extra_sql' => ( keys %hash ? ' AND ' : ' WHERE ' ).
                            " cust_contact.custnum = $custnum "
          });                
}

=item queued_bill 'custnum' => CUSTNUM [ , OPTION => VALUE ... ]

Subroutine (not a method), designed to be called from the queue.

Takes a list of options and values.

Pulls up the customer record via the custnum option and calls bill_and_collect.

=cut

sub queued_bill {
  my (%args) = @_; #, ($time, $invoice_time, $check_freq, $resetup) = @_;

  my $cust_main = qsearchs( 'cust_main', { custnum => $args{'custnum'} } );
  warn 'bill_and_collect custnum#'. $cust_main->custnum. "\n";#log custnum w/pid

  #without this errors don't get rolled back
  $args{'fatal'} = 1; # runs from job queue, will be caught

  $cust_main->bill_and_collect( %args );
}

=item queued_collect 'custnum' => CUSTNUM [ , OPTION => VALUE ... ]

Like queued_bill, but instead of C<bill_and_collect>, just runs the 
C<collect> part.  This is used in batch tax calculation, where invoice 
generation and collection events have to be completely separated.

=cut

sub queued_collect {
  my (%args) = @_;
  my $cust_main = FS::cust_main->by_key($args{'custnum'});
  
  $cust_main->collect(%args);
}

sub process_bill_and_collect {
  my $job = shift;
  my $param = shift;
  my $cust_main = qsearchs( 'cust_main', { custnum => $param->{'custnum'} } )
      or die "custnum '$param->{custnum}' not found!\n";
  $param->{'job'}   = $job;
  $param->{'fatal'} = 1; # runs from job queue, will be caught
  $param->{'retry'} = 1;

  $cust_main->bill_and_collect( %$param );
}

#starting to take quite a while for big dbs
#   (JRNL: journaled so it only happens once per database)
# - seq scan of h_cust_main (yuck), but not going to index paycvv, so
# JRNL seq scan of cust_main on signupdate... index signupdate?  will that help?
# JRNL seq scan of cust_main on paydate... index on substrings?  maybe set an
# JRNL seq scan of cust_main on payinfo.. certainly not going toi ndex that...
# JRNL leading/trailing spaces in first, last, company
# JRNL migrate to cust_payby
# - otaker upgrade?  journal and call it good?  (double check to make sure
#    we're not still setting otaker here)
#
#only going to get worse with new location stuff...

sub _upgrade_data { #class method
  my ($class, %opts) = @_;

  my @statements = (
    'UPDATE h_cust_main SET paycvv = NULL WHERE paycvv IS NOT NULL',
  );

  #this seems to be the only expensive one.. why does it take so long?
  unless ( FS::upgrade_journal->is_done('cust_main__signupdate') ) {
    push @statements,
      'UPDATE cust_main SET signupdate = (SELECT signupdate FROM h_cust_main WHERE signupdate IS NOT NULL AND h_cust_main.custnum = cust_main.custnum ORDER BY historynum DESC LIMIT 1) WHERE signupdate IS NULL';
    FS::upgrade_journal->set_done('cust_main__signupdate');
  }

  unless ( FS::upgrade_journal->is_done('cust_main__paydate') ) {

    # fix yyyy-m-dd formatted paydates
    if ( driver_name =~ /^mysql/i ) {
      push @statements,
      "UPDATE cust_main SET paydate = CONCAT( SUBSTRING(paydate FROM 1 FOR 5), '0', SUBSTRING(paydate FROM 6) ) WHERE SUBSTRING(paydate FROM 7 FOR 1) = '-'";
    } else { # the SQL standard
      push @statements, 
      "UPDATE cust_main SET paydate = SUBSTRING(paydate FROM 1 FOR 5) || '0' || SUBSTRING(paydate FROM 6) WHERE SUBSTRING(paydate FROM 7 FOR 1) = '-'";
    }
    FS::upgrade_journal->set_done('cust_main__paydate');
  }

  unless ( FS::upgrade_journal->is_done('cust_main__payinfo') ) {

    push @statements, #fix the weird BILL with a cc# in payinfo problem
      #DCRD to be safe
      "UPDATE cust_main SET payby = 'DCRD' WHERE payby = 'BILL' and length(payinfo) = 16 and payinfo ". regexp_sql. q( '^[0-9]*$' );

    FS::upgrade_journal->set_done('cust_main__payinfo');
    
  }

  my $t = time;
  foreach my $sql ( @statements ) {
    my $sth = dbh->prepare($sql) or die dbh->errstr;
    $sth->execute or die $sth->errstr;
    #warn ( (time - $t). " seconds\n" );
    #$t = time;
  }

  local($ignore_expired_card) = 1;
  local($ignore_banned_card) = 1;
  local($skip_fuzzyfiles) = 1;
  local($import) = 1; #prevent automatic geocoding (need its own variable?)

  unless ( FS::upgrade_journal->is_done('cust_main__cust_payby') ) {

    #we don't want to decrypt them, just stuff them as-is into cust_payby
    local(@encrypted_fields) = ();

    local($FS::cust_payby::ignore_expired_card) = 1;
    local($FS::cust_payby::ignore_banned_card)  = 1;
    local($FS::cust_payby::ignore_cardtype)     = 1;

    my @payfields = qw( payby payinfo paycvv paymask
                        paydate paystart_month paystart_year payissue
                        payname paystate paytype payip
                      );

    my $search = new FS::Cursor {
      'table'     => 'cust_main',
      'extra_sql' => " WHERE ( payby IS NOT NULL AND payby != '' ) ",
    };

    while (my $cust_main = $search->fetch) {

      unless ( $cust_main->payby =~ /^(BILL|COMP)$/ ) {

        my $cust_payby = new FS::cust_payby {
          'custnum' => $cust_main->custnum,
          'weight'  => 1,
          map { $_ => $cust_main->$_(); } @payfields
        };

        my $error = $cust_payby->insert;
        die $error if $error;

      }

      # at the time we do this, also migrate paytype into cust_pay_batch
      # so that batches that are open before the migration can still be 
      # processed
      my @cust_pay_batch = qsearch('cust_pay_batch', {
          'custnum' => $cust_main->custnum,
          'payby'   => 'CHEK',
          'paytype' => '',
      });
      foreach my $cust_pay_batch (@cust_pay_batch) {
        $cust_pay_batch->set('paytype', $cust_main->get('paytype'));
        my $error = $cust_pay_batch->replace;
        die "$error (setting cust_pay_batch.paytype)" if $error;
      }

      $cust_main->complimentary('Y') if $cust_main->payby eq 'COMP';

      $cust_main->invoice_attn( $cust_main->payname )
        if $cust_main->payby eq 'BILL' && $cust_main->payname;
      $cust_main->po_number( $cust_main->payinfo )
        if $cust_main->payby eq 'BILL' && $cust_main->payinfo;

      $cust_main->setfield($_, '') foreach @payfields;
      my $error = $cust_main->replace;
      die "Error upgradging payment information for custnum ".
          $cust_main->custnum. ": $error"
        if $error;

    };

    FS::upgrade_journal->set_done('cust_main__cust_payby');
  }

  FS::cust_main::Location->_upgrade_data(%opts);

  unless ( FS::upgrade_journal->is_done('cust_main__trimspaces') ) {

    foreach my $cust_main ( qsearch({
      'table'     => 'cust_main', 
      'hashref'   => {},
      'extra_sql' => 'WHERE '.
                       join(' OR ',
                         map "$_ LIKE ' %' OR $_ LIKE '% ' OR $_ LIKE '%  %'",
                           qw( first last company )
                       ),
    }) ) {
      my $error = $cust_main->replace;
      die $error if $error;
    }

    FS::upgrade_journal->set_done('cust_main__trimspaces');

  }

  $class->_upgrade_otaker(%opts);

  # turn on encryption as part of regular upgrade, so all new records are immediately encrypted
  # existing records will be encrypted in queueable_upgrade (below)
  unless ($conf->exists('encryptionpublickey') || $conf->exists('encryptionprivatekey')) {
    eval "use FS::Setup";
    die $@ if $@;
    FS::Setup::enable_encryption();
  }

}

sub queueable_upgrade {
  my $class = shift;

  ### encryption gets turned on in _upgrade_data, above

  eval "use FS::upgrade_journal";
  die $@ if $@;

  # prior to 2013 (commit f16665c9) payinfo was stored in history if not encrypted,
  # clear that out before encrypting/tokenizing anything else
  if (!FS::upgrade_journal->is_done('clear_payinfo_history')) {
    foreach my $table ('cust_payby','cust_pay_pending','cust_pay','cust_pay_void','cust_refund') {
      my $sql = 'UPDATE h_'.$table.' SET payinfo = NULL WHERE payinfo IS NOT NULL';
      my $sth = dbh->prepare($sql) or die dbh->errstr;
      $sth->execute or die $sth->errstr;
    }
    FS::upgrade_journal->set_done('clear_payinfo_history');
  }

  # encrypt old records
  if ($conf->exists('encryption') && !FS::upgrade_journal->is_done('encryption_check')) {

    # allow replacement of closed cust_pay/cust_refund records
    local $FS::payinfo_Mixin::allow_closed_replace = 1;

    # because it looks like nothing's changing
    local $FS::Record::no_update_diff = 1;

    # commit everything immediately
    local $FS::UID::AutoCommit = 1;

    # encrypt what's there
    foreach my $table ('cust_payby','cust_pay_pending','cust_pay','cust_pay_void','cust_refund') {
      my $tclass = 'FS::'.$table;
      my $lastrecnum = 0;
      my @recnums = ();
      while (my $recnum = _upgrade_next_recnum(dbh,$table,\$lastrecnum,\@recnums)) {
        my $record = $tclass->by_key($recnum);
        next unless $record; # small chance it's been deleted, that's ok
        next unless grep { $record->payby eq $_ } @FS::Record::encrypt_payby;
        # window for possible conflict is practically nonexistant,
        #   but just in case...
        $record = $record->select_for_update;
        my $error = $record->replace;
        die $error if $error;
      }
    }

    FS::upgrade_journal->set_done('encryption_check');
  }

}

# not entirely false laziness w/ Billing_Realtime::_token_check_next_recnum
# cust_payby might get deleted while this runs
# not a method!
sub _upgrade_next_recnum {
  my ($dbh,$table,$lastrecnum,$recnums) = @_;
  my $recnum = shift @$recnums;
  return $recnum if $recnum;
  my $tclass = 'FS::'.$table;
  my $sql = 'SELECT '.$tclass->primary_key.
            ' FROM '.$table.
            ' WHERE '.$tclass->primary_key.' > '.$$lastrecnum.
            ' ORDER BY '.$tclass->primary_key.' LIMIT 500';;
  my $sth = $dbh->prepare($sql) or die $dbh->errstr;
  $sth->execute() or die $sth->errstr;
  my @recnums;
  while (my $rec = $sth->fetchrow_hashref) {
    push @$recnums, $rec->{$tclass->primary_key};
  }
  $sth->finish();
  $$lastrecnum = $$recnums[-1];
  return shift @$recnums;
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

Birthdates rely on negative epoch values.

The payby for card/check batches is broken.  With mixed batching, bad
things will happen.

B<collect> I<invoice_time> should be renamed I<time>, like B<bill>.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::cust_bill>, L<FS::cust_credit>
L<FS::agent>, L<FS::part_referral>, L<FS::cust_main_county>,
L<FS::cust_main_invoice>, L<FS::UID>, schema.html from the base documentation.

=cut

1;

