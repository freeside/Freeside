package FS::pay_batch::td_eftret80;

use strict;
use vars qw(@ISA %import_info %export_info $name);

=head1 NAME

td_eftret80 - TD Commercial Banking EFT 80 byte returned item file

=cut

$name = 'td_eftret80';

%import_info = (
  'filetype'    => 'fixed',
  'formatre'    => '^(.)(.{20})(..)(.)(.{6})(.{19})(.{9})(.{12})(.{10})$',
  'fields' => [ qw(
    recordtype
    custname
    reason
    verified
    duedate
    paybatchnum
    bank
    payinfo
    amount
    ) ],
  'hook' => sub {
    my $hash = shift;
    $hash->{'_date'} = time;
    $hash->{'paid'} = sprintf('%.2f', $hash->{'paid'} / 100);
    $hash->{'payinfo'} =~ s/^(\S+).*/$1/; # these often have trailing spaces
    $hash->{'payinfo'} = $hash->{'payinfo'} . '@' . $hash->{'bank'};
  },
  'approved' => sub { 0 },
  'declined' => sub { 1 },
  'skip_condition' => sub {
      my $hash = shift;
      $hash->{'recordtype'} ne 'D'; #Detail record
  },
  'close_condition' => sub { 0 }, # never close just from this
);

%export_info = ( filetype => 'NONE' );
1;

