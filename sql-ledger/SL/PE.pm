#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2003
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
# Project module
# also used for partsgroups
#
#======================================================================

package PE;


sub projects {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{sort} = "projectnumber" unless $form->{sort};
  my @a = ($form->{sort});
  my %ordinal = ( projectnumber	=> 2,
                  description	=> 3 );
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  my $query = qq|SELECT id, projectnumber, description
                 FROM project
		 WHERE 1 = 1|;

  if ($form->{projectnumber}) {
    my $projectnumber = $form->like(lc $form->{projectnumber});
    $query .= " AND lower(projectnumber) LIKE '$projectnumber'";
  }
  if ($form->{projectdescription}) {
    my $description = $form->like(lc $form->{projectdescription});
    $query .= " AND lower(description) LIKE '$description'";
  }
  if ($form->{status} eq 'orphaned') {
    $query .= " AND id NOT IN (SELECT p.id
                               FROM project p, acc_trans a
			       WHERE p.id = a.project_id)
                AND id NOT IN (SELECT p.id
		               FROM project p, invoice i
			       WHERE p.id = i.project_id)
		AND id NOT IN (SELECT p.id
		               FROM project p, orderitems o
			       WHERE p.id = o.project_id)";
  }

  $query .= qq|
		 ORDER BY $sortorder|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $i = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{project_list} }, $ref;
    $i++;
  }

  $sth->finish;
  $dbh->disconnect;
  
  $i;

}


sub get_project {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my $query = qq|SELECT *
                 FROM project
	         WHERE id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # check if it is orphaned
  $query = qq|SELECT count(*)
              FROM acc_trans
	      WHERE project_id = $form->{id}
	   UNION
	      SELECT count(*)
	      FROM invoice
	      WHERE project_id = $form->{id}
	   UNION
	      SELECT count(*)
	      FROM orderitems
	      WHERE project_id = $form->{id}
	     |;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my ($count) = $sth->fetchrow_array) {
    $form->{orphaned} += $count;
  }
  $sth->finish;
  $form->{orphaned} = !$form->{orphaned};
  
  $dbh->disconnect;

}


sub save_project {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  if ($form->{id}) {
    $query = qq|UPDATE project SET
                projectnumber = |.$dbh->quote($form->{projectnumber}).qq|,
		description = |.$dbh->quote($form->{description}).qq|
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO project
                (projectnumber, description)
                VALUES (|
		.$dbh->quote($form->{projectnumber}).qq|, |
		.$dbh->quote($form->{description}).qq|)|;
  }
  $dbh->do($query) || $form->dberror($query);
  
  $dbh->disconnect;

}


sub partsgroups {
  my ($self, $myconfig, $form) = @_;
  
  my $var;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{sort} = "partsgroup" unless $form->{partsgroup};
  my @a = (partsgroup);
  my $sortorder = $form->sort_order(\@a);

  my $query = qq|SELECT g.*
                 FROM partsgroup g|;

  my $where = "1 = 1";
  
  if ($form->{partsgroup}) {
    $var = $form->like(lc $form->{partsgroup});
    $where .= " AND lower(partsgroup) LIKE '$var'";
  }
  $query .= qq|
               WHERE $where
	       ORDER BY $sortorder|;
  
  if ($form->{status} eq 'orphaned') {
    $query = qq|SELECT g.*
                FROM partsgroup g
                LEFT JOIN parts p ON (p.partsgroup_id = g.id)
		WHERE $where
                EXCEPT
                SELECT g.*
	        FROM partsgroup g
	        JOIN parts p ON (p.partsgroup_id = g.id)
	        WHERE $where
		ORDER BY $sortorder|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $i = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{item_list} }, $ref;
    $i++;
  }

  $sth->finish;
  $dbh->disconnect;
  
  $i;

}


sub save_partsgroup {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  if ($form->{id}) {
    $query = qq|UPDATE partsgroup SET
                partsgroup = |.$dbh->quote($form->{partsgroup}).qq|
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO partsgroup
                (partsgroup)
                VALUES (|.$dbh->quote($form->{partsgroup}).qq|)|;
  }
  $dbh->do($query) || $form->dberror($query);
  
  $dbh->disconnect;

}


sub get_partsgroup {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my $query = qq|SELECT *
                 FROM partsgroup
	         WHERE id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
 
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # check if it is orphaned
  $query = qq|SELECT count(*)
              FROM parts
	      WHERE partsgroup_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};
       
  $sth->finish;
  
  $dbh->disconnect;

}


sub pricegroups {
  my ($self, $myconfig, $form) = @_;
  
  my $var;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{sort} = "pricegroup" unless $form->{sort};
  my @a = (pricegroup);
  my $sortorder = $form->sort_order(\@a);

  my $query = qq|SELECT g.*
                 FROM pricegroup g|;

  my $where = "1 = 1";
  
  if ($form->{pricegroup}) {
    $var = $form->like(lc $form->{pricegroup});
    $where .= " AND lower(pricegroup) LIKE '$var'";
  }
  $query .= qq|
               WHERE $where
	       ORDER BY $sortorder|;
  
  if ($form->{status} eq 'orphaned') {
    $query = qq|SELECT g.*
                FROM pricegroup g
		WHERE $where
		AND g.id NOT IN (SELECT DISTINCT pricegroup_id
		                 FROM partscustomer)
		ORDER BY $sortorder|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $i = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{item_list} }, $ref;
    $i++;
  }

  $sth->finish;
  $dbh->disconnect;
  
  $i;

}


sub save_pricegroup {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  if ($form->{id}) {
    $query = qq|UPDATE pricegroup SET
                pricegroup = |.$dbh->quote($form->{pricegroup}).qq|
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO pricegroup
                (pricegroup)
                VALUES (|.$dbh->quote($form->{pricegroup}).qq|)|;
  }
  $dbh->do($query) || $form->dberror($query);
  
  $dbh->disconnect;

}


sub get_pricegroup {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my $query = qq|SELECT *
                 FROM pricegroup
	         WHERE id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
 
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # check if it is orphaned
  $query = qq|SELECT count(*)
              FROM partscustomer
	      WHERE pricegroup_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};
       
  $sth->finish;
  
  $dbh->disconnect;

}


sub delete_tuple {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
  
  $query = qq|DELETE FROM $form->{type}
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  if ($form->{type} !~ /pricegroup/) {
    $query = qq|DELETE FROM translation
		WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }
 
  $dbh->commit;
  $dbh->disconnect;

}


sub description_translations {
  my ($self, $myconfig, $form) = @_;

  my $where = "1 = 1\n";
  my $var;
  my $ref;
  
  map { $where .= "AND lower(p.$_) LIKE '".$form->like(lc $form->{$_})."'\n" if $form->{$_} } qw(partnumber description);
  
  $where .= " AND p.obsolete = '0'";
  $where .= " AND p.id = $form->{id}" if $form->{id};

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my %ordinal = ( 'partnumber' => 2,
                  'description' => 3
		);
  
  my @a = qw(partnumber description);
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  my $query = qq|SELECT l.description AS language, t.description AS translation,
                 l.code
                 FROM translation t
		 JOIN language l ON (l.code = t.language_code)
		 WHERE trans_id = ?
		 ORDER BY 1|;
  my $tth = $dbh->prepare($query);
  
  $query = qq|SELECT p.id, p.partnumber, p.description
	      FROM parts p
  	      WHERE $where
	      ORDER BY $sortorder|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $tra;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{translations} }, $ref;

    # get translations for description
    $tth->execute($ref->{id}) || $form->dberror;

    while ($tra = $tth->fetchrow_hashref(NAME_lc)) {
      $form->{trans_id} = $ref->{id};
      $tra->{id} = $ref->{id};
      push @{ $form->{translations} }, $tra;
    }

  }
  $sth->finish;

  &get_language("", $dbh, $form) if $form->{id};

  $dbh->disconnect;

}


sub partsgroup_translations {
  my ($self, $myconfig, $form) = @_;

  my $where = "1 = 1\n";
  my $ref;
  
  if ($form->{description}) {
    $where .= "AND lower(p.partsgroup) LIKE '".$form->like(lc $form->{description})."'";
  }
  $where .= " AND p.id = $form->{id}" if $form->{id};
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT l.description AS language, t.description AS translation,
                 l.code
                 FROM translation t
		 JOIN language l ON (l.code = t.language_code)
		 WHERE trans_id = ?
		 ORDER BY 1|;
  my $tth = $dbh->prepare($query);
  
  $form->sort_order();
  
  $query = qq|SELECT p.id, p.partsgroup AS description
	      FROM partsgroup p
  	      WHERE $where
	      ORDER BY 2 $form->{direction}|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $tra;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{translations} }, $ref;

    # get translations for partsgroup
    $tth->execute($ref->{id}) || $form->dberror;

    while ($tra = $tth->fetchrow_hashref(NAME_lc)) {
      $form->{trans_id} = $ref->{id};
      push @{ $form->{translations} }, $tra;
    }

  }
  $sth->finish;

  &get_language("", $dbh, $form) if $form->{id};

  $dbh->disconnect;

}


sub project_translations {
  my ($self, $myconfig, $form) = @_;

  my $where = "1 = 1\n";
  my $var;
  my $ref;
  
  map { $where .= "AND lower(p.$_) LIKE '".$form->like(lc $form->{$_})."'\n" if $form->{$_} } qw(projectnumber description);
  
  $where .= " AND p.id = $form->{id}" if $form->{id};

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my %ordinal = ( 'projectnumber' => 2,
                  'description' => 3
		);
  
  my @a = qw(projectnumber description);
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  my $query = qq|SELECT l.description AS language, t.description AS translation,
                 l.code
                 FROM translation t
		 JOIN language l ON (l.code = t.language_code)
		 WHERE trans_id = ?
		 ORDER BY 1|;
  my $tth = $dbh->prepare($query);
  
  $query = qq|SELECT p.id, p.projectnumber, p.description
	      FROM project p
  	      WHERE $where
	      ORDER BY $sortorder|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $tra;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{translations} }, $ref;

    # get translations for description
    $tth->execute($ref->{id}) || $form->dberror;

    while ($tra = $tth->fetchrow_hashref(NAME_lc)) {
      $form->{trans_id} = $ref->{id};
      $tra->{id} = $ref->{id};
      push @{ $form->{translations} }, $tra;
    }

  }
  $sth->finish;

  &get_language("", $dbh, $form) if $form->{id};

  $dbh->disconnect;

}


sub get_language {
  my ($self, $dbh, $form) = @_;
  
  # get language
  my $query = qq|SELECT *
	         FROM language
	         ORDER BY 2|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_language} }, $ref;
  }
  $sth->finish;

}


sub save_translation {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM translation
                 WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|INSERT INTO translation (trans_id, language_code, description)
              VALUES ($form->{id}, ?, ?)|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  foreach my $i (1 .. $form->{translation_rows}) {
    if ($form->{"language_code_$i"}) {
      $sth->execute($form->{"language_code_$i"}, $form->{"translation_$i"});
      $sth->finish;
    }
  }
  $dbh->commit;
  $dbh->disconnect;

}


sub delete_translation {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  $query = qq|DELETE FROM translation
	      WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  $dbh->disconnect;

}


1;

