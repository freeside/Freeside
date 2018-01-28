#!/usr/bin/env perl

=head1 Fake SMTP Server

While this script is running, creates an SMTP server at localhost port 25.

Can only accept one client connection at a time.  If necessary,
it could be updated to fork on client connections.

When an e-mail is delivered, the TO and FROM are printed to STDOUT.
The TO, FROM and MSG are saved to a file in $message_save_dir

=cut

use strict;
use warnings;

use Carp;
use Net::SMTP::Server;
use Net::SMTP::Server::Client;
use Net::SMTP::Server::Relay;

my $message_save_dir = '/home/freeside/fakesmtpserver';

mkdir $message_save_dir, 0777;

my $server = new Net::SMTP::Server('localhost', 25) ||
    croak("Unable to handle client connection: $!\n");

while(my $conn = $server->accept()) {
  my $client = new Net::SMTP::Server::Client($conn) ||
      croak("Unable to handle client connection: $!\n");

  $client->process || next;

  open my $fh, '>', $message_save_dir.'/'.time().'.txt'
    or die "error: $!";

  for my $f (qw/TO FROM/) {

      if (ref $client->{$f} eq 'ARRAY') {
        print "$f: $_\n" for @{$client->{$f}};
        print $fh "$f: $_\n" for @{$client->{$f}};
      } else {
        print "$f: $client->{$f}\n";
        print $fh "$f: $client->{$f}\n";
      }

  }
  print $fh "\n\n$client->{MSG}\n";
  print "\n";
  close $fh;
}
