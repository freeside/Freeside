package FS::ConfItem;

=head1 NAME

FS::ConfItem - Configuration option meta-data.

=head1 SYNOPSIS

  use FS::Conf;
  @config_items = $conf->config_items;

  foreach $item ( @config_items ) {
    $key = $item->key;
    $section = $item->section;
    $description = $item->description;
  }

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item new

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = @_ ? shift : {};
  bless ($self, $class);
}

=item key

=item section

=item description

=cut

sub AUTOLOAD {
  my $self = shift;
  my $field = $AUTOLOAD;
  $field =~ s/.*://;
  $self->{$field};
}

=back

=head1 BUGS

Terse docs.

=head1 SEE ALSO

L<FS::Conf>

=cut

1;

