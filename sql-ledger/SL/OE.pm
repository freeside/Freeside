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
# Order entry module
#
#======================================================================

package OE;


sub transactions {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
 
  my $query;

  my $rate = ($form->{vc} eq 'customer') ? 'buy' : 'sell';
  
  my $query = qq|SELECT o.id, o.ordnumber, o.transdate, o.reqdate,
                 o.amount, ct.name, o.netamount, o.$form->{vc}_id,
		 (SELECT $rate FROM exchangerate ex
		  WHERE ex.curr = o.curr
		  AND ex.transdate = o.transdate) AS exchangerate,
		 o.closed
	         FROM oe o, $form->{vc} ct
	         WHERE o.$form->{vc}_id = ct.id|;
	      
  my $ordnumber = $form->like(lc $form->{ordnumber});
  
  if ($form->{"$form->{vc}_id"}) {
    $query .= qq| AND o.$form->{vc}_id = $form->{"$form->{vc}_id"}|;
  } else {
    if ($form->{$form->{vc}}) {
      my $name = $form->like(lc $form->{$form->{vc}});
      $query .= " AND lower(name) LIKE '$name'";
    }
  }
  unless ($form->{open} && $form->{closed}) {
    $query .= ($form->{open}) ? " AND o.closed = '0'" : " AND o.closed = '1'";
  }

  my $sortorder = join ', ', $form->sort_columns(qw(transdate ordnumber name));
  $sortorder = $form->{sort} unless $sortorder;
  
  $query .= " AND lower(ordnumber) LIKE '$ordnumber'" if $form->{ordnumber};
  $query .= " AND transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
  $query .= " AND transdate <= '$form->{transdateto}'" if $form->{transdateto};
  $query .= " ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $oe = $sth->fetchrow_hashref(NAME_lc)) {
    $oe->{exchangerate} = 1 unless $oe->{exchangerate};
    push @{ $form->{OE} }, $oe;
  }

  $sth->finish;
  $dbh->disconnect;
  
}


sub save_order {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($query, $sth);
  my $exchangerate = 0;

  if ($form->{id}) {

    $query = qq|DELETE FROM orderitems
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

  } else {
    my $uid = time;
    $uid .= $form->{login};
    
    $query = qq|INSERT INTO oe (ordnumber, employee_id)
                VALUES ('$uid', (SELECT id FROM employee
		                 WHERE login = '$form->{login}') )|;
    $dbh->do($query) || $form->dberror($query);
   
    $query = qq|SELECT id FROM oe
                WHERE ordnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
  }

  map { $form->{$_} =~ s/'/''/g } qw(ordnumber shippingpoint notes message);
  
  my ($amount, $linetotal, $discount, $project_id, $reqdate);
  my ($taxrate, $taxamount, $fxsellprice);
  my %taxbase = ();
  my %taxaccounts = ();
  my ($netamount, $tax) = (0, 0);

  for my $i (1 .. $form->{rowcount}) {
    
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    
    if ($form->{"qty_$i"} != 0) {
      
      map { $form->{"${_}_$i"} =~ s/'/''/g } qw(partnumber description unit);
      
      # set values to 0 if nothing entered
      $form->{"discount_$i"} = $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;

      $form->{"sellprice_$i"} = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      $fxsellprice = $form->{"sellprice_$i"};

      my ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;
      
      $discount = $form->round_amount($form->{"sellprice_$i"} * $form->{"discount_$i"}, $decimalplaces);
      $form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} - $discount, $decimalplaces);
      
      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);
      $taxrate = 0;
      map { $taxrate += $form->{"${_}_rate"} } split / /, $form->{"taxaccounts_$i"};

      if ($form->{taxincluded}) {
	$taxamount = $linetotal * $taxrate / (1 + $taxrate);
	$taxbase = $linetotal - $taxamount;
	# we are not keeping a natural price, do not round
	$form->{"sellprice_$i"} = $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
      } else {
	$taxamount = $linetotal * $taxrate;
	$taxbase = $linetotal;
      }

      if ($taxamount != 0) {
	foreach my $item (split / /, $form->{"taxaccounts_$i"}) {
	  $taxaccounts{$item} += $taxamount * $form->{"${item}_rate"} / $taxrate;
	  $taxbase{$item} += $taxbase;
	}
      }
      
      $netamount += $form->{"sellprice_$i"} * $form->{"qty_$i"};
      
      $project_id = 'NULL';
      if ($form->{"project_id_$i"}) {
	$project_id = $form->{"project_id_$i"};
      }
      $reqdate = ($form->{"reqdate_$i"}) ? qq|'$form->{"reqdate_$i"}'| : "NULL";
      
      # save detail record in orderitems table
      $query = qq|INSERT INTO orderitems
		 (trans_id, parts_id, description, qty, sellprice, discount,
		  unit, reqdate, project_id) VALUES (
		  $form->{id}, $form->{"id_$i"}, '$form->{"description_$i"}',
		  $form->{"qty_$i"}, $fxsellprice, $form->{"discount_$i"},
		  '$form->{"unit_$i"}', $reqdate, $project_id)|;
      $dbh->do($query) || $form->dberror($query);

      $form->{"sellprice_$i"} = $fxsellprice;
      $form->{"discount_$i"} *= 100;
    }
  }


  # set values which could be empty
  map { $form->{$_} *= 1 } qw(vendor_id customer_id taxincluded closed);

  $reqdate = ($form->{reqdate}) ? qq|'$form->{reqdate}'| : "NULL";
  
  # add up the tax
  foreach my $item (sort keys %taxaccounts) {
    $taxamount = $form->round_amount($taxaccounts{$item}, 2);
    $tax += $taxamount;
  }
  
  $amount = $form->round_amount($netamount + $tax, 2);
  $netamount = $form->round_amount($netamount, 2);

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, ($form->{vc} eq 'customer') ? 'buy' : 'sell');
  }
  
  $form->{exchangerate} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{exchangerate});
  
  # fill in subject if there is none
  $form->{subject} = qq|$form->{label} $form->{ordnumber}| unless $form->{subject};
  # if there is a message stuff it into the notes
  my $cc = "Cc: $form->{cc}\\r\n" if $form->{cc};
  my $bcc = "Bcc: $form->{bcc}\\r\n" if $form->{bcc};
  $form->{notes} .= qq|\r
\r
[email]\r
To: $form->{email}\r
$cc${bcc}Subject: $form->{subject}\r
\r
Message: $form->{message}\r| if $form->{message};
  
  # save OE record
  $query = qq|UPDATE oe set
	      ordnumber = '$form->{ordnumber}',
              transdate = '$form->{orddate}',
              vendor_id = $form->{vendor_id},
	      customer_id = $form->{customer_id},
              amount = $amount,
              netamount = $netamount,
	      reqdate = $reqdate,
	      taxincluded = '$form->{taxincluded}',
	      shippingpoint = '$form->{shippingpoint}',
	      notes = '$form->{notes}',
	      curr = '$form->{currency}',
	      closed = '$form->{closed}'
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $form->{ordtotal} = $amount;

  # add shipto
  $form->{name} = $form->{$form->{vc}};
  $form->{name} =~ s/--$form->{"$form->{vc}_id"}//;
  $form->add_shipto($dbh, $form->{id});
  
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    if ($form->{vc} eq 'customer') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{orddate}, $form->{exchangerate}, 0);
    }
    if ($form->{vc} eq 'vendor') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{orddate}, 0, $form->{exchangerate});
    }
  }
  
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}



sub delete_order {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  # can't use $form->delete_exchangerate
  if ($form->{currency} ne $form->{defaultcurrency}) {
       $query = qq|SELECT transdate FROM acc_trans
		   WHERE ar.id = trans_id
		   AND ar.curr = '$form->{currency}'
		   AND transdate = '$form->{orddate}'
	   UNION SELECT transdate FROM acc_trans
		   WHERE ap.id = trans_id
		   AND ap.curr = '$form->{currency}'
		   AND transdate = '$form->{orddate}'|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    
    my ($transdate) = $sth->fetchrow_array;
    $sth->finish;

    if (!$transdate) {
      $query = qq|DELETE FROM exchangerate
		  WHERE curr = '$form->{currency}'
		  AND transdate = '$form->{orddate}'|;
      $dbh->do($query) || $self->dberror($query);
    }
  }
	      
  
  # delete OE record
  $query = qq|DELETE FROM oe
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete individual entries
  $query = qq|DELETE FROM orderitems
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM shipto
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}



sub retrieve_order {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  if ($form->{id}) {
    # get default accounts and last order number
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
    my $ordnumber = ($form->{vc} eq 'customer') ? 'sonumber' : 'ponumber';
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
                $ordnumber AS ordnumber, d.curr AS currencies,
		current_date AS orddate, current_date AS reqdate
	 	FROM defaults d|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  ($form->{currency}) = split /:/, $form->{currencies};
  
  if ($form->{id}) {
    
    # retrieve order
    $query = qq|SELECT o.ordnumber, o.transdate AS orddate, o.reqdate,
                o.taxincluded, o.shippingpoint, o.notes, o.curr AS currency,
		(SELECT name FROM employee e
		 WHERE e.id = o.employee_id) AS employee,
		o.$form->{vc}_id, cv.name AS $form->{vc}, o.amount AS invtotal,
		o.closed, o.reqdate
		FROM oe o, $form->{vc} cv
		WHERE o.$form->{vc}_id = cv.id
		AND o.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;
    
   
    $query = qq|SELECT * FROM shipto
                WHERE trans_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;
    
    my %oid = ( 'Pg'		=> 'oid',
                'Oracle'	=> 'rowid',
                'DB2'		=> '' );

    # retrieve individual items
    $query = qq|SELECT c1.accno AS inventory_accno,
                       c2.accno AS income_accno,
		       c3.accno AS expense_accno,
                p.partnumber, p.assembly, o.description, o.qty,
		o.sellprice, o.parts_id AS id, o.unit, o.discount, p.bin,
                o.reqdate, o.project_id,
		pr.projectnumber,
		pg.partsgroup
		FROM orderitems o
		JOIN parts p ON (o.parts_id = p.id)
		LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		LEFT JOIN project pr ON (o.project_id = pr.id)
		LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		WHERE trans_id = $form->{id}
                ORDER BY o.$oid{$myconfig->{dbdriver}}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

      # get tax rates for part
      $query = qq|SELECT c.accno
                  FROM chart c, partstax pt
	          WHERE pt.chart_id = c.id
	          AND pt.parts_id = $ref->{id}|;
      my $pth = $dbh->prepare($query);
      $pth->execute || $form->dberror($query);

      $ref->{taxaccounts} = "";
      my $taxrate = 0;
      
      while (my $ptref = $pth->fetchrow_hashref(NAME_lc)) {
        $ref->{taxaccounts} .= "$ptref->{accno} ";
        $taxrate += $form->{"$ptref->{accno}_rate"};
      }
      $pth->finish;
      chop $ref->{taxaccounts};

      push @{ $form->{order_details} }, $ref;
      
    }
    $sth->finish;

  } else {

    my $ordnumber = ($form->{vc} eq 'customer') ? 'sonumber' : 'ponumber';
    # up order number by 1
    $form->{ordnumber}++;

    # save the new number
    $query = qq|UPDATE defaults
                SET $ordnumber = '$form->{ordnumber}'|;
    $dbh->do($query) || $form->dberror($query);

    $form->get_employee($dbh);
    
    # get last name used
    $form->lastname_used($dbh, $myconfig, $form->{vc}) unless $form->{"$form->{vc}_id"};

  }
  
  $form->{exchangerate} = $form->get_exchangerate($dbh, $form->{currency}, $form->{orddate}, ($form->{vc} eq 'customer') ? "buy" : "sell");
  
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}



sub order_details {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
    
  my $tax = 0;
  my $item;
  my $i;
  my @partsgroup = ();
  my $partsgroup;
  my %oid = ( 'Pg' => 'oid',
	      'Oracle' => 'rowid' );

  # sort items by partsgroup
  for $i (1 .. $form->{rowcount}) {
    $partsgroup = "";
    if ($form->{"partsgroup_$i"} && $form->{groupitems}) {
      $form->format_string("partsgroup_$i");
      $partsgroup = $form->{"partsgroup_$i"};
    }
    push @partsgroup, [ $i, $partsgroup ];
  }
  
  my $sameitem = "";
  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map { push(@{ $form->{$_} }, "") } qw(runningnumber number bin qty unit reqdate sellprice listprice netprice discount linetotal);
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    
    if ($form->{"qty_$i"} != 0) {

      # add number, description and qty to $form->{number}, ....
      push(@{ $form->{runningnumber} }, $i);
      push(@{ $form->{number} }, qq|$form->{"partnumber_$i"}|);
      push(@{ $form->{description} }, qq|$form->{"description_$i"}|);
      push(@{ $form->{qty} }, $form->format_amount($myconfig, $form->{"qty_$i"}));
      push(@{ $form->{unit} }, qq|$form->{"unit_$i"}|);
      push(@{ $form->{reqdate} }, qq|$form->{"reqdate_$i"}|);
      
      push(@{ $form->{sellprice} }, $form->{"sellprice_$i"});
      
      push(@{ $form->{listprice} }, $form->{"listprice_$i"});
      
      my $sellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my ($dec) = ($sellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;

      my $discount = $form->round_amount($sellprice * $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100, $decimalplaces);

      # keep a netprice as well, (sellprice - discount)
      $form->{"netprice_$i"} = $sellprice - $discount;

      my $linetotal = $form->round_amount($form->{"qty_$i"} * $form->{"netprice_$i"}, 2);

      push(@{ $form->{netprice} }, ($form->{"netprice_$i"} != 0) ? $form->format_amount($myconfig, $form->{"netprice_$i"}, $decimalplaces) : " ");
      
      $discount = ($discount != 0) ? $form->format_amount($myconfig, $discount * -1, $decimalplaces) : " ";
      $linetotal = ($linetotal != 0) ? $linetotal : " ";

      push(@{ $form->{discount} }, $discount);
      
      $form->{ordtotal} += $linetotal;

      push(@{ $form->{linetotal} }, $form->format_amount($myconfig, $linetotal, 2));
      
      my ($taxamount, $taxbase);
      my $taxrate = 0;
      
      map { $taxrate += $form->{"${_}_rate"} } split / /, $form->{"taxaccounts_$i"};

      if ($form->{taxincluded}) {
	# calculate tax
	$taxamount = $linetotal * $taxrate / (1 + $taxrate);
	$taxbase = $linetotal / (1 + $taxrate);
      } else {
        $taxamount = $linetotal * $taxrate;
	$taxbase = $linetotal;
      }


      if ($taxamount != 0) {
	foreach my $item (split / /, $form->{"taxaccounts_$i"}) {
	  $taxaccounts{$item} += $taxamount * $form->{"${item}_rate"} / $taxrate;
	  $taxbase{$item} += $taxbase;
	}
      }

      if ($form->{"assembly_$i"}) {
        $sameitem = "";
	
        # get parts and push them onto the stack
	my $sortorder = "";
	if ($form->{groupitems}) {
	  $sortorder = qq|ORDER BY pg.partsgroup, a.$oid{$myconfig->{dbdriver}}|;
	} else {
	  $sortorder = qq|ORDER BY a.$oid{$myconfig->{dbdriver}}|;
	}
	
	$query = qq|SELECT p.partnumber, p.description, p.unit, a.qty,
	            pg.partsgroup
	            FROM assembly a
		    JOIN parts p ON (a.parts_id = p.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    WHERE a.bom = '1'
		    AND a.id = '$form->{"id_$i"}'
		    $sortorder|;
        $sth = $dbh->prepare($query);
        $sth->execute || $form->dberror($query);

	while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
	  if ($form->{groupitems} && $ref->{partsgroup} ne $sameitem) {
	    map { push(@{ $form->{$_} }, "") } qw(runningnumber number unit bin qty sellprice listprice netprice discount linetotal);
	    $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
	    push(@{ $form->{description} }, $sameitem);
	  }
	    
	  push(@{ $form->{number} }, qq|$ref->{partnumber}|);
	  push(@{ $form->{description} }, qq|$ref->{description}|);
	  push(@{ $form->{unit} }, qq|$ref->{unit}|);
	  push(@{ $form->{qty} }, $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}));

          map { push(@{ $form->{$_} }, "") } qw(runningnumber bin sellprice listprice netprice discount linetotal);
	  
	}
	$sth->finish;
      }

    }
  }


  foreach $item (sort keys %taxaccounts) {
    if ($form->round_amount($taxaccounts{$item}, 2) != 0) {
      push(@{ $form->{taxbase} }, $form->format_amount($myconfig, $taxbase{$item}, 2));
      
      $taxamount = $form->round_amount($taxaccounts{$item}, 2);
      $tax += $taxamount;
      
      push(@{ $form->{tax} }, $form->format_amount($myconfig, $taxamount, 2));
      push(@{ $form->{taxdescription} }, $form->{"${item}_description"});
      push(@{ $form->{taxrate} }, $form->format_amount($myconfig, $form->{"${item}_rate"} * 100));
      push(@{ $form->{taxnumber} }, $form->{"${item}_taxnumber"});
    }
  }


  $form->{subtotal} = $form->format_amount($myconfig, $form->{ordtotal}, 2);
  $form->{ordtotal} = ($form->{taxincluded}) ? $form->{ordtotal} : $form->{ordtotal} + $tax;
  
  # format amounts
  $form->{ordtotal} = $form->format_amount($myconfig, $form->{ordtotal}, 2);

  # myconfig variables
  map { $form->{$_} = $myconfig->{$_} } (qw(company address tel fax signature businessnumber));
  $form->{username} = $myconfig->{name};

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


1;

