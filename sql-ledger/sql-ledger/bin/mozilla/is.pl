#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
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
# Inventory invoicing module
#
#======================================================================


use SL::IS;
use SL::PE;

require "$form->{path}/arap.pl";
require "$form->{path}/io.pl";


1;
# end of main



sub add {

  $form->{title} = $locale->text('Add Sales Invoice');

  $form->{callback} = "$form->{script}?action=add&type=$form->{type}&login=$form->{login}&path=$form->{path}&sessionid=$form->{sessionid}" unless $form->{callback};

  &invoice_links;
  &prepare_invoice;
  &display_form;
  
}


sub edit {

  $form->{title} = $locale->text('Edit Sales Invoice');

  &invoice_links;
  &prepare_invoice;
  &display_form;
  
}


sub invoice_links {

  $form->{vc} = 'customer';

  # create links
  $form->create_links("AR", \%myconfig, "customer");
  
  # currencies
  @curr = split /:/, $form->{currencies};
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];

  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  if ($form->{all_customer}) {
    unless ($form->{customer_id}) {
      $form->{customer_id} = $form->{all_customer}->[0]->{id};
    }
  }

  IS->get_customer(\%myconfig, \%$form);
  delete $form->{notes};
  IS->retrieve_invoice(\%myconfig, \%$form);

  $form->{oldlanguage_code} = $form->{language_code};
  
  $form->get_partsgroup(\%myconfig, { language_code => $form->{language_code} });
  if (@{ $form->{all_partsgroup} }) {
    $form->{selectpartsgroup} = "<option>\n";
    foreach $ref (@ { $form->{all_partsgroup} }) {
      if ($ref->{translation}) {
	$form->{selectpartsgroup} .= qq|<option value="$ref->{partsgroup}--$ref->{id}">$ref->{translation}\n|;
      } else {
	$form->{selectpartsgroup} .= qq|<option value="$ref->{partsgroup}--$ref->{id}">$ref->{partsgroup}\n|;
      }
    }
  }
  
  if (@{ $form->{all_projects} }) {
    $form->{selectprojectnumber} = "<option>\n";
    map { $form->{selectprojectnumber} .= qq|<option value="$_->{projectnumber}--$_->{id}">$_->{projectnumber}\n| } @{ $form->{all_projects} };
  }

  $form->{oldcustomer} = "$form->{customer}--$form->{customer_id}";
  $form->{oldtransdate} = $form->{transdate};
  
  if ($form->{all_customer}) {
    $form->{customer} = "$form->{customer}--$form->{customer_id}";
    map { $form->{selectcustomer} .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } (@{ $form->{all_customer} });
  }

  # departments
  if ($form->{all_departments}) {
    $form->{selectdepartment} = "<option>\n";
    $form->{department} = "$form->{department}--$form->{department_id}";

    map { $form->{selectdepartment} .= qq|<option value="$_->{description}--$_->{id}">$_->{description}\n| } (@{ $form->{all_departments} });
  }
  
  $form->{employee} = "$form->{employee}--$form->{employee_id}";
  # sales staff
  if ($form->{all_employees}) {
    $form->{selectemployee} = "";
    map { $form->{selectemployee} .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } (@{ $form->{all_employees} });
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
      $form->{"select$key"} .= "<option>$ref->{accno}--$ref->{description}\n";
    }

    if ($key eq "AR_paid") {
      for $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {
	$form->{"AR_paid_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
	# reverse paid
	$form->{"paid_$i"} = $form->{acc_trans}{$key}->[$i-1]->{amount} * -1;
	$form->{"datepaid_$i"} = $form->{acc_trans}{$key}->[$i-1]->{transdate};
	$form->{"forex_$i"} = $form->{"exchangerate_$i"} = $form->{acc_trans}{$key}->[$i-1]->{exchangerate};
	$form->{"source_$i"} = $form->{acc_trans}{$key}->[$i-1]->{source};
	$form->{"memo_$i"} = $form->{acc_trans}{$key}->[$i-1]->{memo};
	
	$form->{paidaccounts} = $i;
      }
    } else {
      $form->{$key} = "$form->{acc_trans}{$key}->[0]->{accno}--$form->{acc_trans}{$key}->[0]->{description}";
    }
    
  }

  $form->{paidaccounts} = 1 unless (exists $form->{paidaccounts});

  $form->{AR} = $form->{AR_1} unless $form->{id};
  
  $form->{locked} = ($form->{revtrans}) ? '1' : ($form->datetonum($form->{transdate}, \%myconfig) <= $form->datetonum($form->{closedto}, \%myconfig));

  $form->{readonly} = 1 if $myconfig{acs} =~ /AR--Sales Invoice/;

}


sub prepare_invoice {

  $form->{type} = "invoice";
  $form->{formname} = "invoice";
  $form->{format} = "postscript" if $myconfig{printer};
  $form->{media} = $myconfig{printer};
  
  $form->{oldcurrency} = $form->{currency};
  
  if ($form->{id}) {
    
    map { $form->{$_} = $form->quote($form->{$_}) } qw(invnumber ordnumber quonumber shippingpoint shipvia notes intnotes);

    foreach $ref (@{ $form->{invoice_details} } ) {
      $i++;
      map { $form->{"${_}_$i"} = $ref->{$_} } keys %{ $ref };

      $form->{"projectnumber_$i"} = qq|$ref->{projectnumber}--$ref->{project_id}|;
      $form->{"partsgroup_$i"} = qq|$ref->{partsgroup}--$ref->{partsgroup_id}|;

      $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100);

      ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec = length $dec;
      $decimalplaces = ($dec > 2) ? $dec : 2;

      $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
      $form->{"qty_$i"} = $form->format_amount(\%myconfig, $form->{"qty_$i"});
      $form->{"oldqty_$i"} = $form->{"qty_$i"};
      
      map { $form->{"${_}_$i"} = $form->quote($form->{"${_}_$i"}) } qw(partnumber sku description unit);
      $form->{rowcount} = $i;
    }
  }
  
}



sub form_header {

  # set option selected
  foreach $item (qw(AR currency)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }
  
  foreach $item (qw(customer department employee)) {
    $form->{"select$item"} = $form->unescape($form->{"select$item"});
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/(<option value="\Q$form->{$item}\E")/$1 selected/;
  }
    
  $form->{exchangerate} = $form->format_amount(\%myconfig, $form->{exchangerate});

 
  $exchangerate = "";
  if ($form->{currency} ne $form->{defaultcurrency}) {
    if ($form->{forex}) {
      $exchangerate .= qq|<th align=right>|.$locale->text('Exchange Rate').qq|</th><td>$form->{exchangerate}<input type=hidden name=exchangerate value=$form->{exchangerate}></td>|;
    } else {
      $exchangerate .= qq|<th align=right>|.$locale->text('Exchange Rate').qq|</th><td><input name=exchangerate size=10 value=$form->{exchangerate}></td>|;
    }
  }
  $exchangerate .= qq|
<input type=hidden name=forex value=$form->{forex}>
|;

  if ($form->{selectcustomer}) {
    $customer = qq|<select name=customer>$form->{selectcustomer}</select>
                   <input type=hidden name="selectcustomer" value="|.
		   $form->escape($form->{selectcustomer},1).qq|">|;
  } else {
    $customer = qq|<input name=customer value="$form->{customer}" size=35>|;
  }
  
  $department = qq|
              <tr>
	        <th align="right" nowrap>|.$locale->text('Department').qq|</th>
		<td colspan=3><select name=department>$form->{selectdepartment}</select>
		<input type=hidden name=selectdepartment value="|.
		$form->escape($form->{selectdepartment},1).qq|">
		</td>
	      </tr>
| if $form->{selectdepartment};


  $n = ($form->{creditremaining} < 0) ? "0" : "1";


  if ($form->{business}) {
    $business = qq|
	      <tr>
		<th align=right>|.$locale->text('Business').qq|</th>
		<td>$form->{business}</td>
		<th align=right>|.$locale->text('Trade Discount').qq|</th>
		<td>|.$form->format_amount(\%myconfig, $form->{tradediscount} * 100).qq| %</td>
	      </tr>
|;
  }


  $form->header;

  print qq|
<body>

<form method=post action="$form->{script}#end">

<input type=hidden name=id value=$form->{id}>

<input type=hidden name=type value=$form->{type}>
<input type=hidden name=media value=$form->{media}>
<input type=hidden name=format value=$form->{format}>

<input type=hidden name=queued value="$form->{queued}">
<input type=hidden name=printed value="$form->{printed}">
<input type=hidden name=emailed value="$form->{emailed}">

<input type=hidden name=title value="$form->{title}">
<input type=hidden name=vc value=$form->{vc}>

<input type=hidden name=terms value=$form->{terms}>

<input type=hidden name=discount value=$form->{discount}>
<input type=hidden name=creditlimit value=$form->{creditlimit}>
<input type=hidden name=creditremaining value=$form->{creditremaining}>

<input type=hidden name=tradediscount value=$form->{tradediscount}>
<input type=hidden name=business value="$form->{business}">

<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>

<input type=hidden name=shipped value=$form->{shipped}>

<input type=hidden name=oldtransdate value=$form->{oldtransdate}>


<table width=100%>
  <tr class=listtop>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
	<tr valign=top>
	  <td>
	    <table>
	      <tr>
		<th align=right nowrap>|.$locale->text('Customer').qq|</th>
		<td colspan=3>$customer</td>
		<input type=hidden name=customer_id value=$form->{customer_id}>
		<input type=hidden name=oldcustomer value="$form->{oldcustomer}"> 
	      </tr>
	      <tr>
		<td></td>
		<td colspan=3>
		  <table>
		    <tr>
		      <th nowrap>|.$locale->text('Credit Limit').qq|</th>
		      <td>|.$form->format_amount(\%myconfig, $form->{creditlimit}, 0, "0").qq|</td>
		      <td width=20%></td>
		      <th nowrap>|.$locale->text('Remaining').qq|</th>
		      <td class="plus$n" nowrap>|.$form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0").qq|</td>
		    </tr>
		  </table>
		</td>
	      </tr>
	      $business
	      <tr>
		<th align=right nowrap>|.$locale->text('Record in').qq|</th>
		<td colspan=3><select name=AR>$form->{selectAR}</select></td>
		<input type=hidden name=selectAR value="$form->{selectAR}">
	      </tr>
	      $department
	      <tr>
		<th align=right nowrap>|.$locale->text('Currency').qq|</th>
		<td><select name=currency>$form->{selectcurrency}</select></td>
		<input type=hidden name=selectcurrency value="$form->{selectcurrency}">
		<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
		<input type=hidden name=fxgain_accno value=$form->{fxgain_accno}>
		<input type=hidden name=fxloss_accno value=$form->{fxloss_accno}>
		$exchangerate
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Shipping Point').qq|</th>
		<td colspan=3><input name=shippingpoint size=35 value="$form->{shippingpoint}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Ship via').qq|</th>
		<td colspan=3><input name=shipvia size=35 value="$form->{shipvia}"></td>
	      </tr>
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      <tr>
	        <th align=right nowrap>|.$locale->text('Salesperson').qq|</th>
		<td><select name=employee>$form->{selectemployee}</select></td>
		<input type=hidden name=selectemployee value="|.
		$form->escape($form->{selectemployee},1).qq|">
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Invoice Number').qq|</th>
		<td><input name=invnumber size=20 value="$form->{invnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Order Number').qq|</th>
		<td><input name=ordnumber size=20 value="$form->{ordnumber}"></td>
<input type=hidden name=quonumber value="$form->{quonumber}">
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Invoice Date').qq|</th>
		<td><input name=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate}></td>
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Due Date').qq|</th>
		<td><input name=duedate size=11 title="$myconfig{dateformat}" value=$form->{duedate}></td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
    </td>
  </tr>
<!-- shipto are in hidden variables -->

<input type=hidden name=shiptoname value="$form->{shiptoname}">
<input type=hidden name=shiptoaddress1 value="$form->{shiptoaddress1}">
<input type=hidden name=shiptoaddress2 value="$form->{shiptoaddress2}">
<input type=hidden name=shiptocity value="$form->{shiptocity}">
<input type=hidden name=shiptostate value="$form->{shiptostate}">
<input type=hidden name=shiptozipcode value="$form->{shiptozipcode}">
<input type=hidden name=shiptocountry value="$form->{shiptocountry}">
<input type=hidden name=shiptocontact value="$form->{shiptocontact}">
<input type=hidden name=shiptophone value="$form->{shiptophone}">
<input type=hidden name=shiptofax value="$form->{shiptofax}">
<input type=hidden name=shiptoemail value="$form->{shiptoemail}">

<!-- email variables -->
<input type=hidden name=message value="$form->{message}">
<input type=hidden name=email value="$form->{email}">
<input type=hidden name=subject value="$form->{subject}">
<input type=hidden name=cc value="$form->{cc}">
<input type=hidden name=bcc value="$form->{bcc}">

<input type=hidden name=taxaccounts value="$form->{taxaccounts}">
|;

  foreach $item (split / /, $form->{taxaccounts}) {
    print qq|
<input type=hidden name="${item}_rate" value="$form->{"${item}_rate"}">
<input type=hidden name="${item}_description" value="$form->{"${item}_description"}">
<input type=hidden name="${item}_taxnumber" value="$form->{"${item}_taxnumber"}">
|;
  }

}



sub form_footer {

  $form->{invtotal} = $form->{invsubtotal};

  if (($rows = $form->numtextrows($form->{notes}, 26, 8)) < 2) {
    $rows = 2;
  }
  if (($introws = $form->numtextrows($form->{intnotes}, 35, 8)) < 2) {
    $introws = 2;
  }
  $rows = ($rows > $introws) ? $rows : $introws;
  $notes = qq|<textarea name=notes rows=$rows cols=26 wrap=soft>$form->{notes}</textarea>|;
  $intnotes = qq|<textarea name=intnotes rows=$rows cols=35 wrap=soft>$form->{intnotes}</textarea>|;

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";

  $taxincluded = "";
  if ($form->{taxaccounts}) {
    $taxincluded = qq|
              <tr height="5"></tr>
              <tr>
	        <td align=right>
	        <input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}></td><th align=left>|.$locale->text('Tax Included').qq|</th>
	     </tr>
|;
  }

  if (!$form->{taxincluded}) {
    
    foreach $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
	$form->{"${item}_total"} = $form->round_amount($form->{"${item}_base"} * $form->{"${item}_rate"}, 2);
	$form->{invtotal} += $form->{"${item}_total"};
	$form->{"${item}_total"} = $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);
	
	$tax .= qq|
	      <tr>
		<th align=right>$form->{"${item}_description"}</th>
		<td align=right>$form->{"${item}_total"}</td>
	      </tr>
|;
      }
    }

    $form->{invsubtotal} = $form->format_amount(\%myconfig, $form->{invsubtotal}, 2, 0);
    
    $subtotal = qq|
	      <tr>
		<th align=right>|.$locale->text('Subtotal').qq|</th>
		<td align=right>$form->{invsubtotal}</td>
	      </tr>
|;

  }

  $form->{oldinvtotal} = $form->{invtotal};
  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2, 0);
  
  print qq|
  <tr>
    <td>
      <table width=100%>
	<tr valign=bottom>
	  <td>
	    <table>
	      <tr>
		<th align=left>|.$locale->text('Notes').qq|</th>
		<th align=left>|.$locale->text('Internal Notes').qq|</th>
	      </tr>
	      <tr valign=top>
		<td>$notes</td>
		<td>$intnotes</td>
	      </tr>
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      $subtotal
	      $tax
	      <tr>
		<th align=right>|.$locale->text('Total').qq|</th>
		<td align=right>$form->{invtotal}</td>
	      </tr>
	      $taxincluded
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
	  <th colspan=6 class=listheading>|.$locale->text('Payments')
	  .qq|</th>
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
        <tr>\n";

    $form->{"selectAR_paid_$i"} = $form->{selectAR_paid};
    $form->{"selectAR_paid_$i"} =~ s/option>\Q$form->{"AR_paid_$i"}\E/option selected>$form->{"AR_paid_$i"}/;
    
    # format amounts
    $totalpaid += $form->{"paid_$i"};
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

    $column_data{"paid_$i"} = qq|<td align=center><input name="paid_$i" size=11 value=$form->{"paid_$i"}></td>|;
    $column_data{"exchangerate_$i"} = qq|<td align=center>$exchangerate</td>|;
    $column_data{"AR_paid_$i"} = qq|<td align=center><select name="AR_paid_$i">$form->{"selectAR_paid_$i"}</select></td>|;
    $column_data{"datepaid_$i"} = qq|<td align=center><input name="datepaid_$i" size=11 title="$myconfig{dateformat}" value=$form->{"datepaid_$i"}></td>|;
    $column_data{"source_$i"} = qq|<td align=center><input name="source_$i" size=11 value="$form->{"source_$i"}"></td>|;
    $column_data{"memo_$i"} = qq|<td align=center><input name="memo_$i" size=11 value="$form->{"memo_$i"}"></td>|;

    map { print qq|$column_data{"${_}_$i"}\n| } @column_index;
    print "
        </tr>\n";
  }

  print qq|
<input type=hidden name=paidaccounts value=$form->{paidaccounts}>
<input type=hidden name=selectAR_paid value="$form->{selectAR_paid}">
<input type=hidden name=oldinvtotal value=$form->{oldinvtotal}>
<input type=hidden name=oldtotalpaid value=$totalpaid>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
  <tr>
    <td>
|;

  &print_options;

  print qq|
    </td>
  </tr>
</table>
<br>
|;


  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);

  if (! $form->{readonly}) {
    
    if ($form->{id}) {
      
      print qq|
      <input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('Ship to').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('Print').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('E-mail').qq|">
|;

        if (! $form->{locked}) {
	  print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Post').qq|">|;

	  if ($latex) {
	    print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Print and Post').qq|">|;
	  }

	  print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">
|;
	}

	print qq|
      <input class=submit type=submit name=action value="|.$locale->text('Post as new').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('Sales Order').qq|">
|;

    } else {

      if ($transdate > $closedto) {
	print qq|
        <input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Ship to').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Print').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('E-mail').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Post').qq|">|;

	if ($latex) {
	  print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Print and Post').qq|">|;
	}
      }
    }
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|

<input type=hidden name=rowcount value=$form->{rowcount}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

</form>

<a name="end"></a>

</body>
</html>
|;

}


sub update {

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate);
  
  &check_name(customer);

  if ($form->{transdate} ne $form->{oldtransdate}) {
    $form->{duedate} = $form->current_date(\%myconfig, $form->{transdate}, $form->{terms} * 1);
    $form->{oldtransdate} = $form->{transdate};
  }


  $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, 'buy')));

  $j = 1;
  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      map { $form->{"${_}_$j"} = $form->{"${_}_$i"} } qw(datepaid source memo);
      map { $form->{"${_}_$j"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);

      $form->{"exchangerate_$j"} = $exchangerate if ($form->{"forex_$j"} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{"datepaid_$j"}, 'buy')));
      map { delete $form->{"${_}_$i"} } qw(datepaid source memo paid exchangerate forex) if $j != $i;
      $j++;
    } else {
      map { delete $form->{"${_}_$i"} } qw(datepaid source memo paid exchangerate forex);
    }
    $form->{paidaccounts} = $j;
  }

  $i = $form->{rowcount};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  foreach $item (qw(partsgroup projectnumber)) {
    $form->{"select$item"} = $form->unescape($form->{"select$item"}) if $form->{"select$item"};
  }
    
  # if last row empty, check the form otherwise retrieve new item
  if (($form->{"partnumber_$i"} eq "") && ($form->{"description_$i"} eq "") && ($form->{"partsgroup_$i"} eq "")) {

    $form->{creditremaining} += ($form->{oldinvtotal} - $form->{oldtotalpaid});
    &check_form;

  } else {

    IS->retrieve_item(\%myconfig, \%$form);
    
    $rows = scalar @{ $form->{item_list} };

    $form->{"discount_$i"}	= $form->format_amount(\%myconfig, $form->{discount} * 100);

    if ($rows > 0) {
      $form->{"qty_$i"}		= ($form->{"qty_$i"} * 1) ? $form->{"qty_$i"} : 1;
      
      if ($rows > 1) {
	
	&select_item;
	exit;
	
      } else {

        $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});
	
	map { $form->{item_list}[$i]{$_} = $form->quote($form->{item_list}[$i]{$_}) } qw(partnumber description unit);
	map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} } keys %{ $form->{item_list}[0] };
	
	$form->{"discount_$i"} = $form->{discount} * 100;
	
	$s = ($sellprice) ? $sellprice : $form->{"sellprice_$i"};
	($dec) = ($s =~ /\.(\d+)/);
	$dec = length $dec;
	$decimalplaces = ($dec > 2) ? $dec : 2;

	if ($sellprice) {
	  $form->{"sellprice_$i"} = $sellprice;
	} else {
	  # if there is an exchange rate adjust sellprice
	  $form->{"sellprice_$i"} *= (1 - $form->{tradediscount});
	  $form->{"sellprice_$i"} /= $exchangerate;
	}
	
	map { $form->{"${_}_$i"} /= $exchangerate } qw(listprice lastcost);

        $amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * (1 - $form->{"discount_$i"} / 100);
	map { $form->{"${_}_base"} = 0 } (split / /, $form->{taxaccounts});
        map { $form->{"${_}_base"} += $amount } (split / /, $form->{"taxaccounts_$i"});
	map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{"taxaccounts_$i"} if !$form->{taxincluded};
	
        $form->{creditremaining} -= $amount;
	
	map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, $decimalplaces) } qw(sellprice listprice lastcost);
	
	$form->{"qty_$i"} =  $form->format_amount(\%myconfig, $form->{"qty_$i"});
      }

      &display_form;

    } else {
      # ok, so this is a new part
      # ask if it is a part or service item

      if ($form->{"partsgroup_$i"} && ($form->{"partsnumber_$i"} eq "") && ($form->{"description_$i"} eq "")) {
	$form->{rowcount}--;
	$form->{"discount_$i"} = "";
	&display_form;
      } else {
	
	$form->{"id_$i"}          = 0;
	$form->{"unit_$i"}        = $locale->text('ea');

	&new_item;
	
      }
    }
  }
}



sub post {

  $form->isblank("transdate", $locale->text('Invoice Date missing!'));
  $form->isblank("customer", $locale->text('Customer missing!'));

  # if oldcustomer ne customer redo form
  if (&check_name(customer)) {
    &update;
    exit;
  }

  &validate_items;

  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  
  $form->error($locale->text('Cannot post invoice for a closed period!')) if ($transdate <= $closedto);

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

  
  ($form->{AR}) = split /--/, $form->{AR};
  ($form->{AR_paid}) = split /--/, $form->{AR_paid};
  
  $form->{label} = $locale->text('Invoice');

  $form->{id} = 0 if $form->{postasnew};
  
  $form->{invnumber} = $form->update_defaults(\%myconfig, "sinumber") unless $form->{invnumber};

  $form->redirect($locale->text('Invoice posted!')) if (IS->post_invoice(\%myconfig, \%$form));
  $form->error($locale->text('Cannot post invoice!'));
    
}


sub print_and_post {

  $form->error($locale->text('Select postscript or PDF!')) if $form->{format} !~ /(postscript|pdf)/;
  $form->error($locale->text('Select Printer or Queue!')) if $form->{media} eq 'screen';

  $old_form = new Form;
  $form->{display_form} = "post";
  map { $old_form->{$_} = $form->{$_} } keys %$form;
  $old_form->{rowcount}++;

  &print_form($old_form);

}



sub delete {

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  # delete action variable
  map { delete $form->{$_} } qw(action header);

  $form->hide_form();

  print qq|
<h2 class=confirm>|.$locale->text('Confirm!').qq|</h2>

<h4>|.$locale->text('Are you sure you want to delete Invoice Number').qq| $form->{invnumber}
</h4>

<p>
<input name=action class=submit type=submit value="|.$locale->text('Yes').qq|">
</form>
|;


}



sub yes {

  $form->redirect($locale->text('Invoice deleted!')) if (IS->delete_invoice(\%myconfig, \%$form, $spool));
  $form->error($locale->text('Cannot delete invoice!'));

}


sub redirect {

  $form->redirect;
  $form->error($locale->text('Invoice processed!'));

}

