#!/usr/bin/perl


use strict;
use FS::UID qw(adminsuidsetup);
use FS::Record qw(qsearchs qsearch);
use FS::svc_domain;
use FS::h_svc_domain;
use FS::domain_record;
use FS::h_domain_record;

use Data::Dumper;

adminsuidsetup(shift);


my $svcnum = shift;

my $svc_domain = qsearchs('svc_domain', { svcnum => $svcnum }) or die "no svcnum '$svcnum'";

my $h_svc_domain = qsearchs(
  'h_svc_domain',
  { 'svcnum' => $svc_domain->svcnum },
  FS::h_svc_domain->sql_h_searchs(time),
);

unless ($h_svc_domain) {
  print $svc_domain->_h_statement('insert', 1) . "\n";
}

foreach my $rec ($svc_domain->domain_record) {
  my $h_rec =  qsearchs(
    'h_domain_record',
    { 'svcnum' => $svc_domain->svcnum },
    FS::h_domain_record->sql_h_searchs(time),
  );

  #print Dumper($h_rec);

  unless ($h_rec) {
    print $rec->_h_statement('insert', 1) . "\n";
  }

}

