package FS::pay_batch::td_eftack264;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Date::Format 'time2str';
use FS::Conf;
use FS::Record qw(qsearch);

=head1 NAME

td_eftack264 - TD Commercial Banking EFT 264 byte acknowledgement file

=cut

$name = 'td_eftack264';

%import_info = (
  'filetype'    => 'fixed',
  'formatre'    => 
  '^(.)(.{9})(.{10})(.{4})(.{3})(.{10})(.{6})(.{9})(.{12}).{25}(.{15})(.{30})(.{30})(.{10})(.{19})(.{9})(.{12}).{15}.{22}(..)(.{11})$',
  'fields' => [ qw(
    recordtype
    count
    origid
    fcn
    cpacode
    paid
    duedate
    bank
    payinfo
    shortname
    custname
    longname
    origid2
    paybatchnum
    retbranch
    retacct
    usdcode
    invfield
    ) ],
  'hook' => sub {
    my $hash = shift;
    $hash->{'_date'} = time;
    $hash->{'paid'} = sprintf('%.2f', $hash->{'paid'} / 100);
    $hash->{'payinfo'} =~ s/^(\S+).*/$1/; # remove trailing spaces
    $hash->{'payinfo'} = $hash->{'payinfo'} . '@' . $hash->{'bank'};
  },
  'approved'    => sub { 0 },
  'declined'    => sub { 1 },
  'skip_condition' => sub {
    my $hash = shift;
    $hash->{'recordtype'} ne 'D'; # Debit Detail record
  },
  'close_condition' => sub { 0 },
);

%export_info = ( filetype => 'NONE' );
1;

