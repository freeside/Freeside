package FS::UI::Web::small_custview;

use strict;
use vars qw(@EXPORT_OK @ISA);
use Exporter;
use FS::Msgcat;
use FS::Record qw(qsearchs);
use FS::cust_main;

@ISA = qw(Exporter);
@EXPORT_OK = qw( small_custview );

=item small_custview CUSTNUM || CUST_MAIN_OBJECT, COUNTRYDEFAULT, NOBALANCE_FLAG, URL

Sheesh. I did switch to mason, but this is still hanging around.  Figure out
some better way to sling mason components to self-service & RT.

=cut

sub small_custview {

  my $arg = shift;
  my $countrydefault = shift || 'US';
  my $nobalance = shift;
  my $url = shift;

  my $cust_main = ref($arg) ? $arg
                  : qsearchs('cust_main', { 'custnum' => $arg } )
    or die "unknown custnum $arg";

  my $html;
  
  $html = qq!View <A HREF="$url?! . $cust_main->custnum . '">'
    if $url;

  $html .= 'Customer #<B>'. $cust_main->custnum. '</B></A>'.
    ' - <B><FONT COLOR="#'. $cust_main->statuscolor. '">'.
    ucfirst($cust_main->status). '</FONT></B>'.
    ntable('#e8e8e8'). '<TR><TD VALIGN="top">'. ntable("#cccccc",2).
    '<TR><TD ALIGN="right" VALIGN="top">Billing<BR>Address</TD><TD BGCOLOR="#ffffff">'.
    $cust_main->getfield('last'). ', '. $cust_main->first. '<BR>';

  $html .= $cust_main->company. '<BR>' if $cust_main->company;
  $html .= $cust_main->address1. '<BR>';
  $html .= $cust_main->address2. '<BR>' if $cust_main->address2;
  $html .= $cust_main->city. ', '. $cust_main->state. '  '. $cust_main->zip. '<BR>';
  $html .= $cust_main->country. '<BR>'
    if $cust_main->country && $cust_main->country ne $countrydefault;

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

  if ( defined $cust_main->dbdef_table->column('ship_last') ) {

    my $pre = $cust_main->ship_last ? 'ship_' : '';

    $html .= '<TD VALIGN="top">'. ntable("#cccccc",2).
      '<TR><TD ALIGN="right" VALIGN="top">Service<BR>Address</TD><TD BGCOLOR="#ffffff">'.
      $cust_main->get("${pre}last"). ', '.
      $cust_main->get("${pre}first"). '<BR>';
    $html .= $cust_main->get("${pre}company"). '<BR>'
      if $cust_main->get("${pre}company");
    $html .= $cust_main->get("${pre}address1"). '<BR>';
    $html .= $cust_main->get("${pre}address2"). '<BR>'
      if $cust_main->get("${pre}address2");
    $html .= $cust_main->get("${pre}city"). ', '.
             $cust_main->get("${pre}state"). '  '.
             $cust_main->get("${pre}zip"). '<BR>';
    $html .= $cust_main->get("${pre}country"). '<BR>'
      if $cust_main->get("${pre}country")
         && $cust_main->get("${pre}country") ne $countrydefault;

    $html .= '</TD></TR><TR><TD></TD><TD BGCOLOR="#ffffff">';

    if ( $cust_main->get("${pre}daytime") && $cust_main->get("${pre}night") ) {
      use FS::Msgcat;
      $html .= ( FS::Msgcat::_gettext('daytime') || 'Day' ).
               ' '. $cust_main->get("${pre}daytime").
               '<BR>'. ( FS::Msgcat::_gettext('night') || 'Night' ).
               ' '. $cust_main->get("${pre}night");
    } elsif ( $cust_main->get("${pre}daytime")
              || $cust_main->get("${pre}night") ) {
      $html .= $cust_main->get("${pre}daytime")
               || $cust_main->get("${pre}night");
    }
    if ( $cust_main->get("${pre}fax") ) {
      $html .= '<BR>Fax '. $cust_main->get("${pre}fax");
    }

    $html .= '</TD></TR></TABLE></TD>';
  }

  $html .= '</TR></TABLE>';

  $html .= '<BR>Balance: <B>$'. $cust_main->balance. '</B><BR>'
    unless $nobalance;

  # last payment might be good here too?

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

1;

