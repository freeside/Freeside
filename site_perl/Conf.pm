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
  my $dir = $self->{dir};
  -e $dir or die "FATAL: $dir doesn't exist!";
  -d $dir or die "FATAL: $dir isn't a directory!";
  -r $dir or die "FATAL: Can't read $dir!";
  -x $dir or die "FATAL: $dir not searchable (executable)!";
  $dir;
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
      /^(.*)$/
        or die "Illegal line (array context) in $dir/$file:\n$_\n";
      $1;
    } <$fh>;
  } else {
    <$fh> =~ /^(.*)$/
      or die "Illegal line (scalar context) in $dir/$file:\n$_\n";
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
Revision 1.4  1999-05-11 10:09:13  ivan
try to diagnose strange multiple-line problem

Revision 1.3  1999/03/29 01:29:33  ivan
die unless the configuration directory exists

Revision 1.2  1998/11/13 04:08:44  ivan
no default default_dir (ironic)


=cut

1;
