package FS::part_export;

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG %exports );
use Exporter;
use Tie::IxHash;
use FS::Record qw( qsearch qsearchs dbh );
use FS::option_Common;
use FS::part_svc;
use FS::part_export_option;
use FS::export_svc;

#for export modules, though they should probably just use it themselves
use FS::queue;

@ISA = qw( FS::option_Common );
@EXPORT_OK = qw(export_info);

$DEBUG = 0;

=head1 NAME

FS::part_export - Object methods for part_export records

=head1 SYNOPSIS

  use FS::part_export;

  $record = new FS::part_export \%hash;
  $record = new FS::part_export { 'column' => 'value' };

  #($new_record, $options) = $template_recored->clone( $svcpart );

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

=cut

#=item clone SVCPART
#
#An alternate constructor.  Creates a new export by duplicating an existing
#export.  The given svcpart is assigned to the new export.
#
#Returns a list consisting of the new export object and a hashref of options.
#
#=cut
#
#sub clone {
#  my $self = shift;
#  my $class = ref($self);
#  my %hash = $self->hash;
#  $hash{'exportnum'} = '';
#  $hash{'svcpart'} = shift;
#  ( $class->new( \%hash ),
#    { map { $_->optionname => $_->optionvalue }
#        qsearch('part_export_option', { 'exportnum' => $self->exportnum } )
#    }
#  );
#}

=item insert HASHREF

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If a hash reference of options is supplied, part_export_option records are
created (see L<FS::part_export_option>).

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

  foreach my $export_svc ( $self->export_svc ) {
    my $error = $export_svc->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

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
    || $self->ut_alpha('exporttype')
  ;
  return $error if $error;

  $self->nodomain =~ /^(Y?)$/ or return "Illegal nodomain: ". $self->nodomain;
  $self->nodomain($1);

  $self->deprecated(1); #BLAH

  #check exporttype?

  $self->SUPER::check;
}

#=item part_svc
#
#Returns the service definition (see L<FS::part_svc>) for this export.
#
#=cut
#
#sub part_svc {
#  my $self = shift;
#  qsearchs('part_svc', { svcpart => $self->svcpart } );
#}

sub part_svc {
  use Carp;
  croak "FS::part_export::part_svc deprecated";
  #confess "FS::part_export::part_svc deprecated";
}

=item svc_x

Returns a list of associated FS::svc_* records.

=cut

sub svc_x {
  my $self = shift;
  map { $_->svc_x } $self->cust_svc;
}

=item cust_svc

Returns a list of associated FS::cust_svc records.

=cut

sub cust_svc {
  my $self = shift;
  map { qsearch('cust_svc', { 'svcpart' => $_->svcpart } ) }
    grep { qsearch('cust_svc', { 'svcpart' => $_->svcpart } ) }
      $self->export_svc;
}

=item export_svc

Returns a list of associated FS::export_svc records.

=cut

sub export_svc {
  my $self = shift;
  qsearch('export_svc', { 'exportnum' => $self->exportnum } );
}

=item export_device

Returns a list of associated FS::export_device records.

=cut

sub export_device {
  my $self = shift;
  qsearch('export_device', { 'exportnum' => $self->exportnum } );
}

=item part_export_option

Returns all options as FS::part_export_option objects (see
L<FS::part_export_option>).

=cut

sub part_export_option {
  my $self = shift;
  $self->option_objects;
}

=item options 

Returns a list of option names and values suitable for assigning to a hash.

=item option OPTIONNAME

Returns the option value for the given name, or the empty string.

=item _rebless

Reblesses the object into the FS::part_export::EXPORTTYPE class, where
EXPORTTYPE is the object's I<exporttype> field.  There should be better docs
on how to create new exports, but until then, see L</NEW EXPORT CLASSES>.

=cut

sub _rebless {
  my $self = shift;
  my $exporttype = $self->exporttype;
  my $class = ref($self). "::$exporttype";
  eval "use $class;";
  #die $@ if $@;
  bless($self, $class) unless $@;
  $self;
}

#these should probably all go away, just let the subclasses define em

=item export_insert SVC_OBJECT

=cut

sub export_insert {
  my $self = shift;
  #$self->rebless;
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
  #$self->rebless;
  $self->_export_replace(@_);
}

=item export_delete

=cut

sub export_delete {
  my $self = shift;
  #$self->rebless;
  $self->_export_delete(@_);
}

=item export_suspend

=cut

sub export_suspend {
  my $self = shift;
  #$self->rebless;
  $self->_export_suspend(@_);
}

=item export_unsuspend

=cut

sub export_unsuspend {
  my $self = shift;
  #$self->rebless;
  $self->_export_unsuspend(@_);
}

#fallbacks providing useful error messages intead of infinite loops
sub _export_insert {
  my $self = shift;
  return "_export_insert: unknown export type ". $self->exporttype;
}

sub _export_replace {
  my $self = shift;
  return "_export_replace: unknown export type ". $self->exporttype;
}

sub _export_delete {
  my $self = shift;
  return "_export_delete: unknown export type ". $self->exporttype;
}

#call svcdb-specific fallbacks

sub _export_suspend {
  my $self = shift;
  #warn "warning: _export_suspened unimplemented for". ref($self);
  my $svc_x = shift;
  my $new = $svc_x->clone_suspended;
  $self->_export_replace( $new, $svc_x );
}

sub _export_unsuspend {
  my $self = shift;
  #warn "warning: _export_unsuspend unimplemented for ". ref($self);
  my $svc_x = shift;
  my $old = $svc_x->clone_kludge_unsuspend;
  $self->_export_replace( $svc_x, $old );
}

=item export_links SVC_OBJECT ARRAYREF

Adds a list of web elements to ARRAYREF specific to this export and SVC_OBJECT.
The elements are displayed in the UI to lead the the operator to external
configuration, monitoring, and similar tools.

=item export_getsettings SVC_OBJECT SETTINGS_HASHREF DEFAUTS_HASHREF

Adds a hashref of settings to SETTINGSREF specific to this export and
SVC_OBJECT.  The elements can be displayed in the UI on the service view.

DEFAULTSREF is a hashref with the same keys where true values indicate the
setting is a default (and thus can be displayed in the UI with less emphasis,
or hidden by default).

=cut

=back

=head1 SUBROUTINES

=over 4

=item export_info [ SVCDB ]

Returns a hash reference of the exports for the given I<svcdb>, or if no
I<svcdb> is specified, for all exports.  The keys of the hash are
I<exporttype>s and the values are again hash references containing information
on the export:

  'desc'     => 'Description',
  'options'  => {
                  'option'  => { label=>'Option Label' },
                  'option2' => { label=>'Another label' },
                },
  'nodomain' => 'Y', #or ''
  'notes'    => 'Additional notes',

=cut

sub export_info {
  #warn $_[0];
  return $exports{$_[0]} || {} if @_;
  #{ map { %{$exports{$_}} } keys %exports };
  my $r = { map { %{$exports{$_}} } keys %exports };
}

#=item exporttype2svcdb EXPORTTYPE
#
#Returns the applicable I<svcdb> for an I<exporttype>.
#
#=cut
#
#sub exporttype2svcdb {
#  my $exporttype = $_[0];
#  foreach my $svcdb ( keys %exports ) {
#    return $svcdb if grep { $exporttype eq $_ } keys %{$exports{$svcdb}};
#  }
#  '';
#}

#false laziness w/part_pkg & cdr
foreach my $INC ( @INC ) {
  foreach my $file ( glob("$INC/FS/part_export/*.pm") ) {
    warn "attempting to load export info from $file\n" if $DEBUG;
    $file =~ /\/(\w+)\.pm$/ or do {
      warn "unrecognized file in $INC/FS/part_export/: $file\n";
      next;
    };
    my $mod = $1;
    my $info = eval "use FS::part_export::$mod; ".
                    "\\%FS::part_export::$mod\::info;";
    if ( $@ ) {
      die "error using FS::part_export::$mod (skipping): $@\n" if $@;
      next;
    }
    unless ( keys %$info ) {
      warn "no %info hash found in FS::part_export::$mod, skipping\n"
        unless $mod =~ /^(passwdfile|null)$/; #hack but what the heck
      next;
    }
    warn "got export info from FS::part_export::$mod: $info\n" if $DEBUG;
    no strict 'refs';
    foreach my $svc (
      ref($info->{'svc'}) ? @{$info->{'svc'}} : $info->{'svc'}
    ) {
      unless ( $svc ) {
        warn "blank svc for FS::part_export::$mod (skipping)\n";
        next;
      }
      $exports{$svc}->{$mod} = $info;
    }
  }
}

=back

=head1 NEW EXPORT CLASSES

A module should be added in FS/FS/part_export/ (an example may be found in
eg/export_template.pm)

=head1 BUGS

Hmm... cust_export class (not necessarily a database table...) ... ?

deprecated column...

=head1 SEE ALSO

L<FS::part_export_option>, L<FS::export_svc>, L<FS::svc_acct>,
L<FS::svc_domain>,
L<FS::svc_forward>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

