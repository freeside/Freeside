#!/usr/bin/perl -Tw

use strict;
use DBI;
use HTML::TableParser;
use Date::Parse;
use Text::CSV_XS;
use FS::Record qw(qsearch qsearchs);
use FS::cust_credit;
use FS::cust_main;
use FS::cust_pkg;
use FS::cust_svc;
use FS::svc_acct;
use FS::part_referral;
use FS::part_pkg;
use FS::UID qw(adminsuidsetup);

my $DEBUG = 0;

my $dry_run = '0';

my $s_dbname = 'DBI:Pg:dbname=optigoldimport';
my $s_dbuser = 'freeside';
my $s_dbpass = '';
my $extension = '.htm';

#my $d_dbuser = 'freeside';
my $d_dbuser = 'enet';
#my $d_dbuser = 'ivan';
#my $d_dbuser = 'freesideimport';

my $radius_file    = 'radius.csv';
my $email_file    = 'email.csv';

#my $agentnum = 1;
my $agentnum = 13;
my $legacy_domain_svcnum = 1;
my $legacy_ppp_svcpart = 2;
my $legacy_email_svcpart = 3;
#my $legacy_broadband_svcpart = 4;
#my $legacy_broadband_svcpart = 14;
#my $previous_credit_reasonnum = 1;
my $previous_credit_reasonnum = 1220;


my $state = '';  #statemachine-ish
my $sourcefile;
my $s_dbh;
my $columncount;
my $rowcount;

my @args = (
             {
               id    => 1,
               hdr   => \&header,
               row   => \&row,
               start => \&start,
               end   => \&end,
             },
           );


$s_dbh = DBI->connect($s_dbname, $s_dbuser, $s_dbpass,
                           { 'AutoCommit' => 0,
                             'ChopBlanks' => 1,
                             'ShowErrorStatement' => 1
                           }
                     );

foreach ( qw ( billcycle cust email product ) ) {
  $sourcefile = $_;

  print "parsing $sourcefile\n";

  die "bad file name" unless $sourcefile =~ /^\w+$/;

  $columncount = 0;
  $rowcount = 0;

  my $c_sth = '';
  if ( $c_sth = $s_dbh->prepare("SELECT COUNT(*) FROM $sourcefile") ) {
    if ( $c_sth->execute ) {
      if ( $c_sth->fetchrow_arrayref->[0] ) {
        warn "already have data in $sourcefile table; skipping";
        next;
      }
    }
  }

  my $tp = new HTML::TableParser( \@args, { Decode => 1, Trim => 1, Chomp => 1 });
  $tp->parse_file($sourcefile.$extension) or die "failed";
  $s_dbh->commit or die $s_dbh->errstr;
#  $s_dbh->disconnect;
}


sub start {
  warn "start\n" if $DEBUG;
  my $table_id = shift;
  die "unexpected state change" unless $state eq '';
  die "unexpected table" unless $table_id eq '1';
  $state = 'table';
}

sub end {
  warn "end\n" if $DEBUG;
  my ($tbl_id, $line, $udata) = @_;
  die "unexpected state change in header" unless $state eq 'rows';
  die "unexpected table" unless $tbl_id eq '1';
  $state = '';
}

sub header {
  warn "header\n" if $DEBUG;
  my ($tbl_id, $line, $cols, $udata) = @_;
  die "unexpected state change in header" unless $state eq 'table';
  die "unexpected table" unless $tbl_id eq '1';
  $state = 'rows';

  die "invalid column ". join (', ', grep { !/^[ \w\r]+$/ } @$cols)
    if scalar(grep { !/^[ \w\r]+$/ } @$cols);

  my $sql = "CREATE TABLE $sourcefile ( ".
    join(', ', map { s/[ \r]/_/g; "$_ varchar NULL" } @$cols). " )";
  $s_dbh->do($sql) or die "create table failed: ". $s_dbh->errstr;
  $columncount = scalar( @$cols );
}

sub row {
  warn "row\n" if $DEBUG;
  my ($tbl_id, $line, $cols, $udata) = @_;
  die "unexpected state change in row" unless $state eq 'rows';
  die "unexpected table" unless $tbl_id eq '1';

  die "invalid number of columns: ". join(', ', @$cols)
    unless (scalar(@$cols) == $columncount);

  my $sql = "INSERT INTO $sourcefile VALUES(".
    join(', ', map { $s_dbh->quote($_) } @$cols). ")";
  $s_dbh->do($sql) or die "insert failed: ". $s_dbh->errstr;
  $rowcount++;
  warn "row $rowcount\n" unless ($rowcount % 1000);
}

## now svc_acct from CSV files

$FS::cust_main::import=1;
$FS::cust_pkg::disable_agentcheck = 1;
$FS::cust_svc::ignore_quantity = 1;

my (%master_map) = ();
my (%referrals) = ();
my (%custid) = ();
my (%cancel) = ();
my (%susp) = ();
my (%adjo) = ();
my (%bill) = ();
my (%cust_pkg_map) = ();
my (%object_map) = ();
my (%package_cache) = ();
my $count = 0;

my $d_dbh = adminsuidsetup $d_dbuser;
local $FS::UID::AutoCommit = 0;

my @import = ( { 'file'     => $radius_file,
                 'sep_char' => ';',
                 'fields'   => [ qw( garbage1 username garbage2 garbage3 _password ) ],
                 'fixup'    => sub {
                                     my $hash = shift;
                                     delete $hash->{$_}
                                       foreach qw (garbage1 garbage2 garbage3);
                                     $hash->{'svcpart'} = $legacy_ppp_svcpart;
                                     $hash->{'domsvc'} = $legacy_domain_svcnum;
                                     '';
                                   },
                 'mapkey'   => 'legacy_ppp',
                 'skey'     => 'username',
               },
               { 'file'     => $email_file,
                 'sep_char' => ';',
                 'fields'   => [ qw( username null finger _password status garbage ) ],
                 'fixup'    => sub {
                                     my $hash = shift;
                                     return 1
                                       if $object_map{'legacy_ppp'}{$hash->{'username'}};
                                     delete $hash->{$_}
                                       foreach qw (null status garbage);
                                     $hash->{'svcpart'} = $legacy_email_svcpart;
                                     $hash->{'domsvc'} = $legacy_domain_svcnum;
                                     '';
                                   },
                 'mapkey'   => 'legacy_email',
                 'skey'     => 'username',
               },
);

while ( @import ) {
  my $href = shift @import;
  my $file = $href->{'file'} or die "No file specified";
  my (@fields)   = @{$href->{'fields'}};
  my ($sep_char) = $href->{'sep_char'} || ';';
  my ($fixup)    = $href->{'fixup'};
  my ($mapkey)   = $href->{'mapkey'};
  my ($skey)     = $href->{'skey'};
  my $line;

  my $csv = new Text::CSV_XS({'sep_char' => $sep_char});
  open(FH, $file) or die "cannot open $file: $!";
  $count = 0;

  while ( defined($line=<FH>) ) {
    chomp $line;

    $line &= "\177" x length($line); # i hope this isn't really necessary
    $csv->parse($line)
      or die "cannot parse: " . $csv->error_input();

    my @values = $csv->fields();
    my %hash;
    foreach my $field (@fields) {
      $hash{$field} = shift @values;
    }

    if (@values) {
      warn "skipping malformed line: $line\n";
      next;
    }

    my $skip = &{$fixup}(\%hash)
      if $fixup;

    unless ($skip) {
      my $svc_acct = new FS::svc_acct { %hash };
      my $error = $svc_acct->insert;
      if ($error) {
        warn $error;
        next;
      }

      if ($skey && $mapkey) {
        my $key = (ref($skey) eq 'CODE') ? &{$skey}($svc_acct) : $hash{$skey};
        $object_map{$mapkey}{$key} = $svc_acct->svcnum;
      }

      $count++
    }
  }
  print "Imported $count service records\n";

}



sub pkg_freq {
  my ( $href ) = ( shift );
  $href->{'one_time_list'}
    ? 0
#    : int(eval "$href->{'months_credit'} + 0");
    : int(eval "$href->{'month_credit'} + 0");
}

sub b_or {
  my ( $field, $hash ) = ( shift, shift );
  $field = 'bill_'. $field
    if $hash->{'billing_use'} eq 'Billing Address';
  $hash->{$field};
}

sub p_or {
  my ( $field, $hash ) = ( shift, shift );
  $field = 'bill_'. $field
    if $hash->{'billing_use'} eq 'Billing Address';
  my $ac = ( $hash->{$field. '_area_code'}
          && $hash->{$field. '_area_code'} =~ /^\d{3}$/ )
             ? $hash->{$field. '_area_code'}. '-'
             : '903-' # wtf?
  ;
  ( $hash->{$field} && $hash->{$field} =~ /^\d{3}-\d{4}$/)
    ? $ac. $hash->{$field}
    : '';
}

sub or_b {
  my ( $field, $hash ) = ( shift, shift );
  $hash->{'billing_use'} eq 'Billing Address' ? $hash->{$field} : '';
}

sub or_p {
  my ( $field, $hash ) = ( shift, shift );
  $hash->{'billing_use'} eq 'Billing Address' && $hash->{$field} =~ /^\d{3}-\d{4}$/
    ? ( $hash->{$field. '_area_code'} =~ /^\d{3}$/
        ? $hash->{$field. '_area_code'}. '-'
        : '903-'  # wtf?
      ). $hash->{$field}
    : '';
}

my %payby_map = ( ''              => 'BILL',
                  'None'          => 'BILL',
                  'Credit Card'   => 'CARD',
                  'Bank Debit'    => 'CHEK',
                  'Virtual Check' => 'CHEK',
);
sub payby {
  $payby_map{ shift->{billing_type} };
}

sub payinfo {
  my $hash = shift;
  my $payby = payby($hash);
  my $info;
  my $cc =
    $hash->{'credit_card_number_1'}.
    $hash->{'credit_card_number_2'}.
    $hash->{'credit_card_number_3'}.
    $hash->{'credit_card_number_4'};
  my $bank = 
    $hash->{'bank_account_number'}.
    '@'.
    $hash->{'bank_transit_number'};
  if ($payby eq 'CARD') {
    $info = $cc;
  }elsif ($payby eq 'CHEK') {
    $info = $bank;
  }elsif ($payby eq 'BILL') {
    $info = $hash->{'blanket_purchase_order_number'};
    $bank =~ s/[^\d\@]//g;
    $cc =~ s/\D//g;
    if ( $bank =~ /^\d+\@\d{9}/) {
      $info = $bank;
      $payby = 'DCHK';
    }
    if ( $cc =~ /^\d{13,16}/ ) {
      $info = $cc;
      $payby = 'DCRD';
    }
  }else{
    die "unexpected payby";
  }
  ($info, $payby);
}

sub ut_name_fixup {
  my ($object, $field) = (shift, shift);
  my $value = $object->getfield($field);
  $value =~ s/[^\w \,\.\-\']/ /g;
  $object->setfield($field, $value);
}

sub ut_text_fixup {
  my ($object, $field) = (shift, shift);
  my $value = $object->getfield($field);
  $value =~ s/[^\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=\[\]]/ /g;
  $object->setfield($field, $value);
}

sub ut_state_fixup {
  my ($object, $field) = (shift, shift);
  my $value = $object->getfield($field);
  $value = 'TX' if $value eq 'TTX';
  $object->setfield($field, $value);
}

sub ut_zip_fixup {
  my ($object, $field) = (shift, shift);
  my $value = $object->getfield($field);
  $value =~ s/[^-\d]//g;
  $object->setfield($field, $value);
}

my @tables = (
#part_pkg => { 'stable'  => 'product',
part_pkg => { 'stable'  => 'billcycle',
              'mapping' =>
                { 'pkg'      => sub { my $href = shift;
                                      $href->{'description'}
                                        ? $href->{'description'}
                                        : $href->{'product_id'};
                                    },
                  'comment'  => 'product_id',
                  'freq'     => sub { pkg_freq(shift) },
                  'recur'    => sub { my $href = shift;
                                      my $price = ( pkg_freq($href)
                                        ? $href->{'unit_price'}
                                        : 0
                                      );
                                      $price =~ s/[^\d.]//g;
                                      $price = 0 unless $price;
                                      sprintf("%.2f", $price);
                                    },
                  'setuptax' => sub { my $href = shift;
                                      $href->{'taxable'} ? '' : 'Y';
                                    },
                  'recurtax' => sub { my $href = shift;
                                      $href->{'taxable'} ? '' : 'Y';
                                    },
                  'plan'     => sub { 'flat' },
                  'disabled' => sub { 'Y' },
                  'pkg_svc'  => sub { my $href = shift;
                                      my $result = {};
                                      if (pkg_freq($href)){
                                        $result->{$legacy_ppp_svcpart} = 1;
                                        $result->{$legacy_email_svcpart} = 
                                            $href->{emails_allowed}
                                          if $href->{emails_allowed};
                                      }
                                    },
                  'primary_svc'=> sub { pkg_freq(shift)
                                          ? $legacy_ppp_svcpart
                                          : ''
                                        ;
                                      },
                },
              'fixup'   => sub { my $part_pkg = shift;
                                 my $row = shift;
                                 unless ($part_pkg->pkg =~ /^\s*(\S[\S ]*?)\s*$/) {
                                   warn "no pkg: ". $part_pkg->pkg. " for ". $row->{product_id};
                                   return 1;
                                 }

                                 unless ($part_pkg->comment =~ /^\s*(\S[\S ]*?)\s*$/) {
                                   warn "no comment: ". $part_pkg->comment. " for ". $row->{product_id};
                                   return 1;
                                 }

                                 return 1 if exists($package_cache{$1});
                                 $package_cache{$1} = $part_pkg;
                                 1;
                               },
              'wrapup'  => sub { foreach (keys %package_cache) {
                                   my $part_pkg = $package_cache{$_};
                                   my $options =
                                     { map { my $v = $part_pkg->$_;
                                             $part_pkg->$_('');
                                             ($_ => $v);
                                           }
                                       qw (setup recur)
                                     };
                                   my $error =
                                     $part_pkg->insert(options=>$options);
                                   die "Error inserting package: $error"
                                     if $error;
                                   $count++ unless $error;
                                 }
                               },
            },
part_referral => { 'stable'  => 'cust',
                   'mapping' =>
                     { 'agentnum' => sub { $agentnum },
                       'referral' => sub { my $r = shift->{'referred_from'};
                                           $referrals{$r} = 1;
                                         },
                     },
                   'fixup'   => sub { 1 },
                   'wrapup'  => sub { foreach (keys %referrals) {
                                        my $part_referral =
                                          new FS::part_referral( {
                                            'agentnum' => $agentnum,
                                            'referral' => $referrals{$_},
                                          } );
                                        my $error = $part_referral->insert;
                                        die "Error inserting referral: $error"
                                          if $error;
                                        $count++ unless $error;
                                        $referrals{$_} = $part_referral->refnum;
                                      }
                                    },
                 },
#svc_acct  => { 'stable'  => 'cust',
#               'mapping' =>
#                 { 'username'     => 'login',
#                   '_password'    => 'password',
#                   'svcpart'      => sub{ $legacy_ppp_svcpart },
#                   'domsvc'       => sub{ $legacy_domain_svcnum },
#                   'status'       => 'status',
#                 },
#               'fixup'   => sub { my $svc_acct = shift;
#                                  my $row = shift;
#                                  my $id = $row->{'master_account'}
#                                           ? 'slave:'. $row->{'customer_id'}
#                                           : $row->{'login'};
#                                  my $status = $svc_acct->status;
#                                  if ( $status ne 'Current'
#                                    && $status ne 'On Hold' )
#                                  {
#                                    $cancel{$id} =
#                                      str2time($row->{termination_date});
#                                    warn "not creating (cancelled) svc_acct for " .
#                                      $svc_acct->username. "\n";
#                                    return 1
#                                  }
#                                  $susp{$id} = str2time($row->{hold_date})
#                                    if $status eq 'On Hold';
#                                  $adjo{$id} = str2time($row->{hold_date})
#                                    if ( $status eq 'Current' &&
#                                         $row->{hold_date} );
#                                  $bill{$id} =
#                                    str2time($row->{expiration_date});
#                                  '';
#                                },
#               'skey'    => sub { my $svc_acct = shift;
#                                  my $row = shift;
#                                  my $id = $row->{'master_account'}
#                                    ? 'slave:'. $row->{'customer_id'}
#                                    : $row->{'login'};
#                                },
#             },
cust_main => { 'stable'  => 'cust',
               'mapping' =>
                 { 'agentnum'     => sub { $agentnum },
                   'agent_custid' => sub { my $id = shift->{'customer_number'};
                                           if (exists($custid{$id})) {
                                             $custid{$id}++;
                                             $id.  chr(64 + $custid{$id});
                                           }else{
                                             $custid{$id} = 0;
                                             $id;
                                           }
                                         },
                   'last'         => sub { b_or('last_name', shift) || ' ' },
                   'first'        => sub { b_or('first_name', shift)  || ' ' },
                   'stateid'      => 'drivers_license_number',
                   'signupdate'   => sub { str2time(shift->{'creation_date'}) },
                   'company'      => sub { b_or('company_name', shift) },
                   'address1'     => sub { b_or('address', shift) || ' ' },
                   'city'         => sub { b_or('city', shift) || 'Paris' },
                   'state'        => sub { uc(b_or('state', shift)) || 'TX' },
                   'zip'          => sub { b_or('zip_code', shift) || '75460' },
                   'country'      => sub { 'US' },
                   'daytime'      => sub { p_or('phone', shift) },
                   'night'        => sub { p_or('phone_alternate_1', shift) },
                   'fax'          => sub { p_or('fax', shift) },
                   'ship_last'    => sub { or_b('last_name', shift) },
                   'ship_first'   => sub { or_b('first_name', shift) },
                   'ship_company' => sub { or_b('company_name', shift) },
                   'ship_address1'=> sub { or_b('address', shift) },
                   'ship_city'    => sub { or_b('city', shift) },
                   'ship_state'   => sub { uc(or_b('state', shift)) },
                   'ship_zip'     => sub { or_b('zip_code', shift) },
                   'ship_daytime' => sub { or_p('phone', shift) },
                   'ship_fax'     => sub { or_p('fax', shift) },
                   'tax'          => sub { shift->{taxable} eq '' ? 'Y' : '' },
                   'refnum'       => sub { $referrals{shift->{'referred_from'}}
                                           || 1
                                         },
                 },
               'fixup'   => sub { my $cust_main = shift;
                                  my $row = shift;

                                  my ($master_account, $customer_id, $login) =
                                    ('', '', '');
                                  $row->{'master_account'} =~ /^\s*(\S[\S ]*?)\s*$/
                                    && ($master_account = $1);
                                  $row->{'customer_id'} =~ /^\s*(\S[\S ]*?)\s*$/
                                    && ($customer_id = $1);
                                  $row->{'login'} =~ /^\s*(\S[\S ]*?)\s*$/
                                    && ($login = $1);

                                  my $id = $master_account
                                           ? 'slave:'. $customer_id
                                           : $login;
                                  my $status = $row->{status};

                                  my $cancelled = 0;
                                  if ( $status ne 'Current'
                                    && $status ne 'On Hold' )
                                  {
                                    $cancelled = 1;
                                    $cancel{$id} =
                                      str2time($row->{termination_date});
                                  }
                                  $susp{$id} = str2time($row->{hold_date})
                                    if ($status eq 'On Hold' && !$cancelled);
                                  $adjo{$id} = str2time($row->{hold_date})
                                    if ( $status eq 'Current' && !$cancelled &&
                                         $row->{hold_date} );
                                  $bill{$id} =
                                      str2time($row->{expiration_date})
                                    if (!$cancelled);

                                  my $svcnum =
                                    $object_map{legacy_ppp}{$row->{'login'} };
                                  unless( $cancelled || $svcnum ) {
                                    warn "can't find svc_acct for legacy ppp ".
                                        $row->{'login'}, "\n";
                                  }

                                  $object_map{svc_acct}{$id} = $svcnum
                                    unless $cancelled;

                                  $master_map{$login} = $row->{master_account}
                                    if $row->{master_account};
                                  return 1 if $row->{master_account};
                                  $cust_main->ship_country('US')
                                    if $cust_main->has_ship_address;
                                  ut_name_fixup($cust_main, 'first');
                                  ut_name_fixup($cust_main, 'company');
                                  ut_name_fixup($cust_main, 'last');

                                  my ($info, $payby) = payinfo($row);
                                  $cust_main->payby($payby);
                                  $cust_main->payinfo($info);

                                  $cust_main->paycvv(
                                      $row->{'credit_card_cvv_number'}
                                  )
                                    if ($payby eq 'CARD' or $payby eq 'DCRD');

                                  $cust_main->paydate('20'.
                                      $row->{'credit_card_exp_date_2'}.  '-'.
                                      substr(
                                        $row->{'credit_card_exp_date_1'},
                                        0,
                                        2,
                                      ).
                                      '-01'
                                  )
                                    if ($payby eq 'CARD' or $payby eq 'DCRD');

                                  my $payname = '';
                                  $payname = $row->{'credit_card_name'}
                                    if ($payby eq 'CARD' or $payby eq 'DCRD');
                                  $payname = $row->{'bank_name'}
                                    if ($payby eq 'CHEK' or $payby eq 'DCHK');
                                  $cust_main->payname($payname);

                                  $cust_main->paytype(
                                      $row->{'bank_account_to_debit'}
                                        ? 'Personal '.
                                          $row->{bank_account_to_debit}
                                        : ''
                                  )
                                    if ($payby eq 'CHEK' or $payby eq 'DCHK');

                                  $cust_main->payby('BILL')
                                    if ($cust_main->payby eq 'CHEK' && 
                                        $cust_main->payinfo !~ /^\d+\@\d{9}$/);
                                  $cust_main->payby('BILL')
                                    if ($cust_main->payby eq 'CARD' && 
                                        $cust_main->payinfo =~ /^\s*$/);
                                  $cust_main->paydate('2037-12-01')
                                    if ($cust_main->payby eq 'BILL');
                                  ut_text_fixup($cust_main, 'address1');
                                  ut_state_fixup($cust_main, 'state');
                                  ut_zip_fixup($cust_main, 'zip');


                                  '';
                                },
               'skey'    => sub { my $object = shift;
                                  my $href = shift;
                                  my $balance = sprintf("%.2f",
                                                        $href->{balance_due});
                                  if ($balance < 0) {
                                    my $cust_credit = new FS::cust_credit({
                                      'custnum'   => $object->custnum,
                                      'amount'    => sprintf("%.2f", -$balance),
                                      'reasonnum' => $previous_credit_reasonnum,
                                    });
                                    my $error = $cust_credit->insert;
                                    warn "Error inserting credit for ",
                                         $href->{'login'}, " : $error\n"
                                      if $error;

                                  }elsif($balance > 0) {
                                    my $error = $object->charge(
                                                  $balance, "Prior balance",
                                                );
                                    warn "Error inserting balance charge for ",
                                         $href->{'login'}, " : $error\n"
                                      if $error;

                                  }
                                  $href->{'login'};
                                },
             },
#cust_main => { 'stable'  => 'cust',
#               'mapping' =>
#                 { 'referred_by' => sub { my $href = shift;
#                                          my $u = shift->{'login'};
#                                          my $cn = $href->{'customer_number'};
#
#                                          my $c = qsearch( 'cust_main', 
#                                                           { 'custnum' => $cn }
#                                          ) or die "can't fine customer $cn";
#
#                                          my $s = qsearch( 'svc_acct', 
#                                                           { 'username' => $u }
#                                                         ) or return '';
#
#                                          my $n = $s->cust_svc
#                                                    ->cust_pkg
#                                                    ->cust_main
#                                                    ->custnum;
#
#                                          $c->referral_custnum($n);
#                                          my $error = $c->replace;
#                                          die "error setting referral: $error"
#                                            if $error;
#                                          '';
#                                        },
#                 };
#               'fixup'   => sub { 1 },
#             },
cust_pkg  => { 'stable'  => 'billcycle',
               'mapping' =>
                 { 'custnum'     => sub { my $l = shift->{cbilling_cycle_login};
                                          $l =~ /^\s*(\S[\S ]*?)\s*$/ && ($l = $1);
                                          my $r = $object_map{'cust_main'}{$l};
                                          unless ($r) {
                                            my $m = $master_map{$l};
                                            $r = $object_map{'cust_main'}{$m}
                                              if $m;
                                          }
                                          $r;
                                        },
                   'pkgpart'     => sub { my $p = shift->{product_id};
                                          $p =~ /^\s*(\S[\S ]*?)\s*$/ && ($p = $1);
                                          $package_cache{$p}
                                            ? $package_cache{$p}->pkgpart
                                            : '';
                                        },
                   'setup'       => sub { str2time(shift->{creation_date}) },
                   'bill'        => sub { my $href = shift;
                                          my $id = $href->{'slave_account_id'}
                                            ? 'slave:'. $href->{'slave_account_id'}
                                            : $href->{'cbilling_cycle_login'};
                                          $bill{$id};
                                        },
                   'susp'        => sub { my $href = shift;
                                          my $id = $href->{'slave_account_id'}
                                            ? 'slave:'. $href->{'slave_account_id'}
                                            : $href->{'cbilling_cycle_login'};
                                          $susp{$id};
                                        },
                   'adjo'        => sub { my $href = shift;
                                          my $id = $href->{'slave_account_id'}
                                            ? 'slave:'. $href->{'slave_account_id'}
                                            : $href->{'cbilling_cycle_login'};
                                          $adjo{$id};
                                        },
                   'cancel'      => sub { my $href = shift;
                                          my $id = $href->{'slave_account_id'}
                                            ? 'slave:'. $href->{'slave_account_id'}
                                            : $href->{'cbilling_cycle_login'};
                                          $cancel{$id};
                                        },
                 },
               'fixup'  => sub { my ($object, $row) = (shift,shift);
                                 unless ($object->custnum) {
                                   warn "can't find customer for ".
                                     $row->{cbilling_cycle_login}. "\n";
                                   return 1;
                                 }
                                 unless ($object->pkgpart) {
                                   warn "can't find package for ".
                                     $row->{product_id}. "\n";
                                   return 1;
                                 }
                                 '';
                               },
               'skey'   => sub { my $object = shift;
                                 my $href = shift;
                                 if ($href->{'slave_account_id'} =~ /^\s*(\S[\S ]*?)\s*$/) {
                                   "slave:$1";
                                 }else{
                                   my $id = $href->{'billing_cycle_item_id'};
                                   $cust_pkg_map{$id} = $object->pkgnum;
                                   $href->{'cbilling_cycle_login'};
                                 }
                               },
               'wrapup'   => sub { for my $id (keys %{$object_map{'cust_pkg'}}){
                                     my $cust_svc =
                                       qsearchs( 'cust_svc', { 'svcnum' =>
                                                 $object_map{'svc_acct'}{$id} }
                                       );
                                     unless ($cust_svc) {
                                       warn "can't find legacy ppp $id\n";
                                       next;
                                     }
                                     $cust_svc->
                                       pkgnum($object_map{'cust_pkg'}{$id});
                                     my $error = $cust_svc->replace;
                                     warn "error linking legacy ppp $id: $error\n"
                                       if $error;
                                   }
                                 },
             },
svc_acct  => { 'stable'  => 'email',
               'mapping' =>
                 { 'username'    => 'email_name',
                   '_password'   => 'password',
                   'svcpart'      => sub{ $legacy_email_svcpart },
                   'domsvc'       => sub{ $legacy_domain_svcnum },
                 },
#               'fixup'   => sub { my ($object, $row) = (shift,shift);
#                                  my ($sd,$sm,$sy) = split '/',
#                                                     $row->{shut_off_date}
#                                    if $row->{shut_off_date};
#                                  if ($sd && $sm && $sy) {
#                                    my ($cd, $cm, $cy) = (localtime)[3,4,5];
#                                    $cy += 1900; $cm++;
#                                    return 1 if $sy < $cy;
#                                    return 1 if ($sy == $cy && $sm < $cm);
#                                    return 1 if ($sy == $cy && $sm == $cm && $sd <= $cd);
#                                  }
#                                  return 1 if $object_map{'cust_main'}{$object->username};
#                                  '';
#                                },
               'fixup'   => sub { my ($object, $row) = (shift,shift);
                                  my ($sd,$sm,$sy) = split '/',
                                                     $row->{shut_off_date}
                                    if $row->{shut_off_date};
                                  if ($sd && $sm && $sy) {
                                    my ($cd, $cm, $cy) = (localtime)[3,4,5];
                                    $cy += 1900; $cm++;
                                    return 1 if $sy < $cy;
                                    return 1 if ($sy == $cy && $sm < $cm);
                                    return 1 if ($sy == $cy && $sm == $cm && $sd <= $cd);
                                  }
                                  return 1 if $object_map{'cust_main'}{$object->username};

                                  my $svcnum =
                                    $object_map{legacy_email}{$row->{'email_name'} };
                                  unless( $svcnum ) {
                                    warn "can't find svc_acct for legacy email ".
                                      $row->{'email_name'}, "\n";
                                    return 1;
                                  }

                                  $object_map{svc_acct}{'email:'.$row->{'email_customer_id'}} = $svcnum;
                                  return 1;
                                },
#               'skey'    => sub { my $object = shift;
#                                  my $href = shift;
#                                  'email:'. $href->{'email_customer_id'};
#                                },
               'wrapup'   => sub { for my $id (keys %{$object_map{'cust_pkg'}}){
                                     next unless $id =~ /^email:(\d+)/;
                                     my $custid = $1;
                                     my $cust_svc =
                                       qsearchs( 'cust_svc', { 'svcnum' =>
                                                 $object_map{'svc_acct'}{$id} }
                                       );
                                     unless ($cust_svc) {
                                       warn "can't find legacy email $id\n";
                                       next;
                                     }

                                     $cust_svc->
                                       pkgnum($cust_pkg_map{$custid});
                                     my $error = $cust_svc->replace;
                                     warn "error linking legacy email $id: $error\n"
                                       if $error;
                                   }
                                 },
             },
);

#my $s_dbh = DBI->connect($s_datasrc, $s_dbuser, $s_dbpass) or die $DBI::errstr;

while ( @tables ) {
  my ($table, $href) = (shift @tables, shift @tables);
  my $stable = $href->{'stable'} or die "No source table"; # good enough for now
  my (%mapping) = %{$href->{'mapping'}};
  my ($fixup)   = $href->{'fixup'};
  my ($wrapup)  = $href->{'wrapup'};
  my ($id)      = $href->{'id'};
  my ($skey)    = $href->{'skey'};

  #$d_dbh->do("delete from $table");

  my $s_sth = $s_dbh->prepare("select count(*) from $stable");
  $s_sth->execute or die $s_sth->errstr;
  my $rowcount = $s_sth->fetchrow_arrayref->[0];

  $s_sth = $s_dbh->prepare("select * from $stable");
  $s_sth->execute or die $s_sth->errstr;

  my $row;
  $count = 0;
  while ( $row = $s_sth->fetchrow_hashref ) {
    my $class = "FS::$table";

    warn sprintf("%.2f", 100*$count/$rowcount). "% of $table processed\n"
      unless( !$count || $count % 100 );

    my $object = new $class ( {
        map { $_  => ( ref($mapping{$_}) eq 'CODE'
                       ? &{$mapping{$_}}($row)
                       : $row->{$mapping{$_}}
                     )
            }
          keys(%mapping) 
    } );
    my $skip = &{$fixup}($object, $row)
      if $fixup;

    unless ($skip) {
      my $error = $object->insert;
      if ($error) {
        warn "Error inserting $table ".
          join(", ", map{"$_ => ". $object->get($_)} fields $object).
          ": $error\n";
        next;
      }
      if ($skey) {
        my $key = (ref($skey) eq 'CODE') ? &{$skey}($object, $row)
                                         : $row->{$skey};
        $object_map{$table}{$key} = $object->get($object->primary_key)
      }
      $count++;
    }
  }

  &{$wrapup}()
    if $wrapup;

  print "$count/$rowcount of $table SUCCESSFULLY processed\n";

}

if ($dry_run) {
  $d_dbh->rollback;
}else{
  $d_dbh->commit or die $d_dbh->errstr;
}

