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
# backend code for customers and vendors
#
#======================================================================

package CT;


sub create_links {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);
  my $query;
  my $sth;
  my $ref;

  if ($form->{id}) {
    $query = qq|SELECT ct.*, b.description AS business, s.*,
                e.name AS employee, g.pricegroup AS pricegroup,
		l.description AS language, ct.curr
                FROM $form->{db} ct
		LEFT JOIN business b ON (ct.business_id = b.id)
		LEFT JOIN shipto s ON (ct.id = s.trans_id)
		LEFT JOIN employee e ON (ct.employee_id = e.id)
		LEFT JOIN pricegroup g ON (g.id = ct.pricegroup_id)
		LEFT JOIN language l ON (l.code = ct.language_code)
                WHERE ct.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
  
    $ref = $sth->fetchrow_hashref(NAME_lc);
  
    map { $form->{$_} = $ref->{$_} } keys %$ref;

    $sth->finish;

    # check if it is orphaned
    my $arap = ($form->{db} eq 'customer') ? "ar" : "ap";
    $query = qq|SELECT a.id
              FROM $arap a
	      JOIN $form->{db} ct ON (a.$form->{db}_id = ct.id)
	      WHERE ct.id = $form->{id}
	    UNION
	      SELECT a.id
	      FROM oe a
	      JOIN $form->{db} ct ON (a.$form->{db}_id = ct.id)
	      WHERE ct.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
  
    unless ($sth->fetchrow_array) {
      $form->{status} = "orphaned";
    }
    $sth->finish;


    # get taxes for customer/vendor
    $query = qq|SELECT c.accno
		FROM chart c
		JOIN $form->{db}tax t ON (t.chart_id = c.id)
		WHERE t.$form->{db}_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      $form->{tax}{$ref->{accno}}{taxable} = 1;
    }
    $sth->finish;

  } else {

    ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh);

    $query = qq|SELECT current_date FROM defaults|;
    ($form->{startdate}) = $dbh->selectrow_array($query);

  }

  # get tax labels
  $query = qq|SELECT c.accno, c.description
              FROM chart c
	      JOIN tax t ON (t.chart_id = c.id)
	      WHERE c.link LIKE '%CT_tax%'
	      ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxaccounts} .= "$ref->{accno} ";
    $form->{tax}{$ref->{accno}}{description} = $ref->{description};
  }
  $sth->finish;
  chop $form->{taxaccounts};

    
  # get business types
  $query = qq|SELECT *
              FROM business
	      ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_business} }, $ref;
  }
  $sth->finish;
  
  # this is for the salesperson
  $query = qq|SELECT id, name
              FROM employee
	      WHERE sales = '1'
	      ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_employee} }, $ref;
  }
  $sth->finish;

  # get language
  $query = qq|SELECT *
              FROM language
	      ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_language} }, $ref;
  }
  $sth->finish;
 
  # get pricegroups
  $query = qq|SELECT *
              FROM pricegroup
	      ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_pricegroup} }, $ref;
  }
  $sth->finish;
  
  # get currencies
  $query = qq|SELECT curr AS currencies
              FROM defaults|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  ($form->{currencies}) = $sth->fetchrow_array;
  $sth->finish;

  $dbh->disconnect;

}


sub save_customer {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
  my $query;
  my $sth;
  my $null;
  
  # remove double spaces
  $form->{name} =~ s/  / /g;
  # remove double minus and minus at the end
  $form->{name} =~ s/--+/-/g;
  $form->{name} =~ s/-+$//;
  
  # assign value discount, terms, creditlimit
  $form->{discount} = $form->parse_amount($myconfig, $form->{discount});
  $form->{discount} /= 100;
  $form->{terms} *= 1;
  $form->{taxincluded} *= 1;
  $form->{creditlimit} = $form->parse_amount($myconfig, $form->{creditlimit});
  

  if ($form->{id}) {
    $query = qq|DELETE FROM customertax
                WHERE customer_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    # retrieve enddate
    if ($form->{type} && $form->{enddate}) {
      my $now;
      $query = qq|SELECT enddate, current_date AS now FROM customer|;
      ($form->{enddate}, $now) = $dbh->selectrow_array($query);
      $form->{enddate} = $now if $form->{enddate} lt $now;
    }

  } else {
    my $uid = time;
    $uid .= $form->{login};

    $query = qq|INSERT INTO customer (name)
                VALUES ('$uid')|;
    $dbh->do($query) || $form->dberror($query);
    
    $query = qq|SELECT id FROM customer
                WHERE name = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;

  }

  my $employee_id;
  ($null, $employee_id) = split /--/, $form->{employee};
  $employee_id *= 1;
  
  my $pricegroup_id;
  ($null, $pricegroup_id) = split /--/, $form->{pricegroup};
  $pricegroup_id *= 1;

  my $business_id;
  ($null, $business_id) = split /--/, $form->{business};
  $business_id *= 1;

  my $language_code;
  ($null, $language_code) = split /--/, $form->{language};

  $form->{customernumber} = $form->update_defaults($myconfig, "customernumber", $dbh) if ! $form->{customernumber};
  
  $query = qq|UPDATE customer SET
              customernumber = |.$dbh->quote($form->{customernumber}).qq|,
	      name = |.$dbh->quote($form->{name}).qq|,
	      address1 = |.$dbh->quote($form->{address1}).qq|,
	      address2 = |.$dbh->quote($form->{address2}).qq|,
	      city = |.$dbh->quote($form->{city}).qq|,
	      state = |.$dbh->quote($form->{state}).qq|,
	      zipcode = |.$dbh->quote($form->{zipcode}).qq|,
	      country = |.$dbh->quote($form->{country}).qq|,
	      contact = |.$dbh->quote($form->{contact}).qq|,
	      phone = '$form->{phone}',
	      fax = '$form->{fax}',
	      email = '$form->{email}',
	      cc = '$form->{cc}',
	      bcc = '$form->{bcc}',
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      discount = $form->{discount},
	      creditlimit = $form->{creditlimit},
	      terms = $form->{terms},
	      taxincluded = '$form->{taxincluded}',
	      business_id = $business_id,
	      taxnumber = |.$dbh->quote($form->{taxnumber}).qq|,
	      sic_code = '$form->{sic}',
	      iban = '$form->{iban}',
	      bic = '$form->{bic}',
	      employee_id = $employee_id,
	      pricegroup_id = $pricegroup_id,
	      language_code = '$language_code',
	      curr = '$form->{curr}',
	      startdate = |.$form->dbquote($form->{startdate}, SQL_DATE).qq|,
	      enddate = |.$form->dbquote($form->{enddate}, SQL_DATE).qq|
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # save taxes
  foreach $item (split / /, $form->{taxaccounts}) {
    if ($form->{"tax_$item"}) {
      $query = qq|INSERT INTO customertax (customer_id, chart_id)
		  VALUES ($form->{id}, (SELECT id
				        FROM chart
				        WHERE accno = '$item'))|;
      $dbh->do($query) || $form->dberror($query);
    }
  }
  
  # add shipto
  $form->add_shipto($dbh, $form->{id});

  $dbh->commit;
  $dbh->disconnect;

}


sub save_vendor {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my $sth;
  my $null;

  # remove double spaces
  $form->{name} =~ s/  / /g;
  # remove double minus and minus at the end
  $form->{name} =~ s/--+/-/g;
  $form->{name} =~ s/-+$//;

  $form->{discount} = $form->parse_amount($myconfig, $form->{discount});
  $form->{discount} /= 100;
  $form->{terms} *= 1;
  $form->{taxincluded} *= 1;
  $form->{creditlimit} = $form->parse_amount($myconfig, $form->{creditlimit});
 
  
  if ($form->{id}) {
    $query = qq|DELETE FROM vendortax
                WHERE vendor_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  } else {
    my $uid = time;
    $uid .= $form->{login};
    
    $query = qq|INSERT INTO vendor (name)
                VALUES ('$uid')|;
    $dbh->do($query) || $form->dberror($query);
   
    $query = qq|SELECT id FROM vendor
                WHERE name = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;

  }
   
  my $employee_id;
  ($null, $employee_id) = split /--/, $form->{employee};
  $employee_id *= 1;
  
  my $pricegroup_id;
  ($null, $pricegroup_id) = split /--/, $form->{pricegroup};
  $pricegroup_id *= 1;

  my $business_id;
  ($null, $business_id) = split /--/, $form->{business};
  $business_id *= 1;

  my $language_code;
  ($null, $language_code) = split /--/, $form->{language};
 
  $form->{vendornumber} = $form->update_defaults($myconfig, "vendornumber", $dbh) if ! $form->{vendornumber};
  
  $query = qq|UPDATE vendor SET
              vendornumber = |.$dbh->quote($form->{vendornumber}).qq|,
	      name = |.$dbh->quote($form->{name}).qq|,
	      address1 = |.$dbh->quote($form->{address1}).qq|,
	      address2 = |.$dbh->quote($form->{address2}).qq|,
	      city = |.$dbh->quote($form->{city}).qq|,
	      state = |.$dbh->quote($form->{state}).qq|,
	      zipcode = |.$dbh->quote($form->{zipcode}).qq|,
	      country = |.$dbh->quote($form->{country}).qq|,
	      contact = |.$dbh->quote($form->{contact}).qq|,
	      phone = '$form->{phone}',
	      fax = '$form->{fax}',
	      email = '$form->{email}',
	      cc = '$form->{cc}',
	      bcc = '$form->{bcc}',
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      terms = $form->{terms},
	      discount = $form->{discount},
	      creditlimit = $form->{creditlimit},
	      taxincluded = '$form->{taxincluded}',
	      gifi_accno = '$form->{gifi_accno}',
	      business_id = $business_id,
	      taxnumber = |.$dbh->quote($form->{taxnumber}).qq|,
	      sic_code = '$form->{sic}',
	      iban = '$form->{iban}',
	      bic = '$form->{bic}',
	      employee_id = $employee_id,
	      language_code = '$language_code',
	      pricegroup_id = $pricegroup_id,
	      curr = '$form->{curr}',
	      startdate = |.$form->dbquote($form->{startdate}, SQL_DATE).qq|,
	      enddate = |.$form->dbquote($form->{enddate}, SQL_DATE).qq|
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # save taxes
  foreach $item (split / /, $form->{taxaccounts}) {
    if ($form->{"tax_$item"}) {
      $query = qq|INSERT INTO vendortax (vendor_id, chart_id)
		  VALUES ($form->{id}, (SELECT id
				        FROM chart
				        WHERE accno = '$item'))|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # add shipto
  $form->add_shipto($dbh, $form->{id});

  $dbh->commit;
  $dbh->disconnect;

}



sub delete {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # delete customer/vendor
  my $query = qq|DELETE FROM $form->{db}
	         WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}


sub search {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where = "1 = 1";
  $form->{sort} = ($form->{sort}) ? $form->{sort} : "name";
  my @a = qw(name);
  my $sortorder = $form->sort_order(\@a);

  my $var;
  my $item;

  @a = ("$form->{db}number");
  push @a, qw(name contact city state zipcode country notes email);
  
  foreach $item (@a) {
    if ($form->{$item}) {
      $var = $form->like(lc $form->{$item});
      $where .= " AND lower(ct.$item) LIKE '$var'";
    }
  }
  if ($form->{address}) {
    $var = $form->like(lc $form->{address});
    $where .= " AND (lower(ct.address1) LIKE '$var' OR lower(ct.address2) LIKE '$var')";
  }

  if ($form->{status} eq 'orphaned') {
    $where .= qq| AND ct.id NOT IN (SELECT o.$form->{db}_id
                                    FROM oe o, $form->{db} cv
		 	            WHERE cv.id = o.$form->{db}_id)|;
    if ($form->{db} eq 'customer') {
      $where .= qq| AND ct.id NOT IN (SELECT a.customer_id
                                      FROM ar a, customer cv
				      WHERE cv.id = a.customer_id)|;
    }
    if ($form->{db} eq 'vendor') {
      $where .= qq| AND ct.id NOT IN (SELECT a.vendor_id
                                      FROM ap a, vendor cv
				      WHERE cv.id = a.vendor_id)|;
    }
    $form->{l_invnumber} = $form->{l_ordnumber} = $form->{l_quonumber} = "";
  }
  

  my $query = qq|SELECT ct.*, b.description AS business,
                 e.name AS employee, g.pricegroup, l.description AS language,
		 m.name AS manager
                 FROM $form->{db} ct
	      LEFT JOIN business b ON (ct.business_id = b.id)
	      LEFT JOIN employee e ON (ct.employee_id = e.id)
	      LEFT JOIN employee m ON (m.id = e.managerid)
	      LEFT JOIN pricegroup g ON (ct.pricegroup_id = g.id)
	      LEFT JOIN language l ON (l.code = ct.language_code)
                 WHERE $where|;

  # redo for invoices, orders and quotations
  if ($form->{l_transnumber} || $form->{l_invnumber} || $form->{l_ordnumber} || $form->{l_quonumber}) {

    my ($ar, $union, $module);
    $query = "";
    my $transwhere;
    my $openarap = "";
    my $openoe = "";
    
    if ($form->{open} || $form->{closed}) {
      unless ($form->{open} && $form->{closed}) {
	$openarap = " AND a.amount != a.paid" if $form->{open};
	$openarap = " AND a.amount = a.paid" if $form->{closed};
	$openoe = " AND o.closed = '0'" if $form->{open};
	$openoe = " AND o.closed = '1'" if $form->{closed};
      }
    }
      
    if ($form->{l_transnumber}) {
      $ar = ($form->{db} eq 'customer') ? 'ar' : 'ap';
      $module = $ar;

      $transwhere = "";
      $transwhere .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $transwhere .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};
      
   
      $query = qq|SELECT ct.*, b.description AS business,
                  a.invnumber, a.ordnumber, a.quonumber, a.id AS invid,
		  '$ar' AS module, 'invoice' AS formtype,
		  (a.amount = a.paid) AS closed, a.amount, a.netamount
		  FROM $form->{db} ct
		JOIN $ar a ON (a.$form->{db}_id = ct.id)
	        LEFT JOIN business b ON (ct.business_id = b.id)
		  WHERE $where
		  AND a.invoice = '0'
		  $transwhere
		  $openarap
		  |;
  
      $union = qq|
              UNION|;
      
    }

    if ($form->{l_invnumber}) {
      $ar = ($form->{db} eq 'customer') ? 'ar' : 'ap';
      $module = ($ar eq 'ar') ? 'is' : 'ir';

      $transwhere = "";
      $transwhere .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $transwhere .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};
    
      $query .= qq|$union
                  SELECT ct.*, b.description AS business,
                  a.invnumber, a.ordnumber, a.quonumber, a.id AS invid,
		  '$module' AS module, 'invoice' AS formtype,
		  (a.amount = a.paid) AS closed, a.amount, a.netamount
		  FROM $form->{db} ct
		JOIN $ar a ON (a.$form->{db}_id = ct.id)
	        LEFT JOIN business b ON (ct.business_id = b.id)
		  WHERE $where
		  AND a.invoice = '1'
		  $transwhere
		  $openarap
		  |;
  
      $union = qq|
              UNION|;
      
    }
    
    if ($form->{l_ordnumber}) {
      
      $transwhere = "";
      $transwhere .= " AND o.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $transwhere .= " AND o.transdate <= '$form->{transdateto}'" if $form->{transdateto};
      $query .= qq|$union
                  SELECT ct.*, b.description AS business,
		  ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid,
		  'oe' AS module, 'order' AS formtype,
		  o.closed, o.amount, o.netamount
		  FROM $form->{db} ct
		JOIN oe o ON (o.$form->{db}_id = ct.id)
	        LEFT JOIN business b ON (ct.business_id = b.id)
		  WHERE $where
		  AND o.quotation = '0'
		  $transwhere
		  $openoe
		  |;
  
      $union = qq|
              UNION|;

    }

    if ($form->{l_quonumber}) {

      $transwhere = "";
      $transwhere .= " AND o.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
      $transwhere .= " AND o.transdate <= '$form->{transdateto}'" if $form->{transdateto};
      $query .= qq|$union
                  SELECT ct.*, b.description AS business,
		  ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid,
		  'oe' AS module, 'quotation' AS formtype,
		  o.closed, o.amount, o.netamount
		  FROM $form->{db} ct
		JOIN oe o ON (o.$form->{db}_id = ct.id)
	        LEFT JOIN business b ON (ct.business_id = b.id)
		  WHERE $where
		  AND o.quotation = '1'
		  $transwhere
		  $openoe
		  |;

    }

      $sortorder .= ", invid";
  }

  $query .= qq|
		 ORDER BY $sortorder|;
		 
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{address} = "";
    map { $ref->{address} .= "$ref->{$_} "; } qw(address1 address2 city state zipcode country);
    push @{ $form->{CT} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

}


sub get_history {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $where = "1 = 1";
  $form->{sort} = "partnumber" unless $form->{sort};
  my $sortorder = $form->{sort};
  my %ordinal = ();
  my $var;
  my $table;

  # setup ASC or DESC
  $form->sort_order();
  
  if ($form->{"$form->{db}number"}) {
    $var = $form->like(lc $form->{"$form->{db}number"});
    $where .= " AND lower(ct.$form->{db}number) LIKE '$var'";
  }
  if ($form->{name}) {
    $var = $form->like(lc $form->{name});
    $where .= " AND lower(ct.name) LIKE '$var'";
  }
  if ($form->{address}) {
    $var = $form->like(lc $form->{address});
    $where .= " AND lower(ct.address1) LIKE '$var'";
  }
  if ($form->{city}) {
    $var = $form->like(lc $form->{city});
    $where .= " AND lower(ct.city) LIKE '$var'";
  }
  if ($form->{state}) {
    $var = $form->like(lc $form->{state});
    $where .= " AND lower(ct.state) LIKE '$var'";
  }
  if ($form->{zipcode}) {
    $var = $form->like(lc $form->{zipcode});
    $where .= " AND lower(ct.zipcode) LIKE '$var'";
  }
  if ($form->{country}) {
    $var = $form->like(lc $form->{country});
    $where .= " AND lower(ct.country) LIKE '$var'";
  }
  if ($form->{contact}) {
    $var = $form->like(lc $form->{contact});
    $where .= " AND lower(ct.contact) LIKE '$var'";
  }
  if ($form->{notes}) {
    $var = $form->like(lc $form->{notes});
    $where .= " AND lower(ct.notes) LIKE '$var'";
  }
  if ($form->{email}) {
    $var = $form->like(lc $form->{email});
    $where .= " AND lower(ct.email) LIKE '$var'";
  }

  $where .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
  $where .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};

  if ($form->{open} || $form->{closed}) {
    unless ($form->{open} && $form->{closed}) {
      if ($form->{type} eq 'invoice') {
	$where .= " AND a.amount != a.paid" if $form->{open};
	$where .= " AND a.amount = a.paid" if $form->{closed};
      } else {
	$where .= " AND a.closed = '0'" if $form->{open};
	$where .= " AND a.closed = '1'" if $form->{closed};
      }
    }
  }
  
  my $invnumber = 'invnumber';
  my $deldate = 'deliverydate';
  my $buysell;
  
  if ($form->{db} eq 'customer') {
    $buysell = "buy";
    if ($form->{type} eq 'invoice') {
      $where .= qq| AND a.invoice = '1' AND i.assemblyitem = '0'|;
      $table = 'ar';
    } else {
      $table = 'oe';
      if ($form->{type} eq 'order') {
	$invnumber = 'ordnumber';
	$where .= qq| AND a.quotation = '0'|;
      } else {
	$invnumber = 'quonumber';
	$where .= qq| AND a.quotation = '1'|;
      }
      $deldate = 'reqdate';
    }
  }
  if ($form->{db} eq 'vendor') {
    $buysell = "sell";
    if ($form->{type} eq 'invoice') {
      $where .= qq| AND a.invoice = '1' AND i.assemblyitem = '0'|;
      $table = 'ap';
    } else {
      $table = 'oe';
      if ($form->{type} eq 'order') {
	$invnumber = 'ordnumber';
	$where .= qq| AND a.quotation = '0'|;
      } else {
	$invnumber = 'quonumber';
	$where .= qq| AND a.quotation = '1'|;
      } 
      $deldate = 'reqdate';
    }
  }
 
  my $invjoin = qq|
		 JOIN invoice i ON (i.trans_id = a.id)|;

  if ($form->{type} eq 'order') {
    $invjoin = qq|
		 JOIN orderitems i ON (i.trans_id = a.id)|;
  }
  if ($form->{type} eq 'quotation') {
    $invjoin = qq|
		 JOIN orderitems i ON (i.trans_id = a.id)|;
    $where .= qq| AND a.quotation = '1'|;
  }


  if ($form->{history} eq 'summary') {
    $query = qq|SELECT curr FROM defaults|;
    my ($curr) = $dbh->selectrow_array($query);
    $curr =~ s/:.*//;
    
    %ordinal = ( partnumber	=> 8,
                 description	=> 9
	       );
    $sortorder = "2 $form->{direction}, 1, $ordinal{$sortorder} $form->{direction}";
    
    $query = qq|SELECT ct.id AS ctid, ct.name, ct.address1,
		ct.address2, ct.city, ct.state,
		p.id AS pid, p.partnumber, i.description, p.unit,
		sum(i.qty) AS qty, sum(i.sellprice) AS sellprice,
		'$curr' AS curr,
		ct.zipcode, ct.country
		FROM $form->{db} ct
		JOIN $table a ON (a.$form->{db}_id = ct.id)
		$invjoin
		JOIN parts p ON (p.id = i.parts_id)
		WHERE $where
		GROUP BY ct.id, ct.name, ct.address1, ct.address2, ct.city,
		ct.state, ct.zipcode, ct.country,
		p.id, p.partnumber, i.description, p.unit
		ORDER BY $sortorder|;
  } else {
    %ordinal = ( partnumber	=> 9,
                 description	=> 12,
		 "$deldate"	=> 16,
		 serialnumber	=> 17,
		 projectnumber	=> 18
		);
 
    $sortorder = "2 $form->{direction}, 1, 11, $ordinal{$sortorder} $form->{direction}";
    
    $query = qq|SELECT ct.id AS ctid, ct.name, ct.address1,
		ct.address2, ct.city, ct.state,
		p.id AS pid, p.partnumber, a.id AS invid,
		a.$invnumber, a.curr, i.description,
		i.qty, i.sellprice, i.discount,
		i.$deldate, i.serialnumber, pr.projectnumber,
		e.name AS employee, ct.zipcode, ct.country, i.unit|;
    $query .= qq|, i.fxsellprice| if $form->{type} eq 'invoice';

    if ($form->{type} ne 'invoice') {
      if ($form->{l_curr}) {
	$query .= qq|, (SELECT $buysell FROM exchangerate ex
	                WHERE a.curr = ex.curr
			AND a.transdate = ex.transdate) AS exchangerate|;
      }
    }
	
    $query .= qq|
                FROM $form->{db} ct
		JOIN $table a ON (a.$form->{db}_id = ct.id)
		$invjoin
		JOIN parts p ON (p.id = i.parts_id)
		LEFT JOIN project pr ON (pr.id = i.project_id)
		LEFT JOIN employee e ON (e.id = a.employee_id)
		WHERE $where
		ORDER BY $sortorder|;
  }


  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{address} = "";
    $ref->{exchangerate} = 1 unless $ref->{exchangerate};
    map { $ref->{address} .= "$ref->{$_} "; } qw(address1 address2 city state zipcode country);
    $ref->{id} = $ref->{ctid};
    push @{ $form->{CT} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

}


sub pricelist {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;

  if ($form->{db} eq 'customer') {
    $query = qq|SELECT p.id, p.partnumber, p.description,
                p.sellprice, pg.partsgroup, p.partsgroup_id,
                m.pricebreak, m.sellprice,
		m.validfrom, m.validto, m.curr
                FROM partscustomer m
		JOIN parts p ON (p.id = m.parts_id)
		LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		WHERE m.customer_id = $form->{id}
		ORDER BY partnumber|;
  }
  if ($form->{db} eq 'vendor') {
    $query = qq|SELECT p.id, p.partnumber AS sku, p.description,
                pg.partsgroup, p.partsgroup_id,
		m.partnumber, m.leadtime, m.lastcost, m.curr
		FROM partsvendor m
		JOIN parts p ON (p.id = m.parts_id)
		LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		WHERE m.vendor_id = $form->{id}
		ORDER BY p.partnumber|;
  }

  my $sth;
  my $ref;

  if ($form->{id}) {
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{all_partspricelist} }, $ref;
    }
    $sth->finish;
  }

  $query = qq|SELECT curr FROM defaults|;
  ($form->{currencies}) = $dbh->selectrow_array($query);

  $query = qq|SELECT id, partsgroup FROM partsgroup
              ORDER BY partsgroup|;

  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $form->{all_partsgroup} = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_partsgroup} }, $ref;
  }
  $sth->finish;
  
  $dbh->disconnect;

}


sub save_pricelist {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect_noauto($myconfig);
  
  my $query = qq|DELETE FROM parts$form->{db}
                 WHERE $form->{db}_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  
  foreach $i (1 .. $form->{rowcount}) {

    if ($form->{"id_$i"}) {

      if ($form->{db} eq 'customer') {
	map { $form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"}) } qw(pricebreak sellprice);
	
	$query = qq|INSERT INTO parts$form->{db} (parts_id, customer_id,
		    pricebreak, sellprice, validfrom, validto, curr)
		    VALUES ($form->{"id_$i"}, $form->{id},
		    $form->{"pricebreak_$i"}, $form->{"sellprice_$i"},|
		    .$form->dbquote($form->{"validfrom_$i"}, SQL_DATE) .qq|,|
		    .$form->dbquote($form->{"validto_$i"}, SQL_DATE) .qq|,
		    '$form->{"curr_$i"}')|;
      } else {
	map { $form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"}) } qw(leadtime lastcost);
	
	$query = qq|INSERT INTO parts$form->{db} (parts_id, vendor_id,
		    partnumber, lastcost, leadtime, curr)
		    VALUES ($form->{"id_$i"}, $form->{id},
		    '$form->{"partnumber_$i"}', $form->{"lastcost_$i"},
		    $form->{"leadtime_$i"}, '$form->{"curr_$i"}')|;

      }
      $dbh->do($query) || $form->dberror($query);
    }

  }

  $_ = $dbh->commit;
  $dbh->disconnect;

}



sub retrieve_item {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $i = $form->{rowcount};
  my $var;
  my $null;

  my $where = "WHERE p.obsolete = '0' AND p.income_accno_id > 0";

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
  
  
  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                 p.lastcost, p.unit, pg.partsgroup, p.partsgroup_id
		 FROM parts p
		 LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		 $where
		 |;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref;
  $form->{item_list} = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{item_list} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;

}


1;

