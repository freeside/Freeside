#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors: Antonio Gallardo <agssa@ibw.com.ni>
#                Benjamin Lee <benjaminlee@consultant.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# module for preparing Income Statement and Balance Sheet
# 
#======================================================================


use SL::RP;

1;
# end of main

# this is for our long dates
# $locale->text('January')
# $locale->text('February')
# $locale->text('March')
# $locale->text('April')
# $locale->text('May ')
# $locale->text('June')
# $locale->text('July')
# $locale->text('August')
# $locale->text('September')
# $locale->text('October')
# $locale->text('November')
# $locale->text('December')

# this is for our short month
# $locale->text('Jan')
# $locale->text('Feb')
# $locale->text('Mar')
# $locale->text('Apr')
# $locale->text('May')
# $locale->text('Jun')
# $locale->text('Jul')
# $locale->text('Aug')
# $locale->text('Sep')
# $locale->text('Oct')
# $locale->text('Nov')
# $locale->text('Dec')

# $locale->text('Balance Sheet')
# $locale->text('Income Statement')
# $locale->text('Trial Balance')
# $locale->text('AR Aging')
# $locale->text('AP Aging')
# $locale->text('Tax collected')
# $locale->text('Tax paid')
# $locale->text('Receipts')
# $locale->text('Payments')


sub report {

  %title = ( 'balance_sheet'	=> 'Balance Sheet',
             'income_statement'	=> 'Income Statement',
             'trial_balance'	=> 'Trial Balance',
	     'ar_aging'		=> 'AR Aging',
	     'ap_aging'		=> 'AP Aging',
	     'tax_collected'	=> 'Tax collected',
	     'tax_paid'		=> 'Tax paid',
	     'receipts'		=> 'Receipts',
	     'payments'		=> 'Payments',
	   );
  
  $form->{title} = $locale->text($title{$form->{report}});
  
  $form->header;
  
  $gifi = qq|
<tr>
  <th align=right>|.$locale->text('Accounts').qq|</th>
  <td><input name=accounttype class=radio type=radio value=standard checked> |.$locale->text('Standard').qq|
   
      <input name=accounttype class=radio type=radio value=gifi> |.$locale->text('GIFI').qq|
  </td>
</tr>
|;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=title value="$form->{title}">

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
|;

  if ($form->{report} eq "income_statement") {
    print qq|
        <input type=hidden name=nextsub value=generate_income_statement>
	<tr>
	  <th align=right>|.$locale->text('From').qq|</th>
	  <td><input name=fromdate size=11 title="$myconfig{dateformat}" value=$form->{fromdate}></td>
	  <th align=right>|.$locale->text('to').qq|</th>
	  <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
	</tr>
	<tr>
	  <th colspan=4>|.$locale->text('Compare to').qq|</th>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('From').qq|</th>
	  <td><input name=comparefromdate size=11 title="$myconfig{dateformat}"></td>
	  <th align=right>|.$locale->text('to').qq|</th>
	  <td><input name=comparetodate size=11 title="$myconfig{dateformat}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Decimalplaces').qq|</th>
	  <td><input name=decimalplaces size=3 maxsize=1></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Include in Report').qq|</th>
	  <td colspan=3><input name=l_heading class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Heading').qq|</td>
	  <td><input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Subtotal').qq|</td>
	</tr>
|;
  }


  if ($form->{report} eq "balance_sheet") {
    print qq|
        <input type=hidden name=nextsub value=generate_balance_sheet>
	<tr>
	  <th align=right>|.$locale->text('as at').qq|</th>
	  <td><input name=asofdate size=11 title="$myconfig{dateformat}" value=$form->{asofdate}></td>
	  <th align=right nowrap>|.$locale->text('Compare to').qq|</th>
	  <td><input name=compareasofdate size=11 title="$myconfig{dateformat}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Decimalplaces').qq|</th>
	  <td><input name=decimalplaces size=3 maxsize=1></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Include in Report').qq|</th>
	  <td><input name=l_heading class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Heading').qq|</td>
	  <td><input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Subtotal').qq|</td>
	</tr>
|;
  }


  if ($form->{report} eq "trial_balance") {
    print qq|
        <input type=hidden name=nextsub value=generate_trial_balance>
        <tr>
	  <th align=right>|.$locale->text('From').qq|</th>
	  <td><input name=fromdate size=11 title="$myconfig{dateformat}" value=$form->{fromdate}></td>
	  <th align=right>|.$locale->text('to').qq|</th>
	  <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Include in Report').qq|</th>
	  <td><input name=l_heading class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Heading').qq|
	  <input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Subtotal').qq|</td>
	</tr>
|;
  }

  
  if (($form->{report} eq "tax_paid") || ($form->{report} eq "tax_collected")) {
    $gifi = "";

    $form->{db} = ($form->{report} eq "tax_collected") ? "ar" : "ap";
    
    RP->get_taxaccounts(\%myconfig, \%$form);

    print qq|
        <input type=hidden name=nextsub value=generate_tax_report>
	<tr>
	  <th align=right>|.$locale->text('From').qq|</th>
	  <td><input name=fromdate size=11 title="$myconfig{dateformat}" value=$form->{fromdate}></td>
	  <th align=right>|.$locale->text('to').qq|</th>
	  <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Cash based').qq|</th>
	  <td><input name=cashbased class=checkbox type=checkbox value=Y></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Report for').qq|</th>
	  <td>
|;

  $checked = "checked";
  foreach $item (@{ $form->{taxaccounts} }) {
    ($accno, $description) = split /--/, $item;
    
    print qq|<input name=accno class=radio type=radio value=$accno $checked>&nbsp;$description

    <input name="${accno}_description" type=hidden value="$description">|;

    $checked = "";
  }

  print qq|
  <input type=hidden name=db value=$form->{db}>
  <input type=hidden name=sort value=transdate>

	  </td>
	</tr>
|;


  if (@{ $form->{gifi_taxaccounts} }) {
    print qq|
        <tr>
	  <th align=right>|.$locale->text('GIFI').qq|</th>
	  <td>
|;

    foreach $item (@{ $form->{gifi_taxaccounts} }) {
      ($accno, $description) = split /--/, $item;
      
      print qq|<input name=accno class=radio type=radio value="gifi_$accno" $checked>&nbsp;$description

      <input name="gifi_${accno}_description" type=hidden value="$description">|;

    }

    print qq|
	  </td>
	</tr>
|;
  }


print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right>|.$locale->text('Include in Report').qq|</th>
	  <td>
	    <table>
	      <tr>
		<td><input name="l_id" class=checkbox type=checkbox value=Y></td>
		<td>|.$locale->text('ID').qq|</td>
		<td><input name="l_invnumber" class=checkbox type=checkbox value=Y checked></td>
		<td>|.$locale->text('Invoice').qq|</td>
		<td><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		<td>|.$locale->text('Date').qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
		<td>|;
		
  if ($form->{db} eq 'ar') {
    print $locale->text('Customer');
  }
  if ($form->{db} eq 'ap') {
    print $locale->text('Vendor');
  }
  
  print qq|</td>
                <td><input name="l_netamount" class=checkbox type=checkbox value=Y checked></td>
		<td>|.$locale->text('Amount').qq|</td>
		<td><input name="l_tax" class=checkbox type=checkbox value=Y checked></td>
		<td>|.$locale->text('Tax').qq|</td>
		<td><input name="l_amount" class=checkbox type=checkbox value=Y></td>
		<td>|.$locale->text('Total').qq|</td>
	      </tr>
	      <tr>
	        <td><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
		<td>|.$locale->text('Subtotal').qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;

  }


  if (($form->{report} eq "ar_aging") || ($form->{report} eq "ap_aging")) {
    $gifi = "";

    if ($form->{report} eq 'ar_aging') {
      $label = $locale->text('Customer');
      $form->{vc} = 'customer';
    } else {
      $label = $locale->text('Vendor');
      $form->{vc} = 'vendor';
    }
      
    $nextsub = "generate_$form->{report}";
    
    # setup vc selection
    $form->all_vc(\%myconfig, $form->{vc});

    map { $vc .= "<option>$_->{name}--$_->{id}\n" } @{ $form->{"all_$form->{vc}"} };
    
    $vc = ($vc) ? qq|<select name=$form->{vc}><option>\n$vc</select>| : qq|<input name=$form->{vc} size=35>|;
    
    print qq|
	<tr>
	  <th align=right>|.$locale->text($label).qq|</th>
	  <td>$vc</td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('to').qq|</th>
	  <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
	</tr>
        <input type=hidden name=type value=statement>
        <input type=hidden name=format value=html>
	<input type=hidden name=media value=screen>

	<input type=hidden name=nextsub value=$nextsub>
	<input type=hidden name=action value=$nextsub>
|;
  }

# above action can be removed if there is more than one input field


  if (($form->{report} eq "receipts") || ($form->{report} eq "payments")) {
    $gifi = "";

    $form->{db} = ($form->{report} eq "receipts") ? "ar" : "ap";

    RP->paymentaccounts(\%myconfig, \%$form);

    $selection = "<option>\n";
    foreach $ref (@{ $form->{PR} }) {
      $paymentaccounts .= "$ref->{accno} ";
      $selection .= "<option>$ref->{accno}--$ref->{description}\n";
    }
    
    chop $paymentaccounts;

    print qq|
        <input type=hidden name=nextsub value=list_payments>
        <tr>
	  <th align=right nowrap>|.$locale->text('Account').qq|</th>
          <td colspan=3><select name=account>$selection</select>
	    <input type=hidden name=paymentaccounts value="$paymentaccounts">
	  </td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('From').qq|</th>
	  <td><input name=fromdate size=11 title="$myconfig{dateformat}" value=$form->{fromdate}></td>
	  <th align=right>|.$locale->text('to').qq|</th>
	  <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
	</tr>
	  <input type=hidden name=db value=$form->{db}>
	  <input type=hidden name=sort value=transdate>
|;

  }


  print qq|

$gifi

      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">

</form>

</body>
</html>
|;

}


sub continue { &{$form->{nextsub}} };


sub generate_income_statement {

  $form->{padding} = "&nbsp;&nbsp;";
  $form->{bold} = "<b>";
  $form->{endbold} = "</b>";
  $form->{br} = "<br>";

  RP->income_statement(\%myconfig, \%$form);


  $form->{period} = $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  $form->{todate} = $form->current_date(\%myconfig) unless $form->{todate};

  # if there are any dates construct a where
  if ($form->{fromdate} || $form->{todate}) {
    
    unless ($form->{todate}) {
      $form->{todate} = $form->current_date(\%myconfig);
    }

    $longtodate = $locale->date(\%myconfig, $form->{todate}, 1);
    $shorttodate = $locale->date(\%myconfig, $form->{todate});
    
    $longfromdate = $locale->date(\%myconfig, $form->{fromdate}, 1);
    $shortfromdate = $locale->date(\%myconfig, $form->{fromdate});
    
    $form->{this_period} = "$shortfromdate<br>\n$shorttodate";
    $form->{period} = $locale->text('for Period').qq|<br>\n$longfromdate |.$locale->text('to').qq| $longtodate|;
  }

  if ($form->{comparefromdate} || $form->{comparetodate}) {
    $longcomparefromdate = $locale->date(\%myconfig, $form->{comparefromdate}, 1);
    $shortcomparefromdate = $locale->date(\%myconfig, $form->{comparefromdate});
    
    $longcomparetodate = $locale->date(\%myconfig, $form->{comparetodate}, 1);
    $shortcomparetodate = $locale->date(\%myconfig, $form->{comparetodate});
    
    $form->{last_period} = "$shortcomparefromdate<br>\n$shortcomparetodate";
    $form->{period} .= "<br>\n$longcomparefromdate ".$locale->text('to').qq| $longcomparetodate|;
  }

 
  # setup variables for the form
  @a = qw(company address businessnumber);
  map { $form->{$_} = $myconfig{$_} } @a;
  $form->{address} =~ s/\\n/<br>/g;

  $form->{templates} = $myconfig{templates};

  $form->{IN} = "income_statement.html";
  
  $form->parse_template;

}


sub generate_balance_sheet {

  $form->{padding} = "&nbsp;&nbsp;";
  $form->{bold} = "<b>";
  $form->{endbold} = "</b>";
  $form->{br} = "<br>";

  RP->balance_sheet(\%myconfig, \%$form);

  $form->{asofdate} = $form->current_date(\%myconfig) unless $form->{asofdate};
  $form->{period} = $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  
  # define Retained Earnings account
  $padding = ($form->{l_heading}) ? $form->{padding} : "";
  push(@{$form->{equity_account}}, $padding.$locale->text('Retained Earnings'));

  $form->{this_period} = $locale->date(\%myconfig, $form->{asofdate});
  $form->{last_period} = $locale->date(\%myconfig, $form->{compareasofdate});

  $form->{IN} = "balance_sheet.html";

  # setup company variables for the form
  map { $form->{$_} = $myconfig{$_} } (qw(company address businessnumber nativecurr));
  $form->{address} =~ s/\\n/<br>/g;

  $form->{templates} = $myconfig{templates};
	  
  $form->parse_template;

}


# Antonio Gallardo
#
# D.S. Feb 16, 2001
# included links to display transactions for period entered
# added headers and subtotals
#
sub generate_trial_balance {
  
  # get for each account initial balance, debits and credits
  RP->trial_balance_details(\%myconfig, \%$form);

  $form->{nextsub} = "generate_trial_balance";
  $form->{title} = $locale->text('Trial Balance');
  &list_accounts;

}


sub list_accounts {

  $title = $form->escape($form->{title});
  
  if ($form->{projectnumber}) {
    $options .= $locale->text('Project Number')." : $form->{projectnumber}<br>";
    $projectnumber = $form->escape($form->{projectnumber});
  }
 
  # if there are any dates
  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $fromdate = $locale->date(\%myconfig, $form->{fromdate}, 1);
    }
    if ($form->{todate}) {
      $todate = $locale->date(\%myconfig, $form->{todate}, 1);
    }
    
    $form->{period} = "$fromdate - $todate";
  } else {
    $form->{period} = $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  }
  
  $options .= $form->{period};

  @column_index = qw(accno description begbalance debit credit endbalance);

  $column_header{accno} = qq|<th class=listheading>|.$locale->text('Account').qq|</th>|;
  $column_header{description} = qq|<th class=listheading>|.$locale->text('Description').qq|</th>|;
  $column_header{debit} = qq|<th class=listheading>|.$locale->text('Debit').qq|</th>|;
  $column_header{credit} = qq|<th class=listheading>|.$locale->text('Credit').qq|</th>|;
  $column_header{begbalance} = qq|<th class=listheading>|.$locale->text('Balance').qq|</th>|;
  $column_header{endbalance} = qq|<th class=listheading>|.$locale->text('Balance').qq|</th>|;


  if ($form->{accounttype} eq 'gifi') {
    $column_header{accno} = qq|<th class=listheading>|.$locale->text('GIFI').qq|</th>|;
  }
  

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$options</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr>|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;


  
  # sort the whole thing by account numbers and display
  foreach $ref (sort { $a->{accno} cmp $b->{accno} } @{ $form->{TB} }) {

    $description = $form->escape($ref->{description});
    
    $href = qq|ca.pl?path=$form->{path}&action=list_transactions&accounttype=$form->{accounttype}&login=$form->{login}&password=$form->{password}&fromdate=$form->{fromdate}&todate=$form->{todate}&sort=transdate&l_heading=$form->{l_heading}&l_subtotal=$form->{l_subtotal}&projectnumber=$projectnumber&project_id=$form->{project_id}&title=$title&nextsub=$form->{nextsub}|;
    
    if ($form->{accounttype} eq 'gifi') {
      $href .= "&gifi_accno=$ref->{accno}&gifi_description=$description";
      $na = $locale->text('N/A');
      map { $ref->{$_} = $na } qw(accno description) unless $ref->{accno};
    } else {
      $href .= "&accno=$ref->{accno}&description=$description";
    }

    $ml = ($ref->{category} =~ /(A|E)/) ? -1 : 1;
    
    $debit = $form->format_amount(\%myconfig, $ref->{debit}, 2, "&nbsp;");
    $credit = $form->format_amount(\%myconfig, $ref->{credit}, 2, "&nbsp;");
    $begbalance = $form->format_amount(\%myconfig, $ref->{balance} * $ml, 2, "&nbsp;");
    $endbalance = $form->format_amount(\%myconfig, ($ref->{balance} + $ref->{amount}) * $ml, 2, "&nbsp;");

    next if ($ref->{debit} == 0 && $ref->{credit} == 0);
    
    if ($ref->{charttype} eq "H" && $subtotal && $form->{l_subtotal}) {
      map { $column_data{$_} = "<th>&nbsp;</th>" } qw(accno begbalance endbalance);

      $subtotalbegbalance = $form->format_amount(\%myconfig, $subtotalbegbalance, 2, "&nbsp;");
      $subtotalendbalance = $form->format_amount(\%myconfig, $subtotalendbalance, 2, "&nbsp;");
      $subtotaldebit = $form->format_amount(\%myconfig, $subtotaldebit, 2, "&nbsp;");
      $subtotalcredit = $form->format_amount(\%myconfig, $subtotalcredit, 2, "&nbsp;");
      $column_data{description} = "<th>$subtotaldescription</th>";
      $column_data{begbalance} = "<th align=right>$subtotalbegbalance</th>";
      $column_data{endbalance} = "<th align=right>$subtotalendbalance</th>";
      $column_data{debit} = "<th align=right>$subtotaldebit</th>";
      $column_data{credit} = "<th align=right>$subtotalcredit</th>";
      
      print qq|
	<tr class=listsubtotal>
|;
      map { print "$column_data{$_}\n" } @column_index;
      
      print qq|
        </tr>
|;
    }
 
    if ($ref->{charttype} eq "H") {
      $subtotal = 1;
      $subtotaldescription = $ref->{description};
      $subtotaldebit = $ref->{debit};
      $subtotalcredit = $ref->{credit};
      $subtotalbegbalance = 0;
      $subtotalendbalance = 0;

      next unless $form->{l_heading};
      
      map { $column_data{$_} = "<th>&nbsp;</th>" } qw(accno debit credit begbalance endbalance);
      $column_data{description} = "<th class=listheading>$ref->{description}</th>";
    }

    if ($ref->{charttype} eq "A") {
      $column_data{accno} = "<td><a href=$href>$ref->{accno}</a></td>";
      $column_data{description} = "<td>$ref->{description}</td>";
      $column_data{debit} = "<td align=right>$debit</td>";
      $column_data{credit} = "<td align=right>$credit</td>";
      $column_data{begbalance} = "<td align=right>$begbalance</td>";
      $column_data{endbalance} = "<td align=right>$endbalance</td>";
    
      $totaldebit += $ref->{debit};
      $totalcredit += $ref->{credit};

      $subtotalbegbalance += $ref->{balance} * $ml;
      $subtotalendbalance += ($ref->{balance} + $ref->{amount}) * $ml;

    }
    
    if ($ref->{charttype} eq "H") {
      print qq|
      <tr class=listheading>
|;
    }
    if ($ref->{charttype} eq "A") {
      $i++; $i %= 2;
      print qq|
      <tr class=listrow$i>
|;
    }
    
    map { print "$column_data{$_}\n" } @column_index;
    
    print qq|
      </tr>
|;
  }


  # print last subtotal
  if ($subtotal && $form->{l_subtotal}) {
    map { $column_data{$_} = "<th>&nbsp;</th>" } qw(accno begbalance endbalance);
    $subtotalbegbalance = $form->format_amount(\%myconfig, $subtotalbegbalance, 2, "&nbsp;");
    $subtotalendbalance = $form->format_amount(\%myconfig, $subtotalendbalance, 2, "&nbsp;");
    $subtotaldebit = $form->format_amount(\%myconfig, $subtotaldebit, 2, "&nbsp;");
    $subtotalcredit = $form->format_amount(\%myconfig, $subtotalcredit, 2, "&nbsp;");
    $column_data{description} = "<th>$subdescription</th>";
    $column_data{begbalance} = "<th align=right>$subtotalbegbalance</th>";
    $column_data{endbalance} = "<th align=right>$subtotalendbalance</th>";
    $column_data{debit} = "<th align=right>$subtotaldebit</th>";
    $column_data{credit} = "<th align=right>$subtotalcredit</th>";
    
    print qq|
      <tr class=listsubtotal>
|;
    map { print "$column_data{$_}\n" } @column_index;
    
    print qq|
      </tr>
|;
  }
  
  $totaldebit = $form->format_amount(\%myconfig, $totaldebit, 2, "&nbsp;");
  $totalcredit = $form->format_amount(\%myconfig, $totalcredit, 2, "&nbsp;");

  map { $column_data{$_} = "<th>&nbsp;</th>" } qw(accno description begbalance endbalance);
 
  $column_data{debit} = qq|<th align=right class=listtotal>$totaldebit</th>|;
  $column_data{credit} = qq|<th align=right class=listtotal>$totalcredit</th>|;
  
  print qq|
        <tr class=listtotal>
|;

  map { print "$column_data{$_}\n" } @column_index;

  print qq|
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

</body>
</html>
|;

}



sub generate_ar_aging {

  # split customer
  ($form->{customer}) = split(/--/, $form->{customer});

  $form->{ct} = "customer";
  $form->{arap} = "ar";

  $form->{callback} = qq|$form->{script}?path=$form->{path}&action=generate_ar_aging&login=$form->{login}&password=$form->{password}&todate=$form->{todate}&customer=|.$form->escape($form->{customer});

  RP->aging(\%myconfig, \%$form);
  &aging;
  
}


sub generate_ap_aging {
  
  # split vendor
  ($form->{vendor}) = split(/--/, $form->{vendor});

  $form->{ct} = "vendor";
  $form->{arap} = "ap";
  
  $form->{callback} = qq|$form->{script}?path=$form->{path}&action=generate_ap_aging&login=$form->{login}&password=$form->{password}&todate=$form->{todate}&vendor=|.$form->escape($form->{vendor});

  RP->aging(\%myconfig, \%$form);
  &aging;
  
}


sub aging {


  $form->header;

  $column_header{statement} = qq|<th class=listheading>&nbsp;</th>|;
  $column_header{ct} = qq|<th class=listheading>|.$locale->text(ucfirst $form->{ct}).qq|</th>|;
  $column_header{invnumber} = qq|<th class=listheading>|.$locale->text('Invoice').qq|</th>|;
  $column_header{transdate} = qq|<th class=listheading>|.$locale->text('Date').qq|</th>|;
  $column_header{duedate} = qq|<th class=listheading>|.$locale->text('Due').qq|</th>|;
  $column_header{c0} = qq|<th class=listheading>|.$locale->text('Current').qq|</th>|;
  $column_header{c30} = qq|<th class=listheading>30</th>|;
  $column_header{c60} = qq|<th class=listheading>60</th>|;
  $column_header{c90} = qq|<th class=listheading>90</th>|;
  
  @column_index = (qw(statement ct invnumber transdate duedate c0 c30 c60 c90));

  
  if ($form->{arap} eq 'ar') {
    if ($form->{customer}) {
      $option .= "\n<br>" if $option;
      $option .= $form->{customer};
    }
  }
  if ($form->{arap} eq 'ap') {
    shift @column_index;
    if ($form->{vendor}) {
      $option .= "\n<br>" if $option;
      $option .= $form->{vendor};
    }
  }
  
  $todate = $locale->date(\%myconfig, $form->{todate}, 1);
  $option .= "\n<br>" if $option;
  $option .= $locale->text('for Period')." ".$locale->text('to')." $todate";

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;
  
  print qq|
	</tr>
|;


  $ctid = 0;
  $subtotal = 0;
  $i = 0;

  foreach $ref (@{ $form->{AG} }) {

    if ($ctid != $ref->{ctid}) {

      $i++;

      if ($subtotal) {
	$c0subtotal = $form->format_amount(\%myconfig, $c0subtotal, 2, "&nbsp");
	$c30subtotal = $form->format_amount(\%myconfig, $c30subtotal, 2, "&nbsp");
	$c60subtotal = $form->format_amount(\%myconfig, $c60subtotal, 2, "&nbsp");
	$c90subtotal = $form->format_amount(\%myconfig, $c90subtotal, 2, "&nbsp");
      }
      
      $column_data{ct} = qq|<th>&nbsp;</th>|;
      $column_data{invnumber} = qq|<th>&nbsp;</th>|;
      $column_data{transdate} = qq|<th>&nbsp;</th>|;
      $column_data{duedate} = qq|<th>&nbsp;</th>|;
      $column_data{c0} = qq|<th class=listsubtotal align=right>$c0subtotal</th>|;
      $column_data{c30} = qq|<th class=listsubtotal align=right>$c30subtotal</th>|;
      $column_data{c60} = qq|<th class=listsubtotal align=right>$c60subtotal</th>|;
      $column_data{c90} = qq|<th class=listsubtotal align=right>$c90subtotal</th>|;
     
      if ($subtotal) {
	# print subtotals
	print qq|
	<tr class=listsubtotal>
|;

	map { print "$column_data{$_}\n" } @column_index;

	$column_data{statement} = qq|<td>&nbsp;</td>|;

	print qq|
        </tr>
|;
      }
   
      $subtotal = 1;

      $c0subtotal = 0;
      $c30subtotal = 0;
      $c60subtotal = 0;
      $c90subtotal = 0;

      $column_data{ct} = qq|<td>$ref->{name}</td>|;
      $column_data{statement} = qq|<td><input name="statement_$i" type=checkbox class=checkbox value=1 $ref->{checked}>
      <input type=hidden name="$form->{ct}_id_$i" value=$ref->{ctid}>
      </td>|;
    }

    $c0subtotal += $ref->{c0};
    $c30subtotal += $ref->{c30};
    $c60subtotal += $ref->{c60};
    $c90subtotal += $ref->{c90};

    $c0total += $ref->{c0};
    $c30total += $ref->{c30};
    $c60total += $ref->{c60};
    $c90total += $ref->{c90};

    $ref->{c0} = $form->format_amount(\%myconfig, $ref->{c0}, 2, "&nbsp;");
    $ref->{c30} = $form->format_amount(\%myconfig, $ref->{c30}, 2, "&nbsp;");
    $ref->{c60} = $form->format_amount(\%myconfig, $ref->{c60}, 2, "&nbsp;");
    $ref->{c90} = $form->format_amount(\%myconfig, $ref->{c90}, 2, "&nbsp;");
 
    $href = qq|$ref->{module}.pl?path=$form->{path}&action=edit&id=$ref->{id}&login=$form->{login}&password=$form->{password}&callback=|.$form->escape($form->{callback});
    
    $column_data{invnumber} = qq|<td><a href=$href>$ref->{invnumber}</a></td>|;
    $column_data{transdate} = qq|<td>$ref->{transdate}</td>|;
    $column_data{duedate} = qq|<td>$ref->{duedate}&nbsp;</td>|;
    $column_data{c0} = qq|<td align=right>$ref->{c0}</td>|;
    $column_data{c30} = qq|<td align=right>$ref->{c30}</td>|;
    $column_data{c60} = qq|<td align=right>$ref->{c60}</td>|;
    $column_data{c90} = qq|<td align=right>$ref->{c90}</td>|;
    
    $j++; $j %= 2;
    print qq|
	<tr class=listrow$j>
|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
        </tr>
|;
 
    $column_data{ct} = qq|<td>&nbsp;</td>|;
    $column_data{statement} = qq|<td>&nbsp;</td>|;

    $ctid = $ref->{ctid};

  }
  
  # print subtotals
  $c0subtotal = $form->format_amount(\%myconfig, $c0subtotal, 2, "&nbsp;");
  $c30subtotal = $form->format_amount(\%myconfig, $c30subtotal, 2, "&nbsp;");
  $c60subtotal = $form->format_amount(\%myconfig, $c60subtotal, 2, "&nbsp;");
  $c90subtotal = $form->format_amount(\%myconfig, $c90subtotal, 2, "&nbsp;");
  
  print qq|
        <tr class=listsubtotal>
|;

  map { $column_data{$_} = qq|<th>&nbsp;</th>| } @column_index;

  $column_data{c0} = qq|<th class=listsubtotal align=right>$c0subtotal</th>|;
  $column_data{c30} = qq|<th class=listsubtotal align=right>$c30subtotal</th>|;
  $column_data{c60} = qq|<th class=listsubtotal align=right>$c60subtotal</th>|;
  $column_data{c90} = qq|<th class=listsubtotal align=right>$c90subtotal</th>|;

  map { print "$column_data{$_}\n" } @column_index;
 
  
  print qq|
        </tr>
        <tr class=listtotal>
|;

  $c0total = $form->format_amount(\%myconfig, $c0total, 2, "&nbsp;");
  $c30total = $form->format_amount(\%myconfig, $c30total, 2, "&nbsp;");
  $c60total = $form->format_amount(\%myconfig, $c60total, 2, "&nbsp;");
  $c90total = $form->format_amount(\%myconfig, $c90total, 2, "&nbsp;");
  
  $column_data{c0} = qq|<th class=listtotal align=right>$c0total</th>|;
  $column_data{c30} = qq|<th class=listtotal align=right>$c30total</th>|;
  $column_data{c60} = qq|<th class=listtotal align=right>$c60total</th>|;
  $column_data{c90} = qq|<th class=listtotal align=right>$c90total</th>|;

 
  map { print "$column_data{$_}\n" } @column_index;

  
  print qq|
          <input type=hidden name=rowcount value=$i>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
|;

  &print_options if ($form->{arap} eq 'ar');

  print qq|
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

  if ($form->{arap} eq 'ar') {
    print qq|
<input type=hidden name=todate value=$form->{todate}>

<input type=hidden name=title value="$form->{title}">

<input type=hidden name=arap value=$form->{arap}>
<input type=hidden name=ct value=$form->{ct}>
<input type=hidden name=$form->{ct} value="$form->{$form->{ct}}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>
  
<br>
<input class=submit type=submit name=action value="|.$locale->text('Select all').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Print').qq|">
<input class=submit type=submit name=action value="|.$locale->text('E-mail').qq|">
|;
  }

  print qq|
</form>

</body>
</html>
|;

}


sub select_all {

  RP->aging(\%myconfig, \%$form);

  map { $_->{checked} = "checked" } @{ $form->{AG} };

  &aging;

}


sub print_options {

  $form->{sendmode} = "attachment";
  $form->{copies} = 2 unless $form->{copies};
  
  $form->{PD}{$form->{type}} = "checked";
  $form->{DF}{$form->{format}} = "checked";
  $form->{OP}{$form->{media}} = "checked";
  $form->{SM}{$form->{sendmode}} = "checked";
  

  if ($form->{media} eq 'email') {
    $email = qq|
	<td><input class=radio type=radio name=sendmode value=attachment $form->{SM}{attachment}> |.$locale->text('Attachment')
	.qq| <input class=radio type=radio name=sendmode value=inline $form->{SM}{inline}> |.$locale->text('In-line').qq|</td>
|;
  } else {
    $screen = qq|
	<td><input class=radio type=radio name=media value=screen $form->{OP}{screen}></td>
	<td>|.$locale->text('Screen').qq|</td>
|;
  }

  print qq|
<table width=100%>
  <tr valign=top>
    <td><input class=radio type=radio name=type value=statement $form->{PD}{statement}></td><td>|.$locale->text('Statement').qq|</td>
    <td><input class=radio type=radio name=format value=html $form->{DF}{html}></td>
    <td>html</td>
|;

  if ($latex) {
      print qq|
    <td><input class=radio type=radio name=format value=postscript $form->{DF}{postscript}></td>
    <td>|.$locale->text('Postscript').qq|</td>
    <td><input class=radio type=radio name=format value=pdf $form->{DF}{pdf}></td>
    <td>|.$locale->text('PDF').qq|</td>
|;
  }

  print qq|
    $screen
|;

  if ($screen) {
    if ($myconfig{printer} && $latex) {
      print qq|
    <td><input class=radio type=radio name=media value=printer $form->{OP}{printer}></td>
    <td>|.$locale->text('Printer')
    .qq| (|.$locale->text('Copies')
    .qq| <input name=copies size=2 value=$form->{copies}>)</td>
|;
    }
  }

  print qq|
    $email
  </tr>
</table>
|;

}


sub e_mail {

  # get name and email addresses
  for $i (1 .. $form->{rowcount}) {
    if ($form->{"statement_$i"}) {
      $form->{"$form->{ct}_id"} = $form->{"$form->{ct}_id_$i"};
      RP->get_customer(\%myconfig, \%$form);
      $selected = 1;
      last;
    }
  }

  $form->error($locale->text('Nothing selected!')) unless $selected;

  if ($myconfig{admin}) {
    $bcc = qq|
          <th align=right nowrap=true>|.$locale->text('Bcc').qq|</th>
	  <td><input name=bcc size=30 value="$form->{bcc}"></td>
|;
  }

  $title = $locale->text('E-mail Statement to')." $form->{$form->{ct}}";

  $form->{media} = "email";
  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr class=listtop>
    <th class=listtop>$title</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr>
	  <th align=right nowrap>|.$locale->text('E-mail').qq|</th>
	  <td><input name=email size=30 value="$form->{email}"></td>
	  <th align=right nowrap>|.$locale->text('Cc').qq|</th>
	  <td><input name=cc size=30 value="$form->{cc}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Subject').qq|</th>
	  <td><input name=subject size=30 value="$form->{subject}"></td>
	  $bcc
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
        <tr>
	  <th align=left nowrap>|.$locale->text('Message').qq|</th>
	</tr>
	<tr>
	  <td><textarea name=message rows=15 cols=60 wrap=soft>$form->{message}</textarea></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
|;

  &print_options;

  map { delete $form->{$_} } qw(action email cc bcc subject message type sendmode format);

  # save all other variables
  foreach $key (keys %$form) {
    $form->{$key} =~ s/"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=send_email>

<br>
<input name=action class=submit type=submit value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}


sub send_email {

  $form->{OUT} = "$sendmail";

  $form->{subject} = $locale->text('Statement').qq| - $form->{todate}| unless $form->{subject};
  
  RP->aging(\%myconfig, \%$form);
  
  $form->{"statement_1"} = 1;

  &print_form;
  
  $form->redirect($locale->text('Statement sent to')." $form->{$form->{ct}}");

}



sub print {
  
  if ($form->{media} eq 'printer') {
    $form->error($locale->text('Select postscript or PDF!')) if ($form->{format} !~ /(postscript|pdf)/);
  }
  
  for $i (1 .. $form->{rowcount}) {
    if ($form->{"statement_$i"}) {
      $form->{"$form->{ct}_id"} = $form->{"$form->{ct}_id_$i"};
      $selected = 1;
      last;
    }
  }

  $form->error($locale->text('Nothing selected!')) unless $selected;
     
 
  if ($form->{media} eq 'printer') {
    $form->{OUT} = "| $myconfig{printer}";
    $form->{"$form->{ct}_id"} = "";
  } else {
    $form->{"statement_1"} = 1;
  }
  
  RP->aging(\%myconfig, \%$form);
 
  &print_form;

  $form->redirect($locale->text('Statements sent to printer!')) if ($form->{media} eq 'printer');

}


sub print_form {
  
  $form->{statementdate} = $locale->date(\%myconfig, $form->{todate}, 1);

  $form->{templates} = "$myconfig{templates}";
 
  # setup variables for the form
  @a = qw(company address businessnumber tel fax);
  map { $form->{$_} = $myconfig{$_} } @a;
  $form->format_string(@a);
  
  $form->{IN} = "$form->{type}.html";

  if ($form->{format} eq 'postscript') {
    $form->{postscript} = 1;
    $form->{IN} =~ s/html$/tex/;
  }
  if ($form->{format} eq 'pdf') {
    $form->{pdf} = 1;
    $form->{IN} =~ s/html$/tex/;
  }

  $i = 0;
  while (@{ $form->{AG} }) {

    $ref = shift @{ $form->{AG} };
    
    if ($ctid != $ref->{ctid}) {
      
      $ctid = $ref->{ctid};
      $i++;

      if ($form->{"statement_$i"}) {
	
	@a = (name, addr1, addr2, addr3, addr4, contact, "$form->{ct}phone", "$form->{ct}fax");
	map { $form->{$_} = $ref->{$_} } @a;
	$form->format_string(@a);

	$form->{$form->{ct}} = $form->{name};
	$form->{"$form->{ct}_id"} = $ref->{ctid};
	
	map { $form->{$_} = () } qw(invnumber invdate duedate);
	$form->{total} = 0;
	foreach $item (qw(c0 c30 c60 c90)) {
	  $form->{$item} = ();
	  $form->{"${item}total"} = 0;
	}

	&statement_details($ref);
	
        while ($ref) {

          if (scalar (@{ $form->{AG} }) > 0) {
	    # one or more left to go
	    if ($ctid == $form->{AG}->[0]->{ctid}) {
	      $ref = shift @{ $form->{AG} };
	      &statement_details($ref);
	      # any more?
	      $ref = scalar (@{ $form->{AG} });
	    } else {
	      $ref = 0;
	    }
	  } else {
	    # set initial ref to 0
	    $ref = 0;
	  }

	}
	
	map { $form->{"${_}total"} = $form->format_amount(\%myconfig, $form->{"${_}total"}, 2) } (c0, c30, c60, c90, "");

	$form->parse_template(\%myconfig, $userspath);
	
      }
    }
  }

}


sub statement_details {
  my ($ref) = @_;
  
  push @{ $form->{invnumber} }, $ref->{invnumber};
  push @{ $form->{invdate} }, $ref->{transdate};
  push @{ $form->{duedate} }, $ref->{duedate};
  
  foreach $item (qw(c0 c30 c60 c90)) {
    $ref->{$item} = $form->round_amount($ref->{$item} / $ref->{exchangerate}, 2);
    $form->{"${item}total"} += $ref->{$item};
    $form->{total} += $ref->{$item};
    push @{ $form->{$item} }, $form->format_amount(\%myconfig, $ref->{$item}, 2);
  }

}
 

sub generate_tax_report {

  RP->tax_report(\%myconfig, \%$form);

  $descvar = "$form->{accno}_description";
  $description = $form->escape($form->{$descvar});
  
  # construct href
  $href = "$form->{script}?path=$form->{path}&action=generate_tax_report&login=$form->{login}&password=$form->{password}&fromdate=$form->{fromdate}&todate=$form->{todate}&db=$form->{db}&accno=$form->{accno}&$descvar=$description";

  # construct callback
  $callback = $href;

 
  @columns = $form->sort_columns(qw(id transdate invnumber name netamount tax amount));

  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href .= "&l_$item=Y";
    }
  }

  if ($form->{l_subtotal} eq 'Y') {
    $callback .= "&l_subtotal=Y";
    $href .= "&l_subtotal=Y";
  }
  
  
  # if there are any dates
  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $fromdate = $locale->date(\%myconfig, $form->{fromdate}, 1);
    }
    if ($form->{todate}) {
      $todate = $locale->date(\%myconfig, $form->{todate}, 1);
    }
    
    $form->{period} = "$fromdate - $todate";
  } else {
    $form->{period} = $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  }

  $form->{title} = $locale->text('GIFI')." - " if ($form->{accno} =~ /^gifi_/);
  $form->{title} = qq|$form->{"$form->{accno}_description"} |;
  if ($form->{db} eq 'ar') {
    $form->{title} .= $locale->text('collected on sales');
    $name = $locale->text('Customer');
    $invoice = 'is.pl';
    $arap = 'ar.pl';
  }
  if ($form->{db} eq 'ap') {
    $form->{title} .= $locale->text('paid on purchases');
    $name = $locale->text('Vendor');
    $invoice = 'ir.pl';
    $arap = 'ap.pl';
  }

 
  $column_header{id} = qq|<th><a class=listheading href=$href&sort=id>|.$locale->text('ID').qq|</th>|;
  $column_header{invnumber} = qq|<th><a class=listheading href=$href&sort=invnumber>|.$locale->text('Invoice').qq|</th>|;
  $column_header{transdate} = qq|<th><a class=listheading href=$href&sort=transdate>|.$locale->text('Date').qq|</th>|;
  $column_header{netamount} = qq|<th class=listheading>|.$locale->text('Amount').qq|</th>|;
  $column_header{tax} = qq|<th class=listheading>|.$locale->text('Tax').qq|</th>|;
  $column_header{amount} = qq|<th class=listheading>|.$locale->text('Total').qq|</th>|;
  
  $column_header{name} = qq|<th><a class=listheading href=$href&sort=name>$name</th>|;

  
  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop colspan=$colspan>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$form->{period}</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;
  
  print qq|
	</tr>
|;

  # add sort and escape callback
  $callback = $form->escape($callback . "&sort=$form->{sort}");
    
  if (@{ $form->{TR} }) {
    $sameitem = $form->{TR}->[0]->{$form->{sort}};
  }

  foreach $ref (@{ $form->{TR} }) {

    $module = ($ref->{invoice}) ? $invoice : $arap;
    
    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ref->{$form->{sort}}) {
	&tax_subtotal;
	$sameitem = $ref->{$form->{sort}};
      }
    }

    $totalnetamount += $ref->{netamount};
    $totaltax += $ref->{tax};
    $ref->{amount} = $ref->{netamount} + $ref->{tax};

    $subtotalnetamount += $ref->{netamount};
    $subtotaltax += $ref->{tax};
    
    map { $ref->{$_} = $form->format_amount(\%myconfig, $ref->{$_}, 2, "&nbsp;"); } qw(netamount tax amount);
    
    $column_data{id} = qq|<td>$ref->{id}</td>|;
    $column_data{invnumber} = qq|<td><a href=$module?path=$form->{path}&action=edit&id=$ref->{id}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{invnumber}</a></td>|;
    $column_data{transdate} = qq|<td>$ref->{transdate}</td>|;
    $column_data{name} = qq|<td>$ref->{name}&nbsp;</td>|;
    
    map { $column_data{$_} = qq|<td align=right>$ref->{$_}</td>| } qw(netamount tax amount);

    $i++; $i %= 2;
    print qq|
	<tr class=listrow$i>
|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
 
  }
 
  if ($form->{l_subtotal} eq 'Y') {
    &tax_subtotal;
  }

  
  map { $column_data{$_} = qq|<th>&nbsp;</th>| } @column_index;
  
  print qq|
        </tr>
	<tr class=listtotal>
|;

  $total = $form->format_amount(\%myconfig, $totalnetamount + $totaltax, 2, "&nbsp;");
  $totalnetamount = $form->format_amount(\%myconfig, $totalnetamount, 2, "&nbsp;");
  $totaltax = $form->format_amount(\%myconfig, $totaltax, 2, "&nbsp;");
  
  $column_data{netamount} = qq|<th class=listtotal align=right>$totalnetamount</th>|;
  $column_data{tax} = qq|<th class=listtotal align=right>$totaltax</th>|;
  $column_data{amount} = qq|<th class=listtotal align=right>$total</th>|;
 
  map { print "$column_data{$_}\n" } @column_index;
 
    
  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

</body>
</html>
|;

}


sub tax_subtotal {

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $subtotalnetamount = $form->format_amount(\%myconfig, $subtotalnetamount, 2, "&nbsp;");
  $subtotaltax = $form->format_amount(\%myconfig, $subtotaltax, 2, "&nbsp;");
  $subtotal = $form->format_amount(\%myconfig, $subtotalnetamount + $subtotaltax, 2, "&nbsp;");
  
  $column_data{netamount} = "<th class=listsubtotal align=right>$subtotalnetamount</th>";
  $column_data{tax} = "<th class=listsubtotal align=right>$subtotaltax</th>";
  $column_data{amount} = "<th class=listsubtotal align=right>$subtotal</th>";

  $subtotalnetamount = 0;
  $subtotaltax = 0;
  
  print qq|
	<tr class=listsubtotal>
|;
  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;
  
}



sub list_payments {

  if ($form->{account}) {
    ($form->{paymentaccounts}) = split /--/, $form->{account};
  }

  RP->payments(\%myconfig, \%$form);
  
  @columns = $form->sort_columns(qw(transdate invnumber name paid source));

  # construct href
  $href = "$form->{script}?path=$form->{path}&action=list_payments&login=$form->{login}&password=$form->{password}&fromdate=$form->{fromdate}&todate=$form->{todate}&db=$form->{db}&title=".$form->escape($form->{title})."&account=".$form->escape($form->{account});

  $form->{paymentaccounts} =~ s/ /%20/g;
  $href .= "&paymentaccounts=$form->{paymentaccounts}";


  # construct callback
  $form->{callback} = "$href&sort=$form->{sort}";
  $callback = $form->escape($form->{callback});

  
  $column_header{name} = "<th><a class=listheading href=$href&sort=name>".$locale->text('Description')."</a></th>";
  $column_header{invnumber} = "<th><a class=listheading href=$href&sort=invnumber>".$locale->text('Invoice')."</a></th>";
  $column_header{transdate} = "<th><a class=listheading href=$href&sort=transdate>".$locale->text('Date')."</a></th>";
  $column_header{paid} = "<th class=listheading>".$locale->text('Amount')."</a></th>";
  $column_header{source} = "<th><a class=listheading href=$href&sort=source>".$locale->text('Source')."</a></th>";
  

  if ($form->{fromdate}) {
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('From')."&nbsp;".$locale->date(\%myconfig, $form->{fromdate}, 1);
  }
  if ($form->{todate}) {
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('to')."&nbsp;".$locale->date(\%myconfig, $form->{todate}, 1);
  }

  @column_index = @columns;
  $colspan = $#column_index + 1;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
|;

  map { print "\n$column_header{$_}" } @column_index;

  print qq|
        </tr>
|;

  
  foreach $ref (sort { $a->{accno} cmp $b->{accno} } @{ $form->{PR} }) {

    print qq|
        <tr>
	  <th colspan=$colspan align=left>$ref->{accno}--$ref->{description}</th>
	</tr>
|;
  
    foreach $payment (@{ $form->{$ref->{id}} }) {
      
      $module = $payment->{module};
      $module = 'is' if ($payment->{invoice} && $payment->{module} eq 'ar');
      $module = 'ir' if ($payment->{invoice} && $payment->{module} eq 'ap');
      
      $href = qq|${module}.pl?path=$form->{path}&action=edit&id=$payment->{id}&login=$form->{login}&password=$form->{password}&callback=$callback|;
    
      
      $column_data{name} = "<td>$payment->{name}&nbsp;</td>";
      $column_data{invnumber} = qq|<td><a href=$href>$payment->{invnumber}</a></td>|;
      $column_data{transdate} = "<td>$payment->{transdate}&nbsp;</td>";
      $column_data{paid} = "<td align=right>".$form->format_amount(\%myconfig, $payment->{paid}, 2, "&nbsp;")."</td>";
      $column_data{source} = "<td>$payment->{source}&nbsp;</td>";

      $subtotalpaid += $payment->{paid};
      $totalpaid += $payment->{paid};
       
      $i++; $i %= 2;
      print qq|
	<tr class=listrow$i>
|;

      map { print "\n$column_data{$_}" } @column_index;

      print qq|
        </tr>
|;

    }

    # print subtotals
    map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

    $column_data{paid} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalpaid, 2, "&nbsp;")."</th>";
     
    print qq|
	<tr class=listsubtotal>
|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>
|;

    $subtotalpaid = 0;
     
  }


  # print total
  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{paid} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalpaid, 2, "&nbsp;")."</th>";
     
  print qq|
        <tr class=listtotal>
|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>

      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

</body>
</html>
|;

}



