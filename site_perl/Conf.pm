package FS::Conf;

use vars qw($default_dir);
use IO::File;

=head1 NAME

FS::Conf - Read access to Freeside configuration values

=head1 SYNOPSIS

  use FS::Conf;

  $conf = new FS::Conf "/config/directory";

  $FS::Conf::default_dir = "/config/directory";
  $conf = new FS::Conf;

  $dir = $conf->dir;

  $value = $conf->config('key');
  @list  = $conf->config('key');
  $bool  = $conf->exists('key');

=head1 DESCRIPTION

Read access to Freeside configuration values.  Keys currently map to filenames,
but this may change in the future.

=head1 METHODS

=over 4

=item new [ DIRECTORY ]

Create a new configuration object.  A directory arguement is required if
$FS::Conf::default_dir has not been set.

=cut

sub new {
  my($proto,$dir) = @_;
  my($class) = ref($proto) || $proto;
  my($self) = { 'dir' => $dir || $default_dir } ;
  bless ($self, $class);
}

=item dir

Returns the directory.

=cut

sub dir {
  my($self) = @_;
  $self->{dir};
}

=item config 

Returns the configuration value or values (depending on context) for key.

=cut

sub config {
  my($self,$file)=@_;
  my($dir)=$self->dir;
  my $fh = new IO::File "<$dir/$file" or return;
  if ( wantarray ) {
    map {
      /^(.*)$/ or die "Illegal line in $dir/$file:\n$_\n";
      $1;
    } <$fh>;
  } else {
    <$fh> =~ /^(.*)$/ or die "Illegal line in $dir/$file:\n$_\n";
    $1;
  }
}

=item exists

Returns true if the specified key exists, even if the corresponding value
is undefined.

=cut

sub exists {
  my($self,$file)=@_;
  my($dir) = $self->dir;
  -e "$dir/$file";
}

=back

=head1 BUGS

Write access (with locking) should be implemented.

=head1 SEE ALSO

config.html from the base documentation contains a list of configuration files.

=head1 HISTORY

Ivan Kohler <ivan@sisd.com> 98-sep-6

sub exists forgot to fetch $dir ivan@sisd.com 98-sep-27

$Log: Conf.pm,v $
Revision 1.2  1998-11-13 04:08:44  ivan
no default default_dir (ironic)


=cut

1;
