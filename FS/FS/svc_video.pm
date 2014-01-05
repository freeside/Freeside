package FS::svc_video;
use base qw( FS::svc_MAC_Mixin FS::svc_Common );

use strict;
use Tie::IxHash;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::svc_video - Object methods for svc_video records

=head1 SYNOPSIS

  use FS::svc_video;

  $record = new FS::svc_video \%hash;
  $record = new FS::svc_video { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_video object represents an IPTV or video-on-demand service.
FS::svc_video inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item svcnum

primary key

=item smartcard_num

smartcard_num

=item mac_addr

mac_addr

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_video'; }

sub search_sql {
  my( $class, $string ) = @_;
  if ( $string =~ /^([A-F0-9]{12})$/i ) {
    $class->search_sql_field('mac_addr', uc($string));
  } elsif ( $string =~ /^(([A-F0-9]{2}:){5}([A-F0-9]{2}))$/i ) {
    $string =~ s/://g;
    $class->search_sql_field('mac_addr', uc($string) );
  } elsif ( $string =~ /^(\d+)$/ ) {
    $class->search_sql_field('smartcard_num', $1);
  } else {
    '1 = 0'; #false
  }
}

sub table_info {
  my %opts = ( 'type' => 'text', 
               'disable_select' => 1,
               'disable_inventory' => 1,
             );

  tie my %fields, 'Tie::IxHash',
    'svcnum'         => { label => 'Service' },
    'smartcard_num'  => { label     => 'Smartcard #',
                          size      => 17,
                          maxlength => 16,
                          %opts,
                        },
    'mac_addr'       => { label          => 'MAC address',
                          type           => 'input-mac_addr',
                          value_callback => sub {
                                             my $svc = shift;
                                             join(':', $svc->mac_addr =~ /../g);
                                            },
                        },
    'duration'       => { label     => 'Duration (days)',
                          size      => 4,
                          maxlength => 3,
                          %opts,
                        },
  ;

  {
    'name'                => 'Video', # service',
    #'name_plural'     => '', #optional,
    #'longname_plural' => '', #optional
    'fields'              => \%fields,
    #'sorts'               => [ 'smartcard_num' ],
    'display_weight'      => 57.5,
    'cancel_weight'       => 70, #?  no deps, so
  };

}

sub label {
  my $self = shift;
  my $label = $self->smartcard_num;
  $label .= ', MAC:'. $self->mac_addr
    if $self->mac_addr;
  return $label;
}

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
    $self->ut_numbern('svcnum')
    || $self->ut_number('smartcard_num')
    || $self->ut_mac_addr('mac_addr')
    || $self->ut_number('duration')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

