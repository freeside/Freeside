#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2000
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
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
# Inventory Control backend
#
#======================================================================

package IC;


sub get_part {
  my ($self, $myconfig, $form) = @_;

  # connect to db
  my $dbh = $form->dbconnect($myconfig);
  my $i;

  my $query = qq|SELECT p.*,
                 c1.accno AS inventory_accno,
		 c2.accno AS income_accno,
		 c3.accno AS expense_accno,
		 pg.partsgroup
	         FROM parts p
		 LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		 LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		 LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		 LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
                 WHERE p.id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my $ref = $sth->fetchrow_hashref(NAME_lc);

  # copy to $form variables
  map { $form->{$_} = $ref->{$_} } ( keys %{ $ref } );
  
  $sth->finish;
  
  my %oid = ('Pg'	=> 'a.oid',
             'PgPP'	=> 'a.oid',
             'Oracle'	=> 'a.rowid',
	     'DB2'	=> '1=1'
	    );

  # part, service item or labor
  $form->{item} = ($form->{inventory_accno}) ? 'part' : 'service';
  $form->{item} = 'labor' if ! $form->{income_accno};
    
  if ($form->{assembly}) {
    $form->{item} = 'assembly';

    # retrieve assembly items
    $query = qq|SELECT p.id, p.partnumber, p.description,
                p.sellprice, p.weight, a.qty, a.bom, a.adj, p.unit,
		p.lastcost, p.listprice,
		pg.partsgroup, p.assembly, p.partsgroup_id
                FROM parts p
		JOIN assembly a ON (a.parts_id = p.id)
		LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		WHERE a.id = $form->{id}
		ORDER BY $oid{$myconfig->{dbdriver}}|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    
    $form->{assembly_rows} = 0;
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $form->{assembly_rows}++;
      foreach my $key ( keys %{ $ref } ) {
	$form->{"${key}_$form->{assembly_rows}"} = $ref->{$key};
      }
    }
    $sth->finish;

  }

  # setup accno hash for <option checked> {amount} is used in create_links
  $form->{amount}{IC} = $form->{inventory_accno};
  $form->{amount}{IC_income} = $form->{income_accno};
  $form->{amount}{IC_sale} = $form->{income_accno};
  $form->{amount}{IC_expense} = $form->{expense_accno};
  $form->{amount}{IC_cogs} = $form->{expense_accno};
  

  if ($form->{item} =~ /(part|assembly)/) {
    # get makes
    if ($form->{makemodel}) {
      $query = qq|SELECT make, model
                  FROM makemodel
                  WHERE parts_id = $form->{id}|;

      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);
      
      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
	push @{ $form->{makemodels} }, $ref;
      }
      $sth->finish;
    }
  }

  # now get accno for taxes
  $query = qq|SELECT c.accno
              FROM chart c, partstax pt
	      WHERE pt.chart_id = c.id
	      AND pt.parts_id = $form->{id}|;
  
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (($key) = $sth->fetchrow_array) {
    $form->{amount}{$key} = $key;
  }

  $sth->finish;

  # is it an orphan
  $query = qq|SELECT parts_id
              FROM invoice
	      WHERE parts_id = $form->{id}
	    UNION
	      SELECT parts_id
	      FROM orderitems
	      WHERE parts_id = $form->{id}
	    UNION
	      SELECT parts_id
	      FROM assembly
	      WHERE parts_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};
  $sth->finish;


  if ($form->{item} =~ /(part|service)/) {
    # get vendors
    $query = qq|SELECT v.id, v.name, pv.partnumber,
                pv.lastcost, pv.leadtime, pv.curr AS vendorcurr
		FROM partsvendor pv
		JOIN vendor v ON (v.id = pv.vendor_id)
		WHERE pv.parts_id = $form->{id}
		ORDER BY 2|;
    
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{vendormatrix} }, $ref;
    }
    $sth->finish;
  }
 
  # get matrix
  if ($form->{item} ne 'labor') {
    $query = qq|SELECT pc.pricebreak, pc.sellprice AS customerprice,
		pc.curr AS customercurr,
		pc.validfrom, pc.validto,
		c.name, c.id AS cid, g.pricegroup, g.id AS gid
		FROM partscustomer pc
		LEFT JOIN customer c ON (c.id = pc.customer_id)
		LEFT JOIN pricegroup g ON (g.id = pc.pricegroup_id)
		WHERE pc.parts_id = $form->{id}
		ORDER BY c.name, g.pricegroup, pc.pricebreak|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{customermatrix} }, $ref;
    }
    $sth->finish;
  }
 
  $dbh->disconnect;
  
}


sub save {
  my ($self, $myconfig, $form) = @_;

  ($form->{inventory_accno}) = split(/--/, $form->{IC});
  ($form->{expense_accno}) = split(/--/, $form->{IC_expense});
  ($form->{income_accno}) = split(/--/, $form->{IC_income});

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  # save the part
  # make up a unique handle and store in partnumber field
  # then retrieve the record based on the unique handle to get the id
  # replace the partnumber field with the actual variable
  # add records for makemodel

  # if there is a $form->{id} then replace the old entry
  # delete all makemodel entries and add the new ones

  # undo amount formatting
  map { $form->{$_} = $form->parse_amount($myconfig, $form->{$_}) } qw(rop weight listprice sellprice lastcost stock);
  
  $form->{lastcost} = $form->{sellprice} if $form->{item} eq 'labor';
  
  $form->{makemodel} = (($form->{make_1}) || ($form->{model_1})) ? 1 : 0;

  $form->{assembly} = ($form->{item} eq 'assembly') ? 1 : 0;
  map { $form->{$_} *= 1 } qw(alternate obsolete onhand);
  
  my $query;
  my $sth;
  my $i;
  my $null;
  my $vendor_id;
  my $customer_id;
  
  if ($form->{id}) {

    # get old price
    $query = qq|SELECT listprice, sellprice, lastcost, weight
                FROM parts
		WHERE id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my ($listprice, $sellprice, $lastcost, $weight) = $sth->fetchrow_array;
    $sth->finish;

    # if item is part of an assembly adjust all assemblies
    $query = qq|SELECT id, qty, adj
                FROM assembly
		WHERE parts_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my ($id, $qty, $adj) = $sth->fetchrow_array) {
      &update_assembly($dbh, $form, $id, $qty, $adj, $listprice * 1, $sellprice * 1, $lastcost * 1, $weight * 1);
    }
    $sth->finish;

    if ($form->{item} =~ /(part|service)/) {
      # delete partsvendor records
      $query = qq|DELETE FROM partsvendor
		  WHERE parts_id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);
    }
     
    if ($form->{item} !~ /(service|labor)/) {
      # delete makemodel records
      $query = qq|DELETE FROM makemodel
		  WHERE parts_id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);
    }

    if ($form->{item} eq 'assembly') {
      if ($form->{onhand} != 0) {
	&adjust_inventory($dbh, $form, $form->{id}, $form->{onhand} * -1);
      }
      
      if ($form->{orphaned}) {
	# delete assembly records
	$query = qq|DELETE FROM assembly
		    WHERE id = $form->{id}|;
	$dbh->do($query) || $form->dberror($query);
      } else {
        # update BOM, A only
	$query = qq|UPDATE assembly
	            SET bom = ?, adj = ?
		    WHERE id = ?
		    AND parts_id = ?|;
        $sth = $dbh->prepare($query);

	for $i (1 .. $form->{assembly_rows} - 1) {
	  $sth->execute(($form->{"bom_$i"}) ? '1' : '0', ($form->{"adj_$i"}) ? '1' : '0', $form->{id}, $form->{"id_$i"});
	  $sth->finish;
	}
      }

      $form->{onhand} += $form->{stock};
      
    }
    
    # delete tax records
    $query = qq|DELETE FROM partstax
		WHERE parts_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    # delete matrix
    $query = qq|DELETE FROM partscustomer
                WHERE parts_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

  } else {
    my $uid = time;
    $uid .= $form->{login};

    $query = qq|INSERT INTO parts (partnumber)
                VALUES ('$uid')|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT id FROM parts
                WHERE partnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;

    $form->{orphaned} = 1;
    $form->{onhand} = ($form->{stock} * 1) if $form->{item} eq 'assembly';
    
  }

  my $partsgroup_id;
  ($null, $partsgroup_id) = split /--/, $form->{partsgroup};
  $partsgroup_id *= 1;

  $form->{partnumber} = $form->update_defaults($myconfig, "partnumber", $dbh) if ! $form->{partnumber};

  $query = qq|UPDATE parts SET
	      partnumber = |.$dbh->quote($form->{partnumber}).qq|,
	      description = |.$dbh->quote($form->{description}).qq|,
	      makemodel = '$form->{makemodel}',
	      alternate = '$form->{alternate}',
	      assembly = '$form->{assembly}',
	      listprice = $form->{listprice},
	      sellprice = $form->{sellprice},
	      lastcost = $form->{lastcost},
	      weight = $form->{weight},
	      priceupdate = |.$form->dbquote($form->{priceupdate}, SQL_DATE).qq|,
	      unit = |.$dbh->quote($form->{unit}).qq|,
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      rop = $form->{rop},
	      bin = |.$dbh->quote($form->{bin}).qq|,
	      inventory_accno_id = (SELECT id FROM chart
				    WHERE accno = '$form->{inventory_accno}'),
	      income_accno_id = (SELECT id FROM chart
				 WHERE accno = '$form->{income_accno}'),
	      expense_accno_id = (SELECT id FROM chart
				  WHERE accno = '$form->{expense_accno}'),
              obsolete = '$form->{obsolete}',
	      image = '$form->{image}',
	      drawing = '$form->{drawing}',
	      microfiche = '$form->{microfiche}',
	      partsgroup_id = $partsgroup_id
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

 
  # insert makemodel records
  if ($form->{item} =~ /(part|assembly)/) {
    for $i (1 .. $form->{makemodel_rows}) {
      if (($form->{"make_$i"}) || ($form->{"model_$i"})) {
	$query = qq|INSERT INTO makemodel (parts_id, make, model)
		    VALUES ($form->{id},|
		    .$dbh->quote($form->{"make_$i"}).qq|, |
		    .$dbh->quote($form->{"model_$i"}).qq|)|;
	$dbh->do($query) || $form->dberror($query);
      }
    }
  }


  # insert taxes
  foreach $item (split / /, $form->{taxaccounts}) {
    if ($form->{"IC_tax_$item"}) {
      $query = qq|INSERT INTO partstax (parts_id, chart_id)
                  VALUES ($form->{id}, 
		          (SELECT id
			   FROM chart
			   WHERE accno = '$item'))|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # add assembly records
  if ($form->{item} eq 'assembly') {
    
    if ($form->{orphaned}) {
      for $i (1 .. $form->{assembly_rows}) {
	$form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
	
	if ($form->{"qty_$i"} != 0) {
	  map { $form->{"${_}_$i"} *= 1 } qw(bom adj);
	  $query = qq|INSERT INTO assembly (id, parts_id, qty, bom, adj)
		      VALUES ($form->{id}, $form->{"id_$i"},
		      $form->{"qty_$i"}, '$form->{"bom_$i"}',
		      '$form->{"adj_$i"}')|;
	  $dbh->do($query) || $form->dberror($query);
	}
      }
    }
    
    # adjust onhand for the parts
    if ($form->{onhand} != 0) {
      &adjust_inventory($dbh, $form, $form->{id}, $form->{onhand});
    }

    @a = localtime; $a[5] += 1900; $a[4]++;
    my $shippingdate = "$a[5]-$a[4]-$a[3]";
    
    ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh);
    
    # add inventory record
    if ($form->{stock} != 0) {
      $query = qq|INSERT INTO inventory (warehouse_id, parts_id, qty,
		  shippingdate, employee_id) VALUES (
		  0, $form->{id}, $form->{stock}, '$shippingdate',
		  $form->{employee_id})|;
      $dbh->do($query) || $form->dberror($query);
    }

  }


  # add vendors
  if ($form->{item} ne 'assembly') {
    for $i (1 .. $form->{vendor_rows}) {
      if ($form->{"vendor_$i"} && $form->{"lastcost_$i"}) {

        ($null, $vendor_id) = split /--/, $form->{"vendor_$i"};
	
	map { $form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"})} qw(lastcost leadtime);
	
	$query = qq|INSERT INTO partsvendor (vendor_id, parts_id, partnumber,
	            lastcost, leadtime, curr)
		    VALUES ($vendor_id, $form->{id},|
		    .$dbh->quote($form->{"partnumber_$i"}).qq|,
		    $form->{"lastcost_$i"},
		    $form->{"leadtime_$i"}, '$form->{"vendorcurr_$i"}')|;
	$dbh->do($query) || $form->dberror($query);
      }
    }
  }
  
  
  # add pricematrix
  for $i (1 .. $form->{customer_rows}) {

    map { $form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"})} qw(pricebreak customerprice);

    if ($form->{"customerprice_$i"}) {

      ($null, $customer_id) = split /--/, $form->{"customer_$i"};
      $customer_id *= 1;
      
      ($null, $pricegroup_id) = split /--/, $form->{"pricegroup_$i"};
      $pricegroup_id *= 1;
      
      $query = qq|INSERT INTO partscustomer (parts_id, customer_id,
                  pricegroup_id, pricebreak, sellprice, curr,
		  validfrom, validto)
		  VALUES ($form->{id}, $customer_id,
		  $pricegroup_id, $form->{"pricebreak_$i"},
		  $form->{"customerprice_$i"}, '$form->{"customercurr_$i"}',|
		  .$form->dbquote($form->{"validfrom_$i"}, SQL_DATE).qq|, |
		  .$form->dbquote($form->{"validto_$i"}, SQL_DATE).qq|)|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}



sub update_assembly {
  my ($dbh, $form, $id, $qty, $adj, $listprice, $sellprice, $lastcost, $weight) = @_;

  my $formlistprice = $form->{listprice};
  my $formsellprice = $form->{sellprice};
  
  if (!$adj) {
    $formlistprice = $listprice;
    $formsellprice = $sellprice;
  }
  
  my $query = qq|SELECT id, qty, adj
                 FROM assembly
	         WHERE parts_id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{$id} = 1;
  
  while (my ($pid, $aqty, $aadj) = $sth->fetchrow_array) {
    &update_assembly($dbh, $form, $pid, $aqty * $qty, $aadj, $listprice, $sellprice, $lastcost, $weight) if !$form->{$pid};
  }
  $sth->finish;

  $query = qq|UPDATE parts
              SET listprice = listprice +
	          $qty * ($formlistprice - $listprice),
	          sellprice = sellprice +
	          $qty * ($formsellprice - $sellprice),
		  lastcost = lastcost +
		  $qty * ($form->{lastcost} - $lastcost),
                  weight = weight +
		  $qty * ($form->{weight} - $weight)
	      WHERE id = $id|;
  $dbh->do($query) || $form->dberror($query);

  delete $form->{$id};
  
}



sub retrieve_assemblies {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where = '1 = 1';
  
  if ($form->{partnumber}) {
    my $partnumber = $form->like(lc $form->{partnumber});
    $where .= " AND lower(p.partnumber) LIKE '$partnumber'";
  }
  
  if ($form->{description}) {
    my $description = $form->like(lc $form->{description});
    $where .= " AND lower(p.description) LIKE '$description'";
  }
  $where .= " AND NOT p.obsolete = '1'";

  my %ordinal = ( 'partnumber' => 2,
                  'description' => 3,
		  'bin' => 4
		);

  my @a = qw(partnumber description bin);
  my $sortorder = $form->sort_order(\@a, \%ordinal);
  
  
  # retrieve assembly items
  my $query = qq|SELECT p.id, p.partnumber, p.description,
                 p.bin, p.onhand, p.rop,
		   (SELECT sum(p2.inventory_accno_id)
		    FROM parts p2, assembly a
		    WHERE p2.id = a.parts_id
		    AND a.id = p.id) AS inventory
                 FROM parts p
 		 WHERE $where
		 AND assembly = '1'
		 ORDER BY $sortorder|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my $inh;
  if ($form->{checkinventory}) {
    $query = qq|SELECT p.id, p.onhand, a.qty FROM parts p
                JOIN assembly a ON (a.parts_id = p.id)
                WHERE a.id = ?|;
    $inh = $dbh->prepare($query) || $form->dberror($query);
  }
  
  my $onhand = ();
  my $ref;
  my $aref;
  my $stock;
  my $howmany;
  my $ok;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    if ($ref->{inventory}) {
      $ok = 1;
      if ($form->{checkinventory}) {
	$inh->execute($ref->{id}) || $form->dberror($query);;
	$ok = 0;
	while ($aref = $inh->fetchrow_hashref(NAME_lc)) {
	  $onhand{$aref->{id}} = (exists $onhand{$aref->{id}}) ? $onhand{$aref->{id}} : $aref->{onhand};
	  
	  if ($aref->{onhand} >= $aref->{qty}) {
	    
	    $howmany = ($aref->{qty}) ? $aref->{onhand}/$aref->{qty} : 1;
	    if ($stock) {
	      $stock = ($stock > $howmany) ? $howmany : $stock;
	    } else {
	      $stock = $howmany;
	    }
	    $ok = 1;

	    $onhand{$aref->{id}} -= ($aref->{qty} * $stock);

	  } else {
	    $ok = 0;
	    last;
	  }
	}
	$inh->finish;
	$ref->{stock} = (($ref->{rop} - $ref->{qty}) > $stock) ? int $stock : $ref->{rop};
      }
      push @{ $form->{assembly_items} }, $ref if $ok;
    }
  }
  $sth->finish;

  $dbh->disconnect;
  
}


sub restock_assemblies {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
   
  @a = localtime; $a[5] += 1900; $a[4]++;
  my $shippingdate = "$a[5]-$a[4]-$a[3]";
  
  ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh);
  
  for my $i (1 .. $form->{rowcount}) {

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"qty_$i"} != 0) {
      &adjust_inventory($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"});
    }
 
    # add inventory record
    if ($form->{"qty_$i"} != 0) {
      $query = qq|INSERT INTO inventory (warehouse_id, parts_id, qty,
		  shippingdate, employee_id) VALUES (
		  0, $form->{"id_$i"}, $form->{"qty_$i"}, '$shippingdate',
		  $form->{employee_id})|;
      $dbh->do($query) || $form->dberror($query);
    }

  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub adjust_inventory {
  my ($dbh, $form, $id, $qty) = @_;

  my $query = qq|SELECT p.id, p.inventory_accno_id, p.assembly, a.qty
		 FROM parts p, assembly a
		 WHERE a.parts_id = p.id
		 AND a.id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    my $allocate = $qty * $ref->{qty};
    
    # is it a service item then loop
    if (($ref->{inventory_accno_id} *= 1) == 0) {
      next unless $ref->{assembly};              # assembly
    }
    
    # adjust parts onhand
    $form->update_balance($dbh,
			  "parts",
			  "onhand",
			  qq|id = $ref->{id}|,
			  $allocate * -1);
  }

  $sth->finish;

  # update assembly
  $form->update_balance($dbh,
			"parts",
			"onhand",
			qq|id = $id|,
			$qty);

}


sub delete {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM parts
 	         WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM partstax
	      WHERE parts_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);


  if ($form->{item} ne 'assembly') {
    $query = qq|DELETE FROM partsvendor
		WHERE parts_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  # check if it is a part, assembly or service
  if ($form->{item} ne 'service') {
    $query = qq|DELETE FROM makemodel
		WHERE parts_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  if ($form->{item} eq 'assembly') {
    # delete inventory
    $query = qq|DELETE FROM inventory
                WHERE parts_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
    
    $query = qq|DELETE FROM assembly
		WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }
  
  if ($form->{item} eq 'alternate') {
    $query = qq|DELETE FROM alternate
		WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }
  
  $query = qq|DELETE FROM partscustomer
	      WHERE parts_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  $query = qq|DELETE FROM translation
	      WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}


sub assembly_item {
  my ($self, $myconfig, $form) = @_;

  my $i = $form->{assembly_rows};
  my $var;
  my $null;
  my $where = "p.obsolete = '0'";

  if ($form->{"partnumber_$i"}) {
    $var = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$var'";
  }
  if ($form->{"description_$i"}) {
    $var = $form->like(lc $form->{"description_$i"});
    $where .= " AND lower(p.description) LIKE '$var'";
  }
  if ($form->{"partsgroup_$i"}) {
    ($null, $var) = split /--/, $form->{"partsgroup_$i"};
    $where .= qq| AND p.partsgroup_id = $var|;
  }

  if ($form->{id}) {
    $where .= " AND p.id != $form->{id}";
  }

  if ($partnumber) {
    $where .= " ORDER BY p.partnumber";
  } else {
    $where .= " ORDER BY p.description";
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                 p.weight, p.onhand, p.unit, p.lastcost,
		 pg.partsgroup, p.partsgroup_id
		 FROM parts p
		 LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		 WHERE $where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{item_list} }, $ref;
  }
  
  $sth->finish;
  $dbh->disconnect;
  
}


sub all_parts {
  my ($self, $myconfig, $form) = @_;

  my $where = '1 = 1';
  my $null;
  my $var;
  my $ref;
  my $item;
  
  foreach $item (qw(partnumber drawing microfiche)) {
    if ($form->{$item}) {
      $var = $form->like(lc $form->{$item});
      $where .= " AND lower(p.$item) LIKE '$var'";
    }
  }
  # special case for description
  if ($form->{description}) {
    unless ($form->{bought} || $form->{sold} || $form->{onorder} || $form->{ordered} || $form->{rfq} || $form->{quoted}) {
      $var = $form->like(lc $form->{description});
      $where .= " AND lower(p.description) LIKE '$var'";
    }
  }
  
  # assembly components
  my $assemblyflds;
  if ($form->{searchitems} eq 'component') {
    $assemblyflds = qq|, p1.partnumber AS assemblypartnumber, a.id AS assembly_id|;
  }

  # special case for serialnumber
  if ($form->{l_serialnumber}) {
    if ($form->{serialnumber}) {
      $var = $form->like(lc $form->{serialnumber});
      $where .= " AND lower(i.serialnumber) LIKE '$var'";
    }
  }

  if ($form->{warehouse} || $form->{l_warehouse}) {
    $form->{l_warehouse} = 1;
  }
  
  if ($form->{searchitems} eq 'part') {
    $where .= " AND p.inventory_accno_id > 0 AND p.assembly = '0' AND p.income_accno_id > 0";
  }
  if ($form->{searchitems} eq 'assembly') {
    $form->{bought} = "";
    $where .= " AND p.assembly = '1'";
  }
  if ($form->{searchitems} eq 'service') {
    $where .= " AND p.inventory_accno_id IS NULL AND p.assembly = '0'";
  }
  if ($form->{searchitems} eq 'labor') {
    $where .= " AND p.inventory_accno_id > 0 AND p.income_accno_id IS NULL";
  }

  # items which were never bought, sold or on an order
  if ($form->{itemstatus} eq 'orphaned') {
    $where .= " AND p.onhand = 0
                AND p.id NOT IN (SELECT p.id FROM parts p, invoice i
				 WHERE p.id = i.parts_id)
		AND p.id NOT IN (SELECT p.id FROM parts p, assembly a
				 WHERE p.id = a.parts_id)
                AND p.id NOT IN (SELECT p.id FROM parts p, orderitems o
				 WHERE p.id = o.parts_id)";
  }
  
  if ($form->{itemstatus} eq 'active') {
    $where .= " AND p.obsolete = '0'";
  }
  if ($form->{itemstatus} eq 'obsolete') {
    $where .= " AND p.obsolete = '1'";
  }
  if ($form->{itemstatus} eq 'onhand') {
    $where .= " AND p.onhand > 0";
  }
  if ($form->{itemstatus} eq 'short') {
    $where .= " AND p.onhand < p.rop";
  }

  my $makemodelflds = qq|, '', ''|;;
  my $makemodeljoin;
  
  if ($form->{make} || $form->{l_make} || $form->{model} || $form->{l_model}) {
    $makemodelflds = qq|, m.make, m.model|;
    $makemodeljoin = qq|LEFT JOIN makemodel m ON (m.parts_id = p.id)|;
    
    if ($form->{make}) {
      $var = $form->like(lc $form->{make});
      $where .= " AND lower(m.make) LIKE '$var'";
    }
    if ($form->{model}) {
      $var = $form->like(lc $form->{model});
      $where .= " AND lower(m.model) LIKE '$var'";
    }
  }
  if ($form->{partsgroup}) {
    ($null, $var) = split /--/, $form->{partsgroup};
    $where .= qq| AND p.partsgroup_id = $var|;
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my %ordinal = ( 'partnumber' => 2,
                  'description' => 3,
		  'bin' => 6,
		  'priceupdate' => 12,
		  'drawing' => 14,
		  'microfiche' => 15,
		  'partsgroup' => 17,
		  'make' => 19,
		  'model' => 20,
		  'assemblypartnumber' => 21
		);
  
  my @a = qw(partnumber description);
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  my $query = qq|SELECT curr FROM defaults|;
  my ($curr) = $dbh->selectrow_array($query);
  $curr =~ s/:.*//;
  
  my $flds = qq|p.id, p.partnumber, p.description, p.onhand, p.unit,
                p.bin, p.sellprice, p.listprice, p.lastcost, p.rop,
		p.weight, p.priceupdate, p.image, p.drawing, p.microfiche,
		p.assembly, pg.partsgroup, '$curr' AS curr
		$makemodelflds $assemblyflds
		|;

  $query = qq|SELECT $flds
	      FROM parts p
	      LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
	      $makemodeljoin
  	      WHERE $where
	      ORDER BY $sortorder|;

  # redo query for components report
  if ($form->{searchitems} eq 'component') {
    
    $query = qq|SELECT $flds
		FROM assembly a
		JOIN parts p ON (a.parts_id = p.id)
		JOIN parts p1 ON (a.id = p1.id)
		LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		$makemodeljoin
  	        WHERE $where
	        ORDER BY $sortorder|;
		
  }


  # rebuild query for bought and sold items
  if ($form->{bought} || $form->{sold} || $form->{onorder} || $form->{ordered} || $form->{rfq} || $form->{quoted}) {

    $form->sort_order();
    my @a = qw(partnumber description employee);
    
    push @a, qw(invnumber serialnumber) if ($form->{bought} || $form->{sold});
    push @a, "ordnumber" if ($form->{onorder} || $form->{ordered});
    push @a, "quonumber" if ($form->{rfq} || $form->{quoted});

    %ordinal = ( 'partnumber' => 2,
                 'description' => 3,
		 'serialnumber' => 4,
		 'bin' => 7,
		 'priceupdate' => 13,
		 'partsgroup' => 18,
		 'invnumber' => 19,
		 'ordnumber' => 20,
		 'quonumber' => 21,
		 'name' => 23,
		 'employee' => 24,
		 'make' => 27,
		 'model' => 28
	       );
    
    $sortorder = $form->sort_order(\@a, \%ordinal);

    my $union = "";
    $query = "";
  
    if ($form->{bought} || $form->{sold}) {
      
      my $invwhere = "$where";
      my $transdate = ($form->{method} eq 'accrual') ? "transdate" : "datepaid";
      
      $invwhere .= " AND i.assemblyitem = '0'";
      $invwhere .= " AND a.$transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $invwhere .= " AND a.$transdate <= '$form->{transdateto}'" if $form->{transdateto};

      if ($form->{description}) {
	$var = $form->like(lc $form->{description});
	$invwhere .= " AND lower(i.description) LIKE '$var'";
      }

      if ($form->{open} || $form->{closed}) {
	if ($form->{open} && $form->{closed}) {
	  if ($form->{method} eq 'cash') {
	    $invwhere .= " AND a.amount = a.paid";
	  }
	} else {
	  if ($form->{open}) {
	    if ($form->{method} eq 'cash') {
	      $invwhere .= " AND a.id = 0";
	    } else {
	      $invwhere .= " AND NOT a.amount = a.paid";
	    }
	  } else {
	    $invwhere .= " AND a.amount = a.paid";
	  }
	}
      } else {
	$invwhere .= " AND a.id = 0";
      }

      my $flds = qq|p.id, p.partnumber, i.description, i.serialnumber,
                    i.qty AS onhand, i.unit, p.bin, i.sellprice,
		    p.listprice, p.lastcost, p.rop, p.weight,
		    p.priceupdate, p.image, p.drawing, p.microfiche,
		    p.assembly,
		    pg.partsgroup, a.invnumber, a.ordnumber, a.quonumber,
		    i.trans_id, ct.name, e.name AS employee, a.curr, a.till
		    $makemodelfld|;


      if ($form->{bought}) {
	$query = qq|
	            SELECT $flds, 'ir' AS module, '' AS type,
		    (SELECT sell FROM exchangerate ex
		     WHERE ex.curr = a.curr
		     AND ex.transdate = a.$transdate) AS exchangerate,
		     i.discount
		    FROM invoice i
		    JOIN parts p ON (p.id = i.parts_id)
		    JOIN ap a ON (a.id = i.trans_id)
		    JOIN vendor ct ON (a.vendor_id = ct.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    LEFT JOIN employee e ON (a.employee_id = e.id)
		    $makemodeljoin
		    WHERE $invwhere|;
	$union = "
	          UNION";
      }

      if ($form->{sold}) {
	$query .= qq|$union
                     SELECT $flds, 'is' AS module, '' AS type,
		    (SELECT buy FROM exchangerate ex
		     WHERE ex.curr = a.curr
		     AND ex.transdate = a.$transdate) AS exchangerate,
		     i.discount
		     FROM invoice i
		     JOIN parts p ON (p.id = i.parts_id)
		     JOIN ar a ON (a.id = i.trans_id)
		     JOIN customer ct ON (a.customer_id = ct.id)
		     LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		     LEFT JOIN employee e ON (a.employee_id = e.id)
		     $makemodeljoin
		     WHERE $invwhere|;
	$union = "
	          UNION";
      }
    }

    if ($form->{onorder} || $form->{ordered}) {
      my $ordwhere = "$where
		     AND a.quotation = '0'";
      $ordwhere .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $ordwhere .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};

      if ($form->{description}) {
	$var = $form->like(lc $form->{description});
	$ordwhere .= " AND lower(i.description) LIKE '$var'";
      }
      
      if ($form->{open} || $form->{closed}) {
	unless ($form->{open} && $form->{closed}) {
	  $ordwhere .= " AND a.closed = '0'" if $form->{open};
	  $ordwhere .= " AND a.closed = '1'" if $form->{closed};
	}
      } else {
	$ordwhere .= " AND a.id = 0";
      }

      $flds = qq|p.id, p.partnumber, i.description, '' AS serialnumber,
                 i.qty AS onhand, i.unit, p.bin, i.sellprice,
	         p.listprice, p.lastcost, p.rop, p.weight,
		 p.priceupdate, p.image, p.drawing, p.microfiche,
		 p.assembly,
		 pg.partsgroup, '' AS invnumber, a.ordnumber, a.quonumber,
		 i.trans_id, ct.name,e.name AS employee, a.curr, '0' AS till
		 $makemodelfld|;

      if ($form->{ordered}) {
	$query .= qq|$union
                     SELECT $flds, 'oe' AS module, 'sales_order' AS type,
		    (SELECT buy FROM exchangerate ex
		     WHERE ex.curr = a.curr
		     AND ex.transdate = a.transdate) AS exchangerate,
		     i.discount
		     FROM orderitems i
		     JOIN parts p ON (i.parts_id = p.id)
		     JOIN oe a ON (i.trans_id = a.id)
		     JOIN customer ct ON (a.customer_id = ct.id)
		     LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		     LEFT JOIN employee e ON (a.employee_id = e.id)
		     $makemodeljoin
		     WHERE $ordwhere
		     AND a.customer_id > 0|;
	$union = "
	          UNION";
      }
      
      if ($form->{onorder}) {
        $flds = qq|p.id, p.partnumber, i.description, '' AS serialnumber,
                   i.qty AS onhand, i.unit, p.bin, i.sellprice,
		   p.listprice, p.lastcost, p.rop, p.weight,
		   p.priceupdate, p.image, p.drawing, p.microfiche,
		   p.assembly,
		   pg.partsgroup, '' AS invnumber, a.ordnumber, a.quonumber,
		   i.trans_id, ct.name,e.name AS employee, a.curr, '0' AS till
		   $makemodelfld|;

	$query .= qq|$union
	            SELECT $flds, 'oe' AS module, 'purchase_order' AS type,
		    (SELECT sell FROM exchangerate ex
		     WHERE ex.curr = a.curr
		     AND ex.transdate = a.transdate) AS exchangerate,
		     i.discount
		    FROM orderitems i
		    JOIN parts p ON (i.parts_id = p.id)
		    JOIN oe a ON (i.trans_id = a.id)
		    JOIN vendor ct ON (a.vendor_id = ct.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    LEFT JOIN employee e ON (a.employee_id = e.id)
		    $makemodeljoin
		    WHERE $ordwhere
		    AND a.vendor_id > 0|;
      }
    
    }
      
    if ($form->{rfq} || $form->{quoted}) {
      my $quowhere = "$where
		     AND a.quotation = '1'";
      $quowhere .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $quowhere .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};

      if ($form->{description}) {
	$var = $form->like(lc $form->{description});
	$quowhere .= " AND lower(i.description) LIKE '$var'";
      }
      
      if ($form->{open} || $form->{closed}) {
	unless ($form->{open} && $form->{closed}) {
	  $ordwhere .= " AND a.closed = '0'" if $form->{open};
	  $ordwhere .= " AND a.closed = '1'" if $form->{closed};
	}
      } else {
	$ordwhere .= " AND a.id = 0";
      }


      $flds = qq|p.id, p.partnumber, i.description, '' AS serialnumber,
                 i.qty AS onhand, i.unit, p.bin, i.sellprice,
	         p.listprice, p.lastcost, p.rop, p.weight,
		 p.priceupdate, p.image, p.drawing, p.microfiche,
		 p.assembly,
		 pg.partsgroup, '' AS invnumber, a.ordnumber, a.quonumber,
		 i.trans_id, ct.name, e.name AS employee, a.curr, '0' AS till
		 $makemodelfld|;

      if ($form->{quoted}) {
	$query .= qq|$union
                     SELECT $flds, 'oe' AS module, 'sales_quotation' AS type,
		    (SELECT buy FROM exchangerate ex
		     WHERE ex.curr = a.curr
		     AND ex.transdate = a.transdate) AS exchangerate,
		     i.discount
		     FROM orderitems i
		     JOIN parts p ON (i.parts_id = p.id)
		     JOIN oe a ON (i.trans_id = a.id)
		     JOIN customer ct ON (a.customer_id = ct.id)
		     LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		     LEFT JOIN employee e ON (a.employee_id = e.id)
		     $makemodeljoin
		     WHERE $quowhere
		     AND a.customer_id > 0|;
	$union = "
	          UNION";
      }
      
      if ($form->{rfq}) {
        $flds = qq|p.id, p.partnumber, i.description, '' AS serialnumber,
                   i.qty AS onhand, i.unit, p.bin, i.sellprice,
		   p.listprice, p.lastcost, p.rop, p.weight,
		   p.priceupdate, p.image, p.drawing, p.microfiche,
		   p.assembly,
		   pg.partsgroup, '' AS invnumber, a.ordnumber, a.quonumber,
		   i.trans_id, ct.name, e.name AS employee, a.curr, '0' AS till
		   $makemodelfld|;

	$query .= qq|$union
	            SELECT $flds, 'oe' AS module, 'request_quotation' AS type,
		    (SELECT sell FROM exchangerate ex
		     WHERE ex.curr = a.curr
		     AND ex.transdate = a.transdate) AS exchangerate,
		     i.discount
		    FROM orderitems i
		    JOIN parts p ON (i.parts_id = p.id)
		    JOIN oe a ON (i.trans_id = a.id)
		    JOIN vendor ct ON (a.vendor_id = ct.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    LEFT JOIN employee e ON (a.employee_id = e.id)
		    $makemodeljoin
		    WHERE $quowhere
		    AND a.vendor_id > 0|;
      }

    }

    $query .= qq|
		 ORDER BY $sortorder|;

  }

  
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{parts} }, $ref;
  }
  $sth->finish;

  my @a = ();
  
  # include individual items for assembly
  if ($form->{searchitems} eq 'assembly' && $form->{bom}) {

    if ($form->{sold} || $form->{ordered} || $form->{quoted}) {
      $flds = qq|p.id, p.partnumber, p.description, a.qty AS onhand, p.unit,
                 p.bin, p.sellprice, p.listprice, p.lastcost, p.rop,
 		 p.weight, p.priceupdate, p.image, p.drawing, p.microfiche,
		 p.assembly, pg.partsgroup
		 $makemodelflds $assemblyflds
		 |;
    } else {
      # replace p.onhand with a.qty AS onhand
      $flds =~ s/p.onhand/a.qty AS onhand/;
    }
	
    while ($item = shift @{ $form->{parts} }) {
      push @a, $item;
      $flds =~ s/a\.qty.*AS onhand/a\.qty * $item->{onhand} AS onhand/;
      push @a, &include_assembly($dbh, $form, $item->{id}, $flds, $makemodeljoin);
      push @a, {id => $item->{id}};
    }

    # copy assemblies to $form->{parts}
    @{ $form->{parts} } = @a;
    
  }
    
  
  @a = ();
  if ($form->{l_warehouse} || $form->{l_warehouse}) {
    
    if ($form->{warehouse}) {
      ($null, $var) = split /--/, $form->{warehouse};
      $var *= 1;
      $query = qq|SELECT SUM(qty) AS onhand, '$null' AS description
                  FROM inventory
		  WHERE warehouse_id = $var
                  AND parts_id = ?|;
    } else {

      $query = qq|SELECT SUM(i.qty) AS onhand, w.description AS warehouse
                  FROM inventory i
		  JOIN warehouse w ON (w.id = i.warehouse_id)
                  WHERE i.parts_id = ?
		  GROUP BY w.description|;
    }

    $sth = $dbh->prepare($query) || $form->dberror($query);

    foreach $item (@{ $form->{parts} }) {

      if ($item->{onhand} <= 0 && ! $form->{warehouse}) {
	push @a, $item;
	next;
      }

      $sth->execute($item->{id}) || $form->dberror($query);
      
      if ($form->{warehouse}) {
	
	$ref = $sth->fetchrow_hashref(NAME_lc);
	if ($ref->{onhand} > 0) {
	  $item->{onhand} = $ref->{onhand};
	  push @a, $item;
	}

      } else {

	push @a, $item;
	
	while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
          if ($ref->{onhand} > 0) {
	    push @a, $ref;
	  }
	}
      }
      
      $sth->finish;
    }

    @{ $form->{parts} } = @a;

  }

  $dbh->disconnect;

}


sub include_assembly {
  my ($dbh, $form, $id, $flds, $makemodeljoin) = @_;
  
  $form->{stagger}++;
  if ($form->{stagger} > $form->{pncol}) {
    $form->{pncol} = $form->{stagger};
  }
 
  $form->{$id} = 1;
  
  my @a = ();
  my $query = qq|SELECT $flds
		 FROM parts p
		 JOIN assembly a ON (a.parts_id = p.id)
		 LEFT JOIN partsgroup pg ON (pg.id = p.id)
		 $makemodeljoin
		 WHERE a.id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{assemblyitem} = 1;
    $ref->{stagger} = $form->{stagger};
    push @a, $ref;
    if ($ref->{assembly} && !$form->{$ref->{id}}) {
      push @a, &include_assembly($dbh, $form, $ref->{id}, $flds, $makemodeljoin);
      if ($form->{stagger} > $form->{pncol}) {
	$form->{pncol} = $form->{stagger};
      }
    }
  }
  $sth->finish;

  $form->{$id} = 0;
  $form->{stagger}--;

  @a;

}


sub create_links {
  my ($self, $module, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my $ref;

  my $query = qq|SELECT accno, description, link
                 FROM chart
		 WHERE link LIKE '%$module%'
		 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split /:/, $ref->{link}) {
      if ($key =~ /$module/) {
	push @{ $form->{"${module}_links"}{$key} }, { accno => $ref->{accno},
				      description => $ref->{description} };
      }
    }
  }
  $sth->finish;

  if ($form->{item} ne 'assembly') {
    $query = qq|SELECT count(*) FROM vendor|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    my ($count) = $sth->fetchrow_array;
    $sth->finish;

    if ($count < $myconfig->{vclimit}) {
      $query = qq|SELECT id, name
		  FROM vendor
		  ORDER BY name|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
	push @{ $form->{all_vendor} }, $ref;
      }
      $sth->finish;
    }
  }


  # pricegroups, customers
  $query = qq|SELECT count(*) FROM customer|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my ($count) = $sth->fetchrow_array;
  $sth->finish;

  if ($count < $myconfig->{vclimit}) {
    $query = qq|SELECT id, name
		FROM customer
		ORDER BY name|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{all_customer} }, $ref;
    }
    $sth->finish;
  }

  $query = qq|SELECT id, pricegroup
              FROM pricegroup
	      ORDER BY pricegroup|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_pricegroup} }, $ref;
  }
  $sth->finish;


  if ($form->{id}) {
    $query = qq|SELECT weightunit, curr AS currencies
                FROM defaults|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{weightunit}, $form->{currencies}) = $sth->fetchrow_array;
    $sth->finish;

  } else {
    $query = qq|SELECT weightunit, current_date, curr AS currencies
                FROM defaults|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{weightunit}, $form->{priceupdate}, $form->{currencies}) = $sth->fetchrow_array;
    $sth->finish;
  }
  
  $dbh->disconnect;

}


sub get_warehouses {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT id, description
                 FROM warehouse|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_warehouses} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}

1;

