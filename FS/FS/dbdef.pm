package FS::dbdef;

use strict;
use vars qw(@ISA);
use Exporter;
use Carp;
use FreezeThaw qw(freeze thaw cmpStr);
use FS::dbdef_table;
use FS::dbdef_unique;
use FS::dbdef_index;
use FS::dbdef_column;

@ISA = qw(Exporter);

=head1 NAME

FS::dbdef - Database objects

=head1 SYNOPSIS

  use FS::dbdef;

  $dbdef = new FS::dbdef (@dbdef_table_objects);
  $dbdef = load FS::dbdef "filename";

  $dbdef->save("filename");

  $dbdef->addtable($dbdef_table_object);

  @table_names = $dbdef->tables;

  $FS_dbdef_table_object = $dbdef->table;

=head1 DESCRIPTION

FS::dbdef objects are collections of FS::dbdef_table objects and represnt
a database (a collection of tables).

=head1 METHODS

=over 4

=item new TABLE, TABLE, ...

Creates a new FS::dbdef object

=cut

sub new {
  my($proto,@tables)=@_;
  my(%tables)=map  { $_->name, $_ } @tables; #check for duplicates?

  my($class) = ref($proto) || $proto;
  my($self) = {
    'tables' => \%tables,
  };

  bless ($self, $class);

}

=item load FILENAME

Loads an FS::dbdef object from a file.

=cut

sub load {
  my($proto,$file)=@_; #use $proto ?
  open(FILE,"<$file") or die "Can't open $file: $!";
  my($string)=join('',<FILE>); #can $string have newlines?  pry not?
  close FILE or die "Can't close $file: $!";
  my($self)=thaw $string;
  #no bless needed?
  $self;
}

=item save FILENAME

Saves an FS::dbdef object to a file.

=cut

sub save {
  my($self,$file)=@_;
  my($string)=freeze $self;
  open(FILE,">$file") or die "Can't open $file: $!";
  print FILE $string;
  close FILE or die "Can't close file: $!";
  my($check_self)=thaw $string;
  die "Verify error: Can't freeze and thaw dbdef $self"
    if (cmpStr($self,$check_self));
}

=item addtable TABLE

Adds this FS::dbdef_table object.

=cut

sub addtable {
  my($self,$table)=@_;
  ${$self->{'tables'}}{$table->name}=$table; #check for dupliates?
}

=item tables 

Returns the names of all tables.

=cut

sub tables {
  my($self)=@_;
  keys %{$self->{'tables'}};
}

=item table TABLENAME

Returns the named FS::dbdef_table object.

=cut

sub table {
  my($self,$table)=@_;
  $self->{'tables'}->{$table};
}

=head1 BUGS

Each FS::dbdef object should have a name which corresponds to its name within
the SQL database engine.

=head1 SEE ALSO

L<FS::dbdef_table>, L<FS::Record>,

=cut

1;

