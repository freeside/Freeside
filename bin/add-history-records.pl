#!/usr/bin/perl

die "This is broken.  Don't use it!\n";

use strict;
use FS::UID qw(adminsuidsetup);
use FS::Record qw(qsearchs qsearch);

use Data::Dumper;

my @tables = qw(svc_acct svc_broadband svc_domain svc_external svc_forward svc_www cust_svc domain_record);
#my @tables = qw(svc_www);

my $user = shift or die &usage;
my $dbh = adminsuidsetup($user);

my $dbdef = FS::Record::dbdef;

foreach my $table (@tables) {

  my $h_table = 'h_' . $table;
  my $cnt = 0;
  my $t_cnt = 0;

  eval "use FS::${table}";
  die $@ if $@;
  eval "use FS::${h_table}";
  die $@ if $@;

  print "Adding history records for ${table}...\n";

  my $dbdef_table = $dbdef->table($table);
  my $pkey = $dbdef_table->primary_key;

  foreach my $rec (qsearch($table, {})) {

    #my $h_rec = qsearchs(
    #  $h_table,
    #  { $pkey => $rec->getfield($pkey) },
    #  eval "FS::${h_table}->sql_h_searchs(time)",
    #);

    my $h_rec = qsearchs(
      $h_table,
      { $pkey => $rec->getfield($pkey) },
      "DISTINCT ON ( $pkey ) *",
      "AND history_action = 'insert' ORDER BY $pkey ASC, history_date DESC",
      '',
      'AS maintable',
    );

    unless ($h_rec) {
      my $h_insert_rec = $rec->_h_statement('insert', 1);
      #print $h_insert_rec . "\n";
      $dbh->do($h_insert_rec);
      die $dbh->errstr if $dbh->err;
      $dbh->commit or die $dbh->errstr;
      $cnt++;
    }


  $t_cnt++;

  }

  print "History records inserted into $h_table: $cnt\n";
  print "               Total records in $table: $t_cnt\n";

  print "\n";

}

foreach my $table (@tables) {

  my $h_table = 'h_' . $table;
  my $cnt = 0;

  eval "use FS::${table}";
  die $@ if $@;
  eval "use FS::${h_table}";
  die $@ if $@;

  print "Adding insert records for unmatched delete records on ${table}...\n";

  my $dbdef_table = $dbdef->table($table);
  my $pkey = $dbdef_table->primary_key;

  #SELECT * FROM h_svc_www
  #DISTINCT ON ( $pkey ) ?
  my $where = "
  WHERE ${pkey} in (
    SELECT ${h_table}1.${pkey}
      FROM ${h_table} as ${h_table}1
      WHERE (
        SELECT count(${h_table}2.${pkey})
	  FROM ${h_table} as ${h_table}2
	  WHERE ${h_table}2.${pkey} = ${h_table}1.${pkey}
	    AND ${h_table}2.history_action = 'delete'
      ) > 0
      AND (
        SELECT count(${h_table}3.${pkey})
	  FROM ${h_table} as ${h_table}3
	  WHERE ${h_table}3.${pkey} = ${h_table}1.${pkey}
	    AND ( ${h_table}3.history_action = 'insert'
	    OR ${h_table}3.history_action = 'replace_new' )
      ) = 0
      GROUP BY ${h_table}1.${pkey})";


  my @h_recs = qsearch(
    $h_table, { },
    "DISTINCT ON ( $pkey ) *",
    $where,
    '',
    ''
  );

  foreach my $h_rec (@h_recs) {
    #print "Adding insert record for deleted record with pkey='" . $h_rec->getfield($pkey) . "'...\n";
    my $class = 'FS::' . $table;
    my $rec = $class->new({ $h_rec->hash });
    my $h_insert_rec = $rec->_h_statement('insert', 1);
    #print $h_insert_rec . "\n";
    $dbh->do($h_insert_rec);
    die $dbh->errstr if $dbh->err;
    $dbh->commit or die $dbh->errstr;
    $cnt++;
  }

  print "History records inserted into $h_table: $cnt\n";

}



sub usage {
  die "Usage:\n  add-history-records.pl user\n";
}

