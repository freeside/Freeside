#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2000
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
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
# Accounts Receivable
#
#======================================================================


use SL::AR;
use SL::IS;
use SL::PE;

require "$form->{path}/arap.pl";
require "$form->{path}/arapprn.pl";

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


sub add {

  $form->{title} = "Add";
  $form->{callback} = "$form->{script}?action=add&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  &create_links;
  &display_form;
  
}


sub edit {

  $form->{title} = "Edit";

  &create_links;
  &display_form;

}


sub display_form {

  &form_header;
  &form_footer;

}


sub create_links {

  $form->create_links("AR", \%myconfig, "customer");
  $duedate = $form->{duedate};

  $form->{formname} = "transaction";
  $form->{format} = "postscript" if $myconfig{printer};
  $form->{media} = $myconfig{printer};
  
  # currencies
  @curr = split /:/, $form->{currencies};
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];

  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  IS->get_customer(\%myconfig, \%$form);

  $form->{duedate} = $duedate if $duedate;
  $form->{notes} = $form->{intnotes} if !$form->{id};
  
  $form->{oldcustomer} = "$form->{customer}--$form->{customer_id}";
  $form->{oldtransdate} = $form->{transdate};

  # customers
  if (@{ $form->{all_customer} }) {
    $form->{customer} = "$form->{customer}--$form->{customer_id}";
    map { $form->{selectcustomer} .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } (@{ $form->{all_customer} });
  }
  
  # departments
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";
    $form->{department} = "$form->{department}--$form->{department_id}";
    
    map { $form->{selectdepartment} .= qq|<option value="$_->{description}--$_->{id}">$_->{description}\n| } (@{ $form->{all_departments} });
  }
  
  $form->{employee} = "$form->{employee}--$form->{employee_id}";
  # sales staff
  if (@{ $form->{all_employees} }) {
    $form->{selectemployee} = "";
    map { $form->{selectemployee} .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } (@{ $form->{all_employees} });
  }
  
  # projects
  if (@{ $form->{all_projects} }) {
    $form->{selectprojectnumber} = "<option>\n";
    map { $form->{selectprojectnumber} .= qq|<option value="$_->{projectnumber}--$_->{id}">$_->{projectnumber}\n| } (@{ $form->{all_projects} });
  }

  if (@{ $form->{all_languages} }) {
    $form->{selectlanguage} = "<option>\n";
    map { $form->{selectlanguage} .= qq|<option value="$_->{code}">$_->{description}\n| } @{ $form->{all_languages} };
  }

  # forex
  $form->{forex} = $form->{exchangerate};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  foreach $key (keys %{ $form->{AR_links} }) {
       
    foreach $ref (@{ $form->{AR_links}{$key} }) {
      if ($key eq 'AR_tax') {
	$form->{"selectAR_tax_$ref->{accno}"} = "<option>$ref->{accno}--$ref->{description}\n";
	$form->{"calctax_$ref->{accno}"} = 1;
	next;
      }
      $form->{"select$key"} .= "<option>$ref->{accno}--$ref->{description}\n";
    }
    
    # if there is a value we have an old entry
    for $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {
      if ($key eq "AR_paid") {
	$form->{"AR_paid_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
	# reverse paid
	$form->{"paid_$i"} = $form->{acc_trans}{$key}->[$i-1]->{amount} * -1;
	$form->{"datepaid_$i"} = $form->{acc_trans}{$key}->[$i-1]->{transdate};
	$form->{"source_$i"} = $form->{acc_trans}{$key}->[$i-1]->{source};
	$form->{"memo_$i"} = $form->{acc_trans}{$key}->[$i-1]->{memo};
	
	$form->{"forex_$i"} = $form->{"exchangerate_$i"} = $form->{acc_trans}{$key}->[$i-1]->{exchangerate};
	
	$form->{paidaccounts}++;
      } else {
     
	$akey = $key;
	$akey =~ s/AR_//;
	
        if ($key eq "AR_tax") {
	  $form->{"${key}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
	  $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} = $form->round_amount($form->{acc_trans}{$key}->[$i-1]->{amount} / $exchangerate, 2);
	  
	  if ($form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"} > 0) {
	    $totaltax += $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
	    $taxrate += $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};
	  } else {
	    $totalwithholding += $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
	    $withholdingrate += $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};
	  }

	} else {
	  $form->{"${akey}_$i"} = $form->round_amount($form->{acc_trans}{$key}->[$i-1]->{amount} / $exchangerate, 2);
	  if ($akey eq 'amount') {
	    $form->{rowcount}++;
	    $totalamount += $form->{"${akey}_$i"};

            $form->{"projectnumber_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{projectnumber}--$form->{acc_trans}{$key}->[$i-1]->{project_id}";
	  }
	  $form->{"${key}_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
	}
      }
    }
  }

  $form->{paidaccounts} = 1 if not defined $form->{paidaccounts};

  if ($form->{taxincluded} && $totalamount) {
    # add tax to individual amounts
    for $i (1 .. $form->{rowcount}) {
      $taxamount = ($totaltax + $totalwithholding) * $form->{"amount_$i"} / $totalamount;
      $tax = $form->round_amount($taxamount, 2);
      $diff += ($taxamount - $tax);
      $form->{"amount_$i"} += $tax;
    }
    $form->{amount_1} += $form->round_amount($diff, 2);
  }
  
  # check if calculated is equal to stored
  # taxincluded is terrible to calculate
  # this works only if all taxes are checked
  foreach $item (split / /, $form->{taxaccounts}) {
    if ($form->{taxincluded}) {
      if ($form->{"${item}_rate"} > 0) {
	if ($taxrate) {
	  $taxamount = $form->round_amount(($totalamount + $totaltax + $totalwithholding) * $taxrate / (1 + $taxrate), 2) * $form->{"${item}_rate"} / $taxrate;
	}
      } else {
	if ($withholdingrate) {
	  $taxamount = $form->round_amount(($totalamount + $totaltax + $totalwithholding) * $withholdingrate / (1 - $withholdingrate), 2) * $form->{"${item}_rate"} / $withholdingrate;
	}
      }
    } else {
      $taxamount = $totalamount * $form->{"${item}_rate"};
    }
    $taxamount = $form->round_amount($taxamount, 2);

    $form->{"calctax_$item"} = 0;
    if ($form->{"tax_$item"} == $taxamount) {
      $form->{"calctax_$item"} = 1;
    }
  }

  $form->{invtotal} = $totalamount + $totaltax + $totalwithholding;
  $form->{rowcount}++ if $form->{id};
  
  $form->{AR} = $form->{AR_1};
  $form->{rowcount} = 1 unless $form->{AR_amount_1};
  
  $form->{locked} = ($form->{revtrans}) ? '1' : ($form->datetonum($form->{transdate}, \%myconfig) <= $form->datetonum($form->{closedto}, \%myconfig));

  # readonly
  $form->{readonly} = 1 if $myconfig{acs} =~ /AR--Add Transaction/;

}


sub form_header {

  $title = $form->{title};
  $form->{title} = $locale->text("$title AR Transaction");

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";
  
# $locale->text('Add AR Transaction')
# $locale->text('Edit AR Transaction')

  # set option selected
  foreach $item (qw(AR currency)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/<option>\Q$form->{$item}\E/<option selected>$form->{$item}/;
  }
  
  foreach $item (qw(customer department employee)) {
    $form->{"select$item"} = $form->unescape($form->{"select$item"});
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/(<option value="\Q$form->{$item}\E")/$1 selected/;
  }

  $form->{selectprojectnumber} = $form->unescape($form->{selectprojectnumber});
  
  # format amounts
  $form->{exchangerate} = $form->format_amount(\%myconfig, $form->{exchangerate});
  
  $exchangerate = qq|
<input type=hidden name=forex value=$form->{forex}>
|;
  if ($form->{currency} ne $form->{defaultcurrency}) {
    if ($form->{forex}) {
      $exchangerate .= qq|
	<th align=right>|.$locale->text('Exchange Rate').qq|</th>
	<td><input type=hidden name=exchangerate value=$form->{exchangerate}>$form->{exchangerate}</td>
|;
    } else {
      $exchangerate .= qq|
        <th align=right>|.$locale->text('Exchange Rate').qq|</th>
        <td><input name=exchangerate size=10 value=$form->{exchangerate}></td>
|;
    }
  }
  
  $taxincluded = "";
  if ($form->{taxaccounts}) {
    $taxincluded = qq|
	      <tr>
		<td align=right><input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}></td>
		<th align=left nowrap>|.$locale->text('Tax Included').qq|</th>
	      </tr>
|;
  }

 
  if (($rows = $form->numtextrows($form->{notes}, 50)) < 2) {
    $rows = 2;
  }
  $notes = qq|<textarea name=notes rows=$rows cols=50 wrap=soft>$form->{notes}</textarea>|;
  
  $department = qq|
	      <tr>
		<th align="right" nowrap>|.$locale->text('Department').qq|</th>
		<td colspan=3><select name=department>$form->{selectdepartment}</select>
		<input type=hidden name=selectdepartment value="|.$form->escape($form->{selectdepartment},1).qq|">
		</td>
	      </tr>
| if $form->{selectdepartment};

 
  $n = ($form->{creditremaining} < 0) ? "0" : "1";

  $customer = ($form->{selectcustomer}) ? qq|<select name=customer>$form->{selectcustomer}</select>| : qq|<input name=customer value="$form->{customer}" size=35>|;

  $employee = qq|
                <input type=hidden name=employee value="$form->{employee}">
|;

  $employee = qq|
	      <tr>
		<th align=right nowrap>|.$locale->text('Salesperson').qq|</th>
		<td><select name=employee>$form->{selectemployee}</select></td>
		<input type=hidden name=selectemployee value="|.$form->escape($form->{selectemployee},1).qq|">
	      </tr>
| if $form->{selectemployee};

  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>

<input type=hidden name=type value="transaction">
<input type=hidden name=vc value="customer">

<input type=hidden name=queued value="$form->{queued}">
<input type=hidden name=printed value="$form->{printed}">
<input type=hidden name=emailed value="$form->{emailed}">

<input type=hidden name=sort value=$form->{sort}>

<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>

<input type=hidden name=title value="$title">

<input type=hidden name=oldtransdate value=$form->{oldtransdate}>
<input type=hidden name=audittrail value="$form->{audittrail}">

<table width=100%>
  <tr class=listtop>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table width=100%>
        <tr valign=top>
	  <td>
	    <table>
	      <tr>
		<th align="right" nowrap>|.$locale->text('Customer').qq|</th>
		<td colspan=3>$customer</td>
		<input type=hidden name=selectcustomer value="|.$form->escape($form->{selectcustomer},1).qq|">
		<input type=hidden name=oldcustomer value="$form->{oldcustomer}">
		<input type=hidden name=customer_id value="$form->{customer_id}">
		<input type=hidden name=terms value=$form->{terms}>
	      </tr>
	      <tr>
		<td></td>
		<td colspan=3>
		  <table width=100%>
		    <tr>
		      <th align=left nowrap>|.$locale->text('Credit Limit').qq|</th>
		      <td>$form->{creditlimit}</td>
		      <th align=left nowrap>|.$locale->text('Remaining').qq|</th>
		      <td class="plus$n">|.$form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0").qq|</td>
		      <input type=hidden name=creditlimit value=$form->{creditlimit}>
		      <input type=hidden name=creditremaining value=$form->{creditremaining}>
		    </tr>
		  </table>
		</td>
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Currency').qq|</th>
		<td><select name=currency>$form->{selectcurrency}</select></td>
		<input type=hidden name=selectcurrency value="$form->{selectcurrency}">
		<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
		<input type=hidden name=fxgain_accno value=$form->{fxgain_accno}>
		<input type=hidden name=fxloss_accno value=$form->{fxloss_accno}>
		$exchangerate
	      </tr>
	      $department
	      $taxincluded
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      $employee
	      <tr>
		<th align=right nowrap>|.$locale->text('Invoice Number').qq|</th>
		<td><input name=invnumber size=20 value="$form->{invnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Order Number').qq|</th>
		<td><input name=ordnumber size=20 value="$form->{ordnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Invoice Date').qq|</th>
		<td><input name=transdate size=11 title="($myconfig{'dateformat'})" value=$form->{transdate}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Due Date').qq|</th>
		<td><input name=duedate size=11 title="$myconfig{'dateformat'}" value=$form->{duedate}></td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
    
<input type=hidden name=selectAR_amount value="$form->{selectAR_amount}">
<input type=hidden name=selectprojectnumber value="|.$form->escape($form->{selectprojectnumber},1).qq|">
<input type=hidden name=rowcount value=$form->{rowcount}>
|;

  $amount = $locale->text('Amount');
  
  for $i (1 .. $form->{rowcount}) {

    $selectAR_amount = $form->{selectAR_amount};
    $selectAR_amount =~ s/option>\Q$form->{"AR_amount_$i"}\E/option selected>$form->{"AR_amount_$i"}/;
    
    $selectprojectnumber = $form->{selectprojectnumber};
    $selectprojectnumber =~ s/(<option value="\Q$form->{"projectnumber_$i"}\E")/$1 selected/;
    
    # format amounts
    $form->{"amount_$i"} = $form->format_amount(\%myconfig, $form->{"amount_$i"}, 2);

    $project = qq|
	  <td align=right><select name="projectnumber_$i">$selectprojectnumber</select></td>
| if $form->{selectprojectnumber};
	  
    print qq|
	<tr>
	  <th align=right>$amount</th>
	  <td><input name="amount_$i" size=10 value=$form->{"amount_$i"}></td>
	  <td></td>
	  <td><select name="AR_amount_$i">$selectAR_amount</select></td>
	  $project
	</tr>
|;
    $amount = "";
  }


  $taxlabel = ($form->{taxincluded}) ? $locale->text('Tax Included') : $locale->text('Tax');
  
  foreach $item (split / /, $form->{taxaccounts}) {

    $form->{"calctax_$item"} = ($form->{"calctax_$item"}) ? "checked" : "";

    $form->{"tax_$item"} = $form->format_amount(\%myconfig, $form->{"tax_$item"}, 2);
    print qq|
        <tr>
	  <th align=right nowrap>$taxlabel</th>
	  <td><input name="tax_$item" size=10 value=$form->{"tax_$item"}></td>
	  <td align=right><input name="calctax_$item" class=checkbox type=checkbox value=1 $form->{"calctax_$item"}></td>
	  <td><select name="AR_tax_$item">$form->{"selectAR_tax_$item"}</select></td>
	</tr>
	<input type=hidden name="${item}_rate" value="$form->{"${item}_rate"}">
	<input type=hidden name="${item}_description" value="$form->{"${item}_description"}">
	<input type=hidden name="selectAR_tax_$item" value="$form->{"selectAR_tax_$item"}">
|;
  
  }

  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2);

  print qq|
        <tr>

	  <th align=right>|.$locale->text('Total').qq|</th>
	  <th align=left>$form->{invtotal}</th>
	  <td></td>

	  <input type=hidden name=oldinvtotal value=$form->{oldinvtotal}>
	  <input type=hidden name=oldtotalpaid value=$form->{oldtotalpaid}>

	  <input type=hidden name=taxaccounts value="$form->{taxaccounts}">

	  <td><select name=AR>$form->{selectAR}</select></td>
          <input type=hidden name=selectAR value="$form->{selectAR}">
  
        </tr>
        <tr valign=top>
	  <th align=right>|.$locale->text('Notes').qq|</th>
	  <td colspan=4>$notes</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
	  <th colspan=6 class=listheading>|.$locale->text('Payments').qq|</th>
	</tr>
|;

  if ($form->{currency} eq $form->{defaultcurrency}) {
    @column_index = qw(datepaid source memo paid AR_paid);
  } else {
    @column_index = qw(datepaid source memo paid exchangerate AR_paid);
  }

  $column_data{datepaid} = "<th>".$locale->text('Date')."</th>";
  $column_data{paid} = "<th>".$locale->text('Amount')."</th>";
  $column_data{exchangerate} = "<th>".$locale->text('Exch')."</th>";
  $column_data{AR_paid} = "<th>".$locale->text('Account')."</th>";
  $column_data{source} = "<th>".$locale->text('Source')."</th>";
  $column_data{memo} = "<th>".$locale->text('Memo')."</th>";
  
  print "
        <tr>
";
  map { print "$column_data{$_}\n" } @column_index;
  print "
        </tr>
";


  $form->{paidaccounts}++ if ($form->{"paid_$form->{paidaccounts}"});
  for $i (1 .. $form->{paidaccounts}) {
    print "
        <tr>
";

    $form->{"selectAR_paid_$i"} = $form->{selectAR_paid};
    $form->{"selectAR_paid_$i"} =~ s/option>\Q$form->{"AR_paid_$i"}\E/option selected>$form->{"AR_paid_$i"}/;
  
    # format amounts
    $form->{"paid_$i"} = $form->format_amount(\%myconfig, $form->{"paid_$i"}, 2);
    $form->{"exchangerate_$i"} = $form->format_amount(\%myconfig, $form->{"exchangerate_$i"});

    $exchangerate = qq|&nbsp;|;
    if ($form->{currency} ne $form->{defaultcurrency}) {
      if ($form->{"forex_$i"}) {
	$exchangerate = qq|<input type=hidden name="exchangerate_$i" value=$form->{"exchangerate_$i"}>$form->{"exchangerate_$i"}|;
      } else {
	$exchangerate = qq|<input name="exchangerate_$i" size=10 value=$form->{"exchangerate_$i"}>|;
      }
    }
    
    $exchangerate .= qq|
<input type=hidden name="forex_$i" value=$form->{"forex_$i"}>
|;

    $column_data{paid} = qq|<td align=center><input name="paid_$i" size=11 value=$form->{"paid_$i"}></td>|;
    $column_data{AR_paid} = qq|<td align=center><select name="AR_paid_$i">$form->{"selectAR_paid_$i"}</select></td>|;
    $column_data{exchangerate} = qq|<td align=center>$exchangerate</td>|;
    $column_data{datepaid} = qq|<td align=center><input name="datepaid_$i" size=11 value=$form->{"datepaid_$i"}></td>|;
    $column_data{source} = qq|<td align=center><input name="source_$i" size=11 value="$form->{"source_$i"}"></td>|;
    $column_data{memo} = qq|<td align=center><input name="memo_$i" size=11 value="$form->{"memo_$i"}"></td>|;

    map { print qq|$column_data{$_}\n| } @column_index;
    
    print "
        </tr>
";
  }
  
  print qq|
<input type=hidden name=paidaccounts value=$form->{paidaccounts}>
<input type=hidden name=selectAR_paid value="$form->{selectAR_paid}">

      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

}


sub form_footer {

  &print_options;
  
  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<br>
|;

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  
  if (! $form->{readonly}) {
    
    if ($form->{id}) {
      print qq|<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
|;

      if (!$form->{locked}) {
	print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Post').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Print').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Print and Post').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">
|;
      }

      print qq|
<input class=submit type=submit name=action value="|.$locale->text('Post as new').qq|">
|;

    } else {
      if ($transdate > $closedto) {
	print qq|<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Print').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Post').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Print and Post').qq|">|;
      }
    }
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print "
</form>

</body>
</html>
";

}


sub update {
  my $display = shift;

  if ($display) {
    goto TAXCALC;
  }

  $form->{invtotal} = 0;
  
  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate);

  @flds = qw(amount AR_amount projectnumber);
  $count = 0;
  @a = ();
  for $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} = $form->parse_amount(\%myconfig, $form->{"amount_$i"});
    if ($form->{"amount_$i"}) {
      push @a, {};
      $j = $#a;

      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }

  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
  $form->{rowcount} = $count + 1;

  map { $form->{invtotal} += $form->{"amount_$_"} } (1 .. $form->{rowcount});

  $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, 'buy')));


  if (&check_name(customer)) {
    $form->{notes} = $form->{intnotes} unless $form->{id};
  }

  if ($form->{transdate} ne $form->{oldtransdate}) {
    $form->{duedate} = $form->current_date(\%myconfig, $form->{transdate}, $form->{terms} * 1);
    $form->{oldtransdate} = $form->{transdate};
  }
  


TAXCALC:
  # recalculate taxes

  @taxaccounts = split / /, $form->{taxaccounts};
  
  map { $form->{"tax_$_"} = $form->parse_amount(\%myconfig, $form->{"tax_$_"}) } @taxaccounts;
  
  if ($form->{taxincluded}) {
    $taxrate = 0;
    $withholdingrate = 0;

    foreach $item (@taxaccounts) {
      $form->{"calctax_$item"} = 1 if $form->{calctax};
      
      if ($form->{"calctax_$item"}) {
	if ($form->{"${item}_rate"} > 0) {
	  $taxrate += $form->{"${item}_rate"};
	} else {
	  $withholdingrate += $form->{"${item}_rate"};
	}
      }
    }

    foreach $item (@taxaccounts) {

      if ($form->{"calctax_$item"}) {
	if ($form->{"${item}_rate"} > 0) {
	  if ($taxrate) {
	    $amount = $form->round_amount($form->{invtotal} * $taxrate / (1 + $taxrate), 2) * $form->{"${item}_rate"} / $taxrate;
	    $form->{"tax_$item"} = $form->round_amount($amount, 2);
	    $taxdiff += ($amount - $form->{"tax_$item"});
	  }
	} else {
	  if ($withholdingrate) {
	    $amount = $form->round_amount($form->{invtotal} * $withholdingrate / (1 - $withholdingrate), 2) * $form->{"${item}_rate"} / $withholdingrate;
	    $form->{"tax_$item"} = $form->round_amount($amount, 2);
	    $taxdiff += ($amount - $form->{"tax_$item"});
	  }
	}

	if (abs($taxdiff) >= 0.005) {
	  $form->{"tax_$item"} += $form->round_amount($taxdiff, 2);
	  $taxdiff = 0;
	}
      }
      $form->{"selectAR_tax_$item"} = qq|<option>$item--$form->{"${item}_description"}|;
      $totaltax += $form->{"tax_$item"};
    }
  } else {
    foreach $item (@taxaccounts) {
      $form->{"calctax_$item"} = 1 if $form->{calctax};
      
      if ($form->{"calctax_$item"}) {
	$form->{"tax_$item"} = $form->round_amount($form->{invtotal} * $form->{"${item}_rate"}, 2);
      }
      $form->{"selectAR_tax_$item"} = qq|<option>$item--$form->{"${item}_description"}|;
      $totaltax += $form->{"tax_$item"};
    }
  }

  $form->{invtotal} = ($form->{taxincluded}) ? $form->{invtotal} : $form->{invtotal} + $totaltax;

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);

      $totalpaid += $form->{"paid_$i"};

      $form->{"exchangerate_$i"} = $exchangerate if ($form->{"forex_$i"} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy')));
    }
  }

  $form->{creditremaining} -= ($form->{invtotal} - $totalpaid + $form->{oldtotalpaid} - $form->{oldinvtotal});
  $form->{oldinvtotal} = $form->{invtotal};
  $form->{oldtotalpaid} = $totalpaid;
  
  &display_form;
  
}


sub post {

  # check if there is an invoice number, invoice and due date
  $form->isblank("transdate", $locale->text('Invoice Date missing!'));
  $form->isblank("duedate", $locale->text('Due Date missing!'));
  $form->isblank("customer", $locale->text('Customer missing!'));

  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  
  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($transdate <= $closedto);

  $form->isblank("exchangerate", $locale->text('Exchange rate missing!')) if ($form->{currency} ne $form->{defaultcurrency});
  
  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);
      
      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!')) if ($datepaid <= $closedto);

      if ($form->{currency} ne $form->{defaultcurrency}) {
	$form->{"exchangerate_$i"} = $form->{exchangerate} if ($transdate == $datepaid);
	$form->isblank("exchangerate_$i", $locale->text('Exchange rate for payment missing!'));
      }
    }
  }

  # if oldcustomer ne customer redo form
  ($customer) = split /--/, $form->{customer};
  if ($form->{oldcustomer} ne "$customer--$form->{customer_id}") {
    &update;
    exit;
  }

  $form->{invnumber} = $form->update_defaults(\%myconfig, "sinumber") unless $form->{invnumber};

  $form->{id} = 0 if $form->{postasnew};

  $form->redirect($locale->text('Transaction posted!')) if (AR->post_transaction(\%myconfig, \%$form));
  $form->error($locale->text('Cannot post transaction!'));

}


sub post_as_new {

  $form->{postasnew} = 1;
  &post;

}


sub delete {

  $form->{title} = $locale->text('Confirm!');
  
  $form->header;

  delete $form->{header};

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  $form->hide_form();

  print qq|
<h2 class=confirm>$form->{title}</h2>

<h4>|.$locale->text('Are you sure you want to delete Transaction').qq| $form->{invnumber}</h4>

<input name=action class=submit type=submit value="|.$locale->text('Yes').qq|">
</form>

</body>
</html>
|;

}



sub yes {

  $form->redirect($locale->text('Transaction deleted!')) if (AR->delete_transaction(\%myconfig, \%$form, $spool));
  $form->error($locale->text('Cannot delete transaction!'));

}


sub search {

  $form->create_links("AR", \%myconfig, "customer");
  
  $form->{selectAR} = "<option>\n";
  map { $form->{selectAR} .= "<option>$_->{accno}--$_->{description}\n" } @{ $form->{AR_links}{AR} };
  
  if (@{ $form->{all_customer} }) { 
    map { $customer .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } @{ $form->{all_customer} };
    $customer = qq|<select name=customer><option>\n$customer</select>|;
  } else {
    $customer = qq|<input name=customer size=35>|;
  }

  # departments 
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map { $form->{selectdepartment} .= qq|<option value="$_->{description}--$_->{id}">$_->{description}\n| } (@{ $form->{all_departments} });
  }

  $department = qq| 
        <tr> 
	  <th align=right nowrap>|.$locale->text('Department').qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	</tr>
| if $form->{selectdepartment};


  $form->{title} = $locale->text('AR Transactions');

  $invnumber = qq|
	<tr>
	  <th align=right nowrap>|.$locale->text('Invoice Number').qq|</th>
	  <td colspan=3><input name=invnumber size=20></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Order Number').qq|</th>
	  <td colspan=3><input name=ordnumber size=20></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Notes').qq|</th>
	  <td colspan=3><input name=notes size=40></td>
	</tr>
|;

  $openclosed = qq|
	      <tr>
		<td align=right><input name=open class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Open').qq|</td>
		<td align=right><input name=closed class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Closed').qq|</td>
	      </tr>
|;

  if ($form->{outstanding}) {
    $form->{title} = $locale->text('AR Outstanding');
    $invnumber = "";
    $openclosed = "";
  }

  # accounting years
  $form->{selectaccountingyear} = "<option>\n";
  map { $form->{selectaccountingyear} .= qq|<option>$_\n| } @{ $form->{all_years} };
  $form->{selectaccountingmonth} = "<option>\n";
  map { $form->{selectaccountingmonth} .= qq|<option value=$_>|.$locale->text($form->{all_month}{$_}).qq|\n| } sort keys %{ $form->{all_month} };

  $selectfrom = qq|
        <tr>
	<th align=right>|.$locale->text('Period').qq|</th>
	<td colspan=3>
	<select name=month>$form->{selectaccountingmonth}</select>
	<select name=year>$form->{selectaccountingyear}</select>
	<input name=interval class=radio type=radio value=0 checked>|.$locale->text('Current').qq|
	<input name=interval class=radio type=radio value=1>|.$locale->text('Month').qq|
	<input name=interval class=radio type=radio value=3>|.$locale->text('Quarter').qq|
	<input name=interval class=radio type=radio value=12>|.$locale->text('Year').qq|
	</td>
      </tr>
|;

    
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=title value="$form->{title}">
<input type=hidden name=outstanding value=$form->{outstanding}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right>|.$locale->text('Account').qq|</th>
	  <td colspan=3><select name=AR>$form->{selectAR}</select></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Customer').qq|</th>
	  <td colspan=3>$customer</td>
	</tr>
	$department
	$invnumber
	<tr>
	  <th align=right>|.$locale->text('Ship via').qq|</th>
	  <td colspan=3><input name=shipvia size=40></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('From').qq|</th>
	  <td><input name=transdatefrom size=11 title="$myconfig{dateformat}"></td>
	  <th align=right>|.$locale->text('To').qq|</th>
	  <td><input name=transdateto size=11 title="$myconfig{dateformat}"></td>
	</tr>
	<input type=hidden name=sort value=transdate>
	$selectfrom
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Include in Report').qq|</th>
	  <td>
	    <table width=100%>
	      $openclosed
	      <tr>
		<td align=right><input name="l_id" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('ID').qq|</td>
		<td align=right><input name="l_invnumber" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Invoice Number').qq|</td>
		<td align=right><input name="l_ordnumber" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Order Number').qq|</td>
		<td align=right><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Invoice Date').qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Customer').qq|</td>
		<td align=right><input name="l_employee" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Salesperson').qq|</td>
		<td align=right><input name="l_manager" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Manager').qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_netamount" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Amount').qq|</td>
		<td align=right><input name="l_tax" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Tax').qq|</td>
		<td align=right><input name="l_amount" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Total').qq|</td>
		<td align=right><input name="l_curr" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Currency').qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_datepaid" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Date Paid').qq|</td>
		<td align=right><input name="l_paid" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Paid').qq|</td>
		<td align=right><input name="l_duedate" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Due Date').qq|</td>
		<td align=right><input name="l_due" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Amount Due').qq|</td>
	      </tr>
	      <tr valign=top>
		<td align=right><input name="l_notes" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Notes').qq|</td>
		<td align=right><input name="l_till" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Till').qq|</td>
		<td align=right><input name="l_shippingpoint" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Shipping Point').qq|</td>
		<td align=right><input name="l_shipvia" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Ship via').qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Subtotal').qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=$form->{nextsub}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">

</form>

</body>
</html>
|;

}


sub ar_transactions {

  if ($form->{customer}) {
    $form->{customer} = $form->unescape($form->{customer});
    ($form->{customer}, $form->{customer_id}) = split(/--/, $form->{customer});
  }
  
  AR->ar_transactions(\%myconfig, \%$form);

  $href = "$form->{script}?action=ar_transactions&direction=$form->{direction}&oldsort=$form->{oldsort}&till=$form->{till}&outstanding=$form->{outstanding}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";
  
  $href .= "&title=".$form->escape($form->{title});

  $form->sort_order();
  
  $callback = "$form->{script}?action=ar_transactions&direction=$form->{direction}&oldsort=$form->{oldsort}&till=$form->{till}&outstanding=$form->{outstanding}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";

  $callback .= "&title=".$form->escape($form->{title},1);

  if ($form->{AR}) {
    $callback .= "&AR=".$form->escape($form->{AR},1);
    $href .= "&AR=".$form->escape($form->{AR});
    $form->{AR} =~ s/--/ /;
    $option = $locale->text('Account')." : $form->{AR}";
  }
  
  if ($form->{customer}) {
    $callback .= "&customer=".$form->escape($form->{customer},1)."--$form->{customer_id}";
    $href .= "&customer=".$form->escape($form->{customer})."--$form->{customer_id}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Customer')." : $form->{customer}";
  }
  if ($form->{department}) {
    $callback .= "&department=".$form->escape($form->{department},1);
    $href .= "&department=".$form->escape($form->{department});
    ($department) = split /--/, $form->{department};
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Department')." : $department";
  }
  if ($form->{invnumber}) {
    $callback .= "&invnumber=".$form->escape($form->{invnumber},1);
    $href .= "&invnumber=".$form->escape($form->{invnumber});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Invoice Number')." : $form->{invnumber}";
  }
  if ($form->{ordnumber}) {
    $callback .= "&ordnumber=".$form->escape($form->{ordnumber},1);
    $href .= "&ordnumber=".$form->escape($form->{ordnumber});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Order Number')." : $form->{ordnumber}";
  }
  if ($form->{notes}) {
    $callback .= "&notes=".$form->escape($form->{notes},1);
    $href .= "&notes=".$form->escape($form->{notes});
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Notes')." : $form->{notes}";
  }
  
  if ($form->{transdatefrom}) {
    $callback .= "&transdatefrom=$form->{transdatefrom}";
    $href .= "&transdatefrom=$form->{transdatefrom}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('From')."&nbsp;".$locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    $callback .= "&transdateto=$form->{transdateto}";
    $href .= "&transdateto=$form->{transdateto}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('To')."&nbsp;".$locale->date(\%myconfig, $form->{transdateto}, 1);
  }
  if ($form->{open}) {
    $callback .= "&open=$form->{open}";
    $href .= "&open=$form->{open}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Open');
  }
  if ($form->{closed}) {
    $callback .= "&closed=$form->{closed}";
    $href .= "&closed=$form->{closed}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Closed');
  }

  @columns = $form->sort_columns(qw(transdate id invnumber ordnumber name netamount tax amount paid due curr datepaid duedate notes till employee manager shippingpoint shipvia));
  
  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      if ($form->{l_curr} && $item =~ /(amount|tax|paid|due)/) {
	push @column_index, "fx_$item";
      }
	
      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href .= "&l_$item=Y";
    }
  }

    

  if ($form->{l_subtotal} eq 'Y') {
    $callback .= "&l_subtotal=Y";
    $href .= "&l_subtotal=Y";
  }
  

  $column_header{id} = "<th><a class=listheading href=$href&sort=id}>".$locale->text('ID')."</a></th>";
  $column_header{transdate} = "<th><a class=listheading href=$href&sort=transdate>".$locale->text('Date')."</a></th>";
  $column_header{duedate} = "<th><a class=listheading href=$href&sort=duedate>".$locale->text('Due Date')."</a></th>";
  $column_header{invnumber} = "<th><a class=listheading href=$href&sort=invnumber>".$locale->text('Invoice')."</a></th>";
  $column_header{ordnumber} = "<th><a class=listheading href=$href&sort=ordnumber>".$locale->text('Order')."</a></th>";
  $column_header{name} = "<th><a class=listheading href=$href&sort=name>".$locale->text('Customer')."</a></th>";
  $column_header{netamount} = "<th class=listheading>" . $locale->text('Amount') . "</th>";
  $column_header{tax} = "<th class=listheading>" . $locale->text('Tax') . "</th>";
  $column_header{amount} = "<th class=listheading>" . $locale->text('Total') . "</th>";
  $column_header{paid} = "<th class=listheading>" . $locale->text('Paid') . "</th>";
  $column_header{datepaid} = "<th><a class=listheading href=$href&sort=datepaid>" . $locale->text('Date Paid') . "</a></th>";
  $column_header{due} = "<th class=listheading>" . $locale->text('Amount Due') . "</th>";
  $column_header{notes} = "<th class=listheading>".$locale->text('Notes')."</th>";
  $column_header{employee} = "<th><a class=listheading href=$href&sort=employee>".$locale->text('Salesperson')."</th>";
  $column_header{manager} = "<th><a class=listheading href=$href&sort=manager>".$locale->text('Manager')."</th>";
  $column_header{till} = "<th class=listheading><a class=listheading href=$href&sort=till>".$locale->text('Till')."</th>";
  
  $column_header{shippingpoint} = "<th><a class=listheading href=$href&sort=shippingpoint>" . $locale->text('Shipping Point') . "</a></th>";
  $column_header{shipvia} = "<th><a class=listheading href=$href&sort=shipvia>" . $locale->text('Ship via') . "</a></th>";

  $column_header{curr} = "<th><a class=listheading href=$href&sort=curr>" . $locale->text('Curr') . "</a></th>";
  map { $column_header{"fx_$_"} = "<th>&nbsp;</th>" } qw(amount tax netamount paid due);

  $form->{title} = ($form->{title}) ? $form->{title} : $locale->text('AR Transactions');

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


  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $callback .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($callback);
  
  # flip direction
  $direction = ($form->{direction} eq 'ASC') ? "ASC" : "DESC";
  $href =~ s/&direction=(\w+)&/&direction=$direction&/;
  
  if (@{ $form->{transactions} }) {
    $sameitem = $form->{transactions}->[0]->{$form->{sort}};
  }
  
  # sums and tax on reports by Antonio Gallardo
  #
  foreach $ar (@{ $form->{transactions} }) {

    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ar->{$form->{sort}}) {
	&ar_subtotal;
      }
    }

    if ($form->{l_curr}) {
      map { $ar->{"fx_$_"} = $ar->{$_}/$ar->{exchangerate} } qw(netamount amount paid);

      map { $column_data{"fx_$_"} = "<td align=right>".$form->format_amount(\%myconfig, $ar->{"fx_$_"}, 2, "&nbsp;")."</td>" } qw(netamount amount paid);
      
      $column_data{fx_tax} = "<td align=right>".$form->format_amount(\%myconfig, $ar->{fx_amount} - $ar->{fx_netamount}, 2, "&nbsp;")."</td>";
      $column_data{fx_due} = "<td align=right>".$form->format_amount(\%myconfig, $ar->{fx_amount} - $ar->{fx_paid}, 2, "&nbsp;")."</td>";

      $subtotalfxnetamount += $ar->{fx_netamount};
      $subtotalfxamount += $ar->{fx_amount};
      $subtotalfxpaid += $ar->{fx_paid};
      
      $totalfxnetamount += $ar->{fx_netamount};
      $totalfxamount += $ar->{fx_amount};
      $totalfxpaid += $ar->{fx_paid};
      
    }
    
    map { $column_data{$_} = "<td align=right>".$form->format_amount(\%myconfig, $ar->{$_}, 2, "&nbsp;")."</td>" } qw(netamount amount paid);
    
    $column_data{tax} = "<td align=right>".$form->format_amount(\%myconfig, $ar->{amount} - $ar->{netamount}, 2, "&nbsp;")."</td>";
    $column_data{due} = "<td align=right>".$form->format_amount(\%myconfig, $ar->{amount} - $ar->{paid}, 2, "&nbsp;")."</td>";
    
    
    $subtotalnetamount += $ar->{netamount};
    $subtotalamount += $ar->{amount};
    $subtotalpaid += $ar->{paid};
    
    $totalnetamount += $ar->{netamount};
    $totalamount += $ar->{amount};
    $totalpaid += $ar->{paid};
    
    $column_data{transdate} = "<td>$ar->{transdate}&nbsp;</td>";
    $column_data{id} = "<td>$ar->{id}</td>";
    $column_data{datepaid} = "<td>$ar->{datepaid}&nbsp;</td>";
    $column_data{duedate} = "<td>$ar->{duedate}&nbsp;</td>";

    $module = ($ar->{invoice}) ? "is.pl" : $form->{script};
    $module = ($ar->{till}) ? "ps.pl" : $module;

    $column_data{invnumber} = "<td><a href=$module?action=edit&id=$ar->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ar->{invnumber}</a></td>";
    $column_data{ordnumber} = "<td>$ar->{ordnumber}&nbsp;</td>";
    

    $name = $form->escape($ar->{name});
    $column_data{name} = "<td><a href=$href&customer=$name--$ar->{customer_id}&sort=$form->{sort}>$ar->{name}</a></td>";
    
    $ar->{notes} =~ s/\r\n/<br>/g;
    $column_data{notes} = "<td>$ar->{notes}&nbsp;</td>";
    $column_data{shippingpoint} = "<td>$ar->{shippingpoint}&nbsp;</td>";
    $column_data{shipvia} = "<td>$ar->{shipvia}&nbsp;</td>";
    $column_data{employee} = "<td>$ar->{employee}&nbsp;</td>";
    $column_data{manager} = "<td>$ar->{manager}&nbsp;</td>";
    $column_data{till} = "<td>$ar->{till}&nbsp;</td>";
    $column_data{curr} = "<td>$ar->{curr}</td>";
    
    $i++; $i %= 2;
    print "
        <tr class=listrow$i>
";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>
|;

  
  }

  if ($form->{l_subtotal} eq 'Y') {
    &ar_subtotal;
  }

  # print totals
  print qq|
        <tr class=listtotal>
|;

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
  
  $column_data{netamount} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalnetamount, 2, "&nbsp;")."</th>";
  $column_data{tax} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalamount - $totalnetamount, 2, "&nbsp;")."</th>";
  $column_data{amount} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalamount, 2, "&nbsp;")."</th>";
  $column_data{paid} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalpaid, 2, "&nbsp;")."</th>";
  $column_data{due} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalamount - $totalpaid, 2, "&nbsp;")."</th>";

  if ($form->{l_curr} && $form->{sort} eq 'curr' && $form->{l_subtotal}) {
    $column_data{fx_netamount} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalfxnetamount, 2, "&nbsp;")."</th>";
    $column_data{fx_tax} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalfxamount - $totalfxnetamount, 2, "&nbsp;")."</th>";
    $column_data{fx_amount} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalfxamount, 2, "&nbsp;")."</th>";
    $column_data{fx_paid} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalfxpaid, 2, "&nbsp;")."</th>";
    $column_data{fx_due} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalfxamount - $totalfxpaid, 2, "&nbsp;")."</th>";
  }

  map { print "\n$column_data{$_}" } @column_index;

  if ($myconfig{acs} !~ /AR--AR/) {
    $i = 1;
    $button{'AR--Add Transaction'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('AR Transaction').qq|"> |;
    $button{'AR--Add Transaction'}{order} = $i++;
    $button{'AR--Sales Invoice'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Sales Invoice.').qq|"> |;
    $button{'AR--Sales Invoice'}{order} = $i++;

    foreach $item (split /;/, $myconfig{acs}) {
      delete $button{$item};
    }
  }

  print qq|
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=customer value="$form->{customer}">
<input type=hidden name=customer_id value=$form->{customer_id}>
<input type=hidden name=vc value=customer>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>
|;

  if (! $form->{till}) {
    foreach $item (sort { $a->{order} <=> $b->{order} } %button) {
      print $item->{code};
    }
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|
</form>

</body>
</html>
|;

}


sub ar_subtotal {

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
  
  $column_data{tax} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalamount - $subtotalnetamount, 2, "&nbsp;")."</th>";
  $column_data{amount} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalamount, 2, "&nbsp;")."</th>";
  $column_data{paid} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalpaid, 2, "&nbsp;")."</th>";
  $column_data{due} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalamount - $subtotalpaid, 2, "&nbsp;")."</th>";

  if ($form->{l_curr} && $form->{sort} eq 'curr' && $form->{l_subtotal}) {
    $column_data{fx_tax} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalfxamount - $subtotalfxnetamount, 2, "&nbsp;")."</th>";
    $column_data{fx_amount} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalfxamount, 2, "&nbsp;")."</th>";
    $column_data{fx_paid} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalfxpaid, 2, "&nbsp;")."</th>";
    $column_data{fx_due} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalfxmount - $subtotalfxpaid, 2, "&nbsp;")."</th>";
  }
  
  $subtotalnetamount = 0;
  $subtotalamount = 0;
  $subtotalpaid = 0;
  
  $subtotalfxnetamount = 0;
  $subtotalfxamount = 0;
  $subtotalfxpaid = 0;

  $sameitem = $ar->{$form->{sort}};
  
  print "<tr class=listsubtotal>";

  map { print "\n$column_data{$_}" } @column_index;

print "
</tr>
";
 
}



