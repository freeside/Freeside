#=====================================================================
# SQL-Ledger, Accounting
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
# Inventory Control module
#
#======================================================================


use SL::IC;

require "$form->{path}/io.pl";

1;
# end of main



sub add {

  %label = ( part	=> 'Part',
             service	=> 'Service',
	     assembly	=> 'Assembly',
	     labor	=> 'Labor/Overhead' );

# $locale->text('Add Part')
# $locale->text('Add Service')
# $locale->text('Add Assembly')
# $locale->text('Add Labor/Overhead')

  $label = "Add $label{$form->{item}}";
  $form->{title} = $locale->text($label);

  $form->{callback} = "$form->{script}?action=add&item=$form->{item}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}" unless $form->{callback};

  $form->{orphaned} = 1;

  if ($form->{previousform}) {
    $form->{callback} = "";
  }

  &link_part;
  &display_form;
  
}


sub search {

  $form->get_partsgroup(\%myconfig, { all => 0, searchitems => $form->{searchitems}});

  IC->get_warehouses(\%myconfig, \%$form) unless $form->{searchitems} =~ /(service|labor)/;

  if (@{ $form->{all_partsgroup} }) {
    $partsgroup = qq|<option>\n|;

    map { $partsgroup .= qq|<option value="$_->{partsgroup}--$_->{id}">$_->{partsgroup}\n| } @{ $form->{all_partsgroup} }; 

    $partsgroup = qq| 
        <th align=right nowrap>|.$locale->text('Group').qq|</th>
	<td><select name=partsgroup>$partsgroup</select></td>
|;
  }

  $l_listprice = qq|
                <td><input name=l_listprice class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('List Price').qq|</td>
|;
  $l_sellprice = qq|
		<td><input name=l_sellprice class=checkbox type=checkbox value=Y checked>&nbsp;|.$locale->text('Sell Price').qq|</td>
|;
  $l_lastcost = qq|
		<td><input name=l_lastcost class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Cost').qq|</td>
|;
  $l_linetotal = qq|
		<td><input name=l_linetotal class=checkbox type=checkbox value=Y checked>&nbsp;|.$locale->text('Line Total').qq|</td>
|;
  $l_curr = qq|
		<td><input name=l_curr class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Currency').qq|</td>
|;

  $accrual = qq|
		    <tr>
		      <td colspan=4><input name=method class=radio type=radio value=accrual checked>|.$locale->text('Accrual').qq|
		      &nbsp;<input name=method class=radio type=radio value=cash>|.$locale->text('Cash').qq|</td>
		    </tr>
|;

  $serialnumber = qq|
          <th align=right nowrap>|.$locale->text('Serial Number').qq|</th>
          <td><input name=serialnumber size=20></td>
|;

  $l_serialnumber = qq|
        <td><input name=l_serialnumber class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Serial Number').qq|</td>
|;


  if ($form->{searchitems} =~ /(part|assembly)/) {
    
    $onhand = qq|
            <input name=itemstatus class=radio type=radio value=onhand>&nbsp;|.$locale->text('On Hand').qq|
            <input name=itemstatus class=radio type=radio value=short>&nbsp;|.$locale->text('Short').qq|
|;

    $makemodel = qq|
        <tr>
          <th align=right nowrap>|.$locale->text('Make').qq|</th>
          <td><input name=make size=20></td>
          <th align=right nowrap>|.$locale->text('Model').qq|</th>
          <td><input name=model size=20></td>
        </tr>
|;

    $l_makemodel = qq|
        <td><input name=l_make class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Make').qq|</td>
        <td><input name=l_model class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Model').qq|</td>
|;

    $l_bin = qq|
		<td><input name=l_bin class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Bin').qq|</td>|;

    $l_rop = qq|
		<td><input name=l_rop class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('ROP').qq|</td>|;


    $l_weight = qq|
		<td><input name=l_weight class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Weight').qq|</td>|;


    if (@{ $form->{all_warehouses} }) {
      $selectwarehouse = "<option>\n";

      map { $selectwarehouse .= qq|<option value="$_->{description}--$_->{id}">$_->{description}\n| } (@{ $form->{all_warehouses} });
      
      $warehouse = qq|
          <th align=right nowrap>|.$locale->text('Warehouse').qq|</th>
          <td><select name=warehouse>$selectwarehouse</select></td>
|;

      $l_warehouse = qq|
        <td><input name=l_warehouse class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Warehouse').qq|</td>
|;


      $drawing = qq|
        <tr>
          <th align=right nowrap>|.$locale->text('Drawing').qq|</th>
          <td><input name=drawing size=20></td>
          <th align=right nowrap>|.$locale->text('Microfiche').qq|</th>
          <td><input name=microfiche size=20></td>
        </tr>
|;

      $l_drawing = qq|
	      <tr>
                <td><input name=l_image class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Image').qq|</td>
		<td><input name=l_drawing class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Drawing').qq|</td>
		<td><input name=l_microfiche class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Microfiche').qq|</td>
	      </tr>
|;

    }
  }

  if ($form->{searchitems} eq 'assembly') {
 
    $toplevel = qq|
        <tr>
	  <td></td>
          <td colspan=3>
	  <input name=null class=radio type=radio value=1 checked>&nbsp;|.$locale->text('Top Level').qq|
	  <input name=bom class=checkbox type=checkbox value=1>&nbsp;|.$locale->text('Individual Items').qq|
          </td>
        </tr>
|;
    
    $bought = qq|
	<tr>
	  <td></td>
	  <td colspan=3>
	    <table>
	      <tr>
	        <td>
		  <table>
		    <tr>
		      <td><input name=sold class=checkbox type=checkbox value=1></td>
		      <td nowrap>|.$locale->text('Sales Invoices').qq|</td>
		    </tr>
		    <tr>
		      <td colspan=2><hr size=1 noshade></td>
		    </tr>
		    <tr>
		      <td><input name=ordered class=checkbox type=checkbox value=1></td>
		      <td nowrap>|.$locale->text('Sales Orders').qq|</td>
		    </tr>
		    <tr>
		      <td colspan=4><hr size=1 noshade></td>
		    </tr>
		    <tr>
		      <td><input name=quoted class=checkbox type=checkbox value=1></td>
		      <td nowrap>|.$locale->text('Quotations').qq|</td>
		    </tr>
		  </table>
		</td>
		<td width=5%>&nbsp;</td>
		<td>
		  <table>
		    $accrual
		    <tr>
		      <th>|.$locale->text('From').qq|</th>
		      <td><input name=transdatefrom size=11 title="$myconfig{dateformat}"></td>
		      <th>|.$locale->text('To').qq|</th>
		      <td><input name=transdateto size=11 title="$myconfig{dateformat}"></td>
		    </tr>
		    <tr>
		      <td colspan=4><input name=open class=checkbox type=checkbox value=1 checked>&nbsp;|.$locale->text('Open').qq|
		      <input name=closed class=checkbox type=checkbox>&nbsp;|.$locale->text('Closed').qq|</td>
		    </tr>
		  </table>
		</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;

  } elsif ($form->{searchitems} eq 'component') {

    $warehouse = "";
    $serialnumber = "";
    $l_serialnumber = "";
    $l_warehouse = "";
  
  } elsif ($form->{searchitems} eq 'labor') {

    $warehouse = "";
    $serialnumber = "";
    $l_serialnumber = "";
    $l_sellprice = qq|
		<td><input name=l_sellprice class=checkbox type=checkbox value=Y checked>&nbsp;|.$locale->text('Amount').qq|</td>
|;
    $l_listprice = "";
    $l_lastcost = "";
    
  } else {
       
     $bought = qq|
        <tr>
          <td></td>
          <td colspan=3>
	    <table>
	      <tr>
	        <td>
		  <table>
		    <tr>
		      <td><input name=bought class=checkbox type=checkbox value=1></td>
		      <td nowrap>|.$locale->text('Vendor Invoices').qq|</td>
		      <td><input name=sold class=checkbox type=checkbox value=1></td>
		      <td nowrap>|.$locale->text('Sales Invoices').qq|</td>
		    </tr>
		    <tr>
		      <td colspan=4><hr size=1 noshade></td>
		    </tr>
		    <tr>
		      <td><input name=onorder class=checkbox type=checkbox value=1></td>
		      <td nowrap>|.$locale->text('Purchase Orders').qq|</td>
		      <td><input name=ordered class=checkbox type=checkbox value=1></td>
		      <td nowrap>|.$locale->text('Sales Orders').qq|</td>
		    </tr>
		    <tr>
		      <td colspan=4><hr size=1 noshade></td>
		    </tr>
		    <tr>
		      <td><input name=rfq class=checkbox type=checkbox value=1></td>
		      <td nowrap>|.$locale->text('RFQ').qq|</td>
		      <td><input name=quoted class=checkbox type=checkbox value=1></td>
		      <td nowrap>|.$locale->text('Quotations').qq|</td>
		    </tr>
		  </table>
		</td>
		<td width=5%>&nbsp;</td>
		<td>
		  <table>
		    $accrual
		    <tr>
		      <th>|.$locale->text('From').qq|</th>
		      <td><input name=transdatefrom size=11 title="$myconfig{dateformat}"></td>
		      <th>|.$locale->text('To').qq|</th>
		      <td><input name=transdateto size=11 title="$myconfig{dateformat}"></td>
		    </tr>
		    <tr>
		      <td colspan=4><input name=open class=checkbox type=checkbox value=1 checked>&nbsp;|.$locale->text('Open').qq|
		      <input name=closed class=checkbox type=checkbox>&nbsp;|.$locale->text('Closed').qq|</td>
		    </tr>
		  </table>
		</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;
  }

  %title = ( all	=> 'Items',
             part	=> 'Parts',
	     labor	=> 'Labor/Overhead',
	     service	=> 'Services',
	     assembly	=> 'Assemblies',
	     component	=> 'Components'
	   );

# $locale->text('Items')
# $locale->text('Parts')
# $locale->text('Labor/Overhead')
# $locale->text('Services')
# $locale->text('Assemblies')
# $locale->text('Components')
  
  $form->{title} = $locale->text($title{$form->{searchitems}});
   
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=searchitems value=$form->{searchitems}>
<input type=hidden name=title value="$form->{title}">

<table width="100%">
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
        <tr>
          <th align=right nowrap>|.$locale->text('Number').qq|</th>
          <td><input name=partnumber size=20></td>
        </tr>
        <tr>
          <th align=right nowrap>|.$locale->text('Description').qq|</th>
          <td colspan=3><input name=description size=40></td>
        </tr>
	<tr>
	  $warehouse
	</tr>
	<tr>
	  $partsgroup
	  $serialnumber
	</tr>
	$makemodel
	$drawing
	$toplevel
        <tr>
          <td></td>
          <td colspan=3>
            <input name=itemstatus class=radio type=radio value=active checked>&nbsp;|.$locale->text('Active').qq|
	    $onhand
            <input name=itemstatus class=radio type=radio value=obsolete>&nbsp;|.$locale->text('Obsolete').qq|
            <input name=itemstatus class=radio type=radio value=orphaned>&nbsp;|.$locale->text('Orphaned').qq|
	  </td>
	</tr>
	$bought
        <tr>
	  <td></td>
          <td colspan=3>
	    <hr size=1 noshade>
	  </td>
	</tr>
	<tr>
          <th align=right nowrap>|.$locale->text('Include in Report').qq|</th>
          <td colspan=3>
            <table>
              <tr>
                <td><input name=l_partnumber class=checkbox type=checkbox value=Y checked>&nbsp;|.$locale->text('Number').qq|</td>
		<td><input name=l_description class=checkbox type=checkbox value=Y checked>&nbsp;|.$locale->text('Description').qq|</td>
		$l_serialnumber
		<td><input name=l_unit class=checkbox type=checkbox value=Y checked>&nbsp;|.$locale->text('Unit of measure').qq|</td>
                <td><input name=l_priceupdate class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Updated').qq|</td>
		<td><input name=l_partsgroup class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Group').qq|</td>
	      </tr>
	      <tr>
	        $l_listprice
		$l_sellprice
		$l_lastcost
		$l_linetotal
		$l_curr
	      </tr>
	      <tr>
		$l_bin
		$l_rop
		$l_weight
              </tr>
	        $l_drawing
	      <tr>
		$l_makemodel
		$l_warehouse
              </tr>
	      <tr>
                <td><input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|.$locale->text('Subtotal').qq|</td>
	      </tr>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr><td colspan=4><hr size=3 noshade></td></tr>
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

  # setup $form->{sort}
  unless ($form->{sort}) {
    if ($form->{description} && !($form->{partnumber})) {
      $form->{sort} = "description";
    } else {
      $form->{sort} = "partnumber";
    }
  }

  $warehouse = $form->escape($form->{warehouse},1);
  $partsgroup = $form->escape($form->{partsgroup},1);
  $title = $form->escape($form->{title},1);
  
  $callback = "$form->{script}?action=generate_report&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&searchitems=$form->{searchitems}&itemstatus=$form->{itemstatus}&bom=$form->{bom}&l_linetotal=$form->{l_linetotal}&warehouse=$warehouse&partsgroup=$partsgroup&title=$title&method=$form->{method}";


  # if we have a serialnumber limit search
  if ($form->{serialnumber} || $form->{l_serialnumber}) {
    $form->{l_serialnumber} = "Y";
    unless ($form->{bought} || $form->{sold} || $form->{onorder} || $form->{ordered}) {
      if ($form->{searchitems} eq 'assembly') {
	$form->{sold} = $form->{ordered} = 1;
      } else {
	$form->{bought} = $form->{sold} = $form->{onorder} = $form->{ordered} = 1;
      }
    }
  }

 
  if ($form->{itemstatus} eq 'active') {
    $option .= $locale->text('Active')." : ";
  }
  if ($form->{itemstatus} eq 'obsolete') {
    $form->{onhand} = $form->{short} = 0;
    $form->{warehouse} = "";
    $form->{l_warehouse} = 0;

    $option .= $locale->text('Obsolete')." : ";
  }
  if ($form->{itemstatus} eq 'orphaned') {
    $form->{onhand} = $form->{short} = 0;
    $form->{bought} = $form->{sold} = 0;
    $form->{onorder} = $form->{ordered} = 0;
    $form->{rfq} = $form->{quoted} = 0;

    $form->{warehouse} = "";
    $form->{l_warehouse} = 0;

    $form->{transdatefrom} = $form->{transdateto} = "";
    
    $option .= $locale->text('Orphaned')." : ";
  }
  if ($form->{itemstatus} eq 'onhand') {
    $option .= $locale->text('On Hand')." : ";
    $form->{l_onhand} = "Y";
  }
  if ($form->{itemstatus} eq 'short') {
    $option .= $locale->text('Short')." : ";
    $form->{l_onhand} = "Y";
    $form->{l_rop} = "Y" unless $form->{searchitems} eq 'labor';
    
    $form->{warehouse} = "";
    $form->{l_warehouse} = 0;
  }
  if ($form->{onorder}) {
    $form->{l_ordnumber} = "Y";
    $callback .= "&onorder=$form->{onorder}";
    $option .= $locale->text('Purchase Order')." : ";
  }
  if ($form->{ordered}) {
    $form->{l_ordnumber} = "Y";
    $callback .= "&ordered=$form->{ordered}";
    $option .= $locale->text('Sales Order')." : ";
  }
  if ($form->{rfq}) {
    $form->{l_quonumber} = "Y";
    $callback .= "&rfq=$form->{rfq}";
    $option .= $locale->text('RFQ')." : ";
  }
  if ($form->{quoted}) {
    $form->{l_quonumber} = "Y";
    $callback .= "&quoted=$form->{quoted}";
    $option .= $locale->text('Quotation')." : ";
  }
  if ($form->{bought}) {
    $form->{l_invnumber} = "Y";
    $callback .= "&bought=$form->{bought}";
    $option .= $locale->text('Vendor Invoice')." : ";
  }
  if ($form->{sold}) {
    $form->{l_invnumber} = "Y";
    $callback .= "&sold=$form->{sold}";
    $option .= $locale->text('Sales Invoice')." : ";
  }
  if ($form->{sold} || $form->{bought}) {
    $label = ucfirst $form->{method};
    $option .= $locale->text($label) ." : ";
  }

  if ($form->{bought} || $form->{sold} || $form->{onorder} || $form->{ordered} || $form->{rfq} || $form->{quoted}) {
    
    # warehouse stuff is meaningless
    $form->{warehouse} = "";
    $form->{l_warehouse} = 0;
    
    $form->{l_lastcost} = "";
    $form->{l_name} = "Y";
    $form->{l_employee} = "Y";

     
    if ($form->{open}) {
      $callback .= "&open=$form->{open}";
      $option .= $locale->text('Open');
    }
    if ($form->{closed}) {
      $callback .= "&closed=$form->{closed}";
      if ($form->{open}) {
	$option .= " : ".$locale->text('Closed');
      } else {
	$option .= $locale->text('Closed');
      }
    }

    if ($form->{transdatefrom}) {
      $callback .= "&transdatefrom=$form->{transdatefrom}";
      $option .= "\n<br>".$locale->text('From')."&nbsp;".$locale->date(\%myconfig, $form->{transdatefrom}, 1);
    }
    if ($form->{transdateto}) {
      $callback .= "&transdateto=$form->{transdateto}";
      $option .= "\n<br>".$locale->text('To')."&nbsp;".$locale->date(\%myconfig, $form->{transdateto}, 1);
    }
  }
  
  if ($form->{warehouse}) {
    ($warehouse) = split /--/, $form->{warehouse};
    $option .= "<br>".$locale->text('Warehouse')." : $warehouse";
    $form->{l_warehouse} = 0;
  }
 
  $option .= "<br>";
  
  if ($form->{partnumber}) {
    $callback .= "&partnumber=".$form->escape($form->{partnumber},1);
    $option .= $locale->text('Number').qq| : $form->{partnumber}<br>|;
  }
  if ($form->{partsgroup}) {
    ($partsgroup) = split /--/, $form->{partsgroup};
    $option .= $locale->text('Group').qq| : $partsgroup<br>|;
  }
  if ($form->{serialnumber}) {
    $callback .= "&serialnumber=".$form->escape($form->{serialnumber},1);
    $option .= $locale->text('Serial Number').qq| : $form->{serialnumber}<br>|;
  }
  if ($form->{description}) {
    $callback .= "&description=".$form->escape($form->{description},1);
    $description = $form->{description};
    $description =~ s//<br>/g;
    $option .= $locale->text('Description').qq| : $form->{description}<br>|;
  }
  if ($form->{make}) {
    $callback .= "&make=".$form->escape($form->{make},1);
    $option .= $locale->text('Make').qq| : $form->{make}<br>|;
  }
  if ($form->{model}) {
    $callback .= "&model=".$form->escape($form->{model},1);
    $option .= $locale->text('Model').qq| : $form->{model}<br>|;
  }
  if ($form->{drawing}) {
    $callback .= "&drawing=".$form->escape($form->{drawing},1);
    $option .= $locale->text('Drawing').qq| : $form->{drawing}<br>|;
  }
  if ($form->{microfiche}) {
    $callback .= "&microfiche=".$form->escape($form->{microfiche},1);
    $option .= $locale->text('Microfiche').qq| : $form->{microfiche}<br>|;
  }

  
  @columns = $form->sort_columns(qw(partnumber description assemblypartnumber partsgroup make model bin onhand rop unit listprice linetotallistprice sellprice linetotalsellprice lastcost linetotallastcost curr priceupdate weight image drawing microfiche invnumber ordnumber quonumber name employee serialnumber warehouse));

  if ($form->{l_linetotal}) {
    $form->{l_onhand} = "Y";
    $form->{l_linetotalsellprice} = "Y" if $form->{l_sellprice};
    $form->{l_linetotallastcost} = "Y" if $form->{l_lastcost};
    $form->{l_linetotallistprice} = "Y" if $form->{l_listprice};
  }

  if ($form->{searchitems} eq 'service') {
    # remove bin, weight and rop from list
    map { $form->{"l_$_"} = "" } qw(bin weight rop);

    $form->{l_onhand} = "";
    # qty is irrelevant unless bought or sold
    if ($form->{bought} || $form->{sold} || $form->{onorder} ||
        $form->{ordered} || $form->{rfq} || $form->{quoted}) {
      $form->{l_onhand} = "Y";
    } else {
      $form->{l_linetotalsellprice} = "";
      $form->{l_linetotallastcost} = "";
    }
  }

  
  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to callback
      $callback .= "&l_$item=Y";
    }
  }

  if ($form->{l_subtotal} eq 'Y') {
    $callback .= "&l_subtotal=Y";
  }


  IC->all_parts(\%myconfig, \%$form);

  $callback .= "&direction=$form->{direction}&oldsort=$form->{oldsort}";
  
  $href = $callback;
  
  $form->sort_order();
  
  $callback =~ s/(direction=).*\&{1}/$1$form->{direction}\&/;


  if ($form->{searchitems} eq 'assembly' && $form->{l_partnumber}) {
    # replace partnumber with partnumber_
    $ndx = 0;
    foreach $item (@column_index) {
      $ndx++;
      last if $item eq 'partnumber';
    }

    splice @column_index, $ndx, 0, map { "partnumber_$_" } (1 .. $form->{pncol});
    $colspan = $form->{pncol} + 1;
  }

  if ($form->{searchitems} eq 'component') {
    if ($form->{l_partnumber}) {
      # splice it in after the partnumber
      $ndx = 0;
      foreach $item (@column_index) {
	$ndx++;
	last if $item eq 'partnumber';
      }
      
      @a = splice @column_index, 0, $ndx;
      unshift @column_index, "assemblypartnumber";
      unshift @column_index, @a;
    }
  }
  
  $column_header{partnumber} = qq|<th nowrap colspan=$colspan><a class=listheading href=$href&sort=partnumber>|.$locale->text('Number').qq|</a></th>|;
  $column_header{description} = qq|<th nowrap><a class=listheading href=$href&sort=description>|.$locale->text('Description').qq|</a></th>|;
  $column_header{partsgroup} = qq|<th nowrap><a class=listheading href=$href&sort=partsgroup>|.$locale->text('Group').qq|</a></th>|;
  $column_header{bin} = qq|<th><a class=listheading href=$href&sort=bin>|.$locale->text('Bin').qq|</a></th>|;
  $column_header{priceupdate} = qq|<th nowrap><a class=listheading href=$href&sort=priceupdate>|.$locale->text('Updated').qq|</a></th>|;
  $column_header{onhand} = qq|<th class=listheading nowrap>|.$locale->text('Qty').qq|</th>|;
  $column_header{unit} = qq|<th class=listheading nowrap>|.$locale->text('Unit').qq|</th>|;
  $column_header{listprice} = qq|<th class=listheading nowrap>|.$locale->text('List Price').qq|</th>|;
  $column_header{lastcost} = qq|<th class=listheading nowrap>|.$locale->text('Cost').qq|</th>|;
  $column_header{rop} = qq|<th class=listheading nowrap>|.$locale->text('ROP').qq|</th>|;
  $column_header{weight} = qq|<th class=listheading nowrap>|.$locale->text('Weight').qq|</th>|;

  $column_header{make} = qq|<th nowrap><a class=listheading href=$href&sort=make>|.$locale->text('Make').qq|</a></th>|;
  $column_header{model} = qq|<th nowrap><a class=listheading href=$href&sort=model>|.$locale->text('Model').qq|</a></th>|;
  
  $column_header{invnumber} = qq|<th nowrap><a class=listheading href=$href&sort=invnumber>|.$locale->text('Invoice Number').qq|</a></th>|;
  $column_header{ordnumber} = qq|<th nowrap><a class=listheading href=$href&sort=ordnumber>|.$locale->text('Order Number').qq|</a></th>|;
  $column_header{quonumber} = qq|<th nowrap><a class=listheading href=$href&sort=quonumber>|.$locale->text('Quotation').qq|</a></th>|;
  
  $column_header{name} = qq|<th nowrap><a class=listheading href=$href&sort=name>|.$locale->text('Name').qq|</a></th>|;
  
  $column_header{employee} = qq|<th nowrap><a class=listheading href=$href&sort=employee>|.$locale->text('Employee').qq|</a></th>|;
  
  $column_header{sellprice} = qq|<th class=listheading nowrap>|;
  $column_header{sellprice} .= ($form->{searchitems} ne 'labor') ? $locale->text('Sell Price') : $locale->text('Amount');
  $column_header{sellprice} .= qq|</th>|;
  
  $column_header{linetotalsellprice} = qq|<th class=listheading nowrap>|.$locale->text('Extended').qq|</th>|;
  $column_header{linetotallastcost} = qq|<th class=listheading nowrap>|.$locale->text('Extended').qq|</th>|;
  $column_header{linetotallistprice} = qq|<th class=listheading nowrap>|.$locale->text('Extended').qq|</th>|;
  
  $column_header{curr} = qq|<th class=listheading nowrap>|.$locale->text('Curr').qq|</th>|;
  
  $column_header{image} = qq|<th class=listheading nowrap>|.$locale->text('Image').qq|</a></th>|;
  $column_header{drawing} = qq|<th nowrap><a class=listheading href=$href&sort=drawing>|.$locale->text('Drawing').qq|</a></th>|;
  $column_header{microfiche} = qq|<th nowrap><a class=listheading href=$href&sort=microfiche>|.$locale->text('Microfiche').qq|</a></th>|;
  
  $column_header{serialnumber} = qq|<th nowrap><a class=listheading href=$href&sort=serialnumber>|.$locale->text('Serial Number').qq|</a></th>|;
  
  $column_header{assemblypartnumber} = qq|<th nowrap><a class=listheading href=$href&sort=assemblypartnumber>|.$locale->text('Assembly').qq|</a></th>|;
  
  $column_header{warehouse} = qq|<th nowrap class=listheading>|.$locale->text('Warehouse').qq|</th>|;

  
  $form->header;

  $i = 1;
  if ($form->{searchitems} eq 'part') {
    $button{'Goods & Services--Add Part'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Part').qq|"> |;
    $button{'Goods & Services--Add Part'}{order} = $i++;
  }
  if ($form->{searchitems} eq 'service') {
    $button{'Goods & Services--Add Service'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Service').qq|"> |;
    $button{'Goods & Services--Add Service'}{order} = $i++;
  }
  if ($form->{searchitems} eq 'assembly') {  
    $button{'Goods & Services--Add Assembly'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Assembly').qq|"> |;
    $button{'Goods & Services--Add Assembly'}{order} = $i++;
  }
  if ($form->{searchitems} eq 'labor') {  
    $button{'Goods & Services--Add Labor/Overhead'}{code} = qq|<input class=submit type=submit name=action value="|.$locale->text('Add Labor/Overhead').qq|"> |;
    $button{'Goods & Services--Add Labor/Overhead'}{order} = $i++;
  }

  foreach $item (split /;/, $myconfig{acs}) {
    delete $button{$item};
  }

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

  if (@{ $form->{parts} }) {
    $sameitem = $form->{parts}->[0]->{$form->{sort}};
  }


  foreach $ref (@{ $form->{parts} }) {
  
    if ($form->{l_subtotal} eq 'Y' && !$ref->{assemblyitem}) {
      if ($sameitem ne $ref->{$form->{sort}}) {
	&parts_subtotal;
	$sameitem = $ref->{$form->{sort}};
      }
    }

    $ref->{exchangerate} = 1 unless $ref->{exchangerate};
    $ref->{discount} *= 1;
    $ref->{sellprice} = $ref->{sellprice} * (1 - $ref->{discount});
    if ($form->{l_curr}) {
      if ($ref->{module} ne 'oe') {
	map { $ref->{$_} = $form->round_amount($ref->{$_} / $ref->{exchangerate}, 2) } qw(sellprice listprice lastcost);
      }
    } else {
      if ($ref->{module} eq 'oe') {
	map { $ref->{$_} = $form->round_amount($ref->{$_} * $ref->{exchangerate}, 2) } qw(sellprice listprice lastcost);
      }
    }
    
    # use this for assemblies
    $onhand = $ref->{onhand};
    
    $ref->{description} =~ s//<br>/g;
    
    map { $column_data{"partnumber_$_"} = "<td>&nbsp;</td>" } (1 .. $form->{pncol});

    $column_data{partnumber} = "<td><a href=$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{partnumber}&nbsp;</a></td>";
    
    $column_data{assemblypartnumber} = "<td><a href=$form->{script}?action=edit&id=$ref->{assembly_id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{assemblypartnumber}&nbsp;</a></td>";
    
    if ($ref->{assemblyitem}) {
      $onhand = 0 if ($form->{sold});
      
      $column_data{partnumber} = "<td>&nbsp;</td>";
      
      $column_data{"partnumber_$ref->{stagger}"} = "<td><a href=$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{partnumber}&nbsp;</a></td>";

    }
    
    map { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" } qw(description partsgroup employee curr);

    $column_data{onhand} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{onhand}, '', "&nbsp;")."</td>";

    map { $column_data{$_} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{$_}, 2, "&nbsp;") . "</td>" } qw(sellprice listprice lastcost);
    
    $column_data{linetotalsellprice} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{onhand} * $ref->{sellprice}, 2, "&nbsp;")."</td>";
    $column_data{linetotallastcost} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{onhand} * $ref->{lastcost}, 2, "&nbsp;")."</td>";
    $column_data{linetotallistprice} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{onhand} * $ref->{listprice}, 2, "&nbsp;")."</td>";

    if ($ref->{assemblyitem} && $ref->{stagger} > 1) {
      map { $column_data{$_} = "<td>&nbsp;</td>" } qw(linetotalsellprice linetotallastcost linetotallistprice);
    }
    
    if (!$ref->{assemblyitem}) {
      $totalsellprice += $onhand * $ref->{sellprice};
      $totallastcost += $onhand * $ref->{lastcost};
      $totallistprice += $onhand * $ref->{listprice};

      $subtotalonhand += $onhand;
      $subtotalsellprice += $onhand * $ref->{sellprice};
      $subtotallastcost += $onhand * $ref->{lastcost};
      $subtotallistprice += $onhand * $ref->{listprice};
    }

    $column_data{rop} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{rop}, '', "&nbsp;")."</td>";
    $column_data{weight} = "<td align=right>".$form->format_amount(\%myconfig, $ref->{weight}, '', "&nbsp;")."</td>";
    $column_data{unit} = "<td>$ref->{unit}&nbsp;</td>";
    $column_data{bin} = "<td>$ref->{bin}&nbsp;</td>";
    $column_data{priceupdate} = "<td>$ref->{priceupdate}&nbsp;</td>";
    
    $ref->{module} = 'ps' if $ref->{till};
    $column_data{invnumber} = ($ref->{module} ne 'oe') ? "<td><a href=$ref->{module}.pl?action=edit&type=invoice&id=$ref->{trans_id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{invnumber}&nbsp;</a></td>" : "<td>$ref->{invnumber}&nbsp;</td>";
    $column_data{ordnumber} = ($ref->{module} eq 'oe') ? "<td><a href=$ref->{module}.pl?action=edit&type=$ref->{type}&id=$ref->{trans_id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{ordnumber}&nbsp;</a></td>" : "<td>$ref->{ordnumber}&nbsp;</td>";
    $column_data{quonumber} = ($ref->{module} eq 'oe' && !$ref->{ordnumber}) ? "<td><a href=$ref->{module}.pl?action=edit&type=$ref->{type}&id=$ref->{trans_id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{quonumber}&nbsp;</a></td>" : "<td>$ref->{quonumber}&nbsp;</td>";

    $column_data{name} = "<td>$ref->{name}&nbsp;</td>";
   
    $column_data{image} = ($ref->{image}) ? "<td><a href=$ref->{image}><img src=$ref->{image} height=32 border=0></a></td>" : "<td>&nbsp;</td>";
    $column_data{drawing} = ($ref->{drawing}) ? "<td><a href=$ref->{drawing}>$ref->{drawing}</a></td>" : "<td>&nbsp;</td>";
    $column_data{microfiche} = ($ref->{microfiche}) ? "<td><a href=$ref->{microfiche}>$ref->{microfiche}</a></td>" : "<td>&nbsp;</td>";
    
    $column_data{make} = "<td>$ref->{make}&nbsp;</td>";
    $column_data{model} = "<td>$ref->{model}&nbsp;</td>";
    
    $column_data{serialnumber} = "<td>$ref->{serialnumber}&nbsp;</td>";
    $column_data{warehouse} = "<td>$ref->{warehouse}&nbsp;</td>";
    
    $i++; $i %= 2;
    print "<tr class=listrow$i>";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
    </tr>
|;

  }
  
  
  if ($form->{l_subtotal} eq 'Y') {
    &parts_subtotal;
  }

  if ($form->{"l_linetotal"}) {
    map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
    $column_data{linetotalsellprice} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totalsellprice, 2, "&nbsp;")."</th>";
    $column_data{linetotallastcost} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totallastcost, 2, "&nbsp;")."</th>";
    $column_data{linetotallistprice} = "<th class=listtotal align=right>".$form->format_amount(\%myconfig, $totallistprice, 2, "&nbsp;")."</th>";

    print "<tr class=listtotal>";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|</tr>
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

<input type=hidden name=item value=$form->{searchitems}>

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



sub parts_subtotal {

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
  $subtotalonhand = 0 if ($form->{searchitems} eq 'assembly' && $form->{bom});

  $column_data{onhand} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalonhand, '', "&nbsp;")."</th>";

  $column_data{linetotalsellprice} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotalsellprice, 2, "&nbsp;")."</th>";
  $column_data{linetotallistprice} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotallistprice, 2, "&nbsp;")."</th>";
  $column_data{linetotallastcost} = "<th class=listsubtotal align=right>".$form->format_amount(\%myconfig, $subtotallastcost, 2, "&nbsp;")."</th>";
  
  $subtotalonhand = 0;
  $subtotalsellprice = 0;
  $subtotallistprice = 0;
  $subtotallastcost = 0;

  print "<tr class=listsubtotal>";

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
  </tr>
|;

}



sub edit {
  
 %label = ( part	=> 'Part',
            service	=> 'Service',
            assembly	=> 'Assembly',
	    labor	=> 'Labor/Overhead' );

# $locale->text('Edit Part')
# $locale->text('Edit Service')
# $locale->text('Edit Assembly')
# $locale->text('Edit Labor/Overhead')

  IC->get_part(\%myconfig, \%$form);

  $label = "Edit $label{$form->{item}}";
  $form->{title} = $locale->text($label);

  &link_part;

  $form->{previousform} = $form->escape($form->{previousform}, 1) if $form->{previousform};
  
  &display_form;

}



sub link_part {

  IC->create_links("IC", \%myconfig, \%$form);
  
  # currencies 
  map { $form->{selectcurrency} .= "<option>$_\n" } split /:/, $form->{currencies};
  
  # parts and assemblies have the same links
  $item = $form->{item};
  
  # readonly
  if ($form->{item} eq 'part') {
    $form->{readonly} = 1 if $myconfig{acs} =~ /Goods \& Services--Add Part/;
  }
  if ($form->{item} eq 'service') {
    $form->{readonly} = 1 if $myconfig{acs} =~ /Goods \& Services--Add Service/;
  }
  if ($form->{item} eq 'assembly') {
    $item = 'part';
    $form->{readonly} = 1 if $myconfig{acs} =~ /Goods \& Services--Add Assembly/;
  }
  if ($form->{item} eq 'labor') {
    $item = 'labor';
    $form->{readonly} = 1 if $myconfig{acs} =~ /Goods \& Services--Add Labor\/Overhead/;
  }

  # build the popup menus
  $form->{taxaccounts} = "";
  foreach $key (keys %{ $form->{IC_links} }) {
    foreach $ref (@{ $form->{IC_links}{$key} }) {
      # if this is a tax field
      if ($key =~ /IC_tax/) {
	if ($key =~ /$item/) {
	  $form->{taxaccounts} .= "$ref->{accno} ";
	  $form->{"IC_tax_$ref->{accno}_description"} = "$ref->{accno}--$ref->{description}";
	  
	  if ($form->{id}) {
	    if ($form->{amount}{$ref->{accno}}) {
	      $form->{"IC_tax_$ref->{accno}"} = "checked";
	    }
	  } else {
	    $form->{"IC_tax_$ref->{accno}"} = "checked";
	  }
	}
      } else {

	$form->{"select$key"} .= "<option>$ref->{accno}--$ref->{description}\n";
	if ($form->{amount}{$key} eq $ref->{accno}) {
	  $form->{$key} = "$ref->{accno}--$ref->{description}";
	}
	
      }
    }
  }
  chop $form->{taxaccounts};

  if ($form->{item} !~ /service/) {
    $form->{selectIC_income} = $form->{selectIC_sale};
    $form->{selectIC_expense} = $form->{selectIC_cogs};
    $form->{IC_income} = $form->{IC_sale};
    $form->{IC_expense} = $form->{IC_cogs};
  }
  
  delete $form->{IC_links};
  delete $form->{amount};

  $form->get_partsgroup(\%myconfig, {all => 1});
  $form->{partsgroup} = "$form->{partsgroup}--$form->{partsgroup_id}";
  
  if (@{ $form->{all_partsgroup} }) {
    $form->{selectpartsgroup} = qq|<option>\n|;

    map { $form->{selectpartsgroup} .= qq|<option value="$_->{partsgroup}--$_->{id}">$_->{partsgroup}\n| } @{ $form->{all_partsgroup} };
  }

  if ($form->{item} eq 'assembly') {

    foreach $i (1 .. $form->{assembly_rows}) {
      if ($form->{"partsgroup_id_$i"}) {
	$form->{"partsgroup_$i"} = qq|$form->{"partsgroup_$i"}--$form->{"partsgroup_id_$i"}|;
      }
    }
    
    $form->get_partsgroup(\%myconfig);

    if (@{ $form->{all_partsgroup} }) {
      $form->{selectassemblypartsgroup} = qq|<option>\n|;

      map { $form->{selectassemblypartsgroup} .= qq|<option value="$_->{partsgroup}--$_->{id}">$_->{partsgroup}\n| } @{ $form->{all_partsgroup} };
    }
  }
  
  # setup make and models
  $i = 1;
  foreach $ref (@{ $form->{makemodels} }) {
    map { $form->{"${_}_$i"} = $ref->{$_} } qw(make model);
    $i++;
  }
  $form->{makemodel_rows} = $i - 1;

  
  # setup vendors
  if (@{ $form->{all_vendor} }) {
    $form->{selectvendor} = "<option>\n";
    map { $form->{selectvendor} .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } @{ $form->{all_vendor} };
  }

  # vendor matrix
  $i = 1;
  foreach $ref (@{ $form->{vendormatrix} }) {
    $form->{"vendor_$i"} = qq|$ref->{name}--$ref->{id}|;

    map { $form->{"${_}_$i"} = $ref->{$_} } qw(partnumber lastcost leadtime vendorcurr);
    $i++;
  }
  $form->{vendor_rows} = $i - 1;
  
  # setup customers and groups
  if (@{ $form->{all_customer} }) {
    $form->{selectcustomer} = "<option>\n";
    map { $form->{selectcustomer} .= qq|<option value="$_->{name}--$_->{id}">$_->{name}\n| } @{ $form->{all_customer} };
  }

  if (@{ $form->{all_pricegroup} }) {
    $form->{selectpricegroup} = "<option>\n";
    map { $form->{selectpricegroup} .= qq|<option value="$_->{pricegroup}--$_->{id}">$_->{pricegroup}\n| } @{ $form->{all_pricegroup} };
  }

  $i = 1;
  # customer matrix
  foreach $ref (@{ $form->{customermatrix} }) {

    $form->{"customer_$i"} = "$ref->{name}--$ref->{cid}" if $ref->{cid};
    $form->{"pricegroup_$i"} = "$ref->{pricegroup}--$ref->{gid}" if $ref->{gid};

    map { $form->{"${_}_$i"} = $ref->{$_} } qw(validfrom validto pricebreak customerprice customercurr);

    $i++;
    
  }
  $form->{customer_rows} = $i - 1;

}



sub form_header {

  ($dec) = ($form->{sellprice} =~ /\.(\d+)/);
  $dec = length $dec;
  my $decimalplaces = ($dec > 2) ? $dec : 2;

  if ($form->{lastcost} > 0) {
    $markup = $form->round_amount((($form->{sellprice}/$form->{lastcost} - 1) * 100), 1);
    $form->{markup} = $form->format_amount(\%myconfig, $markup, 1);
  }
  
  map { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, $decimalplaces)} qw(listprice sellprice);
  
  ($dec) = ($form->{lastcost} =~ /\.(\d+)/);
  $dec = length $dec;
  my $decimalplaces = ($dec > 2) ? $dec : 2;

  $form->{lastcost} = $form->format_amount(\%myconfig, $form->{lastcost}, $decimalplaces);

  map { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}) } qw(weight rop stock);
  
  map { $form->{$_} = $form->quote($form->{$_}) } qw(partnumber description unit notes);

  if (($rows = $form->numtextrows($form->{notes}, 40)) < 2) {
    $rows = 2;
  }
  
  $notes = qq|<textarea name=notes rows=$rows cols=40 wrap=soft>$form->{notes}</textarea>|;

  if (($rows = $form->numtextrows($form->{description}, 40)) > 1) {
    $description = qq|<textarea name="description" rows=$rows cols=40 wrap=soft>$form->{description}</textarea>|;
  } else {
    $description = qq|<input name=description size=40 value="$form->{description}">|;
  }
  
  foreach $item (split / /, $form->{taxaccounts}) {
    $form->{"IC_tax_$item"} = ($form->{"IC_tax_$item"}) ? "checked" : "";
  }


  # set option
  foreach $item (qw(IC IC_income IC_expense)) {
    if ($form->{$item}) {
      if ($form->{orphaned}) {
	$form->{"select$item"} =~ s/ selected//;
	$form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
      } else {
	$form->{"select$item"} = qq|<option selected>$form->{$item}|;
      }
    }
  }

  if ($form->{selectpartsgroup}) {
    $form->{selectpartsgroup} = $form->unescape($form->{selectpartsgroup});

    $partsgroup = qq|<input type=hidden name=selectpartsgroup value="|.$form->escape($form->{selectpartsgroup},1).qq|">|;
    
    $form->{selectpartsgroup} =~ s/(<option value="\Q$form->{partsgroup}\E")/$1 selected/;

    $partsgroup .= qq|<select name=partsgroup>$form->{selectpartsgroup}</select>|;
    $group = $locale->text('Group');
  }

  # tax fields
  foreach $item (split / /, $form->{taxaccounts}) {
    $tax .= qq|
      <input class=checkbox type=checkbox name="IC_tax_$item" value=1 $form->{"IC_tax_$item"}>&nbsp;<b>$form->{"IC_tax_${item}_description"}</b>
      <br><input type=hidden name=IC_tax_${item}_description value="$form->{"IC_tax_${item}_description"}">
|;
  }

  $form->{obsolete} = "checked" if $form->{obsolete};
  
  $sellprice = qq|
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('List Price').qq|</th>
		<td><input name=listprice size=11 value=$form->{listprice}></td>
	      </tr>
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('Sell Price').qq|</th>
		<td><input name=sellprice size=11 value=$form->{sellprice}></td>
	      </tr>
|;

  $lastcost = qq|
 	      <tr>
                <th align="right" nowrap="true">|.$locale->text('Cost').qq|</th>
                <td><input name=lastcost size=11 value=$form->{lastcost}></td>
              </tr>
	      <tr>
	        <th align="right" nowrap="true">|.$locale->text('Markup').qq| %</th>
		<td><input name=markup size=5 value=$form->{markup}></td>
		<input type=hidden name=oldmarkup value=$markup>
	      </tr>
|;
 
  if ($form->{item} eq "part") {

    $linkaccounts = qq|
	      <tr>
		<th align=right>|.$locale->text('Inventory').qq|</th>
		<td><select name=IC>$form->{selectIC}</select></td>
		<input name=selectIC type=hidden value="$form->{selectIC}">
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Income').qq|</th>
		<td><select name=IC_income>$form->{selectIC_income}</select></td>
		<input name=selectIC_income type=hidden value="$form->{selectIC_income}">
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('COGS').qq|</th>
		<td><select name=IC_expense>$form->{selectIC_expense}</select></td>
		<input name=selectIC_expense type=hidden value="$form->{selectIC_expense}">
	      </tr>
|;
  
    if ($tax) {
      $linkaccounts .= qq|
	      <tr>
		<th align=right>|.$locale->text('Tax').qq|</th>
		<td>$tax</td>
	      </tr>
|;
    }
  
    $weight = qq|
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('Weight').qq|</th>
		<td>
		  <table>
		    <tr>
		      <td>
			<input name=weight size=10 value=$form->{weight}>
		      </td>
		      <th>
			&nbsp;
			$form->{weightunit}
			<input type=hidden name=weightunit value=$form->{weightunit}>
		      </th>
		    </tr>
		  </table>
		</td>
	      </tr>
|;
    
  }


  if ($form->{item} eq "assembly") {
    
    $lastcost = qq|
              <tr>
	        <th align="right" nowrap="true">|.$locale->text('Cost').qq|</th> 
		<td><input type=hidden name=lastcost value=$form->{lastcost}>$form->{lastcost}</td>
	      </tr>
	      <tr>
	        <th align="right" nowrap="true">|.$locale->text('Markup').qq| %</th>
		<td><input name=markup size=5 value=$form->{markup}></td>
		<input type=hidden name=oldmarkup value=$markup>
	      </tr>
|;

    $linkaccounts = qq|
<!--
	      <tr>
		<th align=right>|.$locale->text('Inventory').qq|</th>
		<td><select name=IC>$form->{selectIC}</select></td>
		<input name=selectIC type=hidden value="$form->{selectIC}">
	      </tr>
-->
	      <tr>
		<th align=right>|.$locale->text('Income').qq|</th>
		<td><select name=IC_income>$form->{selectIC_income}</select></td>
		<input name=selectIC_income type=hidden value="$form->{selectIC_income}">
	      </tr>
|;
  
    if ($tax) {
      $linkaccounts .= qq|
	      <tr>
		<th align=right>|.$locale->text('Tax').qq|</th>
		<td>$tax</td>
	      </tr>
|;
    }
  
    $weight = qq|
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('Weight').qq|</th>
		<td>
		  <table>
		    <tr>
		      <td>
			&nbsp;$form->{weight}
			<input type=hidden name=weight value=$form->{weight}>
		      </td>
		      <th>
			&nbsp;
			$form->{weightunit}
			<input type=hidden name=weightunit value=$form->{weightunit}>
		      </th>
		    </tr>
		  </table>
		</td>
	      </tr>
|;
    
  }

 
  if ($form->{item} eq "service") {
    
    $linkaccounts = qq|
	      <tr>
		<th align=right>|.$locale->text('Income').qq|</th>
		<td><select name=IC_income>$form->{selectIC_income}</select></td>
		<input name=selectIC_income type=hidden value="$form->{selectIC_income}">
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Expense').qq|</th>
		<td><select name=IC_expense>$form->{selectIC_expense}</select></td>
		<input name=selectIC_expense type=hidden value="$form->{selectIC_expense}">
	      </tr>
|;
  
    if ($tax) {
      $linkaccounts .= qq|
	      <tr>
		<th align=right>|.$locale->text('Tax').qq|</th>
		<td>$tax</td>
	      </tr>
|;
    }

  }

  if ($form->{item} eq "labor") {
    $lastcost = "";
    $sellprice = qq|
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('Amount').qq|</th>
		<td><input name=sellprice size=11 value=$form->{sellprice}></td>
	      </tr>
|;

    $linkaccounts = qq|
	      <tr>
		<th align=right>|.$locale->text('Labor/Overhead').qq|</th>
		<td><select name=IC>$form->{selectIC}</select></td>
		<input name=selectIC type=hidden value="$form->{selectIC}">
	      </tr>
	      <tr>
		<th align=right>|.$locale->text('Expense').qq|</th>
		<td><select name=IC_expense>$form->{selectIC_expense}</select></td>
		<input name=selectIC_expense type=hidden value="$form->{selectIC_expense}">
	      </tr>
|;
  
  }


  if ($form->{item} =~ /(part|assembly)/) {
    $n = ($form->{onhand} > 0) ? "1" : "0";
    $rop = qq|
	      <tr>
		<th align="right" nowrap>|.$locale->text('On Hand').qq|</th>
		<th align=left nowrap class="plus$n">&nbsp;|.$form->format_amount(\%myconfig, $form->{onhand}).qq|</th>
	      </tr>
|;

    if ($form->{item} eq 'assembly') {
      $rop .= qq|
              <tr>
	        <th align="right" nowrap>|.$locale->text('Stock').qq|</th>
		<td><input name=stock size=10 value=$form->{stock}></td>
	      </tr>
|;
    }

    $rop .= qq|
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('ROP').qq|</th>
		<td><input name=rop size=10 value=$form->{rop}></td>
	      </tr>
|;
    
    $bin = qq|
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('Bin').qq|</th>
		<td><input name=bin size=10 value=$form->{bin}></td>
	      </tr>
|;
    
    $imagelinks = qq|
  <tr>
    <td>
      <table width=100%>
        <tr>
	  <th align=right nowrap>|.$locale->text('Image').qq|</th>
	  <td><input name=image size=40 value="$form->{image}"></td>
	  <th align=right nowrap>|.$locale->text('Microfiche').qq|</th>
	  <td><input name=microfiche size=20 value="$form->{microfiche}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|.$locale->text('Drawing').qq|</th>
	  <td><input name=drawing size=40 value="$form->{drawing}"></td>
	</tr>
      </table>
    </td>
  </tr>
|;

  }

  if ($form->{id}) {
    $obsolete = qq|
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('Obsolete').qq|</th>
		<td><input name=obsolete type=checkbox class=checkbox value=1 $form->{obsolete}></td>
	      </tr>
|;
  }


# type=submit $locale->text('Edit Part')
# type=submit $locale->text('Edit Service')
# type=submit $locale->text('Edit Assembly')


  $form->header;

  print qq|
<body>

<form method=post action="$form->{script}#end">

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=item value=$form->{item}>
<input type=hidden name=title value="$form->{title}">
<input type=hidden name=makemodel value="$form->{makemodel}">
<input type=hidden name=alternate value="$form->{alternate}">
<input type=hidden name=onhand value=$form->{onhand}>
<input type=hidden name=orphaned value=$form->{orphaned}>
<input type=hidden name=taxaccounts value="$form->{taxaccounts}">
<input type=hidden name=rowcount value=$form->{rowcount}>
<input type=hidden name=baseassembly value=$form->{baseassembly}>

<table width="100%">
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width="100%">
        <tr valign=top>
          <th align=left>|.$locale->text('Number').qq|</th>
          <th align=left>|.$locale->text('Description').qq|</th>
	  <th align=left>$group</th>
	</tr>
	<tr valign=top>
          <td><input name=partnumber value="$form->{partnumber}" size=20></td>
          <td>$description</td>
	  <td>$partsgroup</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width="100%" height="100%">
        <tr valign=top>
          <td width=70%>
            <table width="100%" height="100%">
              <tr class="listheading">
                <th class="listheading" align="center" colspan=2>|.$locale->text('Link Accounts').qq|</th>
              </tr>
              $linkaccounts
              <tr>
                <th align="left">|.$locale->text('Notes').qq|</th>
              </tr>
              <tr>
                <td colspan=2>
                  $notes
                </td>
              </tr>
            </table>
          </td>
	  <td width="30%">
	    <table width="100%">
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('Updated').qq|</th>
		<td><input name=priceupdate size=11 title="$myconfig{dateformat}" value=$form->{priceupdate}></td>    
	      </tr>
	      $sellprice
	      $lastcost
	      <tr>
		<th align="right" nowrap="true">|.$locale->text('Unit').qq|</th>
		<td><input name=unit size=5 value="$form->{unit}"></td>
	      </tr>
	      $weight
	      $rop
	      $bin
	      $obsolete
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  $imagelinks
|;
}


sub form_footer {

  print qq|
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=customer_rows value=$form->{customer_rows}>
|;


  if ($form->{item} =~ /(part|assembly)/) {
    print qq|
      <input type=hidden name=makemodel_rows value=$form->{makemodel_rows}>
|;
  }
  
  if ($form->{item} =~ /(part|service)/) {
    print qq|
      <input type=hidden name=vendor_rows value=$form->{vendor_rows}>
|;
  }


  if (! $form->{readonly}) {
    print qq|
      <input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
      <input class=submit type=submit name=action value="|.$locale->text('Save').qq|">|;

    if ($form->{id}) {

      if (!$form->{isassemblyitem}) {
	print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Save as new').qq|">|;
      }

      if ($form->{orphaned}) {
	print qq|
	<input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">|;
      }
    }
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  &assembly_row(++$form->{assembly_rows}) if $form->{item} eq 'assembly';

  print qq|

  <input type=hidden name=path value=$form->{path}>
  <input type=hidden name=login value=$form->{login}>
  <input type=hidden name=sessionid value=$form->{sessionid}>
  <input type=hidden name=callback value="$form->{callback}">
  <input type=hidden name=previousform value="$form->{previousform}">
  <input type=hidden name=isassemblyitem value=$form->{isassemblyitem}>

</form>

<a name="end"></a>

</body>
</html>
|;

}



sub makemodel_row {
  my ($numrows) = @_;

  map { $form->{"${_}_$i"} = $form->quote($form->{"${_}_$i"}) } qw(make model);

  print qq|
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th class="listheading">|.$locale->text('Make').qq|</th>
	  <th class="listheading">|.$locale->text('Model').qq|</th>
	</tr>
|;

  for $i (1 .. $numrows) {
    print qq|
	<tr>
	  <td><input name="make_$i" size=30 value="$form->{"make_$i"}"></td>
	  <td><input name="model_$i" size=30 value="$form->{"model_$i"}"></td>
	</tr>
|;
  }

  print qq|
      </table>
    </td>
  </tr>
|;

}


sub vendor_row {
  my ($numrows) = @_;

  $form->{selectvendor} = $form->unescape($form->{selectvendor});
  print qq|
  <input type=hidden name=selectvendor value="|.$form->escape($form->{selectvendor},1).qq|">
  
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th class="listheading">|.$locale->text('Vendor').qq|</th>
	  <th class="listheading">|.$locale->text('Number').qq|</th>
	  <th class="listheading">|.$locale->text('Cost').qq|</th>
	  <th class="listheading">|.$locale->text('Curr').qq|</th>
	  <th class="listheading">|.$locale->text('Leadtime').qq|</th>
	</tr>
|;

  for $i (1 .. $numrows) {
    
    $form->{selectcurrency} =~ s/ selected//;
   
    if ($i == $numrows) {
     
      $vendor = qq|
          <td><input name="vendor_$i" size=35 value="$form->{"vendor_$i"}"></td>
|;
 
      if ($form->{selectvendor}) {
	$vendor = qq|
	  <td width=99%><select name="vendor_$i">$form->{selectvendor}</select></td>
|;
      }
   
    } else {
      
      $form->{selectcurrency} =~ s/option>$form->{"vendorcurr_$i"}/option selected>$form->{"vendorcurr_$i"}/;
 
      ($vendor) = split /--/, $form->{"vendor_$i"};
      $vendor = qq|
          <td>$vendor
	  <input type=hidden name="vendor_$i" value="$form->{"vendor_$i"}">
	  </td>
|;

    }
   
    print qq|
	<tr>
	  $vendor
	  <td><input name="partnumber_$i" size=20 value="$form->{"partnumber_$i"}"></td>
	  <td><input name="lastcost_$i" size=10 value=|.$form->format_amount(\%myconfig, $form->{"lastcost_$i"}, 2).qq|></td>
	  <td><select name="vendorcurr_$i">$form->{selectcurrency}</select></td>
	  <td nowrap><input name="leadtime_$i" size=5 value=|.$form->format_amount(\%myconfig, $form->{"leadtime_$i"}).qq|> <b>|.$locale->text('days').qq|</b></td>
	</tr>
|;
      
  }

  print qq|
      </table>
    </td>
  </tr>
|;

}


sub customer_row {
  my ($numrows) = @_;

  if ($form->{selectpricegroup}) {
    $pricegroup = qq|
          <th class="listheading">|.$locale->text('Pricegroup').qq|
          </th>
|;
  }

  $form->{selectcustomer} = $form->unescape($form->{selectcustomer});
  $form->{selectpricegroup} = $form->unescape($form->{selectpricegroup});
  
  print qq|
  <input type=hidden name=selectcurrency value="$form->{selectcurrency}">
  <input type=hidden name=selectcustomer value="|.$form->escape($form->{selectcustomer},1).qq|">
  <input type=hidden name=selectpricegroup value="|.$form->escape($form->{selectpricegroup},1).qq|">
  
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th class="listheading">|.$locale->text('Customer').qq|</th>
	  $pricegroup
	  <th class="listheading">|.$locale->text('Break').qq|</th>
	  <th class="listheading">|.$locale->text('Sell Price').qq|</th>
	  <th class="listheading">|.$locale->text('Curr').qq|</th>
	  <th class="listheading">|.$locale->text('From').qq|</th>
	  <th class="listheading">|.$locale->text('To').qq|</th>
	</tr>
|;

  for $i (1 .. $numrows) {
    
    $form->{selectcurrency} =~ s/ selected//;
    $form->{selectcurrency} =~ s/option>$form->{"customercurr_$i"}/option selected>$form->{"customercurr_$i"}/;
    
    if ($i == $numrows) {
      $customer = qq|
          <td><input name="customer_$i" size=35 value="$form->{"customer_$i"}"></td>
	  |;
  
      if ($form->{selectcustomer}) {
	$customer = qq|
	  <td><select name="customer_$i">$form->{selectcustomer}</select></td>
|;
      }

      if ($form->{selectpricegroup}) {
	$pricegroup = qq|
	  <td><select name="pricegroup_$i">$form->{selectpricegroup}</select></td>
|;
      }

    } else {
      ($customer) = split /--/, $form->{"customer_$i"};
      $customer = qq|
          <td>$customer</td>
	  <input type=hidden name="customer_$i" value="$form->{"customer_$i"}">
	  |;

      if ($form->{selectpricegroup}) {
	($pricegroup) = split /--/, $form->{"pricegroup_$i"};
	$pricegroup = qq|
	  <td>$pricegroup</td>
	  <input type=hidden name="pricegroup_$i" value="$form->{"pricegroup_$i"}">
|;
      }
    }
    
    
    print qq|
	<tr>
	  $customer
	  $pricegroup

	  <td><input name="pricebreak_$i" size=5 value=|.$form->format_amount(\%myconfig, $form->{"pricebreak_$i"}).qq|></td>
	  <td><input name="customerprice_$i" size=10 value=|.$form->format_amount(\%myconfig, $form->{"customerprice_$i"}, 2).qq|></td>
	  <td><select name="customercurr_$i">$form->{selectcurrency}</select></td>
	  <td><input name="validfrom_$i" size=11 title="$myconfig{dateformat}" value="$form->{"validfrom_$i"}"></td>
	  <td><input name="validto_$i" size=11 title="$myconfig{dateformat}" value="$form->{"validto_$i"}"></td>
	</tr>
|;
  }

  print qq|
      </table>
    </td>
  </tr>
|;

}



sub assembly_row {
  my ($numrows) = @_;

  @column_index = qw(runningnumber qty unit bom adj partnumber description listprice sellprice lastcost);
  
  if ($form->{selectassemblypartsgroup}) {
    $form->{selectassemblypartsgroup} = $form->unescape($form->{selectassemblypartsgroup});
    @column_index = qw(runningnumber qty unit bom adj partnumber description partsgroup listprice sellprice lastcost);
  }
  
  delete $form->{previousform};

  # change callback
  $form->{old_callback} = $form->{callback};
  $callback = $form->{callback};
  $form->{callback} = "$form->{script}?action=display_form";

  # delete action
  map { delete $form->{$_} } qw(action header);

  $form->{baseassembly} = 0;
  $previousform = "";
  # save form variables in a previousform variable
  foreach $key (sort keys %$form) {
    # escape ampersands
    $form->{$key} =~ s/&/%26/g;
    $previousform .= qq|$key=$form->{$key}&|;
  }
  chop $previousform;
  $form->{previousform} = $form->escape($previousform, 1);

  $form->{sellprice} = 0;
  $form->{listprice} = 0;
  $form->{lastcost} = 0;
  $form->{weight} = 0;

  $form->{callback} = $callback;


  $column_header{runningnumber} = qq|<th nowrap width=5%>|.$locale->text('No.').qq|</th>|;
  $column_header{qty} = qq|<th align=left nowrap width=10%>|.$locale->text('Qty').qq|</th>|;
  $column_header{unit} = qq|<th align=left nowrap width=5%>|.$locale->text('Unit').qq|</th>|;
  $column_header{partnumber} = qq|<th align=left nowrap width=20%>|.$locale->text('Number').qq|</th>|;
  $column_header{description} = qq|<th nowrap width=50%>|.$locale->text('Description').qq|</th>|;
  $column_header{sellprice} = qq|<th align=right nowrap>|.$locale->text('Sell').qq|</th>|;
  $column_header{listprice} = qq|<th align=right nowrap>|.$locale->text('List').qq|</th>|;
  $column_header{lastcost} = qq|<th align=right nowrap>|.$locale->text('Cost').qq|</th>|;
  $column_header{bom} = qq|<th>|.$locale->text('BOM').qq|</th>|;
  $column_header{adj} = qq|<th>|.$locale->text('A').qq|</th>|;
  $column_header{partsgroup} = qq|<th>|.$locale->text('Group').qq|</th>|;
  
  print qq|
  <p>

  <table width=100%>
  <tr class=listheading>
    <th class=listheading>|.$locale->text('Individual Items').qq|</th>
  </tr>
  <tr>
    <td>
      <table width=100%>
        <tr>
|;

  map { print "\n$column_header{$_}" } @column_index;
  
  print qq|
        </tr>
|;


  for $i (1 .. $numrows) {
    $form->{"partnumber_$i"} = $form->quote($form->{"partnumber_$i"});

    $linetotalsellprice = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);
    $form->{sellprice} += $linetotalsellprice;
    
    $linetotallistprice = $form->round_amount($form->{"listprice_$i"} * $form->{"qty_$i"}, 2);
    $form->{listprice} += $linetotallistprice;

    $linetotallastcost = $form->round_amount($form->{"lastcost_$i"} * $form->{"qty_$i"}, 2);
    $form->{lastcost} += $linetotallastcost;


    $form->{"qty_$i"} = $form->format_amount(\%myconfig, $form->{"qty_$i"});

    $linetotalsellprice = $form->format_amount(\%myconfig, $linetotalsellprice, 2);
    $linetotallistprice = $form->format_amount(\%myconfig, $linetotallistprice, 2);
    $linetotallastcost = $form->format_amount(\%myconfig, $linetotallastcost, 2);

    if ($i == $numrows) {

      map { $column_data{$_} = qq|<td></td>| } qw(runningnumber unit bom adj);

      $column_data{qty} = qq|<td><input name="qty_$i" size=5 value="$form->{"qty_$i"}"></td>|;
      $column_data{partnumber} = qq|<td><input name="partnumber_$i" size=15 value="$form->{"partnumber_$i"}"></td>|;
      $column_data{description} = qq|<td><input name="description_$i" size=30 value="$form->{"description_$i"}"></td>|;
      $column_data{partsgroup} = qq|<td><select name="partsgroup_$i">$form->{selectassemblypartsgroup}</select></td>|;

    } else {
      
      $column_data{partnumber} = qq|<td><input class=submit type=submit name=action value=" $form->{"partnumber_$i"}"></td>
      <input type=hidden name="partnumber_$i" value="$form->{"partnumber_$i"}">|;
	
      $column_data{runningnumber} = qq|<td><input name="runningnumber_$i" size=3 value="$i"></td>|;
      $column_data{qty} = qq|<td><input name="qty_$i" size=5 value="$form->{"qty_$i"}"></td>|;

      map { $form->{"${_}_$i"} = ($form->{"${_}_$i"}) ? "checked" : "" } qw(bom adj);
      $column_data{bom} = qq|<td align=center><input name="bom_$i" type=checkbox class=checkbox value=1 $form->{"bom_$i"}></td>|;
      $column_data{adj} = qq|<td align=center><input name="adj_$i" type=checkbox class=checkbox value=1 $form->{"adj_$i"}></td>|;

      ($partsgroup) = split /--/, $form->{"partsgroup_$i"};
      $column_data{partsgroup} = qq|<td><input type=hidden name="partsgroup_$i" value="$form->{"partsgroup_$i"}">$partsgroup</td>|;

      $column_data{unit} = qq|<td><input type=hidden name="unit_$i" value="$form->{"unit_$i"}">$form->{"unit_$i"}</td>|;
      $column_data{description} = qq|<td><input type=hidden name="description_$i" value="$form->{"description_$i"}">$form->{"description_$i"}</td>|;
      
    }
    
    $column_data{sellprice} = qq|<td align=right>$linetotalsellprice</td>|;
    $column_data{listprice} = qq|<td align=right>$linetotallistprice</td>|;
    $column_data{lastcost} = qq|<td align=right>$linetotallastcost</td>|;
    
    print qq|
        <tr>|;

    map { print "\n$column_data{$_}" } @column_index;
    
    print qq|
        </tr>
  <input type=hidden name="id_$i" value=$form->{"id_$i"}>
  <input type=hidden name="sellprice_$i" value=$form->{"sellprice_$i"}>
  <input type=hidden name="listprice_$i" value=$form->{"listprice_$i"}>
  <input type=hidden name="lastcost_$i" value=$form->{"lastcost_$i"}>
  <input type=hidden name="weight_$i" value=$form->{"weight_$i"}>
  <input type=hidden name="assembly_$i" value=$form->{"assembly_$i"}>
|;
  }

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{sellprice} = "<th align=right>".$form->format_amount(\%myconfig, $form->{sellprice}, 2)."</th>";
  $column_data{listprice} = "<th align=right>".$form->format_amount(\%myconfig, $form->{listprice}, 2)."</th>";
  $column_data{lastcost} = "<th align=right>".$form->format_amount(\%myconfig, $form->{lastcost}, 2)."</th>";
  
  print qq|
        <tr>|;

  map { print "\n$column_data{$_}" } @column_index;
    
  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
  </table>
  <input type=hidden name=assembly_rows value=$form->{assembly_rows}>
  <input type=hidden name=nextsub value=edit_assemblyitem>
  <input type=hidden name=selectassemblypartsgroup value="|.$form->escape($form->{selectassemblypartsgroup},1).qq|">
|;
 
}


sub edit_assemblyitem {

  $pn = substr($form->{action}, 1);

  for ($i = 1; $i < $form->{assembly_rows}; $i++) {
    last if $form->{"partnumber_$i"} eq $pn;
  }

  $form->error($local->text('unexpected error!')) unless $i;
  
  $form->{baseassembly} = ($form->{baseassembly}) ? $form->{baseassembly} : $form->{"assembly_$i"};

  $form->{callback} = qq|$form->{script}?action=edit&id=$form->{"id_$i"}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&rowcount=$i&baseassembly=$form->{baseassembly}&isassemblyitem=1&previousform=$form->{previousform}|;

  $form->redirect;
  
}


sub update {

  if ($form->{item} eq "assembly") {

    $i = $form->{assembly_rows};
    
    # if last row is empty check the form otherwise retrieve item
    if (($form->{"partnumber_$i"} eq "") && ($form->{"description_$i"} eq "") && ($form->{"partsgroup_$i"} eq "")) {
      
      &check_form;
      
    } else {

      IC->assembly_item(\%myconfig, \%$form);

      $rows = scalar @{ $form->{item_list} };
      
      if ($rows) {
	$form->{"qty_$i"} = 1 unless ($form->{"qty_$i"});
	$form->{"adj_$i"} = 1;
	
	if ($rows > 1) {
	  $form->{makemodel_rows}--;
	  $form->{customer_rows}--;
	  &select_item;
	  exit;
	} else {
	  map { $form->{item_list}[$i]{$_} = $form->quote($form->{item_list}[$i]{$_}) } qw(partnumber description unit);
	  map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} } keys %{ $form->{item_list}[0] };

	  if ($form->{item_list}[0]{partsgroup_id}) {
	    $form->{"partsgroup_$i"} = qq|$form->{item_list}[0]{partsgroup}--$form->{item_list}[0]{partsgroup_id}|;
	  }
	  
	  $form->{"runningnumber_$i"} = $form->{assembly_rows};
	  $form->{assembly_rows}++;

	  &check_form;

	}

      } else {

        $form->{rowcount} = $i;
	$form->{assembly_rows}++;
	
	&new_item;

      }
    }

  } else {
  
    &check_form;

  }

}


sub check_vendor {
  
  @flds = qw(vendor partnumber lastcost leadtime);
  @a = (); 
  $count = 0; 

  map { $form->{"${_}_$form->{vendor_rows}"} = $form->parse_amount(\%myconfig, $form->{"${_}_$form->{vendor_rows}"}) } qw(lastcost leadtime);
  
  for $i (1 .. $form->{vendor_rows} - 1) {
    
    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(lastcost leadtime);
    
    if ($form->{"lastcost_$i"} || $form->{"partnumber_$i"}) {

      push @a, {};
      $j = $#a; 
      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;

    } 
  }
  
  $i = $form->{vendor_rows};
  
  if (!$form->{selectvendor}) {

    if ($form->{"vendor_$i"}) {
      ($form->{vendor}) = split /--/, $form->{"vendor_$i"};
      if (($j = $form->get_name(\%myconfig, vendor)) > 1) {
	&select_name(vendor, $i);
	exit;
      }

      if ($j == 1) {
	# we got one name
	$form->{"vendor_$i"} = qq|$form->{name_list}[0]->{name}--$form->{name_list}[0]->{id}|;
      } else {
	# name is not on file
	$form->error(qq|$form->{"vendor_$i"} : |.$locale->text('Vendor not on file!'));
      }
    }
  }

  if ($form->{"vendor_$i"}) {
    push @a, {};
    $j = $#a; 
    map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
    $count++;
  }

  $form->redo_rows(\@flds, \@a, $count, $form->{vendor_rows});
  $form->{vendor_rows} = $count;

}


sub check_customer {
  
  @flds = qw(customer validfrom validto pricebreak customerprice pricegroup);
  @a = (); 
  $count = 0;

  map { $form->{"${_}_$form->{customer_rows}"} = $form->parse_amount(\%myconfig, $form->{"${_}_$form->{customer_rows}"}) } qw(customerprice pricebreak);

  for $i (1 .. $form->{customer_rows} - 1) {

    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(customerprice pricebreak);
    
    if ($form->{"customerprice_$i"}) {
      if ($form->{"pricebreak_$i"} || $form->{"customer_$i"} || $form->{"pricegroup_$i"}) {
	
	push @a, {};
	$j = $#a; 
	map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
	$count++;
	
      }
    }
  }

  $i = $form->{customer_rows};

  if (!$form->{selectcustomer}) {

    if ($form->{"customer_$i"}) {
      ($form->{customer}) = split /--/, $form->{"customer_$i"};

      if (($j = $form->get_name(\%myconfig, customer)) > 1) {
	&select_name(customer, $i);
	exit;
      }

      if ($j == 1) {
	# we got one name
	$form->{"customer_$i"} = qq|$form->{name_list}[0]->{name}--$form->{name_list}[0]->{id}|;
      } else {
	# name is not on file
	$form->error(qq|$form->{customer} : |.$locale->text('Customer not on file!'));
      }
    }
  }

  if ($form->{"customer_$i"} || $form->{"pricegroup_$i"} || ($form->{"customerprice_$i"} || $form->{"pricebreak_$i"})) {
    push @a, {};
    $j = $#a; 
    map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
    $count++;
  }

  $form->redo_rows(\@flds, \@a, $count, $form->{customer_rows});
  $form->{customer_rows} = $count;

}



sub select_name {
  my ($table, $vr) = @_;
  
  @column_index = qw(ndx name address);

  $label = ucfirst $table;
  $column_data{ndx} = qq|<th>&nbsp;</th>|;
  $column_data{name} = qq|<th class=listheading>|.$locale->text($label).qq|</th>|;
  $column_data{address} = qq|<th class=listheading>|.$locale->text('Address').qq|</th>|;
  
  # list items with radio button on a form
  $form->header;

  $title = $locale->text('Select from one of the names below');

  print qq|
<body>

<form method=post action="$form->{script}#end">

<input type=hidden name=vr value=$vr>

<table width=100%>
  <tr>
    <th class=listtop>$title</th>
  </tr>
  <tr space=5></tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;
  
  print qq|
	</tr>
|;

  my $i = 0;
  foreach $ref (@{ $form->{name_list} }) {
    $checked = ($i++) ? "" : "checked";

    $ref->{name} = $form->quote($ref->{name});
    
   $column_data{ndx} = qq|<td><input name=ndx class=radio type=radio value=$i $checked></td>|;
   $column_data{name} = qq|<td><input name="new_name_$i" type=hidden value="$ref->{name}">$ref->{name}</td>|;
   $column_data{address} = qq|<td>$ref->{address1} $ref->{address2} $ref->{city} $ref->{state} $ref->{zipcode} $ref->{country}</td>|;
    
    $j++; $j %= 2;
    print qq|
	<tr class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
	</tr>

<input name="new_id_$i" type=hidden value=$ref->{id}>

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

<input name=lastndx type=hidden value=$i>

|;

  # delete variables
  map { delete $form->{$_} } qw(action name_list header);

  $form->hide_form();
  
  print qq|
<input type=hidden name=nextsub value=name_selected>

<input type=hidden name=vc value=$table>
<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}



sub name_selected {

  # replace the variable with the one checked

  # index for new item
  $i = $form->{ndx};
  
  $form->{"$form->{vc}_$form->{vr}"} = qq|$form->{"new_name_$i"}--$form->{"new_id_$i"}|;
  $form->{"$form->{vc}_id_$form->{vr}"} = $form->{"new_id_$i"};

  # delete all the new_ variables
  for $i (1 .. $form->{lastndx}) {
    map { delete $form->{"new_${_}_$i"} } (id, name);
  }
  
  map { delete $form->{$_} } qw(ndx lastndx nextsub);

  &update;

}


sub save {

  if ($form->{obsolete}) {
    $form->error($locale->text("Inventory quantity must be zero before you can set this $form->{item} obsolete!")) if ($form->{onhand});
  }

# expand dynamic strings
# $locale->text('Inventory quantity must be zero before you can set this part obsolete!')
# $locale->text('Inventory quantity must be zero before you can set this assembly obsolete!')

  $olditem = $form->{id};

  # save part
  $rc = IC->save(\%myconfig, \%$form);

  $parts_id = $form->{id};

  # load previous variables
  if ($form->{previousform} && !$form->{callback}) {
    # save the new form variables before splitting previousform
    map { $newform{$_} = $form->{$_} } keys %$form;

    $previousform = $form->unescape($form->{previousform});
    $baseassembly = $form->{baseassembly};

    # don't trample on previous variables
    map { delete $form->{$_} } keys %newform;

    # now take it apart and restore original values
    foreach $item (split /&/, $previousform) {
      ($key, $value) = split /=/, $item, 2;
      $value =~ s/%26/&/g;
      $form->{$key} = $value;
    }


    if ($form->{item} eq 'assembly') {

      if ($baseassembly) {
	#redo the assembly
	$previousform =~ /\&id=(\d+)/;
	$form->{id} = $1;
	
	# restore original callback
	$form->{callback} = $form->unescape($form->{old_callback});

	&edit;
	exit;
      }
	
      # undo number formatting
      map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(weight listprice sellprice lastcost rop);

      $form->{assembly_rows}-- if $olditem;
      $i = $newform{rowcount};
      $form->{"qty_$i"} = 1 unless ($form->{"qty_$i"});

      ($dec) = ($form->{listprice} =~ /\.(\d+)/);
      $dec = length $dec;
      $dec1 = ($dec > 2) ? $dec : 2;
 
      ($dec) = ($form->{sellprice} =~ /\.(\d+)/);
      $dec = length $dec;
      $dec2 = ($dec > 2) ? $dec : 2;
     
      ($dec) = ($form->{lastcost} =~ /\.(\d+)/);
      $dec = length $dec;
      $dec3 = ($dec > 2) ? $dec : 2;

      $form->{listprice} -= $form->{"listprice_$i"} * $form->{"qty_$i"};
      $form->{sellprice} -= $form->{"sellprice_$i"} * $form->{"qty_$i"};
      $form->{lastcost} -= $form->{"lastcost_$i"} * $form->{"qty_$i"};
      $form->{weight} -= $form->{"weight_$i"} * $form->{"qty_$i"};

      # change/add values for assembly item
      map { $form->{"${_}_$i"} = $newform{$_} } qw(partnumber description bin unit weight listprice sellprice lastcost inventory_accno income_accno expense_accno);

      $form->{listprice} += $form->{"listprice_$i"} * $form->{"qty_$i"};
      $form->{listprice} = $form->round_amount($form->{listprice}, $dec1);

      $form->{sellprice} += $form->{"sellprice_$i"} * $form->{"qty_$i"};
      $form->{sellprice} = $form->round_amount($form->{sellprice}, $dec2);
      
      $form->{lastcost} += $form->{"lastcost_$i"} * $form->{"qty_$i"};
      $form->{lastcost} = $form->round_amount($form->{lastcost}, $dec3);

      $form->{weight} += $form->{"weight_$i"} * $form->{"qty_$i"};

      $form->{"adj_$i"} = 1 if !$olditem;

      $form->{customer_rows}--;
      
    } else {
      # set values for last invoice/order item
      $i = $form->{rowcount};
      $form->{"qty_$i"} = 1 unless ($form->{"qty_$i"});

      map { $form->{"${_}_$i"} = $newform{$_} } qw(partnumber description bin unit listprice inventory_accno income_accno expense_accno sellprice partsgroup);
      $form->{"sellprice_$i"} = $newform{lastcost} if ($form->{vendor_id});

      if ($form->{exchangerate} != 0) {
	($dec) = ($newform{sellprice} =~ /\.(\d+)/);
	$dec = length $dec;
	$decimalplaces = ($dec > 2) ? $dec : 2;
	
	$form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} / $form->{exchangerate}, $decimalplaces);
      }
      
      map { $form->{"taxaccounts_$i"} .= "$_ " if ($newform{"IC_tax_$_"}) } split / /, $newform{taxaccounts};
      chop $form->{"taxaccounts_$i"};

      # credit remaining calculation
      $amount = $form->{"sellprice_$i"} * (1 - $form->{"discount_$i"} / 100) * $form->{"qty_$i"};
      map { $form->{"${_}_base"} += $amount } (split / /, $form->{"taxaccounts_$i"});
      map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{"taxaccounts_$i"} if !$form->{taxincluded};

      $form->{creditremaining} -= $amount;
      
    }
    
    $form->{"id_$i"} = $parts_id;
    delete $form->{action};

    # restore original callback
    $callback = $form->unescape($form->{callback});
    $form->{callback} = $form->unescape($form->{old_callback});
    delete $form->{old_callback};

    $form->{makemodel_rows}--;

    # put callback together
    foreach $key (keys %$form) {
      # do single escape for Apache 2.0
      $value = $form->escape($form->{$key}, 1);
      $callback .= qq|&$key=$value|;
    }
    $form->{callback} = $callback;
  }

  # redirect
  $form->redirect;

}


sub save_as_new {

  $form->{id} = 0;
  &save;

}


sub delete {

  $rc = IC->delete(\%myconfig, \%$form);
  
  # redirect
  $form->redirect($locale->text('Item deleted!')) if ($rc > 0);
  $form->error($locale->text('Cannot delete item!'));

}



sub stock_assembly {

  $form->{title} = $locale->text('Stock Assembly');
  
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>

<table width="100%">
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
        <tr>
          <th align="right" nowrap="true">|.$locale->text('Number').qq|</th>
          <td><input name=partnumber size=20></td>
          <td>&nbsp;</td>
        </tr>
        <tr>
          <th align="right" nowrap="true">|.$locale->text('Description').qq|</th>
          <td><input name=description size=40></td>
        </tr>
        <tr>
          <td></td>
	  <td><input name=checkinventory class=checkbox type=checkbox value=1>&nbsp;|.$locale->text('Check Inventory').qq|</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr><td><hr size=3 noshade></td></tr>
</table>

<input type=hidden name=sort value=partnumber>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input type=hidden name=nextsub value=list_assemblies>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

}




sub list_assemblies {

  IC->retrieve_assemblies(\%myconfig, \%$form);

  $callback = "$form->{script}?action=list_assemblies&direction=$form->{direction}&oldsort=$form->{oldsort}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&checkinventory=$form->{checkinventory}";
  
  $form->sort_order();
  $href = "$form->{script}?action=list_assemblies&direction=$form->{direction}&oldsort=$form->{oldsort}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&checkinventory=$form->{checkinventory}";
  
  if ($form->{partnumber}) {
    $callback .= "&partnumber=".$form->escape($form->{partnumber},1);
    $href .= "&partnumber=".$form->escape($form->{partnumber});
    $form->{sort} = "partnumber" unless $form->{sort};
  }
  if ($form->{description}) {
    $callback .= "&description=".$form->escape($form->{description},1);
    $href .= "&description=".$form->escape($form->{description});
    $form->{sort} = "description" unless $form->{sort};
  }
 
  $column_header{partnumber} = qq|<th><a class=listheading href=$href&sort=partnumber>|.$locale->text('Number').qq|</th>|;
  $column_header{description} = qq|<th><a class=listheading href=$href&sort=description>|.$locale->text('Description').qq|</th>|;
  $column_header{bin} = qq|<th><a class=listheading href=$href&sort=bin>|.$locale->text('Bin').qq|</th>|;
  $column_header{onhand} = qq|<th class=listheading>|.$locale->text('Qty').qq|</th>|;
  $column_header{rop} = qq|<th class=listheading>|.$locale->text('ROP').qq|</th>|;
  $column_header{stock} = qq|<th class=listheading>|.$locale->text('Add').qq|</th>|;

  @column_index = $form->sort_columns(qw(partnumber description bin onhand rop stock));
  
  $form->{title} = $locale->text('Stock Assembly');

  
  $form->header;
  

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr size=5></tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
|;

  map { print "\n$column_header{$_}" } @column_index;

  print qq|
	</tr>
|;

  # add sort and escape callback
  $form->{callback} = $callback .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($callback);


  $i = 1;
  foreach $ref (@{ $form->{assembly_items} }) {

    map { $ref->{$_} = $form->quote($ref->{$_}) } qw(partnumber description);
   
    $column_data{partnumber} = "<td width=20%><a href=$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$callback>$ref->{partnumber}&nbsp;</a></td>";
    
    $column_data{description} = qq|<td width=50%>$ref->{description}&nbsp;</td>|;
    $column_data{bin} = qq|<td>$ref->{bin}&nbsp;</td>|;
    $column_data{onhand} = qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{onhand}, "", "&nbsp;").qq|</td>|;
    $column_data{rop} = qq|<td align=right>|.$form->format_amount(\%myconfig, $ref->{rop}, '', "&nbsp;").qq|</td>|;
    $column_data{stock} = qq|<td width=10%><input name="qty_$i" size=10 value=|.$form->format_amount(\%myconfig, $ref->{stock}).qq|></td>
    <input type=hidden name="stock_$i" value=$ref->{stock}>|;

    $j++; $j %= 2;
    print qq|<tr class=listrow$j><input name="id_$i" type=hidden value=$ref->{id}>\n|;
    
    map { print "\n$column_data{$_}" } @column_index;
    
    print qq|
	</tr>
|;

    $i++;

  }
  
  $i--;
  print qq|
      </td>
    </table>
  <tr>
    <td><hr size=3 noshade>
  </tr>
</table>

<input name=rowcount type=hidden value="$i">
<input type=hidden name=checkinventory value=$form->{checkinventory}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=sessionid value=$form->{sessionid}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=nextsub value=restock_assemblies>

<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">

</form>

</body>
</html>
|;
 
}


sub restock_assemblies {


  if ($form->{checkinventory}) {
    map { $form->error($locale->text('Quantity exceeds available units to stock!')) if $form->parse_amount($myconfig, $form->{"qty_$_"}) > $form->{"stock_$_"} }(1 .. $form->{rowcount});
  }

  $form->redirect($locale->text('Assemblies restocked!')) if (IC->restock_assemblies(\%myconfig, \%$form));
  $form->error($locale->text('Cannot stock assemblies!'));
  
}


sub continue { &{ $form->{nextsub} } };

sub add_part { &add };
sub add_service { &add };
sub add_assembly { &add };
sub add_labor_overhead { &add };


