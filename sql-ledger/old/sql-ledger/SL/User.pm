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
#=====================================================================
#
# user related functions
#
#=====================================================================

package User;


sub new {
  my ($type, $memfile, $login) = @_;
  my $self = {};

  if ($login ne "") {
    # check if the file is locked
    &error("", "$memfile locked!") if (-f "${memfile}.LCK");
    
    open(MEMBER, "$memfile") or &error("", "$memfile : $!");
    
    while (<MEMBER>) {
      if (/^\[$login\]/) {
	while (<MEMBER>) {
	  last if /^\[/;
	  next if /^(#|\s)/;
	  
	  # remove comments
	  s/\s#.*//g;

	  # remove any trailing whitespace
	  s/^\s*(.*?)\s*$/$1/;

	  ($key, $value) = split /=/, $_, 2;
	  
	  $self->{$key} = $value;
	}
	
	$self->{login} = $login;

	last;
      }
    }
    close MEMBER;
  }
  
  bless $self, $type;
}


sub country_codes {

  my %cc = ();
  my @language = ();
  
  # scan the locale directory and read in the LANGUAGE files
  opendir DIR, "locale";

  my @dir = grep !/(^\.\.?$|\..*)/, readdir DIR;
  
  foreach my $dir (@dir) {
    next unless open(FH, "locale/$dir/LANGUAGE");
    @language = <FH>;
    close FH;

    $cc{$dir} = "@language";
  }

  closedir(DIR);
  
  %cc;

}


sub login {
  my ($self, $form, $userspath) = @_;


  if ($self->{login}) {
    
    if ($self->{password}) {
      $form->{password} = crypt $form->{password}, substr($self->{login}, 0, 2);
      if ($self->{password} ne $form->{password}) {
	return -1;
      }
    }
    
    unless (-e "$userspath/$self->{login}.conf") {
      $self->create_config("$userspath/$self->{login}.conf");
    }
    
    do "$userspath/$self->{login}.conf";
    $myconfig{dbpasswd} = unpack 'u', $myconfig{dbpasswd};
  
    # check if database is down
    my $dbh = DBI->connect($myconfig{dbconnect}, $myconfig{dbuser}, $myconfig{dbpasswd}) or $self->error(DBI::errstr);

    # we got a connection, check the version
    my $query = qq|SELECT version FROM defaults|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my ($dbversion) = $sth->fetchrow_array;
    $sth->finish;

    # add login to employee table if it does not exist
    # no error check for employee table, ignore if it does not exist
    $query = qq|SELECT id FROM employee WHERE login = '$self->{login}'|;
    $sth = $dbh->prepare($query);
    $sth->execute;

    my ($login) = $sth->fetchrow_array;
    $sth->finish;

    if (!$login) {
      $query = qq|INSERT INTO employee (login, name, workphone)
                  VALUES ('$self->{login}', '$myconfig{name}', '$myconfig{tel}')|;
      $dbh->do($query);
    }
    $dbh->disconnect;

    if ($form->{dbversion} ne $dbversion) {
      return -2;
    }

  } else {
    return -3;
  }

}



sub dbconnect_vars {
  my ($form, $db) = @_;
  
  my %dboptions = (
     'Pg' => {
        'yy-mm-dd' => 'set DateStyle to \'ISO\'',
	'mm/dd/yy' => 'set DateStyle to \'SQL, US\'',
	'mm-dd-yy' => 'set DateStyle to \'POSTGRES, US\'',
	'dd/mm/yy' => 'set DateStyle to \'SQL, EUROPEAN\'',
	'dd-mm-yy' => 'set DateStyle to \'POSTGRES, EUROPEAN\'',
	'dd.mm.yy' => 'set DateStyle to \'GERMAN\''
	     },
     'Oracle' => {
	'yy-mm-dd' => 'ALTER SESSION SET NLS_DATE_FORMAT = \'YY-MM-DD\'',
	'mm/dd/yy' => 'ALTER SESSION SET NLS_DATE_FORMAT = \'MM/DD/YY\'',
	'mm-dd-yy' => 'ALTER SESSION SET NLS_DATE_FORMAT = \'MM-DD-YY\'',
	'dd/mm/yy' => 'ALTER SESSION SET NLS_DATE_FORMAT = \'DD/MM/YY\'',
	'dd-mm-yy' => 'ALTER SESSION SET NLS_DATE_FORMAT = \'DD-MM-YY\'',
	'dd.mm.yy' => 'ALTER SESSION SET NLS_DATE_FORMAT = \'DD.MM.YY\'',
	         }
     );
			     
  $form->{dboptions} = $dboptions{$form->{dbdriver}}{$form->{dateformat}};

  if ($form->{dbdriver} eq 'Pg') {
    $form->{dbconnect} = "dbi:Pg:dbname=$db";
  }

  if ($form->{dbdriver} eq 'Oracle') {
    $form->{dbconnect} = "dbi:Oracle:sid=$form->{sid}";
  }

  if ($form->{dbhost}) {
    $form->{dbconnect} .= ";host=$form->{dbhost}";
  }
  if ($form->{dbport}) {
    $form->{dbconnect} .= ";port=$form->{dbport}";
  }
  
}


sub dbdrivers {

  my @drivers = DBI->available_drivers();

  return (grep { /(Pg|Oracle)$/ } @drivers);

}


sub dbsources {
  my ($self, $form) = @_;

  my @dbsources = ();
  my ($sth, $query);
  
  $form->{dbdefault} = $form->{dbuser} unless $form->{dbdefault};
  $form->{sid} = $form->{dbdefault};
  &dbconnect_vars($form, $form->{dbdefault});

  my $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) or $form->dberror;


  if ($form->{dbdriver} eq 'Pg') {

    $query = qq|SELECT datname FROM pg_database|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    
    while (my ($db) = $sth->fetchrow_array) {

      if ($form->{only_acc_db}) {
	
	next if ($db =~ /^template/);

	&dbconnect_vars($form, $db);
	my $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) or $form->dberror;

	$query = qq|SELECT tablename FROM pg_tables
		    WHERE tablename = 'defaults'
		    AND tableowner = '$form->{dbuser}'|;
	my $sth = $dbh->prepare($query);
	$sth->execute || $form->dberror($query);

	if ($sth->fetchrow_array) {
	  push @dbsources, $db;
	}
	$sth->finish;
	$dbh->disconnect;
	next;
      }
      push @dbsources, $db;
    }
  }

  if ($form->{dbdriver} eq 'Oracle') {
    if ($form->{only_acc_db}) {
      $query = qq|SELECT owner FROM dba_objects
		  WHERE object_name = 'DEFAULTS'
		  AND object_type = 'TABLE'|;
    } else {
      $query = qq|SELECT username FROM dba_users|;
    }

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my ($db) = $sth->fetchrow_array) {
      push @dbsources, $db;
    }
  }

  $sth->finish;
  $dbh->disconnect;
  
  return @dbsources;

}


sub dbcreate {
  my ($self, $form) = @_;

  my %dbcreate = ( 'Pg' => qq|CREATE DATABASE "$form->{db}"|,
               'Oracle' => qq|CREATE USER "$form->{db}" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP IDENTIFIED BY "$form->{db}"|);

  $dbcreate{Pg} .= " WITH ENCODING = '$form->{encoding}'" if $form->{encoding};
  
  $form->{sid} = $form->{dbdefault};
  &dbconnect_vars($form, $form->{dbdefault});
  my $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) or $form->dberror;
  my $query = qq|$dbcreate{$form->{dbdriver}}|;
  $dbh->do($query) || $form->dberror($query);

  if ($form->{dbdriver} eq 'Oracle') {
    $query = qq|GRANT CONNECT,RESOURCE TO "$form->{db}"|;
    $dbh->do($query) || $form->dberror($query);
  }
  $dbh->disconnect;


  # setup variables for the new database
  if ($form->{dbdriver} eq 'Oracle') {
    $form->{dbuser} = $form->{db};
    $form->{dbpasswd} = $form->{db};
  }
  
  
  &dbconnect_vars($form, $form->{db});
  
  $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) or $form->dberror;
  
  # create the tables
  my $filename = qq|sql/$form->{dbdriver}-tables.sql|;
  $self->processquery($form, $dbh, $filename);

  # load gifi
  ($filename) = split /_/, $form->{chart};
  $filename =~ s/_//;
  $self->processquery($form, $dbh, "sql/${filename}-gifi.sql");

  # load chart of accounts
  $filename = qq|sql/$form->{chart}-chart.sql|;
  $self->processquery($form, $dbh, $filename);

  # create indices
  $filename = qq|sql/$form->{dbdriver}-indices.sql|;
  $self->processquery($form, $dbh, $filename);
  
  $dbh->disconnect;

}



sub processquery {
  my ($self, $form, $dbh, $filename) = @_;
  
  return unless (-f $filename);
  
  open(FH, "$filename") or $form->error("$filename : $!\n");
  my $query = "";
  
  while (<FH>) {
    $query .= $_;

    if (/;\s*$/) {
      # strip ;... Oracle doesn't like it
      $query =~ s/;\s*$//;
      $dbh->do($query) || $form->dberror($query);
      $query = "";
    }
  }
  close FH;

}
  


sub dbdelete {
  my ($self, $form) = @_;

  my %dbdelete = ( 'Pg' => qq|DROP DATABASE "$form->{db}"|,
               'Oracle' => qq|DROP USER $form->{db} CASCADE|
	         );
  
  $form->{sid} = $form->{dbdefault};
  &dbconnect_vars($form, $form->{dbdefault});
  my $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) or $form->dberror;
  my $query = qq|$dbdelete{$form->{dbdriver}}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

}
  


sub dbsources_unused {
  my ($self, $form, $memfile) = @_;

  my @dbexcl = ();
  my @dbsources = ();
  
  $form->error('File locked!') if (-f "${memfile}.LCK");
  
  # open members file
  open(FH, "$memfile") or $form->error("$memfile : $!");

  while (<FH>) {
    if (/^dbname=/) {
      my ($null,$item) = split /=/;
      push @dbexcl, $item;
    }
  }

  close FH;

  $form->{only_acc_db} = 1;
  my @db = &dbsources("", $form);

  push @dbexcl, $form->{dbdefault};

  foreach $item (@db) {
    unless (grep /$item$/, @dbexcl) {
      push @dbsources, $item;
    }
  }

  return @dbsources;

}


sub dbneedsupdate {
  my ($self, $form) = @_;

  my %dbsources = ();
  my $query;
  
  $form->{sid} = $form->{dbdefault};
  &dbconnect_vars($form, $form->{dbdefault});

  my $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) or $form->dberror;

  if ($form->{dbdriver} eq 'Pg') {

    $query = qq|SELECT d.datname FROM pg_database d, pg_user u
                WHERE d.datdba = u.usesysid
		AND u.usename = '$form->{dbuser}'|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    
    while (my ($db) = $sth->fetchrow_array) {

      next if ($db =~ /^template/);

      &dbconnect_vars($form, $db);
      
      my $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) or $form->dberror;

      $query = qq|SELECT tablename FROM pg_tables
		  WHERE tablename = 'defaults'|;
      my $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      if ($sth->fetchrow_array) {
	$query = qq|SELECT version FROM defaults|;
	my $sth = $dbh->prepare($query);
	$sth->execute;
	
	if (my ($version) = $sth->fetchrow_array) {
	  $dbsources{$db} = $version;
	}
	$sth->finish;
      }
      $sth->finish;
      $dbh->disconnect;
    }
    $sth->finish;
  }


  if ($form->{dbdriver} eq 'Oracle') {
    $query = qq|SELECT owner FROM dba_objects
		WHERE object_name = 'DEFAULTS'
		AND object_type = 'TABLE'|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my ($db) = $sth->fetchrow_array) {
      
      $form->{dbuser} = $db;
      &dbconnect_vars($form, $db);
      
      my $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) or $form->dberror;

      $query = qq|SELECT version FROM defaults|;
      my $sth = $dbh->prepare($query);
      $sth->execute;
      
      if (my ($version) = $sth->fetchrow_array) {
	$dbsources{$db} = $version;
      }
      $sth->finish;
      $dbh->disconnect;
    }
    $sth->finish;
  }
  
  $dbh->disconnect;
  
  %dbsources;

}


sub dbupdate {
  my ($self, $form) = @_;

  $form->{sid} = $form->{dbdefault};
  
  my @upgradescripts = ();
  my $query;
  
  if ($form->{dbupdate}) {
    # read update scripts into memory
    opendir SQLDIR, "sql/." or $form-error($!);
    @upgradescripts = sort grep /$form->{dbdriver}-upgrade-.*?\.sql/, readdir SQLDIR;
    closedir SQLDIR;
  }

  
  foreach my $db (split / /, $form->{dbupdate}) {

    next unless $form->{$db};

    # strip db from dataset
    $db =~ s/^db//;
    &dbconnect_vars($form, $db);

    my $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}) or $form->dberror;

    # check version
    $query = qq|SELECT version FROM defaults|;
    my $sth = $dbh->prepare($query);
    # no error check, let it fall through
    $sth->execute;

    my $version = $sth->fetchrow_array;
    $sth->finish;
    
    next unless $version;

    foreach my $upgradescript (@upgradescripts) {
      my $a = $upgradescript;
      $a =~ s/(^$form->{dbdriver}-upgrade-|\.sql$)//g;
      
      my ($mindb, $maxdb) = split /-/, $a;

      next if ($version ge $maxdb);

      # if there is no upgrade script exit
      last if ($version lt $mindb);

      # apply upgrade
      $self->processquery($form, $dbh, "sql/$upgradescript");

      $version = $maxdb;
 
    }
    
    $dbh->disconnect;
    
  }
}
  


sub create_config {
  my ($self, $filename) = @_;


  @config = &config_vars;
  
  open(CONF, ">$filename") or $self->error("$filename : $!");
  
  # create the config file
  print CONF qq|# configuration file for $self->{login}

\%myconfig = (
|;

  foreach $key (sort @config) {
    $self->{$key} =~ s/'/\\'/g;
    print CONF qq|  $key => '$self->{$key}',\n|;
  }

   
  print CONF qq|);\n\n|;

  close CONF;

}


sub save_member {
  my ($self, $memberfile, $userspath) = @_;

  my $newmember = 1;
  
  # format dbconnect and dboptions string
  map { $self->{$_} = lc $self->{$_} } qw(dbname host);
  &dbconnect_vars($self, $self->{dbname});
  
  $self->error('File locked!') if (-f "${memberfile}.LCK");
  open(FH, ">${memberfile}.LCK") or $self->error("${memberfile}.LCK : $!");
  close(FH);
  
  open(CONF, "+<$memberfile") or $self->error("$memberfile : $!");
  
  @config = <CONF>;
  
  seek(CONF, 0, 0);
  truncate(CONF, 0);
  
  while ($line = shift @config) {
    if ($line =~ /^\[$self->{login}\]/) {
      $newmember = 0;
      last;
    }
    print CONF $line;
  }

  # remove everything up to next login or EOF
  while ($line = shift @config) {
    last if ($line =~ /^\[/);
  }

  # this one is either the next login or EOF
  print CONF $line;

  while ($line = shift @config) {
    print CONF $line;
  }

  print CONF qq|[$self->{login}]\n|;
  
  if ((($self->{dbpasswd} ne $self->{old_dbpasswd}) || $newmember) && $self->{root}) {
    $self->{dbpasswd} = pack 'u', $self->{dbpasswd};
    chop $self->{dbpasswd};
  }
  
  if ($self->{password} ne $self->{old_password}) {
    $self->{password} = crypt $self->{password}, substr($self->{login}, 0, 2) if $self->{password};
  }
  
  if ($self->{'root login'}) {
    @config = ("password");
  } else {
    @config = &config_vars;
  }
  
  # replace \r\n with \n
  $self->{address} =~ s/\r\n/\\n/g if $self->{address};
  $self->{signature} =~ s/\r\n/\\n/g if $self->{signature};

  foreach $key (sort @config) {
    print CONF qq|$key=$self->{$key}\n|;
  }

  print CONF "\n";
  close CONF;
  unlink "${memberfile}.LCK";
  
  # create conf file
  $self->create_config("$userspath/$self->{login}.conf") unless $self->{'root login'};
 
}


sub config_vars {
  
  my @conf = qw(acs address admin businessnumber charset company countrycode
             currency dateformat dbconnect dbdriver dbhost dbport dboptions
	     dbname dbuser dbpasswd email fax name numberformat password
	     printer sid shippingpoint signature stylesheet tel templates
	     vclimit);

  @conf;

}


sub error {
  my ($self, $msg) = @_;

  if ($ENV{HTTP_USER_AGENT}) {
    print qq|Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">

<body bgcolor=ffffff>

<h2><font color=red>Error!</font></h2>
<p><b>$msg</b>|;

  }
  
  die "Error: $msg\n";
  
}


1;

