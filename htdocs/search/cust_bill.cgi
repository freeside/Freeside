#!/usr/bin/perl -Tw
#
# $Id: cust_bill.cgi,v 1.6 2001-04-22 01:38:39 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/cust_bill.cgi
#
# ivan@voicenet.com 97-apr-4
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: cust_bill.cgi,v $
# Revision 1.6  2001-04-22 01:38:39  ivan
# svc_domain needs to import dbh sub from Record
# view/cust_main.cgi needs to use ->owed method, not check (depriciated) owed field
# search/cust_bill.cgi redirect error when there's only one invoice
#
# Revision 1.5  2000/07/17 16:45:41  ivan
# first shot at invoice browsing and some other cleanups
#
# Revision 1.4  1999/02/28 00:03:54  ivan
# removed misleading comments
#
# Revision 1.3  1999/01/19 05:14:11  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.2  1998/12/17 09:41:07  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#

use strict;
use vars qw ( $cgi $invnum $query $sortby @cust_bill );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Date::Format;
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl header menubar eidiot table );
use FS::Record qw(qsearch qsearchs);
use FS::cust_bill;
use FS::cust_main;

$cgi = new CGI;
cgisuidsetup($cgi);

if ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  if ( $query eq 'invnum' ) {
    $sortby = \*invnum_sort;
    @cust_bill = qsearch('cust_bill', {} );
  } elsif ( $query eq 'date' ) {
    $sortby = \*date_sort;
    @cust_bill = qsearch('cust_bill', {} );
  } elsif ( $query eq 'custnum' ) {
    $sortby = \*custnum_sort;
    @cust_bill = qsearch('cust_bill', {} );
  } elsif ( $query eq 'OPEN_invnum' ) {
    $sortby = \*invnum_sort;
    @cust_bill = grep $_->owed != 0, qsearch('cust_bill', {} );
  } elsif ( $query eq 'OPEN_date' ) {
    $sortby = \*date_sort;
    @cust_bill = grep $_->owed != 0, qsearch('cust_bill', {} );
  } elsif ( $query eq 'OPEN_custnum' ) {
    $sortby = \*custnum_sort;
    @cust_bill = grep $_->owed != 0, qsearch('cust_bill', {} );
  } elsif ( $query =~ /^OPEN(\d+)_invnum$/ ) {
    my $open = $1 * 86400;
    $sortby = \*invnum_sort;
    @cust_bill =
      grep $_->owed != 0 && $_->_date < time - $open, qsearch('cust_bill', {} );
  } elsif ( $query =~ /^OPEN(\d+)_date$/ ) {
    my $open = $1 * 86400;
    $sortby = \*date_sort;
    @cust_bill =
      grep $_->owed != 0 && $_->_date < time - $open, qsearch('cust_bill', {} );
  } elsif ( $query =~ /^OPEN(\d+)_custnum$/ ) {
    my $open = $1 * 86400;
    $sortby = \*custnum_sort;
    @cust_bill =
      grep $_->owed != 0 && $_->_date < time - $open, qsearch('cust_bill', {} );
  } else {
    die "unknown query string $query";
  }
} else {
  $cgi->param('invnum') =~ /^\s*(FS-)?(\d+)\s*$/;
  $invnum = $2;
  @cust_bill = qsearchs('cust_bill', { 'invnum' => $invnum } );
  $sortby = \*invnum_sort;
}

if ( scalar(@cust_bill) == 1 ) {
  my $invnum = $cust_bill[0]->invnum;
  print $cgi->redirect(popurl(2). "view/cust_bill.cgi?$invnum");  #redirect
} elsif ( scalar(@cust_bill) == 0 ) {
  eidiot("Invoice not found.");
} else {
  my $total = scalar(@cust_bill);
  print $cgi->header( '-expires' => 'now' ),
        &header("Invoice Search Results", menubar(
          'Main Menu', popurl(2)
        )), "$total matching invoices found<BR>", &table(), <<END;
      <TR>
        <TH></TH>
        <TH>Balance</TH>
        <TH>Amount</TH>
        <TH>Date</TH>
        <TH>Contact name</TH>
        <TH>Company</TH>
      </TR>
END

  my(%saw, $cust_bill);
  foreach $cust_bill (
    sort $sortby grep(!$saw{$_->invnum}++, @cust_bill)
  ) {
    my($invnum, $owed, $charged, $date ) = (
      $cust_bill->invnum,
      $cust_bill->owed,
      $cust_bill->charged,
      $cust_bill->_date,
    );
    my $pdate = time2str("%b %d %Y", $date);

    my $rowspan = 1;

    my $view = popurl(2). "view/cust_bill.cgi?$invnum";
    print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$invnum</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>\$$owed</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>\$$charged</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$pdate</FONT></A></TD>
END
    my $custnum = $cust_bill->custnum;
    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
    if ( $cust_main ) {
      my $cview = popurl(2). "view/cust_main.cgi?". $cust_main->custnum;
      my ( $name, $company ) = (
        $cust_main->last. ', '. $cust_main->first,
        $cust_main->company,
      );
      print <<END;
        <TD ROWSPAN=$rowspan><A HREF="$cview"><FONT SIZE=-1>$name</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$cview"><FONT SIZE=-1>$company</FONT></A></TD>
END
    } else {
      print <<END
        <TD ROWSPAN=$rowspan COLSPAN=2>WARNING: couldn't find cust_main.custnum $custnum (cust_bill.invnum $invnum)</TD>
END
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

sub invnum_sort {
  $a->invnum <=> $b->invnum;
}

sub custnum_sort {
  $a->custnum <=> $b->custnum || $a->invnum <=> $b->invnum;
}

sub date_sort {
  $a->_date <=> $b->_date || $a->invnum <=> $b->invnum;
}
