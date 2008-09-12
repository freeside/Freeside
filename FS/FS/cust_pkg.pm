package FS::cust_pkg;

use strict;
use vars qw(@ISA $disable_agentcheck $DEBUG);
use Scalar::Util qw( blessed );
use List::Util qw(max);
use Tie::IxHash;
use FS::UID qw( getotaker dbh );
use FS::Misc qw( send_email );
use FS::Record qw( qsearch qsearchs );
use FS::m2m_Common;
use FS::cust_main_Mixin;
use FS::cust_svc;
use FS::part_pkg;
use FS::cust_main;
use FS::type_pkgs;
use FS::pkg_svc;
use FS::cust_bill_pkg;
use FS::cust_pkg_detail;
use FS::cust_event;
use FS::h_cust_svc;
use FS::reg_code;
use FS::part_svc;
use FS::cust_pkg_reason;
use FS::reason;
use FS::UI::Web;

# need to 'use' these instead of 'require' in sub { cancel, suspend, unsuspend,
# setup }
# because they load configuration by setting FS::UID::callback (see TODO)
use FS::svc_acct;
use FS::svc_domain;
use FS::svc_www;
use FS::svc_forward;

# for sending cancel emails in sub cancel
use FS::Conf;

@ISA = qw( FS::m2m_Common FS::cust_main_Mixin FS::option_Common FS::Record );

$DEBUG = 0;

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

=item pkgnum - primary key (assigned automatically for new billing items)

=item custnum - Customer (see L<FS::cust_main>)

=item pkgpart - Billing item definition (see L<FS::part_pkg>)

=item setup - date

=item bill - date (next bill date)

=item last_bill - last bill date

=item adjourn - date

=item susp - date

=item expire - date

=item cancel - date

=item otaker - order taker (assigned automatically if null, see L<FS::UID>)

=item manual_flag - If this field is set to 1, disables the automatic
unsuspension of this package when using the B<unsuspendauto> config file.

=item quantity - If not set, defaults to 1

=back

Note: setup, bill, adjourn, susp, expire and cancel are specified as UNIX timestamps;
see L<perlfunc/"time">.  Also see L<Time::Local> and L<Date::Parse> for
conversion functions.

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

=back

=cut

sub insert {
  my( $self, %options ) = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert($options{options} ? %{$options{options}} : ());
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

  #if ( $self->reg_code ) {
  #  my $reg_code = qsearchs('reg_code', { 'code' => $self->reg_code } );
  #  $error = $reg_code->delete;
  #  if ( $error ) {
  #    $dbh->rollback if $oldAutoCommit;
  #    return $error;
  #  }
  #}

  my $conf = new FS::Conf;
  my $cust_main = $self->cust_main;
  my $part_pkg = $self->part_pkg;
  if ( $conf->exists('referral_credit')
       && $cust_main->referral_custnum
       && ! $options{'change'}
       && $part_pkg->freq !~ /^0\D?$/
     )
  {
    my $referring_cust_main = $cust_main->referring_cust_main;
    if ( $referring_cust_main->status ne 'cancelled' ) {
      my $error;
      if ( $part_pkg->freq !~ /^\d+$/ ) {
        warn 'WARNING: Not crediting customer '. $cust_main->referral_custnum.
             ' for package '. $self->pkgnum.
             ' ( customer '. $self->custnum. ')'.
             ' - One-time referral credits not (yet) available for '.
             ' packages with '. $part_pkg->freq_pretty. ' frequency';
      } else {

        my $amount = sprintf( "%.2f", $part_pkg->base_recur / $part_pkg->freq );
        my $error =
          $referring_cust_main->
            credit( $amount,
                    'Referral credit for '.$cust_main->name,
                    'reason_type' => $conf->config('referral_credit_type')
                  );
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return "Error crediting customer ". $cust_main->referral_custnum.
               " for referral: $error";
        }

      }

    }
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

You don't want to delete billing items, because there would then be no record
the customer ever purchased the item.  Instead, see the cancel method.

=cut

#sub delete {
#  return "Can't delete cust_pkg records!";
#}

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
  return "Can't change otaker!" if $old->otaker ne $new->otaker;

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
    my $s_error = $new_svc_acct->replace($old_svc_acct);
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

  my $error = 
    $self->ut_numbern('pkgnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_numbern('pkgpart')
    || $self->ut_numbern('setup')
    || $self->ut_numbern('bill')
    || $self->ut_numbern('susp')
    || $self->ut_numbern('cancel')
    || $self->ut_numbern('adjourn')
    || $self->ut_numbern('expire')
  ;
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
      my $pkgpart_href = $agent->pkgpart_hashref;
      return "agent ". $agent->agentnum.
             " can't purchase pkgpart ". $self->pkgpart
        unless $pkgpart_href->{ $self->pkgpart };
    }

    $error = $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart' );
    return $error if $error;

  }

  $self->otaker(getotaker) unless $self->otaker;
  $self->otaker =~ /^(\w{1,32})$/ or return "Illegal otaker";
  $self->otaker($1);

  if ( $self->dbdef_table->column('manual_flag') ) {
    $self->manual_flag('') if $self->manual_flag eq ' ';
    $self->manual_flag =~ /^([01]?)$/
      or return "Illegal manual_flag ". $self->manual_flag;
    $self->manual_flag($1);
  }

  $self->SUPER::check;
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

=back

If there is an error, returns the error, otherwise returns false.

=cut

sub cancel {
  my( $self, %options ) = @_;
  my $error;

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

  my $cancel_time = $options{'time'} || time;

  if ( $options{'reason'} ) {
    $error = $self->insert_reason( 'reason' => $options{'reason'},
                                   'action' => $date ? 'expire' : 'cancel',
                                   'reason_otaker' => $options{'reason_otaker'},
                                 );
    if ( $error ) {
      dbh->rollback if $oldAutoCommit;
      return "Error inserting cust_pkg_reason: $error";
    }
  }

  my %svc;
  unless ( $date ) {
    foreach my $cust_svc (
      #schwartz
      map  { $_->[0] }
      sort { $a->[1] <=> $b->[1] }
      map  { [ $_, $_->svc_x->table_info->{'cancel_weight'} ]; }
      qsearch( 'cust_svc', { 'pkgnum' => $self->pkgnum } )
    ) {

      my $error = $cust_svc->cancel;

      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error cancelling cust_svc: $error";
      }
    }

    # Add a credit for remaining service
    my $remaining_value = $self->calc_remain(time=>$cancel_time);
    if ( $remaining_value > 0 && !$options{'no_credit'} ) {
      my $conf = new FS::Conf;
      my $error = $self->cust_main->credit(
        $remaining_value,
        'Credit for unused time on '. $self->part_pkg->pkg,
        'reason_type' => $conf->config('cancel_credit_type'),
      );
      if ($error) {
        $dbh->rollback if $oldAutoCommit;
        return "Error crediting customer \$$remaining_value for unused time on".
               $self->part_pkg->pkg. ": $error";
      }
    }
  }

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

  my $conf = new FS::Conf;
  my @invoicing_list = grep { $_ !~ /^(POST|FAX)$/ } $self->cust_main->invoicing_list;
  if ( !$options{'quiet'} && $conf->exists('emailcancel') && @invoicing_list ) {
    my $conf = new FS::Conf;
    my $error = send_email(
      'from'    => $conf->config('invoice_from'),
      'to'      => \@invoicing_list,
      'subject' => ( $conf->config('cancelsubject') || 'Cancellation Notice' ),
      'body'    => [ map "$_\n", $conf->config('cancelmessage') ],
    );
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

=item reason - can be set to a cancellation reason (see L<FS:reason>), either a reasonnum of an existing reason, or passing a hashref will create a new reason.  The hashref should have the following keys: typenum - Reason type (see L<FS::reason_type>, reason - Text of the new reason.

=item date - can be set to a unix style timestamp to specify when to suspend (adjourn)

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

  my $date = $options{date} if $options{date}; # adjourn/suspend later
  $date = '' if ($date && $date <= time);      # complain instead?

  if ( $date && $old->get('expire') && $old->get('expire') < $date ) {
    dbh->rollback if $oldAutoCommit;
    return "Package $pkgnum expires before it would be suspended.";
  }

  if ( $options{'reason'} ) {
    $error = $self->insert_reason( 'reason' => $options{'reason'},
                                   'action' => $date ? 'adjourn' : 'suspend',
                                   'reason_otaker' => $options{'reason_otaker'},
                                 );
    if ( $error ) {
      dbh->rollback if $oldAutoCommit;
      return "Error inserting cust_pkg_reason: $error";
    }
  }

  unless ( $date ) {
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
      }
    }
  }

  my %hash = $self->hash;
  $date ? ($hash{'adjourn'} = $date) : ($hash{'susp'} = time);
  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options } );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
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
    dbh->rollback if $oldAutoCommit;
    return "Can't unsuspend cancelled package $pkgnum";
  }

  unless ( $old->get('susp') && $self->get('susp') ) {
    dbh->rollback if $oldAutoCommit;
    return "";  # no error                     # complain instead?
  }

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
    }

  }

  my %hash = $self->hash;
  my $inactive = time - $hash{'susp'};

  my $conf = new FS::Conf;

  $hash{'bill'} = ( $hash{'bill'} || $hash{'setup'} ) + $inactive
    if ( $opt{'adjust_next_bill'}
         || $conf->config('unsuspend-always_adjust_next_bill_date') )
    && $inactive > 0 && ( $hash{'bill'} || $hash{'setup'} );

  $hash{'susp'} = '';
  $hash{'adjourn'} = '' if $hash{'adjourn'} < time;
  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options } );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
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
  my $new = new FS::cust_pkg ( \%hash );
  $error = $new->replace( $self, options => { $self->options } );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors

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
  #exists( $self->{'_pkgpart'} )
  $self->{'_pkgpart'}
    ? $self->{'_pkgpart'}
    : qsearchs( 'part_pkg', { 'pkgpart' => $self->pkgpart } );
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

=item cust_svc [ SVCPART ]

Returns the services for this package, as FS::cust_svc objects (see
L<FS::cust_svc>).  If a svcpart is specified, return only the matching
services.

=cut

sub cust_svc {
  my $self = shift;

  if ( @_ ) {
    return qsearch( 'cust_svc', { 'pkgnum'  => $self->pkgnum,
                                  'svcpart' => shift,          } );
  }

  #if ( $self->{'_svcnum'} ) {
  #  values %{ $self->{'_svcnum'}->cache };
  #} else {
    $self->_sort_cust_svc(
      [ qsearch( 'cust_svc', { 'pkgnum' => $self->pkgnum } ) ]
    );
  #}

}

=item overlimit [ SVCPART ]

Returns the services for this package which have exceeded their
usage limit as FS::cust_svc objects (see L<FS::cust_svc>).  If a svcpart
is specified, return only the matching services.

=cut

sub overlimit {
  my $self = shift;
  grep { $_->overlimit } $self->cust_svc;
}

=item h_cust_svc END_TIMESTAMP [ START_TIMESTAMP ] 

Returns historical services for this package created before END TIMESTAMP and
(optionally) not cancelled before START_TIMESTAMP, as FS::h_cust_svc objects
(see L<FS::h_cust_svc>).

=cut

sub h_cust_svc {
  my $self = shift;

  $self->_sort_cust_svc(
    [ qsearch( 'h_cust_svc',
               { 'pkgnum' => $self->pkgnum, },
               FS::h_cust_svc->sql_h_search(@_),
             )
    ]
  );
}

sub _sort_cust_svc {
  my( $self, $arrayref ) = @_;

  map  { $_->[0] }
  sort { $b->[1] cmp $a->[1]  or  $a->[2] <=> $b->[2] } 
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

=item num_cust_svc [ SVCPART ]

Returns the number of provisioned services for this package.  If a svcpart is
specified, counts only the matching services.

=cut

sub num_cust_svc {
  my $self = shift;
  my $sql = 'SELECT COUNT(*) FROM cust_svc WHERE pkgnum = ?';
  $sql .= ' AND svcpart = ?' if @_;
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute($self->pkgnum, @_) or die $sth->errstr;
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
          $part_svc;
        }
      $self->part_pkg->pkg_svc;
}

=item part_svc

Returns a list of FS::part_svc objects representing provisioned and available
services included in this package.  Each FS::part_svc object also has the
following extra fields:

=over 4

=item num_cust_svc  (count)

=item num_avail     (quantity - count)

=item cust_pkg_svc (services) - array reference containing the provisioned services, as cust_svc objects

svcnum
label -> ($cust_svc->label)[1]

=back

=cut

sub part_svc {
  my $self = shift;

  #XXX some sort of sort order besides numeric by svcpart...
  my @part_svc = sort { $a->svcpart <=> $b->svcpart } map {
    my $pkg_svc = $_;
    my $part_svc = $pkg_svc->part_svc;
    my $num_cust_svc = $self->num_cust_svc($part_svc->svcpart);
    $part_svc->{'Hash'}{'num_cust_svc'} = $num_cust_svc; #more evil
    $part_svc->{'Hash'}{'num_avail'}    =
      max( 0, $pkg_svc->quantity - $num_cust_svc );
    $part_svc->{'Hash'}{'cust_pkg_svc'} = [ $self->cust_svc($part_svc->svcpart) ];
    $part_svc;
  } $self->part_pkg->pkg_svc;

  #extras
  push @part_svc, map {
    my $part_svc = $_;
    my $num_cust_svc = $self->num_cust_svc($part_svc->svcpart);
    $part_svc->{'Hash'}{'num_cust_svc'} = $num_cust_svc; #speak no evail
    $part_svc->{'Hash'}{'num_avail'}    = 0; #0-$num_cust_svc ?
    $part_svc->{'Hash'}{'cust_pkg_svc'} = [ $self->cust_svc($part_svc->svcpart) ];
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
  my $pkgpart = $self->pkgpart;

  qsearch( {
    'table'     => 'part_svc',
    'hashref'   => {},
    'extra_sql' => "WHERE 0 = ( SELECT COUNT(*) FROM pkg_svc 
                                  WHERE pkg_svc.svcpart = part_svc.svcpart 
				    AND pkg_svc.pkgpart = $pkgpart
				    AND quantity > 0 
			      )
	              AND 0 < ( SELECT count(*)
		                  FROM cust_svc
		                    LEFT JOIN cust_pkg using ( pkgnum )
				  WHERE cust_svc.svcpart = part_svc.svcpart
				    AND pkgnum = $pkgnum
			      )",
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

=item statuses

Class method that returns the list of possible status strings for packages
(see L<the status method|/status>).  For example:

  @statuses = FS::cust_pkg->statuses();

=cut

tie my %statuscolor, 'Tie::IxHash', 
  'not yet billed'  => '000000',
  'one-time charge' => '000000',
  'active'          => '00CC00',
  'suspended'       => 'FF9900',
  'cancelled'       => 'FF0000',
;

sub statuses {
  my $self = shift; #could be class...
  grep { $_ !~ /^(not yet billed)$/ } #this is a dumb status anyway
                                      # mayble split btw one-time vs. recur
    keys %statuscolor;
}

=item statuscolor

Returns a hex triplet color string for this package's status.

=cut

sub statuscolor {
  my $self = shift;
  $statuscolor{$self->status};
}

=item labels

Returns a list of lists, calling the label method for all services
(see L<FS::cust_svc>) of this billing item.

=cut

sub labels {
  my $self = shift;
  map { [ $_->label ] } $self->cust_svc;
}

=item h_labels END_TIMESTAMP [ START_TIMESTAMP ] 

Like the labels method, but returns historical information on services that
were active as of END_TIMESTAMP and (optionally) not cancelled before
START_TIMESTAMP.

Returns a list of lists, calling the label method for all (historical) services
(see L<FS::h_cust_svc>) of this billing item.

=cut

sub h_labels {
  my $self = shift;
  map { [ $_->label(@_) ] } $self->h_cust_svc(@_);
}

=item h_labels_short END_TIMESTAMP [ START_TIMESTAMP ]

Like h_labels, except returns a simple flat list, and shortens long
(currently >5 or the cust_bill-max_same_services configuration value) lists of
identical services to one line that lists the service label and the number of
individual services rather than individual items.

=cut

sub h_labels_short {
  my $self = shift;

  my $conf = new FS::Conf;
  my $max_same_services = $conf->config('cust_bill-max_same_services') || 5;

  my %labels;
  #tie %labels, 'Tie::IxHash';
  push @{ $labels{$_->[0]} }, $_->[1]
    foreach $self->h_labels(@_);
  my @labels;
  foreach my $label ( keys %labels ) {
    my @values = @{ $labels{$label} };
    my $num = scalar(@values);
    if ( $num > $max_same_services ) {
      push @labels, "$label ($num)";
    } else {
      push @labels, map { "$label: $_" } @values;
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

=item active_sql

Returns an SQL expression identifying active packages.

=cut

sub active_sql { "
  ". $_[0]->recurring_sql(). "
  AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
  AND ( cust_pkg.susp   IS NULL OR cust_pkg.susp   = 0 )
"; }

=item inactive_sql

Returns an SQL expression identifying inactive packages (one-time packages
that are otherwise unsuspended/uncancelled).

=cut

sub inactive_sql { "
  ". $_[0]->onetime_sql(). "
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

=item search_sql HASHREF

(Class method)

Returns a qsearch hash expression to search for parameters specified in HASHREF.
Valid parameters are

=over 4

=item agentnum

=item magic

active, inactive, suspended, cancel (or cancelled)

=item status

active, inactive, suspended, one-time charge, inactive, cancel (or cancelled)

=item classnum

=item pkgpart

list specified how?

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

=back

=cut

sub search_sql { 
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
  # parse status
  ##

  if (    $params->{'magic'}  eq 'active'
       || $params->{'status'} eq 'active' ) {

    push @where, FS::cust_pkg->active_sql();

  } elsif (    $params->{'magic'}  eq 'inactive'
            || $params->{'status'} eq 'inactive' ) {

    push @where, FS::cust_pkg->inactive_sql();

  } elsif (    $params->{'magic'}  eq 'suspended'
            || $params->{'status'} eq 'suspended'  ) {

    push @where, FS::cust_pkg->suspended_sql();

  } elsif (    $params->{'magic'}  =~ /^cancell?ed$/
            || $params->{'status'} =~ /^cancell?ed$/ ) {

    push @where, FS::cust_pkg->cancelled_sql();

  } elsif ( $params->{'status'} =~ /^(one-time charge|inactive)$/ ) {

    push @where, FS::cust_pkg->inactive_sql();

  }

  ###
  # parse package class
  ###

  #false lazinessish w/graph/cust_bill_pkg.cgi
  my $classnum = 0;
  my @pkg_class = ();
  if ( exists($params->{'classnum'})
       && $params->{'classnum'} =~ /^(\d*)$/
     )
  {
    $classnum = $1;
    if ( $classnum ) { #a specific class
      push @where, "classnum = $classnum";

      #@pkg_class = ( qsearchs('pkg_class', { 'classnum' => $classnum } ) );
      #die "classnum $classnum not found!" unless $pkg_class[0];
      #$title .= $pkg_class[0]->classname.' ';

    } elsif ( $classnum eq '' ) { #the empty class

      push @where, "classnum IS NULL";
      #$title .= 'Empty class ';
      #@pkg_class = ( '(empty class)' );
    } elsif ( $classnum eq '0' ) {
      #@pkg_class = qsearch('pkg_class', {} ); # { 'disabled' => '' } );
      #push @pkg_class, '(empty class)';
    } else {
      die "illegal classnum";
    }
  }
  #eslaf

  ###
  # parse part_pkg
  ###

  my $pkgpart = join (' OR pkgpart=',
                      grep {$_} map { /^(\d+)$/; } ($params->{'pkgpart'}));
  push @where,  '(pkgpart=' . $pkgpart . ')' if $pkgpart;

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

  foreach my $field (qw( setup last_bill bill adjourn susp expire cancel )) {

    next unless exists($params->{$field});

    my($beginning, $ending) = @{$params->{$field}};

    next if $beginning == 0 && $ending == 4294967295;

    push @where,
      "cust_pkg.$field IS NOT NULL",
      "cust_pkg.$field >= $beginning",
      "cust_pkg.$field <= $ending";

    $orderby ||= "ORDER BY cust_pkg.$field";

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
    }else{
      push @where, "1=0";
    }
  }else{
    push @where, $FS::CurrentUser::CurrentUser->agentnums_sql('table'=>'cust_main');
  }

  my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

  my $addl_from = 'LEFT JOIN cust_main USING ( custnum  ) '.
                  'LEFT JOIN part_pkg  USING ( pkgpart  ) '.
                  'LEFT JOIN pkg_class USING ( classnum ) ';

  my $count_query = "SELECT COUNT(*) FROM cust_pkg $addl_from $extra_sql";

  my $sql_query = {
    'table'       => 'cust_pkg',
    'hashref'     => {},
    'select'      => join(', ',
                                'cust_pkg.*',
                                ( map "part_pkg.$_", qw( pkg freq ) ),
                                'pkg_class.classname',
                                'cust_main.custnum as cust_main_custnum',
                                FS::UI::Web::cust_sql_fields(
                                  $params->{'cust_fields'}
                                ),
                     ),
    'extra_sql'   => "$extra_sql $orderby",
    'addl_from'   => $addl_from,
    'count_query' => $count_query,
  };

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
  my $cust_main = qsearchs('cust_main', { custnum => $custnum });
  return "Customer not found: $custnum" unless $cust_main;

  my @old_cust_pkg = map { qsearchs('cust_pkg', { pkgnum => $_ }) }
                         @$remove_pkgnum;

  my $change = scalar(@old_cust_pkg) != 0;

  my %hash = (); 
  if ( scalar(@old_cust_pkg) == 1 && scalar(@$pkgparts) == 1 ) {

    my $time = time;

    #$hash{$_} = $old_cust_pkg[0]->$_() foreach qw( last_bill bill );
    
    #$hash{$_} = $old_cust_pkg[0]->$_() foreach qw( setup );
    $hash{'setup'} = $time if $old_cust_pkg[0]->setup;

    $hash{'change_date'} = $time;
    $hash{"change_$_"}  = $old_cust_pkg[0]->$_() foreach qw( pkgnum pkgpart );
  }

  # Create the new packages.
  foreach my $pkgpart (@$pkgparts) {
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

PKGPARTS is a list of pkgparts specifying the the billing item definitions (see
L<FS::part_pkg>) to order for this customer.  Duplicates are of course
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

=item set_usage USAGE_VALUE_HASHREF 

USAGE_VALUE_HASHREF is a hashref of svc_acct usage columns and the amounts
to which they should be set (see L<FS::svc_acct>).  Currently seconds,
upbytes, downbytes, and totalbytes are appropriate keys.

All svc_accts which are part of this package have their values reset.

=cut

sub set_usage {
  my ($self, $valueref) = @_;

  foreach my $cust_svc ($self->cust_svc){
    my $svc_x = $cust_svc->svc_x;
    $svc_x->set_usage($valueref)
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

  foreach my $cust_svc ($self->cust_svc){
    my $svc_x = $cust_svc->svc_x;
    $svc_x->recharge($valueref)
      if $svc_x->can("recharge");
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

