#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2001
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
# Genereal Ledger
#
#======================================================================


use SL::GL;
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
  
  $form->{callback} = "$form->{script}?action=add&transfer=$form->{transfer}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  # we use this only to set a default date
  GL->transaction(\%myconfig, \%$form);
  
  map { $form->{selectaccno} .= "<option>$_->{accno}--$_->{description}\n" } @{ $form->{all_accno} };

  if ($form->{all_projects}) {
    $form->{selectprojectnumber} = "<option>\n";
    map { $form->{selectprojectnumber} .= qq|<option value="$_->{projectnumber}--$_->{id}">$_->{projectnumber}\n| } @{ $form->{all_projects} };
  }

  
  $form->{rowcount} = ($form->{transfer}) ? 2 : 9;

  # departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map { $form->{selectdepartment} .= qq|<option value="$_->{description}--$_->{id}">$_->{description}\n| } (@{ $form->{all_departments} });
  }
 
  &display_form;
  
}


sub edit {

  GL->transaction(\%myconfig, \%$form);

  map { $form->{selectaccno} .= "<option>$_->{accno}--$_->{description}\n" } @{ $form->{all_accno} };
  
  # projects
  if ($form->{all_projects}) {
    $form->{selectprojectnumber} = "<option>\n";
    map { $form->{selectprojectnumber} .= qq|<option value="$_->{projectnumber}--$_->{id}">$_->{projectnumber}\n| } @{ $form->{all_projects} };
  }

  
  # departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} }) {

    $form->{department} = "$form->{department}--$form->{department_id}";

    $form->{selectdepartment} = "<option>\n";

    map { $form->{selectdepartment} .= qq|<option value="$_->{description}--$_->{id}">$_->{description}\n| } (@{ $form->{all_departments} });
  }
 
  $form->{locked} = ($form->{revtrans}) ? '1' : ($form->datetonum($form->{transdate}, \%myconfig) <= $form->datetonum($form->{closedto}, \%myconfig));

  # readonly
  $form->{readonly} = 1 if $myconfig{acs} =~ /General Ledger--Add Transaction/; 

  $form->{title} = "Edit";
  
  &form_header;

  $i = 1;
  foreach $ref (@{ $form->{GL} }) {
    $form->{"accno_$i"} = "$ref->{accno}--$ref->{description}";

    $form->{"projectnumber_$i"} = "$ref->{projectnumber}--$ref->{project_id}";
    $form->{"fx_transaction_$i"} = $ref->{fx_transaction};
    
    if ($ref->{amount} < 0) {
      $form->{totaldebit} -= $ref->{amount};
      $form->{"debit_$i"} = $ref->{amount} * -1;
    } else {
      $form->{totalcredit} += $ref->{amount};
      $form->{"credit_$i"} = $ref->{amount};
    }

    $i++;
  }

  $form->{rowcount} = $i;
  
  &display_rows;

  &form_footer;
  
}



sub search {

  $form->{title} = $locale->text('General Ledger')." ".$locale->text('Reports');
  
  $form->all_departments(\%myconfig);
  # departments
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map { $form->{selectdepartment} .= qq|<option value="$_->{description}--$_->{id}">$_->{description}\n| } (@{ $form->{all_departments} });
 
    $department = qq|
  	<tr>
	  <th align=right nowrap>|.$locale->text('Department').qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	</tr>
|;
  }


  # accounting years
  $form->{selectaccountingyear} = "<option>\n";
  map { $form->{selectaccountingyear} .= qq|<option>$_\n| } @{ $form->{all_years} };
  $form->{selectaccountingmonth} = "<option>\n";
  map { $form->{selectaccountingmonth} .= qq|<option value=$_>|.$locale->text($form->{all_month}{$_}).qq|\n| } sort keys %{ $form->{all_month} };

  $selectfrom = qq|
        <tr>
	<th align=right>|.$locale->text('Period').qq|</th>
	<td colspan=3>
	<select name=month>$form->{selectaccountingmonth}</select>
	<select name=year>$form->{selectaccountingyear}</select>
	<input name=interval class=radio type=radio value=0 checked>|.$locale->text('Current').qq|
	<input name=interval class=radio type=radio value=1>|.$locale->text('Month').qq|
	<input name=interval class=radio type=radio value=3>|.$locale->text('Quarter').qq|
	<input name=interval class=radio type=radio value=12>|.$locale->text('Year').qq|
	</td>
      </tr>
|;

  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=sort value=transdate>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>|.$locale->text('Reference').qq|</th>
	  <td><input name=reference size=20></td>
	  <th align=right>|.$locale->text('Source').qq|</th>
	  <td><input name=source size=20></td>
	</tr>
	$department
	<tr>
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td colspan=3><input name=description size=40></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Notes').qq|</th>
	  <td colspan=3><input name=notes size=40></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('From').qq|</th>
	  <td><input name=datefrom size=11 title="$myconfig{dateformat}"></td>
	  <th align=right>|.$locale->text('To').qq|</th>
	  <td><input name=dateto size=11 title="$myconfig{dateformat}"></td>
	</tr>
	$selectfrom
	<tr>
	  <th align=right>|.$locale->text('Amount').qq| >=</th>
	  <td><input name=amountfrom size=11></td>
	  <th align=right>|.$locale->text('Amount').qq| <=</th>
	  <td><input name=amountto size=11></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Include in Report').qq|</th>
	  <td colspan=3>
	    <table>
	      <tr>
		<td>
		  <input name="category" class=radio type=radio value=X checked>&nbsp;|.$locale->text('All').qq|
		  <input name="category" class=radio type=radio value=A>&nbsp;|.$locale->text('Asset').qq|
		  <input name="category" class=radio type=radio value=C>&nbsp;|.$locale->text('Contra').qq|
		  <input name="category" class=radio type=radio value=L>&nbsp;|.$locale->text('Liability').qq|
		  <input name="category" class=radio type=radio value=Q>&nbsp;|.$locale->text('Equity').qq|
		  <input name="category" class=radio type=radio value=I>&nbsp;|.$locale->text('Income').qq|
		  <input name="category" class=radio type=radio value=E>&nbsp;|.$locale->text('Expense').qq|
		</td>
	      </tr>
	      <tr>
		<table>
		  <tr>
		    <td align=right><input name="l_id" class=checkbox type=checkbox value=Y></td>
		    <td>|.$locale->text('ID').qq|</td>
		    <td align=right><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Date').qq|</td>
		    <td align=right><input name="l_reference" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Reference').qq|</td>
		    <td align=right><input name="l_description" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Description').qq|</td>
		    <td align=right><input name="l_notes" class=checkbox type=checkbox value=Y></td>
		    <td>|.$locale->text('Notes').qq|</td>
		  </tr>
		  <tr>
		    <td align=right><input name="l_debit" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Debit').qq|</td>
		    <td align=right><input name="l_credit" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Credit').qq|</td>
		    <td align=right><input name="l_source" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Source').qq|</td>
		    <td align=right><input name="l_accno" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Account').qq|</td>
		    <td align=right><input name="l_gifi_accno" class=checkbox type=checkbox value=Y></td>
		    <td>|.$locale->text('GIFI').qq|</td>
		  </tr>
		  <tr>
		    <td align=right><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
		    <td>|.$locale->text('Subtotal').qq|</td>
		  </tr>
		</table>
	      </tr>
	    </table>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=generate_report>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;
}


sub generate_report {

  $form->{sort} = "transdate" unless $form->{sort};

  GL->all_transactions(\%myconfig, \%$form);
  
  $href = "$form->{script}?action=generate_report&direction=$form->{direction}&oldsort=$form->{oldsort}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";
  
  $form->sort_order();

  $callback = "$form->{script}?action=generate_report&direction=$form->{direction}&oldsort=$form->{oldsort}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}";
  
  %acctype = ( 'A' => $locale->text('Asset'),
               'C' => $locale->text('Contra'),
               'L' => $locale->text('Liability'),
	       'Q' => $locale->text('Equity'),
	       'I' => $locale->text('Income'),
	       'E' => $locale->text('Expense'),
	     );
  
  $form->{title} = $locale->text('General Ledger');
  
  $ml = ($form->{ml} =~ /(A|E)/) ? -1 : 1;

  unless ($form->{category} eq 'X') {
    $form->{title} .= " : ".$locale->text($acctype{$form->{category}});
  }
  if ($form->{accno}) {
    $href .= "&accno=".$form->escape($form->{accno});
    $callback .= "&accno=".$form->escape($form->{accno},1);
    $option = $locale->text('Account')." : $form->{accno} $form->{account_description}";
  }
  if ($form->{gifi_accno}) {
    $href .= "&gifi_accno=".$form->escape($form->{gifi_accno});
    $callback .= "&gifi_accno=".$form->escape($form->{gifi_accno},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('GIFI')." : $form->{gifi_accno} $form->{gifi_account_description}";
  }
  if ($form->{source}) {
    $href .= "&source=".$form->escape($form->{source});
    $callback .= "&source=".$form->escape($form->{source},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Source')." : $form->{source}";
  }
  if ($form->{reference}) {
    $href .= "&reference=".$form->escape($form->{reference});
    $callback .= "&reference=".$form->escape($form->{reference},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Reference')." : $form->{reference}";
  }
  if ($form->{department}) {
    $href .= "&department=".$form->escape($form->{department});
    $callback .= "&department=".$form->escape($form->{department},1);
    ($department) = split /--/, $form->{department};
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Department')." : $department";
  }

  if ($form->{description}) {
    $href .= "&description=".$form->escape($form->{description});
    $callback .= "&description=".$form->escape($form->{description},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Description')." : $form->{description}";
  }
  if ($form->{notes}) {
    $href .= "&notes=".$form->escape($form->{notes});
    $callback .= "&notes=".$form->escape($form->{notes},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Notes')." : $form->{notes}";
  }
   
  if ($form->{datefrom}) {
    $href .= "&datefrom=$form->{datefrom}";
    $callback .= "&datefrom=$form->{datefrom}";
    $option .= "\n<br>" if $option;
    $option .= $locale->text('From')." ".$locale->date(\%myconfig, $form->{datefrom}, 1);
  }
  if ($form->{dateto}) {
    $href .= "&dateto=$form->{dateto}";
    $callback .= "&dateto=$form->{dateto}";
    if ($form->{datefrom}) {
      $option .= " ";
    } else {
      $option .= "\n<br>" if $option;
    }
    $option .= $locale->text('To')." ".$locale->date(\%myconfig, $form->{dateto}, 1);
  }
  
  if ($form->{amountfrom}) {
    $href .= "&amountfrom=$form->{amountfrom}";
    $callback .= "&amountfrom=$form->{amountfrom}";
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Amount')." >= ".$form->format_amount(\%myconfig, $form->{amountfrom}, 2);
  }
  if ($form->{amountto}) {
    $href .= "&amountto=$form->{amountto}";
    $callback .= "&amountto=$form->{amountto}";
    if ($form->{amountfrom}) {
      $option .= " <= ";
    } else {
      $option .= "\n<br>" if $option;
      $option .= $locale->text('Amount')." <= ";
    }
    $option .= $form->format_amount(\%myconfig, $form->{amountto}, 2);
  }


  @columns = $form->sort_columns(qw(transdate id reference description notes source debit credit accno gifi_accno));

  if ($form->{link} =~ /_paid/) {
    @columns = $form->sort_columns(qw(transdate id reference description notes source cleared debit credit accno gifi_accno));
    $form->{l_cleared} = "Y";
  }

  if ($form->{accno} || $form->{gifi_accno}) {
    @columns = grep !/(accno|gifi_accno)/, @columns;
    push @columns, "balance";
    $form->{l_balance} = "Y";
  }
  
  
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

  $callback .= "&category=$form->{category}";
  $href .= "&category=$form->{category}";

  $column_header{id} = "<th><a class=listheading href=$href&sort=id>".$locale->text('ID')."</a></th>";
  $column_header{transdate} = "<th><a class=listheading href=$href&sort=transdate>".$locale->text('Date')."</a></th>";
  $column_header{reference} = "<th><a class=listheading href=$href&sort=reference>".$locale->text('Reference')."</a></th>";
  $column_header{source} = "<th><a class=listheading href=$href&sort=source>".$locale->text('Source')."</a></th>";
  $column_header{description} = "<th><a class=listheading href=$href&sort=description>".$locale->text('Description')."</a></th>";
  $column_header{notes} = "<th class=listheading>".$locale->text('Notes')."</th>";
  $column_header{debit} = "<th class=listheading>".$locale->text('Debit')."</th>";
  $column_header{credit} = "<th class=listheading>".$locale->text('Credit')."</th>";
  $column_header{accno} = "<th><a class=listheading href=$href&sort=accno>".$locale->text('Account')."</a></th>";
  $column_header{gifi_accno} = "<th><a class=listheading href=$href&sort=gifi_accno>".$locale->text('GIFI')."</a></th>";
  $column_header{balance} = "<th>".$locale->text('Balance')."</th>";
  $column_header{cleared} = qq|<th>|.$locale->text('R').qq|</th>|;
 
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

print "
        </tr>
";
  
  # add sort to callback
  $form->{callback} = "$callback&sort=$form->{sort}";
  $callback = $form->escape($form->{callback});
  
  # initial item for subtotals
  if (@{ $form->{GL} }) {
    $sameitem = $form->{GL}->[0]->{$form->{sort}};
  }
  
  if (($form->{accno} || $form->{gifi_accno}) && $form->{balance}) {

    map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
    $column_data{balance} = "<td align=right>".$form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0)."</td>";
    
    $i++; $i %= 2;
    print qq|
        <tr class=listrow$i>
|;
    map { print "$column_data{$_}\n" } @column_index;
    
    print qq|
        </tr>
|;
  }

  # reverse href
  $direction = ($form->{direction} eq 'ASC') ? "ASC" : "DESC";
  $form->sort_order();
  $href =~ s/direction=$form->{direction}/direction=$direction/;
    
  foreach $ref (@{ $form->{GL} }) {

    # if item ne sort print subtotal
    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ref->{$form->{sort}}) {
	&gl_subtotal;
      }
    }
    
    $form->{balance} += $ref->{amount};
    
    $subtotaldebit += $ref->{debit};
    $subtotalcredit += $ref->{credit};
    
    $totaldebit += $ref->{debit};
    $totalcredit += $ref->{credit};

    $ref->{debit} = $form->format_amount(\%myconfig, $ref->{debit}, 2, "&nbsp;");
    $ref->{credit} = $form->format_amount(\%myconfig, $ref->{credit}, 2, "&nbsp;");
    
    $column_data{id} = "<td>$ref->{id}</td>";
    $column_data{transdate} = "<td>$ref->{transdate}</td>";
    $column_data{reference} = "<td><a href=$ref->{module}.pl?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{reference}</td>";
    $column_data{description} = "<td>$ref->{description}&nbsp;</td>";
    $column_data{source} = "<td>$ref->{source}&nbsp;</td>";
    $column_data{notes} = "<td>$ref->{notes}&nbsp;</td>";
    $column_data{debit} = "<td align=right>$ref->{debit}</td>";
    $column_data{credit} = "<td align=right>$ref->{credit}</td>";
    $column_data{accno} = "<td><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{accno}</a></td>";
    $column_data{gifi_accno} = "<td><a href=$href&gifi_accno=$ref->{gifi_accno}&callback=$callback>$ref->{gifi_accno}</a>&nbsp;</td>";
    $column_data{balance} = "<td align=right>".$form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0)."</td>";
    $column_data{cleared} = ($ref->{cleared}) ? "<td>*</td>" : "<td>&nbsp;</td>";

    $i++; $i %= 2;
    print "
        <tr class=listrow$i>";
    map { print "$column_data{$_}\n" } @column_index;
    print "</tr>";
    
  }


  &gl_subtotal if ($form->{l_subtotal} eq 'Y');


  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
  
  $column_data{debit} = "<th align=right class=listtotal>".$form->format_amount(\%myconfig, $totaldebit, 2, "&nbsp;")."</th>";
  $column_data{credit} = "<th align=right class=listtotal>".$form->format_amount(\%myconfig, $totalcredit, 2, "&nbsp;")."</th>";
  $column_data{balance} = "<th align=right class=listtotal>".$form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0)."</th>";
  
  print qq|
	<tr class=listtotal>
|;

  map { print "$column_data{$_}\n" } @column_index;

  $i = 1;
  if ($myconfig{acs} !~ /GL--GL/) {
    $button{'GL--Add Transaction'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('GL Transaction').qq|"> |;
    $button{'GL--Add Transaction'}{order} = $i++;
  }
  if ($myconfig{acs} !~ /AR--AR/) {
    $button{'AR--Add Transaction'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('AR Transaction').qq|"> |;
    $button{'AR--Add Transaction'}{order} = $i++;
    $button{'AR--Sales Invoice'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Sales Invoice ').qq|"> |;
    $button{'AR--Sales Invoice'}{order} = $i++;
  }
  if ($myconfig{acs} !~ /AP--AP/) {
    $button{'AP--Add Transaction'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('AP Transaction').qq|"> |;
    $button{'AP--Add Transaction'}{order} = $i++;
    $button{'AP--Vendor Invoice'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Vendor Invoice ').qq|"> |;
    $button{'AP--Vendor Invoice'}{order} = $i++;
  }

  foreach $item (split /;/, $myconfig{acs}) {
    delete $button{$item};
  }
  
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
<input type=hidden name=sessionid value=$form->{sessionid}>
|;

  foreach $item (sort { $a->{order} <=> $b->{order} } %button) {
    print $item->{code};
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


sub gl_subtotal {
      
  $subtotaldebit = $form->format_amount(\%myconfig, $subtotaldebit, 2, "&nbsp;");
  $subtotalcredit = $form->format_amount(\%myconfig, $subtotalcredit, 2, "&nbsp;");
  
  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{debit} = "<th align=right class=listsubtotal>$subtotaldebit</td>";
  $column_data{credit} = "<th align=right class=listsubtotal>$subtotalcredit</td>";

  
  print "<tr class=listsubtotal>";
  map { print "$column_data{$_}\n" } @column_index;
  print "</tr>";

  $subtotaldebit = 0;
  $subtotalcredit = 0;

  $sameitem = $ref->{$form->{sort}};

}


sub update {

  @a = ();
  $count = 0;
  @flds = qw(accno debit credit projectnumber);

  for $i (1 .. $form->{rowcount}) {
    unless (($form->{"debit_$i"} eq "") && ($form->{"credit_$i"} eq "")) {
      # take accno apart
      ($form->{"accno_$i"}) = split(/--/, $form->{"accno_$i"});
      map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(debit credit);
      
      push @a, {};
      $j = $#a;
      
      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }


  for $i (1 .. $count) {
    $j = $i - 1;
    map { $form->{"${_}_$i"} = $a[$j]->{$_} } @flds;
  }

  for $i ($count + 1 .. $form->{rowcount}) {
    map { delete $form->{"${_}_$i"} } @flds;
  }

  $form->{rowcount} = $count + 1;

  &display_form;
  
}


sub display_form {

  &form_header;
  &display_rows;
  &form_footer;

}


sub display_rows {

  $form->{selectprojectnumber} = $form->unescape($form->{selectprojectnumber});
  
  $form->{totaldebit} = 0;
  $form->{totalcredit} = 0;

  for $i (1 .. $form->{rowcount}) {
 
    $form->{totaldebit} += $form->{"debit_$i"};
    $form->{totalcredit} += $form->{"credit_$i"};

    map { $form->{"${_}_$i"} = ($form->{"${_}_$i"}) ? $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) : "" } qw(debit credit);

    $selectaccno = $form->{selectaccno};
    $selectaccno =~ s/option>\Q$form->{"accno_$i"}\E/option selected>$form->{"accno_$i"}/;

    if ($form->{selectprojectnumber}) {
      $selectprojectnumber = $form->{selectprojectnumber};
      $selectprojectnumber =~ s/(<option value="$form->{"projectnumber_$i"}")/$1 selected/;
      
      $project = qq|
  <td><select name="projectnumber_$i">$selectprojectnumber</select></td>|;
    }
    
  
    if ($form->{transfer}) {
      $form->{"fx_transaction_$i"} = ($form->{"fx_transaction_$i"}) ? "checked" : "";
      $fx_transaction = qq|
  <td><input name="fx_transaction_$i" class=checkbox type=checkbox value=1 $form->{"fx_transaction_$i"}></td>
|;
    } else {
      $fx_transaction = qq|
    <input type=hidden name="fx_transaction_$i" value=$form->{"fx_transaction_$i"}>
|;
    }
    

    print qq|<tr>
  <td><select name="accno_$i">$selectaccno</select></td>
  $fx_transaction
  <td><input name="debit_$i" size=12 value=$form->{"debit_$i"}></td>
  <td><input name="credit_$i" size=12 value=$form->{"credit_$i"}></td>
  $project
</tr>

|;
  }


  print qq|
<input type=hidden name=rowcount value=$form->{rowcount}>
<input type=hidden name=selectaccno value="$form->{selectaccno}">
<input type=hidden name=selectprojectnumber value="|.$form->escape($form->{selectprojectnumber},1).qq|">|;

}


sub form_header {

  $title = $form->{title};
  if ($form->{transfer}) {
    $form->{title} = $locale->text("$title Cash Transfer Transaction");
  } else {
    $form->{title} = $locale->text("$title General Ledger Transaction");
  }
    
# $locale->text('Add Cash Transfer Transaction')
# $locale->text('Edit Cash Transfer Transaction')
# $locale->text('Add General Ledger Transaction')
# $locale->text('Edit General Ledger Transaction')
  

  $form->{selectdepartment} = $form->unescape($form->{selectdepartment});
  $form->{selectdepartment} =~ s/ selected//;
  $form->{selectdepartment} =~ s/(<option value="\Q$form->{department}\E")/$1 selected/;

  map { $form->{$_} = $form->quote($form->{$_}) } qw(reference description notes);

  if (($rows = $form->numtextrows($form->{description}, 50)) > 1) {
    $description = qq|<textarea name=description rows=$rows cols=50 wrap=soft>$form->{description}</textarea>|;
  } else {
    $description = qq|<input name=description size=50 value="$form->{description}">|;
  }
  
  if (($rows = $form->numtextrows($form->{notes}, 50)) > 1) {
    $notes = qq|<textarea name=notes rows=$rows cols=50 wrap=soft>$form->{notes}</textarea>|;
  } else {
    $notes = qq|<input name=notes size=50 value="$form->{notes}">|;
  }
  
  $department = qq|
        <tr>
	  <th align=right nowrap>|.$locale->text('Department').qq|</th>
	  <td><select name=department>$form->{selectdepartment}</select></td>
	  <input type=hidden name=selectdepartment value="|.$form->escape($form->{selectdepartment},1).qq|">
	</tr>
| if $form->{selectdepartment};

  $project = qq| 
	  <th class=listheading>|.$locale->text('Project').qq|</th>
| if $form->{selectprojectnumber};

  if ($form->{transfer}) {
    $fx_transaction = qq|
	  <th class=listheading>|.$locale->text('FX').qq|</th>
|;
  }
  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input name=id type=hidden value=$form->{id}>

<input type=hidden name=transfer value=$form->{transfer}>

<input type=hidden name=selectaccno value="$form->{selectaccno}">

<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>
<input type=hidden name=title value="$title">

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th align=right>|.$locale->text('Reference').qq|</th>
	  <td><input name=reference size=20 value="$form->{reference}"></td>
	  <th align=right>|.$locale->text('Date').qq|</th>
	  <td><input name=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate}></td>
	</tr>
	$department
	<tr>
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td colspan=3>$description</td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Notes').qq|</th>
	  <td colspan=3>$notes</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
	  <th class=listheading>|.$locale->text('Account').qq|</th>
	  $fx_transaction
	  <th class=listheading>|.$locale->text('Debit').qq|</th>
	  <th class=listheading>|.$locale->text('Credit').qq|</th>
	  $project
	</tr>
|;

}


sub form_footer {

  ($dec) = ($form->{totaldebit} =~ /\.(\d+)/);
  $dec = length $dec;
  $decimalplaces = ($dec > 2) ? $dec : 2;
  
  map { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, $decimalplaces, "&nbsp;") } qw(totaldebit totalcredit);


  $project = qq|
	  <th>&nbsp;</th>
| if $form->{selectprojectnumber};

  if ($form->{transfer}) {
    $fx_transaction = qq|
	  <th>&nbsp;</th>
|;
  }
    
  print qq|
        <tr class=listtotal>
	  <th>&nbsp;</th>
	  $fx_transaction
	  <th class=listtotal align=right>$form->{totaldebit}</th>
	  <th class=listtotal align=right>$form->{totalcredit}</th>
	  $project
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
<input type=hidden name=sessionid value=$form->{sessionid}>

<input name=callback type=hidden value="$form->{callback}">

<br>
|;

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  
  if (! $form->{readonly}) {
    
    if ($form->{id}) {
      print qq|<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
|;

      if (!$form->{locked}) {
	print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Post').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">
|;
      }

      print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Post as new').qq|">
|;
      
    } else {
      if ($transdate > $closedto) {
	print qq|<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
	<input class=submit type=submit name=action value="|.$locale->text('Post').qq|">|;
      }
    }
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }
  
  print "
  </form>

</body>
</html>
";
  
}


sub delete {

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  $form->hide_form();
  
  print qq|
<h2 class=confirm>|.$locale->text('Confirm!').qq|</h2>

<h4>|.$locale->text('Are you sure you want to delete Transaction').qq| $form->{reference}</h4>

<input name=action class=submit type=submit value="|.$locale->text('Yes').qq|">
</form>
|;

}


sub yes {

  $form->redirect($locale->text('Transaction deleted!')) if (GL->delete_transaction(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete transaction!'));
  
}


sub post {

  # check if there is something in reference and date
  $form->isblank("reference", $locale->text('Reference missing!'));
  $form->isblank("transdate", $locale->text('Transaction Date missing!'));

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);

  
  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($transdate <= $closedto);

  # add up debits and credits
  if (!$form->{adjustment}) {
    for $i (1 .. $form->{rowcount}) {
      $debit += $form->parse_amount(\%myconfig, $form->{"debit_$i"});
      $credit += $form->parse_amount(\%myconfig, $form->{"credit_$i"});
    }
    
    if ($form->round_amount($debit, 2) != $form->round_amount($credit, 2)) {
      &post_adjustment;
      exit;
    }
  }

  $form->redirect($locale->text('Transaction posted!')) if GL->post_transaction(\%myconfig, \%$form);
  $form->error($locale->text('Cannot post transaction!'));
  
}


sub post_as_new {

  $form->{id} = 0;
  &post;

}


sub post_adjustment {

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=adjustment value=1>
|;

  $form->hide_form();
  
  print qq|
<h2 class=confirm>|.$locale->text('Warning!').qq|</h2>

<h4>|.$locale->text('Out of balance transaction!').qq|</h4>

<input name=action class=submit type=submit value="|.$locale->text('Post').qq|">
</form>
|;

}


