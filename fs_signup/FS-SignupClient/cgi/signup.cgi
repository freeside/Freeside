#!/usr/bin/perl -Tw
#
# $Id: signup.cgi,v 1.3 2000-01-28 22:49:49 ivan Exp $

use strict;
use vars qw( @payby $cgi $locales $packages $pops $r $error
             $last $first $ss $company $address1 $address2 $city $state $county
             $country $zip $daytime $night $fax $invoicing_list $payby $payinfo
             $paydate $payname $pkgpart $username $password $popnum
             $ieak_file $ieak_template $ac $exch $loc
           );
             #$ieak_docroot $ieak_baseurl
use subs qw( print_form print_okay expselect );

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use HTTP::Headers::UserAgent 2.00;
use FS::SignupClient qw( signup_info new_customer );
use Text::Template;

#acceptable payment methods
#
#@payby = qw( CARD BILL COMP );
#@payby = qw( CARD BILL );
@payby = qw( CARD );

$ieak_file = '/usr/local/freeside/ieak.template';

if ( -e $ieak_file ) {
  $ieak_template = new Text::Template ( TYPE => 'FILE', SOURCE => $ieak_file )
    or die "Couldn't construct template: $Text::Template::ERROR";
} else {
  $ieak_template = '';
}

#	#to enable ieak signups, you need to specify a directory in the web server's
#	#document space and the equivalent base URL
#	#
#	$ieak_docroot = "/var/www/sisd.420.am/freeside/ieak";
#	$ieak_baseurl = "http://sisd.420.am/freeside/ieak";

#srand (time ^ $$ ^ unpack "%L*", `ps axww | gzip`);

( $locales, $packages, $pops ) = signup_info();

$cgi = new CGI;

if ( defined $cgi->param('magic') ) {
  if ( $cgi->param('magic') eq 'process' ) {

    $cgi->param('state') =~ /^(\w*)( \(([\w ]+)\))? ?\/ ?(\w+)$/
      or die "Oops, illegal \"state\" param: ". $cgi->param('state');
    $state = $1;
    $county = $3 || '';
    $country = $4;

    $payby = $cgi->param('payby');
    $payinfo = $cgi->param( $payby. '_payinfo' );
    $paydate =
      $cgi->param( $payby. '_month' ). '-'. $cgi->param( $payby. '_year' );
    $payname = $cgi->param( $payby. '_payname' );

    if ( $invoicing_list = $cgi->param('invoicing_list') ) {
      $invoicing_list .= ', POST' if $cgi->param('invoicing_list_POST');
    } else {
      $invoicing_list = 'POST';
    }

    ( $error = new_customer ( {
      'last'           => $last            = $cgi->param('last'),
      'first'          => $first           = $cgi->param('first'),
      'ss'             => $ss              = $cgi->param('ss'),
      'company'        => $company         = $cgi->param('company'),
      'address1'       => $address1        = $cgi->param('address1'),
      'address2'       => $address2        = $cgi->param('address2'),
      'city'           => $city            = $cgi->param('city'),
      'county'         => $county,
      'state'          => $state,
      'zip'            => $zip             = $cgi->param('zip'),
      'country'        => $country,
      'daytime'        => $daytime         = $cgi->param('daytime'),
      'night'          => $night           = $cgi->param('night'),
      'fax'            => $fax             = $cgi->param('fax'),
      'payby'          => $payby,
      'payinfo'        => $payinfo,
      'paydate'        => $paydate,
      'payname'        => $payname,
      'invoicing_list' => $invoicing_list,
      'pkgpart'        => $pkgpart         = $cgi->param('pkgpart'),
      'username'       => $username        = $cgi->param('username'),
      '_password'      => $password        = $cgi->param('_password'),
      'popnum'         => $popnum          = $cgi->param('popnum'),
    } ) )
      ? print_form()
      : print_okay();
  } else {
    die "unrecognized magic: ". $cgi->param('magic');
  }
} else {
  $error = '';
  $last = '';
  $first = '';
  $ss = '';
  $company = '';
  $address1 = '';
  $address2 = '';
  $city = '';
  $state = '';
  $county = '';
  $country = '';
  $zip = '';
  $daytime = '';
  $night = '';
  $fax = '';
  $invoicing_list = '';
  $payby = '';
  $payinfo = '';
  $paydate = '';
  $payname = '';
  $pkgpart = '';
  $username = '';
  $password = '';
  $popnum = '';

  print_form;
}

sub print_form {

  my $r = qq!<font color="#ff0000">*</font>!;
  my $self_url = $cgi->self_url;

  print $cgi->header( '-expires' => 'now' ), <<END;
<HTML><HEAD><TITLE>ISP Signup form</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=7>ISP Signup form</FONT><BR><BR>
END

  print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: $error</FONT>! if $error;

  print <<END;
<FORM ACTION="$self_url" METHOD=POST>
<INPUT TYPE="hidden" NAME="magic" VALUE="process">
Contact Information
<TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=0 WIDTH="100%">
<TR>
  <TH ALIGN="right">${r}Contact name<BR>(last, first)</TH>
  <TD COLSPAN=3><INPUT TYPE="text" NAME="last" VALUE="$last">,
                <INPUT TYPE="text" NAME="first" VALUE="$first"></TD>
  <TD ALIGN="right">SS#</TD>
  <TD><INPUT TYPE="text" NAME="ss" SIZE=11 VALUE="$ss"></TD>
</TR>
<TR>
  <TD ALIGN="right">Company</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="company" SIZE=70 VALUE="$company"></TD>
</TR>
<TR>
  <TH ALIGN="right">${r}Address</TH>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="address1" SIZE=70 VALUE="$address1"></TD>
</TR>
<TR>
  <TD ALIGN="right">&nbsp;</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="address2" SIZE=70 VALUE="$address2"></TD>
</TR>
<TR>
  <TH ALIGN="right">${r}City</TH>
  <TD><INPUT TYPE="text" NAME="city" VALUE="$city"></TD>
  <TH ALIGN="right">${r}State/Country</TH>
  <TD><SELECT NAME="state" SIZE="1">
END

  foreach ( @{$locales} ) {
    print "<OPTION";
    print " SELECTED" if ( $state eq $_->{'state'}
                           && $county eq $_->{'county'}
                           && $country eq $_->{'country'}
                         );
    print ">", $_->{'state'};
    print " (",$_->{'county'},")" if $_->{'county'};
    print " / ", $_->{'country'};
  }

  print <<END;
  </SELECT></TD>
  <TH>${r}Zip</TH>
  <TD><INPUT TYPE="text" NAME="zip" SIZE=10 VALUE="$zip"></TD>
</TR>
<TR>
  <TD ALIGN="right">Day Phone</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="daytime" VALUE="$daytime" SIZE=18></TD>
</TR>
<TR>
  <TD ALIGN="right">Night Phone</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="night" VALUE="$night" SIZE=18></TD>
</TR>
<TR>
  <TD ALIGN="right">Fax</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="fax" VALUE="$fax" SIZE=12></TD>
</TR>
</TABLE>$r required fields<BR>
<BR>Billing information<TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=0 WIDTH="100%">
<TR><TD>
END

  print qq!<INPUT TYPE="checkbox" NAME="invoicing_list_POST" VALUE="POST"!;
  my @invoicing_list = split(', ', $invoicing_list );
  print ' CHECKED'
    if ! @invoicing_list || grep { $_ eq 'POST' } @invoicing_list;
  print '>Postal mail invoice</TD></TR><TR><TD>Email invoice ',
         qq!<INPUT TYPE="text" NAME="invoicing_list" VALUE="!,
         join(', ', grep { $_ ne 'POST' } @invoicing_list ),
         qq!"></TD></TR>!;

  print <<END;
<TR><TD>Billing type</TD></TR></TABLE>
<TABLE BGCOLOR="#c0c0c0" BORDER=1 WIDTH="100%">
<TR>
END

  my %payby = (
    'CARD' => qq!Credit card<BR>${r}<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="" MAXLENGTH=19><BR>${r}Exp !. expselect("CARD"). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="">!,
    'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE=""><BR>${r}Exp !. expselect("BILL", "12-2037"). qq!<BR>${r}Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="Accounts Payable">!,
    'COMP' => qq!Complimentary<BR>${r}Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE=""><BR>${r}Exp !. expselect("COMP"),
  );

  my %paybychecked = (
    'CARD' => qq!Credit card<BR>${r}<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="$payinfo" MAXLENGTH=19><BR>${r}Exp !. expselect("CARD", $paydate). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="$payname">!,
    'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE="$payinfo"><BR>${r}Exp !. expselect("BILL", $paydate). qq!<BR>${r}Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="$payname">!,
    'COMP' => qq!Complimentary<BR>${r}Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE="$payinfo"><BR>${r}Exp !. expselect("COMP", $paydate),
  );

  for (@payby) {
    print qq!<TD VALIGN=TOP><INPUT TYPE="radio" NAME="payby" VALUE="$_"!;
    if ($payby eq $_) {
      print qq! CHECKED> $paybychecked{$_}</TD>!;
    } else {
      print qq!> $payby{$_}</TD>!;
    }
  }

  print <<END;
</TR></TABLE>$r required fields for each billing type
<BR><BR>First package
<TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=0 WIDTH="100%">
<TR>
  <TD COLSPAN=2><SELECT NAME="pkgpart"><OPTION VALUE="">(none)
END

  foreach my $package ( @{$packages} ) {
    print qq!<OPTION VALUE="!, $package->{'pkgpart'}, '"';
    print " SELECTED" if $pkgpart && ( $package->{'pkgpart'} == $pkgpart );
    print ">", $package->{'pkg'};
  }

  print <<END;
  </SELECT></TD>
</TR>
<TR>
  <TD ALIGN="right">Username</TD>
  <TD><INPUT TYPE="text" NAME="username" VALUE="$username"></TD>
</TR>
<TR>
  <TD ALIGN="right">Password</TD>
  <TD><INPUT TYPE="text" NAME="_password" VALUE="$password">
  (blank to generate)</TD>
</TR>
<TR>
  <TD ALIGN="right">POP</TD>
  <TD><SELECT NAME="popnum" SIZE=1><OPTION> 
END

  foreach my $pop ( @{$pops} ) {
    print qq!<OPTION VALUE="!, $pop->{'popnum'}, '"',
          ( $popnum && $pop->{'popnum'} == $popnum ) ? ' SELECTED' : '', ">", 
          $pop->{'popnum'}, ": ", 
          $pop->{'city'}, ", ",
          $pop->{'state'},
          " (", $pop->{'ac'}, ")/",
          $pop->{'exch'}, "\n"
        ;
  }
  print <<END;
  </SELECT></TD>
</TR>
</TABLE>
<BR><BR><INPUT TYPE="submit" VALUE="Signup">
</FORM></BODY></HTML>
END

}

sub print_okay {
  my $user_agent = new HTTP::Headers::UserAgnet $ENV{HTTP_USER_AGENT};
  if ( $ieak_template
       && $user_agent->platform eq 'ia32'
       && $user_agent->os =~ /^win/
       && ($user_agent->browser)[0] eq 'IE'
     )
  { #send an IEAK config
    my $username = $cgi->param('username');
    my $password = $cgi->param('_password');
    my $email_name = $cgi->param('first'). ' '. $cgi->param('last');

    print $cgi->header('application/x-Internet-signup'),
          $ieak_template->fill_in();

#    my $ins_file = rand(4294967296). ".ins";
#    open(INS_FILE, ">$ieak_docroot/$ins_file");
#    print INS_FILE <<END;
#    close INS_FILE;
#    print $cgi->redirect("$ieak_docroot/$ins_file");

  } else { #send a simple confirmation
    print $cgi->header( '-expires' => 'now' ), <<END;
<HTML><HEAD><TITLE>Signup successful</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=7>Signup successful</FONT><BR><BR>
blah blah blah
</BODY>
</HTML>
END
  }
}

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

