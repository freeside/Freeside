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
# Inventory received module
#
#======================================================================


use SL::IR;
use SL::PE;

require "$form->{path}/io.pl";
require "$form->{path}/arap.pl";

1;
# end of main



sub add {

  $form->{title} = $locale->text('Add Vendor Invoice');

  &invoice_links;
  &prepare_invoice;
  &display_form;
  
}


sub edit {

  $form->{title} = $locale->text('Edit Vendor Invoice');

  &invoice_links;
  &prepare_invoice;
  &display_form;
  
}


sub invoice_links {

  # create links
  $form->create_links("AP", \%myconfig, "vendor");

  IR->get_vendor(\%myconfig, \%$form);
  IR->retrieve_invoice(\%myconfig, \%$form);

  # currencies
  @curr = split /:/, $form->{currencies};
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];

  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  $form->{oldvendor} = "$form->{vendor}--$form->{vendor_id}";

  # vendors
  if (@{ $form->{all_vendor} }) {
    $form->{vendor} = "$form->{vendor}--$form->{vendor_id}";
    map { $form->{selectvendor} .= "<option>$_->{name}--$_->{id}\n" } (@{ $form->{all_vendor} });
  }

  
  # forex
  $form->{forex} = $form->{exchangerate};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;
  
  foreach $key (keys %{ $form->{AP_links} }) {

    foreach $ref (@{ $form->{AP_links}{$key} }) {
      $form->{"select$key"} .= "<option>$ref->{accno}--$ref->{description}\n";
    }

    if ($key eq "AP_paid") {
      for $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {
	$form->{"AP_paid_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
	# reverse paid
	$form->{"paid_$i"} = $form->{acc_trans}{$key}->[$i-1]->{amount};
	$form->{"datepaid_$i"} = $form->{acc_trans}{$key}->[$i-1]->{transdate};
	$form->{"forex_$i"} = $form->{"exchangerate_$i"} = $form->{acc_trans}{$key}->[$i-1]->{exchangerate};
	$form->{"source_$i"} = $form->{acc_trans}{$key}->[$i-1]->{source};
	$form->{paidaccounts} = $i;
      }
    } else {
      $form->{$key} = "$form->{acc_trans}{$key}->[0]->{accno}--$form->{acc_trans}{$key}->[0]->{description}";
    }
  }

  $form->{paidaccounts} = 1 unless (exists $form->{paidaccounts});

  $form->{AP} = $form->{AP_1} unless $form->{id};

  $form->{locked} = ($form->datetonum($form->{invdate}, \%myconfig) <= $form->datetonum($form->{closedto}, \%myconfig));
  
}



sub prepare_invoice {

  if ($form->{id}) {
        
    map { $form->{$_} =~ s/"/&quot;/g } qw(invnumber ordnumber);

    foreach $ref (@{ $form->{invoice_details} }) {
      $i++;
      map { $form->{"${_}_$i"} = $ref->{$_} } keys %{ $ref };
      
      ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec = length $dec;
      $decimalplaces = ($dec > 2) ? $dec : 2;
      
      $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
      $form->{"qty_$i"} = $form->format_amount(\%myconfig, $form->{"qty_$i"});

      $form->{rowcount} = $i;
    }
  }
  
}



sub form_header {

  # set option selected
  foreach $item (qw(AP vendor currency)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }
  
  $form->{exchangerate} = $form->format_amount(\%myconfig, $form->{exchangerate});

  $exchangerate = "";
  if ($form->{currency} ne $form->{defaultcurrency}) {
    if ($form->{forex}) {
      $exchangerate .= qq|
      <th align=right nowrap>|.$locale->text('Exchangerate').qq|</th>
      <td>$form->{exchangerate}<input type=hidden name=exchangerate value=$form->{exchangerate}></td>
|;
    } else {
      $exchangerate .= qq|
      <th align=right nowrap>|.$locale->text('Exchangerate').qq|</th>
      <td><input name=exchangerate size=10 value=$form->{exchangerate}></td>
|;
    }
  }
  $exchangerate .= qq|
<input type=hidden name=forex value=$form->{forex}>
|;
  
  $vendor = ($form->{selectvendor}) ? qq|<select name=vendor>$form->{selectvendor}</select>\n<input type=hidden name="selectvendor" value="$form->{selectvendor}">| : qq|<input name=vendor value="$form->{vendor}" size=35>|;
  

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=title value="$form->{title}">
<input type=hidden name=vc value="vendor">

<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>


<table width=100%>
  <tr class=listtop>
    <th>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr valign=top>
	  <td>
	    <table>
	      <tr>
		<th align=right>|.$locale->text('Record in').qq|</th>
		<td colspan=3><select name=AP>$form->{selectAP}</select></td>
		<input type=hidden name=selectAP value="$form->{selectAP}">
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Vendor').qq|</th>
		<td colspan=3>$vendor</td>
		
		<input type=hidden name=vendor_id value=$form->{vendor_id}>
		<input type=hidden name=oldvendor value="$form->{oldvendor}">

	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Currency').qq|</th>
		<td><select name=currency>$form->{selectcurrency}</select></td>
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
		<th align=right nowrap>|.$locale->text('Invoice Date').qq|</th>
		<td><input name=invdate size=11 title="$myconfig{dateformat}" value=$form->{invdate}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Due Date').qq|</th>
		<td><input name=duedate size=11 title="$myconfig{dateformat}" value=$form->{duedate}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Order Number').qq|</th>
		<td><input name=ordnumber size=11 value="$form->{ordnumber}"></td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
<input type=hidden name=selectcurrency value="$form->{selectcurrency}">
<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
<input type=hidden name=fxgain_accno value=$form->{fxgain_accno}>
<input type=hidden name=fxloss_accno value=$form->{fxloss_accno}>

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


  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2, 0);

  print qq|
  <tr>
    <td colspan=$colspan>
      <table cellspacing="0">
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
	  <td colspan=2 align=right width=100%>
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
  <tr>
    <td colspan=$colspan>
      <table width=100%>
        <tr>
	  <th colspan=5 class=listheading>|.$locale->text('Payments').qq|</th>
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

    print qq|
	<tr>
|;
    map { print "$column_data{$_}\n" } @column_index;
    print qq|
	</tr>
|;

    $form->{paidaccounts}++ if ($form->{"paid_$form->{paidaccounts}"});
    for $i (1 .. $form->{paidaccounts}) {

      print qq|
	<tr>
|;

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

      $column_data{"paid_$i"} = qq|<td align=center><input name="paid_$i" size=11 value=$form->{"paid_$i"}></td>|;
      $column_data{"exchangerate_$i"} = qq|<td align=center>$exchangerate</td>|;
      $column_data{"AP_paid_$i"} = qq|<td align=center><select name="AP_paid_$i">$form->{"selectAP_paid_$i"}</select></td>|;
      $column_data{"datepaid_$i"} = qq|<td align=center><input name="datepaid_$i" size=11 title="$myconfig{dateformat}" value=$form->{"datepaid_$i"}></td>|;
      $column_data{"source_$i"} = qq|<td align=center><input name="source_$i" size=11 value=$form->{"source_$i"}></td>|;

      map { print qq|$column_data{"${_}_$i"}\n| } @column_index;

      print qq|
	</tr>
|;
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
<br>
|;

  $invdate = $form->datetonum($form->{invdate}, \%myconfig);
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

    if ($invdate > $closedto) {
      print qq|
      <input class=submit type=submit name=action value="|.$locale->text('Post as new').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('Order').qq|">
|;
    }

  } else {
    if ($invdate > $closedto) {
      print qq|<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('Post').qq|">|;
    }
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

  $form->{exchangerate} = $form->parse_amount(\%myconfig, $form->{exchangerate});
  
  &check_name(vendor);

  &check_project;

  $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, 'sell')));
  
  
  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);

      $form->{"exchangerate_$i"} = $exchangerate if ($form->{"forex_$i"} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell')));
    }
  }
  
  $i = $form->{rowcount};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  if (($form->{"partnumber_$i"} eq "") && ($form->{"description_$i"} eq "") && ($form->{"partsgroup_$i"} eq "")) {

    &check_form;
    
  } else {
   
    IR->retrieve_item(\%myconfig, \%$form);

    my $rows = scalar @{ $form->{item_list} };

    if ($rows) {
      $form->{"qty_$i"}                     = 1 unless ($form->{"qty_$i"});
      
      if ($rows > 1) {
	
	&select_item;
	exit;
	
      } else {
        # override sellprice if there is one entered
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



sub post {

  $form->isblank("invnumber", $locale->text('Invoice Number missing!'));
  $form->isblank("invdate", $locale->text('Invoice Date missing!'));
  $form->isblank("vendor", $locale->text('Vendor missing!'));
  
  # if the vendor changed get new values
  if (&check_name(vendor)) {
    &update;
    exit;
  }

  &validate_items;

  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  $invdate = $form->datetonum($form->{invdate}, \%myconfig);

  $form->error($locale->text('Cannot post invoice for a closed period!')) if ($invdate <= $closedto);

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!')) if ($form->{currency} ne $form->{defaultcurrency});
  
  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));
      
      $form->error($locale->text('Cannot post payment for a closed period!')) if ($datepaid <= $closedto);
      
      if ($form->{currency} ne $form->{defaultcurrency}) {
	$form->{"exchangerate_$i"} = $form->{exchangerate} if ($invdate == $datepaid);
	$form->isblank("exchangerate_$i", $locale->text('Exchangerate for payment missing!'));
      }
    }
  }
  
  
  ($form->{AP}) = split /--/, $form->{AP};
  ($form->{AP_paid}) = split /--/, $form->{AP_paid};
  
  $form->{id} = 0 if $form->{postasnew};

  $form->redirect($locale->text('Invoice posted!')) if (IR->post_invoice(\%myconfig, \%$form));
  $form->error($locale->text('Cannot post invoice!'));
  
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

<h4>|.$locale->text('Are you sure you want to delete Invoice Number').qq| $form->{invnumber}</h4>
<p>
<input name=action class=submit type=submit value="|.$locale->text('Yes').qq|">
</form>
|;


}



sub yes {

  $form->redirect($locale->text('Invoice deleted!')) if (IR->delete_invoice(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete invoice!'));

}


