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
# administration
#
#======================================================================


use SL::AM;
use SL::CA;
use SL::Form;
use SL::User;
use SL::RP;
use SL::GL;


1;
# end of main



sub add { &{ "add_$form->{type}" } };
sub edit { &{ "edit_$form->{type}" } };
sub save { &{ "save_$form->{type}" } };
sub delete { &{ "delete_$form->{type}" } };


sub save_as_new {

  delete $form->{id};

  &save;

}


sub add_account {
  
  $form->{title} = "Add";
  $form->{charttype} = "A";
  
  $form->{callback} = "$form->{script}?action=list_account&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  &account_header;
  &form_footer;
  
}


sub edit_account {
  
  $form->{title} = "Edit";
  
  $form->{accno} =~ s/\\'/'/g;
  $form->{accno} =~ s/\\\\/\\/g;
 
  AM->get_account(\%myconfig, \%$form);
  
  foreach my $item (split(/:/, $form->{link})) {
    $form->{$item} = "checked";
  }

  &account_header;
  &form_footer;

}


sub account_header {

  $form->{title} = $locale->text("$form->{title} Account");
  
  $checked{$form->{charttype}} = "checked";
  $checked{"$form->{category}_"} = "checked";
  $checked{CT_tax} = ($form->{CT_tax}) ? "" : "checked";
  
  map { $form->{$_} = $form->quote($form->{$_}) } qw(accno description);

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
	  <td><input name=accno size=20 value="$form->{accno}"></td>
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
		<input name=category type=radio class=radio value=C $checked{C_}>&nbsp;|.$locale->text('Contra').qq|\n<br>
		<input name=category type=radio class=radio value=L $checked{L_}>&nbsp;|.$locale->text('Liability').qq|\n<br>
		<input name=category type=radio class=radio value=Q $checked{Q_}>&nbsp;|.$locale->text('Equity').qq|\n<br>
		<input name=category type=radio class=radio value=I $checked{I_}>&nbsp;|.$locale->text('Income').qq|\n<br>
		<input name=category type=radio class=radio value=E $checked{E_}>&nbsp;|.$locale->text('Expense')
		.qq|</td>
		<td width=50>&nbsp;</td>
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
		<th align=left>|.$locale->text('Labor/Overhead').qq|</th>
	      </tr>
	      <tr>
		<td>
		<input name=AR_amount type=checkbox class=checkbox value=AR_amount $form->{AR_amount}>&nbsp;|.$locale->text('Income').qq|\n<br>
		<input name=AR_paid type=checkbox class=checkbox value=AR_paid $form->{AR_paid}>&nbsp;|.$locale->text('Payment').qq|\n<br>
		<input name=AR_tax type=checkbox class=checkbox value=AR_tax $form->{AR_tax}>&nbsp;|.$locale->text('Tax') .qq|
		</td>
		<td>
		<input name=AP_amount type=checkbox class=checkbox value=AP_amount $form->{AP_amount}>&nbsp;|.$locale->text('Expense/Asset').qq|\n<br>
		<input name=AP_paid type=checkbox class=checkbox value=AP_paid $form->{AP_paid}>&nbsp;|.$locale->text('Payment').qq|\n<br>
		<input name=AP_tax type=checkbox class=checkbox value=AP_tax $form->{AP_tax}>&nbsp;|.$locale->text('Tax') .qq|
		</td>
		<td>
		<input name=IC_sale type=checkbox class=checkbox value=IC_sale $form->{IC_sale}>&nbsp;|.$locale->text('Income').qq|\n<br>
		<input name=IC_cogs type=checkbox class=checkbox value=IC_cogs $form->{IC_cogs}>&nbsp;|.$locale->text('COGS').qq|\n<br>
		<input name=IC_taxpart type=checkbox class=checkbox value=IC_taxpart $form->{IC_taxpart}>&nbsp;|.$locale->text('Tax') .qq|
		</td>
		<td>
		<input name=IC_income type=checkbox class=checkbox value=IC_income $form->{IC_income}>&nbsp;|.$locale->text('Income').qq|\n<br>
		<input name=IC_expense type=checkbox class=checkbox value=IC_expense $form->{IC_expense}>&nbsp;|.$locale->text('Expense').qq|\n<br>
		<input name=IC_taxservice type=checkbox class=checkbox value=IC_taxservice $form->{IC_taxservice}>&nbsp;|.$locale->text('Tax') .qq|
		</td>
		<td>
		<br>
		<input name=IC_cogs type=checkbox class=checkbox value=IC_cogs $form->{IC_cogs}>&nbsp;|.$locale->text('COGS').qq|\n<br>
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
<input type=hidden name=sessionid value=$form->{sessionid}>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">
|;

  if ($form->{id}) {
    print qq|
<input type=submit class=submit name=action value="|.$locale->text('Save as new').qq|">
|;
  }

  if ($form->{id} && $form->{orphaned}) {
    print qq|<input type=submit class=submit name=action value="|.$locale->text('Delete').qq|">|;
  }

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

  
sub save_account {

  $form->isblank("accno", $locale->text('Account Number missing!'));
  $form->isblank("category", $locale->text('Account Type missing!'));
  
  # check for conflicting accounts
  if ($form->{AR} || $form->{AP} || $form->{IC}) {
    map { $a .= $form->{$_} } qw(AR AP IC);
    $form->error($locale->text('Cannot set account for more than one of AR, AP or IC')) if length $a > 2;

    map { $form->error("$form->{AR}$form->{AP}$form->{IC} ". $locale->text('account cannot be set to any other type of account')) if $form->{$_} } qw(AR_amount AR_tax AR_paid AP_amount AP_tax AP_paid IC_sale IC_cogs IC_taxpart IC_income IC_expense IC_taxservice);
  }

  foreach $item ("AR", "AP") {
    $i = 0;
    map { $i++ if $form->{$_} } ("${item}_amount", "${item}_paid", "${item}_tax");
    $form->error($locale->text('Cannot set multiple options for')." $item") if $i > 1;
  }
  
  $i = 0;
  map { $i++ if $form->{$_} } qw(IC_sale IC_cogs IC_taxpart);
  $form->error($locale->text('Cannot set multiple options for Parts Inventory')) if $i > 1;

  $i = 0;
  map { $i++ if $form->{$_} } qw(IC_income IC_expense IC_taxservice);
  $form->error($locale->text('Cannot set multiple options for Service Items')) if $i > 1;
  
  $form->redirect($locale->text('Account saved!')) if (AM->save_account(\%myconfig, \%$form));
  $form->error($locale->text('Cannot save account!'));

}


sub list_account {

  CA->all_accounts(\%myconfig, \%$form);

  $form->{title} = $locale->text('Chart of Accounts');
  
  # construct callback
  $callback = "$form->{script}?action=list_account&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";

  @column_index = qw(accno gifi_accno description debit credit link);

  $column_header{accno} = qq|<th class=listtop>|.$locale->text('Account').qq|</a></th>|;
  $column_header{gifi_accno} = qq|<th class=listtop>|.$locale->text('GIFI').qq|</a></th>|;
  $column_header{description} = qq|<th class=listtop>|.$locale->text('Description').qq|</a></th>|;
  $column_header{debit} = qq|<th class=listtop>|.$locale->text('Debit').qq|</a></th>|;
  $column_header{credit} = qq|<th class=listtop>|.$locale->text('Credit').qq|</a></th>|;
  $column_header{link} = qq|<th class=listtop>|.$locale->text('Link').qq|</a></th>|;


  $form->header;
  $colspan = $#column_index + 1;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop colspan=$colspan>$form->{title}</th>
  </tr>
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

    if ($ca->{amount} > 0) {
      $ca->{credit} = $form->format_amount(\%myconfig, $ca->{amount}, 2, "&nbsp;");
    }
    if ($ca->{amount} < 0) {
      $ca->{debit} = $form->format_amount(\%myconfig, -$ca->{amount}, 2, "&nbsp;");
    }

    $ca->{link} =~ s/:/<br>/og;

    if ($ca->{charttype} eq "H") {
      print qq|<tr class=listheading>|;

      $column_data{accno} = qq|<th><a class=listheading href=$form->{script}?action=edit_account&id=$ca->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ca->{accno}</a></th>|;
      $column_data{gifi_accno} = qq|<th class=listheading><a href=$form->{script}?action=edit_gifi&accno=$ca->{gifi_accno}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ca->{gifi_accno}</a>&nbsp;</th>|;
      $column_data{description} = qq|<th class=listheading>$ca->{description}&nbsp;</th>|;
      $column_data{debit} = qq|<th>&nbsp;</th>|;
      $column_data{credit} = qq| <th>&nbsp;</th>|;
      $column_data{link} = qq|<th>&nbsp;</th>|;

    } else {
      $i++; $i %= 2;
      print qq|
<tr valign=top class=listrow$i>|;
      $column_data{accno} = qq|<td><a href=$form->{script}?action=edit_account&id=$ca->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ca->{accno}</a></td>|;
      $column_data{gifi_accno} = qq|<td><a href=$form->{script}?action=edit_gifi&accno=$ca->{gifi_accno}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ca->{gifi_accno}</a>&nbsp;</td>|;
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


sub delete_account {

  $form->{title} = $locale->text('Delete Account');

  foreach $id (qw(inventory_accno_id income_accno_id expense_accno_id fxgain_accno_id fxloss_accno_id)) {
    if ($form->{id} == $form->{$id}) {
      $form->error($locale->text('Cannot delete default account!'));
    }
  }

  $form->redirect($locale->text('Account deleted!')) if (AM->delete_account(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete account!'));

}


sub list_gifi {

  @{ $form->{fields} } = qw(accno description);
  $form->{table} = "gifi";
  
  AM->gifi_accounts(\%myconfig, \%$form);

  $form->{title} = $locale->text('GIFI');
  
  # construct callback
  $callback = "$form->{script}?action=list_gifi&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";

  @column_index = qw(accno description);

  $column_header{accno} = qq|<th class=listheading>|.$locale->text('GIFI').qq|</a></th>|;
  $column_header{description} = qq|<th class=listheading>|.$locale->text('Description').qq|</a></th>|;


  $form->header;
  $colspan = $#column_index + 1;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop colspan=$colspan>$form->{title}</th>
  </tr>
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
    
    $column_data{accno} = qq|<td><a href=$form->{script}?action=edit_gifi&coa=1&accno=$ca->{accno}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ca->{accno}</td>|;
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
  $form->{callback} = "$form->{script}?action=list_gifi&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";

  $form->{coa} = 1;
  
  &gifi_header;
  &gifi_footer;
  
}


sub edit_gifi {
  
  $form->{title} = "Edit";
  
  AM->get_gifi(\%myconfig, \%$form);

  $form->error($locale->text('Account does not exist!')) unless $form->{accno};
  
  &gifi_header;
  &gifi_footer;
  
}


sub gifi_header {

  $form->{title} = $locale->text("$form->{title} GIFI");
  
# $locale->text('Add GIFI')
# $locale->text('Edit GIFI')

  map { $form->{$_} = $form->quote($form->{$_}) } qw(accno description);

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value="$form->{accno}">
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
	  <td><input name=accno size=20 value="$form->{accno}"></td>
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
<input type=hidden name=sessionid value=$form->{sessionid}>

<br><input type=submit class=submit name=action value="|.$locale->text('Save').qq|">|;

  if ($form->{coa}) {
    print qq|
<input type=submit class=submit name=action value="|.$locale->text('Copy to COA').qq|">
|;

    if ($form->{accno} && $form->{orphaned}) {
      print qq|<input type=submit class=submit name=action value="|.$locale->text('Delete').qq|">|;
    }
  }

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
  
  &account_header;
  &form_footer;
  
}


sub delete_gifi {

  AM->delete_gifi(\%myconfig, \%$form);
  $form->redirect($locale->text('GIFI deleted!'));

}


sub add_department {

  $form->{title} = "Add";
  $form->{role} = "P";
  
  $form->{callback} = "$form->{script}?action=add_department&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  &department_header;
  &form_footer;

}


sub edit_department {

  $form->{title} = "Edit";

  AM->get_department(\%myconfig, \%$form);

  &department_header;
  &form_footer;

}


sub list_department {

  AM->departments(\%myconfig, \%$form);

  $href = "$form->{script}?action=list_department&direction=$form->{direction}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";

  $form->sort_order();
  
  $form->{callback} = "$form->{script}?action=list_department&direction=$form->{direction}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";
  
  $callback = $form->escape($form->{callback});
  
  $form->{title} = $locale->text('Departments');

  @column_index = qw(description cost profit);

  $column_header{description} = qq|<th width=90%><a class=listheading href=$href>|.$locale->text('Description').qq|</a></th>|;
  $column_header{cost} = qq|<th class=listheading nowrap>|.$locale->text('Cost Center').qq|</th>|;
  $column_header{profit} = qq|<th class=listheading nowrap>|.$locale->text('Profit Center').qq|</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {
    
    $i++; $i %= 2;
    
    print qq|
        <tr valign=top class=listrow$i>
|;

   $costcenter = ($ref->{role} eq "C") ? "*" : "&nbsp;";
   $profitcenter = ($ref->{role} eq "P") ? "*" : "&nbsp;";
   
   $column_data{description} = qq|<td><a href=$form->{script}?action=edit_department&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{description}</td>|;
   $column_data{cost} = qq|<td align=center>$costcenter</td>|;
   $column_data{profit} = qq|<td align=center>$profitcenter</td>|;

   map { print "$column_data{$_}\n" } @column_index;

   print qq|
	</tr>
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

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=type value=department>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input class=submit type=submit name=action value="|.$locale->text('Add Department').qq|">|;

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


sub department_header {

  $form->{title} = $locale->text("$form->{title} Department");

# $locale->text('Add Department')
# $locale->text('Edit Department')

  $form->{description} = $form->quote($form->{description});

  if (($rows = $form->numtextrows($form->{description}, 60)) > 1) {
    $description = qq|<textarea name="description" rows=$rows cols=60 wrap=soft>$form->{description}</textarea>|;
  } else {
    $description = qq|<input name=description size=60 value="$form->{description}">|;
  }

  $costcenter = "checked" if $form->{role} eq "C";
  $profitcenter = "checked" if $form->{role} eq "P";
  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=department>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>|.$locale->text('Description').qq|</th>
    <td>$description</td>
  </tr>
  <tr>
    <td></td>
    <td><input type=radio style=radio name=role value="C" $costcenter> |.$locale->text('Cost Center').qq|
        <input type=radio style=radio name=role value="P" $profitcenter> |.$locale->text('Profit Center').qq|
    </td>
  <tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

}


sub save_department {

  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_department(\%myconfig, \%$form);
  $form->redirect($locale->text('Department saved!'));

}


sub delete_department {

  AM->delete_department(\%myconfig, \%$form);
  $form->redirect($locale->text('Department deleted!'));

}


sub add_business {

  $form->{title} = "Add";
  
  $form->{callback} = "$form->{script}?action=add_business&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  &business_header;
  &form_footer;

}


sub edit_business {

  $form->{title} = "Edit";

  AM->get_business(\%myconfig, \%$form);

  &business_header;

  $form->{orphaned} = 1;
  &form_footer;

}


sub list_business {

  AM->business(\%myconfig, \%$form);

  $href = "$form->{script}?action=list_business&direction=$form->{direction}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";

  $form->sort_order();
  
  $form->{callback} = "$form->{script}?action=list_business&direction=$form->{direction}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";
  
  $callback = $form->escape($form->{callback});
  
  $form->{title} = $locale->text('Type of Business');

  @column_index = qw(description discount);

  $column_header{description} = qq|<th width=90%><a class=listheading href=$href>|.$locale->text('Description').qq|</a></th>|;
  $column_header{discount} = qq|<th class=listheading>|.$locale->text('Discount').qq| %</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {
    
    $i++; $i %= 2;
    
    print qq|
        <tr valign=top class=listrow$i>
|;

   $discount = $form->format_amount(\%myconfig, $ref->{discount} * 100, 2, "&nbsp");
   
   $column_data{description} = qq|<td><a href=$form->{script}?action=edit_business&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{description}</td>|;
   $column_data{discount} = qq|<td align=right>$discount</td>|;
   
   map { print "$column_data{$_}\n" } @column_index;

   print qq|
	</tr>
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

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=type value=business>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input class=submit type=submit name=action value="|.$locale->text('Add Business').qq|">|;

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


sub business_header {

  $form->{title} = $locale->text("$form->{title} Business");

# $locale->text('Add Business')
# $locale->text('Edit Business')

  $form->{description} = $form->quote($form->{description});
  $form->{discount} = $form->format_amount(\%myconfig, $form->{discount} * 100);

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=business>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>|.$locale->text('Type of Business').qq|</th>
	  <td><input name=description size=30 value="$form->{description}"></td>
	<tr>
	<tr>
	  <th align=right>|.$locale->text('Discount').qq| %</th>
	  <td><input name=discount size=5 value=$form->{discount}></td>
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


sub save_business {

  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_business(\%myconfig, \%$form);
  $form->redirect($locale->text('Business saved!'));

}


sub delete_business {

  AM->delete_business(\%myconfig, \%$form);
  $form->redirect($locale->text('Business deleted!'));

}



sub add_sic {

  $form->{title} = "Add";
  
  $form->{callback} = "$form->{script}?action=add_sic&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  &sic_header;
  &form_footer;

}


sub edit_sic {

  $form->{title} = "Edit";

  $form->{code} =~ s/\\'/'/g;
  $form->{code} =~ s/\\\\/\\/g;
  
  AM->get_sic(\%myconfig, \%$form);
  $form->{id} = $form->{code};

  &sic_header;

  $form->{orphaned} = 1;
  &form_footer;

}


sub list_sic {

  AM->sic(\%myconfig, \%$form);

  $href = "$form->{script}?action=list_sic&direction=$form->{direction}&oldsort=$form->{oldsort}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";
  
  $form->sort_order();

  $form->{callback} = "$form->{script}?action=list_sic&direction=$form->{direction}&oldsort=$form->{oldsort}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";
  
  $callback = $form->escape($form->{callback});
  
  $form->{title} = $locale->text('Standard Industrial Codes');

  @column_index = $form->sort_columns(qw(code description));

  $column_header{code} = qq|<th><a class=listheading href=$href&sort=code>|.$locale->text('Code').qq|</a></th>|;
  $column_header{description} = qq|<th><a class=listheading href=$href&sort=description>|.$locale->text('Description').qq|</a></th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {
    
    $i++; $i %= 2;
    
    if ($ref->{sictype} eq 'H') {
      print qq|
        <tr valign=top class=listheading>
|;
      $column_data{code} = qq|<th><a href=$form->{script}?action=edit_sic&code=$ref->{code}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{code}</th>|;
      $column_data{description} = qq|<th>$ref->{description}</th>|;
     
    } else {
      print qq|
        <tr valign=top class=listrow$i>
|;

      $column_data{code} = qq|<td><a href=$form->{script}?action=edit_sic&code=$ref->{code}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{code}</td>|;
      $column_data{description} = qq|<td>$ref->{description}</td>|;

   }
    
   map { print "$column_data{$_}\n" } @column_index;

   print qq|
	</tr>
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

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=type value=sic>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input class=submit type=submit name=action value="|.$locale->text('Add SIC').qq|">|;

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


sub sic_header {

  $form->{title} = $locale->text("$form->{title} SIC");

# $locale->text('Add SIC')
# $locale->text('Edit SIC')

  map { $form->{$_} = $form->quote($form->{$_}) } qw(code description);

  $checked = ($form->{sictype} eq 'H') ? "checked" : "";

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=type value=sic>
<input type=hidden name=id value="$form->{code}">

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>|.$locale->text('Code').qq|</th>
    <td><input name=code size=10 value="$form->{code}"></td>
  <tr>
  <tr>
    <td></td>
    <th align=left><input name=sictype type=checkbox style=checkbox value="H" $checked> |.$locale->text('Heading').qq|</th>
  <tr>
  <tr>
    <th align=right>|.$locale->text('Description').qq|</th>
    <td><input name=description size=60 value="$form->{description}"></td>
  </tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

}


sub save_sic {

  $form->isblank("code", $locale->text('Code missing!'));
  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_sic(\%myconfig, \%$form);
  $form->redirect($locale->text('SIC saved!'));

}


sub delete_sic {

  AM->delete_sic(\%myconfig, \%$form);
  $form->redirect($locale->text('SIC deleted!'));

}


sub add_language {

  $form->{title} = "Add";
  
  $form->{callback} = "$form->{script}?action=add_language&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  &language_header;
  &form_footer;

}


sub edit_language {

  $form->{title} = "Edit";

  $form->{code} =~ s/\\'/'/g;
  $form->{code} =~ s/\\\\/\\/g;
  
  AM->get_language(\%myconfig, \%$form);
  $form->{id} = $form->{code};

  &language_header;

  $form->{orphaned} = 1;
  &form_footer;

}


sub list_language {

  AM->language(\%myconfig, \%$form);

  $href = "$form->{script}?action=list_language&direction=$form->{direction}&oldsort=$form->{oldsort}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";
  
  $form->sort_order();

  $form->{callback} = "$form->{script}?action=list_language&direction=$form->{direction}&oldsort=$form->{oldsort}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";
  
  $callback = $form->escape($form->{callback});
  
  $form->{title} = $locale->text('Languages');

  @column_index = $form->sort_columns(qw(code description));

  $column_header{code} = qq|<th><a class=listheading href=$href&sort=code>|.$locale->text('Code').qq|</a></th>|;
  $column_header{description} = qq|<th><a class=listheading href=$href&sort=description>|.$locale->text('Description').qq|</a></th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {
    
    $i++; $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;

    $column_data{code} = qq|<td><a href=$form->{script}?action=edit_language&code=$ref->{code}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{code}</td>|;
    $column_data{description} = qq|<td>$ref->{description}</td>|;
    
   map { print "$column_data{$_}\n" } @column_index;

   print qq|
	</tr>
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

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=type value=language>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input class=submit type=submit name=action value="|.$locale->text('Add Language').qq|">|;

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


sub language_header {

  $form->{title} = $locale->text("$form->{title} Language");

# $locale->text('Add Language')
# $locale->text('Edit Language')

  map { $form->{$_} = $form->quote($form->{$_}) } qw(code description);

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=type value=language>
<input type=hidden name=id value="$form->{code}">

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>|.$locale->text('Code').qq|</th>
    <td><input name=code size=10 value="$form->{code}"></td>
  <tr>
  <tr>
    <th align=right>|.$locale->text('Description').qq|</th>
    <td><input name=description size=60 value="$form->{description}"></td>
  </tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

}


sub save_language {

  $form->isblank("code", $locale->text('Code missing!'));
  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_language(\%myconfig, \%$form);
  $form->redirect($locale->text('Language saved!'));

}


sub delete_language {

  AM->delete_language(\%myconfig, \%$form);
  $form->redirect($locale->text('Language deleted!'));

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
<input name=type type=hidden value=template>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input name=action type=submit class=submit value="|.$locale->text('Edit').qq|">|;

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
<input type=hidden name=sessionid value=$form->{sessionid}>

<input name=callback type=hidden value="$form->{script}?action=display_form&file=$form->{file}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}">

<textarea name=body rows=25 cols=70>
$form->{body}
</textarea>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">|;

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print q|
  </form>


</body>
</html>
|;

}


sub save_template {

  AM->save_template(\%$form);
  $form->redirect($locale->text('Template saved!'));
  
}


sub defaults {
  
  # get defaults for account numbers and last numbers
  AM->defaultaccounts(\%myconfig, \%$form);

  foreach $key (keys %{ $form->{IC} }) {
    foreach $accno (sort keys %{ $form->{IC}{$key} }) {
      $form->{account}{$key} .= ($form->{IC}{$key}{$accno}{id} == $form->{defaults}{$key}) ? "<option selected>$accno--$form->{IC}{$key}{$accno}{description}\n" : "<option>$accno--$form->{IC}{$key}{$accno}{description}\n";
    }
  }

  $form->{title} = $locale->text('System Defaults');
  
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=type value=defaults>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>|.$locale->text('Business Number').qq|</th>
	  <td><input name=businessnumber size=25 value="$form->{defaults}{businessnumber}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Weight Unit').qq|</th>
	  <td><input name=weightunit size=5 value="$form->{defaults}{weightunit}"></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <th class=listheading>|.$locale->text('Last Numbers & Default Accounts').qq|</th>
  </tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Inventory Account').qq|</th>
	  <td><select name=inventory_accno>$form->{account}{IC}</select></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Income Account').qq|</th>
	  <td><select name=income_accno>$form->{account}{IC_income}</select></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Expense Account').qq|</th>
	  <td><select name=expense_accno>$form->{account}{IC_expense}</select></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Foreign Exchange Gain').qq|</th>
	  <td><select name=fxgain_accno>$form->{account}{FX_gain}</select></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Foreign Exchange Loss').qq|</th>
	  <td><select name=fxloss_accno>$form->{account}{FX_loss}</select></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <th align=left>|.$locale->text('Enter up to 3 letters separated by a colon (i.e CAD:USD:EUR) for your native and foreign currencies').qq|</th>
  </tr>
  <tr>
    <td>
    <input name=curr size=40 value="$form->{defaults}{curr}">
    </td>
  </tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Sales Invoice Number').qq|</th>
	  <td><input name=sinumber size=40 value="$form->{defaults}{sinumber}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Sales Order Number').qq|</th>
	  <td><input name=sonumber size=40 value="$form->{defaults}{sonumber}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Vendor Invoice Number').qq|</th>
	  <td><input name=vinumber size=40 value="$form->{defaults}{vinumber}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Purchase Order Number').qq|</th>
	  <td><input name=ponumber size=40 value="$form->{defaults}{ponumber}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Sales Quotation Number').qq|</th>
	  <td><input name=sqnumber size=40 value="$form->{defaults}{sqnumber}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('RFQ Number').qq|</th>
	  <td><input name=rfqnumber size=40 value="$form->{defaults}{rfqnumber}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Partnumber').qq|</th>
	  <td><input name=partnumber size=40 value="$form->{defaults}{partnumber}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Employee Number').qq|</th>
	  <td><input name=employeenumber size=40 value="$form->{defaults}{employeenumber}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Customer Number').qq|</th>
	  <td><input name=customernumber size=40 value="$form->{defaults}{customernumber}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Vendor Number').qq|</th>
	  <td><input name=vendornumber size=40 value="$form->{defaults}{vendornumber}"></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <th class=listheading>|.$locale->text('Tax Accounts').qq|</th>
  </tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th></th>
	  <th>|.$locale->text('Rate').qq| (%)</th>
	  <th>|.$locale->text('Number').qq|</th>
	</tr>
|;

  foreach $accno (sort keys %{ $form->{taxrates} }) {
    $form->{taxrates}{$accno}{rate} = $form->format_amount(\%myconfig, $form->{taxrates}{$accno}{rate});
    
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
      </table>
    </td>
  </tr>
<input name=taxaccounts type=hidden value="$form->{taxaccounts}">
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">|;

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


sub config {

  foreach $item (qw(mm-dd-yy mm/dd/yy dd-mm-yy dd/mm/yy dd.mm.yy yyyy-mm-dd)) {
    $dateformat .= ($item eq $myconfig{dateformat}) ? "<option selected>$item\n" : "<option>$item\n";
  }

  foreach $item (qw(1,000.00 1000.00 1.000,00 1000,00 1'000.00)) {
    $numberformat .= ($item eq $myconfig{numberformat}) ? "<option selected>$item\n" : "<option>$item\n";
  }

  map { $myconfig{$_} = $form->quote($myconfig{$_}) } qw(name company address signature);
  map { $myconfig{$_} =~ s/\\n/\r\n/g } qw(address signature);

  %countrycodes = User->country_codes;
  $countrycodes = '';
  
  foreach $key (sort { $countrycodes{$a} cmp $countrycodes{$b} } keys %countrycodes) {
    $countrycodes .= ($myconfig{countrycode} eq $key) ? "<option selected value=$key>$countrycodes{$key}\n" : "<option value=$key>$countrycodes{$key}\n";
  }
  $countrycodes = qq|<option value="">English\n$countrycodes|;

  opendir CSS, "css/.";
  @all = grep /.*\.css$/, readdir CSS;
  closedir CSS;

  foreach $item (@all) {
    if ($item eq $myconfig{stylesheet}) {
      $selectstylesheet .= qq|<option selected>$item\n|;
    } else {
      $selectstylesheet .= qq|<option>$item\n|;
    }
  }
  $selectstylesheet .= "<option>\n";
  
  if (%printer && $latex) {
    $selectprinter = "<option>\n";
    foreach $item (sort keys %printer) {
      if ($myconfig{printer} eq $item) {
	$selectprinter .= qq|<option value="$item" selected>$item\n|;
      } else {
	$selectprinter .= qq|<option value="$item">$item\n|;
      }
    }

    $printer = qq|
	      <tr>
		<th align=right>|.$locale->text('Printer').qq|</th>
		<td><select name=printer>$selectprinter</select></td>
	      </tr>
|;
  }
  
  $form->{title} = $locale->text('Edit Preferences for').qq| $form->{login}|;
  
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=old_password value=$myconfig{password}>
<input type=hidden name=type value=preferences>
<input type=hidden name=role value=$myconfig{role}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr>
    <td>
      <table width=100%>
        <tr valign=top>
	  <td>
	    <table>
	      <tr>
		<th align=right>|.$locale->text('Name').qq|</th>
		<td><input name=name size=20 value="$myconfig{name}"></td>
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('E-mail').qq|</th>
		<td><input name=email size=35 value="$myconfig{email}"></td>
	      </tr>
	      <tr valign=top>
		<th align=right>|.$locale->text('Signature').qq|</th>
		<td><textarea name=signature rows=3 cols=35>$myconfig{signature}</textarea></td>
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
		<td><input name=company size=35 value="$myconfig{company}"></td>
	      </tr>
	      <tr valign=top>
		<th align=right>|.$locale->text('Address').qq|</th>
		<td><textarea name=address rows=4 cols=35>$myconfig{address}</textarea></td>
	      </tr>
	    </table>
	  </td>
	  <td>
	    <table>
	      <tr>
		<th align=right>|.$locale->text('Password').qq|</th>
		<td><input type=password name=new_password size=10 value=$myconfig{password}></td>
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Confirm').qq|</th>
		<td><input type=password name=confirm_password size=10></td>
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
		<th align=right>|.$locale->text('Menu Width').qq|</th>
		<td><input name=menuwidth size=10 value="$myconfig{menuwidth}"></td>
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
		<th align=right>|.$locale->text('Session Timeout').qq|</th>
		<td><input name=timeout size=10 value="$myconfig{timeout}"></td>
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Stylesheet').qq|</th>
		<td><select name=usestylesheet>$selectstylesheet</select></td>
	      </tr>
	      $printer
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">|;

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


sub save_defaults {

  $form->redirect($locale->text('Defaults saved!')) if (AM->save_defaults(\%myconfig, \%$form));
  $form->error($locale->text('Cannot save defaults!'));

}


sub save_preferences {

  $form->{stylesheet} = $form->{usestylesheet};

  if ($form->{new_password} ne $form->{old_password}) {
    $form->error($locale->text('Password does not match!')) if $form->{new_password} ne $form->{confirm_password};
  }

  $form->redirect($locale->text('Preferences saved!')) if AM->save_preferences(\%myconfig, \%$form, $memberfile, $userspath);
  $form->error($locale->text('Cannot save preferences!'));

}


sub backup {

  if ($form->{media} eq 'email') {
    $form->error($locale->text('No email address for')." $myconfig{name}") unless ($myconfig{email});
    
    $form->{OUT} = "$sendmail";

  }

  $SIG{INT} = 'IGNORE';
  AM->backup(\%myconfig, \%$form, $userspath, $gzip);

  if ($form->{media} eq 'email') {
    $form->redirect($locale->text('Backup sent to').qq| $myconfig{email}|);
  }

}



sub audit_control {

  $form->{title} = $locale->text('Audit Control');

  AM->closedto(\%myconfig, \%$form);
  
  if ($form->{revtrans}) {
    $checked{revtransY} = "checked";
  } else {
    $checked{revtransN} = "checked";
  }
  
  if ($form->{audittrail}) {
    $checked{audittrailY} = "checked";
  } else {
    $checked{audittrailN} = "checked";
  }
 
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>|.$locale->text('Enforce transaction reversal for all dates').qq|</th>
	  <td><input name=revtrans class=radio type=radio value="1" $checked{revtransY}> |.$locale->text('Yes').qq| <input name=revtrans class=radio type=radio value="0" $checked{revtransN}> |.$locale->text('No').qq|</td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Close Books up to').qq|</th>
	  <td><input name=closedto size=11 title="$myconfig{dateformat}" value=$form->{closedto}></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Activate Audit trails').qq|</th>
	  <td><input name=audittrail class=radio type=radio value="1" $checked{audittrailY}> |.$locale->text('Yes').qq| <input name=audittrail class=radio type=radio value="0" $checked{audittrailN}> |.$locale->text('No').qq|</td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Remove Audit trails up to').qq|</th>
	  <td><input name=removeaudittrail size=11 title="$myconfig{dateformat}"></td>
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
    $msg = $locale->text('Transaction reversal enforced for all dates');
  } else {
    if ($form->{closedto}) {
      $msg = $locale->text('Transaction reversal enforced up to')
      ." ".$locale->date(\%myconfig, $form->{closedto}, 1);
    } else {
      $msg = $locale->text('Books are open');
    }
  }

  $msg .= "<p>";
  if ($form->{audittrail}) {
    $msg .= $locale->text('Audit trails enabled');
  } else {
    $msg .= $locale->text('Audit trails disabled');
  }

  $msg .= "<p>";
  if ($form->{removeaudittrail}) {
    $msg .= $locale->text('Audit trail removed up to')
    ." ".$locale->date(\%myconfig, $form->{removeaudittrail}, 1);
  }
    
  $form->redirect($msg);
  
}


sub add_warehouse {

  $form->{title} = "Add";
  
  $form->{callback} = "$form->{script}?action=add_warehouse&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  &warehouse_header;
  &form_footer;

}


sub edit_warehouse {

  $form->{title} = "Edit";

  AM->get_warehouse(\%myconfig, \%$form);

  &warehouse_header;
  &form_footer;

}


sub list_warehouse {

  AM->warehouses(\%myconfig, \%$form);

  $href = "$form->{script}?action=list_warehouse&direction=$form->{direction}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";

  $form->sort_order();
  
  $form->{callback} = "$form->{script}?action=list_warehouse&direction=$form->{direction}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";

  $callback = $form->escape($form->{callback});
  
  $form->{title} = $locale->text('Warehouses');

  @column_index = qw(description);

  $column_header{description} = qq|<th width=100%><a class=listheading href=$href>|.$locale->text('Description').qq|</a></th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {
    
    $i++; $i %= 2;
    
    print qq|
        <tr valign=top class=listrow$i>
|;

   $column_data{description} = qq|<td><a href=$form->{script}?action=edit_warehouse&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{description}</td>|;

   map { print "$column_data{$_}\n" } @column_index;

   print qq|
	</tr>
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

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=type value=warehouse>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input class=submit type=submit name=action value="|.$locale->text('Add Warehouse').qq|">|;

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



sub warehouse_header {

  $form->{title} = $locale->text("$form->{title} Warehouse");

# $locale->text('Add Warehouse')
# $locale->text('Edit Warehouse')

  $form->{description} = $form->quote($form->{description});

  if (($rows = $form->numtextrows($form->{description}, 60)) > 1) {
    $description = qq|<textarea name="description" rows=$rows cols=60 wrap=soft>$form->{description}</textarea>|;
  } else {
    $description = qq|<input name=description size=60 value="$form->{description}">|;
  }

  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=warehouse>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>|.$locale->text('Description').qq|</th>
    <td>$description</td>
  </tr>
  <tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

}


sub save_warehouse {

  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_warehouse(\%myconfig, \%$form);
  $form->redirect($locale->text('Warehouse saved!'));

}


sub delete_warehouse {

  AM->delete_warehouse(\%myconfig, \%$form);
  $form->redirect($locale->text('Warehouse deleted!'));

}


sub yearend {

  AM->earningsaccounts(\%myconfig, \%$form);
  map { $chart .= "<option>$_->{accno}--$_->{description}" } @{ $form->{chart} };
  
  $form->{title} = $locale->text('Yearend');
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=decimalplaces value=2>
<input type=hidden name=l_accno value=Y>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>|.$locale->text('Yearend').qq|</th>
	  <td><input name=todate size=11 title="$myconfig{dateformat}" value=$todate></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Reference').qq|</th>
	  <td><input name=reference size=20 value="|.$locale->text('Yearend').qq|"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td><textarea name=description rows=3 cols=50 wrap=soft></textarea></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Retained Earnings').qq|</th>
	  <td><select name=accno>$chart</select></td>
	</tr>
	<tr>
          <th align=right>|.$locale->text('Method').qq|</th>
          <td><input name=method class=radio type=radio value=accrual checked>&nbsp;|.$locale->text('Accrual').qq|&nbsp;<input name=method class=radio type=radio value=cash>&nbsp;|.$locale->text('Cash').qq|</td>
        </tr>
      </table>
    </td>
  </tr>
</table>

<hr size=3 noshade>

<input type=hidden name=nextsub value=generate_yearend>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">|;

}


sub generate_yearend {

  $form->isblank("todate", $locale->text('Yearend date missing!'));

  RP->yearend_statement(\%myconfig, \%$form);
  
  $form->{transdate} = $form->{todate};

  $earnings = 0;
  
  $form->{rowcount} = 1;
  foreach $key (keys %{ $form->{I} }) {
    if ($form->{I}{$key}{charttype} eq "A") {
      $form->{"debit_$form->{rowcount}"} = $form->{I}{$key}{this};
      $earnings += $form->{I}{$key}{this};
      $form->{"accno_$form->{rowcount}"} = $key;
      $form->{rowcount}++;
      $ok = 1;
    }
  }

  foreach $key (keys %{ $form->{E} }) {
    if ($form->{E}{$key}{charttype} eq "A") {
      $form->{"credit_$form->{rowcount}"} = $form->{E}{$key}{this} * -1;
      $earnings += $form->{E}{$key}{this};
      $form->{"accno_$form->{rowcount}"} = $key;
      $form->{rowcount}++;
      $ok = 1;
    }
  }
  if ($earnings > 0) {
    $form->{"credit_$form->{rowcount}"} = $earnings;
    $form->{"accno_$form->{rowcount}"} = $form->{accno}
  } else {
    $form->{"debit_$form->{rowcount}"} = $earnings * -1;
    $form->{"accno_$form->{rowcount}"} = $form->{accno}
  }
  
  if ($ok) {
    if (AM->post_yearend(\%myconfig, \%$form)) {
      $form->redirect($locale->text('Yearend posted!'));
    }
    $form->error($locale->text('Yearend posting failed!'));
  } else {
    $form->error('Nothing to do!');
  }
  
}



sub company_logo {
  
  $myconfig{address} =~ s/\\n/<br>/g;
  $myconfig{dbhost} = $locale->text('localhost') unless $myconfig{dbhost};

  map { $form->{$_} = $myconfig{$_} } qw(charset stylesheet);
  
  $form->{title} = $locale->text('About');
  
  # create the logo screen
  $form->header;

  print qq|
<body>

<pre>

</pre>
<center>
<a href="http://www.sql-ledger.org" target=_top><img src=sql-ledger.gif border=0></a>
<h1 class=login>|.$locale->text('Version').qq| $form->{version}</h1>

<p>
|.$locale->text('Licensed to').qq|
<p>
<b>
$myconfig{company}
<br>$myconfig{address}
</b>

<p>
<table border=0>
  <tr>
    <th align=right>|.$locale->text('User').qq|</th>
    <td>$myconfig{name}</td>
  </tr>
  <tr>
    <th align=right>|.$locale->text('Dataset').qq|</th>
    <td>$myconfig{dbname}</td>
  </tr>
  <tr>
    <th align=right>|.$locale->text('Database Host').qq|</th>
    <td>$myconfig{dbhost}</td>
  </tr>
</table>

</center>

</body>
</html>
|;

}


sub continue {
    
  &{ $form->{nextsub} };

}


