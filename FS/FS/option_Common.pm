package FS::option_Common;

use strict;
use vars qw( @ISA $DEBUG );
use Scalar::Util qw( blessed );
use FS::Record qw( qsearch qsearchs dbh );

@ISA = qw( FS::Record );

$DEBUG = 0;

=head1 NAME

FS::option_Common - Base class for option sub-classes

=head1 SYNOPSIS

use FS::option_Common;

@ISA = qw( FS::option_Common );

#optional for non-standard names
sub _option_table    { 'table_name'; }  #defaults to ${table}_option
sub _option_namecol  { 'column_name'; } #defaults to optionname
sub _option_valuecol { 'column_name'; } #defaults to optionvalue

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

  my $error;
  
  $error = $self->check_options($options) 
           || $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $pkey = $self->primary_key;
  my $option_table = $self->option_table;

  my $namecol = $self->_option_namecol;
  my $valuecol = $self->_option_valuecol;

  foreach my $optionname ( keys %{$options} ) {

    my $optionvalue = $options->{$optionname};

    my $href = {
      $pkey     => $self->get($pkey),
      $namecol  => $optionname,
      $valuecol => ( ref($optionvalue) || $optionvalue ),
    };

    #my $option_record = eval "new FS::$option_table \$href";
    #if ( $@ ) {
    #  $dbh->rollback if $oldAutoCommit;
    #  return $@;
    #}
    my $option_record = "FS::$option_table"->new($href);

    my @args = ();
    push @args, $optionvalue if ref($optionvalue); #only hashes supported so far

    $error = $option_record->insert(@args);
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
  
  my $pkey = $self->primary_key;
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

=item replace [ OLD_RECORD ] [ HASHREF | OPTION => VALUE ... ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If a list or hash reference of options is supplied, option records are created
or modified.

=cut

sub replace {
  my $self = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $self->replace_old;

  my $options;
  my $options_supplied = 0;
  if ( ref($_[0]) eq 'HASH' ) {
    $options = shift;
    $options_supplied = 1;
  } else {
    $options = { @_ };
    $options_supplied = scalar(@_) ? 1 : 0;
  }

  warn "FS::option_Common::replace called on $self with options ".
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

  my $error;
  
  if ($options_supplied) {
    $error = $self->check_options($options);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }
  
  $error = $self->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $pkey = $self->primary_key;
  my $option_table = $self->option_table;

  my $namecol = $self->_option_namecol;
  my $valuecol = $self->_option_valuecol;

  foreach my $optionname ( keys %{$options} ) {

    warn "FS::option_Common::replace: inserting or replacing option: $optionname"
      if $DEBUG > 1;

    my $oldopt = qsearchs( $option_table, {
        $pkey    => $self->get($pkey),
        $namecol => $optionname,
    } );

    my $optionvalue = $options->{$optionname};

    my %oldhash = $oldopt ? $oldopt->hash : ();

    my $href = {
        %oldhash,
        $pkey     => $self->get($pkey),
        $namecol  => $optionname,
        $valuecol => ( ref($optionvalue) || $optionvalue ),
    };

    #my $newopt = eval "new FS::$option_table \$href";
    #if ( $@ ) {
    #  $dbh->rollback if $oldAutoCommit;
    #  return $@;
    #}
    my $newopt = "FS::$option_table"->new($href);

    my $opt_pkey = $newopt->primary_key;

    $newopt->$opt_pkey($oldopt->$opt_pkey) if $oldopt;

    my @args = ();
    push @args, $optionvalue if ref($optionvalue); #only hashes supported so far

    warn "FS::option_Common::replace: ".
         ( $oldopt ? "$newopt -> replace($oldopt)" : "$newopt -> insert" )
      if $DEBUG > 2;
    my $error = $oldopt ? $newopt->replace($oldopt, @args)
                        : $newopt->insert( @args);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  #remove extraneous old options
  if ( $options_supplied ) {
    foreach my $opt (
      grep { !exists $options->{$_->$namecol()} } $old->option_objects
    ) {
      my $error = $opt->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item check_options HASHREF

This method is called by 'insert' and 'replace' to check the options that were supplied.

Return error-message, or false.

(In this class, this is a do-nothing routine that always returns false.  Override as necessary.  No need to call superclass.)

=cut

sub check_options {
	my ($self, $options) = @_;
	'';
}

=item option_objects

Returns all options as FS::I<tablename>_option objects.

=cut

sub option_objects {
  my $self = shift;
  my $pkey = $self->primary_key;
  my $option_table = $self->option_table;
  qsearch($option_table, { $pkey => $self->get($pkey) } );
}

=item options 

Returns a list of option names and values suitable for assigning to a hash.

=cut

sub options {
  my $self = shift;
  my $namecol = $self->_option_namecol;
  my $valuecol = $self->_option_valuecol;
  map { $_->$namecol() => $_->$valuecol() } $self->option_objects;
}

=item option OPTIONNAME

Returns the option value for the given name, or the empty string.

=cut

sub option {
  my $self = shift;
  my $pkey = $self->primary_key;
  my $option_table = $self->option_table;
  my $namecol = $self->_option_namecol;
  my $valuecol = $self->_option_valuecol;
  my $hashref = {
      $pkey    => $self->get($pkey),
      $namecol => shift,
  };
  warn "$self -> option: searching for ".
         join(' / ', map { "$_ => ". $hashref->{$_} } keys %$hashref )
    if $DEBUG;
  my $obj = qsearchs($option_table, $hashref);
  $obj ? $obj->$valuecol() : '';
}


sub option_table {
  my $self = shift;
  my $option_table = $self->_option_table;
  eval "use FS::$option_table";
  die $@ if $@;
  $option_table;
}

#defaults
sub _option_table    { shift->table .'_option'; }
sub _option_namecol  { 'optionname'; }
sub _option_valuecol { 'optionvalue'; }

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

