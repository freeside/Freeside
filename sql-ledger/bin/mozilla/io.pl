######################################################################
# SQL-Ledger, Accounting
# Copyright (c) 2002
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

  @column_index = qw(runningnumber partnumber description qty);

  if ($form->{type} eq "sales_order") {
    push @column_index, "ship";
    $column_data{ship} = qq|<th class=listheading align=center width="auto">|.$locale->text('Ship').qq|</th>|;
  }
  if ($form->{type} eq "purchase_order") {
    push @column_index, "ship";
    $column_data{ship} = qq|<th class=listheading align=center width="auto">|.$locale->text('Recd').qq|</th>|;
  }

  foreach $item (qw(projectnumber partsgroup)) {
    $form->{"select$item"} = $form->unescape($form->{"select$item"}) if $form->{"select$item"};
  }
      
  if ($form->{language_code} ne $form->{oldlanguage_code}) {
    # rebuild partsgroup
    $form->get_partsgroup(\%myconfig, { language_code => $form->{language_code} });
    if (@ { $form->{all_partsgroup} }) {
      $form->{selectpartsgroup} = "<option>\n";
      foreach $ref (@ { $form->{all_partsgroup} }) {
	if ($ref->{translation}) {
	  $form->{selectpartsgroup} .= qq|<option value="$ref->{partsgroup}--$ref->{id}">$ref->{translation}\n|;
	} else {
	  $form->{selectpartsgroup} .= qq|<option value="$ref->{partsgroup}--$ref->{id}">$ref->{partsgroup}\n|;
	}
      }
    }
    $form->{oldlanguage_code} = $form->{language_code};
  }
      

  push @column_index, qw(unit sellprice discount linetotal);

  my $colspan = $#column_index + 1;

  $form->{invsubtotal} = 0;
  map { $form->{"${_}_base"} = 0 } (split / /, $form->{taxaccounts});
  
  $column_data{runningnumber} = qq|<th class=listheading nowrap>|.$locale->text('No.').qq|</th>|;
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


  $deliverydate = $locale->text('Delivery Date');
  $serialnumber = $locale->text('Serial No.');
  $projectnumber = $locale->text('Project');
  $group = $locale->text('Group');
  $sku = $locale->text('SKU');

  $delvar = 'deliverydate';
  
  if ($form->{type} =~ /_(order|quotation)$/) {
    $reqdate = $locale->text('Required by');
    $delvar = 'reqdate';
  }

  $exchangerate = $form->parse_amount(\%myconfig, $form->{exchangerate});
  $exchangerate = ($exchangerate) ? $exchangerate : 1;

  for $i (1 .. $numrows) {
    # undo formatting
    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(qty ship discount sellprice);
    
    ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec = length $dec;
    $decimalplaces = ($dec > 2) ? $dec : 2;

    if (($form->{"qty_$i"} != $form->{"oldqty_$i"}) || ($form->{currency} ne $form->{oldcurrency})) {
      # check for a pricematrix
      @a = split / /, $form->{"pricematrix_$i"};
      if ((scalar @a) > 2 || $form->{currency} ne $form->{oldcurrency}) {
	foreach $item (@a) {
	  ($q, $p) = split /:/, $item;
	  if ($p != 0 && $form->{"qty_$i"} > $q) {
	    $form->{"sellprice_$i"} = $form->round_amount($p / $exchangerate, $decimalplaces);
	  }
	}
      }
    }
    
    $discount = $form->round_amount($form->{"sellprice_$i"} * $form->{"discount_$i"}/100, $decimalplaces);
    $linetotal = $form->round_amount($form->{"sellprice_$i"} - $discount, $decimalplaces);
    $linetotal = $form->round_amount($linetotal * $form->{"qty_$i"}, 2);

    map { $form->{"${_}_$i"} = $form->quote($form->{"${_}_$i"}) } qw(partnumber sku description unit);
    
    $skunumber = qq|
                <p><b>$sku</b> $form->{"sku_$i"}| if ($form->{vc} eq 'vendor' && $form->{"sku_$i"});

    
    if ($form->{selectpartsgroup}) {
      if ($i < $numrows) {
	$partsgroup = qq|
	      <p><b>$group</b>
	      <input type=hidden name="partsgroup_$i" value="$form->{"partsgroup_$i"}">|;
	($form->{"partsgroup_$i"}) = split /--/, $form->{"partsgroup_$i"};
	$partsgroup .= $form->{"partsgroup_$i"};
	$partsgroup = "" unless $form->{"partsgroup_$i"};
      }
    }
    
    $delivery = qq|
	  <b>${$delvar}</b>
	  <input name="${delvar}_$i" size=11 title="$myconfig{dateformat}" value="$form->{"${delvar}_$i"}">
|;

    $column_data{runningnumber} = qq|<td><input name="runningnumber_$i" size=3 value=$i></td>|;
    $column_data{partnumber} = qq|<td><input name="partnumber_$i" size=15 value="$form->{"partnumber_$i"}">$skunumber</td>|;

    if (($rows = $form->numtextrows($form->{"description_$i"}, 25, 6)) > 1) {
      $column_data{description} = qq|<td><textarea name="description_$i" rows=$rows cols=25 wrap=soft>$form->{"description_$i"}</textarea>$partsgroup</td>|;
    } else {
      $column_data{description} = qq|<td><input name="description_$i" size=30 value="$form->{"description_$i"}">$partsgroup</td>|;
    }

    $column_data{qty} = qq|<td align=right><input name="qty_$i" size=5 value=|.$form->format_amount(\%myconfig, $form->{"qty_$i"}).qq|></td>|;
    $column_data{ship} = qq|<td align=right><input name="ship_$i" size=5 value=|.$form->format_amount(\%myconfig, $form->{"ship_$i"}).qq|></td>|;
    $column_data{unit} = qq|<td><input name="unit_$i" size=5 value="$form->{"unit_$i"}"></td>|;
    $column_data{sellprice} = qq|<td align=right><input name="sellprice_$i" size=9 value=|.$form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces).qq|></td>|;
    $column_data{discount} = qq|<td align=right><input name="discount_$i" size=3 value=|.$form->format_amount(\%myconfig, $form->{"discount_$i"}).qq|></td>|;
    $column_data{linetotal} = qq|<td align=right>|.$form->format_amount(\%myconfig, $linetotal, 2).qq|</td>|;
    $column_data{bin} = qq|<td>$form->{"bin_$i"}</td>|;
    
    print qq|
        <tr valign=top>|;

    map { print "\n$column_data{$_}" } @column_index;
  
    print qq|
        </tr>

<input type=hidden name="orderitems_id_$i" value=$form->{"orderitems_id_$i"}>

<input type=hidden name="id_$i" value=$form->{"id_$i"}>
<input type=hidden name="inventory_accno_$i" value=$form->{"inventory_accno_$i"}>
<input type=hidden name="bin_$i" value="$form->{"bin_$i"}">
<input type=hidden name="weight_$i" value="$form->{"weight_$i"}">
<input type=hidden name="income_accno_$i" value=$form->{"income_accno_$i"}>
<input type=hidden name="expense_accno_$i" value=$form->{"expense_accno_$i"}>
<input type=hidden name="listprice_$i" value="$form->{"listprice_$i"}">
<input type=hidden name="assembly_$i" value="$form->{"assembly_$i"}">
<input type=hidden name="taxaccounts_$i" value="$form->{"taxaccounts_$i"}">
<input type=hidden name="pricematrix_$i" value="$form->{"pricematrix_$i"}">
<input type=hidden name="oldqty_$i" value="$form->{"qty_$i"}">
<input type=hidden name="sku_$i" value="$form->{"sku_$i"}">

|;

    $form->{selectprojectnumber} =~ s/ selected//;
    $form->{selectprojectnumber} =~ s/(<option value="\Q$form->{"projectnumber_$i"}\E")/$1 selected/;

    $project = qq|
                <b>$projectnumber</b>
		<select name="projectnumber_$i">$form->{selectprojectnumber}</select>
| if $form->{selectprojectnumber};

    $serial = qq|
                <b>$serialnumber</b> <input name="serialnumber_$i" size=15 value="$form->{"serialnumber_$i"}">| if $form->{type} !~ /_quotation/;
		
    $partsgroup = "";
    if ($i == $numrows) {
      if ($form->{selectpartsgroup}) {
	$partsgroup = qq|
	        <b>$group</b>
		<select name="partsgroup_$i">$form->{selectpartsgroup}</select>
|;
      }

      $serial = "";
      $project = "";
      $delivery = ""
    }

	
    # print second row
    print qq|
        <tr>
	  <td colspan=$colspan>
	  $delivery
	  $serial
	  $project
	  $partsgroup
	  </td>
	</tr>
	<tr>
	  <td colspan=$colspan><hr size=1 noshade></td>
	</tr>
|;

    $skunumber = "";
    
    map { $form->{"${_}_base"} += $linetotal } (split / /, $form->{"taxaccounts_$i"});
  
    $form->{invsubtotal} += $linetotal;
  }

  print qq|
      </table>
    </td>
  </tr>
|;

  print qq|

<input type=hidden name=oldcurrency value=$form->{currency}>
<input type=hidden name=audittrail value="$form->{audittrail}">

<input type=hidden name=selectpartsgroup value="|.$form->escape($form->{selectpartsgroup},1).qq|">
<input type=hidden name=selectprojectnumber value="|.$form->escape($form->{selectprojectnumber},1).qq|">
|;
 
}


sub select_item {

  if ($form->{vc} eq "vendor") {
    @column_index = qw(ndx partnumber sku description partsgroup onhand sellprice);
  } else {
    @column_index = qw(ndx partnumber description partsgroup onhand sellprice);
  }

  $column_data{ndx} = qq|<th>&nbsp;</th>|;
  $column_data{partnumber} = qq|<th class=listheading>|.$locale->text('Number').qq|</th>|;
  $column_data{sku} = qq|<th class=listheading>|.$locale->text('SKU').qq|</th>|;
  $column_data{description} = qq|<th class=listheading>|.$locale->text('Description').qq|</th>|;
  $column_data{partsgroup} = qq|<th class=listheading>|.$locale->text('Group').qq|</th>|;
  $column_data{sellprice} = qq|<th class=listheading>|.$locale->text('Price').qq|</th>|;
  $column_data{onhand} = qq|<th class=listheading>|.$locale->text('Qty').qq|</th>|;
  
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  # list items with radio button on a form
  $form->header;

  $title = $locale->text('Select from one of the items below');

  print qq|
<body>

<form method=post action="$form->{script}#end">

<table width=100%>
  <tr>
    <th class=listtop>$title</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;
  
  print qq|
        </tr>
|;

  my $i = 0;
  foreach $ref (@{ $form->{item_list} }) {
    $checked = ($i++) ? "" : "checked";

    map { $ref->{$_} = $form->quote($ref->{$_}) } qw(sku partnumber description unit);

    $ref->{sellprice} = $form->round_amount($ref->{sellprice} * (1 - $form->{tradediscount}), 2);

    $column_data{ndx} = qq|<td><input name=ndx class=radio type=radio value=$i $checked></td>|;
    $column_data{partnumber} = qq|<td>$ref->{partnumber}</td>|;
    $column_data{sku} = qq|<td>$ref->{sku}</td>|;
    $column_data{description} = qq|<td>$ref->{description}</td>|;
    $column_data{partsgroup} = qq|<td>$ref->{partsgroup}</td>|;
    $column_data{sellprice} = qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{sellprice} / $exchangerate, 2, "&nbsp;").qq|</td>|;
    $column_data{onhand} = qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{onhand}, '', "&nbsp;").qq|</td>|;
    
    $j++; $j %= 2;
    print qq|
        <tr class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>

<input name="new_partnumber_$i" type=hidden value="$ref->{partnumber}">
<input name="new_sku_$i" type=hidden value="$ref->{sku}">
<input name="new_description_$i" type=hidden value="$ref->{description}">
<input name="new_partsgroup_$i" type=hidden value="$ref->{partsgroup}">
<input name="new_partsgroup_id_$i" type=hidden value="$ref->{partsgroup_id}">
<input name="new_bin_$i" type=hidden value="$ref->{bin}">
<input name="new_weight_$i" type=hidden value=$ref->{weight}>
<input name="new_sellprice_$i" type=hidden value=$ref->{sellprice}>
<input name="new_listprice_$i" type=hidden value=$ref->{listprice}>
<input name="new_lastcost_$i" type=hidden value=$ref->{lastcost}>
<input name="new_onhand_$i" type=hidden value=$ref->{onhand}>
<input name="new_inventory_accno_$i" type=hidden value=$ref->{inventory_accno}>
<input name="new_income_accno_$i" type=hidden value=$ref->{income_accno}>
<input name="new_expense_accno_$i" type=hidden value=$ref->{expense_accno}>
<input name="new_unit_$i" type=hidden value="$ref->{unit}">
<input name="new_weight_$i" type=hidden value="$ref->{weight}">
<input name="new_assembly_$i" type=hidden value="$ref->{assembly}">
<input name="new_taxaccounts_$i" type=hidden value="$ref->{taxaccounts}">
<input name="new_pricematrix_$i" type=hidden value="$ref->{pricematrix}">

<input name="new_id_$i" type=hidden value=$ref->{id}>

|;

  }
  
  print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input name=lastndx type=hidden value=$i>

|;

  # delete action variable
  map { delete $form->{$_} } qw(action item_list header);

  $form->hide_form();
  
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
  
  map { $form->{"${_}_$i"} = $form->{"new_${_}_$j"} } qw(id partnumber sku description sellprice listprice lastcost inventory_accno income_accno expense_accno bin unit weight assembly taxaccounts pricematrix);

  $form->{"partsgroup_$i"} = qq|$form->{"new_partsgroup_$j"}--$form->{"new_partsgroup_id_$j"}|;

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

  if (($form->{exchangerate} * 1) != 0) {
    map { $form->{"${_}_$i"} /= $form->{exchangerate} } qw(listprice lastcost);
  }
  
  # this is for the assembly
  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(sellprice listprice weight);

  $form->{sellprice} += ($form->{"sellprice_$i"} * $form->{"qty_$i"});
  $form->{weight} += ($form->{"weight_$i"} * $form->{"qty_$i"});

  $amount = $form->{"sellprice_$i"} * (1 - $form->{"discount_$i"} / 100) * $form->{"qty_$i"};
  map { $form->{"${_}_base"} += $amount } (split / /, $form->{"taxaccounts_$i"});
  map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{"taxaccounts_$i"} if !$form->{taxincluded};

  $form->{creditremaining} -= $amount;

  $form->{"runningnumber_$i"} = $i;
  
  # delete all the new_ variables
  for $i (1 .. $form->{lastndx}) {
    map { delete $form->{"new_${_}_$i"} } qw(partnumber sku description sellprice bin listprice lastcost inventory_accno income_accno expense_accno unit assembly taxaccounts id pricematrix weight);
  }
  
  map { delete $form->{$_} } qw(ndx lastndx nextsub);

  # format amounts
  map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, $decimalplaces) } qw(sellprice listprice lastcost) if $form->{item} ne 'assembly';

  &display_form;

}


sub new_item {

  if ($form->{language_code} && $form->{"description_$form->{rowcount}"}) {
    $form->error($locale->text('Translation not on file!'));
  }
  
  # change callback
  $form->{old_callback} = $form->escape($form->{callback},1);
  $form->{callback} = $form->escape("$form->{script}?action=display_form",1);

  # delete action
  delete $form->{action};

  # save all other form variables in a previousform variable
  if (!$form->{previousform}) {
    foreach $key (keys %$form) {
      # escape ampersands
      $form->{$key} =~ s/&/%26/g;
      $form->{previousform} .= qq|$key=$form->{$key}&|;
    }
    chop $form->{previousform};
    $form->{previousform} = $form->escape($form->{previousform}, 1);
  }

  $i = $form->{rowcount};
  map { $form->{"${_}_$i"} = $form->quote($form->{"${_}_$i"}) } qw(partnumber description);

  $form->header;

  print qq|
<body>

<h4 class=error>|.$locale->text('Item not on file!').qq|</h4>|;

  if ($myconfig{acs} !~ /(Goods \& Services--Add Part|Goods \& Services--Add Service)/) {

    print qq|
<h4>|.$locale->text('What type of item is this?').qq|</h4>

<form method=post action=ic.pl>

<p>

  <input class=radio type=radio name=item value=part checked>&nbsp;|.$locale->text('Part')
.qq|<br>
  <input class=radio type=radio name=item value=service>&nbsp;|.$locale->text('Service')

.qq|
<input type=hidden name=previousform value="$form->{previousform}">
<input type=hidden name=partnumber value="$form->{"partnumber_$i"}">
<input type=hidden name=description value="$form->{"description_$i"}">
<input type=hidden name=rowcount value=$form->{rowcount}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input type=hidden name=nextsub value=add>

<p>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>
|;
  }

  print qq|
</body>
</html>
|;

}



sub display_form {

  # if we have a display_form
  if ($form->{display_form}) {
    &{ "$form->{display_form}" };
    exit;
  }
  
  &form_header;

  $numrows = ++$form->{rowcount};
  $subroutine = "display_row";

  if ($form->{item} eq 'part') {
    # create makemodel rows
    &makemodel_row(++$form->{makemodel_rows});

    &vendor_row(++$form->{vendor_rows});
    
    $numrows = ++$form->{customer_rows};
    $subroutine = "customer_row";
  }
  if ($form->{item} eq 'assembly') {
    # create makemodel rows
    &makemodel_row(++$form->{makemodel_rows});
    
    $numrows = ++$form->{customer_rows};
    $subroutine = "customer_row";
  }
  if ($form->{item} eq 'service') {
    &vendor_row(++$form->{vendor_rows});
    
    $numrows = ++$form->{customer_rows};
    $subroutine = "customer_row";
  }
  if ($form->{item} eq 'labor') {
    $numrows = 0;
  }

  # create rows
  &{ $subroutine }($numrows) if $numrows;

  &form_footer;

}



sub check_form {
  
  my @a = ();
  my $count = 0;
  my $i;
  my $j;
  my @flds = qw(id partnumber sku description qty ship sellprice unit discount inventory_accno income_accno expense_accno listprice taxaccounts bin assembly weight projectnumber runningnumber serialnumber partsgroup reqdate pricematrix);

  # remove any makes or model rows
  if ($form->{item} eq 'part') {
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(listprice sellprice lastcost weight rop markup);
    
    &calc_markup;
    
    @flds = qw(make model);
    $count = 0;
    @a = ();
    for $i (1 .. $form->{makemodel_rows}) {
      if (($form->{"make_$i"} ne "") || ($form->{"model_$i"} ne "")) {
	push @a, {};
	$j = $#a;

	map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
	$count++;
      }
    }

    $form->redo_rows(\@flds, \@a, $count, $form->{makemodel_rows});
    $form->{makemodel_rows} = $count;

    &check_vendor;
    &check_customer;
    
  } elsif ($form->{item} eq 'service') {
    
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(sellprice listprice lastcost markup);
    
    &calc_markup;
    &check_vendor;
    &check_customer;
    
  } elsif ($form->{item} eq 'assembly') {

    $form->{sellprice} = 0;
    $form->{weight} = 0;
    $form->{lastcost} = 0;
    $form->{listprice} = 0;
    
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(rop stock markup);

   
    @flds = qw(id qty unit bom adj partnumber description sellprice listprice weight runningnumber partsgroup);
    $count = 0;
    @a = ();
    
    for my $i (1 .. ($form->{assembly_rows} - 1)) {
      if ($form->{"qty_$i"}) {
	push @a, {};
	my $j = $#a;

        $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});

	map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;

        map { $form->{$_} += ($form->{"${_}_$i"} * $form->{"qty_$i"}) } qw(sellprice listprice weight lastcost);
	
	$count++;
      }
    }

    if ($form->{markup} && $form->{markup} != $form->{oldmarkup}) {
      $form->{sellprice} = 0;
      &calc_markup;
    }
 
    map { $form->{$_} = $form->round_amount($form->{$_}, 2) } qw(sellprice lastcost listprice);
    
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

    &check_customer;
  
  } else {

    # this section applies to invoices and orders
    # remove any empty numbers
    
    $count = 0;
    @a = ();
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


sub calc_markup {

  if ($form->{markup}) {
    if ($form->{markup} != $form->{oldmarkup}) {
      if ($form->{lastcost}) {
	$form->{sellprice} = $form->{lastcost} * (1 + $form->{markup}/100);
	$form->{sellprice} = $form->round_amount($form->{sellprice}, 2);
      } else {
	$form->{lastcost} = $form->{sellprice} / (1 + $form->{markup}/100);
	$form->{lastcost} = $form->round_amount($form->{lastcost}, 2);
      }
    }
  } else {
    if ($form->{lastcost}) {
      $form->{markup} = $form->round_amount(((1 - $form->{sellprice} / $form->{lastcost}) * 100), 1);
    }
    $form->{markup} = "" if $form->{markup} == 0;
  }

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



sub purchase_order {
  
  $form->{title} = $locale->text('Add Purchase Order');
  $form->{vc} = 'vendor';
  $form->{type} = 'purchase_order';
  $buysell = 'sell';

  &create_form;

}

 
sub sales_order {

  $form->{title} = $locale->text('Add Sales Order');
  $form->{vc} = 'customer';
  $form->{type} = 'sales_order';
  $buysell = 'buy';

  &create_form;

}


sub rfq {
  
  $form->{title} = $locale->text('Add Request for Quotation');
  $form->{vc} = 'vendor';
  $form->{type} = 'request_quotation';
  $buysell = 'sell';
 
  &create_form;
  
}


sub quotation {

  $form->{title} = $locale->text('Add Quotation');
  $form->{vc} = 'customer';
  $form->{type} = 'sales_quotation';
  $buysell = 'buy';

  &create_form;

}


sub create_form {

  map { delete $form->{$_} } qw(id printed emailed queued);
 
  $form->{script} = 'oe.pl';

  $form->{shipto} = 1;

  $form->{rowcount}-- if $form->{rowcount};

  require "$form->{path}/$form->{script}";

  map { $form->{"select$_"} = "" } ($form->{vc}, currency);
  
  map { $temp{$_} = $form->{$_} } qw(currency employee department intnotes notes language_code);

  &order_links;

  map { $form->{$_} = $temp{$_} if $temp{$_} } keys %temp;

  $form->{exchangerate} = "";
  $form->{forex} = "";
  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, $buysell)));
  }
  
  &prepare_order;

  &display_form;

}



sub e_mail {

  $bcc = qq|<input type=hidden name=bcc value="$form->{bcc}">|;
  if ($myconfig{role} =~ /(admin|manager)/) {
    $bcc = qq|
 	  <th align=right nowrap=true>|.$locale->text('Bcc').qq|</th>
	  <td><input name=bcc size=30 value="$form->{bcc}"></td>
|;
  }

  if ($form->{formname} =~ /(pick|packing|bin)_list/) {
    $form->{email} = $form->{shiptoemail} if $form->{shiptoemail};
  }

  $name = $form->{$form->{vc}};
  $name =~ s/--.*//g;
  $title = $locale->text('E-mail')." $name";
  
  $form->header;

  print qq|
<body>

<form method=post action="$form->{script}#end">

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

  $form->{oldmedia} = $form->{media};
  $form->{media} = "email";
  $form->{format} = "pdf";
  
  &print_options;
  
  map { delete $form->{$_} } qw(action email cc bcc subject message formname sendmode format header);
  
  $form->hide_form();

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
  $old_form->{media} = $old_form->{oldmedia};
  
  &print_form($old_form);
  
}
  

 
sub print_options {

  $form->{sendmode} = "attachment";
  $form->{copies} = 1 unless $form->{copies};
  
  $form->{PD}{$form->{formname}} = "selected";
  $form->{DF}{$form->{format}} = "selected";
  $form->{SM}{$form->{sendmode}} = "selected";
  
  if ($form->{selectlanguage}) {
    $form->{"selectlanguage"} = $form->unescape($form->{"selectlanguage"});
    $form->{"selectlanguage"} =~ s/ selected//;
    $form->{"selectlanguage"} =~ s/(<option value="\Q$form->{language_code}\E")/$1 selected/;
    $lang = qq|<td><select name=language_code>$form->{selectlanguage}</select></td>
    <input type=hidden name=oldlanguage_code value=$form->{oldlanguage_code}>
    <input type=hidden name=selectlanguage value="|.
    $form->escape($form->{selectlanguage},1).qq|">|;
  }
  
  if ($form->{type} eq 'purchase_order') {
    $type = qq|<td><select name=formname>
	    <option value=purchase_order $form->{PD}{purchase_order}>|.$locale->text('Purchase Order').qq|
	    <option value=bin_list $form->{PD}{bin_list}>|.$locale->text('Bin List').qq|</select></td>|;
  }
  
  if ($form->{type} eq 'sales_order') {
    $type = qq|<td><select name=formname>
	    <option value=sales_order $form->{PD}{sales_order}>|.$locale->text('Sales Order').qq|
	    <option value=work_order $form->{PD}{work_order}>|.$locale->text('Work Order').qq|
	    <option value=pick_list $form->{PD}{pick_list}>|.$locale->text('Pick List').qq|
	    <option value=packing_list $form->{PD}{packing_list}>|.$locale->text('Packing List').qq|</select></td>|;
  }
  
  if ($form->{type} =~ /_quotation$/) {
    $type = qq|<td><select name=formname>
	    <option value="$`_quotation" $form->{PD}{"$`_quotation"}>|.$locale->text('Quotation').qq|</select></td>|;
  }
  
  if ($form->{type} eq 'invoice') {
    $type = qq|<td><select name=formname>
	    <option value=invoice $form->{PD}{invoice}>|.$locale->text('Invoice').qq|
	    <option value=pick_list $form->{PD}{pick_list}>|.$locale->text('Pick List').qq|
	    <option value=packing_list $form->{PD}{packing_list}>|.$locale->text('Packing List').qq|</select></td>|;
  }
  
  if ($form->{type} eq 'ship_order') {
    $type = qq|<td><select name=formname>
	    <option value=pick_list $form->{PD}{pick_list}>|.$locale->text('Pick List').qq|
	    <option value=packing_list $form->{PD}{packing_list}>|.$locale->text('Packing List').qq|</select></td>|;
  }
  
  if ($form->{type} eq 'receive_order') {
    $type = qq|<td><select name=formname>
	    <option value=bin_list $form->{PD}{bin_list}>|.$locale->text('Bin List').qq|</select></td>|;
  }
 
  if ($form->{media} eq 'email') {
    $media = qq|<td><select name=sendmode>
	    <option value=attachment $form->{SM}{attachment}>|.$locale->text('Attachment').qq|
	    <option value=inline $form->{SM}{inline}>|.$locale->text('In-line').qq|</select></td>|;
  } else {
    $media = qq|<td><select name=media>
	    <option value=screen>|.$locale->text('Screen');
    if (%printer && $latex) {
      map { $media .= qq|
            <option value="$_">$_| } sort keys %printer;
    }
    if ($latex) {
      $media .= qq|
            <option value="queue">|.$locale->text('Queue');
    }
    $media .= qq|</select></td>|;

    # set option selected
    $media =~ s/(<option value="\Q$form->{media}\E")/$1 selected/;
 
  }

  $format = qq|<td><select name=format>
            <option value=html $form->{DF}{html}>html|;

#	    <option value=txt $form->{DF}{txt}>txt|;

  if ($latex) {
    $format .= qq|
            <option value=postscript $form->{DF}{postscript}>|.$locale->text('Postscript').qq|
	    <option value=pdf $form->{DF}{pdf}>|.$locale->text('PDF');
  }
  $format .= qq|</select></td>|;

  print qq|
<table width=100% cellspacing=0 cellpadding=0>
  <tr>
    <td>
      <table>
	<tr>
	  $type
	  $lang
	  $format
	  $media
|;

  if (%printer && $latex && $form->{media} ne 'email') {
    print qq|
	  <td>|.$locale->text('Copies').qq|
	  <input name=copies size=2 value=$form->{copies}></td>
|;
  }

  $form->{groupprojectnumber} = "checked" if $form->{groupprojectnumber};
  $form->{grouppartsgroup} = "checked" if $form->{grouppartsgroup};

  print qq|
          <td>|.$locale->text('Group Items').qq|</td>
          <td>
	  <input name=groupprojectnumber type=checkbox class=checkbox $form->{groupprojectnumber}>
	  |.$locale->text('Project').qq|
	  <input name=grouppartsgroup type=checkbox class=checkbox $form->{grouppartsgroup}>
	  |.$locale->text('Group').qq|
	  </td>
        </tr>
      </table>
    </td>
    <td align=right>
|;

  if ($form->{printed} =~ /$form->{formname}/) {
    print $locale->text('Printed').qq|<br>|;
  }
  
  if ($form->{emailed} =~ /$form->{formname}/) {
    print $locale->text('E-mailed').qq|<br>|;
  }
  
  if ($form->{queued} =~ /$form->{formname}/) {
    print $locale->text('Queued');
  }
  
  print qq|
    </td>
  </tr>
</table>
|;


}



sub print {

  # if this goes to the printer pass through
  if ($form->{media} !~ /(screen|email)/) {
    $form->error($locale->text('Select txt, postscript or PDF!')) if ($form->{format} !~ /(txt|postscript|pdf)/);

    $old_form = new Form;
    map { $old_form->{$_} = $form->{$_} } keys %$form;
    
  }
   
  &print_form($old_form);

}


sub print_form {
  my ($old_form) = @_;

  $inv = "inv";
  $due = "due";

  $numberfld = "sinumber";

  $display_form = ($form->{display_form}) ? $form->{display_form} : "display_form";

  if ($form->{formname} eq "invoice") {
    $form->{label} = $locale->text('Invoice');
  }
  if ($form->{formname} eq 'sales_order') {
    $inv = "ord";
    $due = "req";
    $form->{label} = $locale->text('Sales Order');
    $numberfld = "sonumber";
    $order = 1;
  }
  if ($form->{formname} eq 'work_order') {
    $inv = "ord";
    $due = "req";
    $form->{label} = $locale->text('Work Order');
    $numberfld = "sonumber";
    $order = 1;
  }
  if ($form->{formname} eq 'packing_list') {
    # we use the same packing list as from an invoice
    $form->{label} = $locale->text('Packing List');

    if ($form->{type} ne 'invoice') {
      $inv = "ord";
      $due = "req";
      $numberfld = "sonumber";
      $order = 1;
    }
  }
  if ($form->{formname} eq 'pick_list') {
    $form->{label} = $locale->text('Pick List');
    if ($form->{type} ne 'invoice') {
      $inv = "ord";
      $due = "req";
      $order = 1;
      $numberfld = "sonumber";
    }
  }
  if ($form->{formname} eq 'purchase_order') {
    $inv = "ord";
    $due = "req";
    $form->{label} = $locale->text('Purchase Order');
    $numberfld = "ponumber";
    $order = 1;
  }
  if ($form->{formname} eq 'bin_list') {
    $inv = "ord";
    $due = "req";
    $form->{label} = $locale->text('Bin List');
    $numberfld = "ponumber";
    $order = 1;
  }
  if ($form->{formname} eq 'sales_quotation') {
    $inv = "quo";
    $due = "req";
    $form->{label} = $locale->text('Quotation');
    $numberfld = "sqnumber";
    $order = 1;
  }
  if ($form->{formname} eq 'request_quotation') {
    $inv = "quo";
    $due = "req";
    $form->{label} = $locale->text('Quotation');
    $numberfld = "rfqnumber";
    $order = 1;
  }
  
  $form->{"${inv}date"} = $form->{transdate};

  $form->isblank("email", $locale->text('E-mail address missing!')) if ($form->{media} eq 'email');
  $form->isblank("${inv}date", $locale->text($form->{label} .' Date missing!'));

  # get next number
  if (! $form->{"${inv}number"}) {
    $form->{"${inv}number"} = $form->update_defaults(\%myconfig, $numberfld);
    if ($form->{media} eq 'screen') {
      &update;
      exit;
    }
  }


# $locale->text('Invoice Number missing!')
# $locale->text('Invoice Date missing!')
# $locale->text('Packing List Number missing!')
# $locale->text('Packing List Date missing!')
# $locale->text('Order Number missing!')
# $locale->text('Order Date missing!')
# $locale->text('Quotation Number missing!')
# $locale->text('Quotation Date missing!')

  &validate_items;

  &{ "$form->{vc}_details" };

  @a = ();
  foreach $i (1 .. $form->{rowcount}) {
    push @a, ("partnumber_$i", "description_$i", "projectnumber_$i", "partsgroup_$i", "serialnumber_$i", "bin_$i", "unit_$i");
  }
  map { push @a, "${_}_description" } split / /, $form->{taxaccounts};

  $ARAP = ($form->{vc} eq 'customer') ? "AR" : "AP";
  push @a, $ARAP;
  
  # format payment dates
  for $i (1 .. $form->{paidaccounts} - 1) {
    if (exists $form->{longformat}) {
      $form->{"datepaid_$i"} = $locale->date(\%myconfig, $form->{"datepaid_$i"}, $form->{longformat});
    }
    
    push @a, "${ARAP}_paid_$i", "source_$i", "memo_$i";
  }
  
  $form->format_string(@a);
  
  ($form->{employee}) = split /--/, $form->{employee};
  ($form->{warehouse}, $form->{warehouse_id}) = split /--/, $form->{warehouse};
  
  # this is a label for the subtotals
  $form->{groupsubtotaldescription} = $locale->text('Subtotal') if not exists $form->{groupsubtotaldescription};
  delete $form->{groupsubtotaldescription} if $form->{deletegroupsubtotal};

  # create the form variables
  if ($order) {
    OE->order_details(\%myconfig, \%$form);
  } else {
    IS->invoice_details(\%myconfig, \%$form);
  }

  if (exists $form->{longformat}) {
    map { $form->{$_} = $locale->date(\%myconfig, $form->{$_}, $form->{longformat}) } ("${inv}date", "${due}date", "shippingdate", "transdate");
  }
  
  @a = qw(name address1 address2 city state zipcode country);
 
  $shipto = 1;
  # if there is no shipto fill it in from billto
  foreach $item (@a) {
    if ($form->{"shipto$item"}) {
      $shipto = 0;
      last;
    }
  }

  if ($shipto) {
    if ($form->{formname} eq 'purchase_order' || $form->{formname} eq 'request_quotation') {
	$form->{shiptoname} = $myconfig{company};
	$form->{shiptoaddress1} = $myconfig{address};
    } else {
      if ($form->{formname} !~ /bin_list/) {
	map { $form->{"shipto$_"} = $form->{$_} } @a;
      }
    }
  }

  $form->{notes} =~ s/^\s+//g;

  # some of the stuff could have umlauts so we translate them
  push @a, qw(contact shiptoname shiptoaddress1 shiptoaddress2 shiptocity shiptostate shiptozipcode shiptocountry shiptocontact shiptoemail shippingpoint shipvia notes employee warehouse);

  push @a, ("${inv}number", "${inv}date", "${due}date", "email", "cc", "bcc");
  
  map { $form->{$_} = $myconfig{$_} } (qw(company address tel fax signature businessnumber));
  map { $form->{"user$_"} = $myconfig{$_} } qw(name email);
  push @a, qw(company address tel fax signature businessnumber username useremail);

  $form->format_string(@a);


  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = "$form->{formname}.$form->{format}";

  if ($form->{format} =~ /(postscript|pdf)/) {
    $form->{IN} =~ s/$&$/tex/;
  }

  $form->{pre} = "<body bgcolor=#ffffff>\n<pre>" if $form->{format} eq 'txt';

  if ($form->{media} !~ /(screen|queue|email)/) {
    $form->{OUT} = "| $printer{$form->{media}}";
    
    if ($form->{printed} !~ /$form->{formname}/) {
    
      $form->{printed} .= " $form->{formname}";
      $form->{printed} =~ s/^ //;

      $form->update_status(\%myconfig);
    }

    $old_form->{printed} = $form->{printed};

    %audittrail = ( tablename	=> ($order) ? 'oe' : lc $ARAP,
                    reference	=> $form->{"${inv}number"},
		    formname	=> $form->{formname},
		    action	=> 'printed',
		    id		=> $form->{id} );
 
    $old_form->{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);
    
  }


  if ($form->{media} eq 'email') {
    $form->{subject} = qq|$form->{label} $form->{"${inv}number"}| unless $form->{subject};

    $form->{plainpaper} = 1;
    $form->{OUT} = "$sendmail";

    if ($form->{emailed} !~ /$form->{formname}/) {
      $form->{emailed} .= " $form->{formname}";
      $form->{emailed} =~ s/^ //;

      # save status
      $form->update_status(\%myconfig);
    }

    $now = scalar localtime;
    $cc = $locale->text('Cc').qq|: $form->{cc}\n| if $form->{cc};
    $bcc = $locale->text('Bcc').qq|: $form->{bcc}\n| if $form->{bcc};
    
    $old_form->{intnotes} = qq|$old_form->{intnotes}\n\n| if $old_form->{intnotes};
    $old_form->{intnotes} .= qq|[email]
|.$locale->text('Date').qq|: $now
|.$locale->text('To').qq|: $form->{email}
$cc${bcc}|.$locale->text('Subject').qq|: $form->{subject}\n|;

    $old_form->{intnotes} .= qq|\n|.$locale->text('Message').qq|: |;
    $old_form->{intnotes} .= ($form->{message}) ? $form->{message} : $locale->text('sent');

    $old_form->{message} = $form->{message};
    $old_form->{emailed} = $form->{emailed};

    $old_form->{format} = "postscript" if $myconfig{printer};
    $old_form->{media} = $myconfig{printer};

    $old_form->save_intnotes(\%myconfig, ($order) ? 'oe' : lc $ARAP);
    
    %audittrail = ( tablename	=> ($order) ? 'oe' : lc $ARAP,
                    reference	=> $form->{"${inv}number"},
		    formname	=> $form->{formname},
		    action	=> 'emailed',
		    id		=> $form->{id} );
 
    $old_form->{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);
  }


  if ($form->{media} eq 'queue') {
    %queued = split / /, $form->{queued};
    
    if ($filename = $queued{$form->{formname}}) {
      $form->{queued} =~ s/$form->{formname} $filename//;
      unlink "$spool/$filename";
      $filename =~ s/\..*$//g;
    } else {
      $filename = time;
      $filename .= $$;
    }

    $filename .= ($form->{format} eq 'postscript') ? '.ps' : '.pdf';
    $form->{OUT} = ">$spool/$filename";

    $form->{queued} .= " $form->{formname} $filename";
    $form->{queued} =~ s/^ //;

    # save status
    $form->update_status(\%myconfig);

    $old_form->{queued} = $form->{queued};
    
    %audittrail = ( tablename	=> ($order) ? 'oe' : lc $ARAP,
                    reference	=> $form->{"${inv}number"},
		    formname	=> $form->{formname},
		    action	=> 'queued',
		    id		=> $form->{id} );
 
    $old_form->{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);
    
  }


  $form->{fileid} = $form->{"${inv}number"};
  $form->{fileid} =~ s/(\s|\W)+//g;
  
  $form->parse_template(\%myconfig, $userspath);

  # if we got back here restore the previous form
  if ($old_form) {
    
    $old_form->{"${inv}number"} = $form->{"${inv}number"};
    
    # restore and display form
    map { $form->{$_} = $old_form->{$_} } keys %$old_form;
    delete $form->{pre};
    
    $form->{rowcount}--;

    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate creditlimit creditremaining);
    
    for $i (1 .. $form->{paidaccounts}) {
      map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);
    }

    &{ "$display_form" };

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
  map { delete $form->{$_} } qw(printed emailed queued);
  
  &post;

}


sub ship_to {

  $title = $form->{title};
  $form->{title} = $locale->text('Ship to');

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate creditlimit creditremaining);

  # get details for name
  &{ "$form->{vc}_details" };

  $number = ($form->{vc} eq 'customer') ? $locale->text('Customer Number') : $locale->text('Vendor Number');

  $nextsub = ($form->{display_form}) ? $form->{display_form} : "display_form";

  $form->{rowcount}--;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <td>
      <table>
	<tr class=listheading>
	  <th class=listheading colspan=2 width=50%>|.$locale->text('Billing Address').qq|</th>
	  <th class=listheading width=50%>|.$locale->text('Shipping Address').qq|</th>
	</tr>
	<tr height="5"></tr>
	<tr>
	  <th align=right nowrap>$number</th>
	  <td>$form->{"$form->{vc}number"}</td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Company Name').qq|</th>
	  <td>$form->{name}</td>
	  <td><input name=shiptoname size=35 maxlength=64 value="$form->{shiptoname}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Address').qq|</th>
	  <td>$form->{address1}</td>
	  <td><input name=shiptoaddress1 size=35 maxlength=32 value="$form->{shiptoaddress1}"></td>
	</tr>
	<tr>
	  <th></th>
	  <td>$form->{address2}</td>
	  <td><input name=shiptoaddress2 size=35 maxlength=32 value="$form->{shiptoaddress2}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('City').qq|</th>
	  <td>$form->{city}</td>
	  <td><input name=shiptocity size=35 maxlength=32 value="$form->{shiptocity}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('State/Province').qq|</th>
	  <td>$form->{state}</td>
	  <td><input name=shiptostate size=35 maxlength=32 value="$form->{shiptostate}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Zip/Postal Code').qq|</th>
	  <td>$form->{zipcode}</td>
	  <td><input name=shiptozipcode size=10 maxlength=10 value="$form->{shiptozipcode}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Country').qq|</th>
	  <td>$form->{country}</td>
	  <td><input name=shiptocountry size=35 maxlength=32 value="$form->{shiptocountry}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Contact').qq|</th>
	  <td>$form->{contact}</td>
	  <td><input name=shiptocontact size=35 maxlength=64 value="$form->{shiptocontact}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Phone').qq|</th>
	  <td>$form->{"$form->{vc}phone"}</td>
	  <td><input name=shiptophone size=20 value="$form->{shiptophone}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Fax').qq|</th>
	  <td>$form->{"$form->{vc}fax"}</td>
	  <td><input name=shiptofax size=20 value="$form->{shiptofax}"></td>
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

<input type=hidden name=nextsub value=$nextsub>
|;

  # delete shipto
  map { delete $form->{$_} } qw(shiptoname shiptoaddress1 shiptoaddress2 shiptocity shiptostate shiptozipcode shiptocountry shiptocontact shiptophone shiptofax shiptoemail header);
  $form->{title} = $title;
  
  $form->hide_form();

  print qq|

<hr size=3 noshade>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}


