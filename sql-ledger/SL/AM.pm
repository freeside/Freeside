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
# Administration module
#    Chart of Accounts
#    template routines
#    preferences
#
#======================================================================

package AM;


sub get_account {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT accno, description, charttype, gifi_accno,
                 category, link
                 FROM chart
	         WHERE id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  
  foreach my $key (keys %$ref) {
    $form->{"$key"} = $ref->{"$key"};
  }

  $sth->finish;


  # get default accounts
  $query = qq|SELECT inventory_accno_id, income_accno_id, expense_accno_id
              FROM defaults|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %ref;

  $sth->finish;
  $dbh->disconnect;

}


sub save_account {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  # sanity check, can't have AR with AR_...
  if ($form->{AR} || $form->{AP} || $form->{IC}) {
    map { delete $form->{$_} } qw(AR_amount AR_tax AR_paid AP_amount AP_tax AP_paid IC_sale IC_cogs IC_taxpart IC_income IC_expense IC_taxservice);
  }
  
  $form->{link} = "";
  foreach my $item ($form->{AR},
		    $form->{AR_amount},
                    $form->{AR_tax},
                    $form->{AR_paid},
                    $form->{AP},
		    $form->{AP_amount},
		    $form->{AP_tax},
		    $form->{AP_paid},
		    $form->{IC},
		    $form->{IC_sale},
		    $form->{IC_cogs},
		    $form->{IC_taxpart},
		    $form->{IC_income},
		    $form->{IC_expense},
		    $form->{IC_taxservice},
		    $form->{CT_tax}
		    ) {
     $form->{link} .= "${item}:" if ($item);
  }
  chop $form->{link};

  # if we have an id then replace the old record
  $form->{description} =~ s/'/''/g;

  # strip blanks from accno
  map { $form->{$_} =~ s/ //g; } qw(accno gifi_accno);
  
  my ($query, $sth);
  
  if ($form->{id}) {
    $query = qq|UPDATE chart SET
                accno = '$form->{accno}',
		description = '$form->{description}',
		charttype = '$form->{charttype}',
		gifi_accno = '$form->{gifi_accno}',
		category = '$form->{category}',
		link = '$form->{link}'
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO chart 
                (accno, description, charttype, gifi_accno, category, link)
                VALUES ('$form->{accno}', '$form->{description}',
		'$form->{charttype}', '$form->{gifi_accno}',
		'$form->{category}', '$form->{link}')|;
  }
  $dbh->do($query) || $form->dberror($query);
  

  if ($form->{IC_taxpart} || $form->{IC_taxservice} || $form->{CT_tax}) {

    my $chart_id = $form->{id};
    
    unless ($form->{id}) {
      # get id from chart
      $query = qq|SELECT id
                  FROM chart
		  WHERE accno = '$form->{accno}'|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      ($chart_id) = $sth->fetchrow_array;
      $sth->finish;
    }
    
    # add account if it doesn't exist in tax
    $query = qq|SELECT chart_id
                FROM tax
		WHERE chart_id = $chart_id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my ($tax_id) = $sth->fetchrow_array;
    $sth->finish;
    
    # add tax if it doesn't exist
    unless ($tax_id) {
      $query = qq|INSERT INTO tax (chart_id, rate)
                  VALUES ($chart_id, 0)|;
      $dbh->do($query) || $form->dberror($query);
    }
  } else {
    # remove tax
    if ($form->{id}) {
      $query = qq|DELETE FROM tax
		  WHERE chart_id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);
    }
  }


  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}



sub delete_account {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  # delete chart of account record
  $query = qq|DELETE FROM chart
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # set inventory_accno_id, income_accno_id, expense_accno_id to defaults
  $query = qq|UPDATE parts
              SET inventory_accno_id = 
	                 (SELECT inventory_accno_id FROM defaults)
	      WHERE inventory_accno_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  $query = qq|UPDATE parts
              SET income_accno_id =
	                 (SELECT income_accno_id FROM defaults)
	      WHERE income_accno_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  $query = qq|UPDATE parts
              SET expense_accno_id =
	                 (SELECT expense_accno_id FROM defaults)
	      WHERE expense_accno_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  foreach my $table (qw(partstax customertax vendortax tax)) {
    $query = qq|DELETE FROM $table
		WHERE chart_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;
  
  $rc;

}


sub gifi_accounts {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT accno, description
                 FROM gifi
		 ORDER BY accno|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;
  
}



sub get_gifi {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my $query = qq|SELECT accno, description
                 FROM gifi
	         WHERE accno = '$form->{accno}'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  $dbh->disconnect;

}


sub save_gifi {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  $form->{description} =~ s/'/''/g;
  $form->{accno} =~ s/ //g;

  # id is the old account number!
  if ($form->{id}) {
    $query = qq|UPDATE gifi SET
                accno = '$form->{accno}',
		description = '$form->{description}'
		WHERE accno = '$form->{id}'|;
  } else {
    $query = qq|INSERT INTO gifi 
                (accno, description)
                VALUES ('$form->{accno}', '$form->{description}')|;
  }
  $dbh->do($query) || $form->dberror($query);
  
  $dbh->disconnect;

}


sub delete_gifi {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  # id is the old account number!
  $query = qq|DELETE FROM gifi
	      WHERE accno = '$form->{id}'|;
  $dbh->do($query) || $form->dberror($query);
  
  $dbh->disconnect;

}


sub load_template {
  my ($self, $form) = @_;
  
  open(TEMPLATE, "$form->{file}") or $form->error("$form->{file} : $!");

  while (<TEMPLATE>) {
    $form->{body} .= $_;
  }

  close(TEMPLATE);

}


sub save_template {
  my ($self, $form) = @_;
  
  open(TEMPLATE, ">$form->{file}") or $form->error("$form->{file} : $!");
  
  # strip 
  $form->{body} =~ s/\r\n/\n/g;
  print TEMPLATE $form->{body};

  close(TEMPLATE);

}



sub save_preferences {
  my ($self, $myconfig, $form, $memberfile, $userspath) = @_;

  map { ($form->{$_}) = split /--/, $form->{$_} } qw(inventory_accno income_accno expense_accno fxgain_accno fxloss_accno);
  
  my @a;
  $form->{curr} =~ s/ //g;
  map { push(@a, uc pack "A3", $_) if $_ } split /:/, $form->{curr};
  $form->{curr} = join ':', @a;
    
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
  
  # these defaults are database wide
  # user specific variables are in myconfig
  # save defaults
  my $query = qq|UPDATE defaults SET
                 inventory_accno_id = 
		     (SELECT id FROM chart
		                WHERE accno = '$form->{inventory_accno}'),
                 income_accno_id =
		     (SELECT id FROM chart
		                WHERE accno = '$form->{income_accno}'),
	         expense_accno_id =
		     (SELECT id FROM chart
		                WHERE accno = '$form->{expense_accno}'),
	         fxgain_accno_id =
		     (SELECT id FROM chart
		                WHERE accno = '$form->{fxgain_accno}'),
	         fxloss_accno_id =
		     (SELECT id FROM chart
		                WHERE accno = '$form->{fxloss_accno}'),
	         invnumber = '$form->{invnumber}',
	         sonumber = '$form->{sonumber}',
	         ponumber = '$form->{ponumber}',
		 yearend = '$form->{yearend}',
		 curr = '$form->{curr}',
		 weightunit = '$form->{weightunit}',
		 businessnumber = '$form->{businessnumber}'
		|;
  $dbh->do($query) || $form->dberror($query);

  # update name
  my $name = $form->{name};
  $name =~ s/'/''/g;
  $query = qq|UPDATE employee
              SET name = '$name'
	      WHERE login = '$form->{login}'|;
  $dbh->do($query) || $form->dberror($query);
  
  foreach my $item (split / /, $form->{taxaccounts}) {
    $query = qq|UPDATE tax
		SET rate = |.($form->{$item} / 100).qq|,
		taxnumber = '$form->{"taxnumber_$item"}'
		WHERE chart_id = $item|;
    $dbh->do($query) || $form->dberror($query);
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  # save first currency in myconfig
  $form->{currency} = substr($form->{curr},0,3);
  
  my $myconfig = new User "$memberfile", "$form->{login}";
  
  foreach my $item (keys %$form) {
    $myconfig->{$item} = $form->{$item};
  }

  $myconfig->save_member($memberfile, $userspath);

  $rc;
  
}


sub defaultaccounts {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  # get defaults from defaults table
  my $query = qq|SELECT * FROM defaults|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  $form->{defaults} = $sth->fetchrow_hashref(NAME_lc);
  $form->{defaults}{IC} = $form->{defaults}{inventory_accno_id};
  $form->{defaults}{IC_income} = $form->{defaults}{income_accno_id};
  $form->{defaults}{IC_expense} = $form->{defaults}{expense_accno_id};
  $form->{defaults}{FX_gain} = $form->{defaults}{fxgain_accno_id};
  $form->{defaults}{FX_loss} = $form->{defaults}{fxloss_accno_id};
  
  
  $sth->finish;


  $query = qq|SELECT id, accno, description, link
              FROM chart
              WHERE link LIKE '%IC%'
              ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /IC/) {
	$nkey = $key;
	if ($key =~ /cogs/) {
	  $nkey = "IC_expense";
	}
	if ($key =~ /sale/) {
	  $nkey = "IC_income";
	}
        %{ $form->{IC}{$nkey}{$ref->{accno}} } = ( id => $ref->{id},
                                        description => $ref->{description} );
      }
    }
  }
  $sth->finish;


  $query = qq|SELECT id, accno, description
              FROM chart
	      WHERE category = 'I'
	      AND charttype = 'A'
              ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    %{ $form->{IC}{FX_gain}{$ref->{accno}} } = ( id => $ref->{id},
                                      description => $ref->{description} );
  }
  $sth->finish;

  $query = qq|SELECT id, accno, description
              FROM chart
	      WHERE category = 'E'
	      AND charttype = 'A'
              ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    %{ $form->{IC}{FX_loss}{$ref->{accno}} } = ( id => $ref->{id},
                                      description => $ref->{description} );
  }
  $sth->finish;


  # now get the tax rates and numbers
  $query = qq|SELECT chart.id, chart.accno, chart.description,
              tax.rate * 100 AS rate, tax.taxnumber
              FROM chart, tax
	      WHERE chart.id = tax.chart_id|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxrates}{$ref->{accno}}{id} = $ref->{id};
    $form->{taxrates}{$ref->{accno}}{description} = $ref->{description};
    $form->{taxrates}{$ref->{accno}}{taxnumber} = $ref->{taxnumber} if $ref->{taxnumber};
    $form->{taxrates}{$ref->{accno}}{rate} = $ref->{rate} if $ref->{rate};
  }

  $sth->finish;
  $dbh->disconnect;
  
}


sub backup {
  my ($self, $myconfig, $form, $userspath) = @_;
  
  my ($tmpfile, $out, $mail);
  
  if ($form->{media} eq 'email') {

    my $boundary = time;
    $tmpfile = "$userspath/$boundary.$myconfig->{dbname}-$form->{dbversion}.sql";
    $out = $form->{OUT};
    $form->{OUT} = ">$tmpfile";
    
    use SL::Mailer;
    $mail = new Mailer;

    $mail->{to} = qq|"$myconfig->{name}" <$myconfig->{email}>|;
    $mail->{from} = qq|"$myconfig->{name}" <$myconfig->{email}>|;
    $mail->{subject} = "SQL-Ledger Backup / $myconfig->{dbname}-$form->{dbversion}.sql";
    @{ $mail->{attachments} } = ($tmpfile);
    $mail->{version} = $form->{version};
    $mail->{fileid} = "$boundary.";

    $myconfig->{signature} =~ s/\\n/\r\n/g;
    $mail->{message} = "--\n$myconfig->{signature}";
    
  }
    
  if ($form->{OUT}) {
    open(OUT, "$form->{OUT}") or $form->error("$form->{OUT} : $!");
  } else {
    open(OUT, ">-") or $form->error("STDOUT : $!");
  }

  if ($form->{media} eq 'file') {
    print OUT qq|Content-Type: Application/File;
Content-Disposition: filename="$myconfig->{dbname}-$form->{dbversion}.sql"\n\n|;
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get all the tables
  my @tables = $dbh->tables;
  
  my $today = scalar localtime;
  

  $myconfig->{dbhost} = 'localhost' unless $myconfig->{dbhost};
  
  print OUT qq|-- SQL-Ledger Backup
-- Dataset: $myconfig->{dbname}
-- Version: $form->{dbversion}
-- Host: $myconfig->{dbhost}
-- Login: $form->{login}
-- User: $myconfig->{name}
-- Date: $today
--
-- set options
$myconfig->{dboptions};
--
|;

  foreach $table (@tables) {
    my $query = qq|SELECT * FROM $table|;
    
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $query = qq|INSERT INTO $table (|;
    map { $query .= qq|$sth->{NAME}->[$_],| } (0 .. $sth->{NUM_OF_FIELDS} - 1);
    chop $query;

    $query .= qq|) VALUES|;
    
    print OUT qq|--
DELETE FROM $table;
|;
    while (my @arr = $sth->fetchrow_array) {

      $fields = "(";
      foreach my $item (@arr) {
	if (defined $item) {
	  $item =~ s/'/''/g;
	  $fields .= qq|'$item',|;
	} else {
	  $fields .= 'NULL,';
	}
      }
	
      chop $fields;
      $fields .= ")";
	
      print OUT qq|$query $fields;\n|;
    }
    
    $sth->finish;
  }

  $query = qq|SELECT last_value FROM id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my ($id) = $sth->fetchrow_array;
  $sth->finish;
  
  print OUT qq|--
DROP SEQUENCE id;
CREATE SEQUENCE id START $id;
|;
  
  close(OUT);
  
  $dbh->disconnect;

  if ($form->{media} eq 'email') {
    my $err = $mail->send($out);
    $_ = $tmpfile;
    unlink;
  }
    
}


sub closedto {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT closedto, revtrans FROM defaults|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{closedto}, $form->{revtrans}) = $sth->fetchrow_array;
  
  $sth->finish;
  
  $dbh->disconnect;

}

 
sub closebooks {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  if ($form->{revtrans}) {
   
    $query = qq|UPDATE defaults SET closedto = NULL,
				    revtrans = '1'|;
  } else {
    if ($form->{closedto}) {
    
      $query = qq|UPDATE defaults SET closedto = '$form->{closedto}',
				      revtrans = '0'|;
    } else {
      
      $query = qq|UPDATE defaults SET closedto = NULL,
				      revtrans = '0'|;
    }
  }

  # set close in defaults
  $dbh->do($query) || $form->dberror($query);
  
  $dbh->disconnect;
  
}


1;

