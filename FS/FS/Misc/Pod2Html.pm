package FS::Misc::Pod2Html;
use strict;
use warnings;
use Carp qw( croak );
use File::Copy;
use Pod::Simple::HTML;
use Pod::Simple::HTMLBatch;
use Pod::Simple::Search;

use base 'Exporter';
our @EXPORT_OK = qw(
  fs_pod2html
  fs_pod2html_from_src
  fs_pod2html_from_dirs
  $include_system_perl_modules
  $quiet_mode
);

our $include_system_perl_modules = 1;
our $quiet_mode = 0;
our $DEBUG = 0;

=head1 NAME

FS::Misc::Pod2Html

=head1 DESCRIPTION

Generate HTML from POD Documentation

=head1 SYNOPSIS

Usage:

  use FS::Misc::Pod2Html 'fs_pod2html';
  fs_pod2html( '/output/directory' );

Also:

  perl -MFS::Misc::Pod2Html -e "FS::Misc::Pod2Html::fs_pod2html('/tmp/pod2html');"

=cut

our $html_before_title = q{
  <% include( '/elements/header.html', 'Developer Documentation' ) %>
  <& /elements/menubar.html,
    'Freeside Perl Modules' => $fsurl.'docs/library/FS.html',
    'Complete Index' => $fsurl.'docs/library/index.html',
  &>

  <div style="width: 90%; margin: 1em auto; font-size: .9em; border: solid 1px #666; background-color: #eee; padding: 1em;">
  <h1 style="margin: .5em; border-bottom: solid 1px #999;">
};

our $html_after_title = q{</h1>};

our $html_footer = q{</div><% include ('/elements/footer.html' ) %>};

=head2 fs_pod2html output_dir

Generates Freeside-themed HTML docuemtnation from installed perl modules

=cut

sub fs_pod2html {
  fs_pod2html_from_dirs(
    shift,
    '/usr/local/share/perl/5.24.1',
    '/usr/local/bin',
    $include_system_perl_modules ? (
      '/usr/share/perl5',
      '/usr/share/perl/5.24',
      '/usr/share/perl/5.24.1',
    ) : (),
  );
}

=head2 fs_pod2html_from_src output_dir

Generate Freeside-themed HTML documentation from a Freeside source tree

Will fail, unless run with CWD at the root of the Freesidse source tree

=cut

sub fs_pod2html_from_src {
  my $html_dir = shift;

  fs_pod2html_from_dirs(
    $html_dir,
    'FS/bin',
    'bin',
    'FS',
    'fs_selfservice/FS-SelfService',
    # '/usr/local/share/perl/5.24.1',
    # '/usr/local/bin',
    $include_system_perl_modules ? (
      '/usr/share/perl5',
      '/usr/share/perl/5.24',
      '/usr/share/perl/5.24.1',
    ) : (),
  );

  # FS-SelfService is loosely packaged:
  #   perl modules are not stored in lib/FS, scripts not stored in /bin, so
  # batch_convert() places these .html in the wrong locations
  #
  # Copy to correct locations, and correct relative links
  copy( "$html_dir/SelfService.html", "$html_dir/FS/SelfService.html" );
  mkdir( "$html_dir/FS/SelfService" );
  copy( "$html_dir/SelfService/XMLRPC.html", "$html_dir/FS/SelfService/XMLRPC.html" );
    for my $sed_cmd (
    'sed -i "s/href=\"\.\//href=\"\.\.\//g" "'.$html_dir.'/FS/SelfService.html"',
    'sed -i "s/href=\"\\..\//href=\"\.\.\/\.\.\//g" "'.$html_dir.'/FS/SelfService/XMLRPC.html"',
  ) {
    `$sed_cmd`
  }
}

=head2 fs_pod2html output_dir @source_scan_dirs

Generate Freeside-themed HTML documentation, scanning the provided directories

=cut

sub fs_pod2html_from_dirs {
  my $html_dir = shift
    or croak 'Please specify an output directory';

  croak "Directory $html_dir: No write access"
    unless -w $html_dir;

  my @search_dirs = @_;

  for my $dir ( @search_dirs ) {
    unless ( -d $dir ) {
      croak "Cannot continue - source directory ($dir) not found! ";
    }
  }

  my $parser = Pod::Simple::HTMLBatch->new;

  $parser->verbose(0)
    if $quiet_mode;

  $parser->verbose(2)
    if $DEBUG;

  $parser->search_class('Inline::Pod::Simple::Search');
  $parser->html_render_class('Inline::Pod::Simple::HTML');
  $parser->contents_page_start(
    "$html_before_title Freeside Documentation Index $html_after_title"
  );
  $parser->contents_page_end( $html_footer );

  $parser->batch_convert( \@search_dirs, $html_dir );
}

1;

=head1 NAME

Inline::Pod::Simple::Search

=head2 DESCRIPTION

Subclass of Pod::Simple::Search

Enable searching for POD in all files instead of just .pl and .pm

=cut

package Inline::Pod::Simple::Search;
use base 'Pod::Simple::Search';

sub new {
  my $class = shift;
  my $self = Pod::Simple::Search->new( @_ );
  $self->laborious(1);
  $self->verbose(2)
    if $DEBUG;
  $self;
}

1;

=head1 NAME

Inline::Pod::Simple::HTML

=head2 DESCRIPTION

Subclass of Pod::Simple::HTML

Customize parsed HTML output

=cut

# Subclass Pod::Simple::HTML to control HTML output
package Inline::Pod::Simple::HTML;
use base 'Pod::Simple::HTML';

sub html_header_before_title { $html_before_title }
sub html_header_after_title { $html_after_title }
sub html_footer { $html_footer }

1;
