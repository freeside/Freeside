package DBIx::DBSchema::Table;

use strict;
use vars qw(@ISA %create_params);
#use Carp;
#use Exporter;
use DBIx::DBSchema::Column 0.02;
use DBIx::DBSchema::ColGroup::Unique;
use DBIx::DBSchema::ColGroup::Index;

#@ISA = qw(Exporter);
@ISA = qw();

=head1 NAME

DBIx::DBSchema::Table - Table objects

=head1 SYNOPSIS

  use DBIx::DBSchema::Table;

  #old style (depriciated)
  $table = new DBIx::DBSchema::Table (
    "table_name",
    "primary_key",
    $dbix_dbschema_colgroup_unique_object,
    $dbix_dbschema_colgroup_index_object,
    @dbix_dbschema_column_objects,
  );

  #new style (preferred), pass a hashref of parameters
  $table = new DBIx::DBSchema::Table (
    {
      name        => "table_name",
      primary_key => "primary_key",
      unique      => $dbix_dbschema_colgroup_unique_object,
      'index'     => $dbix_dbschema_colgroup_index_object,
      columns     => \@dbix_dbschema_column_objects,
    }
  );

  $table->addcolumn ( $dbix_dbschema_column_object );

  $table_name = $table->name;
  $table->name("table_name");

  $primary_key = $table->primary_key;
  $table->primary_key("primary_key");

  $dbix_dbschema_colgroup_unique_object = $table->unique;
  $table->unique( $dbix_dbschema__colgroup_unique_object );

  $dbix_dbschema_colgroup_index_object = $table->index;
  $table->index( $dbix_dbschema_colgroup_index_object );

  @column_names = $table->columns;

  $dbix_dbschema_column_object = $table->column("column");

  #preferred
  @sql_statements = $table->sql_create_table( $dbh );
  @sql_statements = $table->sql_create_table( $datasrc, $username, $password );

  #possible problems
  @sql_statements = $table->sql_create_table( $datasrc );
  @sql_statements = $table->sql_create_table;

=head1 DESCRIPTION

DBIx::DBSchema::Table objects represent a single database table.

=head1 METHODS

=over 4

=item new [ TABLE_NAME [ , PRIMARY_KEY [ , UNIQUE [ , INDEX [ , COLUMN... ] ] ] ] ]

=item new HASHREF

Creates a new DBIx::DBSchema::Table object.  The preferred usage is to pass a
hash reference of named parameters.

  {
    name        => TABLE_NAME,
    primary_key => PRIMARY_KEY,
    unique      => UNIQUE,
    'index'     => INDEX,
    columns     => COLUMNS
  }

TABLE_NAME is the name of the table.  PRIMARY_KEY is the primary key (may be
empty).  UNIQUE is a DBIx::DBSchema::ColGroup::Unique object (see
L<DBIx::DBSchema::ColGroup::Unique>).  INDEX is a
DBIx::DBSchema::ColGroup::Index object (see
L<DBIx::DBSchema::ColGroup::Index>).  COLUMNS is a reference to an array of
DBIx::DBSchema::Column objects (see L<DBIx::DBSchema::Column>).

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self;
  if ( ref($_[0]) ) {

    $self = shift;
    $self->{column_order} = [ map { $_->name } @{$self->{columns}} ];
    $self->{columns} = { map { $_->name, $_ } @{$self->{columns}} };

  } else {

    my($name,$primary_key,$unique,$index,@columns) = @_;

    my %columns = map { $_->name, $_ } @columns;
    my @column_order = map { $_->name } @columns;

    $self = {
      'name'         => $name,
      'primary_key'  => $primary_key,
      'unique'       => $unique,
      'index'        => $index,
      'columns'      => \%columns,
      'column_order' => \@column_order,
    };

  }

  #check $primary_key, $unique and $index to make sure they are $columns ?
  # (and sanity check?)

  bless ($self, $class);

}

=item new_odbc DATABASE_HANDLE TABLE_NAME

Creates a new DBIx::DBSchema::Table object from the supplied DBI database
handle for the specified table.  This uses the experimental DBI type_info
method to create a table with standard (ODBC) SQL column types that most
closely correspond to any non-portable column types.   Use this to import a
schema that you wish to use with many different database engines.  Although
primary key and (unique) index information will only be imported from databases
with DBIx::DBSchema::DBD drivers (currently MySQL and PostgreSQL), import of
column names and attributes *should* work for any database.

Note: the _odbc refers to the column types used and nothing else - you do not
have to have ODBC installed or connect to the database via ODBC.

=cut

%create_params = (
#  undef             => sub { '' },
  ''                => sub { '' },
  'max length'      => sub { $_[0]->{PRECISION}->[$_[1]]; },
  'precision,scale' =>
    sub { $_[0]->{PRECISION}->[$_[1]]. ','. $_[0]->{SCALE}->[$_[1]]; }
);

sub new_odbc {
  my( $proto, $dbh, $name) = @_;
  my $driver = DBIx::DBSchema::_load_driver($dbh);
  my $sth = _null_sth($dbh, $name);
  my $sthpos = 0;
  $proto->new (
    $name,
    scalar(eval "DBIx::DBSchema::DBD::$driver->primary_key(\$dbh, \$name)"),
    DBIx::DBSchema::ColGroup::Unique->new(
      $driver
       ? [values %{eval "DBIx::DBSchema::DBD::$driver->unique(\$dbh, \$name)"}]
       : []
    ),
    DBIx::DBSchema::ColGroup::Index->new(
      $driver
      ? [ values %{eval "DBIx::DBSchema::DBD::$driver->index(\$dbh, \$name)"} ]
      : []
    ),
    map { 
      my $type_info = scalar($dbh->type_info($sth->{TYPE}->[$sthpos]))
        or die "DBI::type_info ". $dbh->{Driver}->{Name}. " driver ".
               "returned no results for type ".  $sth->{TYPE}->[$sthpos];
      new DBIx::DBSchema::Column
          $_,
          $type_info->{'TYPE_NAME'},
          #"SQL_". uc($type_info->{'TYPE_NAME'}),
          $sth->{NULLABLE}->[$sthpos],
          &{ $create_params{ $type_info->{CREATE_PARAMS} } }( $sth, $sthpos++ ),          $driver && #default
            ${ [
              eval "DBIx::DBSchema::DBD::$driver->column(\$dbh, \$name, \$_)"
            ] }[4]
          # DB-local
    } @{$sth->{NAME}}
  );
}

=item new_native DATABASE_HANDLE TABLE_NAME

Creates a new DBIx::DBSchema::Table object from the supplied DBI database
handle for the specified table.  This uses database-native methods to read the
schema, and will preserve any non-portable column types.  The method is only
available if there is a DBIx::DBSchema::DBD for the corresponding database
engine (currently, MySQL and PostgreSQL).

=cut

sub new_native {
  my( $proto, $dbh, $name) = @_;
  my $driver = DBIx::DBSchema::_load_driver($dbh);
  $proto->new (
    $name,
    scalar(eval "DBIx::DBSchema::DBD::$driver->primary_key(\$dbh, \$name)"),
    DBIx::DBSchema::ColGroup::Unique->new(
      [ values %{eval "DBIx::DBSchema::DBD::$driver->unique(\$dbh, \$name)"} ]
    ),
    DBIx::DBSchema::ColGroup::Index->new(
      [ values %{eval "DBIx::DBSchema::DBD::$driver->index(\$dbh, \$name)"} ]
    ),
    map {
      DBIx::DBSchema::Column->new( @{$_} )
    } eval "DBIx::DBSchema::DBD::$driver->columns(\$dbh, \$name)"
  );
}

=item addcolumn COLUMN

Adds this DBIx::DBSchema::Column object. 

=cut

sub addcolumn {
  my($self,$column)=@_;
  ${$self->{'columns'}}{$column->name}=$column; #sanity check?
  push @{$self->{'column_order'}}, $column->name;
}

=item delcolumn COLUMN_NAME

Deletes this column.  Returns false if no column of this name was found to
remove, true otherwise.

=cut

sub delcolumn {
  my($self,$column) = @_;
  return 0 unless exists $self->{'columns'}{$column};
  delete $self->{'columns'}{$column};
  @{$self->{'column_order'}}= grep { $_ ne $column } @{$self->{'column_order'}};  1;
}

=item name [ TABLE_NAME ]

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

=item primary_key [ PRIMARY_KEY ]

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
      or die "Illegal primary key: ", $self->{primary_key};
    $1;
  }
}

=item unique [ UNIQUE ]

Returns or sets the DBIx::DBSchema::ColGroup::Unique object.

=cut

sub unique { 
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{unique} = $value;
  } else {
    $self->{unique};
  }
}

=item index [ INDEX ]

Returns or sets the DBIx::DBSchema::ColGroup::Index object.

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
  #keys %{$self->{'columns'}};
  #must preserve order
  @{ $self->{'column_order'} };
}

=item column COLUMN_NAME

Returns the column object (see L<DBIx::DBSchema::Column>) for the specified
COLUMN_NAME.

=cut

sub column {
  my($self,$column)=@_;
  $self->{'columns'}->{$column};
}

=item sql_create_table [ DATABASE_HANDLE | DATA_SOURCE [ USERNAME PASSWORD [ ATTR ] ] ]

Returns a list of SQL statments to create this table.

The data source can be specified by passing an open DBI database handle, or by
passing the DBI data source name, username and password.  

Although the username and password are optional, it is best to call this method
with a database handle or data source including a valid username and password -
a DBI connection will be opened and the quoting and type mapping will be more
reliable.

If passed a DBI data source (or handle) such as `DBI:mysql:database', will use
MySQL- or PostgreSQL-specific syntax.  Non-standard syntax for other engines
(if applicable) may also be supported in the future.

=cut

sub sql_create_table { 
  my($self, $dbh) = (shift, shift);

  my $created_dbh = 0;
  unless ( ref($dbh) || ! @_ ) {
    $dbh = DBI->connect( $dbh, @_ ) or die $DBI::errstr;
    my $gratuitous = $DBI::errstr; #surpress superfluous `used only once' error
    $created_dbh = 1;
  }
  #false laziness: nicked from DBSchema::_load_driver
  my $driver;
  if ( ref($dbh) ) {
    $driver = $dbh->{Driver}->{Name};
  } else {
    my $discard = $dbh;
    $discard =~ s/^dbi:(\w*?)(?:\((.*?)\))?://i #nicked from DBI->connect
                        or '' =~ /()/; # ensure $1 etc are empty if match fails
    $driver = $1 or die "can't parse data source: $dbh";
  }
  #eofalse

#should be in the DBD somehwere :/
#  my $saved_pkey = '';
#  if ( $driver eq 'Pg' && $self->primary_key ) {
#    my $pcolumn = $self->column( (
#      grep { $self->column($_)->name eq $self->primary_key } $self->columns
#    )[0] );
##AUTO-INCREMENT#    $pcolumn->type('serial') if lc($pcolumn->type) eq 'integer';
#    $pcolumn->local( $pcolumn->local. ' PRIMARY KEY' );
#    #my $saved_pkey = $self->primary_key;
#    #$self->primary_key('');
#    #change it back afterwords :/
#  }

  my @columns = map { $self->column($_)->line($dbh) } $self->columns;

  push @columns, "PRIMARY KEY (". $self->primary_key. ")"
    #if $self->primary_key && $driver ne 'Pg';
    if $self->primary_key;

  my $indexnum = 1;

  my @r = (
    "CREATE TABLE ". $self->name. " (\n  ". join(",\n  ", @columns). "\n)\n"
  );

  push @r, map {
                 #my($index) = $self->name. "__". $_ . "_idx";
                 #$index =~ s/,\s*/_/g;
                 my $index = $self->name. $indexnum++;
                 "CREATE UNIQUE INDEX $index ON ". $self->name. " ($_)\n"
               } $self->unique->sql_list
    if $self->unique;

  push @r, map {
                 #my($index) = $self->name. "__". $_ . "_idx";
                 #$index =~ s/,\s*/_/g;
                 my $index = $self->name. $indexnum++;
                 "CREATE INDEX $index ON ". $self->name. " ($_)\n"
               } $self->index->sql_list
    if $self->index;

  #$self->primary_key($saved_pkey) if $saved_pkey;
  $dbh->disconnect if $created_dbh;
  @r;
}

#

sub _null_sth {
  my($dbh, $table) = @_;
  my $sth = $dbh->prepare("SELECT * FROM $table WHERE 1=0")
    or die $dbh->errstr;
  $sth->execute or die $sth->errstr;
  $sth;
}

=back

=head1 AUTHOR

Ivan Kohler <ivan-dbix-dbschema@420.am>

Thanks to Mark Ethan Trostler <mark@zzo.com> for a patch to allow tables
with no indices.

=head1 COPYRIGHT

Copyright (c) 2000 Ivan Kohler
Copyright (c) 2000 Mail Abuse Prevention System LLC
All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 BUGS

sql_create_table() has database-specific foo that probably ought to be
abstracted into the DBIx::DBSchema::DBD:: modules.

sql_create_table may change or destroy the object's data.  If you need to use
the object after sql_create_table, make a copy beforehand.

Some of the logic in new_odbc might be better abstracted into Column.pm etc.

=head1 SEE ALSO

L<DBIx::DBSchema>, L<DBIx::DBSchema::ColGroup::Unique>,
L<DBIx::DBSchema::ColGroup::Index>, L<DBIx::DBSchema::Column>, L<DBI>

=cut

1;

