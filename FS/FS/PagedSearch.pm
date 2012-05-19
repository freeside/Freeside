package FS::PagedSearch;

use strict;
use vars qw($DEBUG $default_limit @EXPORT_OK);
use base qw( Exporter );
use FS::Record qw(qsearch dbdef);
use Data::Dumper;

$DEBUG = 0;
$default_limit = 100;

@EXPORT_OK = 'psearch';

=head1 NAME

FS::PagedSearch - Iterator for querying large data sets

=head1 SYNOPSIS

use FS::PagedSearch qw(psearch);

my $search = psearch('table', { field => 'value' ... });
$search->limit(100); #optional
while ( my $row = $search->fetch ) {
...
}

=head1 SUBROUTINES

=over 4

=item psearch ARGUMENTS

A wrapper around L<FS::Record::qsearch>.  Accepts all the same arguments 
as qsearch, except for the arrayref union query mode, and returns an 
FS::PagedSearch object to access the rows of the query one at a time.  
If the query doesn't contain an ORDER BY clause already, it will be ordered
by the table's primary key.

=cut

sub psearch {
  # deep-copy qsearch args
  my $q;
  if ( ref($_[0]) eq 'ARRAY' ) {
    die "union query not supported with psearch"; #yet
  }
  elsif ( ref($_[0]) eq 'HASH' ) {
    %$q = %{ $_[0] };
  }
  else {
    $q = {
      'table'     => shift,
      'hashref'   => shift,
      'select'    => shift,
      'extra_sql' => shift,
      'cache_obj' => shift,
      'addl_from' => shift,
    };
  }
  warn Dumper($q) if $DEBUG > 1;

  # clean up query
  my $dbdef = dbdef->table($q->{table});
  # qsearch just appends order_by to extra_sql, so do that ourselves
  $q->{extra_sql} ||= '';
  $q->{extra_sql} .= ' '.$q->{order_by} if $q->{order_by};
  $q->{order_by} = '';
  # and impose an ordering if needed
  if ( not $q->{extra_sql} =~ /order by/i ) {
    $q->{extra_sql} .= ' ORDER BY '.$dbdef->primary_key;
  }
  # and then we'll use order_by for LIMIT/OFFSET

  my $self = {
    query     => $q,
    buffer    => [],
    offset    => 0,
    limit     => $default_limit,
    increment => 1,
  };
  bless $self, 'FS::PagedSearch';

  $self;
}

=back

=head1 METHODS

=over 4

=item fetch

Fetch the next row from the search results and remove it from the buffer.
Returns undef if there are no more rows.

=cut

sub fetch {
  my $self = shift;
  my $b = $self->{buffer};
  $self->refill if @$b == 0;
  $self->{offset} += $self->{increment} if @$b;
  return shift @$b;
}

=item adjust ROWS

Add ROWS to the offset counter.  This won't cause rows to be skipped in the
current buffer but will affect the starting point of the next refill.

=cut

sub adjust {
  my $self = shift;
  my $r = shift;
  $self->{offset} += $r;
}

=item limit [ VALUE ]

Set/get the number of rows to retrieve per page.  The default is 100.

=cut

sub limit {
  my $self = shift;
  my $new_limit = shift;
  if ( defined($new_limit) ) {
    $self->{limit} = $new_limit;
  }
  $self->{limit};
}

=item increment [ VALUE ]

Set/get the number of rows to increment the offset for each row that's
retrieved.  Defaults to 1.  If the rows are being modified in a way that 
removes them from the result set of the query, it's probably wise to set 
this to zero.  Setting it to anything else is probably nonsense.

=cut

sub increment {
  my $self = shift;
  my $new_inc = shift;
  if ( defined($new_inc) ) {
    $self->{increment} = $new_inc;
  }
  $self->{increment};
}


=item refill

Run the query, skipping a number of rows set by the row offset, and replace 
the contents of the buffer with the result.  If there are no more rows, 
this will just empty the buffer.  Called automatically as needed; don't call 
this from outside.

=cut

sub refill {
  my $self = shift;
  my $b = $self->{buffer};
  warn "refilling (limit ".$self->{limit}.", offset ".$self->{offset}.")\n"
    if $DEBUG;
  warn "discarding ".scalar(@$b)." rows\n" if $DEBUG and @$b;
  if ( $self->{limit} > 0 ) {
    $self->{query}->{order_by} = 'LIMIT ' . $self->{limit} . 
                                 ' OFFSET ' . $self->{offset};
  }
  @$b = qsearch( $self->{query} );
  my $rows = scalar @$b;
  warn "$rows returned\n" if $DEBUG;

  $rows;
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;
