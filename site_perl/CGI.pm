package FS::CGI;

use strict;
use vars qw(@EXPORT_OK @ISA);
use Exporter;
use CGI::Base;
use CGI::Carp qw(fatalsToBrowser);

@ISA = qw(Exporter);
@EXPORT_OK = qw(header menubar idiot eidiot);

=head1 NAME

FS::CGI - Subroutines for the web interface

=head1 SYNOPSIS

  use FS::CGI qw(header menubar idiot eidiot);

  print header( 'Title', '' );
  print header( 'Title', menubar('item', 'URL', ... ) );

  idiot "error message"; 
  eidiot "error message";

=head1 DESCRIPTION

Provides a few common subroutines for the web interface.

=head1 SUBROUTINES

=over 4

=item header TITLE, MENUBAR

Returns an HTML header.

=cut

sub header {
  my($title,$menubar)=@_;

  <<END;
    <HTML>
      <HEAD>
        <TITLE>
          $title
        </TITLE>
      </HEAD>
      <BODY BGCOLOR="#ffffff">
          <FONT COLOR="#FF0000" SIZE=7>
            $title
          </FONT>
          <BR><BR>
          $menubar
      <BR><BR>
END
}

=item menubar ITEM, URL, ...

Returns an HTML menubar.

=cut

sub menubar { #$menubar=menubar('Main Menu', '../', 'Item', 'url', ... );
  my($item,$url,@html);
  while (@_) {
    ($item,$url)=splice(@_,0,2);
    push @html, qq!<A HREF="$url">$item</A>!;
  }
  join(' | ',@html);
}

=item idiot ERROR

Sends headers and an HTML error message.

=cut

sub idiot {
  my($error)=@_;
  CGI::Base::SendHeaders();
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error processing your request</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error processing your request</H4>
    </CENTER>
    Your request could not be processed because of the following error:
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake, and try again.
  </BODY>
</HTML>
END

}

=item eidiot ERROR

Sends headers and an HTML error message, then exits.

=cut

sub eidiot {
  idiot(@_);
  exit;
}

=back

=head1 BUGS

Not OO.

Not complete.

Uses CGI-modules instead of CGI.pm

=head1 SEE ALSO

L<CGI::Base>

=head1 HISTORY

subroutines for the HTML/CGI GUI, not properly OO. :(

ivan@sisd.com 98-apr-16
ivan@sisd.com 98-jun-22

lose the background, eidiot ivan@sisd.com 98-sep-2

pod ivan@sisd.com 98-sep-12

$Log: CGI.pm,v $
Revision 1.2  1998-11-07 10:24:23  ivan
don't use depriciated FS::Bill and FS::Invoice, other miscellania


=cut

1;


