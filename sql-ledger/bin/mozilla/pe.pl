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
# project administration
# partsgroup administration
# translation maintainance
#
#======================================================================


use SL::PE;

1;
# end of main



sub add {
  
  $form->{title} = "Add";

  # construct callback
  $form->{callback} = "$form->{script}?action=add&type=$form->{type}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  &{ "$form->{type}_header" };
  &{ "$form->{type}_footer" };
  
}


sub edit {
  
  $form->{title} = "Edit";

  &{ "PE::get_$form->{type}" }("", \%myconfig, \%$form);
  &{ "$form->{type}_header" };
  &{ "$form->{type}_footer" };
  
}


sub search {

  if ($form->{type} eq 'project') {
    $report = "project_report";
    $sort = 'projectnumber';
    $form->{title} = $locale->text('Projects');

    $number = qq|
	<tr>
	  <th align=right width=1%>|.$locale->text('Number').qq|</th>
	  <td><input name=projectnumber size=20></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td><input name=description size=60></td>
	</tr>
|;

  }
  if ($form->{type} eq 'partsgroup') {
    $report = "partsgroup_report";
    $sort = 'partsgroup';
    $form->{title} = $locale->text('Groups');
    
    $number = qq|
	<tr>
	  <th align=right width=1%>|.$locale->text('Group').qq|</th>
	  <td><input name=partsgroup size=20></td>
	</tr>
|;

  }
  if ($form->{type} eq 'pricegroup') {
    $report = "pricegroup_report";
    $sort = 'pricegroup';
    $form->{title} = $locale->text('Pricegroups');
    
    $number = qq|
	<tr>
	  <th align=right width=1%>|.$locale->text('Pricegroup').qq|</th>
	  <td><input name=pricegroup size=20></td>
	</tr>
|;

  }


  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=sort value=$sort>
<input type=hidden name=type value=$form->{type}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        $number
	<tr>
	  <td></td>
	  <td><input name=status class=radio type=radio value=all checked>&nbsp;|.$locale->text('All').qq|
	  <input name=status class=radio type=radio value=orphaned>&nbsp;|.$locale->text('Orphaned').qq|</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=$report>

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



sub project_report {

  map { $form->{$_} = $form->unescape($form->{$_}) } (projectnumber, description);
  PE->projects(\%myconfig, \%$form);

  $href = "$form->{script}?action=project_report&direction=$form->{direction}&oldsort=$form->{oldsort}&type=$form->{type}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&status=$form->{status}";

  $form->sort_order();
  
  $callback = "$form->{script}?action=project_report&direction=$form->{direction}&oldsort=$form->{oldsort}&type=$form->{type}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&status=$form->{status}";
  
  if ($form->{status} eq 'all') {
    $option = $locale->text('All');
  }
  if ($form->{status} eq 'orphaned') {
    $option .= $locale->text('Orphaned');
  }
  if ($form->{projectnumber}) {
    $href .= "&projectnumber=".$form->escape($form->{projectnumber});
    $callback .= "&projectnumber=$form->{projectnumber}";
    $option .= "\n<br>".$locale->text('Project')." : $form->{projectnumber}";
  }
  if ($form->{description}) {
    $href .= "&description=".$form->escape($form->{description});
    $callback .= "&description=$form->{description}";
    $option .= "\n<br>".$locale->text('Description')." : $form->{description}";
  }
    

  @column_index = $form->sort_columns(qw(projectnumber description));

  $column_header{projectnumber} = qq|<th><a class=listheading href=$href&sort=projectnumber>|.$locale->text('Number').qq|</a></th>|;
  $column_header{description} = qq|<th><a class=listheading href=$href&sort=description>|.$locale->text('Description').qq|</a></th>|;

  $form->{title} = $locale->text('Projects');

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

  # escape callback
  $form->{callback} = $callback .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($callback);
  
  foreach $ref (@{ $form->{project_list} }) {
    
    $i++; $i %= 2;
    
    print qq|
        <tr valign=top class=listrow$i>
|;
    
    $column_data{projectnumber} = qq|<td><a href=$form->{script}?action=edit&type=$form->{type}&status=$form->{status}&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{projectnumber}</td>|;
    $column_data{description} = qq|<td>$ref->{description}&nbsp;</td>|;
    
    map { print "$column_data{$_}\n" } @column_index;
    
    print "
        </tr>
";
  }
  
  $i = 1;
  if ($myconfig{acs} !~ /Projects--Projects/) {
    $button{'Projects--Add Project'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Project').qq|"> |;
    $button{'Projects--Add Project'}{order} = $i++;

    foreach $item (split /;/, $myconfig{acs}) {
      delete $button{$item};
    }
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

<input type=hidden name=type value=$form->{type}>

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


sub project_header {

  $form->{title} = $locale->text("$form->{title} Project");
  
# $locale->text('Add Project')
# $locale->text('Edit Project')

  $form->{description} = $form->quote($form->{description});

  if (($rows = $form->numtextrows($form->{description}, 60)) > 1) {
    $description = qq|<textarea name="description" rows=$rows cols=60 style="width: 100%" wrap=soft>$form->{description}</textarea>|;
  } else {
    $description = qq|<input name=description size=60 value="$form->{description}">|;
  }
  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=project>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>|.$locale->text('Number').qq|</th>
	  <td><input name=projectnumber size=20 value="$form->{projectnumber}"></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td>$description</td>
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


sub project_footer {

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>
<br>
|;

  if ($myconfig{acs} !~ /Projects--Add Project/) {
    print qq|
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">
|;

    if ($form->{id} && $form->{orphaned}) {
      print qq|
<input type=submit class=submit name=action value="|.$locale->text('Delete').qq|">|;
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


sub save {

  if ($form->{type} eq 'project') {
    $form->isblank("projectnumber", $locale->text('Project Number missing!'));
    PE->save_project(\%myconfig, \%$form);
    $form->redirect($locale->text('Project saved!'));
  }
  if ($form->{type} eq 'partsgroup') {
    $form->isblank("partsgroup", $locale->text('Group missing!'));
    PE->save_partsgroup(\%myconfig, \%$form);
    $form->redirect($locale->text('Group saved!'));
  }
  if ($form->{type} eq 'pricegroup') {
    $form->isblank("pricegroup", $locale->text('Pricegroup missing!'));
    PE->save_pricegroup(\%myconfig, \%$form);
    $form->redirect($locale->text('Pricegroup saved!'));
  }
  if ($form->{translation}) {
    PE->save_translation(\%myconfig, \%$form);
    $form->redirect($locale->text('Translations saved!'));
  }

}


sub delete {

  if ($form->{translation}) {
    PE->delete_translation(\%myconfig, \%$form);
    $form->redirect($locale->text('Translation deleted!'));

  } else {
  
    PE->delete_tuple(\%myconfig, \%$form);
    
    if ($form->{type} eq 'project') { 
      $form->redirect($locale->text('Project deleted!'));
    }
    if ($form->{type} eq 'partsgroup') {
      $form->redirect($locale->text('Group deleted!'));
    }
    if ($form->{type} eq 'pricegroup') {
      $form->redirect($locale->text('Pricegroup deleted!'));
    }
  }

}


sub continue { &{ $form->{nextsub} } };


sub partsgroup_report {

  map { $form->{$_} = $form->unescape($form->{$_}) } (partsgroup);
  PE->partsgroups(\%myconfig, \%$form);

  $href = "$form->{script}?action=partsgroup_report&direction=$form->{direction}&oldsort=$form->{oldsort}&type=$form->{type}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&status=$form->{status}";
  
  $form->sort_order();

  $callback = "$form->{script}?action=partsgroup_report&direction=$form->{direction}&oldsort=$form->{oldsort}&type=$form->{type}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&status=$form->{status}";
  
  if ($form->{status} eq 'all') {
    $option = $locale->text('All');
  }
  if ($form->{status} eq 'orphaned') {
    $option .= $locale->text('Orphaned');
  }
  if ($form->{partsgroup}) {
    $callback .= "&partsgroup=$form->{partsgroup}";
    $option .= "\n<br>".$locale->text('Group')." : $form->{partsgroup}";
  }
   

  @column_index = $form->sort_columns(qw(partsgroup));

  $column_header{partsgroup} = qq|<th><a class=listheading href=$href&sort=partsgroup width=90%>|.$locale->text('Group').qq|</a></th>|;

  $form->{title} = $locale->text('Groups');

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

  # escape callback
  $form->{callback} = $callback;

  # escape callback for href
  $callback = $form->escape($callback);
  
  foreach $ref (@{ $form->{item_list} }) {
    
    $i++; $i %= 2;
    
    print qq|
        <tr valign=top class=listrow$i>
|;
    
    $column_data{partsgroup} = qq|<td><a href=$form->{script}?action=edit&type=$form->{type}&status=$form->{status}&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{partsgroup}</td>|;
    map { print "$column_data{$_}\n" } @column_index;
    
    print "
        </tr>
";
  }

  $i = 1;
  if ($myconfig{acs} !~ /Goods \& Services--Goods \& Services/) {
    $button{'Goods & Services--Add Group'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Group').qq|"> |;
    $button{'Goods & Services--Add Group'}{order} = $i++;

    foreach $item (split /;/, $myconfig{acs}) {
      delete $button{$item};
    }
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

<input type=hidden name=type value=$form->{type}>

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


sub partsgroup_header {

  $form->{title} = $locale->text("$form->{title} Group");
  
# $locale->text('Edit Group')

  $form->{partsgroup} = $form->quote($form->{partsgroup});

  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=$form->{type}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th align=right>|.$locale->text('Group').qq|</th>

          <td><input name=partsgroup size=30 value="$form->{partsgroup}"></td>
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


sub partsgroup_footer {

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>
<br>
|;

  if ($myconfig{acs} !~ /Goods \& Services--Add Group/) {
    print qq|
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">
|;

    if ($form->{id} && $form->{orphaned}) {
      print qq|
<input type=submit class=submit name=action value="|.$locale->text('Delete').qq|">|;
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


sub pricegroup_report {

  map { $form->{$_} = $form->unescape($form->{$_}) } (pricegroup);
  PE->pricegroups(\%myconfig, \%$form);

  $href = "$form->{script}?action=pricegroup_report&direction=$form->{direction}&oldsort=$form->{oldsort}&type=$form->{type}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&status=$form->{status}";
  
  $form->sort_order();

  $callback = "$form->{script}?action=pricegroup_report&direction=$form->{direction}&oldsort=$form->{oldsort}&type=$form->{type}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&status=$form->{status}";
  
  if ($form->{status} eq 'all') {
    $option = $locale->text('All');
  }
  if ($form->{status} eq 'orphaned') {
    $option .= $locale->text('Orphaned');
  }
  if ($form->{pricegroup}) {
    $callback .= "&pricegroup=$form->{pricegroup}";
    $option .= "\n<br>".$locale->text('Pricegroup')." : $form->{pricegroup}";
  }
   

  @column_index = $form->sort_columns(qw(pricegroup));

  $column_header{pricegroup} = qq|<th><a class=listheading href=$href&sort=pricegroup width=90%>|.$locale->text('Pricegroup').qq|</th>|;

  $form->{title} = $locale->text('Pricegroups');

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

  # escape callback
  $form->{callback} = $callback;

  # escape callback for href
  $callback = $form->escape($callback);
  
  foreach $ref (@{ $form->{item_list} }) {
    
    $i++; $i %= 2;
    
    print qq|
        <tr valign=top class=listrow$i>
|;
    
    $column_data{pricegroup} = qq|<td><a href=$form->{script}?action=edit&type=$form->{type}&status=$form->{status}&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{pricegroup}</td>|;
    map { print "$column_data{$_}\n" } @column_index;
    
    print "
        </tr>
";
  }

  $i = 1;
  if ($myconfig{acs} !~ /Goods \& Services--Goods \& Services/) {
    $button{'Goods & Services--Add Pricegroup'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Pricegroup').qq|"> |;
    $button{'Goods & Services--Add Pricegroup'}{order} = $i++;

    foreach $item (split /;/, $myconfig{acs}) {
      delete $button{$item};
    }
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

<input type=hidden name=type value=$form->{type}>

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


sub pricegroup_header {

  $form->{title} = $locale->text("$form->{title} Pricegroup");
  
# $locale->text('Edit Pricegroup')

  $form->{pricegroup} = $form->quote($form->{pricegroup});

  
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=$form->{type}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th align=right>|.$locale->text('Pricegroup').qq|</th>

          <td><input name=pricegroup size=30 value="$form->{pricegroup}"></td>
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


sub pricegroup_footer {

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>
<br>
|;

  if ($myconfig{acs} !~ /Goods \& Services--Add Pricegroup/) {
    print qq|
<input type=submit class=submit name=action value="|.$locale->text('Save').qq|">
|;

    if ($form->{id} && $form->{orphaned}) {
      print qq|
<input type=submit class=submit name=action value="|.$locale->text('Delete').qq|">|;
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


sub translation {

  if ($form->{translation} eq 'description') {
    $form->{title} = $locale->text('Description Translations');
    $sort = qq|<input type=hidden name=sort value=partnumber>|;
    $form->{number} = "partnumber";
    $number = qq|
        <tr>
          <th align=right nowrap>|.$locale->text('Number').qq|</th>
          <td><input name=partnumber size=20></td>
        </tr>
|;
  }

  if ($form->{translation} eq 'partsgroup') {
    $form->{title} = $locale->text('Group Translations');
    $sort = qq|<input type=hidden name=sort value=partsgroup>|;
  }
  
  if ($form->{translation} eq 'project') {
    $form->{title} = $locale->text('Project Description Translations');
    $form->{number} = "projectnumber";
    $sort = qq|<input type=hidden name=sort value=projectnumber>|;
    $number = qq|
        <tr>
          <th align=right nowrap>|.$locale->text('Project Number').qq|</th>
          <td><input name=projectnumber size=20></td>
        </tr>
|;
  }


  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=translation value=$form->{translation}>
<input type=hidden name=title value="$form->{title}">
<input type=hidden name=number value=$form->{number}>

<table width="100%">
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
        $number
        <tr>
          <th align=right nowrap>|.$locale->text('Description').qq|</th>
          <td colspan=3><input name=description size=40></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr><td><hr size=3 noshade></td></tr>
</table>

<input type=hidden name=nextsub value=list_translations>
$sort

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


sub list_translations {

  $title = $form->escape($form->{title},1);
  
  $callback = "$form->{script}?action=list_translations&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&translation=$form->{translation}&number=$form->{number}&title=$title";

  if ($form->{"$form->{number}"}) {
    $callback .= qq|&$form->{number}=$form->{"$form->{number}"}|;
    $option .= $locale->text('Number').qq| : $form->{"$form->{number}"}<br>|;
  }
  if ($form->{description}) {
    $callback .= "&description=$form->{description}";
    $description = $form->{description};
    $description =~ s//<br>/g;
    $option .= $locale->text('Description').qq| : $form->{description}<br>|;
  }

  if ($form->{translation} eq 'partsgroup') {
    @column_index = qw(description language translation);
    $form->{sort} = "";
  } else {
    @column_index = $form->sort_columns("$form->{number}", "description", "language", "translation");
  }

  &{ "PE::$form->{translation}_translations" }("", \%myconfig, \%$form);

  $callback .= "&direction=$form->{direction}&oldsort=$form->{oldsort}";
  
  $href = $callback;
  
  $form->sort_order();
  
  $callback =~ s/(direction=).*\&{1}/$1$form->{direction}\&/;

  $column_header{"$form->{number}"} = qq|<th nowrap><a class=listheading href=$href&sort=$form->{number}>|.$locale->text('Number').qq|</a></th>|;
  $column_header{description} = qq|<th nowrap width=40%><a class=listheading href=$href&sort=description>|.$locale->text('Description').qq|</a></th>|;
  $column_header{language} = qq|<th nowrap class=listheading>|.$locale->text('Language').qq|</a></th>|;
  $column_header{translation} = qq|<th nowrap width=40% class=listheading>|.$locale->text('Translation').qq|</a></th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>

  <tr><td>$option</td></tr>

  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "\n$column_header{$_}" } @column_index;
  
  print qq|
        </tr>
  |;


  # add order to callback
  $form->{callback} = $callback .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($callback);

  if (@{ $form->{translations} }) {
    $sameitem = $form->{translations}->[0]->{$form->{sort}};
  }

  foreach $ref (@{ $form->{translations} }) {
  
    $ref->{description} =~ s//<br>/g;
    
    map { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" } @column_index;
    
    $column_data{description} = "<td><a href=$form->{script}?action=edit_translation&translation=$form->{translation}&number=$form->{number}&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{description}&nbsp;</a></td>";
    
    $i++; $i %= 2;
    print "<tr class=listrow$i>";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
    </tr>
|;

  }
  
  print qq|
      </table>
    </td>
  </tr>
  <tr><td><hr size=3 noshade></td></tr>
</table>

|;
 
  print qq|

<br>

<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>
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


sub edit_translation {

  &{ "PE::$form->{translation}_translations" }("", \%myconfig, \%$form);

  $form->error($locale->text('Languages not defined!')) unless $form->{all_language};

  $form->{selectlanguage} = qq|<option>\n|;
  map { $form->{selectlanguage} .= qq|<option value="$_->{code}">$_->{description}\n| } @{ $form->{all_language} };

  $form->{"$form->{number}"} = $form->{translations}->[0]->{"$form->{number}"};
  $form->{description} = $form->{translations}->[0]->{description};
  $form->{description} =~ s//<br>/g;

  shift @{ $form->{translations} };

  $i = 1;
  foreach $row (@{ $form->{translations} }) {
    $form->{"language_code_$i"} = $row->{code};
    $form->{"translation_$i"} = $row->{translation};
    $i++;
  }
  $form->{translation_rows} = $i - 1;
    
  $form->{title} = $locale->text('Edit Description Translations');
  
  &translation_header;
  &translation_footer;

}


sub translation_header {

  $form->{translation_rows}++;

  $form->{selectlanguage} = $form->unescape($form->{selectlanguage});
  for ($i = 1; $i <= $form->{translation_rows}; $i++) {
    $form->{"selectlanguage_$i"} = $form->{selectlanguage};
    if ($form->{"language_code_$i"}) {
      $form->{"selectlanguage_$i"} =~ s/(<option value="\Q$form->{"language_code_$i"}\E")/$1 selected/;
    }
  }
  
  $form->{selectlanguage} = $form->escape($form->{selectlanguage},1);

  $form->header;
 
  print qq|
<body>

<form method=post action=$form->{script}>

<input name=id type=hidden value=$form->{id}>
<input name=trans_id type=hidden value=$form->{trans_id}>

<input type=hidden name=selectlanguage value="$form->{selectlanguage}">
<input type=hidden name=translation_rows value=$form->{translation_rows}>

<input type=hidden name=number value=$form->{number}>
<input type=hidden name=$form->{number} value="|.$form->quote($form->{"$form->{number}"}).qq|">
<input type=hidden name=description value="|.$form->quote($form->{description}).qq|">

<input type=hidden name=translation value=$form->{translation}>
<input type=hidden name=title value="$form->{title}">

<table width="100%">
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table width=100%>
        <tr>
          <td align=left>$form->{"$form->{number}"}</th>
	  <td align=left>$form->{description}</th>
        </tr>
        <tr>
	<tr>
	  <th class=listheading>|.$locale->text('Language').qq|</th>
	  <th class=listheading>|.$locale->text('Translation').qq|</th>
	</tr>
|;

  for ($i = 1; $i <= $form->{translation_rows}; $i++) {
    
    if (($rows = $form->numtextrows($form->{"translation_$i"}, 40)) > 1) {
      $translation = qq|<textarea name="translation_$i" rows=$rows cols=40 wrap=soft>$form->{"translation_$i"}</textarea>|;
    } else {
      $translation = qq|<input name="translation_$i" size=40 value="$form->{"translation_$i"}">|;
    }
   
    print qq|
	<tr valign=top>
	  <td><select name="language_code_$i">$form->{"selectlanguage_$i"}</select></td>
	  <td>$translation</td>
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
|;

}


sub translation_footer {

  print qq|
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input type=hidden name=callback value="$form->{callback}">

<br>

<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Save').qq|">
|;

  if ($form->{trans_id}) {
    print qq|
<input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">
|;
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

  @flds = qw(language translation);
  $count = 0;
  @a = ();
  for $i (1 .. $form->{translation_rows}) {
    if ($form->{"language_code_$i"} ne "") {
      push @a, {};
      $j = $#a;

      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }
  $form->redo_rows(\@flds, \@a, $count, $form->{translation_rows});
  $form->{translation_rows} = $count;

  &translation_header;
  &translation_footer;

}

    
sub add_group { &add };
sub add_project { &add };
sub add_pricegroup { &add };

