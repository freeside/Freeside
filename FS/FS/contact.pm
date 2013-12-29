package FS::contact;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearchs dbh ); # qw( qsearch qsearchs dbh );

=head1 NAME

FS::contact - Object methods for contact records

=head1 SYNOPSIS

  use FS::contact;

  $record = new FS::contact \%hash;
  $record = new FS::contact { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::contact object represents an example.  FS::contact inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item contactnum

primary key

=item prospectnum

prospectnum

=item custnum

custnum

=item locationnum

locationnum

=item last

last

=item first

first

=item title

title

=item comment

comment

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'contact'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

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

  foreach my $pf ( grep { /^phonetypenum(\d+)$/ && $self->get($_) =~ /\S/ }
                        keys %{ $self->hashref } ) {
    $pf =~ /^phonetypenum(\d+)$/ or die "wtf (daily, the)";
    my $phonetypenum = $1;

    my $contact_phone = new FS::contact_phone {
      'contactnum' => $self->contactnum,
      'phonetypenum' => $phonetypenum,
      _parse_phonestring( $self->get($pf) ),
    };
    $error = $contact_phone->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( $self->get('emailaddress') =~ /\S/ ) {

    foreach my $email ( split(/\s*,\s*/, $self->get('emailaddress') ) ) {
 
      my $contact_email = new FS::contact_email {
        'contactnum'   => $self->contactnum,
        'emailaddress' => $email,
      };
      $error = $contact_email->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

    }

  }

  #unless ( $import || $skip_fuzzyfiles ) {
    #warn "  queueing fuzzyfiles update\n"
    #  if $DEBUG > 1;
    $error = $self->queue_fuzzyfiles_update;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "updating fuzzy search cache: $error";
    }
  #}

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

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

  foreach my $object ( $self->contact_phone, $self->contact_email ) {
    my $error = $object->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $self = shift;

  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::replace(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $pf ( grep { /^phonetypenum(\d+)$/ && $self->get($_) }
                        keys %{ $self->hashref } ) {
    $pf =~ /^phonetypenum(\d+)$/ or die "wtf (daily, the)";
    my $phonetypenum = $1;

    my %cp = ( 'contactnum'   => $self->contactnum,
               'phonetypenum' => $phonetypenum,
             );
    my $contact_phone = qsearchs('contact_phone', \%cp)
                        || new FS::contact_phone   \%cp;

    my %cpd = _parse_phonestring( $self->get($pf) );
    $contact_phone->set( $_ => $cpd{$_} ) foreach keys %cpd;

    my $method = $contact_phone->contactphonenum ? 'replace' : 'insert';

    $error = $contact_phone->$method;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( defined($self->get('emailaddress')) ) {

    #ineffecient but whatever, how many email addresses can there be?

    foreach my $contact_email ( $self->contact_email ) {
      my $error = $contact_email->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }

    foreach my $email ( split(/\s*,\s*/, $self->get('emailaddress') ) ) {
 
      my $contact_email = new FS::contact_email {
        'contactnum'   => $self->contactnum,
        'emailaddress' => $email,
      };
      $error = $contact_email->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

    }

  }

  #unless ( $import || $skip_fuzzyfiles ) {
    #warn "  queueing fuzzyfiles update\n"
    #  if $DEBUG > 1;
    $error = $self->queue_fuzzyfiles_update;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "updating fuzzy search cache: $error";
    }
  #}

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

#i probably belong in contact_phone.pm
sub _parse_phonestring {
  my $value = shift;

  my($countrycode, $extension) = ('1', '');

  #countrycode
  if ( $value =~ s/^\s*\+\s*(\d+)// ) {
    $countrycode = $1;
  } else {
    $value =~ s/^\s*1//;
  }
  #extension
  if ( $value =~ s/\s*(ext|x)\s*(\d+)\s*$//i ) {
     $extension = $2;
  }

  ( 'countrycode' => $countrycode,
    'phonenum'    => $value,
    'extension'   => $extension,
  );
}

=item queue_fuzzyfiles_update

Used by insert & replace to update the fuzzy search cache

=cut

use FS::cust_main::Search;
sub queue_fuzzyfiles_update {
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

  foreach my $field ( 'first', 'last' ) {
    my $queue = new FS::queue { 
      'job' => 'FS::cust_main::Search::append_fuzzyfiles_fuzzyfield'
    };
    my @args = "contact.$field", $self->get($field);
    my $error = $queue->insert( @args );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "queueing job (transaction rolled back): $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('contactnum')
    || $self->ut_foreign_keyn('prospectnum', 'prospect_main', 'prospectnum')
    || $self->ut_foreign_keyn('custnum',     'cust_main',     'custnum')
    || $self->ut_foreign_keyn('locationnum', 'cust_location', 'locationnum')
    || $self->ut_foreign_keyn('classnum',    'contact_class', 'classnum')
    || $self->ut_namen('last')
    || $self->ut_namen('first')
    || $self->ut_textn('title')
    || $self->ut_textn('comment')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  return "No prospect or customer!" unless $self->prospectnum || $self->custnum;
  return "Prospect and customer!"       if $self->prospectnum && $self->custnum;

  return "One of first name, last name, or title must have a value"
    if ! grep $self->$_(), qw( first last title);

  $self->SUPER::check;
}

sub line {
  my $self = shift;
  my $data = $self->first. ' '. $self->last;
  $data .= ', '. $self->title
    if $self->title;
  $data .= ' ('. $self->comment. ')'
    if $self->comment;
  $data;
}

sub contact_classname {
  my $self = shift;
  my $contact_class = $self->contact_class or return '';
  $contact_class->classname;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

