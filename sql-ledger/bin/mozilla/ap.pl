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
# Accounts Payables
#
#======================================================================


use SL::AP;
use SL::IR;
use SL::PE;

require "$form->{path}/arap.pl";

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
  
  $form->{callback} = "$form->{script}?action=add&path=$form->{path}&login=$form->{login}&password=$form->{password}" unless $form->{callback};

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

  $form->create_links("AP", \%myconfig, "vendor");

  $taxincluded = $form->{taxincluded};
  $duedate = $form->{duedate};
  
  IR->get_vendor(\%myconfig, \%$form);
  
  $form->{duedate} = $duedate;
  $form->{oldvendor} = "$form->{vendor}--$form->{vendor_id}";
  
  # build the popup menus

  # currencies
  @curr = split /:/, $form->{currencies};
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];

  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  # vendors
  if (@{ $form->{all_vendor} }) {
    $form->{vendor} = qq|$form->{vendor}--$form->{vendor_id}|;
    map { $form->{selectvendor} .= "<option>$_->{name}--$_->{id}\n" } (@{ $form->{all_vendor} });
  }
  

  # forex
  $form->{forex} = $form->{exchangerate};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;
  
  foreach $key (keys %{ $form->{AP_links} }) {
    
    foreach $ref (@{ $form->{AP_links}{$key} }) {
      if ($key eq "AP_tax") {
	$form->{"selectAP_tax_$ref->{accno}"} = "<option>$ref->{accno}--$ref->{description}\n";
	next;
      }
      $form->{"select$key"} .= "<option>$ref->{accno}--$ref->{description}\n";
    }
	
    # if there is a value we have an old entry
    for $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {

      if ($key eq "AP_paid") {
	$form->{"AP_paid_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
	$form->{"paid_$i"} = $form->{acc_trans}{$key}->[$i-1]->{amount};
	$form->{"datepaid_$i"} = $form->{acc_trans}{$key}->[$i-1]->{transdate};
	$form->{"source_$i"} = $form->{acc_trans}{$key}->[$i-1]->{source};
	
	$form->{"forex_$i"} = $form->{"exchangerate_$i"} = $form->{acc_trans}{$key}->[$i-1]->{exchangerate};
	
	$form->{paidaccounts}++;
      } else {

        $akey = $key;
        $akey =~ s/AP_//;

	if ($key eq "AP_tax") {
	  $form->{"${key}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
	  $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} = $form->round_amount($form->{acc_trans}{$key}->[$i-1]->{amount} / $exchangerate * -1, 2);
	  $totaltax += $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
	} else {
	  $form->{"${akey}_$i"} = $form->round_amount($form->{acc_trans}{$key}->[$i-1]->{amount} / $exchangerate, 2);
	  if ($akey eq 'amount') {
	    $form->{"${akey}_$i"} *= -1;
	    $totalamount += $form->{"${akey}_$i"};
	    $form->{rowcount}++;

	    $form->{"oldprojectnumber_$i"} = $form->{"projectnumber_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{projectnumber}";
	    $form->{"project_id_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{project_id}";
	  }
	  $form->{"${key}_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
	}
      }
    }
  }

  $form->{taxincluded} = $taxincluded if ($form->{id});
  $form->{paidaccounts} = 1 if not defined $form->{paidaccounts};

  if ($form->{taxincluded} && $totalamount) {
  # add tax to amounts and invtotal
    for $i (1 .. $form->{rowcount}) {
      $taxamount = $totaltax * $form->{"amount_$i"} / $totalamount;
      $tax = $form->round_amount($taxamount, 2);
      $diff += ($taxamount - $tax);
      $form->{"amount_$i"} += $tax;
    }
    $form->{amount_1} += $form->round_amount($diff, 2);
  }
  
  $form->{invtotal} = $totalamount + $totaltax;
  $form->{rowcount}++ if $form->{id};
  
  $form->{AP} = $form->{AP_1};

  $form->{locked} = ($form->datetonum($form->{transdate}, \%myconfig) <= $form->datetonum($form->{closedto}, \%myconfig));

}


sub form_header {

  $title = $form->{title};
  $form->{title} = $locale->text("$title Accounts Payables Transaction");

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";
  
# type=submit $locale->text('Add Accounts Payables Transaction')
# type=submit $locale->text('Edit Accounts Payables Transaction')

  # set option selected
  foreach $item (qw(AP vendor currency)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  
  # format amounts
  $form->{exchangerate} = $form->format_amount(\%myconfig, $form->{exchangerate});
  
  $exchangerate = qq|
<input type=hidden name=forex value=$form->{forex}>
|;
  if ($form->{currency} ne $form->{defaultcurrency}) {
    if ($form->{forex}) {
      $exchangerate .= qq|
	      <th align=right>|.$locale->text('Exchangerate').qq|</th>
              <td><input type=hidden name=exchangerate value=$form->{exchangerate}>$form->{exchangerate}</td>
|;
    } else {
      $exchangerate .= qq|
	     <th align=right>|.$locale->text('Exchangerate').qq|</th>
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
  
  
  $form->header;

  $vendor = ($form->{selectvendor}) ? qq|<select name=vendor>$form->{selectvendor}</select>| : qq|<input name=vendor value="$form->{vendor}" size=35>|; 
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=sort value=$form->{sort}>
<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>
<input type=hidden name=title value="$title">

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
		<th align=right nowrap>|.$locale->text('Vendor').qq|</th>
		<td colspan=3>$vendor</td>
		<input type=hidden name=selectvendor value="$form->{selectvendor}">
		<input type=hidden name=oldvendor value="$form->{oldvendor}">
		<input type=hidden name=vendor_id value="$form->{vendor_id}">
		<input type=hidden name=terms value=$form->{terms}>
	      </tr>
	      $taxincluded
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
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      <tr>
		<th align=right nowrap>|.$locale->text('Invoice Number').qq|</th>
		<td><input name=invnumber size=11 value="$form->{invnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Order Number').qq|</th>
		<td><input name=ordnumber size=11 value="$form->{ordnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Invoice Date').qq|</th>
		<td><input name=transdate size=11 title="$myconfig{'dateformat'}" value=$form->{transdate}></td>
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
  <input type=hidden name=selectAP_amount value="$form->{selectAP_amount}">
  <input type=hidden name=rowcount value=$form->{rowcount}>
  <tr>
    <td>
      <table width=100%>
|;

  $amount = $locale->text('Amount');
  $project = $locale->text('Project');
  
  for $i (1 .. $form->{rowcount}) {

    $form->{"selectAP_amount"} =~ s/ selected//;
    $form->{"selectAP_amount"} =~ s/option>\Q$form->{"AP_amount_$i"}\E/option selected>$form->{"AP_amount_$i"}/;

    # format amounts
    $form->{"amount_$i"} = $form->format_amount(\%myconfig, $form->{"amount_$i"}, 2);

    print qq|
	<tr>
	  <th align=right nowrap>$amount</th>
	  <td><input name="amount_$i" size=10 value=$form->{"amount_$i"}></td>
	  <th>$project</th>
	  <td><input name="projectnumber_$i" size=20 value="$form->{"projectnumber_$i"}">
	      <input type=hidden name="project_id_$i" value=$form->{"project_id_$i"}>
	      <input type=hidden name="oldprojectnumber_$i" value="$form->{"oldprojectnumber_$i"}"></td>
	  <td width=50%><select name="AP_amount_$i">$form->{selectAP_amount}</select></td>
	</tr>
|;
    $amount = "";
    $project = "";
  }

  $taxlabel = ($form->{taxincluded}) ? $locale->text('Tax Included') : $locale->text('Tax');
  
  foreach $item (split / /, $form->{taxaccounts}) {

    # format and reverse tax
    $form->{"tax_$item"} = $form->format_amount(\%myconfig, $form->{"tax_$item"}, 2); 

    print qq|
        <tr>
	  <th align=right nowrap>${taxlabel}</th>
	  <td><input name="tax_$item" size=10 value=$form->{"tax_$item"}></td>
	  <td colspan=2></td>
	  <td><select name=AP_tax_$item>$form->{"selectAP_tax_$item"}</select></td>
        </tr>
	<input type=hidden name="${item}_rate" value="$form->{"${item}_rate"}">
	<input type=hidden name="${item}_description" value="$form->{"${item}_description"}">
	<input type=hidden name="selectAP_tax_$item" value="$form->{"selectAP_tax_$item"}">
|;
  }
   
  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2);

  print qq|
        <tr>
	  <th align=right nowrap>|.$locale->text('Total').qq|</th>
	  <td>$form->{invtotal}</td>
	  <td colspan=2></td>
          <td><select name=AP>$form->{selectAP}</select></td>
	  <input type=hidden name=selectAP value="$form->{selectAP}">
	  <input type=hidden name=taxaccounts value="$form->{taxaccounts}">
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Notes').qq|</th>
	  <td colspan=5>$notes</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
	  <th class=listheading colspan=5>|.$locale->text('Payments').qq|</th>
	</tr>
|;


  if ($form->{currency} eq $form->{defaultcurrency}) {
    @column_index = qw(datepaid source paid AP_paid);
  } else {
    @column_index = qw(datepaid source paid exchangerate AP_paid);
  }

  $column_data{datepaid} = "<th>".$locale->text('Date')."</th>";
  $column_data{paid} = "<th>".$locale->text('Amount')."</th>";
  $column_data{exchangerate} = "<th>".$locale->text('Exch')."</th>";
  $column_data{AP_paid} = "<th>".$locale->text('Account')."</th>";
  $column_data{source} = "<th>".$locale->text('Source')."</th>";

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

    $form->{"selectAP_paid_$i"} = $form->{selectAP_paid};
    $form->{"selectAP_paid_$i"} =~ s/option>\Q$form->{"AP_paid_$i"}\E/option selected>$form->{"AP_paid_$i"}/;

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

    $column_data{"paid_$i"} = qq|<td align=center><input name="paid_$i" size=10 value=$form->{"paid_$i"}></td>|;
    $column_data{"AP_paid_$i"} = qq|<td align=center><select name="AP_paid_$i">$form->{"selectAP_paid_$i"}</select></td>|;
    $column_data{"exchangerate_$i"} = qq|<td align=center>$exchangerate</td>|;
    $column_data{"datepaid_$i"} = qq|<td align=center><input name="datepaid_$i" size=11 title="($myconfig{'dateformat'})" value=$form->{"datepaid_$i"}></td>|;
    $column_data{"source_$i"} = qq|<td align=center><input name="source_$i" size=10 value="$form->{"source_$i"}"></td>|;

    map { print qq|$column_data{"${_}_$i"}\n| } @column_index;

    print "
        </tr>
";
  }

  print qq|
    <input type=hidden name=paidaccounts value=$form->{paidaccounts}>
    <input type=hidden name=selectAP_paid value="$form->{selectAP_paid}">
    
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

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
|;

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  
  if ($form->{id}) {
    print qq|<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
|;

    if (!$form->{revtrans}) {
      if (!$form->{locked}) {
	print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Post').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">
|;
      }
    }

    if ($transdate > $closedto) {
      print qq|
<input class=submit type=submit name=action value="|.$locale->text('Post as new').qq|">
|;
    }

  } else {
    if ($transdate > $closedto) {
      print qq|<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('Post').qq|">|;
    }
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
  
  $form->{exchangerate} = $form->parse_amount(\%myconfig, $form->{exchangerate});

  @flds = qw(amount AP_amount projectnumber oldprojectnumber project_id);
  $count = 0;
  for $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} = $form->parse_amount(\%myconfig, $form->{"amount_$i"});
    if ($form->{"amount_$i"}) {
      push @a, {};
      my $j = $#a;
      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }
  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
  $form->{rowcount} = $count + 1;
  
  map { $form->{invtotal} += $form->{"amount_$_"} } (1 .. $form->{rowcount});
  
  $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, 'sell')));

  $form->{invdate} = $form->{transdate};
  &check_name(vendor);

  &check_project;


TAXCALC:
  # recalculate taxes
  if ($form->{taxincluded}) {
    $taxrate = 0;

    map { $taxrate += $form->{"${_}_rate"} } split / /, $form->{taxaccounts};

    foreach $item (split / /, $form->{taxaccounts}) {
      $amount = ($form->{invtotal} * (1 - 1 / (1 + $taxrate)) * $form->{"${item}_rate"} / $taxrate) if $taxrate;
      $form->{"tax_$item"} = $form->round_amount($amount, 2);
      $taxdiff += ($amount - $form->{"tax_$item"});
      if (abs $taxdiff >= 0.005) {
	$form->{"tax_$item"} += $form->round_amount($taxdiff, 2);
	$taxdiff = 0;
      }
      $form->{"selectAP_tax_$item"} = qq|<option>$item--$form->{"${item}_description"}|;
      $totaltax += $form->{"tax_$item"};
    }
  } else {
    foreach $item (split / /, $form->{taxaccounts}) {
      $form->{"tax_$item"} = $form->round_amount($form->{invtotal} * $form->{"${item}_rate"}, 2);
      $form->{"selectAP_tax_$item"} = qq|<option>$item--$form->{"${item}_description"}|;
      $totaltax += $form->{"tax_$item"};
    }
  }

  $form->{invtotal} = ($form->{taxincluded}) ? $form->{invtotal} : $form->{invtotal} + $totaltax;
  
  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);
      
      $form->{"exchangerate_$i"} = $exchangerate if ($form->{"forex_$i"} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell')));
    }
  }

  &display_form;

}

 
sub post {

  # check if there is an invoice number, invoice and due date
  $form->isblank("invnumber", $locale->text("Invoice Number missing!"));
  $form->isblank("transdate", $locale->text("Invoice Date missing!"));
  $form->isblank("duedate", $locale->text("Due Date missing!"));
  $form->isblank("vendor", $locale->text('Vendor missing!'));
  
  
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  $transdate = $form->datetonum($form->{transdate}, \%myconfig);

  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($transdate <= $closedto);

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!')) if ($form->{currency} ne $form->{defaultcurrency});

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!')) if ($datepaid <= $closedto);

      if ($form->{currency} ne $form->{defaultcurrency}) {
	$form->{"exchangerate_$i"} = $form->{exchangerate} if ($transdate == $datepaid);
	$form->isblank("exchangerate_$i", $locale->text('Exchangerate for payment missing!'));
      }
      
    }
  }
      

  # if old vendor ne vendor redo form
  ($vendor) = split /--/, $form->{vendor};
  if ($form->{oldvendor} ne "$vendor--$form->{vendor_id}") {
    &update;
    exit;
  }

  $form->{id} = 0 if $form->{postasnew};

  $form->redirect($locale->text('Transaction posted!')) if (AP->post_transaction(\%myconfig, \%$form));
  $form->error($locale->text('Cannot post transaction!'));
  
}


sub post_as_new {

  $form->{postasnew} = 1;
  &post;

}


sub delete {

  $form->{title} = $locale->text('Confirm!');
  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  foreach $key (keys %$form) {
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

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

  $form->redirect($locale->text('Transaction deleted!')) if (AP->delete_transaction(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete transaction!'));

}


sub search {
  
  # setup vendor selection
  $form->all_vc(\%myconfig, "vendor");

  if (@{ $form->{all_vendor} }) {
    map { $vendor .= "<option>$_->{name}--$_->{id}\n" } @{ $form->{all_vendor} };
    $vendor = qq|<select name=vendor><option>\n$vendor\n</select>|;
  } else {
    $vendor = qq|<input name=vendor size=35>|;
  }
    
    $form->{title} = $locale->text('AP Transactions');

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>|.$locale->text('Vendor').qq|</th>
	  <td colspan=3>$vendor</td>
	</tr>
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
	<tr>
	  <th align=right nowrap>|.$locale->text('From').qq|</th>
	  <td><input name=transdatefrom size=11 title="$myconfig{dateformat}"></td>
	  <th align=right>|.$locale->text('to').qq|</th>
	  <td><input name=transdateto size=11 title="$myconfig{dateformat}"></td>
	</tr>
        <input type=hidden name=sort value=transdate>
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
	      <tr>
		<td align=right><input name=open class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Open').qq|</td>
		<td align=right><input name=closed class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Closed').qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_id" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('ID').qq|</td>
		<td align=right><input name="l_invnumber" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Invoice Number').qq|</td>
		<td align=right><input name="l_ordnumber" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Order Number').qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Vendor').qq|</td>
		<td align=right><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Invoice Date').qq|</td>
		<td align=right><input name="l_netamount" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Amount').qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_tax" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Tax').qq|</td>
		<td align=right><input name="l_amount" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Total').qq|</td>
		<td align=right><input name="l_datepaid" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Date Paid').qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_paid" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>|.$locale->text('Paid').qq|</td>
		<td align=right><input name="l_duedate" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Due Date').qq|</td>
		<td align=right><input name="l_due" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Amount Due').qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_notes" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Notes').qq|</td>
		<td align=right><input name="l_employee" class=checkbox type=checkbox value=Y></td>
		<td nowrap>|.$locale->text('Employee').qq|</td>
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

<br>
<input type=hidden name=nextsub value=$form->{nextsub}>
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}


sub ap_transactions {

  $form->{vendor} = $form->unescape($form->{vendor});
  ($form->{vendor}, $form->{vendor_id}) = split(/--/, $form->{vendor});

  AP->ap_transactions(\%myconfig, \%$form);

  $callback = "$form->{script}?action=ap_transactions&path=$form->{path}&login=$form->{login}&password=$form->{password}";
  $href = $callback;
    

  if ($form->{vendor}) {
    $callback .= "&vendor=".$form->escape($form->{vendor});
    $href .= "&vendor=".$form->escape($form->{vendor});
    $option .= $locale->text('Vendor')." : $form->{vendor}";
  }
  if ($form->{invnumber}) {
    $callback .= "&invnumber=$form->{invnumber}";
    $href .= "&invnumber=".$form->escape($form->{invnumber});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Invoice Number')." : $form->{invnumber}";
  }
  if ($form->{ordnumber}) {
    $callback .= "&ordnumber=$form->{ordnumber}";
    $href .= "&ordnumber=".$form->escape($form->{ordnumber});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Order Number')." : $form->{ordnumber}";
  }
  if ($form->{notes}) {
    $callback .= "&notes=$form->{notes}";
    $href .= "&notes=".$form->escape($form->{notes});
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Notes')." : $form->{notes}";
  }
  
  if ($form->{transdatefrom}) {
    $callback .= "&transdatefrom=$form->{transdatefrom}";
    $href .= "&transdatefrom=$form->{transdatefrom}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('From')." ".$locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    $callback .= "&transdateto=$form->{transdateto}";
    $href .= "&transdateto=$form->{transdateto}";
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('to')." ".$locale->date(\%myconfig, $form->{transdateto}, 1);
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

  @columns = $form->sort_columns(qw(transdate id invnumber ordnumber name netamount tax amount paid datepaid due duedate notes employee));

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
  
    
  $column_header{id} = qq|<th><a class=listheading href=$href&sort=id>|.$locale->text('ID').qq|</a></th>|;
  $column_header{transdate} = qq|<th><a class=listheading href=$href&sort=transdate>|.$locale->text('Date').qq|</a></th>|;
  $column_header{duedate} = qq|<th><a class=listheading href=$href&sort=duedate>|.$locale->text('Due Date').qq|</a></th>|;
  $column_header{due} = qq|<th class=listheading>|.$locale->text('Amount Due').qq|</th>|;
  $column_header{invnumber} = qq|<th><a class=listheading href=$href&sort=invnumber>|.$locale->text('Invoice').qq|</a></th>|;
  $column_header{ordnumber} = qq|<th><a class=listheading href=$href&sort=ordnumber>|.$locale->text('Order').qq|</a></th>|;
  $column_header{name} = qq|<th><a class=listheading href=$href&sort=name>|.$locale->text('Vendor').qq|</a></th>|;
  $column_header{netamount} = qq|<th class=listheading>|.$locale->text('Amount').qq|</th>|;
  $column_header{tax} = qq|<th class=listheading>|.$locale->text('Tax').qq|</th>|;
  $column_header{amount} = qq|<th class=listheading>|.$locale->text('Total').qq|</th>|;
  $column_header{paid} = qq|<th class=listheading>|.$locale->text('Paid').qq|</th>|;
  $column_header{datepaid} = qq|<th><a class=listheading href=$href&sort=datepaid>|.$locale->text('Date Paid').qq|</a></th>|;
  $column_header{notes} = qq|<th><a class=listheading>|.$locale->text('Notes').qq|</th>|;
  $column_header{employee} = "<th><a class=listheading href=$href&sort=employee>".$locale->text('Employee')."</th>";

  
  $form->{title} = $locale->text('AP Transactions');

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

  # add sort and escape callback
  $form->{callback} = "$callback&sort=$form->{sort}";
  $callback = $form->escape($form->{callback});

  if (@{ $form->{AP} }) {
    $sameitem = $form->{AP}->[0]->{$form->{sort}};
  }
  
  # sums and tax on reports by Antonio Gallardo
  #
  foreach $ap (@{ $form->{AP} }) {

    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ap->{$form->{sort}}) {
	&ap_subtotal;
	$sameitem = $ap->{$form->{sort}};
      }
    }
    
    $column_data{netamount} = "<td align=right>".$form->format_amount(\%myconfig, $ap->{netamount}, 2, "&nbsp;")."</td>";
    $column_data{tax} = "<td align=right>".$form->format_amount(\%myconfig, $ap->{amount} - $ap->{netamount}, 2, "&nbsp;") . "</td>";
    $column_data{amount} = "<td align=right>".$form->format_amount(\%myconfig, $ap->{amount}, 2, "&nbsp;") . "</td>";
    $column_data{paid} = "<td align=right>".$form->format_amount(\%myconfig, $ap->{paid}, 2, "&nbsp;")."</td>";
    $column_data{due} = "<td align=right>".$form->format_amount(\%myconfig, $ap->{amount} - $ap->{paid}, 2, "&nbsp;")."</td>";

    $totalnetamount += $ap->{netamount};
    $totalamount += $ap->{amount};
    $totalpaid += $ap->{paid};
    $totaldue += ($ap->{amount} - $ap->{paid});

    $subtotalnetamount += $ap->{netamount};
    $subtotalamount += $ap->{amount};
    $subtotalpaid += $ap->{paid};
    $subtotaldue += ($ap->{amount} - $ap->{paid});

    $column_data{transdate} = "<td>$ap->{transdate}&nbsp;</td>";
    $column_data{duedate} = "<td>$ap->{duedate}&nbsp;</td>";
    $column_data{datepaid} = "<td>$ap->{datepaid}&nbsp;</td>";

    $module = ($ap->{invoice}) ? "ir.pl" : $form->{script};

    $column_data{invnumber} = qq|<td><a href="$module?action=edit&path=$form->{path}&id=$ap->{id}&login=$form->{login}&password=$form->{password}&callback=$callback">$ap->{invnumber}</a></td>|;
    $column_data{id} = "<td>$ap->{id}</td>";
    $column_data{ordnumber} = "<td>$ap->{ordnumber}&nbsp;</td>";
    $column_data{name} = "<td>$ap->{name}</td>";
    $ap->{notes} =~ s/\r\n/<br>/g;
    $column_data{notes} = "<td>$ap->{notes}&nbsp;</td>";
    $column_data{employee} = "<td>$ap->{employee}&nbsp;</td>";
    
    $i++;
    $i %= 2;
    print "
        <tr class=listrow$i >
";
    
    map { print "\n$column_data{$_}" } @column_index;

    print qq|
	</tr>
|;

  }
  
  if ($form->{l_subtotal} eq 'Y') {
    &ap_subtotal;
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
  $column_data{due} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totaldue, 2, "&nbsp;")."</th>";

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

<br>
<form method=post action=$form->{script}>
 
<input name=callback type=hidden value="$form->{callback}">
  
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>
   
<input class=submit type=submit name=action value="|.$locale->text('AP Transaction').qq|">

<input class=submit type=submit name=action value="|.$locale->text('Vendor Invoice').qq|">

</form>

</body>
</html>
|;

}


sub ap_subtotal {

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
  
  $column_data{netamount} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalnetamount, 2, "&nbsp;")."</th>";
  $column_data{tax} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalamount - $subtotalnetamount, 2, "&nbsp;")."</th>";
  $column_data{amount} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalamount, 2, "&nbsp;")."</th>";
  $column_data{paid} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalpaid, 2, "&nbsp;")."</th>";
  $column_data{due} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotaldue, 2, "&nbsp;")."</th>";

  $subtotalnetamount = 0;
  $subtotalamount = 0;
  $subtotalpaid = 0;
  $subtotaldue = 0;

  print "<tr class=listsubtotal>";
  
  map { print "\n$column_data{$_}" } @column_index;

  print qq|
  </tr>
|;

}



