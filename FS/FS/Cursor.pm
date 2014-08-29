package FS::Cursor;

use strict;
use vars qw($DEBUG $buffer);
use FS::Record;
use FS::UID qw(myconnect driver_name);
use Scalar::Util qw(refaddr);

$DEBUG = 2;

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
  my $dbh;

  my $self = {
    query => $q,
    class => 'FS::' . ($q->{table} || 'Record'),
    buffer => [],
    position => 0, # for mysql
  };
  bless $self, $class;

  # the class of record object to return
  $self->{class} = "FS::".($q->{table} || 'Record');

  # save for later, so forked children will not destroy me when they exit
  $self->{pid} = $$;

  $self->{id} = sprintf('cursor%08x', refaddr($self));

  my $statement;
  if ( driver_name() eq 'Pg' ) {
    $self->{dbh} = $dbh = myconnect();
    $statement = "DECLARE ".$self->{id}." CURSOR FOR ".$q->{statement};
  } elsif ( driver_name() eq 'mysql' ) {
    # build a cursor from scratch
    #
    #
    # there are problems doing it this way, and we don't have time to resolve
    # them all right now...
    #$statement = "CREATE TEMPORARY TABLE $self->{id} 
    #  (rownum INT AUTO_INCREMENT, PRIMARY KEY (rownum))
    #  $q->{statement}";

    # one of those problems is locking, so keep everything on the main session
    $self->{dbh} = $dbh = FS::UID::dbh();
    $statement = $q->{statement};
  }

  my $sth = $dbh->prepare($statement)
    or die $dbh->errstr;
  my $bind = 1;
  foreach my $value ( @{ $q->{value} } ) {
    my $bind_type = shift @{ $q->{bind_type} };
    $sth->bind_param($bind++, $value, $bind_type );
  }

  $sth->execute or die $sth->errstr;

  if ( driver_name() eq 'Pg' ) {
    $self->{fetch} = $dbh->prepare("FETCH FORWARD $buffer FROM ".$self->{id});
  } elsif ( driver_name() eq 'mysql' ) {
    # make sure we're not holding any locks on the tables mentioned
    # in the query
    #$dbh->commit if driver_name() eq 'mysql';
    #$self->{fetch} = $dbh->prepare("SELECT * FROM $self->{id} ORDER BY rownum LIMIT ?, $buffer");

    # instead, fetch all the rows at once
    $self->{buffer} = $sth->fetchall_arrayref( {} );
  }

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
  if (driver_name() eq 'Pg') {
    my $sth = $self->{fetch};
    $sth->bind_param(1, $self->{position}) if driver_name() eq 'mysql';
    $sth->execute or die $sth->errstr;
    my $result = $self->{fetch}->fetchall_arrayref( {} );
    $self->{buffer} = $result;
    $self->{position} += $sth->rows;
    scalar @$result;
  } # mysql can't be refilled, since everything is buffered from the start
}

sub DESTROY {
  my $self = shift;
  return if driver_name() eq 'mysql';

  return unless $self->{pid} eq $$;
  $self->{dbh}->do('CLOSE '. $self->{id})
    or die $self->{dbh}->errstr; # clean-up the cursor in Pg
  $self->{dbh}->rollback;
  $self->{dbh}->disconnect;
}

=back

=head1 TO DO

Replace all uses of qsearch with this.

=head1 BUGS

Still doesn't really support MySQL, but it pretends it does, by simply
running the query and returning records one at a time.

The cursor will close prematurely if any code issues a rollback/commit. If
you need protection against this use qsearch or fork and get a new dbh
handle.
Normally this issue will represent itself this message.
ERROR: cursor "cursorXXXXXXX" does not exist.

=head1 SEE ALSO

L<FS::Record>

=cut

1;
