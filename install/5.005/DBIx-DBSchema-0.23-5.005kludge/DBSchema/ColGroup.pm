package DBIx::DBSchema::ColGroup;

use strict;
use vars qw(@ISA);
#use Exporter;

#@ISA = qw(Exporter);
@ISA = qw();

=head1 NAME

DBIx::DBSchema::ColGroup - Column group objects

=head1 SYNOPSIS

  use DBIx::DBSchema::ColGroup;

  $colgroup = new DBIx::DBSchema::ColGroup ( $lol_ref );
  $colgroup = new DBIx::DBSchema::ColGroup ( \@lol );
  $colgroup = new DBIx::DBSchema::ColGroup (
    [
      [ 'single_column' ],
      [ 'multiple_columns', 'another_column', ],
    ]
  );

  $lol_ref = $colgroup->lol_ref;

  @sql_lists = $colgroup->sql_list;

  @singles = $colgroup->singles;

=head1 DESCRIPTION

DBIx::DBSchema::ColGroup objects represent sets of sets of columns.  (IOW a
"list of lists" - see L<perllol>.)

=head1 METHODS

=over 4

=item new [ LOL_REF ]

Creates a new DBIx::DBSchema::ColGroup object.  Pass a reference to a list of
lists of column names.

=cut

sub new {
  my($proto, $lol) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    'lol' => $lol,
  };

  bless ($self, $class);

}

=item lol_ref

Returns a reference to a list of lists of column names.

=cut

sub lol_ref {
  my($self) = @_;
  $self->{'lol'};
}

=item sql_list

Returns a flat list of comma-separated values, for SQL statements.

For example:

  @lol = (
           [ 'single_column' ],
           [ 'multiple_columns', 'another_column', ],
         );

  $colgroup = new DBIx::DBSchema::ColGroup ( \@lol );

  print join("\n", $colgroup->sql_list), "\n";

Will print:

  single_column
  multiple_columns, another_column

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

=head1 AUTHOR

Ivan Kohler <ivan-dbix-dbschema@420.am>

=head1 COPYRIGHT

Copyright (c) 2000 Ivan Kohler
Copyright (c) 2000 Mail Abuse Prevention System LLC
All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 BUGS

=head1 SEE ALSO

L<DBIx::DBSchema::Table>, L<DBIx::DBSchema::ColGroup::Unique>,
L<DBIx::DBSchema::ColGroup::Index>, L<DBIx::DBSchema>, L<perllol>, L<perldsc>,
L<DBI>

=cut

1;

