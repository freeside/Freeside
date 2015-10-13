package FS::part_pkg_usageprice;
use base qw( FS::Record );

use strict;
use Tie::IxHash;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::part_pkg_usageprice - Object methods for part_pkg_usageprice records

=head1 SYNOPSIS

  use FS::part_pkg_usageprice;

  $record = new FS::part_pkg_usageprice \%hash;
  $record = new FS::part_pkg_usageprice { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_usageprice object represents a usage pricing add-on.
FS::part_pkg_usageprice inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item usagepricepart

primary key

=item pkgpart

pkgpart

=item price

price

=item currency

currency

=item action

action

=item target

target

=item amount

amount


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'part_pkg_usageprice'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('usagepricepart')
    || $self->ut_number('pkgpart')
    || $self->ut_money('price')
    || $self->ut_currencyn('currency')
    || $self->ut_enum('action', [ 'increment', 'set' ])
    || $self->ut_enum('target', [ 'svc_acct.totalbytes', 'svc_acct.seconds',
                                  'svc_conferencing.participants',
#                                  'svc_conferencing.confqualitynum',
                                  'sqlradacct_hour.recur_included_total'
                                ]
                     )
    || $self->ut_text('amount')
  ;
  return $error if $error;

  #Check target against package
  #UI doesn't currently prevent these from happing,
  #so keep error messages informative
  my $part_pkg = $self->part_pkg;
  my $target = $self->target;
  my $label = $self->target_info->{'label'};
  my ($needs_svcdb, $needs_plan);
  if ( $target =~ /^svc_acct.(\w+)$/ ) {
    $needs_svcdb = 'svc_acct';
  } elsif ( $target eq 'svc_conferencing.participants' ) {
    $needs_svcdb = 'svc_conferencing';
  } elsif ( $target =~ /^sqlradacct_hour.(\w+)$/ ) {
    $needs_plan = 'sqlradacct_hour';
  }
  if ($needs_svcdb) {
    my $has_svcdb = 0;
    foreach my $pkg_svc ($part_pkg->pkg_svc) {
      next unless $pkg_svc->quantity;
      my $svcdb = $pkg_svc->part_svc->svcdb;
      $has_svcdb = 1
        if $svcdb eq $needs_svcdb;
      last if $has_svcdb;
    }
    return "Usage pricing add-on \'$label\' can only be used on packages with at least one $needs_svcdb service.\n"
      unless $has_svcdb;
  }
  if ($needs_plan) {
    return "Usage pricing add-on \'$label\' can only be used on packages with pricing plan \'" . 
           FS::part_pkg->plan_info->{$needs_plan}->{'shortname'} . "\'\n"
      unless ref($part_pkg) eq 'FS::part_pkg::' . $needs_plan;
  }

  $self->SUPER::check;
}

=item target_info

Returns a hash reference of information about the target of this object.
Keys are "label" and "multiplier".

=cut

sub target_info {
  my $self = shift;
  $self->targets->{$self->target};
}

=item targets

(Class method)
Returns a hash reference.  Keys are possible values for the "target" field.
Values are hash references with "label" and "multiplier" keys.

=cut

sub targets {

  tie my %targets, 'Tie::IxHash', # once?
    #'svc_acct.totalbytes' => { label      => 'Megabytes',
    #                           multiplier => 1048576,
    #                         },
    'svc_acct.totalbytes' => { label      => 'Total Gigabytes',
                               multiplier => 1073741824,
                             },
    'svc_acct.seconds' => { label      => 'Total Hours',
                            multiplier => 3600,
                          },
    'svc_conferencing.participants' => { label     => 'Conference Participants',
                                         multiplier=> 1,
                                       },
  #this will take more work: set action, not increment..
  #  and then value comes from a select, not a text field
  #  'svc_conferencing.confqualitynum' => { label => 'Conference Quality',
  #                                        },

    # this bypasses usual apply methods, handled entirely in sqlradacct_hour
    'sqlradacct_hour.recur_included_total' => { label => 'Included Gigabytes',
                                                multiplier => 1 }, #recur_included_total is stored in GB
 
  ;

  \%targets;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_pkg>, L<FS::Record>

=cut

1;

