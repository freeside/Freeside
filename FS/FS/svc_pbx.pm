package FS::svc_pbx;

use strict;
use base qw( FS::svc_External_Common );
use FS::Record qw( qsearch qsearchs dbh );
use FS::Conf;
use FS::cust_svc;
use FS::svc_phone;
use FS::svc_acct;

=head1 NAME

FS::svc_pbx - Object methods for svc_pbx records

=head1 SYNOPSIS

  use FS::svc_pbx;

  $record = new FS::svc_pbx \%hash;
  $record = new FS::svc_pbx { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_pbx object represents a PBX tenant.  FS::svc_pbx inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum

Primary key (assigned automatcially for new accounts)

=item id

(Unique?) number of external record

=item title

PBX name

=item max_extensions

Maximum number of extensions

=item max_simultaneous

Maximum number of simultaneous users

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new PBX tenant.  To add the PBX tenant to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_pbx'; }

sub table_info {
  {
    'name' => 'PBX',
    'name_plural' => 'PBXs', #optional,
    'longname_plural' => 'PBXs', #optional
    'sorts' => 'svcnum', # optional sort field (or arrayref of sort fields, main first)
    'display_weight' => 70,
    'cancel_weight'  => 90,
    'fields' => {
      'id'    => 'ID',
      'title' => 'Name',
      'max_extensions' => 'Maximum number of User Extensions',
      'max_simultaneous' => 'Maximum number of simultaneous users',
#      'field'         => 'Description',
#      'another_field' => { 
#                           'label'     => 'Description',
#			   'def_label' => 'Description for service definitions',
#			   'type'      => 'text',
#			   'disable_default'   => 1, #disable switches
#			   'disable_fixed'     => 1, #
#			   'disable_inventory' => 1, #
#			 },
#      'foreign_key'   => { 
#                           'label'        => 'Description',
#			   'def_label'    => 'Description for service defs',
#			   'type'         => 'select',
#			   'select_table' => 'foreign_table',
#			   'select_key'   => 'key_field_in_table',
#			   'select_label' => 'label_field_in_table',
#			 },

    },
  };
}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

#XXX
#or something more complicated if necessary
#sub search_sql {
#  my($class, $string) = @_;
#  $class->search_sql_field('title', $string);
#}

=item label

Returns the title field for this PBX tenant.

=cut

sub label {
  my $self = shift;
  $self->title;
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=cut

sub insert {
  my $self = shift;
  my $error;

  $error = $self->SUPER::insert;
  return $error if $error;

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

  foreach my $svc_phone (qsearch('svc_phone', { 'pbxsvc' => $self->svcnum } )) {
    $svc_phone->pbxsvc('');
    my $error = $svc_phone->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $svc_acct  (qsearch('svc_acct',  { 'pbxsvc' => $self->svcnum } )) {
    my $error = $svc_acct->delete;
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

#sub replace {
#  my ( $new, $old ) = ( shift, shift );
#  my $error;
#
#  $error = $new->SUPER::replace($old);
#  return $error if $error;
#
#  '';
#}

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid PBX tenant.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;


  $self->SUPER::check;
}

#XXX this is a way-too simplistic implementation
# at the very least, title should be unique across exports that need that or
# controlled by a conf setting or something
sub _check_duplicate {
  my $self = shift;

  my $conf = new FS::Conf;
  return '' if $conf->config('global_unique-pbx_title') eq 'disabled';

  $self->lock_table;

  if ( qsearchs( 'svc_pbx', { 'title' => $self->title } ) ) {
    return "Name in use";
  } else {
    return '';
  }
}

=item get_cdrs

Returns a set of Call Detail Records (see L<FS::cdr>) associated with this 
service.  By default, "associated with" means that the "charged_party" field of
the CDR matches the "title" field of the service.

=over 2

Accepts the following options:

=item for_update => 1: SELECT the CDRs "FOR UPDATE".

=item status => "" (or "done"): Return only CDRs with that processing status.

=item inbound => 1: No-op for svc_pbx CDR processing.

=item default_prefix => "XXX": Also accept the phone number of the service prepended 
with the chosen prefix.

=item disable_src => 1: No-op for svc_pbx CDR processing.

=back

=cut

sub get_cdrs {
  my($self, %options) = @_;
  my %hash = ();
  my @where = ();

  my @fields = ( 'charged_party' );
  $hash{'freesidestatus'} = $options{'status'}
    if exists($options{'status'});
  
  my $for_update = $options{'for_update'} ? 'FOR UPDATE' : '';

  my $title = $self->title;

  my $prefix = $options{'default_prefix'};

  my @orwhere =  map " $_ = '$title'        ", @fields;
  push @orwhere, map " $_ = '$prefix$title' ", @fields
    if length($prefix);
  if ( $prefix =~ /^\+(\d+)$/ ) {
    push @orwhere, map " $_ = '$1$title' ", @fields
  }

  push @where, ' ( '. join(' OR ', @orwhere ). ' ) ';

  if ( $options{'begin'} ) {
    push @where, 'startdate >= '. $options{'begin'};
  }
  if ( $options{'end'} ) {
    push @where, 'startdate < '.  $options{'end'};
  }

  my $extra_sql = ( keys(%hash) ? ' AND ' : ' WHERE ' ). join(' AND ', @where );

  my @cdrs =
    qsearch( {
      'table'      => 'cdr',
      'hashref'    => \%hash,
      'extra_sql'  => $extra_sql,
      'order_by'   => "ORDER BY startdate $for_update",
    } );

  @cdrs;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

