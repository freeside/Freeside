#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2003
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
# Contributors: Steve Doerr <sdoerr907@everestkc.net>
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
#=====================================================================
#
# POS
#
#=====================================================================


1;
# end


sub add {

  $form->{title} = $locale->text('Add POS Invoice');

  $form->{callback} = "$form->{script}?action=$form->{nextsub}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};
  
  &invoice_links;

  $form->{type} =  "pos_invoice";
  $form->{format} = "txt";
  $form->{media} = ($myconfig{printer}) ? $myconfig{printer} : "screen";
  $form->{rowcount} = 0;

  $form->{readonly} = ($myconfig{acs} =~ /POS--Sale/) ? 1 : 0;

  $ENV{REMOTE_ADDR} =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
  $form->{till} = $4;

  map { $form->{partsgroup} .= "$_->{partsgroup}--$_->{translation}\n" } @{ $form->{all_partsgroup} };

  &display_form;

}


sub openinvoices {

  $ENV{REMOTE_ADDR} =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
  $form->{till} = $4;
  
  $form->{sort} = 'transdate';

  map { $form->{$_} = 'Y' } qw(open l_invnumber l_transdate l_name l_amount l_curr l_till l_subtotal);

  if ($myconfig{role} ne 'user') {
    $form->{l_employee} = 'Y';
  }

  $form->{title} = $locale->text('Open');
  &ar_transactions;
  
}


sub edit {

  $form->{title} = $locale->text('Edit POS Invoice');

  $form->{callback} = "$form->{script}?action=$form->{nextsub}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};
  
  &invoice_links;
  &prepare_invoice;

  $form->{type} =  "pos_invoice";
  $form->{format} = "txt";
  $form->{media} = ($myconfig{printer}) ? $myconfig{printer} : "screen";

  $form->{readonly} = ($myconfig{acs} =~ /POS--Sale/) ? 1 : 0;

  map { $form->{partsgroup} .= "$_->{partsgroup}--$_->{translation}\n" } @{ $form->{all_partsgroup} };
  
  &display_form;

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

  if ($form->{oldtotalpaid} > $form->{oldinvtotal}) {
    $adj = $form->{oldtotalpaid} - $form->{oldinvtotal};
  }
  $form->{creditremaining} = $form->{creditremaining} - $adj + $form->{oldchange};
  
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

  if ($form->{selectlanguage}) {
    if ($form->{language_code} ne $form->{oldlanguage_code}) {
      # rebuild partsgroup
      $form->get_partsgroup(\%myconfig, { language_code => $form->{language_code} });
      $form->{partsgroup} = "";
      map { $form->{partsgroup} .= "$_->{partsgroup}--$_->{translation}\n" } @{ $form->{all_partsgroup} };
      $form->{oldlanguage_code} = $form->{language_code};
    }

      
    $form->{"selectlanguage"} = $form->unescape($form->{"selectlanguage"});
    $form->{"selectlanguage"} =~ s/ selected//;
    $form->{"selectlanguage"} =~ s/(<option value="\Q$form->{language_code}\E")/$1 selected/; 
    $lang = qq|
	      <tr>
                <th align=right>|.$locale->text('Language').qq|</th>
		<td colspan=3><select name=language_code>$form->{selectlanguage}</select></td>
	      </tr>
    <input type=hidden name=oldlanguage_code value=$form->{oldlanguage_code}>
    <input type=hidden name=selectlanguage value="|.
    $form->escape($form->{selectlanguage},1).qq|">|;
  }
 

  $form->header;

 
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>

<input type=hidden name=till value=$form->{till}>

<input type=hidden name=type value=$form->{type}>
<input type=hidden name=media value=$form->{media}>
<input type=hidden name=format value=$form->{format}>

<input type=hidden name=printed value="$form->{printed}">

<input type=hidden name=title value="$form->{title}">
<input type=hidden name=vc value="customer">

<input type=hidden name=discount value=$form->{discount}>
<input type=hidden name=creditlimit value=$form->{creditlimit}>
<input type=hidden name=creditremaining value=$form->{creditremaining}>

<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>


<table width=100%>
  <tr class=listtop>
    <th class=listtop>$form->{title}</font></th>
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
		<td>$customer</td>
		<input type=hidden name=customer_id value=$form->{customer_id}>
		<input type=hidden name=oldcustomer value="$form->{oldcustomer}"> 
	      </tr>
	      <tr>
	        <td></td>
		<td colspan=3>
		  <table>
		    <tr>
		      <th nowrap>|.$locale->text('Credit Limit').qq|</th>
		      <td>$form->{creditlimit}</td>
		      <th nowrap>|.$locale->text('Remaining').qq|</th>
		      <td class="plus$n">|.$form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0").qq|</font></td>
		    </tr>
		  </table>
		</td>
	      </tr>
	      $discount
	      <tr>
		<th align=right nowrap>|.$locale->text('Record in').qq|</th>
		<td><select name=AR>$form->{selectAR}</select></td>
		<input type=hidden name=selectAR value="$form->{selectAR}">
	      </tr>
	      $department
	    </table>
	  </td>
	  <td>
	    <table>
	      <tr>
	        <th align=right nowrap>|.$locale->text('Salesperson').qq|</th>
		<td colspan=3><select name=employee>$form->{selectemployee}</select></td>
		<input type=hidden name=selectemployee value="|.
		$form->escape($form->{selectemployee},1).qq|">
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Currency').qq|</th>
		<td><select name=currency>$form->{selectcurrency}</select></td>
		<input type=hidden name=selectcurrency value="$form->{selectcurrency}">
		<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
		<input type=hidden name=fxgain_accno value=$form->{fxgain_accno}>
		<input type=hidden name=fxloss_accno value=$form->{fxloss_accno}>
		$exchangerate
	      </tr>
	      $lang
	    </table>
	  </td>
	<input type=hidden name=invnumber value=$form->{invnumber}>
	<input type=hidden name=transdate value=$form->{transdate}>
	<input type=hidden name=duedate value=$form->{duedate}>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
    </td>
  </tr>


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
  
  foreach $item (split / /, $form->{taxaccounts}) {
    if ($form->{"${item}_base"}) {
      $form->{"${item}_total"} = $form->round_amount($form->{"${item}_base"} * $form->{"${item}_rate"}, 2);
      $form->{invtotal} += $form->{"${item}_total"};
      $form->{"${item}_total"} = $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2, 0);
      
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


  $totalpaid = 0;
  
  $form->{paidaccounts} = 1;
  $i = 1;
  
  $form->{"selectAR_paid_$i"} = $form->{selectAR_paid};
  $form->{"selectAR_paid_$i"} =~ s/option>\Q$form->{"AR_paid_$i"}\E/option selected>$form->{"AR_paid_$i"}/;
  
  # format amounts
  $totalpaid += $form->{"paid_$i"};
  $form->{"paid_$i"} = $form->format_amount(\%myconfig, $form->{"paid_$i"}, 2);
  $form->{"exchangerate_$i"} = $form->format_amount(\%myconfig, $form->{"exchangerate_$i"});
  
  $form->{change} = 0;
  if ($totalpaid > $form->{invtotal}) {
    $form->{change} = $totalpaid - $form->{invtotal};
  }
  $form->{oldchange} = $form->{change};
  $form->{change} = $form->format_amount(\%myconfig, $form->{change}, 2, 0);
  $form->{totalpaid} = $form->format_amount(\%myconfig, $totalpaid, 2);

 
  $form->{oldinvtotal} = $form->{invtotal};
  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2, 0);
  
 
  print qq|

<input type=hidden name="exchangerate_$i" value=$form->{"exchangerate"}>
<input type=hidden name="forex_$i" value=$form->{"forex_$i"}>

  <tr>
    <td>
      <table width=100%>
	<tr valign=bottom>
	  <td>
	    <table>
	      <tr>
	        <td></td>
                <th>|.$locale->text('Paid').qq|</th>
		<th>|.$locale->text('Source').qq|</th>
		<th>|.$locale->text('Memo').qq|</th>
		<th>|.$locale->text('Account').qq|</th>
	      </tr>
	      <tr>
	        <td></td>
		<td><input name="paid_$i" size=11 value=$form->{"paid_$i"}></td>
		<td><input name="source_$i" size=10 value="$form->{"source_$i"}"></td>
		<td><input name="memo_$i" size=10 value="$form->{"memo_$i"}"></td>
	        <td><select name="AR_paid_$i">$form->{"selectAR_paid_$i"}</select></td>
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Change').qq|</th>
		<th>$form->{change}</th>
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
 
<input type=hidden name=paidaccounts value=$form->{paidaccounts}>
<input type=hidden name=selectAR_paid value="$form->{selectAR_paid}">
<input type=hidden name=oldinvtotal value=$form->{oldinvtotal}>
<input type=hidden name=oldtotalpaid value=$totalpaid>

<input type=hidden name=change value=$form->{change}>
<input type=hidden name=oldchange value=$form->{oldchange}>

<input type=hidden name=datepaid value=$form->{transdate}>
<input type=hidden name=invtotal value=$form->{invtotal}>

<tr>
  <td>
|;

  &print_options;

  print qq|
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
 
  if (! $form->{readonly}) {
    if ($transdate > $closedto) {
      print qq|
      <input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('Print').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('Post').qq|">|;

      if ($form->{id}) {
	print qq|
      <input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">|;
      }
    

      print "<p>\n";
    
      if ($form->{partsgroup}) {
	print qq|
<input type=hidden name=nextsub value=lookup_partsgroup>
<input type=hidden name=partsgroup value="$form->{partsgroup}">|;

	foreach $item (split /\n/, $form->{partsgroup}) {
	  $item =~ s///;
	  ($partsgroup, $translation) = split /--/, $item;
	  $item = ($translation) ? $translation : $partsgroup;
	  print qq| <input class=submit type=submit name=action value=".$item">\n|;
	}
      }
    }
  }
  
  print qq|

<input type=hidden name=rowcount value=$form->{rowcount}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

</form>

</body>
</html>
|;

}


sub post {

  $form->isblank("customer", $locale->text('Customer missing!'));

  # if oldcustomer ne customer redo form
  $customer = $form->{customer};
  $customer =~ s/--.*//g;
  $customer .= "--$form->{customer_id}";
  if ($customer ne $form->{oldcustomer}) {
    &update;
    exit;
  }
  
  &validate_items;

  $form->isblank("exchangerate", $locale->text('Exchange rate missing!')) if ($form->{currency} ne $form->{defaultcurrency});
  
  $paid = $form->parse_amount(\%myconfig, $form->{"paid_1"});
  $total = $form->parse_amount(\%myconfig, $form->{invtotal});
  
  $form->{"paid_1"} = $form->{invtotal} if $paid > $total;
  
  ($form->{AR}) = split /--/, $form->{AR};

  $form->{invnumber} = $form->update_defaults(\%myconfig, "sinumber") unless $form->{invnumber};
  
  $form->redirect($locale->text('Posted!')) if (IS->post_invoice(\%myconfig, \%$form));
  $form->error($locale->text('Cannot post transaction!'));
  
}


sub display_row {
  my $numrows = shift;

  @column_index = qw(partnumber description partsgroup qty unit sellprice discount linetotal);
    
  $form->{invsubtotal} = 0;

  map { $form->{"${_}_base"} = 0 } (split / /, $form->{taxaccounts});
  
  $column_data{partnumber} = qq|<th class=listheading nowrap>|.$locale->text('Number').qq|</th>|;
  $column_data{description} = qq|<th class=listheading nowrap>|.$locale->text('Description').qq|</th>|;
  $column_data{qty} = qq|<th class=listheading nowrap>|.$locale->text('Qty').qq|</th>|;
  $column_data{unit} = qq|<th class=listheading nowrap>|.$locale->text('Unit').qq|</th>|;
  $column_data{sellprice} = qq|<th class=listheading nowrap>|.$locale->text('Price').qq|</th>|;
  $column_data{linetotal} = qq|<th class=listheading nowrap>|.$locale->text('Extended').qq|</th>|;
  $column_data{discount} = qq|<th class=listheading nowrap>%</th>|;
  
  print qq|
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;

  $exchangerate = $form->parse_amount(\%myconfig, $form->{exchangerate});
  $exchangerate = ($exchangerate) ? $exchangerate : 1;
  
  for $i (1 .. $numrows) {
    # undo formatting
    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(qty discount sellprice);

    ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec = length $dec;
    $decimalplaces = ($dec > 2) ? $dec : 2;

    if (($form->{"qty_$i"} != $form->{"oldqty_$i"}) || ($form->{currency} ne $form->{oldcurrency})) {
# check for a pricematrix
      foreach $item (split / /, $form->{"pricematrix_$i"}) {
	($q, $p) = split /:/, $item;
	if ($p && $form->{"qty_$i"} > $q) {
	  $form->{"sellprice_$i"} = $form->round_amount($p / $exchangerate, $decimalplaces);
	}
      }
    }
    
    if ($i < $numrows) {
      if ($form->{"discount_$i"} != $form->{discount} * 100) {
	$form->{"discount_$i"} = $form->{discount} * 100;
      }
    }
    
    $discount = $form->round_amount($form->{"sellprice_$i"} * $form->{"discount_$i"}/100, $decimalplaces);
    $linetotal = $form->round_amount($form->{"sellprice_$i"} - $discount, $decimalplaces);
    $linetotal = $form->round_amount($linetotal * $form->{"qty_$i"}, 2);

    map { $form->{"${_}_$i"} = $form->quote($form->{"${_}_$i"}) } qw(partnumber sku description partsgroup unit);
    
    $column_data{partnumber} = qq|<td><input name="partnumber_$i" size=20 value="$form->{"partnumber_$i"}"></td>|;

    if (($rows = $form->numtextrows($form->{"description_$i"}, 25, 6)) > 1) {
      $column_data{description} = qq|<td><textarea name="description_$i" rows=$rows cols=25 wrap=soft>$form->{"description_$i"}</textarea></td>|;
    } else {
      $column_data{description} = qq|<td><input name="description_$i" size=30 value="$form->{"description_$i"}"></td>|;
    }

    $column_data{partsgroup} = qq|<input type=hidden name="partsgroup_$i" value="$form->{"partsgroup_$i"}">|;

    $column_data{qty} = qq|<td align=right><input name="qty_$i" size=5 value=|.$form->format_amount(\%myconfig, $form->{"qty_$i"}).qq|></td>|;
    $column_data{unit} = qq|<td><input type=hidden name="unit_$i" value="$form->{"unit_$i"}">$form->{"unit_$i"}</td>|;
    $column_data{sellprice} = qq|<td align=right><input name="sellprice_$i" size=9 value=|.$form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces).qq|></td>|;
    $column_data{linetotal} = qq|<td align=right>|.$form->format_amount(\%myconfig, $linetotal, 2).qq|</td>|;
    

    $discount = $form->format_amount(\%myconfig, $form->{"discount_$i"});
    $column_data{discount} = qq|<td align=right>$discount</td>
    <input type=hidden name="discount_$i" value=$discount>|;
    
    print qq|
        <tr valign=top>|;

    map { print "\n$column_data{$_}" } @column_index;
  
    print qq|
        </tr>

<input type=hidden name="id_$i" value=$form->{"id_$i"}>
<input type=hidden name="inventory_accno_$i" value=$form->{"inventory_accno_$i"}>
<input type=hidden name="income_accno_$i" value=$form->{"income_accno_$i"}>
<input type=hidden name="expense_accno_$i" value=$form->{"expense_accno_$i"}>
<input type=hidden name="listprice_$i" value="$form->{"listprice_$i"}">
<input type=hidden name="assembly_$i" value="$form->{"assembly_$i"}">
<input type=hidden name="taxaccounts_$i" value="$form->{"taxaccounts_$i"}">
<input type=hidden name="pricematrix_$i" value="$form->{"pricematrix_$i"}">
<input type=hidden name="oldqty_$i" value="$form->{"qty_$i"}">
<input type=hidden name="sku_$i" value="$form->{"sku_$i"}">

|;

    map { $form->{"${_}_base"} += $linetotal } (split / /, $form->{"taxaccounts_$i"});
  
    $form->{invsubtotal} += $linetotal;
  }

  print qq|
      </table>
    </td>
  </tr>

<input type=hidden name=oldcurrency value=$form->{currency}>

|;

}


sub print {
  
  $paid = $form->parse_amount(\%myconfig, $form->{"paid_1"});
  $total = $form->parse_amount(\%myconfig, $form->{invtotal});

  $form->{change} = 0;
  if ($paid > $total) {
    $form->{paid} = $total - $paid;
    $form->{"paid_1"} = $form->format_amount(\%myconfig, $paid, 2, 0);
    $form->{change} = $form->format_amount(\%myconfig, $paid - $total, 2, 0);
  }

  $old_form = new Form;
  map { $old_form->{$_} = $form->{$_} } keys %$form;
  
  map { $form->{$_} =~ s/--.*//g } qw(employee department);
  $form->{invdate} = $form->{transdate};
  $form->{invtime} = scalar localtime;

  &print_form($old_form);

}


sub print_form {
  my $old_form = shift;
  
  # if oldcustomer ne customer redo form
  $customer = $form->{customer};
  $customer =~ s/--.*//g;
  $customer .= "--$form->{customer_id}";
  if ($customer ne $form->{oldcustomer}) {
    &update;
    exit;
  }
 
 
  &validate_items;

  &{ "$form->{vc}_details" };

  @a = ();
  map { push @a, ("partnumber_$_", "description_$_") } (1 .. $form->{rowcount});
  map { push @a, "${_}_description" } split / /, $form->{taxaccounts};
  $form->format_string(@a);

  # format payment dates
  map { $form->{"datepaid_$_"} = $locale->date(\%myconfig, $form->{"datepaid_$_"}) } (1 .. $form->{paidaccounts});
  
  IS->invoice_details(\%myconfig, \%$form);

  map { $form->{$_} = $myconfig{$_} } (qw(company address tel fax businessnumber));
  $form->{username} = $myconfig{name};
  map { $form->{$_} =~ s/\\n/ /g } qw(company address);

  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = "$form->{type}.$form->{format}";

  if ($form->{media} !~ /screen/) {
    $form->{OUT} = "| $printer{$form->{media}}";
  }

  $form->{discount} = $form->format_amount(\%myconfig, $form->{discount} * 100);
  
  $form->{rowcount}--;
  $form->{pre} = "<body bgcolor=#ffffff>\n<pre>";
  delete $form->{stylesheet};
  
  $form->parse_template(\%myconfig, $userspath);

  if ($form->{printed} !~ /$form->{formname}/) {
    $form->{printed} .= " $form->{formname}";
    $form->{printed} =~ s/^ //;
    
    $form->update_status(\%myconfig);
  }
  $old_form->{printed} = $form->{printed};
  
  # if we got back here restore the previous form
  if ($form->{media} !~ /screen/) {
    # restore and display form
    map { $form->{$_} = $old_form->{$_} } keys %$old_form;
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate);

    $form->{rowcount}--;
    for $i (1 .. $form->{paidaccounts}) {
      map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);
    }

    delete $form->{pre};

    &display_form;
    exit;
  }

}


sub lookup_partsgroup {

  $form->{action} =~ s///;
  $form->{action} = substr($form->{action}, 1);

  if ($form->{language_code}) {
    # get english
    foreach $item (split /\n/, $form->{partsgroup}) {
      if ($item =~ /$form->{action}/) {
	($partsgroup, $translation) = split /--/, $item;
	$form->{action} = $partsgroup;
	last;
      }
    }
  }
  
  $form->{"partsgroup_$form->{rowcount}"} = $form->{action};
 
  &update;

}



sub print_options {

  $form->{PD}{$form->{type}} = "checked";
  
  print qq|
<input type=hidden name=format value=$form->{format}>
<input type=hidden name=formname value=$form->{type}>

<table width=100%>
  <tr>
|;

 
  $media = qq|
    <td><input class=radio type=radio name=media value="screen"></td>
    <td>|.$locale->text('Screen').qq|</td>|;

  if (%printer) {
    map { $media .= qq|
    <td><input class=radio type=radio name=media value="$_"></td>
    <td nowrap>$_</td>
| } keys %printer;
  }

  $media =~ s/(value="\Q$form->{media}\E")/$1 checked/;

  print qq|
  $media
  
  <td width=99%>&nbsp;</td>|;
  
  if ($form->{printed} =~ /$form->{type}/) {
    print qq|
    <th>\||.$locale->text('Printed').qq|\|</th>|;
  }
  
  print qq|
  </tr>
</table>
|;

}


sub receipts {

  $form->{title} = $locale->text('Receipts');

  $form->{db} = 'ar';
  RP->paymentaccounts(\%myconfig, \%$form);
  
  map { $paymentaccounts .= "$_->{accno} " } @{ $form->{PR} };

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
<input type=hidden name=paymentaccounts value="$paymentaccounts">

<input type=hidden name=till value=1>
<input type=hidden name=subtotal value=1>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
      
        <input type=hidden name=nextsub value=list_payments>
	
        <tr>
	  <th align=right>|.$locale->text('From').qq|</th>
	  <td><input name=fromdate size=11 title="$myconfig{dateformat}" value=$form->{fromdate}></td>
	  <th align=right>|.$locale->text('To').qq|</th>
	  <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
	</tr>
	$selectfrom
	  <input type=hidden name=sort value=transdate>
	  <input type=hidden name=db value=$form->{db}>
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
<input type=hidden name=sessionid value=$form->{sessionid}>

<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">

</form>

</body>
</html>
|;

}


