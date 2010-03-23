package FS::svc_mailinglist;

use strict;
use base qw( FS::svc_Domain_Mixin FS::svc_Common );
use Scalar::Util qw( blessed );
use FS::Record qw( qsearchs dbh ); # qsearch );
use FS::svc_domain;
use FS::mailinglist;

=head1 NAME

FS::svc_mailinglist - Object methods for svc_mailinglist records

=head1 SYNOPSIS

  use FS::svc_mailinglist;

  $record = new FS::svc_mailinglist \%hash;
  $record = new FS::svc_mailinglist { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_mailinglist object represents a mailing list customer service.
FS::svc_mailinglist inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item svcnum

primary key

=item username

username

=item domsvc

domsvc

=item listnum

listnum

=item reply_to_group

reply_to_group

=item remove_author

remove_author

=item reject_auto

reject_auto

=item remove_to_and_cc

remove_to_and_cc

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'svc_mailinglist'; }

sub table_info {
  {
    'name' => 'Mailing list',
    'display_weight' => 80,
    'cancel_weight'  => 55,
    'fields' => {
      'username' => { 'label' => 'List address',
                      'disable_default'   => 1,
                      'disable_fixed'     => 1,
                      'disable_inventory' => 1,
                    },
      'domsvc' => { 'label' => 'List address domain',
                    'disable_inventory' => 1,
                    },
      'domain' => 'List address domain',
      'listnum' => { 'label' => 'List name',
                     'disable_inventory' => 1,
                   },
      'listname' => 'List name', #actually mailinglist.listname
      'reply_to' => { 'label' => 'Reply-To list',
                      'type'  => 'checkbox',
                      'disable_inventory' => 1,
                      'disable_select'    => 1,
                    },
      'remove_from' => { 'label' => 'Remove From: from messages',
                          'type'  => 'checkbox',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                        },
      'reject_auto' => { 'label' => 'Reject automatic messages',
                         'type'  => 'checkbox',
                         'disable_inventory' => 1,
                         'disable_select'    => 1,
                       },
      'remove_to_and_cc' => { 'label' => 'Remove To: and Cc: from messages',
                              'type'  => 'checkbox',
                              'disable_inventory' => 1,
                              'disable_select'    => 1,
                            },
    },
  };
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
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

  my $error;

  #attach to existing lists?  sound scary 
  #unless ( $self->listnum ) {
    my $mailinglist = new FS::mailinglist {
      'listname' => $self->get('listname'),
    };
    $error = $mailinglist->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    $self->listnum($mailinglist->listnum);
  #}

  $error = $self->SUPER::insert(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
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

  my $error = $self->mailinglist->delete || $self->SUPER::delete;
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
  my $new = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $new->replace_old;

  return "can't change listnum" if $old->listnum != $new->listnum; #?

  my %options = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $new->get('listname') && $new->get('listname') ne $old->listname ) {
    my $mailinglist = $old->mailinglist;
    $mailinglist->listname($new->get('listname'));
    my $error = $mailinglist->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error if $error;
    }
  }

  my $error = $new->SUPER::replace($old, %options);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error if $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
  

}

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_text('username')
    || $self->ut_foreign_key('domsvc', 'svc_domain', 'svcnum')
    #|| $self->ut_foreign_key('listnum', 'mailinglist', 'listnum')
    || $self->ut_foreign_keyn('listnum', 'mailinglist', 'listnum')
    || $self->ut_enum('reply_to_group', [ '', 'Y' ] )
    || $self->ut_enum('remove_author', [ '', 'Y' ] )
    || $self->ut_enum('reject_auto', [ '', 'Y' ] )
    || $self->ut_enum('remove_to_and_cc', [ '', 'Y' ] )
  ;
  return $error if $error;

  return "Can't remove listnum" if $self->svcnum && ! $self->listnum;

  $self->SUPER::check;
}

=item mailinglist

=cut

sub mailinglist {
  my $self = shift;
  qsearchs('mailinglist', { 'listnum' => $self->listnum } );
}

=item listname

=cut

sub listname {
  my $self = shift;
  my $mailinglist = $self->mailinglist;
  $mailinglist ? $mailinglist->listname : '';
}

=item label

=cut

sub label {
  my $self = shift;
  $self->listname. ' <'. $self->username. '@'. $self->domain. '>';
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

