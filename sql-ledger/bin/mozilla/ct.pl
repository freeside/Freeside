#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors: Reed White <alta@alta-research.com>
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
# customer/vendor module
#
#======================================================================

# $locale->text('Customers')
# $locale->text('Vendors')

use SL::CT;

1;
# end of main



sub add {

  $form->{title} = "Add";

  $form->{callback} = "$form->{script}?action=add&db=$form->{db}&path=$form->{path}&login=$form->{login}&password=$form->{password}" unless $form->{callback};

  CT->taxaccounts(\%myconfig, \%$form);
  
  &form_header;
  &form_footer;
  
}


sub search {

  $label = ucfirst $form->{db};
  $form->{title} = $locale->text($label."s");
 
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=db value=$form->{db}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Number').qq|</th>
	  <td><input name=$form->{db}number size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Name').qq|</th>
	  <td><input name=name size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Contact').qq|</th>
	  <td><input name=contact size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('E-mail').qq|</th>
	  <td><input name=email size=35></td>
	</tr>
	<tr>
	  <td></td>
	  <td><input name=status class=radio type=radio value=all checked>&nbsp;|.$locale->text('All').qq|
	  <input name=status class=radio type=radio value=orphaned>&nbsp;|.$locale->text('Orphaned').qq|</td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Include in Report').qq|</th>
	  <td>
	  <input name="l_$form->{db}number" type=checkbox class=checkbox value=Y>&nbsp;|.$locale->text('Number').qq|
	  <input name="l_name" type=checkbox class=checkbox value=Y checked>&nbsp;|.$locale->text('Name').qq|
	  <input name="l_address" type=checkbox class=checkbox value=Y>&nbsp;|.$locale->text('Address').qq|<br>
	  <input name="l_contact" type=checkbox class=checkbox value=Y checked>&nbsp;|.$locale->text('Contact').qq|
	  <input name="l_phone" type=checkbox class=checkbox value=Y checked>&nbsp;|.$locale->text('Phone').qq|
	  <input name="l_fax" type=checkbox class=checkbox value=Y>&nbsp;|.$locale->text('Fax').qq|
	  <input name="l_email" type=checkbox class=checkbox value=Y checked>&nbsp;|.$locale->text('E-mail').qq|
	  <input name="l_cc" type=checkbox class=checkbox value=Y>&nbsp;|.$locale->text('Cc').qq|
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=list_names>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;
}


sub list_names {
  
  CT->search(\%myconfig, \%$form);
  
  $callback = "$form->{script}?action=list_names&db=$form->{db}&path=$form->{path}&login=$form->{login}&password=$form->{password}&status=$form->{status}";
  $href = $callback;
  
  @columns = $form->sort_columns(name, "$form->{db}number", address, contact, phone, fax, email, cc);

  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href .= "&l_$item=Y";
    }
  }
  
  if ($form->{status} eq 'all') {
    $option = $locale->text('All');
  }
  if ($form->{status} eq 'orphaned') {
    $option .= $locale->text('Orphaned');
  }
  if ($form->{name}) {
    $callback .= "&name=$form->{name}";
    $href .= "&name=".$form->escape($form->{name});
    $option .= "\n<br>".$locale->text('Name')." : $form->{name}";
  }
  if ($form->{contact}) {
    $callback .= "&contact=$form->{contact}";
    $href .= "&contact=".$form->escape($form->{contact});
    $option .= "\n<br>".$locale->text('Contact')." : $form->{contact}";
  }
  if ($form->{"$form->{db}number"}) {
    $callback .= qq|&$form->{db}number=$form->{"$form->{db}number"}|;
    $href .= "&$form->{db}number=".$form->escape($form->{"$form->{db}number"});
    $option .= "\n<br>".$locale->text('Number').qq| : $form->{"$form->{db}number"}|;
  }
  if ($form->{email}) {
    $callback .= "&email=$form->{email}";
    $href .= "&email=".$form->escape($form->{email});
    $option .= "\n<br>".$locale->text('E-mail')." : $form->{email}";
  }

  $form->{callback} = "$callback&sort=$form->{sort}";
  $callback = $form->escape($form->{callback});
  
  $column_header{"$form->{db}number"} = qq|<th><a class=listheading href=$href&sort=$form->{db}number>|.$locale->text('Number').qq|</a></th>|;
  $column_header{name} = qq|<th><a class=listheading href=$href&sort=name>|.$locale->text('Name').qq|</a></th>|;
  $column_header{address} = qq|<th><a class=listheading href=$href&sort=address>|.$locale->text('Address').qq|</a></th>|;
  $column_header{contact} = qq|<th><a class=listheading href=$href&sort=contact>|.$locale->text('Contact').qq|</a></th>|;
  $column_header{phone} = qq|<th><a class=listheading href=$href&sort=phone>|.$locale->text('Phone').qq|</a></th>|;
  $column_header{fax} = qq|<th><a class=listheading href=$href&sort=fax>|.$locale->text('Fax').qq|</a></th>|;
  $column_header{email} = qq|<th><a class=listheading href=$href&sort=email>|.$locale->text('E-mail').qq|</a></th>|;
  $column_header{cc} = qq|<th><a class=listheading href=$href&sort=cc>|.$locale->text('Cc').qq|</a></th>|;
  
  $label = ucfirst $form->{db}."s";
  $form->{title} = $locale->text($label);

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

  map { print "$column_header{$_}\n" } @column_index;
  
  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{CT} }) {

    map { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" } ("$form->{db}number", address, contact, phone, fax);
    
    $column_data{name} = "<td><a href=$form->{script}?action=edit&id=$ref->{id}&db=$form->{db}&path=$form->{path}&login=$form->{login}&password=$form->{password}&status=$form->{status}&callback=$callback>$ref->{name}&nbsp;</td>";
    
    $column_data{email} = ($ref->{email}) ? qq|<td><a href="mailto:$ref->{email}">$ref->{email}</a></td>| : "<td>&nbsp;</td>";
    $column_data{cc} = ($ref->{cc}) ? qq|<td><a href="mailto:$ref->{cc}">$ref->{cc}</a></td>| : "<td>&nbsp;</td>";
    
    $i++; $i %= 2;
    print "
        <tr class=listrow$i>
";

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
<input name=db type=hidden value=$form->{db}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|.$locale->text('Add').qq|">

</form>

</body>
</html>
|;
 
}


sub edit {

# $locale->text('Edit Customer')
# $locale->text('Edit Vendor')

  CT->get_tuple(\%myconfig, \%$form);

  # format " into &quot;
  map { $form->{$_} =~ s/"/&quot;/g } keys %$form;

  $form->{title} = "Edit";

  # format discount
  $form->{discount} *= 100;
  
  &form_header;
  &form_footer;

}


sub form_header {

  foreach $item (split / /, $form->{taxaccounts}) {
    if (($form->{tax}{$item}{taxable}) || !($form->{id})) {
      $taxable .= qq| <input name="tax_$item" value=1 class=checkbox type=checkbox checked>&nbsp;<b>$form->{tax}{$item}{description}</b>|;
    } else {
      $taxable .= qq| <input name="tax_$item" value=1 class=checkbox type=checkbox>&nbsp;<b>$form->{tax}{$item}{description}</b>|;
    }
  }

  $tax = qq|
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right>|.$locale->text('Taxable').qq|</th>
	  <td>$taxable</td>
	</tr>
      </table>
    </td>
  </tr>
|;

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";
  $form->{creditlimit} = $form->format_amount(\%myconfig, $form->{creditlimit}, 0);
  
  if ($myconfig{admin}) {
    $bcc = qq|
        <tr>
	  <th align=right nowrap>|.$locale->text('Bcc').qq|</th>
	  <td><input name=bcc size=35 value="$form->{bcc}"></td>
	</tr>
|;
  }
  
  
  $label = ucfirst $form->{db};
  $form->{title} = $locale->text("$form->{title} $label");

  if ($form->{db} eq 'customer') {
    $creditlimit = qq|
	  <th align=right>|.$locale->text('Credit Limit').qq|</th>
	  <td><input name=creditlimit size=9 value="$form->{creditlimit}"></td>
	  <th align=right>|.$locale->text('Discount').qq|</th>
	  <td><input name=discount size=4 value="$form->{discount}"></td>
	  <th>%</th>
|;
  }

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
	  <th class=listheading colspan=2 width=50%">&nbsp;</th>
	  <th class=listheading width=50%">|.$locale->text('Ship to').qq|</th>
	</tr>
	<tr height="5"></tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Number').qq|</th>
	  <td><input name="$form->{db}number" size=35 maxsize=35 value="$form->{"$form->{db}number"}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Name').qq|</th>
	  <td><input name=name size=35 maxsize=35 value="$form->{name}"></td>
	  <td><input name=shiptoname size=35 maxsize=35 value="$form->{shiptoname}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Address').qq|</th>
	  <td><input name=addr1 size=35 maxsize=35 value="$form->{addr1}"></td>
	  <td><input name=shiptoaddr1 size=35 maxsize=35 value="$form->{shiptoaddr1}"></td>
	</tr>
	<tr>
	  <th></th>
	  <td><input name=addr2 size=35 maxsize=35 value="$form->{addr2}"></td>
	  <td><input name=shiptoaddr2 size=35 maxsize=35 value="$form->{shiptoaddr2}"></td>
	</tr>
	<tr>
	  <th></th>
	  <td><input name=addr3 size=35 maxsize=35 value="$form->{addr3}"></td>
	  <td><input name=shiptoaddr3 size=35 maxsize=35 value="$form->{shiptoaddr3}"></td>
	</tr>
	<tr>
	  <th></th>
	  <td><input name=addr4 size=35 maxsize=35 value="$form->{addr4}"></td>
	  <td><input name=shiptoaddr4 size=35 maxsize=35 value="$form->{shiptoaddr4}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Contact').qq|</th>
	  <td><input name=contact size=35 maxsize=35 value="$form->{contact}"></td>
	  <td><input name=shiptocontact size=35 maxsize=35 value="$form->{shiptocontact}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Phone').qq|</th>
	  <td><input name=phone size=20 maxsize=20 value="$form->{phone}"></td>
	  <td><input name=shiptophone size=20 maxsize=20 value="$form->{shiptophone}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Fax').qq|</th>
	  <td><input name=fax size=20 maxsize=20 value="$form->{fax}"></td>
	  <td><input name=shiptofax size=20 maxsize=20 value="$form->{shiptofax}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('E-mail').qq|</th>
	  <td><input name=email size=35 value="$form->{email}"></td>
	  <td><input name=shiptoemail size=35 value="$form->{shiptoemail}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Cc').qq|</th>
	  <td><input name=cc size=35 value="$form->{cc}"></td>
	</tr>
        $bcc
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th align=right>|.$locale->text('Terms: Net').qq|</th>
	  <td><input name=terms size=2 value="$form->{terms}"></td>
	  <th>|.$locale->text('days').qq|</th>
	  $creditlimit
	  <td><input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}></td>
	  <th align=left>|.$locale->text('Tax Included').qq|</th>
	</tr>
      </table>
    </td>
  </tr>
  $tax
  <tr>
    <th align=left nowrap>|.$locale->text('Notes').qq|</th>
  </tr>
  <tr>
    <td><textarea name=notes rows=3 cols=60 wrap=soft>$form->{notes}</textarea></td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

}



sub form_footer {

  $label = ucfirst $form->{db};

  print qq|
<input name=id type=hidden value=$form->{id}>
<input name=taxaccounts type=hidden value="$form->{taxaccounts}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input type=hidden name=callback value="$form->{callback}">
<input type=hidden name=db value=$form->{db}>

<br>

<input class=submit type=submit name=action value="|.$locale->text("Save").qq|">
<input class=submit type=submit name=action value="|.$locale->text("Invoice").qq|">
<input class=submit type=submit name=action value="|.$locale->text('Order').qq|">
|;

  if ($form->{id} && $form->{status} eq 'orphaned') {
    print qq|<input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">\n|;
  }

  print qq|
 
  </form>

</body>
</html>
|;

}


sub invoice { &{ "$form->{db}_invoice" } };

sub customer_invoice {

  $form->isblank("name", $locale->text("Name missing!"));
  CT->save_customer(\%myconfig, \%$form);
  
  delete $form->{script};
  
  $form->{action} = "add";
  $form->{callback} = $form->escape($form->{callback},1);

  $form->{customer} = $form->{name};
  $form->{customer_id} = $form->{id};
  $form->{vc} = 'customer';

  delete $form->{id};

  map { $argv .= "$_=$form->{$_}&" } keys %$form;
  
  exec ("perl", "is.pl", $argv);

}


sub vendor_invoice {

  $form->isblank("name", $locale->text("Name missing!"));
  CT->save_vendor(\%myconfig, \%$form);
  
  delete $form->{script};
  
  $form->{action} = "add";
  $form->{callback} = $form->escape($form->{callback},1);

  $form->{vendor} = $form->{name};
  $form->{vendor_id} = $form->{id};
  $form->{vc} = 'vendor';
  
  delete $form->{id};

  map { $argv .= "$_=$form->{$_}&" } keys %$form;
  
  exec ("perl", "ir.pl", $argv);

}


sub order { &{ "$form->{db}_order" } };

sub customer_order {

  $form->isblank("name", $locale->text("Name missing!"));
  CT->save_customer(\%myconfig, \%$form);
  
  delete $form->{script};
  
  $form->{action} = "add";
  $form->{callback} = $form->escape($form->{callback},1);
  
  $form->{customer} = $form->{name};
  $form->{customer_id} = $form->{id};
  $form->{vc} = 'customer';

  $form->{type} = 'sales_order';
  
  delete $form->{id};

  map { $argv .= "$_=$form->{$_}&" } keys %$form;
  
  exec ("perl", "oe.pl", $argv);

}


sub vendor_order {

  $form->isblank("name", $locale->text("Name missing!"));
  CT->save_vendor(\%myconfig, \%$form);
  
  delete $form->{script};
  
  $form->{action} = "add";
  $form->{callback} = $form->escape($form->{callback},1);
  
  $form->{vendor} = $form->{name};
  $form->{vendor_id} = $form->{id};
  $form->{vc} = 'vendor';

  $form->{type} = 'purchase_order';

  delete $form->{id};

  map { $argv .= "$_=$form->{$_}&" } keys %$form;
  
  exec ("perl", "oe.pl", $argv);

}


sub save { &{ "save_$form->{db}" } };

sub save_customer {

  $form->isblank("name", $locale->text("Name missing!"));
  CT->save_customer(\%myconfig, \%$form);
  $form->redirect($locale->text('Customer saved!'));
  
}


sub save_vendor {

  $form->isblank("name", $locale->text("Name missing!"));
  CT->save_vendor(\%myconfig, \%$form);
  $form->redirect($locale->text('Vendor saved!'));
  
}


sub delete { &{ "delete_$form->{db}" } };

sub delete_customer {

  $rc = CT->delete_customer(\%myconfig, \%$form);
  
  $form->error($locale->text('Transactions exist, cannot delete customer!')) if ($rc == -1);
  $form->redirect($locale->text('Customer deleted!')) if $rc;
  $form->error($locale->text('Cannot delete customer!'));

}


sub delete_vendor {

  $rc = CT->delete_vendor(\%myconfig, \%$form);
  
  $form->error($locale->text('Transactions exist, cannot delete vendor!')) if ($rc == -1);
  $form->redirect($locale->text('Vendor deleted!')) if $rc;
  $form->error($locale->text('Cannot delete vendor!'));

}


sub continue { &{ $form->{nextsub} } };


