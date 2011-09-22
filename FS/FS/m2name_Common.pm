package FS::m2name_Common;

use strict;
use vars qw( $DEBUG $me );
use Carp;
use FS::Schema qw( dbdef );
use FS::Record qw( qsearchs ); #qsearch dbh );

$DEBUG = 0;

$me = '[FS::m2name_Common]';

=head1 NAME

FS::m2name_Common - Mixin class for tables with a related table listing names

=head1 SYNOPSIS

    use base qw( FS::m2name_Common FS::Record );

=head1 DESCRIPTION

FS::m2name_Common is intended as a mixin class for classes which have a
related table that lists names.

=head1 METHODS

=over 4

=item process_m2name OPTION => VALUE, ...

Available options:

link_table (required) - Table into which the records are inserted.

num_col (optional) - Column in link_table which links to the primary key of the base table.  If not specified, it is assumed this has the same name.

name_col (required) - Name of the column in link_table that stores the string names.

names_list (required) - List reference of the possible string name values.

params (required) - Hashref of keys and values, often passed as C<scalar($cgi->Vars)> from a form.  Processing is controlled by the B<param_style param> option.

param_style (required) - Controls processing of B<params>.  I<'link_table.value checkboxes'> specifies that parameters keys are in the form C<link_table.name>, and the values are booleans controlling whether or not to insert that name into link_table.  I<'name_colN values'> specifies that parameter keys are in the form C<name_col0>, C<name_col1>, and so on, and values are the names inserted into link_table.

args_callback (optional) - Coderef.  Optional callback that may modify arguments for insert and replace operations.  The callback is run with four arguments: the first argument is object being inserted or replaced (i.e. FS::I<link_table> object), the second argument is a prefix to use when retreiving CGI arguements from the params hashref, the third argument is the params hashref (see above), and the final argument is a listref of arguments that the callback should modify.

=cut

sub process_m2name {
  my( $self, %opt ) = @_;

  my $self_pkey = $self->dbdef_table->primary_key;
  my $link_sourcekey = $opt{'num_col'} || $self_pkey;

  my $link_table = $self->_load_table($opt{'link_table'});

  my $link_static = $opt{'link_static'} || {};

  warn "$me processing m2name from ". $self->table. ".$link_sourcekey".
       " to $link_table\n"
    if $DEBUG;

  foreach my $name ( @{ $opt{'names_list'} } ) {

    warn "$me   checking $name\n" if $DEBUG;

    my $name_col = $opt{'name_col'};

    my $obj = qsearchs( $link_table, {
        $link_sourcekey  => $self->$self_pkey(),
        $name_col        => $name,
        %$link_static,
    });

    my $param = '';
    my $prefix = '';
    if ( $opt{'param_style'} =~ /link_table.value\s+checkboxes/i ) {
      #access_group.html style
      my $paramname = "$link_table.$name";
      $param = $opt{'params'}->{$paramname};
    } elsif ( $opt{'param_style'} =~ /name_colN values/i ) {
      #part_event.html style
      
      my @fields = grep { /^$name_col\d+$/ }
                        keys %{$opt{'params'}};

      $param = grep { $name eq $opt{'params'}->{$_} } @fields;

      if ( $param ) {
        #this depends on their being one condition per name...
        #which needs to be enforced on the edit page...
        #(it is on part_event and access_group edit)
        foreach my $field (@fields) {
          $prefix = "$field." if $name eq $opt{'params'}->{$field};
        }
        warn "$me     prefix $prefix\n" if $DEBUG;
      }
    } else { #??
      croak "unknown param_style: ". $opt{'param_style'};
      $param = $opt{'params'}->{$name};
    }

    if ( $obj && ! $param ) {

      warn "$me   deleting $name\n" if $DEBUG;

      my $d_obj = $obj; #need to save $obj for below.
      my $error = $d_obj->delete;
      die "error deleting $d_obj for $link_table.$name: $error" if $error;

    } elsif ( $param && ! $obj ) {

      warn "$me   inserting $name\n" if $DEBUG;

      #ok to clobber it now (but bad form nonetheless?)
      #$obj = new "FS::$link_table" ( {
      $obj = "FS::$link_table"->new( {
        $link_sourcekey  => $self->$self_pkey(),
        $opt{'name_col'} => $name,
        %$link_static,
      });

      my @args = ();
      if ( $opt{'args_callback'} ) { #edit/process/part_event.html
        &{ $opt{'args_callback'} }( $obj,
                                    $prefix,
                                    $opt{'params'},
                                    \@args
                                  );
      }

      my $error = $obj->insert( @args );
      die "error inserting $obj for $link_table.$name: $error" if $error;

    } elsif ( $param && $obj && $opt{'args_callback'} ) {

      my @args = ();
      if ( $opt{'args_callback'} ) { #edit/process/part_event.html
        &{ $opt{'args_callback'} }( $obj,
                                    $prefix,
                                    $opt{'params'},
                                    \@args
                                  );
      }

      my $error = $obj->replace( $obj, @args );
      die "error replacing $obj for $link_table.$name: $error" if $error;

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

