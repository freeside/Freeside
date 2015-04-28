package FS::ClientAPI::MyAccount::quotation;

use strict;
use FS::Record qw(qsearch qsearchs);
use FS::quotation;
use FS::quotation_pkg;

our $DEBUG = 0;

sub _custoragent_session_custnum {
  FS::ClientAPI::MyAccount::_custoragent_session_custnum(@_);
}

# _quotation(session, quotationnum)
# returns that quotation, or '' if it doesn't exist and belong to this
# customer

sub _quotation {
  my $session = shift;
  my $quotationnum = shift;
  my $quotation;

  if ( $quotationnum =~ /^(\d+)$/ ) {
    $quotation = qsearchs( 'quotation', {
        'custnum'       => $session->{'custnum'},
        'usernum'       => $FS::CurrentUser::CurrentUser->usernum,
        'disabled'      => '',
        'quotationnum'  => $1,
    }); 
    warn "found selfservice quotation #". $quotation->quotationnum."\n"
      if $quotation and $DEBUG;

    return $quotation;
  }
  '';
}

=item list_quotations { session }

Returns a hashref listing this customer's active self-service quotations.
Contents are:

- 'quotations', an arrayref containing an element for each quotation.
  - quotationnum, the primary key
  - _date, the date it was started
  - num_pkgs, the number of packages
  - total_setup, the sum of setup fees
  - total_recur, the sum of recurring charges

=cut

sub list_quotations {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my @quotations = qsearch('quotation', {
      'custnum'   => $session->{'custnum'},
      'usernum'   => $FS::CurrentUser::CurrentUser->usernum,
      'disabled'  => '',
  });
  my @q;
  foreach my $quotation (@quotations) {
    warn "found selfservice quotation #". $quotation->quotationnum."\n"
      if $quotation and $DEBUG;
    push @q, { 'quotationnum' => $quotation->quotationnum,
               '_date'        => $quotation->_date,
               'num_pkgs'     => scalar($quotation->quotation_pkg),
               'total_setup'  => $quotation->total_setup,
               'total_recur'  => $quotation->total_recur,
             };
  }
  return { 'quotations' => \@q, 'error' => '' };
}

=item quotation_new { session }

Creates a quotation and returns its quotationnum.

=cut

sub quotation_new {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $quotation = FS::quotation->new({
      'custnum'   => $session->{'custnum'},
      'usernum'   => $FS::CurrentUser::CurrentUser->usernum,
      '_date'     => time,
  }); 
  my $error = $quotation->insert;
  if ( $error ) {
    warn "failed to create selfservice quotation for custnum #" .
      $session->{custnum} . "\n";
    return { 'error' => $error };
  } else {
    warn "started new selfservice quotation #". $quotation->quotationnum."\n"
      if $DEBUG;
    return { 'error' => $error, 'quotationnum' => $quotation->quotationnum };
  }
}

=item quotation_delete { session, quotationnum }

Disables (doesn't actually delete) the specified quotationnum.

=cut

sub quotation_delete {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $quotation = _quotation($session, $p->{quotationnum})
    or return { 'error' => "Quotation not found" };
  warn "quotation_delete #".$quotation->quotationnum
    if $DEBUG;

  $quotation->set('disabled' => 'Y');
  my $error = $quotation->replace;
  return { 'error' => $error };
}

=item quotation_info { session, quotationnum }

Returns a hashref describing the specified quotation, containing:

- "sections", an arrayref containing one section for each billing frequency.
  Each one will have:
  - "description"
  - "subtotal"
  - "detail_items", an arrayref of detail items, each with:
    - "pkgnum", the reference number (actually the quotationpkgnum field)
    - "description", the package name (or tax name)
    - "quantity"
    - "amount"
- "num_pkgs", the number of packages in the quotation
- "total_setup", the sum of setup/one-time charges and their taxes
- "total_recur", the sum of all recurring charges and their taxes

=cut

sub quotation_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $quotation = _quotation($session, $p->{quotationnum})
    or return { 'error' => "Quotation not found" };
  warn "quotation_info #".$quotation->quotationnum
    if $DEBUG;

  my $null_escape = sub { @_ };
  # 3.x only; 4.x quotation redesign uses actual sections for this
  # and isn't a weird hack
  my @items =
    map { $_->{'pkgnum'} = $_->{'preref_html'}; $_ }
    $quotation->_items_pkg(escape_function => $null_escape,
                           preref_callback => sub { shift->quotationpkgnum });
  push @items, $quotation->_items_total();

  my $sections = [
    { 'description' => 'Estimated Charges',
      'detail_items' => \@items
    }
  ];

  return { 'error'        => '',
           'sections'     => $sections,
           'num_pkgs'     => scalar($quotation->quotation_pkg),
           'total_setup'  => $quotation->total_setup,
           'total_recur'  => $quotation->total_recur,
         };
}

=item quotation_print { session, 'format' }

Renders the quotation. 'format' can be either 'html' or 'pdf'; the resulting
hashref will contain 'document' => the HTML or PDF contents.

=cut

sub quotation_print {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $quotation = _quotation($session, $p->{quotationnum})
    or return { 'error' => "Quotation not found" };
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
  
  my $quotation = _quotation($session, $p->{quotationnum})
    or return { 'error' => "Quotation not found" };
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
           || $quotation->estimate
           || '';

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
  
  my $quotation = _quotation($session, $p->{quotationnum})
    or return { 'error' => "Quotation not found" };
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
  
  my $quotation = _quotation($session, $p->{quotationnum})
    or return { 'error' => "Quotation not found" };

  my $error = $quotation->order;

  $quotation->set('disabled' => 'Y');
  $error ||= $quotation->replace;

  return { 'error' => $error };
}

1;
