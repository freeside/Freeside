#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2000
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors: Jim Rawlings <jim@your-dba.com>
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
# Inventory invoicing module
#
#======================================================================

package IS;


sub invoice_details {
  my ($self, $myconfig, $form) = @_;

  $form->{duedate} = $form->{transdate} unless ($form->{duedate});

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT date '$form->{duedate}' - date '$form->{transdate}'
                 AS terms
		 FROM defaults|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{terms}) = $sth->fetchrow_array;
  $sth->finish;

  # this is for the template
  $form->{invdate} = $form->{transdate};
  
  my $tax = 0;
  my $item;
  my $i;
  my @sortlist = ();
  my $projectnumber;
  my $projectnumber_id;
  my $translation;
  my $partsgroup;
  
  my %oid = ( 'Pg'	=> 'oid',
              'PgPP'	=> 'oid',
              'Oracle'	=> 'rowid',
	      'DB2'	=> '1=1'
	    );
  
  # sort items by partsgroup
  for $i (1 .. $form->{rowcount}) {
    $projectnumber = "";
    $partsgroup = "";
    $projectnumber_id = 0;
    if ($form->{"projectnumber_$i"} && $form->{groupprojectnumber}) {
      ($projectnumber, $projectnumber_id) = split /--/, $form->{"projectnumber_$i"};
    }
    if ($form->{"partsgroup_$i"} && $form->{grouppartsgroup}) {
      ($partsgroup) = split /--/, $form->{"partsgroup_$i"};
    }
    push @sortlist, [ $i, "$projectnumber$partsgroup", $projectnumber, $projectnumber_id, $partsgroup ];


    # sort the whole thing by project and group
    @sortlist = sort { $a->[1] cmp $b->[1] } @sortlist;
    
  }
  
  my @taxaccounts;
  my %taxaccounts;
  my $taxrate;
  my $taxamount;
  my $taxbase;
  my $taxdiff;
 
  $query = qq|SELECT p.description, t.description
              FROM project p
	      LEFT JOIN translation t ON (t.trans_id = p.id AND t.language_code = '$form->{language_code}')
	      WHERE id = ?|;
  my $prh = $dbh->prepare($query) || $form->dberror($query);

  my $runningnumber = 1;
  my $sameitem = "";
  my $subtotal;
  my $k = scalar @sortlist;
  my $j = 0;
  
  foreach $item (@sortlist) {
    $i = $item->[0];
    $j++;

    if ($form->{groupprojectnumber} || $form->{grouppartsgroup}) {
      if ($item->[1] ne $sameitem) {

	$projectnumber = "";
	if ($form->{groupprojectnumber} && $item->[2]) {
          # get project description
	  $prh->execute($item->[3]) || $form->dberror($query);

	  ($projectnumber, $translation) = $prh->fetchrow_array;
	  $prh->finish;

	  $projectnumber = ($translation) ? "$item->[2], $translation" : "$item->[2], $projectnumber";
	}

	if ($form->{grouppartsgroup} && $item->[4]) {
	  $projectnumber .= " / " if $projectnumber;
	  $projectnumber .= $item->[4];
	}

	$form->{projectnumber} = $projectnumber;
	$form->format_string(projectnumber);

	push(@{ $form->{description} }, qq|$form->{projectnumber}|);
	$sameitem = $item->[1];

	map { push(@{ $form->{$_} }, "") } qw(runningnumber number sku serialnumber bin qty unit deliverydate projectnumber sellprice listprice netprice discount discountrate linetotal weight);
      }
    }
      
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    
    if ($form->{"qty_$i"} != 0) {

      $form->{totalqty} += $form->{"qty_$i"};
      $form->{totalship} += $form->{"ship_$i"};
      $form->{totalweight} += ($form->{"qty_$i"} * $form->{"weight_$i"});

      # add number, description and qty to $form->{number}, ....
      push(@{ $form->{runningnumber} }, $runningnumber++);
      push(@{ $form->{number} }, qq|$form->{"partnumber_$i"}|);
      push(@{ $form->{sku} }, qq|$form->{"sku_$i"}|);
      push(@{ $form->{serialnumber} }, qq|$form->{"serialnumber_$i"}|);
      push(@{ $form->{bin} }, qq|$form->{"bin_$i"}|);
      push(@{ $form->{description} }, qq|$form->{"description_$i"}|);
      push(@{ $form->{qty} }, $form->format_amount($myconfig, $form->{"qty_$i"}));
      push(@{ $form->{unit} }, qq|$form->{"unit_$i"}|);
      push(@{ $form->{deliverydate} }, qq|$form->{"deliverydate_$i"}|);
      push(@{ $form->{projectnumber} }, qq|$form->{"projectnumber_$i"}|);
      
      push(@{ $form->{sellprice} }, $form->{"sellprice_$i"});
      
      # listprice
      push(@{ $form->{listprice} }, $form->{"listprice_$i"});
      
      push(@{ $form->{weight} }, $form->{"weight_$i"});

      my $sellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my ($dec) = ($sellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;
      
      my $discount = $form->round_amount($sellprice * $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100, $decimalplaces);
      
      # keep a netprice as well, (sellprice - discount)
      $form->{"netprice_$i"} = $sellprice - $discount;
      push(@{ $form->{netprice} }, ($form->{"netprice_$i"} != 0) ? $form->format_amount($myconfig, $form->{"netprice_$i"}, $decimalplaces) : " ");

      
      my $linetotal = $form->round_amount($form->{"qty_$i"} * $form->{"netprice_$i"}, 2);

      $discount = ($discount != 0) ? $form->format_amount($myconfig, $discount * -1, $decimalplaces) : " ";
      $linetotal = ($linetotal != 0) ? $linetotal : " ";
      
      push(@{ $form->{discount} }, $discount);
      push(@{ $form->{discountrate} }, $form->format_amount($myconfig, $form->{"discount_$i"}));

      $form->{total} += $linetotal;

      # this is for the subtotals for grouping
      $subtotal += $linetotal;

      push(@{ $form->{linetotal} }, $form->format_amount($myconfig, $linetotal, 2));
      
      @taxaccounts = split / /, $form->{"taxaccounts_$i"};
      $taxrate = 0;
      $taxdiff = 0;
      
      map { $taxrate += $form->{"${_}_rate"} } @taxaccounts;

      if ($form->{taxincluded}) {
	# calculate tax
	$taxamount = $linetotal * $taxrate / (1 + $taxrate);
	$taxbase = $linetotal - $taxamount;
      } else {
        $taxamount = $linetotal * $taxrate;
	$taxbase = $linetotal;
      }

      if (@taxaccounts && $form->round_amount($taxamount, 2) == 0) {
	if ($form->{taxincluded}) {
	  foreach $item (@taxaccounts) {
	    $taxamount = $form->round_amount($linetotal * $form->{"${item}_rate"} / (1 + abs($form->{"${item}_rate"})), 2);
	    
	    $taxaccounts{$item} += $taxamount;
	    $taxdiff += $taxamount;
	    
	    $taxbase{$item} += $taxbase;
	  }
	  $taxaccounts{$taxaccounts[0]} += $taxdiff;
	} else {
	  foreach $item (@taxaccounts) {
	    $taxaccounts{$item} += $linetotal * $form->{"${item}_rate"};
	    $taxbase{$item} += $taxbase;
	  }
	}
      } else {
	foreach $item (@taxaccounts) {
	  $taxaccounts{$item} += $taxamount * $form->{"${item}_rate"} / $taxrate;
	  $taxbase{$item} += $taxbase;
	}
      }
      

      if ($form->{"assembly_$i"}) {
	my $sm = "";
	
        # get parts and push them onto the stack
	my $sortorder = "";
	if ($form->{groupitems}) {
	  $sortorder = qq|ORDER BY pg.partsgroup, a.$oid{$myconfig->{dbdriver}}|;
	} else {
	  $sortorder = qq|ORDER BY a.$oid{$myconfig->{dbdriver}}|;
	}
	
	$query = qq|SELECT p.partnumber, p.description, p.unit, a.qty,
	            pg.partsgroup, p.partnumber AS sku
	            FROM assembly a
		    JOIN parts p ON (a.parts_id = p.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    WHERE a.bom = '1'
		    AND a.id = '$form->{"id_$i"}'
		    $sortorder|;
        $sth = $dbh->prepare($query);
        $sth->execute || $form->dberror($query);

	while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
	  if ($form->{grouppartsgroup} && $ref->{partsgroup} ne $sameitem) {
	    map { push(@{ $form->{$_} }, "") } qw(runningnumber number sku serialnumber unit qty bin deliverydate projectnumber sellprice listprice netprice discount discountrate linetotal weight);
	    $sm = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
	    push(@{ $form->{description} }, $sm);
	  }
	    
	  map { $form->{"a_$_"} = $ref->{$_} } qw(partnumber description);
	  $form->format_string("a_partnumber", "a_description");
	  
	  push(@{ $form->{description} }, $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}) . qq| -- $form->{"a_partnumber"}, $form->{"a_description"}|);
          map { push(@{ $form->{$_} }, "") } qw(runningnumber number sku serialnumber unit qty bin deliverydate projectnumber sellprice listprice netprice discount discountrate linetotal weight);
	  
	}
	$sth->finish;
      }
    }

    # add subtotal
    if ($form->{groupprojectnumber} || $form->{grouppartsgroup}) {
      if ($subtotal) {
	if ($j < $k) {
	  # look at next item
	  if ($sortlist[$j]->[1] ne $sameitem) {
	    map { push(@{ $form->{$_} }, "") } qw(runningnumber number sku serialnumber bin qty unit deliverydate projectnumber sellprice listprice netprice discount discountrate weight);
	    push(@{ $form->{description} }, $form->{groupsubtotaldescription});
	    if (exists $form->{groupsubtotaldescription}) {
	      push(@{ $form->{linetotal} }, $form->format_amount($myconfig, $subtotal, 2));
	    } else {
	      push(@{ $form->{linetotal} }, "");
	    }
	    $subtotal = 0;
	  }
	} else {

	  # got last item
	  if (exists $form->{groupsubtotaldescription}) {
	    map { push(@{ $form->{$_} }, "") } qw(runningnumber number sku serialnumber bin qty unit deliverydate projectnumber sellprice listprice netprice discount discountrate weight);
	    push(@{ $form->{description} }, $form->{groupsubtotaldescription});
	    push(@{ $form->{linetotal} }, $form->format_amount($myconfig, $subtotal, 2));
	  }
	}
      }
    }

  }


  foreach my $item (sort keys %taxaccounts) {
    if ($form->round_amount($taxaccounts{$item}, 2) != 0) {
      push(@{ $form->{taxbase} }, $form->format_amount($myconfig, $taxbase{$item}, 2));

      $tax += $taxamount = $form->round_amount($taxaccounts{$item}, 2);

      push(@{ $form->{tax} }, $form->format_amount($myconfig, $taxamount));
      push(@{ $form->{taxdescription} }, $form->{"${item}_description"});
      push(@{ $form->{taxrate} }, $form->format_amount($myconfig, $form->{"${item}_rate"} * 100));
      push(@{ $form->{taxnumber} }, $form->{"${item}_taxnumber"});
    }
  }
    

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      push(@{ $form->{payment} }, $form->{"paid_$i"});
      my ($accno, $description) = split /--/, $form->{"AR_paid_$i"};
      push(@{ $form->{paymentaccount} }, $description); 
      push(@{ $form->{paymentdate} }, $form->{"datepaid_$i"});
      push(@{ $form->{paymentsource} }, $form->{"source_$i"});
      push(@{ $form->{paymentmemo} }, $form->{"memo_$i"});

      $form->{paid} += $form->parse_amount($myconfig, $form->{"paid_$i"});
    }
  }
  
  map { $form->{$_} = $form->format_amount($myconfig, $form->{$_}) } qw(totalqty totalship totalweight);
  $form->{subtotal} = $form->format_amount($myconfig, $form->{total}, 2);
  $form->{invtotal} = ($form->{taxincluded}) ? $form->{total} : $form->{total} + $tax;

  use SL::CP;
  my $c;
  if ($form->{language_code}) {
    $c = new CP $form->{language_code};
  } else {
    $c = new CP $myconfig->{countrycode};
  }
  $c->init;
  my $whole;
  ($whole, $form->{decimal}) = split /\./, $form->{invtotal};
  $form->{decimal} .= "00";
  $form->{decimal} = substr($form->{decimal}, 0, 2);
  $form->{text_amount} = $c->num2text($whole);
  
  $form->{total} = $form->format_amount($myconfig, $form->{invtotal} - $form->{paid}, 2);
  $form->{invtotal} = $form->format_amount($myconfig, $form->{invtotal}, 2);

  $form->{paid} = $form->format_amount($myconfig, $form->{paid}, 2);

  $dbh->disconnect;
  
}


sub project_description {
  my ($self, $dbh, $id) = @_;

  my $query = qq|SELECT description
                 FROM project
		 WHERE id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($_) = $sth->fetchrow_array;

  $sth->finish;

  $_;

}


sub customer_details {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  # get rest for the customer
  my $query = qq|SELECT customernumber, name, address1, address2, city,
                 state, zipcode, country,
	         phone as customerphone, fax as customerfax, contact,
		 taxnumber, sic_code AS sic, iban, bic
	         FROM customer
	         WHERE id = $form->{customer_id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  $dbh->disconnect;

}


sub post_invoice {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my $sth;
  my $null;
  my $project_id;
  my $exchangerate = 0;

  ($null, $form->{employee_id}) = split /--/, $form->{employee};
  unless ($form->{employee_id}) {
    ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh);
  }
  
  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;
 
  if ($form->{id}) {

    &reverse_invoice($dbh, $form);

  } else {
    my $uid = time;
    $uid .= $form->{login};
    
    $query = qq|INSERT INTO ar (invnumber, employee_id)
                VALUES ('$uid', $form->{employee_id})|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT id FROM ar
                WHERE invnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
  }

  my ($netamount, $invoicediff) = (0, 0);
  my ($amount, $linetotal, $lastincomeaccno);

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'buy');
  }

  $form->{exchangerate} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{exchangerate});
  

  foreach my $i (1 .. $form->{rowcount}) {
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    
    if ($form->{"qty_$i"} != 0) {

      # project
      $project_id = 'NULL';
      if ($form->{"projectnumber_$i"}) {
	($null, $project_id) = split /--/, $form->{"projectnumber_$i"};
      }

      # undo discount formatting
      $form->{"discount_$i"} = $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;

      my ($allocated, $taxrate) = (0, 0);
      my $taxamount;
      
      # keep entered selling price
      my $fxsellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      
      my ($dec) = ($fxsellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;
      
      # deduct discount
      my $discount = $form->round_amount($fxsellprice * $form->{"discount_$i"}, $decimalplaces);
      $form->{"sellprice_$i"} = $fxsellprice - $discount;
      
      # add tax rates
      map { $taxrate += $form->{"${_}_rate"} } split / /, $form->{"taxaccounts_$i"};

      # round linetotal to 2 decimal places
      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);
      
      if ($form->{taxincluded}) {
	$taxamount = $linetotal * ($taxrate / (1 + $taxrate));
	$form->{"sellprice_$i"} = $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
      } else {
	$taxamount = $linetotal * $taxrate;
      }

      $netamount += $linetotal;
      
      if ($form->round_amount($taxamount, 2) != 0) {
	map { $form->{amount}{$form->{id}}{$_} += $taxamount * $form->{"${_}_rate"} / $taxrate } split / /, $form->{"taxaccounts_$i"};
      }
    
    
      # add amount to income, $form->{amount}{trans_id}{accno}
      $amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate};
      
      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2) * $form->{exchangerate};
      $linetotal = $form->round_amount($linetotal, 2);
      
      # this is the difference from the inventory
      $invoicediff += ($amount - $linetotal);

      $form->{amount}{$form->{id}}{$form->{"income_accno_$i"}} += $linetotal;
      
      $lastincomeaccno = $form->{"income_accno_$i"};

      # adjust and round sellprice
      $form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate}, $decimalplaces);
      
      if ($form->{"inventory_accno_$i"} || $form->{"assembly_$i"}) {
        # adjust parts onhand quantity

        if ($form->{"assembly_$i"}) {
	  # do not update if assembly consists of all services
	  $query = qq|SELECT sum(p.inventory_accno_id)
		      FROM parts p
		      JOIN assembly a ON (a.parts_id = p.id)
		      WHERE a.id = $form->{"id_$i"}|;
	  $sth = $dbh->prepare($query);
	  $sth->execute || $form->dberror($query);

	  if ($sth->fetchrow_array) {
	    $form->update_balance($dbh,
				  "parts",
				  "onhand",
				  qq|id = $form->{"id_$i"}|,
				  $form->{"qty_$i"} * -1) unless $form->{shipped};
	  }
	  $sth->finish;
	   
	  # record assembly item as allocated
	  &process_assembly($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"});
	} else {
	  $form->update_balance($dbh,
				"parts",
				"onhand",
				qq|id = $form->{"id_$i"}|,
				$form->{"qty_$i"} * -1) unless $form->{shipped};
	  
	  $allocated = &cogs($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"});
	}
      }

      
      # save detail record in invoice table
      $query = qq|INSERT INTO invoice (trans_id, parts_id, description, qty,
                  sellprice, fxsellprice, discount, allocated, assemblyitem,
		  unit, deliverydate, project_id, serialnumber)
		  VALUES ($form->{id}, $form->{"id_$i"}, |
		  .$dbh->quote($form->{"description_$i"}).qq|,
		  $form->{"qty_$i"}, $form->{"sellprice_$i"}, $fxsellprice,
		  $form->{"discount_$i"}, $allocated, 'f', |
		  .$dbh->quote($form->{"unit_$i"}).qq|, |
		  .$form->dbquote($form->{"deliverydate_$i"}, SQL_DATE).qq|,
		  $project_id, |
		  .$dbh->quote($form->{"serialnumber_$i"}).qq|)|;
      $dbh->do($query) || $form->dberror($query);

    }
  }


  $form->{datepaid} = $form->{transdate};
  
  # total payments, don't move we need it here
  $form->{paid} = 0;
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{paid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"} if ($form->{"datepaid_$i"});
  }
  
  my ($tax, $diff) = (0, 0);
  
  $netamount = $form->round_amount($netamount, 2);
  
  # figure out rounding errors for total amount vs netamount + taxes
  if ($form->{taxincluded}) {
    
    $amount = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $diff += $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;
    
    foreach my $item (split / /, $form->{taxaccounts}) {
      $amount = $form->{amount}{$form->{id}}{$item} * $form->{exchangerate};
      $form->{amount}{$form->{id}}{$item} = $form->round_amount($amount, 2);
      $tax += $form->{amount}{$form->{id}}{$item};
      $netamount -= $form->{amount}{$form->{id}}{$item};
    }

    $invoicediff += $diff;
    ######## this only applies to tax included
    if ($lastincomeaccno) {
      $form->{amount}{$form->{id}}{$lastincomeaccno} += $invoicediff;
    }

  } else {
    $amount = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $diff = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;
    foreach my $item (split / /, $form->{taxaccounts}) {
      $form->{amount}{$form->{id}}{$item} = $form->round_amount($form->{amount}{$form->{id}}{$item}, 2);
      $amount = $form->round_amount($form->{amount}{$form->{id}}{$item} * $form->{exchangerate}, 2);
      $diff += $amount - $form->{amount}{$form->{id}}{$item} * $form->{exchangerate};
      $form->{amount}{$form->{id}}{$item} = $form->round_amount($amount, 2);
      $tax += $form->{amount}{$form->{id}}{$item};
    }
  }

  $diff = 0 if $form->{paidaccounts} < 2;

  $form->{amount}{$form->{id}}{$form->{AR}} = $netamount + $tax;
  $form->{paid} = $form->round_amount($form->{paid} * $form->{exchangerate} + $diff, 2);
  
  # reverse AR
  $form->{amount}{$form->{id}}{$form->{AR}} *= -1;


  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, $form->{exchangerate}, 0);
  }
    
  foreach my $trans_id (keys %{$form->{amount}}) {
    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      if (($form->{amount}{$trans_id}{$accno} = $form->round_amount($form->{amount}{$trans_id}{$accno}, 2)) != 0) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate)
		    VALUES ($trans_id, (SELECT id FROM chart
					WHERE accno = '$accno'),
		    $form->{amount}{$trans_id}{$accno},
		    '$form->{transdate}')|;
	$dbh->do($query) || $form->dberror($query);
      }
    }
  }

  # deduct payment differences from diff
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);
      $diff -= $amount - $form->{"paid_$i"} * $form->{exchangerate};
    }
  }


  # force AR entry if 0
  $form->{amount}{$form->{id}}{$form->{AR}} = $form->{paid} if ($form->{amount}{$form->{id}}{$form->{AR}} == 0);
  
  # record payments and offsetting AR
  for my $i (1 .. $form->{paidaccounts}) {
    
    if ($form->{"paid_$i"} != 0) {
      my ($accno) = split /--/, $form->{"AR_paid_$i"};
      $form->{"datepaid_$i"} = $form->{transdate} unless ($form->{"datepaid_$i"});
      $form->{datepaid} = $form->{"datepaid_$i"};
      
      $exchangerate = 0;
      
      if ($form->{currency} eq $form->{defaultcurrency}) {
	$form->{"exchangerate_$i"} = 1;
      } else {
	$exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy');
	
	$form->{"exchangerate_$i"} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }
      
 
      # record AR
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate} + $diff, 2);

      if ($form->{amount}{$form->{id}}{$form->{AR}} != 0) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate)
		    VALUES ($form->{id}, (SELECT id FROM chart
					WHERE accno = '$form->{AR}'),
		    $amount, '$form->{"datepaid_$i"}')|;
	$dbh->do($query) || $form->dberror($query);
      }

      # record payment
      $form->{"paid_$i"} *= -1;

      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                  source, memo)
                  VALUES ($form->{id}, (SELECT id FROM chart
		                      WHERE accno = '$accno'),
		  $form->{"paid_$i"}, '$form->{"datepaid_$i"}', |
		  .$dbh->quote($form->{"source_$i"}).qq|, |
		  .$dbh->quote($form->{"memo_$i"}).qq|)|;
      $dbh->do($query) || $form->dberror($query);

     
      # exchangerate difference
      $form->{fx}{$accno}{$form->{"datepaid_$i"}} += $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) + $diff;

      # gain/loss
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate},2) - $form->round_amount($form->{"paid_$i"} * $form->{"exchangerate_$i"},2);
      if ($amount > 0) {
	$form->{fx}{$form->{fxgain_accno}}{$form->{"datepaid_$i"}} += $amount;
      } else {
	$form->{fx}{$form->{fxloss_accno}}{$form->{"datepaid_$i"}} += $amount;
      }

      $diff = 0;

      # update exchange rate
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
	$form->update_exchangerate($dbh, $form->{currency}, $form->{"datepaid_$i"}, $form->{"exchangerate_$i"}, 0);
      }
    }
  }

  
  # record exchange rate differences and gains/losses
  foreach my $accno (keys %{$form->{fx}}) {
    foreach my $transdate (keys %{ $form->{fx}{$accno} }) {
      if (($form->{fx}{$accno}{$transdate} = $form->round_amount($form->{fx}{$accno}{$transdate}, 2)) != 0) {

	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, cleared, fx_transaction)
		    VALUES ($form->{id},
		           (SELECT id FROM chart
		            WHERE accno = '$accno'),
		    $form->{fx}{$accno}{$transdate}, '$transdate', '0', '1')|;
	$dbh->do($query) || $form->dberror($query);
      }
    }
  }
 

  $amount = $netamount + $tax;
  
  # set values which could be empty to 0
  $form->{terms} *= 1;
  $form->{taxincluded} *= 1;

  # if this is from a till
  my $till = ($form->{till}) ? qq|'$form->{till}'| : "NULL";
  
  # save AR record
  $query = qq|UPDATE ar set
              invnumber = |.$dbh->quote($form->{invnumber}).qq|,
	      ordnumber = |.$dbh->quote($form->{ordnumber}).qq|,
	      quonumber = |.$dbh->quote($form->{quonumber}).qq|,
              transdate = '$form->{transdate}',
              customer_id = $form->{customer_id},
              amount = $amount,
              netamount = $netamount,
              paid = $form->{paid},
	      datepaid = |.$form->dbquote($form->{datepaid}, SQL_DATE).qq|,
	      duedate = |.$form->dbquote($form->{duedate}, SQL_DATE).qq|,
	      invoice = '1',
	      shippingpoint = |.$dbh->quote($form->{shippingpoint}).qq|,
	      shipvia = |.$dbh->quote($form->{shipvia}).qq|,
	      terms = $form->{terms},
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      intnotes = |.$dbh->quote($form->{intnotes}).qq|,
	      taxincluded = '$form->{taxincluded}',
	      curr = '$form->{currency}',
	      department_id = $form->{department_id},
	      employee_id = $form->{employee_id},
	      till = $till,
	      language_code = '$form->{language_code}'
              WHERE id = $form->{id}
             |;
  $dbh->do($query) || $form->dberror($query);

  # add shipto
  $form->{name} = $form->{customer};
  $form->{name} =~ s/--$form->{customer_id}//;
  $form->add_shipto($dbh, $form->{id});

  # save printed, emailed and queued
  $form->save_status($dbh);
  
  my %audittrail = ( tablename  => 'ar',
                     reference  => $form->{invnumber},
		     formname   => $form->{type},
		     action     => 'posted',
		     id         => $form->{id} );
 
  $form->audittrail($dbh, "", \%audittrail);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}


sub process_assembly {
  my ($dbh, $form, $id, $totalqty) = @_;

  my $query = qq|SELECT a.parts_id, a.qty, p.assembly,
                 p.partnumber, p.description, p.unit,
                 p.inventory_accno_id, p.income_accno_id,
		 p.expense_accno_id
                 FROM assembly a
		 JOIN parts p ON (a.parts_id = p.id)
		 WHERE a.id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    my $allocated = 0;
    
    $ref->{inventory_accno_id} *= 1;
    $ref->{expense_accno_id} *= 1;

    # multiply by number of assemblies
    $ref->{qty} *= $totalqty;
    
    if ($ref->{assembly}) {
      &process_assembly($dbh, $form, $ref->{parts_id}, $ref->{qty});
      next;
    } else {
      if ($ref->{inventory_accno_id}) {
	$allocated = &cogs($dbh, $form, $ref->{parts_id}, $ref->{qty});
      }
    }

    # save detail record for individual assembly item in invoice table
    $query = qq|INSERT INTO invoice (trans_id, description, parts_id, qty,
                sellprice, fxsellprice, allocated, assemblyitem, unit)
		VALUES
		($form->{id}, |
		.$dbh->quote($ref->{description}).qq|,
		$ref->{parts_id}, $ref->{qty}, 0, 0, $allocated, 't', |
		.$dbh->quote($ref->{unit}).qq|)|;
    $dbh->do($query) || $form->dberror($query);
	 
  }

  $sth->finish;

}


sub cogs {
  my ($dbh, $form, $id, $totalqty) = @_;

  my $query = qq|SELECT i.id, i.trans_id, i.qty, i.allocated, i.sellprice,
                   (SELECT c.accno FROM chart c
		    WHERE p.inventory_accno_id = c.id) AS inventory_accno,
		   (SELECT c.accno FROM chart c
		    WHERE p.expense_accno_id = c.id) AS expense_accno
		  FROM invoice i, parts p
		  WHERE i.parts_id = p.id
		  AND i.parts_id = $id
		  AND (i.qty + i.allocated) < 0
		  ORDER BY trans_id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $allocated = 0;
  my $qty;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if (($qty = (($ref->{qty} * -1) - $ref->{allocated})) > $totalqty) {
      $qty = $totalqty;
    }
    
    $form->update_balance($dbh,
			  "invoice",
			  "allocated",
			  qq|id = $ref->{id}|,
			  $qty);

    # total expenses and inventory
    # sellprice is the cost of the item
    $linetotal = $form->round_amount($ref->{sellprice} * $qty, 2);
    
    # add to expense
    $form->{amount}{$form->{id}}{$ref->{expense_accno}} += -$linetotal;

    # deduct inventory
    $form->{amount}{$form->{id}}{$ref->{inventory_accno}} -= -$linetotal;

    # add allocated
    $allocated += -$qty;
    
    last if (($totalqty -= $qty) <= 0);
  }

  $sth->finish;

  $allocated;
  
}



sub reverse_invoice {
  my ($dbh, $form) = @_;
  
  # reverse inventory items
  my $query = qq|SELECT i.id, i.parts_id, i.qty, i.assemblyitem, p.assembly,
		 p.inventory_accno_id
                 FROM invoice i
		 JOIN parts p ON (i.parts_id = p.id)
		 WHERE i.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    if ($ref->{inventory_accno_id} || $ref->{assembly}) {

      # if the invoice item is not an assemblyitem adjust parts onhand
      if (!$ref->{assemblyitem}) {
	# adjust onhand in parts table
	$form->update_balance($dbh,
			      "parts",
			      "onhand",
			      qq|id = $ref->{parts_id}|,
			      $ref->{qty});
      }

      # loop if it is an assembly
      next if ($ref->{assembly});
      
      # de-allocated purchases
      $query = qq|SELECT id, trans_id, allocated
                  FROM invoice
		  WHERE parts_id = $ref->{parts_id}
		  AND allocated > 0
		  ORDER BY trans_id DESC|;
      my $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      while (my $inhref = $sth->fetchrow_hashref(NAME_lc)) {
	$qty = $ref->{qty};
	if (($ref->{qty} - $inhref->{allocated}) > 0) {
	  $qty = $inhref->{allocated};
	}
	
	# update invoice
	$form->update_balance($dbh,
			      "invoice",
			      "allocated",
			      qq|id = $inhref->{id}|,
			      $qty * -1);

        last if (($ref->{qty} -= $qty) <= 0);
      }
      $sth->finish;
    }
  }
  
  $sth->finish;
  
  # delete acc_trans
  $query = qq|DELETE FROM acc_trans
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
 
  # delete invoice entries
  $query = qq|DELETE FROM invoice
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM shipto
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

}



sub delete_invoice {
  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  &reverse_invoice($dbh, $form);
  
  my %audittrail = ( tablename  => 'ar',
                     reference  => $form->{invnumber},
		     formname   => $form->{type},
		     action     => 'deleted',
		     id         => $form->{id} );
 
  $form->audittrail($dbh, "", \%audittrail);
     
  # delete AR record
  my $query = qq|DELETE FROM ar
                 WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete spool files
  $query = qq|SELECT spoolfile FROM status
              WHERE trans_id = $form->{id}
	      AND spoolfile IS NOT NULL|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $spoolfile;
  my @spoolfiles = ();
  
  while (($spoolfile) = $sth->fetchrow_array) {
    push @spoolfiles, $spoolfile;
  }
  $sth->finish;  

  # delete status entries
  $query = qq|DELETE FROM status
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  if ($rc) {
    foreach $spoolfile (@spoolfiles) {
      unlink "$spool/$spoolfile" if $spoolfile;
    }
  }
  
  $rc;
  
}



sub retrieve_invoice {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  if ($form->{id}) {
    # get default accounts and last invoice number
    $query = qq|SELECT (SELECT c.accno FROM chart c
                        WHERE d.inventory_accno_id = c.id) AS inventory_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.income_accno_id = c.id) AS income_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.expense_accno_id = c.id) AS expense_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
                d.curr AS currencies
		FROM defaults d|;
  } else {
    $query = qq|SELECT (SELECT c.accno FROM chart c
                        WHERE d.inventory_accno_id = c.id) AS inventory_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.income_accno_id = c.id) AS income_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.expense_accno_id = c.id) AS expense_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
                d.curr AS currencies, current_date AS transdate
                FROM defaults d|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  
  if ($form->{id}) {
    
    # retrieve invoice
    $query = qq|SELECT a.invnumber, a.ordnumber, a.quonumber,
                a.transdate, a.paid,
                a.shippingpoint, a.shipvia, a.terms, a.notes, a.intnotes,
		a.duedate, a.taxincluded, a.curr AS currency,
		a.employee_id, e.name AS employee, a.till, a.customer_id,
		a.language_code
		FROM ar a
	        LEFT JOIN employee e ON (e.id = a.employee_id)
		WHERE a.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    # get shipto
    $query = qq|SELECT * FROM shipto
                WHERE trans_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    # retrieve individual items
    $query = qq|SELECT (SELECT c.accno FROM chart c
                       WHERE p.inventory_accno_id = c.id)
                       AS inventory_accno,
		       (SELECT c.accno FROM chart c
		       WHERE p.income_accno_id = c.id)
		       AS income_accno,
		       (SELECT c.accno FROM chart c
		       WHERE p.expense_accno_id = c.id)
		       AS expense_accno,
                i.description, i.qty, i.fxsellprice, i.sellprice,
		i.discount, i.parts_id AS id, i.unit, i.deliverydate,
		i.project_id, pr.projectnumber, i.serialnumber,
		p.partnumber, p.assembly, p.bin,
		pg.partsgroup, p.partsgroup_id, p.partnumber AS sku,
		p.listprice, p.lastcost, p.weight,
		t.description AS partsgrouptranslation
		FROM invoice i
	        JOIN parts p ON (i.parts_id = p.id)
	        LEFT JOIN project pr ON (i.project_id = pr.id)
	        LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		LEFT JOIN translation t ON (t.trans_id = p.partsgroup_id AND t.language_code = '$form->{language_code}')
		WHERE i.trans_id = $form->{id}
		AND NOT i.assemblyitem = '1'
		ORDER BY i.id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    # foreign currency
    &exchangerate_defaults($dbh, $form);

    # query for price matrix
    my $pmh = &price_matrix_query($dbh, $form);
    
    # taxes
    $query = qq|SELECT c.accno
		FROM chart c
		JOIN partstax pt ON (pt.chart_id = c.id)
		WHERE pt.parts_id = ?|;
    my $tth = $dbh->prepare($query) || $form->dberror($query);
   
    my $taxrate;
    my $ptref;
    
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

      ($decimalplaces) = ($ref->{fxsellprice} =~ /\.(\d+)/);
      $decimalplaces = length $decimalplaces;
      $decimalplaces = 2 unless $decimalplaces;
    
      $tth->execute($ref->{id});

      $ref->{taxaccounts} = "";
      $taxrate = 0;
      
      while ($ptref = $tth->fetchrow_hashref(NAME_lc)) {
	$ref->{taxaccounts} .= "$ptref->{accno} ";
	$taxrate += $form->{"$ptref->{accno}_rate"};
      }
      $tth->finish;
      chop $ref->{taxaccounts};

      # price matrix
      $ref->{sellprice} = ($ref->{fxsellprice} * $form->{$form->{currency}});
      &price_matrix($pmh, $ref, $form->{transdate}, $decimalplaces, $form, $myconfig, 1);
      $ref->{sellprice} = $ref->{fxsellprice};

      $ref->{partsgroup} = $ref->{partsgrouptranslation} if $ref->{partsgrouptranslation};
      
      push @{ $form->{invoice_details} }, $ref;
    }
    $sth->finish;

  }

  my $rc = $dbh->commit;
  $dbh->disconnect;
  
  $rc;

}


sub get_customer {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my $dateformat = $myconfig->{dateformat};
  if ($myconfig->{dateformat} !~ /^y/) {
    my @a = split /\W/, $form->{transdate};
    $dateformat .= "yy" if (length $a[2] > 2);
  }
  
  if ($form->{transdate} !~ /\W/) {
    $dateformat = 'yyyymmdd';
  }
  
  my $duedate;
  
  if ($myconfig->{dbdriver} eq 'DB2') {
    $duedate = ($form->{transdate}) ? "date('$form->{transdate}') + c.terms DAYS" : "current_date + c.terms DAYS";
  } else {
    $duedate = ($form->{transdate}) ? "to_date('$form->{transdate}', '$dateformat') + c.terms" : "current_date + c.terms";
  }

  $form->{customer_id} *= 1;
  # get customer
  my $query = qq|SELECT c.name AS customer, c.discount, c.creditlimit, c.terms,
                 c.email, c.cc, c.bcc, c.taxincluded,
		 c.address1, c.address2, c.city, c.state,
		 c.zipcode, c.country, c.curr AS currency, c.language_code,
	         $duedate AS duedate, c.notes AS intnotes,
		 b.discount AS tradediscount, b.description AS business,
		 e.name AS employee, e.id AS employee_id
                 FROM customer c
		 LEFT JOIN business b ON (b.id = c.business_id)
		 LEFT JOIN employee e ON (e.id = c.employee_id)
	         WHERE c.id = $form->{customer_id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  if ($form->{id}) {
    map { delete $ref->{$_} } qw(currency taxincluded employee employee_id intnotes);
  }
  
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  # if no currency use defaultcurrency
  $form->{currency} = ($form->{currency}) ? $form->{currency} : $form->{defaultcurrency}; 
  $form->{exchangerate} = 0 if $form->{currency} eq $form->{defaultcurrency};
  if ($form->{transdate} && ($form->{currency} ne $form->{defaultcurrency})) {
    $form->{exchangerate} = $form->get_exchangerate($dbh, $form->{currency}, $form->{transdate}, "buy");
  }
  $form->{forex} = $form->{exchangerate};
  
  # if no employee, default to login
  ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh) unless $form->{employee_id};
  
  $form->{creditremaining} = $form->{creditlimit};
  $query = qq|SELECT SUM(amount - paid)
	      FROM ar
	      WHERE customer_id = $form->{customer_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{creditremaining}) -= $sth->fetchrow_array;

  $sth->finish;
  
  $query = qq|SELECT o.amount,
                (SELECT e.buy FROM exchangerate e
		 WHERE e.curr = o.curr
		 AND e.transdate = o.transdate)
	      FROM oe o
	      WHERE o.customer_id = $form->{customer_id}
	      AND o.quotation = '0'
	      AND o.closed = '0'|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my ($amount, $exch) = $sth->fetchrow_array) {
    $exch = 1 unless $exch;
    $form->{creditremaining} -= $amount * $exch;
  }
  $sth->finish;


  # get shipto if we did not converted an order or invoice
  if (!$form->{shipto}) {
    map { delete $form->{$_} } qw(shiptoname shiptoaddress1 shiptoaddress2 shiptocity shiptostate shiptozipcode shiptocountry shiptocontact shiptophone shiptofax shiptoemail);

    $query = qq|SELECT * FROM shipto
                WHERE trans_id = $form->{customer_id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;
  }
      
  # get taxes we charge for this customer
  $query = qq|SELECT c.accno
              FROM chart c
	      JOIN customertax ct ON (ct.chart_id = c.id)
	      WHERE ct.customer_id = $form->{customer_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my $customertax = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $customertax{$ref->{accno}} = 1;
  }
  $sth->finish;
    
  # get tax rates and description
  $query = qq|SELECT c.accno, c.description, t.rate, t.taxnumber
	      FROM chart c
	      JOIN tax t ON (c.id = t.chart_id)
	      WHERE c.link LIKE '%CT_tax%'
	      ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{taxaccounts} = "";
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    if ($customertax{$ref->{accno}}) {
      $form->{"$ref->{accno}_rate"} = $ref->{rate};
      $form->{"$ref->{accno}_description"} = $ref->{description};
      $form->{"$ref->{accno}_taxnumber"} = $ref->{taxnumber};
      $form->{taxaccounts} .= "$ref->{accno} ";
    }
  }
  $sth->finish;
  chop $form->{taxaccounts};

  # setup last accounts used for this customer
  if (!$form->{id} && $form->{type} !~ /_(order|quotation)/) {
    $query = qq|SELECT c.accno, c.description, c.link, c.category,
                ac.project_id, p.projectnumber, a.department_id,
		d.description AS department
                FROM chart c
		JOIN acc_trans ac ON (ac.chart_id = c.id)
		JOIN ar a ON (a.id = ac.trans_id)
		LEFT JOIN project p ON (ac.project_id = p.id)
		LEFT JOIN department d ON (d.id = a.department_id)
		WHERE a.customer_id = $form->{customer_id}
		AND a.id IN (SELECT max(id) FROM ar
		             WHERE customer_id = $form->{customer_id})|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my $i = 0;
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      $form->{department} = $ref->{department};
      $form->{department_id} = $ref->{department_id};
      
      if ($ref->{link} =~ /_amount/) {
	$i++;
	$form->{"AR_amount_$i"} = "$ref->{accno}--$ref->{description}";
	$form->{"projectnumber_$i"} = "$ref->{projectnumber}--$ref->{project_id}";
      }
      if ($ref->{category} eq 'A') {
	$form->{AR} = $form->{AR_1} = "$ref->{accno}--$ref->{description}";
      }
    }
    $sth->finish;
    $form->{rowcount} = $i if ($i && !$form->{type});
  }
  
  $dbh->disconnect;
  
}



sub retrieve_item {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $i = $form->{rowcount};
  my $null;
  my $var;

  my $where = "WHERE p.obsolete = '0' AND NOT p.income_accno_id IS NULL";

  if ($form->{"partnumber_$i"}) {
    $var = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$var'";
  }
  if ($form->{"description_$i"}) {
    $var = $form->like(lc $form->{"description_$i"});
    if ($form->{language_code}) {
      $where .= " AND lower(t1.description) LIKE '$var'";
    } else {
      $where .= " AND lower(p.description) LIKE '$var'";
    }
  }

  if ($form->{"partsgroup_$i"}) {
    ($null, $var) = split /--/, $form->{"partsgroup_$i"};
    $var *= 1;
    if ($var == 0) {
      # search by partsgroup, this is for the POS
      $where .= qq| AND pg.partsgroup = '$form->{"partsgroup_$i"}'|;
    } else {
      $where .= qq| AND p.partsgroup_id = $var|;
    }
  }

  if ($form->{"description_$i"}) {
    $where .= " ORDER BY 3";
  } else {
    $where .= " ORDER BY 2";
  }
  
  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                 p.listprice, p.lastcost,
                 c1.accno AS inventory_accno,
		 c2.accno AS income_accno,
		 c3.accno AS expense_accno,
		 p.unit, p.assembly, p.bin, p.onhand,
		 pg.partsgroup, p.partsgroup_id, p.partnumber AS sku,
		 p.weight,
		 t1.description AS translation,
		 t2.description AS grouptranslation
                 FROM parts p
		 LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		 LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		 LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		 LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		 LEFT JOIN translation t1 ON (t1.trans_id = p.id AND t1.language_code = '$form->{language_code}')
		 LEFT JOIN translation t2 ON (t2.trans_id = p.partsgroup_id AND t2.language_code = '$form->{language_code}')
	         $where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref;
  my $ptref;

  # setup exchange rates
  &exchangerate_defaults($dbh, $form);
  
  # taxes
  $query = qq|SELECT c.accno
	      FROM chart c
	      JOIN partstax pt ON (c.id = pt.chart_id)
	      WHERE pt.parts_id = ?|;
  my $tth = $dbh->prepare($query) || $form->dberror($query);


  # price matrix
  my $pmh = &price_matrix_query($dbh, $form);

  my $transdate = $form->datetonum($form->{transdate}, $myconfig);
  my $decimalplaces;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    ($decimalplaces) = ($ref->{sellprice} =~ /\.(\d+)/);
    $decimalplaces = length $decimalplaces;
    $decimalplaces = 2 unless $decimalplaces;
    
    # get taxes for part
    $tth->execute($ref->{id});

    $ref->{taxaccounts} = "";
    while ($ptref = $tth->fetchrow_hashref(NAME_lc)) {
      $ref->{taxaccounts} .= "$ptref->{accno} ";
    }
    $tth->finish;
    chop $ref->{taxaccounts};

    # get matrix
    &price_matrix($pmh, $ref, $transdate, $decimalplaces, $form, $myconfig);

    $ref->{description} = $ref->{translation} if $ref->{translation};
    $ref->{partsgroup} = $ref->{grouptranslation} if $ref->{grouptranslation};
    
    push @{ $form->{item_list} }, $ref;

  }
  
  $sth->finish;
  $dbh->disconnect;
  
}


sub price_matrix_query {
  my ($dbh, $form) = @_;
  
  my $query = qq|SELECT p.*, g.pricegroup
              FROM partscustomer p
	      LEFT JOIN pricegroup g ON (g.id = p.pricegroup_id)
	      WHERE p.parts_id = ?
	      AND p.customer_id = $form->{customer_id}
	      
	      UNION

	      SELECT p.*, g.pricegroup 
	      FROM partscustomer p 
	      LEFT JOIN pricegroup g ON (g.id = p.pricegroup_id)
	      JOIN customer c ON (c.pricegroup_id = g.id)
	      WHERE p.parts_id = ?
	      AND c.id = $form->{customer_id}
	      
	      UNION

	      SELECT p.*, '' AS pricegroup
	      FROM partscustomer p
	      WHERE p.customer_id = 0
	      AND p.pricegroup_id = 0
	      AND p.parts_id = ?

	      ORDER BY customer_id DESC, pricegroup_id DESC, pricebreak
	      
	      |;
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  $sth;

}


sub price_matrix {
  my ($pmh, $ref, $transdate, $decimalplaces, $form, $myconfig, $init) = @_;
  
  $pmh->execute($ref->{id}, $ref->{id}, $ref->{id});
 
  $ref->{pricematrix} = "";
  my $customerprice;
  my $pricegroup;
  my $sellprice;
  my $mref;

  while ($mref = $pmh->fetchrow_hashref(NAME_lc)) {

    $customerprice = 0;
    $pricegroup = 0;
    
    # check date
    if ($mref->{validfrom}) {
      next if $transdate < $form->datetonum($mref->{validfrom}, $myconfig);
    }
    if ($mref->{validto}) {
      next if $transdate > $form->datetonum($mref->{validto}, $myconfig);
    }

    # convert price
    $sellprice = $form->round_amount($mref->{sellprice} * $form->{$mref->{curr}}, $decimalplaces);
    
    if ($mref->{customer_id}) {
      $ref->{sellprice} = $sellprice unless $mref->{pricebreak};
      $ref->{pricematrix} .= "$mref->{pricebreak}:$sellprice ";
      $customerprice = 1;
    }

    if ($mref->{pricegroup_id}) {
      if (! $customerprice) {
	$ref->{sellprice} = $sellprice unless $mref->{pricebreak};
	$ref->{pricematrix} .= "$mref->{pricebreak}:$sellprice ";
	$pricegroup = 1;
      }
    }
    
    if (! $customerprice && ! $pricegroup) {
      $ref->{sellprice} = $sellprice unless $mref->{pricebreak};
      $ref->{pricematrix} .= "$mref->{pricebreak}:$sellprice ";
    }

    if ($form->{tradediscount}) {
      $ref->{sellprice} = $form->round_amount($ref->{sellprice} / (1 - $form->{tradediscount}), $decimalplaces);
    }
    
  }
  $pmh->finish;

  if ($ref->{pricematrix} !~ /^0:/) {
    if ($init) {
      $sellprice = $form->round_amount($ref->{sellprice}, $decimalplaces);
    } else {
      $sellprice = $form->round_amount($ref->{sellprice} * (1 - $form->{tradediscount}), $decimalplaces);
    }
    $ref->{pricematrix} = "0:$sellprice ".$ref->{pricematrix};
  }
  chop $ref->{pricematrix};

}


sub exchangerate_defaults {
  my ($dbh, $form) = @_;

  my $var;
  
  # get default currencies
  my $query = qq|SELECT substr(curr,1,3), curr FROM defaults|;
  my $eth = $dbh->prepare($query) || $form->dberror($query);
  $eth->execute;
  ($form->{defaultcurrency}, $form->{currencies}) = $eth->fetchrow_array;
  $eth->finish;

  $query = qq|SELECT buy
              FROM exchangerate
	      WHERE curr = ?
	      AND transdate = ?|;
  my $eth1 = $dbh->prepare($query) || $form->dberror($query);

  $query = qq~SELECT max(transdate || ' ' || buy || ' ' || curr)
              FROM exchangerate
	      WHERE curr = ?~;
  my $eth2 = $dbh->prepare($query) || $form->dberror($query);

  # get exchange rates for transdate or max
  foreach $var (split /:/, substr($form->{currencies},4)) {
    $eth1->execute($var, $form->{transdate});
    ($form->{$var}) = $eth1->fetchrow_array;
    if (! $form->{$var} ) {
      $eth2->execute($var);
      
      ($form->{$var}) = $eth2->fetchrow_array;
      ($null, $form->{$var}) = split / /, $form->{$var};
      $form->{$var} = 1 unless $form->{$var};
      $eth2->finish;
    }
    $eth1->finish;
  }

  $form->{$form->{defaultcurrency}} = 1;

}


1;

