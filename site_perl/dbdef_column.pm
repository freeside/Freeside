package FS::dbdef_column;

use strict;
#use Carp;
use Exporter;
use vars qw(@ISA);

@ISA = qw(Exporter);

=head1 NAME

FS::dbdef_column - Column object

=head1 SYNOPSIS

  use FS::dbdef_column;

  $column_object = new FS::dbdef_column ( $name, $sql_type, '' );
  $column_object = new FS::dbdef_column ( $name, $sql_type, 'NULL' );
  $column_object = new FS::dbdef_column ( $name, $sql_type, '', $length );
  $column_object = new FS::dbdef_column ( $name, $sql_type, 'NULL', $length );

  $name = $column_object->name;
  $column_object->name ( 'name' );

  $name = $column_object->type;
  $column_object->name ( 'sql_type' );

  $name = $column_object->null;
  $column_object->name ( 'NOT NULL' );

  $name = $column_object->length;
  $column_object->name ( $length );

  $sql_line = $column->line;
  $sql_line = $column->line $datasrc;

=head1 DESCRIPTION

FS::dbdef::column objects represend columns in tables (see L<FS::dbdef_table>).

=head1 METHODS

=over 4

=item new

Creates a new FS::dbdef_column object.

=cut

sub new {
  my($proto,$name,$type,$null,$length)=@_;

  #croak "Illegal name: $name" if grep $name eq $_, @reserved_words;

  $null =~ s/^NOT NULL$//i;

  my $class = ref($proto) || $proto;
  my $self = {
    'name'   => $name,
    'type'   => $type,
    'null'   => $null,
    'length' => $length,
  };

  bless ($self, $class);

}

=item name

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

=item type

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

=item null

Returns or sets the column null flag.

=cut

sub null {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $value =~ s/^NOT NULL$//i;
    $self->{'null'} = $value;
  } else {
    $self->{'null'};
  }
}

=item type

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

=item line [ $datasrc ]

Returns an SQL column definition.

If passed a DBI $datasrc specifying L<DBD::mysql> or L<DBD::Pg>, will use
engine-specific syntax.

=cut

sub line {
  my($self,$datasrc)=@_;
  my($null)=$self->null;
  if ( $datasrc =~ /mysql/ ) { #yucky mysql hack
    $null ||= "NOT NULL"
  }
  if ( $datasrc =~ /Pg/ ) { #yucky Pg hack
    $null ||= "NOT NULL";
    $null =~ s/^NULL$//;
  }
  join(' ',
    $self->name,
    $self->type. ( $self->length ? '('.$self->length.')' : '' ),
    $null,
  );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::dbdef_table>, L<FS::dbdef>, L<DBI>

=head1 VERSION

$Id: dbdef_column.pm,v 1.3 1998-10-13 13:04:17 ivan Exp $

=head1 HISTORY

class for dealing with column definitions

ivan@sisd.com 98-apr-17

now methods can be used to get or set data ivan@sisd.com 98-may-11

mySQL-specific hack for null (what should be default?) ivan@sisd.com 98-jun-2

$Log: dbdef_column.pm,v $
Revision 1.3  1998-10-13 13:04:17  ivan
fixed doc to indicate Pg specific syntax too

Revision 1.2  1998/10/12 23:40:28  ivan
added Pg-specific behaviour in sub line


=cut

1;

