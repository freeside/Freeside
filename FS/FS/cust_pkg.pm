package FS::cust_pkg;

use strict;
use vars qw(@ISA $disable_agentcheck);
use vars qw( $quiet );
use FS::UID qw( getotaker dbh );
use FS::Record qw( qsearch qsearchs );
use FS::Misc qw( send_email );
use FS::cust_svc;
use FS::part_pkg;
use FS::cust_main;
use FS::type_pkgs;
use FS::pkg_svc;
use FS::cust_bill_pkg;

# need to 'use' these instead of 'require' in sub { cancel, suspend, unsuspend,
# setup }
# because they load configuraion by setting FS::UID::callback (see TODO)
use FS::svc_acct;
use FS::svc_domain;
use FS::svc_www;
use FS::svc_forward;

# for sending cancel emails in sub cancel
use FS::Conf;

@ISA = qw( FS::Record );

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

=item susp - date

=item expire - date

=item cancel - date

=item otaker - order taker (assigned automatically if null, see L<FS::UID>)

=item manual_flag - If this field is set to 1, disables the automatic
unsuspension of this package when using the B<unsuspendauto> config file.

=back

Note: setup, bill, susp, expire and cancel are specified as UNIX timestamps;
see L<perlfunc/"time">.  Also see L<Time::Local> and L<Date::Parse> for
conversion functions.

=head1 METHODS

=over 4

=item new HASHREF

Create a new billing item.  To add the item to the database, see L<"insert">.

=cut

sub table { 'cust_pkg'; }

=item insert

Adds this billing item to the database ("Orders" the item).  If there is an
error, returns the error, otherwise returns false.

=cut

sub insert {
  my $self = shift;

  # custnum might not have have been defined in sub check (for one-shot new
  # customers), so check it here instead
  # (is this still necessary with transactions?)

  my $error = $self->ut_number('custnum');
  return $error if $error;

  my $cust_main = $self->cust_main;
  return "Unknown customer ". $self->custnum unless $cust_main;

  unless ( $disable_agentcheck ) {
    my $agent = qsearchs( 'agent', { 'agentnum' => $cust_main->agentnum } );
    my $pkgpart_href = $agent->pkgpart_hashref;
    return "agent ". $agent->agentnum.
           " can't purchase pkgpart ". $self->pkgpart
      unless $pkgpart_href->{ $self->pkgpart };
  }

  $self->SUPER::insert;

}

=item delete

This method now works but you probably shouldn't use it.

You don't want to delete billing items, because there would then be no record
the customer ever purchased the item.  Instead, see the cancel method.

=cut

#sub delete {
#  return "Can't delete cust_pkg records!";
#}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Currently, custnum, setup, bill, susp, expire, and cancel may be changed.

Changing pkgpart may have disasterous effects.  See the order subroutine.

setup and bill are normally updated by calling the bill method of a customer
object (see L<FS::cust_main>).

suspend is normally updated by the suspend and unsuspend methods.

cancel is normally updated by the cancel method (and also the order subroutine
in some cases).

=cut

sub replace {
  my( $new, $old ) = ( shift, shift );

  #return "Can't (yet?) change pkgpart!" if $old->pkgpart != $new->pkgpart;
  return "Can't change otaker!" if $old->otaker ne $new->otaker;

  #allow this *sigh*
  #return "Can't change setup once it exists!"
  #  if $old->getfield('setup') &&
  #     $old->getfield('setup') != $new->getfield('setup');

  #some logic for bill, susp, cancel?

  $new->SUPER::replace($old);
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
    || $self->ut_numbern('custnum')
    || $self->ut_number('pkgpart')
    || $self->ut_numbern('setup')
    || $self->ut_numbern('bill')
    || $self->ut_numbern('susp')
    || $self->ut_numbern('cancel')
  ;
  return $error if $error;

  if ( $self->custnum ) { 
    return "Unknown customer ". $self->custnum unless $self->cust_main;
  }

  return "Unknown pkgpart: ". $self->pkgpart
    unless qsearchs( 'part_pkg', { 'pkgpart' => $self->pkgpart } );

  $self->otaker(getotaker) unless $self->otaker;
  $self->otaker =~ /^([\w\.\-]{0,16})$/ or return "Illegal otaker";
  $self->otaker($1);

  if ( $self->dbdef_table->column('manual_flag') ) {
    $self->manual_flag =~ /^([01]?)$/ or return "Illegal manual_flag";
    $self->manual_flag($1);
  }

  ''; #no error
}

=item cancel

Cancels and removes all services (see L<FS::cust_svc> and L<FS::part_svc>)
in this package, then cancels the package itself (sets the cancel field to
now).

If there is an error, returns the error, otherwise returns false.

=cut

sub cancel {
  my $self = shift;
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

  foreach my $cust_svc (
    qsearch( 'cust_svc', { 'pkgnum' => $self->pkgnum } )
  ) {
    my $error = $cust_svc->cancel;

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error cancelling cust_svc: $error";
    }

  }

  unless ( $self->getfield('cancel') ) {
    my %hash = $self->hash;
    $hash{'cancel'} = time;
    my $new = new FS::cust_pkg ( \%hash );
    $error = $new->replace($self);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  my $conf = new FS::Conf;
  my @invoicing_list = grep { $_ ne 'POST' } $self->cust_main->invoicing_list;
  if ( !$quiet && $conf->exists('emailcancel') && @invoicing_list ) {
    my $conf = new FS::Conf;
    my $error = send_email(
      'from'    => $conf->config('invoice_from'),
      'to'      => \@invoicing_list,
      'subject' => $conf->config('cancelsubject'),
      'body'    => [ map "$_\n", $conf->config('cancelmessage') ],
    );
    #should this do something on errors?
  }

  ''; #no errors

}

=item suspend

Suspends all services (see L<FS::cust_svc> and L<FS::part_svc>) in this
package, then suspends the package itself (sets the susp field to now).

If there is an error, returns the error, otherwise returns false.

=cut

sub suspend {
  my $self = shift;
  my $error ;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

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

  unless ( $self->getfield('susp') ) {
    my %hash = $self->hash;
    $hash{'susp'} = time;
    my $new = new FS::cust_pkg ( \%hash );
    $error = $new->replace($self);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors
}

=item unsuspend

Unsuspends all services (see L<FS::cust_svc> and L<FS::part_svc>) in this
package, then unsuspends the package itself (clears the susp field).

If there is an error, returns the error, otherwise returns false.

=cut

sub unsuspend {
  my $self = shift;
  my($error);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

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

  unless ( ! $self->getfield('susp') ) {
    my %hash = $self->hash;
    $hash{'susp'} = '';
    my $new = new FS::cust_pkg ( \%hash );
    $error = $new->replace($self);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
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
  if ( $self->dbdef_table->column('last_bill') ) {
    return $self->setfield('last_bill', $_[0]) if @_;
    return $self->getfield('last_bill') if $self->getfield('last_bill');
  }    
  my $cust_bill_pkg = qsearchs('cust_bill_pkg', { 'pkgnum' => $self->pkgnum,
                                                  'edate'  => $self->bill,  } );
  $cust_bill_pkg ? $cust_bill_pkg->sdate : $self->setup || 0;
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

=item cust_svc

Returns the services for this package, as FS::cust_svc objects (see
L<FS::cust_svc>)

=cut

sub cust_svc {
  my $self = shift;
  if ( $self->{'_svcnum'} ) {
    values %{ $self->{'_svcnum'}->cache };
  } else {
    qsearch ( 'cust_svc', { 'pkgnum' => $self->pkgnum } );
  }
}

=item labels

Returns a list of lists, calling the label method for all services
(see L<FS::cust_svc>) of this billing item.

=cut

sub labels {
  my $self = shift;
  map { [ $_->label ] } $self->cust_svc;
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

=back

=head1 SUBROUTINES

=over 4

=item order CUSTNUM, PKGPARTS_ARYREF, [ REMOVE_PKGNUMS_ARYREF [ RETURN_CUST_PKG_ARRAYREF ] ]

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

=cut

sub order {
  my($custnum, $pkgparts, $remove_pkgnums, $return_cust_pkg) = @_;
  $remove_pkgnums = [] unless defined($remove_pkgnums);

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  # generate %part_pkg
  # $part_pkg{$pkgpart} is true iff $custnum may purchase $pkgpart
  #
  my($cust_main)=qsearchs('cust_main',{'custnum'=>$custnum});
  my($agent)=qsearchs('agent',{'agentnum'=> $cust_main->agentnum });
  my %part_pkg = %{ $agent->pkgpart_hashref };

  my(%svcnum);
  # generate %svcnum
  # for those packages being removed:
  #@{ $svcnum{$svcpart} } goes from a svcpart to a list of FS::cust_svc objects
  my($pkgnum);
  foreach $pkgnum ( @{$remove_pkgnums} ) {
    foreach my $cust_svc (qsearch('cust_svc',{'pkgnum'=>$pkgnum})) {
      push @{ $svcnum{$cust_svc->getfield('svcpart')} }, $cust_svc;
    }
  }
  
  my @cust_svc;
  #generate @cust_svc
  # for those packages the customer is purchasing:
  # @{$pkgparts} is a list of said packages, by pkgpart
  # @cust_svc is a corresponding list of lists of FS::Record objects
  foreach my $pkgpart ( @{$pkgparts} ) {
    unless ( $part_pkg{$pkgpart} ) {
      $dbh->rollback if $oldAutoCommit;
      return "Customer not permitted to purchase pkgpart $pkgpart!";
    }
    push @cust_svc, [
      map {
        ( $svcnum{$_} && @{ $svcnum{$_} } ) ? shift @{ $svcnum{$_} } : ();
      } map { $_->svcpart }
          qsearch('pkg_svc', { pkgpart  => $pkgpart,
                               quantity => { op=>'>', value=>'0', } } )
    ];
  }

  #special-case until this can be handled better
  # move services to new svcparts - even if the svcparts don't match (svcdb
  # needs to...)
  # looks like they're moved in no particular order, ewwwwwwww
  # and looks like just one of each svcpart can be moved... o well

  #start with still-leftover services
  #foreach my $svcpart ( grep { scalar(@{ $svcnum{$_} }) } keys %svcnum ) {
  foreach my $svcpart ( keys %svcnum ) {
    next unless @{ $svcnum{$svcpart} };

    my $svcdb = $svcnum{$svcpart}->[0]->part_svc->svcdb;

    #find an empty place to put one
    my $i = 0;
    foreach my $pkgpart ( @{$pkgparts} ) {
      my @pkg_svc =
        qsearch('pkg_svc', { pkgpart  => $pkgpart,
                             quantity => { op=>'>', value=>'0', } } );
      #my @pkg_svc =
      #  grep { $_->quantity > 0 } qsearch('pkg_svc', { pkgpart=>$pkgpart } );
      if ( ! @{$cust_svc[$i]} #find an empty place to put them with 
           && grep { $svcdb eq $_->part_svc->svcdb } #with appropriate svcdb
                @pkg_svc
      ) {
        my $new_svcpart =
          ( grep { $svcdb eq $_->part_svc->svcdb } @pkg_svc )[0]->svcpart; 
        my $cust_svc = shift @{$svcnum{$svcpart}};
        $cust_svc->svcpart($new_svcpart);
        #warn "changing from $svcpart to $new_svcpart!!!\n";
        $cust_svc[$i] = [ $cust_svc ];
      }
      $i++;
    }

  }
  
  #check for leftover services
  foreach (keys %svcnum) {
    next unless @{ $svcnum{$_} };
    $dbh->rollback if $oldAutoCommit;
    return "Leftover services, svcpart $_: svcnum ".
           join(', ', map { $_->svcnum } @{ $svcnum{$_} } );
  }

  #no leftover services, let's make changes.
 
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE'; 
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE'; 
  local $SIG{PIPE} = 'IGNORE'; 

  #first cancel old packages
  foreach my $pkgnum ( @{$remove_pkgnums} ) {
    my($old) = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
    unless ( $old ) {
      $dbh->rollback if $oldAutoCommit;
      return "Package $pkgnum not found to remove!";
    }
    my(%hash) = $old->hash;
    $hash{'cancel'}=time;   
    my($new) = new FS::cust_pkg ( \%hash );
    my($error)=$new->replace($old);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Couldn't update package $pkgnum: $error";
    }
  }

  #now add new packages, changing cust_svc records if necessary
  my $pkgpart;
  while ($pkgpart=shift @{$pkgparts} ) {
 
    my $new = new FS::cust_pkg {
                                 'custnum' => $custnum,
                                 'pkgpart' => $pkgpart,
                               };
    my $error = $new->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Couldn't insert new cust_pkg record: $error";
    }
    push @{$return_cust_pkg}, $new if $return_cust_pkg;
    my $pkgnum = $new->pkgnum;
 
    foreach my $cust_svc ( @{ shift @cust_svc } ) {
      my(%hash) = $cust_svc->hash;
      $hash{'pkgnum'}=$pkgnum;
      my $new = new FS::cust_svc ( \%hash );

      #avoid Record diffing missing changed svcpart field from above.
      my $old = qsearchs('cust_svc', { 'svcnum' => $cust_svc->svcnum } );

      my $error = $new->replace($old);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Couldn't link old service to new package: $error";
      }
    }
  }  

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors
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

