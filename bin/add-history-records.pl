#!/usr/bin/perl


use strict;
use FS::UID qw(adminsuidsetup);
use FS::Record qw(qsearchs qsearch);

use Data::Dumper;

my @tables = qw(svc_acct svc_broadband svc_domain svc_external svc_forward svc_www cust_svc domain_record);

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

    my $h_rec = qsearchs(
      $h_table,
      { $pkey => $rec->getfield($pkey) },
      eval "FS::${h_table}->sql_h_searchs(time)",
    );

    unless ($h_rec) {
      my $h_insert_rec = $rec->_h_statement('insert', 1);
      print $h_insert_rec . "\n";
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

sub usage {
  die "Usage:\n  add-history-records.pl user\n";
}

