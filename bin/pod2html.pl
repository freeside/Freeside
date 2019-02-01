#!/usr/bin/env perl

=head1 NAME

pod2html.pl

=head1 DESCRIPTION

Generate HTML from POD documentation

Search directories /usr/local/share/perl and /usr/local/bin

Output HTML to /var/www/html/freeside-doc

=cut

use strict;
use warnings;
use v5.10;

use Pod::Simple::Search;
use Pod::Simple::HTML;
use Pod::Simple::HTMLBatch;

# Disable this to only build docs for Freeside modules
# This will cause links to non-freeside packages to be broken,
# but save 30-60secs during build process
my $include_system_perl_modules = 1;


my $html_dir = shift @ARGV
  or HELP_MESSAGE('Please specify an OUTPUT_DIRECTORY');

HELP_MESSAGE("Directory $html_dir: No write access!")
  unless -w $html_dir;


my $parser = Pod::Simple::HTMLBatch->new;

# Uncomment to suppress status output to STDIN
# $parser->verbose(0);

$parser->search_class('Inline::Pod::Simple::Search');
$parser->html_render_class('Inline::Pod::Simple::HTML');

# Customized HTML output
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

$parser->contents_page_start(
  "$html_before_title Freeside Documentation Index $html_after_title"
);
$parser->contents_page_end( $html_footer );

my @search_dirs = (
  '/usr/local/share/perl/5.24.1',
  '/usr/local/bin',
  $include_system_perl_modules ? (
    '/usr/share/perl5',
    '/usr/share/perl/5.24',
    '/usr/share/perl/5.24.1',
  ) : (),
);

$parser->batch_convert( \@search_dirs, $html_dir );

sub HELP_MESSAGE {
  my $error = shift;
  print " ERROR: $error \n"
    if $error;
  print "
    Tool to generate HTML from Freeside POD documentation

    Usage: pod2html.pl OUTPUT_DIRECTORY

  ";
  exit;
}



# Subclass Pod::Simple::Search to render POD from files without
# normal perl extensions like PL and PM
package Inline::Pod::Simple::Search;
use base 'Pod::Simple::Search';

sub new {
  my $class = shift;
  my $self = Pod::Simple::Search->new( @_ );
  $self->laborious(1);
  $self;
}
1;


# Subclass Pod::Simple::HTML to control HTML output
package Inline::Pod::Simple::HTML;
use base 'Pod::Simple::HTML';

sub html_header_before_title { $html_before_title }
sub html_header_after_title { $html_after_title }
sub html_footer { $html_footer }

1;
