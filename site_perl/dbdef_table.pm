package FS::dbdef_table;

use strict;
#use Carp;
use Exporter;
use vars qw(@ISA);
use FS::dbdef_column;

@ISA = qw(Exporter);

=head1 NAME

FS::dbdef_table - Table objects

=head1 SYNOPSIS

  use FS::dbdef_table;

  $dbdef_table = new FS::dbdef_table (
    "table_name",
    "primary_key",
    $FS_dbdef_unique_object,
    $FS_dbdef_index_object,
    @FS_dbdef_column_objects,
  );

  $dbdef_table->addcolumn ( $FS_dbdef_column_object );

  $table_name = $dbdef_table->name;
  $dbdef_table->name ("table_name");

  $table_name = $dbdef_table->primary_keye;
  $dbdef_table->primary_key ("primary_key");

  $FS_dbdef_unique_object = $dbdef_table->unique;
  $dbdef_table->unique ( $FS_dbdef_unique_object );

  $FS_dbdef_index_object = $dbdef_table->index;
  $dbdef_table->index ( $FS_dbdef_index_object );

  @column_names = $dbdef->columns;

  $FS_dbdef_column_object = $dbdef->column;

  @sql_statements = $dbdef->sql_create_table;
  @sql_statements = $dbdef->sql_create_table $datasrc;

=head1 DESCRIPTION

FS::dbdef_table objects represent a single database table.

=head1 METHODS

=over 4

=item new

Creates a new FS::dbdef_table object.

=cut

sub new {
  my($proto,$name,$primary_key,$unique,$index,@columns)=@_;

  my(%columns) = map { $_->name, $_ } @columns;

  #check $primary_key, $unique and $index to make sure they are $columns ?
  # (and sanity check?)

  my $class = ref($proto) || $proto;
  my $self = {
    'name'        => $name,
    'primary_key' => $primary_key,
    'unique'      => $unique,
    'index'       => $index,
    'columns'     => \%columns,
  };

  bless ($self, $class);

}

=item addcolumn

Adds this FS::dbdef_column object. 

=cut

sub addcolumn {
  my($self,$column)=@_;
  ${$self->{'columns'}}{$column->name}=$column; #sanity check?
}

=item name

Returns or sets the table name.

=cut

sub name {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{name} = $value;
  } else {
    $self->{name};
  }
}

=item primary_key

Returns or sets the primary key.

=cut

sub primary_key {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{primary_key} = $value;
  } else {
    #$self->{primary_key};
    #hmm.  maybe should untaint the entire structure when it comes off disk 
    # cause if you don't trust that, ?
    $self->{primary_key} =~ /^(\w*)$/ 
      #aah!
      or die "Illegal primary key ", $self->{primary_key}, " in dbdef!\n";
    $1;
  }
}

=item unique

Returns or sets the FS::dbdef_unique object.

=cut

sub unique { 
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{unique} = $value;
  } else {
    $self->{unique};
  }
}

=item index

Returns or sets the FS::dbdef_index object.

=cut

sub index { 
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{'index'} = $value;
  } else {
    $self->{'index'};
  }
}

=item columns

Returns a list consisting of the names of all columns.

=cut

sub columns {
  my($self)=@_;
  keys %{$self->{'columns'}};
}

=item column "column"

Returns the column object (see L<FS::dbdef_column>) for "column".

=cut

sub column {
  my($self,$column)=@_;
  $self->{'columns'}->{$column};
}

=item sql_create_table [ $datasrc ]

Returns an array of SQL statments to create this table.

If passed a DBI $datasrc specifying L<DBD::mysql>, will use MySQL-specific
syntax.  Non-standard syntax for other engines (if applicable) may also be
supported in the future.

=cut

sub sql_create_table { 
  my($self,$datasrc)=@_;

  my(@columns)=map { $self->column($_)->line($datasrc) } $self->columns;
  push @columns, "PRIMARY KEY (". $self->primary_key. ")"
    if $self->primary_key;
  if ( $datasrc =~ /mysql/ ) { #yucky mysql hack
    push @columns, map "UNIQUE ($_)", $self->unique->sql_list;
    push @columns, map "INDEX ($_)", $self->index->sql_list;
  }

  "CREATE TABLE ". $self->name. " ( ". join(", ", @columns). " )",
  ( map {
    my($index) = $self->name. "__". $_ . "_index";
    $index =~ s/,\s*/_/g;
    "CREATE UNIQUE INDEX $index ON ". $self->name. " ($_)"
  } $self->unique->sql_list ),
  ( map {
    my($index) = $self->name. "__". $_ . "_index";
    $index =~ s/,\s*/_/g;
    "CREATE INDEX $index ON ". $self->name. " ($_)"
  } $self->index->sql_list ),
  ;  


}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::dbdef>, L<FS::dbdef_unique>, L<FS::dbdef_index>, L<FS::dbdef_unique>,
L<DBI>

=head1 VERSION

$Id: dbdef_table.pm,v 1.2 1998-10-14 07:05:06 ivan Exp $

=head1 HISTORY

class for dealing with table definitions

ivan@sisd.com 98-apr-18

gained extra functions (should %columns be an IxHash?)
ivan@sisd.com 98-may-11

sql_create_table returns a list of statments, not just one, and now it
does indices (plus mysql hack) ivan@sisd.com 98-jun-2

untaint primary_key... hmm.  is this a hack around a bigger problem?
looks like, did the same thing singles in colgroup!
ivan@sisd.com 98-jun-4

pod ivan@sisd.com 98-sep-24

$Log: dbdef_table.pm,v $
Revision 1.2  1998-10-14 07:05:06  ivan
1.1.4 release, fix postgresql


=cut

1;

