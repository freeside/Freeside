package FS::detail_format;

use strict;
use vars qw( $DEBUG );
use FS::Conf;
use FS::cdr;
use FS::cust_bill_pkg_detail;
use Date::Format qw(time2str);
use Text::CSV_XS;

my $me = '[FS::detail_format]';

=head1 NAME

FS::detail_format - invoice detail formatter

=head1 DESCRIPTION

An FS::detail_format object is a converter to create invoice details 
(L<FS::cust_bill_pkg_detail>) from call detail records (L<FS::cdr>)
or other usage information.  FS::detail_format inherits from nothing.

Subclasses of FS::detail_format represent specific detail formats.

=head1 CLASS METHODS

=over 4

=item new FORMAT, OPTIONS

Returns a new detail formatter.  The FORMAT argument is the name of 
a subclass.

OPTIONS may contain:

- buffer: an arrayref to store details into.  This may avoid the need for 
  a large copy operation at the end of processing.  However, since 
  summary formats will produce nothing until the end of processing, 
  C<finish> must be called after all CDRs have been appended.

- inbound: a flag telling the formatter to format CDRs for display to 
  the receiving party, rather than the originator.  In this case, the 
  L<FS::cdr_termination> object will be fetched and its values used for
  rated_price, rated_seconds, rated_minutes, and svcnum.  This can be 
  changed with the C<inbound> method.

=cut

sub new {
  my $class = shift;
  if ( $class eq 'FS::detail_format' ) {
    my $format = shift
      or die "$me format name required";
    $class = "FS::detail_format::$format"
      unless $format =~ /^FS::detail_format::/;
  }
  eval "use $class";
  die "$me error loading $class: $@" if $@;
  my %opt = @_;

  my $self = { conf => FS::Conf->new,
               csv  => Text::CSV_XS->new,
               inbound  => ($opt{'inbound'} ? 1 : 0),
               buffer   => ($opt{'buffer'} || []),
             }; 
  bless $self, $class;
}

=back

=head1 METHODS

=item inbound VALUE

Set/get the 'inbound' flag.

=cut

sub inbound {
  my $self = shift;
  $self->{inbound} = ($_[0] > 0) if (@_);
  $self->{inbound};
}

=item append CDRS

Takes any number of call detail records (as L<FS::cdr> objects),
formats them, and appends them to the internal buffer.

By default, this simply calls C<single_detail> on each CDR in the 
set.  Subclasses should override C<append> and maybe C<finish> if 
they do not produce detail lines from CDRs in a 1:1 fashion.

The 'billpkgnum', 'invnum', 'pkgnum', and 'phonenum' fields will 
be set later.

=cut

sub append {
  my $self = shift;
  foreach (@_) {
    push @{ $self->{buffer} }, $self->single_detail($_);
  }
}

=item details

Returns all invoice detail records in the buffer.  This will perform 
a C<finish> first.  Subclasses generally shouldn't override this.

=cut

sub details {
  my $self = shift;
  $self->finish;
  @{ $self->{buffer} }
}

=item finish

Ensures that all invoice details are generated given the CDRs that 
have been appended.  By default, this does nothing.

=cut

sub finish {}

=item header

Returns a header row for the format, as an L<FS::cust_bill_pkg_detail>
object.  By default this has 'format' = 'C', 'detail' = the value 
returned by C<header_detail>, and all other fields empty.

This is called after C<finish>, so it can use information from the CDRs.

=cut

sub header {
  my $self = shift;

  FS::cust_bill_pkg_detail->new(
    { 'format' => 'C', 'detail' => $self->header_detail }
  )
}

=item single_detail CDR

Takes a single CDR and returns an invoice detail to describe it.

By default, this maps the following fields from the CDR:

rated_price       => amount
rated_classnum    => classnum
rated_seconds     => duration
rated_regionname  => regionname
accountcode       => accountcode
startdate         => startdate

It then calls C<columns> on the CDR to obtain a list of detail
columns, formats them as a CSV string, and stores that in the 
'detail' field.

=cut

sub single_detail {
  my $self = shift;
  my $cdr = shift;

  my @columns = $self->columns($cdr);
  my $status = $self->csv->combine(@columns);
  die "$me error combining ".$self->csv->error_input."\n"
    if !$status;

  my $rated_price = $cdr->rated_price;
  $rated_price = 0 if $cdr->freesidestatus eq 'no-charge';

  FS::cust_bill_pkg_detail->new( {
      'amount'      => $rated_price,
      'classnum'    => $cdr->rated_classnum,
      'duration'    => $cdr->rated_seconds,
      'regionname'  => $cdr->rated_regionname,
      'accountcode' => $cdr->accountcode,
      'startdate'   => $cdr->startdate,
      'format'      => 'C',
      'detail'      => $self->csv->string,
  });
}

=item columns CDR

Returns a list of CSV columns (to be shown on the invoice) for
the CDR.  This is the method most subclasses should override.

=cut

sub columns {
  my $self = shift;
  die "$me no columns method in ".ref($self);
}

=item header_detail

Returns the 'detail' field for the header row.  This should 
probably be a CSV string of column headers for the values returned
by C<columns>.

=cut

sub header_detail {
  my $self = shift;
  die "$me no header_detail method in ".ref($self);
}

# convenience methods for subclasses

sub conf { $_[0]->{conf} }

sub csv { $_[0]->{csv} }

sub date_format {
  my $self = shift;
  $self->{date_format} ||= ($self->conf->config('date_format') || '%m/%d/%Y');
}

sub money_char {
  my $self = shift;
  $self->{money_char} ||= ($self->conf->config('money_char') || '$');
}

#imitate previous behavior for now

sub duration {
  my $self = shift;
  my $cdr = shift;
  my $object = $self->{inbound} ? $cdr->cdr_termination(1) : $cdr;
  my $sec = $object->rated_seconds if $object;
  # XXX termination objects don't have rated_granularity so this may 
  # result in inbound CDRs being displayed as min/sec when they shouldn't.
  # Should probably fix this.
  if ( $cdr->rated_granularity eq '0' ) {
    '1 call';
  }
  elsif ( $cdr->rated_granularity eq '60' ) {
    sprintf('%dm', ($sec + 59)/60);
  }
  else {
    sprintf('%dm %ds', $sec / 60, $sec % 60);
  }
}

sub price {
  my $self = shift;
  my $cdr = shift;
  my $object = $self->{inbound} ? $cdr->cdr_termination(1) : $cdr;
  my $price = $object->rated_price if $object;
  $price = '0.00' if $object->freesidestatus eq 'no-charge';
  length($price) ? $self->money_char . $price : '';
}

1;
