#!/usr/bin/perl -Tw
#
# $Id: cust_main.cgi,v 1.6 1999-01-19 05:14:12 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/cust_main.cgi
#
# Note: Should be run setuid freeside as user nobody.
#
# ivan@voicenet.com 96-dec-12
#
# rewrite ivan@sisd.com 98-mar-4
#
# now does browsing too ivan@sisd.com 98-mar-6
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# display total, use FS::CGI ivan@sisd.com 98-jul-17
#
# $Log: cust_main.cgi,v $
# Revision 1.6  1999-01-19 05:14:12  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.5  1999/01/18 09:41:37  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.4  1998/12/30 00:57:50  ivan
# bug
#
# Revision 1.3  1998/12/17 09:41:08  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#
# Revision 1.2  1998/11/12 08:10:22  ivan
# CGI.pm instead of CGI-modules
# relative URLs using popurl
# got rid of lots of little tables
# s/agrep/String::Approx/;
# bubble up packages and services and link (slow)
#

use strict;
use vars qw(%ncancelled_pkgs %all_pkgs $cgi @cust_main $sortby );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use IO::Handle;
use String::Approx qw(amatch);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar idiot popurl table);
use FS::cust_main;

$cgi = new CGI;
cgisuidsetup($cgi);

if ( $cgi->keywords ) {
  my($query)=$cgi->keywords;
  if ( $query eq 'custnum' ) {
    $sortby=\*custnum_sort;
    @cust_main=qsearch('cust_main',{});  
  } elsif ( $query eq 'last' ) {
    $sortby=\*last_sort;
    @cust_main=qsearch('cust_main',{});  
  } elsif ( $query eq 'company' ) {
    $sortby=\*company_sort;
    @cust_main=qsearch('cust_main',{});
  }
} else {
  &cardsearch if ( $cgi->param('card_on') && $cgi->param('card') );
  &lastsearch if ( $cgi->param('last_on') && $cgi->param('last_text') );
  &companysearch if ( $cgi->param('company_on') && $cgi->param('company_text') );
}

%ncancelled_pkgs = map { $_->custnum => [ $_->ncancelled_pkgs ] } @cust_main;
%all_pkgs = map { $_->custnum => [ $_->all_pkgs ] } @cust_main;

if ( scalar(@cust_main) == 1 ) {
  print $cgi->redirect(popurl(2). "view/cust_main.cgi?". $cust_main[0]->custnum);
  exit;
} elsif ( scalar(@cust_main) == 0 ) {
  idiot "No matching customers found!\n";
  exit;
} else { 

  my($total)=scalar(@cust_main);
  print $cgi->header( '-expires' => 'now' ), header("Customer Search Results",menubar(
    'Main Menu', popurl(2)
  )), "$total matching customers found<BR>", table, <<END;
      <TR>
        <TH></TH>
        <TH>Contact name</TH>
        <TH>Company</TH>
        <TH>Packages</TH>
        <TH COLSPAN=2>Services</TH>
      </TR>
END

  my(%saw,$cust_main);
  foreach $cust_main (
    sort $sortby grep(!$saw{$_->custnum}++, @cust_main)
  ) {
    my($custnum,$last,$first,$company)=(
      $cust_main->custnum,
      $cust_main->getfield('last'),
      $cust_main->getfield('first'),
      $cust_main->company,
    );

    my(@lol_cust_svc);
    my($rowspan)=0;#scalar( @{$all_pkgs{$custnum}} );
    foreach ( @{$all_pkgs{$custnum}} ) {
      my(@cust_svc) = qsearch( 'cust_svc', { 'pkgnum' => $_->pkgnum } );
      push @lol_cust_svc, \@cust_svc;
      $rowspan += scalar(@cust_svc) || 1;
    }

    #my($rowspan) = scalar(@{$all_pkgs{$custnum}});
    my($view) = popurl(2). "view/cust_main.cgi?$custnum";
    print <<END;
    <TR>
      <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$custnum</FONT></A></TD>
      <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$last, $first</FONT></A></TD>
      <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$company</FONT></A></TD>
END

    my($n1)='';
    foreach ( @{$all_pkgs{$custnum}} ) {
      my($pkgnum) = ($_->pkgnum);
      my($pkg) = $_->part_pkg->pkg;
      my($pkgview) = popurl(2). "/view/cust_pkg.cgi?$pkgnum";
      #my(@cust_svc) = shift @lol_cust_svc;
      my(@cust_svc) = qsearch( 'cust_svc', { 'pkgnum' => $_->pkgnum } );
      my($rowspan) = scalar(@cust_svc) || 1;

      print $n1, qq!<TD ROWSPAN=$rowspan><A HREF="$pkgview"><FONT SIZE=-1>$pkg</FONT></A></TD>!;
      my($n2)='';
      foreach my $cust_svc ( @cust_svc ) {
         my($label, $value, $svcdb) = $cust_svc->label;
         my($svcnum) = $cust_svc->svcnum;
         my($sview) = popurl(2). "/view";
         print $n2,qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$label</FONT></A></TD>!,
               qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$value</FONT></A></TD>!;
         $n2="</TR><TR>";
      }
      #print qq!</TR><TR>\n!;
      $n1="</TR><TR>";
    }
    print "<\TR>";
  }
 
  print <<END;
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

}

#

sub last_sort {
  $a->getfield('last') cmp $b->getfield('last');
}

sub company_sort {
  return -1 if $a->company && ! $b->company;
  return 1 if ! $a->company && $b->company;
  $a->getfield('company') cmp $b->getfield('company');
}

sub custnum_sort {
  $a->getfield('custnum') <=> $b->getfield('custnum');
}

sub cardsearch {

  my($card)=$cgi->param('card');
  $card =~ s/\D//g;
  $card =~ /^(\d{13,16})$/ or do { idiot "Illegal card number\n"; exit; };
  my($payinfo)=$1;

  push @cust_main, qsearch('cust_main',{'payinfo'=>$payinfo, 'payby'=>'CARD'});

}

sub lastsearch {
  my(%last_type);
  foreach ( $cgi->param('last_type') ) {
    $last_type{$_}++;
  }

  $cgi->param('last_text') =~ /^([\w \,\.\-\']*)$/
    or do { idiot "Illegal last name"; exit; };
  my($last)=$1;

  if ( $last_type{'Exact'}
       && ! $last_type{'Fuzzy'} 
     #  && ! $last_type{'Sound-alike'}
  ) {

    push @cust_main, qsearch('cust_main',{'last'=>$last});

  } else {

    my(%last);

    my(@all_last)=map $_->getfield('last'), qsearch('cust_main',{});
    if ($last_type{'Fuzzy'}) { 
      foreach ( amatch($last, [ qw(i) ], @all_last) ) {
        $last{$_}++; 
      }
    }

    #if ($last_type{'Sound-alike'}) {
    #}

    foreach ( keys %last ) {
      push @cust_main, qsearch('cust_main',{'last'=>$_});
    }

  }
  $sortby=\*last_sort;
}

sub companysearch {

  my(%company_type);
  foreach ( $cgi->param('company_type') ) {
    $company_type{$_}++ 
  };

  $cgi->param('company_text') =~ /^([\w \,\.\-\']*)$/
    or do { idiot "Illegal company"; exit; };
  my($company)=$1;

  if ( $company_type{'Exact'}
       && ! $company_type{'Fuzzy'} 
     #  && ! $company_type{'Sound-alike'}
  ) {

    push @cust_main, qsearch('cust_main',{'company'=>$company});

  } else {

    my(%company);
    my(@all_company)=map $_->company, qsearch('cust_main',{});

    if ($company_type{'Fuzzy'}) { 
      foreach ( amatch($company, [ qw(i) ], @all_company ) ) {
        $company{$_}++;
      }
    }

    #if ($company_type{'Sound-alike'}) {
    #}

    foreach ( keys %company ) {
      push @cust_main, qsearch('cust_main',{'company'=>$_});
    }

  }
  $sortby=\*company_sort;

}
