package FS::bill_batch;

use strict;
use vars qw( @ISA $me $DEBUG );
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_bill_batch;
use CAM::PDF;

@ISA = qw( FS::Record );
$me = '[ FS::bill_batch ]';
$DEBUG=0;

sub table { 'bill_batch' }

sub nohistory_fields { 'pdf' }

=head1 NAME

FS::bill_batch - Object methods for bill_batch records

=head1 SYNOPSIS

  use FS::bill_batch;

  $open_batch = FS::bill_batch->get_open_batch;
  
  my $pdf = $open_batch->print_pdf;
  
  $error = $open_batch->close;
  
=head1 DESCRIPTION

An FS::bill_batch object represents a batch of invoices.  FS::bill_batch 
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item batchnum - primary key

=item status - either 'O' (open) or 'R' (resolved/closed).

=item pdf - blob field for temporarily storing the invoice as a PDF.

=back

=head1 METHODS

=over 4

=item print_pdf

Typeset the entire batch as a PDF file.  Returns the PDF as a string.

=cut

sub print_pdf {
  my $self = shift;
  my $job = shift;
  $job->update_statustext(0) if $job;
  my @invoices = sort { $a->invnum <=> $b->invnum }
                 qsearch('cust_bill_batch', { batchnum => $self->batchnum });
  return "No invoices in batch ".$self->batchnum.'.' if !@invoices;

  my $pdf_out;
  my $num = 0;
  foreach my $invoice (@invoices) {
    my $part = $invoice->cust_bill->print_pdf({$invoice->options});
    die 'Failed creating PDF from invoice '.$invoice->invnum.'\n' if !$part;

    if($pdf_out) {
      $pdf_out->appendPDF(CAM::PDF->new($part));
    }
    else {
      $pdf_out = CAM::PDF->new($part);
    }
    if($job) {
      # update progressbar
      $num++;
      my $error = $job->update_statustext(int(100 * $num/scalar(@invoices)));
      die $error if $error;
    }
  }

  return $pdf_out->toPDF;
}

=item close

Set the status of the batch to 'R' (resolved).

=cut

sub close {
  my $self = shift;
  $self->status('R');
  return $self->replace;
}

=back

=head1 CLASS METHODS

=item get_open_batch

Returns the currently open batch.  There should only be one at a time.

=cut

sub get_open_batch {
  my $class = shift;
  my $batch = qsearchs('bill_batch', { status => 'O' });
  return $batch if $batch;
  $batch = FS::bill_batch->new({status => 'O'});
  my $error = $batch->insert;
  die $error if $error;
  return $batch;
}

use Storable 'thaw';
use Data::Dumper;
use MIME::Base64;

sub process_print_pdf {
  my $job = shift;
  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;
  die "no batchnum specified!\n" if ! exists($param->{batchnum});
  my $batch = FS::bill_batch->by_key($param->{batchnum});
  die "batch '$param->{batchnum}' not found!\n" if !$batch;

  my $pdf = $batch->print_pdf($job);
  $batch->pdf($pdf);
  my $error = $batch->replace;
  die $error if $error;
}


=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

