#!/usr/bin/perl -Tw
#
# process/cust_main.cgi: Search for customers (process form)
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

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use IO::Handle;
use IPC::Open2;
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header idiot);

my($fuzziness)=2; #fuzziness for fuzzy searches, see man agrep
                  #0-4: 0=no fuzz, 4=very fuzzy (too much fuzz!)

my($req)=new CGI::Request;
&cgisuidsetup($req->cgi);

my(@cust_main);
my($sortby);

my($query)=$req->cgi->var('QUERY_STRING');
if ( $query eq 'custnum' ) {
  $sortby=\*custnum_sort;
  @cust_main=qsearch('cust_main',{});  
} elsif ( $query eq 'last' ) {
  $sortby=\*last_sort;
  @cust_main=qsearch('cust_main',{});  
} elsif ( $query eq 'company' ) {
  $sortby=\*company_sort;
  @cust_main=qsearch('cust_main',{});  
} else {
  &cardsearch if ($req->param('card_on') );
  &lastsearch if ($req->param('last_on') );
  &companysearch if ($req->param('company_on') );
}

if ( scalar(@cust_main) == 1 ) {
  $req->cgi->redirect("../view/cust_main.cgi?". $cust_main[0]->custnum);
  exit;
} elsif ( scalar(@cust_main) == 0 ) {
  idiot "No matching customers found!\n";
  exit;
} else { 

  my($total)=scalar(@cust_main);
  CGI::Base::SendHeaders(); # one guess
  print header("Customer Search Results",''), <<END;

    $total matching customers found
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Cust. #</TH>
        <TH>Contact name</TH>
        <TH>Company</TH>
      </TR>
END

  my($lines)=16;
  my($lcount)=$lines;
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
    print <<END;
    <TR>
      <TD><A HREF="../view/cust_main.cgi?$custnum"><FONT SIZE=-1>$custnum</FONT></A></TD>
      <TD><FONT SIZE=-1>$last, $first</FONT></TD>
      <TD><FONT SIZE=-1>$company</FONT></TD>
    </TR>
END
    if ($lcount-- == 0) { # lots of little tables instead of one big one
      $lcount=$lines;
      print <<END;   
  </TABLE>
  <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
    <TR>
      <TH>Cust. #</TH>
      <TH>Contact name</TH>
      <TH>Company<TH>
    </TR>
END
    }
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
  $a->getfield('company') cmp $b->getfield('company');
}

sub custnum_sort {
  $a->getfield('custnum') <=> $b->getfield('custnum');
}

sub cardsearch {

  my($card)=$req->param('card');
  $card =~ s/\D//g;
  $card =~ /^(\d{13,16})$/ or do { idiot "Illegal card number\n"; exit; };
  my($payinfo)=$1;

  push @cust_main, qsearch('cust_main',{'payinfo'=>$payinfo, 'payby'=>'CARD'});

}

sub lastsearch {
  my(%last_type);
  foreach ( $req->param('last_type') ) {
    $last_type{$_}++;
  }

  $req->param('last_text') =~ /^([\w \,\.\-\']*)$/
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
      my($reader,$writer) = ( new IO::Handle, new IO::Handle );
      open2($reader,$writer,'agrep',"-$fuzziness",'-i','-k',
            substr($last,0,30));
      print $writer join("\n",@all_last),"\n";
      close $writer;
      while (<$reader>) {
        chop;
        $last{$_}++;
      } 
      close $reader;
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
  foreach ( $req->param('company_type') ) {
    $company_type{$_}++ 
  };

  $req->param('company_text') =~ /^([\w \,\.\-\']*)$/
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
      my($reader,$writer) = ( new IO::Handle, new IO::Handle );
      open2($reader,$writer,'agrep',"-$fuzziness",'-i','-k',
            substr($company,0,30));
      print $writer join("\n",@all_company),"\n";
      close $writer;
      while (<$reader>) {
        chop;
        $company{$_}++;
      }
      close $reader;
    }

    #if ($company_type{'Sound-alike'}) {
    #}

    foreach ( keys %company ) {
      push @cust_main, qsearch('cust_main',{'company'=>$_});
    }

  }
  $sortby=\*company_sort;

}
