#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
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
             'Oracle'	=> 'a.rowid'
	    );
  
  
  # part or service item
  $form->{item} = ($form->{inventory_accno}) ? 'part' : 'service';
  if ($form->{assembly}) {
    $form->{item} = 'assembly';

    # retrieve assembly items
    $query = qq|SELECT p.id, p.partnumber, p.description,
                p.sellprice, p.weight, a.qty, a.bom, p.unit,
		pg.partsgroup
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
  

  if ($form->{item} ne 'service') {
    # get makes
    if ($form->{makemodel}) {
      $query = qq|SELECT name FROM makemodel
                  WHERE parts_id = $form->{id}|;

      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);
      
      my $i = 1;
      while (($form->{"make_$i"}, $form->{"model_$i"}) = split(/:/, $sth->fetchrow_array)) {
	$i++;
      }
      $sth->finish;
      $form->{makemodel_rows} = $i - 1;

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

  # escape '
  map { $form->{$_} =~ s/'/''/g } qw(partnumber description notes unit bin);

  # undo amount formatting
  map { $form->{$_} = $form->parse_amount($myconfig, $form->{$_}) } qw(rop weight listprice sellprice lastcost stock);
  
  # set date to NULL if nothing entered
  $form->{priceupdate} = ($form->{priceupdate}) ? qq|'$form->{priceupdate}'| : "NULL";
  
  $form->{makemodel} = (($form->{make_1}) || ($form->{model_1})) ? 1 : 0;

  $form->{alternate} = 0;
  $form->{assembly} = ($form->{item} eq 'assembly') ? 1 : 0;
  $form->{obsolete} *= 1;
  $form->{onhand} *= 1;

  my ($query, $sth);
  
  if ($form->{id}) {

    # get old price
    $query = qq|SELECT sellprice, weight
                FROM parts
		WHERE id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my ($sellprice, $weight) = $sth->fetchrow_array;
    $sth->finish;

    # if item is part of an assembly adjust all assemblies
    $query = qq|SELECT id, qty
                FROM assembly
		WHERE parts_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my ($id, $qty) = $sth->fetchrow_array) {
      &update_assembly($dbh, $form, $id, $qty * 1, $sellprice * 1, $weight * 1);
    }
    $sth->finish;


    if ($form->{item} ne 'service') {
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
        # update BOM only
	$query = qq|UPDATE assembly
	            SET bom = ?
		    WHERE id = ?
		    AND parts_id = ?|;
	$sth = $dbh->prepare($query);
	
	for $i (1 .. $form->{assembly_rows} - 1) {
          $sth->execute(($form->{"bom_$i"}) ? '1' : '0', $form->{id}, $form->{"id_$i"}) || $form->dberror($query);
	}
	$sth->finish;
      }
      
      $form->{onhand} += $form->{stock};
    }
    
    # delete tax records
    $query = qq|DELETE FROM partstax
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
  
  my $partsgroup_id = 0;
  if ($form->{partsgroup}) {
    my $partsgroup = lc $form->{partsgroup};
    $query = qq|SELECT DISTINCT id FROM partsgroup
		WHERE lower(partsgroup) = '$partsgroup'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($partsgroup_id) = $sth->fetchrow_array;
    $sth->finish;

    if (!$partsgroup_id) {
      $query = qq|INSERT INTO partsgroup (partsgroup)
                  VALUES ('$form->{partsgroup}')|;
      $dbh->do($query) || $form->dberror($query);

      $query = qq|SELECT id FROM partsgroup
                  WHERE partsgroup = '$form->{partsgroup}'|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      ($partsgroup_id) = $sth->fetchrow_array;
      $sth->finish;
    }
  }
  
  
  $query = qq|UPDATE parts SET 
	      partnumber = '$form->{partnumber}',
	      description = '$form->{description}',
	      makemodel = '$form->{makemodel}',
	      alternate = '$form->{alternate}',
	      assembly = '$form->{assembly}',
	      listprice = $form->{listprice},
	      sellprice = $form->{sellprice},
	      lastcost = $form->{lastcost},
	      weight = $form->{weight},
	      priceupdate = $form->{priceupdate},
	      unit = '$form->{unit}',
	      notes = '$form->{notes}',
	      rop = $form->{rop},
	      bin = '$form->{bin}',
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
  unless ($form->{item} eq 'service') {
    for my $i (1 .. $form->{makemodel_rows}) {
      # put make and model together
      if (($form->{"make_$i"}) || ($form->{"model_$i"})) {
	map { $form->{"${_}_$i"} =~ s/'/''/g } qw(make model);
	
	$query = qq|INSERT INTO makemodel (parts_id, name)
		    VALUES ($form->{id},
		    '$form->{"make_$i"}:$form->{"model_$i"}')|;
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
      for my $i (1 .. $form->{assembly_rows}) {
	$form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
	
	if ($form->{"qty_$i"} != 0) {
	  $form->{"bom_$i"} *= 1;
	  $query = qq|INSERT INTO assembly (id, parts_id, qty, bom)
		      VALUES ($form->{id}, $form->{"id_$i"},
		      $form->{"qty_$i"}, '$form->{"bom_$i"}')|;
	  $dbh->do($query) || $form->dberror($query);
	}
      }
    }
    
    # adjust onhand for the assembly
    if ($form->{onhand} != 0) {
      &adjust_inventory($dbh, $form, $form->{id}, $form->{onhand});
    }
    
  }

 
  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}



sub update_assembly {
  my ($dbh, $form, $id, $qty, $sellprice, $weight) = @_;

  my $query = qq|SELECT id, qty
                 FROM assembly
		 WHERE parts_id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my ($pid, $aqty) = $sth->fetchrow_array) {
    &update_assembly($dbh, $form, $pid, $aqty * $qty, $sellprice, $weight);
  }
  $sth->finish;

  $query = qq|UPDATE parts
              SET sellprice = sellprice +
	          $qty * ($form->{sellprice} - $sellprice),
                  weight = weight +
		  $qty * ($form->{weight} - $weight)
	      WHERE id = $id|;
  $dbh->do($query) || $form->dberror($query);

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

  # retrieve assembly items
  my $query = qq|SELECT p.id, p.partnumber, p.description,
                 p.bin, p.onhand, p.rop,
		   (SELECT sum(p2.inventory_accno_id)
		    FROM parts p2, assembly a
		    WHERE p2.id = a.parts_id
		    AND a.id = p.id) AS inventory
                 FROM parts p
 		 WHERE $where
		 AND assembly = '1'|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{assembly_items} }, $ref if $ref->{inventory};
  }
  $sth->finish;

  $dbh->disconnect;
  
}


sub restock_assemblies {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
  
  for my $i (1 .. $form->{rowcount}) {

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"qty_$i"} != 0) {
      &adjust_inventory($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"});
    }

  }
  
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


sub adjust_inventory {
  my ($dbh, $form, $id, $qty) = @_;

  my $query = qq|SELECT p.id, p.inventory_accno_id, p.assembly, a.qty
		 FROM parts p
		 JOIN assembly a ON (a.parts_id = p.id)
		 WHERE a.id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    my $allocate = $qty * $ref->{qty};
    
    # is it a service item, then loop
    $ref->{inventory_accno_id} *= 1;
    next if (($ref->{inventory_accno_id} == 0) && !$ref->{assembly});
    
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
  
  if ($form->{item} eq 'assembly' && $form->{onhand} != 0) {
    # adjust onhand for the assembly
    &adjust_inventory($dbh, $form, $form->{id}, $form->{onhand} * -1);
  }

  my $query = qq|DELETE FROM parts
 	         WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM partstax
	      WHERE parts_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # check if it is a part, assembly or service
  if ($form->{item} eq 'part') {
    $query = qq|DELETE FROM makemodel
		WHERE parts_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  if ($form->{item} eq 'assembly') {
    $query = qq|DELETE FROM assembly
		WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }
  
  if ($form->{item} eq 'alternate') {
    $query = qq|DELETE FROM alternate
		WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}


sub assembly_item {
  my ($self, $myconfig, $form) = @_;

  my $i = $form->{assembly_rows};
  my $var;
  my $where = "1 = 1";

  if ($form->{"partnumber_$i"}) {
    $var = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$var'";
  }
  if ($form->{"description_$i"}) {
    $var = $form->like(lc $form->{"description_$i"});
    $where .= " AND lower(p.description) LIKE '$var'";
  }
  if ($form->{"partsgroup_$i"}) {
    $var = $form->like(lc $form->{"partsgroup_$i"});
    $where .= " AND lower(pg.partsgroup) LIKE '$var'";
  }
  
  if ($form->{id}) {
    $where .= " AND NOT p.id = $form->{id}";
  }

  if ($partnumber) {
    $where .= " ORDER BY p.partnumber";
  } else {
    $where .= " ORDER BY p.description";
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                 p.weight, p.onhand, p.unit,
		 pg.partsgroup
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
  my $var;
  
  foreach my $item (qw(partnumber drawing microfiche)) {
    if ($form->{$item}) {
      $var = $form->like(lc $form->{$item});
      $where .= " AND lower(p.$item) LIKE '$var'";
    }
  }
  # special case for description
  if ($form->{description}) {
    unless ($form->{bought} || $form->{sold} || $form->{onorder} || $form->{ordered}) {
      $var = $form->like(lc $form->{description});
      $where .= " AND lower(p.description) LIKE '$var'";
    }
  }

  if ($form->{searchitems} eq 'part') {
    $where .= " AND p.inventory_accno_id > 0";
  }
  if ($form->{searchitems} eq 'assembly') {
    $form->{bought} = "";
    $where .= " AND p.assembly = '1'";
  }
  if ($form->{searchitems} eq 'service') {
    $where .= " AND p.inventory_accno_id IS NULL AND NOT p.assembly = '1'";
    # irrelevant for services
    $form->{make} = $form->{model} = "";
  }

  # items which were never bought, sold or on an order
  if ($form->{itemstatus} eq 'orphaned') {
    $form->{onhand} = $form->{short} = 0;
    $form->{bought} = $form->{sold} = 0;
    $form->{onorder} = $form->{ordered} = 0;
    $form->{transdatefrom} = $form->{transdateto} = "";
    
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
    $form->{onhand} = $form->{short} = 0;
  }
  if ($form->{itemstatus} eq 'onhand') {
    $where .= " AND p.onhand > 0";
  }
  if ($form->{itemstatus} eq 'short') {
    $where .= " AND p.onhand < 0";
  }

  if ($form->{make}) {
    $var = $form->like(lc $form->{make}).":%";
    $where .= " AND p.id IN (SELECT DISTINCT ON (m.parts_id) m.parts_id
                           FROM makemodel m WHERE lower(m.name) LIKE '$var')";
  }
  if ($form->{model}) {
    $var = "%:".$form->like($form->{model});
    $where .= " AND p.id IN (SELECT DISTINCT ON (m.parts_id) m.parts_id
                           FROM makemodel m WHERE lower(m.name) LIKE '$var')";
  }
  if ($form->{partsgroup}) {
    $var = $form->like(lc $form->{partsgroup});
    $where .= " AND lower(pg.partsgroup) LIKE '$var'";
    
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  
  my $sortorder = join ', ', $form->sort_columns(qw(partnumber description bin priceupdate partsgroup));
  $sortorder = $form->{sort} unless $sortorder;

  my $query = qq|SELECT p.id, p.partnumber, p.description, p.onhand, p.unit,
                 p.bin, p.sellprice, p.listprice, p.lastcost, p.rop, p.weight,
		 p.priceupdate, p.image, p.drawing, p.microfiche,
		 pg.partsgroup
                 FROM parts p
                 LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
  	         WHERE $where
	         ORDER BY $sortorder|;

  # rebuild query for bought and sold items
  if ($form->{bought} || $form->{sold} || $form->{onorder} || $form->{ordered}) {
    
    my $union = "";
    $query = "";
  
    if ($form->{bought} || $form->{sold}) {
      
      my $invwhere = "$where";
      $invwhere .= " AND i.assemblyitem = '0'";
      $invwhere .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $invwhere .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};

      if ($form->{description}) {
	$var = $form->like(lc $form->{description});
	$invwhere .= " AND lower(i.description) LIKE '$var'";
      }

      my $flds = qq|p.id, p.partnumber, i.description,
                    i.qty AS onhand, i.unit, p.bin, i.sellprice,
		    p.listprice, p.lastcost, p.rop, p.weight,
		    p.priceupdate, p.image, p.drawing, p.microfiche,
		    pg.partsgroup,
		    a.invnumber, a.ordnumber, i.trans_id|;

      if ($form->{bought}) {
	$query = qq|
	            SELECT $flds, 'ir' AS module, '' AS type,
		    1 AS exchangerate
		    FROM parts p
		    JOIN invoice i ON (i.parts_id = p.id)
		    JOIN ap a ON (i.trans_id = a.id)
                    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    WHERE $invwhere|;
	$union = "
	          UNION";
      }

      if ($form->{sold}) {
	$query .= qq|$union
                     SELECT $flds, 'is' AS module, '' AS type,
		     1 As exchangerate
		     FROM parts p
		     JOIN invoice i ON (i.parts_id = p.id)
		     JOIN ar a ON (i.trans_id = a.id)
                     LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		     WHERE $invwhere|;
	$union = "
	          UNION";
      }
    }

    if ($form->{onorder} || $form->{ordered}) {
      my $ordwhere = "$where";
      $ordwhere .= " AND o.closed = '0'" unless $form->{closed};
      
      $ordwhere .= " AND o.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $ordwhere .= " AND o.transdate <= '$form->{transdateto}'" if $form->{transdateto};

      if ($form->{description}) {
	$var = $form->like(lc $form->{description});
	$ordwhere .= " AND lower(oi.description) LIKE '$var'";
      }

      $flds = qq|p.id, p.partnumber, oi.description,
                 oi.qty AS onhand, oi.unit, p.bin, oi.sellprice,
	         p.listprice, p.lastcost, p.rop, p.weight,
		 p.priceupdate, p.image, p.drawing, p.microfiche,
		 pg.partsgroup,
		 '' AS invnumber, o.ordnumber, oi.trans_id|;

      if ($form->{ordered}) {
	$query .= qq|$union
                     SELECT $flds, 'oe' AS module, 'sales_order' AS type,
		    (SELECT buy FROM exchangerate ex
		     WHERE ex.curr = o.curr
		     AND ex.transdate = o.transdate) AS exchangerate
		     FROM parts p
		     JOIN orderitems oi ON (oi.parts_id = p.id)
		     JOIN oe o ON (oi.trans_id = o.id)
                     LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		     WHERE $ordwhere
		     AND o.customer_id > 0|;
	$union = "
	          UNION";
      }
      
      if ($form->{onorder}) {
        $flds = qq|p.id, p.partnumber, oi.description,
                   oi.qty * -1 AS onhand, oi.unit, p.bin, oi.sellprice,
		   p.listprice, p.lastcost, p.rop, p.weight,
		   p.priceupdate, p.image, p.drawing, p.microfiche,
		   pg.partsgroup,
		   '' AS invnumber, o.ordnumber, oi.trans_id|;

	$query .= qq|$union
	            SELECT $flds, 'oe' AS module, 'purchase_order' AS type,
		    (SELECT sell FROM exchangerate ex
		     WHERE ex.curr = o.curr
		     AND ex.transdate = o.transdate) AS exchangerate
		    FROM parts p
		    JOIN orderitems oi ON (oi.parts_id = p.id)
		    JOIN oe o ON (oi.trans_id = o.id)
                    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    WHERE $ordwhere
		    AND o.vendor_id > 0|;
      }

    }

    $query .= qq|
		 ORDER BY $sortorder|;

  }

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{parts} }, $ref;
  }

  $sth->finish;


  # include individual items for assemblies
  if ($form->{searchitems} eq 'assembly' && $form->{bom}) {
    foreach $item (@{ $form->{parts} }) {
      push @assemblies, $item;
      $query = qq|SELECT p.id, p.partnumber, p.description, a.qty AS onhand,
                  p.unit, p.bin,
                  p.sellprice, p.listprice, p.lastcost,
		  p.rop, p.weight, p.priceupdate,
		  p.image, p.drawing, p.microfiche
		  FROM parts p
		  JOIN assembly a ON (p.id = a.parts_id)
		  WHERE a.id = $item->{id}|;
      
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
	$ref->{assemblyitem} = 1;
	push @assemblies, $ref;
      }
      $sth->finish;

      push @assemblies, {id => $item->{id}};

    }

    # copy assemblies to $form->{parts}
    @{ $form->{parts} } = @assemblies;
    
  }

  $dbh->disconnect;

}


sub create_links {
  my ($self, $module, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT accno, description, link
                 FROM chart
		 WHERE link LIKE '%$module%'
		 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /$module/) {
	push @{ $form->{"${module}_links"}{$key} }, { accno => $ref->{accno},
				      description => $ref->{description} };
      }
    }
  }

  $sth->finish;

  if ($form->{id}) {
    $query = qq|SELECT weightunit
                FROM defaults|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{weightunit}) = $sth->fetchrow_array;
    $sth->finish;

  } else {
    $query = qq|SELECT weightunit, current_date
                FROM defaults|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{weightunit}, $form->{priceupdate}) = $sth->fetchrow_array;
    $sth->finish;
  }
  
  $dbh->disconnect;

}


1;

