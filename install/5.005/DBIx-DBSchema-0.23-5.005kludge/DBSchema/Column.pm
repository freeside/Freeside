package DBIx::DBSchema::Column;

use strict;
use vars qw(@ISA $VERSION);
#use Carp;
#use Exporter;

#@ISA = qw(Exporter);
@ISA = qw();

$VERSION = '0.02';

=head1 NAME

DBIx::DBSchema::Column - Column objects

=head1 SYNOPSIS

  use DBIx::DBSchema::Column;

  #named params with a hashref (preferred)
  $column = new DBIx::DBSchema::Column ( {
    'name'    => 'column_name',
    'type'    => 'varchar'
    'null'    => 'NOT NULL',
    'length'  => 64,
    'default' => '
    'local'   => '',
  } );

  #list
  $column = new DBIx::DBSchema::Column ( $name, $sql_type, $nullability, $length, $default, $local );

  $name = $column->name;
  $column->name( 'name' );

  $sql_type = $column->type;
  $column->type( 'sql_type' );

  $null = $column->null;
  $column->null( 'NULL' );
  $column->null( 'NOT NULL' );
  $column->null( '' );

  $length = $column->length;
  $column->length( '10' );
  $column->length( '8,2' );

  $default = $column->default;
  $column->default( 'Roo' );

  $sql_line = $column->line;
  $sql_line = $column->line($datasrc);

=head1 DESCRIPTION

DBIx::DBSchema::Column objects represent columns in tables (see
L<DBIx::DBSchema::Table>).

=head1 METHODS

=over 4

=item new HASHREF

=item new [ name [ , type [ , null [ , length  [ , default [ , local ] ] ] ] ] ]

Creates a new DBIx::DBSchema::Column object.  Takes a hashref of named
parameters, or a list.  B<name> is the name of the column.  B<type> is the SQL
data type.  B<null> is the nullability of the column (intrepreted using Perl's
rules for truth, with one exception: `NOT NULL' is false).  B<length> is the
SQL length of the column.  B<default> is the default value of the column.
B<local> is reserved for database-specific information.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self;
  if ( ref($_[0]) ) {
    $self = shift;
  } else {
    $self = { map { $_ => shift } qw(name type null length default local) };
  }

  #croak "Illegal name: ". $self->{'name'}
  #  if grep $self->{'name'} eq $_, @reserved_words;

  $self->{'null'} =~ s/^NOT NULL$//i;
  $self->{'null'} = 'NULL' if $self->{'null'};

  bless ($self, $class);

}

=item name [ NAME ]

Returns or sets the column name.

=cut

sub name {
  my($self,$value)=@_;
  if ( defined($value) ) {
  #croak "Illegal name: $name" if grep $name eq $_, @reserved_words;
    $self->{'name'} = $value;
  } else {
    $self->{'name'};
  }
}

=item type [ TYPE ]

Returns or sets the column type.

=cut

sub type {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{'type'} = $value;
  } else {
    $self->{'type'};
  }
}

=item null [ NULL ]

Returns or sets the column null flag (the empty string is equivalent to
`NOT NULL')

=cut

sub null {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $value =~ s/^NOT NULL$//i;
    $value = 'NULL' if $value;
    $self->{'null'} = $value;
  } else {
    $self->{'null'};
  }
}

=item length [ LENGTH ]

Returns or sets the column length.

=cut

sub length {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{'length'} = $value;
  } else {
    $self->{'length'};
  }
}

=item default [ LOCAL ]

Returns or sets the default value.

=cut

sub default {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{'default'} = $value;
  } else {
    $self->{'default'};
  }
}


=item local [ LOCAL ]

Returns or sets the database-specific field.

=cut

sub local {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{'local'} = $value;
  } else {
    $self->{'local'};
  }
}

=item line [ DATABASE_HANDLE | DATA_SOURCE [ USERNAME PASSWORD [ ATTR ] ] ]

Returns an SQL column definition.

The data source can be specified by passing an open DBI database handle, or by
passing the DBI data source name, username and password.  

Although the username and password are optional, it is best to call this method
with a database handle or data source including a valid username and password -
a DBI connection will be opened and the quoting and type mapping will be more
reliable.

If passed a DBI data source (or handle) such as `DBI:mysql:database' or
`DBI:Pg:dbname=database', will use syntax specific to that database engine.
Currently supported databases are MySQL and PostgreSQL.  Non-standard syntax
for other engines (if applicable) may also be supported in the future.

=cut

sub line {
  my($self,$dbh) = (shift, shift);

  my $created_dbh = 0;
  unless ( ref($dbh) || ! @_ ) {
    $dbh = DBI->connect( $dbh, @_ ) or die $DBI::errstr;
    my $gratuitous = $DBI::errstr; #surpress superfluous `used only once' error
    $created_dbh = 1;
  }
  
  my $driver = DBIx::DBSchema::_load_driver($dbh);
  my %typemap;
  %typemap = eval "\%DBIx::DBSchema::DBD::${driver}::typemap" if $driver;
  my $type = defined( $typemap{uc($self->type)} )
    ? $typemap{uc($self->type)}
    : $self->type;

  my $null = $self->null;

  my $default;
  if ( defined($self->default) && $self->default ne ''
       && ref($dbh)
       # false laziness: nicked from FS::Record::_quote
       && ( $self->default !~ /^\-?\d+(\.\d+)?$/
            || $type =~ /(char|binary|blob|text)$/i
          )
  ) {
    $default = $dbh->quote($self->default);
  } else {
    $default = $self->default;
  }

  #this should be a callback into the driver
  if ( $driver eq 'mysql' ) { #yucky mysql hack
    $null ||= "NOT NULL";
    $self->local('AUTO_INCREMENT') if uc($self->type) eq 'SERIAL';
  } elsif ( $driver eq 'Pg' ) { #yucky Pg hack
    $null ||= "NOT NULL";
    $null =~ s/^NULL$//;
  }

  my $r = join(' ',
    $self->name,
    $type. ( ( defined($self->length) && $self->length )
             ? '('.$self->length.')'
             : ''
           ),
    $null,
    ( ( defined($default) && $default ne '' )
      ? 'DEFAULT '. $default
      : ''
    ),
    ( ( $driver eq 'mysql' && defined($self->local) )
      ? $self->local
      : ''
    ),
  );
  $dbh->disconnect if $created_dbh;
  $r;

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

line() has database-specific foo that probably ought to be abstracted into
the DBIx::DBSchema:DBD:: modules.

=head1 SEE ALSO

L<DBIx::DBSchema::Table>, L<DBIx::DBSchema>, L<DBIx::DBSchema::DBD>, L<DBI>

=cut

1;

