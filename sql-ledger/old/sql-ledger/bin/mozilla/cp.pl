#=====================================================================
# SQL-Ledger Accounting
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
#======================================================================
#
# Payment module
#
#======================================================================


use SL::CP;
use SL::IS;
use SL::IR;

require "$form->{path}/arap.pl";

1;
# end of main


sub payment {
  
  # setup customer/vendor selection for open invoices
  CP->get_openvc(\%myconfig, \%$form);

  if ($form->{"all_$form->{vc}"}) {
    map { $form->{"select$form->{vc}"} .= "<option>$_->{name}--$_->{id}\n" } @{ $form->{"all_$form->{vc}"} };
  }

  $form->{arap} = ($form->{vc} eq 'customer') ? "AR" : "AP";

  CP->paymentaccounts(\%myconfig, \%$form);

  map { $form->{selectaccount} .= "<option>$_->{accno}--$_->{description}\n" } @{ $form->{PR} };

  # currencies
  @curr = split /:/, $form->{currencies};
  chomp $curr[0];
  $form->{defaultcurrency} = $form->{currency} = $form->{oldcurrency} = $curr[0];

  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  $form->{media} = "screen";

  &form_header;
  &list_invoices;
  &form_footer;

}



sub form_header {

  $vclabel = ucfirst $form->{vc};
  $vclabel = $locale->text($vclabel);

  if ($form->{vc} eq 'customer') {
    $form->{title} = $locale->text('Receipt');
    $rclabel = $locale->text('Reference');
    $form->{type} = 'receipt';
  } else {
    $form->{title} = $locale->text('Payment');
    $rclabel = $locale->text('Check');
    $form->{type} = 'check';
  }

# $locale->text('Customer')
# $locale->text('Vendor')

  if ($form->{$form->{vc}} eq "") {
    map { $form->{"addr$_"} = "" } (1 .. 4);
  }

  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->{exchangerate} = $form->format_amount(\%myconfig, $form->{exchangerate});
    if ($form->{forex}) {
      $exchangerate = qq|
 	      <tr>
		<th align=right nowrap>|.$locale->text('Exchangerate').qq|</th>
		<td colspan=3><input type=hidden name=exchangerate size=10 value=$form->{exchangerate}>$form->{exchangerate}</td>
	      </tr>
|;
    } else {
      $exchangerate = qq|
 	      <tr>
		<th align=right nowrap>|.$locale->text('Exchangerate').qq|</th>
		<td colspan=3><input name=exchangerate size=10 value=$form->{exchangerate}></td>
	      </tr>
|;
    }
  }
  
  foreach $item ($form->{vc}, account, currency) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  $vc = ($form->{"select$form->{vc}"}) ? qq|<select name=$form->{vc}>$form->{"select$form->{vc}"}\n</select>| : qq|<input name=$form->{vc} size=35 value="$form->{$form->{vc}}">|;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=vc value=$form->{vc}>
<input type=hidden name=type value=$form->{type}>

<table border=0 width=100%>
  <tr>
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
		<th align=right>$vclabel</th>
		<td>$vc</td>
                <input type=hidden name="select$form->{vc}" value="$form->{"select$form->{vc}"}">
                <input type=hidden name="$form->{vc}_id" value=$form->{"$form->{vc}_id"}>
		<input type=hidden name="old$form->{vc}" value="$form->{"old$form->{vc}"}">
	      </tr>
	      <tr valign=top>
		<th align=right nowrap>|.$locale->text('Address').qq|</th>
		<td>
		  <table>
		    <tr>
		      <td>$form->{addr1}</td>
		    </tr>
		    <tr>
		      <td>$form->{addr2}</td>
		    </tr>
		    <tr>
		      <td>$form->{addr3}</td>
		    </tr>
		    <tr>
		      <td>$form->{addr4}</td>
		    </tr>
		  </table>
		</td>
		<input type=hidden name=addr1 value="$form->{addr1}">
		<input type=hidden name=addr2 value="$form->{addr2}">
		<input type=hidden name=addr3 value="$form->{addr3}">
		<input type=hidden name=addr4 value="$form->{addr4}">
	      </tr>
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      <tr>
		<th align=right nowrap>|.$locale->text('Account').qq|</th>
		<td colspan=3><select name=account>$form->{selectaccount}</select>
		<input type=hidden name=selectaccount value="$form->{selectaccount}">
		</td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Date').qq|</th>
		<td><input name=datepaid value="$form->{datepaid}" title="$myconfig{dateformat}" size=11></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Currency').qq|</th>
		<td><select name=currency>$form->{selectcurrency}</select></td>
		<input type=hidden name=selectcurrency value="$form->{selectcurrency}">
		<input type=hidden name=oldcurrency value=$form->{oldcurrency}>
	      </tr>
	      $exchangerate
	      <tr>
		<th align=right nowrap>$rclabel</th>
		<td colspan=3><input name=source value="$form->{source}" size=10></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Amount').qq|</th>
		<td colspan=3><input name=amount size=10 value=|.$form->format_amount(\%myconfig, $form->{amount}, 2).qq|></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('From').qq|</th>
		<td><input name=transdatefrom size=11 title="$myconfig{dateformat}" value=$form->{transdatefrom}></td>
		<th align=right nowrap>|.$locale->text('to').qq|</th>
		<td><input name=transdateto size=11 title="$myconfig{dateformat}" value=$form->{transdateto}></td>
		<input type=hidden name=oldtransdatefrom value=$form->{oldtransdatefrom}>
		<input type=hidden name=oldtransdateto value=$form->{oldtransdateto}>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
|;

}


sub list_invoices {

  @column_index = qw(invnumber transdate amount due paid selectpaid);
  
  $colspan = $#column_index + 1;
  
  print qq|
  <input type=hidden name=column_index value="id @column_index">
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th class=listheading colspan=$colspan>|.$locale->text('Invoices').qq|</th>
	</tr>
|;

  $column_data{invnumber} = qq|<th nowrap>|.$locale->text('Invoice')."</th>";
  $column_data{transdate} = qq|<th nowrap>|.$locale->text('Date')."</th>";
  $column_data{amount} = qq|<th nowrap>|.$locale->text('Amount')."</th>";
  $column_data{due} = qq|<th nowrap>|.$locale->text('Due')."</th>";
  $column_data{paid} = qq|<th nowrap>|.$locale->text('Applied')."</th>";
  $column_data{selectpaid} = qq|<th nowrap>|.$locale->text('Paid in full')."</th>";
  
  print qq|
        <tr>
|;
  map { print "$column_data{$_}\n" } @column_index;
  print qq|
        </tr>
|;

  for $i (1 .. $form->{rowcount}) {

    $form->{"selectpaid_$i"} = "checked" if $form->{"selectpaid_$i"};
    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(amount due paid);
    
    $totalamount += $form->{"amount_$i"};
    $totaldue += $form->{"due_$i"};
    $totalpaid += $form->{"paid_$i"};

    map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) } qw(amount due paid);

    $column_data{invnumber} = qq|<td>$form->{"invnumber_$i"}</td>
      <input type=hidden name="invnumber_$i" value="$form->{"invnumber_$i"}">
      <input type=hidden name="id_$i" value=$form->{"id_$i"}>|;
    $column_data{transdate} = qq|<td width=15%>$form->{"transdate_$i"}</td>
      <input type=hidden name="transdate_$i" value=$form->{"transdate_$i"}>|;
    $column_data{amount} = qq|<td align=right width=15%>$form->{"amount_$i"}</td>
      <input type=hidden name="amount_$i" value=$form->{"amount_$i"}>|;
    $column_data{due} = qq|<td align=right width=15%>$form->{"due_$i"}</td>
      <input type=hidden name="due_$i" value=$form->{"due_$i"}>|;

    $column_data{paid} = qq|<td align=right width=15%>|;
    if ($form->{"selectpaid_$i"}) {
      $column_data{paid} .= qq|<input type=hidden name="paid_$i" value=$form->{"paid_$i"}>$form->{"paid_$i"}</td>|;
    } else {
      $column_data{paid} .= qq|<input name="paid_$i" size=10 value=$form->{"paid_$i"}></td>|;
    }
    $column_data{selectpaid} = qq|<td align=center width=10%><input name="selectpaid_$i" type=checkbox class=checkbox $form->{"selectpaid_$i"}></td>|;

    $j++; $j %= 2;
    print qq|
	<tr class=listrow$j>
|;
    map { print "$column_data{$_}\n" } @column_index;
    print qq|
        </tr>
|;
  }

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{amount} = qq|<th align=right>|.$form->format_amount(\%myconfig, $totalamount, 2, "&nbsp;").qq|</th>|;
  $column_data{due} = qq|<th align=right>|.$form->format_amount(\%myconfig, $totaldue, 2, "&nbsp;").qq|</th>|;
  $column_data{paid} = qq|<th align=right>|.$form->format_amount(\%myconfig, $totalpaid, 2, "&nbsp;").qq|</th>|;

  print qq|
        <tr class=listtotal>
|;
  map { print "$column_data{$_}\n" } @column_index;
  print qq|
        </tr>
      </table>
    </td>
  </tr>
|;

}


sub form_footer {

  $form->{OP}{$form->{media}} = "checked";
  
  print qq|
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
<input type=hidden name=rowcount value=$form->{rowcount}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Post').qq|">|;

  if ($latex) {
    print qq|
<input class=submit type=submit name=action value="|.$locale->text('Print').qq|">
<input class=radio type=radio name=media value=screen $form->{OP}{screen}> |.$locale->text('Screen');

    if ($myconfig{printer}) {
      print qq|
<input class=radio type=radio name=media value=printer $form->{OP}{printer}> |.$locale->text('Printer');
    }
  }

  print qq|

</form>

</body>
</html>
|;

}


sub update {
  my ($new_name_selected) = @_;

  # get customer and invoices
  $updated = &check_name($form->{vc});

  $updated = 1 if (($form->{oldtransdatefrom} ne $form->{transdatefrom}) || ($form->{oldtransdateto} ne $form->{transdateto}));
  $form->{oldtransdatefrom} = $form->{transdatefrom};
  $form->{oldtransdateto} = $form->{transdateto};
  
  if ($new_name_selected || $updated) {
    CP->get_openinvoices(\%myconfig, \%$form);
    $updated = 1;
  }

  if ($form->{currency} ne $form->{oldcurrency}) {
    $form->{oldcurrency} = $form->{currency};
    if (!$updated) {
      CP->get_openinvoices(\%myconfig, \%$form);
      $updated = 1;
    }
  }
  
  # check currency
  $buysell = ($form->{vc} eq 'customer') ? "buy" : "sell";
  
  $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{datepaid}, $buysell)));

  $amount = $form->{amount} = $form->parse_amount(\%myconfig, $form->{amount});
  
  if ($updated) {
    $form->{rowcount} = 0;
    
    $i = 0;
    foreach $ref (@{ $form->{PR} }) {
      $i++;
      $form->{"id_$i"} = $ref->{id};
      $form->{"invnumber_$i"} = $ref->{invnumber};
      $form->{"transdate_$i"} = $ref->{transdate};
      $ref->{exchangerate} = 1 unless $ref->{exchangerate};
      $form->{"amount_$i"} = $ref->{amount} / $ref->{exchangerate};
      $form->{"due_$i"} = $form->round_amount(($ref->{amount} - $ref->{paid}) / $ref->{exchangerate}, 2);
      $amount = $form->round_amount($amount - $form->{"due_$i"}, 2);
      $form->{"selectpaid_$i"} = 1 if $amount > 0;

      map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) } qw(amount due paid);

    }
    $form->{rowcount} = $i;
  }

  # recalculate
  $amount = $form->{amount};
  for $i (1 .. $form->{rowcount}) {

    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(amount due paid);

    if ($form->{"selectpaid_$i"}) {
      $amount -= $form->{"due_$i"};
      
      if ($amount < 0) {
	$form->{"selectpaid_$i"} = 0;
      } else {
	$form->{"paid_$i"} = $form->{"due_$i"};
      }
    }

    map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) } qw(amount due paid);

  }

  &form_header;
  &list_invoices;
  &form_footer;
  
}


sub post {
  
  &check_form;

  $form->redirect($locale->text('Payment posted!')) if (CP->process_payment(\%myconfig, \%$form));
  $form->error($locale->text('Cannot post payment!'));

}


sub print {
 
  &check_form;

  ($whole, $form->{decimal}) = split /\./, $form->{amount};
  
  $form->{amount} = $form->format_amount(\%myconfig, $form->{amount}, 2);
  $m = "*" x (24 - length $form->{amount});
  $form->{amount} = $locale->text($form->{currency})."$m$form->{amount}";
  
  $form->{decimal} .= "00";
  $form->{decimal} = substr($form->{decimal}, 0, 2);

  $check = new CP $myconfig{countrycode};
  $check->init;
  $form->{text_amount} = $check->num2text($whole);

  &{ "$form->{vc}_details" };

  $form->{format} = ($form->{media} eq 'screen') ? "pdf" : "postscript";
  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = "$form->{type}.tex";
  $form->{OUT} = "| $myconfig{printer}" if ($form->{media} eq 'printer');

  $form->{company} = $myconfig{company};
  $form->{address} = $myconfig{address};
 
  @a = qw(name invnumber company address text_amount addr1 addr2 addr3 addr4);
  $form->format_string(@a);

  $form->parse_template(\%myconfig, $userspath);

  $form->{callback} = "";

  $label = uc $form->{type};

# $locale->text('Check printed!')
# $locale->text('Check printing failed!')
# $locale->text('Receipt printed!')
# $locale->text('Receipt printing failed!')

  $form->redirect($locale->text("$label printed!"));
  $form->error($locale->text("$label printing failed!"));
  
}


sub customer_details { IS->customer_details(\%myconfig, \%$form) };
sub vendor_details { IR->vendor_details(\%myconfig, \%$form) };
  

sub check_form {
  
  # construct callback
  $form->{callback} = "$form->{script}?action=payment&vc=$form->{vc}&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $form->redirect unless $form->{rowcount};

  if ($form->{currency} ne $form->{oldcurrency}) {
    &update;
    exit;
  }
  
  $form->error($locale->text('Date missing!')) unless $form->{datepaid};
  $form->error($locale->text('Amount missing!')) unless $form->{amount};

  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  $datepaid = $form->datetonum($form->{datepaid}, \%myconfig);
  
  $form->error($locale->text('Cannot process payment for a closed period!')) if ($datepaid <= $closedto);

  $form->{amount} = $form->parse_amount(\%myconfig, $form->{amount});
  for $i (1 .. $form->{rowcount}) {
    $totalpaid += $form->parse_amount(\%myconfig, $form->{"paid_$i"});
    if ($form->{"paid_$i"}) {
      push(@{ $form->{paid} }, $form->{"paid_$i"});
      push(@{ $form->{due} }, $form->{"due_$i"});
      push(@{ $form->{invnumber} }, $form->{"invnumber_$i"});
      push(@{ $form->{invdate} }, $form->{"transdate_$i"});
    }
  }

  $totalpaid = $form->round_amount($totalpaid, 2);

  $form->error($locale->text('Nothing applied!')) unless $totalpaid;
  $form->error($locale->text('Amount does not equal applied!')) if ($form->{amount} != $totalpaid);

}


