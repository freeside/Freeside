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
  my $cgi = &FS::UID::cgi();
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

=cut

1;


