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

=head1 HISTORY

beginning of abstraction into a class (not really)

ivan@sisd.com 97-dec-4

added primary_key
ivan@sisd.com 98-jan-20

added datatype (very kludgy and needs to be cleaned)
ivan@sisd.com 98-feb-21

perltrap (sigh) masked by mysql 3.20->3,21 ivan@sisd.com 98-mar-2

Change 'type' to 'atype' in agent_type
Changed attributes to special words which are changed in fs-setup
	ie. double(10,2) <=> MONEYTYPE
Changed order of some of the field definitions because Pg6.3 is picky
Changed 'day' to 'daytime' in cust_main
Changed type of tax from tinyint to real
Change 'password' to '_password' in svc_acct
Pg6.3 does not allow 'field char(x) NULL'
	bmccane@maxbaud.net	98-apr-3

rewrite: now properly OO.  See also FS::dbdef_{table,column,unique,index}

ivan@sisd.com 98-apr-17

gained some extra functions ivan@sisd.com 98-may-11

now knows how to Freeze and Thaw itself ivan@sisd.com 98-jun-2

pod ivan@sisd.com 98-sep-23

=cut

1;

