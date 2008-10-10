package FS::cust_main;

require 5.006;
use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG $me $conf @encrypted_fields
             $import $skip_fuzzyfiles $ignore_expired_card @paytypes);
use vars qw( $realtime_bop_decline_quiet ); #ugh
use Safe;
use Carp;
use Exporter;
use Scalar::Util qw( blessed );
use Time::Local qw(timelocal_nocheck);
use Data::Dumper;
use Tie::IxHash;
use Digest::MD5 qw(md5_base64);
use Date::Format;
use Date::Parse;
#use Date::Manip;
use File::Slurp qw( slurp );
use File::Temp qw( tempfile );
use String::Approx qw(amatch);
use Business::CreditCard 0.28;
use Locale::Country;
use FS::UID qw( getotaker dbh driver_name );
use FS::Record qw( qsearchs qsearch dbdef );
use FS::Misc qw( generate_email send_email generate_ps do_print );
use FS::Msgcat qw(gettext);
use FS::cust_pkg;
use FS::cust_svc;
use FS::cust_bill;
use FS::cust_bill_pkg;
use FS::cust_bill_pkg_display;
use FS::cust_pay;
use FS::cust_pay_pending;
use FS::cust_pay_void;
use FS::cust_pay_batch;
use FS::cust_credit;
use FS::cust_refund;
use FS::part_referral;
use FS::cust_main_county;
use FS::cust_tax_location;
use FS::agent;
use FS::cust_main_invoice;
use FS::cust_credit_bill;
use FS::cust_bill_pay;
use FS::prepay_credit;
use FS::queue;
use FS::part_pkg;
use FS::part_event;
use FS::part_event_condition;
#use FS::cust_event;
use FS::type_pkgs;
use FS::payment_gateway;
use FS::agent_payment_gateway;
use FS::banned_pay;
use FS::payinfo_Mixin;
use FS::TicketSystem;

@ISA = qw( FS::payinfo_Mixin FS::Record );

@EXPORT_OK = qw( smart_search );

$realtime_bop_decline_quiet = 0;

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;
$me = '[FS::cust_main]';

$import = 0;
$skip_fuzzyfiles = 0;
$ignore_expired_card = 0;

@encrypted_fields = ('payinfo', 'paycvv');
@paytypes = ('', 'Personal checking', 'Personal savings', 'Business checking', 'Business savings');

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

=item payby - Payment Type (See L<FS::payinfo_Mixin> for valid payby values)

=item payinfo - Payment Information (See L<FS::payinfo_Mixin> for data format)

=item paymask - Masked payinfo (See L<FS::payinfo_Mixin> for how this works)

=item paycvv

Card Verification Value, "CVV2" (also known as CVC2 or CID), the 3 or 4 digit number on the back (or front, for American Express) of the credit card

=item paydate - expiration date, mm/yyyy, m/yyyy, mm/yy or m/yy

=item paystart_month - start date month (maestro/solo cards only)

=item paystart_year - start date year (maestro/solo cards only)

=item payissue - issue number (maestro/solo cards only)

=item payname - name on card or billing name

=item payip - IP address from which payment information was received

=item tax - tax exempt, empty or `Y'

=item otaker - order taker (assigned automatically, see L<FS::UID>)

=item comments - comments (optional)

=item referral_custnum - referring customer number

=item spool_cdr - Enable individual CDR spooling, empty or `Y'

=item dundate - a suggestion to events (see L<FS::part_bill_event">) to delay until this unix timestamp

=item squelch_cdr - Discourage individual CDR printing, empty or `Y'

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
as running the customer's credit card successfully).

The I<noexport> option is deprecated.  If I<noexport> is set true, no
provisioning jobs (exports) are scheduled.  (You can schedule them later with
the B<reexport> method.)

=cut

sub insert {
  my $self = shift;
  my $cust_pkgs = @_ ? shift : {};
  my $invoicing_list = @_ ? shift : '';
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
  my( $amount, $seconds ) = ( 0, 0 );
  my $payby = '';
  if ( $self->payby eq 'PREPAY' ) {

    $self->payby('BILL');
    $prepay_identifier = $self->payinfo;
    $self->payinfo('');

    warn "  looking up prepaid card $prepay_identifier\n"
      if $DEBUG > 1;

    my $error = $self->get_prepay($prepay_identifier, \$amount, \$seconds);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      #return "error applying prepaid card (transaction rolled back): $error";
      return $error;
    }

    $payby = 'PREP' if $amount;

  } elsif ( $self->payby =~ /^(CASH|WEST|MCRD)$/ ) {

    $payby = $1;
    $self->payby('BILL');
    $amount = $self->paid;

  }

  warn "  inserting $self\n"
    if $DEBUG > 1;

  $self->signupdate(time) unless $self->signupdate;

  $self->auto_agent_custid()
    if $conf->config('cust_main-auto_agent_custid') && ! $self->agent_custid;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    #return "inserting cust_main record (transaction rolled back): $error";
    return $error;
  }

  warn "  setting invoicing list\n"
    if $DEBUG > 1;

  if ( $invoicing_list ) {
    $error = $self->check_invoicing_list( $invoicing_list );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      #return "checking invoicing_list (transaction rolled back): $error";
      return $error;
    }
    $self->invoicing_list( $invoicing_list );
  }

  if (    $conf->config('cust_main-skeleton_tables')
       && $conf->config('cust_main-skeleton_custnum') ) {

    warn "  inserting skeleton records\n"
      if $DEBUG > 1;

    my $error = $self->start_copy_skel;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  warn "  ordering packages\n"
    if $DEBUG > 1;

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

sub start_copy_skel {
  my $self = shift;

  #'mg_user_preference' => {},
  #'mg_user_indicator_profile.user_indicator_profile_id' => { 'mg_profile_indicator.profile_indicator_id' => { 'mg_profile_details.profile_detail_id' }, },
  #'mg_watchlist_header.watchlist_header_id' => { 'mg_watchlist_details.watchlist_details_id' },
  #'mg_user_grid_header.grid_header_id' => { 'mg_user_grid_details.user_grid_details_id' },
  #'mg_portfolio_header.portfolio_header_id' => { 'mg_portfolio_trades.portfolio_trades_id' => { 'mg_portfolio_trades_positions.portfolio_trades_positions_id' } },
  my @tables = eval(join('\n',$conf->config('cust_main-skeleton_tables')));
  die $@ if $@;

  _copy_skel( 'cust_main',                                 #tablename
              $conf->config('cust_main-skeleton_custnum'), #sourceid
              $self->custnum,                              #destid
              @tables,                                     #child tables
            );
}

#recursive subroutine, not a method
sub _copy_skel {
  my( $table, $sourceid, $destid, %child_tables ) = @_;

  my $primary_key;
  if ( $table =~ /^(\w+)\.(\w+)$/ ) {
    ( $table, $primary_key ) = ( $1, $2 );
  } else {
    my $dbdef_table = dbdef->table($table);
    $primary_key = $dbdef_table->primary_key
      or return "$table has no primary key".
                " (or do you need to run dbdef-create?)";
  }

  warn "  _copy_skel: $table.$primary_key $sourceid to $destid for ".
       join (', ', keys %child_tables). "\n"
    if $DEBUG > 2;

  foreach my $child_table_def ( keys %child_tables ) {

    my $child_table;
    my $child_pkey = '';
    if ( $child_table_def =~ /^(\w+)\.(\w+)$/ ) {
      ( $child_table, $child_pkey ) = ( $1, $2 );
    } else {
      $child_table = $child_table_def;

      $child_pkey = dbdef->table($child_table)->primary_key;
      #  or return "$table has no primary key".
      #            " (or do you need to run dbdef-create?)\n";
    }

    my $sequence = '';
    if ( keys %{ $child_tables{$child_table_def} } ) {

      return "$child_table has no primary key".
             " (run dbdef-create or try specifying it?)\n"
        unless $child_pkey;

      #false laziness w/Record::insert and only works on Pg
      #refactor the proper last-inserted-id stuff out of Record::insert if this
      # ever gets use for anything besides a quick kludge for one customer
      my $default = dbdef->table($child_table)->column($child_pkey)->default;
      $default =~ /^nextval\(\(?'"?([\w\.]+)"?'/i
        or return "can't parse $child_table.$child_pkey default value ".
                  " for sequence name: $default";
      $sequence = $1;

    }
  
    my @sel_columns = grep { $_ ne $primary_key }
                           dbdef->table($child_table)->columns;
    my $sel_columns = join(', ', @sel_columns );

    my @ins_columns = grep { $_ ne $child_pkey } @sel_columns;
    my $ins_columns = ' ( '. join(', ', $primary_key, @ins_columns ). ' ) ';
    my $placeholders = ' ( ?, '. join(', ', map '?', @ins_columns ). ' ) ';

    my $sel_st = "SELECT $sel_columns FROM $child_table".
                 " WHERE $primary_key = $sourceid";
    warn "    $sel_st\n"
      if $DEBUG > 2;
    my $sel_sth = dbh->prepare( $sel_st )
      or return dbh->errstr;
  
    $sel_sth->execute or return $sel_sth->errstr;

    while ( my $row = $sel_sth->fetchrow_hashref ) {

      warn "    selected row: ".
           join(', ', map { "$_=".$row->{$_} } keys %$row ). "\n"
        if $DEBUG > 2;

      my $statement =
        "INSERT INTO $child_table $ins_columns VALUES $placeholders";
      my $ins_sth =dbh->prepare($statement)
          or return dbh->errstr;
      my @param = ( $destid, map $row->{$_}, @ins_columns );
      warn "    $statement: [ ". join(', ', @param). " ]\n"
        if $DEBUG > 2;
      $ins_sth->execute( @param )
        or return $ins_sth->errstr;

      #next unless keys %{ $child_tables{$child_table} };
      next unless $sequence;
      
      #another section of that laziness
      my $seq_sql = "SELECT currval('$sequence')";
      my $seq_sth = dbh->prepare($seq_sql) or return dbh->errstr;
      $seq_sth->execute or return $seq_sth->errstr;
      my $insertid = $seq_sth->fetchrow_arrayref->[0];
  
      # don't drink soap!  recurse!  recurse!  okay!
      my $error =
        _copy_skel( $child_table_def,
                    $row->{$child_pkey}, #sourceid
                    $insertid, #destid
                    %{ $child_tables{$child_table_def} },
                  );
      return $error if $error;

    }

  }

  return '';

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

Services can be new, in which case they are inserted, or existing unaudited
services, in which case they are linked to the newly-created package.

Currently available options are: I<depend_jobnum> and I<noexport>.

If I<depend_jobnum> is set, all provisioning jobs will have a dependancy
on the supplied jobnum (they will not run until the specific job completes).
This can be used to defer provisioning until some action completes (such
as running the customer's credit card successfully).

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
  warn "$me order_pkgs called with options ".
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
      if ( $svc_something->svcnum ) {
        my $old_cust_svc = $svc_something->cust_svc;
        my $new_cust_svc = new FS::cust_svc { $old_cust_svc->hash };
        $new_cust_svc->pkgnum( $cust_pkg->pkgnum);
        $error = $new_cust_svc->replace($old_cust_svc);
      } else {
        $svc_something->pkgnum( $cust_pkg->pkgnum );
        if ( $seconds && $$seconds && $svc_something->isa('FS::svc_acct') ) {
          $svc_something->seconds( $svc_something->seconds + $$seconds );
          $$seconds = 0;
        }
        $error = $svc_something->insert(%svc_options);
      }
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

=item recharge_prepay IDENTIFIER | PREPAY_CREDIT_OBJ [ , AMOUNTREF, SECONDSREF, UPBYTEREF, DOWNBYTEREF ]

Recharges this (existing) customer with the specified prepaid card (see
L<FS::prepay_credit>), specified either by I<identifier> or as an
FS::prepay_credit object.  If there is an error, returns the error, otherwise
returns false.

Optionally, four scalar references can be passed as well.  They will have their
values filled in with the amount, number of seconds, and number of upload and
download bytes applied by this prepaid
card.

=cut

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

  my $error = $self->get_prepay($prepay_credit, \$amount,
                                \$seconds, \$upbytes, \$downbytes, \$totalbytes)
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

=item get_prepay IDENTIFIER | PREPAY_CREDIT_OBJ , AMOUNTREF, SECONDSREF

Looks up and deletes a prepaid card (see L<FS::prepay_credit>),
specified either by I<identifier> or as an FS::prepay_credit object.

References to I<amount> and I<seconds> scalars should be passed as arguments
and will be incremented by the values of the prepaid card.

If the prepaid card specifies an I<agentnum> (see L<FS::agent>), it is used to
check or set this customer's I<agentnum>.

If there is an error, returns the error, otherwise returns false.

=cut


sub get_prepay {
  my( $self, $prepay_credit, $amountref, $secondsref,
      $upref, $downref, $totalref) = @_;

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
      { 'identifier' => $prepay_credit },
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

  $$amountref  += $prepay_credit->amount;
  $$secondsref += $prepay_credit->seconds;
  $$upref      += $prepay_credit->upbytes;
  $$downref    += $prepay_credit->downbytes;
  $$totalref   += $prepay_credit->totalbytes;

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

=item reexport

This method is deprecated.  See the I<depend_jobnum> option to the insert and
order_pkgs methods for a better way to defer provisioning.

Re-schedules all exports by calling the B<reexport> method of all associated
packages (see L<FS::cust_pkg>).  If there is an error, returns the error;
otherwise returns false.

=cut

sub reexport {
  my $self = shift;

  carp "WARNING: FS::cust_main::reexport is deprectated; ".
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

=item replace [ OLD_RECORD ] [ INVOICING_LIST_ARYREF ]

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

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $self->replace_old;

  my @param = @_;

  warn "$me replace called\n"
    if $DEBUG;

  my $curuser = $FS::CurrentUser::CurrentUser;
  if (    $self->payby eq 'COMP'
       && $self->payby ne $old->payby
       && ! $curuser->access_right('Complimentary customer')
     )
  {
    return "You are not permitted to create complimentary accounts.";
  }

  local($ignore_expired_card) = 1
    if $old->payby  =~ /^(CARD|DCRD)$/
    && $self->payby =~ /^(CARD|DCRD)$/
    && ( $old->payinfo eq $self->payinfo || $old->paymask eq $self->paymask );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

  unless ( $import || $skip_fuzzyfiles ) {
    $error = $self->queue_fuzzyfiles_update;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "updating fuzzy search cache: $error";
    }
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
  my $error = $queue->insert( map $self->getfield($_),
                                  qw(first last company)
                            );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "queueing job (transaction rolled back): $error";
  }

  if ( $self->ship_last ) {
    $queue = new FS::queue { 'job' => 'FS::cust_main::append_fuzzyfiles' };
    $error = $queue->insert( map $self->getfield("ship_$_"),
                                 qw(first last company)
                           );
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
    || $self->ut_textn('custbatch')
    || $self->ut_name('last')
    || $self->ut_name('first')
    || $self->ut_snumbern('birthdate')
    || $self->ut_snumbern('signupdate')
    || $self->ut_textn('company')
    || $self->ut_text('address1')
    || $self->ut_textn('address2')
    || $self->ut_text('city')
    || $self->ut_textn('county')
    || $self->ut_textn('state')
    || $self->ut_country('country')
    || $self->ut_anything('comments')
    || $self->ut_numbern('referral_custnum')
    || $self->ut_textn('stateid')
    || $self->ut_textn('stateid_state')
    || $self->ut_textn('invoice_terms')
  ;

  #barf.  need message catalogs.  i18n.  etc.
  $error .= "Please select an advertising source."
    if $error =~ /^Illegal or empty \(numeric\) refnum: /;
  return $error if $error;

  return "Unknown agent"
    unless qsearchs( 'agent', { 'agentnum' => $self->agentnum } );

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

  if ( $conf->exists('cust_main-require_phone')
       && ! length($self->daytime) && ! length($self->night)
     ) {

    my $daytime_label = FS::Msgcat::_gettext('daytime') =~ /^(daytime)?$/
                          ? 'Day Phone'
                          : FS::Msgcat::_gettext('daytime');
    my $night_label = FS::Msgcat::_gettext('night') =~ /^(night)?$/
                        ? 'Night Phone'
                        : FS::Msgcat::_gettext('night');
  
    return "$daytime_label or $night_label is required"
  
  }

  if ( $self->has_ship_address
       && scalar ( grep { $self->getfield($_) ne $self->getfield("ship_$_") }
                        $self->addr_fields )
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
        unless qsearch('cust_main_county',{
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

    return "Unit # is required."
      if $self->ship_address2 =~ /^\s*$/
      && $conf->exists('cust_main-require_address2');

  } else { # ship_ info eq billing info, so don't store dup info in database

    $self->setfield("ship_$_", '')
      foreach $self->addr_fields;

    return "Unit # is required."
      if $self->address2 =~ /^\s*$/
      && $conf->exists('cust_main-require_address2');

  }

  #$self->payby =~ /^(CARD|DCRD|CHEK|DCHK|LECB|BILL|COMP|PREPAY|CASH|WEST|MCRD)$/
  #  or return "Illegal payby: ". $self->payby;
  #$self->payby($1);
  FS::payby->can_payby($self->table, $self->payby)
    or return "Illegal payby: ". $self->payby;

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

  my $check_payinfo = 1;

  if ($self->is_encrypted($self->payinfo)) {
    $check_payinfo = 0;
  }

  if ( $check_payinfo && $self->payby =~ /^(CARD|DCRD)$/ ) {

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

    my $ban = qsearchs('banned_pay', $self->_banned_pay_hashref);
    if ( $ban ) {
      return 'Banned credit card: banned on '.
             time2str('%a %h %o at %r', $ban->_date).
             ' by '. $ban->otaker.
             ' (ban# '. $ban->bannum. ')';
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

  } elsif ( $check_payinfo && $self->payby =~ /^(CHEK|DCHK)$/ ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/[^\d\@]//g;
    if ( $conf->exists('echeck-nonus') ) {
      $payinfo =~ /^(\d+)\@(\d+)$/ or return 'invalid echeck account@aba';
      $payinfo = "$1\@$2";
    } else {
      $payinfo =~ /^(\d+)\@(\d{9})$/ or return 'invalid echeck account@aba';
      $payinfo = "$1\@$2";
    }
    $self->payinfo($payinfo);
    $self->paycvv('');

    my $ban = qsearchs('banned_pay', $self->_banned_pay_hashref);
    if ( $ban ) {
      return 'Banned ACH account: banned on '.
             time2str('%a %h %o at %r', $ban->_date).
             ' by '. $ban->otaker.
             ' (ban# '. $ban->bannum. ')';
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

  if ( $self->paydate eq '' || $self->paydate eq '-' ) {
    return "Expiration date required"
      unless $self->payby =~ /^(BILL|PREPAY|CHEK|DCHK|LECB|CASH|WEST|MCRD)$/;
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
    $self->payname =~ /^([\w \,\.\-\'\&]+)$/
      or return gettext('illegal_name'). " payname: ". $self->payname;
    $self->payname($1);
  }

  foreach my $flag (qw( tax spool_cdr squelch_cdr )) {
    $self->$flag() =~ /^(Y?)$/ or return "Illegal $flag: ". $self->$flag();
    $self->$flag($1);
  }

  $self->otaker(getotaker) unless $self->otaker;

  warn "$me check AFTER: \n". $self->_dump
    if $DEBUG > 2;

  $self->SUPER::check;
}

=item addr_fields 

Returns a list of fields which have ship_ duplicates.

=cut

sub addr_fields {
  qw( last first company
      address1 address2 city county state zip country
      daytime night fax
    );
}

=item has_ship_address

Returns true if this customer record has a separate shipping address.

=cut

sub has_ship_address {
  my $self = shift;
  scalar( grep { $self->getfield("ship_$_") ne '' } $self->addr_fields );
}

=item all_pkgs

Returns all packages (see L<FS::cust_pkg>) for this customer.

=cut

sub all_pkgs {
  my $self = shift;

  return $self->num_pkgs unless wantarray;

  my @cust_pkg = ();
  if ( $self->{'_pkgnum'} ) {
    @cust_pkg = values %{ $self->{'_pkgnum'}->cache };
  } else {
    @cust_pkg = qsearch( 'cust_pkg', { 'custnum' => $self->custnum });
  }

  sort sort_packages @cust_pkg;
}

=item cust_pkg

Synonym for B<all_pkgs>.

=cut

sub cust_pkg {
  shift->all_pkgs(@_);
}

=item ncancelled_pkgs

Returns all non-cancelled packages (see L<FS::cust_pkg>) for this customer.

=cut

sub ncancelled_pkgs {
  my $self = shift;

  return $self->num_ncancelled_pkgs unless wantarray;

  my @cust_pkg = ();
  if ( $self->{'_pkgnum'} ) {

    warn "$me ncancelled_pkgs: returning cached objects"
      if $DEBUG > 1;

    @cust_pkg = grep { ! $_->getfield('cancel') }
                values %{ $self->{'_pkgnum'}->cache };

  } else {

    warn "$me ncancelled_pkgs: searching for packages with custnum ".
         $self->custnum. "\n"
      if $DEBUG > 1;

    @cust_pkg =
      qsearch( 'cust_pkg', {
                             'custnum' => $self->custnum,
                             'cancel'  => '',
                           });
    push @cust_pkg,
      qsearch( 'cust_pkg', {
                             'custnum' => $self->custnum,
                             'cancel'  => 0,
                           });
  }

  sort sort_packages @cust_pkg;

}

# This should be generalized to use config options to determine order.
sub sort_packages {
  if ( $a->get('cancel') and $b->get('cancel') ) {
    $a->pkgnum <=> $b->pkgnum;
  } elsif ( $a->get('cancel') or $b->get('cancel') ) {
    return -1 if $b->get('cancel');
    return  1 if $a->get('cancel');
    return 0;
  } else {
    $a->pkgnum <=> $b->pkgnum;
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
  shift->num_pkgs("cust_pkg.cancel IS NOT NULL AND cust_pkg.cancel != 0");
}

sub num_ncancelled_pkgs {
  shift->num_pkgs("( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )");
}

sub num_pkgs {
  my( $self ) = shift;
  my $sql = scalar(@_) ? shift : '';
  $sql = "AND $sql" if $sql && $sql !~ /^\s*$/ && $sql !~ /^\s*AND/i;
  my $sth = dbh->prepare(
    "SELECT COUNT(*) FROM cust_pkg WHERE custnum = ? $sql"
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

Available options are:

=over 4

=item quiet - can be set true to supress email cancellation notices.

=item reason - can be set to a cancellation reason (see L<FS:reason>), either a reasonnum of an existing reason, or passing a hashref will create a new reason.  The hashref should have the following keys: typenum - Reason type (see L<FS::reason_type>, reason - Text of the new reason.

=item ban - can be set true to ban this customer's credit card or ACH information, if present.

=back

Always returns a list: an empty list on success or a list of errors.

=cut

sub cancel {
  my( $self, %opt ) = @_;

  warn "$me cancel called on customer ". $self->custnum. " with options ".
       join(', ', map { "$_: $opt{$_}" } keys %opt ). "\n"
    if $DEBUG;

  return ( 'access denied' )
    unless $FS::CurrentUser::CurrentUser->access_right('Cancel customer');

  if ( $opt{'ban'} && $self->payby =~ /^(CARD|DCRD|CHEK|DCHK)$/ ) {

    #should try decryption (we might have the private key)
    # and if not maybe queue a job for the server that does?
    return ( "Can't (yet) ban encrypted credit cards" )
      if $self->is_encrypted($self->payinfo);

    my $ban = new FS::banned_pay $self->_banned_pay_hashref;
    my $error = $ban->insert;
    return ( $error ) if $error;

  }

  my @pkgs = $self->ncancelled_pkgs;

  warn "$me cancelling ". scalar($self->ncancelled_pkgs). "/".
       scalar(@pkgs). " packages for customer ". $self->custnum. "\n"
    if $DEBUG;

  grep { $_ } map { $_->cancel(%opt) } $self->ncancelled_pkgs;
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
    'payinfo' => md5_base64($self->payinfo),
    #don't ever *search* on reason! #'reason'  =>
  };
}

=item notes

Returns all notes (see L<FS::cust_main_note>) for this customer.

=cut

sub notes {
  my $self = shift;
  #order by?
  qsearch( 'cust_main_note',
           { 'custnum' => $self->custnum },
	   '',
	   'ORDER BY _DATE DESC'
	 );
}

=item agent

Returns the agent (see L<FS::agent>) for this customer.

=cut

sub agent {
  my $self = shift;
  qsearchs( 'agent', { 'agentnum' => $self->agentnum } );
}

=item bill_and_collect 

Cancels and suspends any packages due, generates bills, applies payments and
cred

Warns on errors (Does not currently: If there is an error, returns the error, otherwise returns false.)

Options are passed as name-value pairs.  Currently available options are:

=over 4

=item time

Bills the customer as if it were that time.  Specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion functions.  For example:

 use Date::Parse;
 ...
 $cust_main->bill( 'time' => str2time('April 20th, 2001') );

=item invoice_time

Used in conjunction with the I<time> option, this option specifies the date of for the generated invoices.  Other calculations, such as whether or not to generate the invoice in the first place, are not affected.

=item check_freq

"1d" for the traditional, daily events (the default), or "1m" for the new monthly events (part_event.check_freq)

=item resetup

If set true, re-charges setup fees.

=item debug

Debugging level.  Default is 0 (no debugging), or can be set to 1 (passed-in options), 2 (traces progress), 3 (more information), or 4 (include full search queries)

=back

=cut

sub bill_and_collect {
  my( $self, %options ) = @_;

  ###
  # cancel packages
  ###

  #$options{actual_time} not $options{time} because freeside-daily -d is for
  #pre-printing invoices
  my @cancel_pkgs = grep { $_->expire && $_->expire <= $options{actual_time} }
                         $self->ncancelled_pkgs;

  foreach my $cust_pkg ( @cancel_pkgs ) {
    my $cpr = $cust_pkg->last_cust_pkg_reason('expire');
    my $error = $cust_pkg->cancel($cpr ? ( 'reason' => $cpr->reasonnum,
                                           'reason_otaker' => $cpr->otaker
                                         )
                                       : ()
                                 );
    warn "Error cancelling expired pkg ". $cust_pkg->pkgnum.
         " for custnum ". $self->custnum. ": $error"
      if $error;
  }

  ###
  # suspend packages
  ###

  #$options{actual_time} not $options{time} because freeside-daily -d is for
  #pre-printing invoices
  my @susp_pkgs = 
    grep { ! $_->susp
           && (    (    $_->part_pkg->is_prepaid
                     && $_->bill
                     && $_->bill < $options{actual_time}
                   )
                || (    $_->adjourn
                    && $_->adjourn <= $options{actual_time}
                  )
              )
         }
         $self->ncancelled_pkgs;

  foreach my $cust_pkg ( @susp_pkgs ) {
    my $cpr = $cust_pkg->last_cust_pkg_reason('adjourn')
      if ($cust_pkg->adjourn && $cust_pkg->adjourn < $^T);
    my $error = $cust_pkg->suspend($cpr ? ( 'reason' => $cpr->reasonnum,
                                            'reason_otaker' => $cpr->otaker
                                          )
                                        : ()
                                  );

    warn "Error suspending package ". $cust_pkg->pkgnum.
         " for custnum ". $self->custnum. ": $error"
      if $error;
  }

  ###
  # bill and collect
  ###

  my $error = $self->bill( %options );
  warn "Error billing, custnum ". $self->custnum. ": $error" if $error;

  $self->apply_payments_and_credits;

  $error = $self->collect( %options );
  warn "Error collecting, custnum". $self->custnum. ": $error" if $error;

}

=item bill OPTIONS

Generates invoices (see L<FS::cust_bill>) for this customer.  Usually used in
conjunction with the collect method by calling B<bill_and_collect>.

If there is an error, returns the error, otherwise returns false.

Options are passed as name-value pairs.  Currently available options are:

=over 4

=item resetup

If set true, re-charges setup fees.

=item time

Bills the customer as if it were that time.  Specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion functions.  For example:

 use Date::Parse;
 ...
 $cust_main->bill( 'time' => str2time('April 20th, 2001') );

=item pkg_list

An array ref of specific packages (objects) to attempt billing, instead trying all of them.

 $cust_main->bill( pkg_list => [$pkg1, $pkg2] );

=item invoice_time

Used in conjunction with the I<time> option, this option specifies the date of for the generated invoices.  Other calculations, such as whether or not to generate the invoice in the first place, are not affected.

=back

=cut

sub bill {
  my( $self, %options ) = @_;
  return '' if $self->payby eq 'COMP';
  warn "$me bill customer ". $self->custnum. "\n"
    if $DEBUG;

  my $time = $options{'time'} || time;

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

  my @cust_bill_pkg = ();

  ###
  # find the packages which are due for billing, find out how much they are
  # & generate invoice database.
  ###

  my( $total_setup, $total_recur, $postal_charge ) = ( 0, 0, 0 );
  my %tax;
  my %taxlisthash;
  my %taxname;
  my @precommit_hooks = ();

  my @cust_pkgs = qsearch('cust_pkg', { 'custnum' => $self->custnum } );
  foreach my $cust_pkg (@cust_pkgs) {

    #NO!! next if $cust_pkg->cancel;  
    next if $cust_pkg->getfield('cancel');  

    warn "  bill package ". $cust_pkg->pkgnum. "\n" if $DEBUG > 1;

    #? to avoid use of uninitialized value errors... ?
    $cust_pkg->setfield('bill', '')
      unless defined($cust_pkg->bill);
 
    #my $part_pkg = $cust_pkg->part_pkg;

    my $real_pkgpart = $cust_pkg->pkgpart;
    my %hash = $cust_pkg->hash;

    foreach my $part_pkg ( $cust_pkg->part_pkg->self_and_bill_linked ) {

      $cust_pkg->set($_, $hash{$_}) foreach qw ( setup last_bill bill );

      my $error =
        $self->_make_lines( 'part_pkg'            => $part_pkg,
                            'cust_pkg'            => $cust_pkg,
                            'precommit_hooks'     => \@precommit_hooks,
                            'line_items'          => \@cust_bill_pkg,
                            'setup'               => \$total_setup,
                            'recur'               => \$total_recur,
                            'tax_matrix'          => \%taxlisthash,
                            'time'                => $time,
                            'options'             => \%options,
                          );
      if ($error) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

    } #foreach my $part_pkg

  } #foreach my $cust_pkg

  unless ( @cust_bill_pkg ) { #don't create an invoice w/o line items
    #but do commit any package date cycling that happened
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return '';
  }

  my $postal_pkg = $self->charge_postal_fee();
  if ( $postal_pkg && !ref( $postal_pkg ) ) {
    $dbh->rollback if $oldAutoCommit;
    return "can't charge postal invoice fee for customer ".
      $self->custnum. ": $postal_pkg";
  }
  if ( $postal_pkg &&
       ( scalar( grep { $_->recur && $_->recur > 0 } @cust_bill_pkg) ||
         !$conf->exists('postal_invoice-recurring_only')
       )
     )
  {
    foreach my $part_pkg ( $postal_pkg->part_pkg->self_and_bill_linked ) {
      my $error =
        $self->_make_lines( 'part_pkg'            => $part_pkg,
                            'cust_pkg'            => $postal_pkg,
                            'precommit_hooks'     => \@precommit_hooks,
                            'line_items'          => \@cust_bill_pkg,
                            'setup'               => \$total_setup,
                            'recur'               => \$total_recur,
                            'tax_matrix'          => \%taxlisthash,
                            'time'                => $time,
                            'options'             => \%options,
                          );
      if ($error) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  warn "having a look at the taxes we found...\n" if $DEBUG > 2;
  foreach my $tax ( keys %taxlisthash ) {
    my $tax_object = shift @{ $taxlisthash{$tax} };
    warn "found ". $tax_object->taxname. " as $tax\n" if $DEBUG > 2;
    my $listref_or_error = $tax_object->taxline( @{ $taxlisthash{$tax} } );
    unless (ref($listref_or_error)) {
      $dbh->rollback if $oldAutoCommit;
      return $listref_or_error;
    }
    unshift @{ $taxlisthash{$tax} }, $tax_object;

    warn "adding ". $listref_or_error->[1].
         " as ". $listref_or_error->[0]. "\n"
      if $DEBUG > 2;
    $tax{ $tax_object->taxname } += $listref_or_error->[1];
    if ( $taxname{ $listref_or_error->[0] } ) {
      push @{ $taxname{ $listref_or_error->[0] } }, $tax_object->taxname;
    }else{
      $taxname{ $listref_or_error->[0] } = [ $tax_object->taxname ];
    }
  
  }

  #some taxes are taxed
  my %totlisthash;
  
  warn "finding taxed taxes...\n" if $DEBUG > 2;
  foreach my $tax ( keys %taxlisthash ) {
    my $tax_object = shift @{ $taxlisthash{$tax} };
    warn "found possible taxed tax ". $tax_object->taxname. " we call $tax\n"
      if $DEBUG > 2;
    next unless $tax_object->can('tax_on_tax');

    foreach my $tot ( $tax_object->tax_on_tax( $self ) ) {
      my $totname = ref( $tot ). ' '. $tot->taxnum;

      warn "checking $totname which we call ". $tot->taxname. " as applicable\n"
        if $DEBUG > 2;
      next unless exists( $taxlisthash{ $totname } ); # only increase
                                                      # existing taxes
      warn "adding $totname to taxed taxes\n" if $DEBUG > 2;
      if ( exists( $totlisthash{ $totname } ) ) {
        push @{ $totlisthash{ $totname  } }, $tax{ $tax_object->taxname };
      }else{
        $totlisthash{ $totname } = [ $tot, $tax{ $tax_object->taxname } ];
      }
    }
  }

  warn "having a look at taxed taxes...\n" if $DEBUG > 2;
  foreach my $tax ( keys %totlisthash ) {
    my $tax_object = shift @{ $totlisthash{$tax} };
    warn "found previously found taxed tax ". $tax_object->taxname. "\n"
      if $DEBUG > 2;
    my $listref_or_error = $tax_object->taxline( @{ $totlisthash{$tax} } );
    unless (ref($listref_or_error)) {
      $dbh->rollback if $oldAutoCommit;
      return $listref_or_error;
    }

    warn "adding taxed tax amount ". $listref_or_error->[1].
         " as ". $tax_object->taxname. "\n"
      if $DEBUG;
    $tax{ $tax_object->taxname } += $listref_or_error->[1];
  }
  
  #consolidate and create tax line items
  warn "consolidating and generating...\n" if $DEBUG > 2;
  foreach my $taxname ( keys %taxname ) {
    my $tax = 0;
    my %seen = ();
    warn "adding $taxname\n" if $DEBUG > 1;
    foreach my $taxitem ( @{ $taxname{$taxname} } ) {
      $tax += $tax{$taxitem} unless $seen{$taxitem};
      warn "adding $tax{$taxitem}\n" if $DEBUG > 1;
    }
    next unless $tax;

    $tax = sprintf('%.2f', $tax );
    $total_setup = sprintf('%.2f', $total_setup+$tax );
  
    push @cust_bill_pkg, new FS::cust_bill_pkg {
      'pkgnum'   => 0,
      'setup'    => $tax,
      'recur'    => 0,
      'sdate'    => '',
      'edate'    => '',
      'itemdesc' => $taxname,
    };

  }

  my $charged = sprintf('%.2f', $total_setup + $total_recur );

  #create the new invoice
  my $cust_bill = new FS::cust_bill ( {
    'custnum' => $self->custnum,
    '_date'   => ( $options{'invoice_time'} || $time ),
    'charged' => $charged,
  } );
  my $error = $cust_bill->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "can't create invoice for customer #". $self->custnum. ": $error";
  }

  foreach my $cust_bill_pkg ( @cust_bill_pkg ) {
    $cust_bill_pkg->invnum($cust_bill->invnum); 
    my $error = $cust_bill_pkg->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't create invoice line item: $error";
    }
  }
    

  foreach my $hook ( @precommit_hooks ) { 
    eval {
      &{$hook}; #($self) ?
    };
    if ( $@ ) {
      $dbh->rollback if $oldAutoCommit;
      return "$@ running precommit hook $hook\n";
    }
  }
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}


sub _make_lines {
  my ($self, %params) = @_;

  my $part_pkg = $params{part_pkg} or die "no part_pkg specified";
  my $cust_pkg = $params{cust_pkg} or die "no cust_pkg specified";
  my $precommit_hooks = $params{precommit_hooks} or die "no package specified";
  my $cust_bill_pkgs = $params{line_items} or die "no line buffer specified";
  my $total_setup = $params{setup} or die "no setup accumulator specified";
  my $total_recur = $params{recur} or die "no recur accumulator specified";
  my $taxlisthash = $params{tax_matrix} or die "no tax accumulator specified";
  my $time = $params{'time'} or die "no time specified";
  my (%options) = %{$params{options}};  #hmmm  only for 'resetup'

  my $dbh = dbh;
  my $real_pkgpart = $cust_pkg->pkgpart;
  my %hash = $cust_pkg->hash;
  my $old_cust_pkg = new FS::cust_pkg \%hash;

  my @details = ();

  my $lineitems = 0;

  $cust_pkg->pkgpart($part_pkg->pkgpart);

  ###
  # bill setup
  ###

  my $setup = 0;
  my $unitsetup = 0;
  if ( ! $cust_pkg->setup &&
       (
         ( $conf->exists('disable_setup_suspended_pkgs') &&
          ! $cust_pkg->getfield('susp')
        ) || ! $conf->exists('disable_setup_suspended_pkgs')
       )
    || $options{'resetup'}
  ) {
    
    warn "    bill setup\n" if $DEBUG > 1;
    $lineitems++;

    $setup = eval { $cust_pkg->calc_setup( $time, \@details ) };
    return "$@ running calc_setup for $cust_pkg\n"
      if $@;

    $unitsetup = $cust_pkg->part_pkg->unit_setup || $setup; #XXX uuh

    $cust_pkg->setfield('setup', $time)
      unless $cust_pkg->setup;
          #do need it, but it won't get written to the db
          #|| $cust_pkg->pkgpart != $real_pkgpart;

  }

  ###
  # bill recurring fee
  ### 

  #XXX unit stuff here too
  my $recur = 0;
  my $unitrecur = 0;
  my $sdate;
  if ( $part_pkg->getfield('freq') ne '0' &&
       ! $cust_pkg->getfield('susp') &&
       ( $cust_pkg->getfield('bill') || 0 ) <= $time
  ) {

    # XXX should this be a package event?  probably.  events are called
    # at collection time at the moment, though...
    $part_pkg->reset_usage($cust_pkg, 'debug'=>$DEBUG)
      if $part_pkg->can('reset_usage');
      #don't want to reset usage just cause we want a line item??
      #&& $part_pkg->pkgpart == $real_pkgpart;

    warn "    bill recur\n" if $DEBUG > 1;
    $lineitems++;

    # XXX shared with $recur_prog
    $sdate = $cust_pkg->bill || $cust_pkg->setup || $time;

    #over two params!  lets at least switch to a hashref for the rest...
    my %param = ( 'precommit_hooks' => $precommit_hooks, );

    $recur = eval { $cust_pkg->calc_recur( \$sdate, \@details, \%param ) };
    return "$@ running calc_recur for $cust_pkg\n"
      if ( $@ );

  
    #change this bit to use Date::Manip? CAREFUL with timezones (see
    # mailing list archive)
    my ($sec,$min,$hour,$mday,$mon,$year) =
      (localtime($sdate) )[0,1,2,3,4,5];
    
    #pro-rating magic - if $recur_prog fiddles $sdate, want to use that
    # only for figuring next bill date, nothing else, so, reset $sdate again
    # here
    $sdate = $cust_pkg->bill || $cust_pkg->setup || $time;
    #no need, its in $hash{last_bill}# my $last_bill = $cust_pkg->last_bill;
    $cust_pkg->last_bill($sdate);
    
    if ( $part_pkg->freq =~ /^\d+$/ ) {
      $mon += $part_pkg->freq;
      until ( $mon < 12 ) { $mon -= 12; $year++; }
    } elsif ( $part_pkg->freq =~ /^(\d+)w$/ ) {
      my $weeks = $1;
      $mday += $weeks * 7;
    } elsif ( $part_pkg->freq =~ /^(\d+)d$/ ) {
      my $days = $1;
      $mday += $days;
    } elsif ( $part_pkg->freq =~ /^(\d+)h$/ ) {
      my $hours = $1;
      $hour += $hours;
    } else {
      return "unparsable frequency: ". $part_pkg->freq;
    }
    $cust_pkg->setfield('bill',
      timelocal_nocheck($sec,$min,$hour,$mday,$mon,$year));

  }

  warn "\$setup is undefined" unless defined($setup);
  warn "\$recur is undefined" unless defined($recur);
  warn "\$cust_pkg->bill is undefined" unless defined($cust_pkg->bill);
  
  ###
  # If there's line items, create em cust_bill_pkg records
  # If $cust_pkg has been modified, update it (if we're a real pkgpart)
  ###

  if ( $lineitems ) {

    if ( $cust_pkg->modified && $cust_pkg->pkgpart == $real_pkgpart ) {
      # hmm.. and if just the options are modified in some weird price plan?
  
      warn "  package ". $cust_pkg->pkgnum. " modified; updating\n"
        if $DEBUG >1;
  
      my $error = $cust_pkg->replace( $old_cust_pkg,
                                      'options' => { $cust_pkg->options },
                                    );
      return "Error modifying pkgnum ". $cust_pkg->pkgnum. ": $error"
        if $error; #just in case
    }
  
    $setup = sprintf( "%.2f", $setup );
    $recur = sprintf( "%.2f", $recur );
    if ( $setup < 0 && ! $conf->exists('allow_negative_charges') ) {
      return "negative setup $setup for pkgnum ". $cust_pkg->pkgnum;
    }
    if ( $recur < 0 && ! $conf->exists('allow_negative_charges') ) {
      return "negative recur $recur for pkgnum ". $cust_pkg->pkgnum;
    }

    if ( $setup != 0 || $recur != 0 ) {

      warn "    charges (setup=$setup, recur=$recur); adding line items\n"
        if $DEBUG > 1;

      my @cust_pkg_detail = map { $_->detail } $cust_pkg->cust_pkg_detail('I');
      if ( $DEBUG > 1 ) {
        warn "      adding customer package invoice detail: $_\n"
          foreach @cust_pkg_detail;
      }
      push @details, @cust_pkg_detail;

      my $cust_bill_pkg = new FS::cust_bill_pkg {
        'pkgnum'    => $cust_pkg->pkgnum,
        'setup'     => $setup,
        'unitsetup' => $unitsetup,
        'recur'     => $recur,
        'unitrecur' => $unitrecur,
        'quantity'  => $cust_pkg->quantity,
        'details'   => \@details,
      };

      if ( $part_pkg->option('recur_temporality', 1) eq 'preceding' ) {
        $cust_bill_pkg->sdate( $hash{last_bill} );
        $cust_bill_pkg->edate( $sdate - 86399   ); #60s*60m*24h-1
      } else { #if ( $part_pkg->option('recur_temporality', 1) eq 'upcoming' ) {
        $cust_bill_pkg->sdate( $sdate );
        $cust_bill_pkg->edate( $cust_pkg->bill );
      }

      $cust_bill_pkg->pkgpart_override($part_pkg->pkgpart)
        unless $part_pkg->pkgpart == $real_pkgpart;

      $$total_setup += $setup;
      $$total_recur += $recur;

      ###
      # handle taxes
      ###

      my $error = 
        $self->_handle_taxes($part_pkg, $taxlisthash, $cust_bill_pkg, $cust_pkg);
      return $error if $error;

      push @$cust_bill_pkgs, $cust_bill_pkg;

    } #if $setup != 0 || $recur != 0
      
  } #if $line_items

  '';

}

sub _handle_taxes {
  my $self = shift;
  my $part_pkg = shift;
  my $taxlisthash = shift;
  my $cust_bill_pkg = shift;
  my $cust_pkg = shift;

  my %cust_bill_pkg = ();
  my %taxes = ();
    
  my $prefix = 
    ( $conf->exists('tax-ship_address') && length($self->ship_last) )
    ? 'ship_'
    : '';

  my @classes;
  #push @classes, $cust_bill_pkg->usage_classes if $cust_bill_pkg->type eq 'U';
  push @classes, $cust_bill_pkg->usage_classes if $cust_bill_pkg->usage;
  push @classes, 'setup' if $cust_bill_pkg->setup;
  push @classes, 'recur' if $cust_bill_pkg->recur;

  if ( $conf->exists('enable_taxproducts')
       && (scalar($part_pkg->part_pkg_taxoverride) || $part_pkg->has_taxproduct)
       && ( $self->tax !~ /Y/i && $self->payby ne 'COMP' )
     )
  { 

    foreach my $class (@classes) {
      my $err_or_ref = $self->_gather_taxes( $part_pkg, $class, $prefix );
      return $err_or_ref unless ref($err_or_ref);
      $taxes{$class} = $err_or_ref;
    }

    unless (exists $taxes{''}) {
      my $err_or_ref = $self->_gather_taxes( $part_pkg, '', $prefix );
      return $err_or_ref unless ref($err_or_ref);
      $taxes{''} = $err_or_ref;
    }

  } elsif ( $self->tax !~ /Y/i && $self->payby ne 'COMP' ) {

    my %taxhash = map { $_ => $self->get("$prefix$_") }
                      qw( state county country );

    $taxhash{'taxclass'} = $part_pkg->taxclass;

    my @taxes = qsearch( 'cust_main_county', \%taxhash );

    unless ( @taxes ) {
      $taxhash{'taxclass'} = '';
      @taxes =  qsearch( 'cust_main_county', \%taxhash );
    }

    #one more try at a whole-country tax rate
    unless ( @taxes ) {
      $taxhash{$_} = '' foreach qw( state county );
      @taxes =  qsearch( 'cust_main_county', \%taxhash );
    }

    $taxes{''} = [ @taxes ];
    $taxes{'setup'} = [ @taxes ];
    $taxes{'recur'} = [ @taxes ];
    $taxes{$_} = [ @taxes ] foreach (@classes);

    # maybe eliminate this entirely, along with all the 0% records
    unless ( @taxes ) {
      return
        "fatal: can't find tax rate for state/county/country/taxclass ".
        join('/', ( map $self->get("$prefix$_"),
                        qw(state county country)
                  ),
                  $part_pkg->taxclass ). "\n";
    }

  } #if $conf->exists('enable_taxproducts') ...
 
  my @display = ();
  if ( $conf->exists('separate_usage') ) {
    my $section = $cust_pkg->part_pkg->option('usage_section', 'Hush!');
    my $summary = $cust_pkg->part_pkg->option('summarize_usage', 'Hush!');
    push @display, new FS::cust_bill_pkg_display { type    => 'S' };
    push @display, new FS::cust_bill_pkg_display { type    => 'R' };
    push @display, new FS::cust_bill_pkg_display { type    => 'U',
                                                   section => $section
                                                 };
    if ($section && $summary) {
      $display[2]->post_total('Y');
      push @display, new FS::cust_bill_pkg_display { type    => 'U',
                                                     summary => 'Y',
                                                   }
    }
  }
  $cust_bill_pkg->set('display', \@display);

  my %tax_cust_bill_pkg = $cust_bill_pkg->disintegrate;
  foreach my $key (keys %tax_cust_bill_pkg) {
    my @taxes = @{ $taxes{$key} };
    my $tax_cust_bill_pkg = $tax_cust_bill_pkg{$key};

    foreach my $tax ( @taxes ) {
      my $taxname = ref( $tax ). ' '. $tax->taxnum;
      if ( exists( $taxlisthash->{ $taxname } ) ) {
        push @{ $taxlisthash->{ $taxname  } }, $tax_cust_bill_pkg;
      }else{
        $taxlisthash->{ $taxname } = [ $tax, $tax_cust_bill_pkg ];
      }
    }
  }

  '';
}

sub _gather_taxes {
  my $self = shift;
  my $part_pkg = shift;
  my $class = shift;
  my $prefix = shift;

  my @taxes = ();
  my $geocode = $self->geocode('cch');

  my @taxclassnums = map { $_->taxclassnum }
                     $part_pkg->part_pkg_taxoverride($class);

  unless (@taxclassnums) {
    @taxclassnums = map { $_->taxclassnum }
                    $part_pkg->part_pkg_taxrate('cch', $geocode, $class);
  }
  warn "Found taxclassnum values of ". join(',', @taxclassnums)
    if $DEBUG;

  my $extra_sql =
    "AND (".
    join(' OR ', map { "taxclassnum = $_" } @taxclassnums ). ")";

  @taxes = qsearch({ 'table' => 'tax_rate',
                     'hashref' => { 'geocode' => $geocode, },
                     'extra_sql' => $extra_sql,
                  })
    if scalar(@taxclassnums);

  # maybe eliminate this entirely, along with all the 0% records
  unless ( @taxes ) {
    return 
      "fatal: can't find tax rate for zip/taxproduct/pkgpart ".
      join('/', ( map $self->get("$prefix$_"),
                      qw(zip)
                ),
                $part_pkg->taxproduct_description,
                $part_pkg->pkgpart ). "\n";
  }

  warn "Found taxes ".
       join(',', map{ ref($_). " ". $_->get($_->primary_key) } @taxes). "\n" 
   if $DEBUG;

  [ @taxes ];

}

=item collect OPTIONS

(Attempt to) collect money for this customer's outstanding invoices (see
L<FS::cust_bill>).  Usually used after the bill method.

Actions are now triggered by billing events; see L<FS::part_event> and the
billing events web interface.  Old-style invoice events (see
L<FS::part_bill_event>) have been deprecated.

If there is an error, returns the error, otherwise returns false.

Options are passed as name-value pairs.

Currently available options are:

=over 4

=item invoice_time

Use this time when deciding when to print invoices and late notices on those invoices.  The default is now.  It is specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion functions.

=item retry

Retry card/echeck/LEC transactions even when not scheduled by invoice events.

=item quiet

set true to surpress email card/ACH decline notices.

=item check_freq

"1d" for the traditional, daily events (the default), or "1m" for the new monthly events (part_event.check_freq)

=item payby

allows for one time override of normal customer billing method

=item debug

Debugging level.  Default is 0 (no debugging), or can be set to 1 (passed-in options), 2 (traces progress), 3 (more information), or 4 (include full search queries)


=back

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

  if ( $DEBUG ) {
    my $balance = $self->balance;
    warn "$me collect customer ". $self->custnum. ": balance $balance\n"
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

  # false laziness w/pay_batch::import_results

  my $due_cust_event = $self->due_cust_event(
    'debug'      => ( $options{'debug'} || 0 ),
    'time'       => $invoice_time,
    'check_freq' => $options{'check_freq'},
  );
  unless( ref($due_cust_event) ) {
    $dbh->rollback if $oldAutoCommit;
    return $due_cust_event;
  }

  foreach my $cust_event ( @$due_cust_event ) {

    #XXX lock event
    
    #re-eval event conditions (a previous event could have changed things)
    unless ( $cust_event->test_conditions( 'time' => $invoice_time ) ) {
      #don't leave stray "new/locked" records around
      my $error = $cust_event->delete;
      if ( $error ) {
        #gah, even with transactions
        $dbh->commit if $oldAutoCommit; #well.
        return $error;
      }
      next;
    }

    {
      local $realtime_bop_decline_quiet = 1 if $options{'quiet'};
      warn "  running cust_event ". $cust_event->eventnum. "\n"
        if $DEBUG > 1;

      
      #if ( my $error = $cust_event->do_event(%options) ) { #XXX %options?
      if ( my $error = $cust_event->do_event() ) {
        #XXX wtf is this?  figure out a proper dealio with return value
        #from do_event
	  # gah, even with transactions.
	  $dbh->commit if $oldAutoCommit; #well.
	  return $error;
	}
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item due_cust_event [ HASHREF | OPTION => VALUE ... ]

Inserts database records for and returns an ordered listref of new events due
for this customer, as FS::cust_event objects (see L<FS::cust_event>).  If no
events are due, an empty listref is returned.  If there is an error, returns a
scalar error message.

To actually run the events, call each event's test_condition method, and if
still true, call the event's do_event method.

Options are passed as a hashref or as a list of name-value pairs.  Available
options are:

=over 4

=item check_freq

Search only for events of this check frequency (how often events of this type are checked); currently "1d" (daily, the default) and "1m" (monthly) are recognized.

=item time

"Current time" for the events.

=item debug

Debugging level.  Default is 0 (no debugging), or can be set to 1 (passed-in options), 2 (traces progress), 3 (more information), or 4 (include full search queries)

=item eventtable

Only return events for the specified eventtable (by default, events of all eventtables are returned)

=item objects

Explicitly pass the objects to be tested (typically used with eventtable).

=back

=cut

sub due_cust_event {
  my $self = shift;
  my %opt = ref($_[0]) ? %{ $_[0] } : @_;

  #???
  #my $DEBUG = $opt{'debug'}
  local($DEBUG) = $opt{'debug'}
    if defined($opt{'debug'}) && $opt{'debug'} > $DEBUG;

  warn "$me due_cust_event called with options ".
       join(', ', map { "$_: $opt{$_}" } keys %opt). "\n"
    if $DEBUG;

  $opt{'time'} ||= time;

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

  ###
  # 1: find possible events (initial search)
  ###
  
  my @cust_event = ();

  my @eventtable = $opt{'eventtable'}
                     ? ( $opt{'eventtable'} )
                     : FS::part_event->eventtables_runorder;

  foreach my $eventtable ( @eventtable ) {

    my @objects;
    if ( $opt{'objects'} ) {

      @objects = @{ $opt{'objects'} };

    } else {

      #my @objects = $self->eventtable(); # sub cust_main { @{ [ $self ] }; }
      @objects = ( $eventtable eq 'cust_main' )
                   ? ( $self )
                   : ( $self->$eventtable() );

    }

    my @e_cust_event = ();

    my $cross = "CROSS JOIN $eventtable";
    $cross .= ' LEFT JOIN cust_main USING ( custnum )'
      unless $eventtable eq 'cust_main';

    foreach my $object ( @objects ) {

      #this first search uses the condition_sql magic for optimization.
      #the more possible events we can eliminate in this step the better

      my $cross_where = '';
      my $pkey = $object->primary_key;
      $cross_where = "$eventtable.$pkey = ". $object->$pkey();

      my $join = FS::part_event_condition->join_conditions_sql( $eventtable );
      my $extra_sql =
        FS::part_event_condition->where_conditions_sql( $eventtable,
                                                        'time'=>$opt{'time'}
                                                      );
      my $order = FS::part_event_condition->order_conditions_sql( $eventtable );

      $extra_sql = "AND $extra_sql" if $extra_sql;

      #here is the agent virtualization
      $extra_sql .= " AND (    part_event.agentnum IS NULL
                            OR part_event.agentnum = ". $self->agentnum. ' )';

      $extra_sql .= " $order";

      warn "searching for events for $eventtable ". $object->$pkey. "\n"
        if $opt{'debug'} > 2;
      my @part_event = qsearch( {
        'debug'     => ( $opt{'debug'} > 3 ? 1 : 0 ),
        'select'    => 'part_event.*',
        'table'     => 'part_event',
        'addl_from' => "$cross $join",
        'hashref'   => { 'check_freq' => ( $opt{'check_freq'} || '1d' ),
                         'eventtable' => $eventtable,
                         'disabled'   => '',
                       },
        'extra_sql' => "AND $cross_where $extra_sql",
      } );

      if ( $DEBUG > 2 ) {
        my $pkey = $object->primary_key;
        warn "      ". scalar(@part_event).
             " possible events found for $eventtable ". $object->$pkey(). "\n";
      }

      push @e_cust_event, map { $_->new_cust_event($object) } @part_event;

    }

    warn "    ". scalar(@e_cust_event).
         " subtotal possible cust events found for $eventtable\n"
      if $DEBUG > 1;

    push @cust_event, @e_cust_event;

  }

  warn "  ". scalar(@cust_event).
       " total possible cust events found in initial search\n"
    if $DEBUG; # > 1;

  ##
  # 2: test conditions
  ##
  
  my %unsat = ();

  @cust_event = grep $_->test_conditions( 'time'          => $opt{'time'},
                                          'stats_hashref' => \%unsat ),
                     @cust_event;

  warn "  ". scalar(@cust_event). " cust events left satisfying conditions\n"
    if $DEBUG; # > 1;

  warn "    invalid conditions not eliminated with condition_sql:\n".
       join('', map "      $_: ".$unsat{$_}."\n", keys %unsat )
    if $DEBUG; # > 1;

  ##
  # 3: insert
  ##

  unless( $opt{testonly} ) {
    foreach my $cust_event ( @cust_event ) {

      my $error = $cust_event->insert();
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
                                       
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ##
  # 4: return
  ##

  warn "  returning events: ". Dumper(@cust_event). "\n"
    if $DEBUG > 2;

  \@cust_event;

}

=item retry_realtime

Schedules realtime / batch  credit card / electronic check / LEC billing
events for for retry.  Useful if card information has changed or manual
retry is desired.  The 'collect' method must be called to actually retry
the transaction.

Implementation details: For either this customer, or for each of this
customer's open invoices, changes the status of the first "done" (with
statustext error) realtime processing event to "failed".

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

  #a little false laziness w/due_cust_event (not too bad, really)

  my $join = FS::part_event_condition->join_conditions_sql;
  my $order = FS::part_event_condition->order_conditions_sql;
  my $mine = 
  '( '
   . join ( ' OR ' , map { 
    "( part_event.eventtable = " . dbh->quote($_) 
    . " AND tablenum IN( SELECT " . dbdef->table($_)->primary_key . " from $_ where custnum = " . dbh->quote( $self->custnum ) . "))" ;
   } FS::part_event->eventtables)
   . ') ';

  #here is the agent virtualization
  my $agent_virt = " (    part_event.agentnum IS NULL
                       OR part_event.agentnum = ". $self->agentnum. ' )';

  #XXX this shouldn't be hardcoded, actions should declare it...
  my @realtime_events = qw(
    cust_bill_realtime_card
    cust_bill_realtime_check
    cust_bill_realtime_lec
    cust_bill_batch
  );

  my $is_realtime_event = ' ( '. join(' OR ', map "part_event.action = '$_'",
                                                  @realtime_events
                                     ).
                          ' ) ';

  my @cust_event = qsearchs({
    'table'     => 'cust_event',
    'select'    => 'cust_event.*',
    'addl_from' => "LEFT JOIN part_event USING ( eventpart ) $join",
    'hashref'   => { 'status' => 'done' },
    'extra_sql' => " AND statustext IS NOT NULL AND statustext != '' ".
                   " AND $mine AND $is_realtime_event AND $agent_virt $order" # LIMIT 1"
  });

  my %seen_invnum = ();
  foreach my $cust_event (@cust_event) {

    #max one for the customer, one for each open invoice
    my $cust_X = $cust_event->cust_X;
    next if $seen_invnum{ $cust_event->part_event->eventtable eq 'cust_bill'
                          ? $cust_X->invnum
                          : 0
                        }++
         or $cust_event->part_event->eventtable eq 'cust_bill'
            && ! $cust_X->owed;

    my $error = $cust_event->retry;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error scheduling event for retry: $error";
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

Available options are: I<description>, I<invnum>, I<quiet>, I<paynum_ref>, I<payunique>

The additional options I<payname>, I<address1>, I<address2>, I<city>, I<state>,
I<zip>, I<payinfo> and I<paydate> are also available.  Any of these options,
if set, will override the value from the customer record.

I<description> is a free-text field passed to the gateway.  It defaults to
"Internet services".

If an I<invnum> is specified, this payment (if successful) is applied to the
specified invoice.  If you don't specify an I<invnum> you might want to
call the B<apply_payments> method.

I<quiet> can be set true to surpress email decline notices.

I<paynum_ref> can be set to a scalar reference.  It will be filled in with the
resulting paynum, if any.

I<payunique> is a unique identifier for this payment.

(moved from cust_bill) (probably should get realtime_{card,ach,lec} here too)

=cut

sub realtime_bop {
  my( $self, $method, $amount, %options ) = @_;
  if ( $DEBUG ) {
    warn "$me realtime_bop: $method $amount\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  $options{'description'} ||= 'Internet services';

  return $self->fake_bop($method, $amount, %options) if $options{'fake'};

  eval "use Business::OnlinePayment";  
  die $@ if $@;

  my $payinfo = exists($options{'payinfo'})
                  ? $options{'payinfo'}
                  : $self->payinfo;

  my %method2payby = (
    'CC'     => 'CARD',
    'ECHECK' => 'CHEK',
    'LEC'    => 'LECB',
  );

  ###
  # check for banned credit card/ACH
  ###

  my $ban = qsearchs('banned_pay', {
    'payby'   => $method2payby{$method},
    'payinfo' => md5_base64($payinfo),
  } );
  return "Banned credit card" if $ban;

  ###
  # select a gateway
  ###

  my $taxclass = '';
  if ( $options{'invnum'} ) {
    my $cust_bill = qsearchs('cust_bill', { 'invnum' => $options{'invnum'} } );
    die "invnum ". $options{'invnum'}. " not found" unless $cust_bill;
    my @taxclasses =
      map  { $_->part_pkg->taxclass }
      grep { $_ }
      map  { $_->cust_pkg }
      $cust_bill->cust_bill_pkg;
    unless ( grep { $taxclasses[0] ne $_ } @taxclasses ) { #unless there are
                                                           #different taxclasses
      $taxclass = $taxclasses[0];
    }
  }

  #look for an agent gateway override first
  my $cardtype;
  if ( $method eq 'CC' ) {
    $cardtype = cardtype($payinfo);
  } elsif ( $method eq 'ECHECK' ) {
    $cardtype = 'ACH';
  } else {
    $cardtype = $method;
  }

  my $override =
       qsearchs('agent_payment_gateway', { agentnum => $self->agentnum,
                                           cardtype => $cardtype,
                                           taxclass => $taxclass,       } )
    || qsearchs('agent_payment_gateway', { agentnum => $self->agentnum,
                                           cardtype => '',
                                           taxclass => $taxclass,       } )
    || qsearchs('agent_payment_gateway', { agentnum => $self->agentnum,
                                           cardtype => $cardtype,
                                           taxclass => '',              } )
    || qsearchs('agent_payment_gateway', { agentnum => $self->agentnum,
                                           cardtype => '',
                                           taxclass => '',              } );

  my $payment_gateway = '';
  my( $processor, $login, $password, $action, @bop_options );
  if ( $override ) { #use a payment gateway override

    $payment_gateway = $override->payment_gateway;

    $processor   = $payment_gateway->gateway_module;
    $login       = $payment_gateway->gateway_username;
    $password    = $payment_gateway->gateway_password;
    $action      = $payment_gateway->gateway_action;
    @bop_options = $payment_gateway->options;

  } else { #use the standard settings from the config

    ( $processor, $login, $password, $action, @bop_options ) =
      $self->default_payment_gateway($method);

  }

  ###
  # massage data
  ###

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

  my @invoicing_list = $self->invoicing_list_emailonly;
  if ( $conf->exists('emailinvoiceautoalways')
       || $conf->exists('emailinvoiceauto') && ! @invoicing_list
       || ( $conf->exists('emailinvoiceonly') && ! @invoicing_list ) ) {
    push @invoicing_list, $self->all_emails;
  }

  my $email = ($conf->exists('business-onlinepayment-email-override'))
              ? $conf->config('business-onlinepayment-email-override')
              : $invoicing_list[0];

  my %content = ();

  my $payip = exists($options{'payip'})
                ? $options{'payip'}
                : $self->payip;
  $content{customer_ip} = $payip
    if length($payip);

  $content{invoice_number} = $options{'invnum'}
    if exists($options{'invnum'}) && length($options{'invnum'});

  $content{email_customer} = 
    (    $conf->exists('business-onlinepayment-email_customer')
      || $conf->exists('business-onlinepayment-email-override') );
      
  my $paydate = '';
  if ( $method eq 'CC' ) { 

    $content{card_number} = $payinfo;
    $paydate = exists($options{'paydate'})
                    ? $options{'paydate'}
                    : $self->paydate;
    $paydate =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
    $content{expiration} = "$2/$1";

    my $paycvv = exists($options{'paycvv'})
                   ? $options{'paycvv'}
                   : $self->paycvv;
    $content{cvv2} = $paycvv
      if length($paycvv);

    my $paystart_month = exists($options{'paystart_month'})
                           ? $options{'paystart_month'}
                           : $self->paystart_month;

    my $paystart_year  = exists($options{'paystart_year'})
                           ? $options{'paystart_year'}
                           : $self->paystart_year;

    $content{card_start} = "$paystart_month/$paystart_year"
      if $paystart_month && $paystart_year;

    my $payissue       = exists($options{'payissue'})
                           ? $options{'payissue'}
                           : $self->payissue;
    $content{issue_number} = $payissue if $payissue;

    $content{recurring_billing} = 'YES'
      if qsearch('cust_pay', { 'custnum' => $self->custnum,
                               'payby'   => 'CARD',
                               'payinfo' => $payinfo,
                             } )
      || qsearch('cust_pay', { 'custnum' => $self->custnum,
                               'payby'   => 'CARD',
                               'paymask' => $self->mask_payinfo('CARD', $payinfo),
                             } );


  } elsif ( $method eq 'ECHECK' ) {
    ( $content{account_number}, $content{routing_code} ) =
      split('@', $payinfo);
    $content{bank_name} = $o_payname;
    $content{bank_state} = exists($options{'paystate'})
                             ? $options{'paystate'}
                             : $self->getfield('paystate');
    $content{account_type} = exists($options{'paytype'})
                               ? uc($options{'paytype'}) || 'CHECKING'
                               : uc($self->getfield('paytype')) || 'CHECKING';
    $content{account_name} = $payname;
    $content{customer_org} = $self->company ? 'B' : 'I';
    $content{state_id}       = exists($options{'stateid'})
                                 ? $options{'stateid'}
                                 : $self->getfield('stateid');
    $content{state_id_state} = exists($options{'stateid_state'})
                                 ? $options{'stateid_state'}
                                 : $self->getfield('stateid_state');
    $content{customer_ssn} = exists($options{'ss'})
                               ? $options{'ss'}
                               : $self->ss;
  } elsif ( $method eq 'LEC' ) {
    $content{phone} = $payinfo;
  }

  ###
  # run transaction(s)
  ###

  my $balance = exists( $options{'balance'} )
                  ? $options{'balance'}
                  : $self->balance;

  $self->select_for_update; #mutex ... just until we get our pending record in

  #the checks here are intended to catch concurrent payments
  #double-form-submission prevention is taken care of in cust_pay_pending::check

  #check the balance
  return "The customer's balance has changed; $method transaction aborted."
    if $self->balance < $balance;
    #&& $self->balance < $amount; #might as well anyway?

  #also check and make sure there aren't *other* pending payments for this cust

  my @pending = qsearch('cust_pay_pending', {
    'custnum' => $self->custnum,
    'status'  => { op=>'!=', value=>'done' } 
  });
  return "A payment is already being processed for this customer (".
         join(', ', map 'paypendingnum '. $_->paypendingnum, @pending ).
         "); $method transaction aborted."
    if scalar(@pending);

  #okay, good to go, if we're a duplicate, cust_pay_pending will kick us out

  my $cust_pay_pending = new FS::cust_pay_pending {
    'custnum'    => $self->custnum,
    #'invnum'     => $options{'invnum'},
    'paid'       => $amount,
    '_date'      => '',
    'payby'      => $method2payby{$method},
    'payinfo'    => $payinfo,
    'paydate'    => $paydate,
    'status'     => 'new',
    'gatewaynum' => ( $payment_gateway ? $payment_gateway->gatewaynum : '' ),
  };
  $cust_pay_pending->payunique( $options{payunique} )
    if defined($options{payunique}) && length($options{payunique});
  my $cpp_new_err = $cust_pay_pending->insert; #mutex lost when this is inserted
  return $cpp_new_err if $cpp_new_err;

  my( $action1, $action2 ) = split(/\s*\,\s*/, $action );

  my $transaction = new Business::OnlinePayment( $processor, @bop_options );
  $transaction->content(
    'type'           => $method,
    'login'          => $login,
    'password'       => $password,
    'action'         => $action1,
    'description'    => $options{'description'},
    'amount'         => $amount,
    #'invoice_number' => $options{'invnum'},
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

  $cust_pay_pending->status('pending');
  my $cpp_pending_err = $cust_pay_pending->replace;
  return $cpp_pending_err if $cpp_pending_err;

  #config?
  my $BOP_TESTING = 0;
  my $BOP_TESTING_SUCCESS = 1;

  unless ( $BOP_TESTING ) {
    $transaction->submit();
  } else {
    if ( $BOP_TESTING_SUCCESS ) {
      $transaction->is_success(1);
      $transaction->authorization('fake auth');
    } else {
      $transaction->is_success(0);
      $transaction->error_message('fake failure');
    }
  }

  if ( $transaction->is_success() && $action2 ) {

    $cust_pay_pending->status('authorized');
    my $cpp_authorized_err = $cust_pay_pending->replace;
    return $cpp_authorized_err if $cpp_authorized_err;

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

    foreach my $field (qw( authorization_source_code returned_ACI
                           transaction_identifier validation_code           
                           transaction_sequence_num local_transaction_date    
                           local_transaction_time AVS_result_code          )) {
      $capture{$field} = $transaction->$field() if $transaction->can($field);
    }

    $capture->content( %capture );

    $capture->submit();

    unless ( $capture->is_success ) {
      my $e = "Authorization successful but capture failed, custnum #".
              $self->custnum. ': '.  $capture->result_code.
              ": ". $capture->error_message;
      warn $e;
      return $e;
    }

  }

  $cust_pay_pending->status($transaction->is_success() ? 'captured' : 'declined');
  my $cpp_captured_err = $cust_pay_pending->replace;
  return $cpp_captured_err if $cpp_captured_err;

  ###
  # remove paycvv after initial transaction
  ###

  #false laziness w/misc/process/payment.cgi - check both to make sure working
  # correctly
  if ( defined $self->dbdef_table->column('paycvv')
       && length($self->paycvv)
       && ! grep { $_ eq cardtype($payinfo) } $conf->config('cvv-save')
  ) {
    my $error = $self->remove_cvv;
    if ( $error ) {
      warn "WARNING: error removing cvv: $error\n";
    }
  }

  ###
  # result handling
  ###

  if ( $transaction->is_success() ) {

    my $paybatch = '';
    if ( $payment_gateway ) { # agent override
      $paybatch = $payment_gateway->gatewaynum. '-';
    }

    $paybatch .= "$processor:". $transaction->authorization;

    $paybatch .= ':'. $transaction->order_number
      if $transaction->can('order_number')
      && length($transaction->order_number);

    my $cust_pay = new FS::cust_pay ( {
       'custnum'  => $self->custnum,
       'invnum'   => $options{'invnum'},
       'paid'     => $amount,
       '_date'    => '',
       'payby'    => $method2payby{$method},
       'payinfo'  => $payinfo,
       'paybatch' => $paybatch,
       'paydate'  => $paydate,
    } );
    #doesn't hurt to know, even though the dup check is in cust_pay_pending now
    $cust_pay->payunique( $options{payunique} )
      if defined($options{payunique}) && length($options{payunique});

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;

    #start a transaction, insert the cust_pay and set cust_pay_pending.status to done in a single transction

    my $error = $cust_pay->insert($options{'manual'} ? ( 'manual' => 1 ) : () );

    if ( $error ) {
      $cust_pay->invnum(''); #try again with no specific invnum
      my $error2 = $cust_pay->insert( $options{'manual'} ?
                                      ( 'manual' => 1 ) : ()
                                    );
      if ( $error2 ) {
        # gah.  but at least we have a record of the state we had to abort in
        # from cust_pay_pending now.
        my $e = "WARNING: $method captured but payment not recorded - ".
                "error inserting payment ($processor): $error2".
                " (previously tried insert with invnum #$options{'invnum'}" .
                ": $error ) - pending payment saved as paypendingnum ".
                $cust_pay_pending->paypendingnum. "\n";
        warn $e;
        return $e;
      }
    }

    if ( $options{'paynum_ref'} ) {
      ${ $options{'paynum_ref'} } = $cust_pay->paynum;
    }

    $cust_pay_pending->status('done');
    $cust_pay_pending->statustext('captured');
    my $cpp_done_err = $cust_pay_pending->replace;

    if ( $cpp_done_err ) {

      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      my $e = "WARNING: $method captured but payment not recorded - ".
              "error updating status for paypendingnum ".
              $cust_pay_pending->paypendingnum. ": $cpp_done_err \n";
      warn $e;
      return $e;

    } else {

      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
      return ''; #no error

    }

  } else {

    my $perror = "$processor error: ". $transaction->error_message;

    unless ( $transaction->error_message ) {

      my $t_response;
      if ( $transaction->can('response_page') ) {
        $t_response = {
                        'page'    => ( $transaction->can('response_page')
                                         ? $transaction->response_page
                                         : ''
                                     ),
                        'code'    => ( $transaction->can('response_code')
                                         ? $transaction->response_code
                                         : ''
                                     ),
                        'headers' => ( $transaction->can('response_headers')
                                         ? $transaction->response_headers
                                         : ''
                                     ),
                      };
      } else {
        $t_response .=
          "No additional debugging information available for $processor";
      }

      $perror .= "No error_message returned from $processor -- ".
                 ( ref($t_response) ? Dumper($t_response) : $t_response );

    }

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

    $cust_pay_pending->status('done');
    $cust_pay_pending->statustext("declined: $perror");
    my $cpp_done_err = $cust_pay_pending->replace;
    if ( $cpp_done_err ) {
      my $e = "WARNING: $method declined but pending payment not resolved - ".
              "error updating status for paypendingnum ".
              $cust_pay_pending->paypendingnum. ": $cpp_done_err \n";
      warn $e;
      $perror = "$e ($perror)";
    }

    return $perror;
  }

}

=item fake_bop

=cut

sub fake_bop {
  my( $self, $method, $amount, %options ) = @_;

  if ( $options{'fake_failure'} ) {
     return "Error: No error; test failure requested with fake_failure";
  }

  my %method2payby = (
    'CC'     => 'CARD',
    'ECHECK' => 'CHEK',
    'LEC'    => 'LECB',
  );

  #my $paybatch = '';
  #if ( $payment_gateway ) { # agent override
  #  $paybatch = $payment_gateway->gatewaynum. '-';
  #}
  #
  #$paybatch .= "$processor:". $transaction->authorization;
  #
  #$paybatch .= ':'. $transaction->order_number
  #  if $transaction->can('order_number')
  #  && length($transaction->order_number);

  my $paybatch = 'FakeProcessor:54:32';

  my $cust_pay = new FS::cust_pay ( {
     'custnum'  => $self->custnum,
     'invnum'   => $options{'invnum'},
     'paid'     => $amount,
     '_date'    => '',
     'payby'    => $method2payby{$method},
     #'payinfo'  => $payinfo,
     'payinfo'  => '4111111111111111',
     'paybatch' => $paybatch,
     #'paydate'  => $paydate,
     'paydate'  => '2012-05-01',
  } );
  $cust_pay->payunique( $options{payunique} ) if length($options{payunique});

  my $error = $cust_pay->insert($options{'manual'} ? ( 'manual' => 1 ) : () );

  if ( $error ) {
    $cust_pay->invnum(''); #try again with no specific invnum
    my $error2 = $cust_pay->insert( $options{'manual'} ?
                                    ( 'manual' => 1 ) : ()
                                  );
    if ( $error2 ) {
      # gah, even with transactions.
      my $e = 'WARNING: Card/ACH debited but database not updated - '.
              "error inserting (fake!) payment: $error2".
              " (previously tried insert with invnum #$options{'invnum'}" .
              ": $error )";
      warn $e;
      return $e;
    }
  }

  if ( $options{'paynum_ref'} ) {
    ${ $options{'paynum_ref'} } = $cust_pay->paynum;
  }

  return ''; #no error

}

=item default_payment_gateway

=cut

sub default_payment_gateway {
  my( $self, $method ) = @_;

  die "Real-time processing not enabled\n"
    unless $conf->exists('business-onlinepayment');

  #load up config
  my $bop_config = 'business-onlinepayment';
  $bop_config .= '-ach'
    if $method =~ /^(ECHECK|CHEK)$/ && $conf->exists($bop_config. '-ach');
  my ( $processor, $login, $password, $action, @bop_options ) =
    $conf->config($bop_config);
  $action ||= 'normal authorization';
  pop @bop_options if scalar(@bop_options) % 2 && $bop_options[-1] =~ /^\s*$/;
  die "No real-time processor is enabled - ".
      "did you set the business-onlinepayment configuration value?\n"
    unless $processor;

  ( $processor, $login, $password, $action, @bop_options )
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

Available options are: I<amount>, I<reason>, I<paynum>, I<paydate>

Most gateways require a reference to an original payment transaction to refund,
so you probably need to specify a I<paynum>.

I<amount> defaults to the original amount of the payment if not specified.

I<reason> specifies a reason for the refund.

I<paydate> specifies the expiration date for a credit card overriding the
value from the customer record or the payment record. Specified as yyyy-mm-dd

Implementation note: If I<amount> is unspecified or equal to the amount of the
orignal payment, first an attempt is made to "void" the transaction via
the gateway (to cancel a not-yet settled transaction) and then if that fails,
the normal attempt is made to "refund" ("credit") the transaction via the
gateway is attempted.

#The additional options I<payname>, I<address1>, I<address2>, I<city>, I<state>,
#I<zip>, I<payinfo> and I<paydate> are also available.  Any of these options,
#if set, will override the value from the customer record.

#If an I<invnum> is specified, this payment (if successful) is applied to the
#specified invoice.  If you don't specify an I<invnum> you might want to
#call the B<apply_payments> method.

=cut

#some false laziness w/realtime_bop, not enough to make it worth merging
#but some useful small subs should be pulled out
sub realtime_refund_bop {
  my( $self, $method, %options ) = @_;
  if ( $DEBUG ) {
    warn "$me realtime_refund_bop: $method refund\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  eval "use Business::OnlinePayment";  
  die $@ if $@;

  ###
  # look up the original payment and optionally a gateway for that payment
  ###

  my $cust_pay = '';
  my $amount = $options{'amount'};

  my( $processor, $login, $password, @bop_options ) ;
  my( $auth, $order_number ) = ( '', '', '' );

  if ( $options{'paynum'} ) {

    warn "  paynum: $options{paynum}\n" if $DEBUG > 1;
    $cust_pay = qsearchs('cust_pay', { paynum=>$options{'paynum'} } )
      or return "Unknown paynum $options{'paynum'}";
    $amount ||= $cust_pay->paid;

    $cust_pay->paybatch =~ /^((\d+)\-)?(\w+):\s*([\w\-\/ ]*)(:([\w\-]+))?$/
      or return "Can't parse paybatch for paynum $options{'paynum'}: ".
                $cust_pay->paybatch;
    my $gatewaynum = '';
    ( $gatewaynum, $processor, $auth, $order_number ) = ( $2, $3, $4, $6 );

    if ( $gatewaynum ) { #gateway for the payment to be refunded

      my $payment_gateway =
        qsearchs('payment_gateway', { 'gatewaynum' => $gatewaynum } );
      die "payment gateway $gatewaynum not found"
        unless $payment_gateway;

      $processor   = $payment_gateway->gateway_module;
      $login       = $payment_gateway->gateway_username;
      $password    = $payment_gateway->gateway_password;
      @bop_options = $payment_gateway->options;

    } else { #try the default gateway

      my( $conf_processor, $unused_action );
      ( $conf_processor, $login, $password, $unused_action, @bop_options ) =
        $self->default_payment_gateway($method);

      return "processor of payment $options{'paynum'} $processor does not".
             " match default processor $conf_processor"
        unless $processor eq $conf_processor;

    }


  } else { # didn't specify a paynum, so look for agent gateway overrides
           # like a normal transaction 

    my $cardtype;
    if ( $method eq 'CC' ) {
      $cardtype = cardtype($self->payinfo);
    } elsif ( $method eq 'ECHECK' ) {
      $cardtype = 'ACH';
    } else {
      $cardtype = $method;
    }
    my $override =
           qsearchs('agent_payment_gateway', { agentnum => $self->agentnum,
                                               cardtype => $cardtype,
                                               taxclass => '',              } )
        || qsearchs('agent_payment_gateway', { agentnum => $self->agentnum,
                                               cardtype => '',
                                               taxclass => '',              } );

    if ( $override ) { #use a payment gateway override
 
      my $payment_gateway = $override->payment_gateway;

      $processor   = $payment_gateway->gateway_module;
      $login       = $payment_gateway->gateway_username;
      $password    = $payment_gateway->gateway_password;
      #$action      = $payment_gateway->gateway_action;
      @bop_options = $payment_gateway->options;

    } else { #use the standard settings from the config

      my $unused_action;
      ( $processor, $login, $password, $unused_action, @bop_options ) =
        $self->default_payment_gateway($method);

    }

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

  my $disable_void_after;
  if ($conf->exists('disable_void_after')
      && $conf->config('disable_void_after') =~ /^(\d+)$/) {
    $disable_void_after = $1;
  }

  #first try void if applicable
  if ( $cust_pay && $cust_pay->paid == $amount
    && (
      ( not defined($disable_void_after) )
      || ( time < ($cust_pay->_date + $disable_void_after ) )
    )
  ) {
    warn "  attempting void\n" if $DEBUG > 1;
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
      warn "  void successful\n" if $DEBUG > 1;
      return '';
    }
  }

  warn "  void unsuccessful, trying refund\n"
    if $DEBUG > 1;

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

  my @invoicing_list = $self->invoicing_list_emailonly;
  if ( $conf->exists('emailinvoiceautoalways')
       || $conf->exists('emailinvoiceauto') && ! @invoicing_list
       || ( $conf->exists('emailinvoiceonly') && ! @invoicing_list ) ) {
    push @invoicing_list, $self->all_emails;
  }

  my $email = ($conf->exists('business-onlinepayment-email-override'))
              ? $conf->config('business-onlinepayment-email-override')
              : $invoicing_list[0];

  my $payip = exists($options{'payip'})
                ? $options{'payip'}
                : $self->payip;
  $content{customer_ip} = $payip
    if length($payip);

  my $payinfo = '';
  if ( $method eq 'CC' ) {

    if ( $cust_pay ) {
      $content{card_number} = $payinfo = $cust_pay->payinfo;
      (exists($options{'paydate'}) ? $options{'paydate'} : $cust_pay->paydate)
        =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/ &&
        ($content{expiration} = "$2/$1");  # where available
    } else {
      $content{card_number} = $payinfo = $self->payinfo;
      (exists($options{'paydate'}) ? $options{'paydate'} : $self->paydate)
        =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
      $content{expiration} = "$2/$1";
    }

  } elsif ( $method eq 'ECHECK' ) {

    if ( $cust_pay ) {
      $payinfo = $cust_pay->payinfo;
    } else {
      $payinfo = $self->payinfo;
    } 
    ( $content{account_number}, $content{routing_code} )= split('@', $payinfo );
    $content{bank_name} = $self->payname;
    $content{account_type} = 'CHECKING';
    $content{account_name} = $payname;
    $content{customer_org} = $self->company ? 'B' : 'I';
    $content{customer_ssn} = $self->ss;
  } elsif ( $method eq 'LEC' ) {
    $content{phone} = $payinfo = $self->payinfo;
  }

  #then try refund
  my $refund = new Business::OnlinePayment( $processor, @bop_options );
  my %sub_content = $refund->content(
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
    'email'          => $email,
    'phone'          => $self->daytime || $self->night,
    %content, #after
  );
  warn join('', map { "  $_ => $sub_content{$_}\n" } keys %sub_content )
    if $DEBUG > 1;
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

  while ( $cust_pay && $cust_pay->unapplied < $amount ) {
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
    'payinfo'  => $payinfo,
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

=item batch_card OPTION => VALUE...

Adds a payment for this invoice to the pending credit card batch (see
L<FS::cust_pay_batch>), or, if the B<realtime> option is set to a true value,
runs the payment using a realtime gateway.

=cut

sub batch_card {
  my ($self, %options) = @_;

  my $amount;
  if (exists($options{amount})) {
    $amount = $options{amount};
  }else{
    $amount = sprintf("%.2f", $self->balance - $self->in_transit_payments);
  }
  return '' unless $amount > 0;
  
  my $invnum = delete $options{invnum};
  my $payby = $options{invnum} || $self->payby;  #dubious

  if ($options{'realtime'}) {
    return $self->realtime_bop( FS::payby->payby2bop($self->payby),
                                $amount,
                                %options,
                              );
  }

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  #this needs to handle mysql as well as Pg, like svc_acct.pm
  #(make it into a common function if folks need to do batching with mysql)
  $dbh->do("LOCK TABLE pay_batch IN SHARE ROW EXCLUSIVE MODE")
    or return "Cannot lock pay_batch: " . $dbh->errstr;

  my %pay_batch = (
    'status' => 'O',
    'payby'  => FS::payby->payby2payment($payby),
  );

  my $pay_batch = qsearchs( 'pay_batch', \%pay_batch );

  unless ( $pay_batch ) {
    $pay_batch = new FS::pay_batch \%pay_batch;
    my $error = $pay_batch->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      die "error creating new batch: $error\n";
    }
  }

  my $old_cust_pay_batch = qsearchs('cust_pay_batch', {
      'batchnum' => $pay_batch->batchnum,
      'custnum'  => $self->custnum,
  } );

  foreach (qw( address1 address2 city state zip country payby payinfo paydate
               payname )) {
    $options{$_} = '' unless exists($options{$_});
  }

  my $cust_pay_batch = new FS::cust_pay_batch ( {
    'batchnum' => $pay_batch->batchnum,
    'invnum'   => $invnum || 0,                    # is there a better value?
                                                   # this field should be
                                                   # removed...
                                                   # cust_bill_pay_batch now
    'custnum'  => $self->custnum,
    'last'     => $self->getfield('last'),
    'first'    => $self->getfield('first'),
    'address1' => $options{address1} || $self->address1,
    'address2' => $options{address2} || $self->address2,
    'city'     => $options{city}     || $self->city,
    'state'    => $options{state}    || $self->state,
    'zip'      => $options{zip}      || $self->zip,
    'country'  => $options{country}  || $self->country,
    'payby'    => $options{payby}    || $self->payby,
    'payinfo'  => $options{payinfo}  || $self->payinfo,
    'exp'      => $options{paydate}  || $self->paydate,
    'payname'  => $options{payname}  || $self->payname,
    'amount'   => $amount,                         # consolidating
  } );
  
  $cust_pay_batch->paybatchnum($old_cust_pay_batch->paybatchnum)
    if $old_cust_pay_batch;

  my $error;
  if ($old_cust_pay_batch) {
    $error = $cust_pay_batch->replace($old_cust_pay_batch)
  } else {
    $error = $cust_pay_batch->insert;
  }

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    die $error;
  }

  my $unapplied = $self->total_credited + $self->total_unapplied_payments + $self->in_transit_payments;
  foreach my $cust_bill ($self->open_cust_bill) {
    #$dbh->commit or die $dbh->errstr if $oldAutoCommit;
    my $cust_bill_pay_batch = new FS::cust_bill_pay_batch {
      'invnum' => $cust_bill->invnum,
      'paybatchnum' => $cust_pay_batch->paybatchnum,
      'amount' => $cust_bill->owed,
      '_date' => time,
    };
    if ($unapplied >= $cust_bill_pay_batch->amount){
      $unapplied -= $cust_bill_pay_batch->amount;
      next;
    }else{
      $cust_bill_pay_batch->amount(sprintf ( "%.2f", 
                                   $cust_bill_pay_batch->amount - $unapplied ));      $unapplied = 0;
    }
    $error = $cust_bill_pay_batch->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      die $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
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
  my $total_bill = 0;
  foreach my $cust_bill (
    grep { $_->_date <= $time }
      qsearch('cust_bill', { 'custnum' => $self->custnum, } )
  ) {
    $total_bill += $cust_bill->owed;
  }
  sprintf( "%.2f", $total_bill );
}

=item apply_payments_and_credits

Applies unapplied payments and credits.

In most cases, this new method should be used in place of sequential
apply_payments and apply_credits methods.

If there is an error, returns the error, otherwise returns false.

=cut

sub apply_payments_and_credits {
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

  $self->select_for_update; #mutex

  foreach my $cust_bill ( $self->open_cust_bill ) {
    my $error = $cust_bill->apply_payments_and_credits;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error applying: $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error

}

=item apply_credits OPTION => VALUE ...

Applies (see L<FS::cust_credit_bill>) unapplied credits (see L<FS::cust_credit>)
to outstanding invoice balances in chronological order (or reverse
chronological order if the I<order> option is set to B<newest>) and returns the
value of any remaining unapplied credits available for refund (see
L<FS::cust_refund>).

Dies if there is an error.

=cut

sub apply_credits {
  my $self = shift;
  my %opt = @_;

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

  unless ( $self->total_credited ) {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return 0;
  }

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
    if ( $error ) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      die $error;
    }
    
    redo if ($cust_bill->owed > 0);

  }

  my $total_credited = $self->total_credited;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return $total_credited;
}

=item apply_payments

Applies (see L<FS::cust_bill_pay>) unapplied payments (see L<FS::cust_pay>)
to outstanding invoice balances in chronological order.

 #and returns the value of any remaining unapplied payments.

Dies if there is an error.

=cut

sub apply_payments {
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

  $self->select_for_update; #mutex

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
    if ( $error ) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      die $error;
    }

    redo if ( $cust_bill->owed > 0);

  }

  my $total_unapplied_payments = $self->total_unapplied_payments;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return $total_unapplied_payments;
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

=item total_unapplied_refunds

Returns the total unrefunded refunds (see L<FS::cust_refund>) for this
customer.  See L<FS::cust_refund/unapplied>.

=cut

sub total_unapplied_refunds {
  my $self = shift;
  my $total_unapplied = 0;
  foreach my $cust_refund ( qsearch('cust_refund', {
    'custnum' => $self->custnum,
  } ) ) {
    $total_unapplied += $cust_refund->unapplied;
  }
  sprintf( "%.2f", $total_unapplied );
}

=item balance

Returns the balance for this customer (total_owed plus total_unrefunded, minus
total_credited minus total_unapplied_payments).

=cut

sub balance {
  my $self = shift;
  sprintf( "%.2f",
      $self->total_owed
    + $self->total_unapplied_refunds
    - $self->total_credited
    - $self->total_unapplied_payments
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
      + $self->total_unapplied_refunds
      - $self->total_credited
      - $self->total_unapplied_payments
  );
}

=item in_transit_payments

Returns the total of requests for payments for this customer pending in 
batches in transit to the bank.  See L<FS::pay_batch> and L<FS::cust_pay_batch>

=cut

sub in_transit_payments {
  my $self = shift;
  my $in_transit_payments = 0;
  foreach my $pay_batch ( qsearch('pay_batch', {
    'status' => 'I',
  } ) ) {
    foreach my $cust_pay_batch ( qsearch('cust_pay_batch', {
      'batchnum' => $pay_batch->batchnum,
      'custnum' => $self->custnum,
    } ) ) {
      $in_transit_payments += $cust_pay_batch->amount;
    }
  }
  sprintf( "%.2f", $in_transit_payments );
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
    if $conf->exists('cust_main-require_invoicing_list_email')
    && ! grep { $_ !~ /^([A-Z]+)$/ } @$arrayref;

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

=item invoicing_list_emailonly

Returns the list of email invoice recipients (invoicing_list without non-email
destinations such as POST and FAX).

=cut

sub invoicing_list_emailonly {
  my $self = shift;
  warn "$me invoicing_list_emailonly called"
    if $DEBUG;
  grep { $_ !~ /^([A-Z]+)$/ } $self->invoicing_list;
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

=item referring_cust_main

Returns the single cust_main record for the customer who referred this customer
(referral_custnum), or false.

=cut

sub referring_cust_main {
  my $self = shift;
  return '' unless $self->referral_custnum;
  qsearchs('cust_main', { 'custnum' => $self->referral_custnum } );
}

=item credit AMOUNT, REASON

Applies a credit to this customer.  If there is an error, returns the error,
otherwise returns false.

=cut

sub credit {
  my( $self, $amount, $reason, %options ) = @_;
  my $cust_credit = new FS::cust_credit {
    'custnum' => $self->custnum,
    'amount'  => $amount,
    'reason'  => $reason,
  };
  $cust_credit->insert(%options);
}

=item charge AMOUNT [ PKG [ COMMENT [ TAXCLASS ] ] ]

Creates a one-time charge for this customer.  If there is an error, returns
the error, otherwise returns false.

=cut

sub charge {
  my $self = shift;
  my ( $amount, $quantity, $pkg, $comment, $taxclass, $additional, $classnum );
  my ( $taxproduct, $override );
  if ( ref( $_[0] ) ) {
    $amount     = $_[0]->{amount};
    $quantity   = exists($_[0]->{quantity}) ? $_[0]->{quantity} : 1;
    $pkg        = exists($_[0]->{pkg}) ? $_[0]->{pkg} : 'One-time charge';
    $comment    = exists($_[0]->{comment}) ? $_[0]->{comment}
                                           : '$'. sprintf("%.2f",$amount);
    $taxclass   = exists($_[0]->{taxclass}) ? $_[0]->{taxclass} : '';
    $classnum   = exists($_[0]->{classnum}) ? $_[0]->{classnum} : '';
    $additional = $_[0]->{additional};
    $taxproduct = $_[0]->{taxproductnum};
    $override   = { '' => $_[0]->{tax_override} };
  }else{
    $amount     = shift;
    $quantity   = 1;
    $pkg        = @_ ? shift : 'One-time charge';
    $comment    = @_ ? shift : '$'. sprintf("%.2f",$amount);
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
    'classnum'      => $classnum ? $classnum : '',
    'taxclass'      => $taxclass,
    'taxproductnum' => $taxproduct,
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
    'custnum'  => $self->custnum,
    'pkgpart'  => $pkgpart,
    'quantity' => $quantity,
  } );

  $error = $cust_pkg->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

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

  my $pkgpart = $conf->config('postal_invoice-fee_pkgpart');
  return '' unless ($pkgpart && grep { $_ eq 'POST' } $self->invoicing_list);

  my $cust_pkg = new FS::cust_pkg ( {
    'custnum'  => $self->custnum,
    'pkgpart'  => $pkgpart,
    'quantity' => 1,
  } );

  my $error = $cust_pkg->insert;
  $error ? $error : $cust_pkg;
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

=item cust_pay_batch

Returns all batched payments (see L<FS::cust_pay_void>) for this customer.

=cut

sub cust_pay_batch {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_pay_batch', { 'custnum' => $self->custnum } )
}

=item cust_refund

Returns all the refunds (see L<FS::cust_refund>) for this customer.

=cut

sub cust_refund {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_refund', { 'custnum' => $self->custnum } )
}

=item display_custnum

Returns the displayed customer number for this customer: agent_custid if
cust_main-default_agent_custid is set and it has a value, custnum otherwise.

=cut

sub display_custnum {
  my $self = shift;
  if ( $conf->exists('cust_main-default_agent_custid') && $self->agent_custid ){
    return $self->agent_custid;
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

=item ship_name

Returns a name string for this (service/shipping) contact, either
"Company (Last, First)" or "Last, First".

=cut

sub ship_name {
  my $self = shift;
  if ( $self->get('ship_last') ) { 
    my $name = $self->ship_contact;
    $name = $self->ship_company. " ($name)" if $self->ship_company;
    $name;
  } else {
    $self->name;
  }
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
  $self->get('ship_last')
    ? $self->get('ship_last'). ', '. $self->ship_first
    : $self->contact;
}

=item country_full

Returns this customer's full country name

=cut

sub country_full {
  my $self = shift;
  code2country($self->country);
}

=item geocode DATA_VENDOR

Returns a value for the customer location as encoded by DATA_VENDOR.
Currently this only makes sense for "CCH" as DATA_VENDOR.

=cut

sub geocode {
  my ($self, $data_vendor) = (shift, shift);  #always cch for now

  my $prefix = ( $conf->exists('tax-ship_address') && length($self->ship_last) )
               ? 'ship_'
               : '';

  my ($zip,$plus4) = split /-/, $self->get("${prefix}zip")
    if $self->country eq 'US';

  #CCH specific location stuff
  my $extra_sql = "AND plus4lo <= '$plus4' AND plus4hi >= '$plus4'";

  my $geocode = '';
  my $cust_tax_location =
    qsearchs( {
                'table'     => 'cust_tax_location', 
                'hashref'   => { 'zip' => $zip, 'data_vendor' => $data_vendor },
                'extra_sql' => $extra_sql,
              }
            );
  $geocode = $cust_tax_location->geocode
    if $cust_tax_location;

  $geocode;
}

=item cust_status

=item status

Returns a status string for this customer, currently:

=over 4

=item prospect - No packages have ever been ordered

=item active - One or more recurring packages is active

=item inactive - No active recurring packages, but otherwise unsuspended/uncancelled (the inactive status is new - previously inactive customers were mis-identified as cancelled)

=item suspended - All non-cancelled recurring packages are suspended

=item cancelled - All recurring packages are cancelled

=back

=cut

sub status { shift->cust_status(@_); }

sub cust_status {
  my $self = shift;
  for my $status (qw( prospect active inactive suspended cancelled )) {
    my $method = $status.'_sql';
    my $numnum = ( my $sql = $self->$method() ) =~ s/cust_main\.custnum/?/g;
    my $sth = dbh->prepare("SELECT $sql") or die dbh->errstr;
    $sth->execute( ($self->custnum) x $numnum )
      or die "Error executing 'SELECT $sql': ". $sth->errstr;
    return $status if $sth->fetchrow_arrayref->[0];
  }
}

=item ucfirst_cust_status

=item ucfirst_status

Returns the status with the first character capitalized.

=cut

sub ucfirst_status { shift->ucfirst_cust_status(@_); }

sub ucfirst_cust_status {
  my $self = shift;
  ucfirst($self->cust_status);
}

=item statuscolor

Returns a hex triplet color string for this customer's status.

=cut

use vars qw(%statuscolor);
tie %statuscolor, 'Tie::IxHash',
  'prospect'  => '7e0079', #'000000', #black?  naw, purple
  'active'    => '00CC00', #green
  'inactive'  => '0000CC', #blue
  'suspended' => 'FF9900', #yellow
  'cancelled' => 'FF0000', #red
;

sub statuscolor { shift->cust_statuscolor(@_); }

sub cust_statuscolor {
  my $self = shift;
  $statuscolor{$self->cust_status};
}

=item tickets

Returns an array of hashes representing the customer's RT tickets.

=cut

sub tickets {
  my $self = shift;

  my $num = $conf->config('cust_main-max_tickets') || 10;
  my @tickets = ();

  unless ( $conf->config('ticket_system-custom_priority_field') ) {

    @tickets = @{ FS::TicketSystem->customer_tickets($self->custnum, $num) };

  } else {

    foreach my $priority (
      $conf->config('ticket_system-custom_priority_field-values'), ''
    ) {
      last if scalar(@tickets) >= $num;
      push @tickets, 
        @{ FS::TicketSystem->customer_tickets( $self->custnum,
                                               $num - scalar(@tickets),
                                               $priority,
                                             )
         };
    }
  }
  (@tickets);
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

=back

=head1 CLASS METHODS

=over 4

=item statuses

Class method that returns the list of possible status strings for customers
(see L<the status method|/status>).  For example:

  @statuses = FS::cust_main->statuses();

=cut

sub statuses {
  #my $self = shift; #could be class...
  keys %statuscolor;
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

sub prospect_sql { "
  0 = ( $select_count_pkgs )
"; }

=item active_sql

Returns an SQL expression identifying active cust_main records (customers with
active recurring packages).

=cut

sub active_sql { "
  0 < ( $select_count_pkgs AND ". FS::cust_pkg->active_sql. "
      )
"; }

=item inactive_sql

Returns an SQL expression identifying inactive cust_main records (customers with
no active recurring packages, but otherwise unsuspended/uncancelled).

=cut

sub inactive_sql { "
  0 = ( $select_count_pkgs AND ". FS::cust_pkg->active_sql. " )
  AND
  0 < ( $select_count_pkgs AND ". FS::cust_pkg->inactive_sql. " )
"; }

=item susp_sql
=item suspended_sql

Returns an SQL expression identifying suspended cust_main records.

=cut


sub suspended_sql { susp_sql(@_); }
sub susp_sql { "
    0 < ( $select_count_pkgs AND ". FS::cust_pkg->suspended_sql. " )
    AND
    0 = ( $select_count_pkgs AND ". FS::cust_pkg->active_sql. " )
"; }

=item cancel_sql
=item cancelled_sql

Returns an SQL expression identifying cancelled cust_main records.

=cut

sub cancelled_sql { cancel_sql(@_); }
sub cancel_sql {

  my $recurring_sql = FS::cust_pkg->recurring_sql;
  my $cancelled_sql = FS::cust_pkg->cancelled_sql;

  "
        0 < ( $select_count_pkgs )
    AND 0 < ( $select_count_pkgs AND $recurring_sql AND $cancelled_sql   )
    AND 0 = ( $select_count_pkgs AND $recurring_sql
                  AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
            )
    AND 0 = (  $select_count_pkgs AND ". FS::cust_pkg->inactive_sql. " )
  ";

}

=item uncancel_sql
=item uncancelled_sql

Returns an SQL expression identifying un-cancelled cust_main records.

=cut

sub uncancelled_sql { uncancel_sql(@_); }
sub uncancel_sql { "
  ( 0 < ( $select_count_pkgs
                   AND ( cust_pkg.cancel IS NULL
                         OR cust_pkg.cancel = 0
                       )
        )
    OR 0 = ( $select_count_pkgs )
  )
"; }

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

=item balance_date_sql START_TIME [ END_TIME [ OPTION => VALUE ... ] ]

Returns an SQL fragment to retreive the balance for this customer, only
considering invoices with date earlier than START_TIME, and optionally not
later than END_TIME (total_owed_date minus total_credited minus
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

=back

=cut

sub balance_date_sql {
  my( $class, $start, $end, %opt ) = @_;

  my $owed         = FS::cust_bill->owed_sql;
  my $unapp_refund = FS::cust_refund->unapplied_sql;
  my $unapp_credit = FS::cust_credit->unapplied_sql;
  my $unapp_pay    = FS::cust_pay->unapplied_sql;

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

=item search_sql HASHREF

(Class method)

Returns a qsearch hash expression to search for parameters specified in HREF.
Valid parameters are

=over 4

=item agentnum

=item status

=item cancelled_pkgs

bool

=item signupdate

listref of start date, end date

=item payby

listref

=item current_balance

listref (list returned by FS::UI::Web::parse_lt_gt($cgi, 'current_balance'))

=item cust_fields

=item flattened_pkgs

bool

=back

=cut

sub search_sql {
  my ($class, $params) = @_;

  my $dbh = dbh;

  my @where = ();
  my $orderby;

  ##
  # parse agent
  ##

  if ( $params->{'agentnum'} =~ /^(\d+)$/ and $1 ) {
    push @where,
      "cust_main.agentnum = $1";
  }

  ##
  # parse status
  ##

  #prospect active inactive suspended cancelled
  if ( grep { $params->{'status'} eq $_ } FS::cust_main->statuses() ) {
    my $method = $params->{'status'}. '_sql';
    #push @where, $class->$method();
    push @where, FS::cust_main->$method();
  }
  
  ##
  # parse cancelled package checkbox
  ##

  my $pkgwhere = "";

  $pkgwhere .= "AND (cancel = 0 or cancel is null)"
    unless $params->{'cancelled_pkgs'};

  ##
  # dates
  ##

  foreach my $field (qw( signupdate )) {

    next unless exists($params->{$field});

    my($beginning, $ending) = @{$params->{$field}};

    push @where,
      "cust_main.$field IS NOT NULL",
      "cust_main.$field >= $beginning",
      "cust_main.$field <= $ending";

    $orderby ||= "ORDER BY cust_main.$field";

  }

  ###
  # payby
  ###

  my @payby = grep /^([A-Z]{4})$/, @{ $params->{'payby'} };
  if ( @payby ) {
    push @where, '( '. join(' OR ', map "cust_main.payby = '$_'", @payby). ' )';
  }

  ##
  # amounts
  ##

  #my $balance_sql = $class->balance_sql();
  my $balance_sql = FS::cust_main->balance_sql();

  push @where, map { s/current_balance/$balance_sql/; $_ }
                   @{ $params->{'current_balance'} };

  ##
  # custbatch
  ##

  if ( $params->{'custbatch'} =~ /^([\w\/\-\:\.]+)$/ and $1 ) {
    push @where,
      "cust_main.custbatch = '$1'";
  }

  ##
  # setup queries, subs, etc. for the search
  ##

  $orderby ||= 'ORDER BY custnum';

  # here is the agent virtualization
  push @where, $FS::CurrentUser::CurrentUser->agentnums_sql;

  my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

  my $addl_from = 'LEFT JOIN cust_pkg USING ( custnum  ) ';

  my $count_query = "SELECT COUNT(*) FROM cust_main $extra_sql";

  my $select = join(', ', 
                 'cust_main.custnum',
                 FS::UI::Web::cust_sql_fields($params->{'cust_fields'}),
               );

  my(@extra_headers) = ();
  my(@extra_fields)  = ();

  if ($params->{'flattened_pkgs'}) {

    if ($dbh->{Driver}->{Name} eq 'Pg') {

      $select .= ", array_to_string(array(select pkg from cust_pkg left join part_pkg using ( pkgpart ) where cust_main.custnum = cust_pkg.custnum $pkgwhere),'|') as magic";

    }elsif ($dbh->{Driver}->{Name} =~ /^mysql/i) {
      $select .= ", GROUP_CONCAT(pkg SEPARATOR '|') as magic";
      $addl_from .= " LEFT JOIN part_pkg using ( pkgpart )";
    }else{
      warn "warning: unknown database type ". $dbh->{Driver}->{Name}. 
           "omitting packing information from report.";
    }

    my $header_query = "SELECT COUNT(cust_pkg.custnum = cust_main.custnum) AS count FROM cust_main $addl_from $extra_sql $pkgwhere group by cust_main.custnum order by count desc limit 1";

    my $sth = dbh->prepare($header_query) or die dbh->errstr;
    $sth->execute() or die $sth->errstr;
    my $headerrow = $sth->fetchrow_arrayref;
    my $headercount = $headerrow ? $headerrow->[0] : 0;
    while($headercount) {
      unshift @extra_headers, "Package ". $headercount;
      unshift @extra_fields, eval q!sub {my $c = shift;
                                         my @a = split '\|', $c->magic;
                                         my $p = $a[!.--$headercount. q!];
                                         $p;
                                        };!;
    }

  }

  my $sql_query = {
    'table'         => 'cust_main',
    'select'        => $select,
    'hashref'       => {},
    'extra_sql'     => $extra_sql,
    'order_by'      => $orderby,
    'count_query'   => $count_query,
    'extra_headers' => \@extra_headers,
    'extra_fields'  => \@extra_fields,
  };

}

=item email_search_sql HASHREF

(Class method)

Emails a notice to the specified customers.

Valid parameters are those of the L<search_sql> method, plus the following:

=over 4

=item from

From: address

=item subject

Email Subject:

=item html_body

HTML body

=item text_body

Text body

=item job

Optional job queue job for status updates.

=back

Returns an error message, or false for success.

If an error occurs during any email, stops the enture send and returns that
error.  Presumably if you're getting SMTP errors aborting is better than 
retrying everything.

=cut

sub email_search_sql {
  my($class, $params) = @_;

  my $from = delete $params->{from};
  my $subject = delete $params->{subject};
  my $html_body = delete $params->{html_body};
  my $text_body = delete $params->{text_body};

  my $job = delete $params->{'job'};

  my $sql_query = $class->search_sql($params);

  my $count_query   = delete($sql_query->{'count_query'});
  my $count_sth = dbh->prepare($count_query)
    or die "Error preparing $count_query: ". dbh->errstr;
  $count_sth->execute
    or die "Error executing $count_query: ". $count_sth->errstr;
  my $count_arrayref = $count_sth->fetchrow_arrayref;
  my $num_cust = $count_arrayref->[0];

  #my @extra_headers = @{ delete($sql_query->{'extra_headers'}) };
  #my @extra_fields  = @{ delete($sql_query->{'extra_fields'})  };


  my( $num, $last, $min_sec ) = (0, time, 5); #progresbar foo

  #eventually order+limit magic to reduce memory use?
  foreach my $cust_main ( qsearch($sql_query) ) {

    my $to = $cust_main->invoicing_list_emailonly_scalar;
    next unless $to;

    my $error = send_email(
      generate_email(
        'from'      => $from,
        'to'        => $to,
        'subject'   => $subject,
        'html_body' => $html_body,
        'text_body' => $text_body,
      )
    );
    return $error if $error;

    if ( $job ) { #progressbar foo
      $num++;
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $num / $num_cust )
        );
        die $error if $error;
        $last = time;
      }
    }

  }

  return '';
}

use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
sub process_email_search_sql {
  my $job = shift;
  #warn "$me process_re_X $method for job $job\n" if $DEBUG;

  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;

  $param->{'job'} = $job;

  my $error = FS::cust_main->email_search_sql( $param );
  die $error if $error;

}

=item fuzzy_search FUZZY_HASHREF [ HASHREF, SELECT, EXTRA_SQL, CACHE_OBJ ]

Performs a fuzzy (approximate) search and returns the matching FS::cust_main
records.  Currently, I<first>, I<last> and/or I<company> may be specified (the
appropriate ship_ field is also searched).

Additional options are the same as FS::Record::qsearch

=cut

sub fuzzy_search {
  my( $self, $fuzzy, $hash, @opt) = @_;
  #$self
  $hash ||= {};
  my @cust_main = ();

  check_and_rebuild_fuzzyfiles();
  foreach my $field ( keys %$fuzzy ) {

    my $all = $self->all_X($field);
    next unless scalar(@$all);

    my %match = ();
    $match{$_}=1 foreach ( amatch( $fuzzy->{$field}, ['i'], @$all ) );

    my @fcust = ();
    foreach ( keys %match ) {
      push @fcust, qsearch('cust_main', { %$hash, $field=>$_}, @opt);
      push @fcust, qsearch('cust_main', { %$hash, "ship_$field"=>$_}, @opt);
    }
    my %fsaw = ();
    push @cust_main, grep { ! $fsaw{$_->custnum}++ } @fcust;
  }

  # we want the components of $fuzzy ANDed, not ORed, but still don't want dupes
  my %saw = ();
  @cust_main = grep { ++$saw{$_->custnum} == scalar(keys %$fuzzy) } @cust_main;

  @cust_main;

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

=back

=head1 SUBROUTINES

=over 4

=item smart_search OPTION => VALUE ...

Accepts the following options: I<search>, the string to search for.  The string
will be searched for as a customer number, phone number, name or company name,
as an exact, or, in some cases, a substring or fuzzy match (see the source code
for the exact heuristics used); I<no_fuzzy_on_exact>, causes smart_search to
skip fuzzy matching when an exact match is found.

Any additional options are treated as an additional qualifier on the search
(i.e. I<agentnum>).

Returns a (possibly empty) array of FS::cust_main objects.

=cut

sub smart_search {
  my %options = @_;

  #here is the agent virtualization
  my $agentnums_sql = $FS::CurrentUser::CurrentUser->agentnums_sql;

  my @cust_main = ();

  my $skip_fuzzy = delete $options{'no_fuzzy_on_exact'};
  my $search = delete $options{'search'};
  ( my $alphanum_search = $search ) =~ s/\W//g;
  
  if ( $alphanum_search =~ /^1?(\d{3})(\d{3})(\d{4})(\d*)$/ ) { #phone# search

    #false laziness w/Record::ut_phone
    my $phonen = "$1-$2-$3";
    $phonen .= " x$4" if $4;

    push @cust_main, qsearch( {
      'table'   => 'cust_main',
      'hashref' => { %options },
      'extra_sql' => ( scalar(keys %options) ? ' AND ' : ' WHERE ' ).
                     ' ( '.
                         join(' OR ', map "$_ = '$phonen'",
                                          qw( daytime night fax
                                              ship_daytime ship_night ship_fax )
                             ).
                     ' ) '.
                     " AND $agentnums_sql", #agent virtualization
    } );

    unless ( @cust_main || $phonen =~ /x\d+$/ ) { #no exact match
      #try looking for matches with extensions unless one was specified

      push @cust_main, qsearch( {
        'table'   => 'cust_main',
        'hashref' => { %options },
        'extra_sql' => ( scalar(keys %options) ? ' AND ' : ' WHERE ' ).
                       ' ( '.
                           join(' OR ', map "$_ LIKE '$phonen\%'",
                                            qw( daytime night
                                                ship_daytime ship_night )
                               ).
                       ' ) '.
                       " AND $agentnums_sql", #agent virtualization
      } );

    }

  # custnum search (also try agent_custid), with some tweaking options if your
  # legacy cust "numbers" have letters
  } elsif ( $search =~ /^\s*(\d+)\s*$/
            || ( $conf->config('cust_main-agent_custid-format') eq 'ww?d+'
                 && $search =~ /^\s*(\w\w?\d+)\s*$/
               )
          )
  {

    push @cust_main, qsearch( {
      'table'     => 'cust_main',
      'hashref'   => { 'custnum' => $1, %options },
      'extra_sql' => " AND $agentnums_sql", #agent virtualization
    } );

    push @cust_main, qsearch( {
      'table'     => 'cust_main',
      'hashref'   => { 'agent_custid' => $1, %options },
      'extra_sql' => " AND $agentnums_sql", #agent virtualization
    } );

  } elsif ( $search =~ /^\s*(\S.*\S)\s+\((.+), ([^,]+)\)\s*$/ ) {

    my($company, $last, $first) = ( $1, $2, $3 );

    # "Company (Last, First)"
    #this is probably something a browser remembered,
    #so just do an exact search

    foreach my $prefix ( '', 'ship_' ) {
      push @cust_main, qsearch( {
        'table'     => 'cust_main',
        'hashref'   => { $prefix.'first'   => $first,
                         $prefix.'last'    => $last,
                         $prefix.'company' => $company,
                         %options,
                       },
        'extra_sql' => " AND $agentnums_sql",
      } );
    }

  } elsif ( $search =~ /^\s*(\S.*\S)\s*$/ ) { # value search
                                              # try (ship_){last,company}

    my $value = lc($1);

    # # remove "(Last, First)" in "Company (Last, First)", otherwise the
    # # full strings the browser remembers won't work
    # $value =~ s/\([\w \,\.\-\']*\)$//; #false laziness w/Record::ut_name

    use Lingua::EN::NameParse;
    my $NameParse = new Lingua::EN::NameParse(
             auto_clean     => 1,
             allow_reversed => 1,
    );

    my($last, $first) = ( '', '' );
    #maybe disable this too and just rely on NameParse?
    if ( $value =~ /^(.+),\s*([^,]+)$/ ) { # Last, First
    
      ($last, $first) = ( $1, $2 );
    
    #} elsif  ( $value =~ /^(.+)\s+(.+)$/ ) {
    } elsif ( ! $NameParse->parse($value) ) {

      my %name = $NameParse->components;
      $first = $name{'given_name_1'};
      $last  = $name{'surname_1'};

    }

    if ( $first && $last ) {

      my($q_last, $q_first) = ( dbh->quote($last), dbh->quote($first) );

      #exact
      my $sql = scalar(keys %options) ? ' AND ' : ' WHERE ';
      $sql .= "
        (     ( LOWER(last) = $q_last AND LOWER(first) = $q_first )
           OR ( LOWER(ship_last) = $q_last AND LOWER(ship_first) = $q_first )
        )";

      push @cust_main, qsearch( {
        'table'     => 'cust_main',
        'hashref'   => \%options,
        'extra_sql' => "$sql AND $agentnums_sql", #agent virtualization
      } );

      # or it just be something that was typed in... (try that in a sec)

    }

    my $q_value = dbh->quote($value);

    #exact
    my $sql = scalar(keys %options) ? ' AND ' : ' WHERE ';
    $sql .= " (    LOWER(last)         = $q_value
                OR LOWER(company)      = $q_value
                OR LOWER(ship_last)    = $q_value
                OR LOWER(ship_company) = $q_value
              )";

    push @cust_main, qsearch( {
      'table'     => 'cust_main',
      'hashref'   => \%options,
      'extra_sql' => "$sql AND $agentnums_sql", #agent virtualization
    } );

    #no exact match, trying substring/fuzzy
    #always do substring & fuzzy (unless they're explicity config'ed off)
    #getting complaints searches are not returning enough
    unless ( @cust_main  && $skip_fuzzy || $conf->exists('disable-fuzzy') ) {

      #still some false laziness w/search_sql (was search/cust_main.cgi)

      #substring

      my @hashrefs = (
        { 'company'      => { op=>'ILIKE', value=>"%$value%" }, },
        { 'ship_company' => { op=>'ILIKE', value=>"%$value%" }, },
      );

      if ( $first && $last ) {

        push @hashrefs,
          { 'first'        => { op=>'ILIKE', value=>"%$first%" },
            'last'         => { op=>'ILIKE', value=>"%$last%" },
          },
          { 'ship_first'   => { op=>'ILIKE', value=>"%$first%" },
            'ship_last'    => { op=>'ILIKE', value=>"%$last%" },
          },
        ;

      } else {

        push @hashrefs,
          { 'last'         => { op=>'ILIKE', value=>"%$value%" }, },
          { 'ship_last'    => { op=>'ILIKE', value=>"%$value%" }, },
        ;
      }

      foreach my $hashref ( @hashrefs ) {

        push @cust_main, qsearch( {
          'table'     => 'cust_main',
          'hashref'   => { %$hashref,
                           %options,
                         },
          'extra_sql' => " AND $agentnums_sql", #agent virtualizaiton
        } );

      }

      #fuzzy
      my @fuzopts = (
        \%options,                #hashref
        '',                       #select
        " AND $agentnums_sql",    #extra_sql  #agent virtualization
      );

      if ( $first && $last ) {
        push @cust_main, FS::cust_main->fuzzy_search(
          { 'last'   => $last,    #fuzzy hashref
            'first'  => $first }, #
          @fuzopts
        );
      }
      foreach my $field ( 'last', 'company' ) {
        push @cust_main,
          FS::cust_main->fuzzy_search( { $field => $value }, @fuzopts );
      }

    }

    #eliminate duplicates
    my %saw = ();
    @cust_main = grep { !$saw{$_->custnum}++ } @cust_main;

  }

  @cust_main;

}

=item email_search

Accepts the following options: I<email>, the email address to search for.  The
email address will be searched for as an email invoice destination and as an
svc_acct account.

#Any additional options are treated as an additional qualifier on the search
#(i.e. I<agentnum>).

Returns a (possibly empty) array of FS::cust_main objects (but usually just
none or one).

=cut

sub email_search {
  my %options = @_;

  local($DEBUG) = 1;

  my $email = delete $options{'email'};

  #we're only being used by RT at the moment... no agent virtualization yet
  #my $agentnums_sql = $FS::CurrentUser::CurrentUser->agentnums_sql;

  my @cust_main = ();

  if ( $email =~ /([^@]+)\@([^@]+)/ ) {

    my ( $user, $domain ) = ( $1, $2 );

    warn "$me smart_search: searching for $user in domain $domain"
      if $DEBUG;

    push @cust_main,
      map $_->cust_main,
          qsearch( {
                     'table'     => 'cust_main_invoice',
                     'hashref'   => { 'dest' => $email },
                   }
                 );

    push @cust_main,
      map  $_->cust_main,
      grep $_,
      map  $_->cust_svc->cust_pkg,
          qsearch( {
                     'table'     => 'svc_acct',
                     'hashref'   => { 'username' => $user, },
                     'extra_sql' =>
                       'AND ( SELECT domain FROM svc_domain
                                WHERE svc_acct.domsvc = svc_domain.svcnum
                            ) = '. dbh->quote($domain),
                   }
                 );
  }

  my %saw = ();
  @cust_main = grep { !$saw{$_->custnum}++ } @cust_main;

  warn "$me smart_search: found ". scalar(@cust_main). " unique customers"
    if $DEBUG;

  @cust_main;

}

=item check_and_rebuild_fuzzyfiles

=cut

use vars qw(@fuzzyfields);
@fuzzyfields = ( 'last', 'first', 'company' );

sub check_and_rebuild_fuzzyfiles {
  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  rebuild_fuzzyfiles() if grep { ! -e "$dir/cust_main.$_" } @fuzzyfields
}

=item rebuild_fuzzyfiles

=cut

sub rebuild_fuzzyfiles {

  use Fcntl qw(:flock);

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  mkdir $dir, 0700 unless -d $dir;

  foreach my $fuzzy ( @fuzzyfields ) {

    open(LOCK,">>$dir/cust_main.$fuzzy")
      or die "can't open $dir/cust_main.$fuzzy: $!";
    flock(LOCK,LOCK_EX)
      or die "can't lock $dir/cust_main.$fuzzy: $!";

    open (CACHE,">$dir/cust_main.$fuzzy.tmp")
      or die "can't open $dir/cust_main.$fuzzy.tmp: $!";

    foreach my $field ( $fuzzy, "ship_$fuzzy" ) {
      my $sth = dbh->prepare("SELECT $field FROM cust_main".
                             " WHERE $field != '' AND $field IS NOT NULL");
      $sth->execute or die $sth->errstr;

      while ( my $row = $sth->fetchrow_arrayref ) {
        print CACHE $row->[0]. "\n";
      }

    } 

    close CACHE or die "can't close $dir/cust_main.$fuzzy.tmp: $!";
  
    rename "$dir/cust_main.$fuzzy.tmp", "$dir/cust_main.$fuzzy";
    close LOCK;
  }

}

=item all_X

=cut

sub all_X {
  my( $self, $field ) = @_;
  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  open(CACHE,"<$dir/cust_main.$field")
    or die "can't open $dir/cust_main.$field: $!";
  my @array = map { chomp; $_; } <CACHE>;
  close CACHE;
  \@array;
}

=item append_fuzzyfiles LASTNAME COMPANY

=cut

sub append_fuzzyfiles {
  #my( $first, $last, $company ) = @_;

  &check_and_rebuild_fuzzyfiles;

  use Fcntl qw(:flock);

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;

  foreach my $field (qw( first last company )) {
    my $value = shift;

    if ( $value ) {

      open(CACHE,">>$dir/cust_main.$field")
        or die "can't open $dir/cust_main.$field: $!";
      flock(CACHE,LOCK_EX)
        or die "can't lock $dir/cust_main.$field: $!";

      print CACHE "$value\n";

      flock(CACHE,LOCK_UN)
        or die "can't unlock $dir/cust_main.$field: $!";
      close CACHE;
    }

  }

  1;
}

=item process_batch_import

Load a batch import as a queued JSRPC job

=cut

use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
sub process_batch_import {
  my $job = shift;

  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;
  
  my $files = $param->{'uploaded_files'}
    or die "No files provided.\n";

  my (%files) = map { /^(\w+):([\.\w]+)$/ ? ($1,$2):() } split /,/, $files;

  my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc. '/';
  my $file = $dir. $files{'file'};

  my $type;
  if ( $file =~ /\.(\w+)$/i ) {
    $type = lc($1);
  } else {
    #or error out???
    warn "can't parse file type from filename $file; defaulting to CSV";
    $type = 'csv';
  }

  my $error =
    FS::cust_main::batch_import( {
      job       => $job,
      file      => $file,
      type      => $type,
      custbatch => $param->{custbatch},
      agentnum  => $param->{'agentnum'},
      refnum    => $param->{'refnum'},
      pkgpart   => $param->{'pkgpart'},
      #'fields'  => [qw( cust_pkg.setup dayphone first last address1 address2
      #                 city state zip comments                          )],
      'format'  => $param->{'format'},
    } );

  unlink $file;

  die "$error\n" if $error;

}

=item batch_import

=cut

#some false laziness w/cdr.pm now
sub batch_import {
  my $param = shift;

  my $job       = $param->{job};

  my $filename  = $param->{file};
  my $type      = $param->{type} || 'csv';

  my $custbatch = $param->{custbatch};

  my $agentnum  = $param->{agentnum};
  my $refnum    = $param->{refnum};
  my $pkgpart   = $param->{pkgpart};

  my $format    = $param->{'format'};

  my @fields;
  my $payby;
  if ( $format eq 'simple' ) {
    @fields = qw( cust_pkg.setup dayphone first last
                  address1 address2 city state zip comments );
    $payby = 'BILL';
  } elsif ( $format eq 'extended' ) {
    @fields = qw( agent_custid refnum
                  last first address1 address2 city state zip country
                  daytime night
                  ship_last ship_first ship_address1 ship_address2
                  ship_city ship_state ship_zip ship_country
                  payinfo paycvv paydate
                  invoicing_list
                  cust_pkg.pkgpart
                  svc_acct.username svc_acct._password 
                );
    $payby = 'BILL';
 } elsif ( $format eq 'extended-plus_company' ) {
    @fields = qw( agent_custid refnum
                  last first company address1 address2 city state zip country
                  daytime night
                  ship_last ship_first ship_company ship_address1 ship_address2
                  ship_city ship_state ship_zip ship_country
                  payinfo paycvv paydate
                  invoicing_list
                  cust_pkg.pkgpart
                  svc_acct.username svc_acct._password 
                );
    $payby = 'BILL';
  } else {
    die "unknown format $format";
  }

  my $count;
  my $parser;
  my @buffer = ();
  if ( $type eq 'csv' ) {

    eval "use Text::CSV_XS;";
    die $@ if $@;

    $parser = new Text::CSV_XS;

    @buffer = split(/\r?\n/, slurp($filename) );
    $count = scalar(@buffer);

  } elsif ( $type eq 'xls' ) {

    eval "use Spreadsheet::ParseExcel;";
    die $@ if $@;

    my $excel = new Spreadsheet::ParseExcel::Workbook->Parse($filename);
    $parser = $excel->{Worksheet}[0]; #first sheet

    $count = $parser->{MaxRow} || $parser->{MinRow};
    $count++;

  } else {
    die "Unknown file type $type\n";
  }

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
  
  my $line;
  my $row = 0;
  my( $last, $min_sec ) = ( time, 5 ); #progressbar foo
  while (1) {

    my @columns = ();
    if ( $type eq 'csv' ) {

      last unless scalar(@buffer);
      $line = shift(@buffer);

      $parser->parse($line) or do {
        $dbh->rollback if $oldAutoCommit;
        return "can't parse: ". $parser->error_input();
      };
      @columns = $parser->fields();

    } elsif ( $type eq 'xls' ) {

      last if $row > ($parser->{MaxRow} || $parser->{MinRow});

      my @row = @{ $parser->{Cells}[$row] };
      @columns = map $_->{Val}, @row;

      #my $z = 'A';
      #warn $z++. ": $_\n" for @columns;

    } else {
      die "Unknown file type $type\n";
    }

    #warn join('-',@columns);

    my %cust_main = (
      custbatch => $custbatch,
      agentnum  => $agentnum,
      refnum    => $refnum,
      country   => $conf->config('countrydefault') || 'US',
      payby     => $payby, #default
      paydate   => '12/2037', #default
    );
    my $billtime = time;
    my %cust_pkg = ( pkgpart => $pkgpart );
    my %svc_acct = ();
    foreach my $field ( @fields ) {

      if ( $field =~ /^cust_pkg\.(pkgpart|setup|bill|susp|adjourn|expire|cancel)$/ ) {

        #$cust_pkg{$1} = str2time( shift @$columns );
        if ( $1 eq 'pkgpart' ) {
          $cust_pkg{$1} = shift @columns;
        } elsif ( $1 eq 'setup' ) {
          $billtime = str2time(shift @columns);
        } else {
          $cust_pkg{$1} = str2time( shift @columns );
        } 

      } elsif ( $field =~ /^svc_acct\.(username|_password)$/ ) {

        $svc_acct{$1} = shift @columns;
        
      } else {

        #refnum interception
        if ( $field eq 'refnum' && $columns[0] !~ /^\s*(\d+)\s*$/ ) {

          my $referral = $columns[0];
          my %hash = ( 'referral' => $referral,
                       'agentnum' => $agentnum,
                       'disabled' => '',
                     );

          my $part_referral = qsearchs('part_referral', \%hash )
                              || new FS::part_referral \%hash;

          unless ( $part_referral->refnum ) {
            my $error = $part_referral->insert;
            if ( $error ) {
              $dbh->rollback if $oldAutoCommit;
              return "can't auto-insert advertising source: $referral: $error";
            }
          }

          $columns[0] = $part_referral->refnum;
        }

        my $value = shift @columns;
        $cust_main{$field} = $value if length($value);
      }
    }

    $cust_main{'payby'} = 'CARD'
      if defined $cust_main{'payinfo'}
      && length  $cust_main{'payinfo'};

    my $invoicing_list = $cust_main{'invoicing_list'}
                           ? [ delete $cust_main{'invoicing_list'} ]
                           : [];

    my $cust_main = new FS::cust_main ( \%cust_main );

    use Tie::RefHash;
    tie my %hash, 'Tie::RefHash'; #this part is important

    if ( $cust_pkg{'pkgpart'} ) {
      my $cust_pkg = new FS::cust_pkg ( \%cust_pkg );

      my @svc_acct = ();
      if ( $svc_acct{'username'} ) {
        my $part_pkg = $cust_pkg->part_pkg;
	unless ( $part_pkg ) {
	  $dbh->rollback if $oldAutoCommit;
	  return "unknown pkgpart: ". $cust_pkg{'pkgpart'};
	} 
        $svc_acct{svcpart} = $part_pkg->svcpart( 'svc_acct' );
        push @svc_acct, new FS::svc_acct ( \%svc_acct )
      }

      $hash{$cust_pkg} = \@svc_acct;
    }

    my $error = $cust_main->insert( \%hash, $invoicing_list );

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't insert customer". ( $line ? " for $line" : '' ). ": $error";
    }

    if ( $format eq 'simple' ) {

      #false laziness w/bill.cgi
      $error = $cust_main->bill( 'time' => $billtime );
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't bill customer for $line: $error";
      }
  
      $error = $cust_main->apply_payments_and_credits;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't bill customer for $line: $error";
      }

      $error = $cust_main->collect();
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't collect customer for $line: $error";
      }

    }

    $row++;

    if ( $job && time - $min_sec > $last ) { #progress bar
      $job->update_statustext( int(100 * $row / $count) );
      $last = time;
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;;

  return "Empty file!" unless $row;

  ''; #no error

}

=item batch_charge

=cut

sub batch_charge {
  my $param = shift;
  #warn join('-',keys %$param);
  my $fh = $param->{filehandle};
  my @fields = @{$param->{fields}};

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

=item notify CUSTOMER_OBJECT TEMPLATE_NAME OPTIONS

Sends a templated email notification to the customer (see L<Text::Template>).

OPTIONS is a hash and may include

I<from> - the email sender (default is invoice_from)

I<to> - comma-separated scalar or arrayref of recipients 
   (default is invoicing_list)

I<subject> - The subject line of the sent email notification
   (default is "Notice from company_name")

I<extra_fields> - a hashref of name/value pairs which will be substituted
   into the template

The following variables are vavailable in the template.

I<$first> - the customer first name
I<$last> - the customer last name
I<$company> - the customer company
I<$payby> - a description of the method of payment for the customer
            # would be nice to use FS::payby::shortname
I<$payinfo> - the account information used to collect for this customer
I<$expdate> - the expiration of the customer payment in seconds from epoch

=cut

sub notify {
  my ($customer, $template, %options) = @_;

  return unless $conf->exists($template);

  my $from = $conf->config('invoice_from') if $conf->exists('invoice_from');
  $from = $options{from} if exists($options{from});

  my $to = join(',', $customer->invoicing_list_emailonly);
  $to = $options{to} if exists($options{to});
  
  my $subject = "Notice from " . $conf->config('company_name')
    if $conf->exists('company_name');
  $subject = $options{subject} if exists($options{subject});

  my $notify_template = new Text::Template (TYPE => 'ARRAY',
                                            SOURCE => [ map "$_\n",
                                              $conf->config($template)]
                                           )
    or die "can't create new Text::Template object: Text::Template::ERROR";
  $notify_template->compile()
    or die "can't compile template: Text::Template::ERROR";

  $FS::notify_template::_template::company_name = $conf->config('company_name');
  $FS::notify_template::_template::company_address =
    join("\n", $conf->config('company_address') ). "\n";

  my $paydate = $customer->paydate || '2037-12-31';
  $FS::notify_template::_template::first = $customer->first;
  $FS::notify_template::_template::last = $customer->last;
  $FS::notify_template::_template::company = $customer->company;
  $FS::notify_template::_template::payinfo = $customer->mask_payinfo;
  my $payby = $customer->payby;
  my ($payyear,$paymonth,$payday) = split (/-/,$paydate);
  my $expire_time = timelocal(0,0,0,$payday,--$paymonth,$payyear);

  #credit cards expire at the end of the month/year of their exp date
  if ($payby eq 'CARD' || $payby eq 'DCRD') {
    $FS::notify_template::_template::payby = 'credit card';
    ($paymonth < 11) ? $paymonth++ : ($paymonth=0, $payyear++);
    $expire_time = timelocal(0,0,0,$payday,$paymonth,$payyear);
    $expire_time--;
  }elsif ($payby eq 'COMP') {
    $FS::notify_template::_template::payby = 'complimentary account';
  }else{
    $FS::notify_template::_template::payby = 'current method';
  }
  $FS::notify_template::_template::expdate = $expire_time;

  for (keys %{$options{extra_fields}}){
    no strict "refs";
    ${"FS::notify_template::_template::$_"} = $options{extra_fields}->{$_};
  }

  send_email(from => $from,
             to => $to,
             subject => $subject,
             body => $notify_template->fill_in( PACKAGE =>
                                                'FS::notify_template::_template'                                              ),
            );

}

=item generate_letter CUSTOMER_OBJECT TEMPLATE_NAME OPTIONS

Generates a templated notification to the customer (see L<Text::Template>).

OPTIONS is a hash and may include

I<extra_fields> - a hashref of name/value pairs which will be substituted
   into the template.  These values may override values mentioned below
   and those from the customer record.

The following variables are available in the template instead of or in addition
to the fields of the customer record.

I<$payby> - a description of the method of payment for the customer
            # would be nice to use FS::payby::shortname
I<$payinfo> - the masked account information used to collect for this customer
I<$expdate> - the expiration of the customer payment method in seconds from epoch
I<$returnaddress> - the return address defaults to invoice_latexreturnaddress or company_address

=cut

sub generate_letter {
  my ($self, $template, %options) = @_;

  return unless $conf->exists($template);

  my $letter_template = new Text::Template
                        ( TYPE       => 'ARRAY',
                          SOURCE     => [ map "$_\n", $conf->config($template)],
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
    } elsif ( grep /\S/, $conf->config('company_address') ) {
      $letter_data{returnaddress} =
        join( '\\*'."\n", map s/( {2,})/'~' x length($1)/eg,
                          $conf->config('company_address')
        );
    } else {
      $letter_data{returnaddress} = '~';
    }
  }

  $letter_data{conf_dir} = "$FS::UID::conf_dir/conf.$FS::UID::datasrc";

  $letter_data{company_name} = $conf->config('company_name');

  my $dir = $FS::UID::conf_dir."cache.". $FS::UID::datasrc;
  my $fh = new File::Temp( TEMPLATE => 'letter.'. $self->custnum. '.XXXXXXXX',
                           DIR      => $dir,
                           SUFFIX   => '.tex',
                           UNLINK   => 0,
                         ) or die "can't open temp file: $!\n";

  $letter_template->fill_in( OUTPUT => $fh, HASH => \%letter_data );
  close $fh;
  $fh->filename =~ /^(.*).tex$/ or die "unparsable filename: ". $fh->filename;
  return $1;
}

=item print_ps TEMPLATE 

Returns an postscript letter filled in from TEMPLATE, as a scalar.

=cut

sub print_ps {
  my $self = shift;
  my $file = $self->generate_letter(@_);
  FS::Misc::generate_ps($file);
}

=item print TEMPLATE

Prints the filled in template.

TEMPLATE is the name of a L<Text::Template> to fill in and print.

=cut

sub queueable_print {
  my %opt = @_;

  my $self = qsearchs('cust_main', { 'custnum' => $opt{custnum} } )
    or die "invalid customer number: " . $opt{custvnum};

  my $error = $self->print( $opt{template} );
  die $error if $error;
}

sub print {
  my ($self, $template) = (shift, shift);
  do_print [ $self->print_ps($template) ];
}

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

  my $regexp = '';
  if ( driver_name =~ /^Pg/i ) {
    $regexp = '~';
  } elsif ( driver_name =~ /^mysql/i ) {
    $regexp = 'REGEXP';
  } else {
    die "don't know how to use regular expressions in ". driver_name. " databases";
  }

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
        LEFT JOIN part_event_option AS peo_cust_bill_age
          ON ( part_event.eventpart = peo_cust_bill_age.eventpart
               AND peo_cust_bill_age.optionname = 'cust_bill_age'
             )
      },
      #'hashref'   => { 'optionname' => $option },
      #'hashref'   => { 'part_event_option.optionname' => $option },
      'extra_sql' =>
        " WHERE part_event_option.optionname = ". dbh->quote($option).
        " AND action = 'cust_bill_send_agent' ".
        " AND ( disabled IS NULL OR disabled != 'Y' ) ".
        " AND peo_agentnum.optionname = 'agentnum' ".
        " AND agentnum IS NULL OR agentnum = $agentnum ".
        " ORDER BY
           CASE WHEN peo_cust_bill_age.optionname != 'cust_bill_age'
           THEN -1
	   ELSE ". FS::part_event::Condition->age2seconds_sql('peo_cust_bill_age.optionvalue').
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

sub queued_bill {
  ## actual sub, not a method, designed to be called from the queue.
  ## sets up the customer, and calls the bill_and_collect
  my (%args) = @_; #, ($time, $invoice_time, $check_freq, $resetup) = @_;
  my $cust_main = qsearchs( 'cust_main', { custnum => $args{'custnum'} } );
      $cust_main->bill_and_collect(
        %args,
      );
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

