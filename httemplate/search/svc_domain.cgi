<%
# <!-- $Id: svc_domain.cgi,v 1.4 2001-10-26 10:24:56 ivan Exp $ -->

use strict;
use vars qw ( $cgi @svc_domain $sortby $query $conf $mydomain );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header eidiot popurl);
use FS::svc_domain;
use FS::cust_svc;
use FS::svc_acct;
use FS::svc_forward;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;
$mydomain = $conf->config('domain');

($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors
if ( $query eq 'svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_domain=qsearch('svc_domain',{});
} elsif ( $query eq 'domain' ) {
  $sortby=\*domain_sort;
  @svc_domain=qsearch('svc_domain',{});
} elsif ( $query eq 'UN_svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_domain = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_domain',{});
} elsif ( $query eq 'UN_domain' ) {
  $sortby=\*domain_sort;
  @svc_domain = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_domain',{});
} else {
  $cgi->param('domain') =~ /^([\w\-\.]+)$/; 
  my($domain)=$1;
  #push @svc_domain, qsearchs('svc_domain',{'domain'=>$domain});
  @svc_domain = qsearchs('svc_domain',{'domain'=>$domain});
}

if ( scalar(@svc_domain) == 1 ) {
  print $cgi->redirect(popurl(2). "view/svc_domain.cgi?". $svc_domain[0]->svcnum);
  exit;
} elsif ( scalar(@svc_domain) == 0 ) {
  eidiot "No matching domains found!\n";
} else {

  my($total)=scalar(@svc_domain);
  print $cgi->header( @FS::CGI::header ),
        header("Domain Search Results",''), <<END;

    $total matching domains found
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Service #</TH>
        <TH>Domain</TH>
        <TH>Mail to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>
        <TH>Forwards to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>
      </TR>
END

#  my(%saw);                 # if we've multiple domains with the same
                             # svcnum, then we've a corrupt database

  my($svc_domain);
  my $p = popurl(2);
  foreach $svc_domain (
#    sort $sortby grep(!$saw{$_->svcnum}++, @svc_domain)
    sort $sortby (@svc_domain)
  ) {
    my($svcnum,$domain)=(
      $svc_domain->svcnum,
      $svc_domain->domain,
    );
    #my($malias);
    #if ( qsearch('svc_acct_sm',{'domsvc'=>$svcnum}) ) {
    #  $malias=(
    #    qq|<FORM ACTION="svc_acct_sm.cgi" METHOD="post">|.
    #      qq|<INPUT TYPE="hidden" NAME="domuser" VALUE="">|.
    #      qq|<INPUT TYPE="hidden" NAME="domain" VALUE="$domain">|.
    #      qq|<INPUT TYPE="submit" VALUE="(mail aliases)">|.
    #      qq|</FORM>|
    #  );
    #} else {
    #  $malias='';
    #}

    my @svc_acct=qsearch('svc_acct',{'domsvc' => $svcnum});
    my $rowspan = 0;

    my $n1 = '';
    my($svc_acct, @rows);
    foreach $svc_acct (
      sort {$b->getfield('username') cmp $a->getfield('username')} (@svc_acct)
    ) {

      my (@forwards) = ();

      my($svcnum,$username)=(
        $svc_acct->svcnum,
        $svc_acct->username,
      );

      my @svc_forward = qsearch( 'svc_forward', { 'srcsvc' => $svcnum } );
      my $svc_forward;
      foreach $svc_forward (@svc_forward) {
        my($dstsvc,$dst) = (
          $svc_forward->dstsvc,
          $svc_forward->dst,
        );
        if ($dstsvc) {
          my $dst_svc_acct=qsearchs( 'svc_acct', { 'svcnum' => $dstsvc } );
          my $destination=$dst_svc_acct->email;
          push @forwards, qq!<TD><A HREF="!, popurl(2),
                qq!view/svc_acct.cgi?$dstsvc">$destination</A>!,
                qq!</TD></TR>!
          ;
        }else{
          push @forwards, qq!<TD>$dst</TD></TR>!
          ;
        }
      }

      push @rows, qq!$n1<TD ROWSPAN=!, (scalar(@svc_forward) || 1),
            qq!><A HREF="!. popurl(2). qq!view/svc_acct.cgi?$svcnum">!,
      #print '', ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser );
            ( ($username eq '*') ? "<I>(anything)</I>" : $username ),
            qq!\@$domain</A> </TD>!,
      ;

      push @rows, @forwards;

      $rowspan += (scalar(@svc_forward) || 1);
      $n1 = "</TR><TR>";
    }
    #end of false laziness



    print <<END;
    <TR>
      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_domain.cgi?$svcnum"><FONT SIZE=-1>$svcnum</FONT></A></TD>
      <TD ROWSPAN=$rowspan>$domain</TD>
END

    print @rows;
    print "</TR>";

  }
 
  print <<END;
    </TABLE>
  </BODY>
</HTML>
END

}

sub svcnum_sort {
  $a->getfield('svcnum') <=> $b->getfield('svcnum');
}

sub domain_sort {
  $a->getfield('domain') cmp $b->getfield('domain');
}


%>
