package FS::cust_pkg;

use strict;
use base qw( FS::otaker_Mixin FS::cust_main_Mixin FS::location_Mixin
             FS::m2m_Common FS::option_Common );
use vars qw($disable_agentcheck $DEBUG $me);
use Carp qw(cluck);
use Scalar::Util qw( blessed );
use List::Util qw(max);
use Tie::IxHash;
use Time::Local qw( timelocal timelocal_nocheck );
use MIME::Entity;
use FS::UID qw( getotaker dbh );
use FS::Misc qw( send_email );
use FS::Record qw( qsearch qsearchs fields );
use FS::CurrentUser;
use FS::cust_svc;
use FS::part_pkg;
use FS::cust_main;
use FS::cust_location;
use FS::pkg_svc;
use FS::cust_bill_pkg;
use FS::cust_pkg_detail;
use FS::cust_event;
use FS::h_cust_svc;
use FS::reg_code;
use FS::part_svc;
use FS::cust_pkg_reason;
use FS::reason;
use FS::cust_pkg_discount;
use FS::discount;
use FS::UI::Web;
use Data::Dumper;

# need to 'use' these instead of 'require' in sub { cancel, suspend, unsuspend,
# setup }
# because they load configuration by setting FS::UID::callback (see TODO)
use FS::svc_acct;
use FS::svc_domain;
use FS::svc_www;
use FS::svc_forward;

# for sending cancel emails in sub cancel
use FS::Conf;

$DEBUG = 0;
$me = '[FS::cust_pkg]';

$disable_agentcheck = 0;

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
sub cust_linked { $_[0]->cust_main_custnum; } 
sub cust_unlinked_msg {
  my $self = shift;
  "WARNING: can't find cust_main.custnum ". $self->custnum.
  ' (cust_pkg.pkgnum '. $self->pkgnum. ')';
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

The following options are available:

=over 4

=item change

If set true, supresses any referral credit to a referring customer.

=item options

cust_pkg_option records will be created

=item ticket_subject

a ticket will be added to this customer with this subject

=item ticket_queue

an optional queue name for ticket additions

=back

=cut

sub insert {
  my( $self, %options ) = @_;

  my $error = $self->check_pkgpart;
  return $error if $error;

  my $part_pkg = $self->part_pkg;

  if ( $part_pkg->option('start_1st', 1) && !$self->start_date ) {
    my ($sec,$min,$hour,$mday,$mon,$year) = (localtime(time) )[0,1,2,3,4,5];
    $mon += 1 unless $mday == 1;
    until ( $mon < 12 ) { $mon -= 12; $year++; }
    $self->start_date( timelocal_nocheck(0,0,0,1,$mon,$year) );
  }

  foreach my $action ( qw(expire adjourn contract_end) ) {
    my $months = $part_pkg->option("${action}_months",1);
    if($months and !$self->$action) {
      my $start = $self->start_date || $self->setup || time;
      $self->$action( $part_pkg->add_freq($start, $months) );
    }
  }

  my $free_days = $part_pkg->option('free_days',1);
  if ( $free_days && $part_pkg->option('delay_setup',1) ) { #&& !$self->start_date
    my ($mday,$mon,$year) = (localtime(time) )[3,4,5];
    #my $start_date = ($self->start_date || timelocal(0,0,0,$mday,$mon,$year)) + 86400 * $free_days;
    my $start_date = timelocal(0,0,0,$mday,$mon,$year) + 86400 * $free_days;
    $self->start_date($start_date);
  }

  $self->order_date(time);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

  if ( $self->discountnum ) {
    my $error = $self->insert_discount();
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  #if ( $self->reg_code ) {
  #  my $reg_code = qsearchs('reg_code', { 'code' => $self->reg_code } );
  #  $error = $reg_code->delete;
  #  if ( $error ) {
  #    $dbh->rollback if $oldAutoCommit;
  #    return $error;
  #  }
  #}

  my $conf = new FS::Conf;

  if ( $conf->config('ticket_system') && $options{ticket_subject} ) {

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

  if ($conf->config('welcome_letter') && $self->cust_main->num_pkgs == 1) {
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

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

  my $error = $new->SUPER::replace($old,
                                   $options->{options} ? $options->{options} : ()
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

  $self->locationnum('') if !$self->locationnum || $self->locationnum == -1;

  my $error = 
    $self->ut_numbern('pkgnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_numbern('pkgpart')
    || $self->check_pkgpart
    || $self->ut_foreign_keyn('locationnum', 'cust_location', 'locationnum')
    || $self->ut_numbern('start_date')
    || $self->ut_numbern('setup')
    || $self->ut_numbern('bill')
    || $self->ut_numbern('susp')
    || $self->ut_numbern('cancel')
    || $self->ut_numbern('adjourn')
    || $self->ut_numbern('resume')
    || $self->ut_numbern('expire')
    || $self->ut_numbern('dundate')
    || $self->ut_enum('no_auto', [ '', 'Y' ])
    || $self->ut_enum('waive_setup', [ '', 'Y' ])
    || $self->ut_numbern('agent_pkgid')
    || $self->ut_enum('recur_show_zero', [ '', 'Y', 'N', ])
    || $self->ut_enum('setup_show_zero', [ '', 'Y', 'N', ])
  ;
  return $error if $error;

  return "A package with both start date (future start) and setup date (already started) will never bill"
    if $self->start_date && $self->setup;

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

=cut

sub check_pkgpart {
  my $self = shift;

  my $error = $self->ut_numbern('pkgpart');
  return $error if $error;

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

=item time -  can be set to cancel the package based on a specific future or historical date.  Using time ensures that the remaining amount is calculated correctly.  Note however that this is an immediate cancel and just changes the date.  You are PROBABLY looking to expire the account instead of using this.

=item reason - can be set to a cancellation reason (see L<FS:reason>), either a reasonnum of an existing reason, or passing a hashref will create a new reason.  The hashref should have the following keys: typenum - Reason type (see L<FS::reason_type>, reason - Text of the new reason.

=item date - can be set to a unix style timestamp to specify when to cancel (expire)

=item nobill - can be set true to skip billing if it might otherwise be done.

=item unused_credit - can be set to 1 to credit the remaining time, or 0 to 
not credit it.  This must be set (by change()) when changing the package 
to a different pkgpart or location, and probably shouldn't be in any other 
case.  If it's not set, the 'unused_credit_cancel' part_pkg option will 
be used.

=back

If there is an error, returns the error, otherwise returns false.

=cut

sub cancel {
  my( $self, %options ) = @_;
  my $error;

  my $conf = new FS::Conf;

  warn "cust_pkg::cancel called with options".
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
  
  my $old = $self->select_for_update;

  if ( $old->get('cancel') || $self->get('cancel') ) {
    dbh->rollback if $oldAutoCommit;
    return "";  # no error
  }

  my $date = $options{date} if $options{date}; # expire/cancel later
  $date = '' if ($date && $date <= time);      # complain instead?

  #race condition: usage could be ongoing until unprovisioned
  #resolved by performing a change package instead (which unprovisions) and
  #later cancelling
  if ( !$options{nobill} && !$date && $conf->exists('bill_usage_on_cancel') ) {
      my $copy = $self->new({$self->hash});
      my $error =
        $copy->cust_main->bill( pkg_list => [ $copy ], cancel => 1 );
      warn "Error billing during cancel, custnum ".
        #$self->cust_main->custnum. ": $error"
        ": $error"
        if $error;
  }

  my $cancel_time = $options{'time'} || time;

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

    # Add a credit for remaining service
    my $last_bill = $self->getfield('last_bill') || 0;
    my $next_bill = $self->getfield('bill') || 0;
    my $do_credit;
    if ( exists($options{'unused_credit'}) ) {
      $do_credit = $options{'unused_credit'};
    }
    else {
      $do_credit = $self->part_pkg->option('unused_credit_cancel', 1);
    }
    if ( $do_credit
          and $last_bill > 0 # the package has been billed
          and $next_bill > 0 # the package has a next bill date
          and $next_bill >= $cancel_time # which is in the future
    ) {
      my $remaining_value = $self->calc_remain('time' => $cancel_time);
      if ( $remaining_value > 0 ) {
        my $error = $self->cust_main->credit(
          $remaining_value,
          'Credit for unused time on '. $self->part_pkg->pkg,
          'reason_type' => $conf->config('cancel_credit_type'),
        );
        if ($error) {
          $dbh->rollback if $oldAutoCommit;
          return "Error crediting customer \$$remaining_value for unused time".
                 " on ". $self->part_pkg->pkg. ": $error";
        }
      } #if $remaining_value
    } #if $do_credit

  } #unless $date

  my %hash = $self->hash;
  $date ? ($hash{'expire'} = $date) : ($hash{'cancel'} = $cancel_time);
  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options } );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
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
        'from'    => $conf->config('invoice_from', $self->cust_main->agentnum),
        'to'      => \@invoicing_list,
        'subject' => ( $conf->config('cancelsubject') || 'Cancellation Notice' ),
        'body'    => [ map "$_\n", $conf->config('cancelmessage') ],
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

cust_pkg: pass a scalar reference, will be filled in with

svc_errors: pass an array reference, will be filled in with any provisioning errors

=cut

sub uncancel {
  my( $self, %options ) = @_;

  #in case you try do do $uncancel-date = $cust_pkg->uncacel 
  return '' unless $self->get('cancel');

  ##
  # Transaction-alize
  ##

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE'; 
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE'; 
  local $SIG{PIPE} = 'IGNORE'; 

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
    map { $_ => $self->get($_) } qw(
      custnum pkgpart locationnum
      setup
      susp adjourn resume expire start_date contract_end dundate
      change_date change_pkgpart change_locationnum
      manual_flag no_auto quantity agent_pkgid recur_show_zero setup_show_zero
    ),
  };

  my $error = $cust_pkg->insert(
    'change' => 1, #supresses any referral credit to a referring customer
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
    if ( $svc_error ) { #&& $options{svc_fatal} ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    push @svc_errors, $svc_error if $svc_error;
  }

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

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

=back

If there is an error, returns the error, otherwise returns false.

=cut

sub suspend {
  my( $self, %options ) = @_;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options } );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  unless ( $date ) {

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

    my $conf = new FS::Conf;
    if ( $conf->config('suspend_email_admin') ) {
 
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
      );

      if ( $error ) {
        warn "WARNING: can't send suspension admin email (suspending anyway): ".
             "$error\n";
      }

    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors
}

=item unsuspend [ OPTION => VALUE ... ]

Unsuspends all services (see L<FS::cust_svc> and L<FS::part_svc>) in this
package, then unsuspends the package itself (clears the susp field and the
adjourn field if it is in the past).

Available options are:

=over 4

=item date

Can be set to a date to unsuspend the package in the future (the 'resume' 
field).

=item adjust_next_bill

Can be set true to adjust the next bill date forward by
the amount of time the account was inactive.  This was set true by default
since 1.4.2 and 1.5.0pre6; however, starting with 1.7.0 this needs to be
explicitly requested.  Price plans for which this makes sense (anniversary-date
based than prorate or subscription) could have an option to enable this
behaviour?

=back

If there is an error, returns the error, otherwise returns false.

=cut

sub unsuspend {
  my( $self, %opt ) = @_;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

  my %hash = $self->hash;
  my $inactive = time - $hash{'susp'};

  my $conf = new FS::Conf;

  if ( $inactive > 0 && 
       ( $hash{'bill'} || $hash{'setup'} ) &&
       ( $opt{'adjust_next_bill'} ||
         $conf->exists('unsuspend-always_adjust_next_bill_date') ||
         $self->part_pkg->option('unsuspend_adjust_bill', 1) )
     ) {

    $hash{'bill'} = ( $hash{'bill'} || $hash{'setup'} ) + $inactive;
  
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
      ],
    );

    if ( $error ) {
      warn "WARNING: can't send unsuspension admin email (unsuspending anyway): ".
           "$error\n";
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

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

=item pkgpart

New pkgpart (see L<FS::part_pkg>).

=item refnum

New refnum (see L<FS::part_referral>).

=item keep_dates

Set to true to transfer billing dates (start_date, setup, last_bill, bill, 
susp, adjourn, cancel, expire, and contract_end) to the new package.

=back

At least one of locationnum, cust_location, pkgpart, refnum must be specified 
(otherwise, what's the point?)

Returns either the new FS::cust_pkg object or a scalar error.

For example:

  my $err_or_new_cust_pkg = $old_cust_pkg->change

=cut

#some false laziness w/order
sub change {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };

#  my ($custnum, $pkgparts, $remove_pkgnum, $return_cust_pkg, $refnum) = @_;
#    

  my $conf = new FS::Conf;

  # Transactionize this whole mess
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE'; 
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE'; 
  local $SIG{PIPE} = 'IGNORE'; 

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error;

  my %hash = (); 

  my $time = time;

  #$hash{$_} = $self->$_() foreach qw( last_bill bill );
    
  #$hash{$_} = $self->$_() foreach qw( setup );

  $hash{'setup'} = $time if $self->setup;

  $hash{'change_date'} = $time;
  $hash{"change_$_"}  = $self->$_()
    foreach qw( pkgnum pkgpart locationnum );

  if ( $opt->{'cust_location'} &&
       ( ! $opt->{'locationnum'} || $opt->{'locationnum'} == -1 ) ) {
    $error = $opt->{'cust_location'}->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "inserting cust_location (transaction rolled back): $error";
    }
    $opt->{'locationnum'} = $opt->{'cust_location'}->locationnum;
  }

  my $unused_credit = 0;
  if ( $opt->{'keep_dates'} ) {
    foreach my $date ( qw(setup bill last_bill susp adjourn cancel expire 
                          resume start_date contract_end ) ) {
      $hash{$date} = $self->getfield($date);
    }
  }
  # Special case.  If the pkgpart is changing, and the customer is
  # going to be credited for remaining time, don't keep setup, bill, 
  # or last_bill dates, and DO pass the flag to cancel() to credit 
  # the customer.
  if ( $opt->{'pkgpart'} 
      and $opt->{'pkgpart'} != $self->pkgpart
      and $self->part_pkg->option('unused_credit_change', 1) ) {
    $unused_credit = 1;
    $hash{$_} = '' foreach qw(setup bill last_bill);
  }

  # allow $opt->{'locationnum'} = '' to specifically set it to null
  # (i.e. customer default location)
  $opt->{'locationnum'} = $self->locationnum if !exists($opt->{'locationnum'});

  # Create the new package.
  my $cust_pkg = new FS::cust_pkg {
    custnum      => $self->custnum,
    pkgpart      => ( $opt->{'pkgpart'}     || $self->pkgpart      ),
    refnum       => ( $opt->{'refnum'}      || $self->refnum       ),
    locationnum  => ( $opt->{'locationnum'}                        ),
    %hash,
  };

  $error = $cust_pkg->insert( 'change' => 1 );
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  # Transfer services and cancel old package.

  $error = $self->transfer($cust_pkg);
  if ($error and $error == 0) {
    # $old_pkg->transfer failed.
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $error > 0 && $conf->exists('cust_pkg-change_svcpart') ) {
    warn "trying transfer again with change_svcpart option\n" if $DEBUG;
    $error = $self->transfer($cust_pkg, 'change_svcpart'=>1 );
    if ($error and $error == 0) {
      # $old_pkg->transfer failed.
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ($error > 0) {
    # Transfers were successful, but we still had services left on the old
    # package.  We can't change the package under this circumstances, so abort.
    $dbh->rollback if $oldAutoCommit;
    return "Unable to transfer all services from package ". $self->pkgnum;
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
      return "Error setting usage values: $error";
    }
  }

  #Good to go, cancel old package.  Notify 'cancel' of whether to credit 
  #remaining time.
  $error = $self->cancel( quiet=>1, unused_credit => $unused_credit );
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $conf->exists('cust_pkg-change_pkgpart-bill_now') ) {
    #$self->cust_main
    my $error = $cust_pkg->cust_main->bill( 'pkg_list' => [ $cust_pkg ] );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  $cust_pkg;

}

use Storable 'thaw';
use MIME::Base64;
sub process_bulk_cust_pkg {
  my $job = shift;
  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;

  my $old_part_pkg = qsearchs('part_pkg', 
                              { pkgpart => $param->{'old_pkgpart'} });
  my $new_part_pkg = qsearchs('part_pkg',
                              { pkgpart => $param->{'new_pkgpart'} });
  die "Must select a new package type\n" unless $new_part_pkg;
  #my $keep_dates = $param->{'keep_dates'} || 0;
  my $keep_dates = 1; # there is no good reason to turn this off

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

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

Returns the new-style customer billing events (see L<FS::cust_event>) for this invoice.

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

Returns the number of new-style customer billing events (see L<FS::cust_event>) for this invoice.

=cut

#false laziness w/cust_bill.pm
sub num_cust_event {
  my $self = shift;
  my $sql =
    "SELECT COUNT(*) FROM cust_event JOIN part_event USING ( eventpart ) ".
    "  WHERE tablenum = ? AND eventtable = 'cust_pkg'";
  my $sth = dbh->prepare($sql) or die  dbh->errstr. " preparing $sql"; 
  $sth->execute($self->pkgnum) or die $sth->errstr. " executing $sql";
  $sth->fetchrow_arrayref->[0];
}

=item cust_svc [ SVCPART ] (old, deprecated usage)

=item cust_svc [ OPTION => VALUE ... ] (current usage)

Returns the services for this package, as FS::cust_svc objects (see
L<FS::cust_svc>).  Available options are svcpart and svcdb.  If either is
spcififed, returns only the matching services.

=cut

sub cust_svc {
  my $self = shift;

  return () unless $self->num_cust_svc(@_);

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
    $search{hashref}->{svcdb} = $opt{'svcdb'};
  }

  cluck "cust_pkg->cust_svc called" if $DEBUG > 2;

  #if ( $self->{'_svcnum'} ) {
  #  values %{ $self->{'_svcnum'}->cache };
  #} else {
    $self->_sort_cust_svc( [ qsearch(\%search) ] );
  #}

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

  map  { $_->[0] }
  sort $sort
  map {
        my $pkg_svc = qsearchs( 'pkg_svc', { 'pkgpart' => $self->pkgpart,
                                             'svcpart' => $_->svcpart     } );
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
  grep { $_->num_avail > 0 }
    map {
          my $part_svc = $_->part_svc;
          $part_svc->{'Hash'}{'num_avail'} = #evil encapsulation-breaking
            $_->quantity - $self->num_cust_svc($_->svcpart);

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

=item num_cust_svc  (count)

=item num_avail     (quantity - count)

=item cust_pkg_svc (services) - array reference containing the provisioned services, as cust_svc objects

=back

Accepts one option: summarize_size.  If specified and non-zero, will omit the
extra cust_pkg_svc option for objects where num_cust_svc is this size or
greater.

=cut

#svcnum
#label -> ($cust_svc->label)[1]

sub part_svc {
  my $self = shift;
  my %opt = @_;

  #XXX some sort of sort order besides numeric by svcpart...
  my @part_svc = sort { $a->svcpart <=> $b->svcpart } map {
    my $pkg_svc = $_;
    my $part_svc = $pkg_svc->part_svc;
    my $num_cust_svc = $self->num_cust_svc($part_svc->svcpart);
    $part_svc->{'Hash'}{'num_cust_svc'} = $num_cust_svc; #more evil
    $part_svc->{'Hash'}{'num_avail'}    =
      max( 0, $pkg_svc->quantity - $num_cust_svc );
    $part_svc->{'Hash'}{'cust_pkg_svc'} =
        $num_cust_svc ? [ $self->cust_svc($part_svc->svcpart) ] : []
      unless exists($opt{summarize_size}) && $opt{summarize_size} > 0
          && $num_cust_svc >= $opt{summarize_size};
    $part_svc->{'Hash'}{'hidden'} = $pkg_svc->hidden;
    $part_svc;
  } $self->part_pkg->pkg_svc;

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
  'not yet billed'  => '009999', #teal? cyan?
  'one-time charge' => '000000',
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

=item statuscolor

Returns a hex triplet color string for this package's status.

=cut

sub statuscolor {
  my $self = shift;
  $statuscolor{$self->status};
}

=item pkg_label

Returns a label for this package.  (Currently "pkgnum: pkg - comment" or
"pkg-comment" depending on user preference).

=cut

sub pkg_label {
  my $self = shift;
  my $label = $self->part_pkg->pkg_comment( 'nopkgpart' => 1 );
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

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
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
        && scalar($part_svc->part_export('sqlradius'));
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
      $part_svc->svcdb eq 'svc_acct'
        && scalar($part_svc->part_export('sqlradius'));
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
    $target{$pkg_svc->svcpart} = $pkg_svc->quantity;
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

  foreach my $cust_svc ($self->cust_svc) {
    if($target{$cust_svc->svcpart} > 0) {
      $target{$cust_svc->svcpart}--;
      my $new = new FS::cust_svc { $cust_svc->hash };
      $new->pkgnum($dest_pkgnum);
      my $error = $new->replace($cust_svc);
      return $error if $error;
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
        my $error = $new->replace($cust_svc);
        return $error if $error;
      } else {
        $remaining++;
      }
    } else {
      $remaining++
    }
  }
  return $remaining;
}

=item reexport

This method is deprecated.  See the I<depend_jobnum> option to the insert and
order_pkgs methods in FS::cust_main for a better way to defer provisioning.

=cut

sub reexport {
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
    return "Unparsable reason: ". $options{'reason'};
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

=item cust_pkg_discount

=cut

sub cust_pkg_discount {
  my $self = shift;
  qsearch('cust_pkg_discount', { 'pkgnum' => $self->pkgnum } );
}

=item cust_pkg_discount_active

=cut

sub cust_pkg_discount_active {
  my $self = shift;
  grep { $_->status eq 'active' } $self->cust_pkg_discount;
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
  WHEN cust_pkg.susp IS NOT NULL THEN 'suspended'
  WHEN cust_pkg.setup IS NULL THEN 'not yet billed'
  WHEN ".onetime_sql()." THEN 'one-time charge'
  ELSE 'active'
END"
}

=item search HASHREF

(Class method)

Returns a qsearch hash expression to search for parameters specified in HASHREF.
Valid parameters are

=over 4

=item agentnum

=item magic

active, inactive, suspended, cancel (or cancelled)

=item status

active, inactive, suspended, one-time charge, inactive, cancel (or cancelled)

=item custom

 boolean selects custom packages

=item classnum

=item pkgpart

pkgpart or arrayref or hashref of pkgparts

=item setup

arrayref of beginning and ending epoch date

=item last_bill

arrayref of beginning and ending epoch date

=item bill

arrayref of beginning and ending epoch date

=item adjourn

arrayref of beginning and ending epoch date

=item susp

arrayref of beginning and ending epoch date

=item expire

arrayref of beginning and ending epoch date

=item cancel

arrayref of beginning and ending epoch date

=item query

pkgnum or APKG_pkgnum

=item cust_fields

a value suited to passing to FS::UI::Web::cust_header

=item CurrentUser

specifies the user for agent virtualization

=item fcc_line

 boolean selects packages containing fcc form 477 telco lines

=back

=cut

sub search {
  my ($class, $params) = @_;
  my @where = ();

  ##
  # parse agent
  ##

  if ( $params->{'agentnum'} =~ /^(\d+)$/ and $1 ) {
    push @where,
      "cust_main.agentnum = $1";
  }

  ##
  # parse custnum
  ##

  if ( $params->{'custnum'} =~ /^(\d+)$/ and $1 ) {
    push @where,
      "cust_pkg.custnum = $1";
  }

  ##
  # custbatch
  ##

  if ( $params->{'pkgbatch'} =~ /^([\w\/\-\:\.]+)$/ and $1 ) {
    push @where,
      "cust_pkg.pkgbatch = '$1'";
  }

  ##
  # parse status
  ##

  if (    $params->{'magic'}  eq 'active'
       || $params->{'status'} eq 'active' ) {

    push @where, FS::cust_pkg->active_sql();

  } elsif (    $params->{'magic'}  =~ /^not[ _]yet[ _]billed$/
            || $params->{'status'} =~ /^not[ _]yet[ _]billed$/ ) {

    push @where, FS::cust_pkg->not_yet_billed_sql();

  } elsif (    $params->{'magic'}  =~ /^(one-time charge|inactive)/
            || $params->{'status'} =~ /^(one-time charge|inactive)/ ) {

    push @where, FS::cust_pkg->inactive_sql();

  } elsif (    $params->{'magic'}  eq 'suspended'
            || $params->{'status'} eq 'suspended'  ) {

    push @where, FS::cust_pkg->suspended_sql();

  } elsif (    $params->{'magic'}  =~ /^cancell?ed$/
            || $params->{'status'} =~ /^cancell?ed$/ ) {

    push @where, FS::cust_pkg->cancelled_sql();

  }

  ###
  # parse package class
  ###

  if ( exists($params->{'classnum'}) ) {

    my @classnum = ();
    if ( ref($params->{'classnum'}) ) {

      if ( ref($params->{'classnum'}) eq 'HASH' ) {
        @classnum = grep $params->{'classnum'}{$_}, keys %{ $params->{'classnum'} };
      } elsif ( ref($params->{'classnum'}) eq 'ARRAY' ) {
        @classnum = @{ $params->{'classnum'} };
      } else {
        die 'unhandled classnum ref '. $params->{'classnum'};
      }


    } elsif ( $params->{'classnum'} =~ /^(\d*)$/ && $1 ne '0' ) {
      @classnum = ( $1 );
    }

    if ( @classnum ) {

      my @c_where = ();
      my @nums = grep $_, @classnum;
      push @c_where, 'part_pkg.classnum IN ('. join(',',@nums). ')' if @nums;
      my $null = scalar( grep { $_ eq '' } @classnum );
      push @c_where, 'part_pkg.classnum IS NULL' if $null;

      if ( scalar(@c_where) == 1 ) {
        push @where, @c_where;
      } elsif ( @c_where ) {
        push @where, ' ( '. join(' OR ', @c_where). ' ) ';
      }

    }
    

  }

  ###
  # parse package report options
  ###

  my @report_option = ();
  if ( exists($params->{'report_option'}) ) {
    if ( ref($params->{'report_option'}) eq 'ARRAY' ) {
      @report_option = @{ $params->{'report_option'} };
    } elsif ( $params->{'report_option'} =~ /^([,\d]*)$/ ) {
      @report_option = split(',', $1);
    }

  }

  if (@report_option) {
    # this will result in the empty set for the dangling comma case as it should
    push @where, 
      map{ "0 < ( SELECT count(*) FROM part_pkg_option
                    WHERE part_pkg_option.pkgpart = part_pkg.pkgpart
                    AND optionname = 'report_option_$_'
                    AND optionvalue = '1' )"
         } @report_option;
  }

  foreach my $any ( grep /^report_option_any/, keys %$params ) {

    my @report_option_any = ();
    if ( ref($params->{$any}) eq 'ARRAY' ) {
      @report_option_any = @{ $params->{$any} };
    } elsif ( $params->{$any} =~ /^([,\d]*)$/ ) {
      @report_option_any = split(',', $1);
    }

    if (@report_option_any) {
      # this will result in the empty set for the dangling comma case as it should
      push @where, ' ( '. join(' OR ',
        map{ "0 < ( SELECT count(*) FROM part_pkg_option
                      WHERE part_pkg_option.pkgpart = part_pkg.pkgpart
                      AND optionname = 'report_option_$_'
                      AND optionvalue = '1' )"
           } @report_option_any
      ). ' ) ';
    }

  }

  ###
  # parse custom
  ###

  push @where,  "part_pkg.custom = 'Y'" if $params->{custom};

  ###
  # parse fcc_line
  ###

  push @where,  "(part_pkg.fcc_ds0s > 0 OR pkg_class.fcc_ds0s > 0)" 
                                                        if $params->{fcc_line};

  ###
  # parse censustract
  ###

  if ( exists($params->{'censustract'}) ) {
    $params->{'censustract'} =~ /^([.\d]*)$/;
    my $censustract = "cust_main.censustract = '$1'";
    $censustract .= ' OR cust_main.censustract is NULL' unless $1;
    push @where,  "( $censustract )";
  }

  ###
  # parse censustract2
  ###
  if ( exists($params->{'censustract2'})
       && $params->{'censustract2'} =~ /^(\d*)$/
     )
  {
    if ($1) {
      push @where, "cust_main.censustract LIKE '$1%'";
    } else {
      push @where,
        "( cust_main.censustract = '' OR cust_main.censustract IS NULL )";
    }
  }

  ###
  # parse part_pkg
  ###

  if ( ref($params->{'pkgpart'}) ) {

    my @pkgpart = ();
    if ( ref($params->{'pkgpart'}) eq 'HASH' ) {
      @pkgpart = grep $params->{'pkgpart'}{$_}, keys %{ $params->{'pkgpart'} };
    } elsif ( ref($params->{'pkgpart'}) eq 'ARRAY' ) {
      @pkgpart = @{ $params->{'pkgpart'} };
    } else {
      die 'unhandled pkgpart ref '. $params->{'pkgpart'};
    }

    @pkgpart = grep /^(\d+)$/, @pkgpart;

    push @where, 'pkgpart IN ('. join(',', @pkgpart). ')' if scalar(@pkgpart);

  } elsif ( $params->{'pkgpart'} =~ /^(\d+)$/ ) {
    push @where, "pkgpart = $1";
  } 

  ###
  # parse dates
  ###

  my $orderby = '';

  #false laziness w/report_cust_pkg.html
  my %disable = (
    'all'             => {},
    'one-time charge' => { 'last_bill'=>1, 'bill'=>1, 'adjourn'=>1, 'susp'=>1, 'expire'=>1, 'cancel'=>1, },
    'active'          => { 'susp'=>1, 'cancel'=>1 },
    'suspended'       => { 'cancel' => 1 },
    'cancelled'       => {},
    ''                => {},
  );

  if( exists($params->{'active'} ) ) {
    # This overrides all the other date-related fields
    my($beginning, $ending) = @{$params->{'active'}};
    push @where,
      "cust_pkg.setup IS NOT NULL",
      "cust_pkg.setup <= $ending",
      "(cust_pkg.cancel IS NULL OR cust_pkg.cancel >= $beginning )",
      "NOT (".FS::cust_pkg->onetime_sql . ")";
  }
  else {
    foreach my $field (qw( setup last_bill bill adjourn susp expire contract_end change_date cancel )) {

      next unless exists($params->{$field});

      my($beginning, $ending) = @{$params->{$field}};

      next if $beginning == 0 && $ending == 4294967295;

      push @where,
        "cust_pkg.$field IS NOT NULL",
        "cust_pkg.$field >= $beginning",
        "cust_pkg.$field <= $ending";

      $orderby ||= "ORDER BY cust_pkg.$field";

    }
  }

  $orderby ||= 'ORDER BY bill';

  ###
  # parse magic, legacy, etc.
  ###

  if ( $params->{'magic'} &&
       $params->{'magic'} =~ /^(active|inactive|suspended|cancell?ed)$/
  ) {

    $orderby = 'ORDER BY pkgnum';

    if ( $params->{'pkgpart'} =~ /^(\d+)$/ ) {
      push @where, "pkgpart = $1";
    }

  } elsif ( $params->{'query'} eq 'pkgnum' ) {

    $orderby = 'ORDER BY pkgnum';

  } elsif ( $params->{'query'} eq 'APKG_pkgnum' ) {

    $orderby = 'ORDER BY pkgnum';

    push @where, '0 < (
      SELECT count(*) FROM pkg_svc
       WHERE pkg_svc.pkgpart =  cust_pkg.pkgpart
         AND pkg_svc.quantity > ( SELECT count(*) FROM cust_svc
                                   WHERE cust_svc.pkgnum  = cust_pkg.pkgnum
                                     AND cust_svc.svcpart = pkg_svc.svcpart
                                )
    )';
  
  }

  ##
  # setup queries, links, subs, etc. for the search
  ##

  # here is the agent virtualization
  if ($params->{CurrentUser}) {
    my $access_user =
      qsearchs('access_user', { username => $params->{CurrentUser} });

    if ($access_user) {
      push @where, $access_user->agentnums_sql('table'=>'cust_main');
    } else {
      push @where, "1=0";
    }
  } else {
    push @where, $FS::CurrentUser::CurrentUser->agentnums_sql('table'=>'cust_main');
  }

  my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

  my $addl_from = 'LEFT JOIN cust_main USING ( custnum  ) '.
                  'LEFT JOIN part_pkg  USING ( pkgpart  ) '.
                  'LEFT JOIN pkg_class ON ( part_pkg.classnum = pkg_class.classnum ) ';

  my $count_query = "SELECT COUNT(*) FROM cust_pkg $addl_from $extra_sql";

  my $sql_query = {
    'table'       => 'cust_pkg',
    'hashref'     => {},
    'select'      => join(', ',
                                'cust_pkg.*',
                                ( map "part_pkg.$_", qw( pkg freq ) ),
                                'pkg_class.classname',
                                'cust_main.custnum AS cust_main_custnum',
                                FS::UI::Web::cust_sql_fields(
                                  $params->{'cust_fields'}
                                ),
                     ),
    'extra_sql'   => $extra_sql,
    'order_by'    => $orderby,
    'addl_from'   => $addl_from,
    'count_query' => $count_query,
  };

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

#        ( $table.${prefix}city    = ? $or_empty_city   $ornull )
  "
        ( $table.${prefix}district = ? OR ? = '' OR CAST(? AS text) IS NULL )
    AND ( $table.${prefix}city     = ? OR ? = '' OR CAST(? AS text) IS NULL )
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
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE'; 
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE'; 
  local $SIG{PIPE} = 'IGNORE'; 

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
    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    push @$return_cust_pkg, $cust_pkg;
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
    $error = $old_pkg->cancel( quiet=>1 );
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
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE'; 
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE'; 
  local $SIG{PIPE} = 'IGNORE'; 

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

