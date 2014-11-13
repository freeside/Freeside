package FS::h_cust_pkg;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::cust_pkg;

@ISA = qw( FS::h_Common FS::cust_pkg );

sub table { 'h_cust_pkg' };

=head1 NAME

FS::h_cust_pkg - Historical record of customer package changes

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_cust_pkg object represents historical changes to packages.
FS::h_cust_pkg inherits from FS::h_Common and FS::cust_pkg.

=head1 CLASS METHODS

=over 4

=item search HASHREF

Like L<FS::cust_pkg::search>, but adapted for searching historical records.
Takes the additional parameter "date", which is the timestamp to perform 
the search "as of" (i.e. search the most recent insert or replace_new record
for each pkgnum that is not later than that date).

=cut

sub search {
  my ($class, $params) = @_;
  my $date = delete $params->{'date'};
  $date =~ /^\d*$/ or die "invalid search date '$date'\n";

  my $query = FS::cust_pkg->search($params);

  # allow multiple status criteria
  # this might be useful in the base cust_pkg search, but I haven't 
  # tested it there yet
  my $status = delete $params->{'status'};
  if( $status ) {
    my @status_where;
    foreach ( split(',', $status) ) {
      if ( /^active$/ ) {
        push @status_where, $class->active_sql();
      } elsif ( /^not[ _]yet[ _]billed$/ ) {
        push @status_where, $class->not_yet_billed_sql();
      } elsif ( /^(one-time charge|inactive)$/ ) {
        push @status_where, $class->inactive_sql();
      } elsif ( /^suspended$/ ) {
        push @status_where, $class->suspended_sql();
      } elsif ( /^cancell?ed$/ ) {
        push @status_where, $class->cancelled_sql();
      }
    }
    if ( @status_where ) {
      $query->{'extra_sql'}   .= ' AND ('.join(' OR ', @status_where).')';
      $query->{'count_query'} .= ' AND ('.join(' OR ', @status_where).')';
    }
  }

  # make some adjustments
  $query->{'table'} = 'h_cust_pkg';
  foreach (qw(select addl_from extra_sql count_query order_by)) {
    $query->{$_} =~ s/cust_pkg\b/h_cust_pkg/g;
    $query->{$_} =~ s/cust_main\b/h_cust_main/g;
  }
  
  my $and_where = " AND h_cust_pkg.historynum = 
  (SELECT historynum FROM h_cust_pkg AS mostrecent
  WHERE mostrecent.pkgnum = h_cust_pkg.pkgnum 
  AND mostrecent.history_date <= $date
  AND mostrecent.history_action IN ('insert', 'replace_new')
  ORDER BY history_date DESC,historynum DESC LIMIT 1
  ) AND h_cust_main.historynum =
  (SELECT historynum FROM h_cust_main AS mostrecent
  WHERE mostrecent.custnum = h_cust_main.custnum
  AND mostrecent.history_date <= h_cust_pkg.history_date
  AND mostrecent.history_action IN ('insert', 'replace_new')
  ORDER BY history_date DESC,historynum DESC LIMIT 1
  )";

  $query->{'extra_sql'} .= $and_where;
  $query->{'count_query'} .= $and_where;

  $query;
}

=item churn_fromwhere_sql STATUS, START, END

Returns SQL fragments to do queries related to "package churn". STATUS
is one of "active", "setup", "cancel", "susp", or "unsusp". These do NOT
correspond directly to package statuses. START and END define a date range.

- active: limit to packages that were active on START. END is ignored.
- setup: limit to packages that were set up between START and END, except
those created by package changes.
- cancel: limit to packages that were canceled between START and END, except
those changed into other packages.
- susp: limit to packages that were suspended between START and END.
- unsusp: limit to packages that were unsuspended between START and END.

The logic of these may change in the future, especially with respect to 
package changes. Watch this space.

Returns a list of:
- a fragment usable as a FROM clause (without the keyword FROM), in which
  the package table is named or aliased to 'cust_pkg'
- one or more conditions to include in the WHERE clause

=cut

sub churn_fromwhere_sql {
  my ($self, $status, $speriod, $eperiod) = @_;

  my ($from, @where);
  if ( $status eq 'active' ) {
    # for all packages that were setup before $speriod, find the pkgnum
    # and the most recent update of the package before $speriod
    my $setup_before = "SELECT DISTINCT ON (pkgnum) pkgnum, historynum
      FROM h_cust_pkg
      WHERE setup < $speriod
        AND history_date < $speriod
        AND history_action IN('insert', 'replace_new')
      ORDER BY pkgnum ASC, history_date DESC";
    # for each of these, exclude if the package was suspended or canceled
    # in the most recent update before $speriod
    $from = "h_cust_pkg AS cust_pkg
      JOIN ($setup_before) AS setup_before USING (historynum)";
    @where = ( 'susp IS NULL', 'cancel IS NULL' );
  } elsif ( $status eq 'setup' ) {
    # the simple case, because packages should only get set up once
    # (but exclude those that were created due to a package change)
    # XXX or should we include if they were created by a pkgpart change?
    $from = "cust_pkg";
    @where = (
      "setup >= $speriod",
      "setup < $eperiod",
      "change_pkgnum IS NULL"
    );
  } elsif ( $status eq 'cancel' ) {
    # also simple, because packages should only be canceled once
    # (exclude those that were canceled due to a package change)
    $from = "cust_pkg";
    @where = (
      "cust_pkg.cancel >= $speriod",
      "cust_pkg.cancel < $eperiod",
      "NOT EXISTS(SELECT 1 FROM cust_pkg AS changed_to_pkg ".
        "WHERE cust_pkg.pkgnum = changed_to_pkg.change_pkgnum)",
    );
  } elsif ( $status eq 'susp' ) {
    # more complicated
    # find packages that were changed from susp = null to susp != null
    my $susp_during = $self->sql_diff($speriod, $eperiod) .
      ' WHERE old.susp IS NULL AND new.susp IS NOT NULL';
    $from = "h_cust_pkg AS cust_pkg
      JOIN ($susp_during) AS susp_during
        ON (susp_during.new_historynum = cust_pkg.historynum)";
    @where = ( 'cust_pkg.cancel IS NULL' );
  } elsif ( $status eq 'unsusp' ) {
    # similar to 'susp'
    my $unsusp_during = $self->sql_diff($speriod, $eperiod) .
      ' WHERE old.susp IS NOT NULL AND new.susp IS NULL';
    $from = "h_cust_pkg AS cust_pkg
      JOIN ($unsusp_during) AS unsusp_during
        ON (unsusp_during.new_historynum = cust_pkg.historynum)";
    @where = ( 'cust_pkg.cancel IS NULL' );
  } else {
    die "'$status' makes no sense";
  }
  return ($from, @where);
}

=head1 as_of_sql DATE

Returns a qsearch hash for the instantaneous state of the cust_pkg table 
on DATE.

Currently accepts no restrictions; use it in a subquery if you want to 
limit or sort the output. (Restricting within the query is problematic.)

=cut

sub as_of_sql {
  my $class = shift;
  my $date = shift;
  "SELECT DISTINCT ON (pkgnum) *
    FROM h_cust_pkg
    WHERE history_date < $date
      AND history_action IN('insert', 'replace_new')
    ORDER BY pkgnum ASC, history_date DESC"
}

=item status_query DATE

Returns a statement for determining the status of packages on a particular 
past date.

=cut

sub status_as_of_sql {
  my $class = shift;
  my $date = shift;

  my @select = (
    'h_cust_pkg.*',
    FS::cust_pkg->active_sql() . ' AS is_active',
    FS::cust_pkg->suspended_sql() . ' AS is_suspended',
    FS::cust_pkg->cancelled_sql() . ' AS is_cancelled',
  );
  # foo_sql queries reference 'cust_pkg' in field names
  foreach(@select) {
    s/\bcust_pkg\b/h_cust_pkg/g;
  }

  return "SELECT DISTINCT ON(pkgnum) ".join(',', @select).
         " FROM h_cust_pkg".
         " WHERE history_date < $date AND history_action IN('insert','replace_new')".
         " ORDER BY pkgnum ASC, history_date DESC";
}

=head1 BUGS

churn_fromwhere_sql and as_of_sql fail on MySQL.

=head1 SEE ALSO

L<FS::cust_pkg>,  L<FS::h_Common>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

