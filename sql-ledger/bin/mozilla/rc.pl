#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2003
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
# Account reconciliation module
#
#======================================================================

use SL::RC;

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


sub reconciliation {
  
  RC->paymentaccounts(\%myconfig, \%$form);

  $selection = "";
  map { $selection .= "<option>$_->{accno}--$_->{description}\n" } @{ $form->{PR} };

  $form->{title} = $locale->text('Reconciliation');

  if ($form->{report}) {
    $form->{title} = $locale->text('Reconciliation Report');
    $cleared = qq|
        <input type=hidden name=report value=1>
        <tr>
	  <td align=right><input type=checkbox style=checkbox name=outstanding value=1 checked></td>
	  <td>|.$locale->text('Outstanding').qq|</td>
	  <td align=right><input type=checkbox style=checkbox name=cleared value=1></td>
	  <td>|.$locale->text('Cleared').qq|</td>
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

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>|.$locale->text('Account').qq|</th>
	  <td colspan=3><select name=accno>$selection</select>
	  </td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('From').qq|</th>
	  <td><input name=fromdate size=11 title="$myconfig{dateformat}"></td>
	  <th align=right>|.$locale->text('To').qq|</th>
	  <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
	</tr>
	$selectfrom
	$cleared
        <tr>
	  <td align=right><input type=radio style=radio name=summary value=1 checked></td>
	  <td>|.$locale->text('Summary').qq|</td>
	  <td align=right><input type=radio style=radio name=summary value=0></td>
	  <td>|.$locale->text('Detail').qq|</td>
	</tr>
	<tr>
	  <td align=right><input type=checkbox style=checkbox name=fx_transaction value=1 checked></td>
	  <td colspan=3>|.$locale->text('Include Exchange Rate Difference').qq|</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>
<input type=hidden name=nextsub value=get_payments>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">

</form>

</body>
</html>
|;

}


sub continue { &{ $form->{nextsub} } };


sub get_payments {

  ($form->{accno}, $form->{account}) = split /--/, $form->{accno};

  RC->payment_transactions(\%myconfig, \%$form);
  
  $ml = ($form->{category} eq 'A') ? -1 : 1;
  $form->{statementbalance} = $form->{endingbalance} * $ml;
  if (! $form->{fx_transaction}) {
    $form->{statementbalance} = ($form->{endingbalance} - $form->{fx_endingbalance}) * $ml;
  }
  
  $form->{statementbalance} = $form->format_amount(\%myconfig, $form->{statementbalance}, 2, 0);
  
  &display_form;

}


sub display_form {
  
  if ($form->{report}) {
    @column_index = qw(transdate source name cleared credit debit);
  } else {
    @column_index = qw(transdate source name cleared credit debit balance);
  }
  
  $column_header{cleared} = qq|<th>|.$locale->text('R').qq|</th>|;
  $column_header{source} = "<th class=listheading>".$locale->text('Source')."</a></th>";
  $column_header{name} = "<th class=listheading>".$locale->text('Description')."</a></th>";
  $column_header{transdate} = "<th class=listheading>".$locale->text('Date')."</a></th>";

  if ($form->{category} eq 'A') {
    $column_header{debit} = "<th class=listheading>".$locale->text('Deposit')."</a></th>";
    $column_header{credit} = "<th class=listheading>".$locale->text('Payment')."</a></th>";
  } else {
    $column_header{debit} = "<th class=listheading>".$locale->text('Decrease')."</a></th>";
    $column_header{credit} = "<th class=listheading>".$locale->text('Increase')."</a></th>";
  }

  $column_header{balance} = "<th class=listheading>".$locale->text('Balance')."</a></th>";

  if ($form->{fromdate}) {
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('From')."&nbsp;".$locale->date(\%myconfig, $form->{fromdate}, 1);
  }
  if ($form->{todate}) {
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('To')."&nbsp;".$locale->date(\%myconfig, $form->{todate}, 1);
  }

  $form->{title} = "$form->{accno}--$form->{account}";
  
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
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
|;

  map { print "\n$column_header{$_}" } @column_index;

  print qq|
        </tr>
|;

  $ml = ($form->{category} eq 'A') ? -1 : 1;
  $form->{beginningbalance} *= $ml;
  $form->{fx_balance} *= $ml;
  
  if (! $form->{fx_transaction}) {
    $form->{beginningbalance} -= $form->{fx_balance};
  }
  $balance = $form->{beginningbalance};
  
  $i = 0;
  $j = 0;
  
  map { $column_data{$_} = "<td>&nbsp;</td>" } qw(cleared transdate source debit credit);

  if (! $form->{report}) {
  $column_data{name} = qq|<td>|.$locale->text('Beginning Balance').qq|</td>|;
  $column_data{balance} = "<td align=right>".$form->format_amount(\%myconfig, $balance, 2, 0)."</td>";
  print qq|
	<tr class=listrow$j>
|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
	</tr>
|;
  }


  foreach $ref (@{ $form->{PR} }) {

    $i++;

    if (! $form->{fx_transaction}) {
      next if $ref->{fx_transaction};
    }

    $checked = ($ref->{cleared}) ? "checked" : "";
    
    $column_data{name} = "<td>";
    map { $column_data{name} .= "$_<br>" } @{ $ref->{name} };
    $column_data{name} .= "</td>";
    $column_data{source} = qq|<td>$ref->{source}&nbsp;</td>
    <input type=hidden name="id_$i" value=$ref->{id}>|;
    
    $column_data{debit} = "<td>&nbsp;</td>";
    $column_data{credit} = "<td>&nbsp;</td>";
    
    $balance += $ref->{amount} * $ml;

    if ($ref->{amount} < 0) {
      
      $totaldebits += $ref->{amount} * -1;

      $column_data{debit} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{amount} * -1, 2, "&nbsp;")."</td>";
      
    } else {
      
      $totalcredits += $ref->{amount};

      $column_data{credit} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{amount}, 2, "&nbsp;")."</td>";
      
    }
    
    $column_data{balance} = "<td align=right>".$form->format_amount(\%myconfig, $balance, 2, 0)."</td>";

    if ($ref->{fx_transaction}) {

      $column_data{cleared} = ($clearfx) ? qq|<td align=center>*</td>| : qq|<td>&nbsp;</td>|;
      $cleared += $ref->{amount} * $ml if $clearfx;
      
    } else {
      
      if ($form->{report}) {
	
	if ($ref->{cleared}) {
	  $column_data{cleared} = qq|<td align=center>*</td>|;
	  $clearfx = 1;
	} else {
	  $column_data{cleared} = qq|<td>&nbsp;</td>|;
	  $clearfx = 0;
	}
	
      } else {

	if ($ref->{oldcleared}) {
	  $cleared += $ref->{amount} * $ml;
	  $clearfx = 1;
	  $column_data{cleared} = qq|<td align=center>*</td>
	  <input type=hidden name="cleared_$i" value=$ref->{cleared}>
	  <input type=hidden name="oldcleared_$i" value=$ref->{oldcleared}>
	  <input type=hidden name="source_$i" value="$ref->{source}">|;
	} else {
	  $cleared += $ref->{amount} * $ml if $checked;
	  $clearfx = ($checked) ? 1 : 0;
	  $column_data{cleared} = qq|<td align=center><input name="cleared_$i" type=checkbox class=checkbox value=1 $checked>
	  <input type=hidden name="source_$i" value="$ref->{source}"></td>|;
	}
	
      }
    }
    
    $column_data{transdate} = qq|<td>$ref->{transdate}&nbsp;</td>
    <input type=hidden name="transdate_$i" value=$ref->{transdate}>|;

    $j++; $j %= 2;
    print qq|
	<tr class=listrow$j>
|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
	</tr>
|;

  }

  $form->{rowcount} = $i;
  
  # print totals
  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{debit} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totaldebits, 2, "&nbsp;")."</th>";
  $column_data{credit} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalcredits, 2, "&nbsp;")."</th>";
   
  print qq|
	<tr class=listtotal>
|;

  map { print "\n$column_data{$_}" } @column_index;
 
  $form->{statementbalance} = $form->parse_amount(\%myconfig, $form->{statementbalance});
  $difference = $form->format_amount(\%myconfig, $form->{beginningbalance} + $cleared - $form->{statementbalance}, 2, 0);
  $form->{statementbalance} = $form->format_amount(\%myconfig, $form->{statementbalance}, 2, 0);

  print qq|
	</tr>
      </table>
    </td>
  </tr>
|;

  
  if ($form->{report}) {

    print qq|
    </tr>
  </table>
|;

  } else {
    
    print qq|
   
  <tr>
    <td>
      <table width=100%>
        <tr>
	  <td align=right>
	    <table>
	      <tr>
		<th align=right nowrap>|.$locale->text('Statement Balance').qq|</th>
		<td width=10%></td>
		<td align=right><input name=statementbalance size=11 value=$form->{statementbalance}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|.$locale->text('Difference').qq|</th>
		<td width=10%></td>
		<td align=right><input name=null size=11 value=$difference></td>
		<input type=hidden name=difference value=$difference>
	      </tr>
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

<input type=hidden name=fx_transaction value=$form->{fx_transaction}>
<input type=hidden name=summary value=$form->{summary}>

<input type=hidden name=rowcount value=$form->{rowcount}>
<input type=hidden name=accno value="$form->{accno}">
<input type=hidden name=account value="$form->{account}">

<input type=hidden name=fromdate value=$form->{fromdate}>
<input type=hidden name=todate value=$form->{todate}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Update').qq|">
<input type=submit class=submit name=action value="|.$locale->text('Select all').qq|">
<input type=submit class=submit name=action value="|.$locale->text('Done').qq|">|;
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


sub update {
  
  RC->payment_transactions(\%myconfig, \%$form);

  $i = 0;
  foreach $ref (@{ $form->{PR} }) {
    $i++;
    $ref->{cleared} = ($form->{"cleared_$i"}) ? 1 : 0;
  }

  &display_form;
  
}


sub select_all {
  
  RC->payment_transactions(\%myconfig, \%$form);

  map { $_->{cleared} = 1 } @{ $form->{PR} };

  &display_form;
  
}


sub done {

  $form->{callback} = "$form->{script}?path=$form->{path}&action=reconciliation&login=$form->{login}&sessionid=$form->{sessionid}";

  $form->error($locale->text('Out of balance!')) if ($form->{difference} *= 1);

  RC->reconcile(\%myconfig, \%$form);
  $form->redirect;
  
}


