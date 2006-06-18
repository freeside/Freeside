package FS::m2name_Common;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Schema qw( dbdef );
use FS::Record qw( qsearch qsearchs ); #dbh );

@ISA = qw( FS::Record );

$DEBUG = 0;

=head1 NAME

FS::m2name_Common - Base class for tables with a related table listing names

=head1 SYNOPSIS

use FS::m2name_Common;

@ISA = qw( FS::m2name_Common );

=head1 DESCRIPTION

FS::m2name_Common is intended as a base class for classes which have a
related table that lists names.

=head1 METHODS

=over 4

=item process_m2name

=cut

sub process_m2name {
  my( $self, %opt ) = @_;

  my $self_pkey = $self->dbdef_table->primary_key;
  my $link_sourcekey = $opt{'num_col'} || $self_pkey;

  my $link_table = $self->_load_table($opt{'link_table'});

  my $link_static = $opt{'link_static'} || {};

  foreach my $name ( @{ $opt{'names_list'} } ) {

    my $obj = qsearchs( $link_table, {
        $link_sourcekey  => $self->$self_pkey(),
        $opt{'name_col'} => $name,
        %$link_static,
    });

    if ( $obj && ! $opt{'params'}->{"$link_table.$name"} ) {

      my $d_obj = $obj; #need to save $obj for below.
      my $error = $d_obj->delete;
      die "error deleting $d_obj for $link_table.$name: $error" if $error;

    } elsif ( $opt{'params'}->{"$link_table.$name"} && ! $obj ) {

      #ok to clobber it now (but bad form nonetheless?)
      #$obj = new "FS::$link_table" ( {
      $obj = "FS::$link_table"->new( {
        $link_sourcekey  => $self->$self_pkey(),
        $opt{'name_col'} => $name,
        %$link_static,
      });
      my $error = $obj->insert;
      die "error inserting $obj for $link_table.$name: $error" if $error;
    }

  }

  '';
}

sub _load_table {
  my( $self, $table ) = @_;
  eval "use FS::$table";
  die $@ if $@;
  $table;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

