package FS::option_Common;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Record qw( qsearch qsearchs dbh );

@ISA = qw( FS::Record );

$DEBUG = 0;

=head1 NAME

FS::option_Common - Base class for option sub-classes

=head1 SYNOPSIS

use FS::option_Common;

@ISA = qw( FS::option_Common );

=head1 DESCRIPTION

FS::option_Common is intended as a base class for classes which have a
simple one-to-many class associated with them, used to store a hash-like data
structure of keys and values.

=head1 METHODS

=over 4

=item insert [ HASHREF | OPTION => VALUE ... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If a list or hash reference of options is supplied, option records are also
created.

=cut

#false laziness w/queue.pm
sub insert {
  my $self = shift;
  my $options = 
    ( ref($_[0]) eq 'HASH' )
      ? shift
      : { @_ };
  warn "FS::option_Common::insert called on $self with options ".
       join(', ', map "$_ => ".$options->{$_}, keys %$options)
    if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $pkey = $self->pkey;
  my $option_table = $self->option_table;

  foreach my $optionname ( keys %{$options} ) {
    my $href = {
      $pkey         => $self->get($pkey),
      'optionname'  => $optionname,
      'optionvalue' => $options->{$optionname},
    };

    #my $option_record = eval "new FS::$option_table \$href";
    #if ( $@ ) {
    #  $dbh->rollback if $oldAutoCommit;
    #  return $@;
    #}
    my $option_record = "FS::$option_table"->new($href);

    $error = $option_record->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Delete this record from the database.  Any associated option records are also
deleted.

=cut

#foreign keys would make this much less tedious... grr dumb mysql
sub delete {
  my $self = shift;
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  
  my $pkey = $self->pkey;
  #my $option_table = $self->option_table;

  foreach my $obj ( $self->option_objects ) {
    my $error = $obj->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace [ HASHREF | OPTION => VALUE ... ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If a list hash reference of options is supplied, part_export_option records are
created or modified (see L<FS::part_export_option>).

=cut

sub replace {
  my $self = shift;
  my $old = shift;
  my $options = 
    ( ref($_[0]) eq 'HASH' )
      ? shift
      : { @_ };
  warn "FS::option_Common::insert called on $self with options ".
       join(', ', map "$_ => ". $options->{$_}, keys %$options)
    if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $pkey = $self->pkey;
  my $option_table = $self->option_table;

  foreach my $optionname ( keys %{$options} ) {
    my $old = qsearchs( $option_table, {
        $pkey         => $self->get($pkey),
        'optionname'  => $optionname,
    } );

    my $href = {
        $pkey         => $self->get($pkey),
        'optionname'  => $optionname,
        'optionvalue' => $options->{$optionname},
    };

    #my $new = eval "new FS::$option_table \$href";
    #if ( $@ ) {
    #  $dbh->rollback if $oldAutoCommit;
    #  return $@;
    #}
    my $new = "FS::$option_table"->new($href);

    $new->optionnum($old->optionnum) if $old;
    my $error = $old ? $new->replace($old) : $new->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  #remove extraneous old options
  foreach my $opt (
    grep { !exists $options->{$_->optionname} } $old->option_objects
  ) {
    my $error = $opt->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item option_objects

Returns all options as FS::I<tablename>_option objects.

=cut

sub option_objects {
  my $self = shift;
  my $pkey = $self->pkey;
  my $option_table = $self->option_table;
  qsearch($option_table, { $pkey => $self->get($pkey) } );
}

=item options 

Returns a list of option names and values suitable for assigning to a hash.

=cut

sub options {
  my $self = shift;
  map { $_->optionname => $_->optionvalue } $self->option_objects;
}

=item option OPTIONNAME

Returns the option value for the given name, or the empty string.

=cut

sub option {
  my $self = shift;
  my $pkey = $self->pkey;
  my $option_table = $self->option_table;
  my $obj =
    qsearchs($option_table, {
      $pkey      => $self->get($pkey),
      optionname => shift,
  } );
  $obj ? $obj->optionvalue : '';
}


sub pkey {
  my $self = shift;
  my $pkey = $self->dbdef_table->primary_key;
}

sub option_table {
  my $self = shift;
  my $option_table = $self->table . '_option';
  eval "use FS::$option_table";
  die $@ if $@;
  $option_table;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

