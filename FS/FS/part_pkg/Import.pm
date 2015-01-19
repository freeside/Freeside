package FS::part_pkg::Import;

use strict;
use FS::Record;
use FS::part_pkg;

=head1 NAME

FS::part_pkg::Import - Batch customer importing

=head1 SYNOPSIS

  use FS::part_pkg::Import;

  #ajax helper
  use FS::UI::Web::JSRPC;
  my $server =
    new FS::UI::Web::JSRPC 'FS::part_pkg::Import::process_batch_import', $cgi;
  print $server->process;

=head1 DESCRIPTION

Batch package definition importing.

=head1 SUBROUTINES

=item process_batch_import

Load a batch import as a queued JSRPC job

=cut

sub process_batch_import {
  my $job = shift;

  my $opt = { 'table'       => 'part_pkg',
              'params'      => [qw( agentnum pkgpartbatch )],
              'formats'     => { 'default' => [
                                   'agent_pkgpartid',
                                   'pkg',
                                   'comment',
                                   'freq',
                                   'plan',
                                   'setup_fee',
                                   'recur_fee',
                                   'setup_cost',
                                   'recur_cost',
                                   'classnum',
                                   'taxclass',
                                 ],
                               },
              'insert_args_callback' => sub {
                my $part_pkg = shift;
                ( 'options' => { 'setup_fee' => $part_pkg->get('setup_fee'),
                                 'recur_fee' => $part_pkg->get('recur_fee'),
                               },
                );
              },
              #'default_csv' => 1,
            };

  FS::Record::process_batch_import( $job, $opt, @_ );

}

=head1 BUGS

Not enough documentation.

=head1 SEE ALSO

L<FS::cust_main>, L<FS::part_pkg>

=cut

1;
