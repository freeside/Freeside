#!/usr/bin/perl -Tw
#
# $Id: cust_main.cgi,v 1.14 1999-04-14 07:47:53 ivan Exp $
#
# Usage: cust_main.cgi custnum
#        http://server.name/path/cust_main.cgi?custnum
#
# ivan@voicenet.com 96-nov-29 -> 96-dec-04
#
# Blank custnum for new customer.
# ivan@voicenet.com 96-dec-16
#
# referral defaults to blank, to force people to pick something
# ivan@voicenet.com 97-jun-4
#
# rewrote for new API
# ivan@voicenet.com 97-jul-28
#
# new customer is null, not '#'
# otaker gotten from &getotaker instead of $ENV{REMOTE_USER}
# ivan@sisd.com 97-nov-12
#
# cgisuidsetup($cgi);
# no need for old_ fields.
# now state+county is a select field (took out PA hack)
# used autoloaded $cust_main->field methods
# ivan@sisd.com 97-dec-17
#
# fixed quoting problems ivan@sisd.com 98-feb-23
#
# paydate sql update ivan@sisd.com 98-mar-5
#
# Changes to allow page to work at a relative position in server
# Changed 'day' to 'daytime' because Pg6.3 reserves the day word
# Added test for paydate in mm-dd-yyyy format for Pg6.3 default format
#	bmccane@maxbaud.net	98-apr-3
#
# fixed one missed day->daytime ivan@sisd.com 98-jul-13
#
# $Log: cust_main.cgi,v $
# Revision 1.14  1999-04-14 07:47:53  ivan
# i18n fixes
#
# Revision 1.13  1999/04/09 03:52:55  ivan
# explicit & for table/itable/ntable
#
# Revision 1.12  1999/04/06 11:16:16  ivan
# give a meaningful error message if you try to create a customer before you've
# created an agent
#
# Revision 1.11  1999/03/25 13:55:10  ivan
# one-screen new customer entry (including package and service) for simple
# packages with one svc_acct service
#
# Revision 1.10  1999/02/28 00:03:34  ivan
# removed misleading comments
#
# Revision 1.9  1999/02/23 08:09:20  ivan
# beginnings of one-screen new customer entry and some other miscellania
#
# Revision 1.8  1999/01/25 12:09:53  ivan
# yet more mod_perl stuff
#
# Revision 1.7  1999/01/19 05:13:34  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.6  1999/01/18 09:41:24  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.5  1999/01/18 09:22:30  ivan
# changes to track email addresses for email invoicing
#
# Revision 1.4  1998/12/23 08:08:15  ivan
# fix typo
#
# Revision 1.3  1998/12/17 06:17:00  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use vars qw( $cgi $custnum $action $cust_main $p1 @agents $agentnum 
             $last $first $ss $company $address1 $address2 $city $zip 
             $daytime $night $fax @invoicing_list $invoicing_list $payinfo
             $payname %payby %paybychecked $refnum $otaker $r );
use vars qw ( $conf $pkgpart $username $password $popnum $ulen $ulen2 );
use CGI::Switch;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
#use FS::Record qw(qsearch qsearchs fields);
use FS::Record qw(qsearch qsearchs fields dbdef);
use FS::CGI qw(header popurl itable table);
use FS::cust_main;
use FS::agent;
use FS::part_referral;
use FS::cust_main_county;

  #for misplaced logic below
  use FS::pkg_svc;
  use FS::part_svc;
  use FS::part_pkg;

  #for false laziness below
  use FS::svc_acct_pop;

  #for (other) false laziness below
  use FS::agent;
  use FS::type_pkgs;

$cgi = new CGI;
cgisuidsetup($cgi);

#get record

if ( $cgi->param('error') ) {
  $cust_main = new FS::cust_main ( {
    map { $_, scalar($cgi->param($_)) } fields('cust_main')
  } );
  $custnum = $cust_main->custnum;
  $pkgpart = $cgi->param('pkgpart_svcpart') || '';
  if ( $pkgpart =~ /^(\d+)_/ ) {
    $pkgpart = $1;
  } else {
    $pkgpart = '';
  }
  $username = $cgi->param('username');
  $password = $cgi->param('_password');
  $popnum = $cgi->param('popnum');
} elsif ( $cgi->keywords ) { #editing
  my( $query ) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $custnum=$1;
  $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
  $pkgpart = 0;
  $username = '';
  $password = '';
  $popnum = 0;
} else {
  $custnum='';
  $cust_main = new FS::cust_main ( {} );
  $cust_main->setfield('otaker',&getotaker);
  $pkgpart = 0;
  $username = '';
  $password = '';
  $popnum = 0;
}
$action = $custnum ? 'Edit' : 'Add';

# top

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("Customer $action", '');
print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');
print qq!<FORM ACTION="${p1}process/cust_main.cgi" METHOD=POST>!,
      qq!<INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!,
      qq!Customer # !, ( $custnum ? $custnum : " (NEW)" ),
      
;

# agent

$r = qq!<font color="#ff0000">*</font>!;

@agents = qsearch( 'agent', {} );
die "No agents created!" unless @agents;
$agentnum = $cust_main->agentnum || $agents[0]->agentnum; #default to first
if ( scalar(@agents) == 1 ) {
  print qq!<INPUT TYPE="hidden" NAME="agentnum" VALUE="$agentnum">!;
} else {
  print qq!<BR><BR>${r}Agent <SELECT NAME="agentnum" SIZE="1">!;
  my $agent;
  foreach $agent (sort {
    $a->agent cmp $b->agent;
  } @agents) {
      print '<OPTION VALUE="', $agent->agentnum, '"',
      " SELECTED"x($agent->agentnum==$agentnum),
      ">", $agent->agentnum,": ", $agent->agent;
  }
  print "</SELECT>";
}

#referral

$refnum = $cust_main->refnum || 0;
if ( $custnum ) {
  print qq!<INPUT TYPE="hidden" NAME="refnum" VALUE="$refnum">!;
} else {
  my(@referrals) = qsearch('part_referral',{});
  if ( scalar(@referrals) == 1 ) {
    $refnum ||= $referrals[0]->refnum;
    print qq!<INPUT TYPE="hidden" NAME="refnum" VALUE="$refnum">!;
  } else {
    print qq!<BR><BR>${r}Referral <SELECT NAME="refnum" SIZE="1">!;
    print "<OPTION> ";
    my($referral);
    foreach $referral (sort {
      $a->refnum <=> $b->refnum;
    } @referrals) {
      print "<OPTION" . " SELECTED"x($referral->refnum==$refnum),
      ">", $referral->refnum, ": ", $referral->referral;
    }
    print "</SELECT>";
  }
}


# contact info

($last,$first,$ss,$company,$address1,$address2,$city,$zip)=(
  $cust_main->last,
  $cust_main->first,
  $cust_main->ss,
  $cust_main->company,
  $cust_main->address1,
  $cust_main->address2,
  $cust_main->city,
  $cust_main->zip,
);

print "<BR><BR>Contact information", &itable("#c0c0c0"), <<END;
<TR><TH ALIGN="right">${r}Contact name<BR>(last, first)</TH><TD COLSPAN=3><INPUT TYPE="text" NAME="last" VALUE="$last">, <INPUT TYPE="text" NAME="first" VALUE="$first"></TD><TD ALIGN="right">SS#</TD><TD><INPUT TYPE="text" NAME="ss" VALUE="$ss" SIZE=11></TD></TR>
<TR><TD ALIGN="right">Company</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="company" VALUE="$company" SIZE=70></TD></TR>
<TR><TH ALIGN="right">${r}Address</TH><TD COLSPAN=5><INPUT TYPE="text" NAME="address1" VALUE="$address1" SIZE=70></TD></TR>
<TR><TD ALIGN="right">&nbsp;</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="address2" VALUE="$address2" SIZE=70></TD></TR>
<TR><TH ALIGN="right">${r}City</TH><TD><INPUT TYPE="text" NAME="city" VALUE="$city"><TH ALIGN="right">${r}State/Country</TH><TD><SELECT NAME="state" SIZE="1">
END

$cust_main->country('US') unless $cust_main->country; #eww
foreach ( qsearch('cust_main_county',{}) ) {
  print "<OPTION";
  print " SELECTED" if ( $cust_main->state eq $_->state
                         && $cust_main->county eq $_->county 
                         && $cust_main->country eq $_->country
                       );
  print ">",$_->state;
  print " (",$_->county,")" if $_->county;
  print " / ", $_->country;
}
print qq!</SELECT></TD><TH>${r}Zip</TH><TD><INPUT TYPE="text" NAME="zip" VALUE="$zip" SIZE=10></TD></TR>!;

($daytime,$night,$fax)=(
  $cust_main->daytime,
  $cust_main->night,
  $cust_main->fax,
);

print <<END;
<TR><TD ALIGN="right">Day Phone</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="daytime" VALUE="$daytime" SIZE=18></TD></TR>
<TR><TD ALIGN="right">Night Phone</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="night" VALUE="$night" SIZE=18></TD></TR>
<TR><TD ALIGN="right">Fax</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="fax" VALUE="$fax" SIZE=12></TD></TR>
END

print "</TABLE>$r required fields<BR>";

# billing info

sub expselect {
  my $prefix = shift;
  my $date = shift || '';
  my( $m, $y ) = ( 0, 0 );
  if ( $date  =~ /^(\d{4})-(\d{2})-\d{2}$/ ) { #PostgreSQL date format
    ( $m, $y ) = ( $2, $1 );
  } elsif ( $date =~ /^(\d{1,2})-(\d{1,2}-)?(\d{4}$)/ ) {
    ( $m, $y ) = ( $1, $3 );
  }
  my $return = qq!<SELECT NAME="$prefix!. qq!_month" SIZE="1">!;
  for ( 1 .. 12 ) {
    $return .= "<OPTION";
    $return .= " SELECTED" if $_ == $m;
    $return .= ">$_";
  }
  $return .= qq!</SELECT>/<SELECT NAME="$prefix!. qq!_year" SIZE="1">!;
  for ( 1999 .. 2037 ) {
    $return .= "<OPTION";
    $return .= " SELECTED" if $_ == $y;
    $return .= ">$_";
  }
  $return .= "</SELECT>";

  $return;
}

print "<BR>Billing information", &itable("#c0c0c0"),
      qq!<TR><TD><INPUT TYPE="checkbox" NAME="tax" VALUE="Y"!;
print qq! CHECKED! if $cust_main->tax eq "Y";
print qq!>Tax Exempt</TD></TR>!;
print qq!<TR><TD><INPUT TYPE="checkbox" NAME="invoicing_list_POST" VALUE="POST"!;
@invoicing_list = $cust_main->invoicing_list;
print qq! CHECKED!
  if ! @invoicing_list || grep { $_ eq 'POST' } @invoicing_list;
print qq!>Postal mail invoice</TD></TR>!;
$invoicing_list = join(', ', grep { $_ ne 'POST' } @invoicing_list );
print qq!<TR><TD>Email invoice <INPUT TYPE="text" NAME="invoicing_list" VALUE="$invoicing_list"></TD></TR>!;

print "<TR><TD>Billing type</TD></TR>",
      "</TABLE>",
      &table("#c0c0c0"), "<TR>";

($payinfo, $payname)=(
  $cust_main->payinfo,
  $cust_main->payname,
);

%payby = (
  'CARD' => qq!Credit card<BR>${r}<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="" MAXLENGTH=19><BR>${r}Exp !. expselect("CARD"). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="">!,
  'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE=""><BR>${r}Exp !. expselect("BILL", "12-2037"). qq!<BR>${r}Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="Accounts Payable">!,
  'COMP' => qq!Complimentary<BR>${r}Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE=""><BR>${r}Exp !. expselect("COMP"),
);
%paybychecked = (
  'CARD' => qq!Credit card<BR>${r}<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="$payinfo" MAXLENGTH=19><BR>${r}Exp !. expselect("CARD", $cust_main->paydate). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="$payname">!,
  'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE="$payinfo"><BR>${r}Exp !. expselect("BILL", $cust_main->paydate). qq!<BR>${r}Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="$payname">!,
  'COMP' => qq!Complimentary<BR>${r}Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE="$payinfo"><BR>${r}Exp !. expselect("COMP", $cust_main->paydate),
);
for (qw(CARD BILL COMP)) {
  print qq!<TD VALIGN=TOP><INPUT TYPE="radio" NAME="payby" VALUE="$_"!;
  if ($cust_main->payby eq "$_") {
    print qq! CHECKED> $paybychecked{$_}</TD>!;
  } else {
    print qq!> $payby{$_}</TD>!;
  }
}

print "</TR></TABLE>$r required fields for each billing type";

unless ( $custnum ) {
  # pry the wrong place for this logic.  also pretty expensive
  #use FS::pkg_svc;
  #use FS::part_svc;
  #use FS::part_pkg;

  #false laziness, copied from FS::cust_pkg::order
  my %part_pkg;
  if ( scalar(@agents) == 1 ) {
    # generate %part_pkg
    # $part_pkg{$pkgpart} is true iff $custnum may purchase $pkgpart
    	#my($cust_main)=qsearchs('cust_main',{'custnum'=>$custnum});
    	#my($agent)=qsearchs('agent',{'agentnum'=> $cust_main->agentnum });
    my($agent)=qsearchs('agent',{'agentnum'=> $agentnum });

    my($type_pkgs);
    foreach $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
      my($pkgpart)=$type_pkgs->pkgpart;
      $part_pkg{$pkgpart}++;
    }
  } else {
    #can't know (agent not chosen), so, allow all
    my %typenum;
    foreach my $agent ( @agents ) {
      next if $typenum{$agent->typenum}++;
      foreach my $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
        my($pkgpart)=$type_pkgs->pkgpart;
        $part_pkg{$pkgpart}++;
      }
    }

  }
  #eslaf

  my %pkgpart;
  #foreach ( @pkg_svc ) {
  foreach ( qsearch( 'pkg_svc', {} ) ) {
    my $part_svc = qsearchs ( 'part_svc', { 'svcpart' => $_->svcpart } );
    $pkgpart{ $_->pkgpart } = -1 # never will == 1 below
      if ( $part_svc->svcdb ne 'svc_acct' );
    if ( $pkgpart{ $_->pkgpart } ) {
      $pkgpart{ $_->pkgpart } = '-1';
    } else {
      $pkgpart{ $_->pkgpart } = $_->svcpart;
    }
  }

  my @part_pkg =
    #grep { $pkgpart{ $_->pkgpart } == 1 } qsearch( 'part_pkg', {} );
    grep {
      #( $pkgpart{ $_->pkgpart } || 0 ) == 1
      $pkgpart{ $_->pkgpart } 
      && $pkgpart{ $_->pkgpart } != -1
      && $part_pkg{ $_->pkgpart }
      ;
    } qsearch( 'part_pkg', {} );

  if ( @part_pkg ) {

    print "<BR><BR>First package", &itable("#c0c0c0"),
          qq!<TR><TD COLSPAN=2><SELECT NAME="pkgpart_svcpart">!;

    print qq!<OPTION VALUE="">(none)!;

    foreach my $part_pkg ( @part_pkg ) {
      print qq!<OPTION VALUE="!,
              $part_pkg->pkgpart. "_". $pkgpart{ $part_pkg->pkgpart }, '"';
      print " SELECTED" if $pkgpart && ( $part_pkg->pkgpart == $pkgpart );
      print ">", $part_pkg->pkg, " - ", $part_pkg->comment;
    }
    print "</SELECT></TD></TR>";

    #false laziness: (mostly) copied from edit/svc_acct.cgi
    #$ulen = $svc_acct->dbdef_table->column('username')->length;
    $ulen = dbdef->table('svc_acct')->column('username')->length;
    $ulen2 = $ulen+2;
    print <<END;
<TR><TD ALIGN="right">Username</TD>
<TD><INPUT TYPE="text" NAME="username" VALUE="$username" SIZE=$ulen2 MAXLENGTH=$ulen></TD></TR>
<TR><TD ALIGN="right">Password</TD>
<TD><INPUT TYPE="text" NAME="_password" VALUE="$password" SIZE=10 MAXLENGTH=8>
(blank to generate)</TD></TR>
END
    print qq!<TR><TD ALIGN="right">POP</TD><TD><SELECT NAME="popnum" SIZE=1><OPTION> !;
    my($svc_acct_pop);
    foreach $svc_acct_pop ( qsearch ('svc_acct_pop',{} ) ) {
    print qq!<OPTION VALUE="!, $svc_acct_pop->popnum, '"',
          ( $popnum && $svc_acct_pop->popnum == $popnum ) ? ' SELECTED' : '', ">", 
          $svc_acct_pop->popnum, ": ", 
          $svc_acct_pop->city, ", ",
          $svc_acct_pop->state,
          " (", $svc_acct_pop->ac, ")/",
          $svc_acct_pop->exch, "\n"
        ;
    }
    print "</SELECT></TD></TR></TABLE>";
  }
}

$otaker = $cust_main->otaker;
print qq!<INPUT TYPE="hidden" NAME="otaker" VALUE="$otaker">!,
      qq!<BR><BR><INPUT TYPE="submit" VALUE="!,
      $custnum ?  "Apply Changes" : "Add Customer", qq!">!,
      "</FORM></BODY></HTML>",
;

