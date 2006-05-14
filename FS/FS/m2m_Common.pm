package FS::m2m_Common;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Schema qw( dbdef );
use FS::Record qw( qsearch qsearchs ); #dbh );

@ISA = qw( FS::Record );

$DEBUG = 0;

=head1 NAME

FS::m2m_Common - Base class for classes in a many-to-many relationship

=head1 SYNOPSIS

use FS::m2m_Common;

@ISA = qw( FS::m2m_Common );

=head1 DESCRIPTION

FS::m2m_Common is intended as a base class for classes which have a
many-to-many relationship with another table (via a linking table).

Note: It is currently assumed that the link table contains two fields
named the same as the primary keys of ths base and target tables.

=head1 METHODS

=over 4

=item process_m2m

=cut

sub process_m2m {
  my( $self, %opt ) = @_;

  my $self_pkey = $self->dbdef_table->primary_key;

  my $link_table = $self->_load_table($opt{'link_table'});

  my $target_table = $self->_load_table($opt{'target_table'});
  my $target_pkey = dbdef->table($target_table)->primary_key;

  foreach my $target_obj ( qsearch($target_table, {} ) ) {

    my $targetnum = $target_obj->$target_pkey();

    my $link_obj = qsearchs( $link_table, {
        $self_pkey   => $self->$self_pkey(),
        $target_pkey => $targetnum,
    });

    if ( $link_obj && ! $opt{'params'}->{"$target_pkey$targetnum"} ) {

      my $d_link_obj = $link_obj; #need to save $link_obj for below.
      my $error = $d_link_obj->delete;
      die $error if $error;

    } elsif ( $opt{'params'}->{"$target_pkey$targetnum"} && ! $link_obj ) {

      #ok to clobber it now (but bad form nonetheless?)
      #$link_obj = new "FS::$link_table" ( {
      $link_obj = "FS::$link_table"->new( {
        $self_pkey   => $self->$self_pkey(),
        $target_pkey => $targetnum,
      });
      my $error = $link_obj->insert;
      die $error if $error;
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

#=item target_table
#
#=cut
#
#sub target_table {
#  my $self = shift;
#  my $target_table = $self->_target_table;
#  eval "use FS::$target_table";
#  die $@ if $@;
#  $target_table;
#}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

