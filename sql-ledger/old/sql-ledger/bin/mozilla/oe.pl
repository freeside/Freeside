#=====================================================================
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
#======================================================================
#
# Order entry module
#
#======================================================================


use SL::OE;
use SL::IR;
use SL::IS;
use SL::PE;

require "$form->{path}/io.pl";
require "$form->{path}/arap.pl";

1;
# end of main


sub add {

  if ($form->{type} eq 'purchase_order') {
    $form->{title} = $locale->text('Add Purchase Order');
    $form->{vc} = 'vendor';
  }
  if ($form->{type} eq 'sales_order') {
    $form->{title} = $locale->text('Add Sales Order');
    $form->{vc} = 'customer';
  }
  
  &order_links;
  &prepare_order;
  &display_form;

}


sub edit {

  if ($form->{type} eq 'purchase_order') {
    $form->{title} = $locale->text('Edit Purchase Order');
    $form->{vc} = 'vendor';
  }
  if ($form->{type} eq 'sales_order') {
    $form->{title} = $locale->text('Edit Sales Order');
    $form->{vc} = 'customer';
  }
  
  &order_links;
  &prepare_order;

  &display_form;

}


sub order_links {

  # get vendors / customers
  $form->all_vc(\%myconfig, $form->{vc});

  # retrieve order
  OE->retrieve_order(\%myconfig, \%$form);
  
  $taxincluded = $form->{taxincluded};
  $form->{shipto} = 1 if $form->{id};

  # get customer / vendor
  if ($form->{type} eq 'purchase_order') {
    IR->get_vendor(\%myconfig, \%$form);
  }
  if ($form->{type} eq 'sales_order') {
    IS->get_customer(\%myconfig, \%$form);
  }

  ($form->{$form->{vc}}) = split /--/, $form->{$form->{vc}};
  $form->{"old$form->{vc}"} = qq|$form->{$form->{vc}}--$form->{"$form->{vc}_id"}|;

  # build the popup menus
  if (@{ $form->{"all_$form->{vc}"} }) {
    $form->{$form->{vc}} = qq|$form->{$form->{vc}}--$form->{"$form->{vc}_id"}|;
    map { $form->{"select$form->{vc}"} .= "<option>$_->{name}--$_->{id}\n" } (@{ $form->{"all_$form->{vc}"} });
  }
  
  # currencies
  @curr = split /:/, $form->{currencies};
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];
  
  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  $form->{taxincluded} = $taxincluded if ($form->{id});

  # forex
  $form->{forex} = $form->{exchangerate};
  
}


sub prepare_order {

  $form->{format} = "html";
  $form->{media} = "screen";
  
  if ($form->{id}) {
    
    map { $form->{$_} =~ s/"/&quot;/g } qw(invnumber shippingpoint notes shiptoname shiptoaddr1 shiptoaddr2 shiptoaddr3 shiptoaddr4 shiptocontact);
    
    foreach $ref (@{ $form->{order_details} } ) {
      $i++;
      map { $form->{"${_}_$i"} = $ref->{$_} } keys %{ $ref };
      $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100);

      ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec = length $dec;
      $decimalplaces = ($dec > 2) ? $dec : 2;
      
      $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
      $form->{"qty_$i"} = $form->format_amount(\%myconfig, $form->{"qty_$i"});
      
      map { $form->{"${_}_$i"} =~ s/"/&quot;/g } qw(partnumber description unit);
      $form->{rowcount} = $i;
    }
  }

}


sub form_header {

  $checkedopen = ($form->{closed}) ? "" : "checked";
  $checkedclosed = ($form->{closed}) ? "checked" : "";

  if ($form->{id}) {
    $openclosed = qq|
      <tr>
        <td colspan=2 align=center>
	  <table>
	    <tr>
	      <th nowrap><input name=closed type=radio class=radio value=0 $checkedopen> |.$locale->text('Open').qq|</th>
	      <th nowrap><input name=closed type=radio class=radio value=1 $checkedclosed> |.$locale->text('Closed').qq|</th>
	    </tr>
	  </table>
	</td>
      </tr>
|;
  }

  # set option selected
  foreach $item ($form->{vc}, currency) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }
    
  $form->{exchangerate} = $form->format_amount(\%myconfig, $form->{exchangerate});

  $form->{creditlimit} = $form->format_amount(\%myconfig, $form->{creditlimit}, 0, "0");
  $form->{creditremaining} = $form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0");
  
  $exchangerate = qq|
<input type=hidden name=forex value=$form->{forex}>
|;

  if ($form->{currency} ne $form->{defaultcurrency}) {
    if ($form->{forex}) {
      $exchangerate .= qq|<th align=right>|.$locale->text('Exchangerate').qq|</th><td>$form->{exchangerate}</td>
      <input type=hidden name=exchangerate value=$form->{exchangerate}>
|;
    } else {
      $exchangerate .= qq|<th align=right>|.$locale->text('Exchangerate').qq|</th><td><input name=exchangerate size=10 value=$form->{exchangerate}></td>|;
    }
  }


  $vclabel = ucfirst $form->{vc};
  $vclabel = $locale->text($vclabel);

  if ($form->{type} eq 'sales_order') {
    
    $n = ($form->{creditremaining} =~ /-/) ? "0" : "1";
    
    $creditremaining = qq|
	      <tr>
		<td></td>
		<td colspan=3>
		  <table width=100%>
		    <tr>
		      <th align=left nowrap>|.$locale->text('Credit Limit').qq|</th>
		      <td>$form->{creditlimit}</td>
		      <th align=left nowrap>|.$locale->text('Remaining').qq|</th>
		      <td class="plus$n">$form->{creditremaining}</td>
		    </tr>
		  </table>
		</td>
	      </tr>
|;
  }

  $vc = ($form->{"select$form->{vc}"}) ? qq|<select name=$form->{vc}>$form->{"select$form->{vc}"}</select>\n<input type=hidden name="select$form->{vc}" value="$form->{"select$form->{vc}"}">| : qq|<input name=$form->{vc} value="$form->{$form->{vc}}" size=35>|;


  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>

<input type=hidden name=type value=$form->{type}>
<input type=hidden name=media value=$form->{media}>
<input type=hidden name=format value=$form->{format}>

<input type=hidden name=vc value=$form->{vc}>
<input type=hidden name=employee value="$form->{employee}">

<input type=hidden name=title value="$form->{title}">

<input type=hidden name=discount value=$form->{discount}>
<input type=hidden name=creditlimit value=$form->{creditlimit}>
<input type=hidden name=creditremaining value=$form->{creditremaining}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width="100%">
        <tr valign=top>
	  <td>
	    <table>
	      <tr>
		<th align=right>$vclabel</th>
		<td colspan=3>$vc</td>
		<input type=hidden name=$form->{vc}_id value=$form->{"$form->{vc}_id"}>
		<input type=hidden name="old$form->{vc}" value="$form->{"old$form->{vc}"}">
	      </tr>
	      $creditremaining
	      <tr>
		<th align=right>|.$locale->text('Currency').qq|</th>
		<td><select name=currency>$form->{selectcurrency}</select></td>
		<input type=hidden name=selectcurrency value="$form->{selectcurrency}">
		<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
		$exchangerate
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Ship via').qq|</th>
		<td colspan=3><input name=shippingpoint size=35 value="$form->{shippingpoint}"></td>
	      </tr>
	    </table>
	  </td>
	  <td align=right>
	    <table width=100%>
	      $openclosed
	      <tr>
		<th align=right nowrap>|.$locale->text('Order Number').qq|</th>
		<td><input name=ordnumber size=11 value="$form->{ordnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Order Date').qq|</th>
		<td><input name=orddate size=11 title="$myconfig{dateformat}" value=$form->{orddate}></td>
	      </tr>
	      <tr>
		<th align=right nowrap=true>|.$locale->text('Required by').qq|</th>
		<td><input name=reqdate size=11 title="$myconfig{dateformat}" value=$form->{reqdate}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Terms: Net').qq|</th>
		<td nowrap=true><input name=terms size="3" maxlength="3" value=$form->{terms}> |.$locale->text('days').qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>

<!-- shipto are in hidden variables -->

<input type=hidden name=shiptoname value="$form->{shiptoname}">
<input type=hidden name=shiptoaddr1 value="$form->{shiptoaddr1}">
<input type=hidden name=shiptoaddr2 value="$form->{shiptoaddr2}">
<input type=hidden name=shiptoaddr3 value="$form->{shiptoaddr3}">
<input type=hidden name=shiptoaddr4 value="$form->{shiptoaddr4}">
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

<input type=hidden name=taxpart value="$form->{taxpart}">
<input type=hidden name=taxservice value="$form->{taxservice}">

<input type=hidden name=taxaccounts value="$form->{taxaccounts}">
|;

  foreach $item (split / /, $form->{taxaccounts}) {
    print qq|
<input type=hidden name="${item}_rate" value=$form->{"${item}_rate"}>
<input type=hidden name="${item}_description" value="$form->{"${item}_description"}">
|;
  }

}


sub form_footer {

  $form->{invtotal} = $form->{invsubtotal};

  if (($rows = $form->numtextrows($form->{notes}, 50, 8)) < 2) {
    $rows = 2;
  }
  $notes = qq|<textarea name=notes rows=$rows cols=50 wrap=soft>$form->{notes}</textarea>|;

  $taxincluded = "";
  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";
  if ($form->{taxaccounts}) {
    $taxincluded = qq|
		<input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}> <b>|.$locale->text('Tax Included').qq|</b><br><br>
|;
  }

  if (!$form->{taxincluded}) {
    
    foreach $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
	$form->{invtotal} += $form->{"${item}_total"} = $form->round_amount($form->{"${item}_base"} * $form->{"${item}_rate"}, 2);
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
	      </tr>
	      <tr>
		<td>$notes</td>
	      </tr>
	    </table>
	  </td>
	  <td align=right width=100%>
	    $taxincluded
	    <table width=100%>
	      $subtotal
	      $tax
	      <tr>
		<th align=right>|.$locale->text('Total').qq|</th>
		<td align=right>$form->{invtotal}</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
<input type=hidden name=oldinvtotal value=$form->{oldinvtotal}>
<input type=hidden name=oldtotalpaid value=$totalpaid>
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

<br>
<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Ship to').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Print').qq|">
<input class=submit type=submit name=action value="|.$locale->text('E-mail').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Save').qq|">
|;

    if ($form->{id}) {
      print qq|
<input class=submit type=submit name=action value="|.$locale->text('Save as new').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Invoice').qq|">
|;
    }

  print qq| 

<input type=hidden name=rowcount value=$form->{rowcount}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

</form>

</body>
</html>
|;

}


sub update {

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate creditlimit creditremaining);

  &check_name($form->{vc});

  &check_project;

  $buysell = 'buy';
  $buysell = 'sell' if ($form->{vc} eq 'vendor');
  $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{orddate}, $buysell)));
  

  my $i = $form->{rowcount};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  if (($form->{"partnumber_$i"} eq "") && ($form->{"description_$i"} eq "") && ($form->{"partsgroup_$i"} eq "")) {

    $form->{creditremaining} += ($form->{oldinvtotal} - $form->{oldtotalpaid});
    &check_form;

  } else {
   
    if ($form->{type} eq 'purchase_order') {
      IR->retrieve_item(\%myconfig, \%$form);
    }
    if ($form->{type} eq 'sales_order') {
      IS->retrieve_item(\%myconfig, \%$form);
    }

    my $rows = scalar @{ $form->{item_list} };
    
    $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{discount} * 100);

    if ($rows) {
      $form->{"qty_$i"}                     = 1 unless ($form->{"qty_$i"});
      
      if ($rows > 1) {
	
	&select_item;
	exit;
	
      } else {
	
	$sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});
	
	map { $form->{item_list}[$i]{$_} =~ s/"/&quot;/g } qw(partnumber description unit);
	map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} } keys %{ $form->{item_list}[0] };

	$s = ($sellprice) ? $sellprice : $form->{"sellprice_$i"};
	
	($dec) = ($s =~ /\.(\d+)/);
	$dec = length $dec;
	$decimalplaces = ($dec > 2) ? $dec : 2;

        if ($sellprice) {
	  $form->{"sellprice_$i"} = $sellprice;
	} else {
	  # if there is an exchange rate adjust sellprice
	  $form->{"sellprice_$i"} /= $exchangerate;
	}
	
	$amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * (1 - $form->{"discount_$i"} / 100);
	map { $form->{"${_}_base"} = 0 } (split / /, $form->{taxaccounts});
	map { $form->{"${_}_base"} += $amount } (split / /, $form->{"taxaccounts_$i"});
	map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{taxaccounts} if !$form->{taxincluded};
	
	$form->{creditremaining} -= $amount;
	
	$form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
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
	
	$form->{"id_$i"}		= 0;
	$form->{"unit_$i"}	= $locale->text('ea');

	&new_item;

      }
    }
  }
}



sub search {
  
  if ($form->{type} eq 'purchase_order') {
    $form->{title} = $locale->text('Purchase Orders');
    $form->{vc} = 'vendor';
  }
  if ($form->{type} eq 'sales_order') {
    $form->{title} = $locale->text('Sales Orders');
    $form->{vc} = 'customer';
  }

  # setup vendor / customer selection
  $form->all_vc(\%myconfig, "$form->{vc}");

  map { $vc .= "<option>$_->{name}--$_->{id}\n" } @{ $form->{"all_$form->{vc}"} };

  $vclabel = ucfirst $form->{vc};
  $vclabel = $locale->text($vclabel);
  
# $locale->text('Vendor')
# $locale->text('Customer')
  
  $vc = ($vc) ? qq|<select name=$form->{vc}><option>\n$vc</select>| : qq|<input name=$form->{vc} size=35>|;

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
          <th align=right>$vclabel</th>
          <td colspan=3>$vc</td>
        </tr>
        <tr>
          <th align=right>|.$locale->text('Order Number').qq|</th>
          <td colspan=3><input name=ordnumber size=20></td>
        </tr>
        <tr>
          <th align=right>|.$locale->text('From').qq|</th>
          <td><input name=transdatefrom size=11 title="$myconfig{dateformat}"></td>
          <th align=right>|.$locale->text('to').qq|</th>
          <td><input name=transdateto size=11 title="$myconfig{dateformat}"></td>
        </tr>
        <input type=hidden name=sort value=transdate>
        <tr>
          <th align=right>|.$locale->text('Include in Report').qq|</th>
          <td colspan=3>
	    <table>
	      <tr>
	        <td><input name="open" class=checkbox type=checkbox value=1 checked> |.$locale->text('Open').qq|</td>
	        <td><input name="closed" class=checkbox type=checkbox value=1 $form->{closed}> |.$locale->text('Closed').qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_id" class=checkbox type=checkbox value=Y> |.$locale->text('ID').qq|</td>
		<td><input name="l_ordnumber" class=checkbox type=checkbox value=Y checked> |.$locale->text('Order Number').qq|</td>
		<td><input name="l_transdate" class=checkbox type=checkbox value=Y checked> |.$locale->text('Order Date').qq|</td>
		<td><input name="l_reqdate" class=checkbox type=checkbox value=Y checked> |.$locale->text('Required by').qq|</td>
	      </tr>
	      <tr>
	        <td><input name="l_name" class=checkbox type=checkbox value=Y checked> $vclabel</td>
		<td><input name="l_netamount" class=checkbox type=checkbox value=Y> |.$locale->text('Amount').qq|</td>
		<td><input name="l_tax" class=checkbox type=checkbox value=Y> |.$locale->text('Tax').qq|</td>
		<td><input name="l_amount" class=checkbox type=checkbox value=Y checked> |.$locale->text('Total').qq|</td>
	      </tr>
	      <tr>
	        <td><input name="l_subtotal" class=checkbox type=checkbox value=Y> |.$locale->text('Subtotal').qq|</td>
	      </tr>
	    </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr><td colspan=4><hr size=3 noshade></td></tr>
</table>

<br>
<input type=hidden name=nextsub value=orders>
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>
<input type=hidden name=vc value=$form->{vc}>
<input type=hidden name=type value=$form->{type}>

<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}


sub orders {

  $name = $form->{$form->{vc}};
  
  # split vendor / customer
  ($form->{$form->{vc}}, $form->{"$form->{vc}_id"}) = split(/--/, $form->{$form->{vc}});

  OE->transactions(\%myconfig, \%$form);

  # construct href
  $href = "$form->{script}?path=$form->{path}&action=orders&type=$form->{type}&vc=$form->{vc}&login=$form->{login}&password=$form->{password}&transdatefrom=$form->{transdatefrom}&transdateto=$form->{transdateto}&open=$form->{open}&closed=$form->{closed}&ordnumber=" . $form->escape($form->{ordnumber}) . "&$form->{vc}=" . $form->escape($form->{$form->{vc}});

  # construct callback
  $name =~ s/&/_/g;
  $callback = "$form->{script}?path=$form->{path}&action=orders&type=$form->{type}&vc=$form->{vc}&login=$form->{login}&password=$form->{password}&transdatefrom=$form->{transdatefrom}&transdateto=$form->{transdateto}&open=$form->{open}&closed=$form->{closed}&ordnumber=$form->{ordnumber}&$form->{vc}=$name";

  @columns = $form->sort_columns(qw(transdate reqdate id ordnumber name netamount tax amount curr open closed));

  $form->{l_open} = $form->{l_closed} = "Y" if ($form->{open} && $form->{closed}) ;

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
 
 
  if ($form->{vc} eq 'vendor') {
    $form->{title} = $locale->text('Purchase Orders');
    $name = $locale->text('Vendor');
  }
  if ($form->{vc} eq 'customer') {
    $form->{title} = $locale->text('Sales Orders');
    $name = $locale->text('Customer');
  }
 
  $column_header{id} = qq|<th><a class=listheading href=$href&sort=id>|.$locale->text('ID').qq|</a></th>|;
  $column_header{transdate} = qq|<th><a class=listheading href=$href&sort=transdate>|.$locale->text('Date').qq|</a></th>|;
  $column_header{reqdate} = qq|<th><a class=listheading href=$href&sort=reqdate>|.$locale->text('Required by').qq|</a></th>|;
  $column_header{ordnumber} = qq|<th><a class=listheading href=$href&sort=ordnumber>|.$locale->text('Order').qq|</a></th>|;
  $column_header{name} = qq|<th><a class=listheading href=$href&sort=name>$name</a></th>|;
  $column_header{netamount} = qq|<th class=listheading>|.$locale->text('Amount').qq|</th>|;
  $column_header{tax} = qq|<th class=listheading>|.$locale->text('Tax').qq|</th>|;
  $column_header{amount} = qq|<th class=listheading>|.$locale->text('Total').qq|</th>|;
  $column_header{curr} = qq|<th class=listheading>|.$locale->text('Curr').qq|</th>|;
  $column_header{open} = qq|<th class=listheading>|.$locale->text('O').qq|</th>|;
  $column_header{closed} = qq|<th class=listheading>|.$locale->text('C').qq|</th>|;

  if ($form->{open}) {
    $option = $locale->text('Open');
  }
  if ($form->{closed}) {
    $option .= " : " if $form->{open};
    $option .= $locale->text('Closed');
  }
  if ($form->{$form->{vc}}) {
    $option .= "\n<br>";
    $option .= ucfirst $form->{vc};
    $option .= " : $form->{$form->{vc}}";
  }
  if ($form->{transdatefrom}) {
    $option .= "\n<br>".$locale->text('From')." ".$locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    $option .= "\n<br>".$locale->text('to')." ".$locale->date(\%myconfig, $form->{transdateto}, 1);
  }
  
  $form->header;

  $colspan = $#column_index + 1;

  print qq|
<body>

<table width=100%>
  <tr><th class=listtop colspan=$colspan>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td colspan=$colspan>$option</td>
  </tr>
  <tr class=listheading>|;

map { print "\n$column_header{$_}" } @column_index;

print qq|
  </tr>
|;

  # add sort and escape callback
  $callback = $form->escape($callback . "&sort=$form->{sort}");

  if (@{ $form->{OE} }) {
    $sameitem = $form->{OE}->[0]->{$form->{sort}};
  }

  foreach $oe (@{ $form->{OE} }) {

    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $oe->{$form->{sort}}) {
	&subtotal;
	$sameitem = $oe->{$form->{sort}};
      }
    }
    
    map { $oe->{$_} *= $oe->{exchangerate} } (qw(netamount amount));
    
    $column_data{netamount} = "<td align=right>".$form->format_amount(\%myconfig, $oe->{netamount}, 2, "&nbsp;")."</td>";
    $column_data{tax} = "<td align=right>".$form->format_amount(\%myconfig, $oe->{amount} - $oe->{netamount}, 2, "&nbsp;")."</td>";
    $column_data{amount} = "<td align=right>".$form->format_amount(\%myconfig, $oe->{amount}, 2, "&nbsp;")."</td>";

    $totalnetamount += $oe->{netamount};
    $totalamount += $oe->{amount};

    $subtotalnetamount += $oe->{netamount};
    $subtotalamount += $oe->{amount};

    $column_data{id} = "<td>$oe->{id}</td>";
    $column_data{transdate} = "<td>$oe->{transdate}&nbsp;</td>";
    $column_data{reqdate} = "<td>$oe->{reqdate}&nbsp;</td>";

    $column_data{ordnumber} = "<td><a href=oe.pl?path=$form->{path}&action=edit&type=$form->{type}&id=$oe->{id}&login=$form->{login}&password=$form->{password}&callback=$callback>$oe->{ordnumber}</a></td>";
    $column_data{name} = "<td>$oe->{name}</td>";

    if ($oe->{closed}) {
      $column_data{closed} = "<td align=center>X</td>";
      $column_data{open} = "<td>&nbsp;</td>";
    } else {
      $column_data{closed} = "<td>&nbsp;</td>";
      $column_data{open} = "<td align=center>X</td>";
    }

    $i++; $i %= 2;
    print "<tr class=listrow$i>";
    
    map { print "\n$column_data{$_}" } @column_index;

    print qq|
    </tr>
|;

  }
  
  if ($form->{l_subtotal} eq 'Y') {
    &subtotal;
  }
  
  # print totals
  print qq|<tr class=listtotal>|;
  
  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
  
  $column_data{netamount} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalnetamount, 2, "&nbsp;")."</th>";
  $column_data{tax} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalamount - $totalnetamount, 2, "&nbsp;")."</th>";
  $column_data{amount} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalamount, 2, "&nbsp;")."</th>";

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
  </tr>
  <tr><td colspan=8><hr size=3 noshade></td></tr>
</table>

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=type value=$form->{type}>
<input type=hidden name=vc value=$form->{vc}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value=|.$locale->text('Add').qq|

</form>

</body>
</html>
|;

}



sub subtotal {

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
  
  $column_data{netamount} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalnetamount, 2, "&nbsp;")."</th>";
  $column_data{tax} = "<td class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalamount - $subtotalnetamount, 2, "&nbsp;")."</th>";
  $column_data{amount} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalamount, 2, "&nbsp;")."</th>";

  $subtotalnetamount = 0;
  $subtotalamount = 0;

  print "<tr class=listsubtotal>";
  
  map { print "\n$column_data{$_}" } @column_index;

  print qq|
  </tr>
|;

}


sub save {

  $form->isblank("ordnumber", $locale->text('Order Number missing!'));
  $form->isblank("orddate", $locale->text('Order Date missing!'));
  
  $msg = ucfirst $form->{vc};
  $form->isblank($form->{vc}, $locale->text($msg . " missing!"));

# $locale->text('Customer missing!');
# $locale->text('Vendor missing!');
  
  $form->isblank("exchangerate", $locale->text('Exchangerate missing!')) if ($form->{currency} ne $form->{defaultcurrency});
  
  &validate_items;

  # if the name changed get new values
  if (&check_name($form->{vc})) {
    &update;
    exit;
  }


  # this is for the notes section for the [email] Subject
  $form->{label} = ($form->{type} eq 'sales_order') ? $locale->text('Sales Order') : $locale->text('Purchase Order');

  $form->{id} = 0 if $form->{saveasnew};
  
  $form->redirect($locale->text('Order saved!')) if (OE->save_order(\%myconfig, \%$form));
  $form->error($locale->text('Cannot save order!'));
  
}



sub delete {

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  # delete action variable
  delete $form->{action};

  foreach $key (keys %$form) {
    $form->{$key} =~ s/"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>|.$locale->text('Confirm!').qq|</h2>

<h4>|
  .$locale->text('Are you sure you want to delete Order Number').qq| $form->{ordnumber}
</h4>
<p>
<input name=action class=submit type=submit value="|.$locale->text('Yes').qq|">
</form>

</body>
</html>
|;


}



sub yes {

  $form->redirect($locale->text('Order deleted!')) if (OE->delete_order(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete order!'));

}


sub invoice {
  
  $form->isblank("ordnumber", $locale->text('Order Number missing!'));
  $form->isblank("orddate", $locale->text('Order Date missing!'));


  # if the name changed get new values
  if (&check_name($form->{vc})) {
    &update;
    exit;
  }

  $form->{closed} = 1;
  OE->save_order(\%myconfig, \%$form);
  
  $form->{orddate} = $form->{transdate} = $form->{invdate} = $form->current_date(\%myconfig);
  $form->{duedate} = $form->current_date(\%myconfig, $form->{invdate}, $form->{terms} * 1);
 
  $form->{id} = '';
  $form->{closed} = 0;
  $form->{rowcount}--;
  $form->{shipto} = 1;

  &create_backorder;

  if ($form->{type} eq 'purchase_order') {
    $form->{title} = $locale->text('Add Vendor Invoice');
    $form->{script} = 'ir.pl';
    $script = "ir";
    $buysell = 'sell';
  }
  if ($form->{type} eq 'sales_order') {
    $form->{title} = $locale->text('Add Sales Invoice');
    $form->{script} = 'is.pl';
    $script = "is";
    $buysell = 'buy';
  }
  
 
  # bo creates the id, reset it
  map { $form->{$_} = "" } qw(id subject message cc bcc);
  $form->{$form->{vc}} =~ s/--.*//g;
  $form->{type} = "invoice";
 
  # locale messages
  $locale = new Locale "$myconfig{countrycode}", "$script";

  require "$form->{path}/$form->{script}";

  map { $form->{"select$_"} = "" } ($form->{vc}, currency);

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(creditlimit creditremaining);

  $currency = $form->{currency};
  &invoice_links;

  $form->{currency} = $currency;
  $form->{exchangerate} = "";
  $form->{forex} = "";
  $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, $buysell)));
 
  $form->{creditremaining} -= ($form->{oldinvtotal} - $form->{ordtotal});

  &prepare_invoice;

  # format amounts
  for $i (1 .. $form->{rowcount}) {
    $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"discount_$i"});

    ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec = length $dec;
    $decimalplaces = ($dec > 2) ? $dec : 2;

    $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
    $form->{"qty_$i"} = $form->format_amount(\%myconfig, $form->{"qty_$i"});

    map { $form->{"${_}_$i"} =~ s/"/&quot;/g } qw(partnumber description unit);
  }

  &display_form;

}


sub create_backorder {

  # figure out if we need to create a backorder
  # items aren't saved if qty != 0

  for $i (1 .. $form->{rowcount}) {
    $totalqty += $qty = $form->parse_amount($myconfig, $form->{"qty_$i"});
    $totalship += $ship = $form->parse_amount($myconfig, $form->{"ship_$i"});
    
    $form->{"qty_$i"} = $qty - $ship;
  }

  if ($totalship == 0) {
    map { $form->{"ship_$_"} = $form->{"qty_$_"} } (1 .. $form->{rowcount});
    $form->{ordtotal} = 0;
    return;
  }

  if ($totalqty == $totalship) {
    map { $form->{"qty_$_"} = $form->{"ship_$_"} } (1 .. $form->{rowcount});
    $form->{ordtotal} = 0;
    return;
  }

  @flds = (qw(partnumber description qty ship unit sellprice discount id inventory_accno bin income_accno expense_accno listprice assembly taxaccounts));

  OE->save_order(\%myconfig, \%$form);
  
  # rebuild rows for invoice
  @a = ();
  $count = 0;

  for $i (1 .. $form->{rowcount}) {
    
    # reformat values if there was a backorder quantity
    if ($form->{"qty_$i"}) {
      $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"discount_$i"});
      $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"});
    }

    $form->{"qty_$i"} = $form->{"ship_$i"};

    if ($form->{"qty_$i"}) {
      push @a, {};
      $j = $#a;
      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }
 
  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
  $form->{rowcount} = $count;
  
}



sub save_as_new {

  $form->{saveasnew} = 1;
  $form->{closed} = 0;
  &save;

}


