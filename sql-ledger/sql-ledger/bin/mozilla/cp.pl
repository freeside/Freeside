#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
# Contributors:
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
use SL::OP;
use SL::IS;
use SL::IR;

require "$form->{path}/arap.pl";

1;
# end of main


sub payment {
  
  $form->{callback} = "$form->{script}?action=payment&vc=$form->{vc}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&all_vc=$form->{all_vc}&type=$form->{type}";
  
  $form->{ARAP} = ($form->{type} eq 'receipt') ? "AR" : "AP";
  $form->{arap} = lc $form->{ARAP};

  # setup customer/vendor selection for open invoices
  if ($form->{all_vc}) {
    $form->all_vc(\%myconfig, $form->{vc}, $form->{ARAP});
  } else {
    CP->get_openvc(\%myconfig, \%$form);
  }

  $form->{"select$form->{vc}"} = "";
  
  if ($form->{"all_$form->{vc}"}) {
    $form->{"$form->{vc}_id"} = $form->{"all_$form->{vc}"}->[0]->{id};
    map { $form->{"select$form->{vc}"} .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } @{ $form->{"all_$form->{vc}"} };
  }

  # departments
  if (@{ $form->{all_departments} }) { 
    $form->{selectdepartment} = "<option>\n";
    $form->{department} = "$form->{department}--$form->{department_id}" if $form->{department};

    map { $form->{selectdepartment} .= qq|<option value="$_->{description}--$_->{id}">$_->{description}\n| } (@{ $form->{all_departments} });
  }

  if (@{ $form->{all_languages} }) {
    $form->{selectlanguage} = "<option>\n";
    map { $form->{selectlanguage} .= qq|<option value="$_->{code}">$_->{description}\n| } @{ $form->{all_languages} };
  }

  CP->paymentaccounts(\%myconfig, \%$form);

  $form->{selectaccount} = "";
  $form->{"select$form->{ARAP}"} = "";

  map { $form->{selectaccount} .= "<option>$_->{accno}--$_->{description}\n" } @{ $form->{PR}{"$form->{ARAP}_paid"} };
  map { $form->{"select$form->{ARAP}"} .= "<option>$_->{accno}--$_->{description}\n" } @{ $form->{PR}{$form->{ARAP}} };

  # currencies
  @curr = split /:/, $form->{currencies};
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];

  $form->{selectcurrency} = "";
  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  $form->{oldcurrency} = $form->{currency};

  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->{forex} = $form->{exchangerate} = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{datepaid}, ($form->{vc} eq 'customer') ? "buy" : "sell");
  }
  
  $form->{media} = $myconfig{printer};
  $form->{format} = "pdf" unless $myconfig{printer};

  &form_header;
  &form_footer;

}



sub form_header {

  $vclabel = ucfirst $form->{vc};
  $vclabel = $locale->text($vclabel);
  
  if ($form->{type} eq 'receipt') {
    $form->{title} = $locale->text('Receipt');
  }
  if ($form->{type} eq 'check') {
    $form->{title} = $locale->text('Payment');
  }


# $locale->text('Customer')
# $locale->text('Vendor')

  if ($form->{$form->{vc}} eq "") {
    map { $form->{$_} = "" } qw(address1 address2 city zipcode state country);
  }

  $exchangerate = "";
  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->{exchangerate} = $form->format_amount(\%myconfig, $form->{exchangerate});
    if ($form->{forex}) {
      $exchangerate = qq|
 	      <tr>
		<th align=right nowrap>|.$locale->text('Exchange Rate').qq|</th>
		<td colspan=3><input type=hidden name=exchangerate size=10 value=$form->{exchangerate}>$form->{exchangerate}</td>
	      </tr>
|;
    } else {
      $exchangerate = qq|
 	      <tr>
		<th align=right nowrap>|.$locale->text('Exchange Rate').qq|</th>
		<td colspan=3><input name=exchangerate size=10 value=$form->{exchangerate}></td>
	      </tr>
|;
    }
  }

  foreach $item ($form->{vc}, department) {
    $form->{"select$item"} = $form->unescape($form->{"select$item"});
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/(<option value="\Q$form->{$item}\E")/$1 selected/;
  }
  
  foreach $item (account, currency, $form->{ARAP}) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  $vc = ($form->{"select$form->{vc}"}) ? qq|<select name=$form->{vc}>$form->{"select$form->{vc}"}\n</select>| : qq|<input name=$form->{vc} size=35 value="$form->{$form->{vc}}">|;

  if ($form->{all_vc}) {
    $allvc = "checked";
    $form->{openinvoices} = "";
  } else {
    $allvc = "";
    $form->{openinvoices} = 1;
  }
  
# $locale->text('AR')
# $locale->text('AP')

  $department = qq|
              <tr>
	        <th align="right" nowrap>|.$locale->text('Department').qq|</th>
		<td><select name=department>$form->{selectdepartment}</select>
		<input type=hidden name=selectdepartment value="|.$form->escape($form->{selectdepartment},1).qq|">
		<input type=hidden name=olddepartment value="$form->{department}">

	      </td>
	    </tr>
| if $form->{selectdepartment};

  $form->header;

  $arap = lc $form->{ARAP};

  print qq|
<body>

<form method=post action=$form->{script}>

<!-- <input type=hidden name=id value=1> -->

<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=vc value=$form->{vc}>
<input type=hidden name=type value=$form->{type}>
<input type=hidden name=formname value=$form->{type}>
<input type=hidden name=queued value="$form->{queued}">
<input type=hidden name=arap value=$arap>
<input type=hidden name=ARAP value=$form->{ARAP}>
<input type=hidden name=openinvoices value=$form->{openinvoices}>
<input type=hidden name=title value="$form->{title}">

<table width=100%>
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
	        <td align=right>
		<input name=all_vc type=checkbox style=checkbox value=Y $allvc>
		<input type=hidden name="oldall_vc" value="$form->{all_vc}"></td>
		<th align=left>|.$locale->text('All').qq|</th>
	      </tr>
	      <tr>
		<th align=right>$vclabel</th>
		<td>$vc</td>
                <input type=hidden name="select$form->{vc}" value="|.$form->escape($form->{"select$form->{vc}"},1).qq|">
                <input type=hidden name="$form->{vc}_id" value=$form->{"$form->{vc}_id"}>
		<input type=hidden name="old$form->{vc}" value="$form->{"old$form->{vc}"}">
	      </tr>
	      <tr valign=top>
		<th align=right nowrap>|.$locale->text('Address').qq|</th>
		<td colspan=2>
		  <table>
		    <tr>
		      <td>$form->{address1}</td>
		    </tr>
		    <tr>
		      <td>$form->{address2}</td>
		    </tr>
		      <td>$form->{city}</td>
		    </tr>
		    </tr>
		      <td>$form->{state}</td>
		    </tr>
		    </tr>
		      <td>$form->{zipcode}</td>
		    </tr>
		    <tr>
		      <td>$form->{country}</td>
		    </tr>
		  </table>
		</td>
		<input type=hidden name=address1 value="$form->{address1}">
		<input type=hidden name=address2 value="$form->{address2}">
		<input type=hidden name=city value="$form->{city}">
		<input type=hidden name=state value="$form->{state}">
		<input type=hidden name=zipcode value="$form->{zipcode}">
		<input type=hidden name=country value="$form->{country}">
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Memo').qq|</th>
		<td colspan=2><input name="memo" size=30 value="$form->{memo}"></td>
	      </tr>
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      $department
	      <tr>
	        <th align=right nowrap>|.$locale->text($form->{ARAP}).qq|</th>
		<td colspan=3><select name=$form->{ARAP}>$form->{"select$form->{ARAP}"}</select>
		</td>
		<input type=hidden name="select$form->{ARAP}" value="$form->{"select$form->{ARAP}"}">
	      </tr>
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
		<th align=right nowrap>|.$locale->text('Source').qq|</th>
		<td colspan=3><input name=source value="$form->{source}" size=10></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Amount').qq|</th>
		<td colspan=3><input name=amount size=10 value=|.$form->format_amount(\%myconfig, $form->{amount}, 2).qq|></td>
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

  @column_index = qw(invnumber transdate amount due checked paid);
  
  $colspan = $#column_index + 1;

  $invoice = $locale->text('Invoices');
  
  print qq|
  <input type=hidden name=column_index value="id @column_index">
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th class=listheading colspan=$colspan>$invoice</th>
	</tr>
|;

  $column_data{invnumber} = qq|<th nowrap>|.$locale->text('Invoice')."</th>";
  $column_data{transdate} = qq|<th nowrap>|.$locale->text('Date')."</th>";
  $column_data{amount} = qq|<th nowrap>|.$locale->text('Amount')."</th>";
  $column_data{due} = qq|<th nowrap>|.$locale->text('Amount Due')."</th>";
  $column_data{paid} = qq|<th nowrap>|.$locale->text('Amount')."</th>";
  $column_data{checked} = qq|<th nowrap>|.$locale->text('Select')."</th>";
  
  print qq|
        <tr>
|;
  map { print "$column_data{$_}\n" } @column_index;
  print qq|
        </tr>
|;

  for $i (1 .. $form->{rowcount}) {

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

    $column_data{paid} = qq|<td align=right width=15%><input name="paid_$i" size=10 value=$form->{"paid_$i"}></td>|;

    $form->{"checked_$i"} = ($form->{"checked_$i"}) ? "checked" : "";
    $column_data{checked} = qq|<td align=center width=10%><input name="checked_$i" type=checkbox style=checkbox $form->{"checked_$i"}></td>|;

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

  $column_data{amount} = qq|<th class=listtotal align=right>|.$form->format_amount(\%myconfig, $totalamount, 2, "&nbsp;").qq|</th>|;
  $column_data{due} = qq|<th class=listtotal align=right>|.$form->format_amount(\%myconfig, $totaldue, 2, "&nbsp;").qq|</th>|;
  $column_data{paid} = qq|<th class=listtotal align=right>|.$form->format_amount(\%myconfig, $totalpaid, 2, "&nbsp;").qq|</th>|;

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

  $form->{DF}{$form->{format}} = "selected";

  if ($form->{selectlanguage}) {
    $form->{"selectlanguage"} = $form->unescape($form->{"selectlanguage"});
    $form->{"selectlanguage"} =~ s/ selected//;
    $form->{"selectlanguage"} =~ s/(<option value="\Q$form->{language_code}\E")/$1 selected/;
    $lang = qq|<select name=language_code>$form->{selectlanguage}</select>
    <input type=hidden name=selectlanguage value="|.
    $form->escape($form->{selectlanguage},1).qq|">|;
  }
  
  $media = qq|
          <option value=screen>|.$locale->text('Screen') if $latex;

  if (%printer && $latex) {
    map { $media .= qq| 
          <option value="$_">$_| } sort keys %printer;
  }
  if ($latex) {
    $media .= qq|
          <option value=queue>|.$locale->text('Queue');
    $format .= qq|
            <option value=postscript $form->{DF}{postscript}>|.$locale->text('Postscript').qq|
	    <option value=pdf $form->{DF}{pdf}>|.$locale->text('PDF');
  }
  
      
  print qq|
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=callback value="$form->{callback}">
<input type=hidden name=rowcount value=$form->{rowcount}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Post').qq|">|;

  if ($latex) {
    print qq|
<input class=submit type=submit name=action value="|.$locale->text('Print').qq|">|;
  }

  $media =~ s/(<option value="\Q$form->{media}\E")/$1 selected/;

  print qq|
  $lang
<select name=format>$format</select>
<select name=media>$media</select>
|;

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


sub update {
  my ($new_name_selected) = @_;

  if ($form->{vc} eq 'customer') {
    $buysell = "buy";
  } else {
    $buysell = "sell";
  }

  # get customer
  $updated = &check_name($form->{vc}, $locale->text('Nothing outstanding for ') . $form->{customer});

  if ($form->{department} ne $form->{olddepartment}) {
    $updated = 1;
  }
  
  # if we switched to all_vc
  if ($form->{all_vc} ne $form->{oldall_vc}) {

    $form->{openinvoices} = ($form->{all_vc}) ? 0 : 1;
    
    $form->{"select$form->{vc}"} = "";

    if ($form->{all_vc}) {
      $form->all_vc(\%myconfig, $form->{vc}, $form->{ARAP});
      
      if ($form->{"all_$form->{vc}"}) {
	map { $form->{"select$form->{vc}"} .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } @{ $form->{"all_$form->{vc}"} };
      }
      
    } else {
      CP->get_openvc(\%myconfig, \%$form);
      
      if ($form->{"all_$form->{vc}"}) {
	$newvc = qq|$form->{"all_$form->{vc}"}[0]->{name}--$form->{"all_$form->{vc}"}[0]->{id}|;
	map { $form->{"select$form->{vc}"} .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } @{ $form->{"all_$form->{vc}"} };


	# if the name is not the same
	if ($form->{"select$form->{vc}"} !~ /$form->{$form->{vc}}/) {
	  $form->{$form->{vc}} = $newvc;
	  &check_name($form->{vc}, $locale->text('Nothing outstanding for ') . $form->{customer});
	}
      }
    }

    if (@{ $form->{all_languages} }) {
      $form->{selectlanguage} = "<option>\n";
      map { $form->{selectlanguage} .= qq|<option value="$_->{code}">$_->{description}\n| } @{ $form->{all_languages} };
    }

  }

  if ($new_name_selected || $updated) {
    CP->get_openinvoices(\%myconfig, \%$form);
    ($newvc) = split /--/, $form->{$form->{vc}};
    $form->{"old$form->{vc}"} = qq|$newvc--$form->{"$form->{vc}_id"}|;;
    $updated = 1;
  }

  if ($form->{currency} ne $form->{oldcurrency}) {
    $form->{oldcurrency} = $form->{currency};
    if (!$updated) {
      CP->get_openinvoices(\%myconfig, \%$form);
      $updated = 1;
    }
  }
  
  
  $form->{exchangerate} = $exchangerate if ($form->{forex} = ($exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{datepaid}, $buysell)));

  $amount = $form->{amount} = $form->parse_amount(\%myconfig, $form->{amount});


  if ($updated) {
    $form->{rowcount} = 0;

    $form->{queued} = "";
    
    $i = 0;
    foreach $ref (@{ $form->{PR} }) {
      $i++;
      $form->{"id_$i"} = $ref->{id};
      $form->{"invnumber_$i"} = $ref->{invnumber};
      $form->{"transdate_$i"} = $ref->{transdate};
      $ref->{exchangerate} = 1 unless $ref->{exchangerate};
      $form->{"amount_$i"} = $ref->{amount} / $ref->{exchangerate};
      $form->{"due_$i"} = ($ref->{amount} - $ref->{paid}) / $ref->{exchangerate};
      $form->{"checked_$i"} = "";
      $form->{"paid_$i"} = "";

      # need to format
      map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) } qw(amount due);

    }
    $form->{rowcount} = $i;
  }

  # recalculate
  $amount = $form->{amount};
  for $i (1 .. $form->{rowcount}) {

    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(amount due paid);

    if ($form->{"checked_$i"}) {
      # calculate paid_$i
      if (!$form->{"paid_$i"}) {
	$form->{"paid_$i"} = $form->{"due_$i"};
      }
      
      $amount -= $form->{"paid_$i"};
    } else {
      $form->{"paid_$i"} = "";
    }

    map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) } qw(amount due paid);

  }

  &form_header;
  &list_invoices;
  &form_footer;
  
}


sub post {
  
  &check_form;
  
  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->error($locale->text('Exchange rate missing!')) unless $form->{exchangerate};
  }

  $msg1 = "$form->{title} posted!";
  $msg2 = "Cannot post $form->{title}!";

# $locale->text('Payment posted!')
# $locale->text('Receipt posted!')
# $locale->text('Cannot post Payment!')
# $locale->text('Cannot post Receipt!')


  $form->{amount} = $form->format_amount(\%myconfig, $form->{amount}, 2);

  $form->redirect($locale->text($msg1)) if (CP->process_payment(\%myconfig, \%$form));
  $form->error($locale->text($msg2));

}


sub print {
 
  &check_form;

  ($whole, $form->{decimal}) = split /\./, $form->{amount};
  
  $form->{amount} = $form->format_amount(\%myconfig, $form->{amount}, 2);
  
  $form->{decimal} .= "00";
  $form->{decimal} = substr($form->{decimal}, 0, 2);

  $countrycode = ($form->{language_code}) ? $form->{language_code} : $myconfig{countrycode};
  $check = new CP $countrycode;
  $check->init;
  $form->{text_amount} = $check->num2text($whole);

  &{ "$form->{vc}_details" };

  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = "$form->{formname}.tex";

  if ($form->{media} !~ /(screen|queue)/) {
    $form->{OUT} = "| $printer{$form->{media}}";
  }
  if ($form->{media} eq 'queue') {
    %queued = split / /, $form->{queued};
    
    if ($filename = $queued{$form->{formname}}) {
      unlink "$spool/$filename";
      $filename =~ s/\..*$//g;
    } else {
      $filename = time;
      $filename .= $$;
    }
    $filename .= ($form->{format} eq 'postscript') ? '.ps' : '.pdf';
    $form->{queued} = "$form->{formname} $filename";
    $form->{OUT} = ">$spool/$filename";

    $form->update_status(\%myconfig);

  }


  $form->{company} = $myconfig{company};
  $form->{address} = $myconfig{address};

  @a = qw(name company address text_amount address1 address2 city state zipcode country memo);
  $form->format_string(@a);

  $form->parse_template(\%myconfig, $userspath);

  &update if $form->{media} ne 'screen';

}


sub customer_details { IS->customer_details(\%myconfig, \%$form) };
sub vendor_details { IR->vendor_details(\%myconfig, \%$form) };
  

sub check_form {
  
  &check_name($form->{vc}, $locale->text('Nothing outstanding for ') . $form->{customer});

  if ($form->{currency} ne $form->{oldcurrency}) {
    &update;
    exit;
  }
  
  $form->error($locale->text('Date missing!')) unless $form->{datepaid};

  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  $datepaid = $form->datetonum($form->{datepaid}, \%myconfig);
  
  $form->error($locale->text('Cannot process payment for a closed period!')) if ($datepaid <= $closedto);

  # this is just to format the year
  $form->{datepaid} = $locale->date(\%myconfig, $form->{datepaid});
  
  $amount = $form->parse_amount(\%myconfig, $form->{amount});
  $form->{amount} = $amount;
  
  for $i (1 .. $form->{rowcount}) {
    if ($form->{"paid_$i"}) {
      $amount -= $form->parse_amount(\%myconfig, $form->{"paid_$i"});
      
      push(@{ $form->{paid} }, $form->{"paid_$i"});
      push(@{ $form->{due} }, $form->{"due_$i"});
      push(@{ $form->{invnumber} }, $form->{"invnumber_$i"});
      push(@{ $form->{invdate} }, $form->{"transdate_$i"});
    }
  }

  if ($form->round_amount($amount, 2) != 0) {
    push(@{ $form->{paid} }, $form->format_amount(\%myconfig, $amount, 2));
    push(@{ $form->{due} }, $form->format_amount(\%myconfig, 0, "0"));
    push(@{ $form->{invnumber} }, ($form->{ARAP} eq 'AR') ? $locale->text('Deposit') : $locale->text('Prepayment'));
    push(@{ $form->{invdate} }, $form->{datepaid});
  }
   
}


