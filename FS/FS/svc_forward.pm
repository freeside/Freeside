package FS::svc_forward;

use strict;
use vars qw( @ISA );
use FS::Conf;
use FS::Record qw( fields qsearch qsearchs dbh );
use FS::svc_Common;
use FS::cust_svc;
use FS::svc_acct;
use FS::svc_domain;

@ISA = qw( FS::svc_Common );

=head1 NAME

FS::svc_forward - Object methods for svc_forward records

=head1 SYNOPSIS

  use FS::svc_forward;

  $record = new FS::svc_forward \%hash;
  $record = new FS::svc_forward { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_forward object represents a mail forwarding alias.  FS::svc_forward
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatcially for new accounts)

=item srcsvc - svcnum of the source of the forward (see L<FS::svc_acct>)

=item src - literal source (username or full email address)

=item dstsvc - svcnum of the destination of the forward (see L<FS::svc_acct>)

=item dst - literal destination (username or full email address)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new mail forwarding alias.  To add the mail forwarding alias to the
database, see L<"insert">.

=cut


sub table_info {
  {
    'name' => 'Forward',
    'name_plural' => 'Mail forwards',
    'display_weight' => 30,
    'cancel_weight'  => 30,
    'fields' => {
        'srcsvc'    => 'service from which mail is to be forwarded',
        'dstsvc'    => 'service to which mail is to be forwarded',
        'dst'       => 'someone@another.domain.com to use when dstsvc is 0',
    },
  };
}

sub table { 'svc_forward'; }

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

sub search_sql {
  my( $class, $string ) = @_;
  $class->search_sql_field('src', $string);
}

=item label [ END_TIMESTAMP [ START_TIMESTAMP ] ]

Returns a text string representing this forward.

END_TIMESTAMP and START_TIMESTAMP can optionally be passed when dealing with
history records.

=cut

sub label {
  my $self = shift;
  my $tag = '';

  if ( $self->srcsvc ) {
    my $svc_acct = $self->srcsvc_acct(@_);
    $tag = $svc_acct->email(@_);
  } else {
    $tag = $self->src;
  }

  $tag .= ' -> ';

  if ( $self->dstsvc ) {
    my $svc_acct = $self->dstsvc_acct(@_);
    $tag .= $svc_acct->email(@_);
  } else {
    $tag .= $self->dst;
  }

  $tag;
}


=item insert [ , OPTION => VALUE ... ]

Adds this mail forwarding alias to the database.  If there is an error, returns
the error, otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

Currently available options are: I<depend_jobnum>

If I<depend_jobnum> is set (to a scalar jobnum or an array reference of
jobnums), all provisioning jobs will have a dependancy on the supplied
jobnum(s) (they will not run until the specific job(s) complete(s)).

=cut

sub insert {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->SUPER::insert(@_);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error

}

=item delete

Deletes this mail forwarding alias from the database.  If there is an error,
returns the error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

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
  local $FS::UID::Autocommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::delete(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}


=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );

  if ( $new->srcsvc != $old->srcsvc
       && ( $new->dstsvc != $old->dstsvc
            || ! $new->dstsvc && $new->dst ne $old->dst 
          )
      ) {
    return "Can't change both source and destination of a mail forward!"
  }

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $new->SUPER::replace($old, @_);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item suspend

Just returns false (no error) for now.

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Just returns false (no error) for now.

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Just returns false (no error) for now.

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid mail forwarding alias.  If there
is an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

Sets any fixed values; see L<FS::part_svc>.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  #my $part_svc = $x;

  my $error = $self->ut_numbern('svcnum')
              || $self->ut_numbern('srcsvc')
              || $self->ut_numbern('dstsvc')
  ;
  return $error if $error;

  return "Both srcsvc and src were defined; only one can be specified"
    if $self->srcsvc && $self->src;

  return "one of srcsvc or src is required"
    unless $self->srcsvc || $self->src;

  return "Unknown srcsvc: ". $self->srcsvc
    unless ! $self->srcsvc || $self->srcsvc_acct;

  return "Both dstsvc and dst were defined; only one can be specified"
    if $self->dstsvc && $self->dst;

  return "one of dstsvc or dst is required"
    unless $self->dstsvc || $self->dst;

  return "Unknown dstsvc: ". $self->dstsvc
    unless ! $self->dstsvc || $self->dstsvc_acct;
  #return "Unknown dstsvc"
  #  unless qsearchs('svc_acct', { 'svcnum' => $self->dstsvc } )
  #         || ! $self->dstsvc;

  if ( $self->src ) {
    $self->src =~ /^([\w\.\-\&]*)(\@([\w\-]+\.)+\w+)$/
       or return "Illegal src: ". $self->src;
    $self->src("$1$2");
  } else {
    $self->src('');
  }

  if ( $self->dst ) {
    my $conf = new FS::Conf;
    if ( $conf->exists('svc_forward-arbitrary_dst') ) {
      my $error = $self->ut_textn('dst');
      return $error if $error;
    } else {
      $self->dst =~ /^([\w\.\-\&]*)(\@([\w\-]+\.)+\w+)$/
         or return "Illegal dst: ". $self->dst;
      $self->dst("$1$2");
    }
  } else {
    $self->dst('');
  }

  $self->SUPER::check;
}

=item srcsvc_acct

Returns the FS::svc_acct object referenced by the srcsvc column, or false for
literally specified forwards.

=cut

sub srcsvc_acct {
  my $self = shift;
  qsearchs('svc_acct', { 'svcnum' => $self->srcsvc } );
}

=item dstsvc_acct

Returns the FS::svc_acct object referenced by the srcsvc column, or false for
literally specified forwards.

=cut

sub dstsvc_acct {
  my $self = shift;
  qsearchs('svc_acct', { 'svcnum' => $self->dstsvc } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>,
L<FS::svc_acct>, L<FS::svc_domain>, schema.html from the base documentation.

=cut

1;

