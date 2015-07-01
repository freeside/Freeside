package FS::UI::Web::small_custview;

use strict;
use vars qw(@EXPORT_OK @ISA);
use Exporter;
use HTML::Entities;
use FS::Msgcat;
use FS::Record qw(qsearchs);
use FS::cust_main;

@ISA = qw(Exporter);
@EXPORT_OK = qw( small_custview );

=head1 NAME

FS::UI::Web::small_custview

=head1 SYNOPSIS

  use FS::UI::Web::small_custview qw( small_custview );
  
  #new-style
  $html = small_custview(
    { 'cust_main'      => $cust_main, #or 'custnum' => $custnum,
      'countrydefault' => 'US',
      'nobalance'      => 1,
      'url'            => 'http://freeside.machine/freeside/view/cust_main.cgi',
      'nopkg'          => 1,
    }
  );

  #old-style (deprecated)
  $html = small_custview( $cust_main, $countrydefault, $nobalance, $url );

=head1 DESCRIPTION

A subroutine for displaying customer information.

=head1 SUBROUTINES

=over 4

=item small_custview HASHREF

New-style interface.  Keys are:

=over 4

=item cust_main

Customer (as a FS::cust_main object)

=item custnum

Customer number (if cust_main is not provided).

=item countrydefault

=item nobalance

=item url

=back

=item small_custview CUSTNUM || CUST_MAIN_OBJECT, COUNTRYDEFAULT, NOBALANCE_FLAG, URL

Old-style (deprecated) interface.

=cut

sub small_custview {
  my( $cust_main, $countrydefault, $nobalance, $url, $nopkg );
  if ( ref($_[0]) eq 'HASH' ) {
    my $opt = shift;
    $cust_main =  $opt->{cust_main}
               || qsearchs('cust_main', { 'custnum' => $opt->{custnum} } );
    $countrydefault = $opt->{countrydefault} || 'US';
    $nobalance = $opt->{nobalance};
    $url = $opt->{url};
    $nopkg = $opt->{nopkg};
  } else {
    my $arg = shift;
    $countrydefault = shift || 'US';
    $nobalance = shift;
    $url = shift;
    $nopkg = 0;

    $cust_main = ref($arg) ? $arg
                           : qsearchs('cust_main', { 'custnum' => $arg } )
      or die "unknown custnum $arg";
  }

  my $html = '<DIV ID="fs_small_custview" CLASS="small_custview">';
  
  $html = qq!<A HREF="$url?! . $cust_main->custnum . '">'
    if $url;

  $html .= 'Customer #<B>'. $cust_main->display_custnum.
           ': '. encode_entities($cust_main->name). '</B></A>';
           ' - <B><FONT COLOR="#'. $cust_main->statuscolor. '">'.
           $cust_main->status_label. '</FONT></B>';

  $html .= ' (Balance: <B>$'. $cust_main->balance. '</B>)'
    unless $nobalance;

  my @part_tag = $cust_main->part_tag;
  if ( @part_tag ) {
    $html .= '<TABLE>';
    foreach my $part_tag ( @part_tag ) {
      $html .= '<TR><TD>'.
               '<FONT '. ( length($part_tag->tagcolor)
                           ? 'STYLE="background-color:#'.$part_tag->tagcolor.'"'
                           : ''
                         ).
               '>'.
                 encode_entities($part_tag->tagname.': '. $part_tag->tagdesc).
               '</FONT>'.
               '</TD></TR>';
    }
    $html .= '</TABLE>';
  }

  $html .=
    ntable('#e8e8e8'). '<TR><TD VALIGN="top">'. ntable("#cccccc",2).
    '<TR><TD ALIGN="right" VALIGN="top">Billing<BR>Address</TD><TD BGCOLOR="#ffffff">';

  if ( $cust_main->bill_locationnum ) {

    $html .= encode_entities($cust_main->address1). '<BR>';
    $html .= encode_entities($cust_main->address2). '<BR>'
      if $cust_main->address2;
    $html .= encode_entities($cust_main->city) . ', ' if $cust_main->city;
    $html .= encode_entities($cust_main->state). '  '.
             encode_entities($cust_main->zip). '<BR>';
    $html .= encode_entities($cust_main->country). '<BR>'
      if $cust_main->country && $cust_main->country ne $countrydefault;

  }

  $html .= '</TD></TR><TR><TD></TD><TD BGCOLOR="#ffffff">';
  if ( $cust_main->daytime && $cust_main->night ) {
    $html .= ( FS::Msgcat::_gettext('daytime') || 'Day' ).
             ' '. $cust_main->daytime.
             '<BR>'. ( FS::Msgcat::_gettext('night') || 'Night' ).
             ' '. $cust_main->night;
  } elsif ( $cust_main->daytime || $cust_main->night ) {
    $html .= $cust_main->daytime || $cust_main->night;
  }
  if ( $cust_main->fax ) {
    $html .= '<BR>Fax '. $cust_main->fax;
  }

  $html .= '</TD></TR></TABLE></TD>';

  if ( $cust_main->ship_locationnum ) {

    my $ship = $cust_main->ship_location;

    $html .= '<TD VALIGN="top">'. ntable("#cccccc",2).
      '<TR><TD ALIGN="right" VALIGN="top">Service<BR>Address</TD><TD BGCOLOR="#ffffff">';
    $html .= join('<BR>', 
      map encode_entities($_), grep $_,
        $cust_main->ship_company,
        $ship->address1,
        $ship->address2,
        (($ship->city ? $ship->city . ', ' : '') . $ship->state . '  ' . $ship->zip),
        ($ship->country eq $countrydefault ? '' : $ship->country ),
    );

    # ship phone numbers no longer exist...

    $html .= '</TD></TR></TABLE></TD>';

  }

  $html .= '</TR>';

  #would be better to use ncancelled_active_pkgs, but that doesn't have an
  # optimization to just count them yet, so it would be a perf problem on 
  # tons-of-package customers
  if ( !$nopkg && scalar($cust_main->ncancelled_pkgs) < 20 ) {

    foreach my $cust_pkg ( $cust_main->ncancelled_active_pkgs ) {

      $html .= '<TR><TD COLSPAN="2">'.
               '<B><FONT COLOR="#'. $cust_pkg->statuscolor. '">'.
               ucfirst($cust_pkg->status). '</FONT></B> - '.
               encode_entities($cust_pkg->part_pkg->pkg_comment_only(nopkgpart=>1)).
               '</TD></TR>';
    }

  }

  $html .= '</TABLE>';

  # last payment might be good here too?

  $html .= '</DIV>';

  $html;
}

#bah.  don't want to pull in all of FS::CGI, that's the whole problem in the
#first place
sub ntable {
  my $col = shift;
  my $cellspacing = shift || 0;
  if ( $col ) {
    qq!<TABLE BGCOLOR="$col" BORDER=0 CELLSPACING=$cellspacing>!;
  } else {
    '<TABLE BORDER CELLSPACING=0 CELLPADDING=2 BORDERCOLOR="#999999">';
  }

}

=back

=head1 BUGS

Sheesh. I did switch to mason, but this is still hanging around.  Figure out
some better way to sling mason components to self-service & RT.

(Or, is it useful to have this without depending on the regular back-office UI
and Mason stuff to be in place?  So we have something suitable for displaying
customer information in other external systems, not just RT?)

=head1 SEE ALSO

L<FS::UI::Web>

=cut

1;

