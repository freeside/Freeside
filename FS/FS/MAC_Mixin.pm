package FS::MAC_Mixin;

use strict;
#use FS::Record qw(qsearch);
#use FS::Conf;
# careful about importing anything here--it will end up in a LOT of 
# namespaces

#use vars qw(@subclasses $DEBUG $conf);

#$DEBUG = 0;

# any subclass that can have MAC addresses needs to be added here
#@subclasses = (qw(FS::svc_broadband FS::svc_cable));

#sub conf {
#  $conf ||= FS::Conf->new;
#}

=head1 NAME

FS::MAC_Mixin - Mixin class for objects that have MAC addresses assigned.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head1 METHODS

=over 4

=item mac_addr_pretty

=cut

sub mac_addr_pretty {
  my $self = shift;
  $self->mac_addr_formatted('U',':');
}

=item mac_addr_formatted CASE DELIMITER

Format the MAC address (for use by exports).  If CASE starts with "l"
(for "lowercase"), it's returned in lowercase.  DELIMITER is inserted
between octets.

=cut

sub mac_addr_formatted {
  my $self = shift;
  my ($case, $delim) = @_;
  my $addr = $self->mac_addr;
  $addr = lc($addr) if $case =~ /^l/i;
  join( $delim || '', $addr =~ /../g );
}

=back

=head1 BUGS

=cut

1; 
