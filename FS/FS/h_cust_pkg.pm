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
  foreach (qw(select addl_from extra_sql count_query)) {
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


=head1 BUGS

=head1 SEE ALSO

L<FS::cust_pkg>,  L<FS::h_Common>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;


