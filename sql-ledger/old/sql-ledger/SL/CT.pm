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
# backend code for customers and vendors
#
# CHANGE LOG:
#   DS. 2000-07-04  Created
#
#======================================================================

package CT;


sub get_tuple {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);
  my $query = qq|SELECT *
                 FROM $form->{db}
                 WHERE id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my $ref = $sth->fetchrow_hashref(NAME_lc);
  
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;


  # get ship to
  $query = qq|SELECT *
              FROM shipto
	      WHERE trans_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;


  # get tax labels
  $query = qq|SELECT accno, description
              FROM chart, tax
	      WHERE link LIKE '%CT_tax%'
	      AND chart.id = tax.chart_id
	      ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxaccounts} .= "$ref->{accno} ";
    $form->{tax}{$ref->{accno}}{description} = $ref->{description};
  }
  $sth->finish;
  chop $form->{taxaccounts};

  # get taxes for customer/vendor
  $query = qq|SELECT chart_id, accno
              FROM $form->{db}tax, chart
              WHERE chart_id = chart.id
              AND $form->{db}_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{tax}{$ref->{accno}}{taxable} = 1;
  }
  $sth->finish;

  
  $dbh->disconnect;

}


sub taxaccounts {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  # get tax labels
  my $query = qq|SELECT accno, description
                 FROM chart, tax
		 WHERE link LIKE '%CT_tax%'
	         AND chart.id = tax.chart_id
		 ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $taxref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxaccounts} .= "$taxref->{accno} ";
    $form->{tax}{$taxref->{accno}}{description} = $taxref->{description};
  }
  $sth->finish;
  chop $form->{taxaccounts};

  $dbh->disconnect;

}


sub delete_customer {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|SELECT id FROM ar
                 WHERE customer_id = $form->{id}
		 UNION
		 SELECT id FROM oe
		 WHERE customer_id = $form->{id}|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;

  my ($rc) = $sth->fetchrow_array;
  $sth->finish;

  if ($rc) {
    $dbh->disconnect;
    $rc = -1;
  } else {
    
    # delete customer
    $query = qq|DELETE FROM customer
                WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
    
    $query = qq|DELETE FROM customertax
                WHERE customer_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    # commit and redirect
    $rc = $dbh->commit;
    $dbh->disconnect;
    
  }

  $rc;
  
}


sub save_customer {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # escape '
  map { $form->{$_} =~ s/'/''/g } qw(customernumber name addr1 addr2 addr3 addr4 contact notes);

  # assign value discount, terms, creditlimit
  $form->{discount} /= 100;
  $form->{terms} *= 1;
  $form->{taxincluded} *= 1;
  $form->{creditlimit} = $form->parse_amount($myconfig, $form->{creditlimit});
  
  my ($query, $sth);

  if ($form->{id}) {
    $query = qq|DELETE FROM customertax
                WHERE customer_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
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
		
  $query = qq|UPDATE customer SET
              customernumber = '$form->{customernumber}',
	      name = '$form->{name}',
	      addr1 = '$form->{addr1}',
	      addr2 = '$form->{addr2}',
	      addr3 = '$form->{addr3}',
	      addr4 = '$form->{addr4}',
	      contact = '$form->{contact}',
	      phone = '$form->{phone}',
	      fax = '$form->{fax}',
	      email = '$form->{email}',
	      cc = '$form->{cc}',
	      bcc = '$form->{bcc}',
	      notes = '$form->{notes}',
	      discount = $form->{discount},
	      creditlimit = $form->{creditlimit},
	      terms = $form->{terms},
	      taxincluded = '$form->{taxincluded}'
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

  $dbh->disconnect;

}


sub save_vendor {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # escape '
  map { $form->{$_} =~ s/'/''/g } qw(vendornumber name addr1 addr2 addr3 addr4 contact notes);

  $form->{terms} *= 1;
  $form->{taxincluded} *= 1;
  
  my $query;
  
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
   

  $query = qq|UPDATE vendor SET
              vendornumber = '$form->{vendornumber}',
	      name = '$form->{name}',
	      addr1 = '$form->{addr1}',
	      addr2 = '$form->{addr2}',
	      addr3 = '$form->{addr3}',
	      addr4 = '$form->{addr4}',
	      contact = '$form->{contact}',
	      phone = '$form->{phone}',
	      fax = '$form->{fax}',
	      email = '$form->{email}',
	      cc = '$form->{cc}',
	      bcc = '$form->{bcc}',
	      notes = '$form->{notes}',
	      terms = $form->{terms},
	      taxincluded = '$form->{taxincluded}'
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

  $dbh->disconnect;

}



sub delete_vendor {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  # check if there are any transactions on file
  my $query = qq|SELECT id FROM ap
                 WHERE vendor_id = $form->{id}
		 UNION
		 SELECT id FROM oe
		 WHERE vendor_id = $form->{id}|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute;
  
  my ($rc) = $sth->fetchrow_array;
  $sth->finish;
  
  if ($rc) {
    $dbh->disconnect;
    $rc = -1;
  } else {
    
    # delete vendor
    $query = qq|DELETE FROM vendor
                WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM vendortax
                WHERE vendor_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    # commit and redirect
    $rc = $dbh->commit;
    $dbh->disconnect;

  }

  $rc;

}


sub search {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where = "1 = 1";
  $form->{sort} = "name" unless ($form->{sort});
  
  if ($form->{"$form->{db}number"}) {
    my $companynumber = $form->like(lc $form->{"$form->{db}number"});
    $where .= " AND lower($form->{db}number) LIKE '$companynumber'";
  }
  if ($form->{name}) {
    my $name = $form->like(lc $form->{name});
    $where .= " AND lower(name) LIKE '$name'";
  }
  if ($form->{contact}) {
    my $contact = $form->like(lc $form->{contact});
    $where .= " AND lower(contact) LIKE '$contact'";
  }
  if ($form->{email}) {
    my $email = $form->like(lc $form->{email});
    $where .= " AND lower(email) LIKE '$email'";
  }

  if ($form->{status} eq 'orphaned') {
    $where .= qq| AND id NOT IN (SELECT o.$form->{db}_id
                                 FROM oe o, $form->{db} ct
		 	         WHERE ct.id = o.$form->{db}_id)|;
    if ($form->{db} eq 'customer') {
      $where .= qq| AND id NOT IN (SELECT a.customer_id
                                   FROM ar a, customer ct
				   WHERE ct.id = a.customer_id)|;
    }
    if ($form->{db} eq 'vendor') {
      $where .= qq| AND id NOT IN (SELECT a.vendor_id
                                   FROM ap a, vendor ct
				   WHERE ct.id = a.vendor_id)|;
    }
  }
  
  my $query = qq~SELECT id, name, $form->{db}number, 
                 addr1 || ' ' || addr2 || ' ' || addr3 || ' ' || addr4 AS address,
                 contact, phone, fax, email, cc, terms
                 FROM $form->{db}
                 WHERE $where
		 ORDER BY $form->{sort}~;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);


  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{CT} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

}


1;

