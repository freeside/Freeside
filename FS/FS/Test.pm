package FS::Test;

use 5.006;
use strict;
use warnings FATAL => 'all';

use FS::UID qw(adminsuidsetup);
use FS::Record;
use URI;
use URI::Escape;
use Class::Accessor 'antlers';
use Class::Load qw(load_class);
use File::Spec;
use HTML::Form;

our $VERSION = '0.03';

=head1 NAME

Freeside testing suite

=head1 SYNOPSIS

  use Test::More 'tests' => 1;
  use FS::Test;
  my $FS = FS::Test->new;
  $FS->post('/edit/cust_main.cgi', ... ); # form fields
  ok( !$FS->error );

=head1 PROPERTIES

=over 4

=item page

The content of the most recent page fetched from the UI.

=item redirect

The redirect location (relative to the Freeside root) of the redirect
returned from the UI, if there was one.

=head1 CLASS METHODS

=item new OPTIONS

Creates a test session. OPTIONS may contain:

- user: the Freeside test username [test]
- base: the fake base URL for Mason to use [http://fake.freeside.biz]

=cut

has user      => ( is => 'rw' );
has base      => ( is => 'ro' );
has fs_interp => ( is => 'rw' );
has path      => ( is => 'rw' );
has page      => ( is => 'ro' );
has error     => ( is => 'rw' );
has dbh       => ( is => 'rw' );
has redirect  => ( is => 'rw' );

sub new {
  my $class = shift;
  my $self = {
    user  => 'test',
    page  => '',
    error => '',
    base  => 'http://fake.freeside.biz',
    @_
  };
  $self->{base} = URI->new($self->{base});
  bless $self;

  adminsuidsetup($self->user);
  load_class('FS::Mason');
  $self->dbh( FS::UID::dbh() );

  my ($fs_interp) = FS::Mason::mason_interps('standalone',
    outbuf => \($self->{page})
  );
  $fs_interp->error_mode('fatal');
  $fs_interp->error_format('brief');

  $self->fs_interp( $fs_interp );

  RT::LoadConfig();
  RT::Init();

  return $self;
}

=back

=head1 METHODS

=over 4

=item post PATH, PARAMS

=item post FORM

Submits a request to PATH, through the Mason UI, with arguments in PARAMS.
This will be converted to a URL query string. Anything returned by the UI
will be in the C<page()> property. 

Alternatively, takes an L<HTML::Form> object (with fields filled in, via
the C<param()> method) and submits it.

=cut

sub post {
  my $self = shift;

  # shut up, CGI
  local $CGI::LIST_CONTEXT_WARN = 0;

  my ($path, $query);
  if ( UNIVERSAL::isa($_[0], 'HTML::Form') ) {
    my $form = shift;
    my $request = $form->make_request;
    $path = $request->uri->path;
    $query = $request->content;
  } else {
    $path = shift;
    my @params = @_;
    if (scalar(@params) == 0) {
      # possibly path?query syntax, or else no query string at all
      ($path, $query) = split('\?', $path);
    } elsif (scalar(@params) == 1) {
      $query = uri_escape($params[0]); # keyword style
    } else {
      while (@params) {
        $query .= uri_escape(shift @params) . '=' .
                  uri_escape(shift @params);
        $query .= ';' if @params;
      }
    }
  }
  # remember which page this is
  $self->path($path);

  local $FS::Mason::Request::FSURL = $self->base->as_string;
  local $FS::Mason::Request::QUERY_STRING = $query;
  # because we're going to construct an actual CGI object in here
  local $ENV{SERVER_NAME} = $self->base->host;
  local $ENV{SCRIPT_NAME} = $self->base->path . $path;
  local $@ = '';
  my $mason_request = $self->fs_interp->make_request(comp => $path);
  eval {
    $mason_request->exec();
  };

  if ( $@ ) {
    if ( ref $@ eq 'HTML::Mason::Exception' ) {
      $self->error($@->message);
    } else {
      $self->error($@);
    }
  } elsif ( $mason_request->notes('error') ) {
    $self->error($mason_request->notes('error'));
  } else {
    $self->error('');
  }

  if ( my $loc = $mason_request->redirect ) {
    my $base = $self->base->as_string;
    $loc =~ s/^$base//;
    $self->redirect($loc);
  } else {
    $self->redirect('');
  }
  ''; # return error? HTTP status? something?
}

=item proceed

If the last request returned a redirect, follow it.

=cut

sub proceed {
  my $self = shift;
  if ($self->redirect) {
    $self->post($self->redirect);
  }
  # else do nothing
}

=item forms

For the most recently returned page, returns a list of L<HTML::Form>s found.

=cut

sub forms {
  my $self = shift;
  my $formbase = $self->base->as_string . $self->path;
  return HTML::Form->parse( $self->page, base => $formbase );
}

=item form NAME

For the most recently returned page, returns an L<HTML::Form> object
representing the form named NAME. You can then call methods like
C<value(inputname, inputvalue)> to set the values of inputs on the form,
and then pass the form object to L</post> to submit it.

=cut

sub form {
  my $self = shift;
  my $name = shift;
  my ($form) = grep { ($_->attr('name') || '') eq $name } $self->forms;
  $form;
}

=item qsearch ARGUMENTS

Searches the database, like L<FS::Record::qsearch>.

=item qsearchs ARGUMENTS

Searches the database for a single record, like L<FS::Record::qsearchs>.

=cut

sub qsearch {
  my $self = shift;
  FS::Record::qsearch(@_);
}

sub qsearchs {
  my $self = shift;
  FS::Record::qsearchs(@_);
}

=item new_customer FIRSTNAME

Returns an L<FS::cust_main> object full of default test data, ready to be inserted.
This doesn't insert the customer, because you might want to change some things first.
FIRSTNAME is recommended so you know which test the customer was used for.

=cut

sub new_customer {
  my $self = shift;
  my $first = shift || 'No Name';
  my $location = FS::cust_location->new({
      address1  => '123 Example Street',
      city      => 'Sacramento',
      state     => 'CA',
      country   => 'US',
      zip       => '94901',
  });
  my $cust = FS::cust_main->new({
      agentnum      => 1,
      refnum        => 1,
      last          => 'Customer',
      first         => $first,
      invoice_email => 'newcustomer@fake.freeside.biz',
      bill_location => $location,
      ship_location => $location,
  });
  $cust;
}

1; # End of FS::Test
