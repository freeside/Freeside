#!/usr/bin/perl -Tw
#
# $Id: signup.cgi,v 1.29 2002-05-30 22:45:20 ivan Exp $

use strict;
use vars qw( @payby $cgi $locales $packages $pops $init_data $error
             $last $first $ss $company $address1 $address2 $city $state $county
             $country $zip $daytime $night $fax $invoicing_list $payby $payinfo
             $paydate $payname $referral_custnum
             $pkgpart $username $password $password2 $sec_phrase $popnum
             $agentnum
             $ieak_file $ieak_template $cck_file $cck_template
             $signup_html $signup_template
             $success_html $success_template
             $decline_html $decline_template
             $ac $exch $loc
             $email_name $pkg
             $self_url
           );
use subs qw( print_form print_okay print_decline
             signup_default success_default decline_default
             expselect );
use CGI;
#use CGI::Carp qw(fatalsToBrowser);
use Text::Template;
use Business::CreditCard;
use HTTP::Headers::UserAgent 2.00;
use FS::SignupClient 0.03 qw( signup_info new_customer );

#acceptable payment methods
#
#@payby = qw( CARD BILL COMP );
#@payby = qw( CARD BILL );
#@payby = qw( CARD );
@payby = qw( CARD PREPAY );

$ieak_file = '/usr/local/freeside/ieak.template';
$cck_file = '/usr/local/freeside/cck.template';
$signup_html = -e 'signup.html'
                 ? 'signup.html'
                 : '/usr/local/freeside/signup.html';
$success_html = -e 'success.html'
                  ? 'success.html'
                  : '/usr/local/freeside/success.html';
$decline_html = -e 'decline.html'
                  ? 'decline.html'
                  : '/usr/local/freeside/decline.html';


if ( -e $ieak_file ) {
  my $ieak_txt = Text::Template::_load_text($ieak_file)
    or die $Text::Template::ERROR;
  $ieak_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $ieak_txt = $1;
  $ieak_txt =~ s/\r//g; # don't double \r on old templates
  $ieak_txt =~ s/\n/\r\n/g;
  $ieak_template = new Text::Template ( TYPE => 'STRING', SOURCE => $ieak_txt )
    or die $Text::Template::ERROR;
} else {
  $ieak_template = '';
}

if ( -e $cck_file ) {
  my $cck_txt = Text::Template::_load_text($cck_file)
    or die $Text::Template::ERROR;
  $cck_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $cck_txt = $1;
  $cck_template = new Text::Template ( TYPE => 'STRING', SOURCE => $cck_txt )
    or die $Text::Template::ERROR;
} else {
  $cck_template = '';
}

$agentnum = '';
if ( -e $signup_html ) {
  my $signup_txt = Text::Template::_load_text($signup_html)
    or die $Text::Template::ERROR;
  $signup_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $signup_txt = $1;
  $signup_template = new Text::Template ( TYPE => 'STRING',
                                          SOURCE => $signup_txt,
                                          DELIMITERS => [ '<%=', '%>' ]
                                        )
    or die $Text::Template::ERROR;
  if ( $signup_txt =~
         /<\s*INPUT TYPE="?hidden"?\s+NAME="?agentnum"?\s+VALUE="?(\d+)"?\s*>/si
  ) {
    $agentnum = $1;
  }
} else {
  $signup_template = new Text::Template ( TYPE => 'STRING',
                                          SOURCE => &signup_default,
                                          DELIMITERS => [ '<%=', '%>' ]
                                        )
    or die $Text::Template::ERROR;
}

if ( -e $success_html ) {
  my $success_txt = Text::Template::_load_text($success_html)
    or die $Text::Template::ERROR;
  $success_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $success_txt = $1;
  $success_template = new Text::Template ( TYPE => 'STRING',
                                           SOURCE => $success_txt,
                                           DELIMITERS => [ '<%=', '%>' ],
                                         )
    or die $Text::Template::ERROR;
} else {
  $success_template = new Text::Template ( TYPE => 'STRING',
                                           SOURCE => &success_default,
                                           DELIMITERS => [ '<%=', '%>' ],
                                         )
    or die $Text::Template::ERROR;
}

if ( -e $decline_html ) {
  my $decline_txt = Text::Template::_load_text($decline_html)
    or die $Text::Template::ERROR;
  $decline_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $decline_txt = $1;
  $decline_template = new Text::Template ( TYPE => 'STRING',
                                           SOURCE => $decline_txt,
                                           DELIMITERS => [ '<%=', '%>' ],
                                         )
    or die $Text::Template::ERROR;
} else {
  $decline_template = new Text::Template ( TYPE => 'STRING',
                                           SOURCE => &decline_default,
                                           DELIMITERS => [ '<%=', '%>' ],
                                         )
    or die $Text::Template::ERROR;
}


( $locales, $packages, $pops, $init_data ) = signup_info();
@payby = @{$init_data->{'payby'}} if @{$init_data->{'payby'}};
$packages = $init_data->{agentnum2part_pkg}{$agentnum} if $agentnum;

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

    $error = '';

    $last             = $cgi->param('last');
    $first            = $cgi->param('first');
    $ss               = $cgi->param('ss');
    $company          = $cgi->param('company');
    $address1         = $cgi->param('address1');
    $address2         = $cgi->param('address2');
    $city             = $cgi->param('city');
    #$county,
    #$state,
    $zip              = $cgi->param('zip');
    #$country,
    $daytime          = $cgi->param('daytime');
    $night            = $cgi->param('night');
    $fax              = $cgi->param('fax');
    #$payby,
    #$payinfo,
    #$paydate,
    #$payname,
    #$invoicing_list,
    $referral_custnum = $cgi->param('ref');
    $pkgpart          = $cgi->param('pkgpart');
    $username         = $cgi->param('username');
    $sec_phrase       = $cgi->param('sec_phrase');
    $password         = $cgi->param('_password');
    $popnum           = $cgi->param('popnum');
    #$agentnum, #         = $cgi->param('agentnum'),

    if ( $cgi->param('_password') ne $cgi->param('_password2') ) {
      $error = $init_data->{msgcat}{passwords_dont_match}; #msgcat
      $password  = '';
      $password2 = '';
    } else {
      $password2 = $cgi->param('_password2');

      if ( $payby eq 'CARD' && $cgi->param('CARD_type') ) {
        $payinfo =~ s/\D//g;

        $payinfo =~ /^(\d{13,16})$/
          or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
        $payinfo = $1;
        validate($payinfo)
          or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
        cardtype($payinfo) eq $cgi->param('CARD_type')
          or $error ||= $init_data->{msgcat}{not_a}. $cgi->param('CARD_type');
      }

      $error ||= new_customer ( {
        'last'             => $last,
        'first'            => $first,
        'ss'               => $ss,
        'company'          => $company,
        'address1'         => $address1,
        'address2'         => $address2,
        'city'             => $city,
        'county'           => $county,
        'state'            => $state,
        'zip'              => $zip,
        'country'          => $country,
        'daytime'          => $daytime,
        'night'            => $night,
        'fax'              => $fax,
        'payby'            => $payby,
        'payinfo'          => $payinfo,
        'paydate'          => $paydate,
        'payname'          => $payname,
        'invoicing_list'   => $invoicing_list,
        'referral_custnum' => $referral_custnum,
        'pkgpart'          => $pkgpart,
        'username'         => $username,
        'sec_phrase'       => $sec_phrase,
        '_password'        => $password,
        'popnum'           => $popnum,
        'agentnum'         => $agentnum,
      } );

    }
    
    if ( $error eq '_decline' ) {
      print_decline();
    } elsif ( $error ) {
      print_form();
    } else {
      print_okay();
    }

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
  $password2 = '';
  $sec_phrase = '';
  $popnum = '';
  $referral_custnum = $cgi->param('ref') || '';
  print_form;
}

sub print_form {

  $cgi->delete('ref');
  $self_url = $cgi->self_url;

  $error = "Error: $error" if $error;

  print $cgi->header( '-expires' => 'now' ),
        $signup_template->fill_in();

}

sub print_decline {
  print $cgi->header( '-expires' => 'now' ),
        $decline_template->fill_in();
}

sub print_okay {
  my $user_agent = new HTTP::Headers::UserAgent $ENV{HTTP_USER_AGENT};

  $cgi->param('username') =~ /^(.+)$/
    or die "fatal: invalid username got past FS::SignupClient::new_customer";
  my $username = $1;
  $cgi->param('_password') =~ /^(.+)$/
    or die "fatal: invalid password got past FS::SignupClient::new_customer";
  my $password = $1;
  ( $cgi->param('first'). ' '. $cgi->param('last') ) =~ /^(.*)$/
    or die "fatal: invalid email_name got past FS::SignupClient::new_customer";
  $email_name = $1; #global for template

  my $pop = pop_info($cgi->param('popnum'));
    #or die "fatal: invalid popnum got past FS::SignupClient::new_customer";
  if ( $pop ) {
    ( $ac, $exch, $loc ) = ( $pop->{'ac'}, $pop->{'exch'}, $pop->{'loc'} );
  } else {
    ( $ac, $exch, $loc ) = ( '', '', ''); #presumably you're not using them.
  }

  #global for template
  $pkg = ( grep { $_->{'pkgpart'} eq $pkgpart } @$packages )[0]->{'pkg'};

  if ( $ieak_template
       && $user_agent->platform eq 'ia32'
       && $user_agent->os =~ /^win/
       && ($user_agent->browser)[0] eq 'IE'
     )
  { #send an IEAK config
    print $cgi->header('application/x-Internet-signup'),
          $ieak_template->fill_in();
  } elsif ( $cck_template
            && $user_agent->platform eq 'ia32'
            && $user_agent->os =~ /^win/
            && ($user_agent->browser)[0] eq 'Netscape'
          )
  { #send a Netscape config
    my $cck_data = $cck_template->fill_in();
    print $cgi->header('application/x-netscape-autoconfigure-dialer-v2'),
          map {
            m/(.*)\s+(.*)$/;
            pack("N", length($1)). $1. pack("N", length($2)). $2;
          } split(/\n/, $cck_data);

  } else { #send a simple confirmation
    print $cgi->header( '-expires' => 'now' ),
          $success_template->fill_in();
  }
}

sub pop_info {
  my $popnum = shift;
  my $pop;
  foreach $pop ( @{$pops} ) {
    if ( $pop->{'popnum'} == $popnum ) { return $pop; }
  }
  '';
}

#horrible false laziness with FS/FS/svc_acct_pop.pm::popselector
sub popselector {
  my( $popnum, $state ) = @_;

  return '<INPUT TYPE="hidden" NAME="popnum" VALUE="">' unless @$pops;
  return $pops->[0]{city}. ', '. $pops->[0]{state}.
         ' ('. $pops->[0]{ac}. ')/'. $pops->[0]{exch}.
         '<INPUT TYPE="hidden" NAME="popnum" VALUE="'. $pops->[0]{popnum}. '">'
    if scalar(@$pops) == 1;

  my %pop = ();
  push @{ $pop{$_->{state}} }, $_ foreach @$pops;

  my $text = <<END;
    <SCRIPT>
    function opt(what,href,text) {
      var optionName = new Option(text, href, false, false)
      var length = what.length;
      what.options[length] = optionName;
    }
    
    function popstate_changed(what) {
      state = what.options[what.selectedIndex].text;
      for (var i = what.form.popnum.length;i > 0;i--)
                what.form.popnum.options[i] = null;
      what.form.popnum.options[0] = new Option("", "", false, true);
END

  foreach my $popstate ( sort { $a cmp $b } keys %pop ) {
    $text .= "\nif ( state == \"$popstate\" ) {\n";

    foreach my $pop ( @{$pop{$popstate}}) {
      my $o_popnum = $pop->{popnum};
      my $poptext =  $pop->{city}. ', '. $pop->{state}.
                     ' ('. $pop->{ac}. ')/'. $pop->{exch};

      $text .= "opt(what.form.popnum, \"$o_popnum\", \"$poptext\");\n"
    }
    $text .= "}\n";
  }

  $text .= "}\n</SCRIPT>\n";

  $text .=
    qq!<SELECT NAME="popstate" SIZE=1 onChange="popstate_changed(this)">!.
    qq!<OPTION> !;
  $text .= "<OPTION>$_" foreach sort { $a cmp $b } keys %pop;
  $text .= '</SELECT>'; #callback? return 3 html pieces?  #'</TD><TD>';

  $text .= qq!<SELECT NAME="popnum" SIZE=1><OPTION> !;
  foreach my $pop ( @$pops ) {
    $text .= qq!<OPTION VALUE="!. $pop->{popnum}. '"'.
             ( ( $popnum && $pop->{popnum} == $popnum ) ? ' SELECTED' : '' ). ">".
             $pop->{city}. ', '. $pop->{state}.
               ' ('. $pop->{ac}. ')/'. $pop->{exch};
  }
  $text .= '</SELECT>';

  $text;
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
  for ( 2001 .. 2037 ) {
    $return .= "<OPTION";
    $return .= " SELECTED" if $_ == $y;
    $return .= ">$_";
  }
  $return .= "</SELECT>";

  $return;
}

sub success_default { #html to use if you don't specify a success file
  <<'END';
<HTML><HEAD><TITLE>Signup successful</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=7>Signup successful</FONT><BR><BR>
Thanks for signing up!
<BR><BR>
Signup information for <%= $email_name %>:
<BR><BR>
Username: <%= $username %><BR>
Password: <%= $password %><BR>
Access number: (<%= $ac %>) / $exch - $local<BR>
Package: <%= $pkg %><BR>
</BODY></HTML>
END
}

sub decline_default { #html to use if there is a decline
  <<'END';
<HTML><HEAD><TITLE>Processing error</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=7>Processing error</FONT><BR><BR>
There has been an error processing your account.  Please contact customer
support.
</BODY></HTML>
END
}

sub signup_default { #html to use if you don't specify a template file
  <<'END';
<HTML><HEAD><TITLE>ISP Signup form</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=7>ISP Signup form</FONT><BR><BR>
<FONT SIZE="+1" COLOR="#ff0000"><%= $error %></FONT>
<FORM ACTION="<%= $self_url %>" METHOD=POST>
<INPUT TYPE="hidden" NAME="magic" VALUE="process">
<INPUT TYPE="hidden" NAME="ref" VALUE="<%= $referral_custnum %>">
<INPUT TYPE="hidden" NAME="ss" VALUE="">
Contact Information
<TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=0 WIDTH="100%">
<TR>
  <TH ALIGN="right"><font color="#ff0000">*</font>Contact name<BR>(last, first)</TH>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="last" VALUE="<%= $last %>">,
                <INPUT TYPE="text" NAME="first" VALUE="<%= $first %>"></TD>
</TR>
<TR>
  <TD ALIGN="right">Company</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="company" SIZE=70 VALUE="<%= $company %>"></TD>
</TR>
<TR>
  <TH ALIGN="right"><font color="#ff0000">*</font>Address</TH>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="address1" SIZE=70 VALUE="<%= $address1 %>"></TD>
</TR>
<TR>
  <TD ALIGN="right">&nbsp;</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="address2" SIZE=70 VALUE="<%= $address2 %>"></TD>
</TR>
<TR>
  <TH ALIGN="right"><font color="#ff0000">*</font>City</TH>
  <TD><INPUT TYPE="text" NAME="city" VALUE="<%= $city %>"></TD>
  <TH ALIGN="right"><font color="#ff0000">*</font>State/Country</TH>
  <TD><SELECT NAME="state" SIZE="1">

  <%=
    foreach ( @{$locales} ) {
      $OUT .= '<OPTION';
      $OUT .= ' SELECTED' if ( $state eq $_->{'state'}
                               && $county eq $_->{'county'}
                               && $country eq $_->{'country'}
                             );
      $OUT .= '>'. $_->{'state'};
      $OUT .= ' ('. $_->{'county'}. ')' if $_->{'county'};
      $OUT .= ' / '. $_->{'country'};
    }
  %>

  </SELECT></TD>
  <TH><font color="#ff0000">*</font>Zip</TH>
  <TD><INPUT TYPE="text" NAME="zip" SIZE=10 VALUE="<%= $zip %>"></TD>
</TR>
<TR>
  <TD ALIGN="right">Day Phone</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="daytime" VALUE="<%= $daytime %>" SIZE=18></TD>
</TR>
<TR>
  <TD ALIGN="right">Night Phone</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="night" VALUE="<%= $night %>" SIZE=18></TD>
</TR>
<TR>
  <TD ALIGN="right">Fax</TD>
  <TD COLSPAN=5><INPUT TYPE="text" NAME="fax" VALUE="<%= $fax %>" SIZE=12></TD>
</TR>
</TABLE><font color="#ff0000">*</font> required fields<BR>
<BR>Billing information<TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=0 WIDTH="100%">
<TR><TD>

  <%=
    $OUT .= '<INPUT TYPE="checkbox" NAME="invoicing_list_POST" VALUE="POST"';
    my @invoicing_list = split(', ', $invoicing_list );
    $OUT .= ' CHECKED'
      if ! @invoicing_list || grep { $_ eq 'POST' } @invoicing_list;
    $OUT .= '>';
  %>

  Postal mail invoice
</TD></TR>
<TR><TD>Email invoice <INPUT TYPE="text" NAME="invoicing_list" VALUE="<%= join(', ', grep { $_ ne 'POST' } split(', ', $invoicing_list ) ) %>">
</TD></TR>
<%= scalar(@payby) > 1 ? '<TR><TD>Billing type</TD></TR>' : '' %>
</TABLE>
<TABLE BGCOLOR="#c0c0c0" BORDER=1 WIDTH="100%">
<TR>

  <%=

    my $cardselect = '<SELECT NAME="CARD_type"><OPTION></OPTION>';
    my %types = (
                  'VISA' => 'VISA card',
                  'MasterCard' => 'MasterCard',
                  'Discover' => 'Discover card',
                  'American Express' => 'American Express card',
                );
    foreach ( keys %types ) {
      $selected = $cgi->param('CARD_type') eq $types{$_} ? 'SELECTED' : '';
      $cardselect .= qq!<OPTION $selected VALUE="$types{$_}">$_</OPTION>!;
    }
    $cardselect .= '</SELECT>';
  
    my %payby = (
      'CARD' => qq!Credit card<BR><font color="#ff0000">*</font>$cardselect<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="" MAXLENGTH=19><BR><font color="#ff0000">*</font>Exp !. expselect("CARD"). qq!<BR><font color="#ff0000">*</font>Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="">!,
      'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE=""><BR><font color="#ff0000">*</font>Exp !. expselect("BILL", "12-2037"). qq!<BR><font color="#ff0000">*</font>Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="Accounts Payable">!,
      'COMP' => qq!Complimentary<BR><font color="#ff0000">*</font>Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE=""><BR><font color="#ff0000">*</font>Exp !. expselect("COMP"),
      'PREPAY' => qq!Prepaid card<BR><font color="#ff0000">*</font><INPUT TYPE="text" NAME="PREPAY_payinfo" VALUE="" MAXLENGTH=80>!,
    );

    my %paybychecked = (
      'CARD' => qq!Credit card<BR><font color="#ff0000">*</font>$cardselect<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="$payinfo" MAXLENGTH=19><BR><font color="#ff0000">*</font>Exp !. expselect("CARD", $paydate). qq!<BR><font color="#ff0000">*</font>Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="$payname">!,
      'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE="$payinfo"><BR><font color="#ff0000">*</font>Exp !. expselect("BILL", $paydate). qq!<BR><font color="#ff0000">*</font>Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="$payname">!,
      'COMP' => qq!Complimentary<BR><font color="#ff0000">*</font>Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE="$payinfo"><BR><font color="#ff0000">*</font>Exp !. expselect("COMP", $paydate),
      'PREPAY' => qq!Prepaid card<BR><font color="#ff0000">*</font><INPUT TYPE="text" NAME="PREPAY_payinfo" VALUE="$payinfo" MAXLENGTH=80>!,
    );

    for (@payby) {
      if ( scalar(@payby) == 1) {
        $OUT .= '<TD VALIGN=TOP>'.
                qq!<INPUT TYPE="hidden" NAME="payby" VALUE="$_">!.
                "$paybychecked{$_}</TD>";
      } else {
        $OUT .= qq!<TD VALIGN=TOP><INPUT TYPE="radio" NAME="payby" VALUE="$_"!;
        if ($payby eq $_) {
          $OUT .= qq! CHECKED> $paybychecked{$_}</TD>!;
        } else {
          $OUT .= qq!> $payby{$_}</TD>!;
        }

      }
    }
  %>

</TR></TABLE><font color="#ff0000">*</font> required fields for each billing type
<BR><BR>First package
<TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=0 WIDTH="100%">
<TR>
  <TD COLSPAN=2><SELECT NAME="pkgpart"><OPTION VALUE="">(none)

  <%=
    foreach my $package ( @{$packages} ) {
      $OUT .= '<OPTION VALUE="'. $package->{'pkgpart'}. '"';
      $OUT .= ' SELECTED' if $pkgpart && $package->{'pkgpart'} == $pkgpart;
      $OUT .= '>'. $package->{'pkg'};
    }
  %>

  </SELECT></TD>
</TR>
<TR>
  <TD ALIGN="right">Username</TD>
  <TD><INPUT TYPE="text" NAME="username" VALUE="<%= $username %>"></TD>
</TR>
<TR>
  <TD ALIGN="right">Password</TD>
  <TD><INPUT TYPE="password" NAME="_password" VALUE="<%= $password %>"></TD>
</TR>
<TR>
  <TD ALIGN="right">Re-enter Password</TD>
  <TD><INPUT TYPE="password" NAME="_password2" VALUE="<%= $password2 %>"></TD>
</TR>
<%=
  if ( $init_data->{'security_phrase'} ) {
    $OUT .= <<ENDOUT;
<TR>
  <TD ALIGN="right">Security Phrase</TD>
  <TD><INPUT TYPE="text" NAME="sec_phrase" VALUE="$sec_phrase">
  </TD>
</TR>
ENDOUT
  } else {
    $OUT .= '<INPUT TYPE="hidden" NAME="sec_phrase" VALUE="">';
  }
%>
<%=
  if ( scalar(@$pops) ) {
    $OUT .= '<TR><TD ALIGN="right">Access number</TD><TD>'.
            popselector($popnum). '</TD></TR>';
  } else {
    $OUT .= popselector($popnum);
  }
%>
</TABLE>
<BR><BR><INPUT TYPE="submit" VALUE="Signup">
</FORM></BODY></HTML>
END
}
