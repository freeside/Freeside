package FS::part_export;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::part_svc;
use FS::part_export_option;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_export - Object methods for part_export records

=head1 SYNOPSIS

  use FS::part_export;

  $record = new FS::part_export \%hash;
  $record = new FS::part_export { 'column' => 'value' };

  ($new_record, $options) = $template_recored->clone( $svcpart );

  $error = $record->insert( { 'option' => 'value' } );
  $error = $record->insert( \%options );

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_export object represents an export of Freeside data to an external
provisioning system.  FS::part_export inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item exportnum - primary key

=item svcpart - Service definition (see L<FS::part_svc>) to which this export applies

=item machine - Machine name 

=item exporttype - Export type

=item nodomain - blank or "Y" : usernames are exported to this service with no domain

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new export.  To add the export to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_export'; }

=item clone SVCPART

An alternate constructor.  Creates a new export by duplicating an existing
export.  The given svcpart is assigned to the new export.

Returns a list consisting of the new export object and a hashref of options.

=cut

sub clone {
  my $self = shift;
  my $class = ref($self);
  my %hash = $self->hash;
  $hash{'exportnum'} = '';
  $hash{'svcpart'} = shift;
  ( $class->new( \%hash ),
    { map { $_->optionname => $_->optionvalue }
        qsearch('part_export_option', { 'exportnum' => $self->exportnum } )
    }
  );
}

=item insert HASHREF

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If a hash reference of options is supplied, part_export_option records are
created (see L<FS::part_export_option>).

=cut

#false laziness w/queue.pm
sub insert {
  my $self = shift;
  my $options = shift;
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

  foreach my $optionname ( keys %{$options} ) {
    my $part_export_option = new FS::part_export_option ( {
      'exportnum'   => $self->exportnum,
      'optionname'  => $optionname,
      'optionvalue' => $options->{$optionname},
    } );
    $error = $part_export_option->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

};

=item delete

Delete this record from the database.

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

  foreach my $part_export_option ( $self->part_export_option ) {
    my $error = $part_export_option->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace OLD_RECORD HASHREF

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If a hash reference of options is supplied, part_export_option records are
created or modified (see L<FS::part_export_option>).

=cut

sub replace {
  my $self = shift;
  my $old = shift;
  my $options = shift;
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

  foreach my $optionname ( keys %{$options} ) {
    my $old = qsearchs( 'part_export_option', {
        'exportnum'   => $self->exportnum,
        'optionname'  => $optionname,
    } );
    my $new = new FS::part_export_option ( {
        'exportnum'   => $self->exportnum,
        'optionname'  => $optionname,
        'optionvalue' => $options->{$optionname},
    } );
    $new->optionnum($old->optionnum) if $old;
    my $error = $old ? $new->replace($old) : $new->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  #remove extraneous old options
  foreach my $opt (
    grep { !exists $options->{$_->optionname} } $old->part_export_option
  ) {
    my $error = $opt->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

};

=item check

Checks all fields to make sure this is a valid export.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $error = 
    $self->ut_numbern('exportnum')
    || $self->ut_domain('machine')
    || $self->ut_number('svcpart')
    || $self->ut_alpha('exporttype')
  ;
  return $error if $error;

  return "Unknown svcpart: ". $self->svcpart
    unless qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );

  $self->machine =~ /^([\w\-\.]*)$/
    or return "Illegal machine: ". $self->machine;
  $self->machine($1);

  $self->nodomain =~ /^(Y?)$/ or return "Illegal nodomain: ". $self->nodomain;
  $self->nodomain($1);

  #check exporttype?

  ''; #no error
}

=item part_svc

Returns the service definition (see L<FS::part_svc>) for this export.

=cut

sub part_svc {
  my $self = shift;
  qsearchs('part_svc', { svcpart => $self->svcpart } );
}

=item part_export_option

Returns all options as FS::part_export_option objects (see
L<FS::part_export_option>).

=cut

sub part_export_option {
  my $self = shift;
  qsearch('part_export_option', { 'exportnum' => $self->exportnum } );
}

=item options 

Returns a list of option names and values suitable for assigning to a hash.

=cut

sub options {
  my $self = shift;
  map { $_->optionname => $_->optionvalue } $self->part_export_option;
}

=item option OPTIONNAME

Returns the option value for the given name, or the empty string.

=cut

sub option {
  my $self = shift;
  my $part_export_option =
    qsearchs('part_export_option', {
      exportnum  => $self->exportnum,
      optionname => shift,
  } );
  $part_export_option ? $part_export_option->optionvalue : '';
}

=item rebless

Reblesses the object into the FS::part_export::EXPORTTYPE class, where
EXPORTTYPE is the object's I<exporttype> field.  There should be better docs
on how to create new exports (and they should live in their own files and be
autoloaded-on-demand), but until then, see L</NEW EXPORT CLASSES>.

=cut

sub rebless {
  my $self = shift;
  my $exporttype = $self->exporttype;
  my $class = ref($self);
  bless($self, $class."::$exporttype");
}

=item export_insert SVC_OBJECT

=cut

sub export_insert {
  my $self = shift;
  $self->rebless;
  $self->_export_insert(@_);
}

#sub AUTOLOAD {
#  my $self = shift;
#  $self->rebless;
#  my $method = $AUTOLOAD;
#  #$method =~ s/::(\w+)$/::_$1/; #infinite loop prevention
#  $method =~ s/::(\w+)$/_$1/; #infinite loop prevention
#  $self->$method(@_);
#}

=item export_replace NEW OLD

=cut

sub export_replace {
  my $self = shift;
  $self->rebless;
  $self->_export_replace(@_);
}

=item export_delete

=cut

sub export_delete {
  my $self = shift;
  $self->rebless;
  $self->_export_delete(@_);
}

=back

=cut

#infostreet

package FS::part_export::infostreet;
use vars qw(@ISA);
@ISA = qw(FS::part_export);

sub _export_insert {
  my( $self, $svc_acct ) = (shift, shift);
  $self->infostreet_queue( $svc_acct->svcnum,
    'createUser', $svc_acct->username, $svc_acct->password );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't change username with InfoStreet"
    if $old->username ne $new->username;
  return '' unless $old->_password ne $new->_password;
  $self->infostreet_queue( $new->svcnum,
    'passwd', $new->username, $new->password );
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $self->infostreet_queue( $svc_acct->svcnum,
    'purgeAccount,releaseUsername', $svc_acct->username );
}

sub infostreet_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => 'FS::part_export::infostreet::infostreet_command',
  };
  $queue->insert(
    $self->option('url'),
    $self->option('login'),
    $self->option('password'),
    $self->option('groupID'),
    $method,
    @_,
  );
}

sub infostreet_command { #subroutine, not method
  my($url, $username, $password, $groupID, $method, @args) = @_;

  #quelle hack
  if ( $method =~ /,/ ) {
    foreach my $part ( split(/,\s*/, $method) ) {
      infostreet_command($url, $username, $password, $groupID, $part, @args);
    }
    return;
  }

  eval "use Frontier::Client;";

  my $conn = Frontier::Client->new( url => $url );
  my $key_result = $conn->call( 'authenticate', $username, $password, $groupID);
  my %key_result = _infostreet_parse($key_result);
  die $key_result{error} unless $key_result{success};
  my $key = $key_result{data};

  my $result = $conn->call($method, $key, @args);
  my %result = _infostreet_parse($result);
  die $result{error} unless $result{success};

}

sub _infostreet_parse { #subroutine, not method
  my $arg = shift;
  map {
    my $value = $arg->{$_};
    #warn ref($value);
    $value = $value->value()
      if ref($value) && $value->isa('Frontier::RPC2::DataType');
    $_=>$value;
  } keys %$arg;
}

#sqlradius

package FS::part_export::sqlradius;
use vars qw(@ISA);
@ISA = qw(FS::part_export);

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);
  $self->sqlradius_queue( $svc_acct->svcnum, 'insert',
    'reply', $svc_acct->username, $svc_acct->radius_reply );
  $self->sqlradius_queue( $svc_acct->svcnum, 'insert',
    'check', $svc_acct->username, $svc_acct->radius_check );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  #return "can't (yet) change username with sqlradius"
  #  if $old->username ne $new->username;
  if ( $old->username ne $new->username ) {
    my $error = $self->sqlradius_queue( $new->svcnum, 'rename',
      $new->username, $old->username );
    return $error if $error;
  }

  foreach my $table (qw(reply check)) {
    my $method = "radius_$table";
    my %new = $new->$method;
    my %old = $old->$method;
    if ( grep { !exists $old{$_} #new attributes
                || $new{$_} ne $old{$_} #changed
              } keys %new
    ) {
      my $error = $self->sqlradius_queue( $new->svcnum, 'insert',
        $table, $new->username, %new );
      return $error if $error;
    }

    my @del = grep { !exists $new{$_} } keys %old;
    my $error = $self->sqlradius_queue( $new->svcnum, 'sqlradius_attrib_delete',
      $table, $new->username, @del );
    return $error if $error;
  }

  '';
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $self->sqlradius_queue( $svc_acct->svcnum, 'delete',
    $svc_acct->username );
}

sub sqlradius_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::sqlradius::sqlradius_$method",
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    @_,
  );
}

sub sqlradius_insert { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my( $replycheck, $username, %attributes ) = @_;

  foreach my $attribute ( keys %attributes ) {
    my $u_sth = $dbh->prepare(
      "UPDATE rad$replycheck SET Value = ? WHERE UserName = ? AND Attribute = ?"    ) or die $dbh->errstr;
    my $i_sth = $dbh->prepare(
      "INSERT INTO rad$replycheck ( id, UserName, Attribute, Value ) ".
        "VALUES ( ?, ?, ?, ? )" )
      or die $dbh->errstr;
    $u_sth->execute($attributes{$attribute}, $username, $attribute) > 0
      or $i_sth->execute( '', $username, $attribute, $attributes{$attribute} )
        or die "can't insert into rad$replycheck table: ". $i_sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_rename { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my($new_username, $old_username) = @_;
  foreach my $table (qw(radreply radcheck)) {
    my $sth = $dbh->prepare("UPDATE $table SET Username = ? WHERE UserName = ?")
      or die $dbh->errstr;
    $sth->execute($new_username, $old_username)
      or die "can't update $table: ". $sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_attrib_delete { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my( $replycheck, $username, @attrib ) = @_;

  foreach my $attribute ( @attrib ) {
    my $sth = $dbh->prepare(
        "DELETE FROM rad$replycheck WHERE UserName = ? AND Attribute = ?" )
      or die $dbh->errstr;
    $sth->execute($username,$attribute)
      or die "can't delete from rad$replycheck table: ". $sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_delete { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my $username = shift;

  foreach my $table (qw( radcheck radreply )) {
    my $sth = $dbh->prepare( "DELETE FROM $table WHERE UserName = ?" );
    $sth->execute($username)
      or die "can't delete from $table table: ". $sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_connect {
  #my($datasrc, $username, $password) = @_;
  #DBI->connect($datasrc, $username, $password) or die $DBI::errstr;
  DBI->connect(@_) or die $DBI::errstr;
}

=head1 NEW EXPORT CLASSES

  #myexport
  
  package FS::part_export::myexport;
  use vars qw(@ISA);
  @ISA = qw(FS::part_export);
  
  sub _export_insert {
    my($self, $svc_something) = (shift, shift);
    $self->myexport_queue( $svc_acct->svcnum, 'insert',
      $svc_something->username, $svc_something->password );
  }
  
  sub _export_replace {
    my( $self, $new, $old ) = (shift, shift, shift);
    #return "can't change username with myexport"
    #  if $old->username ne $new->username;
    #return '' unless $old->_password ne $new->_password;
    $self->myexport_queue( $new->svcnum,
      'replace', $new->username, $new->password );
  }
  
  sub _export_delete {
    my( $self, $svc_something ) = (shift, shift);
    $self->myexport_queue( $svc_acct->svcnum,
      'delete', $svc_something->username );
  }
  
  #a good idea to queue anything that could fail or take any time
  sub myexport_queue {
    my( $self, $svcnum, $method ) = (shift, shift, shift);
    my $queue = new FS::queue {
      'svcnum' => $svcnum,
      'job'    => "FS::part_export::myexport::myexport_$method",
    };
    $queue->insert( @_ );
  }
  
  sub myexport_insert { #subroutine, not method
  }
  sub myexport_replace { #subroutine, not method
  }
  sub myexport_delete { #subroutine, not method
  }

=head1 BUGS

Probably.

Hmm, export code has wound up in here.  Move those sub-classes out into their
own files, at least.  Also hmm... cust_export class (not necessarily a
database table...) ... ?

=head1 SEE ALSO

L<FS::part_export_option>, L<FS::part_svc>, L<FS::svc_acct>, L<FS::svc_domain>,
L<FS::svc_forward>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

