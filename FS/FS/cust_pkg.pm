package FS::cust_pkg;
use base qw( FS::cust_pkg::Search FS::cust_pkg::API
             FS::otaker_Mixin FS::cust_main_Mixin FS::Sales_Mixin
             FS::contact_Mixin FS::location_Mixin
             FS::m2m_Common FS::option_Common
           );

use strict;
use Carp qw(cluck);
use Scalar::Util qw( blessed );
use List::Util qw(min max);
use Tie::IxHash;
use Time::Local qw( timelocal timelocal_nocheck );
use MIME::Entity;
use FS::UID qw( dbh driver_name );
use FS::Misc qw( send_email );
use FS::Record qw( qsearch qsearchs fields );
use FS::CurrentUser;
use FS::cust_svc;
use FS::part_pkg;
use FS::cust_main;
use FS::contact;
use FS::cust_location;
use FS::pkg_svc;
use FS::cust_bill_pkg;
use FS::cust_pkg_detail;
use FS::cust_pkg_usage;
use FS::cdr_cust_pkg_usage;
use FS::cust_event;
use FS::h_cust_svc;
use FS::reg_code;
use FS::part_svc;
use FS::cust_pkg_reason;
use FS::reason;
use FS::cust_pkg_usageprice;
use FS::cust_pkg_discount;
use FS::discount;
use FS::sales;
# for modify_charge
use FS::cust_credit;

# need to 'use' these instead of 'require' in sub { cancel, suspend, unsuspend,
# setup }
# because they load configuration by setting FS::UID::callback (see TODO)
use FS::svc_acct;
use FS::svc_domain;
use FS::svc_www;
use FS::svc_forward;

# for sending cancel emails in sub cancel
use FS::Conf;

our ($disable_agentcheck, $DEBUG, $me, $import) = (0, 0, '[FS::cust_pkg]', 0);

our $upgrade = 0; #go away after setup+start dates cleaned up for old customers

sub _cache {
  my $self = shift;
  my ( $hashref, $cache ) = @_;
  #if ( $hashref->{'pkgpart'} ) {
  if ( $hashref->{'pkg'} ) {
    # #@{ $self->{'_pkgnum'} } = ();
    # my $subcache = $cache->subcache('pkgpart', 'part_pkg');
    # $self->{'_pkgpart'} = $subcache;
    # #push @{ $self->{'_pkgnum'} },
    #   FS::part_pkg->new_or_cached($hashref, $subcache);
    $self->{'_pkgpart'} = FS::part_pkg->new($hashref);
  }
  if ( exists $hashref->{'svcnum'} ) {
    #@{ $self->{'_pkgnum'} } = ();
    my $subcache = $cache->subcache('svcnum', 'cust_svc', $hashref->{pkgnum});
    $self->{'_svcnum'} = $subcache;
    #push @{ $self->{'_pkgnum'} },
    FS::cust_svc->new_or_cached($hashref, $subcache) if $hashref->{svcnum};
  }
}

=head1 NAME

FS::cust_pkg - Object methods for cust_pkg objects

=head1 SYNOPSIS

  use FS::cust_pkg;

  $record = new FS::cust_pkg \%hash;
  $record = new FS::cust_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->cancel;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $part_pkg = $record->part_pkg;

  @labels = $record->labels;

  $seconds = $record->seconds_since($timestamp);

  #bulk cancel+order... perhaps slightly deprecated, only used by the bulk
  # cancel+order in the web UI and nowhere else (edit/process/cust_pkg.cgi)
  $error = FS::cust_pkg::order( $custnum, \@pkgparts );
  $error = FS::cust_pkg::order( $custnum, \@pkgparts, \@remove_pkgnums ] );

=head1 DESCRIPTION

An FS::cust_pkg object represents a customer billing item.  FS::cust_pkg
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item pkgnum

Primary key (assigned automatically for new billing items)

=item custnum

Customer (see L<FS::cust_main>)

=item pkgpart

Billing item definition (see L<FS::part_pkg>)

=item locationnum

Optional link to package location (see L<FS::location>)

=item order_date

date package was ordered (also remains same on changes)

=item start_date

date

=item setup

date

=item bill

date (next bill date)

=item last_bill

last bill date

=item adjourn

date

=item susp

date

=item expire

date

=item contract_end

date

=item cancel

date

=item usernum

order taker (see L<FS::access_user>)

=item manual_flag

If this field is set to 1, disables the automatic
unsuspension of this package when using the B<unsuspendauto> config option.

=item quantity

If not set, defaults to 1

=item change_date

Date of change from previous package

=item change_pkgnum

Previous pkgnum

=item change_pkgpart

Previous pkgpart

=item change_locationnum

Previous locationnum

=item waive_setup

=item main_pkgnum

The pkgnum of the package that this package is supplemental to, if any.

=item pkglinknum

The package link (L<FS::part_pkg_link>) that defines this supplemental
package, if it is one.

=item change_to_pkgnum

The pkgnum of the package this one will be "changed to" in the future
(on its expiration date).

=back

Note: setup, last_bill, bill, adjourn, susp, expire, cancel and change_date
are specified as UNIX timestamps; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=head1 METHODS

=over 4

=item new HASHREF

Create a new billing item.  To add the item to the database, see L<"insert">.

=cut

sub table { 'cust_pkg'; }
sub cust_linked { $_[0]->cust_main_custnum || $_[0]->custnum } 
sub cust_unlinked_msg {
  my $self = shift;
  "WARNING: can't find cust_main.custnum ". $self->custnum.
  ' (cust_pkg.pkgnum '. $self->pkgnum. ')';
}

=item set_initial_timers

If required by the package definition, sets any automatic expire, adjourn,
or contract_end timers to some number of months after the start date 
(or setup date, if the package has already been setup). If the package has
a delayed setup fee after a period of "free days", will also set the 
start date to the end of that period.

=cut

sub set_initial_timers {
  my $self = shift;
  my $part_pkg = $self->part_pkg;
  foreach my $action ( qw(expire adjourn contract_end) ) {
    my $months = $part_pkg->option("${action}_months",1);
    if($months and !$self->get($action)) {
      my $start = $self->start_date || $self->setup || time;
      $self->set($action, $part_pkg->add_freq($start, $months) );
    }
  }

  # if this package has "free days" and delayed setup fee, then
  # set start date that many days in the future.
  # (this should have been set in the UI, but enforce it here)
  if ( $part_pkg->option('free_days',1)
       && $part_pkg->option('delay_setup',1)
     )
  {
    $self->start_date( $part_pkg->default_start_date );
  }
  '';
}

=item insert [ OPTION => VALUE ... ]

Adds this billing item to the database ("Orders" the item).  If there is an
error, returns the error, otherwise returns false.

If the additional field I<promo_code> is defined instead of I<pkgpart>, it
will be used to look up the package definition and agent restrictions will be
ignored.

If the additional field I<refnum> is defined, an FS::pkg_referral record will
be created and inserted.  Multiple FS::pkg_referral records can be created by
setting I<refnum> to an array reference of refnums or a hash reference with
refnums as keys.  If no I<refnum> is defined, a default FS::pkg_referral
record will be created corresponding to cust_main.refnum.

If the additional field I<cust_pkg_usageprice> is defined, it will be treated
as an arrayref of FS::cust_pkg_usageprice objects, which will be inserted.
(Note that this field cannot be set with a usual ->cust_pkg_usageprice method.
It can be set as part of the hash when creating the object, or with the B<set>
method.)

The following options are available:

=over 4

=item change

If set true, supresses actions that should only be taken for new package
orders.  (Currently this includes: intro periods when delay_setup is on,
auto-adding a 1st start date, auto-adding expiration/adjourn/contract_end dates)

=item options

cust_pkg_option records will be created

=item ticket_subject

a ticket will be added to this customer with this subject

=item ticket_queue

an optional queue name for ticket additions

=item allow_pkgpart

Don't check the legality of the package definition.  This should be used
when performing a package change that doesn't change the pkgpart (i.e. 
a location change).

=back

=cut

sub insert {
  my( $self, %options ) = @_;

  my $error;
  $error = $self->check_pkgpart unless $options{'allow_pkgpart'};
  return $error if $error;

  my $part_pkg = $self->part_pkg;

  if ( ! $import && ! $options{'change'} ) {

    # set order date to now
    $self->order_date(time) unless ($import && $self->order_date);

    # if the package def says to start only on the first of the month:
    if ( $part_pkg->option('start_1st', 1) && !$self->start_date ) {
      my ($sec,$min,$hour,$mday,$mon,$year) = (localtime(time) )[0,1,2,3,4,5];
      $mon += 1 unless $mday == 1;
      until ( $mon < 12 ) { $mon -= 12; $year++; }
      $self->start_date( timelocal_nocheck(0,0,0,1,$mon,$year) );
    }

    if ($self->susp eq 'now' or $part_pkg->start_on_hold) {
      # if the package was ordered on hold:
      # - suspend it
      # - don't set the start date (it will be started manually)
      $self->set('susp', $self->order_date);
      $self->set('start_date', '');
    } else {
      # set expire/adjourn/contract_end timers, and free days, if appropriate
      $self->set_initial_timers;
    }
  } # else this is a package change, and shouldn't have "new package" behavior

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->SUPER::insert($options{options} ? %{$options{options}} : ());
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $self->refnum($self->cust_main->refnum) unless $self->refnum;
  $self->refnum( [ $self->refnum ] ) unless ref($self->refnum);
  $self->process_m2m( 'link_table'   => 'pkg_referral',
                      'target_table' => 'part_referral',
                      'params'       => $self->refnum,
                    );

  if ( $self->hashref->{cust_pkg_usageprice} ) {
    for my $cust_pkg_usageprice ( @{ $self->hashref->{cust_pkg_usageprice} } ) {
      $cust_pkg_usageprice->pkgnum( $self->pkgnum );
      my $error = $cust_pkg_usageprice->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  if ( $self->discountnum ) {
    my $error = $self->insert_discount();
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $conf = new FS::Conf;

  if ( ! $import && $conf->config('ticket_system') && $options{ticket_subject} ) {

    #this init stuff is still inefficient, but at least its limited to 
    # the small number (any?) folks using ticket emailing on pkg order

    #eval '
    #  use lib ( "/opt/rt3/local/lib", "/opt/rt3/lib" );
    #  use RT;
    #';
    #die $@ if $@;
    #
    #RT::LoadConfig();
    #RT::Init();
    use FS::TicketSystem;
    FS::TicketSystem->init();

    my $q = new RT::Queue($RT::SystemUser);
    $q->Load($options{ticket_queue}) if $options{ticket_queue};
    my $t = new RT::Ticket($RT::SystemUser);
    my $mime = new MIME::Entity;
    $mime->build( Type => 'text/plain', Data => $options{ticket_subject} );
    $t->Create( $options{ticket_queue} ? (Queue => $q) : (),
                Subject => $options{ticket_subject},
                MIMEObj => $mime,
              );
    $t->AddLink( Type   => 'MemberOf',
                 Target => 'freeside://freeside/cust_main/'. $self->custnum,
               );
  }

  if (! $import && $conf->config('welcome_letter') && $self->cust_main->num_pkgs == 1) {
    my $queue = new FS::queue {
      'job'     => 'FS::cust_main::queueable_print',
    };
    $error = $queue->insert(
      'custnum'  => $self->custnum,
      'template' => 'welcome_letter',
    );

    if ($error) {
      warn "can't send welcome letter: $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete

This method now works but you probably shouldn't use it.

You don't want to delete packages, because there would then be no record
the customer ever purchased the package.  Instead, see the cancel method and
hide cancelled packages.

=cut

sub delete {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $cust_pkg_discount ($self->cust_pkg_discount) {
    my $error = $cust_pkg_discount->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }
  #cust_bill_pkg_discount?

  foreach my $cust_pkg_detail ($self->cust_pkg_detail) {
    my $error = $cust_pkg_detail->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $cust_pkg_reason (
    qsearchs( {
                'table' => 'cust_pkg_reason',
                'hashref' => { 'pkgnum' => $self->pkgnum },
              }
            )
  ) {
    my $error = $cust_pkg_reason->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  #pkg_referral?

  my $error = $self->SUPER::delete(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace [ OLD_RECORD ] [ HASHREF | OPTION => VALUE ... ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Currently, custnum, setup, bill, adjourn, susp, expire, and cancel may be changed.

Changing pkgpart may have disasterous effects.  See the order subroutine.

setup and bill are normally updated by calling the bill method of a customer
object (see L<FS::cust_main>).

suspend is normally updated by the suspend and unsuspend methods.

cancel is normally updated by the cancel method (and also the order subroutine
in some cases).

Available options are:

=over 4

=item reason

can be set to a cancellation reason (see L<FS:reason>), either a reasonnum of an existing reason, or passing a hashref will create a new reason.  The hashref should have the following keys: typenum - Reason type (see L<FS::reason_type>, reason - Text of the new reason.

=item reason_otaker

the access_user (see L<FS::access_user>) providing the reason

=item options

hashref of keys and values - cust_pkg_option records will be created, updated or removed as appopriate

=back

=cut

sub replace {
  my $new = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $new->replace_old;

  my $options = 
    ( ref($_[0]) eq 'HASH' )
      ? shift
      : { @_ };

  #return "Can't (yet?) change pkgpart!" if $old->pkgpart != $new->pkgpart;
  #return "Can't change otaker!" if $old->otaker ne $new->otaker;

  #allow this *sigh*
  #return "Can't change setup once it exists!"
  #  if $old->getfield('setup') &&
  #     $old->getfield('setup') != $new->getfield('setup');

  #some logic for bill, susp, cancel?

  local($disable_agentcheck) = 1 if $old->pkgpart == $new->pkgpart;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $method ( qw(adjourn expire) ) {  # How many reasons?
    if ($options->{'reason'} && $new->$method && $old->$method ne $new->$method) {
      my $error = $new->insert_reason(
        'reason'        => $options->{'reason'},
        'date'          => $new->$method,
        'action'        => $method,
        'reason_otaker' => $options->{'reason_otaker'},
      );
      if ( $error ) {
        dbh->rollback if $oldAutoCommit;
        return "Error inserting cust_pkg_reason: $error";
      }
    }
  }

  #save off and freeze RADIUS attributes for any associated svc_acct records
  my @svc_acct = ();
  if ( $old->part_pkg->is_prepaid || $new->part_pkg->is_prepaid ) {

                #also check for specific exports?
                # to avoid spurious modify export events
    @svc_acct = map  { $_->svc_x }
                grep { $_->part_svc->svcdb eq 'svc_acct' }
                     $old->cust_svc;

    $_->snapshot foreach @svc_acct;

  }

  my $error =  $new->export_pkg_change($old)
            || $new->SUPER::replace( $old,
                                     $options->{options}
                                       ? $options->{options}
                                       : ()
                                   );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  #for prepaid packages,
  #trigger export of new RADIUS Expiration attribute when cust_pkg.bill changes
  foreach my $old_svc_acct ( @svc_acct ) {
    my $new_svc_acct = new FS::svc_acct { $old_svc_acct->hash };
    my $s_error =
      $new_svc_acct->replace( $old_svc_acct,
                              'depend_jobnum' => $options->{depend_jobnum},
                            );
    if ( $s_error ) {
      $dbh->rollback if $oldAutoCommit;
      return $s_error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item check

Checks all fields to make sure this is a valid billing item.  If there is an
error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my $self = shift;

  if ( !$self->locationnum or $self->locationnum == -1 ) {
    $self->set('locationnum', $self->cust_main->ship_locationnum);
  }

  my $error = 
    $self->ut_numbern('pkgnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_numbern('pkgpart')
    || $self->ut_foreign_keyn('contactnum',  'contact',       'contactnum' )
    || $self->ut_foreign_keyn('locationnum', 'cust_location', 'locationnum')
    || $self->ut_foreign_keyn('salesnum', 'sales', 'salesnum')
    || $self->ut_numbern('quantity')
    || $self->ut_numbern('start_date')
    || $self->ut_numbern('setup')
    || $self->ut_numbern('bill')
    || $self->ut_numbern('susp')
    || $self->ut_numbern('cancel')
    || $self->ut_numbern('adjourn')
    || $self->ut_numbern('resume')
    || $self->ut_numbern('expire')
    || $self->ut_numbern('dundate')
    || $self->ut_flag('no_auto', [ '', 'Y' ])
    || $self->ut_flag('waive_setup', [ '', 'Y' ])
    || $self->ut_flag('separate_bill')
    || $self->ut_textn('agent_pkgid')
    || $self->ut_enum('recur_show_zero', [ '', 'Y', 'N', ])
    || $self->ut_enum('setup_show_zero', [ '', 'Y', 'N', ])
    || $self->ut_foreign_keyn('main_pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_foreign_keyn('pkglinknum', 'part_pkg_link', 'pkglinknum')
    || $self->ut_foreign_keyn('change_to_pkgnum', 'cust_pkg', 'pkgnum')
  ;
  return $error if $error;

  return "A package with both start date (future start) and setup date (already started) will never bill"
    if $self->start_date && $self->setup && ! $upgrade;

  return "A future unsuspend date can only be set for a package with a suspend date"
    if $self->resume and !$self->susp and !$self->adjourn;

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  if ( $self->dbdef_table->column('manual_flag') ) {
    $self->manual_flag('') if $self->manual_flag eq ' ';
    $self->manual_flag =~ /^([01]?)$/
      or return "Illegal manual_flag ". $self->manual_flag;
    $self->manual_flag($1);
  }

  $self->SUPER::check;
}

=item check_pkgpart

Check the pkgpart to make sure it's allowed with the reg_code and/or
promo_code of the package (if present) and with the customer's agent.
Called from C<insert>, unless we are doing a package change that doesn't
affect pkgpart.

=cut

sub check_pkgpart {
  my $self = shift;

  # my $error = $self->ut_numbern('pkgpart'); # already done

  my $error;
  if ( $self->reg_code ) {

    unless ( grep { $self->pkgpart == $_->pkgpart }
             map  { $_->reg_code_pkg }
             qsearchs( 'reg_code', { 'code'     => $self->reg_code,
                                     'agentnum' => $self->cust_main->agentnum })
           ) {
      return "Unknown registration code";
    }

  } elsif ( $self->promo_code ) {

    my $promo_part_pkg =
      qsearchs('part_pkg', {
        'pkgpart'    => $self->pkgpart,
        'promo_code' => { op=>'ILIKE', value=>$self->promo_code },
      } );
    return 'Unknown promotional code' unless $promo_part_pkg;

  } else { 

    unless ( $disable_agentcheck ) {
      my $agent =
        qsearchs( 'agent', { 'agentnum' => $self->cust_main->agentnum } );
      return "agent ". $agent->agentnum. ':'. $agent->agent.
             " can't purchase pkgpart ". $self->pkgpart
        unless $agent->pkgpart_hashref->{ $self->pkgpart }
            || $agent->agentnum == $self->part_pkg->agentnum;
    }

    $error = $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart' );
    return $error if $error;

  }

  '';

}

=item cancel [ OPTION => VALUE ... ]

Cancels and removes all services (see L<FS::cust_svc> and L<FS::part_svc>)
in this package, then cancels the package itself (sets the cancel field to
now).

Available options are:

=over 4

=item quiet - can be set true to supress email cancellation notices.

=item time -  can be set to cancel the package based on a specific future or 
historical date.  Using time ensures that the remaining amount is calculated 
correctly.  Note however that this is an immediate cancel and just changes 
the date.  You are PROBABLY looking to expire the account instead of using 
this.

=item reason - can be set to a cancellation reason (see L<FS:reason>), 
either a reasonnum of an existing reason, or passing a hashref will create 
a new reason.  The hashref should have the following keys: typenum - Reason 
type (see L<FS::reason_type>, reason - Text of the new reason.

=item date - can be set to a unix style timestamp to specify when to 
cancel (expire)

=item nobill - can be set true to skip billing if it might otherwise be done.

=item unused_credit - can be set to 1 to credit the remaining time, or 0 to 
not credit it.  This must be set (by change()) when changing the package 
to a different pkgpart or location, and probably shouldn't be in any other 
case.  If it's not set, the 'unused_credit_cancel' part_pkg option will 
be used.

=item no_delay_cancel - prevents delay_cancel behavior
no matter what other options say, for use when changing packages (or any
other time you're really sure you want an immediate cancel)

=back

If there is an error, returns the error, otherwise returns false.

=cut

#NOT DOCUMENTING - this should only be used when calling recursively
#=item delay_cancel - for internal use, to allow proper handling of
#supplemental packages when the main package is flagged to suspend 
#before cancelling, probably shouldn't be used otherwise (set the
#corresponding package option instead)

sub cancel {
  my( $self, %options ) = @_;
  my $error;

  # pass all suspend/cancel actions to the main package
  # (unless the pkglinknum has been removed, then the link is defunct and
  # this package can be canceled on its own)
  if ( $self->main_pkgnum and $self->pkglinknum and !$options{'from_main'} ) {
    return $self->main_pkg->cancel(%options);
  }

  my $conf = new FS::Conf;

  warn "cust_pkg::cancel called with options".
       join(', ', map { "$_: $options{$_}" } keys %options ). "\n"
    if $DEBUG;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  
  my $old = $self->select_for_update;

  if ( $old->get('cancel') || $self->get('cancel') ) {
    dbh->rollback if $oldAutoCommit;
    return "";  # no error
  }

  # XXX possibly set cancel_time to the expire date?
  my $cancel_time = $options{'time'} || time;
  my $date = $options{'date'} if $options{'date'}; # expire/cancel later
  $date = '' if ($date && $date <= $cancel_time);      # complain instead?

  my $delay_cancel = $options{'no_delay_cancel'} ? 0 : $options{'delay_cancel'};
  if ( !$date && $self->part_pkg->option('delay_cancel',1)
       && (($self->status eq 'active') || ($self->status eq 'suspended'))
       && !$options{'no_delay_cancel'}
  ) {
    my $expdays = $conf->config('part_pkg-delay_cancel-days') || 1;
    my $expsecs = 60*60*24*$expdays;
    my $suspfor = $self->susp ? $cancel_time - $self->susp : 0;
    $expsecs = $expsecs - $suspfor if $suspfor;
    unless ($expsecs <= 0) { #if it's already been suspended long enough, don't re-suspend
      $delay_cancel = 1;
      $date = $cancel_time + $expsecs;
    }
  }

  #race condition: usage could be ongoing until unprovisioned
  #resolved by performing a change package instead (which unprovisions) and
  #later cancelling
  if ( !$options{nobill} && !$date ) {
    # && $conf->exists('bill_usage_on_cancel') ) { #calc_cancel checks this
      my $copy = $self->new({$self->hash});
      my $error =
        $copy->cust_main->bill( 'pkg_list' => [ $copy ], 
                                'cancel'   => 1,
                                'time'     => $cancel_time );
      warn "Error billing during cancel, custnum ".
        #$self->cust_main->custnum. ": $error"
        ": $error"
        if $error;
  }

  if ( $options{'reason'} ) {
    $error = $self->insert_reason( 'reason' => $options{'reason'},
                                   'action' => $date ? 'expire' : 'cancel',
                                   'date'   => $date ? $date : $cancel_time,
                                   'reason_otaker' => $options{'reason_otaker'},
                                 );
    if ( $error ) {
      dbh->rollback if $oldAutoCommit;
      return "Error inserting cust_pkg_reason: $error";
    }
  }

  my %svc_cancel_opt = ();
  $svc_cancel_opt{'date'} = $date if $date;
  foreach my $cust_svc (
    #schwartz
    map  { $_->[0] }
    sort { $a->[1] <=> $b->[1] }
    map  { [ $_, $_->svc_x ? $_->svc_x->table_info->{'cancel_weight'} : -1 ]; }
    qsearch( 'cust_svc', { 'pkgnum' => $self->pkgnum } )
  ) {
    my $part_svc = $cust_svc->part_svc;
    next if ( defined($part_svc) and $part_svc->preserve );
    my $error = $cust_svc->cancel( %svc_cancel_opt );

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return 'Error '. ($svc_cancel_opt{'date'} ? 'expiring' : 'canceling' ).
             " cust_svc: $error";
    }
  }

  unless ($date) {
    # credit remaining time if appropriate
    my $do_credit;
    if ( exists($options{'unused_credit'}) ) {
      $do_credit = $options{'unused_credit'};
    }
    else {
      $do_credit = $self->part_pkg->option('unused_credit_cancel', 1);
    }
    if ( $do_credit ) {
      my $error = $self->credit_remaining('cancel', $cancel_time);
      if ($error) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  } #unless $date

  my %hash = $self->hash;
  if ( $date ) {
    $hash{'expire'} = $date;
    if ($delay_cancel) {
      # just to be sure these are clear
      $hash{'adjourn'} = undef;
      $hash{'resume'} = undef;
    }
  } else {
    $hash{'cancel'} = $cancel_time;
  }
  $hash{'change_custnum'} = $options{'change_custnum'};

  # if this is a supplemental package that's lost its part_pkg_link, and it's
  # being canceled for real, unlink it completely
  if ( !$date and ! $self->pkglinknum ) {
    $hash{main_pkgnum} = '';
  }

  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options } );
  if ( $self->change_to_pkgnum ) {
    my $change_to = FS::cust_pkg->by_key($self->change_to_pkgnum);
    $error ||= $change_to->cancel('no_delay_cancel' => 1) || $change_to->delete;
  }
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $supp_pkg ( $self->supplemental_pkgs ) {
    $error = $supp_pkg->cancel(%options, 
      'from_main' => 1, 
      'date' => $date, #in case it got changed by delay_cancel
      'delay_cancel' => $delay_cancel,
    );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "canceling supplemental pkg#".$supp_pkg->pkgnum.": $error";
    }
  }

  if ($delay_cancel && !$options{'from_main'}) {
    $error = $new->suspend(
      'from_cancel' => 1,
      'time'        => $cancel_time
    );
  }

  unless ($date) {
    foreach my $usage ( $self->cust_pkg_usage ) {
      $error = $usage->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "deleting usage pools: $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  return '' if $date; #no errors

  my @invoicing_list = grep { $_ !~ /^(POST|FAX)$/ } $self->cust_main->invoicing_list;
  if ( !$options{'quiet'} && 
        $conf->exists('emailcancel', $self->cust_main->agentnum) && 
        @invoicing_list ) {
    my $msgnum = $conf->config('cancel_msgnum', $self->cust_main->agentnum);
    my $error = '';
    if ( $msgnum ) {
      my $msg_template = qsearchs('msg_template', { msgnum => $msgnum });
      $error = $msg_template->send( 'cust_main' => $self->cust_main,
                                    'object'    => $self );
    }
    else {
      $error = send_email(
        'from'    => $conf->invoice_from_full( $self->cust_main->agentnum ),
        'to'      => \@invoicing_list,
        'subject' => ( $conf->config('cancelsubject') || 'Cancellation Notice' ),
        'body'    => [ map "$_\n", $conf->config('cancelmessage') ],
        'custnum' => $self->custnum,
        'msgtype' => '', #admin?
      );
    }
    #should this do something on errors?
  }

  ''; #no errors

}

=item cancel_if_expired [ NOW_TIMESTAMP ]

Cancels this package if its expire date has been reached.

=cut

sub cancel_if_expired {
  my $self = shift;
  my $time = shift || time;
  return '' unless $self->expire && $self->expire <= $time;
  my $error = $self->cancel;
  if ( $error ) {
    return "Error cancelling expired pkg ". $self->pkgnum. " for custnum ".
           $self->custnum. ": $error";
  }
  '';
}

=item uncancel

"Un-cancels" this package: Orders a new package with the same custnum, pkgpart,
locationnum, (other fields?).  Attempts to re-provision cancelled services
using history information (errors at this stage are not fatal).

cust_pkg: pass a scalar reference, will be filled in with the new cust_pkg object

svc_fatal: service provisioning errors are fatal

svc_errors: pass an array reference, will be filled in with any provisioning errors

main_pkgnum: link the package as a supplemental package of this one.  For 
internal use only.

=cut

sub uncancel {
  my( $self, %options ) = @_;

  #in case you try do do $uncancel-date = $cust_pkg->uncacel 
  return '' unless $self->get('cancel');

  if ( $self->main_pkgnum and !$options{'main_pkgnum'} ) {
    return $self->main_pkg->uncancel(%options);
  }

  ##
  # Transaction-alize
  ##

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  ##
  # insert the new package
  ##

  my $cust_pkg = new FS::cust_pkg {
    last_bill       => ( $options{'last_bill'} || $self->get('last_bill') ),
    bill            => ( $options{'bill'}      || $self->get('bill')      ),
    uncancel        => time,
    uncancel_pkgnum => $self->pkgnum,
    main_pkgnum     => ($options{'main_pkgnum'} || ''),
    map { $_ => $self->get($_) } qw(
      custnum pkgpart locationnum
      setup
      susp adjourn resume expire start_date contract_end dundate
      change_date change_pkgpart change_locationnum
      manual_flag no_auto separate_bill quantity agent_pkgid 
      recur_show_zero setup_show_zero
    ),
  };

  my $error = $cust_pkg->insert(
    'change' => 1, #supresses any referral credit to a referring customer
    'allow_pkgpart' => 1, # allow this even if the package def is disabled
  );
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  ##
  # insert services
  ##

  #find historical services within this timeframe before the package cancel
  # (incompatible with "time" option to cust_pkg->cancel?)
  my $fuzz = 2 * 60; #2 minutes?  too much?   (might catch separate unprovision)
                     #            too little? (unprovisioing export delay?)
  my($end, $start) = ( $self->get('cancel'), $self->get('cancel') - $fuzz );
  my @h_cust_svc = $self->h_cust_svc( $end, $start );

  my @svc_errors;
  foreach my $h_cust_svc (@h_cust_svc) {
    my $h_svc_x = $h_cust_svc->h_svc_x( $end, $start );
    #next unless $h_svc_x; #should this happen?
    (my $table = $h_svc_x->table) =~ s/^h_//;
    require "FS/$table.pm";
    my $class = "FS::$table";
    my $svc_x = $class->new( {
      'pkgnum'  => $cust_pkg->pkgnum,
      'svcpart' => $h_cust_svc->svcpart,
      map { $_ => $h_svc_x->get($_) } fields($table)
    } );

    # radius_usergroup
    if ( $h_svc_x->isa('FS::h_svc_Radius_Mixin') ) {
      $svc_x->usergroup( [ $h_svc_x->h_usergroup($end, $start) ] );
    }

    my $svc_error = $svc_x->insert;
    if ( $svc_error ) {
      if ( $options{svc_fatal} ) {
        $dbh->rollback if $oldAutoCommit;
        return $svc_error;
      } else {
        # if we've failed to insert the svc_x object, svc_Common->insert 
        # will have removed the cust_svc already.  if not, then both records
        # were inserted but we failed for some other reason (export, most 
        # likely).  in that case, report the error and delete the records.
        push @svc_errors, $svc_error;
        my $cust_svc = qsearchs('cust_svc', { 'svcnum' => $svc_x->svcnum });
        if ( $cust_svc ) {
          # except if export_insert failed, export_delete probably won't be
          # much better
          local $FS::svc_Common::noexport_hack = 1;
          my $cleanup_error = $svc_x->delete; # also deletes cust_svc
          if ( $cleanup_error ) { # and if THAT fails, then run away
            $dbh->rollback if $oldAutoCommit;
            return $cleanup_error;
          }
        }
      } # svc_fatal
    } # svc_error
  } #foreach $h_cust_svc

  #these are pretty rare, but should handle them
  # - dsl_device (mac addresses)
  # - phone_device (mac addresses)
  # - dsl_note (ikano notes)
  # - domain_record (i.e. restore DNS information w/domains)
  # - inventory_item(?) (inventory w/un-cancelling service?)
  # - nas (svc_broaband nas stuff)
  #this stuff is unused in the wild afaik
  # - mailinglistmember
  # - router.svcnum?
  # - svc_domain.parent_svcnum?
  # - acct_snarf (ancient mail fetching config)
  # - cgp_rule (communigate)
  # - cust_svc_option (used by our Tron stuff)
  # - acct_rt_transaction (used by our time worked stuff)

  ##
  # also move over any services that didn't unprovision at cancellation
  ## 

  foreach my $cust_svc ( qsearch('cust_svc', { pkgnum => $self->pkgnum } ) ) {
    $cust_svc->pkgnum( $cust_pkg->pkgnum );
    my $error = $cust_svc->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  ##
  # Uncancel any supplemental packages, and make them supplemental to the 
  # new one.
  ##

  foreach my $supp_pkg ( $self->supplemental_pkgs ) {
    my $new_pkg;
    $error = $supp_pkg->uncancel(%options, 'main_pkgnum' => $cust_pkg->pkgnum);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "canceling supplemental pkg#".$supp_pkg->pkgnum.": $error";
    }
  }

  ##
  # Finish
  ##

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ${ $options{cust_pkg} }   = $cust_pkg   if ref($options{cust_pkg});
  @{ $options{svc_errors} } = @svc_errors if ref($options{svc_errors});

  '';
}

=item unexpire

Cancels any pending expiration (sets the expire field to null).

If there is an error, returns the error, otherwise returns false.

=cut

sub unexpire {
  my( $self, %options ) = @_;
  my $error;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $old = $self->select_for_update;

  my $pkgnum = $old->pkgnum;
  if ( $old->get('cancel') || $self->get('cancel') ) {
    dbh->rollback if $oldAutoCommit;
    return "Can't unexpire cancelled package $pkgnum";
    # or at least it's pointless
  }

  unless ( $old->get('expire') && $self->get('expire') ) {
    dbh->rollback if $oldAutoCommit;
    return "";  # no error
  }

  my %hash = $self->hash;
  $hash{'expire'} = '';
  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options } );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors

}

=item suspend [ OPTION => VALUE ... ]

Suspends all services (see L<FS::cust_svc> and L<FS::part_svc>) in this
package, then suspends the package itself (sets the susp field to now).

Available options are:

=over 4

=item reason - can be set to a cancellation reason (see L<FS:reason>),
either a reasonnum of an existing reason, or passing a hashref will create 
a new reason.  The hashref should have the following keys: 
- typenum - Reason type (see L<FS::reason_type>
- reason - Text of the new reason.

=item date - can be set to a unix style timestamp to specify when to 
suspend (adjourn)

=item time - can be set to override the current time, for calculation 
of final invoices or unused-time credits

=item resume_date - can be set to a time when the package should be 
unsuspended.  This may be more convenient than calling C<unsuspend()>
separately.

=item from_main - allows a supplemental package to be suspended, rather
than redirecting the method call to its main package.  For internal use.

=item from_cancel - used when suspending from the cancel method, forces
this to skip everything besides basic suspension.  For internal use.

=back

If there is an error, returns the error, otherwise returns false.

=cut

sub suspend {
  my( $self, %options ) = @_;
  my $error;

  # pass all suspend/cancel actions to the main package
  if ( $self->main_pkgnum and !$options{'from_main'} ) {
    return $self->main_pkg->suspend(%options);
  }

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $old = $self->select_for_update;

  my $pkgnum = $old->pkgnum;
  if ( $old->get('cancel') || $self->get('cancel') ) {
    dbh->rollback if $oldAutoCommit;
    return "Can't suspend cancelled package $pkgnum";
  }

  if ( $old->get('susp') || $self->get('susp') ) {
    dbh->rollback if $oldAutoCommit;
    return "";  # no error                     # complain on adjourn?
  }

  my $suspend_time = $options{'time'} || time;
  my $date = $options{date} if $options{date}; # adjourn/suspend later
  $date = '' if ($date && $date <= $suspend_time); # complain instead?

  if ( $date && $old->get('expire') && $old->get('expire') < $date ) {
    dbh->rollback if $oldAutoCommit;
    return "Package $pkgnum expires before it would be suspended.";
  }

  # some false laziness with sub cancel
  if ( !$options{nobill} && !$date && !$options{'from_cancel'} &&
       $self->part_pkg->option('bill_suspend_as_cancel',1) ) {
    # kind of a kludge--'bill_suspend_as_cancel' to avoid having to 
    # make the entire cust_main->bill path recognize 'suspend' and 
    # 'cancel' separately.
    warn "Billing $pkgnum on suspension (at $suspend_time)\n" if $DEBUG;
    my $copy = $self->new({$self->hash});
    my $error =
      $copy->cust_main->bill( 'pkg_list' => [ $copy ], 
                              'cancel'   => 1,
                              'time'     => $suspend_time );
    warn "Error billing during suspend, custnum ".
      #$self->cust_main->custnum. ": $error"
      ": $error"
      if $error;
  }

  my $cust_pkg_reason;
  if ( $options{'reason'} ) {
    $error = $self->insert_reason( 'reason' => $options{'reason'},
                                   'action' => $date ? 'adjourn' : 'suspend',
                                   'date'   => $date ? $date : $suspend_time,
                                   'reason_otaker' => $options{'reason_otaker'},
                                 );
    if ( $error ) {
      dbh->rollback if $oldAutoCommit;
      return "Error inserting cust_pkg_reason: $error";
    }
    $cust_pkg_reason = qsearchs('cust_pkg_reason', {
        'date'    => $date ? $date : $suspend_time,
        'action'  => $date ? 'A' : 'S',
        'pkgnum'  => $self->pkgnum,
    });
  }

  # if a reasonnum was passed, get the actual reason object so we can check
  # unused_credit
  # (passing a reason hashref is still allowed, but it can't be used with
  # the fancy behavioral options.)

  my $reason;
  if ($options{'reason'} =~ /^\d+$/) {
    $reason = FS::reason->by_key($options{'reason'});
  }

  my %hash = $self->hash;
  if ( $date ) {
    $hash{'adjourn'} = $date;
  } else {
    $hash{'susp'} = $suspend_time;
  }

  my $resume_date = $options{'resume_date'} || 0;
  if ( $resume_date > ($date || $suspend_time) ) {
    $hash{'resume'} = $resume_date;
  }

  $options{options} ||= {};

  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options,
                                              %{ $options{options} },
                                            }
                        );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  unless ( $date ) { # then we are suspending now

    unless ($options{'from_cancel'}) {
      # credit remaining time if appropriate
      # (if required by the package def, or the suspend reason)
      my $unused_credit = $self->part_pkg->option('unused_credit_suspend',1)
                          || ( defined($reason) && $reason->unused_credit );

      if ( $unused_credit ) {
        warn "crediting unused time on pkg#".$self->pkgnum."\n" if $DEBUG;
        my $error = $self->credit_remaining('suspend', $suspend_time);
        if ($error) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }
    }

    my @labels = ();

    foreach my $cust_svc (
      qsearch( 'cust_svc', { 'pkgnum' => $self->pkgnum } )
    ) {
      my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $cust_svc->svcpart } );

      $part_svc->svcdb =~ /^([\w\-]+)$/ or do {
        $dbh->rollback if $oldAutoCommit;
        return "Illegal svcdb value in part_svc!";
      };
      my $svcdb = $1;
      require "FS/$svcdb.pm";

      my $svc = qsearchs( $svcdb, { 'svcnum' => $cust_svc->svcnum } );
      if ($svc) {
        $error = $svc->suspend;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
        my( $label, $value ) = $cust_svc->label;
        push @labels, "$label: $value";
      }
    }

    # suspension fees: if there is a feepart, and it's not an unsuspend fee,
    # and this is not a suspend-before-cancel
    if ( $cust_pkg_reason ) {
      my $reason_obj = $cust_pkg_reason->reason;
      if ( $reason_obj->feepart and
           ! $reason_obj->fee_on_unsuspend and
           ! $options{'from_cancel'} ) {

        # register the need to charge a fee, cust_main->bill will do the rest
        warn "registering suspend fee: pkgnum ".$self->pkgnum.", feepart ".$reason->feepart."\n"
          if $DEBUG;
        my $cust_pkg_reason_fee = FS::cust_pkg_reason_fee->new({
            'pkgreasonnum'  => $cust_pkg_reason->num,
            'pkgnum'        => $self->pkgnum,
            'feepart'       => $reason->feepart,
            'nextbill'      => $reason->fee_hold,
        });
        $error ||= $cust_pkg_reason_fee->insert;
      }
    }

    my $conf = new FS::Conf;
    if ( $conf->config('suspend_email_admin') && !$options{'from_cancel'} ) {
 
      my $error = send_email(
        'from'    => $conf->config('invoice_from', $self->cust_main->agentnum),
                                   #invoice_from ??? well as good as any
        'to'      => $conf->config('suspend_email_admin'),
        'subject' => 'FREESIDE NOTIFICATION: Customer package suspended',
        'body'    => [
          "This is an automatic message from your Freeside installation\n",
          "informing you that the following customer package has been suspended:\n",
          "\n",
          'Customer: #'. $self->custnum. ' '. $self->cust_main->name. "\n",
          'Package : #'. $self->pkgnum. " (". $self->part_pkg->pkg_comment. ")\n",
          ( map { "Service : $_\n" } @labels ),
        ],
        'custnum' => $self->custnum,
        'msgtype' => 'admin'
      );

      if ( $error ) {
        warn "WARNING: can't send suspension admin email (suspending anyway): ".
             "$error\n";
      }

    }

  }

  foreach my $supp_pkg ( $self->supplemental_pkgs ) {
    $error = $supp_pkg->suspend(%options, 'from_main' => 1);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "suspending supplemental pkg#".$supp_pkg->pkgnum.": $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors
}

=item credit_remaining MODE TIME

Generate a credit for this package for the time remaining in the current 
billing period.  MODE is either "suspend" or "cancel" (determines the 
credit type).  TIME is the time of suspension/cancellation.  Both arguments
are mandatory.

=cut

# Implementation note:
#
# If you pkgpart-change a package that has been billed, and it's set to give
# credit on package change, then this method gets called and then the new
# package will have no last_bill date. Therefore the customer will be credited
# only once (per billing period) even if there are multiple package changes.
#
# If you location-change a package that has been billed, this method will NOT
# be called and the new package WILL have the last bill date of the old
# package.
#
# If the new package is then canceled within the same billing cycle, 
# credit_remaining needs to run calc_remain on the OLD package to determine
# the amount of unused time to credit.

sub credit_remaining {
  # Add a credit for remaining service
  my ($self, $mode, $time) = @_;
  die 'credit_remaining requires suspend or cancel' 
    unless $mode eq 'suspend' or $mode eq 'cancel';
  die 'no suspend/cancel time' unless $time > 0;

  my $conf = FS::Conf->new;
  my $reason_type = $conf->config($mode.'_credit_type');

  my $last_bill = $self->getfield('last_bill') || 0;
  my $next_bill = $self->getfield('bill') || 0;
  if ( $last_bill > 0         # the package has been billed
      and $next_bill > 0      # the package has a next bill date
      and $next_bill >= $time # which is in the future
  ) {
    my @cust_credit_source_bill_pkg = ();
    my $remaining_value = 0;

    my $remain_pkg = $self;
    $remaining_value = $remain_pkg->calc_remain(
      'time' => $time, 
      'cust_credit_source_bill_pkg' => \@cust_credit_source_bill_pkg,
    );

    # we may have to walk back past some package changes to get to the 
    # one that actually has unused time
    while ( $remaining_value == 0 ) {
      if ( $remain_pkg->change_pkgnum ) {
        $remain_pkg = FS::cust_pkg->by_key($remain_pkg->change_pkgnum);
      } else {
        # the package has really never been billed
        return;
      }
      $remaining_value = $remain_pkg->calc_remain(
        'time' => $time, 
        'cust_credit_source_bill_pkg' => \@cust_credit_source_bill_pkg,
      );
    }

    if ( $remaining_value > 0 ) {
      warn "Crediting for $remaining_value on package ".$self->pkgnum."\n"
        if $DEBUG;
      my $error = $self->cust_main->credit(
        $remaining_value,
        'Credit for unused time on '. $self->part_pkg->pkg,
        'reason_type' => $reason_type,
        'cust_credit_source_bill_pkg' => \@cust_credit_source_bill_pkg,
      );
      return "Error crediting customer \$$remaining_value for unused time".
        " on ". $self->part_pkg->pkg. ": $error"
        if $error;
    } #if $remaining_value
  } #if $last_bill, etc.
  '';
}

=item unsuspend [ OPTION => VALUE ... ]

Unsuspends all services (see L<FS::cust_svc> and L<FS::part_svc>) in this
package, then unsuspends the package itself (clears the susp field and the
adjourn field if it is in the past).  If the suspend reason includes an 
unsuspension package, that package will be ordered.

Available options are:

=over 4

=item date

Can be set to a date to unsuspend the package in the future (the 'resume' 
field).

=item adjust_next_bill

Can be set true to adjust the next bill date forward by
the amount of time the account was inactive.  This was set true by default
in the past (from 1.4.2 and 1.5.0pre6 through 1.7.0), but now needs to be
explicitly requested with this option or in the price plan.

=back

If there is an error, returns the error, otherwise returns false.

=cut

sub unsuspend {
  my( $self, %opt ) = @_;
  my $error;

  # pass all suspend/cancel actions to the main package
  if ( $self->main_pkgnum and !$opt{'from_main'} ) {
    return $self->main_pkg->unsuspend(%opt);
  }

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $old = $self->select_for_update;

  my $pkgnum = $old->pkgnum;
  if ( $old->get('cancel') || $self->get('cancel') ) {
    $dbh->rollback if $oldAutoCommit;
    return "Can't unsuspend cancelled package $pkgnum";
  }

  unless ( $old->get('susp') && $self->get('susp') ) {
    $dbh->rollback if $oldAutoCommit;
    return "";  # no error                     # complain instead?
  }

  # handle the case of setting a future unsuspend (resume) date
  # and do not continue to actually unsuspend the package
  my $date = $opt{'date'};
  if ( $date and $date > time ) { # return an error if $date <= time?

    if ( $old->get('expire') && $old->get('expire') < $date ) {
      $dbh->rollback if $oldAutoCommit;
      return "Package $pkgnum expires before it would be unsuspended.";
    }

    my $new = new FS::cust_pkg { $self->hash };
    $new->set('resume', $date);
    $error = $new->replace($self, options => $self->options);

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    else {
      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
      return '';
    }
  
  } #if $date 

  if (!$self->setup) {
    # then this package is being released from on-hold status
    $self->set_initial_timers;
  }

  my @labels = ();

  foreach my $cust_svc (
    qsearch('cust_svc',{'pkgnum'=> $self->pkgnum } )
  ) {
    my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $cust_svc->svcpart } );

    $part_svc->svcdb =~ /^([\w\-]+)$/ or do {
      $dbh->rollback if $oldAutoCommit;
      return "Illegal svcdb value in part_svc!";
    };
    my $svcdb = $1;
    require "FS/$svcdb.pm";

    my $svc = qsearchs( $svcdb, { 'svcnum' => $cust_svc->svcnum } );
    if ($svc) {
      $error = $svc->unsuspend;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      my( $label, $value ) = $cust_svc->label;
      push @labels, "$label: $value";
    }

  }

  my $cust_pkg_reason = $self->last_cust_pkg_reason('susp');
  my $reason = $cust_pkg_reason ? $cust_pkg_reason->reason : '';

  my %hash = $self->hash;
  my $inactive = time - $hash{'susp'};

  my $conf = new FS::Conf;

  #adjust the next bill date forward
  # increment next bill date if certain conditions are met:
  # - it was due to be billed at some point
  # - either the global or local config says to do this
  my $adjust_bill = 0;
  if (
       $inactive > 0
    && ( $hash{'bill'} || $hash{'setup'} )
    && (    $opt{'adjust_next_bill'}
         || $conf->exists('unsuspend-always_adjust_next_bill_date')
         || $self->part_pkg->option('unsuspend_adjust_bill', 1)
       )
  ) {
    $adjust_bill = 1;
  }

  # but not if:
  # - the package billed during suspension
  # - or it was ordered on hold
  # - or the customer was credited for the unused time

  if ( $self->option('suspend_bill',1)
      or ( $self->part_pkg->option('suspend_bill',1)
           and ! $self->option('no_suspend_bill',1)
         )
      or $hash{'order_date'} == $hash{'susp'}
  ) {
    $adjust_bill = 0;
  }

  if ( $adjust_bill ) {
    if (    $self->part_pkg->option('unused_credit_suspend')
         or ( ref($reason) and $reason->unused_credit ) ) {
      # then the customer was credited for the unused time before suspending,
      # so their next bill should be immediate 
      $hash{'bill'} = time;
    } else {
      # add the length of time suspended to the bill date
      $hash{'bill'} = ( $hash{'bill'} || $hash{'setup'} ) + $inactive;
    }
  }

  $hash{'susp'} = '';
  $hash{'adjourn'} = '' if $hash{'adjourn'} and $hash{'adjourn'} < time;
  $hash{'resume'} = '' if !$hash{'adjourn'};
  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options } );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $unsusp_pkg;

  if ( $reason ) {
    if ( $reason->unsuspend_pkgpart ) {
      warn "Suspend reason '".$reason->reason."' uses deprecated unsuspend_pkgpart feature.\n";
      my $part_pkg = FS::part_pkg->by_key($reason->unsuspend_pkgpart)
        or $error = "Unsuspend package definition ".$reason->unsuspend_pkgpart.
                    " not found.";
      my $start_date = $self->cust_main->next_bill_date 
        if $reason->unsuspend_hold;

      if ( $part_pkg ) {
        $unsusp_pkg = FS::cust_pkg->new({
            'custnum'     => $self->custnum,
            'pkgpart'     => $reason->unsuspend_pkgpart,
            'start_date'  => $start_date,
            'locationnum' => $self->locationnum,
            # discount? probably not...
        });

        $error ||= $self->cust_main->order_pkg( 'cust_pkg' => $unsusp_pkg );
      }
    }
    # new way, using fees
    if ( $reason->feepart and $reason->fee_on_unsuspend ) {
      # register the need to charge a fee, cust_main->bill will do the rest
      warn "registering unsuspend fee: pkgnum ".$self->pkgnum.", feepart ".$reason->feepart."\n"
        if $DEBUG;
      my $cust_pkg_reason_fee = FS::cust_pkg_reason_fee->new({
          'pkgreasonnum'  => $cust_pkg_reason->num,
          'pkgnum'        => $self->pkgnum,
          'feepart'       => $reason->feepart,
          'nextbill'      => $reason->fee_hold,
      });
      $error ||= $cust_pkg_reason_fee->insert;
    }

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( $conf->config('unsuspend_email_admin') ) {
 
    my $error = send_email(
      'from'    => $conf->config('invoice_from', $self->cust_main->agentnum),
                                 #invoice_from ??? well as good as any
      'to'      => $conf->config('unsuspend_email_admin'),
      'subject' => 'FREESIDE NOTIFICATION: Customer package unsuspended',       'body'    => [
        "This is an automatic message from your Freeside installation\n",
        "informing you that the following customer package has been unsuspended:\n",
        "\n",
        'Customer: #'. $self->custnum. ' '. $self->cust_main->name. "\n",
        'Package : #'. $self->pkgnum. " (". $self->part_pkg->pkg_comment. ")\n",
        ( map { "Service : $_\n" } @labels ),
        ($unsusp_pkg ?
          "An unsuspension fee was charged: ".
            $unsusp_pkg->part_pkg->pkg_comment."\n"
          : ''
        ),
      ],
      'custnum' => $self->custnum,
      'msgtype' => 'admin',
    );

    if ( $error ) {
      warn "WARNING: can't send unsuspension admin email (unsuspending anyway): ".
           "$error\n";
    }

  }

  foreach my $supp_pkg ( $self->supplemental_pkgs ) {
    $error = $supp_pkg->unsuspend(%opt, 'from_main' => 1);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "unsuspending supplemental pkg#".$supp_pkg->pkgnum.": $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors
}

=item unadjourn

Cancels any pending suspension (sets the adjourn field to null).

If there is an error, returns the error, otherwise returns false.

=cut

sub unadjourn {
  my( $self, %options ) = @_;
  my $error;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $old = $self->select_for_update;

  my $pkgnum = $old->pkgnum;
  if ( $old->get('cancel') || $self->get('cancel') ) {
    dbh->rollback if $oldAutoCommit;
    return "Can't unadjourn cancelled package $pkgnum";
    # or at least it's pointless
  }

  if ( $old->get('susp') || $self->get('susp') ) {
    dbh->rollback if $oldAutoCommit;
    return "Can't unadjourn suspended package $pkgnum";
    # perhaps this is arbitrary
  }

  unless ( $old->get('adjourn') && $self->get('adjourn') ) {
    dbh->rollback if $oldAutoCommit;
    return "";  # no error
  }

  my %hash = $self->hash;
  $hash{'adjourn'} = '';
  $hash{'resume'}  = '';
  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options } );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors

}


=item change HASHREF | OPTION => VALUE ... 

Changes this package: cancels it and creates a new one, with a different
pkgpart or locationnum or both.  All services are transferred to the new
package (no change will be made if this is not possible).

Options may be passed as a list of key/value pairs or as a hash reference.
Options are:

=over 4

=item locationnum

New locationnum, to change the location for this package.

=item cust_location

New FS::cust_location object, to create a new location and assign it
to this package.

=item cust_main

New FS::cust_main object, to create a new customer and assign the new package
to it.

=item pkgpart

New pkgpart (see L<FS::part_pkg>).

=item refnum

New refnum (see L<FS::part_referral>).

=item quantity

New quantity; if unspecified, the new package will have the same quantity
as the old.

=item cust_pkg

"New" (existing) FS::cust_pkg object.  The package's services and other 
attributes will be transferred to this package.

=item keep_dates

Set to true to transfer billing dates (start_date, setup, last_bill, bill, 
susp, adjourn, cancel, expire, and contract_end) to the new package.

=item unprotect_svcs

Normally, change() will rollback and return an error if some services 
can't be transferred (also see the I<cust_pkg-change_svcpart> config option).
If unprotect_svcs is true, this method will transfer as many services as 
it can and then unconditionally cancel the old package.

=back

At least one of locationnum, cust_location, pkgpart, refnum, cust_main, or
cust_pkg must be specified (otherwise, what's the point?)

Returns either the new FS::cust_pkg object or a scalar error.

For example:

  my $err_or_new_cust_pkg = $old_cust_pkg->change

=cut

#some false laziness w/order
sub change {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };

  my $conf = new FS::Conf;

  # Transactionize this whole mess
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error;

  if ( $opt->{'cust_location'} ) {
    $error = $opt->{'cust_location'}->find_or_insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "creating location record: $error";
    }
    $opt->{'locationnum'} = $opt->{'cust_location'}->locationnum;
  }

  # Before going any further here: if the package is still in the pre-setup
  # state, it's safe to modify it in place. No need to charge/credit for 
  # partial period, transfer services, transfer usage pools, copy invoice
  # details, or change any dates.
  if ( ! $self->setup and ! $opt->{cust_pkg} and ! $opt->{cust_main} ) {
    foreach ( qw( locationnum pkgpart quantity refnum salesnum ) ) {
      if ( length($opt->{$_}) ) {
        $self->set($_, $opt->{$_});
      }
    }
    # almost. if the new pkgpart specifies start/adjourn/expire timers, 
    # apply those.
    if ( $opt->{'pkgpart'} and $opt->{'pkgpart'} != $self->pkgpart ) {
      $self->set_initial_timers;
    }
    $error = $self->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "modifying package: $error";
    } else {
      $dbh->commit if $oldAutoCommit;
      return '';
    }
  }

  my %hash = (); 

  my $time = time;

  $hash{'setup'} = $time if $self->setup;

  $hash{'change_date'} = $time;
  $hash{"change_$_"}  = $self->$_()
    foreach qw( pkgnum pkgpart locationnum );

  if ( $opt->{'cust_pkg'} ) {
    # treat changing to a package with a different pkgpart as a 
    # pkgpart change (because it is)
    $opt->{'pkgpart'} = $opt->{'cust_pkg'}->pkgpart;
  }

  # whether to override pkgpart checking on the new package
  my $same_pkgpart = 1;
  if ( $opt->{'pkgpart'} and ( $opt->{'pkgpart'} != $self->pkgpart ) ) {
    $same_pkgpart = 0;
  }

  my $unused_credit = 0;
  my $keep_dates = $opt->{'keep_dates'};

  # Special case.  If the pkgpart is changing, and the customer is
  # going to be credited for remaining time, don't keep setup, bill, 
  # or last_bill dates, and DO pass the flag to cancel() to credit 
  # the customer.
  if ( $opt->{'pkgpart'} 
       and $opt->{'pkgpart'} != $self->pkgpart
       and $self->part_pkg->option('unused_credit_change', 1) ) {
    $unused_credit = 1;
    $keep_dates = 0;
    $hash{$_} = '' foreach qw(setup bill last_bill);
  }

  if ( $keep_dates ) {
    foreach my $date ( qw(setup bill last_bill) ) {
      $hash{$date} = $self->getfield($date);
    }
  }
  # always keep the following dates
  foreach my $date (qw(order_date susp adjourn cancel expire resume 
                    start_date contract_end)) {
    $hash{$date} = $self->getfield($date);
  }

  # allow $opt->{'locationnum'} = '' to specifically set it to null
  # (i.e. customer default location)
  $opt->{'locationnum'} = $self->locationnum if !exists($opt->{'locationnum'});

  # usually this doesn't matter.  the two cases where it does are:
  # 1. unused_credit_change + pkgpart change + setup fee on the new package
  # and
  # 2. (more importantly) changing a package before it's billed
  $hash{'waive_setup'} = $self->waive_setup;

  # if this package is scheduled for a future package change, preserve that
  $hash{'change_to_pkgnum'} = $self->change_to_pkgnum;

  my $custnum = $self->custnum;
  if ( $opt->{cust_main} ) {
    my $cust_main = $opt->{cust_main};
    unless ( $cust_main->custnum ) { 
      my $error = $cust_main->insert( @{ $opt->{cust_main_insert_args}||[] } );
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "inserting customer record: $error";
      }
    }
    $custnum = $cust_main->custnum;
  }

  $hash{'contactnum'} = $opt->{'contactnum'} if $opt->{'contactnum'};

  my $cust_pkg;
  if ( $opt->{'cust_pkg'} ) {
    # The target package already exists; update it to show that it was 
    # changed from this package.
    $cust_pkg = $opt->{'cust_pkg'};

    # follow all the above rules for date changes, etc.
    foreach (keys %hash) {
      $cust_pkg->set($_, $hash{$_});
    }
    # except those that implement the future package change behavior
    foreach (qw(change_to_pkgnum start_date expire)) {
      $cust_pkg->set($_, '');
    }

    $error = $cust_pkg->replace;

  } else {
    # Create the new package.
    $cust_pkg = new FS::cust_pkg {
      custnum     => $custnum,
      locationnum => $opt->{'locationnum'},
      ( map {  $_ => ( $opt->{$_} || $self->$_() )  }
          qw( pkgpart quantity refnum salesnum )
      ),
      %hash,
    };
    $error = $cust_pkg->insert( 'change' => 1,
                                'allow_pkgpart' => $same_pkgpart );
  }
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return "inserting new package: $error";
  }

  # Transfer services and cancel old package.
  # Enforce service limits only if this is a pkgpart change.
  local $FS::cust_svc::ignore_quantity;
  $FS::cust_svc::ignore_quantity = 1 if $same_pkgpart;
  $error = $self->transfer($cust_pkg);
  if ($error and $error == 0) {
    # $old_pkg->transfer failed.
    $dbh->rollback if $oldAutoCommit;
    return "transferring $error";
  }

  if ( $error > 0 && $conf->exists('cust_pkg-change_svcpart') ) {
    warn "trying transfer again with change_svcpart option\n" if $DEBUG;
    $error = $self->transfer($cust_pkg, 'change_svcpart'=>1 );
    if ($error and $error == 0) {
      # $old_pkg->transfer failed.
      $dbh->rollback if $oldAutoCommit;
      return "converting $error";
    }
  }

  # We set unprotect_svcs when executing a "future package change".  It's 
  # not a user-interactive operation, so returning an error means the 
  # package change will just fail.  Rather than have that happen, we'll 
  # let leftover services be deleted.
  if ($error > 0 and !$opt->{'unprotect_svcs'}) {
    # Transfers were successful, but we still had services left on the old
    # package.  We can't change the package under this circumstances, so abort.
    $dbh->rollback if $oldAutoCommit;
    return "unable to transfer all services";
  }

  #reset usage if changing pkgpart
  # AND usage rollover is off (otherwise adds twice, now and at package bill)
  if ($self->pkgpart != $cust_pkg->pkgpart) {
    my $part_pkg = $cust_pkg->part_pkg;
    $error = $part_pkg->reset_usage($cust_pkg, $part_pkg->is_prepaid
                                                 ? ()
                                                 : ( 'null' => 1 )
                                   )
      if $part_pkg->can('reset_usage') && ! $part_pkg->option('usage_rollover',1);

    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return "setting usage values: $error";
    }
  } else {
    # if NOT changing pkgpart, transfer any usage pools over
    foreach my $usage ($self->cust_pkg_usage) {
      $usage->set('pkgnum', $cust_pkg->pkgnum);
      $error = $usage->replace;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "transferring usage pools: $error";
      }
    }
  }

  # transfer usage pricing add-ons, if we're not changing pkgpart
  if ( $same_pkgpart ) {
    foreach my $old_cust_pkg_usageprice ($self->cust_pkg_usageprice) {
      my $new_cust_pkg_usageprice = new FS::cust_pkg_usageprice {
        'pkgnum'         => $cust_pkg->pkgnum,
        'usagepricepart' => $old_cust_pkg_usageprice->usagepricepart,
        'quantity'       => $old_cust_pkg_usageprice->quantity,
      };
      $error = $new_cust_pkg_usageprice->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error transferring usage pricing add-on: $error";
      }
    }
  }

  # transfer discounts, if we're not changing pkgpart
  if ( $same_pkgpart ) {
    foreach my $old_discount ($self->cust_pkg_discount_active) {
      # don't remove the old discount, we may still need to bill that package.
      my $new_discount = new FS::cust_pkg_discount {
        'pkgnum'      => $cust_pkg->pkgnum,
        'discountnum' => $old_discount->discountnum,
        'months_used' => $old_discount->months_used,
      };
      $error = $new_discount->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "transferring discounts: $error";
      }
    }
  }

  # transfer (copy) invoice details
  foreach my $detail ($self->cust_pkg_detail) {
    my $new_detail = FS::cust_pkg_detail->new({ $detail->hash });
    $new_detail->set('pkgdetailnum', '');
    $new_detail->set('pkgnum', $cust_pkg->pkgnum);
    $error = $new_detail->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "transferring package notes: $error";
    }
  }
  
  my @new_supp_pkgs;

  if ( !$opt->{'cust_pkg'} ) {
    # Order any supplemental packages.
    my $part_pkg = $cust_pkg->part_pkg;
    my @old_supp_pkgs = $self->supplemental_pkgs;
    foreach my $link ($part_pkg->supp_part_pkg_link) {
      my $old;
      foreach (@old_supp_pkgs) {
        if ($_->pkgpart == $link->dst_pkgpart) {
          $old = $_;
          $_->pkgpart(0); # so that it can't match more than once
        }
        last if $old;
      }
      # false laziness with FS::cust_main::Packages::order_pkg
      my $new = FS::cust_pkg->new({
          pkgpart       => $link->dst_pkgpart,
          pkglinknum    => $link->pkglinknum,
          custnum       => $custnum,
          main_pkgnum   => $cust_pkg->pkgnum,
          locationnum   => $cust_pkg->locationnum,
          start_date    => $cust_pkg->start_date,
          order_date    => $cust_pkg->order_date,
          expire        => $cust_pkg->expire,
          adjourn       => $cust_pkg->adjourn,
          contract_end  => $cust_pkg->contract_end,
          refnum        => $cust_pkg->refnum,
          discountnum   => $cust_pkg->discountnum,
          waive_setup   => $cust_pkg->waive_setup,
      });
      if ( $old and $opt->{'keep_dates'} ) {
        foreach (qw(setup bill last_bill)) {
          $new->set($_, $old->get($_));
        }
      }
      $error = $new->insert( allow_pkgpart => $same_pkgpart );
      # transfer services
      if ( $old ) {
        $error ||= $old->transfer($new);
      }
      if ( $error and $error > 0 ) {
        # no reason why this should ever fail, but still...
        $error = "Unable to transfer all services from supplemental package ".
          $old->pkgnum;
      }
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      push @new_supp_pkgs, $new;
    }
  } # if !$opt->{'cust_pkg'}
    # because if there is one, then supplemental packages would already
    # have been created for it.

  #Good to go, cancel old package.  Notify 'cancel' of whether to credit 
  #remaining time.
  #Don't allow billing the package (preceding period packages and/or 
  #outstanding usage) if we are keeping dates (i.e. location changing), 
  #because the new package will be billed for the same date range.
  #Supplemental packages are also canceled here.

  # during scheduled changes, avoid canceling the package we just
  # changed to (duh)
  $self->set('change_to_pkgnum' => '');

  $error = $self->cancel(
    quiet          => 1, 
    unused_credit  => $unused_credit,
    nobill         => $keep_dates,
    change_custnum => ( $self->custnum != $custnum ? $custnum : '' ),
    no_delay_cancel => 1,
  );
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return "canceling old package: $error";
  }

  if ( $conf->exists('cust_pkg-change_pkgpart-bill_now') ) {
    #$self->cust_main
    my $error = $cust_pkg->cust_main->bill( 
      'pkg_list' => [ $cust_pkg, @new_supp_pkgs ]
    );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "billing new package: $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  $cust_pkg;

}

=item change_later OPTION => VALUE...

Schedule a package change for a later date.  This actually orders the new
package immediately, but sets its start date for a future date, and sets
the current package to expire on the same date.

If the package is already scheduled for a change, this can be called with 
'start_date' to change the scheduled date, or with pkgpart and/or 
locationnum to modify the package change.  To cancel the scheduled change 
entirely, see C<abort_change>.

Options include:

=over 4

=item start_date

The date for the package change.  Required, and must be in the future.

=item pkgpart

=item locationnum

=item quantity

The pkgpart. locationnum, and quantity of the new package, with the same 
meaning as in C<change>.

=back

=cut

sub change_later {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_main = $self->cust_main;

  my $date = delete $opt->{'start_date'} or return 'start_date required';
 
  if ( $date <= time ) {
    $dbh->rollback if $oldAutoCommit;
    return "start_date $date is in the past";
  }

  my $error;

  if ( $self->change_to_pkgnum ) {
    my $change_to = FS::cust_pkg->by_key($self->change_to_pkgnum);
    my $new_pkgpart = $opt->{'pkgpart'}
        if $opt->{'pkgpart'} and $opt->{'pkgpart'} != $change_to->pkgpart;
    my $new_locationnum = $opt->{'locationnum'}
        if $opt->{'locationnum'} and $opt->{'locationnum'} != $change_to->locationnum;
    my $new_quantity = $opt->{'quantity'}
        if $opt->{'quantity'} and $opt->{'quantity'} != $change_to->quantity;
    if ( $new_pkgpart or $new_locationnum or $new_quantity ) {
      # it hasn't been billed yet, so in principle we could just edit
      # it in place (w/o a package change), but that's bad form.
      # So change the package according to the new options...
      my $err_or_pkg = $change_to->change(%$opt);
      if ( ref $err_or_pkg ) {
        # Then set that package up for a future start.
        $self->set('change_to_pkgnum', $err_or_pkg->pkgnum);
        $self->set('expire', $date); # in case it's different
        $err_or_pkg->set('start_date', $date);
        $err_or_pkg->set('change_date', '');
        $err_or_pkg->set('change_pkgnum', '');

        $error = $self->replace       ||
                 $err_or_pkg->replace ||
                 $change_to->cancel('no_delay_cancel' => 1) ||
                 $change_to->delete;
      } else {
        $error = $err_or_pkg;
      }
    } else { # change the start date only.
      $self->set('expire', $date);
      $change_to->set('start_date', $date);
      $error = $self->replace || $change_to->replace;
    }
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    } else {
      $dbh->commit if $oldAutoCommit;
      return '';
    }
  } # if $self->change_to_pkgnum

  my $new_pkgpart = $opt->{'pkgpart'}
      if $opt->{'pkgpart'} and $opt->{'pkgpart'} != $self->pkgpart;
  my $new_locationnum = $opt->{'locationnum'}
      if $opt->{'locationnum'} and $opt->{'locationnum'} != $self->locationnum;
  my $new_quantity = $opt->{'quantity'}
      if $opt->{'quantity'} and $opt->{'quantity'} != $self->quantity;

  return '' unless $new_pkgpart or $new_locationnum or $new_quantity; # wouldn't do anything

  # allow $opt->{'locationnum'} = '' to specifically set it to null
  # (i.e. customer default location)
  $opt->{'locationnum'} = $self->locationnum if !exists($opt->{'locationnum'});

  my $new = FS::cust_pkg->new( {
    custnum     => $self->custnum,
    locationnum => $opt->{'locationnum'},
    start_date  => $date,
    map   {  $_ => ( $opt->{$_} || $self->$_() )  }
      qw( pkgpart quantity refnum salesnum )
  } );
  $error = $new->insert('change' => 1, 
                        'allow_pkgpart' => ($new_pkgpart ? 0 : 1));
  if ( !$error ) {
    $self->set('change_to_pkgnum', $new->pkgnum);
    $self->set('expire', $date);
    $error = $self->replace;
  }
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
  } else {
    $dbh->commit if $oldAutoCommit;
  }

  $error;
}

=item abort_change

Cancels a future package change scheduled by C<change_later>.

=cut

sub abort_change {
  my $self = shift;
  my $pkgnum = $self->change_to_pkgnum;
  my $change_to = FS::cust_pkg->by_key($pkgnum) if $pkgnum;
  my $error;
  if ( $change_to ) {
    $error = $change_to->cancel || $change_to->delete;
    return $error if $error;
  }
  $self->set('change_to_pkgnum', '');
  $self->set('expire', '');
  $self->replace;
}

=item set_quantity QUANTITY

Change the package's quantity field.  This is one of the few package properties
that can safely be changed without canceling and reordering the package
(because it doesn't affect tax eligibility).  Returns an error or an 
empty string.

=cut

sub set_quantity {
  my $self = shift;
  $self = $self->replace_old; # just to make sure
  $self->quantity(shift);
  $self->replace;
}

=item set_salesnum SALESNUM

Change the package's salesnum (sales person) field.  This is one of the few
package properties that can safely be changed without canceling and reordering
the package (because it doesn't affect tax eligibility).  Returns an error or
an empty string.

=cut

sub set_salesnum {
  my $self = shift;
  $self = $self->replace_old; # just to make sure
  $self->salesnum(shift);
  $self->replace;
  # XXX this should probably reassign any credit that's already been given
}

=item modify_charge OPTIONS

Change the properties of a one-time charge.  The following properties can
be changed this way:
- pkg: the package description
- classnum: the package class
- additional: arrayref of additional invoice details to add to this package

and, I<if the charge has not yet been billed>:
- start_date: the date when it will be billed
- amount: the setup fee to be charged
- quantity: the multiplier for the setup fee
- separate_bill: whether to put the charge on a separate invoice

If you pass 'adjust_commission' => 1, and the classnum changes, and there are
commission credits linked to this charge, they will be recalculated.

=cut

sub modify_charge {
  my $self = shift;
  my %opt = @_;
  my $part_pkg = $self->part_pkg;
  my $pkgnum = $self->pkgnum;

  my $dbh = dbh;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  return "Can't use modify_charge except on one-time charges"
    unless $part_pkg->freq eq '0';

  if ( length($opt{'pkg'}) and $part_pkg->pkg ne $opt{'pkg'} ) {
    $part_pkg->set('pkg', $opt{'pkg'});
  }

  my %pkg_opt = $part_pkg->options;
  my $pkg_opt_modified = 0;

  $opt{'additional'} ||= [];
  my $i;
  my @old_additional;
  foreach (grep /^additional/, keys %pkg_opt) {
    ($i) = ($_ =~ /^additional_info(\d+)$/);
    $old_additional[$i] = $pkg_opt{$_} if $i;
    delete $pkg_opt{$_};
  }

  for ( $i = 0; exists($opt{'additional'}->[$i]); $i++ ) {
    $pkg_opt{ "additional_info$i" } = $opt{'additional'}->[$i];
    if (!exists($old_additional[$i])
        or $old_additional[$i] ne $opt{'additional'}->[$i])
    {
      $pkg_opt_modified = 1;
    }
  }
  $pkg_opt_modified = 1 if (scalar(@old_additional) - 1) != $i;
  $pkg_opt{'additional_count'} = $i if $i > 0;

  my $old_classnum;
  if ( exists($opt{'classnum'}) and $part_pkg->classnum ne $opt{'classnum'} )
  {
    # remember it
    $old_classnum = $part_pkg->classnum;
    $part_pkg->set('classnum', $opt{'classnum'});
  }

  if ( !$self->get('setup') ) {
    # not yet billed, so allow amount, setup_cost, quantity, start_date,
    # and separate_bill

    if ( exists($opt{'amount'}) 
          and $part_pkg->option('setup_fee') != $opt{'amount'}
          and $opt{'amount'} > 0 ) {

      $pkg_opt{'setup_fee'} = $opt{'amount'};
      $pkg_opt_modified = 1;
    }

    if ( exists($opt{'setup_cost'}) 
          and $part_pkg->setup_cost != $opt{'setup_cost'}
          and $opt{'setup_cost'} > 0 ) {

      $part_pkg->set('setup_cost', $opt{'setup_cost'});
    }

    if ( exists($opt{'quantity'})
          and $opt{'quantity'} != $self->quantity
          and $opt{'quantity'} > 0 ) {
        
      $self->set('quantity', $opt{'quantity'});
    }

    if ( exists($opt{'start_date'})
          and $opt{'start_date'} != $self->start_date ) {

      $self->set('start_date', $opt{'start_date'});
    }

    if ( exists($opt{'separate_bill'})
          and $opt{'separate_bill'} ne $self->separate_bill ) {

      $self->set('separate_bill', $opt{'separate_bill'});
    }


  } # else simply ignore them; the UI shouldn't allow editing the fields

  
  if ( exists($opt{'taxclass'}) 
          and $part_pkg->taxclass ne $opt{'taxclass'}) {
    
      $part_pkg->set('taxclass', $opt{'taxclass'});
  }

  my $error;
  if ( $part_pkg->modified or $pkg_opt_modified ) {
    # can we safely modify the package def?
    # Yes, if it's not available for purchase, and this is the only instance
    # of it.
    if ( $part_pkg->disabled
         and FS::cust_pkg->count('pkgpart = '.$part_pkg->pkgpart) == 1
         and FS::quotation_pkg->count('pkgpart = '.$part_pkg->pkgpart) == 0
       ) {
      $error = $part_pkg->replace( options => \%pkg_opt );
    } else {
      # clone it
      $part_pkg = $part_pkg->clone;
      $part_pkg->set('disabled' => 'Y');
      $error = $part_pkg->insert( options => \%pkg_opt );
      # and associate this as yet-unbilled package to the new package def
      $self->set('pkgpart' => $part_pkg->pkgpart);
    }
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ($self->modified) { # for quantity or start_date change, or if we had
                         # to clone the existing package def
    my $error = $self->replace;
    return $error if $error;
  }
  if (defined $old_classnum) {
    # fix invoice grouping records
    my $old_catname = $old_classnum
                      ? FS::pkg_class->by_key($old_classnum)->categoryname
                      : '';
    my $new_catname = $opt{'classnum'}
                      ? $part_pkg->pkg_class->categoryname
                      : '';
    if ( $old_catname ne $new_catname ) {
      foreach my $cust_bill_pkg ($self->cust_bill_pkg) {
        # (there should only be one...)
        my @display = qsearch( 'cust_bill_pkg_display', {
            'billpkgnum'  => $cust_bill_pkg->billpkgnum,
            'section'     => $old_catname,
        });
        foreach (@display) {
          $_->set('section', $new_catname);
          $error = $_->replace;
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return $error;
          }
        }
      } # foreach $cust_bill_pkg
    }

    if ( $opt{'adjust_commission'} ) {
      # fix commission credits...tricky.
      foreach my $cust_event ($self->cust_event) {
        my $part_event = $cust_event->part_event;
        foreach my $table (qw(sales agent)) {
          my $class =
            "FS::part_event::Action::Mixin::credit_${table}_pkg_class";
          my $credit = qsearchs('cust_credit', {
              'eventnum' => $cust_event->eventnum,
          });
          if ( $part_event->isa($class) ) {
            # Yes, this results in current commission rates being applied 
            # retroactively to a one-time charge.  For accounting purposes 
            # there ought to be some kind of time limit on doing this.
            my $amount = $part_event->_calc_credit($self);
            if ( $credit and $credit->amount ne $amount ) {
              # Void the old credit.
              $error = $credit->void('Package class changed');
              if ( $error ) {
                $dbh->rollback if $oldAutoCommit;
                return "$error (adjusting commission credit)";
              }
            }
            # redo the event action to recreate the credit.
            local $@ = '';
            eval { $part_event->do_action( $self, $cust_event ) };
            if ( $@ ) {
              $dbh->rollback if $oldAutoCommit;
              return $@;
            }
          } # if $part_event->isa($class)
        } # foreach $table
      } # foreach $cust_event
    } # if $opt{'adjust_commission'}
  } # if defined $old_classnum

  $dbh->commit if $oldAutoCommit;
  '';
}



use Data::Dumper;
sub process_bulk_cust_pkg {
  my $job = shift;
  my $param = shift;
  warn Dumper($param) if $DEBUG;

  my $old_part_pkg = qsearchs('part_pkg', 
                              { pkgpart => $param->{'old_pkgpart'} });
  my $new_part_pkg = qsearchs('part_pkg',
                              { pkgpart => $param->{'new_pkgpart'} });
  die "Must select a new package type\n" unless $new_part_pkg;
  #my $keep_dates = $param->{'keep_dates'} || 0;
  my $keep_dates = 1; # there is no good reason to turn this off

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my @cust_pkgs = qsearch('cust_pkg', { 'pkgpart' => $param->{'old_pkgpart'} } );

  my $i = 0;
  foreach my $old_cust_pkg ( @cust_pkgs ) {
    $i++;
    $job->update_statustext(int(100*$i/(scalar @cust_pkgs)));
    if ( $old_cust_pkg->getfield('cancel') ) {
      warn '[process_bulk_cust_pkg ] skipping canceled pkgnum '.
        $old_cust_pkg->pkgnum."\n"
        if $DEBUG;
      next;
    }
    warn '[process_bulk_cust_pkg] changing pkgnum '.$old_cust_pkg->pkgnum."\n"
      if $DEBUG;
    my $error = $old_cust_pkg->change(
      'pkgpart'     => $param->{'new_pkgpart'},
      'keep_dates'  => $keep_dates
    );
    if ( !ref($error) ) { # change returns the cust_pkg on success
      $dbh->rollback;
      die "Error changing pkgnum ".$old_cust_pkg->pkgnum.": '$error'\n";
    }
  }
  $dbh->commit if $oldAutoCommit;
  return;
}

=item last_bill

Returns the last bill date, or if there is no last bill date, the setup date.
Useful for billing metered services.

=cut

sub last_bill {
  my $self = shift;
  return $self->setfield('last_bill', $_[0]) if @_;
  return $self->getfield('last_bill') if $self->getfield('last_bill');
  my $cust_bill_pkg = qsearchs('cust_bill_pkg', { 'pkgnum' => $self->pkgnum,
                                                  'edate'  => $self->bill,  } );
  $cust_bill_pkg ? $cust_bill_pkg->sdate : $self->setup || 0;
}

=item last_cust_pkg_reason ACTION

Returns the most recent ACTION FS::cust_pkg_reason associated with the package.
Returns false if there is no reason or the package is not currenly ACTION'd
ACTION is one of adjourn, susp, cancel, or expire.

=cut

sub last_cust_pkg_reason {
  my ( $self, $action ) = ( shift, shift );
  my $date = $self->get($action);
  qsearchs( {
              'table' => 'cust_pkg_reason',
              'hashref' => { 'pkgnum' => $self->pkgnum,
                             'action' => substr(uc($action), 0, 1),
                             'date'   => $date,
                           },
              'order_by' => 'ORDER BY num DESC LIMIT 1',
           } );
}

=item last_reason ACTION

Returns the most recent ACTION FS::reason associated with the package.
Returns false if there is no reason or the package is not currenly ACTION'd
ACTION is one of adjourn, susp, cancel, or expire.

=cut

sub last_reason {
  my $cust_pkg_reason = shift->last_cust_pkg_reason(@_);
  $cust_pkg_reason->reason
    if $cust_pkg_reason;
}

=item part_pkg

Returns the definition for this billing item, as an FS::part_pkg object (see
L<FS::part_pkg>).

=cut

sub part_pkg {
  my $self = shift;
  return $self->{'_pkgpart'} if $self->{'_pkgpart'};
  cluck "cust_pkg->part_pkg called" if $DEBUG > 1;
  qsearchs( 'part_pkg', { 'pkgpart' => $self->pkgpart } );
}

=item old_cust_pkg

Returns the cancelled package this package was changed from, if any.

=cut

sub old_cust_pkg {
  my $self = shift;
  return '' unless $self->change_pkgnum;
  qsearchs('cust_pkg', { 'pkgnum' => $self->change_pkgnum } );
}

=item change_cust_main

Returns the customter this package was detached to, if any.

=cut

sub change_cust_main {
  my $self = shift;
  return '' unless $self->change_custnum;
  qsearchs('cust_main', { 'custnum' => $self->change_custnum } );
}

=item calc_setup

Calls the I<calc_setup> of the FS::part_pkg object associated with this billing
item.

=cut

sub calc_setup {
  my $self = shift;
  $self->part_pkg->calc_setup($self, @_);
}

=item calc_recur

Calls the I<calc_recur> of the FS::part_pkg object associated with this billing
item.

=cut

sub calc_recur {
  my $self = shift;
  $self->part_pkg->calc_recur($self, @_);
}

=item base_setup

Calls the I<base_setup> of the FS::part_pkg object associated with this billing
item.

=cut

sub base_setup {
  my $self = shift;
  $self->part_pkg->base_setup($self, @_);
}

=item base_recur

Calls the I<base_recur> of the FS::part_pkg object associated with this billing
item.

=cut

sub base_recur {
  my $self = shift;
  $self->part_pkg->base_recur($self, @_);
}

=item calc_remain

Calls the I<calc_remain> of the FS::part_pkg object associated with this
billing item.

=cut

sub calc_remain {
  my $self = shift;
  $self->part_pkg->calc_remain($self, @_);
}

=item calc_cancel

Calls the I<calc_cancel> of the FS::part_pkg object associated with this
billing item.

=cut

sub calc_cancel {
  my $self = shift;
  $self->part_pkg->calc_cancel($self, @_);
}

=item cust_bill_pkg

Returns any invoice line items for this package (see L<FS::cust_bill_pkg>).

=cut

sub cust_bill_pkg {
  my $self = shift;
  qsearch( 'cust_bill_pkg', { 'pkgnum' => $self->pkgnum } );
}

=item cust_pkg_detail [ DETAILTYPE ]

Returns any customer package details for this package (see
L<FS::cust_pkg_detail>).

DETAILTYPE can be set to "I" for invoice details or "C" for comments.

=cut

sub cust_pkg_detail {
  my $self = shift;
  my %hash = ( 'pkgnum' => $self->pkgnum );
  $hash{detailtype} = shift if @_;
  qsearch({
    'table'    => 'cust_pkg_detail',
    'hashref'  => \%hash,
    'order_by' => 'ORDER BY weight, pkgdetailnum',
  });
}

=item set_cust_pkg_detail DETAILTYPE [ DETAIL, DETAIL, ... ]

Sets customer package details for this package (see L<FS::cust_pkg_detail>).

DETAILTYPE can be set to "I" for invoice details or "C" for comments.

If there is an error, returns the error, otherwise returns false.

=cut

sub set_cust_pkg_detail {
  my( $self, $detailtype, @details ) = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $current ( $self->cust_pkg_detail($detailtype) ) {
    my $error = $current->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error removing old detail: $error";
    }
  }

  foreach my $detail ( @details ) {
    my $cust_pkg_detail = new FS::cust_pkg_detail {
      'pkgnum'     => $self->pkgnum,
      'detailtype' => $detailtype,
      'detail'     => $detail,
    };
    my $error = $cust_pkg_detail->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error adding new detail: $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item cust_event

Returns the customer billing events (see L<FS::cust_event>) for this invoice.

=cut

#false laziness w/cust_bill.pm
sub cust_event {
  my $self = shift;
  qsearch({
    'table'     => 'cust_event',
    'addl_from' => 'JOIN part_event USING ( eventpart )',
    'hashref'   => { 'tablenum' => $self->pkgnum },
    'extra_sql' => " AND eventtable = 'cust_pkg' ",
  });
}

=item num_cust_event

Returns the number of customer billing events (see L<FS::cust_event>) for this package.

=cut

#false laziness w/cust_bill.pm
sub num_cust_event {
  my $self = shift;
  my $sql = "SELECT COUNT(*) ". $self->_from_cust_event_where;
  $self->_prep_ex($sql, $self->pkgnum)->fetchrow_arrayref->[0];
}

=item exists_cust_event

Returns true if there are customer billing events (see L<FS::cust_event>) for this package.  More efficient than using num_cust_event.

=cut

sub exists_cust_event {
  my $self = shift;
  my $sql = "SELECT 1 ". $self->_from_cust_event_where. " LIMIT 1";
  my $row = $self->_prep_ex($sql, $self->pkgnum)->fetchrow_arrayref;
  $row ? $row->[0] : '';
}

sub _from_cust_event_where {
  #my $self = shift;
  " FROM cust_event JOIN part_event USING ( eventpart ) ".
  "  WHERE tablenum = ? AND eventtable = 'cust_pkg' ";
}

sub _prep_ex {
  my( $self, $sql, @args ) = @_;
  my $sth = dbh->prepare($sql) or die  dbh->errstr. " preparing $sql"; 
  $sth->execute(@args)         or die $sth->errstr. " executing $sql";
  $sth;
}

=item part_pkg_currency_option OPTIONNAME

Returns a two item list consisting of the currency of this customer, if any,
and a value for the provided option.  If the customer has a currency, the value
is the option value the given name and the currency (see
L<FS::part_pkg_currency>).  Otherwise, if the customer has no currency, is the
regular option value for the given name (see L<FS::part_pkg_option>).

=cut

sub part_pkg_currency_option {
  my( $self, $optionname ) = @_;
  my $part_pkg = $self->part_pkg;
  if ( my $currency = $self->cust_main->currency ) {
    ($currency, $part_pkg->part_pkg_currency_option($currency, $optionname) );
  } else {
    ('', $part_pkg->option($optionname) );
  }
}

=item cust_svc [ SVCPART ] (old, deprecated usage)

=item cust_svc [ OPTION => VALUE ... ] (current usage)

=item cust_svc_unsorted [ OPTION => VALUE ... ] 

Returns the services for this package, as FS::cust_svc objects (see
L<FS::cust_svc>).  Available options are svcpart and svcdb.  If either is
spcififed, returns only the matching services.

As an optimization, use the cust_svc_unsorted version if you are not displaying
the results.

=cut

sub cust_svc {
  my $self = shift;
  cluck "cust_pkg->cust_svc called" if $DEBUG > 2;
  $self->_sort_cust_svc( $self->cust_svc_unsorted_arrayref(@_) );
}

sub cust_svc_unsorted {
  my $self = shift;
  @{ $self->cust_svc_unsorted_arrayref(@_) };
}

sub cust_svc_unsorted_arrayref {
  my $self = shift;

  return [] unless $self->num_cust_svc(@_);

  my %opt = ();
  if ( @_ && $_[0] =~ /^\d+/ ) {
    $opt{svcpart} = shift;
  } elsif ( @_ && ref($_[0]) eq 'HASH' ) {
    %opt = %{ $_[0] };
  } elsif ( @_ ) {
    %opt = @_;
  }

  my %search = (
    'table'   => 'cust_svc',
    'hashref' => { 'pkgnum' => $self->pkgnum },
  );
  if ( $opt{svcpart} ) {
    $search{hashref}->{svcpart} = $opt{'svcpart'};
  }
  if ( $opt{'svcdb'} ) {
    $search{addl_from} = ' LEFT JOIN part_svc USING ( svcpart ) ';
    $search{extra_sql} = ' AND svcdb = '. dbh->quote( $opt{'svcdb'} );
  }

  [ qsearch(\%search) ];

}

=item overlimit [ SVCPART ]

Returns the services for this package which have exceeded their
usage limit as FS::cust_svc objects (see L<FS::cust_svc>).  If a svcpart
is specified, return only the matching services.

=cut

sub overlimit {
  my $self = shift;
  return () unless $self->num_cust_svc(@_);
  grep { $_->overlimit } $self->cust_svc(@_);
}

=item h_cust_svc END_TIMESTAMP [ START_TIMESTAMP ] [ MODE ]

Returns historical services for this package created before END TIMESTAMP and
(optionally) not cancelled before START_TIMESTAMP, as FS::h_cust_svc objects
(see L<FS::h_cust_svc>).  If MODE is 'I' (for 'invoice'), services with the 
I<pkg_svc.hidden> flag will be omitted.

=cut

sub h_cust_svc {
  my $self = shift;
  warn "$me _h_cust_svc called on $self\n"
    if $DEBUG;

  my ($end, $start, $mode) = @_;

  local($FS::Record::qsearch_qualify_columns) = 0;

  my @cust_svc = $self->_sort_cust_svc(
    [ qsearch( 'h_cust_svc',
      { 'pkgnum' => $self->pkgnum, },  
      FS::h_cust_svc->sql_h_search(@_),  
    ) ]
  );

  if ( defined($mode) && $mode eq 'I' ) {
    my %hidden_svcpart = map { $_->svcpart => $_->hidden } $self->part_svc;
    return grep { !$hidden_svcpart{$_->svcpart} } @cust_svc;
  } else {
    return @cust_svc;
  }
}

sub _sort_cust_svc {
  my( $self, $arrayref ) = @_;

  my $sort =
    sub ($$) { my ($a, $b) = @_; $b->[1] cmp $a->[1]  or  $a->[2] <=> $b->[2] };

  my %pkg_svc = map { $_->svcpart => $_ }
                qsearch( 'pkg_svc', { 'pkgpart' => $self->pkgpart } );

  map  { $_->[0] }
  sort $sort
  map {
        my $pkg_svc = $pkg_svc{ $_->svcpart } || '';
        [ $_,
          $pkg_svc ? $pkg_svc->primary_svc : '',
          $pkg_svc ? $pkg_svc->quantity : 0,
        ];
      }
  @$arrayref;

}

=item num_cust_svc [ SVCPART ] (old, deprecated usage)

=item num_cust_svc [ OPTION => VALUE ... ] (current usage)

Returns the number of services for this package.  Available options are svcpart
and svcdb.  If either is spcififed, returns only the matching services.

=cut

sub num_cust_svc {
  my $self = shift;

  return $self->{'_num_cust_svc'}
    if !scalar(@_)
       && exists($self->{'_num_cust_svc'})
       && $self->{'_num_cust_svc'} =~ /\d/;

  cluck "cust_pkg->num_cust_svc called, _num_cust_svc:".$self->{'_num_cust_svc'}
    if $DEBUG > 2;

  my %opt = ();
  if ( @_ && $_[0] =~ /^\d+/ ) {
    $opt{svcpart} = shift;
  } elsif ( @_ && ref($_[0]) eq 'HASH' ) {
    %opt = %{ $_[0] };
  } elsif ( @_ ) {
    %opt = @_;
  }

  my $select = 'SELECT COUNT(*) FROM cust_svc ';
  my $where = ' WHERE pkgnum = ? ';
  my @param = ($self->pkgnum);

  if ( $opt{'svcpart'} ) {
    $where .= ' AND svcpart = ? ';
    push @param, $opt{'svcpart'};
  }
  if ( $opt{'svcdb'} ) {
    $select .= ' LEFT JOIN part_svc USING ( svcpart ) ';
    $where .= ' AND svcdb = ? ';
    push @param, $opt{'svcdb'};
  }

  my $sth = dbh->prepare("$select $where") or die  dbh->errstr;
  $sth->execute(@param) or die $sth->errstr;
  $sth->fetchrow_arrayref->[0];
}

=item available_part_svc 

Returns a list of FS::part_svc objects representing services included in this
package but not yet provisioned.  Each FS::part_svc object also has an extra
field, I<num_avail>, which specifies the number of available services.

=cut

sub available_part_svc {
  my $self = shift;

  my $pkg_quantity = $self->quantity || 1;

  grep { $_->num_avail > 0 }
    map {
          my $part_svc = $_->part_svc;
          $part_svc->{'Hash'}{'num_avail'} = #evil encapsulation-breaking
            $pkg_quantity * $_->quantity - $self->num_cust_svc($_->svcpart);

	  # more evil encapsulation breakage
	  if($part_svc->{'Hash'}{'num_avail'} > 0) {
	    my @exports = $part_svc->part_export_did;
	    $part_svc->{'Hash'}{'can_get_dids'} = scalar(@exports);
	  }

          $part_svc;
        }
      $self->part_pkg->pkg_svc;
}

=item part_svc [ OPTION => VALUE ... ]

Returns a list of FS::part_svc objects representing provisioned and available
services included in this package.  Each FS::part_svc object also has the
following extra fields:

=over 4

=item num_cust_svc

(count)

=item num_avail

(quantity - count)

=item cust_pkg_svc

(services) - array reference containing the provisioned services, as cust_svc objects

=back

Accepts two options:

=over 4

=item summarize_size

If true, will omit the extra cust_pkg_svc option for objects where num_cust_svc
is this size or greater.

=item hide_discontinued

If true, will omit looking for services that are no longer avaialble in the
package definition.

=back

=cut

#svcnum
#label -> ($cust_svc->label)[1]

sub part_svc {
  my $self = shift;
  my %opt = @_;

  my $pkg_quantity = $self->quantity || 1;

  #XXX some sort of sort order besides numeric by svcpart...
  my @part_svc = sort { $a->svcpart <=> $b->svcpart } map {
    my $pkg_svc = $_;
    my $part_svc = $pkg_svc->part_svc;
    my $num_cust_svc = $self->num_cust_svc($part_svc->svcpart);
    $part_svc->{'Hash'}{'num_cust_svc'} = $num_cust_svc; #more evil
    $part_svc->{'Hash'}{'num_avail'}    =
      max( 0, $pkg_quantity * $pkg_svc->quantity - $num_cust_svc );
    $part_svc->{'Hash'}{'cust_pkg_svc'} =
        $num_cust_svc ? [ $self->cust_svc($part_svc->svcpart) ] : []
      unless exists($opt{summarize_size}) && $opt{summarize_size} > 0
          && $num_cust_svc >= $opt{summarize_size};
    $part_svc->{'Hash'}{'hidden'} = $pkg_svc->hidden;
    $part_svc;
  } $self->part_pkg->pkg_svc;

  unless ( $opt{hide_discontinued} ) {
    #extras
    push @part_svc, map {
      my $part_svc = $_;
      my $num_cust_svc = $self->num_cust_svc($part_svc->svcpart);
      $part_svc->{'Hash'}{'num_cust_svc'} = $num_cust_svc; #speak no evail
      $part_svc->{'Hash'}{'num_avail'}    = 0; #0-$num_cust_svc ?
      $part_svc->{'Hash'}{'cust_pkg_svc'} =
        $num_cust_svc ? [ $self->cust_svc($part_svc->svcpart) ] : [];
      $part_svc;
    } $self->extra_part_svc;
  }

  @part_svc;

}

=item extra_part_svc

Returns a list of FS::part_svc objects corresponding to services in this
package which are still provisioned but not (any longer) available in the
package definition.

=cut

sub extra_part_svc {
  my $self = shift;

  my $pkgnum  = $self->pkgnum;
  #my $pkgpart = $self->pkgpart;

#  qsearch( {
#    'table'     => 'part_svc',
#    'hashref'   => {},
#    'extra_sql' =>
#      "WHERE 0 = ( SELECT COUNT(*) FROM pkg_svc 
#                     WHERE pkg_svc.svcpart = part_svc.svcpart 
#                       AND pkg_svc.pkgpart = ?
#                       AND quantity > 0 
#                 )
#	 AND 0 < ( SELECT COUNT(*) FROM cust_svc
#                       LEFT JOIN cust_pkg USING ( pkgnum )
#                     WHERE cust_svc.svcpart = part_svc.svcpart
#                       AND pkgnum = ?
#                 )",
#    'extra_param' => [ [$self->pkgpart=>'int'], [$self->pkgnum=>'int'] ],
#  } );

#seems to benchmark slightly faster... (or did?)

  my @pkgparts = map $_->pkgpart, $self->part_pkg->self_and_svc_linked;
  my $pkgparts = join(',', @pkgparts);

  qsearch( {
    #'select'      => 'DISTINCT ON (svcpart) part_svc.*',
    #MySQL doesn't grok DISINCT ON
    'select'      => 'DISTINCT part_svc.*',
    'table'       => 'part_svc',
    'addl_from'   =>
      "LEFT JOIN pkg_svc  ON (     pkg_svc.svcpart   = part_svc.svcpart 
                               AND pkg_svc.pkgpart IN ($pkgparts)
                               AND quantity > 0
                             )
       LEFT JOIN cust_svc ON (     cust_svc.svcpart = part_svc.svcpart )
       LEFT JOIN cust_pkg USING ( pkgnum )
      ",
    'hashref'     => {},
    'extra_sql'   => "WHERE pkgsvcnum IS NULL AND cust_pkg.pkgnum = ? ",
    'extra_param' => [ [$self->pkgnum=>'int'] ],
  } );
}

=item status

Returns a short status string for this package, currently:

=over 4

=item on hold

=item not yet billed

=item one-time charge

=item active

=item suspended

=item cancelled

=back

=cut

sub status {
  my $self = shift;

  my $freq = length($self->freq) ? $self->freq : $self->part_pkg->freq;

  return 'cancelled' if $self->get('cancel');
  return 'on hold' if $self->susp && ! $self->setup;
  return 'suspended' if $self->susp;
  return 'not yet billed' unless $self->setup;
  return 'one-time charge' if $freq =~ /^(0|$)/;
  return 'active';
}

=item ucfirst_status

Returns the status with the first character capitalized.

=cut

sub ucfirst_status {
  ucfirst(shift->status);
}

=item statuses

Class method that returns the list of possible status strings for packages
(see L<the status method|/status>).  For example:

  @statuses = FS::cust_pkg->statuses();

=cut

tie my %statuscolor, 'Tie::IxHash', 
  'on hold'         => 'FF00F5', #brighter purple!
  'not yet billed'  => '009999', #teal? cyan?
  'one-time charge' => '0000CC', #blue  #'000000',
  'active'          => '00CC00',
  'suspended'       => 'FF9900',
  'cancelled'       => 'FF0000',
;

sub statuses {
  my $self = shift; #could be class...
  #grep { $_ !~ /^(not yet billed)$/ } #this is a dumb status anyway
  #                                    # mayble split btw one-time vs. recur
    keys %statuscolor;
}

sub statuscolors {
  #my $self = shift;
  \%statuscolor;
}

=item statuscolor

Returns a hex triplet color string for this package's status.

=cut

sub statuscolor {
  my $self = shift;
  $statuscolor{$self->status};
}

=item is_status_delay_cancel

Returns true if part_pkg has option delay_cancel, 
cust_pkg status is 'suspended' and expire is set
to cancel package within the next day (or however
many days are set in global config part_pkg-delay_cancel-days.

This is not a real status, this only meant for hacking display 
values, because otherwise treating the package as suspended is 
really the whole point of the delay_cancel option.

=cut

sub is_status_delay_cancel {
  my ($self) = @_;
  if ( $self->main_pkgnum and $self->pkglinknum ) {
    return $self->main_pkg->is_status_delay_cancel;
  }
  return 0 unless $self->part_pkg->option('delay_cancel',1);
  return 0 unless $self->status eq 'suspended';
  return 0 unless $self->expire;
  my $conf = new FS::Conf;
  my $expdays = $conf->config('part_pkg-delay_cancel-days') || 1;
  my $expsecs = 60*60*24*$expdays;
  return 0 unless $self->expire < time + $expsecs;
  return 1;
}

=item pkg_label

Returns a label for this package.  (Currently "pkgnum: pkg - comment" or
"pkg - comment" depending on user preference).

=cut

sub pkg_label {
  my $self = shift;
  my $label = $self->part_pkg->pkg_comment( cust_pkg=>$self, nopkgpart=>1 );
  $label = $self->pkgnum. ": $label"
    if $FS::CurrentUser::CurrentUser->option('show_pkgnum');
  $label;
}

=item pkg_label_long

Returns a long label for this package, adding the primary service's label to
pkg_label.

=cut

sub pkg_label_long {
  my $self = shift;
  my $label = $self->pkg_label;
  my $cust_svc = $self->primary_cust_svc;
  $label .= ' ('. ($cust_svc->label)[1]. ')' if $cust_svc;
  $label;
}

=item pkg_locale

Returns a customer-localized label for this package.

=cut

sub pkg_locale {
  my $self = shift;
  $self->part_pkg->pkg_locale( $self->cust_main->locale );
}

=item primary_cust_svc

Returns a primary service (as FS::cust_svc object) if one can be identified.

=cut

#for labeling purposes - might not 100% match up with part_pkg->svcpart's idea

sub primary_cust_svc {
  my $self = shift;

  my @cust_svc = $self->cust_svc;

  return '' unless @cust_svc; #no serivces - irrelevant then
  
  return $cust_svc[0] if scalar(@cust_svc) == 1; #always return a single service

  # primary service as specified in the package definition
  # or exactly one service definition with quantity one
  my $svcpart = $self->part_pkg->svcpart;
  @cust_svc = grep { $_->svcpart == $svcpart } @cust_svc;
  return $cust_svc[0] if scalar(@cust_svc) == 1;

  #couldn't identify one thing..
  return '';
}

=item labels

Returns a list of lists, calling the label method for all services
(see L<FS::cust_svc>) of this billing item.

=cut

sub labels {
  my $self = shift;
  map { [ $_->label ] } $self->cust_svc;
}

=item h_labels END_TIMESTAMP [ START_TIMESTAMP ] [ MODE ]

Like the labels method, but returns historical information on services that
were active as of END_TIMESTAMP and (optionally) not cancelled before
START_TIMESTAMP.  If MODE is 'I' (for 'invoice'), services with the 
I<pkg_svc.hidden> flag will be omitted.

Returns a list of lists, calling the label method for all (historical) services
(see L<FS::h_cust_svc>) of this billing item.

=cut

sub h_labels {
  my $self = shift;
  warn "$me _h_labels called on $self\n"
    if $DEBUG;
  map { [ $_->label(@_) ] } $self->h_cust_svc(@_);
}

=item labels_short

Like labels, except returns a simple flat list, and shortens long
(currently >5 or the cust_bill-max_same_services configuration value) lists of
identical services to one line that lists the service label and the number of
individual services rather than individual items.

=cut

sub labels_short {
  shift->_labels_short( 'labels', @_ );
}

=item h_labels_short END_TIMESTAMP [ START_TIMESTAMP ]

Like h_labels, except returns a simple flat list, and shortens long
(currently >5 or the cust_bill-max_same_services configuration value) lists of
identical services to one line that lists the service label and the number of
individual services rather than individual items.

=cut

sub h_labels_short {
  shift->_labels_short( 'h_labels', @_ );
}

sub _labels_short {
  my( $self, $method ) = ( shift, shift );

  warn "$me _labels_short called on $self with $method method\n"
    if $DEBUG;

  my $conf = new FS::Conf;
  my $max_same_services = $conf->config('cust_bill-max_same_services') || 5;

  warn "$me _labels_short populating \%labels\n"
    if $DEBUG;

  my %labels;
  #tie %labels, 'Tie::IxHash';
  push @{ $labels{$_->[0]} }, $_->[1]
    foreach $self->$method(@_);

  warn "$me _labels_short populating \@labels\n"
    if $DEBUG;

  my @labels;
  foreach my $label ( keys %labels ) {
    my %seen = ();
    my @values = grep { ! $seen{$_}++ } @{ $labels{$label} };
    my $num = scalar(@values);
    warn "$me _labels_short $num items for $label\n"
      if $DEBUG;

    if ( $num > $max_same_services ) {
      warn "$me _labels_short   more than $max_same_services, so summarizing\n"
        if $DEBUG;
      push @labels, "$label ($num)";
    } else {
      if ( $conf->exists('cust_bill-consolidate_services') ) {
        warn "$me _labels_short   consolidating services\n"
          if $DEBUG;
        # push @labels, "$label: ". join(', ', @values);
        while ( @values ) {
          my $detail = "$label: ";
          $detail .= shift(@values). ', '
            while @values
               && ( length($detail.$values[0]) < 78 || $detail eq "$label: " );
          $detail =~ s/, $//;
          push @labels, $detail;
        }
        warn "$me _labels_short   done consolidating services\n"
          if $DEBUG;
      } else {
        warn "$me _labels_short   adding service data\n"
          if $DEBUG;
        push @labels, map { "$label: $_" } @values;
      }
    }
  }

 @labels;

}

=item cust_main

Returns the parent customer object (see L<FS::cust_main>).

=item balance

Returns the balance for this specific package, when using
experimental package balance.

=cut

sub balance {
  my $self = shift;
  $self->cust_main->balance_pkgnum( $self->pkgnum );
}

#these subs are in location_Mixin.pm now... unfortunately the POD doesn't mixin

=item cust_location

Returns the location object, if any (see L<FS::cust_location>).

=item cust_location_or_main

If this package is associated with a location, returns the locaiton (see
L<FS::cust_location>), otherwise returns the customer (see L<FS::cust_main>).

=item location_label [ OPTION => VALUE ... ]

Returns the label of the location object (see L<FS::cust_location>).

=cut

#end of subs in location_Mixin.pm now... unfortunately the POD doesn't mixin

=item tax_locationnum

Returns the foreign key to a L<FS::cust_location> object for calculating  
tax on this package, as determined by the C<tax-pkg_address> and 
C<tax-ship_address> configuration flags.

=cut

sub tax_locationnum {
  my $self = shift;
  my $conf = FS::Conf->new;
  if ( $conf->exists('tax-pkg_address') ) {
    return $self->locationnum;
  }
  elsif ( $conf->exists('tax-ship_address') ) {
    return $self->cust_main->ship_locationnum;
  }
  else {
    return $self->cust_main->bill_locationnum;
  }
}

=item tax_location

Returns the L<FS::cust_location> object for tax_locationnum.

=cut

sub tax_location {
  my $self = shift;
  my $conf = FS::Conf->new;
  if ( $conf->exists('tax-pkg_address') and $self->locationnum ) {
    return FS::cust_location->by_key($self->locationnum);
  }
  elsif ( $conf->exists('tax-ship_address') ) {
    return $self->cust_main->ship_location;
  }
  else {
    return $self->cust_main->bill_location;
  }
}

=item seconds_since TIMESTAMP

Returns the number of seconds all accounts (see L<FS::svc_acct>) in this
package have been online since TIMESTAMP, according to the session monitor.

TIMESTAMP is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=cut

sub seconds_since {
  my($self, $since) = @_;
  my $seconds = 0;

  foreach my $cust_svc (
    grep { $_->part_svc->svcdb eq 'svc_acct' } $self->cust_svc
  ) {
    $seconds += $cust_svc->seconds_since($since);
  }

  $seconds;

}

=item seconds_since_sqlradacct TIMESTAMP_START TIMESTAMP_END

Returns the numbers of seconds all accounts (see L<FS::svc_acct>) in this
package have been online between TIMESTAMP_START (inclusive) and TIMESTAMP_END
(exclusive).

TIMESTAMP_START and TIMESTAMP_END are specified as UNIX timestamps; see
L<perlfunc/"time">.  Also see L<Time::Local> and L<Date::Parse> for conversion
functions.


=cut

sub seconds_since_sqlradacct {
  my($self, $start, $end) = @_;

  my $seconds = 0;

  foreach my $cust_svc (
    grep {
      my $part_svc = $_->part_svc;
      $part_svc->svcdb eq 'svc_acct'
        && scalar($part_svc->part_export_usage);
    } $self->cust_svc
  ) {
    $seconds += $cust_svc->seconds_since_sqlradacct($start, $end);
  }

  $seconds;

}

=item attribute_since_sqlradacct TIMESTAMP_START TIMESTAMP_END ATTRIBUTE

Returns the sum of the given attribute for all accounts (see L<FS::svc_acct>)
in this package for sessions ending between TIMESTAMP_START (inclusive) and
TIMESTAMP_END
(exclusive).

TIMESTAMP_START and TIMESTAMP_END are specified as UNIX timestamps; see
L<perlfunc/"time">.  Also see L<Time::Local> and L<Date::Parse> for conversion
functions.

=cut

sub attribute_since_sqlradacct {
  my($self, $start, $end, $attrib) = @_;

  my $sum = 0;

  foreach my $cust_svc (
    grep {
      my $part_svc = $_->part_svc;
      scalar($part_svc->part_export_usage);
    } $self->cust_svc
  ) {
    $sum += $cust_svc->attribute_since_sqlradacct($start, $end, $attrib);
  }

  $sum;

}

=item quantity

=cut

sub quantity {
  my( $self, $value ) = @_;
  if ( defined($value) ) {
    $self->setfield('quantity', $value);
  }
  $self->getfield('quantity') || 1;
}

=item transfer DEST_PKGNUM | DEST_CUST_PKG, [ OPTION => VALUE ... ]

Transfers as many services as possible from this package to another package.

The destination package can be specified by pkgnum by passing an FS::cust_pkg
object.  The destination package must already exist.

Services are moved only if the destination allows services with the correct
I<svcpart> (not svcdb), unless the B<change_svcpart> option is set true.  Use
this option with caution!  No provision is made for export differences
between the old and new service definitions.  Probably only should be used
when your exports for all service definitions of a given svcdb are identical.
(attempt a transfer without it first, to move all possible svcpart-matching
services)

Any services that can't be moved remain in the original package.

Returns an error, if there is one; otherwise, returns the number of services 
that couldn't be moved.

=cut

sub transfer {
  my ($self, $dest_pkgnum, %opt) = @_;

  my $remaining = 0;
  my $dest;
  my %target;

  if (ref ($dest_pkgnum) eq 'FS::cust_pkg') {
    $dest = $dest_pkgnum;
    $dest_pkgnum = $dest->pkgnum;
  } else {
    $dest = qsearchs('cust_pkg', { pkgnum => $dest_pkgnum });
  }

  return ('Package does not exist: '.$dest_pkgnum) unless $dest;

  foreach my $pkg_svc ( $dest->part_pkg->pkg_svc ) {
    $target{$pkg_svc->svcpart} = $pkg_svc->quantity * ( $dest->quantity || 1 );
  }

  foreach my $cust_svc ($dest->cust_svc) {
    $target{$cust_svc->svcpart}--;
  }

  my %svcpart2svcparts = ();
  if ( exists $opt{'change_svcpart'} && $opt{'change_svcpart'} ) {
    warn "change_svcpart option received, creating alternates list\n" if $DEBUG;
    foreach my $svcpart ( map { $_->svcpart } $self->cust_svc ) {
      next if exists $svcpart2svcparts{$svcpart};
      my $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
      $svcpart2svcparts{$svcpart} = [
        map  { $_->[0] }
        sort { $b->[1] cmp $a->[1]  or  $a->[2] <=> $b->[2] } 
        map {
              my $pkg_svc = qsearchs( 'pkg_svc', { 'pkgpart' => $dest->pkgpart,
                                                   'svcpart' => $_          } );
              [ $_,
                $pkg_svc ? $pkg_svc->primary_svc : '',
                $pkg_svc ? $pkg_svc->quantity : 0,
              ];
            }

        grep { $_ != $svcpart }
        map  { $_->svcpart }
        qsearch('part_svc', { 'svcdb' => $part_svc->svcdb } )
      ];
      warn "alternates for svcpart $svcpart: ".
           join(', ', @{$svcpart2svcparts{$svcpart}}). "\n"
        if $DEBUG;
    }
  }

  my $error;
  foreach my $cust_svc ($self->cust_svc) {
    my $svcnum = $cust_svc->svcnum;
    if($target{$cust_svc->svcpart} > 0
       or $FS::cust_svc::ignore_quantity) { # maybe should be a 'force' option
      $target{$cust_svc->svcpart}--;
      my $new = new FS::cust_svc { $cust_svc->hash };
      $new->pkgnum($dest_pkgnum);
      $error = $new->replace($cust_svc);
    } elsif ( exists $opt{'change_svcpart'} && $opt{'change_svcpart'} ) {
      if ( $DEBUG ) {
        warn "looking for alternates for svcpart ". $cust_svc->svcpart. "\n";
        warn "alternates to consider: ".
             join(', ', @{$svcpart2svcparts{$cust_svc->svcpart}}). "\n";
      }
      my @alternate = grep {
                             warn "considering alternate svcpart $_: ".
                                  "$target{$_} available in new package\n"
                               if $DEBUG;
                             $target{$_} > 0;
                           } @{$svcpart2svcparts{$cust_svc->svcpart}};
      if ( @alternate ) {
        warn "alternate(s) found\n" if $DEBUG;
        my $change_svcpart = $alternate[0];
        $target{$change_svcpart}--;
        my $new = new FS::cust_svc { $cust_svc->hash };
        $new->svcpart($change_svcpart);
        $new->pkgnum($dest_pkgnum);
        $error = $new->replace($cust_svc);
      } else {
        $remaining++;
      }
    } else {
      $remaining++
    }
    if ( $error ) {
      my @label = $cust_svc->label;
      return "$label[0] $label[1]: $error";
    }
  }
  return $remaining;
}

=item grab_svcnums SVCNUM, SVCNUM ...

Change the pkgnum for the provided services to this packages.  If there is an
error, returns the error, otherwise returns false.

=cut

sub grab_svcnums {
  my $self = shift;
  my @svcnum = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $svcnum (@svcnum) {
    my $cust_svc = qsearchs('cust_svc', { svcnum=>$svcnum } ) or do {
      $dbh->rollback if $oldAutoCommit;
      return "unknown svcnum $svcnum";
    };
    $cust_svc->pkgnum( $self->pkgnum );
    my $error = $cust_svc->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item reexport

This method is deprecated.  See the I<depend_jobnum> option to the insert and
order_pkgs methods in FS::cust_main for a better way to defer provisioning.

=cut

#looks like this is still used by the order_pkg and change_pkg methods in
# ClientAPI/MyAccount, need to look into those before removing
sub reexport {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $cust_svc ( $self->cust_svc ) {
    #false laziness w/svc_Common::insert
    my $svc_x = $cust_svc->svc_x;
    foreach my $part_export ( $cust_svc->part_svc->part_export ) {
      my $error = $part_export->export_insert($svc_x);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item export_pkg_change OLD_CUST_PKG

Calls the "pkg_change" export action for all services attached to this package.

=cut

sub export_pkg_change {
  my( $self, $old )  = ( shift, shift );

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $svc_x ( map $_->svc_x, $self->cust_svc ) {
    my $error = $svc_x->export('pkg_change', $self, $old);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item insert_reason

Associates this package with a (suspension or cancellation) reason (see
L<FS::cust_pkg_reason>, possibly inserting a new reason on the fly (see
L<FS::reason>).

Available options are:

=over 4

=item reason

can be set to a cancellation reason (see L<FS:reason>), either a reasonnum of an existing reason, or passing a hashref will create a new reason.  The hashref should have the following keys: typenum - Reason type (see L<FS::reason_type>, reason - Text of the new reason.

=item reason_otaker

the access_user (see L<FS::access_user>) providing the reason

=item date

a unix timestamp 

=item action

the action (cancel, susp, adjourn, expire) associated with the reason

=back

If there is an error, returns the error, otherwise returns false.

=cut

sub insert_reason {
  my ($self, %options) = @_;

  my $otaker = $options{reason_otaker} ||
               $FS::CurrentUser::CurrentUser->username;

  my $reasonnum;
  if ( $options{'reason'} =~ /^(\d+)$/ ) {

    $reasonnum = $1;

  } elsif ( ref($options{'reason'}) ) {
  
    return 'Enter a new reason (or select an existing one)'
      unless $options{'reason'}->{'reason'} !~ /^\s*$/;

    my $reason = new FS::reason({
      'reason_type' => $options{'reason'}->{'typenum'},
      'reason'      => $options{'reason'}->{'reason'},
    });
    my $error = $reason->insert;
    return $error if $error;

    $reasonnum = $reason->reasonnum;

  } else {
    return "Unparseable reason: ". $options{'reason'};
  }

  my $cust_pkg_reason =
    new FS::cust_pkg_reason({ 'pkgnum'    => $self->pkgnum,
                              'reasonnum' => $reasonnum, 
		              'otaker'    => $otaker,
		              'action'    => substr(uc($options{'action'}),0,1),
		              'date'      => $options{'date'}
			                       ? $options{'date'}
					       : time,
	                    });

  $cust_pkg_reason->insert;
}

=item insert_discount

Associates this package with a discount (see L<FS::cust_pkg_discount>, possibly
inserting a new discount on the fly (see L<FS::discount>).

Available options are:

=over 4

=item discountnum

=back

If there is an error, returns the error, otherwise returns false.

=cut

sub insert_discount {
  #my ($self, %options) = @_;
  my $self = shift;

  my $cust_pkg_discount = new FS::cust_pkg_discount {
    'pkgnum'      => $self->pkgnum,
    'discountnum' => $self->discountnum,
    'months_used' => 0,
    'end_date'    => '', #XXX
    #for the create a new discount case
    '_type'       => $self->discountnum__type,
    'amount'      => $self->discountnum_amount,
    'percent'     => $self->discountnum_percent,
    'months'      => $self->discountnum_months,
    'setup'      => $self->discountnum_setup,
    #'disabled'    => $self->discountnum_disabled,
  };

  $cust_pkg_discount->insert;
}

=item set_usage USAGE_VALUE_HASHREF 

USAGE_VALUE_HASHREF is a hashref of svc_acct usage columns and the amounts
to which they should be set (see L<FS::svc_acct>).  Currently seconds,
upbytes, downbytes, and totalbytes are appropriate keys.

All svc_accts which are part of this package have their values reset.

=cut

sub set_usage {
  my ($self, $valueref, %opt) = @_;

  #only svc_acct can set_usage for now
  foreach my $cust_svc ( $self->cust_svc( 'svcdb'=>'svc_acct' ) ) {
    my $svc_x = $cust_svc->svc_x;
    $svc_x->set_usage($valueref, %opt)
      if $svc_x->can("set_usage");
  }
}

=item recharge USAGE_VALUE_HASHREF 

USAGE_VALUE_HASHREF is a hashref of svc_acct usage columns and the amounts
to which they should be set (see L<FS::svc_acct>).  Currently seconds,
upbytes, downbytes, and totalbytes are appropriate keys.

All svc_accts which are part of this package have their values incremented.

=cut

sub recharge {
  my ($self, $valueref) = @_;

  #only svc_acct can set_usage for now
  foreach my $cust_svc ( $self->cust_svc( 'svcdb'=>'svc_acct' ) ) {
    my $svc_x = $cust_svc->svc_x;
    $svc_x->recharge($valueref)
      if $svc_x->can("recharge");
  }
}

=item apply_usageprice 

=cut

sub apply_usageprice {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = '';

  foreach my $cust_pkg_usageprice ( $self->cust_pkg_usageprice ) {
    $error ||= $cust_pkg_usageprice->apply;
  }

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    die "error applying part_pkg_usageprice add-ons, pkgnum ". $self->pkgnum.
        ": $error\n";
  } else {
    $dbh->commit if $oldAutoCommit;
  }


}

=item cust_pkg_discount

=item cust_pkg_discount_active

=cut

sub cust_pkg_discount_active {
  my $self = shift;
  grep { $_->status eq 'active' } $self->cust_pkg_discount;
}

=item cust_pkg_usage

Returns a list of all voice usage counters attached to this package.

=item apply_usage OPTIONS

Takes the following options:
- cdr: a call detail record (L<FS::cdr>)
- rate_detail: the rate determined for this call (L<FS::rate_detail>)
- minutes: the maximum number of minutes to be charged

Finds available usage minutes for a call of this class, and subtracts
up to that many minutes from the usage pool.  If the usage pool is empty,
and the C<cdr-minutes_priority> global config option is set, minutes may
be taken from other calls as well.  Either way, an allocation record will
be created (L<FS::cdr_cust_pkg_usage>) and this method will return the 
number of minutes of usage applied to the call.

=cut

sub apply_usage {
  my ($self, %opt) = @_;
  my $cdr = $opt{cdr};
  my $rate_detail = $opt{rate_detail};
  my $minutes = $opt{minutes};
  my $classnum = $rate_detail->classnum;
  my $pkgnum = $self->pkgnum;
  my $custnum = $self->custnum;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $order = FS::Conf->new->config('cdr-minutes_priority');

  my $is_classnum;
  if ( $classnum ) {
    $is_classnum = ' part_pkg_usage_class.classnum = '.$classnum;
  } else {
    $is_classnum = ' part_pkg_usage_class.classnum IS NULL';
  }
  my @usage_recs = qsearch({
      'table'     => 'cust_pkg_usage',
      'addl_from' => ' JOIN part_pkg_usage       USING (pkgusagepart)'.
                     ' JOIN cust_pkg             USING (pkgnum)'.
                     ' JOIN part_pkg_usage_class USING (pkgusagepart)',
      'select'    => 'cust_pkg_usage.*',
      'extra_sql' => " WHERE ( cust_pkg.pkgnum = $pkgnum OR ".
                     " ( cust_pkg.custnum = $custnum AND ".
                     " part_pkg_usage.shared IS NOT NULL ) ) AND ".
                     $is_classnum . ' AND '.
                     " cust_pkg_usage.minutes > 0",
      'order_by'  => " ORDER BY priority ASC",
  });

  my $orig_minutes = $minutes;
  my $error;
  while (!$error and $minutes > 0 and @usage_recs) {
    my $cust_pkg_usage = shift @usage_recs;
    $cust_pkg_usage->select_for_update;
    my $cdr_cust_pkg_usage = FS::cdr_cust_pkg_usage->new({
        pkgusagenum => $cust_pkg_usage->pkgusagenum,
        acctid      => $cdr->acctid,
        minutes     => min($cust_pkg_usage->minutes, $minutes),
    });
    $cust_pkg_usage->set('minutes',
      $cust_pkg_usage->minutes - $cdr_cust_pkg_usage->minutes
    );
    $error = $cust_pkg_usage->replace || $cdr_cust_pkg_usage->insert;
    $minutes -= $cdr_cust_pkg_usage->minutes;
  }
  if ( $order and $minutes > 0 and !$error ) {
    # then try to steal minutes from another call
    my %search = (
        'table'     => 'cdr_cust_pkg_usage',
        'addl_from' => ' JOIN cust_pkg_usage        USING (pkgusagenum)'.
                       ' JOIN part_pkg_usage        USING (pkgusagepart)'.
                       ' JOIN cust_pkg              USING (pkgnum)'.
                       ' JOIN part_pkg_usage_class  USING (pkgusagepart)'.
                       ' JOIN cdr                   USING (acctid)',
        'select'    => 'cdr_cust_pkg_usage.*',
        'extra_sql' => " WHERE cdr.freesidestatus = 'rated' AND ".
                       " ( cust_pkg.pkgnum = $pkgnum OR ".
                       " ( cust_pkg.custnum = $custnum AND ".
                       " part_pkg_usage.shared IS NOT NULL ) ) AND ".
                       " part_pkg_usage_class.classnum = $classnum",
        'order_by'  => ' ORDER BY part_pkg_usage.priority ASC',
    );
    if ( $order eq 'time' ) {
      # find CDRs that are using minutes, but have a later startdate
      # than this call
      my $startdate = $cdr->startdate;
      if ($startdate !~ /^\d+$/) {
        die "bad cdr startdate '$startdate'";
      }
      $search{'extra_sql'} .= " AND cdr.startdate > $startdate";
      # minimize needless reshuffling
      $search{'order_by'} .= ', cdr.startdate DESC';
    } else {
      # XXX may not work correctly with rate_time schedules.  Could 
      # fix this by storing ratedetailnum in cdr_cust_pkg_usage, I 
      # think...
      $search{'addl_from'} .=
        ' JOIN rate_detail'.
        ' ON (cdr.rated_ratedetailnum = rate_detail.ratedetailnum)';
      if ( $order eq 'rate_high' ) {
        $search{'extra_sql'} .= ' AND rate_detail.min_charge < '.
                                $rate_detail->min_charge;
        $search{'order_by'} .= ', rate_detail.min_charge ASC';
      } elsif ( $order eq 'rate_low' ) {
        $search{'extra_sql'} .= ' AND rate_detail.min_charge > '.
                                $rate_detail->min_charge;
        $search{'order_by'} .= ', rate_detail.min_charge DESC';
      } else {
        #  this should really never happen
        die "invalid cdr-minutes_priority value '$order'\n";
      }
    }
    my @cdr_usage_recs = qsearch(\%search);
    my %reproc_cdrs;
    while (!$error and @cdr_usage_recs and $minutes > 0) {
      my $cdr_cust_pkg_usage = shift @cdr_usage_recs;
      my $cust_pkg_usage = $cdr_cust_pkg_usage->cust_pkg_usage;
      my $old_cdr = $cdr_cust_pkg_usage->cdr;
      $reproc_cdrs{$old_cdr->acctid} = $old_cdr;
      $cdr_cust_pkg_usage->select_for_update;
      $old_cdr->select_for_update;
      $cust_pkg_usage->select_for_update;
      # in case someone else stole the usage from this CDR
      # while waiting for the lock...
      next if $old_cdr->acctid != $cdr_cust_pkg_usage->acctid;
      # steal the usage allocation and flag the old CDR for reprocessing
      $cdr_cust_pkg_usage->set('acctid', $cdr->acctid);
      # if the allocation is more minutes than we need, adjust it...
      my $delta = $cdr_cust_pkg_usage->minutes - $minutes;
      if ( $delta > 0 ) {
        $cdr_cust_pkg_usage->set('minutes', $minutes);
        $cust_pkg_usage->set('minutes', $cust_pkg_usage->minutes + $delta);
        $error = $cust_pkg_usage->replace;
      }
      #warn 'CDR '.$cdr->acctid . ' stealing allocation '.$cdr_cust_pkg_usage->cdrusagenum.' from CDR '.$old_cdr->acctid."\n";
      $error ||= $cdr_cust_pkg_usage->replace;
      # deduct the stolen minutes
      $minutes -= $cdr_cust_pkg_usage->minutes;
    }
    # after all minute-stealing is done, reset the affected CDRs
    foreach (values %reproc_cdrs) {
      $error ||= $_->set_status('');
      # XXX or should we just call $cdr->rate right here?
      # it's not like we can create a loop this way, since the min_charge
      # or call time has to go monotonically in one direction.
      # we COULD get some very deep recursions going, though...
    }
  } # if $order and $minutes
  if ( $error ) {
    $dbh->rollback;
    die "error applying included minutes\npkgnum ".$self->pkgnum.", class $classnum, acctid ".$cdr->acctid."\n$error\n"
  } else {
    $dbh->commit if $oldAutoCommit;
    return $orig_minutes - $minutes;
  }
}

=item supplemental_pkgs

Returns a list of all packages supplemental to this one.

=cut

sub supplemental_pkgs {
  my $self = shift;
  qsearch('cust_pkg', { 'main_pkgnum' => $self->pkgnum });
}

=item main_pkg

Returns the package that this one is supplemental to, if any.

=cut

sub main_pkg {
  my $self = shift;
  if ( $self->main_pkgnum ) {
    return FS::cust_pkg->by_key($self->main_pkgnum);
  }
  return;
}

=back

=head1 CLASS METHODS

=over 4

=item recurring_sql

Returns an SQL expression identifying recurring packages.

=cut

sub recurring_sql { "
  '0' != ( select freq from part_pkg
             where cust_pkg.pkgpart = part_pkg.pkgpart )
"; }

=item onetime_sql

Returns an SQL expression identifying one-time packages.

=cut

sub onetime_sql { "
  '0' = ( select freq from part_pkg
            where cust_pkg.pkgpart = part_pkg.pkgpart )
"; }

=item ordered_sql

Returns an SQL expression identifying ordered packages (recurring packages not
yet billed).

=cut

sub ordered_sql {
   $_[0]->recurring_sql. " AND ". $_[0]->not_yet_billed_sql;
}

=item active_sql

Returns an SQL expression identifying active packages.

=cut

sub active_sql {
  $_[0]->recurring_sql. "
  AND cust_pkg.setup IS NOT NULL AND cust_pkg.setup != 0
  AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
  AND ( cust_pkg.susp   IS NULL OR cust_pkg.susp   = 0 )
"; }

=item not_yet_billed_sql

Returns an SQL expression identifying packages which have not yet been billed.

=cut

sub not_yet_billed_sql { "
      ( cust_pkg.setup  IS NULL OR cust_pkg.setup  = 0 )
  AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
  AND ( cust_pkg.susp   IS NULL OR cust_pkg.susp   = 0 )
"; }

=item inactive_sql

Returns an SQL expression identifying inactive packages (one-time packages
that are otherwise unsuspended/uncancelled).

=cut

sub inactive_sql { "
  ". $_[0]->onetime_sql(). "
  AND cust_pkg.setup IS NOT NULL AND cust_pkg.setup != 0
  AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
  AND ( cust_pkg.susp   IS NULL OR cust_pkg.susp   = 0 )
"; }

=item on_hold_sql

Returns an SQL expression identifying on-hold packages.

=cut

sub on_hold_sql {
  #$_[0]->recurring_sql(). ' AND '.
  "
        ( cust_pkg.cancel IS     NULL  OR cust_pkg.cancel  = 0 )
    AND   cust_pkg.susp   IS NOT NULL AND cust_pkg.susp   != 0
    AND ( cust_pkg.setup  IS     NULL  OR cust_pkg.setup   = 0 )
  ";
}

=item susp_sql
=item suspended_sql

Returns an SQL expression identifying suspended packages.

=cut

sub suspended_sql { susp_sql(@_); }
sub susp_sql {
  #$_[0]->recurring_sql(). ' AND '.
  "
        ( cust_pkg.cancel IS     NULL  OR cust_pkg.cancel = 0 )
    AND   cust_pkg.susp   IS NOT NULL AND cust_pkg.susp  != 0
    AND   cust_pkg.setup  IS NOT NULL AND cust_pkg.setup != 0
  ";
}

=item cancel_sql
=item cancelled_sql

Returns an SQL exprression identifying cancelled packages.

=cut

sub cancelled_sql { cancel_sql(@_); }
sub cancel_sql { 
  #$_[0]->recurring_sql(). ' AND '.
  "cust_pkg.cancel IS NOT NULL AND cust_pkg.cancel != 0";
}

=item status_sql

Returns an SQL expression to give the package status as a string.

=cut

sub status_sql {
"CASE
  WHEN cust_pkg.cancel IS NOT NULL THEN 'cancelled'
  WHEN ( cust_pkg.susp IS NOT NULL AND cust_pkg.setup IS NULL ) THEN 'on hold'
  WHEN cust_pkg.susp IS NOT NULL THEN 'suspended'
  WHEN cust_pkg.setup IS NULL THEN 'not yet billed'
  WHEN ".onetime_sql()." THEN 'one-time charge'
  ELSE 'active'
END"
}

=item fcc_477_count

Returns a list of two package counts.  The first is a count of packages
based on the supplied criteria and the second is the count of residential
packages with those same criteria.  Criteria are specified as in the search
method.

=cut

sub fcc_477_count {
  my ($class, $params) = @_;

  my $sql_query = $class->search( $params );

  my $count_sql = delete($sql_query->{'count_query'});
  $count_sql =~ s/ FROM/,count(CASE WHEN cust_main.company IS NULL OR cust_main.company = '' THEN 1 END) FROM/
    or die "couldn't parse count_sql";

  my $count_sth = dbh->prepare($count_sql)
    or die "Error preparing $count_sql: ". dbh->errstr;
  $count_sth->execute
    or die "Error executing $count_sql: ". $count_sth->errstr;
  my $count_arrayref = $count_sth->fetchrow_arrayref;

  return ( @$count_arrayref );

}

=item tax_locationnum_sql

Returns an SQL expression for the tax location for a package, based
on the settings of 'tax-pkg_address' and 'tax-ship_address'.

=cut

sub tax_locationnum_sql {
  my $conf = FS::Conf->new;
  if ( $conf->exists('tax-pkg_address') ) {
    'cust_pkg.locationnum';
  }
  elsif ( $conf->exists('tax-ship_address') ) {
    'cust_main.ship_locationnum';
  }
  else {
    'cust_main.bill_locationnum';
  }
}

=item location_sql

Returns a list: the first item is an SQL fragment identifying matching 
packages/customers via location (taking into account shipping and package
address taxation, if enabled), and subsequent items are the parameters to
substitute for the placeholders in that fragment.

=cut

sub location_sql {
  my($class, %opt) = @_;
  my $ornull = $opt{'ornull'};

  my $conf = new FS::Conf;

  # '?' placeholders in _location_sql_where
  my $x = $ornull ? 3 : 2;
  my @bill_param = ( 
    ('district')x3,
    ('city')x3, 
    ('county')x$x,
    ('state')x$x,
    'country'
  );

  my $main_where;
  my @main_param;
  if ( $conf->exists('tax-ship_address') ) {

    $main_where = "(
         (     ( ship_last IS NULL     OR  ship_last  = '' )
           AND ". _location_sql_where('cust_main', '', $ornull ). "
         )
      OR (       ship_last IS NOT NULL AND ship_last != ''
           AND ". _location_sql_where('cust_main', 'ship_', $ornull ). "
         )
    )";
    #    AND payby != 'COMP'

    @main_param = ( @bill_param, @bill_param );

  } else {

    $main_where = _location_sql_where('cust_main'); # AND payby != 'COMP'
    @main_param = @bill_param;

  }

  my $where;
  my @param;
  if ( $conf->exists('tax-pkg_address') ) {

    my $loc_where = _location_sql_where( 'cust_location', '', $ornull );

    $where = " (
                    ( cust_pkg.locationnum IS     NULL AND $main_where )
                 OR ( cust_pkg.locationnum IS NOT NULL AND $loc_where  )
               )
             ";
    @param = ( @main_param, @bill_param );
  
  } else {

    $where = $main_where;
    @param = @main_param;

  }

  ( $where, @param );

}

#subroutine, helper for location_sql
sub _location_sql_where {
  my $table  = shift;
  my $prefix = @_ ? shift : '';
  my $ornull = @_ ? shift : '';

#  $ornull             = $ornull          ? " OR ( ? IS NULL AND $table.${prefix}county IS NULL ) " : '';

  $ornull = $ornull ? ' OR ? IS NULL ' : '';

  my $or_empty_city     = " OR ( ? = '' AND $table.${prefix}city     IS NULL )";
  my $or_empty_county   = " OR ( ? = '' AND $table.${prefix}county   IS NULL )";
  my $or_empty_state    = " OR ( ? = '' AND $table.${prefix}state    IS NULL )";

  my $text = (driver_name =~ /^mysql/i) ? 'char' : 'text';

#        ( $table.${prefix}city    = ? $or_empty_city   $ornull )
  "
        ( $table.district = ? OR ? = '' OR CAST(? AS $text) IS NULL )
    AND ( $table.${prefix}city     = ? OR ? = '' OR CAST(? AS $text) IS NULL )
    AND ( $table.${prefix}county   = ? $or_empty_county $ornull )
    AND ( $table.${prefix}state    = ? $or_empty_state  $ornull )
    AND   $table.${prefix}country  = ?
  ";
}

sub _X_show_zero {
  my( $self, $what ) = @_;

  my $what_show_zero = $what. '_show_zero';
  length($self->$what_show_zero())
    ? ($self->$what_show_zero() eq 'Y')
    : $self->part_pkg->$what_show_zero();
}

=head1 SUBROUTINES

=over 4

=item order CUSTNUM, PKGPARTS_ARYREF, [ REMOVE_PKGNUMS_ARYREF [ RETURN_CUST_PKG_ARRAYREF [ REFNUM ] ] ]

Bulk cancel + order subroutine.  Perhaps slightly deprecated, only used by the
bulk cancel+order in the web UI and nowhere else (edit/process/cust_pkg.cgi)

CUSTNUM is a customer (see L<FS::cust_main>)

PKGPARTS is a list of pkgparts specifying the the billing item definitions (see
L<FS::part_pkg>) to order for this customer.  Duplicates are of course
permitted.

REMOVE_PKGNUMS is an optional list of pkgnums specifying the billing items to
remove for this customer.  The services (see L<FS::cust_svc>) are moved to the
new billing items.  An error is returned if this is not possible (see
L<FS::pkg_svc>).  An empty arrayref is equivalent to not specifying this
parameter.

RETURN_CUST_PKG_ARRAYREF, if specified, will be filled in with the
newly-created cust_pkg objects.

REFNUM, if specified, will specify the FS::pkg_referral record to be created
and inserted.  Multiple FS::pkg_referral records can be created by
setting I<refnum> to an array reference of refnums or a hash reference with
refnums as keys.  If no I<refnum> is defined, a default FS::pkg_referral
record will be created corresponding to cust_main.refnum.

=cut

sub order {
  my ($custnum, $pkgparts, $remove_pkgnum, $return_cust_pkg, $refnum) = @_;

  my $conf = new FS::Conf;

  # Transactionize this whole mess
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error;
#  my $cust_main = qsearchs('cust_main', { custnum => $custnum });
#  return "Customer not found: $custnum" unless $cust_main;

  warn "$me order: pkgnums to remove: ". join(',', @$remove_pkgnum). "\n"
    if $DEBUG;

  my @old_cust_pkg = map { qsearchs('cust_pkg', { pkgnum => $_ }) }
                         @$remove_pkgnum;

  my $change = scalar(@old_cust_pkg) != 0;

  my %hash = (); 
  if ( scalar(@old_cust_pkg) == 1 && scalar(@$pkgparts) == 1 ) {

    warn "$me order: changing pkgnum ". $old_cust_pkg[0]->pkgnum.
         " to pkgpart ". $pkgparts->[0]. "\n"
      if $DEBUG;

    my $err_or_cust_pkg =
      $old_cust_pkg[0]->change( 'pkgpart' => $pkgparts->[0],
                                'refnum'  => $refnum,
                              );

    unless (ref($err_or_cust_pkg)) {
      $dbh->rollback if $oldAutoCommit;
      return $err_or_cust_pkg;
    }

    push @$return_cust_pkg, $err_or_cust_pkg;
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return '';

  }

  # Create the new packages.
  foreach my $pkgpart (@$pkgparts) {

    warn "$me order: inserting pkgpart $pkgpart\n" if $DEBUG;

    my $cust_pkg = new FS::cust_pkg { custnum => $custnum,
                                      pkgpart => $pkgpart,
                                      refnum  => $refnum,
                                      %hash,
                                    };
    $error = $cust_pkg->insert( 'change' => $change );
    push @$return_cust_pkg, $cust_pkg;

    foreach my $link ($cust_pkg->part_pkg->supp_part_pkg_link) {
      my $supp_pkg = FS::cust_pkg->new({
          custnum => $custnum,
          pkgpart => $link->dst_pkgpart,
          refnum  => $refnum,
          main_pkgnum => $cust_pkg->pkgnum,
          %hash,
      });
      $error ||= $supp_pkg->insert( 'change' => $change );
      push @$return_cust_pkg, $supp_pkg;
    }

    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }
  # $return_cust_pkg now contains refs to all of the newly 
  # created packages.

  # Transfer services and cancel old packages.
  foreach my $old_pkg (@old_cust_pkg) {

    warn "$me order: transferring services from pkgnum ". $old_pkg->pkgnum. "\n"
      if $DEBUG;

    foreach my $new_pkg (@$return_cust_pkg) {
      $error = $old_pkg->transfer($new_pkg);
      if ($error and $error == 0) {
        # $old_pkg->transfer failed.
	$dbh->rollback if $oldAutoCommit;
	return $error;
      }
    }

    if ( $error > 0 && $conf->exists('cust_pkg-change_svcpart') ) {
      warn "trying transfer again with change_svcpart option\n" if $DEBUG;
      foreach my $new_pkg (@$return_cust_pkg) {
        $error = $old_pkg->transfer($new_pkg, 'change_svcpart'=>1 );
        if ($error and $error == 0) {
          # $old_pkg->transfer failed.
  	$dbh->rollback if $oldAutoCommit;
  	return $error;
        }
      }
    }

    if ($error > 0) {
      # Transfers were successful, but we went through all of the 
      # new packages and still had services left on the old package.
      # We can't cancel the package under the circumstances, so abort.
      $dbh->rollback if $oldAutoCommit;
      return "Unable to transfer all services from package ".$old_pkg->pkgnum;
    }
    $error = $old_pkg->cancel( quiet=>1, 'no_delay_cancel'=>1 );
    if ($error) {
      $dbh->rollback;
      return $error;
    }
  }
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item bulk_change PKGPARTS_ARYREF, REMOVE_PKGNUMS_ARYREF [ RETURN_CUST_PKG_ARRAYREF ]

A bulk change method to change packages for multiple customers.

PKGPARTS is a list of pkgparts specifying the the billing item definitions (see
L<FS::part_pkg>) to order for each customer.  Duplicates are of course
permitted.

REMOVE_PKGNUMS is an list of pkgnums specifying the billing items to
replace.  The services (see L<FS::cust_svc>) are moved to the
new billing items.  An error is returned if this is not possible (see
L<FS::pkg_svc>).

RETURN_CUST_PKG_ARRAYREF, if specified, will be filled in with the
newly-created cust_pkg objects.

=cut

sub bulk_change {
  my ($pkgparts, $remove_pkgnum, $return_cust_pkg) = @_;

  # Transactionize this whole mess
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my @errors;
  my @old_cust_pkg = map { qsearchs('cust_pkg', { pkgnum => $_ }) }
                         @$remove_pkgnum;

  while(scalar(@old_cust_pkg)) {
    my @return = ();
    my $custnum = $old_cust_pkg[0]->custnum;
    my (@remove) = map { $_->pkgnum }
                   grep { $_->custnum == $custnum } @old_cust_pkg;
    @old_cust_pkg = grep { $_->custnum != $custnum } @old_cust_pkg;

    my $error = order $custnum, $pkgparts, \@remove, \@return;

    push @errors, $error
      if $error;
    push @$return_cust_pkg, @return;
  }

  if (scalar(@errors)) {
    $dbh->rollback if $oldAutoCommit;
    return join(' / ', @errors);
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

# Used by FS::Upgrade to migrate to a new database.
sub _upgrade_data {  # class method
  my ($class, %opts) = @_;
  $class->_upgrade_otaker(%opts);
  my @statements = (
    # RT#10139, bug resulting in contract_end being set when it shouldn't
  'UPDATE cust_pkg SET contract_end = NULL WHERE contract_end = -1',
    # RT#10830, bad calculation of prorate date near end of year
    # the date range for bill is December 2009, and we move it forward
    # one year if it's before the previous bill date (which it should 
    # never be)
  'UPDATE cust_pkg SET bill = bill + (365*24*60*60) WHERE bill < last_bill
  AND bill > 1259654400 AND bill < 1262332800 AND (SELECT plan FROM part_pkg 
  WHERE part_pkg.pkgpart = cust_pkg.pkgpart) = \'prorate\'',
    # RT6628, add order_date to cust_pkg
    'update cust_pkg set order_date = (select history_date from h_cust_pkg 
	where h_cust_pkg.pkgnum = cust_pkg.pkgnum and 
	history_action = \'insert\') where order_date is null',
  );
  foreach my $sql (@statements) {
    my $sth = dbh->prepare($sql);
    $sth->execute or die $sth->errstr;
  }

  # RT31194: supplemental package links that are deleted don't clean up 
  # linked records
  my @pkglinknums = qsearch({
      'select'    => 'DISTINCT cust_pkg.pkglinknum',
      'table'     => 'cust_pkg',
      'addl_from' => ' LEFT JOIN part_pkg_link USING (pkglinknum) ',
      'extra_sql' => ' WHERE cust_pkg.pkglinknum IS NOT NULL 
                        AND part_pkg_link.pkglinknum IS NULL',
  });
  foreach (@pkglinknums) {
    my $pkglinknum = $_->pkglinknum;
    warn "cleaning part_pkg_link #$pkglinknum\n";
    my $part_pkg_link = FS::part_pkg_link->new({pkglinknum => $pkglinknum});
    my $error = $part_pkg_link->remove_linked;
    die $error if $error;
  }
}

=back

=head1 BUGS

sub order is not OO.  Perhaps it should be moved to FS::cust_main and made so?

In sub order, the @pkgparts array (passed by reference) is clobbered.

Also in sub order, no money is adjusted.  Once FS::part_pkg defines a standard
method to pass dates to the recur_prog expression, it should do so.

FS::svc_acct, FS::svc_domain, FS::svc_www, FS::svc_ip and FS::svc_forward are
loaded via 'use' at compile time, rather than via 'require' in sub { setup,
suspend, unsuspend, cancel } because they use %FS::UID::callback to load
configuration values.  Probably need a subroutine which decides what to do
based on whether or not we've fetched the user yet, rather than a hash.  See
FS::UID and the TODO.

Now that things are transactional should the check in the insert method be
moved to check ?

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::part_pkg>, L<FS::cust_svc>,
L<FS::pkg_svc>, schema.html from the base documentation

=cut

1;

