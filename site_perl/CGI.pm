package FS::CGI;

use strict;
use vars qw(@EXPORT_OK @ISA);
use Exporter;
use CGI;
use URI::URL;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID;

@ISA = qw(Exporter);
@EXPORT_OK = qw(header menubar idiot eidiot popurl table itable ntable);

=head1 NAME

FS::CGI - Subroutines for the web interface

=head1 SYNOPSIS

  use FS::CGI qw(header menubar idiot eidiot popurl);

  print header( 'Title', '' );
  print header( 'Title', menubar('item', 'URL', ... ) );

  idiot "error message"; 
  eidiot "error message";

  $url = popurl; #returns current url
  $url = popurl(3); #three levels up

=head1 DESCRIPTION

Provides a few common subroutines for the web interface.

=head1 SUBROUTINES

=over 4

=item header TITLE, MENUBAR

Returns an HTML header.

=cut

sub header {
  my($title,$menubar)=@_;

  my $x =  <<END;
    <HTML>
      <HEAD>
        <TITLE>
          $title
        </TITLE>
      </HEAD>
      <BODY BGCOLOR="#e8e8e8">
          <FONT SIZE=7>
            $title
          </FONT>
          <BR><BR>
END
  $x .=  $menubar. "<BR><BR>" if $menubar;
  $x;
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

This is depriciated.  Don't use it.

Sends headers and an HTML error message.

=cut

sub idiot {
  #warn "idiot depriciated";
  my($error)=@_;
  my($cgi)=FS::UID::cgi;
  if ( $cgi->isa('CGI::Base') ) {
    no strict 'subs';
    &CGI::Base::SendHeaders;
  } else {
    print $cgi->header( '-expires' => 'now' );
  }
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
  </BODY>
</HTML>
END

}

=item eidiot ERROR

This is depriciated.  Don't use it.

Sends headers and an HTML error message, then exits.

=cut

sub eidiot {
  #warn "eidiot depriciated";
  idiot(@_);
  exit;
}

=item popurl LEVEL

Returns current URL with LEVEL levels of path removed from the end (default 0).

=cut

sub popurl {
  my($up)=@_;
  my($cgi)=&FS::UID::cgi;
  my($url)=new URI::URL $cgi->url;
  my(@path)=$url->path_components;
  splice @path, 0-$up;
  $url->path_components(@path);
  my $x = $url->as_string;
  $x .= '/' unless $x =~ /\/$/;
  $x;
}

=item table

Returns HTML tag for beginning a table.

=cut

sub table {
  my $col = shift;
  if ( $col ) {
    qq!<TABLE BGCOLOR="$col" BORDER=1 WIDTH="100%">!;
  } else { 
    "<TABLE BORDER=1>";
  }
}

=item itable

Returns HTML tag for beginning an (invisible) table.

=cut

sub itable {
  my $col = shift;
  my $cellspacing = shift || 0;
  if ( $col ) {
    qq!<TABLE BGCOLOR="$col" BORDER=0 CELLSPACING=$cellspacing WIDTH="100%">!;
  } else {
    qq!<TABLE BORDER=0 CELLSPACING=$cellspacing WIDTH="100%">!;
  }
}

=item ntable

This is getting silly.

=cut

sub ntable {
  my $col = shift;
  my $cellspacing = shift || 0;
  if ( $col ) {
    qq!<TABLE BGCOLOR="$col" BORDER=0 CELLSPACING=$cellspacing>!;
  } else {
    "<TABLE BORDER>";
  }

}

=back

=head1 BUGS

Not OO.

Not complete.

=head1 SEE ALSO

L<CGI>, L<CGI::Base>

=head1 HISTORY

subroutines for the HTML/CGI GUI, not properly OO. :(

ivan@sisd.com 98-apr-16
ivan@sisd.com 98-jun-22

lose the background, eidiot ivan@sisd.com 98-sep-2

pod ivan@sisd.com 98-sep-12

$Log: CGI.pm,v $
Revision 1.17  1999-02-07 09:59:43  ivan
more mod_perl fixes, and bugfixes Peter Wemm sent via email

Revision 1.16  1999/01/25 12:26:05  ivan
yet more mod_perl stuff

Revision 1.15  1999/01/18 09:41:48  ivan
all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
(good idea anyway)

Revision 1.14  1999/01/18 09:22:37  ivan
changes to track email addresses for email invoicing

Revision 1.12  1998/12/23 02:23:16  ivan
popurl always has trailing slash

Revision 1.11  1998/11/12 07:43:54  ivan
*** empty log message ***

Revision 1.10  1998/11/12 01:53:47  ivan
added table command

Revision 1.9  1998/11/09 08:51:49  ivan
bug squash

Revision 1.7  1998/11/09 06:10:59  ivan
added sub url

Revision 1.6  1998/11/09 05:44:20  ivan
*** empty log message ***

Revision 1.4  1998/11/09 04:55:42  ivan
support depriciated CGI::Base as well as CGI.pm (for now)

Revision 1.3  1998/11/08 10:50:19  ivan
s/CGI::Base/CGI/; etc.


=cut

1;


