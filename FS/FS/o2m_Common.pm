package FS::o2m_Common;

use strict;
use vars qw( $DEBUG $me );
use Carp;
use FS::Schema qw( dbdef );
use FS::Record qw( qsearch qsearchs dbh );

$DEBUG = 0;

$me = '[FS::o2m_Common]';

=head1 NAME

FS::o2m_Common - Mixin class for tables with a related table

=head1 SYNOPSIS

use FS::o2m_Common;

@ISA = qw( FS::o2m_Common FS::Record );

=head1 DESCRIPTION

FS::o2m_Common is intended as a mixin class for classes which have a
related table.

=head1 METHODS

=over 4

=item process_o2m OPTION => VALUE, ...

Available options:

table (required) - Table into which the records are inserted.

num_col (optional) - Column in table which links to the primary key of the base table.  If not specified, it is assumed this has the same name.

params (required) - Hashref of keys and values, often passed as C<scalar($cgi->Vars)> from a form.

fields (required) - Arrayref of field names for each record in table.  Pulled from params as "pkeyNN_field" where pkey is table's primary key and NN is the entry's numeric identifier.

=cut

#a little more false laziness w/m2m_Common.pm than m2_name_Common.pm
# still, far from the worse of it.  at least we're a reuable mixin!
sub process_o2m {
  my( $self, %opt ) = @_;

  my $self_pkey = $self->dbdef_table->primary_key;
  my $link_sourcekey = $opt{'num_col'} || $self_pkey;

  my $hashref = {}; #$opt{'hashref'} || {};
  $hashref->{$link_sourcekey} = $self->$self_pkey();

  my $table = $self->_load_table($opt{'table'});
  my $table_pkey = dbdef->table($table)->primary_key;

#  my $link_static = $opt{'link_static'} || {};

  warn "$me processing o2m from ". $self->table. ".$link_sourcekey".
       " to $table\n"
    if $DEBUG;

  #if ( ref($opt{'params'}) eq 'ARRAY' ) {
  #  $opt{'params'} = { map { $_=>1 } @{$opt{'params'}} };
  #}

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my @fields = grep { /^$table_pkey\d+$/ }
               keys %{ $opt{'params'} };

  my %edits = map  { $opt{'params'}->{$_} => $_ }
              grep { $opt{'params'}->{$_} }
              @fields;

  foreach my $del_obj (
    grep { ! $edits{$_->$table_pkey()} }
         qsearch( $table, $hashref )
  ) {
    my $error = $del_obj->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $pkey_value ( keys %edits ) {
    my $old_obj = qsearchs( $table, { %$hashref, $table_pkey => $pkey_value } ),
    my $add_param = $edits{$pkey_value};
    my %hash = ( $table_pkey => $pkey_value,
                 map { $_ => $opt{'params'}->{$add_param."_$_"} }
                     @{ $opt{'fields'} }
               );
    #next unless grep { $_ =~ /\S/ } values %hash;

    my $new_obj = "FS::$table"->new( { %$hashref, %hash } );
    my $error = $new_obj->replace($old_obj);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $add_param ( grep { ! $opt{'params'}->{$_} } @fields ) {

    my %hash = map { $_ => $opt{'params'}->{$add_param."_$_"} }
               @{ $opt{'fields'} };
    next unless grep { $_ =~ /\S/ } values %hash;

    my $add_obj = "FS::$table"->new( { %$hashref, %hash } );
    my $error = $add_obj->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
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

