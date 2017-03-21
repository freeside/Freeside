package FS::contact;
use base qw( FS::Password_Mixin
             FS::Record );

use strict;
use vars qw( $skip_fuzzyfiles );
use Carp;
use Scalar::Util qw( blessed );
use FS::Record qw( qsearch qsearchs dbh );
use FS::Cursor;
use FS::contact_phone;
use FS::contact_email;
use FS::queue;
use FS::phone_type; #for cgi_contact_fields
use FS::cust_contact;
use FS::prospect_contact;

$skip_fuzzyfiles = 0;

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

An FS::contact object represents an specific contact person for a prospect or
customer.  FS::contact inherits from FS::Record.  The following fields are
currently supported:

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

=item selfservice_access

empty or Y

=item _password

=item _password_encoding

empty or bcrypt

=item disabled

disabled

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new contact.  To add the contact to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'contact'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If the object has an C<emailaddress> field, L<FS::contact_email> records
will be created for each (comma-separated) email address in that field. If
any of these coincide with an existing email address, this contact will be
merged with the contact with that address.

Then, if the object has any fields named C<phonetypenumN> an
L<FS::contact_phone> record will be created for each of them. Those fields
should contain phone numbers of the appropriate types (where N is the key of
an L<FS::phone_type> record identifying the type of number: daytime, night,
etc.).

After inserting the record, if the object has a 'custnum' or 'prospectnum'
field, an L<FS::cust_contact> or L<FS::prospect_contact> record will be
created to link the contact to the customer. The following fields will also
be included in that record, if they are set on the object:
- classnum
- comment
- selfservice_access
- invoice_dest

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

  #save off and blank values that move to cust_contact / prospect_contact now
  my $prospectnum = $self->prospectnum;
  $self->prospectnum('');
  my $custnum = $self->custnum;
  $self->custnum('');

  my %link_hash = ();
  for (qw( classnum comment selfservice_access invoice_dest )) {
    $link_hash{$_} = $self->get($_);
    $self->$_('');
  }

  #look for an existing contact with this email address
  my $existing_contact = '';
  if ( $self->get('emailaddress') =~ /\S/ ) {
  
    my %existing_contact = ();

    foreach my $email ( split(/\s*,\s*/, $self->get('emailaddress') ) ) {
 
      my $contact_email = qsearchs('contact_email', { emailaddress=>$email } )
        or next;

      my $contact = $contact_email->contact;
      $existing_contact{ $contact->contactnum } = $contact;

    }

    if ( scalar( keys %existing_contact ) > 1 ) {
      $dbh->rollback if $oldAutoCommit;
      return 'Multiple email addresses specified '.
             ' that already belong to separate contacts';
    } elsif ( scalar( keys %existing_contact ) ) {
      ($existing_contact) = values %existing_contact;
    }

  }

  my $error;
  if ( $existing_contact ) {

    $self->$_($existing_contact->$_())
      for qw( contactnum _password _password_encoding );
    $error = $self->SUPER::replace($existing_contact);

  } else {

    $error = $self->SUPER::insert;

  }

  $error ||= $self->insert_password_history;

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $cust_contact = '';
  # if $self->custnum was set, then the customer-specific properties
  # (custnum, classnum, invoice_dest, selfservice_access, comment) are in
  # pseudo-fields, and are now in %link_hash. otherwise, ignore all those
  # fields.
  if ( $custnum ) {
    my %hash = ( 'contactnum' => $self->contactnum,
                 'custnum'    => $custnum,
               );
    $cust_contact =  qsearchs('cust_contact', \%hash )
                  || new FS::cust_contact { %hash, %link_hash };
    my $error = $cust_contact->custcontactnum ? $cust_contact->replace
                                              : $cust_contact->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( $prospectnum ) {
    my %hash = ( 'contactnum'  => $self->contactnum,
                 'prospectnum' => $prospectnum,
               );
    my $prospect_contact =  qsearchs('prospect_contact', \%hash )
                         || new FS::prospect_contact { %hash, %link_hash };
    my $error =
      $prospect_contact->prospectcontactnum ? $prospect_contact->replace
                                            : $prospect_contact->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $pf ( grep { /^phonetypenum(\d+)$/ && $self->get($_) =~ /\S/ }
                        keys %{ $self->hashref } ) {
    $pf =~ /^phonetypenum(\d+)$/ or die "wtf (daily, the)";
    my $phonetypenum = $1;

    my %hash = ( 'contactnum'   => $self->contactnum,
                 'phonetypenum' => $phonetypenum,
               );
    my $contact_phone =
      qsearchs('contact_phone', \%hash)
        || new FS::contact_phone { %hash, _parse_phonestring($self->get($pf)) };
    my $error = $contact_phone->contactphonenum ? $contact_phone->replace
                                                : $contact_phone->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( $self->get('emailaddress') =~ /\S/ ) {

    foreach my $email ( split(/\s*,\s*/, $self->get('emailaddress') ) ) {
      my %hash = (
        'contactnum'   => $self->contactnum,
        'emailaddress' => $email,
      );
      unless ( qsearchs('contact_email', \%hash) ) {
        my $contact_email = new FS::contact_email \%hash;
        my $error = $contact_email->insert;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }
    }

  }

  unless ( $skip_fuzzyfiles ) { #unless ( $import || $skip_fuzzyfiles ) {
    #warn "  queueing fuzzyfiles update\n"
    #  if $DEBUG > 1;
    my $error = $self->queue_fuzzyfiles_update;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "updating fuzzy search cache: $error";
    }
  }

  if (      $link_hash{'selfservice_access'} eq 'R'
       or ( $link_hash{'selfservice_access'}
            && $cust_contact
            && ! length($self->_password)
          )
     )
  {
    my $error = $self->send_reset_email( queue=>1 );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Delete this record from the database.

=cut

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

  #got a prospetnum or custnum? delete the prospect_contact or cust_contact link

  if ( $self->prospectnum ) {
    my $prospect_contact = qsearchs('prospect_contact', {
                             'contactnum'  => $self->contactnum,
                             'prospectnum' => $self->prospectnum,
                           });
    my $error = $prospect_contact->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  # if $self->custnum was set, then we're removing the contact from this
  # customer.
  if ( $self->custnum ) {
    my $cust_contact = qsearchs('cust_contact', {
                         'contactnum'  => $self->contactnum,
                         'custnum' => $self->custnum,
                       });
    my $error = $cust_contact->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  # then, proceed with deletion only if the contact isn't attached to any other
  # prospects or customers

  #inefficient, but how many prospects/customers can a single contact be
  # attached too?  (and is removing them from one a common operation?)
  if ( $self->prospect_contact || $self->cust_contact ) {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return '';
  }

  #proceed with deletion

  foreach my $cust_pkg ( $self->cust_pkg ) {
    $cust_pkg->contactnum('');
    my $error = $cust_pkg->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $object ( $self->contact_phone, $self->contact_email ) {
    my $error = $object->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->delete_password_history
           || $self->SUPER::delete;
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

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $self->replace_old;

  $self->$_( $self->$_ || $old->$_ ) for qw( _password _password_encoding );

  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  #save off and blank values that move to cust_contact / prospect_contact now
  my $prospectnum = $self->prospectnum;
  $self->prospectnum('');
  my $custnum = $self->custnum;
  $self->custnum('');

  my %link_hash = ();
  for (qw( classnum comment selfservice_access invoice_dest )) {
    $link_hash{$_} = $self->get($_);
    $self->$_('');
  }

  my $error = $self->SUPER::replace($old);
  if ( $old->_password ne $self->_password ) {
    $error ||= $self->insert_password_history;
  }
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $cust_contact = '';
  # if $self->custnum was set, then the customer-specific properties
  # (custnum, classnum, invoice_dest, selfservice_access, comment) are in
  # pseudo-fields, and are now in %link_hash. otherwise, ignore all those
  # fields.
  if ( $custnum ) {
    my %hash = ( 'contactnum' => $self->contactnum,
                 'custnum'    => $custnum,
               );
    my $error;
    if ( $cust_contact = qsearchs('cust_contact', \%hash ) ) {
      $cust_contact->$_($link_hash{$_}) for keys %link_hash;
      $error = $cust_contact->replace;
    } else {
      $cust_contact = new FS::cust_contact { %hash, %link_hash };
      $error = $cust_contact->insert;
    }
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( $prospectnum ) {
    my %hash = ( 'contactnum'  => $self->contactnum,
                 'prospectnum' => $prospectnum,
               );
    my $error;
    if ( my $prospect_contact = qsearchs('prospect_contact', \%hash ) ) {
      $prospect_contact->$_($link_hash{$_}) for keys %link_hash;
      $error = $prospect_contact->replace;
    } else {
      my $prospect_contact = new FS::prospect_contact { %hash, %link_hash };
      $error = $prospect_contact->insert;
    }
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $pf ( grep { /^phonetypenum(\d+)$/ }
                        keys %{ $self->hashref } ) {
    $pf =~ /^phonetypenum(\d+)$/ or die "wtf (daily, the)";
    my $phonetypenum = $1;

    my %cp = ( 'contactnum'   => $self->contactnum,
               'phonetypenum' => $phonetypenum,
             );
    my $contact_phone = qsearchs('contact_phone', \%cp);

    my $pv = $self->get($pf);
	$pv =~ s/\s//g;

    #if new value is empty, delete old entry
    if (!$pv) {
      if ($contact_phone) {
        $error = $contact_phone->delete;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }
      next;
    }

    $contact_phone ||= new FS::contact_phone \%cp;

    my %cpd = _parse_phonestring( $pv );
    $contact_phone->set( $_ => $cpd{$_} ) foreach keys %cpd;

    my $method = $contact_phone->contactphonenum ? 'replace' : 'insert';

    $error = $contact_phone->$method;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( defined($self->hashref->{'emailaddress'}) ) {

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

  unless ( $skip_fuzzyfiles ) { #unless ( $import || $skip_fuzzyfiles ) {
    #warn "  queueing fuzzyfiles update\n"
    #  if $DEBUG > 1;
    $error = $self->queue_fuzzyfiles_update;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "updating fuzzy search cache: $error";
    }
  }

  if ( $cust_contact and (
                              (      $cust_contact->selfservice_access eq ''
                                  && $link_hash{selfservice_access}
                                  && ! length($self->_password)
                              )
                           || $cust_contact->_resend()
                         )
    )
  {
    my $error = $self->send_reset_email( queue=>1 );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item _parse_phonestring PHONENUMBER_STRING

Subroutine, takes a string and returns a list (suitable for assigning to a hash)
with keys 'countrycode', 'phonenum' and 'extension'

(Should probably be moved to contact_phone.pm, hence the initial underscore.)

=cut

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

Checks all fields to make sure this is a valid contact.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  if ( $self->selfservice_access eq 'R' ) {
    $self->selfservice_access('Y');
    $self->_resend('Y');
  }

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
    || $self->ut_enum('selfservice_access', [ '', 'Y' ])
    || $self->ut_textn('_password')
    || $self->ut_enum('_password_encoding', [ '', 'bcrypt'])
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  return "Prospect and customer!"       if $self->prospectnum && $self->custnum;

  return "One of first name, last name, or title must have a value"
    if ! grep $self->$_(), qw( first last title);

  $self->SUPER::check;
}

=item line

Returns a formatted string representing this contact, including name, title and
comment.

=cut

sub line {
  my $self = shift;
  my $data = $self->first. ' '. $self->last;
  $data .= ', '. $self->title
    if $self->title;
  $data .= ' ('. $self->comment. ')'
    if $self->comment;
  $data;
}

=item firstlast

Returns a formatted string representing this contact, with just the name.

=cut

sub firstlast {
  my $self = shift;
  $self->first . ' ' . $self->last;
}

#=item contact_classname PROSPECT_OBJ | CUST_MAIN_OBJ
#
#Returns the name of this contact's class for the specified prospect or
#customer (see L<FS::prospect_contact>, L<FS::cust_contact> and
#L<FS::contact_class>).
#
#=cut
#
#sub contact_classname {
#  my( $self, $prospect_or_cust ) = @_;
#
#  my $link = '';
#  if ( ref($prospect_or_cust) eq 'FS::prospect_main' ) {
#    $link = qsearchs('prospect_contact', {
#              'contactnum'  => $self->contactnum,
#              'prospectnum' => $prospect_or_cust->prospectnum,
#            });
#  } elsif ( ref($prospect_or_cust) eq 'FS::cust_main' ) {
#    $link = qsearchs('cust_contact', {
#              'contactnum'  => $self->contactnum,
#              'custnum'     => $prospect_or_cust->custnum,
#            });
#  } else {
#    croak "$prospect_or_cust is not an FS::prospect_main or FS::cust_main object";
#  }
#
#  my $contact_class = $link->contact_class or return '';
#  $contact_class->classname;
#}

=item by_selfservice_email EMAILADDRESS

Alternate search constructor (class method).  Given an email address, returns
the contact for that address. If that contact doesn't have selfservice access,
or there isn't one, returns the empty string.

=cut

sub by_selfservice_email {
  my($class, $email) = @_;

  my $contact_email = qsearchs({
    'table'     => 'contact_email',
    'addl_from' => ' LEFT JOIN contact USING ( contactnum ) ',
    'hashref'   => { 'emailaddress' => $email, },
    'extra_sql' => "
      AND ( contact.disabled IS NULL )
      AND EXISTS ( SELECT 1 FROM cust_contact
                     WHERE contact.contactnum = cust_contact.contactnum
                       AND cust_contact.selfservice_access = 'Y'
                 )
    ",
  }) or return '';

  $contact_email->contact;

}

#these three functions are very much false laziness w/FS/FS/Auth/internal.pm
# and should maybe be libraried in some way for other password needs

use Crypt::Eksblowfish::Bcrypt qw( bcrypt_hash en_base64 de_base64);

sub authenticate_password {
  my($self, $check_password) = @_;

  if ( $self->_password_encoding eq 'bcrypt' ) {

    my( $cost, $salt, $hash ) = split(',', $self->_password);

    my $check_hash = en_base64( bcrypt_hash( { key_nul => 1,
                                               cost    => $cost,
                                               salt    => de_base64($salt),
                                             },
                                             $check_password
                                           )
                              );

    $hash eq $check_hash;

  } else { 

    return 0 if $self->_password eq '';

    $self->_password eq $check_password;

  }

}

=item change_password NEW_PASSWORD

Changes the contact's selfservice access password to NEW_PASSWORD. This does
not check password policy rules (see C<is_password_allowed>) and will return
an error only if editing the record fails for some reason.

If NEW_PASSWORD is the same as the existing password, this does nothing.

=cut

sub change_password {
  my($self, $new_password) = @_;

  # do nothing if the password is unchanged
  return if $self->authenticate_password($new_password);

  $self->change_password_fields( $new_password );

  $self->replace;

}

sub change_password_fields {
  my($self, $new_password) = @_;

  $self->_password_encoding('bcrypt');

  my $cost = 8;

  my $salt = pack( 'C*', map int(rand(256)), 1..16 );

  my $hash = bcrypt_hash( { key_nul => 1,
                            cost    => $cost,
                            salt    => $salt,
                          },
                          $new_password,
                        );

  $self->_password(
    join(',', $cost, en_base64($salt), en_base64($hash) )
  );

}

# end of false laziness w/FS/FS/Auth/internal.pm


#false laziness w/ClientAPI/MyAccount/reset_passwd
use Digest::SHA qw(sha512_hex);
use FS::Conf;
use FS::ClientAPI_SessionCache;
sub send_reset_email {
  my( $self, %opt ) = @_;

  my @contact_email = $self->contact_email or return '';

  my $reset_session = {
    'contactnum' => $self->contactnum,
    'svcnum'     => $opt{'svcnum'},
  };

  
  my $conf = new FS::Conf;
  my $timeout =
    ($conf->config('selfservice-password_reset_hours') || 24 ). ' hours';

  my $reset_session_id;
  do {
    $reset_session_id = sha512_hex(time(). {}. rand(). $$)
  } until ( ! defined $self->myaccount_cache->get("reset_passwd_$reset_session_id") );
    #just in case

  $self->myaccount_cache->set( "reset_passwd_$reset_session_id", $reset_session, $timeout );

  #email it

  my $cust_main = '';
  my @cust_contact = grep $_->selfservice_access, $self->cust_contact;
  $cust_main = $cust_contact[0]->cust_main if scalar(@cust_contact) == 1;

  my $agentnum = $cust_main ? $cust_main->agentnum : '';
  my $msgnum = $conf->config('selfservice-password_reset_msgnum', $agentnum);
  #die "selfservice-password_reset_msgnum unset" unless $msgnum;
  return "selfservice-password_reset_msgnum unset" unless $msgnum;
  my $msg_template = qsearchs('msg_template', { msgnum => $msgnum } );
  return "selfservice-password_reset_msgnum cannot be loaded" unless $msg_template;
  my %msg_template = (
    'to'            => join(',', map $_->emailaddress, @contact_email ),
    'cust_main'     => $cust_main,
    'object'        => $self,
    'substitutions' => { 'session_id' => $reset_session_id }
  );

  if ( $opt{'queue'} ) { #or should queueing just be the default?

    my $cust_msg = $msg_template->prepare( %msg_template );
    my $error = $cust_msg->insert;
    return $error if $error;
    my $queue = new FS::queue {
      'job'     => 'FS::cust_msg::process_send',
      'custnum' => $cust_main ? $cust_main->custnum : '',
    };
    $queue->insert( $cust_msg->custmsgnum );

  } else {

    $msg_template->send( %msg_template );

  }

}

use vars qw( $myaccount_cache );
sub myaccount_cache {
  #my $class = shift;
  $myaccount_cache ||= new FS::ClientAPI_SessionCache( {
                         'namespace' => 'FS::ClientAPI::MyAccount',
                       } );
}

=item cgi_contact_fields

Returns a list reference containing the set of contact fields used in the web
interface for one-line editing (i.e. excluding contactnum, prospectnum, custnum
and locationnum, as well as password fields, but including fields for
contact_email and contact_phone records.)

=cut

sub cgi_contact_fields {
  #my $class = shift;

  my @contact_fields = qw(
    classnum first last title comment emailaddress selfservice_access
    invoice_dest
  );

  push @contact_fields, 'phonetypenum'. $_->phonetypenum
    foreach qsearch({table=>'phone_type', order_by=>'weight'});

  \@contact_fields;

}

use FS::upgrade_journal;
sub _upgrade_data { #class method
  my ($class, %opts) = @_;

  # before anything else, migrate contact.custnum to cust_contact records
  unless ( FS::upgrade_journal->is_done('contact_invoice_dest') ) {

    local($skip_fuzzyfiles) = 1;

    foreach my $contact (qsearch('contact', {})) {
      my $error = $contact->replace;
      die $error if $error;
    }

    FS::upgrade_journal->set_done('contact_invoice_dest');
  }


  # always migrate cust_main_invoice records over
  local $FS::cust_main::import = 1; # override require_phone and such
  my $search = FS::Cursor->new('cust_main_invoice', {});
  my %custnum_dest;
  while (my $cust_main_invoice = $search->fetch) {
    my $custnum = $cust_main_invoice->custnum;
    my $dest = $cust_main_invoice->dest;
    my $cust_main = $cust_main_invoice->cust_main;

    if ( $dest =~ /^\d+$/ ) {
      my $svc_acct = FS::svc_acct->by_key($dest);
      die "custnum $custnum, invoice destination svcnum $svc_acct does not exist\n"
        if !$svc_acct;
      $dest = $svc_acct->email;
    }
    push @{ $custnum_dest{$custnum} ||= [] }, $dest;

    my $error = $cust_main_invoice->delete;
    if ( $error ) {
      die "custnum $custnum, cleaning up cust_main_invoice: $error\n";
    }
  }

  foreach my $custnum (keys %custnum_dest) {
    my $dests = $custnum_dest{$custnum};
    my $cust_main = FS::cust_main->by_key($custnum);
    my $error = $cust_main->replace( invoicing_list => $dests );
    if ( $error ) {
      die "custnum $custnum, creating contact: $error\n";
    }
  }

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

