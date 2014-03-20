package FS::cust_svc;

use strict;
use vars qw( @ISA $DEBUG $me $ignore_quantity $conf $ticket_system );
use Carp;
#use Scalar::Util qw( blessed );
use List::Util qw( max );
use FS::Conf;
use FS::Record qw( qsearch qsearchs dbh str2time_sql );
use FS::cust_pkg;
use FS::part_pkg;
use FS::part_svc;
use FS::pkg_svc;
use FS::domain_record;
use FS::part_export;
use FS::cdr;
use FS::UI::Web;

#most FS::svc_ classes are autoloaded in svc_x emthod
use FS::svc_acct;  #this one is used in the cache stuff

@ISA = qw( FS::cust_main_Mixin FS::option_Common ); #FS::Record );

$DEBUG = 0;
$me = '[cust_svc]';

$ignore_quantity = 0;

#ask FS::UID to run this stuff for us later
FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $ticket_system = $conf->config('ticket_system')
});

sub _cache {
  my $self = shift;
  my ( $hashref, $cache ) = @_;
  if ( $hashref->{'username'} ) {
    $self->{'_svc_acct'} = FS::svc_acct->new($hashref, '');
  }
  if ( $hashref->{'svc'} ) {
    $self->{'_svcpart'} = FS::part_svc->new($hashref);
  }
}

=head1 NAME

FS::cust_svc - Object method for cust_svc objects

=head1 SYNOPSIS

  use FS::cust_svc;

  $record = new FS::cust_svc \%hash
  $record = new FS::cust_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  ($label, $value) = $record->label;

=head1 DESCRIPTION

An FS::cust_svc represents a service.  FS::cust_svc inherits from FS::Record.
The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatically for new services)

=item pkgnum - Package (see L<FS::cust_pkg>)

=item svcpart - Service definition (see L<FS::part_svc>)

=item agent_svcid - Optional legacy service ID

=item overlimit - date the service exceeded its usage limit

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new service.  To add the refund to the database, see L<"insert">.
Services are normally created by creating FS::svc_ objects (see
L<FS::svc_acct>, L<FS::svc_domain>, and L<FS::svc_forward>, among others).

=cut

sub table { 'cust_svc'; }

=item insert

Adds this service to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this service from the database.  If there is an error, returns the
error, otherwise returns false.  Note that this only removes the cust_svc
record - you should probably use the B<cancel> method instead.

=cut

my $rt_session;

sub delete {
  my $self = shift;

  my $cust_pkg = $self->cust_pkg;
  my $custnum = $cust_pkg->custnum if $cust_pkg;

  my $error = $self->SUPER::delete;
  return $error if $error;

  if ( $ticket_system eq 'RT_Internal' ) {
    unless ( $rt_session ) {
      FS::TicketSystem->init;
      $rt_session = FS::TicketSystem->session;
    }
    my $links = RT::Links->new($rt_session->{CurrentUser});
    my $svcnum = $self->svcnum;
    $links->Limit(FIELD => 'Target', 
                  VALUE => 'freeside://freeside/cust_svc/'.$svcnum);
    while ( my $l = $links->Next ) {
      my ($val, $msg);
      if ( $custnum ) {
        # re-link to point to the customer instead
        ($val, $msg) =
          $l->SetTarget('freeside://freeside/cust_main/'.$custnum);
      } else {
        # unlinked service
        ($val, $msg) = $l->Delete;
      }
      # can't do anything useful on error
      warn "error unlinking ticket $svcnum: $msg\n" if !$val;
    }
  }
}

=item cancel

Cancels the relevant service by calling the B<cancel> method of the associated
FS::svc_XXX object (i.e. an FS::svc_acct object or FS::svc_domain object),
deleting the FS::svc_XXX record and then deleting this record.

If there is an error, returns the error, otherwise returns false.

=cut

sub cancel {
  my($self,%opt) = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $part_svc = $self->part_svc;

  $part_svc->svcdb =~ /^([\w\-]+)$/ or do {
    $dbh->rollback if $oldAutoCommit;
    return "Illegal svcdb value in part_svc!";
  };
  my $svcdb = $1;
  require "FS/$svcdb.pm";

  my $svc = $self->svc_x;
  if ($svc) {
    if ( %opt && $opt{'date'} ) {
	my $error = $svc->expire($opt{'date'});
	if ( $error ) {
	  $dbh->rollback if $oldAutoCommit;
	  return "Error expiring service: $error";
	}
    } else {
	my $error = $svc->cancel;
	if ( $error ) {
	  $dbh->rollback if $oldAutoCommit;
	  return "Error canceling service: $error";
	}
	$error = $svc->delete; #this deletes this cust_svc record as well
	if ( $error ) {
	  $dbh->rollback if $oldAutoCommit;
	  return "Error deleting service: $error";
	}
    }

  } elsif ( !%opt ) {

    #huh?
    warn "WARNING: no svc_ record found for svcnum ". $self->svcnum.
         "; deleting cust_svc only\n"; 

    my $error = $self->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error deleting cust_svc: $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors

}

=item overlimit [ ACTION ]

Retrieves or sets the overlimit date.  If ACTION is absent, return
the present value of overlimit.  If ACTION is present, it can
have the value 'suspend' or 'unsuspend'.  In the case of 'suspend' overlimit
is set to the current time if it is not already set.  The 'unsuspend' value
causes the time to be cleared.  

If there is an error on setting, returns the error, otherwise returns false.

=cut

sub overlimit {
  my $self = shift;
  my $action = shift or return $self->getfield('overlimit');

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $action eq 'suspend' ) {
    $self->setfield('overlimit', time) unless $self->getfield('overlimit');
  }elsif ( $action eq 'unsuspend' ) {
    $self->setfield('overlimit', '');
  }else{
    die "unexpected action value: $action";
  }

  local $ignore_quantity = 1;
  my $error = $self->replace;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "Error setting overlimit: $error";
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no errors

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
#  my $new = shift;
#
#  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
#              ? shift
#              : $new->replace_old;
  my ( $new, $old ) = ( shift, shift );
  $old = $new->replace_old unless defined($old);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $new->svcpart != $old->svcpart ) {
    my $svc_x = $new->svc_x;
    my $new_svc_x = ref($svc_x)->new({$svc_x->hash, svcpart=>$new->svcpart });
    local($FS::Record::nowarn_identical) = 1;
    my $error = $new_svc_x->replace($svc_x);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error if $error;
    }
  }

#  #trigger a re-export on pkgnum changes?
#  # (of prepaid packages), for Expiration RADIUS attribute
#  if ( $new->pkgnum != $old->pkgnum && $new->cust_pkg->part_pkg->is_prepaid ) {
#    my $svc_x = $new->svc_x;
#    local($FS::Record::nowarn_identical) = 1;
#    my $error = $svc_x->export('replace');
#    if ( $error ) {
#      $dbh->rollback if $oldAutoCommit;
#      return $error if $error;
#    }
#  }

  #trigger a pkg_change export on pkgnum changes
  if ( $new->pkgnum != $old->pkgnum ) {
    my $error = $new->svc_x->export('pkg_change', $new->cust_pkg,
                                                  $old->cust_pkg,
                                   );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error if $error;
    }
  }

  #my $error = $new->SUPER::replace($old, @_);
  my $error = $new->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error if $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error

}

=item check

Checks all fields to make sure this is a valid service.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('svcnum')
    || $self->ut_numbern('pkgnum')
    || $self->ut_number('svcpart')
    || $self->ut_numbern('agent_svcid')
    || $self->ut_numbern('overlimit')
  ;
  return $error if $error;

  my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );
  return "Unknown svcpart" unless $part_svc;

  if ( $self->pkgnum && ! $ignore_quantity ) {

    #slightly inefficient since ->pkg_svc will also look it up, but fixing
    # a much larger perf problem and have bigger fish to fry
    my $cust_pkg = $self->cust_pkg;

    my $pkg_svc = $self->pkg_svc
                    || new FS::pkg_svc { 'svcpart'  => $self->svcpart,
                                         'pkgpart'  => $cust_pkg->pkgpart,
                                         'quantity' => 0,
                                       };

    #service add-ons, kinda false laziness/reimplementation of part_pkg->pkg_svc
    foreach my $part_pkg_link ( $cust_pkg->part_pkg->svc_part_pkg_link ) {
      my $addon_pkg_svc = qsearchs('pkg_svc', {
                            pkgpart => $part_pkg_link->dst_pkgpart,
                            svcpart => $self->svcpart,
                          });
      $pkg_svc->quantity( $pkg_svc->quantity + $addon_pkg_svc->quantity )
        if $addon_pkg_svc;
    }

   #better error message?  UI shouldn't get here
   return "No svcpart ". $self->svcpart.
          " services in pkgpart ". $cust_pkg->pkgpart
     unless $pkg_svc->quantity > 0;

    my $num_cust_svc = $cust_pkg->num_cust_svc( $self->svcpart );

    #false laziness w/cust_pkg->part_svc
    my $num_avail = max( 0, ($cust_pkg->quantity || 1) * $pkg_svc->quantity
                            - $num_cust_svc
                       );

   #better error message?  again, UI shouldn't get here
    return "Already $num_cust_svc ". $pkg_svc->part_svc->svc.
           " services for pkgnum ". $self->pkgnum
      if $num_avail <= 0;

  }

  $self->SUPER::check;
}

=item display_svcnum 

Returns the displayed service number for this service: agent_svcid if it has a
value, svcnum otherwise

=cut

sub display_svcnum {
  my $self = shift;
  $self->agent_svcid || $self->svcnum;
}

=item part_svc

Returns the definition for this service, as a FS::part_svc object (see
L<FS::part_svc>).

=cut

sub part_svc {
  my $self = shift;
  $self->{'_svcpart'}
    ? $self->{'_svcpart'}
    : qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );
}

=item cust_pkg

Returns the package this service belongs to, as a FS::cust_pkg object (see
L<FS::cust_pkg>).

=cut

sub cust_pkg {
  my $self = shift;
  qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
}

=item pkg_svc

Returns the pkg_svc record for for this service, if applicable.

=cut

sub pkg_svc {
  my $self = shift;
  my $cust_pkg = $self->cust_pkg;
  return undef unless $cust_pkg;

  qsearchs( 'pkg_svc', { 'svcpart' => $self->svcpart,
                         'pkgpart' => $cust_pkg->pkgpart,
                       }
          );
}

=item date_inserted

Returns the date this service was inserted.

=cut

sub date_inserted {
  my $self = shift;
  $self->h_date('insert');
}

=item pkg_cancel_date

Returns the date this service's package was canceled.  This normally only 
exists for a service that's been preserved through cancellation with the 
part_pkg.preserve flag.

=cut

sub pkg_cancel_date {
  my $self = shift;
  my $cust_pkg = $self->cust_pkg or return;
  return $cust_pkg->getfield('cancel') || '';
}

=item label

Returns a list consisting of:
- The name of this service (from part_svc)
- A meaningful identifier (username, domain, or mail alias)
- The table name (i.e. svc_domain) for this service
- svcnum

Usage example:

  my($label, $value, $svcdb) = $cust_svc->label;

=item label_long

Like the B<label> method, except the second item in the list ("meaningful
identifier") may be longer - typically, a full name is included.

=cut

sub label      { shift->_label('svc_label',      @_); }
sub label_long { shift->_label('svc_label_long', @_); }

sub _label {
  my $self = shift;
  my $method = shift;
  my $svc_x = $self->svc_x
    or return "can't find ". $self->part_svc->svcdb. '.svcnum '. $self->svcnum;

  $self->$method($svc_x);
}

sub svc_label      { shift->_svc_label('label',      @_); }
sub svc_label_long { shift->_svc_label('label_long', @_); }

sub _svc_label {
  my( $self, $method, $svc_x ) = ( shift, shift, shift );

  (
    $self->part_svc->svc,
    $svc_x->$method(@_),
    $self->part_svc->svcdb,
    $self->svcnum
  );

}

=item export_links

Returns a listref of html elements associated with this service's exports.

=cut

sub export_links {
  my $self = shift;
  my $svc_x = $self->svc_x
    or return [ "can't find ". $self->part_svc->svcdb. '.svcnum '. $self->svcnum ];

  $svc_x->export_links;
}

=item export_getsettings

Returns two hashrefs of settings associated with this service's exports.

=cut

sub export_getsettings {
  my $self = shift;
  my $svc_x = $self->svc_x
    or return "can't find ". $self->part_svc->svcdb. '.svcnum '. $self->svcnum;

  $svc_x->export_getsettings;
}


=item svc_x

Returns the FS::svc_XXX object for this service (i.e. an FS::svc_acct object or
FS::svc_domain object, etc.)

=cut

sub svc_x {
  my $self = shift;
  my $svcdb = $self->part_svc->svcdb;
  if ( $svcdb eq 'svc_acct' && $self->{'_svc_acct'} ) {
    $self->{'_svc_acct'};
  } else {
    require "FS/$svcdb.pm";
    warn "$me svc_x: part_svc.svcpart ". $self->part_svc->svcpart.
         ", so searching for $svcdb.svcnum ". $self->svcnum. "\n"
      if $DEBUG;
    qsearchs( $svcdb, { 'svcnum' => $self->svcnum } );
  }
}

=item seconds_since TIMESTAMP

See L<FS::svc_acct/seconds_since>.  Equivalent to
$cust_svc->svc_x->seconds_since, but more efficient.  Meaningless for records
where B<svcdb> is not "svc_acct".

=cut

#internal session db deprecated (or at least on hold)
sub seconds_since { 'internal session db deprecated'; };
##note: implementation here, POD in FS::svc_acct
#sub seconds_since {
#  my($self, $since) = @_;
#  my $dbh = dbh;
#  my $sth = $dbh->prepare(' SELECT SUM(logout-login) FROM session
#                              WHERE svcnum = ?
#                                AND login >= ?
#                                AND logout IS NOT NULL'
#  ) or die $dbh->errstr;
#  $sth->execute($self->svcnum, $since) or die $sth->errstr;
#  $sth->fetchrow_arrayref->[0];
#}

=item seconds_since_sqlradacct TIMESTAMP_START TIMESTAMP_END

See L<FS::svc_acct/seconds_since_sqlradacct>.  Equivalent to
$cust_svc->svc_x->seconds_since_sqlradacct, but more efficient.  Meaningless
for records where B<svcdb> is not "svc_acct".

=cut

#note: implementation here, POD in FS::svc_acct
sub seconds_since_sqlradacct {
  my($self, $start, $end) = @_;

  my $mes = "$me seconds_since_sqlradacct:";

  my $svc_x = $self->svc_x;

  my @part_export = $self->part_svc->part_export_usage;
  die "no accounting-capable exports are enabled for ". $self->part_svc->svc.
      " service definition"
    unless @part_export;
    #or return undef;

  my $seconds = 0;
  foreach my $part_export ( @part_export ) {

    next if $part_export->option('ignore_accounting');

    warn "$mes connecting to sqlradius database\n"
      if $DEBUG;

    my $dbh = DBI->connect( map { $part_export->option($_) }
                            qw(datasrc username password)    )
      or die "can't connect to sqlradius database: ". $DBI::errstr;

    warn "$mes connected to sqlradius database\n"
      if $DEBUG;

    #select a unix time conversion function based on database type
    my $str2time = str2time_sql( $dbh->{Driver}->{Name} );
    
    my $username = $part_export->export_username($svc_x);

    my $query;

    warn "$mes finding closed sessions completely within the given range\n"
      if $DEBUG;
  
    my $realm = '';
    my $realmparam = '';
    if ($part_export->option('process_single_realm')) {
      $realm = 'AND Realm = ?';
      $realmparam = $part_export->option('realm');
    }

    my $sth = $dbh->prepare("SELECT SUM(acctsessiontime)
                               FROM radacct
                               WHERE UserName = ?
                                 $realm
                                 AND $str2time AcctStartTime) >= ?
                                 AND $str2time AcctStopTime ) <  ?
                                 AND $str2time AcctStopTime ) > 0
                                 AND AcctStopTime IS NOT NULL"
    ) or die $dbh->errstr;
    $sth->execute($username, ($realm ? $realmparam : ()), $start, $end)
      or die $sth->errstr;
    my $regular = $sth->fetchrow_arrayref->[0];
  
    warn "$mes finding open sessions which start in the range\n"
      if $DEBUG;

    # count session start->range end
    $query = "SELECT SUM( ? - $str2time AcctStartTime ) )
                FROM radacct
                WHERE UserName = ?
                  $realm
                  AND $str2time AcctStartTime ) >= ?
                  AND $str2time AcctStartTime ) <  ?
                  AND ( ? - $str2time AcctStartTime ) ) < 86400
                  AND (    $str2time AcctStopTime ) = 0
                                    OR AcctStopTime IS NULL )";
    $sth = $dbh->prepare($query) or die $dbh->errstr;
    $sth->execute( $end,
                   $username,
                   ($realm ? $realmparam : ()),
                   $start,
                   $end,
                   $end )
      or die $sth->errstr. " executing query $query";
    my $start_during = $sth->fetchrow_arrayref->[0];
  
    warn "$mes finding closed sessions which start before the range but stop during\n"
      if $DEBUG;

    #count range start->session end
    $sth = $dbh->prepare("SELECT SUM( $str2time AcctStopTime ) - ? ) 
                            FROM radacct
                            WHERE UserName = ?
                              $realm
                              AND $str2time AcctStartTime ) < ?
                              AND $str2time AcctStopTime  ) >= ?
                              AND $str2time AcctStopTime  ) <  ?
                              AND $str2time AcctStopTime ) > 0
                              AND AcctStopTime IS NOT NULL"
    ) or die $dbh->errstr;
    $sth->execute( $start,
                   $username,
                   ($realm ? $realmparam : ()),
                   $start,
                   $start,
                   $end )
      or die $sth->errstr;
    my $end_during = $sth->fetchrow_arrayref->[0];
  
    warn "$mes finding closed sessions which start before the range but stop after\n"
      if $DEBUG;

    # count range start->range end
    # don't count open sessions anymore (probably missing stop record)
    $sth = $dbh->prepare("SELECT COUNT(*)
                            FROM radacct
                            WHERE UserName = ?
                              $realm
                              AND $str2time AcctStartTime ) < ?
                              AND ( $str2time AcctStopTime ) >= ?
                                                                  )"
                              #      OR AcctStopTime =  0
                              #      OR AcctStopTime IS NULL       )"
    ) or die $dbh->errstr;
    $sth->execute($username, ($realm ? $realmparam : ()), $start, $end )
      or die $sth->errstr;
    my $entire_range = ($end-$start) * $sth->fetchrow_arrayref->[0];

    $seconds += $regular + $end_during + $start_during + $entire_range;

    warn "$mes done finding sessions\n"
      if $DEBUG;

  }

  $seconds;

}

=item attribute_since_sqlradacct TIMESTAMP_START TIMESTAMP_END ATTRIBUTE

See L<FS::svc_acct/attribute_since_sqlradacct>.  Equivalent to
$cust_svc->svc_x->attribute_since_sqlradacct, but more efficient.  Meaningless
for records where B<svcdb> is not "svc_acct".

=cut

#note: implementation here, POD in FS::svc_acct
#(false laziness w/seconds_since_sqlradacct above)
sub attribute_since_sqlradacct {
  my($self, $start, $end, $attrib) = @_;

  my $mes = "$me attribute_since_sqlradacct:";

  my $svc_x = $self->svc_x;

  my @part_export = $self->part_svc->part_export_usage;
  die "no accounting-capable exports are enabled for ". $self->part_svc->svc.
      " service definition"
    unless @part_export;
    #or return undef;

  my $sum = 0;

  foreach my $part_export ( @part_export ) {

    next if $part_export->option('ignore_accounting');

    warn "$mes connecting to sqlradius database\n"
      if $DEBUG;

    my $dbh = DBI->connect( map { $part_export->option($_) }
                            qw(datasrc username password)    )
      or die "can't connect to sqlradius database: ". $DBI::errstr;

    warn "$mes connected to sqlradius database\n"
      if $DEBUG;

    #select a unix time conversion function based on database type
    my $str2time = str2time_sql( $dbh->{Driver}->{Name} );

    my $username = $part_export->export_username($svc_x);

    warn "$mes SUMing $attrib sessions\n"
      if $DEBUG;

    my $realm = '';
    my $realmparam = '';
    if ($part_export->option('process_single_realm')) {
      $realm = 'AND Realm = ?';
      $realmparam = $part_export->option('realm');
    }

    my $sth = $dbh->prepare("SELECT SUM($attrib)
                               FROM radacct
                               WHERE UserName = ?
                                 $realm
                                 AND $str2time AcctStopTime ) >= ?
                                 AND $str2time AcctStopTime ) <  ?
                                 AND AcctStopTime IS NOT NULL"
    ) or die $dbh->errstr;
    $sth->execute($username, ($realm ? $realmparam : ()), $start, $end)
      or die $sth->errstr;

    my $row = $sth->fetchrow_arrayref;
    $sum += $row->[0] if defined($row->[0]);

    warn "$mes done SUMing sessions\n"
      if $DEBUG;

  }

  $sum;

}

=item get_session_history TIMESTAMP_START TIMESTAMP_END

See L<FS::svc_acct/get_session_history>.  Equivalent to
$cust_svc->svc_x->get_session_history, but more efficient.  Meaningless for
records where B<svcdb> is not "svc_acct".

=cut

sub get_session_history {
  my($self, $start, $end, $attrib) = @_;

  #$attrib ???

  my @part_export = $self->part_svc->part_export_usage;
  die "no accounting-capable exports are enabled for ". $self->part_svc->svc.
      " service definition"
    unless @part_export;
    #or return undef;
                     
  my @sessions = ();

  foreach my $part_export ( @part_export ) {
    push @sessions,
      @{ $part_export->usage_sessions( $start, $end, $self->svc_x ) };
  }

  @sessions;

}

=item tickets

Returns an array of hashes representing the tickets linked to this service.

=cut

sub tickets {
  my $self = shift;

  my $conf = FS::Conf->new;
  my $num = $conf->config('cust_main-max_tickets') || 10;
  my @tickets = ();

  if ( $conf->config('ticket_system') ) {
    unless ( $conf->config('ticket_system-custom_priority_field') ) {

      @tickets = @{ FS::TicketSystem->service_tickets($self->svcnum, $num) };

    } else {

      foreach my $priority (
        $conf->config('ticket_system-custom_priority_field-values'), ''
      ) {
        last if scalar(@tickets) >= $num;
        push @tickets,
        @{ FS::TicketSystem->service_tickets( $self->svcnum,
            $num - scalar(@tickets),
            $priority,
          )
        };
      }
    }
  }
  (@tickets);
}


=back

=head1 SUBROUTINES

=over 4

=item smart_search OPTION => VALUE ...

Accepts the option I<search>, the string to search for.  The string will 
be searched for as a username, email address, IP address, MAC address, 
phone number, and hardware serial number.  Unlike the I<smart_search> on 
customers, this always requires an exact match.

=cut

# though perhaps it should be fuzzy in some cases?

sub smart_search {
  my %param = __PACKAGE__->smart_search_param(@_);
  qsearch(\%param);
}

sub smart_search_param {
  my $class = shift;
  my %opt = @_;

  my $string = $opt{'search'};
  $string =~ s/(^\s+|\s+$)//; #trim leading & trailing whitespace

  my @or = 
      map { my $table = $_;
            my $search_sql = "FS::$table"->search_sql($string);

            "SELECT $table.svcnum AS svcnum, '$table' AS svcdb ".
            "FROM $table WHERE $search_sql";
          }
      FS::part_svc->svc_tables;

  if ( $string =~ /^(\d+)$/ ) {
    unshift @or, "SELECT cust_svc.svcnum, NULL as svcdb FROM cust_svc WHERE agent_svcid = $1";
  }

  my $addl_from = " RIGHT JOIN (\n" . join("\nUNION\n", @or) . "\n) AS svc_all ".
                  " ON (svc_all.svcnum = cust_svc.svcnum) ";

  my @extra_sql;

  push @extra_sql, $FS::CurrentUser::CurrentUser->agentnums_sql(
    'null_right' => 'View/link unlinked services'
  );
  my $extra_sql = ' WHERE '.join(' AND ', @extra_sql);
  #for agentnum
  $addl_from  .=  ' LEFT JOIN cust_pkg  USING ( pkgnum  )'.
                  FS::UI::Web::join_cust_main('cust_pkg', 'cust_pkg').
                  ' LEFT JOIN part_svc  USING ( svcpart )';

  (
    'table'     => 'cust_svc',
    'select'    => 'svc_all.svcnum AS svcnum, '.
                   'COALESCE(svc_all.svcdb, part_svc.svcdb) AS svcdb, '.
                   'cust_svc.*',
    'addl_from' => $addl_from,
    'hashref'   => {},
    'extra_sql' => $extra_sql,
  );
}

sub _upgrade_data {
  my $class = shift;

  # fix missing (deleted by mistake) svc_x records
  warn "searching for missing svc_x records...\n";
  my %search = (
    'table'     => 'cust_svc',
    'select'    => 'cust_svc.*',
    'addl_from' => ' LEFT JOIN ( ' .
      join(' UNION ',
        map { "SELECT svcnum FROM $_" } 
        FS::part_svc->svc_tables
      ) . ' ) AS svc_all ON cust_svc.svcnum = svc_all.svcnum',
    'extra_sql' => ' WHERE svc_all.svcnum IS NULL',
  );
  my @svcs = qsearch(\%search);
  warn "found ".scalar(@svcs)."\n";

  local $FS::Record::nowarn_classload = 1; # for h_svc_
  local $FS::svc_Common::noexport_hack = 1; # because we're inserting services

  my %h_search = (
    'hashref'  => { history_action => 'delete' },
    'order_by' => ' ORDER BY history_date DESC LIMIT 1',
  );
  foreach my $cust_svc (@svcs) {
    my $svcnum = $cust_svc->svcnum;
    my $svcdb = $cust_svc->part_svc->svcdb;
    $h_search{'hashref'}{'svcnum'} = $svcnum;
    $h_search{'table'} = "h_$svcdb";
    my $h_svc_x = qsearchs(\%h_search)
      or next;
    my $class = "FS::$svcdb";
    my $new_svc_x = $class->new({ $h_svc_x->hash });
    my $error = $new_svc_x->insert;
    warn "error repairing svcnum $svcnum ($svcdb) from history:\n$error\n"
      if $error;
  }

  '';
}

=back

=head1 BUGS

Behaviour of changing the svcpart of cust_svc records is undefined and should
possibly be prohibited, and pkg_svc records are not checked.

pkg_svc records are not checked in general (here).

Deleting this record doesn't check or delete the svc_* record associated
with this record.

In seconds_since_sqlradacct, specifying a DATASRC/USERNAME/PASSWORD instead of
a DBI database handle is not yet implemented.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::part_svc>, L<FS::pkg_svc>, 
schema.html from the base documentation

=cut

1;

