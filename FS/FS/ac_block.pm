package FS::ac_block;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs qsearch );
use FS::ac_type;
use FS::ac;
use FS::svc_broadband;
use NetAddr::IP;

@ISA = qw( FS::Record );

=head1 NAME

FS::ac - Object methods for ac records

=head1 SYNOPSIS

  use FS::ac_block;

  $record = new FS::ac_block \%hash;
  $record = new FS::ac_block { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::ac_block record describes an address block assigned for broadband 
access.  FS::ac_block inherits from FS::Record.  The following fields are 
currently supported:

=over 4

=item acnum - the access concentrator (see L<FS::ac_type>) to which this 
block is assigned.

=item ip_gateway - the gateway address used by customers within this block.  
This functions as the primary key.

=item ip_netmask - the netmask of the block, expressed as an integer.

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'ac_block'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this record from the database.  If there is an error, returns the
error, otherwise returns false.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_number('acnum')
    || $self->ut_ip('ip_gateway')
    || $self->ut_number('ip_netmask')
  ;
  return $error if $error;

  return "Unknown acnum"
    unless $self->ac;

  my $self_addr = new NetAddr::IP ($self->ip_gateway, $self->ip_netmask);
  return "Cannot parse address: ". $self->ip_gateway . '/' . $self->ip_netmask
    unless $self_addr;

  my @block = grep {
    my $block_addr = new NetAddr::IP ($_->ip_gateway, $_->ip_netmask);
    if($block_addr->contains($self_addr) 
    or $self_addr->contains($block_addr)) { $_; };
  } qsearch( 'ac_block', {});

  foreach(@block) {
    return "Block intersects existing block ".$_->ip_gateway."/".$_->ip_netmask;
  }

  '';
}


=item ac

Returns the L<FS::ac> object corresponding to this object.

=cut

sub ac {
  my $self = shift;
  return qsearchs('ac', { acnum => $self->acnum });
}

=item svc_broadband

Returns a list of L<FS::svc_broadband> objects associated
with this object.

=cut

#sub svc_broadband {
#  my $self = shift;
#  my @svc = qsearch('svc_broadband', { actypenum => $self->ac->ac_type->actypenum });
#  return grep { 
#    my $svc_addr = new NetAddr::IP($_->ip_addr, $_->ip_netmask);
#    $self_addr->contains($svc_addr);
#  } @svc;
#}

=back

=cut

1;

