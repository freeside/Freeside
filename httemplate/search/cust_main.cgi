<%
#<!-- $Id: cust_main.cgi,v 1.7 2001-10-10 05:33:43 thalakan Exp $ -->

use strict;
#use vars qw( $conf %ncancelled_pkgs %all_pkgs $cgi @cust_main $sortby );
use vars qw( $conf %all_pkgs $cgi @cust_main $sortby );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use IO::Handle;
use String::Approx qw(amatch);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs dbdef ut_name);
use FS::CGI qw(header menubar eidiot popurl table);
use FS::cust_main;
use FS::cust_svc;

$cgi = new CGI;
cgisuidsetup($cgi);

$conf = new FS::Conf;

if ( $cgi->param('browse') ) {
  my $query = $cgi->param('browse');
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
    die "unknown browse field $query";
  }
} else {
  @cust_main=();
  &cardsearch if $cgi->param('card_on') && $cgi->param('card');
  &lastsearch if $cgi->param('last_on') && $cgi->param('last_text');
  &companysearch if $cgi->param('company_on') && $cgi->param('company_text');
  &referralsearch if $cgi->param('referral_custnum');
}

@cust_main = grep { $_->ncancelled_pkgs || ! $_->all_pkgs } @cust_main
  if $cgi->param('showcancelledcustomers') eq '0' #see if it was set by me
     || ( $conf->exists('hidecancelledcustomers')
           && ! $cgi->param('showcancelledcustomers') );
if ( $conf->exists('hidecancelledpackages' ) ) {
  %all_pkgs = map { $_->custnum => [ $_->ncancelled_pkgs ] } @cust_main;
} else {
  %all_pkgs = map { $_->custnum => [ $_->all_pkgs ] } @cust_main;
}

if ( scalar(@cust_main) == 1 && ! $cgi->param('referral_custnum') ) {
  print $cgi->redirect(popurl(2). "view/cust_main.cgi?". $cust_main[0]->custnum);
  exit;
} elsif ( scalar(@cust_main) == 0 ) {
  eidiot "No matching customers found!\n";
} else { 

  my($total)=scalar(@cust_main);
  print $cgi->header( '-expires' => 'now' ), header("Customer Search Results",menubar(
    'Main Menu', popurl(2)
  )), "$total matching customers found ";
  if ( $cgi->param('showcancelledcustomers') eq '0' #see if it was set by me
       || ( $conf->exists('hidecancelledcustomers')
            && ! $cgi->param('showcancelledcustomers')
          )
     ) {
    $cgi->param('showcancelledcustomers', 1);
    print qq!( <a href="!. $cgi->self_url. qq!">show cancelled customers</a> )!;
  } else {
    $cgi->param('showcancelledcustomers', 0);
    print qq!( <a href="!. $cgi->self_url. qq!">hide cancelled customers</a> )!;
  }
  if ( $cgi->param('referral_custnum') ) {
    $cgi->param('referral_custnum') =~ /^(\d+)$/
      or eidiot "Illegal referral_custnum\n";
    my $referral_custnum = $1;
    my $cust_main = qsearchs('cust_main', { custnum => $referral_custnum } );
    print '<FORM METHOD=POST>'.
          qq!<INPUT TYPE="hidden" NAME="referral_custnum" VALUE="$referral_custnum">!.
          'referrals of <A HREF="'. popurl(2).
          "view/cust_main.cgi?$referral_custnum\">$referral_custnum: ".
          ( $cust_main->company
            || $cust_main->last. ', '. $cust_main->first ).
          '</A>';
    print "\n",<<END;
      <SCRIPT>
      function changed(what) {
        what.form.submit();
      }
      </SCRIPT>
END
    print ' <SELECT NAME="referral_depth" SIZE="1" onChange="changed(this)">';
    my $max = 8; #config file
    $cgi->param('referral_depth') =~ /^(\d*)$/ 
      or eidiot "Illegal referral_depth";
    my $referral_depth = $1;

    foreach my $depth ( 1 .. $max ) {
      print '<OPTION',
            ' SELECTED'x($depth == $referral_depth),
            ">$depth";
    }
    print "</SELECT> levels deep".
          '<NOSCRIPT> <INPUT TYPE="submit" VALUE="change"></NOSCRIPT>'.
          '</FORM>';
  }
  print "<BR>", &table(), <<END;
      <TR>
        <TH></TH>
        <TH>(bill) name</TH>
        <TH>company</TH>
END

if ( defined dbdef->table('cust_main')->column('ship_last') ) {
  print <<END;
      <TH>(service) name</TH>
      <TH>company</TH>
END
}

print <<END;
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
    if ( defined dbdef->table('cust_main')->column('ship_last') ) {
      my($ship_last,$ship_first,$ship_company)=(
        $cust_main->ship_last || $cust_main->getfield('last'),
        $cust_main->ship_last ? $cust_main->ship_first : $cust_main->first,
        $cust_main->ship_last ? $cust_main->ship_company : $cust_main->company,
      );
print <<END;
      <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$ship_last, $ship_first</FONT></A></TD>
      <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$ship_company</FONT></A></TD>
END
    }

    my($n1)='';
    foreach ( @{$all_pkgs{$custnum}} ) {
      my($pkgnum) = ($_->pkgnum);
      my($pkg) = $_->part_pkg->pkg;
      my $comment = $_->part_pkg->comment;
      my($pkgview) = popurl(2). "/view/cust_pkg.cgi?$pkgnum";
      #my(@cust_svc) = shift @lol_cust_svc;
      my(@cust_svc) = qsearch( 'cust_svc', { 'pkgnum' => $_->pkgnum } );
      my($rowspan) = scalar(@cust_svc) || 1;

      print $n1, qq!<TD ROWSPAN=$rowspan><A HREF="$pkgview"><FONT SIZE=-1>$pkg - $comment</FONT></A></TD>!;
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
    print "</TR>";
  }
 
  print <<END;
    </TABLE>
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
  $card =~ /^(\d{13,16})$/ or eidiot "Illegal card number\n";
  my($payinfo)=$1;

  push @cust_main, qsearch('cust_main',{'payinfo'=>$payinfo, 'payby'=>'CARD'});
  $sortby=\*last_sort;
}

sub referralsearch {
  $cgi->param('referral_custnum') =~ /^(\d+)$/
    or eidiot "Illegal referral_custnum";
  my $cust_main = qsearchs('cust_main', { 'custnum' => $1 } )
    or eidiot "Customer $1 not found";
  my $depth;
  if ( $cgi->param('referral_depth') ) {
    $cgi->param('referral_depth') =~ /^(\d+)$/
      or eidiot "Illegal referral_depth";
    $depth = $1;
  } else {
    $depth = 1;
  }
  push @cust_main, $cust_main->referral_cust_main($depth);
  $sortby=\*last_sort;
}

sub lastsearch {
  my(%last_type);
  foreach ( $cgi->param('last_type') ) {
    $last_type{$_}++;
  }

  my $error = ut_name($cgi->param('last_text'));
  eidiot "Illegal last name" if $error;

  if ( $last_type{'Exact'}
       && ! $last_type{'Fuzzy'} 
     #  && ! $last_type{'Sound-alike'}
  ) {

    push @cust_main, qsearch('cust_main',{'last'=>$last});

    push @cust_main, qsearch('cust_main',{'ship_last'=>$last})
      if defined dbdef->table('cust_main')->column('ship_last');

  } else {

    &FS::cust_main::check_and_rebuild_fuzzyfiles;
    my $all_last = &FS::cust_main::all_last;

    my %last;
    if ($last_type{'Fuzzy'}) { 
      foreach ( amatch($last, [ qw(i) ], @$all_last) ) {
        $last{$_}++; 
      }
    }

    #if ($last_type{'Sound-alike'}) {
    #}

    foreach ( keys %last ) {
      push @cust_main, qsearch('cust_main',{'last'=>$_});
      push @cust_main, qsearch('cust_main',{'ship_last'=>$_})
        if defined dbdef->table('cust_main')->column('ship_last');
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
    or eidiot "Illegal company";
  my($company)=$1;

  if ( $company_type{'Exact'}
       && ! $company_type{'Fuzzy'} 
     #  && ! $company_type{'Sound-alike'}
  ) {

    push @cust_main, qsearch('cust_main',{'company'=>$company});

    push @cust_main, qsearch('cust_main',{'ship_company'=>$company})
      if defined dbdef->table('cust_main')->column('ship_last');

  } else {

    &FS::cust_main::check_and_rebuild_fuzzyfiles;
    my $all_company = &FS::cust_main::all_company;

    my %company;
    if ($company_type{'Fuzzy'}) { 
      foreach ( amatch($company, [ qw(i) ], @$all_company ) ) {
        $company{$_}++;
      }
    }

    #if ($company_type{'Sound-alike'}) {
    #}

    foreach ( keys %company ) {
      push @cust_main, qsearch('cust_main',{'company'=>$_});
      push @cust_main, qsearch('cust_main',{'ship_company'=>$_})
        if defined dbdef->table('cust_main')->column('ship_last');
    }

  }
  $sortby=\*company_sort;

}
%>
