package FS::part_pkg_usage;

use strict;
use base qw( FS::m2m_Common FS::Record );
use FS::Record qw( qsearch qsearchs );
use Scalar::Util qw(blessed);

=head1 NAME

FS::part_pkg_usage - Object methods for part_pkg_usage records

=head1 SYNOPSIS

  use FS::part_pkg_usage;

  $record = new FS::part_pkg_usage \%hash;
  $record = new FS::part_pkg_usage { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_usage object represents a stock of usage minutes (generally
for voice services) included in a package definition.  FS::part_pkg_usage 
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item pkgusagepart - primary key

=item pkgpart - the package definition (L<FS::part_pkg>)

=item minutes - the number of minutes included per billing cycle

=item priority - the relative order in which to use this stock of minutes.

=item shared - 'Y' to allow these minutes to be shared with other packages
belonging to the same customer.  Otherwise, only usage allocated to this
package will use this stock of minutes.

=item rollover - 'Y' to allow unused minutes to carry over between billing
cycles.  Otherwise, the available minutes will reset to the value of the 
"minutes" field upon billing.

=item description - a text description of this stock of minutes

=back

=head1 METHODS

=over 4

=item new HASHREF

=item insert CLASSES

=item replace CLASSES

CLASSES can be an array or hash of usage classnums (see L<FS::usage_class>)
to link to this record.

=item delete

=cut

sub table { 'part_pkg_usage'; }

sub insert {
  my $self = shift;
  my $opt = ref($_[0]) eq 'HASH' ? shift : { @_ };

  $self->SUPER::insert
  || $self->process_m2m( 'link_table'   => 'part_pkg_usage_class',
                         'target_table' => 'usage_class',
                         'params'       => $opt,
  );
}

sub replace {
  my $self = shift;
  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $self->replace_old;
  my $opt = ref($_[0]) eq 'HASH' ? $_[0] : { @_ };
  $self->SUPER::replace($old)
  || $self->process_m2m( 'link_table'   => 'part_pkg_usage_class',
                         'target_table' => 'usage_class',
                         'params'       => $opt,
  );
}

sub delete {
  my $self = shift;
  $self->process_m2m( 'link_table'   => 'part_pkg_usage_class',
                      'target_table' => 'usage_class',
                      'params'       => {},
  ) || $self->SUPER::delete;
}

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('pkgusagepart')
    || $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_float('minutes')
    || $self->ut_numbern('priority')
    || $self->ut_flag('shared')
    || $self->ut_flag('rollover')
    || $self->ut_textn('description')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item classnums

Returns the usage class numbers that are allowed to use minutes from this
pool.

=cut

sub classnums {
  my $self = shift;
  if (!$self->get('classnums')) {
    my $classnums = [
      map { $_->classnum }
      qsearch('part_pkg_usage_class', { 'pkgusagepart' => $self->pkgusagepart })
    ];
    $self->set('classnums', $classnums);
  }
  @{ $self->get('classnums') };
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

