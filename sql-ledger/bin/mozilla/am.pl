#=====================================================================
# SQL-Ledger Accounting
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
# administration
#
#======================================================================


use SL::AM;
use SL::CA;
use SL::Form;
use SL::User;


1;
# end of main



sub add {

  $form->{title} = "Add";
  $form->{charttype} = "A";
  
  $form->{callback} = "$form->{script}?action=list&path=$form->{path}&login=$form->{login}&password=$form->{password}" unless $form->{callback};

  &form_header;
  &form_footer;
  
}


sub edit {
  $form->{title} = "Edit";

  # if it is a template
  if ($form->{file}) {
    $form->{type} = "template";
    &edit_template;
    exit;
  }

  AM->get_account(\%myconfig, \%$form);
  
  foreach my $item (split(/:/, $form->{link})) {
    $form->{$item} = "checked";
  }

  &form_header;
  &form_footer;

}


sub form_header {

  $form->{title} = $locale->text("$form->{title} Account");
  
  $checked{$form->{charttype}} = "checked";
  $checked{"$form->{category}_"} = "checked";
  $checked{CT_tax} = ($form->{CT_tax}) ? "" : "checked";
  
  $form->{description} =~ s/"/&quot;/g;

# this is for our parser only!
# type=submit $locale->text('Add Account')
# type=submit $locale->text('Edit Account')

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=account>

<input type=hidden name=inventory_accno_id value=$form->{inventory_accno_id}>
<input type=hidden name=income_accno_id value=$form->{income_accno_id}>
<input type=hidden name=expense_accno_id value=$form->{expense_accno_id}>
<input type=hidden name=fxgain_accno_id values=$form->{fxgain_accno_id}>
<input type=hidden name=fxloss_accno_id values=$form->{fxloss_accno_id}>

<input type=hidden name=amount value=$form->{amount}>

<table border=0 width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
	<tr>
	  <th align=right>|.$locale->text('Account Number').qq|</th>
	  <td><input name=accno size=20 value=$form->{accno}></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td><input name=description size=40 value="$form->{description}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Account Type').qq|</th>
	  <td>
	    <table>
	      <tr valign=top>
		<td><input name=category type=radio class=radio value=A $checked{A_}>&nbsp;|.$locale->text('Asset').qq|\n<br>
		<input name=category type=radio class=radio value=L $checked{L_}>&nbsp;|.$locale->text('Liability').qq|\n<br>
		<input name=category type=radio class=radio value=Q $checked{Q_}>&nbsp;|.$locale->text('Equity').qq|\n<br>
		<input name=category type=radio class=radio value=I $checked{I_}>&nbsp;|.$locale->text('Income').qq|\n<br>
		<input name=category type=radio class=radio value=E $checked{E_}>&nbsp;|.$locale->text('Expense')
		.qq|</td>
		<td>
		<input name=charttype type=radio class=radio value="H" $checked{H}>&nbsp;|.$locale->text('Heading').qq|<br>
		<input name=charttype type=radio class=radio value="A" $checked{A}>&nbsp;|.$locale->text('Account')
		.qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;


if ($form->{charttype} eq "A") {
  print qq|
	<tr>
	  <td colspan=2>
	    <table>
	      <tr>
		<th align=left>|.$locale->text('Is this a summary account to record').qq|</th>
		<td>
		<input name=AR type=checkbox class=checkbox value=AR $form->{AR}>&nbsp;|.$locale->text('AR')
		.qq|&nbsp;<input name=AP type=checkbox class=checkbox value=AP $form->{AP}>&nbsp;|.$locale->text('AP')
		.qq|&nbsp;<input name=IC type=checkbox class=checkbox value=IC $form->{IC}>&nbsp;|.$locale->text('Inventory')
		.qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
	<tr>
	  <th colspan=2>|.$locale->text('Include in drop-down menus').qq|</th>
	</tr>
	<tr valign=top>
	  <td colspan=2>
	    <table width=100%>
	      <tr>
		<th align=left>|.$locale->text('Receivables').qq|</th>
		<th align=left>|.$locale->text('Payables').qq|</th>
		<th align=left>|.$locale->text('Parts Inventory').qq|</th>
		<th align=left>|.$locale->text('Service Items').qq|</th>
	      </tr>
	      <tr>
		<td>
		<input name=AR_amount type=checkbox class=checkbox value=AR_amount $form->{AR_amount}>&nbsp;|.$locale->text('Income').qq|\n<br>
		<input name=AR_paid type=checkbox class=checkbox value=AR_paid $form->{AR_paid}>&nbsp;|.$locale->text('Payment').qq|\n<br>
		<input name=AR_tax type=checkbox class=checkbox value=AR_tax $form->{AR_tax}>&nbsp;|.$locale->text('Tax')
		.qq|
		</td>
		<td>
		<input name=AP_amount type=checkbox class=checkbox value=AP_amount $form->{AP_amount}>&nbsp;|.$locale->text('Expense/Asset').qq|\n<br>
		<input name=AP_paid type=checkbox class=checkbox value=AP_paid $form->{AP_paid}>&nbsp;|.$locale->text('Payment').qq|\n<br>
		<input name=AP_tax type=checkbox class=checkbox value=AP_tax $form->{AP_tax}>&nbsp;|.$locale->text('Tax')
		.qq|
		</td>
		<td>
		<input name=IC_sale type=checkbox class=checkbox value=IC_sale $form->{IC_sale}>&nbsp;|.$locale->text('Sales').qq|\n<br>
		<input name=IC_cogs type=checkbox class=checkbox value=IC_cogs $form->{IC_cogs}>&nbsp;|.$locale->text('COGS').qq|\n<br>
		<input name=IC_taxpart type=checkbox class=checkbox value=IC_taxpart $form->{IC_taxpart}>&nbsp;|.$locale->text('Tax')
		.qq|
		</td>
		<td>
		<input name=IC_income type=checkbox class=checkbox value=IC_income $form->{IC_income}>&nbsp;|.$locale->text('Income').qq|\n<br>
		<input name=IC_expense type=checkbox class=checkbox value=IC_expense $form->{IC_expense}>&nbsp;|.$locale->text('Expense').qq|\n<br>
		<input name=IC_taxservice type=checkbox class=checkbox value=IC_taxservice $form->{IC_taxservice}>&nbsp;|.$locale->text('Tax')
		.qq|
		</td>
	      </tr>
	    </table>
	  </td>  
	</tr>  
	<tr>
	  <td colspan=2>
	    <table>
	      <tr>
		<th align=left>|.$locale->text('Include this account on the customer/vendor forms to flag customer/vendor as taxable?').qq|</th>
		<td>
		  <input name=CT_tax type=radio class=radio value=CT_tax $form->{CT_tax}>&nbsp;|.$locale->text('Yes').qq|&nbsp;
		  <input name=CT_tax type=radio class=radio value="" $checked{CT_tax}>&nbsp;|.$locale->text('No')
		.qq|
		</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;
}

print qq|
        <tr>
	  <th align=right>|.$locale->text('GIFI').qq|</th>
	  <td><input name=gifi_accno size=9 value=$form->{gifi_accno}></td>
	</tr>
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
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">
|;

  if ($form->{id}) {
    print qq|<input type=submit class=submit name=action value="|.$locale->text('Delete').qq|">|;
  }

  print qq|
</form>

</body>
</html>
|;

}


sub save { &{ "save_$form->{type}" } };
  
sub save_account {

  $form->isblank("accno", $locale->text('Account Number missing!'));
  $form->isblank("category", $locale->text('Account Type missing!'));
  
  $form->redirect($locale->text('Account saved!')) if (AM->save_account(\%myconfig, \%$form));
  $form->error($locale->text('Cannot save account!'));

}


sub list {

  CA->all_accounts(\%myconfig, \%$form);

  $form->{title} = $locale->text('Chart of Accounts');
  
  # construct callback
  $callback = "$form->{script}?action=list&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  @column_index = qw(accno gifi_accno description debit credit link);

  $column_header{accno} = qq|<th class=listheading>|.$locale->text('Account').qq|</a></th>|;
  $column_header{gifi_accno} = qq|<th class=listheading>|.$locale->text('GIFI').qq|</a></th>|;
  $column_header{description} = qq|<th class=listheading>|.$locale->text('Description').qq|</a></th>|;
  $column_header{debit} = qq|<th class=listheading>|.$locale->text('Debit').qq|</a></th>|;
  $column_header{credit} = qq|<th class=listheading>|.$locale->text('Credit').qq|</a></th>|;
  $column_header{link} = qq|<th class=listheading>|.$locale->text('Link').qq|</a></th>|;


  $form->header;
  $colspan = $#column_index + 1;

  print qq|
<body>

<table border=0 width=100%>
  <tr><th class=listtop colspan=$colspan>$form->{title}</th></tr>
  <tr height=5></tr>
  <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;
  
  print qq|
</tr>
|;

  # escape callback
  $callback = $form->escape($callback);
  
  foreach $ca (@{ $form->{CA} }) {
    
    $ca->{debit} = "&nbsp;";
    $ca->{credit} = "&nbsp;";

    # needed if we can delete an account
    $amount = 0;

    if ($ca->{amount} > 0) {
      $amount = $ca->{amount};
      $ca->{credit} = $form->format_amount(\%myconfig, $ca->{amount}, 2, "&nbsp;");
    }
    if ($ca->{amount} < 0) {
      $amount = -$ca->{amount};
      $ca->{debit} = $form->format_amount(\%myconfig, -$ca->{amount}, 2, "&nbsp;");
    }

    $ca->{link} =~ s/:/<br>/og;

    if ($ca->{charttype} eq "H") {
      print qq|<tr class=listheading>|;

      $column_data{accno} = qq|<th><a class=listheading href=$form->{script}?action=edit&id=$ca->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ca->{accno}</a></th>|;
      $column_data{gifi_accno} = qq|<th><a class=listheading href=$form->{script}?action=edit_gifi&accno=$ca->{gifi_accno}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ca->{gifi_accno}</a>&nbsp;</th>|;
      $column_data{description} = qq|<th class=listheading>$ca->{description}&nbsp;</th>|;
      $column_data{debit} = qq|<th>&nbsp;</th>|;
      $column_data{credit} = qq| <th>&nbsp;</th>|;
      $column_data{link} = qq|<th>&nbsp;</th>|;

    } else {
      $i++; $i %= 2;
      print qq|
<tr valign=top class=listrow$i>|;
      $column_data{accno} = qq|<td><a href=$form->{script}?action=edit&id=$ca->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback&amount=$amount>$ca->{accno}</a></td>|;
      $column_data{gifi_accno} = qq|<td><a href=$form->{script}?action=edit_gifi&accno=$ca->{gifi_accno}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback&amount=$amount>$ca->{gifi_accno}</a>&nbsp;</td>|;
      $column_data{description} = qq|<td>$ca->{description}&nbsp;</td>|;
      $column_data{debit} = qq|<td align=right>$ca->{debit}</td>|;
      $column_data{credit} = qq|<td align=right>$ca->{credit}</td>|;
      $column_data{link} = qq|<td>$ca->{link}&nbsp;</td>|;
      
    }

    map { print "$column_data{$_}\n" } @column_index;
    
    print "</tr>\n";
  }
  
  print qq|
  <tr><td colspan=$colspan><hr size=3 noshade></td></tr>
</table>

</body>
</html>
|;

}


sub delete { &{ "delete_$form->{type}" } };

sub delete_account {

  $form->{title} = $locale->text('Delete Account');

  if ($form->{amount} != 0) {  
    $form->error($locale->text('Transactions exist; cannot delete account!'));
  }

  foreach $id (qw(inventory_accno_id income_accno_id expense_accno_id fxgain_accno_id fxloss_accno_id)) {
    if ($form->{id} == $form->{$id}) {
      $form->error($locale->text('Cannot delete default account!'));
    }
  }

  $form->redirect($locale->text('Account deleted!')) if (AM->delete_account(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete account!'));

}


sub list_gifi {

  @{ $form->{fields} } = (accno, description);
  $form->{table} = "gifi";
  $form->{sortorder} = "accno";
  
  AM->gifi_accounts(\%myconfig, \%$form);

  $form->{title} = $locale->text('GIFI');
  
  # construct callback
  $callback = "$form->{script}?action=list_gifi&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  @column_index = qw(accno description);

  $column_header{accno} = qq|<th class=listheading>|.$locale->text('GIFI').qq|</a></th>|;
  $column_header{description} = qq|<th class=listheading>|.$locale->text('Description').qq|</a></th>|;


  $form->header;
  $colspan = $#column_index + 1;

  print qq|
<body>

<table border=0 width=100%>
  <tr><th class=listtop colspan=$colspan>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;
  
  print qq|
</tr>
|;

  # escape callback
  $callback = $form->escape($callback);
  
  foreach $ca (@{ $form->{ALL} }) {
    
    $i++; $i %= 2;
    
    print qq|
<tr valign=top class=listrow$i>|;
    
    $column_data{accno} = qq|<td><a href=$form->{script}?action=edit_gifi&coa=1&accno=$ca->{accno}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ca->{accno}</td>|;
    $column_data{description} = qq|<td>$ca->{description}&nbsp;</td>|;
    
    map { print "$column_data{$_}\n" } @column_index;
    
    print "</tr>\n";
  }
  
  print qq|
  <tr>
    <td colspan=$colspan><hr size=3 noshade></td>
  </tr>
</table>

</body>
</html>
|;

}


sub add_gifi {
  $form->{title} = "Add";
  
  # construct callback
  $form->{callback} = "$form->{script}?action=list_gifi&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $form->{coa} = 1;
  
  &gifi_header;
  &gifi_footer;
  
}


sub edit_gifi {
  
  $form->{title} = "Edit";

  AM->get_gifi(\%myconfig, \%$form);
  
  &gifi_header;
  &gifi_footer;
  
}


sub gifi_header {

  $form->{title} = $locale->text("$form->{title} GIFI");
  
# $locale->text('Add GIFI')
# $locale->text('Edit GIFI')

  $form->{description} =~ s/"/&quot;/g;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{accno}>
<input type=hidden name=type value=gifi>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>|.$locale->text('GIFI').qq|</th>
	  <td><input name=accno size=20 value=$form->{accno}></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td><input name=description size=60 value="$form->{description}"></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

}


sub gifi_footer {

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br><input type=submit class=submit name=action value="|.$locale->text('Save').qq|">
|;

  if ($form->{coa}) {
    print qq|
<input type=submit class=submit name=action value="|.$locale->text('Copy to COA').qq|">
|;

    if ($form->{accno}) {
      print qq|<input type=submit class=submit name=action value="|.$locale->text('Delete').qq|">|;
    }
  }

  print qq|
</form>

</body>
</html>
|;

}


sub save_gifi {

  $form->isblank("accno", $locale->text('GIFI missing!'));
  AM->save_gifi(\%myconfig, \%$form);
  $form->redirect($locale->text('GIFI saved!'));

}


sub copy_to_coa {

  $form->isblank("accno", $locale->text('GIFI missing!'));

  AM->save_gifi(\%myconfig, \%$form);

  delete $form->{id};
  $form->{gifi_accno} = $form->{accno};
  $form->{title} = "Add";
  $form->{charttype} = "A";
  
  &form_header;
  &form_footer;
  
}


sub delete_gifi {

  AM->delete_gifi(\%myconfig, \%$form);
  $form->redirect($locale->text('GIFI deleted!'));

}


sub display_stylesheet {
  
  $form->{file} = "css/$myconfig{stylesheet}";
  &display_form;
  
}


sub display_form {

  $form->{file} =~ s/^(.:)*?\/|\.\.\///g;
  $form->{file} =~ s/^\/*//g;
  $form->{file} =~ s/$userspath//;

  $form->error("$!: $form->{file}") unless -f $form->{file};

  AM->load_template(\%$form);

  $form->{title} = $form->{file};

  # if it is anything but html
  if ($form->{file} !~ /\.html$/) {
    $form->{body} = "<pre>\n$form->{body}\n</pre>";
  }
    
  $form->header;

  print qq|
<body>

$form->{body}

<form method=post action=$form->{script}>

<input name=file type=hidden value=$form->{file}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input name=action type=submit class=submit value="|.$locale->text('Edit').qq|">
</form>


</body>
</html>
|;

}


sub edit_template {

  AM->load_template(\%$form);

  $form->{title} = $locale->text('Edit Template');
  # convert &nbsp to &amp;nbsp;
  $form->{body} =~ s/&nbsp;/&amp;nbsp;/gi;
  

  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input name=file type=hidden value=$form->{file}>
<input name=type type=hidden value=template>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input name=callback type=hidden value="$form->{script}?action=display_form&file=$form->{file}&path=$form->{path}&login=$form->{login}&password=$form->{password}">

<textarea name=body rows=25 cols=70>
$form->{body}
</textarea>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">

</form>


</body>
</html>
|;

}


sub save_template {

  AM->save_template(\%$form);
  $form->redirect($locale->text('Template saved!'));
  
}


sub config {

  # get defaults for account numbers and last numbers
  AM->defaultaccounts(\%myconfig, \%$form);

  foreach $item (qw(mm-dd-yy mm/dd/yy dd-mm-yy dd/mm/yy dd.mm.yy yyyy-mm-dd)) {
    $dateformat .= ($item eq $myconfig{dateformat}) ? "<option selected>$item\n" : "<option>$item\n";
  }

  foreach $item (qw(1,000.00 1000.00 1.000,00 1000,00)) {
    $numberformat .= ($item eq $myconfig{numberformat}) ? "<option selected>$item\n" : "<option>$item\n";
  }

  foreach $item (qw(name company address signature shippingpoint)) {
    $myconfig{$item} =~ s/"/&quot;/g;
  }

  foreach $item (qw(address signature)) {
    $myconfig{$item} =~ s/\\n/\r\n/g;
  }

  %countrycodes = User->country_codes;
  $countrycodes = '';
  foreach $key (sort { $countrycodes{$a} cmp $countrycodes{$b} } keys %countrycodes) {
    $countrycodes .= ($myconfig{countrycode} eq $key) ? "<option selected value=$key>$countrycodes{$key}\n" : "<option value=$key>$countrycodes{$key}\n";
  }
  $countrycodes = "<option>American English\n$countrycodes";

  foreach $key (keys %{ $form->{IC} }) {
    foreach $accno (sort keys %{ $form->{IC}{$key} }) {
      $myconfig{$key} .= ($form->{IC}{$key}{$accno}{id} == $form->{defaults}{$key}) ? "<option selected>$accno--$form->{IC}{$key}{$accno}{description}\n" : "<option>$accno--$form->{IC}{$key}{$accno}{description}\n";
    }
  }
  
  $form->{title} = $locale->text('Edit Preferences for').qq| $form->{login}|;
  
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=old_password value=$myconfig{password}>
<input type=hidden name=type value=preferences>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right>|.$locale->text('Name').qq|</th>
	  <td><input name=name size=15 value="$myconfig{name}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Password').qq|</th>
	  <td><input type=password name=password size=10 value=$myconfig{password}></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('E-mail').qq|</th>
	  <td><input name=email size=30 value="$myconfig{email}"></td>
	</tr>
	<tr valign=top>
	  <th align=right>|.$locale->text('Signature').qq|</th>
	  <td><textarea name=signature rows=3 cols=50>$myconfig{signature}</textarea></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Phone').qq|</th>
	  <td><input name=tel size=14 value="$myconfig{tel}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Fax').qq|</th>
	  <td><input name=fax size=14 value="$myconfig{fax}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Company').qq|</th>
	  <td><input name=company size=30 value="$myconfig{company}"></td>
	</tr>
	<tr valign=top>
	  <th align=right>|.$locale->text('Address').qq|</th>
	  <td><textarea name=address rows=4 cols=50>$myconfig{address}</textarea></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Date Format').qq|</th>
	  <td><select name=dateformat>$dateformat</select></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Number Format').qq|</th>
	  <td><select name=numberformat>$numberformat</select></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Dropdown Limit').qq|</th>
	  <td><input name=vclimit size=10 value="$myconfig{vclimit}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Language').qq|</th>
	  <td><select name=countrycode>$countrycodes</select></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Character Set').qq|</th>
	  <td><input name=charset size=20 value="$myconfig{charset}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Stylesheet').qq|</th>
	  <td><input name=stylesheet size=20 value="$myconfig{stylesheet}"></td>
	</tr>
	<input name=printer type=hidden value="$myconfig{printer}">
	<tr>
	  <th align=right>|.$locale->text('Ship via').qq|</th>
	  <td><input name=shippingpoint size=25 value="$myconfig{shippingpoint}"></td>
	</tr>
	<tr class=listheading>
	  <th colspan=2>&nbsp;</th>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Business Number').qq|</th>
	  <td><input name=businessnumber size=25 value="$myconfig{businessnumber}"></td>
	</tr>
	<tr>
	  <td colspan=2>
	    <table width=100%>
	      <tr>
		<th align=right>|.$locale->text('Year End').qq| (mm/dd)</th>
		<td><input name=yearend size=5 maxsize=5 value=$form->{defaults}{yearend}></td>
		<th align=right>|.$locale->text('Weight Unit').qq|</th>
		<td><input name=weightunit size=5 value="$form->{defaults}{weightunit}"></td>
	      </tr>
	    </table>
	  </td>
	</tr>
	<tr class=listheading>
	  <th class=listheading colspan=2>|.$locale->text('Last Numbers & Default Accounts').qq|</th>
	</tr>
	<tr>
	  <td colspan=2>
	    <table width=100%>
	      <tr>
		<th width=1% align=right nowrap>|.$locale->text('Inventory Account').qq|</th>
		<td><select name=inventory_accno>$myconfig{IC}</select></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Income Account').qq|</th>
		<td><select name=income_accno>$myconfig{IC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Expense Account').qq|</th>
		<td><select name=expense_accno>$myconfig{IC_expense}</select></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Foreign Exchange Gain').qq|</th>
		<td><select name=fxgain_accno>$myconfig{FX_gain}</select></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Foreign Exchange Loss').qq|</th>
		<td><select name=fxloss_accno>$myconfig{FX_loss}</select></td>
	      </tr>
	      <tr>
		<td colspan=2>|.$locale->text('Enter up to 3 letters separated by a colon (i.e CAD:USD:EUR) for your native and foreign currencies').qq|<br><input name=curr size=40 value="$form->{defaults}{curr}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Last Invoice Number').qq|</th>
		<td><input name=invnumber size=10 value=$form->{defaults}{invnumber}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Last Sales Order Number').qq|</th>
		<td><input name=sonumber size=10 value=$form->{defaults}{sonumber}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Last Purchase Order Number').qq|</th>
		<td><input name=ponumber size=10 value=$form->{defaults}{ponumber}></td>
	      </tr>
	    </table>
	  </td>
	</tr>
	<tr class=listheading>
	  <th class=listheading colspan=2>|.$locale->text('Tax Accounts').qq|</th>
	</tr>
	<tr>
	  <td colspan=2>
	    <table>
	      <tr>
		<th>&nbsp;</th>
		<th>|.$locale->text('Rate').qq| (%)</th>
		<th>|.$locale->text('Number').qq|</th>
	      </tr>
|;

  foreach $accno (sort keys %{ $form->{taxrates} }) {
    print qq|
              <tr>
		<th align=right>$form->{taxrates}{$accno}{description}</th>
		<td><input name=$form->{taxrates}{$accno}{id} size=6 value=$form->{taxrates}{$accno}{rate}></td>
		<td><input name="taxnumber_$form->{taxrates}{$accno}{id}" value="$form->{taxrates}{$accno}{taxnumber}"></td>
	      </tr>
|;
    $form->{taxaccounts} .= "$form->{taxrates}{$accno}{id} ";
  }

  chop $form->{taxaccounts};

  print qq|
<input name=taxaccounts type=hidden value="$form->{taxaccounts}">

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

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">
</form>

</body>
</html>
|;

}


sub save_preferences {

  # does stylesheet exist
  if ($form->{stylesheet}) {
    $form->error($locale->text('Stylesheet').": css/$form->{stylesheet} ".$locale->text('does not exist')) unless (-f "css/$form->{stylesheet}");
  } 

  $form->redirect($locale->text('Preferences saved!')) if (AM->save_preferences(\%myconfig, \%$form, $memberfile, $userspath));
  $form->error($locale->text('Cannot save preferences!'));

}


sub backup {

  if ($form->{media} eq 'email') {
    $form->error($locale->text('No email address for')." $myconfig{name}") unless ($myconfig{email});
    
    $form->{OUT} = "$sendmail";

  }
  
  AM->backup(\%myconfig, \%$form, $userspath);

  if ($form->{media} eq 'email') {
    $form->redirect($locale->text('Backup sent to').qq| $myconfig{email}|);
  }

}



sub audit_control {

  $form->{title} = $locale->text('Audit Control');

  AM->closedto(\%myconfig, \%$form);
  
  if ($form->{revtrans}) {
    $checked{Y} = "checked";
  } else {
    $checked{N} = "checked";
  }
  
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <td>|.$locale->text('Enforce transaction reversal for all dates').qq|</th>
	  <td><input name=revtrans class=radio type=radio value="1" $checked{Y}> |.$locale->text('Yes').qq| <input name=revtrans class=radio type=radio value="0" $checked{N}> |.$locale->text('No').qq|</td>
	</tr>
	<tr>
	  <td>|.$locale->text('Close Books up to').qq|</th>
	  <td><input name=closedto size=11 title="$myconfig{dateformat}" value=$form->{closedto}></td>
	</tr>
      </table>
    </td>
  </tr>
</table>

<hr size=3 noshade>

<br>
<input type=hidden name=nextsub value=doclose>

<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">

</form>

</body>
</html>
|;

}


sub doclose {

  AM->closebooks(\%myconfig, \%$form);
  
  if ($form->{revtrans}) {
    $form->redirect($locale->text('Transaction reversal enforced for all dates'));
  } else {
    if ($form->{closedto}) {
      $form->redirect($locale->text('Transaction reversal enforced up to')
      ." ".$locale->date(\%myconfig, $form->{closedto}, 1));
    } else {
      $form->redirect($locale->text('Books are open'));
    }
  }

}



sub continue {
    
  &{ $form->{nextsub} };

}


