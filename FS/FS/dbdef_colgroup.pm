package FS::dbdef_colgroup;

use strict;
use vars qw(@ISA);
use Exporter;

@ISA = qw(Exporter);

=head1 NAME

FS::dbdef_colgroup - Column group objects

=head1 SYNOPSIS

  use FS::dbdef_colgroup;

  $colgroup = new FS::dbdef_colgroup ( $lol );
  $colgroup = new FS::dbdef_colgroup (
    [
      [ 'single_column' ],
      [ 'multiple_columns', 'another_column', ],
    ]
  );

  @sql_lists = $colgroup->sql_list;

  @singles = $colgroup->singles;

=head1 DESCRIPTION

FS::dbdef_colgroup objects represent sets of sets of columns.

=head1 METHODS

=over 4

=item new

Creates a new FS::dbdef_colgroup object.

=cut

sub new {
  my($proto, $lol) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    'lol' => $lol,
  };

  bless ($self, $class);

}

=item sql_list

Returns a flat list of comma-separated values, for SQL statements.

=cut

sub sql_list { #returns a flat list of comman-separates lists (for sql)
  my($self)=@_;
   grep $_ ne '', map join(', ', @{$_}), @{$self->{'lol'}};
}

=item singles

Returns a flat list of all single item lists.

=cut

sub singles { #returns single-field groups as a flat list
  my($self)=@_;
  #map ${$_}[0], grep scalar(@{$_}) == 1, @{$self->{'lol'}};
  map { 
    ${$_}[0] =~ /^(\w+)$/
      #aah!
      or die "Illegal column ", ${$_}[0], " in colgroup!";
    $1;
  } grep scalar(@{$_}) == 1, @{$self->{'lol'}};
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::dbdef_table>, L<FS::dbdef_unique>, L<FS::dbdef_index>,
L<FS::dbdef_column>, L<FS::dbdef>, L<perldsc>

=cut

1;

