package Torrus::Renderer::Freeside;

use strict;

#Freeside
use FS::Mason qw( mason_interps );
use FS::UID qw(cgisuidsetup);
use FS::TicketSystem;

my $outbuf;
my( $fs_interp, $rt_interp ) = mason_interps('standalone', 'outbuf'=>\$outbuf);

sub freesideHeader {
  my($self, $title, $stylesheet) = @_;

  #from html-incblocks.txt
  my $head =
  #  <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
  #  [% IF expires %]<META HTTP-EQUIV="Refresh" CONTENT="[% expires %]"/>[% END %]
    '<STYLE type="text/css" media="all">
     @import url( '. $Torrus::Renderer::plainURL. $stylesheet. ' );
     </STYLE>
    ';

  $self->freesideComponent('/elements/header.html',
                             {
                               'title' => $title,
                               'head'  => $head,
                               #'etc'   => $etc,
                               #'nobr'  => 1,
                               #'nocss' => 1,
                             }
                          );
}

sub freesideFooter {
  my $self = shift;
  $self->freesideComponent('/elements/footer.html');
}

our $FSURL;

sub freesideComponent {
  my($self, $comp) = (shift, shift);

#  my $conf = new FS::Conf;
  $FS::Mason::Request::FSURL = $FSURL;
  $FS::Mason::Request::FSURL .= '/' unless $FS::Mason::Request::FSURL =~ /\/$/;
#  $FS::Mason::Request::QUERY_STRING = $packet->{'query_string'} || '';

  cgisuidsetup($Torrus::CGI::q);
  FS::TicketSystem->init();

  $outbuf = '';
  #$fs_interp->exec($comp, @args); #only FS for now alas...
  $fs_interp->exec($comp, @_); #only FS for now alas...

  #errors? (turn off in-line error reporting?)

  return $outbuf;

}

1;

