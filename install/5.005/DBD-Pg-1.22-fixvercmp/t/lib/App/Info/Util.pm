package App::Info::Util;

# $Id: Util.pm,v 1.1 2004-04-29 09:21:28 ivan Exp $

=head1 NAME

App::Info::Util - Utility class for App::Info subclasses

=head1 SYNOPSIS

  use App::Info::Util;

  my $util = App::Info::Util->new;

  # Subclasses File::Spec.
  my @paths = $util->paths;

  # First directory that exists in a list.
  my $dir = $util->first_dir(@paths);

  # First directory that exists in a path.
  $dir = $util->first_path($ENV{PATH});

  # First file that exists in a list.
  my $file = $util->first_file('this.txt', '/that.txt', 'C:\\foo.txt');

  # First file found among file base names and directories.
  my $files = ['this.txt', 'that.txt'];
  $file = $util->first_cat_file($files, @paths);

=head1 DESCRIPTION

This class subclasses L<File::Spec|File::Spec> and adds its own methods in
order to offer utility methods to L<App::Info|App::Info> classes. Although
intended to be used by App::Info subclasses, in truth App::Info::Util's
utility may be considered more general, so feel free to use it elsewhere.

The methods added in addition to the usual File::Spec suspects are designed to
facilitate locating files and directories on the file system, as well as
searching those files. The assumption is that, in order to provide useful
metadata about a given software package, an App::Info subclass must find
relevant files and directories and parse them with regular expressions. This
class offers methods that simplify those tasks.

=cut

use strict;
use File::Spec ();
use vars qw(@ISA $VERSION);
@ISA = qw(File::Spec);
$VERSION = '0.22';

my %path_dems = (MacOS   => qr',',
                 MSWin32 => qr';',
                 os2     => qr';',
                 VMS     => undef,
                 epoc    => undef);

my $path_dem = exists $path_dems{$^O} ? $path_dems{$^O} : qr':';

=head1 CONSTRUCTOR

=head2 new

  my $util = App::Info::Util->new;

This is a very simple constructor that merely returns an App::Info::Util
object. Since, like its File::Spec super class, App::Info::Util manages no
internal data itself, all methods may be used as class methods, if one prefers
to. The constructor here is provided merely as a convenience.

=cut

sub new { bless {}, ref $_[0] || $_[0] }

=head1 OBJECT METHODS

In addition to all of the methods offered by its super class,
L<File::Spec|File::Spec>, App::Info::Util offers the following methods.

=head2 first_dir

  my @paths = $util->paths;
  my $dir = $util->first_dir(@dirs);

Returns the first file system directory in @paths that exists on the local
file system. Only the first item in @paths that exists as a directory will be
returned; any other paths leading to non-directories will be ignored.

=cut

sub first_dir {
    shift;
    foreach (@_) { return $_ if -d }
    return;
}

=head2 first_path

  my $path = $ENV{PATH};
  $dir = $util->first_path($path);

Takes the $path string and splits it into a list of directory paths, based on
the path demarcator on the local file system. Then calls C<first_dir()> to
return the first directoy in the path list that exists on the local file
system. The path demarcator is specified for the following file systems:

=over 4

=item MacOS: ","

=item MSWin32: ";"

=item os2: ";"

=item VMS: undef

This method always returns undef on VMS. Patches welcome.

=item epoc: undef

This method always returns undef on epoch. Patches welcome.

=item Unix: ":"

All other operating systems are assumed to be Unix-based.

=back

=cut

sub first_path {
    return unless $path_dem;
    shift->first_dir(split /$path_dem/, shift)
}

=head2 first_file

  my $file = $util->first_file(@filelist);

Examines each of the files in @filelist and returns the first one that exists
on the file system. The file must be a regular file -- directories will be
ignored.

=cut

sub first_file {
    shift;
    foreach (@_) { return $_ if -f }
    return;
}

=head2 first_exe

  my $exe = $util->first_exe(@exelist);

Examines each of the files in @exelist and returns the first one that exists
on the file system as an executable file. Directories will be ignored.

=cut

sub first_exe {
    shift;
    foreach (@_) { return $_ if -f && -x }
    return;
}

=head2 first_cat_path

  my $file = $util->first_cat_path('ick.txt', @paths);
  $file = $util->first_cat_path(['this.txt', 'that.txt'], @paths);

The first argument to this method may be either a file or directory base name
(that is, a file or directory name without a full path specification), or a
reference to an array of file or directory base names. The remaining arguments
constitute a list of directory paths. C<first_cat_path()> processes each of
these directory paths, concatenates (by the method native to the local
operating system) each of the file or directory base names, and returns the
first one that exists on the file system.

For example, let us say that we were looking for a file called either F<httpd>
or F<apache>, and it could be in any of the following paths:
F</usr/local/bin>, F</usr/bin/>, F</bin>. The method call looks like this:

  my $httpd = $util->first_cat_path(['httpd', 'apache'], '/usr/local/bin',
                                    '/usr/bin/', '/bin');

If the OS is a Unix variant, C<first_cat_path()> will then look for the first
file that exists in this order:

=over 4

=item /usr/local/bin/httpd

=item /usr/local/bin/apache

=item /usr/bin/httpd

=item /usr/bin/apache

=item /bin/httpd

=item /bin/apache

=back

The first of these complete paths to be found will be returned. If none are
found, then undef will be returned.

=cut

sub first_cat_path {
    my $self = shift;
    my $files = ref $_[0] ? shift() : [shift()];
    foreach my $p (@_) {
        foreach my $f (@$files) {
            my $path = $self->catfile($p, $f);
            return $path if -e $path;
        }
    }
    return;
}

=head2 first_cat_dir

  my $dir = $util->first_cat_dir('ick.txt', @paths);
  $dir = $util->first_cat_dir(['this.txt', 'that.txt'], @paths);

Funtionally identical to C<first_cat_path()>, except that it returns the
directory path in which the first file was found, rather than the full
concatenated path. Thus, in the above example, if the file found was
F</usr/bin/httpd>, while C<first_cat_path()> would return that value,
C<first_cat_dir()> would return F</usr/bin> instead.

=cut

sub first_cat_dir {
    my $self = shift;
    my $files = ref $_[0] ? shift() : [shift()];
    foreach my $p (@_) {
        foreach my $f (@$files) {
            my $path = $self->catfile($p, $f);
            return $p if -e $path;
        }
    }
    return;
}

=head2 first_cat_exe

  my $exe = $util->first_cat_exe('ick.txt', @paths);
  $exe = $util->first_cat_exe(['this.txt', 'that.txt'], @paths);

Funtionally identical to C<first_cat_path()>, except that it returns the full
path to the first executable file found, rather than simply the first file
found.

=cut

sub first_cat_exe {
    my $self = shift;
    my $files = ref $_[0] ? shift() : [shift()];
    foreach my $p (@_) {
        foreach my $f (@$files) {
            my $path = $self->catfile($p, $f);
            return $path if -f $path && -x $path;
        }
    }
    return;
}

=head2 search_file

  my $file = 'foo.txt';
  my $regex = qr/(text\s+to\s+find)/;
  my $value = $util->search_file($file, $regex);

Opens C<$file> and executes the C<$regex> regular expression against each line
in the file. Once the line matches and one or more values is returned by the
match, the file is closed and the value or values returned.

For example, say F<foo.txt> contains the line "Version 6.5, patch level 8",
and you need to grab each of the three version parts. All three parts can
be grabbed like this:

  my $regex = qr/Version\s+(\d+)\.(\d+),[^\d]*(\d+)/;
  my @nums = $util->search_file($file, $regex);

Now C<@nums> will contain the values C<(6, 5, 8)>. Note that in a scalar
context, the above search would yeild an array reference:

  my $regex = qr/Version\s+(\d+)\.(\d+),[^\d]*(\d+)/;
  my $nums = $util->search_file($file, $regex);

So now C<$nums> contains C<[6, 5, 8]>. The same does not hold true if the
match returns only one value, however. Say F<foo.txt> contains the line
"king of the who?", and you wish to know who the king is king of. Either
of the following two calls would get you the data you need:

  my $minions = $util->search_file($file, qr/King\s+of\s+(.*)/);
  my @minions = $util->search_file($file, qr/King\s+of\s+(.*)/);

In the first case, because the regular expression contains only one set of
parentheses, C<search_file()> will simply return that value: C<$minions>
contains the string "the who?". In the latter case, C<@minions> of course
contains a single element: C<("the who?")>.

Note that a regular expression without parentheses -- that is, one that
doesn't grab values and put them into $1, $2, etc., will never successfully
match a line in this method. You must include something to parentetically
match. If you just want to know the value of what was matched, parenthesize
the whole thing and if the value returns, you have a match. Also, if you need
to match patterns across lines, try using multiple regular expressions with
C<multi_search_file()>, instead.

=cut

sub search_file {
    my ($self, $file, $regex) = @_;
    return unless $file && $regex;
    open F, "<$file" or Carp::croak "Cannot open $file: $!\n";
    my @ret;
    while (<F>) {
        # If we find a match, we're done.
        (@ret) = /$regex/ and last;
    }
    close F;
    # If the match returned an more than one value, always return the full
    # array. Otherwise, return just the first value in a scalar context.
    return unless @ret;
    return wantarray ? @ret : $#ret <= 0 ? $ret[0] : \@ret;
}

=head2 multi_search_file

  my @regexen = (qr/(one)/, qr/(two)\s+(three)/);
  my @matches = $util->multi_search_file($file, @regexen);

Like C<search_file()>, this mehod opens C<$file> and parses it for regular
expresion matches. This method, however, can take a list of regular
expressions to look for, and will return the values found for all of them.
Regular expressions that match and return multiple values will be returned as
array referernces, while those that match and return a single value will
return just that single value.

For example, say you are parsing a file with lines like the following:

  #define XML_MAJOR_VERSION 1
  #define XML_MINOR_VERSION 95
  #define XML_MICRO_VERSION 2

You need to get each of these numbers, but calling C<search_file()> for each
of them would be wasteful, as each call to C<search_file()> opens the file and
parses it. With C<multi_search_file()>, on the other hand, the file will be
opened only once, and, once all of the regular expressions have returned
matches, the file will be closed and the matches returned.

Thus the above values can be collected like this:

  my @regexen = ( qr/XML_MAJOR_VERSION\s+(\d+)$/,
                  qr/XML_MINOR_VERSION\s+(\d+)$/,
                  qr/XML_MICRO_VERSION\s+(\d+)$/ );

  my @nums = $file->multi_search_file($file, @regexen);

The result will be that C<@nums> contains C<(1, 95, 2)>. Note that
C<multi_file_search()> tries to do the right thing by only parsing the file
until all of the regular expressions have been matched. Thus, a large file
with the values you need near the top can be parsed very quickly.

As with C<search_file()>, C<multi_search_file()> can take regular expressions
that match multiple values. These will be returned as array references. For
example, say the file you're parsing has files like this:

  FooApp Version 4
  Subversion 2, Microversion 6

To get all of the version numbers, you can either use three regular
expressions, as in the previous example:

  my @regexen = ( qr/FooApp\s+Version\s+(\d+)$/,
                  qr/Subversion\s+(\d+),/,
                  qr/Microversion\s+(\d$)$/ );

  my @nums = $file->multi_search_file($file, @regexen);

In which case C<@nums> will contain C<(4, 2, 6)>. Or, you can use just two
regular expressions:

  my @regexen = ( qr/FooApp\s+Version\s+(\d+)$/,
                  qr/Subversion\s+(\d+),\s+Microversion\s+(\d$)$/ );

  my @nums = $file->multi_search_file($file, @regexen);

In which case C<@nums> will contain C<(4, [2, 6])>. Note that the two
parentheses that return values in the second regular expression cause the
matches to be returned as an array reference.

=cut

sub multi_search_file {
    my ($self, $file, @regexen) = @_;
    return unless $file && @regexen;
    my @each = @regexen;
    open F, "<$file" or Carp::croak "Cannot open $file: $!\n";
    my %ret;
    while (my $line = <F>) {
        my @splice;
        # Process each of the regular expresssions.
        for (my $i = 0; $i < @each; $i++) {
            if ((my @ret) = $line =~ /$each[$i]/) {
                # We have a match! If there's one match returned, just grab
                # it. If there's more than one, keep it as an array ref.
                $ret{$each[$i]} = $#ret > 0 ? \@ret : $ret[0];
                # We got values for this regex, so not its place in the @each
                # array.
                push @splice, $i;
            }
        }
        # Remove any regexen that have already found a match.
        for (@splice) { splice @each, $_, 1 }
        # If there are no more regexes, we're done -- no need to keep
        # processing lines in the file!
        last unless @each;
    }
    close F;
    return unless %ret;
    return wantarray ? @ret{@regexen} : \@ret{@regexen};
}

1;
__END__

=head1 BUGS

Report all bugs via the CPAN Request Tracker at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Info>.

=head1 AUTHOR

David Wheeler <L<david@wheeler.net|"david@wheeler.net">>

=head1 SEE ALSO

L<App::Info|App::Info>, L<File::Spec|File::Spec>,
L<App::Info::HTTPD::Apache|App::Info::HTTPD::Apache>
L<App::Info::RDBMS::PostgreSQL|App::Info::RDBMS::PostgreSQL>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002, David Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
