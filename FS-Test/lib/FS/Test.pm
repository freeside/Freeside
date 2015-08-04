package FS::Test;

use 5.006;
use strict;
use warnings FATAL => 'all';

use File::ShareDir 'dist_dir';
use WWW::Mechanize;
use File::chdir;
use URI;
use File::Slurp qw(write_file);
use Class::Accessor 'antlers';

our $VERSION = '0.01';

=head1 NAME

Freeside testing suite

=head1 CLASS METHODS

=over 4

=item share_dir

Returns the path to the shared data directory, which contains the reference
database image, the test plan, and probably other stuff.

=cut

sub share_dir {
  dist_dir('FS-Test')
}

=item new OPTIONS

Creates a test session. OPTIONS must contain 'dir', a directory to save the 
output files into (this may eventually default to a temp directory). It can
optionally contain:

- fsurl: the root Freeside url [http://localhost/freeside]
- user: the Freeside test username [test]
- pass: the Freeside test password [test]

=cut

has dir   => ( is => 'rw' );
has fsurl => ( is => 'rw' );
has user  => ( is => 'rw' );
has pass  => ( is => 'rw' );
has mech  => ( is => 'rw' );

sub new {
  my $class = shift;
  my $self = {
    fsurl => 'http://localhost/freeside',
    user  => 'test',
    pass  => 'test',
    @_
  };
  bless $self;

  # strip trailing slash, if any; it causes problems
  $self->{fsurl} =~ s(/$)();

  die "FS::Test->new: 'dir' required" unless $self->dir;
  if ( ! -d $self->dir ) {
    mkdir $self->dir
      or die "can't create '".$self->dir."': $!";
  }
  if ( ! -w $self->dir ) {
    die "FS::Test->new: can't write to '". $self->dir . "'";
  }

  $self->mech( WWW::Mechanize->new( autocheck => 0 ) );

  #freeside v3
  $self->mech->credentials( $self->user, $self->pass );

  return $self;
}

=back

=head1 METHODS

=over 4

=item fetch PATHS...

Takes one or more PATHS (Freeside URIs, relative to $self->fsurl, including
query parameters) and downloads them from the web server, into the output
directory. Currently this will write progress messages to standard output.
If you don't like that, it's open source, fix it.

=cut

sub fetch {
  my $self = shift;

  local $CWD = $self->dir;

  my $base_uri = URI->new($self->fsurl);
  my $basedirs = () = $base_uri->path_segments;

  foreach my $path (@_) {
    $path =~ s/^\s+//;
    $path =~ s/\s+$//;
    next if !$path;

    if ($path =~ /^#(.*)/) {
      print "$path\n";
      next;
    }

    my $uri = URI->new( $self->fsurl . '/' . $path);
    print $uri->path;
    my $response = $self->mech->get($uri);
    print " - " . $response->code . "\n";
    next unless $response->is_success;

    local $CWD;
    my @dirs = $uri->path_segments;
    splice @dirs, 0, $basedirs;

    if ( length($uri->query) ) {
      # if there's a query string, use the (server-side) file name as the 
      # last directory, and the query string as the local file name; this 
      # allows multiple tests that differ only in the query string.
      push @dirs, $uri->query;
    }
    my $file = pop @dirs;
    # make the filename safe for inclusion in a makefile/shell script.
    # & and ; are both bad; using ":" is reversible and unambiguous (because
    # it can't appear in query params)
    $file =~ s/&/:/g;
    foreach my $dir (@dirs) {
      mkdir $dir unless -d $dir;
      push @CWD, $dir;
    }
    write_file($file, {binmode => ':utf8'}, $response->decoded_content);
  }
}

1; # End of FS::Test
