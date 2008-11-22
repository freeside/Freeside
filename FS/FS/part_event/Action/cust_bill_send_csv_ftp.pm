package FS::part_event::Action::cust_bill_send_csv_ftp;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Upload CSV invoice data to an FTP server'; }

sub deprecated { 1; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'ftpformat'   => { label   => 'Format',
                       type    =>'select',
                       options => ['default', 'billco'],
                       option_labels => { 'default' => 'Default',
                                          'billco'  => 'Billco',
                                        },
                     },
    'ftpserver'   => 'FTP server',
    'ftpusername' => 'FTP username',
    'ftppassword' => 'FTP password',
    'ftpdir'      => 'FTP directory',
  );
}

sub default_weight { 50; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  $cust_bill->send_csv(
    'protocol'   => 'ftp',
    'server'     => $self->option('ftpserver'),
    'username'   => $self->option('ftpusername'),
    'password'   => $self->option('ftppassword'),
    'dir'        => $self->option('ftpdir'),
    'format'     => $self->option('ftpformat'),
  );

  '';
}

1;
