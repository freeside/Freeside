######################################################################
# SQL-Ledger, Accounting
# Copyright (c) 1998-2002
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
#
#######################################################################
#
# common routines used in is, ir, oe
#
#######################################################################

# any custom scripts for this one
if (-f "$form->{path}/custom_io.pl") {
  eval { require "$form->{path}/custom_io.pl"; };
}
if (-f "$form->{path}/$form->{login}_io.pl") {
  eval { require "$form->{path}/$form->{login}_io.pl"; };
}


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


sub display_row {
  my $numrows = shift;

  @column_index = (partnumber, description, qty);
  
  if ($form->{type} eq "sales_order") {
    if ($form->{id}) {
      push @column_index, "ship";
      $column_data{ship} = qq|<th class=listheading align=left width="auto">|.$locale->text('Ship').qq|</th>|;
    }
  }
  if ($form->{type} eq "purchase_order") {
    if ($form->{id}) {
      push @column_index, "ship";
      $column_data{ship} = qq|<th class=listheading align=left width="auto">|.$locale->text('Recd').qq|</th>|;
    }
  }
  
  push @column_index, qw(unit sellprice);
  
  if ($form->{script} eq 'is.pl' || $form->{type} eq 'sales_order') {
    push @column_index, qw(discount);
  }
  
  push @column_index, "linetotal";

  my $colspan = $#column_index + 1;

     
  $form->{invsubtotal} = 0;
  map { $form->{"${_}_base"} = 0 } (split / /, $form->{taxaccounts});
  
  $column_data{partnumber} = qq|<th class=listheading nowrap>|.$locale->text('Number').qq|</th>|;
  $column_data{description} = qq|<th class=listheading nowrap>|.$locale->text('Description').qq|</th>|;
  $column_data{qty} = qq|<th class=listheading nowrap>|.$locale->text('Qty').qq|</th>|;
  $column_data{unit} = qq|<th class=listheading nowrap>|.$locale->text('Unit').qq|</th>|;
  $column_data{sellprice} = qq|<th class=listheading nowrap>|.$locale->text('Price').qq|</th>|;
  $column_data{discount} = qq|<th class=listheading>%</th>|;
  $column_data{linetotal} = qq|<th class=listheading nowrap>|.$locale->text('Extended').qq|</th>|;
  $column_data{bin} = qq|<th class=listheading nowrap>|.$locale->text('Bin').qq|</th>|;
  
  print qq|
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;


  $projectnumber = $locale->text('Project');
  $runningnumber = $locale->text('No.');
  $partsgroup = $locale->text('Group');
  
  if ($form->{type} =~ /_order/) {
    $reqdate = $locale->text('Required by');
    $delvar = "reqdate";
  } else {
    $deliverydate = $locale->text('Delivery Date');
    $delvar = "deliverydate";
  }
  
  
  for $i (1 .. $numrows) {
    # undo formatting
    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(qty ship discount sellprice);

    ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec = length $dec;
    $decimalplaces = ($dec > 2) ? $dec : 2;
    
    $discount = $form->round_amount($form->{"sellprice_$i"} * $form->{"discount_$i"}/100, $decimalplaces);
    $linetotal = $form->round_amount($form->{"sellprice_$i"} - $discount, $decimalplaces);
    $linetotal = $form->round_amount($linetotal * $form->{"qty_$i"}, 2);

    # convert " to &quot;
    map { $form->{"${_}_$i"} =~ s/"/&quot;/g } qw(partnumber description unit);
    
    $column_data{partnumber} = qq|<td><input name="partnumber_$i" size=20 value="$form->{"partnumber_$i"}"></td>|;

    if (($rows = $form->numtextrows($form->{"description_$i"}, 30, 6)) > 1) {
      $column_data{description} = qq|<td><textarea name="description_$i" rows=$rows cols=30 wrap=soft>$form->{"description_$i"}</textarea></td>|;
    } else {
      $column_data{description} = qq|<td><input name="description_$i" size=30 value="$form->{"description_$i"}"></td>|;
    }

    $column_data{qty} = qq|<td align=right><input name="qty_$i" size=5 value=|.$form->format_amount(\%myconfig, $form->{"qty_$i"}).qq|></td>|;
    $column_data{ship} = qq|<td align=right><input name="ship_$i" size=5 value=|.$form->format_amount(\%myconfig, $form->{"ship_$i"}).qq|></td>|;
    $column_data{unit} = qq|<td><input name="unit_$i" size=5 maxsize=5 value="$form->{"unit_$i"}"></td>|;
    $column_data{sellprice} = qq|<td align=right><input name="sellprice_$i" size=9 value=|.$form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces).qq|></td>|;
    $column_data{discount} = qq|<td align=right><input name="discount_$i" size=3 value=|.$form->format_amount(\%myconfig, $form->{"discount_$i"}).qq|></td>|;
    $column_data{linetotal} = qq|<td align=right>|.$form->format_amount(\%myconfig, $linetotal, 2).qq|</td>|;
    $column_data{bin} = qq|<td>$form->{"bin_$i"}</td>|;
    
    print qq|
        <tr valign=top>|;

    map { print "\n$column_data{$_}" } @column_index;
  
    print qq|
        </tr>

<input type=hidden name="id_$i" value=$form->{"id_$i"}>
<input type=hidden name="inventory_accno_$i" value=$form->{"inventory_accno_$i"}>
<input type=hidden name="bin_$i" value="$form->{"bin_$i"}">
<input type=hidden name="income_accno_$i" value=$form->{"income_accno_$i"}>
<input type=hidden name="expense_accno_$i" value=$form->{"expense_accno_$i"}>
<input type=hidden name="listprice_$i" value="$form->{"listprice_$i"}">
<input type=hidden name="assembly_$i" value="$form->{"assembly_$i"}">
<input type=hidden name="taxaccounts_$i" value="$form->{"taxaccounts_$i"}">

|;

    # print second row
    print qq|
        <tr>
	  <td colspan=$colspan>
	    <table>
	      <tr>
                <th>$runningnumber</th>
		<td><input name="runningnumber_$i" size=3 value=$i></td>
		<td width=20></td>
	        <th>$partsgroup</th>
		<td><input name="partsgroup_$i" size=10 value="$form->{"partsgroup_$i"}">
	        <th>${$delvar}</th>
		<td><input name="${delvar}_$i" size=11 title="$myconfig{dateformat}" value="$form->{"${delvar}_$i"}"></td>
	        <th>$projectnumber</th>
		<td><input name="projectnumber_$i" size=10 value="$form->{"projectnumber_$i"}">
		    <input type=hidden name="oldprojectnumber_$i" value="$form->{"oldprojectnumber_$i"}">
		    <input type=hidden name="project_id_$i" value="$form->{"project_id_$i"}"></td>
	      </tr>
	    </table>
	  </td>
	</tr>
	<tr>
	  <td colspan=$colspan><hr size=1 noshade></td>
	</tr>
|;
  

    map { $form->{"${_}_base"} += $linetotal } (split / /, $form->{"taxaccounts_$i"});
  
    $form->{invsubtotal} += $linetotal;
  }

  print qq|
      </table>
    </td>
  </tr>
|;

}


sub select_item {
  
  @column_index = qw(ndx partnumber description onhand sellprice);

  $column_data{ndx} = qq|<th>&nbsp;</th>|;
  $column_data{partnumber} = qq|<th class=listheading>|.$locale->text('Number').qq|</th>|;
  $column_data{description} = qq|<th class=listheading>|.$locale->text('Description').qq|</th>|;
  $column_data{sellprice} = qq|<th class=listheading>|.$locale->text('Price').qq|</th>|;
  $column_data{onhand} = qq|<th class=listheading>|.$locale->text('Qty').qq|</th>|;
  
  
  # list items with radio button on a form
  $form->header;

  $title = $locale->text('Select from one of the items below');
  $colspan = $#column_index + 1;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop colspan=$colspan>$title</th>
  </tr>
  <tr height="5"></tr>
  <tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;
  
  print qq|</tr>|;

  my $i = 0;
  foreach $ref (@{ $form->{item_list} }) {
    $checked = ($i++) ? "" : "checked";

    map { $ref->{$_} =~ s/"/&quot;/g } qw(partnumber description unit);

    $column_data{ndx} = qq|<td><input name=ndx class=radio type=radio value=$i $checked></td>|;
    $column_data{partnumber} = qq|<td><input name="new_partnumber_$i" type=hidden value="$ref->{partnumber}">$ref->{partnumber}</td>|;
    $column_data{description} = qq|<td><input name="new_description_$i" type=hidden value="$ref->{description}">$ref->{description}</td>|;
    $column_data{sellprice} = qq|<td align=right><input name="new_sellprice_$i" type=hidden value=$ref->{sellprice}>|.$form->format_amount(\%myconfig, $ref->{sellprice}, 2, "&nbsp;").qq|</td>|;
    $column_data{onhand} = qq|<td align=right><input name="new_onhand_$i" type=hidden value=$ref->{onhand}>|.$form->format_amount(\%myconfig, $ref->{onhand}, '', "&nbsp;").qq|</td>|;
    
    $j++; $j %= 2;
    print qq|
<tr class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
</tr>

<input name="new_bin_$i" type=hidden value="$ref->{bin}">
<input name="new_listprice_$i" type=hidden value=$ref->{listprice}>
<input name="new_inventory_accno_$i" type=hidden value=$ref->{inventory_accno}>
<input name="new_income_accno_$i" type=hidden value=$ref->{income_accno}>
<input name="new_expense_accno_$i" type=hidden value=$ref->{expense_accno}>
<input name="new_unit_$i" type=hidden value="$ref->{unit}">
<input name="new_weight_$i" type=hidden value="$ref->{weight}">
<input name="new_assembly_$i" type=hidden value="$ref->{assembly}">
<input name="new_taxaccounts_$i" type=hidden value="$ref->{taxaccounts}">
<input name="new_partsgroup_$i" type=hidden value="$ref->{partsgroup}">

<input name="new_id_$i" type=hidden value=$ref->{id}>

|;

  }
  
  print qq|
<tr><td colspan=8><hr size=3 noshade></td></tr>
</table>

<input name=lastndx type=hidden value=$i>

|;

  # delete action variable
  delete $form->{action};
  delete $form->{item_list};
    
  # save all other form variables
  foreach $key (keys %${form}) {
    $form->{$key} =~ s/"/&quot;/g;
    print qq|<input name=$key type=hidden value="$form->{$key}">\n|;
  }

  print qq|
<input type=hidden name=nextsub value=item_selected>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}



sub item_selected {

  # replace the last row with the checked row
  $i = $form->{rowcount};
  $i = $form->{assembly_rows} if ($form->{item} eq 'assembly');

  # index for new item
  $j = $form->{ndx};

  # if there was a price entered, override it
  $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});
  
  map { $form->{"${_}_$i"} = $form->{"new_${_}_$j"} } qw(id partnumber description sellprice listprice inventory_accno income_accno expense_accno bin unit weight assembly taxaccounts partsgroup);

  ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
  $dec = length $dec;
  $decimalplaces = ($dec > 2) ? $dec : 2;

  if ($sellprice) {
    $form->{"sellprice_$i"} = $sellprice;
  } else {
    # if there is an exchange rate adjust sellprice
    if (($form->{exchangerate} * 1) != 0) {
      $form->{"sellprice_$i"} /= $form->{exchangerate};
      $form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"}, $decimalplaces);
    }
  }

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(sellprice weight);

  $form->{sellprice} += ($form->{"sellprice_$i"} * $form->{"qty_$i"});
  $form->{weight} += ($form->{"weight_$i"} * $form->{"qty_$i"});

  $amount = $form->{"sellprice_$i"} * (1 - $form->{"discount_$i"} / 100) * $form->{"qty_$i"};
  map { $form->{"${_}_base"} += $amount } (split / /, $form->{"taxaccounts_$i"});
  map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{"taxaccounts_$i"} if !$form->{taxincluded};

  $form->{creditremaining} -= $amount;

  $form->{"runningnumber_$i"} = $i;
  
  # delete all the new_ variables
  for $i (1 .. $form->{lastndx}) {
    map { delete $form->{"new_${_}_$i"} } qw(partnumber description sellprice bin listprice inventory_accno income_accno expense_accno unit assembly taxaccounts id);
  }
  
  map { delete $form->{$_} } qw(ndx lastndx nextsub);

  if ($form->{item} eq 'assembly') {
    map { $form->{"qty_$_"} = $form->parse_amount(\%myconfig, $form->{"qty_$_"}) } (1 .. $i);
  } else {
    # format amounts for invoice / order
    map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, $decimalplaces) } qw(sellprice listprice);
  }

  &display_form;
  
}


sub new_item {

  # change callback
  $form->{old_callback} = $form->escape($form->{callback},1);
  $form->{callback} = $form->escape("$form->{script}?action=display_form",1);

  # delete action
  delete $form->{action};

  # save all other form variables in a previous_form variable
  foreach $key (keys %$form) {
    # escape ampersands
    $form->{$key} =~ s/&/%26/g;
    $previous_form .= qq|$key=$form->{$key}&|;
  }
  chop $previous_form;
  $previous_form = $form->escape($previous_form, 1);

  $i = $form->{rowcount};
  map { $form->{"${_}_$i"} =~ s/"/&quot;/g } qw(partnumber description);

  $form->header;

  print qq|
<body>

<h4 class=error>|.$locale->text('Item not on file!').qq|

<p>
|.$locale->text('What type of item is this?').qq|</h4>

<form method=post action=ic.pl>

<p>

  <input class=radio type=radio name=item value=part checked>&nbsp;|.$locale->text('Part')
.qq|<br>
  <input class=radio type=radio name=item value=service>&nbsp;|.$locale->text('Service')

.qq|
<input type=hidden name=previous_form value="$previous_form">
<input type=hidden name=partnumber value="$form->{"partnumber_$i"}">
<input type=hidden name=description value="$form->{"description_$i"}">
<input type=hidden name=rowcount value=$form->{rowcount}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input type=hidden name=nextsub value=add>

<p>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}



sub display_form {

  &form_header;

  $numrows = ++$form->{rowcount};
  $subroutine = "display_row";

  if ($form->{item} eq 'part') {
    $numrows = ++$form->{makemodel_rows};
    $subroutine = "makemodel_row";
  }
  if ($form->{item} eq 'assembly') {
    $numrows = ++$form->{makemodel_rows};
    $subroutine = "makemodel_row";
  
    # create makemodel rows
    &{ $subroutine }($numrows);

    $numrows = ++$form->{assembly_rows};
    $subroutine = "assembly_row";
  }
  if ($form->{item} eq 'service') {
    $numrows = 0;
  }

  # create rows
  &{ $subroutine }($numrows) if $numrows;

  &form_footer;

}



sub check_form {
  
  my @a = ();
  my $count = 0;
  my @flds = (qw(id partnumber description qty sellprice unit discount inventory_accno income_accno expense_accno listprice taxaccounts bin assembly weight projectnumber project_id oldprojectnumber runningnumber partsgroup));

  # remove any makes or model rows
  if ($form->{item} eq 'part') {
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(listprice sellprice lastcost weight rop);
    
    @flds = (make, model);
    for my $i (1 .. ($form->{makemodel_rows})) {
      if (($form->{"make_$i"} ne "") || ($form->{"model_$i"} ne "")) {
	push @a, {};
	my $j = $#a;

	map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
	$count++;
      }
    }

    $form->redo_rows(\@flds, \@a, $count, $form->{makemodel_rows});
    $form->{makemodel_rows} = $count;

  } elsif ($form->{item} eq 'assembly') {
    
    $form->{sellprice} = 0;
    $form->{weight} = 0;
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(listprice rop);

    @flds = qw(id qty unit bom partnumber description sellprice weight runningnumber partsgroup);
    
    for my $i (1 .. ($form->{assembly_rows} - 1)) {
      if ($form->{"qty_$i"}) {
	push @a, {};
	my $j = $#a;

        $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});

	map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;

	$form->{sellprice} += ($form->{"qty_$i"} * $form->{"sellprice_$i"});
	$form->{weight} += ($form->{"qty_$i"} * $form->{"weight_$i"});
	$count++;
      }
    }

    $form->{sellprice} = $form->round_amount($form->{sellprice}, 2);
    
    $form->redo_rows(\@flds, \@a, $count, $form->{assembly_rows});
    $form->{assembly_rows} = $count;
    
    $count = 0;
    @flds = qw(make model);
    @a = ();
    
    for my $i (1 .. ($form->{makemodel_rows})) {
      if (($form->{"make_$i"} ne "") || ($form->{"model_$i"} ne "")) {
	push @a, {};
	my $j = $#a;

	map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
	$count++;
      }
    }

    $form->redo_rows(\@flds, \@a, $count, $form->{makemodel_rows});
    $form->{makemodel_rows} = $count;

  } else {

    # this section applies to invoices and orders
    # remove any empty numbers
    
    if ($form->{rowcount}) {
      for my $i (1 .. $form->{rowcount} - 1) {
	if ($form->{"partnumber_$i"}) {
	  push @a, {};
	  my $j = $#a;

	  map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
	  $count++;
	}
      }
      
      $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
      $form->{rowcount} = $count;

      $form->{creditremaining} -= &invoicetotal;
      
    }
  }

  &display_form;

}


sub invoicetotal {

  $form->{oldinvtotal} = 0;
  # add all parts and deduct paid
  map { $form->{"${_}_base"} = 0 } split / /, $form->{taxaccounts};

  my ($amount, $sellprice, $discount, $qty);
  
  for my $i (1 .. $form->{rowcount}) {
    $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});
    $discount = $form->parse_amount(\%myconfig, $form->{"discount_$i"});
    $qty = $form->parse_amount(\%myconfig, $form->{"qty_$i"});

    $amount = $sellprice * (1 - $discount / 100) * $qty;
    map { $form->{"${_}_base"} += $amount } (split / /, $form->{"taxaccounts_$i"});
    $form->{oldinvtotal} += $amount;
  }

  map { $form->{oldinvtotal} += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{taxaccounts} if !$form->{taxincluded};
  
  $form->{oldtotalpaid} = 0;
  for $i (1 .. $form->{paidaccounts}) {
    $form->{oldtotalpaid} += $form->{"paid_$i"};
  }
  
  # return total
  ($form->{oldinvtotal} - $form->{oldtotalpaid});

}


sub validate_items {
  
  # check if items are valid
  if ($form->{rowcount} == 1) {
    &update;
    exit;
  }
    
  for $i (1 .. $form->{rowcount} - 1) {
    $form->isblank("partnumber_$i", $locale->text('Number missing in Row') . " $i");
  }

}


sub order {

  $form->{ordnumber} = $form->{invnumber};

  $form->{id} = '';

  if ($form->{script} eq 'ir.pl') {
    $form->{title} = $locale->text('Add Purchase Order');
    $form->{vc} = 'vendor';
    $form->{type} = 'purchase_order';
    $buysell = 'sell';
  }
  if ($form->{script} eq 'is.pl') {
    $form->{title} = $locale->text('Add Sales Order');
    $form->{vc} = 'customer';
    $form->{type} = 'sales_order';
    $buysell = 'buy';
  }
  $form->{script} = 'oe.pl';

  $form->{shipto} = 1;
  
  $form->{rowcount}--;

  require "$form->{path}/$form->{script}";

  map { $form->{"select$_"} = "" } ($form->{vc}, currency);
  
  $currency = $form->{currency};
  
  &order_links;

  $form->{currency} = $currency;
  $form->{exchangerate} = "";
  $form->{forex} = "";
  $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{orddate}, $buysell))); 
  
  &prepare_order;
  &display_form;

}


sub e_mail {


  if ($myconfig{admin}) {
    $bcc = qq|
 	  <th align=right nowrap=true>|.$locale->text('Bcc').qq|</th>
	  <td><input name=bcc size=30 value="$form->{bcc}"></td>
|;
  }

  if ($form->{type} eq 'packing_list') {
    $form->{email} = $form->{shiptoemail} if $form->{shiptoemail};
  }

  $name = $form->{$form->{vc}};
  $name =~ s/--.*//g;
  $title = $locale->text('E-mail')." $name";
  
  $form->{oldmedia} = $form->{media};
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
	  <th align=right nowrap>|.$locale->text('To').qq|</th>
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

  $old_form = new Form;
  map { $old_form->{$_} = $form->{$_} } keys %$form;
  $old_form->{media} = $form->{oldmedia};
  &print_form($old_form);
  
}
  

 
sub print_options {

  $form->{sendmode} = "attachment";
  $form->{copies} = 3 unless $form->{copies};
  
  $form->{PD}{$form->{type}} = "checked";
  $form->{DF}{$form->{format}} = "checked";
  $form->{OP}{$form->{media}} = "checked";
  $form->{SM}{$form->{sendmode}} = "checked";
  
  if ($form->{type} =~ /_order/) {
    $order = qq|
	  <td align=right><input class=radio type=radio name=type value="$`_order" $form->{PD}{"$`_order"}></td><td>|.$locale->text('Order').qq|</td>
|;
  } else {
    $invoice = qq|
	  <td align=right><input class=radio type=radio name=type value=invoice $form->{PD}{invoice}></td><td>|.$locale->text('Invoice').qq|</td>
	  <td align=right><input class=radio type=radio name=type value=packing_list $form->{PD}{packing_list}></td><td>|.$locale->text('Packing List').qq|</td>
|;
  }

  if ($form->{media} eq 'email') {
    $email = qq|
	<td align=center><input class=radio type=radio name=sendmode value=attachment $form->{SM}{attachment}> |.$locale->text('Attachment')
	.qq| <input class=radio type=radio name=sendmode value=inline $form->{SM}{inline}> |.$locale->text('In-line').qq|</td>
|;
  } else {
    $screen = qq|
	<td align=right><input class=radio type=radio name=media value=screen $form->{OP}{screen}></td>
	<td>|.$locale->text('Screen').qq|</td>
|;
  }

  print qq|
<table width=100%>
  <tr valign=top>
    $invoice
    $order
    <td align=right><input class=radio type=radio name=format value=html $form->{DF}{html}></td>
    <td>html</td>
|;

  if ($latex) {
      print qq|
    <td align=right><input class=radio type=radio name=format value=postscript $form->{DF}{postscript}></td>
    <td>|.$locale->text('Postscript').qq|</td>
    <td align=right><input class=radio type=radio name=format value=pdf $form->{DF}{pdf}></td>
    <td>|.$locale->text('PDF').qq|</td>
|;
  }

  print qq|
    $screen
|;

  if ($screen) {
    if ($myconfig{printer} && $latex) {
      print qq|
    <td align=right><input class=radio type=radio name=media value=printer $form->{OP}{printer}></td>
    <td>|.$locale->text('Printer')
    .qq| (|.$locale->text('Copies')
    .qq| <input name=copies size=2 value=$form->{copies}>)</td>
|;
    }
  }

  
  $form->{groupitems} = "checked" if $form->{groupitems};
  
  print qq|
    $email
    <td align=right><input name=groupitems type=checkbox class=checkbox $form->{groupitems}></td>
    <td>|.$locale->text('Group Items').qq|</td>
  </tr>
</table>
|;

}


sub print {
  
  # if this goes to the printer pass through
  if ($form->{media} eq 'printer') {
    $form->error($locale->text('Select postscript or PDF!')) if ($form->{format} !~ /(postscript|pdf)/);

    $old_form = new Form;
    map { $old_form->{$_} = $form->{$_} } keys %$form;
  }

  &print_form($old_form);

}


sub print_form {
  my $old_form = shift;
  
  $inv = "inv";
  $due = "due";

  if ($form->{type} eq "invoice") {
    $form->{label} = $locale->text('Invoice');
  }
  if ($form->{type} eq "packing_list") {
    $form->{label} = $locale->text('Packing List');
  }
  if ($form->{type} eq 'sales_order') {
    $inv = "ord";
    $due = "req";
    $form->{label} = $locale->text('Sales Order');
  }
  if ($form->{type} eq 'purchase_order') {
    $inv = "ord";
    $due = "req";
    $form->{label} = $locale->text('Purchase Order');
  }

  $form->isblank("email", $locale->text('E-mail address missing!')) if ($form->{media} eq 'email');
  $form->isblank("${inv}number", $locale->text($form->{label} .' Number missing!'));
  $form->isblank("${inv}date", $locale->text($form->{label} .' Date missing!'));

# $locale->text('Invoice Number missing!')
# $locale->text('Invoice Date missing!')
# $locale->text('Packing List Number missing!')
# $locale->text('Packing List Date missing!')
# $locale->text('Order Number missing!')
# $locale->text('Order Date missing!')

  &validate_items;

  &{ "$form->{vc}_details" };

  @a = ();
  map { push @a, ("partnumber_$_", "description_$_") } (1 .. $form->{rowcount});
  map { push @a, "${_}_description" } split / /, $form->{taxaccounts};
  $form->format_string(@a);

  # format payment dates
  map { $form->{"datepaid_$_"} = $locale->date(\%myconfig, $form->{"datepaid_$_"}) } (1 .. $form->{paidaccounts});
  
  # create the form variables for the invoice, packing list or order
  if ($form->{type} =~ /order$/) {
    OE->order_details(\%myconfig, \%$form);
  } else {
    IS->invoice_details(\%myconfig, \%$form);
  }

  $form->{"${inv}date"} = $locale->date(\%myconfig, $form->{"${inv}date"}, 1);
  $form->{"${due}date"} = $locale->date(\%myconfig, $form->{"${due}date"}, 1);
  
  
  @a = qw(name addr1 addr2 addr3 addr4);
 
  $fillshipto = 1;
  # if there is no shipto fill it in from billto
  foreach $item (@a) {
    if ($form->{"shipto$item"}) {
      $fillshipto = 0;
      last;
    }
  }

  if ($fillshipto) {
    if ($form->{type} eq 'purchase_order') {
	$form->{shiptoname} = $myconfig{company};
	$form->{shiptoaddr1} = $myconfig{address};
    } else {
      map { $form->{"shipto$_"} = $form->{$_} } @a;
    }
  }

  $form->{notes} =~ s/^\s+//g;

  # some of the stuff could have umlauts so we translate them
  push @a, qw(shiptoname shiptoaddr1 shiptoaddr2 shiptoaddr3 shiptoaddr4 shippingpoint company address signature notes);

  push @a, ("${inv}date", "${due}date");
  
  $form->format_string(@a);


  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = "$form->{type}.html";

  if ($form->{format} eq 'postscript') {
    $form->{postscript} = 1;
    $form->{IN} =~ s/html$/tex/;
  }
  if ($form->{format} eq 'pdf') {
    $form->{pdf} = 1;
    $form->{IN} =~ s/html$/tex/;
  }

  $form->format_string(email, shiptoemail, cc, bcc) if $form->{format} =~ /(pdf|postscript)/;
  
  if ($form->{media} eq 'printer') {
    $form->{OUT} = "| $myconfig{printer}";
  }

  if ($form->{media} eq 'email') {
    $form->{subject} = qq|$form->{label} $form->{"${inv}number"}| unless $form->{subject};
    
    $form->{OUT} = "$sendmail";
  }
  

  $form->parse_template(\%myconfig, $userspath);

  $form->{callback} = "";
  
  # if we got back here restore the previous form
  if ($form->{media} =~ /(printer|email)/) {
    if ($old_form) {
      # restore and display form
      map { $form->{$_} = $old_form->{$_} } keys %$old_form;
      $form->{rowcount}--;
      map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate creditlimit creditremaining);

      for $i (1 .. $form->{paidaccounts}) {
	map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);
      }
      
      &display_form;
      exit;
    }

    $msg = ($form->{media} eq 'printer') ? $locale->text('sent to printer') : $locale->text('emailed to')." $form->{email}";
    $form->redirect(qq|$form->{label} $form->{"${inv}number"} $msg|);
  }

}


sub customer_details {

  IS->customer_details(\%myconfig, \%$form);

}


sub vendor_details {

  IR->vendor_details(\%myconfig, \%$form);

}


sub post_as_new {

  $form->{postasnew} = 1;
  &post;

}


sub ship_to {

  $title = $form->{title};
  $form->{title} = $locale->text('Ship to');
  
  $form->{rowcount}--;

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate creditlimit creditremaining);

  # get details for name
  &{ "$form->{vc}_details" };

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <td>
      <table>
	<tr class=listheading>
	  <th class=listheading colspan=2 width=50%>|.$locale->text('To').qq|</th>
	  <th class=listheading width=50%>|.$locale->text('Ship to').qq|</th>
	</tr>
	<tr height="5"></tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Number').qq|</th>
	  <td>$form->{"$form->{vc}number"}</td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Name').qq|</th>
	  <td>$form->{name}</td>
	  <td><input name=shiptoname size=35 maxsize=35 value="$form->{shiptoname}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Address').qq|</th>
	  <td>$form->{addr1}</td>
	  <td><input name=shiptoaddr1 size=35 maxsize=35 value="$form->{shiptoaddr1}"></td>
	</tr>
	<tr>
	  <th></th>
	  <td>$form->{addr2}</td>
	  <td><input name=shiptoaddr2 size=35 maxsize=35 value="$form->{shiptoaddr2}"></td>
	</tr>
	<tr>
	  <th></th>
	  <td>$form->{addr3}</td>
	  <td><input name=shiptoaddr3 size=35 maxsize=35 value="$form->{shiptoaddr3}"></td>
	</tr>
	<tr>
	  <th></th>
	  <td>$form->{addr4}</td>
	  <td><input name=shiptoaddr4 size=35 maxsize=35 value="$form->{shiptoaddr4}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Contact').qq|</th>
	  <td>$form->{contact}</td>
	  <td><input name=shiptocontact size=35 maxsize=35 value="$form->{shiptocontact}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Phone').qq|</th>
	  <td>$form->{"$form->{vc}phone"}</td>
	  <td><input name=shiptophone size=20 maxsize=20 value="$form->{shiptophone}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Fax').qq|</th>
	  <td>$form->{"$form->{vc}fax"}</td>
	  <td><input name=shiptofax size=20 maxsize=20 value="$form->{shiptofax}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('E-mail').qq|</th>
	  <td>$form->{email}</td>
	  <td><input name=shiptoemail size=35 value="$form->{shiptoemail}"></td>
	</tr>
      </table>
    </td>
  </tr>
</table>
|;

  # delete shipto
  map { delete $form->{$_} } qw(shiptoname shiptoaddr1 shiptoaddr2 shiptoaddr3 shiptoaddr4 shiptocontact shiptophone shiptofax shiptoemail);
  $form->{title} = $title;
  
  foreach $key (keys %$form) {
    $form->{$key} =~ s/"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|

<input type=hidden name=nextsub value=display_form>

<hr size=3 noshade>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}


