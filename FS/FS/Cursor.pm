package FS::Cursor;

use strict;
use vars qw($DEBUG $buffer);
use base qw( Exporter );
use FS::Record qw(qsearch dbdef dbh);
use Data::Dumper;
use Scalar::Util qw(refaddr);

$DEBUG = 0;
# this might become a parameter at some point, but right now, you can
# "local $FS::Cursor::buffer = X;"
$buffer = 200;

=head1 NAME

FS::Cursor - Iterator for querying large data sets

=head1 SYNOPSIS

use FS::Cursor;

my $search = FS::Cursor->new('table', { field => 'value' ... });
while ( my $row = $search->fetch ) {
...
}

=head1 CLASS METHODS

=over 4

=item new ARGUMENTS

Constructs a cursored search.  Accepts all the same arguments as qsearch,
and returns an FS::Cursor object to fetch the rows one at a time.

=cut

sub new {
  my $class = shift;
  my $q = FS::Record::_query(@_); # builds the statement and parameter list

  my $self = {
    query => $q,
    class => 'FS::' . ($q->{table} || 'Record'),
    buffer => [],
  };
  bless $self, $class;

  # the class of record object to return
  $self->{class} = "FS::".($q->{table} || 'Record');

  $self->{id} = sprintf('cursor%08x', refaddr($self));
  my $statement = "DECLARE ".$self->{id}." CURSOR FOR ".$q->{statement};

  my $dbh = dbh;
  my $sth = $dbh->prepare($statement)
    or die $dbh->errstr;
  my $bind = 1;
  foreach my $value ( @{ $q->{value} } ) {
    my $bind_type = shift @{ $q->{bind_type} };
    $sth->bind_param($bind++, $value, $bind_type );
  }

  $sth->execute or die $sth->errstr;

  $self->{fetch} = $dbh->prepare("FETCH FORWARD $buffer FROM ".$self->{id});

  $self;
}

=back

=head1 METHODS

=over 4

=item fetch

Fetch the next row from the search results.

=cut

sub fetch {
  # might be a little more efficient to do a FETCH NEXT 1000 or something
  # and buffer them locally, but the semantics are simpler this way
  my $self = shift;
  if (@{ $self->{buffer} } == 0) {
    my $rows = $self->refill;
    return undef if !$rows;
  }
  $self->{class}->new(shift @{ $self->{buffer} });
}

sub refill {
  my $self = shift;
  my $sth = $self->{fetch};
  $sth->execute or die $sth->errstr;
  my $result = $self->{fetch}->fetchall_arrayref( {} );
  $self->{buffer} = $result;
  scalar @$result;
}

sub DESTROY {
  my $self = shift;
  my $statement = "CLOSE ".$self->{id};
  dbh->do($statement);
}  

=back

=head1 TO DO

Replace all uses of qsearch with this.

=head1 BUGS

Doesn't support MySQL.

=head1 SEE ALSO

L<FS::Record>

=cut

1;
