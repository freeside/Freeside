package FS::Misc::Pod2Html;
use strict;
use warnings;
use Carp qw( croak );
use Pod::Simple::HTML;
use Pod::Simple::HTMLBatch;
use Pod::Simple::Search;

use base 'Exporter';
our @EXPORT_OK = qw(
  fs_pod2html
  $include_system_perl_modules
  $quiet_mode
);

our $include_system_perl_modules = 1;
our $quiet_mode = 0;

=head1 NAME

FS::Misc::Pod2Html

=head1 DESCRIPTION

Generate HTML from POD Documentation

=head1 SYNOPSIS

Usage:

  use FS::Misc::Pod2Html 'fs_pod2html';
  fs_pod2html( '/output/directory' );

=head2 fs_pod2html /output/directory/

Generates Freeside-themed HTML docuemtnation from installed perl modules

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

sub fs_pod2html {
  my $html_dir = shift
    or croak 'Please specify an output directory';

  croak "Directory $html_dir: No write access"
    unless -w $html_dir;

  my @search_dirs = (
    '/usr/local/share/perl/5.24.1',
    '/usr/local/bin',
    $include_system_perl_modules ? (
      '/usr/share/perl5',
      '/usr/share/perl/5.24',
      '/usr/share/perl/5.24.1',
    ) : (),
  );

  my $parser = Pod::Simple::HTMLBatch->new;

  $parser->verbose(0)
    if $quiet_mode;

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
