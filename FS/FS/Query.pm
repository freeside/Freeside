package FS::Query;

use strict;
use FS::Record; # don't import qsearch
use Storable 'dclone';

=head1 NAME

FS::Query - A thin wrapper around qsearch argument hashes.

=head1 DESCRIPTION

This module exists because we pass qsearch argument lists around a lot,
and add new joins or WHERE expressions in several stages, and I got tired
of doing this:

  my $andwhere = "mycolumn IN('perl','python','javascript')";
  if ( ($search->{hashref} and keys( %{$search->{hashref}} ))
       or $search->{extra_sql} =~ /^\s*WHERE/ ) {
    $search->{extra_sql} .= " AND $andwhere";
  } else {
    $search->{extra_sql} = " WHERE $andwhere ";
  }

and then having it fail under some conditions if it's done wrong (as the above
example is, obviously).

We may eventually switch over to SQL::Abstract or something for this, but for
now it's a couple of crude manipulations and a wrapper to qsearch.

=head1 METHODS

=over 4

=item new HASHREF

Turns HASHREF (a qsearch argument list) into an FS::Query object. None of
the params are really required, but you should at least supply C<table>.

In the Future this may do a lot more stuff.

=cut

sub new {
  my ($class, $hashref) = @_;

  my $self = bless {
    table     => '',
    select    => '*',
    hashref   => {},
    addl_from => '',
    extra_sql => '',
    order_by  => '',
    %$hashref,
  };
  # load FS::$table? validate anything?
  $self;
}

=item clone

Returns another object that's a copy of this one.

=cut

sub clone {
  my $self = shift;
  $self->new( dclone($self) );
}

=item and_where EXPR

Adds a constraint to the WHERE clause of the query. All other constraints in
the WHERE clause should be joined with AND already; if not, they should be
grouped with parentheses.

=cut

sub and_where {
  my $self = shift;
  my $where = shift;

  if ($self->{extra_sql} =~ /^\s*(?:WHERE|AND)\s+(.*)/is) {
    $where = "($where) AND $1";
  }
  if (keys %{ $self->{hashref} }) {
    $where = " AND $where";
  } else {
    $where = " WHERE $where";
  }
  $self->{extra_sql} = $where;

  return $self;
}

=item qsearch

Runs the query and returns all results.

=cut

sub qsearch {
  my $self = shift;
  FS::Record::qsearch({ %$self });
}

=item qsearchs

Runs the query and returns only one result.

=cut

sub qsearchs {
  my $self = shift;
  FS::Record::qsearchs({ %$self });
}

1;
