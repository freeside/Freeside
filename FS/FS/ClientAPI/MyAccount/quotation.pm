package FS::ClientAPI::MyAccount::quotation;

use strict;
use FS::Record qw(qsearch qsearchs);
use FS::quotation;
use FS::quotation_pkg;

our $DEBUG = 1;

sub _custoragent_session_custnum {
  FS::ClientAPI::MyAccount::_custoragent_session_custnum(@_);
}

sub _quotation {
  # the currently active quotation
  my $session = shift;
  my $quotation;
  if ( my $quotationnum = $session->{'quotationnum'} ) {
    $quotation = FS::quotation->by_key($quotationnum);
  } 
  if ( !$quotation ) {
    # find the last quotation created through selfservice
    $quotation = qsearchs( 'quotation', {
        'custnum'   => $session->{'custnum'},
        'usernum'   => $FS::CurrentUser::CurrentUser->usernum,
        'disabled'  => '',
    }); 
    warn "found selfservice quotation #". $quotation->quotationnum."\n"
      if $quotation and $DEBUG;
  } 
  if ( !$quotation ) {
    $quotation = FS::quotation->new({
        'custnum'   => $session->{'custnum'},
        'usernum'   => $FS::CurrentUser::CurrentUser->usernum,
        '_date'     => time,
    }); 
    $quotation->insert; # what to do on error? call the police?
    warn "started new selfservice quotation #". $quotation->quotationnum."\n"
      if $quotation and $DEBUG;
  } 
  $session->{'quotationnum'} = $quotation->quotationnum;
  return $quotation;
}

=item quotation_info { session }

Returns a hashref describing the current quotation, containing:

- "sections", an arrayref containing one section for each billing frequency.
  Each one will have:
  - "description"
  - "subtotal"
  - "detail_items", an arrayref of detail items, each with:
    - "pkgnum", the reference number (actually the quotationpkgnum field)
    - "description", the package name (or tax name)
    - "quantity"
    - "amount"

=cut

sub quotation_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $quotation = _quotation($session);
  return { 'error' => "No current quotation for this customer" } if !$quotation;
  warn "quotation_info #".$quotation->quotationnum
    if $DEBUG;

  # code reuse ftw
  my $null_escape = sub { @_ };
  my ($sections) = $quotation->_items_sections(escape => $null_escape);
  foreach my $section (@$sections) {
    $section->{'detail_items'} =
      [ $quotation->_items_pkg('section' => $section, escape_function => $null_escape) ]; 
  }
  return { 'error' => '', 'sections' => $sections }
}

=item quotation_print { session, 'format' }

Renders the quotation. 'format' can be either 'html' or 'pdf'; the resulting
hashref will contain 'document' => the HTML or PDF contents.

=cut

sub quotation_print {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $quotation = _quotation($session);
  return { 'error' => "No current quotation for this customer" } if !$quotation;
  warn "quotation_print #".$quotation->quotationnum
    if $DEBUG;

  my $format = $p->{'format'}
   or return { 'error' => "No rendering format specified" };

  my $document;
  if ($format eq 'html') {
    $document = $quotation->print_html;
  } elsif ($format eq 'pdf') {
    $document = $quotation->print_pdf;
  }
  warn "$format, ".length($document)." bytes\n"
    if $DEBUG;
  return { 'error' => '', 'document' => $document };
}

=item quotation_add_pkg { session, 'pkgpart', 'quantity', [ location opts ] }

Adds a package to the user's current quotation. Session info and 'pkgpart' are
required. 'quantity' defaults to 1.

Location can be specified as 'locationnum' to use an existing location, or
'address1', 'address2', 'city', 'state', 'zip', 'country' to create a new one,
or it will default to the customer's service location.

=cut

sub quotation_add_pkg {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';
  
  my $quotation = _quotation($session);
  my $cust_main = $quotation->cust_main;

  my $pkgpart = $p->{'pkgpart'};
  my $allowed_pkgpart = $cust_main->agent->pkgpart_hashref;

  my $part_pkg = FS::part_pkg->by_key($pkgpart);

  if (!$part_pkg or
      (!$allowed_pkgpart->{$pkgpart} and 
       $cust_main->agentnum != ($part_pkg->agentnum || 0))
  ) {
    warn "disallowed quotation_pkg pkgpart $pkgpart\n"
      if $DEBUG;
    return { 'error' => "unknown package $pkgpart" };
  }

  warn "creating quotation_pkg with pkgpart $pkgpart\n"
    if $DEBUG;
  my $quotation_pkg = FS::quotation_pkg->new({
    'quotationnum'  => $quotation->quotationnum,
    'pkgpart'       => $p->{'pkgpart'},
    'quantity'      => $p->{'quantity'} || 1,
  });
  if ( $p->{locationnum} > 0 ) {
    $quotation_pkg->set('locationnum', $p->{locationnum});
  } elsif ( $p->{address1} ) {
    my $location = FS::cust_location->find_or_insert(
      'custnum' => $cust_main->custnum,
      map { $_ => $p->{$_} }
        qw( address1 address2 city county state zip country )
    );
    $quotation_pkg->set('locationnum', $location->locationnum);
  }

  my $error = $quotation_pkg->insert
           || $quotation->estimate;

  { 'error'         => $error,
    'quotationnum'  => $quotation->quotationnum };
}
 
=item quotation_remove_pkg { session, 'pkgnum' }

Removes the package from the user's current quotation. 'pkgnum' is required.

=cut

sub quotation_remove_pkg {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';
  
  my $quotation = _quotation($session);
  my $quotationpkgnum = $p->{pkgnum};
  my $quotation_pkg = FS::quotation_pkg->by_key($quotationpkgnum);
  if (!$quotation_pkg
      or $quotation_pkg->quotationnum != $quotation->quotationnum) {
    return { 'error' => "unknown quotation item $quotationpkgnum" };
  }
  warn "removing quotation_pkg with pkgpart ".$quotation_pkg->pkgpart."\n"
    if $DEBUG;

  my $error = $quotation_pkg->delete
           || $quotation->estimate;

  { 'error'         => $error,
    'quotationnum'  => $quotation->quotationnum };
}

=item quotation_order

Convert the current quotation to a package order.

=cut

sub quotation_order {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';
  
  my $quotation = _quotation($session);

  my $error = $quotation->order;

  return { 'error' => $error };
}

1;
